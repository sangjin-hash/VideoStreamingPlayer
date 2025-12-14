//
//  HLSMediaPlaylist.swift
//  ToyVideoStreamingPlayer
//
//  Created by 이상진 on 12/10/25.
//

import Foundation

/// HLS 미디어 플레이리스트
struct HLSMediaPlaylist {

    // MARK: - Properties

    /// 미디어 플레이리스트 URL
    let baseURL: URL

    /// HLS 프로토콜 버전
    let version: Int?

    /// 타겟 세그먼트 길이 (초)
    let targetDuration: Double

    /// 미디어 시퀀스 시작 번호
    let mediaSequence: Int

    /// 플레이리스트 타입 (VOD, EVENT 등)
    let playlistType: PlaylistType?

    /// 독립적인 세그먼트 여부
    let hasIndependentSegments: Bool

    /// 초기화 세그먼트 (fMP4의 경우 - 코덱 정보, 메타데이터 포함)
    let initializationSegment: InitSegment?

    /// 비디오 세그먼트 목록
    let segments: [MediaSegment]

    /// 플레이리스트 종료 여부 (VOD의 경우 true, LIVE는 false)
    let isEnded: Bool

    // MARK: - Nested Types

    /// 플레이리스트 타입
    enum PlaylistType: String {
        case vod = "VOD"        // 주문형 비디오 (처음부터 끝까지 정해짐)
        case event = "EVENT"    // 라이브 이벤트 (끝이 정해지지 않음)
    }

    /// 초기화 세그먼트 (fMP4)
    /// fMP4는 초기화 세그먼트에 코덱 정보, 트랙 정보 등 메타데이터가 들어있음
    struct InitSegment {
        let uri: String
        let byteRange: ByteRange?
    }

    /// 미디어 세그먼트 (실제 비디오/오디오 데이터)
    struct MediaSegment {
        /// 세그먼트 길이 (초)
        let duration: Double

        /// 세그먼트 URI (파일명)
        let uri: String

        /// 바이트 범위 (fMP4의 경우 하나의 파일에서 범위로 구분)
        let byteRange: ByteRange?

        /// 세그먼트 인덱스 (순서)
        let index: Int
    }

    /// 바이트 범위 (HTTP Range Request에 사용)
    struct ByteRange {
        let length: Int    // 읽을 바이트 길이
        let offset: Int    // 시작 위치
        let isOffsetExplicit: Bool  // offset이 명시되었는지 여부

        /// "length@offset" 또는 "length" 형식 파싱
        /// HLS 스펙: offset이 생략되면 이전 세그먼트 바로 다음부터 시작
        init?(string: String) {
            let components = string.split(separator: "@")
            guard let length = Int(components[0]) else {
                return nil
            }

            self.length = length
            if components.count > 1, let offset = Int(components[1]) {
                self.offset = offset
                self.isOffsetExplicit = true
            } else {
                self.offset = 0  // 임시값, 파서에서 수정됨
                self.isOffsetExplicit = false
            }
        }

        init(length: Int, offset: Int) {
            self.length = length
            self.offset = offset
            self.isOffsetExplicit = true
        }

        /// HTTP Range 헤더 형식: "bytes=start-end"
        var httpRangeHeader: String {
            let end = offset + length - 1
            return "bytes=\(offset)-\(end)"
        }
    }

    // MARK: - Computed Properties

    /// 전체 재생 시간 (초)
    var totalDuration: Double {
        return segments.reduce(0) { $0 + $1.duration }
    }

    // MARK: - Helper Methods

    /// 상대 URI를 절대 URL로 변환
    func absoluteURL(for relativeURI: String) -> URL? {
        return URL(string: relativeURI, relativeTo: baseURL)?.absoluteURL
    }

    /// 특정 시간에 해당하는 세그먼트 찾기
    func segment(at time: Double) -> MediaSegment? {
        var currentTime: Double = 0
        for segment in segments {
            currentTime += segment.duration
            if currentTime >= time {
                return segment
            }
        }
        return segments.last
    }

    /// 특정 인덱스의 세그먼트 찾기
    func segment(at index: Int) -> MediaSegment? {
        return segments.first { $0.index == index }
    }
}

// MARK: - CustomStringConvertible

extension HLSMediaPlaylist: CustomStringConvertible {
    var description: String {
        var desc = "HLS Media Playlist\n"
        desc += "- Base URL: \(baseURL)\n"
        if let version = version {
            desc += "- Version: \(version)\n"
        }
        desc += "- Target Duration: \(targetDuration)s\n"
        desc += "- Media Sequence: \(mediaSequence)\n"
        if let playlistType = playlistType {
            desc += "- Type: \(playlistType.rawValue)\n"
        }
        desc += "- Segments: \(segments.count)\n"
        desc += "- Total Duration: \(String(format: "%.2f", totalDuration))s\n"
        desc += "- Ended: \(isEnded)\n"
        if let initSegment = initializationSegment {
            desc += "- Init Segment: \(initSegment.uri)\n"
        }
        return desc
    }
}
