// home-screen.jsx
// HomeView — the first-impression screen of Lumark.
// Two variants share the same chrome:
//   A: "loaded" state with 3 recent notes
//   B: "empty" state with brown line-art illustration + CTA

// ── Icons ──────────────────────────────────────────────────────────────────
const HVI = {
  // 24×24 stroke icons; SwiftUI gets SF Symbols substitutes
  Upload: () => (
    <svg viewBox="0 0 24 24" width="36" height="36" fill="none">
      <path d="M12 15V4M7 9l5-5 5 5" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"/>
      <path d="M4 16v3a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-3" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round"/>
    </svg>
  ),
  Camera: () => (
    <svg viewBox="0 0 24 24" width="36" height="36" fill="none">
      <path d="M4 9a2 2 0 0 1 2-2h2.2l1.6-2h4.4l1.6 2H18a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V9z" stroke="currentColor" strokeWidth="1.8" strokeLinejoin="round"/>
      <circle cx="12" cy="13.5" r="3.7" stroke="currentColor" strokeWidth="1.8"/>
    </svg>
  ),
  Recent: () => (
    <svg viewBox="0 0 24 24" width="36" height="36" fill="none">
      <rect x="4" y="6" width="16" height="14" rx="2.2" stroke="currentColor" strokeWidth="1.8"/>
      <path d="M8 3v3M16 3v3" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round"/>
      <path d="M8 13h8M8 17h5" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round"/>
    </svg>
  ),
  Gear: () => (
    <svg viewBox="0 0 24 24" width="36" height="36" fill="none">
      <path d="M12.22 2h-.44a2 2 0 0 0-2 2v.18a2 2 0 0 1-1 1.73l-.43.25a2 2 0 0 1-2 0l-.15-.08a2 2 0 0 0-2.73.73l-.22.38a2 2 0 0 0 .73 2.73l.15.1a2 2 0 0 1 1 1.72v.51a2 2 0 0 1-1 1.74l-.15.09a2 2 0 0 0-.73 2.73l.22.38a2 2 0 0 0 2.73.73l.15-.08a2 2 0 0 1 2 0l.43.25a2 2 0 0 1 1 1.73V20a2 2 0 0 0 2 2h.44a2 2 0 0 0 2-2v-.18a2 2 0 0 1 1-1.73l.43-.25a2 2 0 0 1 2 0l.15.08a2 2 0 0 0 2.73-.73l.22-.39a2 2 0 0 0-.73-2.73l-.15-.08a2 2 0 0 1-1-1.74v-.5a2 2 0 0 1 1-1.74l.15-.09a2 2 0 0 0 .73-2.73l-.22-.38a2 2 0 0 0-2.73-.73l-.15.08a2 2 0 0 1-2 0l-.43-.25a2 2 0 0 1-1-1.73V4a2 2 0 0 0-2-2Z" stroke="currentColor" strokeWidth="1.6" strokeLinejoin="round"/>
      <circle cx="12" cy="12" r="3" stroke="currentColor" strokeWidth="1.6"/>
    </svg>
  ),
  GearSmall: () => (
    <svg viewBox="0 0 24 24" width="22" height="22" fill="none">
      <path d="M12.22 2h-.44a2 2 0 0 0-2 2v.18a2 2 0 0 1-1 1.73l-.43.25a2 2 0 0 1-2 0l-.15-.08a2 2 0 0 0-2.73.73l-.22.38a2 2 0 0 0 .73 2.73l.15.1a2 2 0 0 1 1 1.72v.51a2 2 0 0 1-1 1.74l-.15.09a2 2 0 0 0-.73 2.73l.22.38a2 2 0 0 0 2.73.73l.15-.08a2 2 0 0 1 2 0l.43.25a2 2 0 0 1 1 1.73V20a2 2 0 0 0 2 2h.44a2 2 0 0 0 2-2v-.18a2 2 0 0 1 1-1.73l.43-.25a2 2 0 0 1 2 0l.15.08a2 2 0 0 0 2.73-.73l.22-.39a2 2 0 0 0-.73-2.73l-.15-.08a2 2 0 0 1-1-1.74v-.5a2 2 0 0 1 1-1.74l.15-.09a2 2 0 0 0 .73-2.73l-.22-.38a2 2 0 0 0-2.73-.73l-.15.08a2 2 0 0 1-2 0l-.43-.25a2 2 0 0 1-1-1.73V4a2 2 0 0 0-2-2Z" stroke="currentColor" strokeWidth="1.6" strokeLinejoin="round"/>
      <circle cx="12" cy="12" r="3" stroke="currentColor" strokeWidth="1.6"/>
    </svg>
  ),
  Chev: () => (
    <svg viewBox="0 0 20 20" width="14" height="14" fill="none">
      <path d="M7 4l6 6-6 6" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round"/>
    </svg>
  ),
  // Banner glyph — a paper page with an arrow
  Share: () => (
    <svg viewBox="0 0 22 22" width="18" height="18" fill="none">
      <rect x="3" y="4" width="11" height="14" rx="1.5" stroke="currentColor" strokeWidth="1.6"/>
      <path d="M15 9l4 0M19 9l-2-2M19 9l-2 2" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round"/>
    </svg>
  ),
  // Empty-state line illustration: a notebook with a highlighter laid across it.
  // Brown monochrome line art per the spec.
  EmptyArt: () => (
    <svg viewBox="0 0 200 140" width="180" height="126" fill="none" aria-hidden="true">
      {/* notebook */}
      <rect x="32" y="22" width="116" height="100" rx="5" stroke="currentColor" strokeWidth="1.6"/>
      {/* spine binding rings */}
      <line x1="40" y1="22" x2="40" y2="122" stroke="currentColor" strokeWidth="1.6"/>
      {[34, 50, 66, 82, 98, 114].map((y) => (
        <circle key={y} cx="40" cy={y} r="2.2" stroke="currentColor" strokeWidth="1.4"/>
      ))}
      {/* writing lines */}
      <line x1="56" y1="46" x2="138" y2="46" stroke="currentColor" strokeWidth="1.2" opacity="0.6"/>
      <line x1="56" y1="60" x2="124" y2="60" stroke="currentColor" strokeWidth="1.2" opacity="0.6"/>
      <line x1="56" y1="74" x2="132" y2="74" stroke="currentColor" strokeWidth="1.2" opacity="0.6"/>
      {/* highlighter pen laid diagonally over the lower-right */}
      <g transform="translate(118 78) rotate(28)">
        <rect x="0" y="0" width="74" height="16" rx="3" stroke="currentColor" strokeWidth="1.6"/>
        <rect x="62" y="0" width="12" height="16" stroke="currentColor" strokeWidth="1.6"/>
        {/* chisel tip */}
        <path d="M74 0 L 92 4 L 92 12 L 74 16 Z" stroke="currentColor" strokeWidth="1.6" strokeLinejoin="round"/>
        {/* cap line */}
        <line x1="8" y1="0" x2="8" y2="16" stroke="currentColor" strokeWidth="1.4"/>
      </g>
    </svg>
  ),
};

