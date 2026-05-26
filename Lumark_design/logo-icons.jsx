// logo-icons.jsx
// SVG components for the 3 icon directions + wordmark variants.
// All icons are 1024×1024 viewBox so they scale cleanly from app-store size
// down to the 60-point home-screen render.

// ── Shared bits ─────────────────────────────────────────────────────────────

// Brown gradient backing — top a touch lighter than bottom, like light catching
// on warm leather. Each icon has its own gradient ID to avoid SVG def collisions
// when multiple icons live on the same page.
const BrownBg = ({ id }) => (
  <defs>
    <linearGradient id={id} x1="0" x2="0" y1="0" y2="1">
      <stop offset="0%"   stopColor="oklch(0.46 0.062 60)" />
      <stop offset="55%"  stopColor="oklch(0.40 0.058 56)" />
      <stop offset="100%" stopColor="oklch(0.30 0.050 54)" />
    </linearGradient>
    <linearGradient id={`${id}-sheen`} x1="0" x2="1" y1="0" y2="1">
      <stop offset="0%"   stopColor="rgba(255,240,210,.10)" />
      <stop offset="60%"  stopColor="rgba(255,240,210,0)" />
    </linearGradient>
  </defs>
);

// ── A) Monogram L ───────────────────────────────────────────────────────────
// Slim serif L with brass underline + 4 highlighter dots on the baseline.
// The L sits visually centered (its baseline ~0.66 from the top) so the dots
// can hang in the lower band as if they were ink dots on a notebook line.
function IconA() {
  return (
    <svg viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Lumark icon — monogram L">
      <BrownBg id="bg-a" />
      <rect width="1024" height="1024" fill="url(#bg-a)" />
      <rect width="1024" height="1024" fill="url(#bg-a-sheen)" />

      {/* faint horizontal rule like a notebook line */}
      <line x1="220" y1="760" x2="804" y2="760"
            stroke="oklch(0.78 0.10 78)" strokeWidth="2" opacity="0.55" />

      {/* The L. Nanum Myeongjo with a heavy weight reads as solid serif sculpture at icon size. */}
      <text x="512" y="700"
            textAnchor="middle"
            fontFamily="'Nanum Myeongjo','Noto Serif KR',serif"
            fontWeight="800"
            fontSize="640"
            fill="oklch(0.965 0.022 82)"
            letterSpacing="-0.05em">L</text>

      {/* Four highlighter dots, evenly spaced under the rule */}
      <g transform="translate(512 850)">
        <circle cx="-150" cy="0" r="32" fill="var(--hl-yellow, oklch(0.80 0.18 90))" />
        <circle cx="-50"  cy="0" r="32" fill="var(--hl-orange, oklch(0.72 0.18 50))" />
        <circle cx="50"   cy="0" r="32" fill="var(--hl-pink,   oklch(0.70 0.175 0))" />
        <circle cx="150"  cy="0" r="32" fill="var(--hl-blue,   oklch(0.66 0.13 235))" />
      </g>
    </svg>
  );
}

// ── B) Pen tip ──────────────────────────────────────────────────────────────
// A chisel highlighter nib at a confident angle, with four short color
// strokes blooming from the point. Stylised — not a literal pen.
function IconB() {
  // Tip + body geometry, all in a single rotated group so adjusting the angle
  // doesn't drift the strokes' relationship to the nib.
  return (
    <svg viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Lumark icon — pen tip">
      <BrownBg id="bg-b" />
      <rect width="1024" height="1024" fill="url(#bg-b)" />
      <rect width="1024" height="1024" fill="url(#bg-b-sheen)" />

      {/* Four highlighter streaks, fanning from upper-left to lower-right, decreasing length */}
      <g transform="translate(228 540) rotate(-22)" opacity="0.95">
        <rect x="0"  y="0"   width="600" height="42" rx="21" fill="var(--hl-yellow, oklch(0.80 0.18 90))" />
        <rect x="40" y="78"  width="520" height="42" rx="21" fill="var(--hl-orange, oklch(0.72 0.18 50))" />
        <rect x="80" y="156" width="440" height="42" rx="21" fill="var(--hl-pink,   oklch(0.70 0.175 0))" />
        <rect x="120" y="234" width="360" height="42" rx="21" fill="var(--hl-blue,   oklch(0.66 0.13 235))" />
      </g>

      {/* Pen body — a slim ivory shape rising from the upper left, with a chisel tip
          where the strokes begin. The body fades up off-canvas (clipped by viewBox). */}
      <g transform="translate(256 564) rotate(-22)">
        {/* shadow under the pen, soft */}
        <rect x="-46" y="-28" width="92" height="320" rx="14" fill="rgba(0,0,0,.18)" transform="translate(8 6)" />
        {/* body */}
        <rect x="-42" y="-260" width="84" height="280" rx="12"
              fill="oklch(0.94 0.018 82)" />
        {/* ring band near tip (brass) */}
        <rect x="-42" y="-30" width="84" height="14"
              fill="oklch(0.70 0.10 78)" />
        {/* chisel tip — a flat parallelogram angled down-right */}
        <path d="M -42 -16 L 42 -16 L 80 56 L -2 56 Z"
              fill="oklch(0.30 0.04 54)" />
        {/* tip highlight */}
        <path d="M -42 -16 L 42 -16 L 30 -2 L -34 -2 Z"
              fill="rgba(255,255,255,.20)" />
      </g>
    </svg>
  );
}

