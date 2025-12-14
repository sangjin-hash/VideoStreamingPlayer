//
//  HLSParser.swift
//  ToyVideoStreamingPlayer
//
//  Created by 이상진 on 12/10/25.
//

import Foundation

/// HLS 플레이리스트 Parser (Master & Media Playlist)
class HLSParser {

    // MARK: - Error Types

    enum ParsingError: LocalizedError {
        case invalidFormat
        case missingRequiredTag
        case invalidAttribute(String)

        var errorDescription: String? {
            switch self {
            case .invalidFormat:
                return "Invalid M3U8 format"
            case .missingRequiredTag:
                return "Missing required M3U8 tag"
            case .invalidAttribute(let attr):
                return "Invalid attribute: \(attr)"
            }
        }
    }

    // MARK: - Public Methods

    /// 마스터 플레이리스트 문자열을 파싱
    func parseMasterPlaylist(_ content: String, baseURL: URL) throws -> HLSMasterPlaylist {
        let lines = content.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        // #EXTM3U 태그 확인
        guard lines.first == "#EXTM3U" else {
            throw ParsingError.invalidFormat
        }

        var version: Int?
        var hasIndependentSegments = false
        var streams: [HLSStreamInfo] = []
        var iFrameStreams: [HLSIFrameStreamInfo] = []
        var media: [HLSMediaInfo] = []

        var i = 0
        while i < lines.count {
            let line = lines[i]

            if line.hasPrefix("#EXT-X-VERSION:") {
                version = parseVersion(line)

            } else if line == "#EXT-X-INDEPENDENT-SEGMENTS" {
                hasIndependentSegments = true

            } else if line.hasPrefix("#EXT-X-STREAM-INF:") {
                // 다음 줄이 URI
                if i + 1 < lines.count {
                    let uri = lines[i + 1]
                    if !uri.hasPrefix("#") {
                        if let streamInfo = parseStreamInfo(line, uri: uri) {
                            streams.append(streamInfo)
                        }
                        i += 1 // URI 줄도 건너뜀
                    }
                }

            } else if line.hasPrefix("#EXT-X-I-FRAME-STREAM-INF:") {
                if let iFrameStreamInfo = parseIFrameStreamInfo(line) {
                    iFrameStreams.append(iFrameStreamInfo)
                }

            } else if line.hasPrefix("#EXT-X-MEDIA:") {
                if let mediaInfo = parseMediaInfo(line) {
                    media.append(mediaInfo)
                }
            }

            i += 1
        }

        return HLSMasterPlaylist(
            baseURL: baseURL,
            version: version,
            streams: streams,
            iFrameStreams: iFrameStreams,
            media: media,
            hasIndependentSegments: hasIndependentSegments
        )
    }

