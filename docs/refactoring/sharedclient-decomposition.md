# SharedClient God Object 해체 리팩터링 로드맵

## Context (배경)

`SharedClient`(`reazure/fediverse/SharedClient.swift` + `SharedClient+StatusModelActionPerformer.swift`)는
하나의 싱글턴에 **9개의 서로 다른 책임**을 집중시킨 God object다. 어느 한 축을 건드리면 다른 축이
깨질 위험이 있고, `private init` 싱글턴이라 어떤 부분도 격리 단위 테스트가 불가능하다. 게다가
스트리밍 재접속 로직(`didStateChange`)에는 실제 동작 결함(중복 소켓, off-main 데이터 레이스,
계정 전환 시 zombie client)이 내포되어 있다.

**목표**: `SharedClient`를 **"파사드 스토어 + 컴포지션 루트"**로 남기고, *행위(behavior)* 책임들을
협력 객체로 하나씩 추출한다. 뷰가 구독하는 reactive `@Published` 표면(`account`, `configuration`,
`streamingState`, `timeline`, `postAreaFocused`, `currentTab`, `unreadNotificationCount`, `replyTo`)은
파사드에 그대로 유지하고, 추출된 협력 객체는 main-thread setter/콜백으로 상태를 파사드에 되돌린다
(passthrough). 이로써 **뷰 표면 변경을 4곳으로 국한**하면서 결합도를 낮추고 테스트 가능성을 확보한다.

이 로드맵은 서로 독립적인 두 개의 분석 렌즈(**책임 추출** 관점과 **테스트 가능성** 관점)가 거의 동일한
단계 순서로 수렴한 결과를 종합한 것이다. 각 스텝은 **독립적으로 빌드/커밋 가능**하며, 저위험 → 고위험
순으로 배열했다.

> 이번 세션의 산출물은 **이 로드맵 문서 자체**다. 구현은 이후 세션에서 스텝 단위로 진행한다.

---

## 준수 제약 (위반 제안 금지)

- **streaming-only** — 영속성 계층(SQLite/CoreData/SwiftData) 도입 금지.
- **Combine `ObservableObject` 유지** — `@Observable` / actor-isolation 마이그레이션 금지.
- **`DispatchQueue.main.async` 관례 유지** — `@MainActor` 전면 전환 금지.
- **adaptor 패턴 보존** — `StatusAdaptor` 등 프로토콜 경계 유지.
- **`MaskedStatusAdaptor` 마스킹 흐름 보존** — "API 호출 후 masked copy 교체" 낙관적 UI 흐름 유지.
- **린터(SwiftLint/SwiftFormat) 미도입.**
- **순수 구조 리팩터** — 신규 기능 추가 아님. 커밋/코멘트/문서 톤은 사무적으로.

---

## 현황: `SharedClient`가 지는 9개 책임

| # | 책임 | 근거 위치 |
|---|------|-----------|
| 1 | 전역 싱글턴 상태 컨테이너 | `SharedClient.swift:29,31-77` |
| 2 | 계정 수명주기 / 의존성 배선 (`didAccountChanged`) | `SharedClient.swift:31-36,107-139` |
| 3 | 타임라인 팩토리 (`constructTimelineModel`) | `SharedClient.swift:83-105` |
| 4 | `StreamingClientDelegate` — payload 디코딩 & prepend | `SharedClient.swift:142-205` |
| 5 | 알림 부수효과 (사운드/햅틱/unread) | `SharedClient.swift:181-197,53-64` |
| 6 | 스트리밍 재접속 컨트롤러 (`didStateChange`) | `SharedClient.swift:207-229` |
| 7 | `StatusModelActionPerformer` 실행자 | `SharedClient+StatusModelActionPerformer.swift:8-42` |
| 8 | 키보드 단축키 라우터 (`handleShortcut`) | `SharedClient.swift:232-241` |
| 9 | 현재 탭 / 현재 타임라인 선택 | `SharedClient.swift:54-75` |

**최종 목표 상태**: `SharedClient` = ①(파사드 read 표면) + ②/③(컴포지션 루트: 협력 객체 소유·배선)만
남기고, ④~⑦은 전용 협력 객체로 이전. ⑧은 프로토콜 seam으로 분리, ⑨는 파사드에 잔류.

---

## 리팩터 중 함께 수정할 실제 결함

