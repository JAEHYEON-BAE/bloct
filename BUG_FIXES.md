# Bloct 오류·버그 및 수정 기록

- 최신화: **2026-11-06** — Aa 표의 빈 셀 안내 문구(35번)를 제거하고 자동/GUI 검증했습니다.  최우선 개발 목표는 F5의 Notion 방식 편집 전환입니다. Aa 전환의 페이지 재로드·스크롤 왕복·좌우 정렬 차이(34번)를 수정하고 주요 블록의 같은 페이지 전환을 검증했습니다. 30~33번의 이전 검증도 유지합니다. GUI 정리에서 확인한 메뉴 Quit 후 미리보기 잔류는 29번에서 별도로 조사합니다. 기존 항목 상태·과거 날짜는 유지합니다.
- 현재: 총 35개 중 **19개 해당 범위 검증 완료**, **16번 보류**, **15개 미해결·조사 중**. 구현 요약·새 기능 계획은 [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md), 기록 정책은 [AGENTS.md](AGENTS.md)를 따릅니다.
- 다음 순서: **[F5 시각 편집기의 IME·기존 기능 대응 검증](WYSIWYG_BLOCK_PLAN.md#9-구현-순서와-단계별-산출물)**을 최우선으로 진행합니다. 기존 버그는 새 모델의 관련 검증에 연결하며, 기존 경로를 별도 수정할 때의 순서는 **4·17번 → 2·7·8·13번 → 3·5·9·10번 → 11·12·19번**입니다. 26번의 새 GUI 절차 검증은 다음 GUI 작업에서 수행합니다. 다음 새 버그 번호는 36번입니다.

## 항목별 상태

번호와 확인 수준을 유지합니다. 과거 Node/WebKit 보고·정적 코드 확인은 현재 앱의 실제 이벤트 재현과 구분합니다. 완료는 해당 검사 범위의 판정이며 앱 전체 무결함을 뜻하지 않습니다.

| # | 문제 | 현재 상태 | 우선순위·근거 |
|---|---|---|---|
| 1 | Undo/Redo와 저장 문서 불일치 | 수정·재검증 완료(2026-10-15) | 전용 Undo·저장 전 버퍼 분리, 실제 GUI 연속 Undo/Redo·저장·폐기 통과 |
| 2 | 물결표 사이 서식 소실 | 미해결 | 중간 / 기존 Node·WebKit 보고, tokenizer 유지 |
| 3 | 편집 후 다른 블록을 두 번 클릭해야 열림 | 미해결, 실제 이벤트 재현 필요 | 중간 / 이전 앱 관찰, blur와 DOM 교체 경쟁 가설 |
| 4 | 더 긴 닫는 펜스의 코드 보호 실패 | 미해결 | 중간 / 기존 재현, 보호 정규식 유지 |
| 5 | 새 문서 첫 입력 앞에 빈 줄 추가 | 미해결 | 중간 / 기존 WebKit 보고, 빈 문자열 분할 로직 유지 |
| 6 | 저장 결과 전에 변경 상태 해제·닫기 | 수정·재검증 완료(2026-10-15) | 스냅샷 저장, 실제 취소·실패·재저장·다중 창 종료 통과 |
| 7 | 수식 제목의 ID·목차 텍스트 중복 | 미해결 | 중간 / 이전 WebKit 보고, textContent 사용 유지 |
| 8 | 중복 제목 ID와 앵커 이동 충돌 | 미해결 | 중간 / ID 생성·이벤트 전파 코드 확인 |
| 9 | 목차 빈 영역 클릭이 추가 편집기를 엶 | 미해결 | 중간 / 이전 WebKit 보고 |
| 10 | 추가 영역에 입력 후 지워도 빈 줄 추가 | 미해결 | 중간 / 이전 WebKit 보고 |
| 11 | PDF에 목차·편집 UI·화면용 여백 포함 가능 | 미해결, 실제 출력 검증 필요 | 중간 / 인쇄 준비·CSS 코드 확인 |
| 12 | textarea 복사를 전역 copy 처리기가 가로챌 가능성 | 가설, 재현 필요 | 중간 / 실제 선택·클립보드 검사 미완료 |
| 13 | 통화 표기를 수식으로 오인 | 미해결 | 중간 / 이전 WebKit 보고 |
| 14 | 비신뢰 HTML 이벤트와 브리지 노출 | 구현 완료 `ac191f7` | 높음 / 정화·CSP·탐색·브리지 테스트 |
| 15 | 원문과 내부 자리표시자 충돌 | 구현 완료 `ac191f7` | 높음 / 원문·수식·코드 혼합 회귀 테스트 |
| 16 | 별도 정의 참조 링크의 확인·편집 및 지원 방식 | **보류(2026-10-17 사용자 정책)** | 정의 관리 수단 선행. 빈 줄의 목록·문단 분리는 정상 동작이며 수정 대상 제외 |
| 17 | 코드 안의 이미지·수식 문법 전처리 | 미해결 | 중간 / 기존 재현, 전처리 순서·코드 판정 한계 유지 |
| 18 | 공유 미리보기 파일 덮어쓰기·삭제 | 구현 완료 `f062c65` | 높음 / 고유 파일 및 소유권 기반 정리 테스트 |
| 19 | README의 검색 키보드 조작과 불일치 | 미해결 | 낮음 / Return modifier·방향키 처리 코드 확인 |
| 20 | 초기 이중 로드가 정책에 막혀 빈 화면 | **수정·해당 범위 검증 완료(2026-10-22)** | v1.7.6. 초기 탐색 단일화·최신 원문 반영·콜백 식별. Hosted 208 통과, XFAIL·SKIP 0 |
| 21 | 외부 문서 변경이 편집 상태에 반영되지 않음 | **구현·해당 범위 검증 완료(2026-10-17)** | `⌘R`·우클릭 Reload·자동 갱신·저장 충돌·삭제/폐기 보호. 아래 실제 GUI/디스크 근거와 미검증 범위 참조 |
| 22 | Release의 Homebrew tap 자동 갱신 실패 | 대체 자동화 배포·검증 완료(2026-10-15) | tap 자체 GITHUB_TOKEN 기반 동기화, 실제 Actions 검사·변경 없는 push 성공. 2026-10-17 수동 동기화에서 실제 1.7.3 변경 커밋도 확인. 예약 시점은 별도 미검증 |
| 23 | 로컬·Homebrew 배포 SDK 불일치 | 구현·배포 검증 완료(2026-10-15) | v1.7.2 공개 ZIP의 두 CPU 모두 SDK 27.0·최소 OS 14.0 검증, 원격 cask 갱신 |
| 24 | 상위 상대경로·쓰기 금지 폴더의 이미지 로드 실패 | **검증 완료(2026-10-17)** | 이미지 전용 로더. 기본 54/54, 전용 총 70개 통과 및 GUI 표시·편집·저장·재열기 확인 |
| 25 | Edit·Window 메뉴의 지속적인 깜빡임·선택 어려움 | **검증 완료(2026-10-22)** | v1.7.5. 자동·GUI 회귀 통과 및 사용자 직접 확인으로 깜빡임 해결 확인 |
| 26 | GUI 테스트 중 Finder “Bloct is not open anymore” | **조사 중(2026-10-26)** | 종료 직후 재활성화 이벤트의 `-600 procNotFound` 확인. 자동화 절차 보완, 반복 재검증 대기 |
| 27 | Aa 전환 시 수식 폰트·형태 변경 | **수정·해당 범위 검증 완료(2026-11-05)** | font-face 변환 경계 수정·공유 오프라인 KaTeX, 11개 수식 폰트/크기 비교 |
| 28 | 본문이 구분자와 붙은 display 수식의 첫 줄 누락·뒤 문서 흡수 | **수정·해당 범위 검증 완료(2026-11-05)** | 토큰 기반 $$ 경계, 행렬 원문·후속 문서·Edit/저장/재열기 확인 |
| 29 | 앱 메뉴 Quit 후 고유 미리보기 파일 잔류 | 조사 중(2026-11-05) | 격리 앱 두 실행에서 프로세스 종료 후 각각 1개 잔류. 문서 닫기 경로와 종료 cleanup 비교 필요 |
| 30 | 인라인 코드 종료 후 후속 입력도 코드 서식 | 수정·해당 범위 검증 완료(2026-11-05) | stored code mark 제거, 시각 입력 회귀 통과 |
| 31 | 블록 입력 변환 취소 후 다음 줄로 커서 이동 | 수정·해당 범위 검증 완료(2026-11-05) | 입력 규칙의 원래 위치로 selection 복원 |
| 32 | Aa 편집 후 버튼 비활성화로 모드 재진입 불가 | 수정·해당 범위 검증 완료(2026-11-05) | 미저장 스냅샷 전달·원본 저장 기준·Undo checkpoint 보존 |
| 33 | 빈 $$에 Space만 입력해도 Equation 생성 | 수정·해당 범위 검증 완료(2026-11-05) | 여는 구분자 단축키 제거, 본문·닫는 $$를 확인해 블록 변환 |
| 34 | Aa 전환 시 상단으로 이동 후 복귀·본문 좌우 정렬 변경 | 수정·해당 범위 검증 완료(2026-11-05) | 같은 WebView/페이지 유지, 공통 스타일·가시 블록 위치 보존 |
| 35 | Aa 표의 빈 셀에 불필요한 Cell 안내 표시 | 수정·해당 범위 검증 완료(2026-11-06) | 셀 placeholder 제외, 자동/GUI 입력·저장 확인 |

## 35. Aa 표의 빈 셀 안내 문구

- **2026-11-06 / 수정·해당 범위 검증 완료.** 표의 빈 셀에 회색 `Cell`이 표시됐습니다. 시각 편집기의 빈 textblock 장식에서 `table_cell`만 제외해 비워 두고, 일반 문단·제목 등의 안내는 유지합니다.
- 검증: [TypeScript·모델 32](Tests/results/2026-11-06/table-placeholder-model.log), [WebKit 브라우저 모델 18·시각 입력 130](Tests/results/2026-11-06/table-placeholder-visual.log) 통과, 실패/SKIP 0. 가져온 표·새 표의 빈 셀 및 일반 Text 안내 보존·셀 입력을 검사했습니다. [Debug 빌드](Tests/results/2026-11-06/table-placeholder-build.log)·[GUI/디스크 근거](Tests/results/2026-11-06/table-placeholder-gui.json)·[화면](Tests/results/2026-11-06/table-placeholder-gui.png): Aa에서 빈 셀 표시, 입력·⌘S·닫기·미리보기 0개 확인.
- 한계: 격리 앱의 Open 패널이 `.md`를 비활성화해 같은 Markdown을 지원되는 `.txt`로 열었습니다. 타입 선언 정합성은 기존 F3 후속이며, 실제 IME·macOS 14 기기는 미검증입니다.

<a id="bug-34"></a>

## 34. Aa 전환 시 스크롤 왕복과 좌우 정렬 변경

- **2026-11-05 / 수정·해당 범위 검증 완료.** 긴 문서 중간에서 Aa를 누르면 상단이 보였다가 내려오고 본문 폭과 간격이 바뀌었습니다(사용자 재현). `.id(visualEditing)`의 WebView 교체와 `didFinish`의 100ms 지연 smooth-scroll 복원, 별도 980px/54px 본문 스타일이 원인이었습니다.
- 같은 WKWebView·페이지·800px/24px 본문 영역 안에서 편집 루트만 교체합니다. 공통 Markdown 스타일을 사용해 제목·문단·목록·인용·코드·표·수식의 글꼴/간격/정렬을 맞췄습니다. 현재 보이는 블록과 중복 순번을 기준으로 즉시 위치를 맞추며 서식 메뉴 높이만큼만 내려오고 종료 시 되돌립니다. 모드 변경에는 페이지 탐색·초기 스크롤 복원을 실행하지 않습니다. 이전 루트는 문서에서 분리해 중복 목차·검색·클릭을 막고, 기존 textarea close/render가 활성 시각 루트를 덮어쓰지 않도록 분리했습니다. 저장·조합·원본 기준·Undo checkpoint 보호를 유지합니다. 최초 페이지와 전환의 세대 값을 동기화해 첫 Aa Save가 후속 입력·engine Undo를 초기화하지 않도록 했습니다.
- 검증: [WebKit 50](Tests/results/2026-11-05/f5-layout-webkit.log)(기존 22 + 레이아웃 28), [native 33](Tests/results/2026-11-05/f5-layout-native.log)(기존 27 + 동일 WebView/URL/JS 문서 2 + 기본 Markdown 시작의 첫 Aa Save 4), [모델 32/빌드](Tests/results/2026-11-05/f5-layout-model.log), [브라우저 모델 18·시각 입력 128](Tests/results/2026-11-05/f5-layout-visual.log), [Hosted 317](Tests/results/2026-11-05/f5-layout-hosted.log), [기존 체크 저장 17](Tests/results/2026-11-05/f5-layout-tasks.log) 통과, 실패/XFAIL/SKIP 0. 레이아웃 검사는 900/640px·목차 on/off의 좌우 좌표·폭·블록 크기·폰트/색(<0.1px), 메뉴 높이만큼의 가시 제목 이동(<1px), 지연 좌표 샘플·반복 왕복을 확인합니다. offscreen rAF는 정지하므로 샘플은 16ms 타이머이며 실제 painted-frame 영상으로 표현하지 않습니다.
- [독립 Debug 빌드](Tests/results/2026-11-05/f5-layout-build.log)·[GUI/디스크 근거](Tests/results/2026-11-05/f5-layout-gui.json): 24개 섹션 중간(Section 17)에서 Aa 전후 본문 정렬·메뉴 행 높이 변화와 원위치 복귀, 동일 preview URL을 확인했습니다. 편집·⌘S·재열기·두 문서 전환/닫기·미리보기 0개 확인. CUA는 전후 스크린샷 관찰이며 연속 프레임 영상은 없습니다. 사용자 설치 앱은 교체하지 않았습니다.
- 남은 범위: 이미지의 사용자 지정 속성·보호 원문 노드·빈 문단·dark/zoom/PDF/실제 IME까지 모든 문서의 픽셀 동일성을 검증한 것은 아닙니다. 이들은 F5 기존 기능 대응 단계에서 보완합니다. 가시 블록을 대응할 수 없으면 기존 scrollY를 유지합니다.

<a id="bug-33"></a>

## 33. 빈 $$와 Space만으로 Equation이 생성됨

- **2026-11-05 / 수정·해당 범위 검증 완료.** Aa에서 `$$` Space만 입력해도 빈 Equation이 생겼습니다. 별도 블록 단축키 규칙이 원인이었습니다. 이를 제거해 `$$`·`$$$$`·공백뿐인 `$$   $$`는 텍스트로 유지합니다. 최상위 문단의 비어 있지 않은 `$$...$$`는 마지막 `$`에서 블록 수식으로 변환하고 뒤 입력 문단으로 이동합니다. Enter/Shift+Enter로 나뉜 본문도 닫힐 때 모으되 다른 블록 타입·서식/원자 노드는 넘지 않습니다. `$x$` 인라인·문장 속 display 수식은 기존 경로를 유지합니다.
- 미완성 구분자·일반 텍스트의 `$`를 저장할 때 이스케이프해 재열기·모드 왕복 시 수식으로 오인하지 않게 했습니다. 이미 노드인 수식은 해당 구분자로 저장하며 기존 파일의 importer 규약은 바꾸지 않았습니다.
- 검증: [수정 전 재현](Tests/results/2026-11-05/f5-dollar-before.log) → [모델 32·TypeScript/번들](Tests/results/2026-11-05/f5-dollar-model.log)·[브라우저 모델 18/시각 입력 128](Tests/results/2026-11-05/f5-dollar-visual.log)·[native 저장/수명 27](Tests/results/2026-11-05/f5-dollar-native.log)·[WebKit 22](Tests/results/2026-11-05/f5-dollar-webkit.log) 통과, 실패/SKIP 0. 빈/미종결/완결·줄바꿈·후속 문서·코드 mark 보호·snapshot/재파싱·Backspace/Undo 확인. 기본 Markdown 경로의 통화 오인(13번) 해결 근거로 합산하지 않습니다.
- [독립 Debug 빌드](Tests/results/2026-11-05/f5-dollar-build.log)·[GUI/디스크 근거](Tests/results/2026-11-05/f5-dollar-gui.json): 실제 달러 키/Space에서 텍스트 유지, 미완성 상태 Save·Aa 왕복, 마지막 닫는 키에서 단일/여러 줄 수식 변환, Save·닫기·재열기·clean 닫기 후 미리보기 0개 확인. 실제 IME·PDF와 컨테이너 내부 여러 문단을 모으는 입력은 검증 범위 밖입니다.

## 32. Aa 편집 후 버튼 비활성화로 모드 재진입 불가

- **2026-11-05 / 수정·해당 범위 검증 완료.** Aa에서 한 글자만 바꿔도 모드 버튼이 비활성화됐습니다. 미저장 문서의 전환을 막는 초기 보호 정책이 원인이었습니다. 현재는 양쪽 편집기의 최신 스냅샷을 버퍼로 전달하고, 마지막 디스크 저장 기준과 dirty를 따로 유지합니다. 시각 편집기는 직렬화 직후 freeze하고, 기존 textarea도 조합 완료를 기다린 뒤 확정합니다. 저장·전환 중 중복 요청을 막고, 실패 시 현재 편집기를 유지합니다. 전환 자체는 파일을 저장하지 않습니다.
- Undo는 모드 경계를 native 문자열 checkpoint 하나로 유지하며, 새 시각 엔진의 history를 다 사용한 뒤 경계 이전 초안으로 복원할 수 있습니다. 재구성 전 엔진의 개별 키 입력 history는 유지하지 않습니다.
- 검증: [모델 31·TypeScript/번들](Tests/results/2026-11-05/f5-switch-model.log), [브라우저 모델 18·시각 입력 116](Tests/results/2026-11-05/f5-switch-visual.log), [native 수명 27](Tests/results/2026-11-05/f5-switch-native.log) 통과. 미저장 양방향 왕복·활성 textarea 인계·dirty·경계 Undo/Redo·소진 Undo 후 Redo·명시적 Save·실패/재시도·폐기·다중 문서·미리보기 정리 확인. [공유 WebKit 22](Tests/results/2026-11-05/f5-switch-webkit.log)·[기존 체크 저장 17](Tests/results/2026-11-05/f5-switch-tasks.log)·[Hosted 317](Tests/results/2026-11-05/f5-switch-hosted.log) 통과, 실패/XFAIL/SKIP 0.
- [Debug 빌드](Tests/results/2026-11-05/f5-input-fix-build.log)·[GUI/디스크 근거](Tests/results/2026-11-05/f5-input-fix-gui.json): Edited 상태에서 Aa 왕복·내용/dirty 유지, Save 전 디스크 불변, ⌘S·닫기·재열기·다중 문서 전환·clean 닫기 후 미리보기 0개 확인. 실제 IME 조합 중 전환·최초 Save 패널·권한/충돌 UI는 미검증이며 기존 F5의 후속 범위를 유지합니다. 설치본·기존 테스트 앱은 교체하지 않았습니다.

## 31. 블록 입력 변환 취소 후 커서가 다음 줄로 이동

- **2026-11-05 / 수정·해당 범위 검증 완료.** 다음 문단 앞에서 `>`/`-` Space→Backspace 시 기호는 복원되지만 다음 입력이 다음 문단으로 들어갔습니다. 구조 변경 inverse step의 자동 selection 매핑이 다음 문단을 가리켰습니다. 입력 규칙에 기록된 원래 삽입 위치로 Backspace·⌘Z의 selection을 명시적으로 복원합니다.
- 검증: [수정 전 재현](Tests/results/2026-11-05/f5-caret-before.log), [모델 30/빌드](Tests/results/2026-11-05/f5-caret-model.log), [브라우저 모델 18·시각 입력 114 통과](Tests/results/2026-11-05/f5-caret-visual.log). 10가지 블록 규칙의 기호 뒤 커서·후속 입력·다음 문단 불변, 인용/목록 단축키 Undo 확인. [GUI](Tests/results/2026-11-05/f5-input-fix-gui.json)에서 `>`/`-` Space→Backspace 후 같은 줄에 입력되고 뒤 문단이 유지됨을 확인했습니다.

## 30. 인라인 코드 종료 뒤에도 코드 서식이 이어짐

- **2026-11-05 / 수정·해당 범위 검증 완료.** Aa에서 `` `code`tail ``을 입력하면 `tail`까지 코드로 들어갑니다. 닫는 백틱을 처리한 입력 규칙이 코드 mark를 다음 입력의 stored marks에 남기는 것이 원인입니다. 코드 본문에만 mark를 적용한 뒤 stored code mark를 제거했습니다.
- 검증: [수정 전 재현](Tests/results/2026-11-05/f5-inline-before.log), [모델 30/빌드](Tests/results/2026-11-05/f5-inline-model.log), [브라우저 모델 18·시각 입력 110 통과](Tests/results/2026-11-05/f5-inline-visual.log). 바로 이어 쓰기·분리된 두 코드 span·변환 취소·재파싱을 확인했습니다. [GUI](Tests/results/2026-11-05/f5-input-fix-gui.json)에서 닫는 백틱 입력 후 `code`만 코드 표시, `tail`은 일반 표시, 저장·재열기까지 확인했습니다.

<a id="bug-27"></a>
<a id="bug-28"></a>

## 27·28. Aa 전환 시 수식 폰트 변형과 행렬 파싱 손상

- **27·28번 / 2026-11-05 / 수정·해당 범위 검증 완료.** 최소 재현은 [State Space fixture](Tests/fixtures/f5-state-space-math.md)를 열고 **Aa**를 누르는 것입니다. 기본 화면의 행렬은 정상이지만 시각 모드에서 글꼴이 바뀌고, 행렬 첫 줄이 빠지며 다음 제목·수식까지 빨간 오류 본문으로 흡수됐습니다. 독립 앱에서 두 현상을 GUI로 재현했습니다.
- **27번 원인·수정:** 오프라인 폰트 변환의 `src:...;` 정규식이 세미콜론 없이 `}`로 끝나는 minified 선언을 넘어 다음 규칙까지 소비했습니다. 중괄호 경계를 보존하고 양쪽 모드가 KaTeX **0.18.2**의 동일 JS/CSS/내장 WOFF2를 사용하도록 통일했습니다(기존 Markdown 모드의 0.16.11 CDN 제거). 수식은 편집 루트의 pre-wrap/flex 스타일과 상호작용 컨트롤 배치에서 분리합니다. 후속 수식 표면 클릭 UI는 [F5](IMPLEMENTATION_PLAN.md#f5-notion-방식의-블록-관리와-연속-편집)에서 관리합니다. 제목 안 수식도 기본 화면과 글자 크기를 맞춥니다.
- **28번 원인·수정:** 기존 math-flow 문법은 `$$\mathbf{s}_t =`의 본문을 opening metadata로 버리고 `...}$$`를 닫는 줄로 인정하지 않았습니다. micromark 토큰 단계에서 본문과 붙은 구분자를 처리해 코드 보호·컨테이너·빈 줄·UTF-16 source 위치를 유지합니다. 문장 속 `$$...$$`도 display 속성/구분자를 보존합니다. 미수정 수식은 원문 재사용, 수정 수식은 표준 `$$` 줄 형식으로 저장합니다.
- **검증:** [모델 30](Tests/results/2026-11-05/bug27-28-model.log)·[시각 입력 100 + 브라우저 모델 18](Tests/results/2026-11-05/bug27-28-visual.log)·[WebKit 22](Tests/results/2026-11-05/bug27-28-webkit.log) 통과. 상태 행렬·후속 수식·제목 수식 **11개**의 TeX/display 구분·font family/size·글리프 크기 차이 **0.1 CSS px 미만**, clean 원문 보존과 당시(`74e1f9f`)의 Edit 형제 배치를 확인했습니다. [Hosted 317](Tests/results/2026-11-05/bug27-28-hosted.log)·[시각 native 저장 17](Tests/results/2026-11-05/bug27-28-native.log)·[기존 체크 저장 17](Tests/results/2026-11-05/bug27-28-tasks.log)도 통과, 실패/XFAIL/SKIP 0입니다.
- **GUI·한계:** [Debug 빌드](Tests/results/2026-11-05/bug27-28-build.log)·[Computer Use/디스크 근거](Tests/results/2026-11-05/bug27-28-gui.json). 전환 전후 행렬·인라인/블록 수식, Edit 원문 전체, 한 값 수정→Apply→⌘S→재열기→Aa를 확인했습니다. 수식 밖 원문 불변·실제 프로세스 종료 확인. 설치본과 이전 테스트 앱은 보존했습니다. 전체 dark/PDF·macOS 14 기기·사용자 원본 파일 자체는 별도 검증 범위이며, 종료 후 미리보기 잔류는 아래 29번입니다.

## 29. 앱 메뉴 Quit 후 고유 미리보기 파일 잔류

- **2026-11-05 / 조사 중.** 임시 수식 문서를 열고 시각 모드로 전환한 뒤 앱 메뉴 Quit. 수정 전/후 격리 앱 두 실행에서 각각 마지막 `.mv_preview-*.html` 1개가 남았습니다. 전역 앱 목록과 별도 프로세스 조회에서 앱 종료를 확인했습니다. 명시적 문서 닫기→재열기의 미리보기는 정리됐습니다. [파일명·관찰 근거](Tests/results/2026-11-05/bug27-28-gui.json).
- 다음 조치: `applicationWillTerminate`→`removeAllPreviewFiles` 실행/소유권과 NSDocument/SwiftUI 종료 수명을 계측하고 일반 빌드에서도 비교합니다. 18번의 공유 원본 덮어쓰기 방지와 구분하며, 잔류 증거를 삭제해 cleanup 통과로 표현하지 않습니다. 수식 수정의 범위 밖이며 이번 코드에서는 변경하지 않았습니다.

## 26. GUI 테스트 중 Finder “Bloct is not open anymore”

- **2026-10-26 / 조사 중 — 자동화 종료 경합 확인, 새 절차의 반복 검증 대기**. 사용자가 GUI 테스트 중 반복 팝업을 보고했습니다. 이 세션의 최소 조건은 Debug 앱 Quit 직후 같은 앱 핸들로 `getAXState()`를 요청한 흐름입니다. 팝업 자체의 독립 캡처는 없습니다.
- [원시 발췌](Tests/results/2026-10-26/finder-quit-race.log): 13:47:44·13:49:47·13:56:39에 CoreServicesUIAgent가 종료 중인 Bloct에 `aevt/rapp` 재활성화 이벤트를 보내다 `-600 procNotFound`를 반환했습니다. 확인한 Debug 주 프로세스 종료 5회는 모두 `launchd (0, 0, 0)`이며 새 Bloct 충돌 보고서는 없습니다. F1 기능 자체의 충돌을 확인한 결과가 아닙니다.
- 다음 조치: 앱 메뉴의 Quit 이후 이전 핸들에 추가 조회/재활성화를 보내지 않습니다. 전역 앱 목록만으로 종료를 확정하지 않고, 필요하면 실제 프로세스 종료를 확인한 뒤 새 핸들을 얻습니다. 독립 검증 앱의 [최종 정렬 검사](Tests/results/2026-10-26/checkbox-indent-gui.json)에서는 메뉴 Quit 후 실제 종료를 확인했습니다. 다음 GUI 작업에서 새 절차의 재발 여부를 확인합니다. 자동화와 무관한 일반 Finder 문서 열기의 동일 오류는 미재현입니다.
- 2026-11-05 [독립 GUI 검사 1회](Tests/results/2026-11-05/f5-ui-observations.json): 문서 닫기→앱 메뉴 Quit→전역 목록·실제 프로세스 종료 확인, 이전 앱 핸들 재조회 없음. 팝업은 관찰되지 않았습니다. 단일 실행이므로 반복 재검증 대기 상태는 유지합니다.
- 별개 설치 환경: `/Applications/Bloct.app` v1.7.6은 ad-hoc 서명과 `com.apple.quarantine`이 있어 Gatekeeper에 차단됐습니다. 사용자 요청으로 해당 격리 속성만 제거한 뒤 설치본의 Open 창 정상 실행을 확인했습니다. 실행 파일 SHA256·provenance는 보존했고 앱 교체·공증·전역 Gatekeeper 변경은 하지 않았습니다. [조사·로컬 조치 근거](Tests/results/2026-10-26/finder-launch-investigation.json). 배포 시의 기존 제한이며 재다운로드에는 격리 속성이 다시 붙을 수 있습니다.

## 25. macOS Edit·Window 메뉴의 지속적인 깜빡임과 선택 어려움

- **2026-10-22 / 검증 완료 / v1.7.5**, `958e4ae`. 디스크 검사 상태의 불필요한 화면 갱신을 제거하고 메뉴 조작 중 자동 폴링을 쉬도록 수정했습니다.
- 검증: **사용자 직접 확인으로 깜빡임 해결**, [전용 검사 10개](Tests/results/2026-10-22/menu-after.log)와 [GUI 회귀](Tests/results/2026-10-22/menu-gui.json) 통과. [Hosted 회귀](Tests/results/2026-10-22/menu-hosted.log)의 20번 XFAIL 2개는 아래 수정 전의 과거 결과입니다.
- 한계: CUA 연속 화면 검증과 macOS 14 실제 기기 실행은 미검증입니다. 시각적 해결 판정은 사용자 확인에 근거합니다.

## 20. 초기 이중 로드 회귀

- **2026-10-22 / 수정·해당 범위 검증 완료 / v1.7.6**, `ff94d34`. 초기 탐색을 한 번만 시작하고 로딩 중 변경은 최신 원문·이미지 기준·문서 세대로 모아 완료 직후 반영합니다. `WKNavigation` 객체로 완료·실패를 대조하고 닫힌 뷰의 콜백을 차단합니다. 기존 탐색 차단 정책은 유지했습니다.
- 검증: [Hosted 208 통과·XFAIL/SKIP 0](Tests/results/2026-10-22/initial-hosted.log), [WebKit 15](Tests/results/2026-10-22/initial-webkit.log)·[이미지 70](Tests/results/2026-10-22/initial-images.log)·[메뉴 10](Tests/results/2026-10-22/initial-menu.log) 통과. [GUI/빌드](Tests/results/2026-10-22/initial-gui.json)에서 새/기존 문서 표시·편집·저장·재열기·전환·폐기와 미리보기 정리를 확인했습니다. [수정 전](Tests/results/2026-10-22/initial-before.log)의 XFAIL 2개는 정상 검사로 전환했습니다.
- 한계: 경합·지연 콜백은 실제 WebKit 호스팅에서 제어했고 재시도 실패 콜백은 주입했습니다. 모든 실제 I/O 실패·macOS 14 기기·공개 Release GUI는 미검증입니다. 설치본은 교체하지 않았습니다.

## 4·17. 코드 영역 보호

- **미해결 / 중간**. 4번은 분할기와 달리 코드 보호 정규식이 정확히 같은 길이의 닫는 펜스만 인정합니다. 17번은 이미지 확장이 코드 보호보다 먼저 실행되고 들여쓰기 코드도 수식 전처리에서 보호하지 않습니다.
- 2026-11-03 [F5 기반 계층 검사](Tests/results/2026-11-03/f5-block-model.log)의 B05·B06에서 새 importer의 코드/수식 보호를 확인했습니다. 2026-11-05 선택형 시각 편집기에 연결했지만, 기본 Markdown 렌더러의 4·17·13번 해결 근거로 사용하지 않습니다. 새 경로 결과는 F5에서 별도로 관리합니다.
- 최소 재현·완료: 더 긴 닫는 펜스·미종결 펜스·코드 안 수식/이미지 예제로 렌더링·편집·저장 원문 불변을 확인합니다. 빈 줄로 나뉜 독립 블록은 병합하지 않습니다.
- 자리표시자는 `ac191f7`에서 바뀌었으므로 과거 `<mvmath …>` 노출을 현재 출력이라고 재사용하지 않습니다. 현재 원문 보존을 기준으로 회귀를 추가합니다.

## 16. 별도 정의 참조 링크 — 보류

- **2026-10-17 / 사용자 정책에 따라 보류**. 다른 블록의 참조 정의를 쉽게 확인·편집할 수단과 함께 지원을 검토합니다. 현재는 직접 주소 링크를 사용하며 [F4](IMPLEMENTATION_PLAN.md#f4-별도-정의-참조-링크--보류) 재개 전에는 구현하지 않습니다.
- **빈 줄은 독립 파싱·목록 그룹 경계**입니다. F5의 새 모델은 그 내부를 의미 블록으로 나누며, 기본 Markdown 편집은 종전 편집 단위를, 선택형 시각 편집은 의미 블록을 사용합니다. 빈 줄로 나눈 목록의 번호 재시작과 들여쓰기 블록의 독립 렌더링은 정상입니다. 같은 블록의 줄바꿈은 빈 줄 없이 줄 끝에 `\`를 사용합니다. [확인 문서](Tests/fixtures/bug-16-block-context.md).
- 정의 전용 블록은 가시 영역이 없지만 직전 블록 편집기의 `⌘Enter`·`⇧⌘Enter`로 접근/복귀하는 임시 경로는 [합성 키 검사](Tests/results/2026-10-17/bug16-definition-access.log)로 확인했습니다. 정의 관리 UI·교차 블록 해석은 없으며 네이티브 키 입력은 미검증입니다.
- [정책 검사 4/4](Tests/results/2026-10-17/bug16-policy-fixture.log)는 Node 파서 비교(sanitizer 항등 함수)입니다. 이전 전체 파싱 비교의 6/6은 B·C가 결함이라는 근거로 사용하지 않습니다. 앱 전체 회귀 결과도 아닙니다.

## 나머지 미해결 항목의 재현·다음 조치

### 2·7·8·13. 서식·수식·제목

- **2번**: `noStrikethrough`가 첫 물결표부터 다음 물결표까지 한 토큰으로 삼아 그 사이의 굵게·링크·코드 서식을 파싱하지 않습니다. 물결표 자체만 리터럴 토큰으로 소비하도록 검토합니다. 예: `3~5 **중요** 7~9`.
- **7번**: KaTeX 제목의 `textContent`에는 MathML·annotation·HTML 텍스트가 중복됩니다. 제목의 의미 텍스트를 한 번 추출해 ID와 목차에 공통 사용해야 합니다.
- **8번**: 같은 제목은 같은 ID가 됩니다. 목차 항목의 직접 스크롤 뒤 전역 앵커 핸들러가 다시 첫 ID로 이동할 수 있습니다. 문서 전체에서 고유 ID를 만들고 이벤트 경로를 통합합니다. 제목 접미사 자체가 다른 제목과 충돌하는 경우도 포함합니다.
- **13번**: `가격 $5 와 $10 표기`를 수식으로 오인할 수 있습니다. 공백·숫자·이스케이프를 포함한 수식 구분자 정책을 정의하고 통화·정상 수식·코드 영역을 함께 확인합니다.

### 3·5·9·10. 편집 및 포커스

- **3번**: blur의 `setTimeout(0)`이 click보다 먼저 DOM을 교체할 수 있다는 가설입니다. 실제 클릭 순서를 먼저 재현하고, mousedown/pointerdown 조정 시 드래그 선택·링크·caret 위치·키보드 탐색을 보존해야 합니다. 합성 click 테스트 통과만으로 해결되었다고 보지 않습니다.
- **5번**: `''.split('\n')`이 `['']`이므로 첫 입력이 1번 줄에 추가되어 빈 줄로 시작합니다. 빈 문서 모델과 첫 편집의 줄 위치를 일관되게 처리합니다.
- **9번**: 하단 여백 클릭 처리기가 목차 영역을 배제하지 않습니다. 짧은 문서의 목차 빈 공간을 클릭해 추가 편집기가 열리는지 검증합니다.
- **10번**: 추가 영역에 입력 후 전부 지우면 `['']`와 구분 줄이 남을 수 있습니다. 시작 상태와 최종 텍스트가 같으면 문서·dirty·Undo에 변화가 없어야 합니다.

### 11·12·19. 출력·복사·키보드

- **11번**: 인쇄 CSS는 글자 크기만 지정합니다. 출력 전 활성 편집기를 확정하고 갱신을 기다린 뒤 목차·검색 강조·화면용 좌측/하단 여백을 제거해야 합니다. textarea만 숨기면 `display:none`인 원본 블록까지 출력에서 빠질 수 있습니다. 실제 PDF 검증이 필요합니다.
- **12번**: 전역 copy 처리기가 textarea 선택을 잘못 변환한다는 가설입니다. 실제 textarea 선택·부분 복사·줄바꿈·유니코드·미리보기 복사를 먼저 재현하고 기본 편집기 복사를 보존합니다. 현재 자동 테스트는 미리보기의 합성 copy를 검사하며 이 가설을 확정하지 않습니다.
- **19번**: 검색 필드는 Return을 항상 다음 검색으로 처리하고 Shift-Return·↑/↓ 검색 이동이 없습니다. README와 실제 지원을 일치시킵니다.


## 완료 항목의 수정·검증 근거

### 2026-10-15 Undo·폐기 수정 및 최신 검증

- **1·6번 / 해당 범위 검증 완료**, `e40a84b`. `DocumentState`의 편집 버퍼·전용 Undo와 FileDocument를 분리하고 명시적 Save 때만 고정 스냅샷을 전달합니다. 실제 저장 성공 콜백 후 기준을 갱신/닫고, 취소·실패는 버퍼와 창을 유지합니다. 저장 중 추가 편집은 별도 변경으로 남깁니다. 폐기 시 FileDocument Binding을 바꾸는 경로로 되돌리지 않습니다.
- 검증: [수정 전 실패](Tests/results/2026-10-15/fix-before-native.log) → [Native 5그룹](Tests/results/2026-10-15/fix-native.log), [WebKit 15/15](Tests/results/2026-10-15/fix-webkit.log). [당시 Hosted](Tests/results/2026-10-15/fix-hosted.log)는 **127 통과·XFAIL 2·SKIP 1**이며 쓰기 금지 이미지 SKIP은 이후 24번에서 실제 검사했습니다.
- 실제 GUI에서 BASELINE→A→B 편집 후 연속 Undo/Redo, 활성 textarea 저장, ⌘W/닫기/⌘Q의 Don't Save, 새 문서 Save 취소, 0555 폴더 저장 실패→복구·재저장, 다중 창 종료 Cancel·Save·폐기를 확인했습니다. [디스크 결과](Tests/results/2026-10-15/fix-gui-disk.log). [기존 GUI 보고서](Tests/GUI_ACCEPTANCE_2026-10-15.md)는 수정 전 관찰 기록입니다.
- 한계: 저장 전 버퍼의 크래시 복구·자동 저장은 미구현입니다. 지연 I/O 중 실제 GUI 추가 입력은 미검증이며 스냅샷 분리는 자동 검사로 확인했습니다.

### 14·15·18번: HTML·자리표시자·미리보기 파일 보호

- **2026-10-14~15 / 해당 범위 검증 완료**. `ac191f7`: DOMPurify 3.4.17·nonce CSP·탐색/메인 프레임/페이지 URL 브리지 검사·안전한 이미지 속성·렌더링별 자리표시자로 충돌을 방지합니다. `f062c65`: `PreviewFiles`가 문서별 `.mv_preview-UUID.html`을 만들고 소유 파일만 정리하며 기존 `.mv_preview.html`은 보존합니다.
- 근거: [WebKit](Tests/results/2026-10-15/fix-webkit.log), [Native](Tests/results/2026-10-15/fix-native.log), [Hosted](Tests/results/2026-10-15/fix-hosted.log). 원문 HTML의 ID/name/data·예약 클래스·일부 태그 제거는 의도된 제한입니다. HTML 앵커 복원 시 편집기 사칭·DOM clobbering 방어를 유지합니다. 라이선스는 [THIRD_PARTY.md](THIRD_PARTY.md)를 따릅니다.
- 초기 탐색의 후속 수정·검증은 20번을 참조합니다. 해당 자동 검사는 전체 보안 감사나 실제 GUI/클립보드 검증을 대신하지 않습니다.

### 21. 외부 문서 변경과 편집 상태의 불일치

- **2026-10-17 / 구현·해당 범위 검증 완료**, `0ff3e30` / v1.7.4. 수정 전에는 최초 Binding 이후 외부 원문을 편집 버퍼·기준·미리보기에 수용하는 경로가 없었습니다(소스 확인, 구버전 GUI 덮어쓰기 재현은 미실행).
- 구현: `ContentView.checkDisk`의 0.6초 내용 폴링·Binding/URL 관찰, `⌘R`·기존 우클릭 Reload. 깨끗하면 자동 수용하고, 미저장 입력에는 Keep Editing / Discard Edits and Reload / Save a Copy…를 제공합니다. 같은 원본/심볼릭 링크에 사본 저장하지 않으며, 새 문서 Reload는 비활성입니다. 오래된 문서 세대의 commit은 거절합니다.
- 재발 방지: `DocumentDisk`의 조정 I/O는 백그라운드에서 실행합니다. 읽기는 `.withoutChanges`, 내용 쓰기는 `.forReplacing` 없이 같은 accessor에서 원본 비교 후 원자적 쓰기를 사용합니다. 수용은 NSDocument 재읽기로 모델·기준·버퍼·Undo를 맞춥니다. 삭제 시 마지막 URL·공유 쓰기 취소/보호·native 폐기로 과거 원문 재생성을 막고, rename/최초 Save는 새 URL을 따릅니다. 닫힌 문서의 콜백과 키 감시는 해제합니다.
- 최소 재검증: 임시 문서에서 외부 직접 쓰기·원자적 교체(수정 시각 유지 포함) → 깨끗한 읽기/편집 자동 갱신. 활성 초안에서 Reload → 유지 후 Save 거절·사본 저장/취소·명시적 버리기·Undo 경계. 이어 정상/최초 Save·두 문서·rename·삭제 후 Save 실패/Close Cancel/Don't Save와 디스크·소유 파일 정리를 확인합니다.
- 자동 결과: [Native 8그룹](Tests/results/2026-10-17/reload-native.log), [WebKit 15개](Tests/results/2026-10-17/reload-webkit.log), [상대 이미지 70개](Tests/results/2026-10-17/reload-relative-images.log) 통과. [Hosted](Tests/results/2026-10-17/reload-hosted.log) **134 통과·0 일반 실패·20번 XFAIL 2·0 SKIP**.
- 실제 DocumentGroup: 위 시나리오를 별도 `BloctReloadCheck.app`에서 확인했습니다. [GUI](Tests/results/2026-10-17/reload-gui.log), [디스크](Tests/results/2026-10-17/reload-disk.log), [빌드/체크섬](Tests/results/2026-10-17/reload-artifact.json). 설치 앱은 교체하지 않았습니다.
- 미검증: 실제 한국어 IME(합성 composition만 검사), 지연시킨 동시 writer/Save, 외장/네트워크/iCloud·큰 문서 폴링, 기존 문서 Save As·PDF·macOS 14 실제 기기. 파일 조정을 무시한 외부 writer까지 절대적인 CAS는 보장하지 않습니다.

## 24. 상대경로 이미지 로드 실패

- **2026-10-17 / 해당 범위 검증 완료**, 수정 `ee614a2` / v1.7.3. 문서 폴더만 허용한 `loadFileURL`에서는 상위 이미지가, 쓰기 금지 폴더의 `loadHTMLString` 대체 경로에서는 같은 폴더 이미지도 실패했습니다. 기대는 원본 문서 기준의 실제 이미지 표시입니다.
- 재현: `sh Tests/run-relative-images.sh /private/tmp/bloct-relative-images-check`로 fixture를 만들고 `plain/docs/chapter/probe.md` 등을 엽니다. 같은/하위/상위/다시 내부로 돌아오는 경로와 0555 폴더·한글/공백 경로를 비교합니다. [수정 전](Tests/results/2026-10-17/relative-images.log) **24 통과·30 실패·0 SKIP**였습니다.
- 구현: 문서별 `LocalImageLoader`·`bloct-image` 스킴으로 정화 후 로컬 이미지 요청만 처리합니다. 이미지 MIME·일반 파일·문서 토큰을 확인하며 원격/POST/비이미지/다른 문서 토큰은 거절합니다. 위치 변경 시 토큰 교체·닫을 때 무효화하고, 원문·복사 경로는 보존합니다. 루트 읽기 허용으로 확장하지 않습니다.
- 검증: [전용 검사](Tests/results/2026-10-17/relative-images-fixed.log) **70 통과·0 실패·0 SKIP**(기본 PNG 54개 포함). [당시 Hosted](Tests/results/2026-10-17/relative-fix-hosted.log)는 **128 통과·XFAIL 2·SKIP 0**, Native 5그룹·WebKit 15개 통과입니다.
- 실제 Debug GUI: 6경로·Locked 폴더·JPEG/SVG·혼합 인코딩·심볼릭 링크 표시, 편집·Save·닫기·재열기를 확인했습니다. [GUI 기록](Tests/results/2026-10-17/relative-fix-gui-checks.txt), [최종 재열기](Tests/results/2026-10-17/relative-images-final-gui.png). 설치본 교체는 하지 않았습니다.
- 미검증: 외장/네트워크·실제 Save As·PDF·macOS 14 기기·공개 Release GUI. 문서 위치 변경은 호스팅 검사, 복사는 합성 이벤트입니다. 다른 항목의 검증 범위와 구분합니다.

## 22·23번: Homebrew 동기화·배포 SDK

- **22번 / 2026-10-15 구현·배포·원격 실행 검증 완료**. 기존 cross-repository push는 인증 거절이었습니다. app `ec61fb8`·tap `8c7f5ce`에서 개인 토큰 push 대신 tap 자체 `GITHUB_TOKEN`의 Sync Bloct로 전환했습니다. 15분 예약·수동 실행이며 ZIP SHA256/asset digest를 검증합니다. 스케줄 지연·비활성화 시 수동 실행/재활성화가 필요합니다.
- 근거: [최초 원격 실행](Tests/results/2026-10-15/tap-sync-actions.json)은 4개 검사·변경 없는 push 통과. 2026-10-17에는 v1.7.3·v1.7.4의 실제 변경 커밋과 수동 dispatch 성공도 확인했습니다. 예약 시점 자체의 실행은 별도 미검증입니다. 로컬 `gh`가 sandbox에서 invalid를 출력해도 키체인 제한일 수 있으므로 일반 권한의 조회와 구분합니다(2026-10-17 확인).
- **23번 / 2026-10-15 구현·배포 검증 완료**, `67263f1` / v1.7.2. 공유 빌드·검사 스크립트에서 **Xcode/SDK 27.0·최소 macOS 14.0·arm64/x86_64 Universal**을 강제합니다. [공개 ZIP](Tests/results/2026-10-15/sdk27-published.json) 두 CPU 검증 완료. 당시 Release는 tap 단계 실패로 전체 실패였고, cask는 수동 복구했습니다. 이후 22번으로 자동화를 대체했습니다. macOS 14 실제 실행·OS 간 UI 동일성은 보장하지 않습니다.

## 최신 배포 검증 기록 — 2026-10-26

v1.8.0은 2026-10-26 공개 ZIP·Homebrew 검증을 완료한 기능 릴리스입니다. v1.7.5·v1.7.6는 2026-10-22, 이전 버전 행은 2026-10-17의 배포 검증입니다. 설치 앱 교체·공개 Release의 실제 GUI·macOS 14 기기 실행은 범위 밖입니다.

| 버전 | 결과·근거 |
|---|---|
| v1.8.0 (`3bcab98`) | F1 체크박스 토글·상태 저장 및 표시 정책 포함. [Release](https://github.com/JAEHYEON-BAE/bloct/releases/tag/v1.8.0)·[Release Actions](https://github.com/JAEHYEON-BAE/bloct/actions/runs/40338147371)·[tap Actions](https://github.com/JAEHYEON-BAE/homebrew-tap/actions/runs/40338515054) success. [공개 ZIP/cask 검증](Tests/results/2026-10-26/release-1.8.0-published.json): 버전 1.8.0·SDK 27·최소 OS 14·두 CPU, 태그 JS/CSS·ZIP/digest/cask SHA256 일치. tap 변경 `19122e6` |
| v1.7.6 (`ff94d34`) | 20번 수정 포함. [Release](https://github.com/JAEHYEON-BAE/bloct/releases/tag/v1.7.6)·[Release Actions](https://github.com/JAEHYEON-BAE/bloct/actions/runs/39732136173)·[tap Actions](https://github.com/JAEHYEON-BAE/homebrew-tap/actions/runs/39732350275) success. [공개 ZIP/cask 검증](Tests/results/2026-10-22/release-1.7.6-published.json): 버전 1.7.6·SDK 27·최소 OS 14·두 CPU 및 ZIP/digest/cask SHA256 일치, tap 변경 `fe3e95d` |
| v1.7.5 (`958e4ae`) | 25번 수정·사용자 해결 확인. [Release](https://github.com/JAEHYEON-BAE/bloct/releases/tag/v1.7.5)·[Release Actions](https://github.com/JAEHYEON-BAE/bloct/actions/runs/39711758926)·[tap Actions](https://github.com/JAEHYEON-BAE/homebrew-tap/actions/runs/39711903573) success. [공개 ZIP/cask 검증](Tests/results/2026-10-22/release-1.7.5-published.json): 버전 1.7.5·SDK 27·최소 OS 14·두 CPU 및 ZIP/digest/cask SHA256 일치, tap 변경 `6b29507` |
| v1.7.4 (`0ff3e30`) | [Release](https://github.com/JAEHYEON-BAE/bloct/releases/tag/v1.7.4)·[Actions](Tests/results/2026-10-17/release-1.7.4-actions.json) success. [공개 ZIP](Tests/results/2026-10-17/release-1.7.4-published.json)의 버전·SDK 27·최소 OS 14·두 CPU, [ZIP/digest/cask 체크섬](Tests/results/2026-10-17/release-1.7.4-checksums.json) 일치. [tap 실행](Tests/results/2026-10-17/release-1.7.4-tap-actions.json) success·변경 `fa2ae75` |
| v1.7.3 (`c8bf59a`) | 24번 수정 포함. [공개 ZIP](Tests/results/2026-10-17/release-1.7.3-published.json) 구성·[체크섬](Tests/results/2026-10-17/release-1.7.3-checksums.json) 검증, [Release](Tests/results/2026-10-17/release-1.7.3-actions.json)·[tap](Tests/results/2026-10-17/release-1.7.3-tap-actions.json) success·변경 `2bf8523` |

## 검사 범위와 근거

검사 명령과 계층은 [Tests/README.md](Tests/README.md)를 따릅니다. 합성 이벤트·호스팅 검사는 실제 창·포커스·마우스·저장 패널·클립보드·PDF 검증을 대신하지 않습니다. 과거 로그는 덮어쓰거나 최신 수치에 합산하지 않습니다. 2026-10-14 결과와 `relative-images.log`는 과거/수정 전, `relative-images-fixed.log`·`reload-*.log`는 해당 수정 후 근거입니다. 상세 경과는 Git 이력과 원시 증거에서 확인합니다.
