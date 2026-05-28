/**
 * Lumark OCR Proxy — Cloudflare Worker
 *
 * 목적: Gemini API 키를 클라이언트(iOS 앱)에 노출하지 않고, 서버가 키를 쥐고
 *       대신 호출한다. 기기당/전체 일일 페이지 한도로 비용 폭주를 막는다.
 *
 * 흐름:
 *   앱 → POST /ocr  { "image_base64": "<jpeg base64>" }  + 헤더 X-Device-ID
 *      → (한도 체크) → Gemini generateContent 호출 → spans 추출
 *      → 200 { "spans": [{ "text", "color" }] }
 *
 * 한도 초과: 429 { "error": "...", "scope": "device" | "global" }
 *
 * 필요한 바인딩 (wrangler.toml / 대시보드):
 *   - KV namespace: RATE        (일일 카운터)
 *   - secret: GEMINI_KEY        (Google AI Studio 키)
 *   - var: MODEL                (예: "gemini-2.5-flash-lite")
 *   - var: PER_DEVICE_DAILY     (기기당 일일 페이지 한도, 예: "60")
 *   - var: GLOBAL_DAILY         (전체 일일 페이지 한도, 예: "1500")
 */

const PROMPT = `이 페이지 이미지에서 형광펜으로 강조된 텍스트만 추출하세요.

[색 분류]
- 노랑 형광펜 → color "yellow"
- 주황 형광펜 → color "orange"
- 형광펜이 칠해지지 않은 일반 텍스트, 빨간펜 밑줄/취소선/필기는 모두 무시

[읽기 순서]
- 위에서 아래로, 왼쪽에서 오른쪽으로
- 2단(컬럼) 편집이면 왼쪽 단을 끝까지 읽은 뒤 오른쪽 단

[줄 정리 — 중요]
- 하나의 형광펜 강조가 여러 줄에 걸쳐 이어지면 반드시 하나의 항목으로 합치세요
- 줄바꿈으로 쪼개진 단어("바"+"탕" → "바탕")나 문장은 자연스럽게 이어붙여 완성된 한 문장으로 만드세요
- 단, 서로 떨어진 별개의 강조(다른 문장·다른 위치)는 각각 별도 항목으로 유지

[제목 처리]
- 섹션 제목/소제목은 여러 어절·여러 줄이어도 절대 쪼개지 말고 하나의 항목으로
- 같은 제목이 여러 페이지 상단에 반복되면 매번 글자 그대로 동일한 텍스트로 반환

[정확성]
- 보이는 텍스트에 충실하게. 내용을 새로 지어내거나 의미를 바꾸지 말 것
- 이어붙이기 + 띄어쓰기 정리 정도만 허용

응답: {"spans": [{"text": "...", "color": "yellow"}, ...]}
형광펜이 하나도 없으면 {"spans": []}.`;

const SCHEMA = {
  type: "object",
  properties: {
    spans: {
      type: "array",
      items: {
        type: "object",
        properties: {
          text: { type: "string" },
          color: { type: "string", enum: ["yellow", "orange"] },
        },
        required: ["text", "color"],
      },
    },
  },
  required: ["spans"],
};