- **스트리밍 재접속 4대 결함** (`SharedClient.swift:207-229`, `StreamingClient.swift:70,92,95`)
  1. 백오프/시도상한/단일화(single-flight) 가드 없음
  2. `state` `didSet`이 `.disconnected` 재대입마다 재진입 → 중첩 타이머가 소켓을 여러 개 오픈
  3. `DispatchQueue.global()`에서 `@Published configuration/timeline`을 off-main으로 읽음 → 데이터 레이스
  4. 계정 전환 teardown(`110-114`) 후에도 예약된 재접속 클로저가 옛 `client`를 잡아 **zombie 접속** 생성
- **마스크 순환참조 누수** (`adaptors.swift:114,196`) — `MaskedStatusAdaptor.reblog`가 강참조하는
  `ReblogMaskedStatusAdaptor._parent`가 다시 부모를 강참조 → 부스트에 대한 낙관적 액션마다 마스크 쌍 누수.
- **`deleteStatus` 디코딩 버그** (`MastodonAPI.swift:213`) — 응답을 `expects: String.self`로 디코딩해
  HTTP 성공에도 throw. 삭제가 항상 실패한 것처럼 보임 (인라인 `FIXME` 존재).
- **`AppRootView` 네트워크 leak** (`AppRootView.swift:36-45`) — 컴포저가 `sharedClient.client?.postStatus`를
  직접 호출하고 에러를 `print`로 삼킴 → reblog/favourite/reply가 지나는 performer seam을 우회.

---

## 로드맵 (4 Phase · 각 스텝 독립 빌드/커밋)

각 스텝은 `title / 왜 / 대상 파일 / 작업 / 위험도·난이도 / 뷰 표면 변경 / 커밋 단위 / 선행`을 명시한다.
위험도(risk)와 난이도(difficulty)는 `low/medium/high`, `small/medium/large` 기준.

### Phase 1 — 안전망 (저위험 · 복귀 워밍업)

리팩터 이전에 회귀 가드를 먼저 심는다. 기존에 이미 열려 있는 seam만 쓰므로 프로덕션 변경이 거의 없다.

#### 1.1 테스트 스캐폴딩 시드 (프로덕션 변경 0) — `low/small`
- **왜**: 테스트 타깃이 빈 `example()` 하나뿐(`reazureTests/reazureTests.swift:12`)이라 이후 모든
  추출이 무방비다. 두 개의 기존 seam으로 프로덕션 변경 없이 시작한다:
  (a) `StatusAdaptor`는 순수 프로토콜(`adaptors.swift:71-99`) → `FakeStatusAdaptor`로
  `mask()` 병합·`canonical` 부스트 해석·`MaskedStatusAdaptor` 플래그 오버라이드 검증 가능,
  (b) `StatusModel(adaptor:performer:)`가 performer를 주입받으므로(`StatusModel.swift:26`)
  `FakePerformer`로 낙관적 마스킹 불변식(`StatusModelBase.swift:71-101`) 고정 가능.
- **작업**: `reazureTests`에 `FakeStatusAdaptor` / `FakePerformer` 헬퍼 추가.
  마스킹 불변식(`toggleFavourite`/`toggleReblog`/`delete`가 performer 호출 후 올바른 mask로 교체) 테스트.
  focus 전이(`focusNext`/`focusPrevious`/`expandFocused`/`collapseFocused`, `TimelineModel+shortcuts.swift:66-156`) 테스트.
- **주의**: `performer`는 `weak`(`StatusModel.swift:12`)라 테스트가 fake를 강하게 붙잡아야 함.
  `withReplacingOperation`이 `DispatchQueue.main.async`로 교체하므로(`StatusModelBase.swift:66`)
  단언 전 메인큐 flush 필요.
- **대상 파일**: `reazureTests/reazureTests.swift`
- **뷰 표면 변경**: 없음. **커밋 단위**: `test: 마스킹/포커스 불변식 회귀 테스트 추가`

#### 1.2 마스크 순환참조 수정 + 부스트 마스킹 테스트 — `low/small`
- **왜**: `ReblogMaskedStatusAdaptor._parent`가 `MaskedStatusAdaptor`를 강참조(`adaptors.swift:114`)하고
  부모가 `reblog`로 자식을 강참조(`:196`)하여 순환. 부모가 자식을 소유하므로 `_parent`를 `unowned`로 바꾸면
  안전하게 해소된다. 1.1의 fake 하네스가 있으므로 부스트 마스킹 동작(`adaptors.swift:120-129`,
  "난 너무 게을러" FIXME `:112`)을 테스트로 고정한 뒤 수정한다.
