import Foundation

/// A git host Kujto can provision against. GitHub is the golden path; GitLab
/// and Gitea are later adapters that conform to the same protocol, which is why
/// request building and response parsing both live behind it. The device-flow
/// client and the provisioner are provider-agnostic.
public protocol GitProvider: Sendable {
    var name: String { get }

    func deviceCodeRequest(scopes: [String]) -> HTTPRequest
    func tokenRequest(deviceCode: String) -> HTTPRequest
    func currentUserRequest(token: String) -> HTTPRequest
    func getRepoRequest(owner: String, name: String, token: String) -> HTTPRequest
    func createRepoRequest(name: String, isPrivate: Bool, token: String) -> HTTPRequest

    func parseDeviceCode(_ response: HTTPResponse) throws -> DeviceCodeGrant
    func parseToken(_ response: HTTPResponse) throws -> TokenPollResult
    func parseUserLogin(_ response: HTTPResponse) throws -> String
    /// Returns the repo, or nil for a 404 (not found), so the provisioner knows
    /// to create it. Any other non-success status throws.
    func parseRepo(_ response: HTTPResponse) throws -> RepoRef?
}

/// The GitHub adapter. The client id is a public device-flow identifier (not a
/// secret) injected at construction so builds and tests can supply their own.
public struct GitHubProvider: GitProvider {
    public let name = "github"
    private let clientID: String
    private let webBase: URL
    private let apiBase: URL

    public init(
        clientID: String,
        webBase: URL = URL(string: "https://github.com")!,
        apiBase: URL = URL(string: "https://api.github.com")!
    ) {
        self.clientID = clientID
        self.webBase = webBase
        self.apiBase = apiBase
    }

    // MARK: Requests

    public func deviceCodeRequest(scopes: [String]) -> HTTPRequest {
        let body = form(["client_id": clientID, "scope": scopes.joined(separator: " ")])
        return HTTPRequest(
            method: "POST",
            url: webBase.appendingPathComponent("login/device/code"),
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
            url: webBase.appendingPathComponent("login/oauth/access_token"),
            headers: ["Accept": "application/json", "Content-Type": "application/x-www-form-urlencoded"],
            body: body)
    }

    public func currentUserRequest(token: String) -> HTTPRequest {
        HTTPRequest(method: "GET", url: apiBase.appendingPathComponent("user"), headers: apiHeaders(token))
    }

    public func getRepoRequest(owner: String, name: String, token: String) -> HTTPRequest {
        HTTPRequest(
            method: "GET",
            url: apiBase.appendingPathComponent("repos/\(owner)/\(name)"),
            headers: apiHeaders(token))
    }

    public func createRepoRequest(name: String, isPrivate: Bool, token: String) -> HTTPRequest {
        let payload: [String: Any] = ["name": name, "private": isPrivate,
                                      "description": "Kujto Studio memory. Your rules, skills, and agents."]
        let body = try? JSONSerialization.data(withJSONObject: payload)
        return HTTPRequest(
            method: "POST",
            url: apiBase.appendingPathComponent("user/repos"),
            headers: apiHeaders(token).merging(["Content-Type": "application/json"]) { _, new in new },
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
        let expiresIn = json["expires_in"] as? Int ?? 900
        let interval = json["interval"] as? Int ?? 5
        return DeviceCodeGrant(deviceCode: deviceCode, userCode: userCode,
                               verificationURI: verificationURI, expiresIn: expiresIn, interval: interval)
    }

    public func parseToken(_ response: HTTPResponse) throws -> TokenPollResult {
        // GitHub returns 200 with either an access_token or an error field
        // during device flow.
        let json = try object(response)
        if let token = json["access_token"] as? String {
            return .authorized(token)
        }
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
        guard let login = json["login"] as? String else {
            throw AuthError.decoding("user response missing login")
        }
        return login
    }

    public func parseRepo(_ response: HTTPResponse) throws -> RepoRef? {
        if response.status == 404 { return nil }
        guard response.status == 200 || response.status == 201 else {
            throw AuthError.unexpectedStatus(response.status)
        }
        let json = try object(response)
        guard let fullName = json["full_name"] as? String,
              let httpsURL = json["clone_url"] as? String,
              let sshURL = json["ssh_url"] as? String else {
            throw AuthError.decoding("repo response missing fields")
        }
        let isPrivate = json["private"] as? Bool ?? true
        return RepoRef(fullName: fullName, httpsURL: httpsURL, sshURL: sshURL, isPrivate: isPrivate)
    }

    // MARK: Helpers

    private func apiHeaders(_ token: String) -> [String: String] {
        [
            "Accept": "application/vnd.github+json",
            "Authorization": "Bearer \(token)",
            "X-GitHub-Api-Version": "2022-11-28"
        ]
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
