//
//  VideoPlayerViewController.swift
//  ToyVideoStreamingPlayer
//
//  Created by 이상진 on 12/5/25.
//

import UIKit
import AVFoundation
import AVKit

class VideoPlayerViewController: UIViewController, UIGestureRecognizerDelegate {
    
    // MARK: - IBOutlets
    @IBOutlet weak var playerView: PlayerView!
    @IBOutlet weak var controlPanelView: UIView!
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var loadingIndicator: UIActivityIndicatorView!
    
    // SeekBar Components
    @IBOutlet weak var seekBarContainerView: UIView!
    @IBOutlet weak var currentTimeLabel: UILabel!
    @IBOutlet weak var totalTimeLabel: UILabel!
    @IBOutlet weak var backgroundBar: UIView!
    @IBOutlet weak var bufferedBar: UIView!
    @IBOutlet weak var progressBar: UIView!
    @IBOutlet weak var bufferedBarWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var progressBarWidthConstraint: NSLayoutConstraint!
    
    // Gestures
    @IBOutlet weak var videoContainerTapGesture: UITapGestureRecognizer!
    @IBOutlet weak var seekBarTapGesture: UITapGestureRecognizer!
    
    // VideoContainer Constraints
    @IBOutlet weak var videoContainerView: UIView!
    
    // orientation 변경 시 isActive = false 로 인해 nil이 되므로 강한 관계 설정
    private var centerYConstraint: NSLayoutConstraint!
    private var topConstraint: NSLayoutConstraint!
    private var bottomConstraint: NSLayoutConstraint!
    
    @IBOutlet weak var videoContainerCenterYConstraint: NSLayoutConstraint! {
        didSet {
            centerYConstraint = videoContainerCenterYConstraint
        }
    }
    
    @IBOutlet weak var videoContainerLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var videoContainerTrailingConstraint: NSLayoutConstraint!
    
    @IBOutlet weak var videoContainerTopConstraint: NSLayoutConstraint! {
        didSet {
            topConstraint = videoContainerTopConstraint
        }
    }
    
    @IBOutlet weak var videoContainerBottomConstraint: NSLayoutConstraint! {
        didSet {
            bottomConstraint = videoContainerBottomConstraint
        }
    }
    
    // MARK: - Managers
    private let streamPlayerManager = StreamPlayerManager()
    
    // MARK: - Properties
    
    private let testStreamURL = "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_fmp4/master.m3u8"
    
    private var hideControlsWorkItem: DispatchWorkItem?
    private var isControlPanelVisible = true {
        didSet {
            updateControlPanelVisibility()
        }
    }
    
    // SeekBar interaction state
    private var isSeeking = false
    