- **작업**: `_parent`를 `unowned`로 변경. 부스트된 상태 마스킹 시 내부 행이 외부 플래그를 반영하는지 테스트.
- **대상 파일**: `reazure/fediverse/models/adaptors.swift`, `reazureTests/reazureTests.swift`
- **뷰 표면 변경**: 없음. **커밋 단위**: `fix: 부스트 마스킹 순환 참조 해소`. **선행**: 1.1

> **곁다리 quick win (독립 트랙, 언제든 가능)**: `deleteStatus`의 `expects: String.self`를 올바른 디코딩으로
> 교정(`MastodonAPI.swift:213`), `print` 디버그 잔재 정리(13곳). 해체 로드맵과 독립이므로 순서에 얽매이지 않음.
> `deleteStatus`의 "정식" 수정은 Phase 4의 `RequestPerforming` seam과 함께 테스트 하에 진행 가능.

### Phase 2 — 저위험 책임 추출 (SharedClient 경량화)

행위 책임을 협력 객체로 떼어낸다. 각 스텝 후 `SharedClient`가 눈에 띄게 가벼워진다.
위험한 스트리밍 로직은 건드리지 않는다.

#### 2.1 `StatusActionPerformer`를 독립 타입으로 추출 — `low/medium`
- **왜**: 모든 `StatusModel`/`NotificationModel`이 `performer: self`(=싱글턴)로 생성되어
  (`SharedClient.swift:89,97,157,175`) 모델 그래프의 모든 쓰기 경로가 God object로 되돌아온다.
  `StatusModelActionPerformer` 프로토콜(`StatusModelBase.swift:10-21`)은 이미 진짜 seam이다.
- **작업**: `SharedClient+StatusModelActionPerformer` 확장을 `MastodonClient?`와 공유 `replyTo` 참조를 보유한
  구체 타입 `MastodonActionPerformer`로 이동. `SharedClient`가 인스턴스 하나를 소유해 모델 생성부에 주입.
- **핵심 제약**: `replyTo` subject는 `PostArea`가 `sharedClient.replyTo`로 구독하므로(`PostArea.swift:167`)
  **`SharedClient` 소유로 유지**하고 performer엔 주입만. 마스킹 흐름은 모델 쪽이라 보존됨.
- **대상 파일**: `reazure/fediverse/MastodonActionPerformer.swift`(신규), `SharedClient.swift`,
  `SharedClient+StatusModelActionPerformer.swift`
- **뷰 표면 변경**: 없음. **커밋 단위**: `refactor: 상태 액션 실행자를 MastodonActionPerformer로 분리`. **선행**: 1.1

#### 2.2 compose-post 액션 추가 → `AppRootView` 네트워크 leak 제거 — `low/small`
- **왜**: `AppRootView.postArea`가 `sharedClient.client?.postStatus(...)`를 직접 호출(`AppRootView.swift:40`)해
  performer seam을 우회하고 에러를 `print`로 삼킴. 이걸 없애면 **어떤 뷰도 `sharedClient.client`를 직접
  참조하지 않게** 되어 네트워크 소유권이 계층으로 복귀한다.
- **작업**: performer(또는 파사드)에 `func post(_ request: PostRequest) async throws` 추가.
  `AppRootView.postArea` 클로저가 이를 호출. `PostRequest`는 이미 `PostArea.swift:12`에 정의됨.
- **대상 파일**: `reazure/views/AppRootView.swift`, `MastodonActionPerformer.swift`, `views/core/PostArea.swift`
- **뷰 표면 변경**: `AppRootView.postArea` 클로저 본문만 (시그니처 유지).
  **커밋 단위**: `refactor: 게시 액션을 performer 경유로 통일`. **선행**: 2.1

#### 2.3 `ShortcutHandler`에 라우터 주입 — `low/small`
- **왜**: `ShortcutHandlerInternal`이 다른 모든 뷰와 달리 `SharedClient.shared`를 computed로 하드참조
  (`ShortcutHandler.swift:12-14`)해 DI를 우회하고 단축키 경로를 테스트 불가로 만든다.
- **작업**: 좁은 `ShortcutRouting` 프로토콜(`func handleShortcut(key:)`)을 `SharedClient`가 채택.
  `UIViewControllerRepresentable`인 `ShortcutHandler`를 통해 인스턴스를 `ShortcutHandlerInternal`에 전달.
  **UIKit `UIKeyCommand` 경로는 그대로 유지**(최근 iPad 단축키 수정으로 선호되는 경로). `ExtKeypad`도 동일 seam으로 통일.
