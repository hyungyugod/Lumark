/**
 * Lumark OCR + Quiz Proxy — Cloudflare Worker
 *
 * 목적: Gemini API 키를 클라이언트(iOS 앱)에 노출하지 않고 서버가 대신 호출.
 *       계정 크레딧/전체 일일 한도로 비용 폭주 방지.
 *
 * 라우트:
 *   POST /ocr   { image_base64 }        → { spans: [{text,color}], credits }
 *   POST /quiz  { text, count }         → { cards: [{question,answer}], credits }
 *   둘 다 헤더 Authorization: Bearer <Supabase 사용자 JWT> 필요(로그인).
 *
 * 계정/크레딧: Supabase 사용자 JWT를 /auth/v1/user 로 검증 → userId.
 *   동작 전 spend_credits 로 예약 차감(부족하면 402), Gemini 실패 시 refund_credits.
 *   비용: OCR 1, Quiz 2 (env COST_OCR/COST_QUIZ로 조절).
 *
 * Worker 직접 egress가 Gemini 미지원 리전으로 잡히는 "User location not supported"
 * 회피를 위해 AI Gateway(google-ai-studio) 경유 (CF_ACCOUNT_ID + CF_GATEWAY 설정 시).
 *
 * 바인딩:
 *   KV(RATE)                         — 전역 일일 backstop 카운터
 *   secret GEMINI_KEY                — Gemini API 키
 *   secret SUPABASE_SECRET           — Supabase service_role(sb_secret_...) — RPC 호출용
 *   var    SUPABASE_URL              — 프로젝트 URL
 *   var    SUPABASE_ANON_KEY         — publishable 키(/auth/v1/user 검증용, 공개)
 *   var    MODEL/GLOBAL_DAILY/CF_ACCOUNT_ID/CF_GATEWAY/COST_OCR/COST_QUIZ
 *   선택   secret APP_TOKEN          — 설정 시 X-App-Token 헤더 일치 강제(보조 게이트)
 */

// ── OCR (이미지 → 형광펜 텍스트 + 색)
const OCR_PROMPT = `이 페이지 이미지에서 형광펜으로 강조된 텍스트만 추출하세요.

[색 분류 — 매우 중요]
- 노랑/연두빛 형광펜 → color "yellow"
- 주황/살구빛 형광펜(노랑보다 붉고 진함) → color "orange"
- 노랑과 주황을 반드시 구분할 것. 색이 애매하면 붉은 기가 조금이라도 있으면 "orange"로.
- 보통 주황은 '제목·주제'를, 노랑은 '핵심 내용'을 표시함 — 한 줄짜리 제목처럼 보이는 강조는 orange일 확률이 높음.
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
function quizPrompt(count, kind) {
  if (kind === "ox") {
    return `아래는 학생이 형광펜으로 정리한 학습 노트입니다. 이 내용으로 시험 대비 OX(참/거짓) 퀴즈를 최대 ${count}개 만들어주세요.

규칙:
- 노트에 실제로 있는 내용만 사용. 새로운 사실을 지어내지 말 것.
- question은 참 또는 거짓으로 분명히 판별되는 한 문장의 진술문.
- ox_answer는 그 진술이 참이면 true, 거짓이면 false.
- 참인 진술과 거짓인 진술을 골고루 섞을 것(거짓은 노트 내용을 살짝 바꿔서 만들기).
- answer는 왜 참/거짓인지 한 문장 해설.
- 내용이 적으면 ${count}개보다 적어도 됨. 한국어로.

응답: {"cards": [{"question": "...", "ox_answer": true, "answer": "..."}, ...]}`;
  }
  return `아래는 학생이 형광펜으로 정리한 학습 노트입니다. 이 내용으로 시험 대비 학습용 Q&A 플래시카드를 최대 ${count}개 만들어주세요.

규칙:
- 노트에 실제로 있는 내용만 사용. 새로운 사실을 지어내지 말 것.
- question은 핵심 개념을 묻는 한 문장. answer는 간결하고 정확하게.
- 단순 정의·분류·특징·원인-결과 위주로 좋은 시험 문제를 만들 것.
- 내용이 적으면 ${count}개보다 적어도 됨. 한국어로.

