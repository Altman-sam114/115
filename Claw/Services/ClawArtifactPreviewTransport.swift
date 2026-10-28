import Foundation

struct ClawArtifactPreviewWireRequest: Sendable {
    let url: URL
    let headers: [String: String]
    let body: Data

    static func make(_ request: ClawArtifactPreviewRequest, profile: ClawGatewayProfile, token: String) throws -> Self {
        guard ClawGatewayConfiguration.isValidToken(token),
              ClawMobileBridge.tokenFingerprint(for: token) == profile.tokenFingerprint,
              let endpoint = ClawGatewayConfiguration.validatedEndpoint(profile.endpoint),
              var url = URLComponents(string: endpoint) else { throw ClawArtifactPreviewError.configuration }
        url.scheme = url.scheme == "wss" ? "https" : "http"
        url.path = "/claw/artifacts/preview"
        guard let target = url.url else { throw ClawArtifactPreviewError.configuration }
        return try Self(url: target, headers: ["Authorization": "Bearer \(token)", "Content-Type": "application/json",
            "X-Claw-Control-Plane": ClawArtifactPreviewRequest.controlPlane], body: request.encodedData())
    }
}

protocol ClawArtifactPreviewTransport: Sendable {
    func response(for request: ClawArtifactPreviewWireRequest) async throws -> Data
}

private final class ClawPreviewNoRedirectDelegate: NSObject, URLSessionTaskDelegate, Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

struct URLSessionClawArtifactPreviewTransport: ClawArtifactPreviewTransport {
    func response(for wire: ClawArtifactPreviewWireRequest) async throws -> Data {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 5
        configuration.timeoutIntervalForResource = 8
        configuration.httpShouldSetCookies = false
        configuration.httpCookieStorage = nil
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        let session = URLSession(configuration: configuration, delegate: ClawPreviewNoRedirectDelegate(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        var request = URLRequest(url: wire.url)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = wire.headers
        request.httpBody = wire.body
        do {
            let (bytes, response) = try await session.bytes(for: request)
            guard let response = response as? HTTPURLResponse,
                  [200, 400, 401, 404, 413].contains(response.statusCode), response.mimeType == "application/json",
                  response.expectedContentLength <= 262_144 else { throw ClawArtifactPreviewError.invalidResponse }
            var data = Data()
            for try await byte in bytes {
                try Task.checkCancellation()
                guard data.count < 262_144 else { throw ClawArtifactPreviewError.invalidResponse }
                data.append(byte)
            }
            try Task.checkCancellation()
            return data
        } catch let error as URLError where error.code == .timedOut {
            throw ClawArtifactPreviewError.timeout
        }
    }
}
