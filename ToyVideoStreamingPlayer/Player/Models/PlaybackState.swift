//
//  PlaybackState.swift
//  ToyVideoStreamingPlayer
//
//  Created by 이상진 on 12/5/25.
//

import Foundation

enum PlaybackState {
    case idle
    case loading
    case readyToPlay
    case playing
    case paused
    case buffering
    case ended
    case failed(Error)
}
