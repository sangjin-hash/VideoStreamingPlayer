//
//  HLSDownloadManager.swift
//  ToyVideoStreamingPlayer
//
//  Created by 이상진 on 12/10/25.
//

import Foundation

/// HLS 다운로드 매니저
actor HLSDownloadManager {

    // MARK: - Error Types

    enum DownloadError: LocalizedError {
        case invalidURL
        case networkError(Error)
        case parsingError(Error)
        case noAvailableStream

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid URL"
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            case .parsingError(let error):
                return "Parsing error: \(error.localizedDescription)"
            case .noAvailableStream:
                return "No available stream"
            }
        }
    }

    // MARK: - Properties

    private let parser = HLSParser()
    private let urlSession: URLSession

    private var masterPlaylist: HLSMasterPlaylist?
    private var currentMediaPlaylist: HLSMediaPlaylist?
    private var currentStreamInfo: HLSStreamInfo?

    // MARK: - Initialization

    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }

    // MARK: - Public Methods

    /// Master Playlist 로드 및 파싱
    func loadMasterPlaylist(from url: URL) async throws -> HLSMasterPlaylist {
        let content = try await downloadPlaylist(from: url)
        let playlist = try parser.parseMasterPlaylist(content, baseURL: url)
        self.masterPlaylist = playlist
        return playlist
    }

    /// 특정 대역폭에 맞는 스트림 선택
    func selectStream(bandwidth: Int) throws -> HLSStreamInfo {
        guard let masterPlaylist = masterPlaylist else {
            throw DownloadError.noAvailableStream
        }

        // 대역폭 이하의 가장 높은 품질 선택
        let sortedStreams = masterPlaylist.sortedStreams
        let selectedStream = sortedStreams.last { $0.bandwidth <= bandwidth }
            ?? sortedStreams.first // 최소 품질이라도 선택

        guard let stream = selectedStream else {
            throw DownloadError.noAvailableStream
        }

        self.currentStreamInfo = stream
        return stream
    }

    /// Media Playlist 로드 및 파싱
    func loadMediaPlaylist(for stream: HLSStreamInfo) async throws -> (playlist: HLSMediaPlaylist, content: String) {
        guard let masterPlaylist = masterPlaylist else {
            throw DownloadError.noAvailableStream
        }

        guard let mediaPlaylistURL = masterPlaylist.absoluteURL(for: stream.uri) else {
            throw DownloadError.invalidURL
        }

        let content = try await downloadPlaylist(from: mediaPlaylistURL)
        let playlist = try parser.parseMediaPlaylist(content, baseURL: mediaPlaylistURL)
        self.currentMediaPlaylist = playlist
        return (playlist, content)
    }

    /// 초기화 세그먼트 다운로드 (fMP4 헤더)
    func downloadInitializationSegment() async throws -> Data? {
        guard let mediaPlaylist = currentMediaPlaylist,
              let initSegment = mediaPlaylist.initializationSegment else {
            return nil
        }

        guard let segmentURL = mediaPlaylist.absoluteURL(for: initSegment.uri) else {
            throw DownloadError.invalidURL
        }

        if let byteRange = initSegment.byteRange {
            return try await downloadSegment(url: segmentURL, byteRange: byteRange)
        } else {
            return try await downloadSegment(url: segmentURL)
        }
    }

    /// 특정 세그먼트 다운로드
    func downloadSegment(at index: Int) async throws -> Data {
        guard let mediaPlaylist = currentMediaPlaylist else {
            throw DownloadError.noAvailableStream
        }

        guard let segment = mediaPlaylist.segment(at: index) else {
            throw DownloadError.invalidURL
        }

        guard let segmentURL = mediaPlaylist.absoluteURL(for: segment.uri) else {
            throw DownloadError.invalidURL
        }

        if let byteRange = segment.byteRange {
            return try await downloadSegment(url: segmentURL, byteRange: byteRange)
        } else {
            return try await downloadSegment(url: segmentURL)
        }
    }

    // MARK: - Private Methods

    /// 플레이리스트 다운로드
    private func downloadPlaylist(from url: URL) async throws -> String {
        do {
            let (data, _) = try await urlSession.data(from: url)
            guard let content = String(data: data, encoding: .utf8) else {
                throw DownloadError.parsingError(HLSParser.ParsingError.invalidFormat)
            }
            return content
        } catch {
            throw DownloadError.networkError(error)
        }
    }

    /// 세그먼트 다운로드 (전체 파일)
    private func downloadSegment(url: URL) async throws -> Data {
        do {
            let (data, _) = try await urlSession.data(from: url)
            return data
        } catch {
            throw DownloadError.networkError(error)
        }
    }

    /// 세그먼트 다운로드 (바이트 범위)
    private func downloadSegment(url: URL, byteRange: HLSMediaPlaylist.ByteRange) async throws -> Data {
        do {
            var request = URLRequest(url: url)
            request.setValue(byteRange.httpRangeHeader, forHTTPHeaderField: "Range")

            let (data, _) = try await urlSession.data(for: request)
            return data
        } catch {
            throw DownloadError.networkError(error)
        }
    }
}
