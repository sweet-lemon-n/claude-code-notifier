import Foundation

/// Incoming JSON payload from the Claude Code hook, forwarded by notify.sh
struct HookPayload: Codable {
    let event: EventType
    let cwd: String?
    let message: String?
    let sessionId: String?
    let transcriptPath: String?

    enum CodingKeys: String, CodingKey {
        case event, cwd, message
        case sessionId = "session_id"
        case transcriptPath = "transcript_path"
    }
}
