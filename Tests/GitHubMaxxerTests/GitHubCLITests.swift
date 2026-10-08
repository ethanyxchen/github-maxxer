import Foundation
import Testing

@testable import GitHubMaxxer

struct GitHubCLITests {
  @Test func findsGitHubCLIOnTheLoginShellPath() async throws {
    let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let gh = directory.appending(path: "gh")
    let shell = directory.appending(path: "shell")
    try "#!/bin/sh\n".write(to: gh, atomically: true, encoding: .utf8)
    try "#!/bin/sh\necho 'Welcome back'\necho '\(gh.path)'\n"
      .write(to: shell, atomically: true, encoding: .utf8)
    for file in [gh, shell] {
      try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: file.path)
    }
    #expect(await GitHubCLI.executable(shell: shell.path) == gh)
  }
}
