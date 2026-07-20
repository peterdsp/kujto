import Foundation

/// The GitLab adapter. GitLab supports OAuth device flow at `/oauth`, and its
/// REST v4 API uses different field names than GitHub (`username`,
/// `path_with_namespace`, `visibility`, `http_url_to_repo`), so it needs its
/// own parsers. Works against gitlab.com or a self-hosted base URL.
public struct GitLabProvider: GitProvider {
    public let name = "gitlab"
    private let clientID: String
    private let base: URL

    public init(clientID: String, base: URL = URL(string: "https://gitlab.com")!) {
        self.clientID = clientID
        self.base = base
    }

    private var api: URL { base.appendingPathComponent("api/v4") }

    // MARK: Requests

    public func deviceCodeRequest(scopes: [String]) -> HTTPRequest {
        let body = form(["client_id": clientID, "scope": scopes.joined(separator: " ")])
        return HTTPRequest(
            method: "POST",
            url: base.appendingPathComponent("oauth/authorize_device"),
            headers: ["Accept": "application/json", "Content-Type": "application/x-www-form-urlencoded"],
            body: body)
    }

    public func tokenRequest(deviceCode: String) -> HTTPRequest {
        let body = form([
            "client_id": clientID,
            "device_code": deviceCode,
            "grant_type": "urn:ietf:params:oauth:grant-type:device_code"
        ])
        return HTTPRequest(
            method: "POST",
            url: base.appendingPathComponent("oauth/token"),
            headers: ["Accept": "application/json", "Content-Type": "application/x-www-form-urlencoded"],
            body: body)
    }

    public func currentUserRequest(token: String) -> HTTPRequest {
        HTTPRequest(method: "GET", url: api.appendingPathComponent("user"), headers: auth(token))
    }

    public func getRepoRequest(owner: String, name: String, token: String) -> HTTPRequest {
        // GitLab addresses a project by `owner/name` with only the slash
        // percent-encoded. Build the URL from a string so the `%2F` is not
        // double-encoded (which `appendingPathComponent` would do).
        let url = URL(string: "\(api.absoluteString)/projects/\(owner)%2F\(name)")!
        return HTTPRequest(method: "GET", url: url, headers: auth(token))
    }

    public func createRepoRequest(name: String, isPrivate: Bool, token: String) -> HTTPRequest {
        let payload: [String: Any] = ["name": name, "visibility": isPrivate ? "private" : "public"]
        let body = try? JSONSerialization.data(withJSONObject: payload)
        return HTTPRequest(
            method: "POST",
            url: api.appendingPathComponent("projects"),
            headers: auth(token).merging(["Content-Type": "application/json"]) { _, new in new },
            body: body)
    }

    // MARK: Parsers

    public func parseDeviceCode(_ response: HTTPResponse) throws -> DeviceCodeGrant {
        guard response.status == 200 else { throw AuthError.unexpectedStatus(response.status) }
        let json = try object(response)
        guard let deviceCode = json["device_code"] as? String,
              let userCode = json["user_code"] as? String,
              let verificationURI = json["verification_uri"] as? String else {
            throw AuthError.decoding("device code response missing fields")
        }
        return DeviceCodeGrant(deviceCode: deviceCode, userCode: userCode,
                               verificationURI: verificationURI,
                               expiresIn: json["expires_in"] as? Int ?? 900,
                               interval: json["interval"] as? Int ?? 5)
    }

    public func parseToken(_ response: HTTPResponse) throws -> TokenPollResult {
        let json = try object(response)
        if let token = json["access_token"] as? String { return .authorized(token) }
        guard let error = json["error"] as? String else {
            throw AuthError.decoding("token response has neither access_token nor error")
        }
        switch error {
        case "authorization_pending": return .pending
        case "slow_down": return .slowDown
        case "expired_token": return .expired
        case "access_denied": return .denied
        default: return .error(error)
        }
    }

    public func parseUserLogin(_ response: HTTPResponse) throws -> String {
        guard response.status == 200 else { throw AuthError.unexpectedStatus(response.status) }
        let json = try object(response)
        guard let username = json["username"] as? String else {
            throw AuthError.decoding("user response missing username")
        }
        return username
    }

    public func parseRepo(_ response: HTTPResponse) throws -> RepoRef? {
        if response.status == 404 { return nil }
        guard response.status == 200 || response.status == 201 else {
            throw AuthError.unexpectedStatus(response.status)
        }
        let json = try object(response)
        guard let fullName = json["path_with_namespace"] as? String,
              let httpsURL = json["http_url_to_repo"] as? String,
              let sshURL = json["ssh_url_to_repo"] as? String else {
            throw AuthError.decoding("project response missing fields")
        }
        let isPrivate = (json["visibility"] as? String ?? "private") != "public"
        return RepoRef(fullName: fullName, httpsURL: httpsURL, sshURL: sshURL, isPrivate: isPrivate)
    }

    // MARK: Helpers

    private func auth(_ token: String) -> [String: String] {
        ["Accept": "application/json", "Authorization": "Bearer \(token)"]
    }

    private func form(_ fields: [String: String]) -> Data {
        var components = URLComponents()
        components.queryItems = fields.map { URLQueryItem(name: $0.key, value: $0.value) }
        return (components.percentEncodedQuery ?? "").data(using: .utf8) ?? Data()
    }

    private func object(_ response: HTTPResponse) throws -> [String: Any] {
        guard let json = try? JSONSerialization.jsonObject(with: response.body) as? [String: Any] else {
            throw AuthError.decoding("body is not a JSON object")
        }
        return json
    }
}