function json(status, obj) {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function todayKey() {
  return new Date().toISOString().slice(0, 10); // YYYY-MM-DD (UTC)
}

/** KV 카운터 N만큼 증가, 증가 후 값 반환. 2일 TTL로 자동 청소. */
async function bump(kv, key, by) {
  const cur = parseInt((await kv.get(key)) || "0", 10);
  const next = cur + by;
  await kv.put(key, String(next), { expirationTtl: 172800 });
  return next;
}

export default {
  async fetch(request, env) {
    if (request.method !== "POST") {
      return json(405, { error: "POST only" });
    }
    const url = new URL(request.url);
    if (url.pathname !== "/ocr") {
      return json(404, { error: "not found" });
    }

    const deviceId = request.headers.get("X-Device-ID");
    if (!deviceId || deviceId.length < 8) {
      return json(400, { error: "missing X-Device-ID" });
    }

    let body;
    try {
      body = await request.json();
    } catch {
      return json(400, { error: "invalid JSON body" });
    }
    const imageBase64 = body && body.image_base64;
    if (!imageBase64 || typeof imageBase64 !== "string") {
      return json(400, { error: "missing image_base64" });
    }

    // ── 한도 체크 (한 페이지 = 1 카운트)
    const perDevice = parseInt(env.PER_DEVICE_DAILY || "60", 10);
    const globalCap = parseInt(env.GLOBAL_DAILY || "1500", 10);
    const day = todayKey();
    const devKey = `d:${deviceId}:${day}`;
    const gKey = `g:${day}`;

    const devUsed = parseInt((await env.RATE.get(devKey)) || "0", 10);
    if (devUsed >= perDevice) {
      return json(429, { error: "기기 일일 한도 초과", scope: "device", limit: perDevice });
    }
    const gUsed = parseInt((await env.RATE.get(gKey)) || "0", 10);
    if (gUsed >= globalCap) {
      return json(429, { error: "서비스 일일 한도 초과", scope: "global", limit: globalCap });
    }

    // ── Gemini 호출
    // AI Gateway 경유(CF_ACCOUNT_ID + CF_GATEWAY 설정 시): Cloudflare Worker 직접
    // egress가 Gemini 미지원 리전으로 잡히는 "User location not supported" 회피.
    // 미설정이면 직접 호출로 폴백.
    const model = env.MODEL || "gemini-2.5-flash-lite";
    const useGateway =
      env.CF_ACCOUNT_ID &&
      env.CF_GATEWAY &&
      !String(env.CF_ACCOUNT_ID).startsWith("CHANGE");
    const base = useGateway
      ? `https://gateway.ai.cloudflare.com/v1/${env.CF_ACCOUNT_ID}/${env.CF_GATEWAY}/google-ai-studio`
      : `https://generativelanguage.googleapis.com`;
    const endpoint = `${base}/v1beta/models/${model}:generateContent`;
    const geminiBody = {
      contents: [
        {
          parts: [
            { inline_data: { mime_type: "image/jpeg", data: imageBase64 } },
            { text: PROMPT },
          ],
        },
      ],
      generationConfig: {
        responseMimeType: "application/json",
        responseSchema: SCHEMA,
        maxOutputTokens: 2048,
        temperature: 0,
      },
    };

    let geminiResp;
    try {
      geminiResp = await fetch(endpoint, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "x-goog-api-key": env.GEMINI_KEY, // 직접/게이트웨이 모두 헤더로 키 전달
        },
        body: JSON.stringify(geminiBody),
      });
    } catch (e) {
      return json(502, { error: "Gemini 호출 실패: " + e.message });
    }

    if (!geminiResp.ok) {
      const txt = await geminiResp.text();
      return json(geminiResp.status, { error: "Gemini 오류", detail: txt.slice(0, 300) });
    }

    let spans = [];
    try {
      const data = await geminiResp.json();
      const inner = data?.candidates?.[0]?.content?.parts?.[0]?.text;
      const parsed = JSON.parse(inner);
      if (Array.isArray(parsed?.spans)) {
        spans = parsed.spans
          .filter((s) => s && typeof s.text === "string" && s.text.trim() !== "")
          .filter((s) => s.color === "yellow" || s.color === "orange")
          .map((s) => ({ text: s.text.trim(), color: s.color }));
      }
    } catch (e) {
      return json(502, { error: "Gemini 응답 파싱 실패: " + e.message });
    }

    // ── 성공 → 카운터 증가 (한 페이지 처리당 1)
    await bump(env.RATE, devKey, 1);
    await bump(env.RATE, gKey, 1);

    return json(200, { spans });
  },
};
