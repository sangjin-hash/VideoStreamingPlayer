## HLS, DASH 학습 기록

### Goal
iOS 에서 HLS 와 DASH 를 지원하는 비디오를 재생해보며 스트리밍 프로토콜의 동작 원리를 학습한 기록입니다. `AVPlayer` 를 사용하며 플레이어 설정 및 제어부터 HLS 와 DASH 이해까지 다루었습니다.

1. `AVPlayer` 설정 및 재생 제어 그리고 상태 관리
  - Blog: [[iOS] AVFoundation, AVKit 이해 그리고 AVPlayer 다뤄보기](https://velog.io/@sangjin-hash/iOS-AVFoundation-AVKit-%EC%9D%B4%ED%95%B4-%EA%B7%B8%EB%A6%AC%EA%B3%A0-AVPlayer-%EB%8B%A4%EB%A4%84%EB%B3%B4%EA%B8%B0)
  - Github: https://github.com/sangjin-hash/VideoStreamingPlayer/tree/AVPlayer
  <img width="297" height="234" alt="image" src="https://github.com/user-attachments/assets/ea5b7c70-9a4c-4c78-a868-f5be245c60d4" />
  <br></br>
  
2. `.m3u8` 파일 톺아보기 + 비디오 세그먼트를 받아와 `AVPlayer`에 재생해보기
  - Blog: [[iOS] HLS 에 대하여](https://velog.io/@sangjin-hash/iOS-HLS-%EC%97%90-%EB%8C%80%ED%95%98%EC%97%AC)
  - Github: https://github.com/sangjin-hash/VideoStreamingPlayer/tree/AVPlayer
  <br></br>

3. Custom scheme을 이용한 `AVAssetResourceLoaderDelegate` 활용하기
  - Blog: [[iOS] AVPlayer 의 Custom ResourceLoader](https://velog.io/@sangjin-hash/iOS-AVPlayer-%EC%9D%98-Custom-ResourceLoader)
  - Github: https://github.com/sangjin-hash/VideoStreamingPlayer/tree/AVAssetResourceLoader
<img width="596" height="672" alt="image" src="https://github.com/user-attachments/assets/5c428116-5824-49b4-a414-50f1550bad41" />
<br></br>

  
4. `.mpd` 파일 톺아보기 + 가상의 HLS 플레이리스트로 변환하여 `AVPlayer` 에서 재생해보기
  - Blog: [[iOS] DASH 에 대하여](https://velog.io/@sangjin-hash/DASH-%EC%97%90-%EB%8C%80%ED%95%98%EC%97%AC)
  - Github: https://github.com/sangjin-hash/VideoStreamingPlayer/tree/main
<img width="493" height="849" alt="image" src="https://github.com/user-attachments/assets/0e41ed01-d071-40d7-9719-a9884667b02b" />
<br></br>

추후에 업데이트되는 내용이 있을 때 추가할 계획입니다.

---

### Structure
```
  ToyVideoStreamingPlayer/
  ├── App/
  │   ├── AppDelegate.swift
  │   └── SceneDelegate.swift
  ├── Player/
  │   ├── VideoPlayerViewController.swift
  │   ├── HLSResourceLoaderDelegate.swift
  │   ├── DASHResourceLoaderDelegate.swift
  │   ├── Models/
  │   │   ├── PlaybackState.swift
  │   │   ├── HLS/
  │   │   │   ├── Master/ (HLSMasterPlaylist, HLSStreamInfo, HLSMediaInfo)
  │   │   │   └── Media/ (HLSMediaPlaylist)
  │   │   └── DASH/ (DASHMPD)
  │   └── Views/
  │       └── PlayerView.swift
  ├── Managers/
  │   ├── StreamPlayerManager.swift
  │   └── HLSDownloadManager.swift
  └── Utilities/
      ├── HLSParser.swift
      └── DASHParser.swift
```
#### 주요 구성
- `Player/Models`: HLS/DASH 매니페스트 및 재생 상태 모델
- `Player/Views`: 렌더링 레이어 (AVPlayerLayer)
- `Player`: ResourceLoaderDelegate, VideoPlayerViewController
- `Managers`: 스트리밍 재생 및 다운로드 관리
- `Utilities`: HLS/DASH 파서

---

### Reference
[Apple Docs]
- https://developer.apple.com/documentation/avfoundation
- https://developer.apple.com/library/archive/documentation/AudioVideo/Conceptual/AVFoundationPG/Articles/00_Introduction.html#//apple_ref/doc/uid/TP40010188-CH1-SW3
- https://developer.apple.com/documentation/avfoundation/avplayer
- https://developer.apple.com/documentation/http-live-streaming
- https://developer.apple.com/documentation/avfoundation/avassetresourceloaderdelegate

[Docs]
- https://en.wikipedia.org/wiki/Dynamic_Adaptive_Streaming_over_HTTP
- https://www.cloudflare.com/ko-kr/learning/video/what-is-mpeg-dash/

[Blog]
- https://medium.com/@hongseongho/introduction-to-hls-e7186f411a02

[Naver Deview]
- https://tv.naver.com/v/23652319
- https://deview.kr/data/deview/session/attach/4_AVPlayer%E2%80%99s%20Custom%20ResourceLoader,%20%EC%96%B4%EB%96%BB%EA%B2%8C%20%EC%82%AC%EC%9A%A9%ED%95%A0%EA%B9%8C%EC%9A%94%20(AVAssetResourceLoaderDelegate%20%EB%85%B8%ED%95%98%EC%9A%B0%20%EA%B3%B5%EC%9C%A0).pdf
