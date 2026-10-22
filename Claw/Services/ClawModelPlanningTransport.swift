import Foundation

struct ClawModelPlanningWireRequest: Sendable {
    let url: URL
    let headers: [String: String]
    let body: Data

    static func make(_ request: ClawModelPlanningRequest, profile: ClawGatewayProfile, token: String) throws -> Self {
        guard ClawGatewayConfiguration.isValidToken(token),
              ClawMobileBridge.tokenFingerprint(for: token) == profile.tokenFingerprint,
              let endpoint = ClawGatewayConfiguration.validatedEndpoint(profile.endpoint),
              var url = URLComponents(string: endpoint) else { throw ClawModelPlanningError.configuration }
        url.scheme = url.scheme == "wss" ? "https" : "http"
        url.path = "/claw/planning"
        guard let target = url.url else { throw ClawModelPlanningError.configuration }
        return try Self(url: target, headers: ["Authorization": "Bearer \(token)", "Content-Type": "application/json",
            "X-Claw-Control-Plane": ClawModelPlanningRequest.controlPlane], body: request.encodedData())
    }
}

protocol ClawModelPlanningTransport: Sendable {
    func response(for request: ClawModelPlanningWireRequest) async throws -> Data
}

private final class ClawPlanningNoRedirectDelegate: NSObject, URLSessionTaskDelegate, Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

struct URLSessionClawModelPlanningTransport: ClawModelPlanningTransport {
    func response(for wire: ClawModelPlanningWireRequest) async throws -> Data {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 35
        configuration.timeoutIntervalForResource = 40
        configuration.httpShouldSetCookies = false
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        let session = URLSession(configuration: configuration, delegate: ClawPlanningNoRedirectDelegate(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        var request = URLRequest(url: wire.url)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = wire.headers
        request.httpBody = wire.body
        do {
            let (bytes, response) = try await session.bytes(for: request)
            guard let response = response as? HTTPURLResponse,
                  [200, 400, 401, 409, 413, 422, 429, 502, 503, 504].contains(response.statusCode),
                  response.mimeType == "application/json",
                  response.expectedContentLength <= 65_536 else { throw ClawModelPlanningError.invalidResponse }
            var data = Data()
            for try await byte in bytes {
                try Task.checkCancellation()
                guard data.count < 65_536 else { throw ClawModelPlanningError.invalidResponse }
                data.append(byte)
            }
            try Task.checkCancellation()
            return data
        } catch let error as URLError where error.code == .timedOut {
            throw ClawModelPlanningError.timeout
        }
    }
}