// ── C) Bookmark ─────────────────────────────────────────────────────────────
// Cream background, leather-brown bookmark ribbon with a V-notch at the
// bottom, stitched inner border, 4 colored dots stacked vertically.
function IconC() {
  return (
    <svg viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Lumark icon — bookmark">
      <defs>
        <linearGradient id="bg-c" x1="0" x2="0" y1="0" y2="1">
          <stop offset="0%"   stopColor="oklch(0.975 0.018 82)" />
          <stop offset="100%" stopColor="oklch(0.940 0.022 80)" />
        </linearGradient>
        <linearGradient id="ribbon-c" x1="0" x2="0" y1="0" y2="1">
          <stop offset="0%"   stopColor="oklch(0.46 0.062 60)" />
          <stop offset="100%" stopColor="oklch(0.34 0.055 55)" />
        </linearGradient>
      </defs>
      <rect width="1024" height="1024" fill="url(#bg-c)" />

      {/* Bookmark ribbon */}
      <path d="M 360 120 L 664 120 L 664 904 L 512 780 L 360 904 Z"
            fill="url(#ribbon-c)" />

      {/* Stitched inner border — only top/sides; stops above the V */}
      <path d="M 396 162 L 628 162 L 628 820"
            fill="none"
            stroke="oklch(0.96 0.018 82)"
            strokeWidth="2.5"
            strokeDasharray="6 8"
            opacity="0.55" />
      <path d="M 396 162 L 396 820"
            fill="none"
            stroke="oklch(0.96 0.018 82)"
            strokeWidth="2.5"
            strokeDasharray="6 8"
            opacity="0.55" />

      {/* 4 colored dots stacked on the ribbon */}
      <circle cx="512" cy="290" r="34" fill="var(--hl-yellow, oklch(0.80 0.18 90))" />
      <circle cx="512" cy="400" r="34" fill="var(--hl-orange, oklch(0.72 0.18 50))" />
      <circle cx="512" cy="510" r="34" fill="var(--hl-pink,   oklch(0.70 0.175 0))" />
      <circle cx="512" cy="620" r="34" fill="var(--hl-blue,   oklch(0.66 0.13 235))" />
    </svg>
  );
}

// ── Icon picker by key ──────────────────────────────────────────────────────
const ICONS = { A: IconA, B: IconB, C: IconC };

const ICON_META = {
  A: { letter: 'A', title: '활자 베이스 — 모노그램 L',
       desc: '가죽 브라운 위에 살짝 세리프가 들어간 L. baseline에 4색 dot, 미세한 황동 underline. 가장 활자적·전통적.' },
  B: { letter: 'B', title: '펜 끝 — 4색 스트로크',
       desc: 'chisel tip에서 4색 형광펜 자국이 짧게 번지는 모습. 가장 도구적·기능 설명적.' },
  C: { letter: 'C', title: '추상 — 책갈피 + 4색 dot',
       desc: 'Cream 위에 갈색 책갈피 띠. 안쪽에 미세한 박음질 점선. 가장 미니멀·조용함.' },
};

// ── Wordmark ────────────────────────────────────────────────────────────────
// Renders "Lumark" with two micro-flourishes: a small dot above the 'm' arch
// and a faint hairline beneath the 'k'. Positions computed visually for
// Nanum Myeongjo 800 at the rendered font-size.
function Wordmark({ tone = 'brown', size = 64, accent = 'brass' }) {
  // Heuristic offsets — eyeballed for Myeongjo 800 weight; tweak if the font swaps.
  // The dot floats above the second arch of 'm' (≈ 60% across word) and
  // the k-flourish underlines the lower-right diagonal of 'k'.
  const dot = {
    width: size * 0.085,
    height: size * 0.085,
    // The 'L u' takes ~38% of word width; the m's second arch sits ~ +20% past that.
    left: `${size * 1.18}px`,
    top:  `-${size * 0.05}px`,
  };
  const kf = {
    width: size * 0.30,
    left: `${size * 2.65}px`,
    bottom: `-${size * 0.10}px`,
    transform: 'rotate(-12deg)',
    transformOrigin: 'left center',
  };

  // Color resolution: solid brown / brass-accented brown / white (on dark)
  const cls = ['wm'];
  if (tone === 'white') cls.push('on-dark', 'solid');
  if (tone === 'solid') cls.push('solid');
  const color = tone === 'white' ? 'var(--cream)' : 'var(--ink)';
  const accentColor = accent === 'brass' ? 'var(--brass)' : 'currentColor';

  return (
    <span className={cls.join(' ')} style={{ fontSize: size, color }}>
      <span className="wm-letters">
        Lumark
        <span className="m-dot" style={{ ...dot, background: accentColor }} />
        <span className="k-flourish" style={{ ...kf, background: accentColor }} />
      </span>
    </span>
  );
}

Object.assign(window, {
  IconA, IconB, IconC, ICONS, ICON_META, Wordmark,
});
