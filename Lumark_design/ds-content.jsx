// ds-content.jsx
// Content sections for the Lumark Design System page.
// Each section is a stateless component; the parent App owns theme/tweak state.

// ── Inline SVG icons (placeholder set — replace with SF Symbols in SwiftUI) ──
const Icon = {
  Chevron: (p) => (
    <svg viewBox="0 0 20 20" width="14" height="14" {...p}>
      <path d="M7 4l6 6-6 6" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round"/>
    </svg>
  ),
  Back: (p) => (
    <svg viewBox="0 0 20 20" width="18" height="18" {...p}>
      <path d="M12 4L6 10l6 6" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round"/>
    </svg>
  ),
  More: (p) => (
    <svg viewBox="0 0 20 20" width="18" height="18" {...p}>
      <circle cx="4" cy="10" r="1.4" fill="currentColor"/>
      <circle cx="10" cy="10" r="1.4" fill="currentColor"/>
      <circle cx="16" cy="10" r="1.4" fill="currentColor"/>
    </svg>
  ),
  Copy: (p) => (
    <svg viewBox="0 0 20 20" {...p}>
      <rect x="3.5" y="5.5" width="10" height="11" rx="2" fill="none" stroke="currentColor" strokeWidth="1.4"/>
      <path d="M6.5 5.5V4.2a1.7 1.7 0 0 1 1.7-1.7H15a1.5 1.5 0 0 1 1.5 1.5v9a1.5 1.5 0 0 1-1.5 1.5h-1.5" fill="none" stroke="currentColor" strokeWidth="1.4"/>
    </svg>
  ),
  Share: (p) => (
    <svg viewBox="0 0 20 20" {...p}>
      <path d="M10 13V3M7 6l3-3 3 3" fill="none" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round" strokeLinejoin="round"/>
      <path d="M4 11v4.5A1.5 1.5 0 0 0 5.5 17h9a1.5 1.5 0 0 0 1.5-1.5V11" fill="none" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round"/>
    </svg>
  ),
  PDF: (p) => (
    <svg viewBox="0 0 20 20" {...p}>
      <path d="M5 2.5h7L16 6v11.5A1 1 0 0 1 15 18.5H5A1 1 0 0 1 4 17.5v-14A1 1 0 0 1 5 2.5z" fill="none" stroke="currentColor" strokeWidth="1.4" strokeLinejoin="round"/>
      <path d="M12 2.5V6h4" fill="none" stroke="currentColor" strokeWidth="1.4" strokeLinejoin="round"/>
      <text x="10" y="14.5" textAnchor="middle" fontSize="4.2" fontWeight="700" fill="currentColor" fontFamily="ui-sans-serif">PDF</text>
    </svg>
  ),
  Book: (p) => (
    <svg viewBox="0 0 80 80" width="80" height="80" {...p}>
      <path d="M14 18c8-3 18-3 26 2v44c-8-5-18-5-26-2V18z" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinejoin="round"/>
      <path d="M66 18c-8-3-18-3-26 2v44c8-5 18-5 26-2V18z" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinejoin="round"/>
      <path d="M48 28l9 4-3 18-9-4z" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinejoin="round"/>
    </svg>
  ),
};

// ── 1) Overview ─────────────────────────────────────────────────────────────
function OverviewSection() {
  return (
    <section className="s" id="overview">
      <div className="s-head">
        <span className="num">00</span>
        <h2 className="h1">개요 · Overview</h2>
      </div>
      <p className="lede" style={{ maxWidth: 680 }}>
        Lumark는 굿노트 PDF에 그은 4색 형광펜을 자동 인식해 마크다운 노트로 변환하는 iOS 학습 도구입니다.
        콘텐츠가 이미 채도 높은 형광펜 색을 갖고 있기 때문에, UI 크롬은 콘텐츠와 싸우지 않도록 차분합니다.
      </p>
      <div className="g-3" style={{ marginTop: 24 }}>
        <div className="tile">
          <div className="eyebrow">Mood</div>
          <div style={{ fontFamily: 'var(--font-display)', fontSize: 19, lineHeight: 1.35, color: 'var(--ink)' }}>
            책상 위에 놓인<br/>가죽 노트 + 만년필 잉크
          </div>
          <div className="caption">iA Writer · Bear · Things 3의 절제된 미감</div>
        </div>
        <div className="tile">
          <div className="eyebrow">Voice</div>
          <div style={{ fontFamily: 'var(--font-display)', fontSize: 19, lineHeight: 1.35, color: 'var(--ink)' }}>
            한국 출판물의<br/>정갈한 활자 감각
          </div>
          <div className="caption">Pretendard / Noto Sans KR + 명조 강조</div>
        </div>
        <div className="tile">
          <div className="eyebrow">Principle</div>
          <div style={{ fontFamily: 'var(--font-display)', fontSize: 19, lineHeight: 1.35, color: 'var(--ink)' }}>
            너무 빈티지하면 촌스럽고,<br/>너무 미니멀하면 차갑다
          </div>
          <div className="caption">그 사이의 따뜻한 모더니즘</div>
        </div>
      </div>
    </section>
  );
}