- **대상 파일**: `reazure/views/core/ShortcutHandler.swift`, `views/AppRootView.swift`
- **뷰 표면 변경**: `AppRootView`가 `ShortcutHandler(router: sharedClient)`로 생성(`AppRootView.swift:91`).
  **커밋 단위**: `refactor: 단축키 핸들러에 라우터 주입`

#### 2.4 `TimelineModel` ↔ hub 사이클 절단 — `low/medium`
- **왜**: `TimelineModel`이 `strong var sharedClient`를 보유(`TimelineModel.swift:28`)하는데 유일한 용도가
  `sharedClient.postAreaFocused.toggle()`(`TimelineModel+shortcuts.swift:60`)이다. 그런데 이 `.u` 분기는
  `SharedClient.handleShortcut`가 위임 전에 가로채므로(`SharedClient.swift:235-236`) **이미 도달 불가능한
  죽은 코드**다. `SharedClient`는 `timeline` dict로 모델을 강소유하므로(`:48,100-103`) 불멸 싱글턴 덕에만
  유지되는 양방향 사이클이다.
- **작업**: `init(with sharedClient:)`를 좁은 `focusPostArea: () -> Void` 주입(또는 단일 메서드 프로토콜)으로 대체.
  `TimelineModel`의 `.u` 죽은 코드 정리. `fetchFunction`은 이미 주입형(`TimelineModel.swift:36`).
- **대상 파일**: `reazure/fediverse/models/TimelineModel.swift`, `TimelineModel+shortcuts.swift`, `SharedClient.swift`
- **뷰 표면 변경**: 없음 (`TimelineView`는 모델 자체를 받고 타입 불변).
  **커밋 단위**: `refactor: TimelineModel의 SharedClient 역참조 제거`. **선행**: 1.1
- **보너스**: 포커스/depth 전이 산술을 순수 함수(`FocusReducer.next(rows:current:)` 등)로 추출하면
  off-by-one·경계 케이스를 테이블 기반으로 테스트 가능. `update()`의 병합(insert-at-0 후 id 내림차순 정렬,
  `TimelineModel.swift:59-65`)도 순수 `merge(existing:incoming:)`로 추출 가능. (선택)

#### 2.5 `NotificationPresenter` 추출 — `low/medium`
- **왜**: 스트리밍 델리게이트가 `didReceive` 안에서 `PreferencesManager.shared`/`NotificationSound`/
  `HapticManager.shared` 세 구체 싱글턴에 직접 손을 뻗어(`SharedClient.swift:181-197`) 스트리밍 디코드가
  오디오/햅틱/설정 없이는 테스트 불가하다.
- **작업**: 부수효과와 unread 누적(`:53-64`)을 `NotificationPresenter`로 이동. `unreadNotificationCount`는
  `Navbar`가 읽으므로(`Navbar.swift:45-46`) **파사드 `@Published`로 유지**하고 presenter가 setter로 갱신
  (탭 진입 시 리셋 규칙도 파사드 유지). 이상적으로는 unread를 "notifications 타임라인 vs lastViewedId"의
  파생값으로 만들면 backfill/reconnect 드리프트 제거 (선택).
- **대상 파일**: `reazure/fediverse/NotificationPresenter.swift`(신규), `SharedClient.swift`, `views/core/Navbar.swift`
- **뷰 표면 변경**: 없음. **커밋 단위**: `refactor: 알림 부수효과를 NotificationPresenter로 분리`. **선행**: 1.1

### Phase 3 — 스트리밍 수술 (고위험 하이라이트)

God object에서 **가장 위험한 로직**을 빼내면서 실제 재접속 결함을 제거한다.

#### 3.1 `StreamingClient`에 WebSocket 팩토리 주입 + `delegate` weak — `medium/medium`
- **왜**: `StreamingClient`가 `start()`에서 구체 `WebSocket`을 직접 인스턴스화(`StreamingClient.swift:46`)해
  유일한 주입점을 막는다. `delegate`도 강참조(`:33`)라 `SharedClient`와의 사이클이 수동 teardown으로만 끊긴다.
- **작업**: `WebSocketProviding` 팩토리를 이니셜라이저로 받고 `start()`가 팩토리에 요청. `delegate`를 `weak`로.
  이러면 합성 `WebSocketEvent`를 `didReceive`(`StreamingClient.swift:66-99`)에 주입해 상태 전이/텍스트 디코딩을
  네트워크 없이 테스트 가능. 델리게이트에 `didFail(reason:)` 채널 추가(FIXME `StreamingClient.swift:20`)로
  인증 거부 종료와 일시 단절을 구분.
