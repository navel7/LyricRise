//
//  UpdaterService.swift
//  LyricRise
//
//  Created by Avi Wadhwa on 2025-07-26.
//

import Foundation
import Observation
import OSLog

@MainActor
@Observable
final class UpdaterService {
    enum Status: Equatable {
        case idle, checking, upToDate, unavailable
        case available(version: String, url: URL)
    }

    private struct Release: Decodable {
        let tag_name: String
    }

    private(set) var status: Status = .idle
    private let releasesURL = URL(string: "https://github.com/navel7/LyricRise/releases")!
    private let latestReleaseAPI = URL(string: "https://api.github.com/repos/navel7/LyricRise/releases/latest")!
    private let logger = Logger(subsystem: "com.navel7.LyricRise", category: "Updates")

    func monitorUpdates() async {
        while !Task.isCancelled {
            do {
                try await Task.sleep(for: .seconds(6 * 60 * 60))
            } catch {
                return
            }
            await checkForUpdates()
        }
    }

    func checkForUpdates() async {
        guard status != .checking else { return }
        let previousStatus = status
        status = .checking

        do {
            var request = URLRequest(url: latestReleaseAPI, timeoutInterval: 15)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            let (data, response) = try await URLSession.shared.data(for: request)
            try Task.checkCancellation()
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }
            let tag = try JSONDecoder().decode(Release.self, from: data).tag_name
            let version = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
            guard let installed = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                  version.range(of: #"^[0-9]+\.[0-9]+\.[0-9]+$"#, options: .regularExpression) != nil
            else { throw URLError(.cannotParseResponse) }

            status = version.compare(installed, options: .numeric) == .orderedDescending
                ? .available(version: version, url: releasesURL.appending(path: "tag").appending(path: tag))
                : .upToDate
        } catch {
            if Task.isCancelled {
                status = previousStatus
            } else {
                logger.error("Release check failed: \(String(describing: error), privacy: .private)")
                if case .available = previousStatus {
                    status = previousStatus
                } else {
                    status = .unavailable
                }
            }
        }
    }
}
