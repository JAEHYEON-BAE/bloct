# Bloct 알려진 버그와 권장 수정 순서

- 정리: **2026-11-12**. 미해결·조사 중 12개와 보류 1개, 최근 검증 완료 26·29·45·46·47·48·51·52·53·55·56번을 유지합니다. 이전 완료·제거된 경로의 기록은 Git 이력에 있고, 2026-11-10까지의 원시 증거는 `v2.0.1` 태그의 `Tests/results/`에 있습니다(저장소에는 최근 두 날짜 폴더만 유지).
- 기존 번호를 유지하며 다음 새 번호는 **57번**입니다. 검증 날짜·범위는 항목별 근거를 따르며 자동 검사와 실제 앱 검증을 구분합니다.
- 기능 계약·남은 수용 검증은 [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md), 검사 방법은 [Tests/README.md](Tests/README.md)를 따릅니다. 블록 편집 검사의 통과를 읽기 렌더러 버그의 해결 근거로 사용하지 않습니다.

## 권장 수정 순서

| 순서 | 대상 | 이유·완료 기준 |
|---|---|---|
| 1 | **4·17 — 코드 보호 → 2·13 — 서식·수식 → 7·8 — 제목·목차** | 코드 원문 보호를 먼저 확보한 뒤 읽기 렌더링과 탐색 정확성 수정 |
| 2 | **10 — 빈 문단 저장, 11 — PDF, 12 — 복사** | 현재 블록 편집 경로에서 먼저 재현. 의도된 빈 줄과 실제 결함, 가설을 구분한 뒤 수정 |
| 3 | **19 — 검색 키보드** | 문서 안내와 실제 키 동작 일치. 16번은 사용자 정책으로 보류 |

