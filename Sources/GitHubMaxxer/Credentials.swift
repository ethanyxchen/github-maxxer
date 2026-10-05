import Foundation
import Security

@MainActor
protocol CredentialStorage {
  func save(_ token: String, for id: UUID) throws
  func read(for id: UUID) throws -> String
  func delete(for id: UUID) throws
}

@MainActor
struct CredentialStore: CredentialStorage {
  private let service: String

  init(service: String = "com.ethanyxchen.github-maxxer") {
    self.service = service
  }

  func save(_ token: String, for id: UUID) throws {
    let attributes: [CFString: Any] = [
      kSecValueData: Data(token.utf8), kSecAttrLabel: "Hammertime",
    ]
    let status = SecItemUpdate(query(id) as CFDictionary, attributes as CFDictionary)
    guard status == errSecItemNotFound else { return try check(status) }
    try check(SecItemAdd(query(id).merging(attributes) { _, value in value } as CFDictionary, nil))
  }

  func read(for id: UUID) throws -> String {
    var item = query(id)
    item[kSecReturnData] = true
    item[kSecMatchLimit] = kSecMatchLimitOne
    var result: CFTypeRef?
    try check(SecItemCopyMatching(item as CFDictionary, &result))
    guard let data = result as? Data, let token = String(data: data, encoding: .utf8) else {
      throw CredentialError.invalidData
    }
    return token
  }

  func delete(for id: UUID) throws {
    let status = SecItemDelete(query(id) as CFDictionary)
    if status != errSecItemNotFound { try check(status) }
  }

  private func query(_ id: UUID) -> [CFString: Any] {
    [kSecClass: kSecClassGenericPassword, kSecAttrService: service, kSecAttrAccount: id.uuidString]
  }

  private func check(_ status: OSStatus) throws {
    guard status == errSecSuccess else { throw CredentialError.keychain(status) }
  }
}

enum CredentialError: LocalizedError {
  case keychain(OSStatus)
  case invalidData, cliUnavailable, cliNotAuthenticated

  var errorDescription: String? {
    switch self {
    case .keychain(errSecInteractionNotAllowed), .keychain(errSecAuthFailed):
      "Keychain access was denied. Click Refresh and allow Hammertime to use this connection."
    case .keychain(let status):
      "Keychain could not access this connection (\(status)). Unlock your Mac or reconnect the account."
    case .invalidData: "This saved credential could not be read. Reconnect the account."
    case .cliUnavailable: "GitHub CLI was not found. Sign in with GitHub in your browser instead."
    case .cliNotAuthenticated:
      "GitHub CLI is not signed in to github.com. Run gh auth login, then try again."
    }
  }
}

enum GitHubCLI {
  static var executable: URL? {
    ["/opt/homebrew/bin/gh", "/usr/local/bin/gh", "/usr/bin/gh"].first {
      FileManager.default.isExecutableFile(atPath: $0)
    }.map { URL(fileURLWithPath: $0) }
  }

  static func token() async throws -> String {
    try await Task.detached {
      guard let executable else { throw CredentialError.cliUnavailable }
      let process = Process()
      let output = Pipe()
      process.executableURL = executable
      process.arguments = ["auth", "token", "--hostname", "github.com"]
      process.standardOutput = output
      process.standardError = FileHandle.nullDevice
      process.standardInput = FileHandle.nullDevice
      try process.run()
      let data = output.fileHandleForReading.readDataToEndOfFile()
      process.waitUntilExit()
      let token = String(decoding: data, as: UTF8.self).trimmingCharacters(
        in: .whitespacesAndNewlines)
      guard process.terminationStatus == 0, !token.isEmpty else {
        throw CredentialError.cliNotAuthenticated
      }
      return token
    }.value
  }
}
