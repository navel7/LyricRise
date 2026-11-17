//
//  TranslationService.swift
//  LyricRise
//
//  Created by Avi Wadhwa on 2025-08-04.
//

import Translation
import NaturalLanguage
import OSLog

class TranslationService {
    static func translationTask(_ session: TranslationSession, request: [TranslationSession.Request]) async -> TranslationResult {
        do {
            return .success(try await session.translations(from: request))
        } catch {
            if Task.isCancelled || error is CancellationError {
                return .cancelled
            }
            if #available(macOS 26.0, *), TranslationError.alreadyCancelled ~= error {
                return .cancelled
            }

            switch error {
            case TranslationError.unableToIdentifyLanguage,
                 TranslationError.unsupportedSourceLanguage,
                 TranslationError.unsupportedLanguagePairing:
                // Only infer a source language when the session detected it automatically.
                guard session.sourceLanguage == nil, let source = findRealLanguage(for: request) else {
                    if session.sourceLanguage?.languageCode == session.targetLanguage?.languageCode,
                       session.sourceLanguage?.languageCode != nil {
                        return .notNeeded
                    }
                    return .failure
                }
                if source.languageCode == session.targetLanguage?.languageCode {
                    return .notNeeded
                }
                return .needsConfigUpdate(source)
            case TranslationError.unsupportedTargetLanguage, TranslationError.nothingToTranslate:
                return .failure
            default:
                if #available(macOS 26.0, *), TranslationError.notInstalled ~= error {
                    return .failure
                }
                let nsError = error as NSError
                Logger(subsystem: "com.navel7.LyricRise", category: "Translation")
                    .error("Translation failed: domain=\(nsError.domain, privacy: .public), code=\(nsError.code, privacy: .public)")
                return .failure
            }
        }
    }

    static private func findRealLanguage(for translationRequest: [TranslationSession.Request]) -> Locale.Language? {
        var langCount: [Locale.Language: Int] = [:]
        let recognizer = NLLanguageRecognizer()
        for lyric in translationRequest {
            recognizer.reset()
            recognizer.processString(lyric.sourceText)
            if let dominantLanguage = recognizer.dominantLanguage {
                let value: Locale.Language = .init(identifier: dominantLanguage.rawValue)
                if value != Locale.Language.systemLanguages.first! {
                    langCount[value, default: 0] += 1
                }
            }
        }
        if let lol =  langCount.sorted( by: { $1.value < $0.value}).first {
            if lol.value >= 3 {
                return lol.key
            }
        }
        return nil
    }
}
