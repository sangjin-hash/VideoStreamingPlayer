//
//  StreamPlayerManager.swift
//  ToyVideoStreamingPlayer
//
//  Created by 이상진 on 12/5/25.
//

import Foundation
import AVFoundation

protocol StreamPlayerManagerDelegate: AnyObject {
    func playerDidUpdateTime(currentTime: Double, duration: Double)
    func playerStateDidChange(state: PlaybackState)
    func playerDidUpdateBuffer(bufferedTime: Double)
}

class StreamPlayerManager {
    
    // MARK: - Delegate
    
    weak var delegate: StreamPlayerManagerDelegate?
    
    // MARK: - Properties
    
    private(set) var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var timeObserverToken: Any?
    private var statusObservation: NSKeyValueObservation?
    private var bufferObservation: NSKeyValueObservation?
    
    private(set) var currentState: PlaybackState = .idle {
        didSet {
            delegate?.playerStateDidChange(state: currentState)
        }
    }
    
    var isPlaying: Bool {
        guard let player = player else { return false }
        return player.rate != 0
    }
    
    var duration: Double {
        guard let duration = playerItem?.duration else { return 0 }
        return duration.seconds
    }
    
    // MARK: - Initialization
    
    init() {
        setupNotifications()
    }
    
    deinit {
        cleanup()
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Public Methods
    
    func loadStream(url: URL) {
        cleanup()
        currentState = .loading

        let asset = AVURLAsset(url: url)
        playerItem = AVPlayerItem(asset: asset)
        player = AVPlayer(playerItem: playerItem)

        // ABR 최적화 설정
        if let player = player {
            // 자동으로 stalling 최소화 (버퍼링 개선)
            player.automaticallyWaitsToMinimizeStalling = true
        }

        setupObservers()
    }
    
    func play() {
        guard let playerItem = playerItem else { return }

        player?.play()

        if playerItem.isPlaybackLikelyToKeepUp {
            currentState = .playing
        } else {
            currentState = .buffering
        }
    }
    
    func pause() {
        player?.pause()
        currentState = .paused
    }
    
    func seek(to time: Double) {
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        player?.seek(to: cmTime)
    }
    
    func seek(toPercent percent: Double) {
        let time = duration * percent
        seek(to: time)
    }
    
    func forward(seconds: Double = 10) {
        guard let currentItem = player?.currentItem else { return }
        let currentTime = currentItem.currentTime().seconds
        let newTime = min(currentTime + seconds, duration)
        seek(to: newTime)
    }
    
    func rewind(seconds: Double = 10) {
        guard let currentItem = player?.currentItem else { return }
        let currentTime = currentItem.currentTime().seconds
        let newTime = max(currentTime - seconds, 0)
        seek(to: newTime)
    }
    
    func setRate(_ rate: Float) {
        player?.rate = rate
    }
    
    // MARK: - Private Methods
    
    private func setupObservers() {
        guard let player = player, let playerItem = playerItem else { return }
        
        // Time Observer
        timeObserverToken = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            guard let self = self else { return }
            self.delegate?.playerDidUpdateTime(
                currentTime: time.seconds,
                duration: self.duration
            )
        }
        
        // Status Observer
        statusObservation = playerItem.observe(\.status, options: [.new]) { [weak self] item, _ in
            guard let self = self else { return }
            
            switch item.status {
            case .readyToPlay:
                self.currentState = .readyToPlay
                
            case .failed:
                if let error = item.error {
                    self.currentState = .failed(error)
                    print("Failed to play: \(error.localizedDescription)")
                }
                
            case .unknown:
                print("Loading...")
                
            @unknown default:
                break
            }
        }
        
        // Buffer Observer - 버퍼 상태 및 UI 업데이트
        bufferObservation = playerItem.observe(\.loadedTimeRanges, options: [.new]) { [weak self] item, _ in
            guard let self = self else { return }

            // 1. UI 업데이트 - 버퍼링 seekbar 표시
            if let timeRange = item.loadedTimeRanges.first?.timeRangeValue {
                let bufferedTime = timeRange.start.seconds + timeRange.duration.seconds
                self.delegate?.playerDidUpdateBuffer(bufferedTime: bufferedTime)
            }

            // 2. 상태 관리 - 버퍼링 상태 체크
            let isPlayingOrBuffering = self.currentState == .playing || self.currentState == .buffering

            if !item.isPlaybackLikelyToKeepUp && isPlayingOrBuffering {
                // 버퍼가 부족하면 buffering 상태로 전환
                self.currentState = .buffering
            } else if item.isPlaybackLikelyToKeepUp && self.currentState == .buffering {
                // 버퍼링이 완료되면 playing 상태로 복귀 (재생 중이었다면)
                if self.player?.rate != 0 {
                    self.currentState = .playing
                }
            }
        }
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerDidFinishPlaying),
            name: .AVPlayerItemDidPlayToEndTime,
            object: nil
        )
    }
    
    @objc private func playerDidFinishPlaying() {
        currentState = .ended
    }
    
    private func cleanup() {
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
            timeObserverToken = nil
        }
        
        statusObservation?.invalidate()
        statusObservation = nil

        bufferObservation?.invalidate()
        bufferObservation = nil
        
        player?.pause()
        player = nil
        playerItem = nil
        
        currentState = .idle
    }
}
