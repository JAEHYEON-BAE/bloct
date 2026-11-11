# Bloct 알려진 버그와 권장 수정 순서

- 정리: **2026-11-11**. 미해결·조사 중 11개와 보류 1개, 최근 검증 완료 29·45·46번을 유지합니다. 이전 완료·제거된 경로의 기록은 Git 이력과 `Tests/results/`에 남아 있습니다.
- 기존 번호를 유지하며 다음 새 번호는 **47번**입니다. 검증 날짜·범위는 항목별 근거를 따르며 자동 검사와 실제 앱 검증을 구분합니다.
- 기능 계약·남은 수용 검증은 [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md), 검사 방법은 [Tests/README.md](Tests/README.md)를 따릅니다. 블록 편집 검사의 통과를 읽기 렌더러 버그의 해결 근거로 사용하지 않습니다.

## 권장 수정 순서

| 순서 | 대상 | 이유·완료 기준 |
|---|---|---|
| 1 | **26 — 종료 자동화 경합** | 29·45번의 검증된 종료 경로와 구분해 Finder 팝업·종료 후 핸들 경합을 확인 |
| 2 | **4·17 — 코드 보호 → 2·13 — 서식·수식 → 7·8 — 제목·목차** | 코드 원문 보호를 먼저 확보한 뒤 읽기 렌더링과 탐색 정확성 수정 |
| 3 | **10 — 빈 문단 저장, 11 — PDF, 12 — 복사** | 현재 블록 편집 경로에서 먼저 재현. 의도된 빈 줄과 실제 결함, 가설을 구분한 뒤 수정 |
| 4 | **19 — 검색 키보드** | 문서 안내와 실제 키 동작 일치. 16번은 사용자 정책으로 보류 |

