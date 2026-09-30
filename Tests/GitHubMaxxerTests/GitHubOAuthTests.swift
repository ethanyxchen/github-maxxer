import Foundation
import Testing

@testable import GitHubMaxxerCore

struct GitHubOAuthTests {
  @Test func requestsPrivateRepositoryPermissionWithoutASecret() async throws {
    let oauth = GitHubOAuth(
      clientID: "client id+&=",
      send: { request in
        #expect(request.url?.absoluteString == "https://github.com/login/device/code")
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
        let fields = formFields(request)
        #expect(fields["client_id"] == "client id+&=")
        #expect(fields["scope"] == "read:user read:org repo")
        #expect(fields["client_secret"] == nil)
        return response(request, body: deviceResponse)
      })
    let authorization = try await oauth.startAuthorization(includePrivateRepositories: true)
    #expect(authorization.userCode == "ABCD-EFGH")
    #expect(authorization.verificationURL.absoluteString == "https://github.com/login/device")
  }

  @Test func publicActivityDoesNotRequestRepositoryWriteAccess() async throws {
    let oauth = GitHubOAuth(
      clientID: "client",
      send: { request in
        #expect(formFields(request)["scope"] == "read:user read:org")
        return response(request, body: deviceResponse)
      })
    _ = try await oauth.startAuthorization(includePrivateRepositories: false)
  }

  @Test func waitsForApprovalAndHonorsSlowDown() async throws {
    let clock = OAuthClock()
    let oauth = GitHubOAuth(
      clientID: "client",
      send: { request in
        if request.url?.path == "/login/device/code" {
          return response(request, body: deviceResponse)
        }
        #expect(formFields(request)["device_code"] == "device-secret")
        #expect(formFields(request)["grant_type"] == "urn:ietf:params:oauth:grant-type:device_code")
        switch clock.delays.count {
        case 1: return response(request, body: "{\"error\":\"authorization_pending\"}")
        case 2: return response(request, body: "{\"error\":\"slow_down\",\"interval\":12}")
        default:
          return response(
            request, body: "{\"access_token\":\"credential\",\"token_type\":\"bearer\"}")
        }
      }, now: { clock.now }, sleep: { clock.advance($0) })
    let authorization = try await oauth.startAuthorization(includePrivateRepositories: true)
    let token = try await oauth.waitForToken(authorization)
    #expect(token == "credential")
    #expect(clock.delays == [5, 5, 12])
  }

  @Test func slowDownWithoutAnIntervalAddsFiveSeconds() async throws {
    let clock = OAuthClock()
    let oauth = GitHubOAuth(
      clientID: "client",
      send: { request in
        if request.url?.path == "/login/device/code" {
          return response(request, body: deviceResponse)
        }
        return response(
          request,
          body: clock.delays.count == 1
            ? "{\"error\":\"slow_down\"}"
            : "{\"access_token\":\"credential\",\"token_type\":\"bearer\"}")
      }, now: { clock.now }, sleep: { clock.advance($0) })
    let authorization = try await oauth.startAuthorization(includePrivateRepositories: false)
    _ = try await oauth.waitForToken(authorization)
    #expect(clock.delays == [5, 10])
  }

  @Test func wakingAfterExpiryDoesNotPoll() async throws {
    let clock = OAuthClock()
    let oauth = GitHubOAuth(
      clientID: "client",
      send: { request in
        #expect(request.url?.path == "/login/device/code")
        return response(request, body: deviceResponse)
      }, now: { clock.now }, sleep: { _ in clock.advance(901) })
    let authorization = try await oauth.startAuthorization(includePrivateRepositories: false)
    await #expect(throws: GitHubOAuthError.expired) { try await oauth.waitForToken(authorization) }
  }

  @Test func neverPollsAnExpiredCode() async throws {
    let clock = OAuthClock()
    let oauth = GitHubOAuth(
      clientID: "client",
      send: { request in
        #expect(request.url?.path == "/login/device/code")
        return response(request, body: deviceResponse)
      }, now: { clock.now }, sleep: { clock.advance($0) })
    let authorization = try await oauth.startAuthorization(includePrivateRepositories: false)
    clock.advance(900)
    await #expect(throws: GitHubOAuthError.expired) { try await oauth.waitForToken(authorization) }
    #expect(clock.delays == [900])
  }

