//
//  HLSResourceLoaderDelegate.swift
//  ToyVideoStreamingPlayer
//
//  Created by 이상진 on 12/10/25.
//

import Foundation
import AVFoundation

/// AVAssetResourceLoader Delegate - HLS 세그먼트를 순차적으로 제공
class HLSResourceLoaderDelegate: NSObject, AVAssetResourceLoaderDelegate {

    // MARK: - Properties

    private let downloadManager: HLSDownloadManager
    private let customScheme = "custom-hls"

    // 세그먼트 캐시 (이미 다운로드한 세그먼트 저장)
    private var segmentCache: [Int: Data] = [:]
    private var initSegmentData: Data?

    // 현재 Media Playlist
    private var mediaPlaylist: HLSMediaPlaylist?
    private var mediaPlaylistContent: String?

    // MARK: - Initialization

    init(downloadManager: HLSDownloadManager) {
        self.downloadManager = downloadManager
        super.init()
    }

    // MARK: - Public Methods

    /// Media Playlist 안 Video Segment URL 상대 주소를
    /// 커스텀 스킴으로 적용된 절대 주소로 변경
    func setMediaPlaylist(_ playlist: HLSMediaPlaylist, content: String) {
        self.mediaPlaylist = playlist

        // main.mp4를 custom-hls URL로 변경하여 우리가 직접 처리하도록 함
        var modifiedContent = content

        // baseURL에서 디렉토리 경로 추출
        let baseURL = playlist.baseURL.absoluteString.components(separatedBy: "/").dropLast().joined(separator: "/")

        if !baseURL.isEmpty {
            // https://...v5/main.mp4 -> custom-hls://...v5/main.mp4
            let httpsURL = "\(baseURL)/main.mp4"
            let customURL = httpsURL.replacingOccurrences(of: "https://", with: "custom-hls://")

            // 1. #EXT-X-MAP의 URI="main.mp4" -> URI="custom-hls://..."
            modifiedContent = modifiedContent.replacingOccurrences(
                of: "URI=\"main.mp4\"",
                with: "URI=\"\(customURL)\""
            )

            // 2. 세그먼트 URI main.mp4 -> custom-hls://...
            let lines = modifiedContent.components(separatedBy: .newlines)
            var modifiedLines: [String] = []

            for (index, line) in lines.enumerated() {
                if line == "main.mp4" {
                    // 이전 줄이 #EXTINF: 또는 #EXT-X-BYTERANGE인 경우
                    if index > 0 && (lines[index - 1].hasPrefix("#EXTINF:") || lines[index - 1].hasPrefix("#EXT-X-BYTERANGE:")) {
                        modifiedLines.append(customURL)
                    } else {
                        modifiedLines.append(line)
                    }
                } else {
                    modifiedLines.append(line)
                }
            }

            modifiedContent = modifiedLines.joined(separator: "\n")
        }

        self.mediaPlaylistContent = modifiedContent
    }

    // MARK: - AVAssetResourceLoaderDelegate

    func resourceLoader(
        _ resourceLoader: AVAssetResourceLoader,
        shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest
    ) -> Bool {
        guard let url = loadingRequest.request.url else {
            loadingRequest.finishLoading(with: NSError(domain: "HLSResourceLoader", code: -1))
            return false
        }

        // 비동기 처리
        Task {
            await handleLoadingRequest(loadingRequest, url: url)
        }

        return true
    }

    // MARK: - Private Methods

    /// 로딩 요청 처리
    private func handleLoadingRequest(_ loadingRequest: AVAssetResourceLoadingRequest, url: URL) async {
        do {
            // 1. Content Information Request 처리
            if let contentRequest = loadingRequest.contentInformationRequest {
                try await handleContentInfoRequest(contentRequest, url: url)
            }

            // 2. Data Request 처리
            if let dataRequest = loadingRequest.dataRequest {
                try await handleDataRequest(dataRequest, url: url)
            }

            loadingRequest.finishLoading()

        } catch {
            print("Request failed: \(error.localizedDescription)")
            loadingRequest.finishLoading(with: error)
        }
    }

    /// Content Information Request 처리
    private func handleContentInfoRequest(
        _ contentRequest: AVAssetResourceLoadingContentInformationRequest,
        url: URL
    ) async throws {
        guard let mediaPlaylist = mediaPlaylist else {
            throw NSError(domain: "HLSResourceLoader", code: -1)
        }

        let fileName = url.lastPathComponent

        // 플레이리스트 파일인 경우
        if fileName.hasSuffix(".m3u8") {
            contentRequest.contentType = "application/x-mpegURL"
            contentRequest.isByteRangeAccessSupported = false
            if let playlistContent = mediaPlaylistContent {
                contentRequest.contentLength = Int64(playlistContent.utf8.count)
            }
        } else {
            // fMP4 세그먼트인 경우 - 전체 파일 크기 계산
            contentRequest.contentType = "video/mp4"
            contentRequest.isByteRangeAccessSupported = true

            // 전체 파일 크기 = 초기화 세그먼트 + 모든 미디어 세그먼트
            var totalLength: Int64 = 0

            if let initSegment = mediaPlaylist.initializationSegment,
               let byteRange = initSegment.byteRange {
                totalLength += Int64(byteRange.offset + byteRange.length)
            }

            for segment in mediaPlaylist.segments {
                if let byteRange = segment.byteRange {
                    let segmentEnd = byteRange.offset + byteRange.length
                    totalLength = max(totalLength, Int64(segmentEnd))
                }
            }

            contentRequest.contentLength = totalLength
        }
    }

