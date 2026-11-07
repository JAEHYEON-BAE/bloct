# Bloct 오류·버그 및 수정 기록

- 최신화: **2026-11-07**. 편집 진입을 Aa로 통합하고 기존 Edit/textarea 경로를 제거했습니다. GUI 종료 접근 한계는 26번에 반영했습니다.
- 현재: 총 41개 중 **25개 해당 범위 검증 완료**, **3·5·9번 경로 제거**, **16번 보류**, **12개 미해결·조사 중**. 구현 요약·새 기능 계획은 [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md), 기록 정책은 [AGENTS.md](AGENTS.md)를 따릅니다.
- 다음 순서: **[F5의 다음 순서와 전환 관문](IMPLEMENTATION_PLAN.md#다음-순서와-기본값-전환-관문)**을 최우선으로 진행합니다. 읽기 렌더러/기존 기능의 조사 순서는 **4·17번 → 2·7·8·13번 → 10번 → 11·12·19번**입니다. 26번의 창 접근/종료 확인을 재검증합니다. 다음 새 버그 번호는 42번입니다.

## 항목별 상태

번호와 확인 수준을 유지합니다. 과거 Node/WebKit 보고·정적 코드 확인은 현재 앱의 실제 이벤트 재현과 구분합니다. 완료는 해당 검사 범위의 판정이며 앱 전체 무결함을 뜻하지 않습니다.

| # | 문제 | 현재 상태 | 우선순위·근거 |
|---|---|---|---|
| 1 | Undo/Redo와 저장 문서 불일치 | 수정·재검증 완료(2026-10-15) | 전용 Undo·저장 전 버퍼 분리, 실제 GUI 연속 Undo/Redo·저장·폐기 통과 |
| 2 | 물결표 사이 서식 소실 | 미해결 | 중간 / 기존 Node·WebKit 보고, tokenizer 유지 |
| 3 | 편집 후 다른 블록을 두 번 클릭해야 열림 | 경로 제거(2026-11-07) | 기존 textarea/blur 편집 제거. Aa 계약은 41번/F5 |
| 4 | 더 긴 닫는 펜스의 코드 보호 실패 | 미해결 | 중간 / 기존 재현, 보호 정규식 유지 |
| 5 | 새 문서 첫 입력 앞에 빈 줄 추가 | 경로 제거(2026-11-07) | 기존 textarea 추가 경로 제거. Aa 첫 입력은 38·39번 |
| 6 | 저장 결과 전에 변경 상태 해제·닫기 | 수정·재검증 완료(2026-10-15) | 스냅샷 저장, 실제 취소·실패·재저장·다중 창 종료 통과 |
| 7 | 수식 제목의 ID·목차 텍스트 중복 | 미해결 | 중간 / 이전 WebKit 보고, textContent 사용 유지 |
| 8 | 중복 제목 ID와 앵커 이동 충돌 | 미해결 | 중간 / ID 생성·이벤트 전파 코드 확인 |
| 9 | 목차 빈 영역 클릭이 추가 편집기를 엶 | 경로 제거(2026-11-07) | 추가 영역/옛 클릭 편집 핸들러 제거. Aa 외 읽기 전용 |
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
| 36 | Aa 표의 화살표 이동·위/아래 탈출 | 수정·해당 범위 검증 완료(2026-11-06) | 첫 행 ↑는 표 앞, 마지막 행 ↓는 표 뒤 영역 이동. 문서 시작/끝이면 새 문단 생성 |
| 37 | Aa 표의 Enter 행 이동·Shift+Enter 행 삽입 | 수정·해당 범위 검증 완료(2026-11-06) | Enter는 아래 행 첫 셀, Shift+Enter는 새 행 첫 셀 이동. Undo·저장·재열기 확인 |
| 38 | 새 문서 Aa 초기화 JavaScript 오류 | 수정·해당 범위 검증 완료(2026-11-07) | about:blank의 randomUUID 부재 재현, getRandomValues 기반 UUID fallback·첫 입력/저장 확인 |
| 39 | Aa 빈 문서·문서 끝 빈 영역에서 입력 불가 | 수정·해당 범위 검증 완료(2026-11-07) | 하단 클릭 시 일반 문단 생성/재사용, Undo·재파싱·GUI 저장/재열기 확인 |
| 40 | Aa 전환 시 체크박스·다른 본문 요소 모양 변경 | 수정·해당 범위 검증 완료(2026-11-07) | 공통 체크 스타일·중첩 간격·표 정렬/줄무늬·이미지/보호 미리보기·공백/구분선 대응 |
| 41 | Aa 해제 후 기존 Edit 상태가 남고 편집 진입이 이중화됨 | 수정·해당 범위 검증 완료(2026-11-07) | Aa 단일 상태/버튼. 꺼짐은 읽기 전용, 초안·저장·재진입 보존. GUI 종료는 26번 |

<a id="bug-41"></a>
## 41. Aa 편집 통합과 기존 Edit 상태 제거

- **2026-11-07 / 수정·해당 범위 검증 완료.** 기존 Aa 해제는 별도 `isEditMode`를 true로 남겨 본문 클릭 시 textarea 편집이 계속됐습니다. 연필 Edit 버튼·Swift 상태·WebKit 모드 setter/클릭/textarea 경로·읽기 화면의 체크 변경 브리지를 제거했습니다. 기본은 읽기, **Aa 켜짐만 수정 가능**하며 꺼짐은 체크·본문 입력·Undo/Redo를 차단합니다. 같은 페이지·가시 위치·미저장 원문/dirty·명시적 Save·재진입 후 history 기준을 유지합니다. Aa 진입 전에 현재 디스크를 확인하고, 적용 전 속성 창이 있으면 Aa를 유지해 초안을 보호합니다.
- 자동 검증: [TypeScript·모델 33·번들](Tests/results/2026-11-07/aa-only-model.log)·[브라우저 모델 18/입력 200](Tests/results/2026-11-07/aa-only-visual.log)·[native 40](Tests/results/2026-11-07/aa-only-native.log)·[Hosted 270](Tests/results/2026-11-07/aa-only-hosted.log)·[WebKit 기존 51/모양·동작 864](Tests/results/2026-11-07/aa-only-webkit.log)·[이미지 70](Tests/results/2026-11-07/aa-only-images.log) 통과, 실패/XFAIL/SKIP 0. 옛 textarea/읽기 체크 변경 전용 검사는 Aa/읽기 계약 검사로 교체했으며, 기존 native 체크 저장 17개는 Aa native harness로 통합했습니다. 읽기 중 edit bridge·Undo 차단, Aa off 초안 Save/재진입, 진입 직전 외부 파일 반영, 속성 창 초안 보호를 검사합니다.
- [빌드](Tests/results/2026-11-07/aa-only-build.log)·[GUI/디스크 근거](Tests/results/2026-11-07/aa-only-gui.json): 연필 없는 Aa 단일 툴바, 읽기 상태 본문 클릭/키 입력 무변경, Aa 체크 토글→꺼짐 후 비활성/dirty 유지→읽기 상태 Save→재진입, 수식 속성 창의 Aa 해제 차단/Cancel→읽기 복귀, 별도 문서 기본 Aa off를 확인했습니다. 저장 파일은 첫 체크 표식 한 글자만 달라지고 나머지 원문·수식은 보존됐습니다.
- 한계: GUI AX 선택/타이핑 시도는 의도한 입력과 달라 Undo로 원복했으므로 정확한 실제 타이핑 수용 근거로 세지 않습니다. 두 번째 창 닫기 뒤 CUA가 반복 시간 초과해 **GUI 테스트 앱 종료 미확인·소유 미리보기 1개 유지**입니다(26번). 실제 IME/최초 Save 취소/전체 충돌 UI·macOS 14는 F5 관문에 남습니다. 이 한계를 자동 native 종료/정리 통과로 대체하지 않습니다.

<a id="bug-40"></a>
## 40. Aa 전환 시 체크박스와 본문 모양 변경

- **2026-11-07 / 수정·해당 범위 검증 완료.** [수정 전 비교](Tests/results/2026-11-07/appearance-before.log)에서 체크박스가 기존 18px 사각형에서 약 12.4px 시스템 기본 모양으로 변했고, 중첩 목록·표 정렬·이미지 크기/정렬/여백·보호 원문에도 차이가 재현됐습니다. 실제 GUI에서 표 첫 본문 행의 줄무늬 어긋남도 확인했습니다.
- 수정: 엔진 소유 체크박스에 기존 `.mv-task-checkbox` 스타일을 공유합니다. 중첩 목록 간격·표 헤더/열 정렬/본문 줄무늬·연속 공백·링크 hover·구분선 높이를 기존 렌더링에 맞췄습니다. 이미지와 미지원 원문은 동일한 정제 렌더러의 미리보기를 사용하고, 버튼이 본문 크기에 영향을 주지 않도록 이미지/원문 표면 클릭으로 편집/읽기 전용 원문을 엽니다. 작성자 HTML의 입력은 비활성이며 원문·권한 모델은 유지합니다. 이미지 URL 수정 시 캡션의 Markdown을 보존하고 상대 경로 표시 URL도 갱신합니다.
- 자동 검증: [TypeScript·모델 33·번들](Tests/results/2026-11-07/appearance-model.log), [브라우저 모델 18·시각 입력 200](Tests/results/2026-11-07/appearance-visual.log), [native 33](Tests/results/2026-11-07/appearance-native.log), [Hosted 317](Tests/results/2026-11-07/appearance-hosted.log) 통과. [WebKit 기존 51 + 모양/동작 864](Tests/results/2026-11-07/appearance-webkit.log) 통과, 실패/XFAIL/SKIP 0. 15개 요소군×900/640px×light/dark×100/125%×TOC on/off에서 치수·글꼴·색·테두리·행 배경·글자 위치·무편집 원문을 비교하고 이미지 수정/Undo/snapshot·이미지 뒤 빈 영역 입력·보호 미리보기 정제/원문 확인을 검사했습니다. 요소 치수 허용차는 0.1 CSS px, 글자 Range는 WebKit 공백/inline 경계 반올림을 고려해 위치 1px·폭 1.25px입니다. [문단 전](Tests/results/2026-11-07/appearance-text-before.png)·[후](Tests/results/2026-11-07/appearance-text-after.png)는 화면 근거이며 픽셀 동일성 판정은 아닙니다.
- [빌드](Tests/results/2026-11-07/appearance-build.log)·[GUI/디스크/종료](Tests/results/2026-11-07/appearance-gui.json): 임시 문서의 사각형 체크/중첩·표 정렬/흰 첫 본문 행·96×48 우측 정렬 상대 이미지·구분선 전후 비교, 체크 토글/Undo/저장, 이미지 표면 편집 창, 하단 입력/저장/Aa 왕복, 새 빈 문서·다중 창 복귀, 미리보기 0·앱 종료를 확인했습니다.
- 한계: GUI는 Markdown 내용의 `.txt`, 자동 비교는 명시한 요소/조건의 범위입니다. 실제 IME·forced-colors·PDF/복사·문서 이동·모든 보호 구문/이미지 조합·macOS 14의 전체 대응은 F5 관문에 남습니다. 미지원 구문의 원문 편집·F4 참조 정의 지원을 추가한 것은 아닙니다.

<a id="bug-39"></a>
## 39. Aa 빈 문서·문서 끝 빈 영역에서 입력 불가

- **2026-11-07 / 수정·해당 범위 검증 완료.** Aa에서 마지막 블록 아래의 편집기/본문 하단 여백을 클릭해도 입력할 새 문단이 선택되지 않았습니다. 본문 폭 안의 마지막 블록 아래 기본 클릭은 최상위 일반 문단을 생성하며, 이미 빈 문단이 있으면 재사용합니다. 빈 문서는 첫 문단을 그대로 사용하므로 앞 빈 줄·클릭마다 빈 줄 누적이 없습니다. Read/freeze/조합·보조 클릭·서식 메뉴·본문 내부 클릭은 제외하고 해제 시 리스너를 제거합니다.
- 검증: [브라우저 모델 18·시각 입력 200](Tests/results/2026-11-07/empty-aa-visual.log), 실패/SKIP 0. 빈 문서·문단/제목/목록/인용/코드/수식/구분선/표/보호 원문/CRLF·Unicode의 끝에서 클릭→즉시 일반 텍스트 입력→snapshot/재파싱→Undo/Redo를 검사했습니다. [모델 32·번들](Tests/results/2026-11-07/empty-aa-model.log)·[native 33](Tests/results/2026-11-07/empty-aa-native.log)·[WebKit/레이아웃 51](Tests/results/2026-11-07/empty-aa-webkit.log)·[빌드](Tests/results/2026-11-07/empty-aa-build.log) 통과. [GUI/디스크/종료](Tests/results/2026-11-07/empty-aa-gui.json): 새 문서 빈 영역 첫 입력·아래 여백 다음 줄·최초 저장·재열기 후 하단 추가 입력·다른 초안 독립성·미리보기 0·앱 종료 확인.
- 한계: 실제 IME·macOS 14·단일 Save 패널로 새 문서 닫기 등은 F5 관문에 남습니다. 이번 새 문서 닫기에서 native Save 후 추가 Unsaved Changes 경고가 관찰됐으며 Save 선택 후 내용 보존·닫기를 확인했습니다. 원인·재현성은 미확정입니다. 빈 최상위 문단의 저장 후 identity 한계는 기존 계약을 유지합니다.

<a id="bug-38"></a>
## 38. 새 문서 Aa 초기화 JavaScript 오류

- **2026-11-07 / 수정·해당 범위 검증 완료.** 파일 없는 새 문서→Aa에서 `TypeError: crypto.randomUUID is not a function`을 [실제 about:blank WKWebView에서 재현](Tests/results/2026-11-07/empty-aa-before.log)했습니다. secure-context 전용 API 대신 공통 `randomID()`를 사용하며, API가 없으면 `crypto.getRandomValues()`로 UUID v4를 생성합니다. 문서/블록/복제/정규화/저장 token의 모든 호출에 적용했습니다.
- 검증: [WebKit 51](Tests/results/2026-11-07/empty-aa-webkit.log)의 파일 URL 없는 Aa 왕복 통과. [입력 검사](Tests/results/2026-11-07/empty-aa-visual.log)는 inline harness의 baseURL을 nil로 바꿔 파일 기반 실행과 함께 ID 생성·편집·snapshot/Undo 경로를 검사합니다. [실제 새 문서 GUI](Tests/results/2026-11-07/empty-aa-gui.json)에서도 오류 패널 없이 Aa 진입·첫 입력·최초 저장·재열기를 확인했습니다. 입력·저장 회귀와 남은 한계는 39번 및 F5 관문을 따릅니다.

## 37. Aa 표의 Enter 탈출과 Shift+Enter 행 삽입

- **2026-11-06 / 해당 범위 검증 완료.** Enter는 아래 행 첫 셀, 마지막 행이면 현재 표 바로 아래 새 문단으로 이동합니다. Tab/Shift+Tab은 현재 표의 다음/이전 셀입니다. Shift+Enter는 머리글·중간·끝 어느 행에서든 바로 아래 빈 행을 삽입하고 **새 행 첫 열 시작**으로 이동합니다. 기존 셀·정렬·다음 표를 보존하고 구조 변경은 Undo 경계로 기록합니다(`7968f1f`·`9692df8`).
- 검증: [모델 32](Tests/results/2026-11-06/table-row-first-column-model.log)·[브라우저 모델 18/시각 입력 164](Tests/results/2026-11-06/table-row-first-column-visual.log)·[native 33](Tests/results/2026-11-06/table-row-first-column-native.log)·[WebKit 50](Tests/results/2026-11-06/table-row-first-column-webkit.log) 통과,실패/SKIP 0. 모든 3×3 출발 행/열·정렬/원문·Undo/Redo·snapshot 재파싱·인용/CRLF 검사. [빌드](Tests/results/2026-11-06/table-row-first-column-build.log)·[GUI/디스크/종료](Tests/results/2026-11-06/table-row-first-column-gui.json)·[화면](Tests/results/2026-11-06/table-row-first-column-gui.png)·[재열기](Tests/results/2026-11-06/table-row-first-column-reopened.png): C/E/I에서 삽입 후 첫 열 입력·Enter/↑·저장/재열기·미리보기 0·앱 종료 확인. 이후 ↓ 변경까지의 자동 회귀는 36번의 174개를 따릅니다.
- 한계: GUI는 Markdown 내용의 임시 `.txt`를 사용했습니다. 실제 IME·macOS 14 기기·모든 중첩 컨테이너 경계와 빈 문단 identity는 [F5](IMPLEMENTATION_PLAN.md#f5-notion-방식의-블록-관리와-연속-편집)에 남아 있습니다. 초기 단계의 다른 Enter/커서 계약은 Git 이력·원시 로그로 추적합니다.

## 36. Aa 표의 화살표 셀 이동

- **2026-11-06 / 해당 범위 검증 완료.** 셀 안 글자/접힌 줄 이동은 native에 맡기고 경계에서 같은 열의 위/아래 또는 같은 행의 좌/우 셀로 이동합니다. 첫 행의 첫 표시 줄 ↑는 표 앞 영역 끝, 마지막 행의 마지막 표시 줄 ↓는 표 뒤 영역 시작으로 이동합니다. 영역이 없으면 최상위 블록 앞/뒤에 빈 문단을 만들고 Undo로 복원합니다. 인접 원자 블록은 삭제 없이 선택합니다. 기존 영역 이동은 원문/dirty/history를 바꾸지 않습니다(`5774ad6`·`84c2405`·`3622265`).
- 최종 회귀: [모델 32](Tests/results/2026-11-06/table-down-exit-model.log)·[브라우저 모델 18/시각 입력 174](Tests/results/2026-11-06/table-down-exit-visual.log)·[native 33](Tests/results/2026-11-06/table-down-exit-native.log)·[WebKit/레이아웃 50](Tests/results/2026-11-06/table-down-exit-webkit.log) 통과, 실패/SKIP 0. 모든 출발 열·이전/이후 문단/제목/목록/인용/수식/표·빈 셀/문단·문서 시작/끝·접힌 줄·Unicode·Undo/재파싱 검사.
- 실제 앱: [↑ GUI/디스크/종료](Tests/results/2026-11-06/table-up-exit-gui.json)·[기존 문단](Tests/results/2026-11-06/table-up-exit-gui.png)·[문서 시작](Tests/results/2026-11-06/table-up-start-gui.png), [↓ 빌드](Tests/results/2026-11-06/table-down-exit-build.log)·[GUI/디스크/종료](Tests/results/2026-11-06/table-down-exit-gui.json)·[기존 문단](Tests/results/2026-11-06/table-down-exit-gui.png)·[문서 끝](Tests/results/2026-11-06/table-down-end-gui.png)·[재열기](Tests/results/2026-11-06/table-down-end-reopened.png): 이동 후 입력·새 문단/Undo/Redo·저장/재열기·두 문서 전환/닫기·미리보기 0·앱 종료 확인.
- 한계: 접힌 줄·빈 셀·Unicode·컨테이너별 세부 경계는 WebKit 자동 검증입니다. GUI의 임시 `.txt` 사용·실제 IME/macOS 14 미검증은 35번과 같습니다.

## 35. Aa 표의 빈 셀 안내 문구

- **2026-11-06 / 수정·해당 범위 검증 완료.** 표의 빈 셀에 회색 `Cell`이 표시됐습니다. 시각 편집기의 빈 textblock 장식에서 `table_cell`만 제외해 비워 두고, 일반 문단·제목 등의 안내는 유지합니다.
- 검증: [TypeScript·모델 32](Tests/results/2026-11-06/table-placeholder-model.log), [WebKit 브라우저 모델 18·시각 입력 130](Tests/results/2026-11-06/table-placeholder-visual.log) 통과, 실패/SKIP 0. 가져온 표·새 표의 빈 셀 및 일반 Text 안내 보존·셀 입력을 검사했습니다. [Debug 빌드](Tests/results/2026-11-06/table-placeholder-build.log)·[GUI/디스크 근거](Tests/results/2026-11-06/table-placeholder-gui.json)·[화면](Tests/results/2026-11-06/table-placeholder-gui.png): Aa에서 빈 셀 표시, 입력·⌘S·닫기·미리보기 0개 확인.
- 한계: 격리 앱의 Open 패널이 `.md`를 비활성화해 같은 Markdown을 지원되는 `.txt`로 열었습니다. 타입 선언 정합성은 기존 F3 후속이며, 실제 IME·macOS 14 기기는 미검증입니다.

<a id="bug-34"></a>

## 34. Aa 전환 시 스크롤 왕복과 좌우 정렬 변경

- **2026-11-05 / 해당 범위 검증 완료.** 긴 문서 중간의 Aa 전환에서 WebView 교체·지연 smooth-scroll·별도 본문 폭이 상단 왕복/정렬 변경을 만들었습니다. 같은 WKWebView/페이지·공통 800px/24px 스타일 안에서 루트만 교체하고 가시 블록·중복 순번으로 즉시 위치를 맞춥니다. 메뉴 행 높이만 이동하며 모드 탐색/초기 스크롤 복원은 하지 않습니다. 최초 세대 동기화로 첫 Aa Save의 입력/history 초기화도 방지했습니다(`cb88297`).
- 검증: [WebKit 50](Tests/results/2026-11-05/f5-layout-webkit.log)·[native 33](Tests/results/2026-11-05/f5-layout-native.log)·[모델 32](Tests/results/2026-11-05/f5-layout-model.log)·[브라우저 모델 18/시각 입력 128](Tests/results/2026-11-05/f5-layout-visual.log)·[Hosted 317](Tests/results/2026-11-05/f5-layout-hosted.log)·[체크 저장 17](Tests/results/2026-11-05/f5-layout-tasks.log) 통과, 실패/XFAIL/SKIP 0. [빌드](Tests/results/2026-11-05/f5-layout-build.log)·[GUI/디스크](Tests/results/2026-11-05/f5-layout-gui.json): 24섹션 중간 Aa 왕복·같은 preview URL·저장/재열기·두 문서·미리보기 0 확인.
- 한계: 좌표/폰트 검사는 900/640px·TOC on/off와 16ms 타이머 샘플입니다. CUA는 전후 화면이며 연속 painted-frame 영상은 없습니다. 이미지 속성·보호 원문·빈 문단·dark/zoom/PDF/실제 IME의 전체 표시 대응은 F5 관문에 남아 있습니다.

<a id="bug-33"></a>

## 33. 빈 $$와 Space만으로 Equation이 생성됨

- **2026-11-05 / 해당 범위 검증 완료.** `$$`+Space의 빈 수식 단축키를 제거했습니다. `$$`·`$$$$`·공백뿐인 수식은 텍스트로 유지하고, 비어 있지 않은 닫힌 `$$...$$`만 변환합니다. 여러 줄은 연속 최상위 일반 문단에서만 모으며 미완성/일반 `$`는 이스케이프해 저장·재열기를 보존합니다. 기존 importer와 기본 Markdown의 통화 오인(13번)은 별도입니다.
- 검증: [수정 전](Tests/results/2026-11-05/f5-dollar-before.log) → [모델 32](Tests/results/2026-11-05/f5-dollar-model.log)·[브라우저 모델 18/시각 입력 128](Tests/results/2026-11-05/f5-dollar-visual.log)·[native 27](Tests/results/2026-11-05/f5-dollar-native.log)·[WebKit 22](Tests/results/2026-11-05/f5-dollar-webkit.log) 통과, 실패/SKIP 0. [빌드](Tests/results/2026-11-05/f5-dollar-build.log)·[GUI/디스크](Tests/results/2026-11-05/f5-dollar-gui.json): 실제 달러/Space·미완성 Save/Aa·닫는 키 변환·여러 줄·저장/재열기·미리보기 0 확인.
- 한계: 실제 IME·PDF·컨테이너 내부 여러 문단 수집은 미검증입니다.

## 32. Aa 편집 후 버튼 비활성화로 모드 재진입 불가

- **2026-11-05 / 해당 범위 검증 완료.** 미저장 전환 금지 정책을 없애고 최신 스냅샷/마지막 디스크 기준을 분리해 양방향 인계합니다. 시각 엔진은 직렬화 후 freeze, textarea는 조합 확정 뒤 인계하며 실패하면 현재 편집기에 남습니다. 전환은 저장하지 않습니다. Undo는 모드 경계 checkpoint 하나이며 이전 엔진의 개별 입력 history는 유지하지 않습니다.
- 검증: [모델 31](Tests/results/2026-11-05/f5-switch-model.log)·[브라우저 모델 18/시각 입력 116](Tests/results/2026-11-05/f5-switch-visual.log)·[native 27](Tests/results/2026-11-05/f5-switch-native.log)·[WebKit 22](Tests/results/2026-11-05/f5-switch-webkit.log)·[체크 저장 17](Tests/results/2026-11-05/f5-switch-tasks.log)·[Hosted 317](Tests/results/2026-11-05/f5-switch-hosted.log) 통과,실패/XFAIL/SKIP 0. [빌드](Tests/results/2026-11-05/f5-input-fix-build.log)·[GUI/디스크](Tests/results/2026-11-05/f5-input-fix-gui.json): 미저장 Aa 왕복·dirty/내용·Save 전 디스크 불변·저장/재열기·두 문서·미리보기 0 확인.
- 한계: 실제 IME 조합 중 전환·최초 Save/권한/충돌 UI는 F5 관문입니다. 저장 실패/지연 쓰기·native revert의 통제 범위를 실제 패널 통과로 보지 않습니다.

## 31. 블록 입력 변환 취소 후 커서가 다음 줄로 이동

- **2026-11-05 / 수정·해당 범위 검증 완료.** 다음 문단 앞에서 `>`/`-` Space→Backspace 시 기호는 복원되지만 다음 입력이 다음 문단으로 들어갔습니다. 구조 변경 inverse step의 자동 selection 매핑이 다음 문단을 가리켰습니다. 입력 규칙에 기록된 원래 삽입 위치로 Backspace·⌘Z의 selection을 명시적으로 복원합니다.
- 검증: [수정 전 재현](Tests/results/2026-11-05/f5-caret-before.log), [모델 30/빌드](Tests/results/2026-11-05/f5-caret-model.log), [브라우저 모델 18·시각 입력 114 통과](Tests/results/2026-11-05/f5-caret-visual.log). 10가지 블록 규칙의 기호 뒤 커서·후속 입력·다음 문단 불변, 인용/목록 단축키 Undo 확인. [GUI](Tests/results/2026-11-05/f5-input-fix-gui.json)에서 `>`/`-` Space→Backspace 후 같은 줄에 입력되고 뒤 문단이 유지됨을 확인했습니다.

## 30. 인라인 코드 종료 뒤에도 코드 서식이 이어짐

- **2026-11-05 / 수정·해당 범위 검증 완료.** Aa에서 `` `code`tail ``을 입력하면 `tail`까지 코드로 들어갑니다. 닫는 백틱을 처리한 입력 규칙이 코드 mark를 다음 입력의 stored marks에 남기는 것이 원인입니다. 코드 본문에만 mark를 적용한 뒤 stored code mark를 제거했습니다.
- 검증: [수정 전 재현](Tests/results/2026-11-05/f5-inline-before.log), [모델 30/빌드](Tests/results/2026-11-05/f5-inline-model.log), [브라우저 모델 18·시각 입력 110 통과](Tests/results/2026-11-05/f5-inline-visual.log). 바로 이어 쓰기·분리된 두 코드 span·변환 취소·재파싱을 확인했습니다. [GUI](Tests/results/2026-11-05/f5-input-fix-gui.json)에서 닫는 백틱 입력 후 `code`만 코드 표시, `tail`은 일반 표시, 저장·재열기까지 확인했습니다.

<a id="bug-27"></a>
<a id="bug-28"></a>

## 27·28. Aa 전환 시 수식 폰트 변형과 행렬 파싱 손상

- **2026-11-05 / 해당 범위 검증 완료.** [State Space fixture](Tests/fixtures/f5-state-space-math.md) → Aa에서 수식 폰트가 달라지고 행렬 첫 줄이 누락되며 뒤 문서를 흡수했습니다(독립 GUI 재현).
- **27번:** minified CSS의 세미콜론 없는 `src:...}`를 정규식이 넘어가던 문제를 수정하고 양 모드에 오프라인 KaTeX 0.18.2·동일 CSS/WOFF2를 적용했습니다. 수식은 편집 루트의 wrapping/컨트롤 배치에서 분리합니다. **28번:** micromark 토큰에서 본문과 붙은 `$$` 시작/종료를 처리해 코드·컨테이너·빈 줄·UTF-16 위치를 유지합니다. 미수정 수식은 원문 재사용, 수정 수식은 표준 줄 구분자로 저장합니다.
- 검증: [모델 30](Tests/results/2026-11-05/bug27-28-model.log)·[브라우저 모델 18/시각 입력 100](Tests/results/2026-11-05/bug27-28-visual.log)·[WebKit 22](Tests/results/2026-11-05/bug27-28-webkit.log)·[Hosted 317](Tests/results/2026-11-05/bug27-28-hosted.log)·[native 17](Tests/results/2026-11-05/bug27-28-native.log)·[체크 저장 17](Tests/results/2026-11-05/bug27-28-tasks.log) 통과, 실패/XFAIL/SKIP 0. 11개 수식의 TeX/display·폰트/글리프 크기 차이 <0.1px·후속 문서·무편집 원문 보존 확인.
- [빌드](Tests/results/2026-11-05/bug27-28-build.log)·[GUI/디스크](Tests/results/2026-11-05/bug27-28-gui.json): 전환 전후·원문 창·값 수정/Apply/Save·재열기/Aa·수식 밖 원문 보존 확인. 당시 Edit 버튼 UI는 현재 F5의 표면 클릭 UI로 교체됐습니다. dark/PDF·macOS 14·사용자 원본 자체는 미검증이며 열린 문서 Quit 잔류는 29번에서 조사합니다.

## 29. 앱 메뉴 Quit 후 고유 미리보기 파일 잔류

- **2026-11-05 / 조사 중.** 임시 수식 문서를 열고 시각 모드로 전환한 뒤 앱 메뉴 Quit. 수정 전/후 격리 앱 두 실행에서 각각 마지막 `.mv_preview-*.html` 1개가 남았습니다. 전역 앱 목록과 별도 프로세스 조회에서 앱 종료를 확인했습니다. 명시적 문서 닫기→재열기의 미리보기는 정리됐습니다. [파일명·관찰 근거](Tests/results/2026-11-05/bug27-28-gui.json).
- 다음 조치: `applicationWillTerminate`→`removeAllPreviewFiles` 실행/소유권과 NSDocument/SwiftUI 종료 수명을 계측하고 일반 빌드에서도 비교합니다. 18번의 공유 원본 덮어쓰기 방지와 구분하며, 잔류 증거를 삭제해 cleanup 통과로 표현하지 않습니다. 문서 닫기 후 Quit한 2026-11-06 [표 GUI](Tests/results/2026-11-06/table-down-exit-gui.json)는 미리보기 0개였지만 열린 문서의 Quit 경로를 검증한 것은 아닙니다.

## 26. GUI 테스트 중 Finder “Bloct is not open anymore”

- **2026-10-26 / 조사 중 — 자동화 종료 경합 확인, 새 절차의 반복 검증 대기**. 사용자가 GUI 테스트 중 반복 팝업을 보고했습니다. 2026-10-26 최소 재현은 Debug 앱 Quit 직후 같은 앱 핸들로 `getAXState()`를 요청한 흐름입니다. 팝업 자체의 독립 캡처는 없습니다.
- [원시 발췌](Tests/results/2026-10-26/finder-quit-race.log): 13:47:44·13:49:47·13:56:39에 CoreServicesUIAgent가 종료 중인 Bloct에 `aevt/rapp` 재활성화 이벤트를 보내다 `-600 procNotFound`를 반환했습니다. 확인한 Debug 주 프로세스 종료 5회는 모두 `launchd (0, 0, 0)`이며 새 Bloct 충돌 보고서는 없습니다. F1 기능 자체의 충돌을 확인한 결과가 아닙니다.
- 다음 조치: 앱 메뉴의 Quit 이후 이전 핸들에 추가 조회/재활성화를 보내지 않습니다. 전역 앱 목록만으로 종료를 확정하지 않고, 필요하면 실제 프로세스 종료를 확인한 뒤 새 핸들을 얻습니다. 독립 검증 앱의 [최종 정렬 검사](Tests/results/2026-10-26/checkbox-indent-gui.json)에서는 메뉴 Quit 후 실제 종료를 확인했습니다. 다음 조치에는 열린 문서 Quit 및 종료 핸들 경합을 별도 재현합니다. 자동화와 무관한 일반 Finder 문서 열기의 동일 오류는 미재현입니다.
- 2026-11-05 [독립 GUI 검사 1회](Tests/results/2026-11-05/f5-ui-observations.json): 문서 닫기→앱 메뉴 Quit→전역 목록·실제 프로세스 종료 확인, 이전 앱 핸들 재조회 없음. 팝업은 관찰되지 않았습니다. 단일 실행이므로 반복 재검증 대기 상태는 유지합니다.
- 2026-11-06 [표 GUI](Tests/results/2026-11-06/table-down-exit-gui.json)도 문서 닫기→Quit→새 목록의 종료 상태를 확인했습니다. 원래 종료 경합 조건의 반복 검증/독립 프로세스 계측을 대신하지 않으므로 조사 상태를 유지합니다.
- 2026-11-07 [Aa 통합 GUI](Tests/results/2026-11-07/aa-only-gui.json): 두 번째 문서 닫기 뒤 `noWindowsAvailable`→반복 `timeoutReached`. 목록/프로세스는 테스트 앱 실행 중이고 소유 미리보기 1개가 남았습니다. 커널 reset·명시 경로/고유 ID 재연결도 실패해 종료/정리를 확인하지 못했습니다. [1초 프로세스 샘플](Tests/results/2026-11-07/aa-only-process-sample.txt)의 main thread는 AppKit 이벤트 루프에서 대기했으며 앱 deadlock을 확정하는 근거는 아닙니다. 강제 종료·잔류 파일 삭제 없이 보존했습니다.
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

### 3·5·9. 제거된 textarea 편집 경로

- **2026-11-07 / 경로 제거.** 기존 3번의 blur/click DOM 교체 경쟁 가설, 5번의 `''.split('\n')` 뒤 첫 입력 추가, 9번의 목차를 배제하지 않는 추가 영역 클릭은 옛 textarea 경로의 기록입니다. 해당 상태·함수·추가 영역·이벤트 핸들러를 제거했습니다([41번](#bug-41)). Aa의 첫 입력과 caret/포커스 검증은 30·31·38·39번 및 F5를 따릅니다.

### 10. 빈 문단의 gap 저장

- **미해결 / Aa에서 구체적 재현 필요.** 과거 추가 영역에 입력 후 모두 지우면 `['']`와 구분 줄이 남는 보고였습니다. 옛 추가 영역은 제거됐지만 Aa의 빈 최상위 문단은 Markdown gap으로 저장됩니다. 단순 무편집과 의도한 빈 블록 생성·삭제를 구분해 원문·dirty·Undo 계약을 확인합니다.

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

- **2026-10-17 / 해당 범위 검증 완료**, `0ff3e30` / v1.7.4. 최초 Binding 이후 외부 변경 수용 경로가 없었습니다(소스 확인, 구버전 GUI 덮어쓰기 미재현). 0.6초 내용 폴링·Binding/URL 관찰·⌘R/우클릭 Reload로 깨끗한 문서는 수용하고 초안에는 유지/폐기 후 Reload/사본 저장을 제공합니다. 같은 원본/심볼릭 링크에 사본 저장은 거절하며 새 문서 Reload는 비활성입니다.
- 보호 계약: 백그라운드 조정 I/O에서 읽기는 `.withoutChanges`, 쓰기는 `.forReplacing` 없이 같은 accessor의 원본 비교 후 원자적 쓰기입니다. NSDocument 재읽기로 모델·기준·버퍼·Undo를 맞추고 rename/최초 Save는 새 URL을 따릅니다. 삭제·폐기 시 과거 원문 재생성, 오래된 세대 commit, 닫힌 문서 콜백을 차단합니다. 외부 writer까지 절대적인 CAS를 보장하지 않습니다.
- 재검증: 외부 직접 쓰기/원자적 교체(수정 시각 유지) → 깨끗한 읽기/편집 갱신; 초안 Reload/Save 거절/사본 취소/폐기·Undo 경계; 이어 Save/최초 Save·두 문서·rename/삭제·Close 취소/폐기·소유 파일 정리를 확인합니다.
- 근거: [Native 8그룹](Tests/results/2026-10-17/reload-native.log)·[WebKit 15](Tests/results/2026-10-17/reload-webkit.log)·[이미지 70](Tests/results/2026-10-17/reload-relative-images.log) 통과. [Hosted](Tests/results/2026-10-17/reload-hosted.log)는 **134 통과·20번 XFAIL 2·일반 실패/SKIP 0**. 독립 DocumentGroup [GUI](Tests/results/2026-10-17/reload-gui.log)·[디스크](Tests/results/2026-10-17/reload-disk.log)·[빌드/체크섬](Tests/results/2026-10-17/reload-artifact.json) 확인.
- 미검증: 실제 IME·지연 동시 writer/Save·외장/네트워크/iCloud·대형 문서 폴링·기존 문서 Save As/PDF·macOS 14 기기. 설치본은 교체하지 않았습니다.

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

## 마지막 기록된 공개 배포 — 2026-10-26

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