응답: {"cards": [{"question": "...", "answer": "..."}, ...]}`;
}

function quizSchema(kind) {
  const props = {
    question: { type: "string" },
    answer: { type: "string" },
  };
  let required = ["question", "answer"];
  if (kind === "ox") {
    props.ox_answer = { type: "boolean" };
    required = ["question", "ox_answer", "answer"];
  }
  return {
    type: "object",
    properties: {
      cards: {
        type: "array",
        items: { type: "object", properties: props, required },
      },
    },
    required: ["cards"],
  };
}

// ── Summary (정리 텍스트 → AI가 재구조화한 정리본 마크다운)
function summaryPrompt() {
  return `아래는 학생이 형광펜으로 정리한 학습 노트입니다. 이 내용을 시험 공부에 바로 쓸 수 있도록 더 명확한 구조의 마크다운 "정리본"으로 다시 써주세요.

[가장 중요 — 원본 보존]
- 원본의 논리 구조(인과·흐름·조건·의사결정)는 그대로 보존하세요. 메커니즘이 결론보다 핵심입니다. 축약·변형 금지.
- 원본에 있는 예시·수치 계산 과정·비유·풀어 쓴 설명은 생략하지 말고 유지하세요.
- 노트에 실제로 있는 내용만 사용하세요. 새로운 사실·정의·예시를 지어내지 마세요.

[재구조화 방법]
- 관련된 내용을 주제별로 묶고 제목(##)·소제목(###)·글머리표(-)로 위계를 잡으세요.
- 어렵거나 압축된 표현은 의미가 바뀌지 않는 선에서 쉬운 말을 함께 적어주세요(원래 용어는 유지).
- 흐름이 있는 내용은 순서가 드러나게 정리하세요.

[불확실 항목]
- 근거가 불분명하거나 원본만으로 판단하기 어려운 항목은 임의로 고치거나 지우지 말고, 맨 끝에 "## 확인 필요" 섹션으로 따로 모아 적으세요.

[출력 형식]
- 마크다운 본문만. 노트 제목을 최상단 #으로 다시 쓰지 말고 ## 섹션부터 시작하세요.
- 한국어로.

응답: {"summary_markdown": "여기에 마크다운 정리본 전체"}`;
}

function summarySchema() {
  return {
    type: "object",
    properties: { summary_markdown: { type: "string" } },
    required: ["summary_markdown"],
  };
}

// ── 헬퍼

const MAX_JSON_BODY_BYTES = 9_000_000;
const MAX_IMAGE_BASE64_CHARS = 8_000_000; // ~6MB JPEG before base64.
const MAX_QUIZ_TEXT_CHARS = 30_000;

function json(status, obj) {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

async function readJsonCapped(request) {
  const contentLength = Number(request.headers.get("content-length") || "0");
  if (contentLength > MAX_JSON_BODY_BYTES) {
    return { error: json(413, { error: "요청이 너무 커요. 파일을 나눠서 다시 시도해주세요." }) };
  }

  const reader = request.body?.getReader();
  if (!reader) {
    return { error: json(400, { error: "invalid JSON body" }) };
  }

  const chunks = [];
  let received = 0;
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    received += value.byteLength;
    if (received > MAX_JSON_BODY_BYTES) {
      return { error: json(413, { error: "요청이 너무 커요. 파일을 나눠서 다시 시도해주세요." }) };
    }
    chunks.push(value);
  }

  const bytes = new Uint8Array(received);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.byteLength;
  }

  try {
    return { body: JSON.parse(new TextDecoder().decode(bytes)) };
  } catch {
    return { error: json(400, { error: "invalid JSON body" }) };
  }
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

/** 전역 일일 backstop 체크(읽기 전용). 초과면 429 Response, 아니면 null.
 *  카운트 증가는 실제 과금 동작 성공 시 bumpGlobal로만 — 빈 요청 spam으로
 *  전역 한도를 소진(타 사용자 DoS)하지 못하게. */
async function globalCapExceeded(env) {
  const cap = parseInt(env.GLOBAL_DAILY || "0", 10);
  if (!cap) return null;
  const used = parseInt((await env.RATE.get(`g:${todayKey()}`)) || "0", 10);
  if (used >= cap) {
    return json(429, { error: "오늘 무료 사용량이 모두 찼어요. 내일 다시 충전돼요. (설정에서 '내 API 키'를 넣으면 지금 바로 쓸 수 있어요.)" });
  }
  return null;
}

/** 과금 동작 1건 카운트(크레딧 차감 성공 후 호출). 증가 후 누적값 반환(없으면 null). */
async function bumpGlobal(env) {
  if (!parseInt(env.GLOBAL_DAILY || "0", 10)) return null;
  return await bump(env.RATE, `g:${todayKey()}`, 1);
}

/** 응답에 실어 보낼 전역 사용량 정보(남은 양 + 한도). GLOBAL_DAILY 미설정이면 빈 객체. */
function globalInfo(env, used) {
  const cap = parseInt(env.GLOBAL_DAILY || "0", 10);
  if (!cap || used == null) return {};
  return { global_remaining: Math.max(0, cap - used), global_cap: cap };
}

// ── 계정 + 크레딧 (Supabase) ────────────────────────────────

/** 동작별 크레딧 비용. env로 덮어쓰기 가능. */
function costOf(env, kind) {
  if (kind === "ocr") return parseInt(env.COST_OCR || "1", 10);
  if (kind === "summary") return parseInt(env.COST_SUMMARY || "5", 10);
  return parseInt(env.COST_QUIZ || "2", 10);
}

/** Bearer JWT 검증 — Supabase /auth/v1/user 로 확인(서명 알고리즘 무관, 항상 정확).
 *  유효하면 {userId}, 아니면 {error: Response}. */
async function authUser(env, request) {
  const authz = request.headers.get("Authorization") || "";
  const token = authz.startsWith("Bearer ") ? authz.slice(7).trim() : "";
  if (!token) return { error: json(401, { error: "로그인이 필요해요." }) };

  const resp = await fetch(`${env.SUPABASE_URL}/auth/v1/user`, {
    headers: { apikey: env.SUPABASE_ANON_KEY, Authorization: `Bearer ${token}` },
  });
  if (!resp.ok) {
    return { error: json(401, { error: "로그인이 만료됐어요. 다시 로그인해주세요." }) };
  }
  const user = await resp.json().catch(() => null);
  if (!user || !user.id) return { error: json(401, { error: "유효하지 않은 사용자." }) };
  return { userId: user.id };
}

/** PostgREST RPC 호출 (service_role = secret key). 반환 스칼라를 그대로. */
async function rpc(env, fn, args) {
  const resp = await fetch(`${env.SUPABASE_URL}/rest/v1/rpc/${fn}`, {
    method: "POST",
    headers: {
      apikey: env.SUPABASE_SECRET,
      Authorization: `Bearer ${env.SUPABASE_SECRET}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(args),
  });
  if (!resp.ok) {
    const t = await resp.text();
    throw new Error(`rpc ${fn} ${resp.status}: ${t.slice(0, 200)}`);
  }
  return resp.json();
}

