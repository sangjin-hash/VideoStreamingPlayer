//
//  HLSMediaInfo.swift
//  ToyVideoStreamingPlayer
//
//  Created by 이상진 on 12/10/25.
//

import Foundation

/// HLS 마스터 플레이리스트의 미디어 정보 (#EXT-X-MEDIA)
struct HLSMediaInfo {

    // MARK: - Properties

    /// 미디어 타입
    let type: MediaType

    /// 그룹 ID
    let groupID: String

    /// 언어 코드 (예: "en", "ko")
    let language: String?

    /// 미디어 이름
    let name: String

    /// 자동 선택 여부
    let autoSelect: Bool

    /// 기본 선택 여부
    let isDefault: Bool

    /// 강제 자막 여부 (자막의 경우)
    let forced: Bool?

    /// 오디오 채널 수 (오디오의 경우)
    let channels: String?

    /// 인스트림 ID (클로즈드 캡션의 경우)
    let instreamID: String?

    /// 미디어 플레이리스트 URI (상대 경로, 없을 수도 있음)
    let uri: String?

    // MARK: - Nested Types

    /// 미디어 타입
    enum MediaType: String {
        case audio = "AUDIO"
        case video = "VIDEO"
        case subtitles = "SUBTITLES"
        case closedCaptions = "CLOSED-CAPTIONS"
    }
}

// MARK: - Equatable

extension HLSMediaInfo: Equatable {
    static func == (lhs: HLSMediaInfo, rhs: HLSMediaInfo) -> Bool {
        return lhs.type == rhs.type &&
               lhs.groupID == rhs.groupID &&
               lhs.name == rhs.name &&
               lhs.uri == rhs.uri
    }
}

// MARK: - CustomStringConvertible

extension HLSMediaInfo: CustomStringConvertible {
    var description: String {
        var desc = "\(type.rawValue)[\(name)"
        if let language = language {
            desc += ", \(language)"
        }
        if let channels = channels {
            desc += ", \(channels)ch"
        }
        desc += "]"
        return desc
    }
}
