import Foundation
import os

extension Logger {
  static let merges = Logger(subsystem: Bundle.main.bundleIdentifier ?? "", category: "merges")
}
