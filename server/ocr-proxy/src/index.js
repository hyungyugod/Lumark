/**
 * Lumark OCR + Quiz Proxy — Cloudflare Worker
 *
 * 목적: Gemini API 키를 클라이언트(iOS 앱)에 노출하지 않고 서버가 대신 호출.
 *       기기당/전체 일일 한도로 비용 폭주 방지.
 *
 * 라우트:
 *   POST /ocr   { image_base64 }        → { spans: [{text,color}] }
 *   POST /quiz  { text, count }         → { cards: [{question,answer}] }
 *   둘 다 헤더 X-Device-ID 필요.
 *
 * Worker 직접 egress가 Gemini 미지원 리전으로 잡히는 "User location not supported"
 * 회피를 위해 AI Gateway(google-ai-studio) 경유 (CF_ACCOUNT_ID + CF_GATEWAY 설정 시).
 *
 * 바인딩: KV(RATE), secret(GEMINI_KEY), vars(MODEL/PER_DEVICE_DAILY/GLOBAL_DAILY/
 *         CF_ACCOUNT_ID/CF_GATEWAY)
 *         선택: secret(APP_TOKEN) — 설정 시 X-App-Token 헤더 일치 강제(앱 전용 게이트).
 */

// ── OCR (이미지 → 형광펜 텍스트 + 색)
const OCR_PROMPT = `이 페이지 이미지에서 형광펜으로 강조된 텍스트만 추출하세요.

[색 분류]
- 노랑 형광펜 → color "yellow"
- 주황 형광펜 → color "orange"
- 형광펜이 칠해지지 않은 일반 텍스트, 빨간펜 밑줄/취소선/필기는 모두 무시

[읽기 순서]
- 위에서 아래로, 왼쪽에서 오른쪽으로
- 2단(컬럼) 편집이면 왼쪽 단을 끝까지 읽은 뒤 오른쪽 단

[줄 정리 — 중요]
- 하나의 형광펜 강조가 여러 줄에 걸쳐 이어지면 반드시 하나의 항목으로 합치세요
- 줄바꿈으로 쪼개진 단어("바"+"탕" → "바탕")나 문장은 자연스럽게 이어붙여 완성된 한 문장으로
- 단, 서로 떨어진 별개의 강조는 각각 별도 항목으로 유지

[제목 처리]
- 섹션 제목/소제목은 여러 어절·여러 줄이어도 쪼개지 말고 하나의 항목으로
- 같은 제목이 여러 페이지 상단에 반복되면 매번 동일한 텍스트로 반환

[정확성]
- 보이는 텍스트에 충실하게. 내용을 새로 지어내거나 의미를 바꾸지 말 것

응답: {"spans": [{"text": "...", "color": "yellow"}, ...]}
형광펜이 하나도 없으면 {"spans": []}.`;

