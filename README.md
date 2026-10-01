# GitHub Maxxer

A native macOS app for tracking the pull requests you merge, across personal projects and work repositories.

Set daily, weekly, and monthly targets. Connect multiple GitHub accounts, choose entire repository owners or individual repositories, and see your progress alongside GitHub's contribution calendar. The app uses SwiftUI navigation, forms, tables, toolbars, settings, and a menu bar item, and follows your system appearance.

## Run locally

Requires macOS 14 or newer and Xcode 26 or newer with Swift 6.2.

```sh
./scripts/build-app.sh
open 'build/GitHub Maxxer.app'
```

You can copy the resulting app to Applications. This local build is ad hoc signed; distributing it to other Macs requires Developer ID signing and notarization.

Open `Package.swift` in Xcode to work on the app. There are no external dependencies.

## Connect GitHub

Choose **Connect GitHub**, name the connection Personal or Work, and click **Sign in with GitHub**. The app opens your browser and shows a short code. Enter that code on GitHub and approve access; your activity loads automatically. No manual access token or GitHub CLI installation is needed.

**Include private repositories** requests GitHub's `repo`, `read:user`, and `read:org` OAuth scopes. GitHub's `repo` permission also grants write access; this app only reads data. Turn the option off to request just `read:user` and `read:org` for public activity. Organizations may require approval or SSO authorization before private activity is accessible.

Credentials are saved in macOS Keychain after the app validates the account and loads its activity. You can add multiple accounts or several connections for the same account with different repository selections. Overlapping PRs count once. Reconnect or disconnect from **Targets & Accounts**. Disconnect removes the local credential; revoke the app's access separately in GitHub's authorized applications settings if desired.

**Use GitHub CLI** imports the account already signed in to `github.com` through `gh auth login`. This option uses your CLI credential's existing permissions rather than the private repositories toggle, which configures browser sign in only.

### One-time setup for the app owner

Browser sign in uses [GitHub's OAuth device flow](https://docs.github.com/en/apps/oauth-apps/building-oauth-apps/authorizing-oauth-apps#device-flow). The standard build includes GitHub Maxxer's registered public Client ID, so you can sign in immediately. End users do not need to register an app.

To use your own OAuth app for a fork:

1. Open [Register a new OAuth application](https://github.com/settings/applications/new).
2. Set the name to **GitHub Maxxer** and homepage to `https://github.com/ethanyxchen/github-maxxer`.
3. Set the required callback URL to `https://github.com/ethanyxchen/github-maxxer`. Device flow does not use a callback.
4. Register the app and enable **Device Flow** in its settings. Use default non-expiring tokens.
5. Copy the public **Client ID**, then build:

```sh
GITHUB_OAUTH_CLIENT_ID=your_client_id ./scripts/build-app.sh
open 'build/GitHub Maxxer.app'
```

The build embeds the public Client ID in the app bundle; the environment variable overrides the registered app for custom builds. No client secret is needed or shipped. For `swift run` or Xcode development, set the same environment variable because those executables do not use the packaged app's Info.plist.

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