/** 월충전(있으면) 후 예약 차감. 새 잔액 반환, 부족하면 -1. */
async function spendCredits(env, userId, amount, reason, ref) {
  try { await rpc(env, "refill_if_due", { p_user: userId }); } catch (_) { /* 충전 실패는 무시 */ }
  return await rpc(env, "spend_credits", {
    p_user: userId, p_amount: amount, p_reason: reason, p_ref: ref || null,
  });
}

/** Gemini 실패 시 예약분 환불(best-effort). */
async function refundCredits(env, userId, amount, ref) {
  try { await rpc(env, "refund_credits", { p_user: userId, p_amount: amount, p_ref: ref || null }); }
  catch (_) { /* 환불 실패는 로그만(여기선 무시) */ }
}

/** Gemini generateContent 호출 (AI Gateway 경유 가능). inner JSON 문자열을 파싱해 반환. */
async function callGemini(env, parts, schema, maxOutputTokens, model = env.MODEL || "gemini-2.5-flash-lite") {
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
    console.warn("Gemini request failed", resp.status, txt.slice(0, 300));
    return { error: json(resp.status === 429 ? 429 : 502, { error: "AI 처리에 실패했어요. 잠시 후 다시 시도해주세요." }) };
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

async function handleOCR(env, userId, body) {
  const imageBase64 = body && body.image_base64;
  if (!imageBase64 || typeof imageBase64 !== "string") {
    return json(400, { error: "missing image_base64" });
  }
  if (imageBase64.length > MAX_IMAGE_BASE64_CHARS) {
    return json(413, { error: "이미지가 너무 커요. 페이지를 낮은 해상도로 다시 보내주세요." });
  }

  // 예약 차감(부족하면 402, Gemini 호출 안 함).
  const cost = costOf(env, "ocr");
  let balance;
  try { balance = await spendCredits(env, userId, cost, "ocr", null); }
  catch (e) { console.log("spend ocr failed:", e.message); return json(502, { error: "크레딧 처리에 문제가 생겼어요. 잠시 후 다시 시도해주세요." }); }
  if (balance === -1) {
    return json(402, { error: "크레딧이 부족해요. 내일 충전되거나, 설정에서 내 Gemini 키로 쓸 수 있어요.", needed: cost });
  }
  const parts = [
    { inline_data: { mime_type: "image/jpeg", data: imageBase64 } },
    { text: OCR_PROMPT },
  ];
  const res = await callGemini(env, parts, OCR_SCHEMA, 4096);
  if (res.error) { await refundCredits(env, userId, cost, "ocr"); return res.error; }
  const used = await bumpGlobal(env);   // AI 처리 성공 후 전역 사용량 1건 카운트(+ 누적값)

  let spans = [];
  if (Array.isArray(res.parsed?.spans)) {
    spans = res.parsed.spans
      .filter((s) => s && typeof s.text === "string" && s.text.trim() !== "")
      .filter((s) => s.color === "yellow" || s.color === "orange")
      .map((s) => ({ text: s.text.trim(), color: s.color }));
  }
  return json(200, { spans, credits: balance, ...globalInfo(env, used) });
}

async function handleQuiz(env, userId, body) {
  const text = body && body.text;
  if (!text || typeof text !== "string" || text.trim() === "") {
    return json(400, { error: "missing text" });
  }
  if (text.length > MAX_QUIZ_TEXT_CHARS) {
    return json(413, { error: "퀴즈로 만들 텍스트가 너무 길어요. 정리본을 나눠서 시도해주세요." });
  }
  const count = Math.min(Math.max(parseInt(body.count || "10", 10) || 10, 1), 30);
  const kind = body.kind === "ox" ? "ox" : "qa";

  const cost = costOf(env, "quiz");
  let balance;
  try { balance = await spendCredits(env, userId, cost, "quiz", null); }
  catch (e) { console.log("spend quiz failed:", e.message); return json(502, { error: "크레딧 처리에 문제가 생겼어요. 잠시 후 다시 시도해주세요." }); }
  if (balance === -1) {
    return json(402, { error: "크레딧이 부족해요. 내일 충전되거나, 설정에서 내 Gemini 키로 쓸 수 있어요.", needed: cost });
  }
  const parts = [{ text: quizPrompt(count, kind) + "\n\n---\n\n" + text }];
  const res = await callGemini(env, parts, quizSchema(kind), 4096);
  if (res.error) { await refundCredits(env, userId, cost, "quiz"); return res.error; }
  const used = await bumpGlobal(env);   // AI 처리 성공 후 전역 사용량 1건 카운트(+ 누적값)

  let cards = [];
  if (Array.isArray(res.parsed?.cards)) {
    cards = res.parsed.cards
      .filter((c) => c && typeof c.question === "string" && typeof c.answer === "string")
      .map((c) => {
        const card = { question: c.question.trim(), answer: c.answer.trim() };
        if (kind === "ox" && typeof c.ox_answer === "boolean") card.ox_answer = c.ox_answer;
        return card;
      })
      .filter((c) => c.question !== "" && c.answer !== "");
  }
  return json(200, { cards, credits: balance, ...globalInfo(env, used) });
}

async function handleSummary(env, userId, body) {
  const text = body && body.text;
  if (!text || typeof text !== "string" || text.trim() === "") {
    return json(400, { error: "missing text" });
  }
  if (text.length > MAX_QUIZ_TEXT_CHARS) {
    return json(413, { error: "정리할 텍스트가 너무 길어요. 노트를 나눠서 시도해주세요." });
  }

  const cost = costOf(env, "summary");
  let balance;
  try { balance = await spendCredits(env, userId, cost, "summary", null); }
  catch (e) { console.log("spend summary failed:", e.message); return json(502, { error: "크레딧 처리에 문제가 생겼어요. 잠시 후 다시 시도해주세요." }); }
  if (balance === -1) {
    return json(402, { error: "크레딧이 부족해요. 내일 충전되거나, 설정에서 내 Gemini 키로 쓸 수 있어요.", needed: cost });
  }
  const parts = [{ text: summaryPrompt() + "\n\n---\n\n" + text }];
  // 정리본은 출력이 길어 8192. 모델은 env.MODEL_SUMMARY(없으면 기본값).
  const res = await callGemini(env, parts, summarySchema(), 8192, env.MODEL_SUMMARY);
  if (res.error) { await refundCredits(env, userId, cost, "summary"); return res.error; }

  const markdown = typeof res.parsed?.summary_markdown === "string" ? res.parsed.summary_markdown.trim() : "";
  if (markdown === "") {
    await refundCredits(env, userId, cost, "summary");   // 빈 결과 = 과금 안 함
    return json(502, { error: "AI 정리본을 만들지 못했어요. 잠시 후 다시 시도해주세요." });
  }
  const used = await bumpGlobal(env);   // AI 처리 성공 후 전역 사용량 1건 카운트(+ 누적값)
  return json(200, { summary_markdown: markdown, credits: balance, ...globalInfo(env, used) });
}

// ── 진입점

export default {
  // ── Cron: Supabase 무료 플랜 keepalive ──────────────────────────────
  // 무료 프로젝트는 7일간 요청이 전혀 없으면 자동 일시정지됨. wrangler.toml의 스케줄
  // (매주 월 21:00 KST)에 맞춰 profiles에 가벼운 SELECT 1건을 날려 DB를 깨워 둔다.
  // service_role 키라 RLS 우회 → 실제 행 1건을 읽어 확실한 DB 활동으로 기록됨.
  async scheduled(event, env, _ctx) {
    try {
      const resp = await fetch(
        `${env.SUPABASE_URL}/rest/v1/profiles?select=id&limit=1`,
        { headers: { apikey: env.SUPABASE_SECRET, Authorization: `Bearer ${env.SUPABASE_SECRET}` } },
      );
      console.log("supabase keepalive", event.cron, resp.status);
    } catch (e) {
      console.log("supabase keepalive failed:", e && e.message);
    }
  },

  async fetch(request, env) {
    if (request.method !== "POST") return json(405, { error: "POST only" });

    const url = new URL(request.url);
    const route = url.pathname;
    if (route !== "/ocr" && route !== "/quiz" && route !== "/summary" && route !== "/usage") {
      return json(404, { error: "not found" });
    }

    // (선택) 앱 토큰 게이트. APP_TOKEN이 설정돼 있을 때만 강제.
    if (env.APP_TOKEN && request.headers.get("X-App-Token") !== env.APP_TOKEN) {
      return json(401, { error: "unauthorized" });
    }

    const contentLength = Number(request.headers.get("content-length") || "0");
    if (contentLength > MAX_JSON_BODY_BYTES) {
      return json(413, { error: "요청이 너무 커요. 파일을 나눠서 다시 시도해주세요." });
    }

    // 로그인 사용자 검증 (Supabase JWT). 크레딧은 이 userId에 묶임.
    const auth = await authUser(env, request);
    if (auth.error) return auth.error;

    // 사용량 조회 라우트 — 카운트 증가 없이 전역 남은 양만 반환(앱 새로고침용).
    if (route === "/usage") {
      const gcap = parseInt(env.GLOBAL_DAILY || "0", 10);
      const gused = parseInt((await env.RATE.get(`g:${todayKey()}`)) || "0", 10);
      return json(200, { global_remaining: Math.max(0, gcap - gused), global_cap: gcap });
    }

    // 전역 일일 backstop(안전망). 읽기 전용 — 실제 카운트는 차감 성공 후.
    const cap = await globalCapExceeded(env);
    if (cap) return cap;

    const parsed = await readJsonCapped(request);
    if (parsed.error) return parsed.error;
    const body = parsed.body;

    if (route === "/ocr") return handleOCR(env, auth.userId, body);
    if (route === "/summary") return handleSummary(env, auth.userId, body);
    return handleQuiz(env, auth.userId, body);
  },
};