    /// 미디어 플레이리스트 문자열을 파싱
    func parseMediaPlaylist(_ content: String, baseURL: URL) throws -> HLSMediaPlaylist {
        let lines = content.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        // #EXTM3U 태그 확인
        guard lines.first == "#EXTM3U" else {
            throw ParsingError.invalidFormat
        }

        var version: Int?
        var targetDuration: Double = 0
        var mediaSequence: Int = 0
        var playlistType: HLSMediaPlaylist.PlaylistType?
        var hasIndependentSegments = false
        var initializationSegment: HLSMediaPlaylist.InitSegment?
        var segments: [HLSMediaPlaylist.MediaSegment] = []
        var isEnded = false

        var i = 0
        var segmentIndex = 0
        var lastByteRangeEnd: Int = 0

        while i < lines.count {
            let line = lines[i]

            if line.hasPrefix("#EXT-X-VERSION:") {
                version = parseVersion(line)

            } else if line.hasPrefix("#EXT-X-TARGETDURATION:") {
                let value = line.replacingOccurrences(of: "#EXT-X-TARGETDURATION:", with: "")
                targetDuration = Double(value) ?? 0

            } else if line.hasPrefix("#EXT-X-MEDIA-SEQUENCE:") {
                let value = line.replacingOccurrences(of: "#EXT-X-MEDIA-SEQUENCE:", with: "")
                mediaSequence = Int(value) ?? 0

            } else if line.hasPrefix("#EXT-X-PLAYLIST-TYPE:") {
                let value = line.replacingOccurrences(of: "#EXT-X-PLAYLIST-TYPE:", with: "")
                playlistType = HLSMediaPlaylist.PlaylistType(rawValue: value)

            } else if line == "#EXT-X-INDEPENDENT-SEGMENTS" {
                hasIndependentSegments = true

            } else if line.hasPrefix("#EXT-X-MAP:") {
                initializationSegment = parseInitSegment(line)

            } else if line == "#EXT-X-ENDLIST" {
                isEnded = true

            } else if line.hasPrefix("#EXTINF:") {
                // 다음 줄에서 byterange와 URI를 파싱
                var duration: Double = 0
                let durationStr = line.replacingOccurrences(of: "#EXTINF:", with: "")
                    .components(separatedBy: ",")[0]
                duration = Double(durationStr) ?? 0

                var byteRange: HLSMediaPlaylist.ByteRange?
                var uri: String = ""

                // 다음 줄 확인
                if i + 1 < lines.count {
                    let nextLine = lines[i + 1]

                    if nextLine.hasPrefix("#EXT-X-BYTERANGE:") {
                        // BYTERANGE가 있는 경우
                        let rangeStr = nextLine.replacingOccurrences(of: "#EXT-X-BYTERANGE:", with: "")
                        byteRange = HLSMediaPlaylist.ByteRange(string: rangeStr)

                        // BYTERANGE의 offset이 명시되지 않은 경우 이전 세그먼트 끝에서 시작
                        if let range = byteRange, !range.isOffsetExplicit {
                            byteRange = HLSMediaPlaylist.ByteRange(
                                length: range.length,
                                offset: lastByteRangeEnd
                            )
                        }

                        if let range = byteRange {
                            lastByteRangeEnd = range.offset + range.length
                        }

                        // URI는 그 다음 줄
                        if i + 2 < lines.count {
                            uri = lines[i + 2]
                            i += 2 // BYTERANGE와 URI 줄 건너뜀
                        }
                    } else if !nextLine.hasPrefix("#") {
                        // URI만 있는 경우
                        uri = nextLine
                        i += 1 // URI 줄 건너뜀
                    }
                }

                if !uri.isEmpty {
                    let segment = HLSMediaPlaylist.MediaSegment(
                        duration: duration,
                        uri: uri,
                        byteRange: byteRange,
                        index: segmentIndex
                    )
                    segments.append(segment)
                    segmentIndex += 1
                }
            }

            i += 1
        }

        return HLSMediaPlaylist(
            baseURL: baseURL,
            version: version,
            targetDuration: targetDuration,
            mediaSequence: mediaSequence,
            playlistType: playlistType,
            hasIndependentSegments: hasIndependentSegments,
            initializationSegment: initializationSegment,
            segments: segments,
            isEnded: isEnded
        )
    }

    // MARK: - Private Methods

    /// #EXT-X-VERSION 파싱
    private func parseVersion(_ line: String) -> Int? {
        let value = line.replacingOccurrences(of: "#EXT-X-VERSION:", with: "")
        return Int(value)
    }

    /// #EXT-X-STREAM-INF 파싱
    private func parseStreamInfo(_ line: String, uri: String) -> HLSStreamInfo? {
        let attributes = parseAttributes(line)

        // BANDWIDTH는 필수
        guard let bandwidthStr = attributes["BANDWIDTH"],
              let bandwidth = Int(bandwidthStr) else {
            return nil
        }

        let averageBandwidth = attributes["AVERAGE-BANDWIDTH"].flatMap { Int($0) }
        let codecs = attributes["CODECS"]
        let resolution = attributes["RESOLUTION"].flatMap { HLSStreamInfo.Resolution(string: $0) }
        let frameRate = attributes["FRAME-RATE"].flatMap { Double($0) }
        let audioGroupID = attributes["AUDIO"]
        let subtitlesGroupID = attributes["SUBTITLES"]
        let closedCaptionsGroupID = attributes["CLOSED-CAPTIONS"]

        return HLSStreamInfo(
            averageBandwidth: averageBandwidth,
            bandwidth: bandwidth,
            codecs: codecs,
            resolution: resolution,
            frameRate: frameRate,
            audioGroupID: audioGroupID,
            subtitlesGroupID: subtitlesGroupID,
            closedCaptionsGroupID: closedCaptionsGroupID,
            uri: uri
        )
    }

