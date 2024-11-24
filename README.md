# NAME

re;azure - "Streaming-only" Mastodon client for iOS / macOS

# DESCRIPTION

re;azure는 iOS와 macOS를 위한 **키보드 중심**의 **스트리밍 전용** Mastodon 클라이언트입니다. 

tmyt님이 작성하신 Windows / Windows Mobile용 Twitter 클라이언트인 [Azurea](https://azurea.info) 로부터 영감을 받아 작성되었습니다.

## KEY FEATURES

### "Streaming-only"

이 앱은 Mastodon의 [`/streaming/user`](https://docs.joinmastodon.org/methods/streaming/) API를 사용하여 홈 타임라인의 새로운 포스트와 알림을 실시간으로 수신받는 것에 중점을 두고 있습니다.

따라서, SQLite 등을 사용한 타임라인의 오프라인 캐싱 같은 기능은 일절 없으며, 개발 계획 또한 없습니다.

### "Azurea-like" Experience

저희의 가장 큰 목표는 **Azurea의 사용자 경험을 최대한 iOS / macOS에 맞게 재현하는 것**입니다. 

키보드를 사용하여 빠르게 타임라인을 스크롤링하며 친구들의 포스트에 반응하고, 새로운 포스트를 작성할 수 있습니다.

# REQUIREMENTS

- iOS 17.6 이상을 필요로 합니다.
- macOS를 지원합니다. (Designed for iPad를 통해 실행되므로 Apple Silicon 기반의 Mac이 필요합니다.)

# INSTALLATION

## App Store

아직 App Store에 출시되지 않았습니다.

## TestFlight

https://testflight.apple.com/join/qmFPWXtS 로부터 TestFlight에 참여할 수 있습니다.


# AUTHORS

### [team unstablers Inc.](https://unstabler.pl)

- Gyuhwan Park (@cheesekun@ppiy.ac)

# LICENSE

이 소프트웨어는 [MIT License](LICENSE) 하에 제공 및 배포됩니다.

이 소프트웨어에 포함된 아래 이미지/오디오 애셋은 별도 라이선스가 적용됩니다.

- [**reazure.aif**](reazure/assets/notification_sounds/reazure.aif)

  ©️ 2024 Cansol (https://soundcloud.com/cansol) • [CC0 1.0 Universal](https://creativecommons.org/publicdomain/zero/1.0/)

- [**boop.aif**](reazure/assets/notification_sounds/boop.aif) 

  ©️ 2017 Josef Kenny (@jk@mastodon.social) • [AGPL-3.0](https://www.gnu.org/licenses/agpl-3.0.html)

- [**notify32.aif**](reazure/assets/notification_sounds/notify32.aif)

  ©️ 2024 Gyuhwan Park (@cheesekun@ppiy.ac) • [CC0 1.0 Universal](https://creativecommons.org/publicdomain/zero/1.0/)

# THANKS TO

- tmyt님, 멋진 소프트웨어를 개발해주셔서 감사합니다.
- Mastodon과 Misskey, 그 외의 ActivityPub 프로토콜을 구사하는 서버 소프트웨어를 개발해주신 모든 분들께 감사드립니다.
