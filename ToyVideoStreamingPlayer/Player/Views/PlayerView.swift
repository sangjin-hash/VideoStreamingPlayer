//
//  PlayerView.swift
//  ToyVideoStreamingPlayer
//
//  Created by 이상진 on 12/5/25.
//

import UIKit
import AVFoundation

class PlayerView: UIView {
    
    // MARK: - Properties
    
    override class var layerClass: AnyClass {
        AVPlayerLayer.self
    }
    
    var playerLayer: AVPlayerLayer? {
        self.layer as? AVPlayerLayer
    }
    
    var player: AVPlayer? {
        get { self.playerLayer?.player }
        set { self.playerLayer?.player = newValue }
    }
    
    // MARK: - Initialization
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayer()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayer()
    }
    
    // MARK: - Setup
    
    private func setupLayer() {
        backgroundColor = .black
        playerLayer?.videoGravity = .resizeAspect
    }
}