- **대상 파일**: `reazure/fediverse/mastodon/StreamingClient.swift`, `SharedClient.swift`
- **뷰 표면 변경**: 없음. **커밋 단위**: `refactor: StreamingClient에 WebSocket 팩토리 주입`. **선행**: 1.1

#### 3.2 `StreamingCoordinator` 추출 + 재접속 4대 결함 수정 — `high/large`
- **왜**: 스트리밍 상태기계는 `StreamingClient`에, 재접속 정책은 `SharedClient.didStateChange`
  (`:207-229`)에 있어 소유가 둘로 쪼개져 있고 위 "실제 결함" 4개가 모두 여기 있다.
- **작업**: `streamingClient` 소유 · configuration fetch/cache · `streamingState` ·
  `StreamingClientDelegate` 준수 · 재접속 루프를 `StreamingCoordinator`로 이전.
  단일 취소가능 재접속(`Task.sleep` 또는 하나의 `DispatchWorkItem`) + `client === current` 아이덴티티 가드
  + `.connecting` 가드 + main-thread 정렬 + 백오프로 4대 결함 제거.
- **핵심 제약**: `streamingState`/`configuration`은 파사드 `@Published`로 유지하고 coordinator가
  main-thread setter로 미러(passthrough) → `PostArea.swift:61,125` 읽기 무변경. 디코드된 update/notification
  이벤트가 타임라인·presenter에 계속 도달하도록 콜백 노출.
- **대상 파일**: `reazure/fediverse/StreamingCoordinator.swift`(신규), `mastodon/StreamingClient.swift`,
  `SharedClient.swift`, `views/core/PostArea.swift`
- **뷰 표면 변경**: 없음. **커밋 단위**: `refactor: 스트리밍 수명주기를 StreamingCoordinator로 분리 및 재접속 결함 수정`.
  **선행**: 2.5(presenter 호출), 3.1

### Phase 4 — 심화 (Misskey 확장 발판 · 선택적)

#### 4.1 `EventIngestor` / per-server 디코드 seam 추출 — `medium/large`
- **왜**: `didReceive`(`SharedClient.swift:142-205`)가 transport 디코드·adaptor/model 생성·타임라인 변이·
  unread·오디오/햅틱을 한 메서드에 뒤섞고, 서버-불가지론을 표방하는 hub가 정작 `Mastodon.Status/Notification`으로
  `JSON.parse`하고 Mastodon adaptor를 인라인 생성한다(FediverseServer 추상화 누수).
- **작업**: `payload → adaptor → StatusModel/NotificationModel → 올바른 TimelineModel prepend`를 서버-키
  디코드 팩토리 뒤로 이동. Mastodon 파싱을 adaptor 팩토리로 이관. `EventIngestor`는 timeline map + performer +
  `NotificationPresenter` 참조를 주입받음. stub 상태 Misskey 추가 시 `SharedClient`를 편집하지 않게 되는 진전.
- **대상 파일**: `reazure/fediverse/EventIngestor.swift`(신규), `mastodon/objdef/Status.swift`, `SharedClient.swift`
- **뷰 표면 변경**: 없음. **커밋 단위**: `refactor: 스트리밍 이벤트 디코드를 서버별 EventIngestor로 분리`.
  **선행**: 2.1, 2.5, 3.2

#### 4.2 `AccountSession` 팩토리로 세션 수명주기 중앙화 — `medium/large`
- **왜**: `didAccountChanged`(`SharedClient.swift:107-139`)의 명령형 teardown/rebuild는 생성 순서/정리가
  흩어져 있고, 세션 부트스트랩·로그아웃이 뷰 계층에 누출돼 있다: `WatchAccountManager`가 `onAppear`에서
  `sharedClient.account = accountManager.accounts.first!`로 두 스토어를 오케스트레이션(`WatchAccountManager.swift:31-36`,
  force-unwrap), `AboutAppView`가 `accountManager.remove` + `sharedClient.account = nil`의 2단계 cross-store
  변이(`AboutAppView.swift:137-140`).
- **작업**: `Account → {MastodonClient, StreamingCoordinator, [TimelineType: TimelineModel], configuration}`를
  만드는 `SessionManager`/`AccountSession`으로 대체. 생성/정리 순서 단일화 + 대기 중 재접속 취소.
  `SharedClient`에 `use(account:)` / `signOut()` 추가해 두 뷰가 호출하게 함.