45번의 해당 종료 경로 검증은 완료했으며, [F5 수용 관문](IMPLEMENTATION_PLAN.md#다음-순서와-기본값-전환-관문)의 실제 IME·저장/외부 변경·기능 대응 검증을 최우선 개발 목표로 이어갑니다. 재현되지 않은 가설을 확정 버그로 처리하지 않습니다.

## 편집 키보드

<a id="bug-46"></a>

### 46. Esc 입력 시 macOS 경고음

- **검증 완료 / 2026-11-11.** 읽기 상태의 Esc와 수식 팝업의 기본 Esc 취소가 WebKit에서 미처리 키로 전달되어 AppKit의 `noResponderFor:keyDown:` 경고음 경로에 도달했습니다. 최소 재현은 문서를 열고 Esc 반복, 또는 수식 클릭 → Esc입니다. 편집 종료 자체의 Esc와 구분했습니다. [읽기 재현](Tests/results/2026-11-11/bug46-before-runtime.log)·[팝업 키 코드 53/호출 스택](Tests/results/2026-11-11/bug46-fixed-keys.log). 경고음 동작은 [Apple 이벤트 처리 문서](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/EventOverview/EventArchitecture/EventArchitecture.html)를 따릅니다.
- **수정:** 읽기에서도 Esc 기본 동작을 막되 모드 전환을 추가 요청하지 않습니다. 공통 수식/이미지/보호 원문 팝업은 Esc를 명시적으로 소비하고 Cancel로 닫습니다. 다음 Esc의 읽기 복귀, 초안·Undo·Save·viewport 보존과 조합/수정자 키 보호는 유지합니다.
- **검증:** [실제 앱·디스크·종료 감사](Tests/results/2026-11-11/bug46-gui.json)에서 Computer Use로 읽기 반복, 팝업 초안 폐기, 편집 종료, 검색창 닫기, Undo/저장/재열기, 두 문서 전환·닫기와 빈 문서를 확인했습니다. [최종 실제 Esc 19회](Tests/results/2026-11-11/bug46-final-keys.log)의 미처리 `keyDown` 0회, 종료 코드 0·미리보기 잔류 0·fixture 원문 복원. [모델/빌드 36개](Tests/results/2026-11-11/bug46-model.log)·[WebKit 963개](Tests/results/2026-11-11/bug46-webkit.log)·[시각 입력 332개/브라우저 모델 18개](Tests/results/2026-11-11/bug46-visual.log)·[native 41개](Tests/results/2026-11-11/bug46-native.log) 통과, 실패/SKIP 0.
- **한계:** 오디오 녹음 대신 원래 AppKit 동작을 유지하는 [계측](Tests/results/2026-11-11/bug46-event-probe.m)으로 재현된 경고음 경로의 차단을 확인했습니다. 실제 IME 조합·macOS 14 기기·설치본 교체·공개 Release는 별도입니다.

## 종료·파일 정리

<a id="bug-45"></a>

### 45. 창 닫기 중 native 예외·비정상 종료

- **검증 완료 / 2026-11-10.** `CloseProxy`가 원래 delegate의 `windowWillClose`를 전달한 뒤에도 AppKit의 알림 수신자로 남아, 종료 중 원래 delegate가 더 이상 광고하지 않는 selector로 알림이 오면 예외가 발생할 수 있었습니다. 종료 시 프록시의 delegate 등록을 먼저 해제하고 원래 delegate에 한 번 전달하도록 수정했습니다. 뷰의 창 이동·해제 시에는 기존 delegate를 복원하며 지연 설치도 취소합니다.
- **회귀 근거:** [수정 전](Tests/results/2026-11-10/bug45-before.log)·[종료 코드 -6](Tests/results/2026-11-10/bug45-before-exit.json): 동적 delegate가 종료 중 `windowDidResize:` 광고를 중단하면 같은 미인식 selector 메커니즘으로 SIGABRT. [수정 후 9개](Tests/results/2026-11-10/bug45-window-close.log)·[ContentView native 41개](Tests/results/2026-11-10/bug45-visual-native.log)·[앱 빌드](Tests/results/2026-11-10/bug45-build.log) 통과.
- **실제 앱:** [Computer Use·디스크·종료 감사](Tests/results/2026-11-10/bug45-gui.json)에서 깨끗한 편집 창 닫기, Cancel 후 추가 입력, Don't Save 원문 보존, Save/재열기, 두 창 전환·Quit 취소/저장/폐기를 확인했습니다. 프로세스 종료 코드 0, 새 충돌 보고서·미리보기 잔류 0.
- **한계:** [2026-11-08 원래 충돌](Tests/results/2026-11-08/window-close-crashes.json)의 private `windowDidOrderOffScreen:` receiver는 독립 식별하지 못했으며 수정 전 일반 앱의 닫기·폐기에서는 재현되지 않았습니다. 위 회귀는 같은 전달 실패 조건의 통제된 재현입니다. macOS 14 기기·실제 IME·설치본/공개 Release와 26번 Finder 경합은 별도입니다. 정상 Quit cleanup의 현재 검증은 29번을 따릅니다.

### 29. 앱 메뉴 Quit 후 고유 미리보기 파일 잔류

- **검증 완료 / 2026-11-10.** 최초 미리보기 생성 때 `PreviewFiles`가 `NSApplication.willTerminateNotification`을 직접 등록하고 종료 전에 소유 파일만 동기 삭제하도록 변경했습니다. AppDelegate의 종료 콜백 전달·문서 뷰 해제에 의존하지 않으며, Quit 취소 시에는 삭제하지 않습니다. 기존 파일/다른 세션 파일은 보존하고 삭제 실패의 소유권·재시도 정책은 유지합니다.
- **회귀 근거:** AppDelegate 종료 cleanup을 전달하지 않는 실제 AppKit 프로세스 3개에서 [수정 전](Tests/results/2026-11-10/bug29-before.log) 잔류 1·2·2개, [수정 후](Tests/results/2026-11-10/bug29-termination.log) 모두 0개. Quit 취소 중 두 파일 유지와 기존 파일 보존도 통과. [native 8개](Tests/results/2026-11-10/bug29-native.log)·[ContentView native 41개](Tests/results/2026-11-10/bug29-visual-native.log)·[앱 빌드](Tests/results/2026-11-10/bug29-build.log) 통과.
- **실제 앱:** [Computer Use·프로세스/디스크 감사](Tests/results/2026-11-10/bug29-gui.json): 읽기 문서를 연 채 앱 메뉴 Quit, 두 문서 전환/개별 닫기/재열기 후 직접 Quit, 변경된 두 문서의 Quit 취소/추가 입력/Save/Don't Save 확인. 세 프로세스 모두 종료 코드 0·소유 미리보기 잔류 0·새 충돌 보고서 0이며 저장/폐기 원문·사용자/다른 세션 파일 보존 확인.
- **한계:** [2026-11-05 잔류 관찰](Tests/results/2026-11-05/bug27-28-gui.json)의 정확한 delegate 호출 경로는 미계측이며 현재 수정 전 정상 앱의 읽기 Quit에서는 재현되지 않았습니다. 콜백 전달 누락 조건은 위 별도 프로세스로 검증했습니다. 강제 종료/충돌·OS 삭제 권한 오류 복구·macOS 14 기기·설치본/공개 Release와 26번 Finder 경합은 별도입니다.

### 26. GUI 테스트 중 Finder “Bloct is not open anymore”

- **조사 중 / 2026-10-26, 2026-11-07 추가 관찰.** Quit 직후 이전 앱 핸들로 `getAXState()`를 요청한 흐름에서 재활성화 이벤트의 `-600 procNotFound`를 확인했습니다. 당시 주 프로세스 종료 5회는 정상이며 팝업 자체의 독립 캡처·일반 Finder 열기 재현은 없습니다. [원시 로그](Tests/results/2026-10-26/finder-quit-race.log).
- 2026-11-07에는 두 번째 창 닫기 후 `noWindowsAvailable`·`timeoutReached`, 실행 중 프로세스와 미리보기 1개가 남아 종료를 확인하지 못했습니다. [GUI](Tests/results/2026-11-07/aa-only-gui.json)·[프로세스 샘플](Tests/results/2026-11-07/aa-only-process-sample.txt). 샘플만으로 deadlock을 확정하지 않습니다. 45번의 실제 native 충돌과 구분합니다.
- 다음: Quit 후 이전 핸들을 조회·재활성화하지 않고 실제 프로세스 종료를 확인한 뒤 새 핸들을 얻습니다. 열린 문서 Quit·다중 창을 반복 검사합니다.
- 별도 설치 제한: 당시 설치본은 ad-hoc 서명·quarantine으로 Gatekeeper에 차단됐으며, 사용자 승인으로 격리 속성만 제거해 Open 창 실행을 확인했습니다. 재다운로드 시 같은 제한이 생길 수 있습니다. [근거](Tests/results/2026-10-26/finder-launch-investigation.json).

## 읽기 렌더링·탐색

아래는 기존 재현 보고·소스 확인에 따른 미해결 항목입니다. 현재 앱에서의 재현 범위부터 확인합니다.

| # | 증상·최소 재현 또는 확인 근거 | 다음 조치 |
|---|---|---|
| **4** | 코드 보호가 같은 길이의 닫는 펜스만 인정해 더 긴 닫는 펜스에서 보호 실패 | 분할기와 보호 판정을 맞추고 긴/미종결 펜스의 원문 보존 검사 |
| **17** | 이미지 확장이 코드 보호보다 먼저 실행되고 들여쓰기 코드는 수식 전처리에서 보호되지 않음 | 코드 안 이미지·수식 문법을 리터럴로 유지하고 렌더링·편집 전환·저장 검사 |
| **2** | `noStrikethrough`가 물결표 사이 전체를 소비해 굵게·링크·코드를 파싱하지 않음. 예: `3~5 **중요** 7~9` | 물결표 자체만 리터럴로 소비하도록 검토 |
| **13** | `가격 $5 와 $10 표기`를 수식으로 오인할 수 있음 | 공백·숫자·이스케이프의 구분자 정책을 정하고 통화/정상 수식/코드 함께 검사 |
| **7** | 수식 제목의 `textContent`에 MathML·annotation·HTML 텍스트가 중복되어 ID·목차도 중복 | 의미 텍스트를 한 번 추출해 ID·목차에 공통 사용 |
| **8** | 같은 제목의 ID가 같고 목차 직접 스크롤 뒤 전역 앵커 처리기가 첫 ID로 다시 이동할 수 있음 | 문서 전체의 고유 ID·단일 이동 경로 보장. 접미사와 다른 제목의 충돌도 검사 |

빈 줄은 독립 파싱·목록 그룹 경계입니다. 목록 번호 재시작·들여쓰기 블록의 독립 렌더링은 정상 동작이므로 위 수정에서 병합하지 않습니다. [정책 fixture](Tests/fixtures/bug-16-block-context.md).

## 현재 경로 재현·검증이 필요한 항목

| # | 상태·증상 | 다음 조치 |
|---|---|---|
| **10** | **미해결, 블록 편집 재현 필요.** 옛 추가 영역에서 입력 후 전부 지워도 빈 줄이 저장된 보고. 해당 경로는 제거됐으나 블록 편집기의 빈 최상위 문단은 Markdown gap으로 저장됨 | 무편집/입력 후 삭제/의도적 빈 블록 생성을 나눠 원문·dirty·Undo·저장/재열기 비교 |
| **11** | **미해결, 실제 PDF 검증 필요.** 목차·편집 UI·검색 강조·화면용 여백이 포함되거나 본문이 누락될 가능성 | 읽기/편집·미저장 초안의 실제 PDF를 확인하고 출력 준비·인쇄 CSS 보완 |
| **12** | **가설, 현재 블록 편집 재현 필요.** 전역 copy 처리기가 편집기 선택을 가로챌 가능성. 과거 textarea 경로는 제거됐으며 합성 미리보기 copy 검사는 이 가설의 증거가 아님 | 편집 중 부분 선택·줄바꿈·Unicode를 실제 클립보드의 Markdown/일반 텍스트/HTML과 비교 |

## 낮은 우선순위·보류

### 19. 검색 키보드 안내와 동작 불일치

- **미해결 / 기존 소스 확인.** Return은 항상 다음 검색이며 Shift+Return·↑/↓ 이동이 없어 README 안내와 다릅니다. 실제 키 입력으로 확인한 뒤 구현 또는 안내를 일치시킵니다.

### 16. 별도 정의 참조 링크 — 보류

- **보류 / 2026-10-17 사용자 정책.** 정의 확인·편집 UI와 교차 블록 해석을 함께 설계하며 [F4](IMPLEMENTATION_PLAN.md#f4-별도-정의-참조-링크--보류) 재개 전에는 구현하지 않습니다. 현재는 직접 주소 링크를 사용합니다.
- 옛 textarea의 정의 접근 단축키는 현재 경로의 지원 근거로 사용하지 않습니다. 빈 줄 경계 정책은 유지합니다.