const OCR_SCHEMA = {
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

// ── Quiz (정리 텍스트 → Q&A 카드)
function quizPrompt(count) {
  return `아래는 학생이 형광펜으로 정리한 학습 노트입니다. 이 내용으로 시험 대비 학습용 Q&A 플래시카드를 최대 ${count}개 만들어주세요.

규칙:
- 노트에 실제로 있는 내용만 사용. 새로운 사실을 지어내지 말 것.
- question은 핵심 개념을 묻는 한 문장. answer는 간결하고 정확하게.
- 단순 정의·분류·특징·원인-결과 위주로 좋은 시험 문제를 만들 것.
- 내용이 적으면 ${count}개보다 적어도 됨. 한국어로.

응답: {"cards": [{"question": "...", "answer": "..."}, ...]}`;
}

const QUIZ_SCHEMA = {
  type: "object",
  properties: {
    cards: {
      type: "array",
      items: {
        type: "object",
        properties: {
          question: { type: "string" },
          answer: { type: "string" },
        },
        required: ["question", "answer"],
      },
    },
  },
  required: ["cards"],
};

// ── 헬퍼

function json(status, obj) {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function todayKey() {
  return new Date().toISOString().slice(0, 10);
}

async function bump(kv, key, by) {
  const cur = parseInt((await kv.get(key)) || "0", 10);
  const next = cur + by;
  await kv.put(key, String(next), { expirationTtl: 172800 });
  return next;
}

/** 한도 체크. 초과면 429 Response, 통과면 {devKey,gKey} 반환. */
async function checkLimits(env, deviceId) {
  const perDevice = parseInt(env.PER_DEVICE_DAILY || "60", 10);
  const globalCap = parseInt(env.GLOBAL_DAILY || "1500", 10);
  const day = todayKey();
  const devKey = `d:${deviceId}:${day}`;
  const gKey = `g:${day}`;

  const devUsed = parseInt((await env.RATE.get(devKey)) || "0", 10);
  if (devUsed >= perDevice) {
    return { limited: json(429, { error: "기기 일일 한도 초과", scope: "device", limit: perDevice }) };
  }
  const gUsed = parseInt((await env.RATE.get(gKey)) || "0", 10);
  if (gUsed >= globalCap) {
    return { limited: json(429, { error: "서비스 일일 한도 초과", scope: "global", limit: globalCap }) };
  }
  return { devKey, gKey };
}

/** Gemini generateContent 호출 (AI Gateway 경유 가능). inner JSON 문자열을 파싱해 반환. */
async function callGemini(env, parts, schema, maxOutputTokens) {
  const model = env.MODEL || "gemini-2.5-flash-lite";
  const useGateway =
    env.CF_ACCOUNT_ID && env.CF_GATEWAY && !String(env.CF_ACCOUNT_ID).startsWith("CHANGE");
  const base = useGateway
    ? `https://gateway.ai.cloudflare.com/v1/${env.CF_ACCOUNT_ID}/${env.CF_GATEWAY}/google-ai-studio`
    : `https://generativelanguage.googleapis.com`;
  const endpoint = `${base}/v1beta/models/${model}:generateContent`;

  const resp = await fetch(endpoint, {
    method: "POST",
    headers: { "Content-Type": "application/json", "x-goog-api-key": env.GEMINI_KEY },
    body: JSON.stringify({
      contents: [{ parts }],
      generationConfig: {
        responseMimeType: "application/json",
        responseSchema: schema,
        maxOutputTokens,
        temperature: 0,
      },
    }),
  });

  if (!resp.ok) {
    const txt = await resp.text();
    return { error: json(resp.status, { error: "Gemini 오류", detail: txt.slice(0, 300) }) };
  }
  try {
    const data = await resp.json();
    const inner = data?.candidates?.[0]?.content?.parts?.[0]?.text;
    return { parsed: JSON.parse(inner) };
  } catch (e) {
    return { error: json(502, { error: "Gemini 응답 파싱 실패: " + e.message }) };
  }
}

// ── 라우트 핸들러

async function handleOCR(env, deviceId, body) {
  const imageBase64 = body && body.image_base64;
  if (!imageBase64 || typeof imageBase64 !== "string") {
    return json(400, { error: "missing image_base64" });
  }
  const lim = await checkLimits(env, deviceId);
  if (lim.limited) return lim.limited;

  const parts = [
    { inline_data: { mime_type: "image/jpeg", data: imageBase64 } },
    { text: OCR_PROMPT },
  ];
  const res = await callGemini(env, parts, OCR_SCHEMA, 2048);
  if (res.error) return res.error;

  let spans = [];
  if (Array.isArray(res.parsed?.spans)) {
    spans = res.parsed.spans
      .filter((s) => s && typeof s.text === "string" && s.text.trim() !== "")
      .filter((s) => s.color === "yellow" || s.color === "orange")
      .map((s) => ({ text: s.text.trim(), color: s.color }));
  }
  await bump(env.RATE, lim.devKey, 1);
  await bump(env.RATE, lim.gKey, 1);
  return json(200, { spans });
}

async function handleQuiz(env, deviceId, body) {
  const text = body && body.text;
  if (!text || typeof text !== "string" || text.trim() === "") {
    return json(400, { error: "missing text" });
  }
  const count = Math.min(Math.max(parseInt(body.count || "10", 10) || 10, 1), 30);
  const lim = await checkLimits(env, deviceId);
  if (lim.limited) return lim.limited;

  const parts = [{ text: quizPrompt(count) + "\n\n---\n\n" + text }];
  const res = await callGemini(env, parts, QUIZ_SCHEMA, 4096);
  if (res.error) return res.error;

  let cards = [];
  if (Array.isArray(res.parsed?.cards)) {
    cards = res.parsed.cards
      .filter((c) => c && typeof c.question === "string" && typeof c.answer === "string")
      .map((c) => ({ question: c.question.trim(), answer: c.answer.trim() }))
      .filter((c) => c.question !== "" && c.answer !== "");
  }
  await bump(env.RATE, lim.devKey, 1);
  await bump(env.RATE, lim.gKey, 1);
  return json(200, { cards });
}

// ── 진입점

export default {
  async fetch(request, env) {
    if (request.method !== "POST") return json(405, { error: "POST only" });

    const url = new URL(request.url);
    const route = url.pathname;
    if (route !== "/ocr" && route !== "/quiz") {
      return json(404, { error: "not found" });
    }

    // 선택적 앱 토큰 게이트. APP_TOKEN secret이 설정돼 있을 때만 강제(없으면 하위호환).
    // 공개 workers.dev URL이 알려져도 무차별 호출로 일일 한도를 태우는 걸 막는 1차 방어.
    if (env.APP_TOKEN && request.headers.get("X-App-Token") !== env.APP_TOKEN) {
      return json(401, { error: "unauthorized" });
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

    if (route === "/ocr") return handleOCR(env, deviceId, body);
    return handleQuiz(env, deviceId, body);
  },
};
