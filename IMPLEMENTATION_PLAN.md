# Bloct 구현 현황 및 계획

- 최신화: **2026-11-05** — **F5의 Notion 방식 블록·연속 편집 전환이 최우선 목표**입니다. 선택형 시각 편집기를 앱에 연결했습니다. 다음 관문은 실제 한글 IME·기존 기능 대응·기본값 전환 검증입니다. 기존 배포 검증은 버그 문서에서 관리합니다.
- 버그의 재현·수정·검증과 기존 경로의 작업 순서는 [BUG_FIXES.md](BUG_FIXES.md)에서 관리합니다. 이 문서는 구현 요약과 새 기능의 요구사항·다음 조치·완료 기준만 유지합니다. 기록 정책은 [AGENTS.md](AGENTS.md)를 따릅니다.

## 현재 구현 현황

검증 범위와 시점은 각 항목을 따릅니다. F1의 최신 근거는 아래 기능 항목에서 관리하며, 기존 버그 검증 결과와 합산하지 않습니다.

| 구현 | 상태·근거 |
|---|---|
| 편집 버퍼·전용 Undo·명시적 Save | 2026-10-15 해당 범위 검증 완료, `e40a84b`. [버그 1·6번](BUG_FIXES.md#2026-10-15-undo폐기-수정-및-최신-검증). 저장 전 버퍼의 크래시 복구·자동 저장은 미구현 |
| HTML 정화·CSP·브리지·자리표시자·문서별 미리보기 | 해당 범위 검증 완료, `ac191f7`·`f062c65`. [버그 14·15·18번](BUG_FIXES.md#141518번-html자리표시자미리보기-파일-보호). 2026-10-22 초기 탐색 단일화·콜백 식별 검증 완료(v1.7.6, [20번](BUG_FIXES.md#20-초기-이중-로드-회귀)) |
| 상대경로·쓰기 금지 폴더 이미지 | 2026-10-17 전용 70개 및 해당 GUI 검증 완료, v1.7.3. [버그 24번](BUG_FIXES.md#24-상대경로-이미지-로드-실패) |
| 외부 파일 자동 갱신·Reload·초안/원본 보호 | 2026-10-17 해당 범위 검증 완료, `0ff3e30` / v1.7.4. [버그 21번](BUG_FIXES.md#21-외부-문서-변경과-편집-상태의-불일치). 2026-10-22 폴링의 메뉴 갱신 제거·자동/GUI 회귀·사용자 확인 완료(v1.7.5), [25번](BUG_FIXES.md#25-macos-editwindow-메뉴의-지속적인-깜빡임과-선택-어려움). 실제 IME·지연 동시 I/O 등은 미검증 |
| SDK 27·최소 macOS 14·Universal·tap 자체 동기화 | v1.8.0 공개 산출물·Homebrew 반영까지 2026-10-26 검증 완료. [버그 22·23번](BUG_FIXES.md#2223번-homebrew-동기화배포-sdk). 예약 시점·macOS 14 실제 실행은 미검증 |

## 기능 구현·계획

**최우선 순위는 F5**이며 상세 실행 순서는 블록 계획 9절을 따릅니다. 미완료 버그의 기존 경로 작업 순서는 버그 문서를 따릅니다. F1 구현으로 기존 3·4·17번 등의 전체 해결을 판정하지 않습니다.

| ID | 항목 | 상태·다음 조치 |
|---|---|---|
| F1 | 체크박스 토글·상태 저장 | 2026-10-26 구현·해당 범위 검증 및 v1.8.0 공개 배포 확인 완료. 아래 근거·한계 참조 |
| F2 | 큰 문서 성능·중복 코드 정리 | 검토 대기 / 효과 미측정. 입력·재렌더링·검색 지연을 먼저 측정 |
| F3 | 문서 타입 메타데이터·확대 단축키 | 검토 대기 / 동작 미검증. 선언 정합성·실제 키 입력 확인 |
| F4 | 별도 정의 참조 링크의 확인·편집 및 지원 | 2026-10-17 사용자 정책으로 보류. 정의 관리 수단과 함께 재검토 |
| F5 | Notion 방식의 블록 관리·연속 편집 | 2026-11-05 구현 후 검증 대기 / 연속 시각 편집 실험 경로·형식별 입력·native 저장 통합. 수식 호환 수정 [27·28번](BUG_FIXES.md#bug-27). 실제 IME·전체 기능 대응은 아래 F5 참조. [상세 계약·실행 순서](WYSIWYG_BLOCK_PLAN.md) 참조 |

## F1. 체크박스 토글 및 상태 저장

### 요구사항과 제약

- GFM `- [ ]`·`- [x]`·`- [X]`를 마우스 또는 Tab/Space로 토글합니다. 읽기/편집 모드 모두 지원하되 블록 편집기를 동시에 열거나 중복 토글하지 않습니다. 체크항목은 18px 정사각형으로 일반 목록과 같은 기호 칸·본문 시작 위치를 사용하고, 구두점 없이 체크박스만 표시하며 포커스 테두리는 숨깁니다. `[]` 단축 입력·클릭 즉시 자동 저장은 첫 구현 범위 밖입니다.
- 상태는 `.md` 원문의 표식만 변경해 저장합니다. 같은 이름의 항목·중첩/순서 있는 목록·인용·빈 줄이 있는 목록을 구분하고 한글·공백·줄바꿈·다른 내용은 보존합니다. 빈 줄 블록 정책을 유지하며 F4는 선행 조건이 아닙니다.
- 한 토글은 Undo 한 단계입니다. `commitEdit` → `DocumentState.commit()`과 명시적 Save 스냅샷을 재사용합니다. Don't Save는 마지막 저장 원문, Cancel/저장 실패는 초안·창을 보존하고 저장 중 새 토글은 이후 변경으로 남깁니다.
- 파서가 만든 체크박스만 활성화합니다. 코드·이스케이프·일반 대괄호·사용자 HTML input/위조 속성은 제외하고 정화·CSP·브리지 검증을 유지합니다. 모든 checkbox의 disabled를 일괄 제거하지 않습니다.

### 구현·검증 — 2026-10-26 / 해당 범위 검증 완료

- [task-lists.js](Sources/Bloct/task-lists.js)에서 실제 list-item 토큰을 원문의 UTF-16 문자 위치와 연결합니다. 인용·중첩 컨테이너의 같은 줄을 대응시키고 이미지/수식 전처리에도 위치를 보존합니다. 원문 파싱 결과와 일치하는 대상만 허용하며, 불명확한 위치는 비활성 상태로 둡니다. `marked.min.js`와 빈 줄 블록 정책은 유지했습니다.
- 정화 뒤 생성한 checkbox 노드만 비공개 `WeakMap`으로 관리합니다. 읽기/편집 모드의 클릭·Tab/Space, 스크롤·토글 후 포커스, 오래된 DOM 거절을 지원합니다. 다른 문단 편집은 먼저 확정·위치를 재계산하고 토글과 Undo를 분리합니다. 비동기 파일 검사 중 blur는 기다리며 연속 클릭은 순서대로 처리합니다.
- 표식 한 글자만 바꿔 기존 `commitEdit`·전용 Undo·명시적 Save를 재사용합니다. 저장 중 추가 토글은 다음 변경으로 남고, Cancel/실패는 초안·창을 보존하며 Don't Save는 마지막 저장 상태로 돌아갑니다.

| 검증 범위 | 결과·근거 |
|---|---|
| 원문·이벤트·보안·스크롤 | [Hosted 317 통과, 실패/XFAIL/SKIP 0](Tests/results/2026-10-26/release-1.8.0-hosted.log). [task suite](Tests/js/task-lists.js): 중복·중첩·순서·인용·빈 항목·빈 줄·한글/emoji·CRLF/탭/후행 공백·전처리·코드/HTML 제외·줄 증감·지연 blur·연속 클릭·stale DOM |
| 실제 상태·Undo·저장 수명 | [전용 17 통과](Tests/results/2026-10-26/release-1.8.0-tasks.log). 전체 `ContentView`·bridge·`DocumentState`·실제 임시 파일 저장, 문서 분리·Undo/Redo·재열기·저장 중 추가 토글·실패/재시도·폐기·닫기·미리보기 정리 |
| 기존 회귀·빌드 | [Native 8그룹](Tests/results/2026-10-26/release-1.8.0-native.log), [WebKit 15](Tests/results/2026-10-26/release-1.8.0-webkit.log), [이미지 70](Tests/results/2026-10-26/release-1.8.0-images.log), [메뉴 10](Tests/results/2026-10-26/release-1.8.0-menu.log) 통과. [Release 빌드](Tests/results/2026-10-26/release-1.8.0-build.log)·[v1.8.0 로컬 Universal/SDK/버전 검증](Tests/results/2026-10-26/release-1.8.0-local.json) 완료 |
| 실제 GUI | [검사 기록](Tests/results/2026-10-26/f1-gui.json)·[스크린샷](Tests/results/2026-10-26/f1-gui.png). 마우스·Tab/Space·Undo/Redo·줄 추가 후 첫 클릭·⌘S/닫기 Save·재열기·Cancel/Don't Save·쓰기 권한 실패 후 재저장·두 문서 전환 확인. 최신 표시 정책은 [목록 들여쓰기 정렬 GUI](Tests/results/2026-10-26/checkbox-indent-gui.png)·[회귀 317 통과](Tests/results/2026-10-26/checkbox-indent-hosted.log) 확인 |

- 한계: 저장 중 경합은 자동 검사에서 쓰기를 의도적으로 지연했고, 전용 저장 검사의 오류 UI·native revert는 통제했습니다. 실제 권한 오류 패널과 재저장은 별도 GUI로 확인했습니다. 스크롤 수치는 Hosted와 GUI 스크롤바, 정렬·포커스 테두리 제거는 최종 GUI 근거입니다. 테스트 종료 직후 Finder 팝업은 [버그 26번](BUG_FIXES.md#26-gui-테스트-중-finder-bloct-is-not-open-anymore)의 자동화 경합으로 별도 관리합니다. macOS 14 실제 기기·공개 Release GUI·큰 문서 성능은 미검증이며 설치본은 교체하지 않았습니다. `[]` 단축 입력·자동 저장·F4는 이번 범위 밖입니다.
- 재실행: [Tests/README.md](Tests/README.md). 이번 사용자 요청의 신규 설계는 F5에서 관리하며 F2·F3은 검토 대기 상태를 유지합니다.

## F2·F3. 검토 대기

- **F2 측정 대상:** textarea 입력의 전체 줄 배열 복사, dirty/stale 이후 전체 파싱·DOM·목차·검색 갱신, 검색어별 텍스트 노드 순회. 실제 지연을 확인한 뒤 버퍼 분리·캐시·디바운스를 검토합니다. 변경 없는 모든 Esc가 재렌더링된다고 단정하거나 버전 카운터가 Undo 후 저장 상태 복원을 대체한다고 가정하지 않습니다.
- **F2 정리 제약:** 대규모 미사용 코드는 확인하지 못했습니다. `WebViewStore` 재대입·`CloseProxy.windowWillClose`는 수명/delegate를 먼저 확인하고, `tocScript` 재주입 가드는 유지합니다. 폐기 시 FileDocument Binding을 바꾸는 과거 방식으로 되돌리지 않습니다.
- **F3 확인 대상:** `CFBundleTypeRole`의 Viewer/Editor, UTType의 `public.text`/`public.plain-text` 정합성, 실제 키보드의 ⌘= 확대 지원. 결함을 재현하면 BUG_FIXES.md의 다음 번호로 등록합니다.

## F4. 별도 정의 참조 링크 — 보류

- 별도 정의 블록을 쉽게 확인·수정할 수 있는 원문 보기 또는 정의 목록 UI와 참조 해석을 함께 검토합니다. 재개 요청 전에는 구현하지 않습니다. 현재 한계·임시 접근 경로는 [버그 16번](BUG_FIXES.md#16-별도-정의-참조-링크--보류)에 있습니다.
- 빈 줄로 나뉜 목록·들여쓰기 블록은 독립적으로 유지합니다. 재개 시 정의 확인·편집·저장·Undo·링크 해석을 함께 설계하고 검증합니다.

## F5. Notion 방식의 블록 관리와 연속 편집

- **수식 표면 편집(2026-11-05 / 구현·클릭 검증 완료, 실제 hover 확인 대기):** 인라인/블록 수식의 `Edit` 버튼을 제거하고, 편집 모드에서 수식 영역 hover 시 옅은 회색·pointer 커서, 클릭/키보드 Enter·Space로 기존 수식 창을 여는 방식으로 변경했습니다. 읽기 모드·저장 freeze에서는 비활성화하고 드래그 선택은 창을 열지 않습니다. 코드 블록은 기존 직접 편집입니다. [모델 30](Tests/results/2026-11-05/f5-math-hover-model.log)·[시각 입력 106 + 브라우저 모델 18](Tests/results/2026-11-05/f5-math-hover-visual.log)·[WebKit 22](Tests/results/2026-11-05/f5-math-hover-webkit.log) 통과, 실패/SKIP 0. 수식 11개의 기존 폰트·크기 비교도 유지했습니다. [Debug 빌드](Tests/results/2026-11-05/f5-math-hover-build.log)·[GUI/디스크 근거](Tests/results/2026-11-05/f5-math-hover-gui.json): 두 수식 클릭→원문→취소, 한 글자 수정·Apply·⌘S·닫기·미리보기 0개 확인. 백그라운드 조작과 offscreen mouseMoved로 실제 `:hover` 상태를 만들지 못했으므로 물리 포인터의 강조색·커서 형태·연속 dwell은 별도 GUI 검증이 남았습니다.

- **수식 호환 보완(2026-11-05):** 폰트 CSS 경계 손실·붙어 있는 `$$` 본문 파싱을 수정하고 공통 오프라인 KaTeX를 적용했습니다. 최신 재현·검증·한계는 [버그 27·28번](BUG_FIXES.md#bug-27)에서 관리합니다. 아래 표는 최초 연속 편집 구현(`a1816fd`) 당시의 검증 근거를 보존합니다.

- **2026-11-05 / 구현 후 검증 대기 — 선택형 연속 시각 편집 구현, 기본값 전환 전.** `@tiptap/pm`의 ProseMirror `EditorView`를 하나의 편집 루트로 연결했습니다. 기본 경로는 기존 Markdown 편집이며, 저장된 상태에서 상단 **Aa** 버튼으로 Visual Editor를 선택합니다. 미저장 중에는 전환을 막습니다.
- 이번 구현: 문단·H1~H6·인용문·일반/번호/할 일 목록·코드·구분선·수식·이미지·표를 시각 노드로 표시합니다. 빈 문단의 Markdown 입력 규칙, 타입별 회색 placeholder, Enter/Shift+Enter·목록 들여쓰기·engine Undo/Redo를 연결했습니다. 표·이미지·수식은 형식 메뉴와 전용 편집 UI도 제공합니다. 보존 원문은 `Preserved content`와 읽기 전용 `View source`로 보호하며 일반 입력 중 Markdown textarea를 사용하지 않습니다. 전체 입력 규칙은 [계획 9절](WYSIWYG_BLOCK_PLAN.md#9-구현-순서와-단계별-산출물)에 둡니다.
- 저장: Swift는 실시간 문자열을 다시 편집기로 보내지 않고 dirty만 받습니다. 명시적 Save 시 고정 스냅샷을 직렬화하고 성공 응답의 token만 저장 기준으로 승인합니다. 쓰기 중 후속 입력은 dirty로 남고, 저장 실패·Don't Save·외부 변경 보호를 유지합니다. native 메뉴와 키보드는 engine history를 공유하며 native 문자열 Undo를 중복 등록하지 않습니다. 조합 중 Save는 완료를 기다리다 시간 초과 시 저장을 거절합니다.
- **다음 순서:** 실제 한글 IME 조합·한자/emoji·조합 중 Save/Reload/Close → 새 문서 최초 Save/취소·권한 오류·충돌 선택 UI → 복사/붙여넣기·PDF·목차/검색·이미지 속성·표 조작/접근성·대형 문서 성능 → 기본값 전환 판단. 슬래시 메뉴·핸들·드래그는 그다음입니다. 기존 버그 상태를 실험 경로 구현만으로 완료 처리하지 않습니다.

| 구현 단위 | 검증 날짜·근거·한계 |
|---|---|
| importer·블록 스키마 (`658e107`) | 2026-11-03 [단위 1](Tests/results/2026-11-03/f5-importer.log): B01~B09·B12 등 11 통과. 이 시점 B10·B11 미구현 |
| 구조 명령·serializer (`aa9075d`) | 2026-11-03 [기반 계층](Tests/results/2026-11-03/f5-block-model.log): B01~B12 관련 26 통과. 2026-11-05 [재검사](Tests/results/2026-11-05/f5-visual-model.log)도 **26 통과·TypeScript/번들 생성 통과**. ID·선택·독립 경계·원문/체크 표식·지연 저장 응답 보호 |
| 실제 EditorView·형식 입력 | 2026-11-05 [WKWebView](Tests/results/2026-11-05/f5-visual-webkit.log): 파일/인라인 CSP 경로의 모델 18개와 **시각 DOM/입력 시뮬레이션 92개 통과**, 실패/SKIP 0. H1~H6·인용문·목록/체크·코드·16개 형식 메뉴·inline marks·구분선/수식·커서·Unicode paste·보호 원문·snapshot/history. 합성 composition 검사는 실제 IME의 증거가 아님 |
| native 저장·수명 | 2026-11-05 [새 모드 17 통과](Tests/results/2026-11-05/f5-visual-native.log): production ContentView 두 문서·native Undo/Redo·dirty 알림 지연 직후 Close·clean Close·저장 중 후속 변경·실패/재시도·외부 reload·Don't Save·Save-and-close·미리보기 정리. controlled NSDocument/revert·지연 쓰기이며 실제 최초 Save 패널/권한 창/IME는 미검증 |
| 실제 Computer Use·빌드 | 2026-11-05 [독립 Debug 빌드](Tests/results/2026-11-05/f5-visual-build.log) 성공. [관찰·디스크 근거](Tests/results/2026-11-05/f5-visual-gui.json): `##` Space→회색 Header 2→한글 붙여넣기→실시간 제목, `>` Space→Quote, `[]` Space→To-do·체크, ⌘Z/⇧⌘Z·⌘S·재열기 확인. 실제 한글 조합 입력은 미검증. 닫기 경고/취소·모드 왕복·clean 닫기 확인. 모드 전환 직후 편집 영역 포커스 없는 ⌘W는 백그라운드 조작에서 닫히지 않아 후속 포커스/단축키 검증에 남김. 설치 앱 교체 없음 |
| 기존 경로 회귀 | 2026-11-05 [Native](Tests/results/2026-11-05/f5-visual-legacy-native.log) 8그룹·[WebKit](Tests/results/2026-11-05/f5-visual-legacy-webkit.log) 15개·[기존 체크 저장](Tests/results/2026-11-05/f5-visual-legacy-tasks.log) 17개·[Hosted](Tests/results/2026-11-05/f5-visual-hosted.log) **317 통과**, 실패/XFAIL/SKIP 0. 통합 전 GUI의 [관찰](Tests/results/2026-11-05/f5-ui-observations.json)·[빌드](Tests/results/2026-11-05/f5-ui-build.log)도 보존. 기존 경로 결과를 새 모드 전체 기능 검증으로 합산하지 않음 |

- 보존 한계: 미지원 원문이 있는 컨테이너의 재구조화는 export를 거절하고 dirty·Undo를 유지합니다. 형제 이동/목록 indent·outdent 범위, 빈 문단의 개별 ID/서식이 Markdown 재열기 시 gap으로 돌아오는 한계는 유지합니다. HTML 붙여넣기는 schema parser를 사용하지만 임의 형식·이미지/표의 왕복 보존까지 검증한 것은 아닙니다. 링크는 안전한 시각 span이며 열기/주소 수정 UI, 이미지 크기/캡션 조절·표 행/열 편집은 후속입니다.
- 실험 모드의 dirty는 generation을 검사하고 Save는 엔진 내부의 문서별 token으로 승인합니다. 계획의 전체 message envelope(schemaVersion/documentId/requestId 등) 통합, 실제 IME·위 미검증 기능과 [종료 cleanup 29번](BUG_FIXES.md#29-앱-메뉴-quit-후-고유-미리보기-파일-잔류)을 확인하기 전에는 기본값을 바꾸거나 기존 편집 코드를 제거하지 않습니다.
- 의존성은 lockfile 고정이며 KaTeX·폰트·라이선스를 오프라인 앱 리소스로 번들합니다. [빌드/재검사 방법](Tests/README.md#new-block-model-f5), [라이선스](THIRD_PARTY.md). 원격 CI·공개 배포는 이번 로컬 구현 범위 밖입니다.
