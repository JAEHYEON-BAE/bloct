# Bloct 작업 지침

macOS 14+용 SwiftUI·WKWebView Markdown 앱. Swift 소스와 웹 리소스는 `Sources/Bloct/`, 프로젝트 설정은 `project.yml`에 있다. 공통 작업 지침은 [AGENTS.md](AGENTS.md)를 따른다.

## 문서 관리

- 시작할 때 [BUG_FIXES.md](BUG_FIXES.md)와 [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md)의 관련 항목을 확인한다.
- 오류·버그의 재현·조사·수정·검증은 `BUG_FIXES.md`, 최근 구현·새 기능 요구사항·향후 계획은 `IMPLEMENTATION_PLAN.md`에 기록한다. 변경이 있으면 같은 작업에서 갱신한다.
- 기존 번호를 유지하고 날짜·상태·검증 결과·남은 범위를 적는다. 별도 진행 보고 문서를 만들지 않으며, 코드 변경과 무관한 GUI 조작 실험은 기록하지 않는다.

## 빌드·테스트

Xcode 27.0·XcodeGen을 사용한다. 개발용 빌드:

```sh
xcodegen generate
xcodebuild -project Bloct.xcodeproj -scheme Bloct -configuration Debug -derivedDataPath build build
```

코드 변경에 맞는 회귀 검사를 실행한다. 검사 범위와 한계는 [Tests/README.md](Tests/README.md)를 따른다.

```sh
sh Tests/run-native.sh
sh Tests/run-webkit.sh
sh Tests/run-hosted.sh
```

- 저장·편집·창 동작 변경은 임시 문서로 실제 GUI의 편집·저장·재열기·폐기·다중 창과 스크린샷을 확인한다. 대상 앱을 지정한 백그라운드 조작을 우선하고, 사용자 입력에 간섭하면 줄이거나 중단한다.
- 구현만으로 완료 처리하지 않는다. XFAIL·SKIP·GUI 미검증을 명시하고 전체 통과로 표현하지 않는다. 문서만 수정할 때는 앱 빌드·실행을 생략한다.
- 릴리스는 `sh scripts/build-release.sh`를 사용한다. SDK 27.0·최소 macOS 14·Universal 검증 등 배포 절차는 [README.md](README.md)를 따른다.

## 변경 원칙

- 사용자와 다른 작업의 미커밋 변경을 보존한다. 커밋·푸시·배포 및 `/Applications/Bloct.app` 교체는 명시적 요청이 있을 때만 수행한다.
- 버그 수정·기능 구현 후 커밋·푸시 요청은 새 버전 반영·태그 푸시·릴리스 및 배포 결과 확인까지 포함한다. [AGENTS.md](AGENTS.md)의 릴리스 규칙에 따라 추가 확인 없이 진행한다. 설치 앱 교체는 별도 요청이 필요하다.
- 편집 버퍼·Undo·명시적 Save 경계, HTML 정화·CSP·브리지 검증, 문서별 미리보기 파일 소유권을 유지한다.
- 최종 응답에 변경 요약, 실행한 검사와 미검증 범위, 갱신한 문서 링크를 짧게 알린다.