    // Fullscreen state
    private var isFullscreen = false
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .allButUpsideDown
    }
    
    override var prefersStatusBarHidden: Bool {
        return isFullscreen
    }
    
    override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation {
        return .fade
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        setupManagers()
        loadTestVideo()
        
        videoContainerTapGesture.require(toFail: seekBarTapGesture)
        seekBarTapGesture.delegate = self
        
        // Initial Orientation: portrait
        topConstraint.isActive = false
        bottomConstraint.isActive = false
        centerYConstraint.isActive = true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        let isLandscape = size.width > size.height
        
        coordinator.animate(alongsideTransition: { _ in
            if isLandscape {
                self.enterFullscreen(animated: false)
            } else {
                self.exitFullscreen(animated: false)
            }
        })
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        view.backgroundColor = .black
        controlPanelView.alpha = 1.0
        isControlPanelVisible = true

        // SeekBar Initial State
        currentTimeLabel.text = "00:00"
        totalTimeLabel.text = "00:00"
        progressBarWidthConstraint.constant = 0
        bufferedBarWidthConstraint.constant = 0
    }
    
    private func setupManagers() {
        streamPlayerManager.delegate = self
    }
    
    private func loadTestVideo() {
        guard let url = URL(string: testStreamURL) else {
            return
        }
        
        streamPlayerManager.loadStream(url: url)
        playerView.player = streamPlayerManager.player
    }
    
    // MARK: - Fullscreen Management
    
    private func enterFullscreen(animated: Bool) {
        guard !isFullscreen else { return }
        
        isFullscreen = true
        
        // Portrait -> Landscape
        centerYConstraint.isActive = false
        topConstraint.isActive = true
        bottomConstraint.isActive = true
        
        // Transition animation
        if animated {
            UIView.animate(withDuration: 0.3) {
                self.view.layoutIfNeeded()
                self.setNeedsStatusBarAppearanceUpdate()
            }
        } else {
            view.layoutIfNeeded()
            setNeedsStatusBarAppearanceUpdate()
        }
    }
    
    private func exitFullscreen(animated: Bool) {
        guard isFullscreen else { return }
        
        isFullscreen = false
        
        // Landscape -> Portrait
        topConstraint.isActive = false
        bottomConstraint.isActive = false
        centerYConstraint.isActive = true
        
        // Transition animation
        if animated {
            UIView.animate(withDuration: 0.3) {
                self.view.layoutIfNeeded()
                self.setNeedsStatusBarAppearanceUpdate()
            }
        } else {
            view.layoutIfNeeded()
            setNeedsStatusBarAppearanceUpdate()
        }
    }
    
    private func toggleFullscreen() {
        if isFullscreen {
            rotateToPortrait()
        } else {
            rotateToLandscape()
        }
    }
    
    private func rotateToLandscape() {
        if #available(iOS 16.0, *) {
            guard let windowScene = view.window?.windowScene else { return }
            windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscapeRight))
        } else {
            let value = UIInterfaceOrientation.landscapeRight.rawValue
            UIDevice.current.setValue(value, forKey: "orientation")
            UIViewController.attemptRotationToDeviceOrientation()
        }
    }
    
    private func rotateToPortrait() {
        if #available(iOS 16.0, *) {
            guard let windowScene = view.window?.windowScene else { return }
            windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
        } else {
            let value = UIInterfaceOrientation.portrait.rawValue
            UIDevice.current.setValue(value, forKey: "orientation")
            UIViewController.attemptRotationToDeviceOrientation()
        }
    }
    
    // MARK: - Gesture Delegate

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldReceive touch: UITouch) -> Bool {
        if gestureRecognizer === seekBarTapGesture {
            let point = touch.location(in: backgroundBar)
            if backgroundBar.bounds.contains(point) {
                return true
            }
        }

        return true
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer === seekBarTapGesture {
            return true
        }
        return false
    }
    
    // MARK: - Control Panel Management
    
    private func updateControlPanelVisibility() {
        UIView.animate(withDuration: 0.3) {
            self.controlPanelView.alpha = self.isControlPanelVisible ? 1.0 : 0.0
        }
    }
    
    private func scheduleHideControls() {
        hideControlsWorkItem?.cancel()
        
        // Hide after 3 second
        let workItem = DispatchWorkItem { [weak self] in
            self?.isControlPanelVisible = false
        }
        
        hideControlsWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0, execute: workItem)
    }
    
    private func updatePlayButtonImage(isPlaying: Bool) {
        let imageName = isPlaying ? "small_pause" : "small_play"
        playButton.setImage(UIImage(named: imageName), for: .normal)
    }
    
    // MARK: - SeekBar Management
    
    private func updateSeekBar(currentTime: Double, totalDuration: Double) {
        guard !isSeeking else { return }
        guard totalDuration > 0 else { return }
        
        let barWidth = backgroundBar.bounds.width
        
        currentTimeLabel.text = formatTime(currentTime)
        
        let progressPercent = min(currentTime / totalDuration, 1.0)
        progressBarWidthConstraint.constant = barWidth * progressPercent
    }
    
    private func formatTime(_ seconds: Double) -> String {
        guard !seconds.isNaN && !seconds.isInfinite else { return "00:00" }
        
        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%02d:%02d", minutes, secs)
        }
    }
    
    private func seekTo(location: CGPoint) {
        let barWidth = backgroundBar.bounds.width
        guard barWidth > 0 else { return }
        
        let percent = max(0, min(1, location.x / barWidth))
        
        let wasPlaying = streamPlayerManager.isPlaying
        streamPlayerManager.seek(toPercent: percent)
        
        if wasPlaying {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.streamPlayerManager.play()
            }
        }
        
        let currentTime = streamPlayerManager.duration * percent
        progressBarWidthConstraint.constant = barWidth * percent
        currentTimeLabel.text = formatTime(currentTime)
    }
}

