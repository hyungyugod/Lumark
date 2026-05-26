// result-screen.jsx
// The ResultView screen — full 393×852 iPhone body, broken into:
//   status bar / nav / tabs / chips / body (md OR pdf) / action bar
// Theme is scoped via [data-theme] on .rv-screen so multiple frames at
// different themes can coexist on the same page.

// ── Inline glyphs (will map to SF Symbols in SwiftUI) ───────────────────────
const RVI = {
  Back: () => (
    <svg width="22" height="22" viewBox="0 0 22 22" fill="none">
      <path d="M13 5L7 11l6 6" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
    </svg>
  ),
  More: () => (
    <svg width="22" height="22" viewBox="0 0 22 22" fill="none">
      <circle cx="5"  cy="11" r="1.6" fill="currentColor"/>
      <circle cx="11" cy="11" r="1.6" fill="currentColor"/>
      <circle cx="17" cy="11" r="1.6" fill="currentColor"/>
    </svg>
  ),
  Copy: () => (
    <svg viewBox="0 0 24 24" width="100%" height="100%" fill="none">
      <rect x="4" y="6.5" width="11.5" height="13.5" rx="2.4" stroke="currentColor" strokeWidth="1.5"/>
      <path d="M7.5 6.5V5a2 2 0 0 1 2-2h8a2 2 0 0 1 2 2v11.5a2 2 0 0 1-2 2H16" stroke="currentColor" strokeWidth="1.5"/>
    </svg>
  ),
  Share: () => (
    <svg viewBox="0 0 24 24" width="100%" height="100%" fill="none">
      <path d="M12 15V4M8 7l4-4 4 4" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
      <path d="M5 12v6.5A1.5 1.5 0 0 0 6.5 20h11a1.5 1.5 0 0 0 1.5-1.5V12" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round"/>
    </svg>
  ),
  PDF: () => (
    <svg viewBox="0 0 24 24" width="100%" height="100%" fill="none">
      <path d="M6 3h8l4 4v13a1 1 0 0 1-1 1H6a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1z" stroke="currentColor" strokeWidth="1.5" strokeLinejoin="round"/>
      <path d="M14 3v4h4" stroke="currentColor" strokeWidth="1.5" strokeLinejoin="round"/>
      <text x="11.5" y="17" textAnchor="middle" fontSize="5.5" fontWeight="700" fill="currentColor" fontFamily="ui-sans-serif">PDF</text>
    </svg>
  ),
  // Status-bar glyphs (cellular signal, wifi, battery) — minimal placeholders.
  Signal: () => (
    <svg width="17" height="11" viewBox="0 0 17 11">
      <rect x="0" y="7" width="3" height="4" rx="0.5" fill="currentColor"/>
      <rect x="4.5" y="5" width="3" height="6" rx="0.5" fill="currentColor"/>
      <rect x="9" y="3" width="3" height="8" rx="0.5" fill="currentColor"/>
      <rect x="13.5" y="0" width="3" height="11" rx="0.5" fill="currentColor"/>
    </svg>
  ),
  Wifi: () => (
    <svg width="15" height="11" viewBox="0 0 15 11" fill="none">
      <path d="M1 4.2a10 10 0 0 1 13 0" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round"/>
      <path d="M3.6 6.6a6.5 6.5 0 0 1 7.8 0" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round"/>
      <circle cx="7.5" cy="9" r="1.2" fill="currentColor"/>
    </svg>
  ),
  Battery: () => (
    <svg width="27" height="13" viewBox="0 0 27 13" fill="none">
      <rect x="0.5" y="0.5" width="22" height="12" rx="3" stroke="currentColor" strokeOpacity="0.4"/>
      <rect x="2" y="2" width="19" height="9" rx="1.8" fill="currentColor"/>
      <rect x="24" y="4" width="1.8" height="5" rx="0.9" fill="currentColor" opacity="0.4"/>
    </svg>
  ),
};

// Status bar — custom so we can match the screen's theme tokens directly.
function StatusBar() {
  return (
    <div className="rv-status">
      <span>9:41</span>
      <span className="right">
        <RVI.Signal/>
        <RVI.Wifi/>
        <RVI.Battery/>
      </span>
    </div>
  );
}

// Chip with a color dot. Active state controlled by `on`.
function Chip({ color, label, on, onClick }) {
  return (
    <button
      type="button"
      className={on ? 'rv-chip on' : 'rv-chip'}
      onClick={onClick}
      style={{ '--c': `var(--hl-${color})`, '--c-bg': `var(--hl-${color}-bg)`, '--c-edge': `var(--hl-${color}-edge)` }}
    >
      <span className="d"/>
      {label}
    </button>
  );
}