    /// #EXT-X-I-FRAME-STREAM-INF 파싱
    private func parseIFrameStreamInfo(_ line: String) -> HLSIFrameStreamInfo? {
        let attributes = parseAttributes(line)

        // BANDWIDTH와 URI는 필수
        guard let bandwidthStr = attributes["BANDWIDTH"],
              let bandwidth = Int(bandwidthStr),
              let uri = attributes["URI"] else {
            return nil
        }

        let averageBandwidth = attributes["AVERAGE-BANDWIDTH"].flatMap { Int($0) }
        let codecs = attributes["CODECS"]
        let resolution = attributes["RESOLUTION"].flatMap { HLSStreamInfo.Resolution(string: $0) }

        return HLSIFrameStreamInfo(
            averageBandwidth: averageBandwidth,
            bandwidth: bandwidth,
            codecs: codecs,
            resolution: resolution,
            uri: uri
        )
    }

    /// #EXT-X-MEDIA 파싱
    private func parseMediaInfo(_ line: String) -> HLSMediaInfo? {
        let attributes = parseAttributes(line)

        // TYPE, GROUP-ID, NAME은 필수
        guard let typeStr = attributes["TYPE"],
              let type = HLSMediaInfo.MediaType(rawValue: typeStr),
              let groupID = attributes["GROUP-ID"],
              let name = attributes["NAME"] else {
            return nil
        }

        let language = attributes["LANGUAGE"]
        let autoSelect = attributes["AUTOSELECT"] == "YES"
        let isDefault = attributes["DEFAULT"] == "YES"
        let forced = attributes["FORCED"].map { $0 == "YES" }
        let channels = attributes["CHANNELS"]
        let instreamID = attributes["INSTREAM-ID"]
        let uri = attributes["URI"]

        return HLSMediaInfo(
            type: type,
            groupID: groupID,
            language: language,
            name: name,
            autoSelect: autoSelect,
            isDefault: isDefault,
            forced: forced,
            channels: channels,
            instreamID: instreamID,
            uri: uri
        )
    }

    /// #EXT-X-MAP 파싱 (초기화 세그먼트)
    private func parseInitSegment(_ line: String) -> HLSMediaPlaylist.InitSegment? {
        let attributes = parseAttributes(line)

        guard let uri = attributes["URI"] else {
            return nil
        }

        let byteRange = attributes["BYTERANGE"].flatMap { HLSMediaPlaylist.ByteRange(string: $0) }

        return HLSMediaPlaylist.InitSegment(uri: uri, byteRange: byteRange)
    }

    /// 속성 파싱 (KEY=VALUE 또는 KEY="VALUE" 형식)
    private func parseAttributes(_ line: String) -> [String: String] {
        var attributes: [String: String] = [:]

        // #EXT-X-...: 이후의 내용만 추출
        guard let colonIndex = line.firstIndex(of: ":") else {
            return attributes
        }

        let attributesString = String(line[line.index(after: colonIndex)...])

        // 속성 파싱
        var currentKey = ""
        var currentValue = ""
        var insideQuotes = false
        var i = attributesString.startIndex

        while i < attributesString.endIndex {
            let char = attributesString[i]

            if char == "\"" {
                insideQuotes.toggle()
            } else if char == "=" && !insideQuotes {
                currentKey = currentValue.trimmingCharacters(in: .whitespaces)
                currentValue = ""
            } else if char == "," && !insideQuotes {
                if !currentKey.isEmpty {
                    let value = currentValue.trimmingCharacters(in: .whitespaces)
                    attributes[currentKey] = value.replacingOccurrences(of: "\"", with: "")
                    currentKey = ""
                    currentValue = ""
                }
            } else {
                currentValue.append(char)
            }

            i = attributesString.index(after: i)
        }

        // 마지막 속성 저장
        if !currentKey.isEmpty {
            let value = currentValue.trimmingCharacters(in: .whitespaces)
            attributes[currentKey] = value.replacingOccurrences(of: "\"", with: "")
        }

        return attributes
    }
}