// ── 2) Colors ───────────────────────────────────────────────────────────────
const COLOR_TILES = [
  { name: 'Primary Brown', vr: '--brown', desc: '메인 액션·헤더·강조' },
  { name: 'Background Cream', vr: '--cream', desc: '메인 배경 (종이)' },
  { name: 'Surface', vr: '--surface', desc: '카드·시트 배경' },
  { name: 'Ink', vr: '--ink', desc: '본문 글자 (다크 에스프레소)' },
  { name: 'Subtle', vr: '--subtle', desc: '보조 텍스트·아이콘' },
  { name: 'Divider', vr: '--divider', desc: '거의 안 보이는 구분선' },
  { name: 'Brass', vr: '--brass', desc: '미세한 황동 액센트' },
];

function ColorsSection() {
  return (
    <section className="s" id="colors">
      <div className="s-head">
        <span className="num">01</span>
        <h2 className="h1">컬러 팔레트 · Palette</h2>
      </div>
      <p className="s-desc">
        Light / Dark 동일한 토큰 이름으로 작동합니다. SwiftUI에서는 <span className="mono">Color(.brown)</span>·<span className="mono">Color(.cream)</span> 등으로 매핑하세요.
      </p>
      <div className="g-3 tiles">
        {COLOR_TILES.map((c) => (
          <div className="tile" key={c.name}>
            <div className="swatch" style={{ background: `var(${c.vr})` }} />
            <div className="vals">
              <div className="label">{c.name}</div>
              <div className="caption">{c.desc}</div>
            </div>
            <div className="meta">
              <span className="var">{c.vr}</span>
              <span className="hex" data-cssvar={c.vr}>—</span>
            </div>
          </div>
        ))}
      </div>
    </section>
  );
}

// ── 3) Highlighter colors (the 4) ───────────────────────────────────────────
const HL = [
  { key: 'yellow', name: '노랑', tag: '핵심', vr: '--hl-yellow', bg: '--hl-yellow-bg', edge: '--hl-yellow-edge' },
  { key: 'orange', name: '주황', tag: '주제', vr: '--hl-orange', bg: '--hl-orange-bg', edge: '--hl-orange-edge' },
  { key: 'pink',   name: '분홍', tag: '보충', vr: '--hl-pink',   bg: '--hl-pink-bg',   edge: '--hl-pink-edge' },
  { key: 'blue',   name: '파랑', tag: '참고', vr: '--hl-blue',   bg: '--hl-blue-bg',   edge: '--hl-blue-edge' },
];