// Body in markdown mode. Active filter dims items whose color is off rather
// than hiding them — preserves the layout and shows the filter UX clearly.
function MarkdownBody({ chips }) {
  const off = (c) => !chips[c];
  return (
    <>
      <h1 className="md-h1">항생제정리</h1>

      <h2 className="md-h2">항생제의 분류</h2>
      <ul className="md-ul">
        <li className={'md-li' + (off('yellow') ? ' off' : '')} data-c="yellow">
          베타락탐계는 세포벽 합성을 억제
        </li>
        <li className={'md-li' + (off('yellow') ? ' off' : '')} data-c="yellow">
          페니실린 알레르기 환자 주의
        </li>
        <li className={'md-li' + (off('orange') ? ' off' : '')} data-c="orange">
          세팔로스포린은 1~5세대까지
        </li>
      </ul>

      <h2 className="md-h2">부작용 모니터링</h2>
      <ul className="md-ul">
        <li className={'md-li' + (off('yellow') ? ' off' : '')} data-c="yellow">
          신독성 신호 — <span className="md-strong">BUN/Cr</span> 상승
        </li>
        <li className={'md-li' + (off('pink') ? ' off' : '')} data-c="pink">
          청신경 독성 — 가역적
        </li>
        <li className={'md-li' + (off('pink') ? ' off' : '')} data-c="pink">
          위막성 대장염 — 클로스트리디움 디피실
        </li>
        <li className={'md-li' + (off('blue') ? ' off' : '')} data-c="blue">
          참고: 항생제 감수성 검사(AST) 결과 우선
        </li>
      </ul>

      <hr className="md-hr"/>
      <h3 className="md-h3">추가 메모</h3>
      <p className="md-p">
        <span className="md-strong">보충 (분홍)</span> · 위막성 대장염 의심 시 메트로니다졸 또는 반코마이신 경구.
        <span className="md-strong"> 신독성</span>에는 BUN/Cr·소변량 동시 추적.
      </p>
    </>
  );
}

// PDF tab — a faux page mockup with colored highlight overlays.
// When a color is filtered off, its overlays fade rather than disappear,
// so the user understands "filter" not "delete".
function PDFBody({ chips }) {
  const cls = (c) => 'hl' + (chips[c] ? '' : ' off');
  return (
    <div className="pdf-page">
      <h1>항생제정리</h1>
      <div className="body">
        <h2 style={{ marginTop: 14 }}>1. 항생제의 분류</h2>
        <p>
          <span className={cls('yellow')} data-c="yellow">베타락탐계는 세포벽 합성을 억제</span>하는 대표적인 항생제이며,
          페니실린·세팔로스포린·카바페넴이 포함된다.
          <span className={cls('yellow')} data-c="yellow"> 페니실린 알레르기 환자에서</span> 교차반응 가능성을 항상 확인한다.
        </p>
        <p>
          <span className={cls('orange')} data-c="orange">세팔로스포린은 1~5세대까지 분류</span>되며,
          세대가 올라갈수록 그람음성 균에 대한 활성이 증가한다.
        </p>

        <h2>2. 부작용 모니터링</h2>
        <p>
          신독성 신호로 <span className={cls('yellow')} data-c="yellow">BUN/Cr 상승</span>을 추적하고,
          <span className={cls('pink')} data-c="pink"> 청신경 독성은 대부분 가역적</span>이지만 조기 발견이 중요하다.
        </p>
        <p>
          <span className={cls('pink')} data-c="pink">위막성 대장염</span>은 클로스트리디움 디피실에 의해 발생하며,
          광범위 항생제 사용 후 발생한 설사에서 의심해야 한다.
        </p>
        <p>
          <span className={cls('blue')} data-c="blue">감수성 검사(AST) 결과가 우선</span>하며,
          경험적 치료는 그 다음이다.
        </p>
      </div>
      <div className="pno">p. 1 / 4</div>
    </div>
  );
}

// Main screen — composes the layout. `chips` is the active state per color;
// `tab` selects md vs pdf body. Pass-through interactivity via setChips/setTab.
function ResultScreen({ theme = 'light', tab: initialTab = 'md', initialChips, interactive = false }) {
  const [tab, setTab] = React.useState(initialTab);
  const [chips, setChips] = React.useState(initialChips || { yellow: true, orange: true, pink: false, blue: false });

  // Lock to non-interactive snapshot when used as a static design panel
  const toggleChip = (k) => interactive && setChips((s) => ({ ...s, [k]: !s[k] }));
  const setTabIfActive = (t) => interactive && setTab(t);

  return (
    <div className="rv-screen" data-theme={theme}>
      {/* Status bar provided by IOSDevice frame (absolute-positioned, theme-aware). */}
      <div className="rv-nav">
        <button className="rv-nav-btn" aria-label="뒤로 가기"><RVI.Back/></button>
        <div className="rv-nav-title">항생제정리</div>
        <button className="rv-nav-btn" aria-label="더보기"><RVI.More/></button>
      </div>

      <div className="rv-tabs" role="tablist">
        <button className={'rv-tab' + (tab === 'md' ? ' on' : '')} onClick={() => setTabIfActive('md')} role="tab">마크다운</button>
        <button className={'rv-tab' + (tab === 'pdf' ? ' on' : '')} onClick={() => setTabIfActive('pdf')} role="tab">원본 PDF</button>
      </div>

      <div className="rv-chips" aria-label="색상 필터">
        <Chip color="yellow" label="노랑 (핵심)" on={chips.yellow} onClick={() => toggleChip('yellow')}/>
        <Chip color="orange" label="주황 (주제)" on={chips.orange} onClick={() => toggleChip('orange')}/>
        <Chip color="pink"   label="분홍"        on={chips.pink}   onClick={() => toggleChip('pink')}/>
        <Chip color="blue"   label="파랑"        on={chips.blue}   onClick={() => toggleChip('blue')}/>
      </div>

      <div className="rv-body">
        {tab === 'md' ? <MarkdownBody chips={chips}/> : <PDFBody chips={chips}/>}
      </div>

      <div className="rv-actionbar">
        <button className="rv-a"><span className="ico"><RVI.Copy/></span>복사</button>
        <button className="rv-a"><span className="ico"><RVI.Share/></span>공유</button>
        <button className="rv-a primary"><span className="ico"><RVI.PDF/></span>PDF 내보내기</button>
      </div>
    </div>
  );
}

Object.assign(window, { ResultScreen });
