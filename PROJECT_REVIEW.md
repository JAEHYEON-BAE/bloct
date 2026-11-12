# Bloct 프로젝트 분석 보고서

## 진행 체크리스트

최신화: 2026-11-12. 번호는 아래 본문 절 번호입니다. 절의 내용이 **전부** 끝나고 [CLAUDE.md](CLAUDE.md)의 완료 기준(코드 변경은 실제 앱 확인 포함)을 채웠을 때만 체크합니다. 상세 기록은 [BUG_FIXES.md](BUG_FIXES.md)와 [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md)에 둡니다.

**2. 저장 실패·데이터 손실 위험**

- [ ] 2.1 UTF-8 BOM 파일 저장 불가 — 미착수
- [x] 2.2 URL·이메일·문자 참조 입력 시 저장 거절 — 검증 완료(2026-11-11), 자동 검사·Computer Use 입력/저장/재열기 통과 ([47번](BUG_FIXES.md#bug-47))
- [x] 2.3 겹친 서식 저장 거절·링크 쪼개짐 — 검증 완료(2026-11-11), 자동 검사·Computer Use 입력/저장/재열기 통과 ([47번](BUG_FIXES.md#bug-47))
- [ ] 2.4 저장 시 확장 속성 소실·심볼릭 링크 교체 — 미착수
- [ ] 2.5 WebContent 프로세스 종료 시 초안 복구 불가 — 미착수
- [ ] 2.6 종료 진행 플래그 잔류 — 미착수

**3. Markdown 관행**

- [x] 3.1 문장부호 전부 이스케이프 — 검증 완료(2026-11-11), 자동 검사·Computer Use 입력/저장/재열기 통과 ([47번](BUG_FIXES.md#bug-47))
- [x] 3.2 서식 옆 공백이 `&#32;`로 저장 — 검증 완료(2026-11-11), 자동 검사·Computer Use 입력/저장/재열기 통과 ([47번](BUG_FIXES.md#bug-47))
- [ ] 3.3 한 항목만 고쳐도 컨테이너 전체 재작성 — 미착수. 3.1·3.2 수정으로 다시 쓰인 항목의 표기는 유지됨
- [x] 3.4 링크 주소 꺾쇠·자동 링크 풀어 쓰기 — 검증 완료(2026-11-11), 자동 검사·Computer Use 입력/저장/재열기 통과 ([47번](BUG_FIXES.md#bug-47))
- [ ] 3.5 취소선·각주·축약 참조 링크가 리터럴로 굳음 — **일부.** 표의 세 예시는 원문 그대로 저장되도록 구현(자동 검사·Computer Use의 리터럴 표기 편집/저장/재열기 통과). 취소선 안에 다른 서식이 있으면 여전히 이스케이프됨. 취소선 mark 지원은 미착수
- [ ] 3.6 편집 시 조용히 바뀌는 표기(코드 펜스 정보 손실 포함) — 미착수
- [ ] 3.7 빈 줄 경계 정책의 사용자 문서 — 미착수
- [ ] 3.8 읽기 상태에서 링크 열기 — 미착수

**4. Swift 관행과 비효율**

- [x] 4.1 직접 만든 직렬화기 — 검증 완료(2026-11-11), 자동 검사·Computer Use 입력/저장/재열기 통과. 인라인 출력을 `mdast-util-to-markdown`으로 교체. 블록 뼈대(목록 marker·체크 문자·표·CRLF)는 원문 표기 보존을 위해 기존 코드를 유지
- [ ] 4.2 문서를 열 때의 중복 작업 — **일부.** 죽은 코드 중 읽기 검색·복사 변환·`exportUnchanged`·`formats` 제거(자동 검사·Computer Use의 읽기/편집 검색·서식 복사/붙여넣기 통과). 남은 것: 이중 렌더·KaTeX/CSS 중복·압축·리소스 캐시, 그리고 테스트가 쓰는 수동 전환 경로·제목 ID 정리·`commitEdit`·`format()`. `execute`/`reference`는 설계 계약(B10·B11)이라 유지하고 주석만 고침
- [ ] 4.2.1 미리보기 파일 필요 여부 — 정책 결정 필요
- [ ] 4.3 0.6초 전체 파일 폴링 — 미착수
- [ ] 4.4 `ContentView` 상태 기계 — 미착수
- [ ] 4.5 입력마다 도는 전체 순회 — 미착수
- [ ] 4.6 Swift 문자열 속 JS — **일부(2026-11-12).** `MarkdownWebView.swift`의 HTML 뼈대·읽기 렌더러·목차/스크롤/리사이즈/목차 토글을 `page.html`·`reader.js`·`page-host.js`·`page-start.js` 리소스로 분리하고 `PageTemplate.swift`가 nonce·JSON 설정만 채움. 값 전달은 JSON 설정과 `callAsyncJavaScript(arguments:)`로 통일(실제 앱·자동 회귀 통과, [기록](Tests/results/2026-11-12/page-resources-gui.json)). 남은 것: TypeScript 이전·번들, `ContentView.swift`의 문자열 보간 호출
- [ ] 4.7 종료 처리 관례 — 미착수
- [ ] 4.8 그 밖의 관행 위반 — 미착수

**5~8. 문서·일관성·빌드·구조**

- [ ] 5 문서와 구현 불일치 — 미착수
- [ ] 6 일관성 — 미착수
- [ ] 7.1 릴리스가 테스트 없이 배포 — 미착수
- [ ] 7.2 테스트의 소스 문자열 치환 — 미착수
- [ ] 7.3 그 밖(빌드·러너) — 미착수
- [ ] 8.2 구조 개편(8.1 문제·8.3 영향 범위·8.4 순서 포함) — 미착수
- [x] 8.5 `Tests/results/` 정리 — 완료(2026-11-11). 최근 두 날짜 폴더만 유지하도록 정책 변경, 이전 폴더 11개·날짜 보고서 삭제, 문서 링크 65개를 `v2.0.1` 태그 영구 링크로 전환

### 권장 다음 순서

이번 변경의 직렬화기·중첩 강조 열기·미사용 코드 제거는 2026-11-11 [Computer Use·자동 회귀](Tests/results/2026-11-11/review-gui.json)와 [저장 원문 비교](Tests/results/2026-11-11/review-gui-disk.json)를 통과했습니다. 상세·남은 한계는 [47·48번](BUG_FIXES.md#bug-47)을 따릅니다.

1. **저장 경로(2.1, 2.4).** BOM 보존과 `replaceItemAt` 교체. 변경 범위가 `DocumentDisk`에 머뭅니다.
2. **직렬화 후속(3.6, 3.3, 3.5).** 코드 펜스 정보 보존, 목록 항목 단위 원문 재사용, 취소선 mark 지원 순서입니다.
3. **4.2의 나머지.** `automaticEditing`·수동 전환 경로와 이중 렌더를 제거합니다. `Tests/js/aa-*.js`와 `commitEdit`을 쓰는 하네스 5개를 함께 옮겨야 합니다.
4. **CI(7.1)와 러너 수리(7.3).** 독립적이라 언제든 가능합니다. `run-menu-polling.sh`는 현재 3건 실패합니다(리소스 누락, 2026-11-11 재실행으로 확인).

---

- 기준: 커밋 `9537180` (v2.0.1), 2026-11-11. 분석 중 `c7139bd`·`9537180`이 추가됐으나 소스 변경은 버전 문자열뿐입니다.
- 최초 분석에서는 코드를 수정하지 않았습니다. 이후 구현·검증 상태는 위 체크리스트를 따릅니다.
- 읽은 범위: `Sources/Bloct/` 전체, `Editor/src/` 전체, `scripts/`, `.github/workflows/release.yml`, `project.yml`, 루트 문서 6종, `Tests/README.md`, `Tests/run-*.sh`, `Tests/gui-session.mjs`.
- 읽지 않은 범위: `Tests/*.swift` 하네스 본문, `Tests/*.js`·`Tests/js/`, `Editor/test/`·`Editor/test-dom/`, `Tests/results/`의 개별 로그. 이 부분의 결함 여부는 판단하지 않았습니다.

각 항목의 근거 수준은 다음 표기로 구분합니다.

| 표기 | 의미 |
|---|---|
| **[실행]** | 프로덕션 코드를 그대로 가져와 임시 폴더에서 실행해 확인. 실제 앱 GUI는 실행하지 않음 |
| **[코드]** | 소스를 읽어 확인. 실행으로 재현하지는 않음 |
| **[추정]** | 코드상 가능성이 있으나 확인하지 못함. 수정 전 재현이 필요 |

실행 확인은 두 가지 방법을 썼습니다. 편집 모델은 `Editor/src/session.ts`의 `BlockSession`을 Node로 직접 불러 문서를 편집한 뒤 `markdown()` 결과를 봤고(프로덕션과 같은 `trailingParagraph: true`), 파일 입출력은 `Sources/Bloct/DocumentDisk.swift`를 그대로 컴파일해 임시 파일에 호출했습니다(macOS 27.2, Swift 6.4). 재현 스크립트는 [부록](#부록-재현-방법)에 있습니다.

## 1. 요약

가장 먼저 볼 항목입니다. 번호는 아래 본문 절 번호입니다.

| # | 심각도 | 내용 | 근거 |
|---|---|---|---|
| 2.1 | 높음 | UTF-8 BOM이 있는 파일은 ⌘S가 항상 충돌로 거절됨 | 실행 |
| 2.2 | 높음 | 본문에 URL·이메일·`&amp;` 같은 글자를 그대로 입력하면 저장과 Esc가 모두 실패 | 실행 |
| 2.3 | 높음 | 굵게 안에 기울임·코드가 섞인 문단을 편집하면 저장 실패. 링크는 둘로 쪼개짐 | 실행 |
| 2.4 | 중간 | 저장할 때마다 Finder 태그 등 확장 속성이 사라지고, 심볼릭 링크는 일반 파일로 바뀜 | 실행 |
| 2.5 | 중간 | WebContent 프로세스가 죽으면 미저장 초안을 복구할 경로가 없음 | 코드 |
| 3.1 | 높음 | 편집한 블록의 문장부호가 전부 백슬래시로 이스케이프됨 (`1.0 (beta)` → `1\.0 \(beta\)`) | 실행 |
| 3.2 | 높음 | 서식 옆 공백이 `&#32;`로 저장됨 | 실행 |
| 3.3 | 중간 | 목록의 한 항목만 고쳐도 목록 전체가 다시 쓰임 | 실행 |
| 3.5 | 중간 | 취소선·각주·축약 참조 링크가 편집 후 리터럴로 굳어 다른 렌더러에서 깨짐 | 실행 |
| 3.8 | 중간 | 읽기 상태에서 링크를 열 방법이 없음 | 코드 |
| 4.2 | 중간 | 문서를 열 때 전체를 두 번 렌더링하고, KaTeX·CSS가 두 벌씩 들어감 | 코드 |
| 4.3 | 중간 | 열린 창마다 0.6초 간격으로 파일 전체를 다시 읽음 | 코드 |
| 7.1 | 중간 | 릴리스 워크플로가 테스트와 타입 검사 없이 배포함 | 코드 |

2.2·2.3은 실패 시 초안을 버리지 않고 거절하는(fail-closed) 설계 덕분에 파일이 망가지지는 않습니다. 다만 사용자는 원인을 알 수 없는 오류만 보고 저장도 읽기 복귀도 못 하게 됩니다.

## 2. 저장 실패·데이터 손실 위험

### 2.1 UTF-8 BOM 파일을 저장할 수 없음 — 높음 [실행]

- 위치: [DocumentDisk.swift:25](Sources/Bloct/DocumentDisk.swift#L25), [DocumentDisk.swift:39](Sources/Bloct/DocumentDisk.swift#L39), [MarkdownDocument.swift:46-47](Sources/Bloct/MarkdownDocument.swift#L46-L47), [MarkdownDocument.swift:28](Sources/Bloct/MarkdownDocument.swift#L28)
- 원인: `String(data:encoding: .utf8)`와 `String(contentsOf:encoding: .utf8)`은 선두 BOM을 제거합니다. 그래서 `originalText`에는 BOM이 없는데, 저장 직전 검사(39행)는 디스크의 원시 바이트와 `Data(expected.utf8)`를 비교합니다. BOM 3바이트만큼 항상 다르므로 `Conflict.changed`가 납니다.
- 재현: BOM + `# Title\n` 파일에 `DocumentDisk.read` 후 `DocumentDisk.save(_:to:replacing:)`를 호출하면 "The file changed on disk…"로 실패합니다. BOM 없는 대조 파일은 성공합니다. 앱에서는 [ContentView.swift:498](Sources/Bloct/ContentView.swift#L498)을 거쳐 ⌘S마다 충돌 대화상자가 뜰 것입니다(GUI 미확인).
- 부수 효과: JS 쪽의 BOM 보존 코드([importer.ts:57](Editor/src/importer.ts#L57), `doc.attrs.bom`)는 Swift가 먼저 BOM을 떼어 내므로 앱에서는 도달하지 않습니다. `TextDecoder`도 기본값으로 BOM을 제거합니다([MarkdownWebView.swift:887](Sources/Bloct/MarkdownWebView.swift#L887), [editor-switch.js:7](Sources/Bloct/editor-switch.js#L7)).
- 수정 방법 (둘 중 하나):
  - Swift에서 BOM을 분리해 관리합니다. `read`가 본문과 `hasBOM`을 함께 돌려주고, 39행 비교와 40행 쓰기에서 BOM을 다시 붙입니다. 변경 범위가 `DocumentDisk`와 `MarkdownDocument`로 한정됩니다.
  - BOM을 문자열에 남깁니다. 유효성은 기존처럼 검사하되 본문은 `String(decoding: data, as: UTF8.self)`로 만들고(BOM 유지 확인함), JS 디코더를 `new TextDecoder('utf-8', {ignoreBOM: true})`로 바꿉니다. 이렇게 해야 importer의 `bom` 속성이 실제로 쓰입니다.
- 문서: [IMPLEMENTATION_PLAN.md:58](IMPLEMENTATION_PLAN.md#L58)의 "BOM·CRLF·공백 … 보존" 계약과 맞지 않습니다. `Tests/run-native.sh`에 BOM 파일 저장 검사를 추가해야 합니다.

### 2.2 URL·이메일·문자 참조를 일반 텍스트로 입력하면 저장이 거절됨 — 높음 [실행]

빈 문서에 아래 글자를 그대로 입력한 뒤 `markdown()`을 호출한 결과입니다.

| 입력한 텍스트 | 결과 |
|---|---|
| `visit https://example.com now` | `Markdown round-trip would change document structure` 예외 |
| `mail user@example.com now` | 같은 예외 |
| `see www.example.com now` | 같은 예외 |
| `use &nbsp; or &amp; here` | 같은 예외 |

- 위치: [serializer.ts:37-40](Editor/src/serializer.ts#L37-L40) `escapeText`, [serializer.ts:169](Editor/src/serializer.ts#L169) 왕복 검증
- 원인: `escapeText`는 `.`만 이스케이프하므로 `https://example\.com`이 됩니다. 재파싱하면 GFM autolink literal이 `https://example\.com`을 링크로 인식해 구조가 달라집니다. 이메일도 `user@example\.com`이 그대로 링크가 됩니다. `&`는 이스케이프 대상에 없어서 `&amp;`가 `&`로 디코드됩니다.
- 영향: `markdown()`이 던지면 `snapshot()`([visual-editor.ts:735-741](Editor/src/visual-editor.ts#L735-L741))이 실패하고, 이를 쓰는 Save([ContentView.swift:467-479](Sources/Bloct/ContentView.swift#L467-L479))와 Esc 인계([editor-switch.js:75](Sources/Bloct/editor-switch.js#L75))가 모두 실패합니다. 사용자는 해당 글자를 지우기 전에는 저장도 읽기 복귀도 못 합니다.
- 수정 방법:
  - 가장 근본적인 방법은 4.1의 권장안처럼 직접 만든 `inline()`/`escapeText()`를 `mdast-util-to-markdown` + `gfmToMarkdown()` + `mathToMarkdown()`으로 교체하는 것입니다. 이 라이브러리는 autolink(`@`, `www.`, `://`)와 문자 참조(`&`)의 문맥별 이스케이프 규칙을 이미 갖고 있고, `mdast-util-gfm`의 의존성으로 설치돼 있습니다.
  - 교체 없이 고치려면 `escapeText`에 다음 규칙을 추가합니다. `&` 뒤에 `#` 또는 영문자가 오면 `\&`, `http`/`https` 뒤의 `:`는 `\:`, 이메일 형태의 `@`는 `\@`, `www` 뒤의 `.`는 `\.`입니다.
  - 정책 대안: 입력 시점에 URL을 링크 mark로 바꿔 편집 상태를 GFM 의미와 일치시킵니다. 이 경우 3.4의 자동 링크 직렬화도 함께 고쳐야 합니다.
- **정정 (2026-11-11):** 위 원인 설명과 두 수정안의 URL·이메일 부분은 틀렸습니다. importer의 `gfmFromMarkdown()`은 파싱이 끝난 뒤 텍스트를 다시 훑어 URL·이메일 모양을 링크로 바꿉니다(`mdast-util-gfm-autolink-literal`의 트리 변환). 그래서 `https\://example.com`처럼 이스케이프해도 링크가 되고(실행 확인), 라이브러리의 이스케이프 규칙이나 `escapeText` 보강으로는 해결되지 않습니다. 실제 수정은 링크가 아닌 URL 텍스트와 리터럴 자동 링크를 같은 의미로 비교하는 방식입니다([BUG_FIXES.md 47번](BUG_FIXES.md#bug-47)). `&amp;` 설명은 맞습니다.

### 2.3 서식이 겹친 문단을 편집하면 저장이 거절되거나 링크가 쪼개짐 — 높음 [실행]

각 원문의 끝에 글자 하나를 덧붙인 뒤의 결과입니다.

| 원문 또는 조작 | 결과 |
|---|---|
| `**bold *both* bold** tail` | 예외. 중간 출력은 `**bold&#32;*****both*****&#32;bold**&#32;tailZ` |
| ``**bold `code` more** tail`` | 예외. 중간 출력은 ``**bold&#32;****`code`****&#32;more**&#32;tailZ`` |
| `a word b`에서 `word `(뒤 공백 포함)를 선택해 굵게 | 예외 |
| `[**Bold** link](https://example.com) tail` | 저장은 되지만 `**[Bold](<…>)**[&#32;link](<…>)`로 링크가 둘이 됨 |

- 위치: [serializer.ts:43-71](Editor/src/serializer.ts#L43-L71), 특히 [63-67행](Editor/src/serializer.ts#L63-L67)
- 원인: `inline()`이 텍스트 노드마다 mark를 따로 감쌉니다. 이웃한 노드가 같은 mark를 공유해도 합치지 않으므로 `**…**`가 노드 수만큼 반복되고, 구분자 안쪽에 공백이 남아 강조로 인식되지 않습니다.
- 수정 방법: mark 스택을 유지하며 직렬화합니다. 노드를 순서대로 보면서 이전 노드와 공통인 mark는 그대로 두고, 사라진 mark만 닫고 새 mark만 엽니다. 여는 구분자 직후와 닫는 구분자 직전의 공백은 구분자 밖으로 옮깁니다. 링크는 같은 `href`·`title`이 이어지는 구간 전체를 하나의 `[...]()`로 감쌉니다. `mdast-util-to-markdown`으로 교체하면 이 처리도 함께 해결됩니다.
- 검사 추가: `Editor/test/session.test.ts`에 위 네 가지와 "굵게 안의 링크", "링크 안의 코드"를 넣습니다. 현재 fixture([bug-44-code-marks.md](Tests/fixtures/bug-44-code-marks.md))는 mark가 노드 전체를 덮는 경우만 다룹니다.

### 2.4 저장할 때 확장 속성이 사라지고 심볼릭 링크가 일반 파일로 바뀜 — 중간 [실행]

- 위치: [DocumentDisk.swift:40](Sources/Bloct/DocumentDisk.swift#L40), [ContentView.swift:678](Sources/Bloct/ContentView.swift#L678)
- 원인: `Data.write(to:options: .atomic)`는 임시 파일을 만든 뒤 이름을 바꿉니다. 실행해 보니 권한(0600)은 유지되지만 inode가 바뀌고 확장 속성이 사라집니다. Finder 태그는 확장 속성에 저장되므로 Bloct로 저장할 때마다 태그가 없어집니다. 대상 경로가 심볼릭 링크이면 링크 자체가 일반 파일로 교체되고 원래 대상 파일은 갱신되지 않습니다.
- 한계: 심볼릭 링크 문제는 `NSDocument`가 넘겨주는 `fileURL`이 링크 경로일 때만 생깁니다. 앱에서 그 조건이 성립하는지는 확인하지 않았습니다.
- 수정 방법: `FileManager.default.url(for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: url, create: true)`에 임시 파일을 쓰고 `FileManager.default.replaceItemAt(url, withItemAt: temp)`로 교체합니다. 같은 조건에서 권한과 확장 속성이 유지되는 것을 확인했습니다. 쓰기 전에 `url.resolvingSymlinksInPath()`로 실제 대상을 구합니다.

### 2.5 WebContent 프로세스가 종료되면 초안을 복구할 수 없음 — 중간 [코드]

- 위치: [MarkdownWebView.swift:225-481](Sources/Bloct/MarkdownWebView.swift#L225-L481) `Coordinator`
- 원인: `webViewWebContentProcessDidTerminate(_:)`가 구현돼 있지 않습니다. 편집 초안은 설계상 JS 엔진에만 있고([IMPLEMENTATION_PLAN.md:56](IMPLEMENTATION_PLAN.md#L56)), Swift의 `docState.text`는 모드 전환·저장 시점의 스냅샷뿐입니다. 메모리 압박 등으로 웹 프로세스가 죽으면 화면은 비고 `isPageLoaded`는 `true`로 남으며, 이후 Save는 JS 호출 오류만 표시합니다.
- 수정 방법: 델리게이트를 구현해 `pageLoad`와 `isPageLoaded`를 초기화하고 마지막 Swift 스냅샷으로 페이지를 다시 띄운 뒤 "편집 내용 일부가 복구되지 않았을 수 있음"을 알립니다. 손실 폭을 줄이려면 편집 중 입력이 멈춘 뒤 1~2초 디바운스로 스냅샷을 `docState.receiveVisualSnapshot`에 반영합니다. 이는 계약 1의 "매 키 입력에 echo하지 않는다"와 충돌하지 않습니다.

### 2.6 종료 진행 플래그가 남아 뜻밖의 종료가 일어날 수 있음 — 낮음 [코드]

- 위치: [BloctApp.swift:125](Sources/Bloct/BloctApp.swift#L125), [ContentView.swift:398](Sources/Bloct/ContentView.swift#L398), [ContentView.swift:411](Sources/Bloct/ContentView.swift#L411)
- 원인: `interceptUnsavedWindowsForQuit`가 `AppDelegate.isQuitting = true`로 만든 뒤 `onIntercept`를 부릅니다. 그런데 `requestVisualClose`는 `isSwitchingEditor`나 `isCheckingVisualClose`가 참이면 플래그를 되돌리지 않고 그냥 반환합니다. 종료는 조용히 무시되고 플래그만 남습니다. 이후 다른 창을 평범하게 닫으면 411행의 `if AppDelegate.isQuitting { handleQuit() }`가 실행돼 앱 종료가 이어집니다.
- 수정 방법: 398행의 조기 반환 경로에서 `AppDelegate.isQuitting = false`로 되돌립니다. 근본적으로는 전역 정적 변수 대신 4.7의 종료 조정 객체로 옮깁니다.

## 3. Markdown 관행과 어긋나는 부분

편집기가 저장하는 Markdown의 품질에 관한 항목입니다. 편집하지 않은 최상위 블록은 원문 그대로 재사용되므로, 아래 문제는 **사용자가 손댄 블록**에서만 나타납니다.

### 3.1 문장부호를 전부 이스케이프함 — 높음 [실행]

- 위치: [serializer.ts:37-40](Editor/src/serializer.ts#L37-L40)
- 현상: `e.g. version 1.0 (beta) - a+b! #tag`를 편집하면 `e\.g\. version 1\.0 \(beta\) \- a\+b\! \#tag`로 저장됩니다. 정규식이 `. - ( ) ! + # | ~ < >`를 위치와 무관하게 이스케이프하기 때문입니다.
- 왜 문제인가: Markdown의 전제는 원문이 그대로 읽히는 것입니다. 이 파일을 다른 편집기나 Git diff로 보면 거의 모든 문장에 백슬래시가 붙어 있습니다.
- 수정 방법: 문자가 실제로 구문이 되는 위치에서만 이스케이프합니다.
  - 어디서나: `\`, `` ` ``, `*`, `_`, `[`, `]`, `<`, `$`
  - 줄 시작에서만: `#`, `>`, `-`, `+`, `=`, 그리고 숫자 뒤의 `.`과 `)`
  - `[` 바로 앞에서만: `!`
  - 표 셀 안에서만: `|`
  - `(`, `)`는 링크 구문 밖에서는 이스케이프할 필요가 없습니다.

### 3.2 서식 옆 공백이 `&#32;`로 저장됨 — 높음 [실행]

- 위치: [serializer.ts:39](Editor/src/serializer.ts#L39)
- 현상: `This is **bold** and *italic* text.`를 편집하면 `This is&#32;**bold**&#32;and&#32;*italic*&#32;text\.`가 됩니다.
- 원인: 앞뒤 공백을 문자 참조로 바꾸는 처리는 문단의 맨 앞과 맨 끝을 보호하려는 것인데, `escapeText`가 텍스트 노드 단위로 호출됩니다. 서식 경계마다 노드가 나뉘므로 문장 중간의 공백도 "노드의 끝"으로 취급됩니다.
- 수정 방법: `escapeText`에서 39행을 제거하고, 공백 치환은 `block()`의 문단 처리([106-107행](Editor/src/serializer.ts#L106-L107))처럼 완성된 줄의 맨 앞·맨 끝에만 적용합니다.

### 3.3 한 항목만 고쳐도 컨테이너 전체가 다시 쓰임 — 중간 [실행]

- 위치: [serializer.ts:101-103](Editor/src/serializer.ts#L101-L103), [serializer.ts:162-167](Editor/src/serializer.ts#L162-L167)
- 현상: `- **a** b` / `- c (d)` 두 항목 중 첫 항목만 편집해도 둘째가 `- c \(d\)`로 바뀝니다. 원문 재사용이 최상위 블록 단위라서 목록·인용·표는 일부만 바뀌어도 전체가 재직렬화됩니다.
- 영향: 긴 목록에서 한 글자를 고치면 diff가 목록 전체로 번집니다. 3.1·3.2가 이 범위 전체에 적용됩니다.
- 수정 방법: `reused()`를 목록 항목과 표 행에도 적용합니다. 부모 목록의 marker·시작 번호·들여쓰기가 그대로이고 해당 항목의 하위 트리가 변하지 않았다면 항목의 원문 구간을 그대로 씁니다. 3.1·3.2를 먼저 고치면 체감 문제는 크게 줄어듭니다.

### 3.4 링크 주소를 항상 꺾쇠로 감싸고 자동 링크를 풀어 씀 — 중간 [실행]

- 위치: [serializer.ts:41](Editor/src/serializer.ts#L41), [serializer.ts:66](Editor/src/serializer.ts#L66), [serializer.ts:73](Editor/src/serializer.ts#L73)
- 현상: `[docs](https://example.com/a_b)`는 편집 후 `[docs](<https://example.com/a_b>)`가 됩니다. 본문에 있던 `https://example.com`이나 `<https://example.com>`은 `[https://example\.com](<https://example.com>)`로 바뀝니다.
- 왜 문제인가: 꺾쇠 주소는 CommonMark에 있는 문법이지만 공백이 있을 때만 쓰는 것이 관례이고, 지원하지 않는 도구도 있습니다. 호환 렌더러에 이 형태를 처리하는 예외 코드를 따로 넣어야 했던 것([MarkdownWebView.swift:764-766](Sources/Bloct/MarkdownWebView.swift#L764-L766))도 같은 원인입니다.
- 수정 방법: 주소에 공백·제어문자·짝이 맞지 않는 괄호가 있거나 빈 문자열일 때만 `<…>`로 감쌉니다. 링크 텍스트가 주소와 같으면 `<https://…>` 자동 링크 형태로 씁니다.

### 3.5 취소선·각주·축약 참조 링크가 편집 후 리터럴로 굳음 — 중간 [실행]

| 원문 (문단 끝에 한 글자 추가) | 저장 결과 |
|---|---|
| `keep ~~old~~ text` | `keep \~\~old\~\~ text` |
| `Text[^1] here.` (각주 정의는 다른 블록) | `Text\[^1\] here\.` |
| `See [docs] for more.` (`[docs]: …` 정의는 다른 블록) | `See \[docs\] for more\.` |

- 위치: [importer.ts:93](Editor/src/importer.ts#L93), [importer.ts:105](Editor/src/importer.ts#L105), [serializer.ts:38](Editor/src/serializer.ts#L38)
- 원인: 빈 줄마다 따로 파싱하므로 다른 구간에 있는 정의를 찾지 못해 `[docs]`와 `[^1]`이 일반 텍스트가 됩니다. 105행의 정규식은 `[a][b]` 형태만 보호하고 축약형 `[a]`는 잡지 못합니다. 취소선은 원문 문자열로 가져온 뒤 `~`를 이스케이프합니다. 세 경우 모두 Bloct 안에서는 모양이 같아 왕복 검증을 통과하지만, GitHub 등에서는 취소선·각주·링크가 사라집니다.
- 수정 방법:
  - 취소선: GFM을 표방한다면 `strike` mark로 지원하는 것이 맞습니다. 리터럴 정책을 유지하려면 [importer.ts:20](Editor/src/importer.ts#L20)의 `gfm()`을 표·할 일·자동 링크·각주 확장만 조합한 것으로 바꿔 `~`가 특수 문자가 되지 않게 하고, `escapeText`에서 `~`를 뺍니다.
  - 참조·각주: `regions()`가 이미 문서 전체를 한 번 파싱하므로, 그 결과에서 정의 식별자 집합을 모읍니다. 문단 원문에 그 식별자를 가리키는 `[id]` 또는 `[^id]`가 있으면 105행처럼 `raw_source`로 보호합니다.

### 3.6 편집 시 조용히 바뀌는 표기 — 낮음 [실행]

원문과 의미는 같지만 편집하면 표기가 바뀝니다. 대부분은 허용할 만한 정규화이고, 정보가 사라지는 것은 첫 줄뿐입니다.

| 원문 | 편집 후 | 비고 |
|---|---|---|
| ` ```js {1,3} title="x" ` | ` ```js ` | **정보 손실.** [importer.ts:142](Editor/src/importer.ts#L142)가 `n.meta`를 버림 |
| `~~~py` 펜스 | ` ```py ` | 펜스 문자 변경 |
| `Title` / `=====` | `# Title` | setext → ATX |
| `## Title ##` | `## Title` | 닫는 `#` 제거 |
| `_em_`, `__strong__` | `*em*`, `**strong**` | 구분자 통일 |
| `1.` `1.` `1.` | `1.` `2.` `3.` | 번호 재부여 |
| 줄 끝 공백 두 칸 | `\` + 개행 | hard break 표기 |
| `AT&amp;T`, `&copy;` | `AT&T`, `©` | 문자 참조 디코드 |

- 수정 방법: `code_block`에 `meta` 속성을 추가해 [serializer.ts:116](Editor/src/serializer.ts#L116)에서 언어 뒤에 다시 붙입니다. 나머지는 "편집한 블록은 Bloct 표기로 정규화된다"고 README에 밝히는 것으로 충분합니다.

### 3.7 빈 줄 경계 정책이 사용자 문서에 없음 — 중간 [실행]

빈 줄을 독립 파싱 경계로 삼는 것은 [AGENTS.md:36](AGENTS.md#L36)에 적힌 의도된 정책이므로 결함으로 보지 않습니다. 다만 일반적인 Markdown과 결과가 달라지는 경우를 README가 설명하지 않습니다.

| 원문 | CommonMark | Bloct |
|---|---|---|
| `1. a` (빈 줄) `2. b` | 느슨한 목록 하나 | 목록 두 개 (둘째는 2부터 시작) |
| `1. step` (빈 줄) 4칸 들여쓴 ` ```sh ` 펜스 | 목록 항목 안의 코드 블록 | 목록 뒤에 **들여쓰기 코드 블록**. 펜스 문자가 본문으로 보임 |

둘째 경우는 설치 안내 같은 README에서 매우 흔한 형태입니다. [README.md:89](README.md#L89)는 "GitHub Flavored Markdown"이라고만 적고 있으므로 사용자는 차이를 알 수 없습니다.

- 수정 방법: README에 "Markdown dialect" 절을 추가해 빈 줄 경계, 취소선·참조 링크·각주 미지원, `$…$` 수식, 이미지 속성 `{width=…}`, 캡션 `*[…]*`을 한곳에 정리합니다. 캡션과 이미지 속성은 다른 렌더러에서 기울임 글자와 리터럴 중괄호로 보인다는 점도 적습니다.

### 3.8 읽기 상태에서 링크를 열 수 없음 — 중간 [코드]

- 위치: [schema.ts:96-101](Editor/src/schema.ts#L96-L101), [editor-switch.js:108-119](Sources/Bloct/editor-switch.js#L108-L119), [MarkdownWebView.swift:904-921](Sources/Bloct/MarkdownWebView.swift#L904-L921)
- 원인: 편집 엔진은 링크를 `<span data-link-source>`로 그립니다. 외부 링크를 여는 처리기(912-921행)와 `#` 앵커 처리기(904-911행)는 `<a href>`만 찾습니다. 프로덕션은 항상 편집 엔진의 DOM을 쓰므로 일반 문단의 링크를 클릭하면 편집 진입만 일어납니다. `<a>`가 실제로 생기는 곳은 보호 원문 미리보기뿐입니다. 제목 ID도 `block-<uuid>`([visual-editor.ts:559](Editor/src/visual-editor.ts#L559))여서 `[x](#제목)` 같은 문서 내 링크는 대상이 없습니다.
- 수정 방법: 읽기 상태(`visual === false`)에서 `[data-link-source]` 클릭을 가로채 편집 진입 대신 이동합니다. `http`/`https`는 기존 `openExternal` 브리지로, `#…`는 제목 텍스트에서 만든 slug와 비교해 스크롤합니다. 편집 중에는 ⌘-클릭으로 엽니다. 스키마 주석("Navigation/URL validation must be added by the UI adapter before use")이 이 작업이 남았음을 가리킵니다.

## 4. Swift 관행과 비효율

### 4.1 직접 만든 직렬화기 — 구조적 원인 [코드]

2.2, 2.3, 3.1, 3.2, 3.4는 모두 [serializer.ts](Editor/src/serializer.ts)의 `inline()`·`escapeText()`·`destination()`에서 나옵니다. 파싱은 micromark/mdast를 쓰면서 출력만 손으로 만들었기 때문에 두 쪽의 규칙이 어긋납니다.

- 권장: ProseMirror 문서를 mdast 트리로 변환하고 `mdast-util-to-markdown`으로 출력합니다. 옵션은 `bullet`(원문 marker), `emphasis: '*'`, `fences: true`, `rule: '-'`, `listItemIndent: 'one'`, 확장은 `gfmToMarkdown()`과 `mathToMarkdown()`입니다. 이미지 속성·캡션은 사용자 정의 handler로 처리합니다.
- 유지할 것: 미변경 블록 재사용(`reused`), 체크 한 글자 패치, 왕복 의미 검증(169행)은 그대로 둡니다. 교체 대상은 "변경된 블록을 문자열로 만드는 부분"뿐입니다.

### 4.2 문서를 열 때의 중복 작업 — 중간 [코드]

프로덕션은 항상 `automaticEditing: true`입니다([ContentView.swift:243](Sources/Bloct/ContentView.swift#L243)). 이 설정에서 옛 읽기 렌더러의 대부분이 쓰이지 않는데도 매번 실행되고 번들됩니다.

| 중복 | 위치 | 내용 |
|---|---|---|
| 전체 문서 이중 렌더 | [MarkdownWebView.swift:894](Sources/Bloct/MarkdownWebView.swift#L894) → [editor-switch.js:44](Sources/Bloct/editor-switch.js#L44) | marked + DOMPurify + KaTeX로 전체를 렌더한 직후 그 DOM을 떼어 내고 ProseMirror가 다시 그림. 떼어 낸 DOM은 `readerHost` 변수에 페이지 수명 동안 남고, 그 안의 `<img>`도 한 번 더 로드됨 |
| KaTeX 두 벌 | [visual-editor.ts:10](Editor/src/visual-editor.ts#L10), [math-runtime.ts:1](Editor/src/math-runtime.ts#L1) | `blocks.js`(1.3MB)와 `math.js`(0.5MB)가 각각 KaTeX를 포함 |
| CSS 두 벌 | [MarkdownWebView.swift:606](Sources/Bloct/MarkdownWebView.swift#L606), [612](Sources/Bloct/MarkdownWebView.swift#L612), [build-resources.mjs:18](Editor/build-resources.mjs#L18) | `visual.css`가 이미 `style.css`를 포함하는데 606행에서 한 번 더 넣음. 612행은 `visualEditorStyles()`를 두 번 호출해 파일을 두 번 읽음 |
| 압축 없음 | [package.json:8](Editor/package.json#L8) | esbuild에 `--minify`가 없음 |
| 리소스 캐시 불일치 | [MarkdownWebView.swift:133-165](Sources/Bloct/MarkdownWebView.swift#L133-L165), [VisualEditorHTML.swift:4-8](Sources/Bloct/VisualEditorHTML.swift#L4-L8) | marked·purify·CSS는 `static let`으로 캐시하지만 `mathResource`와 `editorResource`는 문서를 열 때마다 약 2.2MB를 디스크에서 다시 읽음 |
| 문서 폴더에 미리보기 파일 | [PreviewFiles.swift:17](Sources/Bloct/PreviewFiles.swift#L17), [MarkdownWebView.swift:542](Sources/Bloct/MarkdownWebView.swift#L542) | 위 리소스가 모두 들어간 약 2.3MB HTML을 문서마다 사용자의 폴더에 씀 |

프로덕션에서 도달하지 않는 코드도 함께 남아 있습니다.

| 코드 | 위치 | 도달하지 않는 이유 |
|---|---|---|
| 읽기 검색 `_mvSearch` | [MarkdownWebView.swift:928-980](Sources/Bloct/MarkdownWebView.swift#L928-L980) | [editor-switch.js:99-104](Sources/Bloct/editor-switch.js#L99-L104)가 편집 엔진 검색으로 대체 |
| 복사 변환 `_mvHtmlToMd` | [MarkdownWebView.swift:983-1050](Sources/Bloct/MarkdownWebView.swift#L983-L1050) | 1041행의 `if (window._bloctVisual) return;`이 항상 참 |
| 제목 ID·앵커 정리 | [MarkdownWebView.swift:869-878](Sources/Bloct/MarkdownWebView.swift#L869-L878) | 떼어 낸 DOM에만 적용됨 |
| 수동 전환 경로 | [editor-switch.js:81-85](Sources/Bloct/editor-switch.js#L81-L85), [92](Sources/Bloct/editor-switch.js#L92), [129-130](Sources/Bloct/editor-switch.js#L129-L130) | `automatic`이 항상 참. 호환 테스트만 사용 |
| `commitEdit` 메시지 | [MarkdownWebView.swift:266-275](Sources/Bloct/MarkdownWebView.swift#L266-L275), [488](Sources/Bloct/MarkdownWebView.swift#L488) | 이 메시지를 보내는 JS가 `Sources/`와 `Editor/src/`에 없음 |
| `formats`, `format()` | [visual-editor.ts:25-30](Editor/src/visual-editor.ts#L25-L30), [398-433](Editor/src/visual-editor.ts#L398-L433) | 서식 바 제거 후 테스트만 호출 |
| `exportUnchanged` | [importer.ts:172-177](Editor/src/importer.ts#L172-L177) | 직렬화기 도입 전의 임시 함수 |
| `execute`, `reference` 등 | [session.ts:146-287](Editor/src/session.ts#L146-L287) | UI가 호출하지 않음. 향후 핸들·이동 기능용이라면 그렇게 주석을 고쳐야 함 |

- 수정 방법:
  - `automaticEditing` 매개변수([MarkdownWebView.swift:130](Sources/Bloct/MarkdownWebView.swift#L130))와 수동 경로를 제거하고, 초기 렌더(894행)를 건너뛰어 ProseMirror가 처음부터 그리게 합니다. `_mvRenderOneBlock`은 보호 원문·이미지 미리보기가 쓰므로 남깁니다. `Tests/js/aa-*.js`는 수동 전환을 전제로 하므로 함께 고쳐야 합니다.
  - `blocks.js`가 KaTeX를 `window.katex`로 내보내게 하고 `math.js`를 없애거나, 반대로 `blocks.js`에서 katex를 external로 지정합니다.
  - 606행의 `<style>\(Self.css)</style>`를 제거합니다. 단, `visual.css`가 없을 때의 대체 경로(612행)에서는 필요하므로 그 분기 안으로 옮깁니다.
  - 번들 리소스를 `enum BundledResource { static let blocksJS = load("blocks", "js") … }` 한곳에서 캐시합니다.
  - 미리보기 파일은 4.2.1에서 따로 다룹니다.

#### 4.2.1 미리보기 파일이 아직 필요한지 — 설계 결정 필요 [코드]

문서 폴더에 HTML을 쓰는 이유는 주석([MarkdownWebView.swift:373-376](Sources/Bloct/MarkdownWebView.swift#L373-L376))에 따르면 `file://` 이미지 로딩입니다. 그러나 지금은 파일 문서의 로컬 이미지를 전부 `bloct-image:` 스킴으로 바꿔 `LocalImageLoader`가 제공합니다([643-667행](Sources/Bloct/MarkdownWebView.swift#L643-L667)). 읽기 전용 폴더에서는 미리보기 파일 없이 `loadHTMLString`으로 동작하고 이미지도 로드된다고 [Tests/README.md:184-186](Tests/README.md#L184-L186)이 적고 있습니다.

- 제안: 모든 문서를 그 대체 경로로 통일하면 `PreviewFiles`, 종료 시 정리, 읽기 전용 분기가 사라지고, 동기화 폴더·Git 저장소에 숨김 파일이 생기지 않습니다. 저장소 루트에도 2026-05-01자 `.mv_preview.html`(75KB)이 남아 있습니다.
- 주의: [CLAUDE.md](CLAUDE.md)가 "문서별 미리보기 파일 소유권을 유지한다"를 원칙으로 두고 있으므로 이 변경은 정책 결정이 먼저입니다. `about:blank` 출처에서의 차이(`crypto.randomUUID` 등)는 [id.ts](Editor/src/id.ts)가 이미 처리합니다.

### 4.3 0.6초마다 파일 전체를 읽는 폴링 — 중간 [코드]

- 위치: [ContentView.swift:220](Sources/Bloct/ContentView.swift#L220), [267](Sources/Bloct/ContentView.swift#L267), [564](Sources/Bloct/ContentView.swift#L564), [DocumentDisk.swift:20-29](Sources/Bloct/DocumentDisk.swift#L20-L29)
- 현상: 열린 창마다 0.6초 간격으로 `NSFileCoordinator`를 거쳐 파일 전체를 읽고 문자열을 비교합니다. 문서가 크거나 네트워크·동기화 볼륨에 있으면 유휴 상태에서도 입출력이 계속됩니다.
- 관행: 타이머를 `View`의 저장 프로퍼티로 두면(220행) `ContentView`가 다시 만들어질 때마다 새 publisher가 생겨 주기가 초기화됩니다.
- 수정 방법: 파일과 상위 폴더에 `DispatchSource.makeFileSystemObjectSource`(`.write`, `.rename`, `.delete`)를 걸어 변경 알림이 올 때만 읽고, 알림을 놓치는 경우에 대비해 5~10초 간격의 느린 폴링을 남깁니다. "바이트 비교" 원칙은 읽기 시점에 그대로 적용됩니다. 타이머는 4.4의 컨트롤러가 소유합니다.

### 4.4 `ContentView`가 상태 기계를 `@State` 20개로 직접 운영 — 중간 [코드]

- 위치: [ContentView.swift:201-224](Sources/Bloct/ContentView.swift#L201-L224), [351-711](Sources/Bloct/ContentView.swift#L351-L711)
- 현상:
  - `isSaving`, `isSwitchingEditor`, `isCheckingVisualClose`, `isClosed`, `diskCheck.inProgress` 다섯 개의 불리언이 함께 "지금 무엇을 하는 중인가"를 표현합니다. 조합이 32가지인데 유효한 것은 몇 개뿐입니다.
  - 완료 처리기 + `DispatchQueue.main.async`([370](Sources/Bloct/ContentView.swift#L370), [402](Sources/Bloct/ContentView.swift#L402), [472](Sources/Bloct/ContentView.swift#L472)행 등), `Task { @MainActor in }`, `withCheckedContinuation`이 섞여 있습니다. WebKit 완료 처리기는 이미 메인 스레드에서 호출됩니다.
  - [358행](Sources/Bloct/ContentView.swift#L358)은 10ms 간격으로 `diskCheck.inProgress`를 확인하는 대기 루프이고 제한 시간이 없습니다.
  - 값 타입인 `View`의 메서드가 `self`를 캡처한 채 비동기로 `@State`를 바꿉니다. 뷰가 사라진 뒤의 변경을 막으려고 `isClosed`를 곳곳에서 검사합니다.
  - `isClosed`는 `onDisappear`에서 정해지는데([265-266행](Sources/Bloct/ContentView.swift#L265-L266)), "화면에서 사라짐"과 "닫힘"은 같지 않습니다. 창 탭 전환 등에서 어긋날 수 있습니다 **[추정]**.
- 수정 방법: `@MainActor @Observable final class DocumentController`를 만들어 상태와 저장·전환·디스크 확인 로직을 옮깁니다. 배포 대상이 macOS 14이므로 Observation을 쓸 수 있습니다.
  - 진행 상태는 `enum Activity { case idle, checkingDisk, switchingEditor, saving, confirmingClose }` 하나로 둡니다.
  - JS 호출은 `try await webView.callAsyncJavaScript(_:arguments:in:contentWorld:)`의 async 형태로 통일합니다.
  - 358행의 대기 루프는 진행 중인 `Task`를 저장해 두고 `await task.value`로 바꿉니다.
  - `ContentView`에는 화면 상태(`zoomLevel`, `showTOC`, `showSearch`, `searchText`)만 남깁니다.

### 4.5 편집 중 매 입력마다 도는 전체 순회 — 중간 [코드]

[IMPLEMENTATION_PLAN.md:28](IMPLEMENTATION_PLAN.md#L28)의 F2가 측정을 예정하고 있으므로, 측정할 지점을 구체적으로 적습니다.

| 지점 | 위치 | 내용 |
|---|---|---|
| 목차 재생성 | [visual-editor.ts:388-392](Editor/src/visual-editor.ts#L388-L392) | 커서 이동만 있는 트랜잭션에서도 `_mvBuildTOC`가 모든 제목을 다시 찾고 목차 DOM을 새로 만듦 |
| 장식 재계산 | [visual-editor.ts:542-575](Editor/src/visual-editor.ts#L542-L575) | 상태가 바뀔 때마다 문서 전체를 돌며 `DecorationSet`을 새로 만듦 |
| dirty 판정 | [session.ts:65](Editor/src/session.ts#L65), [82-85](Editor/src/session.ts#L82-L85), [118-121](Editor/src/session.ts#L118-L121) | `#savedDoc`이 `null`이면 `changed`가 `markdown()`을 호출해 전체 직렬화와 재파싱을 수행. 미저장 초안이 있는 채 Esc 후 다시 클릭하면 `setSavedBaseline`이 `#savedDoc`을 `null`로 만들어, 그 뒤 저장 전까지 모든 입력에서 이 경로를 탐 |
| 이중 파싱 | [importer.ts:32-54](Editor/src/importer.ts#L32-L54), [154-163](Editor/src/importer.ts#L154-L163) | `regions()`가 전체를 한 번, 이후 구간마다 한 번 더 파싱 |

- 수정 방법:
  - `notify()`에서 `tr.docChanged`이고 제목 노드가 영향받았을 때만 목차를 갱신하고, 150ms 정도로 디바운스합니다.
  - 장식은 플러그인 상태로 보관하고 `decorations.map(tr.mapping, tr.doc)`로 옮긴 뒤 바뀐 범위만 다시 계산합니다.
  - `setSavedBaseline`에서 기준이 그대로이면(`markdown === this.#saved`이고 `#savedDoc`이 있으면) 아무것도 바꾸지 않고 반환합니다. 기준이 바뀌었으면 `importMarkdown(markdown).doc`을 한 번 만들어 `#savedDoc`으로 둡니다.

### 4.6 `MarkdownWebView.swift`에 JS 450여 줄이 문자열로 들어 있음 — 중간 [코드]

- 위치: [MarkdownWebView.swift:171-214](Sources/Bloct/MarkdownWebView.swift#L171-L214), [394-452](Sources/Bloct/MarkdownWebView.swift#L394-L452), [558-587](Sources/Bloct/MarkdownWebView.swift#L558-L587), [622-1052](Sources/Bloct/MarkdownWebView.swift#L622-L1052)
- 문제: Swift 문자열 안의 JS는 타입 검사·린트·단위 테스트가 안 되고, 정규식마다 `\\s`, `\\n`처럼 이중 이스케이프가 필요합니다. 바로 옆 `Editor/`에 TypeScript 도구가 있는데 호스트 스크립트는 그 밖에 있습니다. [editor-switch.js](Sources/Bloct/editor-switch.js)도 공백 없이 한 줄에 여러 문장을 넣은 형태라 검토하기 어렵습니다.
- 수정 방법: 읽기 렌더러, 목차, 스크롤 기억, 리사이즈 앵커, 편집 전환을 `Editor/src/host/*.ts`로 옮겨 `host.js` 하나로 번들합니다. Swift는 HTML 뼈대와 설정 객체(`generation`, `imageOrigin`, `baseline`, `showTOC`, `savedScrollY`)만 넘깁니다. 문자열 보간으로 값을 넣는 곳([MarkdownWebView.swift:324](Sources/Bloct/MarkdownWebView.swift#L324), [MarkdownWebView.swift:389](Sources/Bloct/MarkdownWebView.swift#L389), [ContentView.swift:621-626](Sources/Bloct/ContentView.swift#L621-L626) 등)은 이미 다른 곳에서 쓰는 `callAsyncJavaScript(arguments:)`로 통일합니다.

### 4.7 종료 처리가 AppKit 관례와 다름 — 낮음 [코드]

- 위치: [BloctApp.swift:117-160](Sources/Bloct/BloctApp.swift#L117-L160)
- 현상: `applicationShouldTerminate`가 미저장 창이 있으면 `.terminateCancel`을 돌려주고, 저장이 끝나면 `handleQuit()`이 `NSApp.terminate`를 다시 부릅니다. 로그아웃·재시동 중이었다면 시스템은 "Bloct가 취소함"으로 처리하고, 이후 앱만 따로 종료됩니다. 상태는 파일 범위 함수 두 개와 `AppDelegate.isQuitting` 정적 변수에 흩어져 있습니다(2.6의 원인).
- 수정 방법: `.terminateLater`를 돌려주고 모든 창의 확인이 끝나면 `NSApp.reply(toApplicationShouldTerminate: true)`, 취소하면 `false`를 보냅니다. 진행 상태는 `@MainActor final class QuitCoordinator`가 소유합니다.

### 4.8 그 밖의 관행 위반과 작은 결함 — 낮음

| 위치 | 내용 | 수정 | 근거 |
|---|---|---|---|
| [MarkdownDocument.swift:5](Sources/Bloct/MarkdownDocument.swift#L5), [project.yml:57-58](project.yml#L57-L58) | Swift는 `conformingTo: .plainText`, plist는 `public.text` | plist를 `public.plain-text`로 맞춤 | 코드 |
| [MarkdownDocument.swift:45-50](Sources/Bloct/MarkdownDocument.swift#L45-L50) | UTF-8이 아닌 파일(CP949 등)은 "손상된 파일" 오류로 열리지 않음 | `.fileReadInapplicableStringEncoding`으로 바꾸고, 가능하면 `NSString.stringEncoding(for:…)`로 감지 후 읽기 전용으로 열기 | 실행 |
| [MarkdownWebView.swift:82-101](Sources/Bloct/MarkdownWebView.swift#L82-L101), [897-902](Sources/Bloct/MarkdownWebView.swift#L897-L902) | ⌘R을 로컬 이벤트 모니터, `performKeyEquivalent`, JS `keydown` 세 곳에서 처리. 모니터가 먼저 소비하므로 나머지 둘은 도달하지 않음 | `Commands`에 "Reload" 메뉴(⌘R)를 추가하고 `FocusedValue`로 연결. 세 처리기 제거 | 코드 |
| [MarkdownWebView.swift:104](Sources/Bloct/MarkdownWebView.swift#L104) | WebKit의 Reload 항목을 제목 문자열 `"Reload"`로 찾음. 현지화되면 일치하지 않음 | `item.identifier?.rawValue == "WKMenuItemIdentifierReload"`로 비교 | 코드 |
| [MarkdownWebView.swift:495-499](Sources/Bloct/MarkdownWebView.swift#L495-L499) | 배포 대상이 14.0이라 `#available(macOS 13.3, *)`는 항상 참. `else`의 비공개 KVC는 죽은 코드 | 분기 제거 | 코드 |
| [MarkdownWebView.swift:262-265](Sources/Bloct/MarkdownWebView.swift#L262-L265) | 스크롤 위치를 `scrollPos:<경로>` 키로 `UserDefaults`에 저장. 지우는 곳이 없어 연 파일 수만큼 계속 늘어남 | 사전 하나에 모으고 최근 N개만 유지 | 코드 |
| [MarkdownWebView.swift:493](Sources/Bloct/MarkdownWebView.swift#L493), [590-592](Sources/Bloct/MarkdownWebView.swift#L590-L592), [BloctApp.swift:20-22](Sources/Bloct/BloctApp.swift#L20-L22) | 핀치는 `magnification`, 메뉴는 `pageZoom`으로 서로 다른 값. ⌘0은 `pageZoom`만 되돌림 | ⌘0에서 `webView.magnification = 1`도 설정하거나 핀치를 끔 | 코드 |
| [BloctApp.swift:75-78](Sources/Bloct/BloctApp.swift#L75-L78) | Close 버튼만 `.disabled(closeDocument == nil)`이 없음. 문서 창이 아닐 때 ⌘W가 아무 일도 안 함 | 다른 명령처럼 `.disabled` 추가 | 코드 |
| [BloctApp.swift:8-11](Sources/Bloct/BloctApp.swift#L8-L11) | 확대 단축키가 `"+"`. 실제 ⌘= 입력은 [IMPLEMENTATION_PLAN.md:33](IMPLEMENTATION_PLAN.md#L33)에도 미검증으로 남아 있음 | `"="`로 등록하거나 둘 다 등록 | 추정 |
| [ContentView.swift:245-257](Sources/Bloct/ContentView.swift#L245-L257) | 창 단위 명령에 `focusedValue` 사용. 포커스가 도구 막대의 검색 필드에 있을 때 Save 등이 비활성화될 수 있음 | `focusedSceneValue`로 변경 | 추정 |
| [ContentView.swift:5-77](Sources/Bloct/ContentView.swift#L5-L77) | `FocusedValueKey` 8개에 같은 형태의 코드 반복 | `extension FocusedValues { @Entry var zoomLevel: Binding<Double>? }` | 코드 |
| [ContentView.swift:108-118](Sources/Bloct/ContentView.swift#L108-L118) | `SearchTextField.Coordinator.parent`를 `updateNSView`에서 갱신하지 않음 | `context.coordinator.parent = self` 추가 | 코드 |
| [ContentView.swift:231](Sources/Bloct/ContentView.swift#L231) | `View.init`에서 `trackSource`가 파일 존재 여부를 확인. `init`은 여러 번 호출됨 | 컨트롤러 생성 시 한 번만 | 코드 |
| [ContentView.swift:492](Sources/Bloct/ContentView.swift#L492), [631](Sources/Bloct/ContentView.swift#L631) | `"net.daringfireball.markdown"` 리터럴 반복 | `UTType.markdown.identifier` | 코드 |
| [ContentView.swift:669](Sources/Bloct/ContentView.swift#L669) | 사본 저장 시 스냅샷 실패를 아무 표시 없이 무시 | 다른 경로처럼 `presentError` | 코드 |
| [ContentView.swift:673](Sources/Bloct/ContentView.swift#L673) | 사본 이름을 항상 `.md`로 만듦 | 원본 확장자 유지 | 코드 |
| [ContentView.swift:675-677](Sources/Bloct/ContentView.swift#L675-L677) | 사본 위치로 원본을 고르면 "파일이 디스크에서 변경됨" 오류가 뜸 | 전용 오류 문구 추가 | 코드 |
| [ContentView.swift:742](Sources/Bloct/ContentView.swift#L742) | PDF 이름만 `fileURL`을 씀. 다른 곳은 `sourceURL` | `sourceURL`로 통일 | 코드 |
| [ContentView.swift:750](Sources/Bloct/ContentView.swift#L750) | `as! NSPrintInfo` 강제 변환 | `NSPrintInfo(dictionary:)`로 새로 만들거나 `guard let` | 코드 |
| [DocumentState.swift:6](Sources/Bloct/DocumentState.swift#L6) | `ObservableObject`가 `Binding`을 저장 | 4.4의 컨트롤러로 옮기며 쓰기 클로저만 주입 | 코드 |
| [BloctApp.swift:170](Sources/Bloct/BloctApp.swift#L170) | 기본 창 높이 1600pt. 대부분의 화면보다 큼 | 900 안팎으로 | 코드 |
| [release.yml:48-50](.github/workflows/release.yml#L48-L50) | `${{ github.ref_name }}`을 셸 명령에 직접 삽입 | `env: TAG: ${{ github.ref_name }}` 후 `"$TAG"` 사용 | 코드 |

형식 면에서는 `final`이 빠진 클래스(`FocusOnAppearTextField`, `WebViewStore`, `CloseHandlerView`, `CloseProxy`, `AppDelegate`, `Coordinator`, `WeakMessageHandler`), `private`이 빠진 `@FocusedValue` 프로퍼티([BloctApp.swift:4](Sources/Bloct/BloctApp.swift#L4) 등 8곳), 500자가 넘는 한 줄([ContentView.swift:243](Sources/Bloct/ContentView.swift#L243)), 줄 끝 세미콜론([MarkdownWebView.swift:460](Sources/Bloct/MarkdownWebView.swift#L460))이 있습니다. `swift-format` 설정을 저장소에 두면 한 번에 정리됩니다.

## 5. 문서와 구현이 맞지 않는 부분

| 문서 | 문서 내용 | 실제 | 조치 |
|---|---|---|---|
| [IMPLEMENTATION_PLAN.md:58](IMPLEMENTATION_PLAN.md#L58) | BOM 보존 | Swift가 BOM을 제거하고 저장은 실패 (2.1) | 수정 전까지 한계로 기록 |
| [README.md:89](README.md#L89) | GFM을 의미 블록으로 파싱 | 취소선 미지원, 빈 줄 경계로 목록·코드 해석이 다름 (3.5, 3.7) | "Markdown dialect" 절 추가 |
| [README.md:90](README.md#L90) | "Fenced code blocks with language labels" | 언어는 속성으로만 보존되고 화면에 표시되지 않음. 구문 강조도 없음 | 문구를 "언어 정보 보존"으로 수정하거나 라벨 구현 |
| [README.md:117](README.md#L117) | 핀치 또는 ⌘+/⌘−로 확대 | 두 방식이 서로 다른 값을 바꾸고 ⌘0은 한쪽만 되돌림 (4.8) | 구현 수정 후 문구 유지 |
| [BUG_FIXES.md:80](BUG_FIXES.md#L80) | 검색 키 동작이 "README 안내와 다릅니다" | [README.md:109](README.md#L109)가 이미 미구현이라고 안내함 | 19번 문구를 "미구현"으로 수정 |
| [IMPLEMENTATION_PLAN.md:32](IMPLEMENTATION_PLAN.md#L32) | Markdown UTType은 `public.text` 상속 | Swift 선언은 `.plainText` (4.8) | 한쪽으로 통일 |
| [THIRD_PARTY.md:32](THIRD_PARTY.md#L32) | marked의 버전·무결성 값이 없음 | 파일 헤더는 v15.0.12. DOMPurify는 버전·해시까지 기록됨 | 같은 형식으로 버전·배포 경로·해시 추가 |
| [schema.ts:58](Editor/src/schema.ts#L58), [session.ts:27](Editor/src/session.ts#L27), [importer.ts:172](Editor/src/importer.ts#L172) | "future WebView adapter", "A future EditorView", "Until the … serializer layer is installed" | 모두 이미 구현됨 | 주석 갱신 |
| [README.md:167-169](README.md#L167-L169) | "커밋·푸시 요청은 버전 올림과 릴리스를 포함한다" | 사용자용 README에 작업자 지침이 들어 있음 | AGENTS.md에만 두고 삭제 |

저장소에 `LICENSE` 파일이 없습니다. 공개 저장소에서 바이너리를 배포하고 MIT·Apache 코드를 포함하므로, 프로젝트 자체의 사용 조건을 README와 `LICENSE`로 밝히는 편이 좋습니다.

문서의 상대 링크는 전부 확인했습니다. 8개 문서의 174개 중 대상이 없는 것은 [README.md:28](README.md#L28)의 `../../releases` 하나이고, 이것은 GitHub 웹에서만 동작하는 경로입니다. 5행처럼 절대 URL로 통일하면 됩니다.

## 6. 일관성

| 영역 | 불일치 | 제안 |
|---|---|---|
| 용어 | 제거된 "Aa" 버튼 이름이 주석 7곳과 파일명에 남음: [ContentView.swift:547](Sources/Bloct/ContentView.swift#L547), [597](Sources/Bloct/ContentView.swift#L597), [686](Sources/Bloct/ContentView.swift#L686), [MarkdownWebView.swift:453](Sources/Bloct/MarkdownWebView.swift#L453), [896](Sources/Bloct/MarkdownWebView.swift#L896), [visual-editor.ts:21](Editor/src/visual-editor.ts#L21), [task-lists.js:165](Sources/Bloct/task-lists.js#L165), `Tests/js/aa-*.js` | "editing"으로 통일 |
| 접두사 | `_mv*`, `mv-*`, `.mv_preview-*`(옛 이름 MarkdownViewer), `_bloct*`, `BloctBlocks`, `visual-*`가 섞임 | 새 코드부터 `bloct` 계열로. 기존 것은 4.6 이전 때 함께 |
| 파일명과 타입 | `WindowCloseProxy.swift` 안의 타입은 `CloseProxy`. `VisualEditorHTML.swift`는 `MarkdownWebView`의 확장 | 타입 이름과 일치시키거나 `MarkdownWebView+VisualEditor.swift` |
| 한 파일 여러 타입 | `ContentView.swift`에 키 8개와 뷰·클래스 6개, `BloctApp.swift`에 명령 8개와 델리게이트, `MarkdownWebView.swift`에 타입 5개와 HTML 템플릿 | 8절의 구조로 분리 |
| 기본값 | `automaticEditing` 기본값은 `false`인데 프로덕션은 항상 `true`. `Coordinator.showTOC` 기본값은 `true`인데 `ContentView`는 `false` | 4.2에서 매개변수 제거. 기본값은 프로덕션 값으로 |
| `</script` 처리 | `blocks.js`·`math.js`만 이스케이프([613](Sources/Bloct/MarkdownWebView.swift#L613), [616](Sources/Bloct/MarkdownWebView.swift#L616)행), marked·purify는 안 함([614-615행](Sources/Bloct/MarkdownWebView.swift#L614-L615)). 현재 두 파일에 해당 문자열은 없음 | 리소스 로더 한곳에서 일괄 처리 |
| 정리 누락 | `dismantle`이 콜백 넷은 비우는데 `onEditingRequested`는 남김([333-336행](Sources/Bloct/MarkdownWebView.swift#L333-L336)) | 함께 비움 |
| 목차 폭 | `220px`이 Swift 문자열 6곳에 반복: [181](Sources/Bloct/MarkdownWebView.swift#L181), [207](Sources/Bloct/MarkdownWebView.swift#L207), [381](Sources/Bloct/MarkdownWebView.swift#L381), [555](Sources/Bloct/MarkdownWebView.swift#L555), [557](Sources/Bloct/MarkdownWebView.swift#L557), [924](Sources/Bloct/MarkdownWebView.swift#L924)행 | CSS 변수 `--toc-width`와 `body.toc-open` 클래스 전환 |
| 검색 강조 | 읽기 렌더러는 현재 일치 항목을 주황색으로 구분([965행](Sources/Bloct/MarkdownWebView.swift#L965)), 편집 엔진은 스크롤만 하고 구분 없음([visual-editor.ts:767-771](Editor/src/visual-editor.ts#L767-L771)). 프로덕션은 후자 | 현재 항목에 별도 장식 클래스 추가 |
| 인코딩 | 디코드는 `TextDecoder`, 인코드는 폐기 예정인 `unescape`([editor-switch.js:8](Sources/Bloct/editor-switch.js#L8)) | `TextEncoder` 사용 |
| 테스트 위치 | 페이지 테스트가 `Tests/*.js`(PascalCase)와 `Tests/js/*.js`(kebab-case)로 나뉨. 편집기 테스트도 `Editor/test/`(TS)와 `Editor/test-dom/`(JS, 타입 검사 제외) | 8절 참고 |
| 모듈 캐시 | `run-native.sh`만 임시 폴더, 나머지는 `/private/tmp/bloct-regression-module-cache` 고정 | 공통 스크립트로 통일 |
| README 형식 | "Features" 아래 제목 10개는 제목 다음 빈 줄이 없고([81](README.md#L81)~[132](README.md#L132)행), "Continuous block editing"([49행](README.md#L49))은 있음. 68~70행만 줄바꿈 폭이 다름 | 제목 앞뒤에 빈 줄. 줄바꿈 폭 통일 |
| 앵커 방식 | BUG_FIXES.md의 45·46번은 `<a id="bug-45">` HTML 앵커, 26·29번은 제목 자동 slug | 한 가지로 통일. Bloct 자체는 HTML 앵커를 보호 원문으로 표시함 |
| 지침 중복 | CLAUDE.md가 "AGENTS.md를 따른다"고 한 뒤 완료 기준·기록 정책을 다시 서술 | CLAUDE.md는 빌드 명령과 AGENTS.md 참조만 남김 |

IMPLEMENTATION_PLAN.md는 400자가 넘는 줄이 26개이고 가장 긴 표 셀이 1,407자입니다([98행](IMPLEMENTATION_PLAN.md#L98)). Markdown 표는 셀이 짧을 때 읽히는 형식이므로, 검증 근거는 "범위별 소제목 + 링크 목록"으로 푸는 편이 원문과 렌더 결과 모두에서 읽기 쉽습니다.

## 7. 빌드·테스트·CI

### 7.1 릴리스가 테스트 없이 배포됨 — 중간 [코드]

- 위치: [release.yml:31-50](.github/workflows/release.yml#L31-L50), [build-editor.sh:9](scripts/build-editor.sh#L9), [package.json:5-9](Editor/package.json#L5-L9)
- 현상: 워크플로는 `npm ci` → 릴리스 빌드 → ZIP 검증 → 게시 순서이고 테스트 단계가 없습니다. 빌드 스크립트는 `npm run build`만 실행하는데 esbuild는 타입을 검사하지 않으므로, 타입 오류가 있어도 릴리스가 만들어집니다. 풀 리퀘스트나 push에서 도는 워크플로도 없습니다.
- 수정 방법: 릴리스 빌드 앞에 `npm run check --prefix Editor`, `npm test --prefix Editor`, `sh Tests/run-native.sh`, `sh Tests/run-window-close.sh`를 넣습니다. WebKit을 띄우는 러너는 실행 환경 권한을 확인한 뒤 추가합니다. push·PR용 `ci.yml`을 따로 둡니다. `package.json`에 `"engines": {"node": ">=22.18"}`을 적습니다.

### 7.2 테스트가 프로덕션 소스를 문자열 치환으로 바꿔 컴파일함 — 중간 [코드]

- 위치: [run-visual-native.sh:15-26](Tests/run-visual-native.sh#L15-L26), [run-menu-polling.sh:15-25](Tests/run-menu-polling.sh#L15-L25)
- 현상: `ContentView.swift`를 읽어 `s.replace('@State private var visualEditing = false', …)`, `s.replace('showCloseWarning = true', …)` 같은 치환을 한 뒤 컴파일합니다. `assert s.count(needle)==1`이 있는 것은 `body` 치환 하나뿐입니다. 소스의 해당 줄이 조금만 바뀌어도 나머지 치환은 조용히 건너뛰고, 테스트는 의도와 다른 코드를 검사합니다.
- 수정 방법: 당장은 모든 치환에 개수 단언을 추가합니다. 근본적으로는 4.4의 컨트롤러에 오류 표시·경고 표시·디스크 쓰기를 프로토콜로 주입하게 하고, `project.yml`에 테스트 타깃을 추가해 `@testable import Bloct`로 검사합니다.

### 7.3 그 밖

| 위치 | 내용 | 수정 | 근거 |
|---|---|---|---|
| [run-menu-polling.sh:8-9](Tests/run-menu-polling.sh#L8-L9) | 다른 러너와 달리 `blocks.js`·`visual.css`를 복사하지 않음. 이 상태면 페이지의 편집 엔진 설치가 실패함. 마지막 로그는 2026-10-26(F5 이전) | 리소스 목록을 맞추고 다시 실행 | 코드 |
| `Tests/run-*.sh` 5개 | 앱 폴더 생성·리소스 복사·`@main` 제거·소스 수집이 그대로 반복됨 | `Tests/lib/harness.sh`로 추출 | 코드 |
| [project.yml:33-35](project.yml#L33-L35) | `CODE_SIGN_IDENTITY: "-"`인데 `CODE_SIGNING_ALLOWED: "NO"`. 번들이 서명되지 않음 | ad-hoc 서명을 켜거나(`CODE_SIGNING_ALLOWED: YES`) 빌드 후 `codesign --force --deep -s -` | 코드 |
| [project.yml:4-5](project.yml#L4-L5), [22](project.yml#L22), [build-release.sh:18](scripts/build-release.sh#L18) | 최소 OS를 세 곳에서 지정 | `options.deploymentTarget` 한 곳만 | 코드 |
| [project.yml:45-47](project.yml#L45-L47) | `LSItemContentTypes`가 있으면 무시되는 `CFBundleTypeExtensions`를 함께 선언 | 제거 | 코드 |
| [project.yml:44-53](project.yml#L44-L53) | Markdown과 일반 텍스트를 "Markdown Document" 한 항목으로 묶음 | 문서 타입을 둘로 분리 | 코드 |
| [project.yml:42-43](project.yml#L42-L43), `Info.plist`, [README.md:5](README.md#L5) | 버전이 세 파일에 적힘. `Info.plist`는 생성물인데 커밋됨 | 버전은 `MARKETING_VERSION` 설정 하나로 두고 plist는 `$(MARKETING_VERSION)` 참조. README의 버전 문구는 삭제 | 코드 |
| `scripts/*.sh`, `Tests/run-*.sh` | shebang이 있는데 실행 권한이 없음(644) | `chmod +x` 또는 shebang 제거 중 하나로 통일 | 코드 |

## 8. 프로젝트 구조 개선안

### 8.1 현재 구조의 문제

- `Sources/Bloct/`에 Swift 10개, 직접 쓴 JS 2개, 외부 라이브러리 2개, CSS, 라이선스, plist, 에셋이 한 폴더에 있습니다.
- Swift 소스의 79%가 두 파일에 있습니다(`MarkdownWebView.swift` 1,057줄, `ContentView.swift` 769줄 / 전체 2,307줄).
- 웹 코드가 세 곳에 나뉩니다. `Editor/src/`(TypeScript, 검사됨), `Sources/Bloct/*.js`(검사 안 됨), Swift 문자열 속 JS(검사 불가).
- 추적 파일 466개 중 375개가 `Tests/results/`의 로그·스크린샷입니다(9.8MB).
- 루트에 스크린샷 2장(약 1MB), 무시되는 잔여 파일(`.mv_preview.html`, `._PIPELINES.md`, `._README.md`, `._TODO.md`)이 있습니다.

### 8.2 제안 구조

```
bloct/
├── Sources/Bloct/
│   ├── App/
│   │   ├── BloctApp.swift            # @main, Scene
│   │   ├── AppDelegate.swift
│   │   ├── QuitCoordinator.swift     # 4.7
│   │   ├── DocumentCommands.swift    # Commands 8개
│   │   └── FocusedValues+Bloct.swift # @Entry 선언
│   ├── Document/
│   │   ├── MarkdownDocument.swift
│   │   ├── DocumentWriteProtection.swift
│   │   ├── DocumentDisk.swift
│   │   ├── DocumentState.swift
│   │   ├── DocumentSaveOperation.swift
│   │   └── StagedDocumentSave.swift
│   ├── Window/
│   │   ├── ContentView.swift         # 화면 상태와 레이아웃만
│   │   ├── DocumentController.swift  # 4.4
│   │   ├── CloseProxy.swift
│   │   ├── WindowCloseHandler.swift
│   │   └── SearchTextField.swift
│   ├── WebView/
│   │   ├── MarkdownWebView.swift     # NSViewRepresentable
│   │   ├── MarkdownWebView+Coordinator.swift
│   │   ├── DocumentWebView.swift
│   │   ├── LocalImageLoader.swift
│   │   ├── PageTemplate.swift        # HTML 뼈대와 CSP
│   │   ├── BundledResource.swift     # 캐시된 리소스 로더
│   │   └── PreviewFiles.swift        # 4.2.1 결정에 따라 유지 또는 삭제
│   └── Resources/
│       ├── Assets.xcassets
│       ├── Info.plist
│       ├── Web/style.css
│       └── Vendor/                   # marked.min.js, purify.min.js, 라이선스
├── Editor/
│   ├── src/
│   │   ├── model/                    # schema, importer, serializer, session, id, math-syntax
│   │   ├── view/                     # visual-editor를 input-rules, keymap, table, node-views로 분할
│   │   ├── host/                     # editor-switch, reader, toc, search, scroll (4.6)
│   │   └── styles/visual.css
│   └── test/                         # unit/, dom/
├── Tests/
│   ├── Native/                       # *.swift 하네스
│   ├── Page/                         # WKWebView에서 도는 *.js
│   ├── GUI/                          # gui-session.mjs
│   ├── fixtures/
│   ├── lib/harness.sh
│   └── run-*.sh
├── docs/images/                      # Bloct_1.png, Bloct_2.png
├── scripts/
└── README.md, AGENTS.md, CLAUDE.md, BUG_FIXES.md, IMPLEMENTATION_PLAN.md, THIRD_PARTY.md
```

루트의 지침·기록 문서는 서로 링크가 많고 작업 지침이 경로를 참조하므로 옮기지 않습니다.

### 8.3 옮길 때 함께 고쳐야 하는 곳

| 변경 | 영향받는 곳 |
|---|---|
| Swift 파일을 하위 폴더로 | `Tests/run-*.sh`의 `for source in Sources/Bloct/*.swift`(5개 스크립트)와 [run-native.sh:7-8](Tests/run-native.sh#L7-L8), [run-window-close.sh:7](Tests/run-window-close.sh#L7), [run-preview-termination.sh:7](Tests/run-preview-termination.sh#L7)의 개별 경로. `find Sources/Bloct -name '*.swift'`로 바꿈 |
| `ContentView.swift` 분할 | 7.2의 문자열 치환이 찾는 줄이 다른 파일로 이동함. 치환 대상 파일을 바꾸거나 주입 방식으로 전환 |
| `style.css` 이동 | [build-resources.mjs:18](Editor/build-resources.mjs#L18)의 `../Sources/Bloct/style.css`, 각 러너의 `cp` 줄 |
| JS를 `Editor/src/host/`로 | [build-editor.sh:12](scripts/build-editor.sh#L12)의 복사 목록, [VisualEditorHTML.swift:15](Sources/Bloct/VisualEditorHTML.swift#L15), 각 러너의 `cp Sources/Bloct/editor-switch.js …` |
| `Info.plist` 이동 | [project.yml:38](project.yml#L38) |
| 스크린샷 이동 | [README.md:8-9](README.md#L8-L9) |

`project.yml`은 `sources: - path: Sources/Bloct`가 하위 폴더를 재귀로 포함하므로 폴더 분리만으로는 바꿀 것이 없습니다.

### 8.4 권장 순서

1. **동작을 바꾸지 않는 정리.** 파일 분리(8.2의 Swift 부분), 죽은 코드 제거(4.2 표), 주석·용어 정리(6절). 각 단계 뒤 기존 러너로 확인합니다.
2. **직렬화기.** 4.1의 교체 또는 2.2·2.3·3.1·3.2의 개별 수정. 사용자가 저장하는 파일의 품질에 직접 영향을 주므로 구조 작업보다 먼저 해도 됩니다.
3. **저장 경로.** 2.1(BOM), 2.4(확장 속성). 변경 범위가 `DocumentDisk` 안에 머뭅니다.
4. **컨트롤러 추출.** 4.4. 이후 7.2의 테스트 주입, 4.3의 파일 감시, 4.7의 종료 조정이 이 위에 올라갑니다.
5. **호스트 스크립트 이전.** 4.6. `automaticEditing` 제거(4.2)와 함께 진행합니다.
6. **CI.** 7.1은 독립적이므로 언제든 추가할 수 있습니다.

### 8.5 `Tests/results/`에 대하여

기록 정책([AGENTS.md:10](AGENTS.md#L10))이 원시 로그 링크를 요구하므로 삭제를 권하지는 않습니다. 다만 저장소의 80%가 로그인 상태는 검색·리뷰·clone을 느리게 합니다. 정책을 유지하면서 줄이는 방법은 두 가지입니다.

- 릴리스마다 그 시점까지의 `Tests/results/`를 묶어 GitHub Release 자산으로 올리고, 본 저장소에는 최근 한두 릴리스 분량만 남깁니다. 문서의 옛 링크는 해당 태그의 영구 링크로 바꿉니다.
- 로그 전문 대신 요약 JSON만 커밋하고 전문은 Release 자산으로 둡니다.

결과 폴더에 실행 스크립트(`.m` 2개, `.py` 1개, `.rb` 3개)가 섞여 있는 점, 날짜가 붙은 보고서([Tests/GUI_ACCEPTANCE_2026-10-15.md](https://github.com/JAEHYEON-BAE/bloct/blob/v2.0.1/Tests/GUI_ACCEPTANCE_2026-10-15.md))가 "별도 보고 Markdown을 만들지 않는다"는 정책([AGENTS.md:8](AGENTS.md#L8))과 어긋나는 점도 함께 정리 대상입니다.

## 부록: 재현 방법

### 편집 모델 (2.2, 2.3, 3.1~3.6)

`Editor/`에서 `npm ci`를 마친 상태에서 아래 파일을 아무 곳에나 만들고 `node 파일명.ts`로 실행합니다(Node 22.18 이상).

```ts
import {BlockSession} from '/절대경로/bloct/Editor/src/session.ts';

// 첫 텍스트 블록 끝에 글자를 덧붙인 뒤 저장 결과를 출력
function edit(md: string) {
  const s = new BlockSession(md, md, true);
  let end = -1;
  s.doc.descendants((n, p) => { if (end < 0 && n.isTextblock) end = p + 1 + n.content.size; });
  s.dispatch(s.state.tr.insertText('Z', end));
  try { console.log(JSON.stringify(s.markdown())); }
  catch (e) { console.log('THROW:', (e as Error).message); }
}
// 빈 문서에 글자를 그대로 입력
function type(text: string) {
  const s = new BlockSession('', '', true);
  s.dispatch(s.state.tr.insertText(text, 1));
  try { console.log(JSON.stringify(s.markdown())); }
  catch (e) { console.log('THROW:', (e as Error).message); }
}

type('visit https://example.com now');          // 2.2
type('use &nbsp; or &amp; here');               // 2.2
edit('**bold *both* bold** tail\n');            // 2.3
edit('e.g. version 1.0 (beta) - a+b! #tag\n');  // 3.1
edit('This is **bold** and *italic* text.\n');  // 3.2
edit('keep ~~old~~ text\n');                    // 3.5
```

### 파일 입출력 (2.1, 2.4)

`Sources/Bloct/DocumentDisk.swift`와 아래 `main.swift`를 함께 컴파일합니다.

```sh
xcrun swiftc -swift-version 6 -parse-as-library Sources/Bloct/DocumentDisk.swift main.swift -o /tmp/bom-test
```

```swift
import Foundation
@main struct M { static func main() throws {
    let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("bom.md")
    try Data([0xEF, 0xBB, 0xBF] + Array("# Title\n".utf8)).write(to: url)
    let original = try DocumentDisk.read(url)
    do { try DocumentDisk.save(original + "edit\n", to: url, replacing: original); print("OK") }
    catch { print("실패:", error.localizedDescription) }   // 2.1: 항상 실패
}}
```

2.4는 임시 파일에 `setxattr`로 속성을 붙이고 `Data.write(to:options: .atomic)` 전후로 `getxattr`와 `lstat`을 비교해 확인했습니다. 같은 조건에서 `FileManager.replaceItemAt`은 속성을 유지했습니다.
