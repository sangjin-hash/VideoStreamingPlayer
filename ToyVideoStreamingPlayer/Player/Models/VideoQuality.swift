//
//  VideoQuality.swift
//  ToyVideoStreamingPlayer
//
//  Created by 이상진 on 12/5/25.
//

import Foundation

struct VideoQuality: Equatable, Hashable {
    let name: String
    let width: Int
    let height: Int
    let bitrate: Int
    let bandwidth: Int
    
    static func == (lhs: VideoQuality, rhs: VideoQuality) -> Bool {
        lhs.name == rhs.name && lhs.height == rhs.height
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(height)
    }
}

extension VideoQuality {
    static var auto: VideoQuality {
        VideoQuality(
            name: "Auto",
            width: 0,
            height: 0,
            bitrate: 0,
            bandwidth: 0
        )
    }
}