26·29·45번의 해당 종료 경로 검증은 완료했으며, [F5 수용 관문](IMPLEMENTATION_PLAN.md#다음-순서와-기본값-전환-관문)의 실제 IME·저장/외부 변경·기능 대응 검증을 최우선 개발 목표로 이어갑니다. 재현되지 않은 가설을 확정 버그로 처리하지 않습니다.

## 편집 키보드

<a id="bug-56"></a>

### 56. 코드 블록의 세로 커서가 길게 표시됨

- **검증 완료 / 2026-11-12.** 사용자 보고는 코드 박스를 벗어나는 세로 커서입니다. 실제 앱의 두 줄 코드 끝에서 수정 전보다 짧은 현재 줄 높이의 커서가 표시되도록 조정했습니다. [공통 CSS](Sources/Bloct/Resources/Web/style.css)의 `pre code`를 `display: block`으로 바꿔 여러 줄을 포함하는 inline 상자 대신 줄별 블록 배치를 사용합니다. 빈 코드의 한 줄 높이·padding·가로 스크롤·소스 내용은 유지합니다.
- **검증:** [Computer Use·원문·종료](Tests/results/2026-11-12/code-caret-gui.json)에서 빈 코드 입력, 두 줄/마지막 빈 줄·추가 입력, 긴 줄의 가로 스크롤 끝 커서, Undo·Save·닫기/재열기를 확인했습니다. 커서는 코드 박스 안에 있고, Undo 후 저장 원문은 byte 동일, 테스트 앱 종료·미리보기 잔류 0입니다. [시각 입력 382·브라우저 모델 18](Tests/results/2026-11-12/code-caret-visual.log)·[WebKit 963](Tests/results/2026-11-12/code-caret-webkit.log)·[격리 Debug 빌드](Tests/results/2026-11-12/code-caret-build.log) 통과, 실패/XFAIL/SKIP 0. 읽기/편집 모양은 light/dark·100/125% 배율 자동 비교도 통과했습니다.
- **한계:** native caret 내부 계산은 계측하지 않았으며 DOM 범위 검사는 실제 커서 그림을 대체하지 않습니다. GUI는 light/default zoom·ASCII이고 실제 IME·macOS 14·설치본/공개 Release는 미검증입니다.

<a id="bug-55"></a>

### 55. 제목의 Enter·Shift+Enter에서 독립적인 일반 줄 보장

- **검증 완료 / 2026-11-12.** H1~H6의 두 키를 같은 제목 종료 명령으로 처리합니다. 제목 시작이면 앞 일반 문단, 중간이면 앞쪽은 제목/뒤쪽은 일반 문단, 끝이면 뒤 빈 일반 문단으로 이동합니다. 빈 제목은 일반 문단으로 바꾸며 새 입력의 인라인 서식을 초기화합니다. 선택한 글자만 지우고 남은 제목·인용 컨테이너를 보존합니다. 기존에도 비어 있지 않은 최상위 제목의 기본 Enter/Shift+Enter는 연결돼 있었으나, 빈 제목에는 불필요한 Header가 남았고 시작 부분을 선택한 뒤 Enter하면 남은 제목까지 일반 문단으로 바뀔 수 있었습니다.
- **수정:** [keymap.ts](Editor/src/view/keymap.ts)의 `exitHeading`을 두 키가 공유합니다. 기본 `splitBlock`의 제목 타입 추론 대신 위치에 따라 명시적으로 일반 문단을 만들고 Undo 경계를 둡니다. 목록 내부 제목은 기존 목록 분할/탈출 정책을 유지합니다.
- **검증:** [수정 전 새 검사 12건 실패](Tests/results/2026-11-12/heading-enter-before.log)(빈 제목 잔류), 수정 후 [시각 입력 380·브라우저 모델 18](Tests/results/2026-11-12/heading-enter-visual.log)·[ContentView native 49](Tests/results/2026-11-12/heading-enter-native.log)·[격리 Debug 빌드](Tests/results/2026-11-12/heading-enter-build.log) 통과, 실패/XFAIL/SKIP 0. 새 검사는 H1~H6×두 키×시작/중간/끝/빈 제목/선택×최상위/인용의 후속 입력·Undo·Save/reimport를 확인합니다. [Computer Use·디스크·종료 감사](Tests/results/2026-11-12/heading-enter-gui.json)에서 H1~H6의 실제 키/선택·빈 H4 Shift+Enter/빈 H1 Enter·후속 일반 입력·Undo/Redo·Save/Esc/닫기/재열기·인용·두 문서/Don't Save를 확인했고, 저장 원문 일치·두 번째 파일 보존·앱 종료·미리보기 잔류 0입니다.
- **한계:** GUI는 ASCII이며 실제 IME·macOS 14·설치본/공개 Release는 미검증입니다. 이번 변경은 Enter/Shift+Enter 경로이며 여러 줄 붙여넣기/가져오기 정책은 바꾸지 않습니다.

<a id="bug-53"></a>

### 53. 수식 편집 창의 Undo/Redo가 문서 이력에 전달됨

- **검증 완료 / 2026-11-12.** 본문을 편집한 뒤 수식 창에서 ⌘Z/⇧⌘Z를 누를 때 문서 대신 해당 입력 초안만 되돌리도록 변경했습니다. 수정 전 소스의 `VisualEditor.history()`는 열린 창을 확인하지 않고 문서 이력을 호출했고, 네이티브 메뉴는 이력이 소진되면 문서 checkpoint까지 조회했습니다. 수정 전 실제 앱의 독립 재현은 수행하지 않았습니다.
- **수정:** [input-history.ts](Editor/src/view/input-history.ts)가 수식 창마다 값·커서·선택 영역의 이력을 관리하고 연속 입력/삭제를 묶습니다. 메뉴·단축키·`beforeinput`의 Undo/Redo를 이 이력에 전달하며, 이력이 비었거나 조합 중이어도 명령을 소비해 문서로 넘어가지 않습니다. Cancel/재열기는 초안 이력을 버리고, Apply는 기존처럼 문서 Undo 한 단계입니다. 공통 이미지 입력에도 같은 분리를 적용하며 읽기 전용 보호 원문 창은 명령만 소비합니다.
- **검증:** [Computer Use·디스크·종료 감사](Tests/results/2026-11-12/math-history-gui.json)에서 인라인/블록 수식의 입력·여러 줄·⌘Z/⇧⌘Z·Edit 메뉴·이력 소진·재열기 초기화·Cancel 후 본문 Undo·Apply 후 한 단계 Undo/Redo·Save/닫기/재열기·두 문서 분리를 확인했습니다. 저장 원문 일치, 두 번째 파일 원문 보존, 테스트 PID 종료·미리보기 잔류 0. [시각 입력 356·브라우저 모델 18](Tests/results/2026-11-12/math-history-visual.log)·[ContentView native 49](Tests/results/2026-11-12/math-history-native.log)·[격리 Debug 빌드](Tests/results/2026-11-12/math-history-build.log) 통과, 실패/XFAIL/SKIP 0. native 검사는 문서 checkpoint가 있는 상태의 빈 수식 이력 차단도 확인합니다.
- **한계:** 실제 GUI 입력은 ASCII이며 조합은 합성 이벤트의 묶음/차단 검사만 수행했습니다. 실제 IME·macOS 14·설치본/공개 Release는 미검증입니다. Cancel한 입력에도 제목에 Edited가 남는 50번은 별도 미해결이며 native 변경 횟수는 이번 수정 범위가 아닙니다.

<a id="bug-46"></a>

### 46. Esc 입력 시 macOS 경고음

- **검증 완료 / 2026-11-11.** 읽기 상태의 Esc와 수식 팝업의 기본 Esc 취소가 WebKit에서 미처리 키로 전달되어 AppKit의 `noResponderFor:keyDown:` 경고음 경로에 도달했습니다. 최소 재현은 문서를 열고 Esc 반복, 또는 수식 클릭 → Esc입니다. 편집 종료 자체의 Esc와 구분했습니다. [읽기 재현](Tests/results/2026-11-11/bug46-before-runtime.log)·[팝업 키 코드 53/호출 스택](Tests/results/2026-11-11/bug46-fixed-keys.log). 경고음 동작은 [Apple 이벤트 처리 문서](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/EventOverview/EventArchitecture/EventArchitecture.html)를 따릅니다.
- **수정:** 읽기에서도 Esc 기본 동작을 막되 모드 전환을 추가 요청하지 않습니다. 공통 수식/이미지/보호 원문 팝업은 Esc를 명시적으로 소비하고 Cancel로 닫습니다. 다음 Esc의 읽기 복귀, 초안·Undo·Save·viewport 보존과 조합/수정자 키 보호는 유지합니다.
- **검증:** [실제 앱·디스크·종료 감사](Tests/results/2026-11-11/bug46-gui.json)에서 Computer Use로 읽기 반복, 팝업 초안 폐기, 편집 종료, 검색창 닫기, Undo/저장/재열기, 두 문서 전환·닫기와 빈 문서를 확인했습니다. [최종 실제 Esc 19회](Tests/results/2026-11-11/bug46-final-keys.log)의 미처리 `keyDown` 0회, 종료 코드 0·미리보기 잔류 0·fixture 원문 복원. [모델/빌드 36개](Tests/results/2026-11-11/bug46-model.log)·[WebKit 963개](Tests/results/2026-11-11/bug46-webkit.log)·[시각 입력 332개/브라우저 모델 18개](Tests/results/2026-11-11/bug46-visual.log)·[native 41개](Tests/results/2026-11-11/bug46-native.log) 통과, 실패/SKIP 0.
- **한계:** 오디오 녹음 대신 원래 AppKit 동작을 유지하는 [계측](Tests/results/2026-11-11/bug46-event-probe.m)으로 재현된 경고음 경로의 차단을 확인했습니다. 2026-11-11 [공개 2.0.1 설치본](Tests/results/2026-11-11/release-2.0.1-installed.json)에서도 편집/읽기 Esc·수식 팝업 취소·Save/Undo를 확인했습니다. 실제 IME 조합·macOS 14 기기는 별도입니다.

<a id="bug-52"></a>

### 52. 닫은 굵게·기울임·인라인 코드가 뒤 입력에 이어짐

- **검증 완료 / 2026-11-12.** `**bold**tail`·`*em*tail`을 입력하면 닫는 표식 뒤 글자도 굵게·기울임이 됐습니다(입력 규칙이 서식만 적용하고 커서의 서식을 끊지 않음). 인라인 코드는 닫는 백틱 직후 입력만 처리돼 있어, 기존 코드 끝을 클릭하거나 화살표·Backspace로 코드 끝에 온 뒤 입력하면 코드에 붙었습니다([수정 전/후 비교](Tests/results/2026-11-12/mark-close-ime.log)의 D·E·F·H·K–N·P).
- **수정:** 굵게·기울임 입력 규칙이 닫을 때 해당 서식을 커서에서 뺍니다. 인라인 코드는 커서가 코드 바로 뒤에 놓이면 일반 글자를 입력하도록 했습니다([input-rules.ts](Editor/src/view/input-rules.ts)의 `codeBoundary`). 코드 안에서 시작한 편집(Mod-e로 켠 입력, 코드 안 삭제)과 IME 조합 트랜잭션은 건드리지 않으며, 코드 뒤에서 Mod-e를 누르면 그 코드를 이어 씁니다. 표식으로 닫지 않은 기존 굵게·기울임 끝에서의 입력은 전처럼 서식을 잇습니다.
- **검증:** [Computer Use](Tests/results/2026-11-12/mark-close-gui.json)에서 기존 코드 끝 입력, 새로 닫은 코드·굵게·기울임 뒤 입력, 화살표·Backspace로 코드 끝에 온 뒤 입력, Save한 디스크 원문과 재열기 후 입력을 확인했습니다. 한글 조합은 [WKWebView 입력 클라이언트 프로브](Tests/results/2026-11-12/mark-close-ime-probe.swift) 19개 시나리오로 확인(코드·굵게 뒤 조합, Mod-e/Mod-b 조합 유지). [시각 입력 350·브라우저 모델 18](Tests/results/2026-11-12/mark-close-visual.log)·모델 61·WebKit 963·Hosted 269·native 통과, 실패/SKIP 0.
- **한계:** Computer Use 도구가 한글 IME를 구동하지 못해 실제 IME 키 입력은 미검증입니다(프로브는 IME가 쓰는 `setMarkedText`/`insertText` 경로를 직접 호출). 공백 뒤에서 Mod-e를 켜면 앞 공백이 코드에 포함되는 것은 수정 전부터의 동작입니다. 테스트 앱은 SIGTERM으로 종료해 Quit 종료 코드·미리보기 정리는 이번 검증 범위가 아닙니다. macOS 14 기기 미검증.

## 저장 표기

<a id="bug-47"></a>

### 47. 편집한 블록의 저장 거절·과도한 이스케이프

- **검증 완료 / 2026-11-11.** 수정 전 URL·이메일·문자 참조 입력, 중첩/겹친 서식 편집에서 Save·Esc가 거절되고 문장부호·공백이 과도하게 이스케이프됐습니다([PROJECT_REVIEW.md](PROJECT_REVIEW.md) 2.2·2.3·3.1·3.2·3.4).
- **수정:** 인라인을 `mdast-util-to-markdown` 2.2.1로 쓰고 mark 구간을 함께 감쌉니다. 블록 뼈대·미변경 원문 재사용·체크 한 글자 패치·왕복 검증은 유지합니다. URL 텍스트는 GFM 재파싱 시 자동 링크가 되므로 이를 같은 의미로 비교하되 기존 링크의 위치·주소를 보존합니다. 공백·줄바꿈의 정규화와 블록별 표기 선택은 [F5 계약 3](IMPLEMENTATION_PLAN.md#유지할-설계보존-계약)을 따릅니다.
- **검증:** [Computer Use·자동 회귀](Tests/results/2026-11-11/review-gui.json)에서 URL/이메일/문자 참조 실제 입력, 서식 뒤 공백·겹친 굵게/기울임 적용, 중첩 서식·코드·링크 편집, 리터럴 취소선/참조/통화 표기, CRLF 제목/목록/체크/표의 Save·Esc·재열기와 Undo/Redo를 확인했습니다. [저장 원문 비교](Tests/results/2026-11-11/review-gui-disk.json) 통과. 미사용 검색·복사 코드 제거 후 읽기/편집 검색과 실제 서식 복사/붙여넣기도 통과했습니다. 같은 소스의 격리 앱 빌드·모델 50개(시드 3개×700회 무작위 초안 포함)·브라우저 모델 18개/시각 입력 338개·WebKit 963개·Hosted 269개·native 41개·이미지 69개 통과, 실패/SKIP 0. 새 문서 최초 저장·다중 문서 전환/닫기·[Quit 종료 코드 0/미리보기 잔류 0/새 충돌 0](Tests/results/2026-11-11/review-gui-exit.json) 확인.
- **한계:** `<`로 시작하는 링크 주소와 표 셀·제목 안의 줄바꿈은 여전히 저장이 거절됩니다. `**한글(영어)**은`처럼 문장부호로 끝나는 강조 뒤에 글자가 붙으면 CommonMark 규칙상 뒤 글자를 `&#x…;` 참조로 씁니다. 취소선 안의 다른 서식은 이스케이프됩니다. 목록·표 전체를 표준 표기로 다시 쓰던 한계는 [51번](#bug-51)에서 원문 표기 유지로 대체했습니다. 실제 IME·macOS 14 기기는 미검증입니다. `run-menu-polling.sh`의 수정 전부터 알려진 3건 실패(리소스 누락)는 이번 검사에서 제외했습니다.

<a id="bug-51"></a>

### 51. 수식 줄바꿈·작성자 표기가 저장 때 바뀜

- **검증 완료 / 2026-11-12.** 수정 전 실제 앱에서 `See $$a = 1` Shift+Enter `b = 2$$`를 입력하면 줄바꿈이 U+FFFC(화면의 `OBJ` 상자)로 바뀌어 저장됐습니다(입력 규칙이 줄바꿈 노드를 대체 문자로 읽음). `$$a` Enter `b$$`는 구분자를 별도 줄로 옮겨 저장했고, 기존 블록을 편집하면 `_em_`→`*em*`, setext→ATX, `~~~`→```` ``` ````, 표 간격, `$$ a $$`→`$$a$$`처럼 블록 전체가 표준 표기로 바뀌었습니다(모델 재현).
- **수정:** 수식 입력 규칙은 줄바꿈을 TeX의 `\n`으로 넣고 다른 인라인 노드가 끼면 변환하지 않습니다. 수식 값은 줄바꿈·안쪽 공백을 그대로 두고(CRLF는 `\n`으로 읽어 파일의 줄 끝으로 씀), 블록 수식의 구분자 줄 배치(`openLine`/`closeLine`)와 `$$ x $$`의 여백(`pad`)을 표기 속성으로 저장합니다. 파일에 있던 블록을 다시 쓸 때는 이전/현재 블록의 표준 표기 차이(편집)를 원문에 3방향 병합한 후보를 먼저 쓰고([preserve.ts](Editor/src/model/preserve.ts)), 재파싱 의미가 같을 때만 채택합니다. 아니면 기존 표준 표기로 씁니다([F5 계약 3](IMPLEMENTATION_PLAN.md#유지할-설계보존-계약)).
- **검증:** [Computer Use](Tests/results/2026-11-12/math-spelling-gui.json)에서 문단·인라인/블록 수식·setext·`~~~`·압축 표에 실제 입력 후 Save한 디스크 차이가 순수 삽입뿐임을 확인했습니다. 새로 입력한 두 수식은 줄바꿈·들여쓰기·같은 줄 구분자를 유지했고 U+FFFC가 없으며 KaTeX 렌더링·Esc 읽기·재열기 동일. 수식 창의 줄 추가·Undo 후 원문 복원·Don't Save·두 문서·Quit 종료와 미리보기 정리 확인. [모델 61·번들](Tests/results/2026-11-12/math-spelling-model.log)·[브라우저 모델 18](Tests/results/2026-11-12/math-spelling-engine.log)·[시각 입력 342](Tests/results/2026-11-12/math-spelling-visual.log)·[native 8](Tests/results/2026-11-12/math-spelling-native.log)·[WebKit 963](Tests/results/2026-11-12/math-spelling-webkit.log)·[Hosted 269](Tests/results/2026-11-12/math-spelling-hosted.log)·[visual native 41](Tests/results/2026-11-12/math-spelling-visual-native.log) 통과, 실패/XFAIL/SKIP 0.
- **한계:** 새로 만든 블록·분할로 생긴 뒤쪽 블록은 표준 표기로 씁니다(수식의 구분자 배치·여백만 유지). 편집과 작성자 표기가 같은 글자에 겹치면 그 구간은 표준 표기가 되며, 차이가 2000 편집을 넘는 블록은 병합하지 않습니다. 수식 안 줄바꿈 뒤 줄이 `+ `·`- `·`#`처럼 블록 시작으로 읽히면 Markdown 구조가 바뀌므로 저장이 거절되고 초안이 유지됩니다. `$ x $` 양끝 공백은 [13번](#읽기-렌더링탐색) 범위입니다. 실제 IME·macOS 14 기기는 미검증입니다.

<a id="bug-48"></a>

### 48. 같은 종류의 강조가 중첩된 문서에서 편집 엔진 생성 실패

- **검증 완료 / 2026-11-11.** `*a *b* c*`, `**a **b** c**`의 중첩 강조를 배열에 중복 추가해 `Invalid collection of marks for node text: em,em`으로 엔진 생성이 실패했습니다. importer에서 mark를 집합으로 추가하도록 수정했습니다([모델 검사](Editor/test/unit/serializer.test.ts)).
- **실제 앱:** [Computer Use](Tests/results/2026-11-11/review-gui.json)에서 위 두 형태와 `*a **b *c* d** e*`가 함께 있는 문서를 열고 각 문단에 실제 입력·Save·Esc·닫기/재열기를 확인했습니다. [화면](Tests/results/2026-11-11/review-gui-formatting.png)·[저장 원문 비교](Tests/results/2026-11-11/review-gui-disk.json) 통과. 수정 전 GUI 증상은 독립 재현하지 않았으며 수정 전 모델 예외와 수정 후 실제 앱 동작을 구분합니다.

## 종료·파일 정리

<a id="bug-45"></a>

### 45. 창 닫기 중 native 예외·비정상 종료

- **검증 완료 / 2026-11-10.** `CloseProxy`가 원래 delegate의 `windowWillClose`를 전달한 뒤에도 AppKit의 알림 수신자로 남아, 종료 중 원래 delegate가 더 이상 광고하지 않는 selector로 알림이 오면 예외가 발생할 수 있었습니다. 종료 시 프록시의 delegate 등록을 먼저 해제하고 원래 delegate에 한 번 전달하도록 수정했습니다. 뷰의 창 이동·해제 시에는 기존 delegate를 복원하며 지연 설치도 취소합니다.
- **회귀 근거:** [수정 전](https://github.com/JAEHYEON-BAE/bloct/blob/v2.0.1/Tests/results/2026-11-10/bug45-before.log)·[종료 코드 -6](https://github.com/JAEHYEON-BAE/bloct/blob/v2.0.1/Tests/results/2026-11-10/bug45-before-exit.json): 동적 delegate가 종료 중 `windowDidResize:` 광고를 중단하면 같은 미인식 selector 메커니즘으로 SIGABRT. [수정 후 9개](https://github.com/JAEHYEON-BAE/bloct/blob/v2.0.1/Tests/results/2026-11-10/bug45-window-close.log)·[ContentView native 41개](https://github.com/JAEHYEON-BAE/bloct/blob/v2.0.1/Tests/results/2026-11-10/bug45-visual-native.log)·[앱 빌드](https://github.com/JAEHYEON-BAE/bloct/blob/v2.0.1/Tests/results/2026-11-10/bug45-build.log) 통과.
- **실제 앱:** [Computer Use·디스크·종료 감사](https://github.com/JAEHYEON-BAE/bloct/blob/v2.0.1/Tests/results/2026-11-10/bug45-gui.json)에서 깨끗한 편집 창 닫기, Cancel 후 추가 입력, Don't Save 원문 보존, Save/재열기, 두 창 전환·Quit 취소/저장/폐기를 확인했습니다. 프로세스 종료 코드 0, 새 충돌 보고서·미리보기 잔류 0.
- **한계:** [2026-11-08 원래 충돌](https://github.com/JAEHYEON-BAE/bloct/blob/v2.0.1/Tests/results/2026-11-08/window-close-crashes.json)의 private `windowDidOrderOffScreen:` receiver는 독립 식별하지 못했으며 수정 전 일반 앱의 닫기·폐기에서는 재현되지 않았습니다. 위 회귀는 같은 전달 실패 조건의 통제된 재현입니다. macOS 14 기기·실제 IME·설치본/공개 Release와 26번 Finder 경합은 별도입니다. 정상 Quit cleanup의 현재 검증은 29번을 따릅니다.

### 29. 앱 메뉴 Quit 후 고유 미리보기 파일 잔류

- **검증 완료 / 2026-11-10.** 최초 미리보기 생성 때 `PreviewFiles`가 `NSApplication.willTerminateNotification`을 직접 등록하고 종료 전에 소유 파일만 동기 삭제하도록 변경했습니다. AppDelegate의 종료 콜백 전달·문서 뷰 해제에 의존하지 않으며, Quit 취소 시에는 삭제하지 않습니다. 기존 파일/다른 세션 파일은 보존하고 삭제 실패의 소유권·재시도 정책은 유지합니다.
- **회귀 근거:** AppDelegate 종료 cleanup을 전달하지 않는 실제 AppKit 프로세스 3개에서 [수정 전](https://github.com/JAEHYEON-BAE/bloct/blob/v2.0.1/Tests/results/2026-11-10/bug29-before.log) 잔류 1·2·2개, [수정 후](https://github.com/JAEHYEON-BAE/bloct/blob/v2.0.1/Tests/results/2026-11-10/bug29-termination.log) 모두 0개. Quit 취소 중 두 파일 유지와 기존 파일 보존도 통과. [native 8개](https://github.com/JAEHYEON-BAE/bloct/blob/v2.0.1/Tests/results/2026-11-10/bug29-native.log)·[ContentView native 41개](https://github.com/JAEHYEON-BAE/bloct/blob/v2.0.1/Tests/results/2026-11-10/bug29-visual-native.log)·[앱 빌드](https://github.com/JAEHYEON-BAE/bloct/blob/v2.0.1/Tests/results/2026-11-10/bug29-build.log) 통과.
- **실제 앱:** [Computer Use·프로세스/디스크 감사](https://github.com/JAEHYEON-BAE/bloct/blob/v2.0.1/Tests/results/2026-11-10/bug29-gui.json): 읽기 문서를 연 채 앱 메뉴 Quit, 두 문서 전환/개별 닫기/재열기 후 직접 Quit, 변경된 두 문서의 Quit 취소/추가 입력/Save/Don't Save 확인. 세 프로세스 모두 종료 코드 0·소유 미리보기 잔류 0·새 충돌 보고서 0이며 저장/폐기 원문·사용자/다른 세션 파일 보존 확인.
- **한계:** [2026-11-05 잔류 관찰](https://github.com/JAEHYEON-BAE/bloct/blob/v2.0.1/Tests/results/2026-11-05/bug27-28-gui.json)의 정확한 delegate 호출 경로는 미계측이며 현재 수정 전 정상 앱의 읽기 Quit에서는 재현되지 않았습니다. 콜백 전달 누락 조건은 위 별도 프로세스로 검증했습니다. 강제 종료/충돌·OS 삭제 권한 오류 복구·macOS 14 기기·설치본/공개 Release와 26번 Finder 경합은 별도입니다.

### 26. GUI 테스트 중 Finder “Bloct is not open anymore”

- **검증 완료(확인된 자동화 경합 방지) / 2026-11-11.** Quit 직후 이전 앱 핸들의 `getAXState()`가 종료 중인 프로세스로 재활성화 이벤트를 보내는 흐름에서 `-600 procNotFound`가 기록됐습니다. 당시 주 프로세스 종료 5회는 정상입니다([2026-10-26 원시 로그](https://github.com/JAEHYEON-BAE/bloct/blob/v2.0.1/Tests/results/2026-10-26/finder-quit-race.log)). 앱의 종료 코드를 바꾸지 않고 [GUI 세션 도구](Tests/GUI/gui-session.mjs)가 최종 Quit 동작을 보내기 **전에** 핸들을 폐기하도록 수정했습니다. 대기 중·응답 오류·저장된 옛 핸들의 후속 조회/입력은 CUA 호출 전에 거절합니다. 새 연결은 별도 PID 종료 확인 후 명시적 앱 경로로 만듭니다([사용법](Tests/README.md#gui-session-lifetime)).
- **검증:** [자동 회귀 4개](Tests/results/2026-11-11/bug26-session.log)와 [Computer Use 3회](Tests/results/2026-11-11/bug26-gui.json). 두 문서의 편집 창 닫기 후 남은 창 응답, Quit 취소/추가 입력/저장/폐기, 종료 후 새 세션·Finder 재실행, 저장 문서 재열기를 확인했습니다. 세 번 모두 옛 핸들 접근 차단, [실제 PID 종료·미리보기 잔류 0](Tests/results/2026-11-11/bug26-process.json), [주 프로세스 정상 종료 `(0,0,0)`·관련 `procNotFound` 0](Tests/results/2026-11-11/bug26-system.log), Finder 오류 팝업 관찰 0입니다.
- **창 없음과 한계:** 마지막 창 닫기 후 `noWindowsAvailable`은 현재 재현했으며 같은 PID에서 ⌘N으로 정상 복귀했습니다. 이를 앱 종료·deadlock으로 처리하지 않습니다. [2026-11-07 지속 `timeoutReached`·잔류](https://github.com/JAEHYEON-BAE/bloct/blob/v2.0.1/Tests/results/2026-11-07/aa-only-gui.json)와 [idle 샘플](https://github.com/JAEHYEON-BAE/bloct/blob/v2.0.1/Tests/results/2026-11-07/aa-only-process-sample.txt)의 정확한 CUA 원인은 미확정이고 이번에는 재현되지 않았습니다. 원래 Finder 팝업 자체의 독립 재현·캡처도 없으므로 모든 CUA/LaunchServices 오류 해결을 의미하지 않습니다. 도구 밖의 raw 핸들은 보호하지 않으며 재발 시 PID·남은 창·CUA 호스트 오류를 함께 수집해 이 항목을 다시 엽니다. 45번의 native 충돌과 구분합니다.
- 별도 설치 제한: 당시 설치본은 ad-hoc 서명·quarantine으로 Gatekeeper에 차단됐으며, 사용자 승인으로 격리 속성만 제거해 Open 창 실행을 확인했습니다. 재다운로드 시 같은 제한이 생길 수 있습니다. [근거](https://github.com/JAEHYEON-BAE/bloct/blob/v2.0.1/Tests/results/2026-10-26/finder-launch-investigation.json).

## 읽기 렌더링·탐색

아래는 기존 재현 보고·소스 확인에 따른 미해결 항목입니다. 현재 앱에서의 재현 범위부터 확인합니다.

| # | 증상·최소 재현 또는 확인 근거 | 다음 조치 |
|---|---|---|
| **4** | 코드 보호가 같은 길이의 닫는 펜스만 인정해 더 긴 닫는 펜스에서 보호 실패 | 분할기와 보호 판정을 맞추고 긴/미종결 펜스의 원문 보존 검사 |
| **17** | 이미지 확장이 코드 보호보다 먼저 실행되고 들여쓰기 코드는 수식 전처리에서 보호되지 않음 | 코드 안 이미지·수식 문법을 리터럴로 유지하고 렌더링·편집 전환·저장 검사 |
| **2** | `noStrikethrough`가 물결표 사이 전체를 소비해 굵게·링크·코드를 파싱하지 않음. 예: `3~5 **중요** 7~9` | 물결표 자체만 리터럴로 소비하도록 검토 |
| **13** | **미해결 / 2026-11-12 소스·모델 재현.** `$ 270{,}822 \text{ bps} \div 8 = 33{,}854 \text{ bps} $`가 일반 텍스트로 남음. 파서는 `inlineMath`로 인식하지만 [importer.ts](Editor/src/model/importer.ts)의 양끝 공백 거부 조건이 텍스트로 되돌리며, [input-rules.ts](Editor/src/view/input-rules.ts)의 입력 규칙도 같은 조건으로 변환을 거부함. 한쪽 공백만 있어도 발생하고 양끝 공백 제거 시 변환됨. 본문·공백 포함 본문의 KaTeX 렌더링은 정상([프로브](Tests/results/2026-11-12/inline-math-space-probe.mjs)·[결과](Tests/results/2026-11-12/inline-math-space-probe.json)). 기존 `가격 $5 와 $10 표기` 통화 오인 보고는 호환 렌더러 범위로 남기며 현재 importer에는 리터럴 유지 검사가 있음 | 통화 보호와 양끝 공백을 허용할 수식의 구분 정책을 정하고 import·직접 입력을 함께 수정·검사. 이번 조사는 코드 수정·실제 앱 GUI/키 입력 검증 없음 |
| **7** | 수식 제목의 `textContent`에 MathML·annotation·HTML 텍스트가 중복되어 ID·목차도 중복 | 의미 텍스트를 한 번 추출해 ID·목차에 공통 사용 |
| **8** | 같은 제목의 ID가 같고 목차 직접 스크롤 뒤 전역 앵커 처리기가 첫 ID로 다시 이동할 수 있음 | 문서 전체의 고유 ID·단일 이동 경로 보장. 접미사와 다른 제목의 충돌도 검사 |

빈 줄은 독립 파싱·목록 그룹 경계입니다. 목록 번호 재시작·들여쓰기 블록의 독립 렌더링은 정상 동작이므로 위 수정에서 병합하지 않습니다. [정책 fixture](Tests/fixtures/bug-16-block-context.md).

## 현재 경로 재현·검증이 필요한 항목

| # | 상태·증상 | 다음 조치 |
|---|---|---|
| **10** | **미해결, 블록 편집 재현 필요.** 옛 추가 영역에서 입력 후 전부 지워도 빈 줄이 저장된 보고. 해당 경로는 제거됐으나 블록 편집기의 빈 최상위 문단은 Markdown gap으로 저장됨 | 무편집/입력 후 삭제/의도적 빈 블록 생성을 나눠 원문·dirty·Undo·저장/재열기 비교 |
| **11** | **미해결, 실제 PDF 검증 필요.** 목차·편집 UI·검색 강조·화면용 여백이 포함되거나 본문이 누락될 가능성 | 읽기/편집·미저장 초안의 실제 PDF를 확인하고 출력 준비·인쇄 CSS 보완 |
| **12** | **가설, 현재 블록 편집 재현 필요.** 전역 copy 처리기가 편집기 선택을 가로챌 가능성. 과거 textarea 경로는 제거됐으며 합성 미리보기 copy 검사는 이 가설의 증거가 아님. 2026-11-11 호환 렌더러의 전역 copy 처리기(편집 엔진이 있으면 항상 즉시 반환)와 그 합성 검사를 제거 | 편집 중 부분 선택·줄바꿈·Unicode를 실제 클립보드의 Markdown/일반 텍스트/HTML과 비교 |
| **49** | **미해결, 1회 관찰 / 2026-11-12.** 코드 블록에 `code` 입력 → Save → Esc 뒤 macOS 자동 수정이 `Code`로 바꿔 저장 직후 문서가 다시 dirty가 됨(닫을 때 Unsaved Changes, 저장하면 그 한 단어만 변경). [관찰](Tests/results/2026-11-12/tight-separators-gui.json) | 코드 블록·읽기 상태에서 자동 수정·맞춤법 대치가 적용되는 조건을 재현하고 차단. 일반 문단의 자동 수정 정책과 구분 |
| **50** | **미해결 / 2026-11-12.** 편집 후 Undo로 저장 상태까지 되돌려도 제목 표시줄의 Edited가 남음. 닫기는 경고 없이 진행되므로 편집기의 dirty 판정은 정상. 설치된 2.0.1에서도 같은 순서(문단 끝 Enter → `## Temp` → Undo 4회)로 재현. 수식 편집 창에 입력 후 Cancel해도 원문 변경 없이 Edited가 켜지고 Save로 꺼짐(2026-11-12 [관찰](Tests/results/2026-11-12/equation-dialog-gui.json); 가설: WebKit 입력 칸의 Undo가 창의 Undo 관리자에 등록됨) | 편집기의 clean 통지와 창의 `isDocumentEdited`·NSDocument 변경 횟수 동기화 확인 |

## 낮은 우선순위·보류

### 19. 검색 키보드 안내와 동작 불일치

- **미해결 / 기존 소스 확인.** Return은 항상 다음 검색이며 Shift+Return·↑/↓ 이동이 없어 README 안내와 다릅니다. 실제 키 입력으로 확인한 뒤 구현 또는 안내를 일치시킵니다.

### 16. 별도 정의 참조 링크 — 보류

- **보류 / 2026-10-17 사용자 정책.** 정의 확인·편집 UI와 교차 블록 해석을 함께 설계하며 [F4](IMPLEMENTATION_PLAN.md#f4-별도-정의-참조-링크--보류) 재개 전에는 구현하지 않습니다. 현재는 직접 주소 링크를 사용합니다.
- 옛 textarea의 정의 접근 단축키는 현재 경로의 지원 근거로 사용하지 않습니다. 빈 줄 경계 정책은 유지합니다.
