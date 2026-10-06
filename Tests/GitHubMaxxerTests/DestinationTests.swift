import GitHubMaxxerCore
import Testing

@testable import GitHubMaxxer

struct DestinationTests {
  @Test func stepsThroughSidebarInOrderAndWraps() {
    let workspaces: [ActivityFilter] = [.personal, .organization("acme")]

    #expect(Destination.activity(.all).step(1, through: workspaces) == .activity(.personal))
    #expect(
      Destination.activity(.personal).step(1, through: workspaces)
        == .activity(.organization("acme")))
    #expect(
      Destination.activity(.organization("acme")).step(1, through: workspaces) == .repositories)
    #expect(Destination.settings.step(1, through: workspaces) == .activity(.all))
    #expect(Destination.activity(.all).step(-1, through: workspaces) == .settings)
  }
}