    /// Data Request 처리
    private func handleDataRequest(
        _ dataRequest: AVAssetResourceLoadingDataRequest,
        url: URL
    ) async throws {
        // Custom scheme을 원래 scheme으로 복원
        let originalURL = restoreOriginalURL(url)

        // 요청된 바이트 범위로 세그먼트 데이터 가져오기
        let requestedOffset = Int(dataRequest.requestedOffset)
        let requestedLength = dataRequest.requestedLength
        let currentOffset = Int(dataRequest.currentOffset)

        // 바이트 범위로 어떤 세그먼트를 요청하는지 파악하고 세그먼트의 ByteRange offset 가져오기
        let (data, segmentByteRangeOffset) = try await fetchSegmentDataByRange(for: originalURL, offset: requestedOffset, length: requestedLength)

        // 세그먼트 데이터에서의 시작 위치 계산
        // data[0]은 파일의 segmentByteRangeOffset 위치에 해당
        // currentOffset부터 제공해야 하므로: currentOffset - segmentByteRangeOffset
        let dataStartOffset = currentOffset - segmentByteRangeOffset

        guard dataStartOffset >= 0 && dataStartOffset < data.count else {
            throw NSError(domain: "HLSResourceLoader", code: -4, userInfo: [
                NSLocalizedDescriptionKey: "Data offset out of bounds"
            ])
        }

        // 제공해야 할 데이터 길이 계산
        // requestedOffset부터 requestedLength만큼 요청했지만, currentOffset부터 제공
        let requestedEndOffset = requestedOffset + requestedLength
        let remainingLength = requestedEndOffset - currentOffset
        let endOffset = min(dataStartOffset + remainingLength, data.count)

        let subdata = data.subdata(in: dataStartOffset..<endOffset)
        dataRequest.respond(with: subdata)
    }

    /// 바이트 범위로 세그먼트 데이터 가져오기
    /// - Returns: (세그먼트 데이터, 세그먼트의 ByteRange offset)
    private func fetchSegmentDataByRange(for url: URL, offset: Int, length: Int) async throws -> (Data, Int) {
        guard let mediaPlaylist = mediaPlaylist else {
            throw NSError(domain: "HLSResourceLoader", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Media playlist not set"
            ])
        }

        let fileName = url.lastPathComponent

        // 플레이리스트 파일 자체 요청 (.m3u8)
        if fileName.hasSuffix(".m3u8") {
            guard let playlistContent = mediaPlaylistContent else {
                throw NSError(domain: "HLSResourceLoader", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Media playlist content not set"
                ])
            }
            return (playlistContent.data(using: .utf8) ?? Data(), 0)
        }

        // 초기화 세그먼트 확인 (offset 0부터 시작)
        if let initSegment = mediaPlaylist.initializationSegment,
           fileName == initSegment.uri,
           let byteRange = initSegment.byteRange,
           offset >= byteRange.offset && offset < byteRange.offset + byteRange.length {

            if let cachedData = initSegmentData {
                return (cachedData, byteRange.offset)
            }

            let data = try await downloadManager.downloadInitializationSegment()
            guard let data = data else {
                throw NSError(domain: "HLSResourceLoader", code: -2)
            }
            initSegmentData = data
            return (data, byteRange.offset)
        }

        // 미디어 세그먼트 찾기 (바이트 범위로 매칭)
        for segment in mediaPlaylist.segments {
            if segment.uri == fileName,
               let byteRange = segment.byteRange,
               offset >= byteRange.offset && offset < byteRange.offset + byteRange.length {

                // 캐시 확인
                if let cachedData = segmentCache[segment.index] {
                    return (cachedData, byteRange.offset)
                }

                // 다운로드
                let data = try await downloadManager.downloadSegment(at: segment.index)
                segmentCache[segment.index] = data
                return (data, byteRange.offset)
            }
        }

        throw NSError(domain: "HLSResourceLoader", code: -3, userInfo: [
            NSLocalizedDescriptionKey: "Segment not found for offset: \(offset)"
        ])
    }

    /// Custom scheme을 원래 scheme으로 복원
    private func restoreOriginalURL(_ url: URL) -> URL {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.scheme = "https"
        return components?.url ?? url
    }


    // MARK: - Cache Management

    /// 캐시 초기화
    func clearCache() {
        segmentCache.removeAll()
        initSegmentData = nil
    }
}
