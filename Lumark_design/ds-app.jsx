// ds-app.jsx
// Root App for Lumark Design System page.
// Owns: theme (light/dark) + tweak state (brown hue, radius, spacing, font).
// Pushes tweak values to :root as CSS custom properties so static
// stylesheet rules pick them up.

const TWEAK_DEFAULTS = /*EDITMODE-BEGIN*/{
  "brownHue": 58,
  "brownChroma": 0.060,
  "rSm": 6,
  "rMd": 12,
  "rLg": 20,
  "spBase": 16,
  "fontDisplay": "myeongjo"
}/*EDITMODE-END*/;

function App() {
  const [theme, setTheme] = React.useState('light');
  const [t, setTweak] = useTweaks(TWEAK_DEFAULTS);

  // Push theme to <html data-theme="…">
  React.useEffect(() => {
    document.documentElement.setAttribute('data-theme', theme);
  }, [theme]);

  // Push tweaks to :root CSS custom properties. Doing this in JS rather than
  // through inline styles keeps the stylesheet authoritative — Tweaks panel
  // only adjusts a handful of named tokens, everything else cascades.
  React.useEffect(() => {
    const root = document.documentElement.style;
    // Re-derive brown when chroma/hue tweak changes. Lightness stays anchored
    // so dark/light mode contrast doesn't drift.
    if (theme === 'dark') {
      root.setProperty('--brown',   `oklch(0.74 ${t.brownChroma} ${t.brownHue})`);
      root.setProperty('--brown-2', `oklch(0.66 ${t.brownChroma} ${t.brownHue})`);
    } else {
      root.setProperty('--brown',   `oklch(0.43 ${t.brownChroma} ${t.brownHue})`);
      root.setProperty('--brown-2', `oklch(0.37 ${Math.max(0, t.brownChroma - 0.005)} ${t.brownHue})`);
    }
    root.setProperty('--r-sm', `${t.rSm}px`);
    root.setProperty('--r-md', `${t.rMd}px`);
    root.setProperty('--r-lg', `${t.rLg}px`);
    // Scale the whole spacing ramp from the spBase knob — keeps proportions intact.
    const k = t.spBase / 16;
    root.setProperty('--sp-1', `${Math.round(4 * k)}px`);
    root.setProperty('--sp-2', `${Math.round(8 * k)}px`);
    root.setProperty('--sp-3', `${Math.round(12 * k)}px`);
    root.setProperty('--sp-4', `${Math.round(16 * k)}px`);
    root.setProperty('--sp-5', `${Math.round(24 * k)}px`);
    root.setProperty('--sp-6', `${Math.round(32 * k)}px`);
    root.setProperty('--sp-7', `${Math.round(48 * k)}px`);

    // Display font swap
    const displayMap = {
      myeongjo: "'Nanum Myeongjo','Noto Serif KR',serif",
      noto:     "'Noto Sans KR',system-ui,sans-serif",
    };
    root.setProperty('--font-display', displayMap[t.fontDisplay] || displayMap.myeongjo);
  }, [t, theme]);

  useResolveHex(theme);

  return (
    <>
      <div className="shell">
        <aside className="sidebar">
          <div className="brand">
            Lumark <span className="ver">v0.1</span>
          </div>
          <div className="brand-sub">
            형광펜만 그으면,<br/>정리 노트가 알아서 쌓이는 iOS 학습 도구
          </div>
          <SidebarNav />
        </aside>

        <main className="content">
          <div className="topbar">
            <div>
              <div className="eyebrow">Design System</div>
              <h1 className="h1" style={{ marginTop: 4 }}>따뜻한 모더니즘 — Lumark</h1>
            </div>
            <ModeToggle theme={theme} setTheme={setTheme} />
          </div>

          <OverviewSection />
          <ColorsSection />
          <HighlightersSection />
          <TypographySection />
          <SpacingSection baseSp={t.spBase} />
          <RadiusSection rSm={t.rSm} rMd={t.rMd} rLg={t.rLg} />
          <ShadowSection />
          <ComponentsSection />

          <div className="footnote">
            <div className="mono">// Lumark Design System v0.1 — Light/Dark, Mobile/Desktop</div>
            <div style={{ marginTop: 8 }}>
              SwiftUI 매핑: 컬러는 <span className="mono">Color(.brown)</span> 등으로 토큰명 그대로, 폰트는 <span className="mono">.font(.system(.body, design: .serif))</span>가 아닌 커스텀 폰트(<span className="mono">Pretendard / Nanum Myeongjo</span>)로 정의하는 것을 권장.
            </div>
          </div>
        </main>
      </div>

      <TweaksPanel title="Tweaks · 디자인 시스템">
        <TweakSection label="브라운 톤" />
        <TweakSlider label="Hue (색조)" value={t.brownHue} min={20} max={90} step={1} unit="°"
                     onChange={(v) => setTweak('brownHue', v)} />
        <TweakSlider label="Chroma (채도)" value={t.brownChroma} min={0.02} max={0.10} step={0.005} unit=""
                     onChange={(v) => setTweak('brownChroma', v)} />

        <TweakSection label="모서리" />
        <TweakSlider label="sm" value={t.rSm} min={0} max={14} step={1} unit="px"
                     onChange={(v) => setTweak('rSm', v)} />
        <TweakSlider label="md" value={t.rMd} min={4} max={24} step={1} unit="px"
                     onChange={(v) => setTweak('rMd', v)} />
        <TweakSlider label="lg" value={t.rLg} min={8} max={32} step={1} unit="px"
                     onChange={(v) => setTweak('rLg', v)} />

        <TweakSection label="간격" />
        <TweakSlider label="기준 (sp-4)" value={t.spBase} min={10} max={22} step={1} unit="px"
                     onChange={(v) => setTweak('spBase', v)} />

        <TweakSection label="강조 폰트" />
        <TweakRadio label="Display" value={t.fontDisplay}
                    options={[{ value: 'myeongjo', label: '명조' }, { value: 'noto', label: '고딕' }]}
                    onChange={(v) => setTweak('fontDisplay', v)} />
      </TweaksPanel>
    </>
  );
}

