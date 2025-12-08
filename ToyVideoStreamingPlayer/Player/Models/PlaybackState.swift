//
//  PlaybackState.swift
//  ToyVideoStreamingPlayer
//
//  Created by 이상진 on 12/5/25.
//

import Foundation

enum PlaybackState: Equatable {
    case idle
    case loading
    case readyToPlay
    case playing
    case paused
    case buffering
    case ended
    case failed(Error)

    static func == (lhs: PlaybackState, rhs: PlaybackState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle),
             (.loading, .loading),
             (.readyToPlay, .readyToPlay),
             (.playing, .playing),
             (.paused, .paused),
             (.buffering, .buffering),
             (.ended, .ended):
            return true
        case (.failed(let lhsError), .failed(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
}
