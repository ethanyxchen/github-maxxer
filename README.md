# GitHub Maxxer

A native macOS app for tracking the pull requests you merge, across personal projects and work repositories.

Set daily, weekly, and monthly targets. Connect multiple GitHub accounts or tokens, choose entire repository owners or individual repositories, and see your progress alongside GitHub's contribution calendar. The app uses SwiftUI navigation, forms, tables, toolbars, settings, and a menu bar item, and follows your system appearance.

## Run locally

Requires macOS 14 or newer and Xcode 26 or newer with Swift 6.2.

```sh
./scripts/build-app.sh
open 'build/GitHub Maxxer.app'
```

You can copy the resulting app to Applications. This local build is ad hoc signed; distributing it to other Macs requires Developer ID signing and notarization.

Open `Package.swift` in Xcode to work on the app. There are no external dependencies.

## Connect GitHub

Choose **Connect GitHub**. Either paste a personal access token or choose **Use GitHub CLI** to use the account already signed in to `github.com` with `gh auth login`. Give each connection a name such as Personal or Work.

The app validates the credential and loads activity before saving it in macOS Keychain. It only reads GitHub data. Classic tokens need `repo`, `read:user`, and `read:org` to include private repositories, private contributions, and organization access; these GitHub scopes also grant capabilities the app never uses. Fine-grained tokens should have read access to pull requests and selected repositories. They cover one resource owner, so add separate connections for personal and organization access. Organizations may require token approval or SSO authorization.

You can connect multiple accounts, or several tokens for the same account. Overlapping PRs count once. Reconnect or disconnect a credential from **Targets & Accounts**. Browser OAuth sign in is not part of this first version; it would require a registered GitHub OAuth application.

## How activity is counted

- Targets count PRs **you authored**, using the time they were **merged**, including merges performed by someone else. Closed but unmerged PRs do not count.
- Daily and monthly targets use your Mac's time zone. Weeks start Monday.
- **Repositories** controls which repositories count toward PR targets. Selecting an owner includes its current and future accessible repositories. Individual selections use GitHub repository IDs, so renaming a repository preserves its selection.
- The contribution calendar comes directly from GitHub and retains GitHub's counts and intensity levels. It includes account-wide commits, issues, reviews, and opened PRs; its data is independent of the repositories selected for PR targets.
- Merged PR history covers the last 90 calendar days. Large searches are split into smaller date ranges to avoid GitHub's 1,000-result search limit.

Activity refreshes approximately every minute while the app is running, when the window becomes active, or with **⌘R**. The menu bar item shows target progress and reopens the window. Closing the window keeps the app running; quitting stops updates. Updates depend on GitHub's search indexing and API availability. No webhooks or server are required.

The last successful activity stays available offline. A failed refresh shows an error and retains its previous snapshot and update time. Missing work repositories usually mean that the credential needs repository access, organization approval, or SSO authorization.

## Local data

Credentials live only in macOS Keychain. Targets, repository selections, and fetched activity are saved under `~/Library/Application Support/GitHub Maxxer/state.json`, with access restricted to your user. The app contacts GitHub directly and has no analytics or backend. Disconnecting removes that connection's Keychain credential and local activity.

## Development checks

```sh
swift test
swift format lint --strict --recursive Package.swift Sources Tests scripts/make-icon.swift
bash -n scripts/build-app.sh scripts/update-icon.sh
```

Run a read only integration check with your existing GitHub CLI session:

```sh
swift run GitHubMaxxer --verify-github
```

It prints account identity and counts, never credentials, and does not save a connection.

For a labeled dashboard with sample activity and no account reads or writes:

```sh
swift run GitHubMaxxer --preview
```

Use `--preview-dark` instead to inspect dark appearance without changing system settings.

Regenerate the original app icon with `./scripts/update-icon.sh`.
