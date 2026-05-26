// result-app.jsx
// Mounts a DesignCanvas with 4 iPhone artboards:
//   Section A (마크다운 탭)   →  Light, Dark
//   Section B (원본 PDF 탭)   →  Light, Dark
// Tweaks let the reviewer scrub the chip filter state across all four frames
// at once — handy for seeing how the four colors interact with both bodies.

const TWEAK_DEFAULTS = /*EDITMODE-BEGIN*/{
  "yellow": true,
  "orange": true,
  "pink": false,
  "blue": false,
  "interactive": false,
  "noteTitle": "항생제정리"
}/*EDITMODE-END*/;

// IOSDevice frame defaults (402×874) match iPhone 15 logical screen 393×852
// once you subtract the bezel — fine for our purposes.
const FRAME_W = 402;
const FRAME_H = 874;
// Add a bit of padding around each device so the DC artboard label has room
// and the device shadow doesn't get clipped.
const ART_W = FRAME_W + 36;
const ART_H = FRAME_H + 56;

function FramedScreen({ theme, tab, chips, interactive }) {
  return (
    <div style={{ width: ART_W, height: ART_H, display: 'flex', alignItems: 'center', justifyContent: 'center',
                  background: 'transparent' }}>
      <IOSDevice width={FRAME_W} height={FRAME_H} dark={theme === 'dark'}>
        <ResultScreen
          theme={theme}
          tab={tab}
          initialChips={chips}
          interactive={interactive}
          key={`${theme}-${tab}-${JSON.stringify(chips)}-${interactive}`}
        />
      </IOSDevice>
    </div>
  );
}

function App() {
  const [t, setTweak] = useTweaks(TWEAK_DEFAULTS);

  const chips = { yellow: t.yellow, orange: t.orange, pink: t.pink, blue: t.blue };
  const ix = t.interactive;

  return (
    <>
      <DesignCanvas style={{ minHeight: '100vh' }}>

        <DCSection id="md-tab"
                   title="A · 마크다운 탭"
                   subtitle="시그니처: 본문 좌측 2px 컬러 바. 비활성 색상은 28% 투명도로 dim — '필터'이지 '삭제'가 아니라는 점을 유지.">
          <DCArtboard id="md-light" label="A · Light" width={ART_W} height={ART_H}>
            <FramedScreen theme="light" tab="md" chips={chips} interactive={ix}/>
          </DCArtboard>
          <DCArtboard id="md-dark" label="A · Dark" width={ART_W} height={ART_H}>
            <FramedScreen theme="dark" tab="md" chips={chips} interactive={ix}/>
          </DCArtboard>
        </DCSection>

        <DCSection id="pdf-tab"
                   title="B · 원본 PDF 탭"
                   subtitle="PDF 페이지 위에 4색 highlight를 살짝 컬러 오버레이. 칩이 꺼지면 오버레이도 사라지지만 본문은 그대로.">
          <DCArtboard id="pdf-light" label="B · Light" width={ART_W} height={ART_H}>
            <FramedScreen theme="light" tab="pdf" chips={chips} interactive={ix}/>
          </DCArtboard>
          <DCArtboard id="pdf-dark" label="B · Dark" width={ART_W} height={ART_H}>
            <FramedScreen theme="dark" tab="pdf" chips={chips} interactive={ix}/>
          </DCArtboard>
        </DCSection>

      </DesignCanvas>

      <TweaksPanel title="Tweaks · ResultView">
        <TweakSection label="필터 칩 (4색)" />
        <TweakToggle label="노랑 (핵심)" value={t.yellow} onChange={(v) => setTweak('yellow', v)} />
        <TweakToggle label="주황 (주제)" value={t.orange} onChange={(v) => setTweak('orange', v)} />
        <TweakToggle label="분홍 (보충)" value={t.pink}   onChange={(v) => setTweak('pink', v)} />
        <TweakToggle label="파랑 (참고)" value={t.blue}   onChange={(v) => setTweak('blue', v)} />

        <TweakSection label="프로토타입" />
        <TweakToggle label="대화형 (탭/칩 클릭)"
                     value={t.interactive}
                     onChange={(v) => setTweak('interactive', v)} />
        <div style={{ fontSize: 11, color: 'rgba(41,38,27,.55)', lineHeight: 1.4, marginTop: -2 }}>
          켜면 각 프레임의 탭과 칩이 독립적으로 작동합니다.
          끄면 모든 프레임이 위 토글의 스냅샷을 보여줍니다.
        </div>
      </TweaksPanel>
    </>
  );
}

ReactDOM.createRoot(document.getElementById('root')).render(<App />);
