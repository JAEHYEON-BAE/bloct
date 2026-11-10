# Bloct 구현 현황 및 계획

- 최신화: **2026-11-10**. 현재 소스 버전은 **2.0.0**입니다. 서식 바·Aa 버튼 제거와 본문 클릭/Esc 편집은 2026-11-09 실사용 검증했으며, [45번 창 종료 충돌](BUG_FIXES.md#bug-45)은 별도 미해결입니다.
- 기능의 현재 상태·설계 계약·다음 순서는 이 문서, 버그의 재현·검증·한계는 [BUG_FIXES.md](BUG_FIXES.md)에서 관리합니다. 기록 규칙은 [AGENTS.md](AGENTS.md)를 따릅니다.

## 기능 상태

| ID | 항목 | 상태·다음 조치 |
|---|---|---|
| F1 | 체크박스 토글·상태 저장 | 2026-10-26 해당 범위 검증·v1.8.0 공개 ZIP/Homebrew 확인 완료. 자동 저장은 미구현 |
| F2 | 큰 문서 성능·중복 코드 정리 | 검토 대기. 측정 후 병목과 중복을 정리 |
| F3 | 문서 타입·확대 단축키 | 검토 대기. UTType/문서 역할과 실제 키 입력 확인 |
| F4 | 별도 정의 참조 링크 | 사용자 정책으로 보류. 정의 확인·편집 수단과 함께 재검토 |
| F5 | Notion 방식 블록·연속 편집 | **최우선 / 구현 후 검증 대기.** [본문 클릭/Esc 편집](Tests/results/2026-11-09/click-focus-gui.json)·[Text 경계 병합](BUG_FIXES.md#bug-42)·[Space 표식](BUG_FIXES.md#bug-43)·[서식 안의 코드](BUG_FIXES.md#bug-44)와 표·입력·모양은 해당 범위 검증 완료. **창 종료 충돌 45번 우선 조사**. 실제 IME·기존 기능 대응·정상 종료는 아래 관문 참조 |

기존 저장·Undo·보안·이미지·외부 갱신·배포의 상태는 버그 1·6·14·15·18·20~25번을 따릅니다. F5 구현만으로 기존 Markdown 경로의 미해결 버그를 완료 처리하지 않습니다.

## F1. 체크박스 토글 및 상태 저장

- GFM `- [ ]`·`- [x]`·`- [X]`는 첫 클릭으로 편집에 진입하며 한 번 토글합니다. Tab/Space는 편집 중에만 동작합니다. 읽기에서도 동일한 18px 사각형을 목록 기호 칸에 표시하며 별도 bullet·포커스 테두리는 없습니다. 기존 경로의 `[]` 단축 입력·클릭 즉시 자동 저장은 범위 밖입니다.
- 엔진 트랜잭션·archive의 UTF-16 위치로 중복/중첩/인용/CRLF를 구분해 체크 표식 한 글자만 패치합니다. 같은 엔진이 읽기 상태의 비활성 체크 표시도 담당합니다. [task-lists.js](Sources/Bloct/task-lists.js)는 호환 렌더러의 비활성 표시만 담당하며 변경 브리지는 없습니다. 코드·이스케이프·작성자 HTML/위조 입력은 변경 권한이 없습니다.
- 한 토글은 Undo 한 단계이며 명시적 Save 스냅샷을 사용합니다. 저장 중 추가 입력, 실패/Cancel의 초안·창 보존, Don't Save의 마지막 저장 상태 복원을 유지합니다.
- **2026-10-26 검증:** [Hosted 317](Tests/results/2026-10-26/release-1.8.0-hosted.log)·[native 저장 17](Tests/results/2026-10-26/release-1.8.0-tasks.log) 통과, 실패/XFAIL/SKIP 0. [GUI](Tests/results/2026-10-26/f1-gui.json)·[최종 정렬 GUI](Tests/results/2026-10-26/checkbox-indent-gui.json)·[정렬 회귀 317](Tests/results/2026-10-26/checkbox-indent-hosted.log). 공개 배포 근거는 버그 22·23번에 둡니다.
- 한계: 지연 쓰기·native revert는 통제된 자동 검사입니다. 실제 GUI 권한 오류/재저장은 확인했지만 macOS 14 기기·공개 Release GUI·큰 문서 성능은 미검증입니다. [종료 자동화 26번](BUG_FIXES.md#26-gui-테스트-중-finder-bloct-is-not-open-anymore)은 별도 조사 중입니다.

## F2·F3. 검토 대기

- **F2:** 입력의 줄 배열 복사·전체 파싱/DOM/목차 갱신·검색 순회 비용을 먼저 측정합니다. 효과를 확인한 뒤 캐시·디바운스·버퍼 분리를 결정합니다. Undo 후 저장 상태 복귀는 내용 비교로 판단하고 버전 카운터만으로 대체하지 않습니다.
- **F3:** `CFBundleTypeRole`의 Viewer/Editor, UTType의 `public.text`/`public.plain-text`, 실제 ⌘= 확대를 확인합니다. 격리 GUI 앱의 `.md` 선택 제한은 아직 원인 미확정이며 최근 표 검증은 Markdown 내용의 `.txt`를 사용했습니다([35번](BUG_FIXES.md#35-aa-표의-빈-셀-안내-문구)).

## F4. 별도 정의 참조 링크 — 보류

- 2026-10-17 사용자 정책입니다. 정의 목록/원문 확인·편집·저장·Undo와 링크 해석을 함께 설계하며 재개 요청 전에는 구현하지 않습니다. 현재 접근 한계와 임시 경로는 [16번](BUG_FIXES.md#16-별도-정의-참조-링크--보류)을 따릅니다.

## F5. Notion 방식의 블록 관리와 연속 편집

### 현재 구현

- **2026-11-09 본문 클릭/Esc 편집 검증 완료.** 기본은 읽기이며 본문 클릭 시 외부 파일 확인을 거쳐 클릭한 위치에 커서를 둡니다. Esc는 초안을 보존한 읽기로 돌아갑니다. Aa 버튼·상단 서식 바 없이 같은 WebView/페이지/EditorView를 유지하므로 본문 모양·스크롤·history가 이어집니다. 전환 자체는 저장하지 않습니다([실사용](Tests/results/2026-11-09/click-focus-gui.json)).
- `@tiptap/pm`의 ProseMirror `EditorView` 하나로 문단·H1~H6·인용·일반/번호/할 일 목록·코드·구분선·수식·이미지·단순 GFM 표·인라인 mark를 편집합니다. 미지원 구문은 정제된 읽기 전용 미리보기와 표면 클릭으로 여는 `View source`로 보호합니다. 이미지도 기존 크기/정렬을 표시하고 표면 클릭으로 편집합니다. 체크박스·목록·표·공백/구분선의 전환 전후 모양 대응은 [40번](BUG_FIXES.md#bug-40)을 따릅니다.
- 양 모드가 오프라인 KaTeX/CSS/폰트를 공유합니다. 수식은 hover 또는 화살표 선택 시 영역 전체를 회색으로 강조하고, 클릭 또는 Enter/Space로 같은 편집 창을 엽니다. 수식 선택의 파란 텍스트 선택·테두리는 숨기며 읽기/저장 freeze·조합 중에는 편집 창을 열지 않습니다. 2026-11-05 [수식 GUI](Tests/results/2026-11-05/f5-math-hover-gui.json)·사용자 hover 확인 완료. 수식 파싱·폰트 수정은 [27·28번](BUG_FIXES.md#bug-27), 입력/전환/표·빈 영역·모양·편집 통합은 30~44번을 따릅니다.

| 책임 | 소스 |
|---|---|
| 스키마·빈 줄 호환 구간·구문/원문 대응 | [schema.ts](Editor/src/schema.ts), [importer.ts](Editor/src/importer.ts), [math-syntax.ts](Editor/src/math-syntax.ts) |
| ID·트랜잭션·history·저장 기준·직렬화 | [session.ts](Editor/src/session.ts), [serializer.ts](Editor/src/serializer.ts) |
| 연속 입력·키보드·서식 명령·검색 장식·노드 UI | [visual-editor.ts](Editor/src/visual-editor.ts) |
| 모드 인계·브리지·Save/Close/Reload | [editor-switch.js](Sources/Bloct/editor-switch.js), [VisualEditorHTML.swift](Sources/Bloct/VisualEditorHTML.swift), [ContentView.swift](Sources/Bloct/ContentView.swift) |

### 유지할 설계·보존 계약

1. **편집 상태의 소유자는 엔진 트리 하나입니다.** 선택·history·부모/순서는 트리에서 관리하며 별도 가변 BlockStore나 Swift 문자열을 동시 편집원으로 두지 않습니다. 매 키 입력에 전체 Markdown 재파싱·DOM 교체·Swift 원문 echo를 하지 않습니다.
2. **빈 줄은 독립 파싱·목록 그룹 경계입니다.** 내부는 의미 블록으로 세분화하되 다른 그룹의 번호 목록·들여쓰기 코드를 자동 병합하지 않습니다. 단일 soft 개행·화면 줄바꿈은 새 블록이 아니며 hard break는 `\`+개행입니다. [기준 fixture](Tests/fixtures/bug-16-block-context.md)를 유지합니다.
3. **원문과 위치:** 무편집 export는 원문 그대로입니다. BOM·CRLF·공백·미수정 최상위 소유 구간을 보존하고, 체크만 바뀌면 표식 한 글자 패치, 그 외 변경은 소유 컨테이너 직렬화 후 재파싱으로 의미를 검증합니다. 범위는 UTF-16 반열림 구간이며 최초 archive 좌표를 변경 후 엔진 위치로 쓰지 않습니다. 일반 수정의 완전한 최소 패치를 보장하지 않습니다.
4. **ID·권한:** 세션 내 ID는 입력/타입 변경/이동에 유지합니다. 분할은 앞 ID 유지/뒤 새 ID, 복제는 자식까지 새 ID, 병합은 앞 ID입니다. Undo는 ID·경계·선택을 복원하고 재열기/외부 수용은 새 세대입니다. DOM 속성은 수정 권한이 아니며 엔진 참조·세대·revision으로 검증합니다. ID를 `.md`에 영속화하지 않습니다.
5. **저장·Undo:** Save는 고정 스냅샷과 문서별 token을 승인하고 후속 입력은 dirty로 남깁니다. 실패/Cancel은 초안·창을 유지하고 Don't Save는 마지막 저장 상태로 돌아갑니다. 구조 명령은 트랜잭션/history 경계, 텍스트는 엔진의 연속 입력 묶음을 사용합니다. 메뉴/키보드는 같은 history에 한 번만 전달합니다. 본문 클릭/Esc는 같은 엔진과 개별 입력 history를 유지하며 네이티브 문자열 checkpoint도 보존합니다. 재열기·외부 reload는 새 세대입니다. 외부 파일 비교·원자적 쓰기·세대 보호를 유지합니다.
6. **보호·한계:** 저장 결과의 의미/원문 보호를 검증할 수 없으면 export를 거절하고 초안·Undo를 유지합니다. `raw_source`가 있는 컨테이너의 재구조화·읽기 전용 원문 UI 한계가 남습니다. 빈 최상위 문단은 Markdown gap으로 저장되므로 재열기 뒤 개별 ID/서식은 복원하지 못합니다. 숨은 HTML/sidecar를 도입하지 않습니다. 이미지에는 원본 경로를 저장하며 `bloct-image`·blob 표시 URL을 쓰지 않습니다.
7. **보안·범위:** nonce CSP·탐색/메인 프레임/페이지 URL·HTML/URL 검증·문서별 이미지 격리를 유지합니다. 엔진 소유 DOM과 비신뢰 HTML을 구분합니다. 단순 표만 지원하며 셀 병합/다중 문단은 허용하지 않습니다. 클라우드·협업·데이터베이스·다단 레이아웃은 범위 밖, F4는 보류입니다. 의존성 lockfile·KaTeX/폰트/라이선스 오프라인 번들을 유지합니다([THIRD_PARTY.md](THIRD_PARTY.md)).

### 입력 계약

| 입력·상태 | 현재 동작 |
|---|---|
| 본문 클릭 / Esc | 클릭한 글자 위치에 커서를 두고 본문/체크 변경·Undo/Redo 활성화. Esc는 초안·Save·재진입·history·화면 위치를 유지한 읽기 전용. 팝업의 Esc는 취소를 먼저 처리하며 IME 조합 중 Esc는 가로채지 않음 |
| 문서 열기·편집 진입·끝 빈 영역 클릭 | 문서 끝에 빈 일반 Text 줄 하나를 제공하고 기존 빈 줄은 재사용. 열기만으로 dirty/history/원문을 바꾸지 않으며 입력·타입 변경 후 일반 블록으로 저장. 반복 클릭은 줄을 누적하지 않음 |
| 빈 문단의 표식 + Space(실제 WebKit NBSP 포함, [43번](BUG_FIXES.md#bug-43)) | `#`~`######`: 제목; `>`: 인용; `-`/`+`/`*`: 불릿; 숫자+`.`/`)`: 번호; `[]`/`[ ]`/`[x]`: 할 일; 백틱 3개/`~~~`+선택적 언어: 코드; `---`/`***`: 구분선 |
| 문단·제목 Enter / Shift+Enter | 문단 Enter는 분할, Shift+Enter는 내부 hard break. 제목 Enter는 시작이면 앞 문단, 중간/끝이면 뒤 일반 문단; 제목 Shift+Enter도 Enter와 같음 |
| 목록·코드 | Enter는 목록 항목 분할·새 체크는 unchecked, 빈 항목은 outdent/문단 전환. 자식 보호를 유지함. Tab/Shift+Tab은 목록 indent/outdent. 코드 시작 표식은 Enter로도 변환, 코드 내부 Enter는 개행, Mod+Enter로 탈출 |
| Backspace·구조 삭제 | 제목/인용/목록 시작은 타입 해제/outdent를 우선하며 보호 노드·독립 경계를 임의 병합하지 않음. 일반 Text 시작 Backspace / 앞 문장 끝 Delete는 문단·제목·인용·불릿/번호/할 일 목록의 마지막 문장에 개행 없이 병합하고 커서는 경계에 둠. 새 항목/번호를 만들지 않으며 빈 Text 삭제도 유지([42번](BUG_FIXES.md#bug-42)). 입력 규칙 취소는 원래 기호 뒤 커서 복원 |
| `$...$`·`$$...$$` | 닫힌 비어 있지 않은 구문만 수식 변환. `$$`+Space는 텍스트. 여러 줄 display 입력은 연속 최상위 일반 문단만 모음. 코드·서식/원자 노드를 넘지 않음 |
| 표의 화살표 | 셀 안 글자/표시 줄 이동 후 인접 행·열로 이동. 첫 행 ↑/마지막 행 ↓는 표 앞/뒤 영역, 영역이 없으면 최상위 블록 앞/뒤 새 문단. 좌우는 행을 넘지 않음 |
| 표의 Enter·Tab | Enter는 아래 행 첫 셀, 마지막 행이면 표 아래 새 문단. Tab/Shift+Tab은 같은 표의 다음/이전 셀, 마지막 Tab은 표 아래 새 문단 |
| 표의 Shift+Enter | 머리글·중간·끝 어느 행에서도 바로 아래 빈 행 삽입 후 **새 행 첫 열 시작**으로 이동 |
| 안내·조합·붙여넣기 | 빈 제목·코드만 더 연한 회색 안내를 표시하며 Text·Quote·불릿/번호/할 일 목록·표 셀은 비움. 안내는 장식이며 실제 입력 글자의 색은 유지함. 조합 중 타입 변환/강제 blur/DOM 교체를 피함. 가져오기·일반 붙여넣기는 타이핑 규칙을 실행하지 않음 |

`>`는 Notion 토글이 아닌 Markdown 인용입니다. 미완성 구문은 텍스트로 보존하고 안내·검색 강조·핸들은 원문/history에 넣지 않습니다. 완성된 inline code 뒤 입력은 일반 서식으로 복귀합니다. 실제 복사/PDF에서 장식 제외까지의 수용 검증은 아래 관문에 남아 있습니다.

### 검증 근거와 수용 기준

각 결과는 해당 날짜·계층의 근거이며 전체 앱 완료 판정이 아닙니다. 실행 방법은 [Tests/README.md](Tests/README.md#new-block-model-f5), 버그별 상세는 BUG_FIXES.md를 따릅니다.

| 범위 | 마지막 기록된 결과 |
|---|---|
| v2.0.0 배포 | 2026-11-10 [Release 빌드·SDK/CPU](Tests/results/2026-11-10/release-2.0.0-local.json)·[회귀 검사](Tests/results/2026-11-10/release-2.0.0-checks.json)·[공개 ZIP/Homebrew](Tests/results/2026-11-10/release-2.0.0-published.json) 검증 완료. SDK 27·최소 macOS 14·Universal, 공개 ZIP/GitHub digest/cask SHA256와 리소스 11개 일치. 실제 IME·공개 Release GUI는 미검증, 창 종료 45번은 미해결 |
| 편집 UI | 2026-11-09 서식 바·Aa 버튼 제거와 본문 클릭/Esc 편집. [모델 36·번들](Tests/results/2026-11-09/click-focus-model.log)·[브라우저 모델 18·시각 입력 332](Tests/results/2026-11-09/click-focus-visual.log)·[native 41](Tests/results/2026-11-09/click-focus-native.log)·[WebKit/레이아웃 54·모양 864·클릭 38](Tests/results/2026-11-09/click-focus-webkit.log)·[앱 빌드](Tests/results/2026-11-09/click-focus-build.log) 통과. [Computer Use](Tests/results/2026-11-09/click-focus-gui.json): 클릭 위치의 즉시 입력·Esc 읽기 차단·초안/Undo/Save·수식 팝업·새 문서·긴 문서 위치 불변·두 창·종료 확인. [원문·종료 감사](Tests/results/2026-11-09/click-focus-gui-disk.json). [서식 바 제거 단독 검증](Tests/results/2026-11-09/no-toolbar-gui.json). 실제 IME·45번은 별도 |
| 빈 블록 안내 표시 | 2026-11-09 Text/Quote/목록 안내 제거·제목/코드 안내 색 보완. [기본 블록 실사용](Tests/results/2026-11-09/plain-guides-gui.json)·[색상 실사용](Tests/results/2026-11-09/light-guides-gui.json)에서 표시·즉시 입력/Undo/Save·원문 보존 확인. [번들](Tests/results/2026-11-09/light-guides-build.log)·[브라우저 모델 18·시각 입력 332](Tests/results/2026-11-09/light-guides-visual.log)·[WebKit/레이아웃 50·모양 864](Tests/results/2026-11-09/light-guides-webkit.log) 통과. [원문·종료 감사](Tests/results/2026-11-09/light-guides-gui-disk.json) |
| 자동 마지막 Text 줄 | 2026-11-09 [모델 36·번들](Tests/results/2026-11-09/trailing-line-model.log)·[브라우저 모델 18·시각 입력 332](Tests/results/2026-11-09/trailing-line-visual.log)·[native 40](Tests/results/2026-11-09/trailing-line-native.log)·[WebKit/레이아웃 50·모양 864](Tests/results/2026-11-09/trailing-line-webkit.log) 통과. [Computer Use](Tests/results/2026-11-09/trailing-line-gui.json): 목록 뒤 자동 Text 입력/저장/Undo, 기존 EOF 공백 재사용·두 창·읽기 전환·종료. [원문·종료 감사](Tests/results/2026-11-09/trailing-line-gui-disk.json). 실제 IME·45번은 별도 |
| 수식 화살표 선택·Enter 편집 | 2026-11-09 [모델 34·번들](Tests/results/2026-11-09/math-keyboard-model.log)·[브라우저 모델 18·시각 입력 312](Tests/results/2026-11-09/math-keyboard-visual.log) 통과, 실패/SKIP 0. [Computer Use](Tests/results/2026-11-09/math-keyboard-gui.json)에서 블록 상·하/인라인 좌·우 진입·전체 회색 강조·Enter·Cancel/Apply·Save/Undo·재열기·읽기 차단·두 문서 전환 확인. [디스크/종료](Tests/results/2026-11-09/math-keyboard-gui-disk.json): 원문 복원·앱 종료·새 충돌/미리보기 잔류 없음. 실제 IME와 45번은 별도 |
| 기반 모델·원문·명령 | 2026-11-03 `658e107`·`aa9075d` [B01~B12 기반 26](Tests/results/2026-11-03/f5-block-model.log). 2026-11-08 [TypeScript·모델 34·번들](Tests/results/2026-11-08/text-boundary-model.log) 통과 |
| 실제 WebKit의 입력 시뮬레이션 | 2026-11-08 [브라우저 모델 18·시각 입력 296](Tests/results/2026-11-08/text-boundary-visual.log), 실패/SKIP 0. 합성 composition은 실제 IME 근거가 아님 |
| native 저장·문서 수명 | 2026-11-07 [40 통과](Tests/results/2026-11-07/aa-only-native.log). production ContentView·두 문서·history·지연 dirty/쓰기·실패/재시도·Reload/폐기/닫기. NSDocument/revert·지연 쓰기는 통제됨 |
| 공통 WebKit·기존 경로 | 2026-11-07 [통합/레이아웃 51·모양/동작 864](Tests/results/2026-11-07/aa-only-webkit.log). 2026-11-07 [Hosted 270](Tests/results/2026-11-07/aa-only-hosted.log)·[이미지 70](Tests/results/2026-11-07/aa-only-images.log). 옛 Edit 전용 검사는 Aa 계약 검사로 교체했으며 체크 native는 위 40개에 통합, 실패/XFAIL/SKIP 0. 새 모드 전체 기능 검증으로 합산하지 않음 |
| 실제 앱·빌드 | 2026-11-05 [최초 형식 입력/저장 GUI](Tests/results/2026-11-05/f5-visual-gui.json), 한글은 붙여넣기. 2026-11-06 표 [빌드](Tests/results/2026-11-06/table-down-exit-build.log)·[GUI/디스크/앱 종료](Tests/results/2026-11-06/table-down-exit-gui.json); 2026-11-07 [빌드·새 문서/하단 입력 GUI](Tests/results/2026-11-07/empty-aa-gui.json). [Aa 모양/체크/이미지/하단 입력 GUI](Tests/results/2026-11-07/appearance-gui.json). [단일 Aa GUI/종료 미확인](Tests/results/2026-11-07/aa-only-gui.json). 2026-11-08 [Backspace GUI](Tests/results/2026-11-08/empty-backspace-gui.json)·[실제 Space 표식 GUI/저장·앱 종료](Tests/results/2026-11-08/space-markers-gui.json). [PS1 서식 코드 Aa·실제 편집·저장/Undo GUI](Tests/results/2026-11-08/code-marks-gui.json). [Text 양방향 병합/번호 보존 GUI](Tests/results/2026-11-08/text-boundary-gui.json). 2026-11-08 과거 종료 검증은 [충돌 감사](Tests/results/2026-11-08/window-close-crashes.json)로 재개방(45번). 모드·수식·입력·표의 세부 범위/한계는 버그 27~45번 |

기존 수용 ID는 유지합니다: **B01~B04** 의미 분할·soft/hard break·독립 목록·중첩/중복 ID, **B05~B08** 코드/수식 보호·표/이미지 속성·미지원 원문, **B09~B12** Unicode/UTF-16/BOM/개행/gap·구조 명령 Undo·체크 위치/위조 거절·빈 파일/제목 왕복입니다. 새 importer 통과를 기본 렌더러의 버그 4·17·13 해결 근거로 사용하지 않습니다.

### 다음 순서와 기본값 전환 관문

**우선 조사:** [45번](BUG_FIXES.md#bug-45)의 창 닫기 native 충돌. 2026-11-08 GUI의 앱 목록 소멸은 정상 종료 증거가 아니며, 실제 종료 코드·새 crash report 부재로 다시 검증합니다.

1. **실제 IME(U03):** macOS 한글·한자·emoji 조합 중 입력 규칙/Undo/Save/Reload/검색 포커스/Close. U01·U02의 형식 입력 자동 검사와 한글 붙여넣기는 이를 대체하지 않습니다.
2. **저장·외부 변경(S01·S02):** 새 문서 최초 Save 취소, 권한 실패/재시도, 충돌 선택 UI·사본 저장, 지연 응답 중 추가 입력, rename/삭제/원자적 교체, 다중 창 종료를 실제 패널로 검증합니다. 비동기 검사 후 조합/편집이 생기면 과거 clean 결과로 덮어쓰지 않습니다. [종료 cleanup 29번](BUG_FIXES.md#29-앱-메뉴-quit-후-고유-미리보기-파일-잔류)도 확인합니다.
3. **기능 대응·보안(S03):** 부분 선택 Markdown/일반 텍스트/HTML 복사·붙여넣기, PDF 본문/UI 제외, 목차·검색(중복/수식 제목 포함), 상대 이미지/속성/캡션·문서 이동, 링크/원문 편집 UI, 표 행 삭제/열 편집을 확인합니다. 보호 원문·악성 HTML·위조 명령 회귀와 `documentId/generation/revision/requestId/schemaVersion` 전체 브리지 envelope 통합도 남아 있습니다.
4. **사용성·성능:** 키보드 포커스/VoiceOver·dark/zoom, 대표 100KB/1MB/5MB·표/수식/이미지 혼합 문서의 입력/조합/열기/검색/직렬화 시간·메모리를 측정합니다. 지원 크기/지연 기준은 측정 후 정합니다. macOS 14 실제 기기·공개 Release GUI는 별도 검증입니다.
5. **수용·배포 판단:** 사용자 요청으로 2026-11-09 개발 버전은 Aa 버튼 없이 본문 클릭/Esc로 편집 포커스를 전환합니다. 위 관문과 원문·빈 줄 경계·저장 보호의 미검증 범위는 유지하며, 옛 textarea를 복구해 완료 근거를 대체하지 않습니다. 슬래시 메뉴·핸들·임의 드래그/이동은 이후 범위이며 현재 구조 명령은 형제 이동·목록 indent/outdent에 제한됩니다. 공개 배포는 별도 요청 범위입니다.