function ModeToggle({ theme, setTheme }) {
  return (
    <div className="mode-toggle" role="tablist">
      <button className={theme === 'light' ? 'on' : ''} onClick={() => setTheme('light')} role="tab">
        <SunIcon /> Light
      </button>
      <button className={theme === 'dark' ? 'on' : ''} onClick={() => setTheme('dark')} role="tab">
        <MoonIcon /> Dark
      </button>
    </div>
  );
}

const SunIcon = () => (
  <svg width="13" height="13" viewBox="0 0 16 16" aria-hidden="true">
    <circle cx="8" cy="8" r="3" fill="currentColor"/>
    {[0,1,2,3,4,5,6,7].map((i) => {
      const a = (i * Math.PI) / 4;
      const x1 = 8 + Math.cos(a) * 5;
      const y1 = 8 + Math.sin(a) * 5;
      const x2 = 8 + Math.cos(a) * 7;
      const y2 = 8 + Math.sin(a) * 7;
      return <line key={i} x1={x1} y1={y1} x2={x2} y2={y2} stroke="currentColor" strokeWidth="1.4" strokeLinecap="round"/>;
    })}
  </svg>
);

const MoonIcon = () => (
  <svg width="13" height="13" viewBox="0 0 16 16" aria-hidden="true">
    <path d="M12.5 9.5A5 5 0 0 1 6.5 3.5a.5.5 0 0 0-.7-.5 6 6 0 1 0 7.2 7.2.5.5 0 0 0-.5-.7z" fill="currentColor"/>
  </svg>
);

ReactDOM.createRoot(document.getElementById('root')).render(<App />);
