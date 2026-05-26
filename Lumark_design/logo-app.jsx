// logo-app.jsx
// Root for "Logo & Icon" design board.
// Assembles wordmark variants, three icon directions, and the 4-color
// usage card. Tweaks panel exposes brown hue/chroma, icon corner radius,
// and a few presentation toggles.

const TWEAK_DEFAULTS = /*EDITMODE-BEGIN*/{
  "brownHue": 60,
  "brownChroma": 0.060,
  "iconRadius": 22.4,
  "preferredIcon": "A",
  "showGuide": false
}/*EDITMODE-END*/;

function App() {
  const [t, setTweak] = useTweaks(TWEAK_DEFAULTS);

  // Push tweakable tokens to :root so the icon gradients + wordmark stay in sync.
  React.useEffect(() => {
    const r = document.documentElement.style;
    r.setProperty('--brown',   `oklch(0.43 ${t.brownChroma} ${t.brownHue})`);
    r.setProperty('--brown-2', `oklch(0.32 ${t.brownChroma} ${t.brownHue})`);
    r.setProperty('--brown-3', `oklch(0.24 ${Math.max(0, t.brownChroma - 0.01)} ${t.brownHue})`);
  }, [t.brownChroma, t.brownHue]);

  // Mask radius lives on the .ic elements — read it via state so we can tweak.
  const radiusStyle = { borderRadius: `${t.iconRadius}%` };

  return (
    <>
      <div className="board">
        <div className="topbar">
          <div>
            <div className="crumb">Lumark · v0.1 · <b>03 Brand</b></div>
            <h1 className="title">아이콘과 워드마크.</h1>
            <p className="lede">
              4가지 형광펜이 곧 정체성인 앱입니다. 그래서 아이콘 안에 4색이 들어가야 인지도가 만들어지고,
              동시에 클래식·전문성을 유지해야 하므로 4색은 작게 — 무게는 갈색이 잡습니다.
            </p>
            <div className="meta-strip">
              <span><span className="k">size</span> 1024 × 1024</span>
              <span><span className="k">mask</span> iOS rounded ({t.iconRadius.toFixed(1)}%)</span>
              <span><span className="k">type</span> Nanum Myeongjo 800</span>
              <span><span className="k">accent</span> Brass</span>
            </div>
          </div>
        </div>

        {/* ── 01 Wordmark ───────────────────────────────────────────────── */}
        <section className="s">
          <div className="s-head">
            <div className="left">
              <span className="num">01</span>
              <h2>워드마크</h2>
            </div>
          </div>
          <p className="s-desc">
            Nanum Myeongjo 800에 살짝 마이너스 자간. <b>m</b>자 윗쪽엔 황동 dot,
            <b> k</b>자 아래엔 짧은 hairline — '표시(mark)'라는 어원을 시각화하는 두 개의 micro-flourish.
          </p>

          <div className="wordmark-row">
            <div className="wm-card">
              <div className="label">01 · Solid Brown</div>
              <div className="stage"><Wordmark tone="solid" size={64} accent="solid"/></div>
              <div className="caption" style={{ fontSize: 12, color: 'var(--subtle)' }}>
                기본 · 본문 헤더용
              </div>
            </div>
            <div className="wm-card">
              <div className="label">02 · Brown + Brass</div>
              <div className="stage"><Wordmark tone="brown" size={64} accent="brass"/></div>
              <div className="caption" style={{ fontSize: 12, color: 'var(--subtle)' }}>
                Pro 톤 · 키 비주얼, 앱스토어
              </div>
            </div>
            <div className="wm-card on-brown">
              <div className="label">03 · White on Dark</div>
              <div className="stage"><Wordmark tone="white" size={64} accent="solid"/></div>
              <div className="caption" style={{ fontSize: 12, color: 'color-mix(in oklab, var(--cream) 60%, var(--brown))' }}>
                다크 배경 · 공유 카드, Splash
              </div>
            </div>
          </div>

          {/* Spec strip */}
          <div style={{ marginTop: 28, display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))', gap: 24 }}>
            <div>
              <div className="spec-row"><span className="k">font</span><span className="v">Nanum Myeongjo 800</span></div>
              <div className="spec-row"><span className="k">tracking</span><span className="v">-4.5%</span></div>
              <div className="spec-row"><span className="k">size (header)</span><span className="v">22 pt</span></div>
              <div className="spec-row"><span className="k">size (splash)</span><span className="v">44 pt</span></div>
            </div>
            <div>
              <div className="spec-row"><span className="k">m-dot</span><span className="v">8.5% of size, brass</span></div>
              <div className="spec-row"><span className="k">k-hairline</span><span className="v">30% width, -12°</span></div>
              <div className="spec-row"><span className="k">clear-space</span><span className="v">≥ 0.5 × cap height</span></div>
              <div className="spec-row"><span className="k">min size</span><span className="v">16 pt</span></div>
            </div>
          </div>
        </section>

        {/* ── 02 Icons ──────────────────────────────────────────────────── */}
        <section className="s">
          <div className="s-head">
            <div className="left">
              <span className="num">02</span>
              <h2>앱 아이콘 — 3가지 방향</h2>
            </div>
            <div className="caption" style={{ fontSize: 12, color: 'var(--subtle)' }}>
              각 시안 · 1024 + 60pt 미리보기 · 검정/흰색/Cream 대비
            </div>
          </div>
          <p className="s-desc">
            세 방향 모두 가죽 브라운 또는 종이 크림을 베이스로 두고, 4색 형광펜을 dot 또는 stroke로 작게 박았습니다.
            현재 추천: <b>{t.preferredIcon}</b>. Tweaks 패널에서 바꿔보세요.
          </p>

          {(['A', 'B', 'C']).map((k) => {
            const Comp = ICONS[k];
            const meta = ICON_META[k];
            const isPref = t.preferredIcon === k;
            return (
              <div className="icon-direction" key={k}>
                <div className="id-head">
                  <div className="letter">방향 {meta.letter}</div>
                  <div className="right">
                    <h3>
                      {meta.title}
                      {isPref && <span style={{
                        marginLeft: 10, padding: '2px 8px', fontSize: 11, fontFamily: 'var(--font-mono)',
                        background: 'color-mix(in oklab, var(--brass) 16%, transparent)',
                        color: 'var(--brass)', border: '1px solid var(--brass)', borderRadius: 999,
                        verticalAlign: 'middle',
                      }}>preferred</span>}
                    </h3>
                    <p>{meta.desc}</p>
                  </div>
                </div>

                <div className="id-grid">
                  {/* Large icon */}
                  <div>
                    <div className="ic ic-1024" style={radiusStyle}><Comp/></div>
                    <div className="caption" style={{ marginTop: 12, textAlign: 'center', fontFamily: 'var(--font-mono)', fontSize: 11, color: 'var(--muted)' }}>
                      1024 × 1024 · App Store
                    </div>
                  </div>

                  {/* Preview row */}
                  <div className="preview-stack">
                    <div className="preview-card cream">
                      <div className="ic" style={radiusStyle}><Comp/></div>
                      <div className="meta">
                        <span className="name">60pt</span>
                        <span className="desc">홈스크린 (Cream)</span>
                      </div>
                    </div>
                    <div className="preview-card light">
                      <div className="ic" style={radiusStyle}><Comp/></div>
                      <div className="meta">
                        <span className="name">60pt · #FFFFFF</span>
                        <span className="desc">밝은 배경 · Light Mode</span>
                      </div>
                    </div>
                    <div className="preview-card dark">
                      <div className="ic" style={radiusStyle}><Comp/></div>
                      <div className="meta">
                        <span className="name">60pt · #0A0908</span>
                        <span className="desc">어두운 배경 · Dark Mode</span>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            );
          })}
        </section>

        {/* ── 03 Color usage ────────────────────────────────────────────── */}
        <section className="s">
          <div className="s-head">
            <div className="left">
              <span className="num">03</span>
              <h2>4색 사용 가이드</h2>
            </div>
          </div>
          <p className="s-desc">
            형광펜 4색은 칩·dot·본문 강조·좌측 컬러 바에 동일하게 재사용됩니다. 의미 매핑은 한 번 정하면 절대 바꾸지 마세요.
          </p>

          <div className="usage-grid">
            <div className="u-block">
              <h4>토글 칩 (필터)</h4>
              <div className="chip-row">
                <span className="chip" style={{ '--c': 'var(--hl-yellow)' }}><span className="d"/>노랑 · 핵심</span>
                <span className="chip" style={{ '--c': 'var(--hl-orange)' }}><span className="d"/>주황 · 주제</span>
                <span className="chip" style={{ '--c': 'var(--hl-pink)' }}><span className="d"/>분홍 · 보충</span>
                <span className="chip" style={{ '--c': 'var(--hl-blue)' }}><span className="d"/>파랑 · 참고</span>
              </div>
              <div style={{ marginTop: 14, fontSize: 12.5, color: 'var(--subtle)' }}>
                활성 칩: 옅은 색 배경 + 진한 dot · 비활성: 투명 + 옅은 dot
              </div>
            </div>

            <div className="u-block">
              <h4>최근 작업 dot 배지</h4>
              <div style={{ display: 'flex', alignItems: 'center', gap: 14 }}>
                <div style={{ fontFamily: 'var(--font-display)', fontWeight: 700, fontSize: 16, color: 'var(--ink)' }}>
                  항생제정리
                </div>
                <span className="dot-stack" aria-label="사용된 색">
                  <i style={{ background: 'var(--hl-yellow)' }}/>
                  <i style={{ background: 'var(--hl-orange)' }}/>
                  <i style={{ background: 'var(--hl-pink)' }}/>
                </span>
              </div>
              <div style={{ marginTop: 6, fontSize: 12.5, color: 'var(--subtle)' }}>
                노트 카드 옆에 사용된 색만 작게 — 4색 모두 사용 시 4개, 일부만 사용 시 해당 색만.
              </div>
            </div>

            <div className="u-block">
              <h4>본문 좌측 컬러 바 (시그니처)</h4>
              <div className="md-mini">
                <ul>
                  <li style={{ '--c': 'var(--hl-yellow)' }}>베타락탐계는 세포벽 합성을 억제</li>
                  <li style={{ '--c': 'var(--hl-orange)' }}>세팔로스포린은 1~5세대까지</li>
                  <li style={{ '--c': 'var(--hl-pink)' }}>청신경 독성 — 가역적</li>
                  <li style={{ '--c': 'var(--hl-blue)' }}>참고: BUN/Cr 동시 추적</li>
                </ul>
              </div>
              <div style={{ marginTop: 10, fontSize: 12.5, color: 'var(--subtle)' }}>
                항목별 좌측 2px 바 — 마크다운 ↔ PDF 양쪽에서 동일하게 작동.
              </div>
            </div>

            <div className="u-block">
              <h4>본문 인라인 강조 (highlight)</h4>
              <div style={{ fontSize: 14, lineHeight: 1.8, color: 'var(--ink-2)' }}>
                <span>페니실린 알레르기 환자에서 </span>
                <span className="body-emphasis" style={{ '--c': 'var(--hl-yellow)' }}>아나필락시스</span>
                <span> 발생률은 약 </span>
                <span className="body-emphasis" style={{ '--c': 'var(--hl-orange)' }}>0.04%</span>
                <span>. </span>
                <span className="body-emphasis" style={{ '--c': 'var(--hl-pink)' }}>세팔로스포린 교차반응</span>
                <span>은 1세대에서 약 10%.</span>
              </div>
              <div style={{ marginTop: 14, fontSize: 12.5, color: 'var(--subtle)' }}>
                형광펜 자국을 그대로 디지털로 — 본문 글자 아래 ~45% 높이의 색 띠.
              </div>
            </div>
          </div>
        </section>

        <div className="footnote">
          <div style={{ fontFamily: 'var(--font-mono)' }}>// Lumark Brand v0.1 — Icon · Wordmark · Color Usage</div>
          <div style={{ marginTop: 8 }}>
            다음 단계: 선택한 아이콘 방향을 1024 PNG로 export 후 <span className="mono">Assets.xcassets/AppIcon.appiconset</span>에 넣고,
            iOS가 자동으로 마스크와 다양한 크기를 처리하도록 함. iPad·앱스토어용은 별도 1024 슬롯에 동일 PNG.
          </div>
        </div>
      </div>

      <TweaksPanel title="Tweaks · Brand">
        <TweakSection label="브라운 톤" />
        <TweakSlider label="Hue (색조)" value={t.brownHue} min={20} max={90} step={1} unit="°"
                     onChange={(v) => setTweak('brownHue', v)} />
        <TweakSlider label="Chroma (채도)" value={t.brownChroma} min={0.02} max={0.10} step={0.005} unit=""
                     onChange={(v) => setTweak('brownChroma', v)} />

        <TweakSection label="iOS 마스크" />
        <TweakSlider label="모서리" value={t.iconRadius} min={10} max={32} step={0.5} unit="%"
                     onChange={(v) => setTweak('iconRadius', v)} />

        <TweakSection label="선택" />
        <TweakRadio label="추천 방향" value={t.preferredIcon}
                    options={['A', 'B', 'C']}
                    onChange={(v) => setTweak('preferredIcon', v)} />
      </TweaksPanel>
    </>
  );
}

ReactDOM.createRoot(document.getElementById('root')).render(<App />);
