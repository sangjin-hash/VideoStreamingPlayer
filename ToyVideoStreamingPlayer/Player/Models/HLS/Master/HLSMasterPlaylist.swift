//
//  HLSMasterPlaylist.swift
//  ToyVideoStreamingPlayer
//
//  Created by 이상진 on 12/10/25.
//

import Foundation

/// HLS 마스터 플레이리스트 전체 정보
struct HLSMasterPlaylist {

    // MARK: - Properties

    /// 마스터 플레이리스트 URL
    let baseURL: URL

    /// HLS 프로토콜 버전
    let version: Int?

    /// 모든 비디오 스트림 정보
    let streams: [HLSStreamInfo]

    /// 모든 I-Frame 스트림 정보 (빠른 탐색용)
    let iFrameStreams: [HLSIFrameStreamInfo]

    /// 모든 미디어 정보 (오디오, 자막 등)
    let media: [HLSMediaInfo]

    /// 독립적인 세그먼트 여부 (#EXT-X-INDEPENDENT-SEGMENTS)
    let hasIndependentSegments: Bool

    // MARK: - Computed Properties

    /// 대역폭별로 정렬된 스트림 (낮은 것부터 높은 것 순)
    var sortedStreams: [HLSStreamInfo] {
        return streams.sorted()
    }

    /// 대역폭별로 정렬된 I-Frame 스트림
    var sortedIFrameStreams: [HLSIFrameStreamInfo] {
        return iFrameStreams.sorted()
    }

    /// 특정 오디오 그룹의 미디어 목록
    func audioMedia(for groupID: String) -> [HLSMediaInfo] {
        return media.filter { $0.type == .audio && $0.groupID == groupID }
    }

    /// 특정 자막 그룹의 미디어 목록
    func subtitlesMedia(for groupID: String) -> [HLSMediaInfo] {
        return media.filter { $0.type == .subtitles && $0.groupID == groupID }
    }

    /// 기본 오디오 미디어
    func defaultAudioMedia(for groupID: String) -> HLSMediaInfo? {
        return audioMedia(for: groupID).first { $0.isDefault }
    }

    /// 기본 자막 미디어
    func defaultSubtitlesMedia(for groupID: String) -> HLSMediaInfo? {
        return subtitlesMedia(for: groupID).first { $0.isDefault }
    }

    // MARK: - Helper Methods

    /// 상대 URI를 절대 URL로 변환
    func absoluteURL(for relativeURI: String) -> URL? {
        return URL(string: relativeURI, relativeTo: baseURL)?.absoluteURL
    }
}

// MARK: - CustomStringConvertible

extension HLSMasterPlaylist: CustomStringConvertible {
    var description: String {
        var desc = "HLS Master Playlist\n"
        desc += "- Base URL: \(baseURL)\n"
        if let version = version {
            desc += "- Version: \(version)\n"
        }
        desc += "- Streams: \(streams.count)\n"
        streams.forEach { stream in
            desc += "  - \(stream.description)\n"
        }
        desc += "- I-Frame Streams: \(iFrameStreams.count)\n"
        iFrameStreams.forEach { iFrameStream in
            desc += "  - \(iFrameStream.description)\n"
        }
        desc += "- Media: \(media.count)\n"
        media.forEach { mediaInfo in
            desc += "  - \(mediaInfo.description)\n"
        }
        return desc
    }
}
