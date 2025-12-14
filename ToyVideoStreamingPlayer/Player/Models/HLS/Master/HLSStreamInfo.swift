//
//  HLSStreamInfo.swift
//  ToyVideoStreamingPlayer
//
//  Created by 이상진 on 12/10/25.
//

import Foundation

/// HLS 마스터 플레이리스트의 스트림 정보 (#EXT-X-STREAM-INF)
struct HLSStreamInfo {

    // MARK: - Properties

    /// 평균 대역폭 (bps)
    let averageBandwidth: Int?

    /// 최대 대역폭 (bps)
    let bandwidth: Int

    /// 비디오/오디오 코덱 정보 (예: "avc1.640020,mp4a.40.2")
    let codecs: String?

    /// 비디오 해상도 (예: 1920x1080)
    let resolution: Resolution?

    /// 프레임 레이트 (예: 60.0)
    let frameRate: Double?

    /// 오디오 그룹 ID
    let audioGroupID: String?

    /// 자막 그룹 ID
    let subtitlesGroupID: String?

    /// 클로즈드 캡션 그룹 ID
    let closedCaptionsGroupID: String?

    /// 미디어 플레이리스트 URI (상대 경로)
    let uri: String

    // MARK: - Nested Types

    /// 비디오 해상도
    struct Resolution: Equatable {
        let width: Int
        let height: Int

        init?(string: String) {
            let components = string.split(separator: "x")
            guard components.count == 2,
                  let width = Int(components[0]),
                  let height = Int(components[1]) else {
                return nil
            }
            self.width = width
            self.height = height
        }

        init(width: Int, height: Int) {
            self.width = width
            self.height = height
        }

        var description: String {
            return "\(width)x\(height)"
        }
    }
}

// MARK: - Equatable

extension HLSStreamInfo: Equatable {
    static func == (lhs: HLSStreamInfo, rhs: HLSStreamInfo) -> Bool {
        return lhs.bandwidth == rhs.bandwidth &&
               lhs.resolution == rhs.resolution &&
               lhs.uri == rhs.uri
    }
}

// MARK: - Comparable

extension HLSStreamInfo: Comparable {
    /// 대역폭 기준으로 정렬 (ABR 로직에 사용)
    static func < (lhs: HLSStreamInfo, rhs: HLSStreamInfo) -> Bool {
        return lhs.bandwidth < rhs.bandwidth
    }
}

// MARK: - CustomStringConvertible

extension HLSStreamInfo: CustomStringConvertible {
    var description: String {
        var desc = "Stream["
        if let resolution = resolution {
            desc += "\(resolution.description)"
        }
        desc += " @ \(bandwidth)bps"
        if let frameRate = frameRate {
            desc += ", \(frameRate)fps"
        }
        desc += "]"
        return desc
    }
}

// MARK: - I-Frame Stream Info

/// HLS 마스터 플레이리스트의 I-Frame 스트림 정보 (#EXT-X-I-FRAME-STREAM-INF)
/// I-Frame 전용 플레이리스트는 빠른 탐색(seek)을 위해 키프레임만 포함
struct HLSIFrameStreamInfo {

    // MARK: - Properties

    /// 평균 대역폭 (bps)
    let averageBandwidth: Int?

    /// 최대 대역폭 (bps)
    let bandwidth: Int

    /// 비디오 코덱 정보 (예: "avc1.64002a")
    let codecs: String?

    /// 비디오 해상도 (예: 1920x1080)
    let resolution: HLSStreamInfo.Resolution?

    /// I-Frame 플레이리스트 URI (상대 경로)
    let uri: String
}

// MARK: - Equatable

extension HLSIFrameStreamInfo: Equatable {
    static func == (lhs: HLSIFrameStreamInfo, rhs: HLSIFrameStreamInfo) -> Bool {
        return lhs.bandwidth == rhs.bandwidth &&
               lhs.resolution == rhs.resolution &&
               lhs.uri == rhs.uri
    }
}

// MARK: - Comparable

extension HLSIFrameStreamInfo: Comparable {
    /// 대역폭 기준으로 정렬
    static func < (lhs: HLSIFrameStreamInfo, rhs: HLSIFrameStreamInfo) -> Bool {
        return lhs.bandwidth < rhs.bandwidth
    }
}

// MARK: - CustomStringConvertible

extension HLSIFrameStreamInfo: CustomStringConvertible {
    var description: String {
        var desc = "I-Frame["
        if let resolution = resolution {
            desc += "\(resolution.description)"
        }
        desc += " @ \(bandwidth)bps"
        desc += "]"
        return desc
    }
}
