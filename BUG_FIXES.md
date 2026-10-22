# Bloct 오류·버그 및 수정 기록

- 최신화: **2026-10-22** — 20번 초기 로드 회귀를 수정하고 자동·GUI 검증을 완료했습니다. 나머지 결과는 각 항목의 날짜를 따릅니다.
- 현재: 총 25개 중 **11개 해당 범위 검증 완료**, **16번 보류**, **13개 미해결·조사 중**. 구현 요약·새 기능 계획은 [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md), 기록 정책은 [AGENTS.md](AGENTS.md)를 따릅니다.
- 다음 순서: **4·17번 → 2·7·8·13번 → 3·5·9·10번 → 11·12·19번**. 다음 새 버그 번호는 26번입니다.

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
- 최소 재현·완료: 더 긴 닫는 펜스·미종결 펜스·코드 안 수식/이미지 예제로 렌더링·편집·저장 원문 불변을 확인합니다. 빈 줄로 나뉜 독립 블록은 병합하지 않습니다.
- 자리표시자는 `ac191f7`에서 바뀌었으므로 과거 `<mvmath …>` 노출을 현재 출력이라고 재사용하지 않습니다. 현재 원문 보존을 기준으로 회귀를 추가합니다.

## 16. 별도 정의 참조 링크 — 보류

- **2026-10-17 / 사용자 정책에 따라 보류**. 다른 블록의 참조 정의를 쉽게 확인·편집할 수단과 함께 지원을 검토합니다. 현재는 직접 주소 링크를 사용하며 [F4](IMPLEMENTATION_PLAN.md#f4-별도-정의-참조-링크--보류) 재개 전에는 구현하지 않습니다.
- **빈 줄은 독립 블록 경계**입니다. 빈 줄로 나눈 목록의 번호 재시작과 들여쓰기 블록의 독립 렌더링은 정상입니다. 같은 블록의 줄바꿈은 빈 줄 없이 줄 끝에 `\`를 사용합니다. [확인 문서](Tests/fixtures/bug-16-block-context.md).
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

## 최신 배포 검증 기록 — 2026-10-22

v1.7.5·v1.7.6는 2026-10-22 원격 실행·공개 ZIP·cask를 확인했고, 이전 버전 행은 2026-10-17 기록입니다. 설치 앱 교체·공개 Release의 실제 GUI·macOS 14 기기 실행은 범위 밖입니다.

| 버전 | 결과·근거 |
|---|---|
| v1.7.6 (`ff94d34`) | 20번 수정 포함. [Release](https://github.com/JAEHYEON-BAE/bloct/releases/tag/v1.7.6)·[Release Actions](https://github.com/JAEHYEON-BAE/bloct/actions/runs/39732136173)·[tap Actions](https://github.com/JAEHYEON-BAE/homebrew-tap/actions/runs/39732350275) success. [공개 ZIP/cask 검증](Tests/results/2026-10-22/release-1.7.6-published.json): 버전 1.7.6·SDK 27·최소 OS 14·두 CPU 및 ZIP/digest/cask SHA256 일치, tap 변경 `fe3e95d` |
| v1.7.5 (`958e4ae`) | 25번 수정·사용자 해결 확인. [Release](https://github.com/JAEHYEON-BAE/bloct/releases/tag/v1.7.5)·[Release Actions](https://github.com/JAEHYEON-BAE/bloct/actions/runs/39711758926)·[tap Actions](https://github.com/JAEHYEON-BAE/homebrew-tap/actions/runs/39711903573) success. [공개 ZIP/cask 검증](Tests/results/2026-10-22/release-1.7.5-published.json): 버전 1.7.5·SDK 27·최소 OS 14·두 CPU 및 ZIP/digest/cask SHA256 일치, tap 변경 `6b29507` |
| v1.7.4 (`0ff3e30`) | [Release](https://github.com/JAEHYEON-BAE/bloct/releases/tag/v1.7.4)·[Actions](Tests/results/2026-10-17/release-1.7.4-actions.json) success. [공개 ZIP](Tests/results/2026-10-17/release-1.7.4-published.json)의 버전·SDK 27·최소 OS 14·두 CPU, [ZIP/digest/cask 체크섬](Tests/results/2026-10-17/release-1.7.4-checksums.json) 일치. [tap 실행](Tests/results/2026-10-17/release-1.7.4-tap-actions.json) success·변경 `fa2ae75` |
| v1.7.3 (`c8bf59a`) | 24번 수정 포함. [공개 ZIP](Tests/results/2026-10-17/release-1.7.3-published.json) 구성·[체크섬](Tests/results/2026-10-17/release-1.7.3-checksums.json) 검증, [Release](Tests/results/2026-10-17/release-1.7.3-actions.json)·[tap](Tests/results/2026-10-17/release-1.7.3-tap-actions.json) success·변경 `2bf8523` |

## 검사 범위와 근거

검사 명령과 계층은 [Tests/README.md](Tests/README.md)를 따릅니다. 합성 이벤트·호스팅 검사는 실제 창·포커스·마우스·저장 패널·클립보드·PDF 검증을 대신하지 않습니다. 과거 로그는 덮어쓰거나 최신 수치에 합산하지 않습니다. 2026-10-14 결과와 `relative-images.log`는 과거/수정 전, `relative-images-fixed.log`·`reload-*.log`는 해당 수정 후 근거입니다. 상세 경과는 Git 이력과 원시 증거에서 확인합니다.
