# 구현 완료 항목 수용 테스트 — 2026-10-15

> **후속 수정 완료:** 이 문서는 수정 전 GUI 관찰의 역사적 기록입니다. 발견한 Undo·폐기 문제는 후속 작업에서 수정·재검증했습니다. 현재 상태, 구현 내용, 최신 재현 결과는 단일 소통 문서인 [CODE_REVIEW.md](../CODE_REVIEW.md)의 “2026-10-15 Undo·폐기 수정 및 최신 검증”을 기준으로 합니다. 아래 수정 전 실패 기록은 회귀 근거로 보존합니다.

## 결론

`CODE_REVIEW.md`에서 구현 완료로 표시된 **1·6·14·15·18번**을 검사했습니다. **1·6번은 GUI 수용 기준을 충족하지 못했습니다.** 14·15·18번은 이번에 실행한 회귀 검사 범위에서 통과했습니다. 이는 모든 입력에 대한 무결함 보증이나 전체 보안 감사 결과가 아닙니다.

앱 소스는 수정하지 않았습니다. 테스트 시작 시 존재한 `.gitignore`, `CODE_REVIEW.md` 변경을 유지했습니다. 배포용 `/Applications/Bloct.app`은 교체하지 않았고 커밋·푸시하지 않았습니다.

## 환경과 빌드

- 소스 HEAD: `e480246`; 프로덕션 소스의 미커밋 변경 없음.
- Mac mini에서 Xcode Debug 빌드 및 실제 macOS 창 조작. GUI 입력은 접근성 API·키보드로 수행하고 AX 트리, 화면, 디스크 원문을 비교했습니다.
- 독립 bundle ID: `com.personal.Bloct.GUIProbe`.
- 실행 앱: `/private/tmp/bloct-codex-gui-build/Build/Products/Debug/Bloct.app`.
- 테스트 문서: `/private/tmp/bloct-acceptance-20261015/` 아래 전용 파일.

```sh
xcodebuild -project Bloct.xcodeproj -scheme Bloct -configuration Debug \
  -derivedDataPath /private/tmp/bloct-codex-gui-build \
  PRODUCT_BUNDLE_IDENTIFIER=com.personal.Bloct.GUIProbe \
  CODE_SIGNING_ALLOWED=NO build
```

빌드 결과: **BUILD SUCCEEDED**. Swift 플러그인 및 AppKit/WebKit 실행을 허용한 환경에서 실행했습니다.

## 항목별 판정

| 항목 | 판정 | 이번 실행 근거 |
|---|---|---|
| 1 Undo/Redo와 문서 동기화 | **부분 통과 / 결함 발견** | Undo·Redo 후 명시적 저장 결과는 화면과 디스크가 일치. 두 번의 블록 편집을 되돌릴 때 두 번째 Undo가 무반응인 현상을 두 차례 확인 |
| 6 저장 결과와 닫기 | **부분 통과 / 폐기 결함 관찰** | 저장 취소·쓰기 오류 후 내용/창 유지, 권한 복구 후 재저장 성공. 그러나 종료의 Don't Save 뒤 수정본이 남은 실행이 있었음. 별도 반복은 정상 폐기되어 타이밍 조건 미확정 |
| 14 HTML 안전성·브리지 | 검사 범위 통과 | 실제 WKWebView의 정화·CSP·탐색 차단·브리지 공격 패턴 검사 통과. 실제 CDN KaTeX 및 폰트 검사도 통과 |
| 15 자리표시자 충돌 | 검사 범위 통과 | 내부 토큰처럼 생긴 원문, 코드, 오프라인/실제 수식 관련 회귀 검사 통과 |
| 18 미리보기 파일 보호 | 검사 범위 통과 | 실제 두 문서의 서로 다른 UUID 미리보기 확인. 종료 후 소유 미리보기 제거 및 기존 `.mv_preview.html` 내용 보존. 네이티브/호스팅 경로 검사도 통과 |

## 발견 1: 연속 Undo에 화면 변화 없는 단계가 끼어듦

우선순위: 중간. 1번의 “Undo 이중 등록 여부” 수용 기준 실패입니다. 중복 등록이 실제 원인인지는 아직 계측하지 않았습니다.

재현:

1. 기존 `undo.md`의 문단 `BASELINE 한글`을 편집 모드에서 `ROUND2 A`로 바꾸고 Escape로 확정합니다.
2. 같은 문단을 `ROUND2 B`로 바꾸고 Escape로 확정합니다.
3. 편집기가 닫힌 상태에서 ⌘Z를 실행합니다: `ROUND2 A`가 됩니다.
4. 다시 ⌘Z: AX 트리에 변화가 없으며 `ROUND2 A`가 유지됩니다.
5. 세 번째 ⌘Z: `BASELINE 한글`로 돌아갑니다.

기대: 두 번의 확정된 편집은 두 번의 Undo로 취소되어야 합니다. 최초 `EDIT A 한글` → 활성 편집기에서 `ACTIVE SAVE B 한글` 직접 저장 시나리오에서도 같은 불필요한 Undo 단계를 관찰했습니다.

별도 정상 동작: 첫 Undo 후 저장하면 디스크에 `BASELINE 한글`, Redo 후 저장하면 `EDIT A 한글`이 기록됐습니다. 활성 textarea에서 ⌘S로 직접 저장하는 동작도 화면에 반영됐습니다.

조사 위치: `DocumentState.apply/commit`, SwiftUI FileDocument Binding의 실제 Undo 등록 시점, WebKit/창 undoManager. 현재 네이티브 테스트는 대역 Binding을 사용하므로 실제 DocumentGroup의 추가 등록을 재현하지 않습니다.

