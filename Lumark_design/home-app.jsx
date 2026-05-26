// home-app.jsx
// DesignCanvas with 4 iPhone artboards:
//   Section A · 정상 상태  →  Light, Dark
//   Section B · Empty State →  Light, Dark
// Tweaks: brand name (for typography stress-test), brown hue, and a global
// state override that toggles all four frames between the two variants.

const TWEAK_DEFAULTS = /*EDITMODE-BEGIN*/{
  "brand": "Lumark",
  "brownHue": 58,
  "stateOverride": "per-section"
}/*EDITMODE-END*/;

const FRAME_W = 402;
const FRAME_H = 874;
const ART_W = FRAME_W + 36;
const ART_H = FRAME_H + 56;

function FramedHome({ theme, state, brand }) {
  return (
    <div style={{ width: ART_W, height: ART_H, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
      <IOSDevice width={FRAME_W} height={FRAME_H} dark={theme === 'dark'}>
        <HomeScreen theme={theme} state={state} brand={brand}/>
      </IOSDevice>
    </div>
  );
}

function App() {
  const [t, setTweak] = useTweaks(TWEAK_DEFAULTS);

  // Brown hue pushes into :root so the .hv-card.primary brown stays in sync
  // with the Design System reference value.
  React.useEffect(() => {
    const r = document.documentElement.style;
    r.setProperty('--brown', `oklch(0.43 0.060 ${t.brownHue})`);
    r.setProperty('--brown-2', `oklch(0.37 0.055 ${t.brownHue})`);
  }, [t.brownHue]);

  // stateOverride: when not "per-section", force all frames to A or B.
  const stateFor = (defaultState) => t.stateOverride === 'per-section' ? defaultState : t.stateOverride;

  return (
    <>
      <DesignCanvas style={{ minHeight: '100vh' }}>

        <DCSection id="loaded"
                   title="A · 정상 상태"
                   subtitle="최근 작업 카드가 누적되며 '내 학기 정리본'이 쌓이는 정서적 만족감. 형광펜 색은 dot 배지에서만 살짝 등장.">
          <DCArtboard id="loaded-light" label="A · Light" width={ART_W} height={ART_H}>
            <FramedHome theme="light" state={stateFor('A')} brand={t.brand}/>
          </DCArtboard>
          <DCArtboard id="loaded-dark" label="A · Dark" width={ART_W} height={ART_H}>
            <FramedHome theme="dark" state={stateFor('A')} brand={t.brand}/>
          </DCArtboard>
        </DCSection>

        <DCSection id="empty"
                   title="B · Empty State"
                   subtitle="첫 실행 직후. 갈색 단색 선화 일러스트(노트+형광펜) + 굿노트 연동 안내 CTA. 액션 카드는 동일하게 노출되어 즉시 시작 가능.">
          <DCArtboard id="empty-light" label="B · Light" width={ART_W} height={ART_H}>
            <FramedHome theme="light" state={stateFor('B')} brand={t.brand}/>
          </DCArtboard>
          <DCArtboard id="empty-dark" label="B · Dark" width={ART_W} height={ART_H}>
            <FramedHome theme="dark" state={stateFor('B')} brand={t.brand}/>
          </DCArtboard>
        </DCSection>

      </DesignCanvas>

      <TweaksPanel title="Tweaks · HomeView">
        <TweakSection label="브랜드" />
        <TweakText  label="이름"   value={t.brand}    onChange={(v) => setTweak('brand', v)} />
        <TweakSlider label="갈색 Hue" value={t.brownHue} min={30} max={80} step={1} unit="°"
                     onChange={(v) => setTweak('brownHue', v)} />

        <TweakSection label="상태" />
        <TweakRadio label="강제 상태" value={t.stateOverride}
                    options={[
                      { value: 'per-section', label: '섹션별' },
                      { value: 'A', label: '정상' },
                      { value: 'B', label: 'Empty' },
                    ]}
                    onChange={(v) => setTweak('stateOverride', v)} />
        <div style={{ fontSize: 11, color: 'rgba(41,38,27,.55)', lineHeight: 1.4, marginTop: -2 }}>
          섹션별: A섹션은 정상, B섹션은 Empty (기본). 정상/Empty: 모든 프레임을 동일 상태로.
        </div>
      </TweaksPanel>
    </>
  );
}

ReactDOM.createRoot(document.getElementById('root')).render(<App />);
