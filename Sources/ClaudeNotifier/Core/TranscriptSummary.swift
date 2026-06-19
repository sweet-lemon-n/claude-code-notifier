import Foundation

struct TranscriptSummary {
    let pendingAction: String?
    let lastAction: String?
    let completionSummary: String?
    let elapsedSeconds: TimeInterval?
}

enum TranscriptSummarizer {
    static func summarize(path: String?) -> TranscriptSummary {
        guard let path, !path.isEmpty else {
            return TranscriptSummary(
                pendingAction: nil,
                lastAction: nil,
                completionSummary: nil,
                elapsedSeconds: nil
            )
        }

        let url = URL(fileURLWithPath: path)
        guard let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8) else {
            return TranscriptSummary(
                pendingAction: nil,
                lastAction: nil,
                completionSummary: nil,
                elapsedSeconds: nil
            )
        }

        let lines = text.split(separator: "\n", omittingEmptySubsequences: true)
        let recentLines = lines.suffix(300)
        var firstTimestamp: Date?
        var lastTimestamp: Date?
        var lastToolUse: String?
        var lastAssistantText: String?

        for line in recentLines {
            guard let jsonData = String(line).data(using: .utf8),
                  let item = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                continue
            }

            if let timestamp = parseTimestamp(item["timestamp"] as? String) {
                firstTimestamp = firstTimestamp ?? timestamp
                lastTimestamp = timestamp
            }

            guard let message = item["message"] as? [String: Any],
                  let content = message["content"] else { continue }

            if let blocks = content as? [[String: Any]] {
                for block in blocks {
                    switch block["type"] as? String {
                    case "tool_use":
                        lastToolUse = describeToolUse(block)
                    case "text":
                        if let text = cleanText(block["text"] as? String), !text.isEmpty {
                            lastAssistantText = text
                        }
                    default:
                        break
                    }
                }
            } else if let text = cleanText(content as? String), !text.isEmpty {
                lastAssistantText = text
            }
        }

        let elapsed: TimeInterval?
        if let firstTimestamp, let lastTimestamp {
            elapsed = max(0, lastTimestamp.timeIntervalSince(firstTimestamp))
        } else {
            elapsed = nil
        }

        return TranscriptSummary(
            pendingAction: lastToolUse,
            lastAction: lastToolUse,
            completionSummary: lastAssistantText,
            elapsedSeconds: elapsed
        )
    }

    private static func describeToolUse(_ block: [String: Any]) -> String? {
        let name = block["name"] as? String ?? "Tool"
        let input = block["input"] as? [String: Any] ?? [:]

        if let description = cleanText(input["description"] as? String), !description.isEmpty {
            return "\(name): \(description)"
        }
        if let command = cleanText(input["command"] as? String), !command.isEmpty {
            return "\(name): \(truncate(command, limit: 140))"
        }
        if let filePath = cleanText(input["file_path"] as? String), !filePath.isEmpty {
            return "\(name): \(filePath)"
        }
        if let path = cleanText(input["path"] as? String), !path.isEmpty {
            return "\(name): \(path)"
        }
        if let url = cleanText(input["url"] as? String), !url.isEmpty {
            return "\(name): \(url)"
        }

        return name
    }

    private static func cleanText(_ value: String?) -> String? {
        guard let value else { return nil }
        let collapsed = value
            .replacingOccurrences(of: "\r", with: "\n")
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return truncate(collapsed, limit: 180)
    }

    private static func truncate(_ value: String, limit: Int) -> String {
        guard value.count > limit else { return value }
        let index = value.index(value.startIndex, offsetBy: limit)
        return String(value[..<index]) + "..."
    }

    private static func parseTimestamp(_ value: String?) -> Date? {
        guard let value else { return nil }
        return isoFormatter.date(from: value)
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}