## 발견 2: 종료에서 Don't Save를 선택해도 수정본이 남는 실행

우선순위: 높음. 사용자의 폐기 의도와 디스크 결과가 달라집니다. **간헐 관찰이며 정확한 경합 조건과 원인은 미확정**입니다.

독립 문서에서 관찰한 실패:

1. `discard.md` 원문은 `# Discard acceptance\n\nDISCARD BASELINE\n`입니다.
2. GUI에서 문단을 `DISCARD MUST NOT PERSIST`로 수정하고 Escape로 확정합니다. ⌘S는 누르지 않습니다.
3. 종료 요청 전에 디스크를 읽었을 때는 `DISCARD BASELINE`이었습니다.
4. ⌘Q → 앱의 **Unsaved Changes** 경고 → **Don't Save**를 선택합니다.
5. 이후 디스크에 `DISCARD MUST NOT PERSIST`가 기록되어 있었습니다. GUI로 다시 열어도 수정본이 표시됐습니다.

그 전에 진행한 두 창 종료에서도 Save/Don't Save를 선택한 뒤 두 파일 모두 편집 문자열이 남았습니다. 다만 당시 각 경고의 부모 창을 확정하지 못했으므로 문서별 Save 대상이 바뀌었다고 단정하지 않습니다.

반례도 기록합니다. 새 파일 `discard-repeat.md`를 `REPEAT BASELINE` → `REPEAT SHOULD DISCARD`로 편집하고 같은 종료 경로를 실행한 별도 반복에서는 **정상 폐기**됐습니다. 이 반복에서는 경고가 열린 직후에도 디스크가 기준 내용임을 확인했고, Don't Save 이후에도 기준 내용이 유지됐습니다. 따라서 항상 실패하는 동작이라고 보고하지 않습니다.

조사 위치: `ContentView.discardAndClose()`의 Binding 복원 직후 `window.close()` 및 `handleQuit()`, SwiftUI/AppKit의 저장·닫기 수명주기. 자동 저장/비동기 Binding 반영과의 경쟁은 가설이며 아직 원인으로 확인하지 않았습니다.

## 저장·취소·실패 GUI 검사

| 시나리오 | 관찰 |
|---|---|
| 새 문서 입력 → ⌘W → 저장 패널 Cancel | 창·내용·Edited 상태 유지 |
| 새 문서 ⌘S → Cancel → 다시 ⌘S | 재시도 가능. `cancel-retry.md` 저장 성공 |
| 기존 문서 편집 후 부모 폴더만 0555로 변경 → ⌘S | 실제 권한 오류 경고. 디스크는 `ORIGINAL SAFE`, 화면은 편집 문자열 유지 |
| 실패 후 ⌘W → Cancel | 닫히지 않고 편집 내용 및 Not Saved 상태 유지 |
| 폴더 0755 복구 → ⌘S → 닫기 | 성공. 디스크에 `WRITE FAILURE RETAIN ME` 확인 |
| 두 미저장 창 → ⌘Q → 각 경고 Cancel | 두 문서의 내용 유지. 다른 창의 경고는 별도로 남아 있었음 |
| 두 창의 종료 Save/Don't Save | 조작은 수행했으나 폐기 결과 이상 때문에 전체 통과로 판정하지 않음 |

일부 ⌘W 경로는 앱의 사용자 정의 경고 대신 AppKit 기본 저장/권한 패널을 표시했습니다. 서로 다른 경로를 같은 구현의 성공으로 간주하지 않습니다. 읽기 전용 파일 자체를 0444로 여는 예비 시도는 편집 시 Unlock 경고를 유발했으므로, 실제 쓰기 오류 검사는 파일을 편집 가능한 상태로 연 뒤 부모 폴더 권한을 바꾸어 수행했습니다. 테스트 폴더 권한은 복구했습니다.

## 자동 회귀 검사

| 실행 | 결과 | 보존 로그 |
|---|---|---|
| `sh Tests/run-native.sh` | 3개 그룹 통과 | [native.log](results/2026-10-15/native.log) |
| `sh Tests/run-webkit.sh` | 15/15 통과 | [webkit.log](results/2026-10-15/webkit.log) |
| `sh Tests/run-hosted.sh` | 127 통과, 일반 실패 0, 알려진 실패 2, 예상 밖 통과 0, 건너뜀 1 | [hosted.log](results/2026-10-15/hosted.log) |

알려진 실패는 완료 항목 밖의 20번(파일·새 문서의 초기 이중 로드로 빈 화면)입니다. 건너뜀은 쓰기 금지 폴더의 상대 이미지 로딩입니다. 이 결과를 새로 통과한 기능으로 합산하지 않습니다. 로그의 sandbox extension 진단과 달리 실행은 완료됐고 위 검사 결과를 반환했습니다.

## 검증 한계와 다음 검증

- 저장 진행 중 추가 입력을 강제로 끼워 넣는 지연 I/O 경합은 이번 GUI 실행에서 검증하지 않았습니다.
- 폐기 결함은 반복 성공 사례도 있어 반복 실행·저장 요청 추적이 필요합니다. 앱 전체가 무결함이라고 판단할 수 없습니다.
- 보안/자리표시자 검사는 기존 회귀 입력 범위입니다. 전체 입력 공간을 검사한 결과는 아닙니다.
- 이번 요청은 테스트이므로 결함 수정은 수행하지 않았습니다. 다음 수정은 폐기 결과 보장과 실제 DocumentGroup Undo 경합에 대한 실패 회귀 검사부터 진행해야 합니다.
- `/private/tmp` 테스트 파일과 빌드는 조사용으로 남겨 두었습니다. 일반 사용자 문서는 편집하지 않았습니다.
