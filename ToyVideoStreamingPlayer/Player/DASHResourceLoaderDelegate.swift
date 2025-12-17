//
//  DASHResourceLoaderDelegate.swift
//  ToyVideoStreamingPlayer
//
//  Created by 이상진 on 12/16/25.
//

import Foundation
import AVFoundation

/// AVAssetResourceLoader Delegate for DASH - 세그먼트를 직접 로드하여 제공
class DASHResourceLoaderDelegate: NSObject, AVAssetResourceLoaderDelegate {

    // MARK: - Properties

    private let customScheme = "custom-dash"
    private let mpd: DASHMPD
    private let representation: DASHMPD.Representation
    private let virtualPlaylist: String

    // MARK: - Initialization

    init(mpd: DASHMPD, representation: DASHMPD.Representation, virtualPlaylist: String) {
        self.mpd = mpd
        self.representation = representation
        self.virtualPlaylist = virtualPlaylist
        super.init()
    }

    // MARK: - AVAssetResourceLoaderDelegate

    func resourceLoader(
        _ resourceLoader: AVAssetResourceLoader,
        shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest
    ) -> Bool {
        guard let url = loadingRequest.request.url else {
            loadingRequest.finishLoading(with: NSError(domain: "DASHResourceLoader", code: -1))
            return false
        }

        handleLoadingRequest(loadingRequest, url: url)

        return true
    }

    // MARK: - Private Methods

    private func handleLoadingRequest(_ loadingRequest: AVAssetResourceLoadingRequest, url: URL) {
        do {
            let urlString = url.absoluteString

            if urlString.hasSuffix("manifest.m3u8") {
                // 가상 HLS 플레이리스트
                loadManifest(loadingRequest)
            } else if urlString.contains("init") {
                // 초기화 세그먼트
                try loadInitializationSegment(loadingRequest, url: url)
            } else {
                // 미디어 세그먼트
                try loadMediaSegment(loadingRequest, url: url)
            }
        } catch {
            loadingRequest.finishLoading(with: error as NSError)
        }
    }

    private func loadManifest(_ loadingRequest: AVAssetResourceLoadingRequest) {
        guard let data = virtualPlaylist.data(using: .utf8) else {
            loadingRequest.finishLoading(with: NSError(domain: "DASHResourceLoader", code: -7))
            return
        }

        if let contentRequest = loadingRequest.contentInformationRequest {
            contentRequest.contentType = "application/x-mpegURL"
            contentRequest.isByteRangeAccessSupported = false
            contentRequest.contentLength = Int64(data.count)
        }

        if let dataRequest = loadingRequest.dataRequest {
            dataRequest.respond(with: data)
        }

        loadingRequest.finishLoading()
    }

    private func loadInitializationSegment(_ loadingRequest: AVAssetResourceLoadingRequest, url: URL) throws {
        // URL 경로 추출 - manifest.m3u8가 경로에 포함되어 있으면 제거
        var path = url.path
        if path.hasPrefix("/manifest.m3u8/") {
            path = String(path.dropFirst("/manifest.m3u8/".count))
        } else if path.hasPrefix("/") {
            path = String(path.dropFirst())
        } else if path.isEmpty {
            path = url.host ?? ""
        }

        // MPD baseURL과 결합하여 실제 URL 생성
        let initURL = URL(string: path, relativeTo: mpd.baseURL.deletingLastPathComponent())!

        // 302 리다이렉트 응답 반환 (데이터 직접 제공하지 않음)
        loadingRequest.redirect = URLRequest(url: initURL)
        loadingRequest.response = HTTPURLResponse(
            url: initURL,
            statusCode: 302,
            httpVersion: "HTTP/1.1",
            headerFields: ["Location": initURL.absoluteString]
        )

        loadingRequest.finishLoading()
    }

    private func loadMediaSegment(_ loadingRequest: AVAssetResourceLoadingRequest, url: URL) throws {
        // URL 경로 추출 - manifest.m3u8가 경로에 포함되어 있으면 제거
        var path = url.path
        if path.hasPrefix("/manifest.m3u8/") {
            path = String(path.dropFirst("/manifest.m3u8/".count))
        } else if path.hasPrefix("/") {
            path = String(path.dropFirst())
        } else if path.isEmpty {
            path = url.host ?? ""
        }

        // MPD baseURL과 결합하여 실제 URL 생성
        let mediaURL = URL(string: path, relativeTo: mpd.baseURL.deletingLastPathComponent())!

        // 302 리다이렉트 응답 반환
        loadingRequest.redirect = URLRequest(url: mediaURL)
        loadingRequest.response = HTTPURLResponse(
            url: mediaURL,
            statusCode: 302,
            httpVersion: "HTTP/1.1",
            headerFields: ["Location": mediaURL.absoluteString]
        )

        loadingRequest.finishLoading()
    }
}