function HighlightersSection() {
  return (
    <section className="s" id="highlighters">
      <div className="s-head">
        <span className="num">02</span>
        <h2 className="h1">형광펜 4색 · Highlighters</h2>
      </div>
      <p className="s-desc">
        콘텐츠 색입니다. 채도만 살짝 정돈하고 의미는 그대로. 칩·dot·본문 좌측 컬러 바·필터에 동일 토큰을 재사용합니다.
      </p>

      <div className="g-4 tiles">
        {HL.map((h) => (
          <div className="tile" key={h.key} style={{ background: `var(${h.bg})`, borderColor: `var(${h.edge})` }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
              <span style={{ width: 22, height: 22, borderRadius: 999, background: `var(${h.vr})`, boxShadow: '0 0 0 3px color-mix(in oklab, var('+h.vr+') 22%, transparent)' }} />
              <div>
                <div className="label">{h.name}</div>
                <div className="caption" style={{ color: 'var(--ink-2)' }}>{h.tag}</div>
              </div>
            </div>
            <div className="meta" style={{ marginTop: 8 }}>
              <span className="var">{h.vr}</span>
            </div>
            <div className="caption" style={{ color: 'var(--ink-2)' }}>
              <span style={{ background: `var(${h.bg})`, padding: '1px 4px', borderRadius: 3, border: `1px solid var(${h.edge})` }}>bg</span>{' '}
              <span style={{ borderLeft: `2px solid var(${h.vr})`, paddingLeft: 6 }}>좌측 바</span>
            </div>
          </div>
        ))}
      </div>

      <div style={{ marginTop: 24 }}>
        <div className="eyebrow" style={{ marginBottom: 8 }}>Usage · 토글 칩</div>
        <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
          {HL.map((h, i) => (
            <button
              key={h.key}
              className={i < 2 ? 'chip on' : 'chip'}
              style={{ '--c': `var(${h.vr})`, '--c-bg': `var(${h.bg})`, '--c-edge': `var(${h.edge})` }}
            >
              <span className="dot" />
              {h.name} ({h.tag})
            </button>
          ))}
        </div>
      </div>
    </section>
  );
}

// ── 4) Typography ───────────────────────────────────────────────────────────
const TYPE_ROWS = [
  { role: 'Display',   sample: '형광펜만 그으면', spec: 'Nanum Myeongjo 800 / 44 / 51 / -2%', cls: 'display' },
  { role: 'H1',        sample: '항생제정리',     spec: 'Nanum Myeongjo 800 / 30 / 36 / -1.5%', cls: 'h1' },
  { role: 'H2',        sample: '항생제의 분류',   spec: 'Nanum Myeongjo 700 / 22 / 28 / -1%', cls: 'h2' },
  { role: 'Body',      sample: '베타락탐계는 세포벽 합성을 억제합니다. 페니실린 알레르기 환자 주의.', spec: 'Noto Sans KR 400 / 15 / 25 / -0.5%', cls: 'body' },
  { role: 'Caption',   sample: '2025년 5월 26일 · 4페이지',   spec: 'Noto Sans KR 400 / 12 / 18 / +2%', cls: 'caption' },
  { role: 'Mono',      sample: 'Color(brown).opacity(0.92)', spec: 'JetBrains Mono 400 / 12.5 / 18', cls: 'mono' },
];

function TypographySection() {
  return (
    <section className="s" id="typography">
      <div className="s-head">
        <span className="num">03</span>
        <h2 className="h1">타이포그래피 · Typography</h2>
      </div>
      <p className="s-desc">
        본문은 <b>Noto Sans KR</b>, 강조·타이틀은 <b>Nanum Myeongjo</b>. 한글 가독성 우선 — line-height 넉넉히, letter-spacing 살짝 마이너스.
      </p>
      <div>
        {TYPE_ROWS.map((r) => (
          <div className="type-row" key={r.role}>
            <div className="role">{r.role}</div>
            <div className={r.cls}>{r.sample}</div>
            <div className="spec">{r.spec}</div>
          </div>
        ))}
      </div>
    </section>
  );
}

// ── 5) Spacing ──────────────────────────────────────────────────────────────
const SP = [
  { name: 'sp-1', vr: '--sp-1', v: 4 },
  { name: 'sp-2', vr: '--sp-2', v: 8 },
  { name: 'sp-3', vr: '--sp-3', v: 12 },
  { name: 'sp-4', vr: '--sp-4', v: 16 },
  { name: 'sp-5', vr: '--sp-5', v: 24 },
  { name: 'sp-6', vr: '--sp-6', v: 32 },
  { name: 'sp-7', vr: '--sp-7', v: 48 },
];

function SpacingSection({ baseSp }) {
  return (
    <section className="s" id="spacing">
      <div className="s-head">
        <span className="num">04</span>
        <h2 className="h1">간격 · Spacing</h2>
      </div>
      <p className="s-desc">4의 배수 스케일. <span className="mono">--sp-4 = 16px</span>을 본문 기본 간격으로 사용합니다.</p>
      <div>
        {SP.map((s) => {
          const w = Math.round(s.v * (baseSp / 16) / 48 * 100);
          return (
            <div className="sp-row" key={s.name}>
              <span className="name">{s.name}</span>
              <div className="bar" style={{ width: `${Math.max(4, w)}%` }} />
              <span className="val">{Math.round(s.v * (baseSp / 16))}px</span>
            </div>
          );
        })}
      </div>
    </section>
  );
}

// ── 6) Radius ───────────────────────────────────────────────────────────────
function RadiusSection({ rSm, rMd, rLg }) {
  return (
    <section className="s" id="radius">
      <div className="s-head">
        <span className="num">05</span>
        <h2 className="h1">모서리 · Radius</h2>
      </div>
      <p className="s-desc">살짝 부드럽지만 너무 둥글지 않게. 칩만 999(pill)을 사용합니다.</p>
      <div className="radius-row">
        <div>
          <div className="r-box" style={{ borderRadius: rSm }} />
          <span className="caption"><span className="mono">--r-sm</span> · {rSm}px</span>
          <span className="caption">버튼, 인풋</span>
        </div>
        <div>
          <div className="r-box" style={{ borderRadius: rMd }} />
          <span className="caption"><span className="mono">--r-md</span> · {rMd}px</span>
          <span className="caption">카드, 시트</span>
        </div>
        <div>
          <div className="r-box" style={{ borderRadius: rLg }} />
          <span className="caption"><span className="mono">--r-lg</span> · {rLg}px</span>
          <span className="caption">큰 영역, 모달</span>
        </div>
        <div>
          <div className="r-box" style={{ borderRadius: 999 }} />
          <span className="caption"><span className="mono">--r-full</span> · pill</span>
          <span className="caption">칩, 토글</span>
        </div>
      </div>
    </section>
  );
}

// ── 7) Shadow ───────────────────────────────────────────────────────────────
function ShadowSection() {
  return (
    <section className="s" id="shadow">
      <div className="s-head">
        <span className="num">06</span>
        <h2 className="h1">그림자 · Elevation</h2>
      </div>
      <p className="s-desc">거의 쓰지 않습니다. 카드를 페이지에서 살짝 들어 올리는 1단계만 정의.</p>
      <div style={{ display: 'flex', gap: 24, alignItems: 'center' }}>
        <div className="shadow-demo">elevation-1</div>
        <div className="mono">box-shadow: 0 1px 2px / 0 6px 18px -10px</div>
      </div>
    </section>
  );
}

// ── 8) Components ───────────────────────────────────────────────────────────
function ComponentsSection() {
  const [activeTab, setActiveTab] = React.useState('md');
  const [chips, setChips] = React.useState({ yellow: true, orange: true, pink: false, blue: false });

  return (
    <section className="s" id="components">
      <div className="s-head">
        <span className="num">07</span>
        <h2 className="h1">컴포넌트 · Components</h2>
      </div>
      <p className="s-desc">SwiftUI로 옮길 때 1:1 매핑되도록 정리. 호버·활성 상태는 사용 맥락에 따라 가감.</p>

      {/* Buttons */}
      <div className="eyebrow" style={{ margin: '24px 0 10px' }}>Buttons</div>
      <div style={{ display: 'flex', gap: 12, flexWrap: 'wrap', alignItems: 'center' }}>
        <button className="btn btn-primary">PDF 내보내기</button>
        <button className="btn btn-secondary">공유</button>
        <button className="btn btn-ghost">취소</button>
      </div>

      {/* Chips */}
      <div className="eyebrow" style={{ margin: '32px 0 10px' }}>Toggle Chips · 4색 형광펜</div>
      <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
        {HL.map((h) => (
          <button
            key={h.key}
            className={chips[h.key] ? 'chip on' : 'chip'}
            onClick={() => setChips({ ...chips, [h.key]: !chips[h.key] })}
            style={{ '--c': `var(${h.vr})`, '--c-bg': `var(${h.bg})`, '--c-edge': `var(${h.edge})` }}
          >
            <span className="dot" />
            {h.name} ({h.tag})
          </button>
        ))}
      </div>

      {/* Tabs */}
      <div className="eyebrow" style={{ margin: '32px 0 10px' }}>Tab Toggle · Markdown ↔ PDF</div>
      <div className="tabs">
        <button className={activeTab === 'md' ? 'tab on' : 'tab'} onClick={() => setActiveTab('md')}>마크다운</button>
        <button className={activeTab === 'pdf' ? 'tab on' : 'tab'} onClick={() => setActiveTab('pdf')}>원본 PDF</button>
      </div>

      {/* Recent cards */}
      <div className="eyebrow" style={{ margin: '32px 0 10px' }}>Recent Card</div>
      <div className="g-2">
        <div className="recent-card">
          <div className="thumb">4p</div>
          <div style={{ flex: 1, minWidth: 0 }}>
            <div className="title">항생제정리</div>
            <div className="date">5월 24일 · 4페이지</div>
            <div className="dots">
              <i style={{ background: 'var(--hl-yellow)' }}/>
              <i style={{ background: 'var(--hl-orange)' }}/>
              <i style={{ background: 'var(--hl-pink)' }}/>
            </div>
          </div>
          <span className="chev"><Icon.Chevron/></span>
        </div>
        <div className="recent-card">
          <div className="thumb">12p</div>
          <div style={{ flex: 1, minWidth: 0 }}>
            <div className="title">심전도 판독 요점</div>
            <div className="date">5월 22일 · 12페이지</div>
            <div className="dots">
              <i style={{ background: 'var(--hl-yellow)' }}/>
              <i style={{ background: 'var(--hl-blue)' }}/>
            </div>
          </div>
          <span className="chev"><Icon.Chevron/></span>
        </div>
      </div>

      {/* Action bar */}
      <div className="eyebrow" style={{ margin: '32px 0 10px' }}>Bottom Action Bar</div>
      <div style={{ maxWidth: 420 }}>
        <div className="actionbar">
          <button className="a"><Icon.Copy className="ico"/> 복사</button>
          <button className="a"><Icon.Share className="ico"/> 공유</button>
          <button className="a primary"><Icon.PDF className="ico"/> PDF 내보내기</button>
        </div>
      </div>

      {/* Progress */}
      <div className="eyebrow" style={{ margin: '32px 0 10px' }}>Progress · 얇고 우아하게</div>
      <div style={{ maxWidth: 420 }}>
        <div className="progress"><i style={{ width: '38%' }}/></div>
      </div>

      {/* Signature: markdown with left color bars */}
      <div className="eyebrow" style={{ margin: '32px 0 10px' }}>★ Signature · 본문 좌측 컬러 바</div>
      <div className="md">
        <h1>항생제정리</h1>
        <h2>항생제의 분류</h2>
        <ul>
          <li data-c="yellow">베타락탐계는 세포벽 합성을 억제</li>
          <li data-c="yellow">페니실린 알레르기 환자 주의</li>
          <li data-c="orange">세팔로스포린은 1~5세대까지</li>
        </ul>
        <h2>부작용 모니터링</h2>
        <ul>
          <li data-c="yellow">신독성 신호 — BUN/Cr 상승</li>
          <li data-c="pink">청신경 독성 — 가역적</li>
          <li data-c="pink">위막성 대장염 — 클로스트리디움 디피실</li>
        </ul>
      </div>

      {/* Empty state */}
      <div className="eyebrow" style={{ margin: '32px 0 10px' }}>Empty State · 선화 일러스트 가이드</div>
      <div className="empty-card">
        <div className="empty-illu"><Icon.Book/></div>
        <div className="h2" style={{ fontSize: 18 }}>아직 변환한 노트가 없어요</div>
        <div className="caption" style={{ maxWidth: 320 }}>굿노트에서 공유 → Lumark로 보내면 마크다운이 알아서 쌓입니다.</div>
        <button className="btn btn-primary" style={{ marginTop: 4 }}>도움말 보기</button>
      </div>
    </section>
  );
}

// ── Sidebar nav (static list) ───────────────────────────────────────────────
function SidebarNav() {
  const items = [
    { num: '00', label: '개요', href: '#overview' },
    { num: '01', label: '컬러 팔레트', href: '#colors' },
    { num: '02', label: '형광펜 4색', href: '#highlighters' },
    { num: '03', label: '타이포그래피', href: '#typography' },
    { num: '04', label: '간격', href: '#spacing' },
    { num: '05', label: '모서리', href: '#radius' },
    { num: '06', label: '그림자', href: '#shadow' },
    { num: '07', label: '컴포넌트', href: '#components' },
  ];
  return (
    <nav className="navlist">
      <div className="group-label">Tokens & Components</div>
      {items.map((i) => (
        <a key={i.href} href={i.href}>
          <span className="num">{i.num}</span>
          <span>{i.label}</span>
        </a>
      ))}
      <div className="group-label">v0.1 · 2025</div>
      <a href="#" style={{ color: 'var(--muted)' }}>
        <span className="num"></span>
        <span>SwiftUI 매핑 가이드</span>
      </a>
    </nav>
  );
}

// Hex resolver — fills in the "—" hex value in each color tile after mount,
// so the page shows real hex codes (Light + Dark mode aware) without
// hardcoding them in two places. Runs whenever theme changes.
function useResolveHex(theme) {
  React.useEffect(() => {
    const cs = getComputedStyle(document.documentElement);
    document.querySelectorAll('[data-cssvar]').forEach((el) => {
      const v = cs.getPropertyValue(el.dataset.cssvar).trim();
      // Render the resolved color string verbatim; oklch(...) is the modern
      // SwiftUI Color(uiColor:) source format anyway.
      el.textContent = v;
    });
  }, [theme]);
}

Object.assign(window, {
  Icon,
  OverviewSection, ColorsSection, HighlightersSection, TypographySection,
  SpacingSection, RadiusSection, ShadowSection, ComponentsSection,
  SidebarNav, useResolveHex,
});
