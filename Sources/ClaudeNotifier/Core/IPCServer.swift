import Foundation
import Network

/// A minimal embedded HTTP server that listens on 127.0.0.1 for IPC from notify.sh.
///
/// Endpoints:
///   POST /event  — body: JSON HookPayload  → dispatches to onEvent
///   GET  /ping   — health check, returns "pong"
///
/// When started with port 0 the OS assigns a free ephemeral port,
/// which is written to ~/.claude/claude-notifier-port so notify.sh
/// knows where to reach us.
final class IPCServer {
    private var listener: NWListener?
    private var actualPort: UInt16 = 0
    private let portFilePath: String
    private let onEvent: (EventType, HookPayload) -> Void

    init?(preferredPort: UInt16 = 0,
          portFilePath: String? = nil,
          onEvent: @escaping (EventType, HookPayload) -> Void) {

        self.onEvent = onEvent

        let home = NSHomeDirectory()
        let claudeDir = "\(home)/.claude"
        self.portFilePath = portFilePath ?? "\(claudeDir)/claude-notifier-port"

        // Ensure ~/.claude exists
        try? FileManager.default.createDirectory(
            atPath: claudeDir, withIntermediateDirectories: true
        )

        // Bind to 127.0.0.1 with the requested port (0 = OS-assigned)
        let params = NWParameters.tcp
        params.requiredLocalEndpoint = NWEndpoint.hostPort(
            host: .ipv4(.loopback),
            port: NWEndpoint.Port(rawValue: preferredPort) ?? NWEndpoint.Port(rawValue: 19999)!
        )
        params.allowLocalEndpointReuse = true

        guard let listener = try? NWListener(using: params) else { return nil }
        self.listener = listener

        setupHandlers()
    }

    deinit { stop() }

    // MARK: - Start / Stop

    func start() {
        listener?.start(queue: .global(qos: .utility))

        // The listener needs a moment to bind; then we can read the OS-assigned port.
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self else { return }
            // NWListener.currentPort (available from macOS 13) returns the bound port.
            if let port = self.listener?.port?.rawValue {
                self.actualPort = port
            }
            self.writePortFile()
            print("[CodeNotifier] IPC server listening on 127.0.0.1:\(self.actualPort)")
        }
    }

    func stop() {
        listener?.cancel()
        removePortFile()
    }

    // MARK: - Private

    private func setupHandlers() {
        listener?.newConnectionHandler = { [weak self] connection in
            connection.start(queue: .global(qos: .utility))
            self?.receive(on: connection)
        }
        listener?.stateUpdateHandler = { state in
            switch state {
            case .failed(let error):
                print("[CodeNotifier] IPC server error: \(error)")
            default:
                break
            }
        }
    }

    private func receive(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) {
            [weak self] data, _, isComplete, error in
            if let error {
                print("[CodeNotifier] Receive error: \(error)")
                connection.cancel()
                return
            }
            if let data, !data.isEmpty {
                self?.handle(data: data, connection: connection)
            }
            if isComplete {
                connection.cancel()
            } else if error == nil {
                self?.receive(on: connection)
            }
        }
    }

    private func handle(data: Data, connection: NWConnection) {
        guard let request = String(data: data, encoding: .utf8) else {
            send(httpResponse(status: 400, body: "Bad Request"), on: connection)
            return
        }
        let lines = request.components(separatedBy: "\r\n")
        guard let firstLine = lines.first else {
            send(httpResponse(status: 400, body: "Bad Request"), on: connection)
            return
        }
        let parts = firstLine.components(separatedBy: " ")
        guard parts.count >= 2 else {
            send(httpResponse(status: 400, body: "Bad Request"), on: connection)
            return
        }
        let method = parts[0]
        let path = parts[1]

        var body: String?
        if let bodyStart = request.range(of: "\r\n\r\n")?.upperBound {
            body = String(request[bodyStart...])
        }

        switch (method, path) {
        case ("GET", "/ping"):
            send(httpResponse(status: 200, body: "pong"), on: connection)
        case ("POST", "/event"):
            handleEvent(body: body, connection: connection)
        default:
            send(httpResponse(status: 404, body: "Not Found"), on: connection)
        }
    }

    private func handleEvent(body: String?, connection: NWConnection) {
        guard let body,
              let jsonData = body.data(using: .utf8),
              let payload = try? JSONDecoder().decode(HookPayload.self, from: jsonData)
        else {
            send(httpResponse(status: 400, body: "Invalid JSON"), on: connection)
            return
        }
        DispatchQueue.main.async { [weak self] in
            self?.onEvent(payload.event, payload)
        }
        send(httpResponse(status: 200, body: "ok"), on: connection)
    }

    private func send(_ response: Data, on connection: NWConnection) {
        connection.send(content: response, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private func httpResponse(status: Int, body: String) -> Data {
        let reason: String = {
            switch status {
            case 200: return "OK"
            case 400: return "Bad Request"
            case 404: return "Not Found"
            default:  return "Error"
            }
        }()
        let content = """
        HTTP/1.1 \(status) \(reason)\r
        Content-Type: text/plain; charset=utf-8\r
        Content-Length: \(body.utf8.count)\r
        Connection: close\r
        \r
        \(body)
        """
        return content.data(using: .utf8) ?? Data()
    }

    // MARK: - Port file

    private func writePortFile() {
        try? "\(actualPort)".write(toFile: portFilePath, atomically: true, encoding: .utf8)
    }

    private func removePortFile() {
        try? FileManager.default.removeItem(atPath: portFilePath)
    }
}