  @Test func cancellationStopsBeforeTheNextPoll() async throws {
    let oauth = GitHubOAuth(
      clientID: "client",
      send: { request in
        #expect(request.url?.path == "/login/device/code")
        return response(request, body: deviceResponse)
      }, sleep: { _ in throw CancellationError() })
    let authorization = try await oauth.startAuthorization(includePrivateRepositories: false)
    await #expect(throws: CancellationError.self) { try await oauth.waitForToken(authorization) }
  }

  @Test(arguments: ["access_denied", "expired_token", "device_flow_disabled"])
  func rejectsTerminalAuthorizationErrors(code: String) async throws {
    let oauth = GitHubOAuth(
      clientID: "client",
      send: { request in
        if request.url?.path == "/login/device/code" {
          return response(request, body: deviceResponse)
        }
        return response(request, body: "{\"error\":\"\(code)\"}")
      }, sleep: { _ in })
    let authorization = try await oauth.startAuthorization(includePrivateRepositories: false)
    await #expect(throws: GitHubOAuthError.self) { try await oauth.waitForToken(authorization) }
  }

  @Test(arguments: [
    deviceResponse.replacingOccurrences(
      of: "https://github.com/login/device", with: "https://example.com/login/device"),
    deviceResponse.replacingOccurrences(of: "\"expires_in\":900", with: "\"expires_in\":0"),
    "{\"error\":\"device_flow_disabled\"}",
  ])
  func rejectsInvalidDeviceResponses(body: String) async {
    let oauth = GitHubOAuth(clientID: "client", send: { request in response(request, body: body) })
    await #expect(throws: GitHubOAuthError.self) {
      try await oauth.startAuthorization(includePrivateRepositories: false)
    }
  }

  @Test func missingConfigurationDoesNotContactGitHub() async {
    let oauth = GitHubOAuth(
      clientID: "  ",
      send: { request in
        Issue.record("Unconfigured sign in must not issue a request")
        return response(request, body: deviceResponse)
      })
    await #expect(throws: GitHubOAuthError.missingClientID) {
      try await oauth.startAuthorization(includePrivateRepositories: false)
    }
  }

  @Test func rejectsEmptyTokens() async throws {
    let oauth = GitHubOAuth(
      clientID: "client",
      send: { request in
        response(
          request,
          body: request.url?.path == "/login/device/code"
            ? deviceResponse : "{\"access_token\":\"\",\"token_type\":\"bearer\"}")
      }, sleep: { _ in })
    let authorization = try await oauth.startAuthorization(includePrivateRepositories: false)
    await #expect(throws: GitHubOAuthError.invalidResponse) {
      try await oauth.waitForToken(authorization)
    }
  }
}

private let deviceResponse =
  "{\"device_code\":\"device-secret\",\"user_code\":\"ABCD-EFGH\",\"verification_uri\":\"https://github.com/login/device\",\"expires_in\":900,\"interval\":5}"

private func response(_ request: URLRequest, body: String) -> (Data, HTTPURLResponse) {
  (
    Data(body.utf8),
    HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
  )
}

private func formFields(_ request: URLRequest) -> [String: String] {
  var components = URLComponents()
  components.percentEncodedQuery = String(decoding: request.httpBody!, as: UTF8.self)
  return Dictionary(uniqueKeysWithValues: components.queryItems!.map { ($0.name, $0.value!) })
}

private final class OAuthClock: @unchecked Sendable {
  private let lock = NSLock()
  private var storedDelays: [TimeInterval] = []
  var delays: [TimeInterval] { lock.withLock { storedDelays } }
  var now: Date { lock.withLock { Date(timeIntervalSince1970: storedDelays.reduce(0, +)) } }
  func advance(_ seconds: TimeInterval) { lock.withLock { storedDelays.append(seconds) } }
}