// MARK: - IBActions

extension VideoPlayerViewController {
    // MARK: - SeekBar Gestures
    
    @IBAction func handleSeekBarTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: backgroundBar)
        seekTo(location: location)
        
        if isControlPanelVisible {
            scheduleHideControls()
        }
    }
    
    // MARK: - Control Panel Toggle
    
    @IBAction func toggleControlPanel(_ sender: Any) {
        isControlPanelVisible.toggle()
        
        if isControlPanelVisible {
            scheduleHideControls()
        } else {
            hideControlsWorkItem?.cancel()
        }
    }
    
    // MARK: - Playback Controls
    
    @IBAction func rewindDidTap(_ sender: Any) {
        streamPlayerManager.rewind(seconds: 5)
        
        if isControlPanelVisible {
            scheduleHideControls()
        }
    }
    
    @IBAction func playDidTap(_ sender: Any) {
        if streamPlayerManager.isPlaying {
            streamPlayerManager.pause()
        } else {
            streamPlayerManager.play()
        }
        
        updatePlayButtonImage(isPlaying: streamPlayerManager.isPlaying)
        
        if streamPlayerManager.isPlaying && isControlPanelVisible {
            scheduleHideControls()
        } else {
            hideControlsWorkItem?.cancel()
        }
    }
    
    @IBAction func forwardDidTap(_ sender: Any) {
        streamPlayerManager.forward(seconds: 5)
        
        if isControlPanelVisible {
            scheduleHideControls()
        }
    }
    
    // MARK: - Expand Button
    
    @IBAction func expandDidTap(_ sender: Any) {
        toggleFullscreen()
    }
}

// MARK: - StreamPlayerManagerDelegate

extension VideoPlayerViewController: StreamPlayerManagerDelegate {
    
    func playerDidUpdateTime(currentTime: Double, duration: Double) {
        updateSeekBar(currentTime: currentTime, totalDuration: duration)
    }
    
    func playerStateDidChange(state: PlaybackState) {
        switch state {
        case .loading:
            loadingIndicator.startAnimating()
            loadingIndicator.isHidden = false
            playButton.isHidden = true

        case .readyToPlay:
            loadingIndicator.stopAnimating()
            loadingIndicator.isHidden = true
            playButton.isHidden = false

            let duration = streamPlayerManager.duration
            totalTimeLabel.text = formatTime(duration)

            streamPlayerManager.play()
            updatePlayButtonImage(isPlaying: true)

            scheduleHideControls()

        case .playing:
            loadingIndicator.stopAnimating()
            loadingIndicator.isHidden = true
            playButton.isHidden = false
            updatePlayButtonImage(isPlaying: true)

        case .paused:
            loadingIndicator.stopAnimating()
            loadingIndicator.isHidden = true
            playButton.isHidden = false
            updatePlayButtonImage(isPlaying: false)
            hideControlsWorkItem?.cancel()

        case .buffering:
            loadingIndicator.startAnimating()
            loadingIndicator.isHidden = false
            playButton.isHidden = true

        case .ended:
            loadingIndicator.stopAnimating()
            loadingIndicator.isHidden = true
            playButton.isHidden = false
            updatePlayButtonImage(isPlaying: false)
            hideControlsWorkItem?.cancel()
            isControlPanelVisible = true

        case .failed(let error):
            loadingIndicator.stopAnimating()
            loadingIndicator.isHidden = true
            playButton.isHidden = false
            print("Error: \(error.localizedDescription)")

        default:
            break
        }
    }
    
    func playerDidUpdateBuffer(bufferedTime: Double) {
        let duration = streamPlayerManager.duration
        guard duration > 0 else { return }
        
        let barWidth = backgroundBar.bounds.width
        guard barWidth > 0 else { return }
        
        let bufferedPercent = min(bufferedTime / duration, 1.0)
        bufferedBarWidthConstraint.constant = barWidth * bufferedPercent
    }
}