- **대상 파일**: `reazure/fediverse/SessionManager.swift`(신규), `SharedClient.swift`,
  `modifiers/WatchAccountManager.swift`, `views/AboutAppView.swift`
- **뷰 표면 변경**: `WatchAccountManager`, `AboutAppView` 두 호출부만 (계정 대입 → `use(account:)`/`signOut()`).
  **커밋 단위**: `refactor: 계정 세션 수명주기를 SessionManager로 중앙화`. **선행**: 2.1, 3.2

#### 4.3 (선택) `RequestPerforming` 전송 seam + `SharedClient` internal init — `medium/medium`
- **왜**: 모든 REST 호출이 전역 `AF.request`로 직결(`MastodonAPI.swift:162`)돼 스텁 seam이 없고,
  `SharedClient.shared`의 `private init`(`:29,79`)이 허브 자체의 fake 조립을 막는다.
- **작업**: `protocol RequestPerforming`을 추출해 Alamofire 구현을 기본값으로 `MastodonClient.init`에 주입
  (→ `deleteStatus` 버그를 실패 테스트 → 수정, force-unwrap을 throw로 교체). `SharedClient`에 협력 객체 주입용
  `internal init(...)` 추가(`.shared`는 앱용 유지)해 델리게이트 fan-out·재접속 배선을 fake로 end-to-end 테스트.
- **대상 파일**: `reazure/fediverse/mastodon/MastodonAPI.swift`, `SharedClient.swift`,
  `FediverseServer.swift`, `MastodonActionPerformer.swift`
- **뷰 표면 변경**: 없음(OAuth/probe static 메서드의 호출부 `AddAccountView`는 조정 필요).
  **커밋 단위**: `refactor: REST 전송 seam 주입 및 deleteStatus 디코딩 수정`. **선행**: 2.1

---

## 의존 그래프 (실행 순서 요약)

```
1.1 테스트 시드 ──┬─> 1.2 마스크 순환참조
                  ├─> 2.1 ActionPerformer ──> 2.2 compose-post
                  ├─> 2.3 ShortcutHandler 라우터
                  ├─> 2.4 TimelineModel 사이클 절단
                  └─> 2.5 NotificationPresenter
2.1, 2.5 ─> 3.1 WebSocket 팩토리 ─> 3.2 StreamingCoordinator(+재접속 수정)
2.1, 2.5, 3.2 ─> 4.1 EventIngestor
2.1, 3.2 ──────> 4.2 AccountSession
2.1 ───────────> 4.3 RequestPerforming seam(선택)
```

## 검증 방법 (각 스텝 완료 시)

```bash
# 빌드 (설치된 시뮬레이터 확인: xcrun simctl list devices)
xcodebuild -project reazure.xcodeproj -scheme reazure \
  -destination 'platform=iOS Simulator,name=iPhone 16' build

# 테스트 (Swift Testing)
xcodebuild test -project reazure.xcodeproj -scheme reazure \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

- **Phase 1**: 새 테스트가 통과 + 기존 동작 무변경.
- **Phase 2~4**: 각 스텝 후 빌드 성공 + Phase 1에서 심은 회귀 테스트 통과. 스텝별로 추가한 seam은
  즉시 Swift Testing 케이스로 회수. **매 스텝 후 커밋** (제시된 커밋 단위 메시지 사용, 한국어 컨벤션 `scope: 설명`).
- **런타임 스모크**: 스트리밍 연결/재연결(Wi-Fi 토글), favourite/reblog/reply/delete 낙관적 반영, 계정 전환,
  단축키(j/k/h/l/f/t/r/u) 동작 확인.

## 리스크 / 주의사항

- `SharedClient.timeline[.home]!` / `[.notifications]!` 강제 언랩(`AppRootView.swift:61,63`)은 팩토리가 두 키를
  항상 시딩한다는 가정에 의존 → 세션 팩토리(4.2)가 이를 보장해야 함. `TimelineType.local/.federated`는 현재
  미시딩 죽은 케이스.
- passthrough 미러링 시 상태 쓰기는 반드시 main-thread(`DispatchQueue.main.async`)에서 수행해 `@Published`
  일관성 유지.
- Phase 3.2는 이 로드맵의 최고 위험 구간 — 반드시 3.1의 WebSocket 팩토리 seam으로 상태기계를 테스트로 덮은 뒤 진행.
- 테스트에서 fake `performer`는 `weak`이므로 테스트 스코프가 강하게 보유해야 하며, main-hop 이후 단언할 것.
```
