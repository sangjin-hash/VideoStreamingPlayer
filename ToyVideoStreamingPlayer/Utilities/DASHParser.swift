//
//  DASHParser.swift
//  ToyVideoStreamingPlayer
//
//  Created by 이상진 on 12/16/25.
//

import Foundation

/// DASH MPD XML Parser
class DASHParser: NSObject {

    // MARK: - Error Types

    enum ParsingError: LocalizedError {
        case invalidXML
        case missingRequiredAttribute(String)
        case unsupportedFormat

        var errorDescription: String? {
            switch self {
            case .invalidXML:
                return "Invalid MPD XML format"
            case .missingRequiredAttribute(let attr):
                return "Missing required attribute: \(attr)"
            case .unsupportedFormat:
                return "Unsupported MPD format"
            }
        }
    }

    // MARK: - Properties

    private var currentElement: String = ""
    private var baseURL: URL?

    // MPD attributes
    private var mpdType: DASHMPD.PresentationType = .static_
    private var mediaPresentationDuration: TimeInterval?
    private var minBufferTime: TimeInterval = 0

    // Parsing state
    private var periods: [DASHMPD.Period] = []
    private var currentPeriod: PeriodBuilder?
    private var currentAdaptationSet: AdaptationSetBuilder?
    private var currentRepresentation: RepresentationBuilder?

    // MARK: - Helper Builders

    private class PeriodBuilder {
        var id: String?
        var duration: TimeInterval?
        var adaptationSets: [DASHMPD.AdaptationSet] = []

        func build() -> DASHMPD.Period {
            DASHMPD.Period(
                id: id,
                duration: duration,
                adaptationSets: adaptationSets
            )
        }
    }

    private class AdaptationSetBuilder {
        var id: String?
        var contentType: String?
        var mimeType: String?
        var codecs: String?
        var representations: [DASHMPD.Representation] = []

        func build() -> DASHMPD.AdaptationSet {
            DASHMPD.AdaptationSet(
                id: id,
                contentType: contentType,
                mimeType: mimeType,
                codecs: codecs,
                representations: representations
            )
        }
    }

    private class RepresentationBuilder {
        var id: String = ""
        var bandwidth: Int = 0
        var width: Int?
        var height: Int?
        var frameRate: String?
        var codecs: String?
        var mimeType: String?
        var segmentTemplate: DASHMPD.SegmentTemplate?
        var segmentList: DASHMPD.SegmentList?
        var baseURL: String?

        func build() -> DASHMPD.Representation {
            DASHMPD.Representation(
                id: id,
                bandwidth: bandwidth,
                width: width,
                height: height,
                frameRate: frameRate,
                codecs: codecs,
                mimeType: mimeType,
                segmentTemplate: segmentTemplate,
                segmentList: segmentList,
                baseURL: baseURL
            )
        }
    }

    // MARK: - Public Methods

    /// MPD XML 문자열을 파싱
    func parse(_ xmlString: String, baseURL: URL) throws -> DASHMPD {
        self.baseURL = baseURL
        reset()

        guard let data = xmlString.data(using: .utf8) else {
            throw ParsingError.invalidXML
        }

        let parser = XMLParser(data: data)
        parser.delegate = self

        guard parser.parse() else {
            throw ParsingError.invalidXML
        }

        guard !periods.isEmpty else {
            throw ParsingError.unsupportedFormat
        }

        return DASHMPD(
            baseURL: baseURL,
            type: mpdType,
            mediaPresentationDuration: mediaPresentationDuration,
            minBufferTime: minBufferTime,
            periods: periods
        )
    }

    // MARK: - Private Methods

    private func reset() {
        periods = []
        currentPeriod = nil
        currentAdaptationSet = nil
        currentRepresentation = nil
        mpdType = .static_
        mediaPresentationDuration = nil
        minBufferTime = 0
    }

    private func parseDuration(_ durationString: String) -> TimeInterval? {
        // ISO 8601 duration format: PT#H#M#S
        var duration: TimeInterval = 0
        var numberString = ""

        for char in durationString {
            if char.isNumber || char == "." {
                numberString.append(char)
            } else if char == "H" {
                if let hours = Double(numberString) {
                    duration += hours * 3600
                }
                numberString = ""
            } else if char == "M" {
                if let minutes = Double(numberString) {
                    duration += minutes * 60
                }
                numberString = ""
            } else if char == "S" {
                if let seconds = Double(numberString) {
                    duration += seconds
                }
                numberString = ""
            }
        }

        return duration > 0 ? duration : nil
    }
}

// MARK: - XMLParserDelegate

extension DASHParser: XMLParserDelegate {

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes attributeDict: [String: String] = [:]) {

        currentElement = elementName

        switch elementName {
        case "MPD":
            if let typeStr = attributeDict["type"] {
                mpdType = DASHMPD.PresentationType(rawValue: typeStr) ?? .static_
            }

            if let durationStr = attributeDict["mediaPresentationDuration"] {
                mediaPresentationDuration = parseDuration(durationStr)
            }

            if let bufferTimeStr = attributeDict["minBufferTime"] {
                minBufferTime = parseDuration(bufferTimeStr) ?? 0
            }

        case "Period":
            currentPeriod = PeriodBuilder()
            currentPeriod?.id = attributeDict["id"]

            if let durationStr = attributeDict["duration"] {
                currentPeriod?.duration = parseDuration(durationStr)
            }

        case "AdaptationSet":
            currentAdaptationSet = AdaptationSetBuilder()
            currentAdaptationSet?.id = attributeDict["id"]
            currentAdaptationSet?.contentType = attributeDict["contentType"]
            currentAdaptationSet?.mimeType = attributeDict["mimeType"]
            currentAdaptationSet?.codecs = attributeDict["codecs"]

        case "Representation":
            currentRepresentation = RepresentationBuilder()
            currentRepresentation?.id = attributeDict["id"] ?? ""
            currentRepresentation?.bandwidth = Int(attributeDict["bandwidth"] ?? "0") ?? 0
            currentRepresentation?.width = attributeDict["width"].flatMap { Int($0) }
            currentRepresentation?.height = attributeDict["height"].flatMap { Int($0) }
            currentRepresentation?.frameRate = attributeDict["frameRate"]
            currentRepresentation?.codecs = attributeDict["codecs"]
            currentRepresentation?.mimeType = attributeDict["mimeType"]

        case "SegmentTemplate":
            let template = DASHMPD.SegmentTemplate(
                initialization: attributeDict["initialization"],
                media: attributeDict["media"],
                timescale: attributeDict["timescale"].flatMap { Int($0) },
                duration: attributeDict["duration"].flatMap { Int($0) },
                startNumber: attributeDict["startNumber"].flatMap { Int($0) }
            )
            currentRepresentation?.segmentTemplate = template

        case "BaseURL":
            break

        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if currentElement == "BaseURL" {
            currentRepresentation?.baseURL = trimmed
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?) {

        switch elementName {
        case "Representation":
            if let representation = currentRepresentation?.build() {
                currentAdaptationSet?.representations.append(representation)
            }
            currentRepresentation = nil

        case "AdaptationSet":
            if let adaptationSet = currentAdaptationSet?.build() {
                currentPeriod?.adaptationSets.append(adaptationSet)
            }
            currentAdaptationSet = nil

        case "Period":
            if let period = currentPeriod?.build() {
                periods.append(period)
            }
            currentPeriod = nil

        default:
            break
        }

        currentElement = ""
    }
}

