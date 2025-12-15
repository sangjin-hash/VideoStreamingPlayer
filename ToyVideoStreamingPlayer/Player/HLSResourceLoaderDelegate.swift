//
//  HLSResourceLoaderDelegate.swift
//  ToyVideoStreamingPlayer
//
//  Created by 이상진 on 12/10/25.
//

import Foundation
import AVFoundation

/// AVAssetResourceLoader Delegate - 리다이렉트를 통해 AVPlayer가 직접 처리하도록 함
class HLSResourceLoaderDelegate: NSObject, AVAssetResourceLoaderDelegate {

    // MARK: - Properties

    private let customScheme = "custom-hls"

    // 현재 Media Playlist
    private var mediaPlaylistContent: String?

    // MARK: - Initialization

    override init() {
        super.init()
    }

    // MARK: - Public Methods

    /// Media Playlist 안 Video Segment URL 상대 주소를
    /// 커스텀 스킴으로 적용된 절대 주소로 변경
    func setMediaPlaylist(_ playlist: HLSMediaPlaylist, content: String) {
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

        handleLoadingRequest(loadingRequest, url: url)
        return true
    }

    // MARK: - Private Methods

    /// 로딩 요청 처리 - 302 리다이렉트로 AVPlayer가 직접 처리하도록 함(선택적 로드)
    private func handleLoadingRequest(_ loadingRequest: AVAssetResourceLoadingRequest, url: URL) {
        let fileName = url.lastPathComponent

        // 플레이리스트 파일인 경우 직접 제공
        if fileName.hasSuffix(".m3u8") {
            if let playlistContent = mediaPlaylistContent,
               let data = playlistContent.data(using: .utf8) {

                if let contentRequest = loadingRequest.contentInformationRequest {
                    contentRequest.contentType = "application/x-mpegURL"
                    contentRequest.isByteRangeAccessSupported = false
                    contentRequest.contentLength = Int64(data.count)
                }

                if let dataRequest = loadingRequest.dataRequest {
                    dataRequest.respond(with: data)
                }

                loadingRequest.finishLoading()
            } else {
                loadingRequest.finishLoading(with: NSError(domain: "HLSResourceLoader", code: -1))
            }
        } else {
            // 비디오 세그먼트인 경우 원본 URL로 302 리다이렉트
            let originalURL = restoreOriginalURL(url)

            loadingRequest.redirect = URLRequest(url: originalURL)
            loadingRequest.response = HTTPURLResponse(
                url: originalURL,
                statusCode: 302,
                httpVersion: "HTTP/1.1",
                headerFields: ["Location": originalURL.absoluteString]
            )

            loadingRequest.finishLoading()
        }
    }

    /// Custom scheme을 원래 scheme으로 복원
    private func restoreOriginalURL(_ url: URL) -> URL {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.scheme = "https"
        return components?.url ?? url
    }
}