// ── Action cards (2×2) ──────────────────────────────────────────────────────
function ActionCard({ icon, label, desc, primary }) {
  return (
    <button type="button" className={primary ? 'hv-card primary' : 'hv-card'}>
      <span className="ico">{icon}</span>
      <span>
        <span className="label" style={{ display: 'block' }}>{label}</span>
        <span className="desc">{desc}</span>
      </span>
    </button>
  );
}

// ── Recent card ─────────────────────────────────────────────────────────────
const NoteIcon = ({ pages }) => (
  <span className="thumb">
    <span>{pages}p</span>
  </span>
);

const Dots = ({ colors }) => (
  <span className="dots">
    {colors.map((c) => (
      <i key={c} style={{ background: `var(--hl-${c})` }} />
    ))}
  </span>
);

function RecentRow({ title, date, pages, colors }) {
  return (
    <div className="hv-rec">
      <NoteIcon pages={pages} />
      <div className="meta">
        <div className="title">{title}</div>
        <div className="date">{date}</div>
        <Dots colors={colors} />
      </div>
      <span className="chev"><HVI.Chev/></span>
    </div>
  );
}

// ── Main screen ─────────────────────────────────────────────────────────────
function HomeScreen({ theme = 'light', state = 'A', brand = 'Lumark' }) {
  return (
    <div className="hv-screen" data-theme={theme}>
      {/* Header */}
      <div className="hv-header">
        <div>
          <div className="hv-brand">{brand}</div>
          <div className="hv-sub">형광펜만 그으면,<br/>정리 노트가 알아서 쌓여요</div>
        </div>
        <button className="hv-gear" aria-label="설정"><HVI.GearSmall/></button>
      </div>

      <div className="hv-body">
        {/* 2×2 grid */}
        <div className="hv-grid">
          <ActionCard icon={<HVI.Upload/>}   label="업로드"     desc="PDF·이미지 선택" primary/>
          <ActionCard icon={<HVI.Camera/>}   label="카메라"     desc="직접 촬영"        primary/>
          <ActionCard icon={<HVI.Recent/>}   label="최근 작업"  desc="내 정리본"/>
          <ActionCard icon={<HVI.Gear/>}     label="설정"       desc="색·라벨"/>
        </div>

        {/* Banner */}
        <div className="hv-banner">
          <span className="b-ico"><HVI.Share/></span>
          <span className="b-text">
            <b>굿노트에서 공유</b> → Lumark로 보내면 자동으로 받아요
          </span>
          <span className="b-chev"><HVI.Chev/></span>
        </div>

        {/* Recent OR Empty */}
        {state === 'A' ? (
          <>
            <div className="hv-secthead">
              <h3>최근 작업</h3>
              <button className="seeall">모두 보기 <HVI.Chev/></button>
            </div>
            <div className="hv-recent">
              <RecentRow title="항생제정리"      date="5월 24일 · 4페이지"  pages="4"  colors={['yellow','orange','pink']}/>
              <RecentRow title="심전도 판독 요점" date="5월 22일 · 12페이지" pages="12" colors={['yellow','blue']}/>
              <RecentRow title="당뇨병 약물 정리" date="5월 19일 · 8페이지"  pages="8"  colors={['yellow','orange']}/>
            </div>
          </>
        ) : (
          <div className="hv-empty">
            <span className="illu"><HVI.EmptyArt/></span>
            <div className="e-title">아직 변환한 노트가 없어요</div>
            <div className="e-desc">굿노트 PDF를 공유로 보내거나<br/>업로드 버튼을 눌러 시작해보세요</div>
            <button className="cta">굿노트 연동 안내</button>
          </div>
        )}
      </div>
    </div>
  );
}

Object.assign(window, { HomeScreen });
