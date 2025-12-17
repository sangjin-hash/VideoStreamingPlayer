//
//  DASHMPD.swift
//  ToyVideoStreamingPlayer
//
//  Created by 이상진 on 12/16/25.
//

import Foundation

/// DASH MPD (Media Presentation Description) 모델
struct DASHMPD {
    let baseURL: URL
    let type: PresentationType
    let mediaPresentationDuration: TimeInterval?
    let minBufferTime: TimeInterval
    let periods: [Period]

    enum PresentationType: String {
        case static_ = "static"
        case dynamic = "dynamic"
    }

    struct Period {
        let id: String?
        let duration: TimeInterval?
        let adaptationSets: [AdaptationSet]
    }

    struct AdaptationSet {
        let id: String?
        let contentType: String?
        let mimeType: String?
        let codecs: String?
        let representations: [Representation]
    }

    struct Representation {
        let id: String
        let bandwidth: Int
        let width: Int?
        let height: Int?
        let frameRate: String?
        let codecs: String?
        let mimeType: String?
        let segmentTemplate: SegmentTemplate?
        let segmentList: SegmentList?
        let baseURL: String?
    }

    struct SegmentTemplate {
        let initialization: String?
        let media: String?
        let timescale: Int?
        let duration: Int?
        let startNumber: Int?
    }

    struct SegmentList {
        let initialization: Initialization?
        let segments: [SegmentURL]
        let timescale: Int?
        let duration: Int?
    }

    struct Initialization {
        let sourceURL: String?
        let range: String?
    }

    struct SegmentURL {
        let media: String?
        let mediaRange: String?
    }
}

extension DASHMPD {
    /// 특정 bandwidth에 가장 가까운 Representation 선택
    func selectRepresentation(bandwidth: Int) -> Representation? {
        // 첫 번째 Period의 첫 번째 비디오 AdaptationSet에서 선택
        guard let period = periods.first else {
            return nil
        }

        // 비디오 AdaptationSet 찾기
        // 1. mimeType/contentType으로 찾기
        // 2. 없으면 width/height가 있는 Representation이 있는 AdaptationSet 찾기
        let videoAdaptationSet = period.adaptationSets.first(where: { adaptationSet in
            // mimeType이나 contentType에 "video"가 포함되어 있는지 확인
            if adaptationSet.mimeType?.contains("video") ?? false ||
               adaptationSet.contentType?.contains("video") ?? false {
                return true
            }

            // 없으면 width와 height가 0이 아닌 Representation이 있는지 확인
            return adaptationSet.representations.contains(where: { representation in
                (representation.width ?? 0) > 0 && (representation.height ?? 0) > 0
            })
        })

        guard let videoAdaptationSet = videoAdaptationSet else {
            return nil
        }

        // Bandwidth로 정렬하여 가장 가까운 것 선택
        let sorted = videoAdaptationSet.representations.sorted { $0.bandwidth < $1.bandwidth }

        // 요청한 bandwidth보다 작거나 같은 것 중 가장 큰 것
        if let selected = sorted.last(where: { $0.bandwidth <= bandwidth }) {
            return selected
        }

        // 없으면 가장 작은 것
        if let fallback = sorted.first {
            return fallback
        }

        return nil
    }

    /// Representation의 초기화 세그먼트 URL 생성
    func initializationURL(for representation: Representation) -> URL? {
        guard let template = representation.segmentTemplate,
              let initPattern = template.initialization else {
            return nil
        }

        let urlString = initPattern
            .replacingOccurrences(of: "$RepresentationID$", with: representation.id)
            .replacingOccurrences(of: "$Bandwidth$", with: "\(representation.bandwidth)")

        return URL(string: urlString, relativeTo: baseURL)
    }

    /// Representation의 미디어 세그먼트 URL 생성
    func mediaSegmentURL(for representation: Representation, segmentNumber: Int) -> URL? {
        guard let template = representation.segmentTemplate,
              let mediaPattern = template.media else {
            return nil
        }

        let urlString = mediaPattern
            .replacingOccurrences(of: "$RepresentationID$", with: representation.id)
            .replacingOccurrences(of: "$Bandwidth$", with: "\(representation.bandwidth)")
            .replacingOccurrences(of: "$Number$", with: "\(segmentNumber)")

        return URL(string: urlString, relativeTo: baseURL)
    }

    /// 전체 세그먼트 개수 계산
    func totalSegmentCount(for representation: Representation) -> Int? {
        guard let template = representation.segmentTemplate,
              let duration = template.duration,
              let timescale = template.timescale,
              let totalDuration = mediaPresentationDuration else {
            return nil
        }

        let segmentDuration = Double(duration) / Double(timescale)
        return Int(ceil(totalDuration / segmentDuration))
    }
}
