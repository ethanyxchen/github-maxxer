import Foundation

public struct DeviceAuthorization: Sendable {
  public let userCode: String
  public let verificationURL: URL
  fileprivate let expiresAt: Date
  fileprivate let deviceCode: String
  fileprivate let interval: TimeInterval
}

public struct GitHubOAuth: Sendable {
  private let clientID: String
  private let send: @Sendable (URLRequest) async throws -> (Data, HTTPURLResponse)
  private let now: @Sendable () -> Date
  private let sleep: @Sendable (TimeInterval) async throws -> Void

  public init(clientID: String, session: URLSession = URLSession(configuration: .ephemeral)) {
    self.init(
      clientID: clientID,
      send: { request in
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else {
          throw GitHubOAuthError.invalidResponse
        }
        return (data, response)
      })
  }

  init(
    clientID: String,
    send: @escaping @Sendable (URLRequest) async throws -> (Data, HTTPURLResponse),
    now: @escaping @Sendable () -> Date = { .now },
    sleep: @escaping @Sendable (TimeInterval) async throws -> Void = {
      try await Task.sleep(for: .seconds($0))
    }
  ) {
    self.clientID = clientID.trimmingCharacters(in: .whitespacesAndNewlines)
    self.send = send
    self.now = now
    self.sleep = sleep
  }

  public func startAuthorization(includePrivateRepositories: Bool) async throws
    -> DeviceAuthorization
  {
    let response = try await request(
      path: "device/code",
      fields: [
        "scope": includePrivateRepositories ? "read:user read:org repo" : "read:user read:org"
      ])
    guard let code = response.deviceCode, !code.isEmpty,
      let userCode = response.userCode, !userCode.isEmpty,
      let verificationURL = response.verificationUri,
      verificationURL.absoluteString == "https://github.com/login/device",
      let expiresIn = response.expiresIn, expiresIn > 0,
      let interval = response.interval, interval > 0, interval < expiresIn
    else { throw GitHubOAuthError.invalidResponse }
    return DeviceAuthorization(
      userCode: userCode, verificationURL: verificationURL,
      expiresAt: now().addingTimeInterval(expiresIn), deviceCode: code, interval: interval)
  }

  public func waitForToken(_ authorization: DeviceAuthorization) async throws -> String {
    var interval = authorization.interval
    while true {
      try Task.checkCancellation()
      guard now().addingTimeInterval(interval) < authorization.expiresAt else {
        throw GitHubOAuthError.expired
      }
      try await sleep(interval)
      try Task.checkCancellation()
      guard now() < authorization.expiresAt else { throw GitHubOAuthError.expired }
      let response = try await request(
        path: "oauth/access_token",
        fields: [
          "device_code": authorization.deviceCode,
          "grant_type": "urn:ietf:params:oauth:grant-type:device_code",
        ])
      switch response.error {
      case "authorization_pending": continue
      case "slow_down":
        interval = max(interval + 5, response.interval ?? 0)
      case nil:
        guard let token = response.accessToken, !token.isEmpty,
          response.tokenType?.lowercased() == "bearer"
        else { throw GitHubOAuthError.invalidResponse }
        return token
      default: throw GitHubOAuthError.invalidResponse
      }
    }
  }

  private func request(path: String, fields: [String: String]) async throws -> OAuthResponse {
    guard !clientID.isEmpty else { throw GitHubOAuthError.missingClientID }
    try Task.checkCancellation()
    var form = URLComponents()
    form.queryItems = (["client_id": clientID].merging(fields) { _, value in value })
      .sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
    var request = URLRequest(url: URL(string: "https://github.com/login/\(path)")!)
    request.httpMethod = "POST"
    request.timeoutInterval = 30
    request.cachePolicy = .reloadIgnoringLocalCacheData
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
    request.setValue("Hammertime", forHTTPHeaderField: "User-Agent")
    request.httpBody = form.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B").data(
      using: .utf8)
    let (data, http) = try await send(request)
    try Task.checkCancellation()
    if http.statusCode == 429 { throw GitHubOAuthError.rateLimited }
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    guard let response = try? decoder.decode(OAuthResponse.self, from: data) else {
      throw GitHubOAuthError.invalidResponse
    }
    switch response.error {
    case "authorization_pending", "slow_down", nil: break
    case "access_denied": throw GitHubOAuthError.denied
    case "expired_token": throw GitHubOAuthError.expired
    case "device_flow_disabled": throw GitHubOAuthError.deviceFlowDisabled
    case "incorrect_client_credentials", "invalid_client": throw GitHubOAuthError.invalidClientID
    default: throw GitHubOAuthError.invalidResponse
    }
    guard (200..<300).contains(http.statusCode) else {
      throw GitHubOAuthError.unavailable
    }
    return response
  }
}

private struct OAuthResponse: Decodable {
  let deviceCode: String?
  let userCode: String?
  let verificationUri: URL?
  let expiresIn: TimeInterval?
  let interval: TimeInterval?
  let accessToken: String?
  let tokenType: String?
  let error: String?
}

public enum GitHubOAuthError: LocalizedError, Equatable {
  case missingClientID, invalidClientID, deviceFlowDisabled, invalidResponse, unavailable
  case expired, denied, rateLimited

  public var errorDescription: String? {
    switch self {
    case .missingClientID:
      "Browser sign in needs a registered GitHub OAuth app. Configure its Client ID when building Hammertime."
    case .invalidClientID:
      "GitHub did not recognize this app's Client ID. Check its OAuth app registration."
    case .deviceFlowDisabled:
      "Enable device flow in this app's GitHub OAuth settings, then try again."
    case .invalidResponse: "GitHub returned an unexpected sign in response. Please try again."
    case .unavailable: "GitHub sign in is unavailable. Please try again later."
    case .expired: "Your sign in code expired. Sign in again to get a new code."
    case .denied: "GitHub authorization was declined. You can sign in again when ready."
    case .rateLimited:
      "GitHub is limiting sign in attempts. Please wait a few minutes before trying again."
    }
  }
}
