# Hammertime

A native macOS app for tracking the pull requests you merge, across personal projects and work repositories.

Set daily, weekly, and monthly targets. Connect multiple GitHub accounts, choose entire repository owners or individual repositories, and see your progress against them. The app uses SwiftUI navigation, forms, tables, toolbars, settings, and a menu bar item, and follows your system appearance.

## Run locally

Requires macOS 26 or newer and Xcode 26 or newer with Swift 6.2.

```sh
./scripts/build-app.sh
open 'build/Hammertime.app'
```

You can copy the resulting app to Applications. Quit Hammertime before building: the script stages and verifies the new bundle before replacing it, and refuses to overwrite a running app.

Local builds use an **Apple Development** certificate with a Team ID so Keychain authorization can persist across builds. Create one in **Xcode → Settings → Apple Accounts → your Apple account → Personal Team → Manage Certificates → + → Apple Development**. If you have multiple signing identities, select one consistently:

```sh
CODESIGN_IDENTITY='Apple Development: your name (identity)' ./scripts/build-app.sh
```

List available identities with `security find-identity -v -p codesigning`. The first build with a new identity may need Keychain approval. Reconnect the GitHub account to save its credential with the current app's access description. Distributing the app to other Macs requires Developer ID signing and notarization.

Self-signed and ad hoc builds (`CODESIGN_IDENTITY=-`) do not preserve Keychain approval across rebuilds because their code-hash partition changes.

Open `Package.swift` in Xcode to work on the app. There are no external dependencies.

## Connect GitHub

Choose **Connect GitHub**, name the connection Personal or Work, and click **Sign in with GitHub**. The app opens your browser and shows a short code. Enter that code on GitHub and approve access; your activity loads automatically. No manual access token or GitHub CLI installation is needed.

**Include private repositories** requests GitHub's `repo`, `read:user`, and `read:org` OAuth scopes. GitHub's `repo` permission also grants write access; this app only reads data. Turn the option off to request just `read:user` and `read:org` for public activity. Organizations may require approval or SSO authorization before private activity is accessible.

Credentials are saved in macOS Keychain after the app validates the account and loads its activity. You can add multiple GitHub accounts. Signing in to the same account again updates its credential and activity while keeping its name and repository selections. Reconnect or disconnect from **Targets & Accounts**. Disconnect removes the local credential; revoke the app's access separately in GitHub's authorized applications settings if desired.

**Use GitHub CLI** imports the account already signed in to `github.com` through `gh auth login`. This option uses your CLI credential's existing permissions rather than the private repositories toggle, which configures browser sign in only.

### One-time setup for the app owner

Browser sign in uses [GitHub's OAuth device flow](https://docs.github.com/en/apps/oauth-apps/building-oauth-apps/authorizing-oauth-apps#device-flow). The standard build includes Hammertime's registered public Client ID, so you can sign in immediately. End users do not need to register an app.

To use your own OAuth app for a fork:

1. Open [Register a new OAuth application](https://github.com/settings/applications/new).
2. Set the name to **Hammertime** and homepage to `https://github.com/ethanyxchen/github-maxxer`.
3. Set the required callback URL to `https://github.com/ethanyxchen/github-maxxer`. Device flow does not use a callback.
4. Register the app and enable **Device Flow** in its settings. Use default non-expiring tokens.
5. Copy the public **Client ID**, then build:

```sh
GITHUB_OAUTH_CLIENT_ID=your_client_id ./scripts/build-app.sh
open 'build/Hammertime.app'
```

The build embeds the public Client ID in the app bundle; the environment variable overrides the registered app for custom builds. No client secret is needed or shipped. For `swift run` or Xcode development, set the same environment variable because those executables do not use the packaged app's Info.plist.

## How activity is counted

- Edit the daily PR target in **Targets & Accounts**. Weekly and monthly targets update automatically using 5 days per week and 20 days per month: a daily target of 3 gives weekly and monthly targets of 15 and 60.
- The activity view leads with today's count against your target, then week and month meters. Below them, merged PRs are listed by day with that day's count against the daily target, starting with the last 7 days. **Older** and **Newer** step through the 90-day history a week at a time. Search looks through all 90 days by title, repository, or PR number.
- While a week or month target is unmet, a marker shows where you should be after the weekdays elapsed so far, and the note says how far ahead or behind pace you are.
- Targets count PRs **you authored**, using the time they were **merged**, including merges performed by someone else. Closed but unmerged PRs do not count.
- Daily and monthly targets use your Mac's time zone. Weeks start Monday.
- **Repositories** controls which repositories count toward PR targets. Choosing an organisation or account under **Count repositories from** includes all of its current and future accessible repositories. Only PRs you author ever count. Individual selections use GitHub repository IDs, so renaming a repository preserves its selection.
- The sidebar lists **All activity**, **Personal**, and each organisation. Selecting one filters target progress and the merge list to that owner's repositories. Once the sidebar has focus, the arrow keys move between items and typing a name jumps to it.
- Right-click an organisation to pin it to the top, rename it, or remove it from the sidebar. Names and pins only change how Hammertime shows the organisation, and a removed organisation still counts toward **All activity**. Bring removed organisations back from **Show in Sidebar** at the top of **Repositories**.
- Merged PR history covers the last 90 calendar days. Large searches are split into smaller date ranges to avoid GitHub's 1,000-result search limit.

Activity refreshes approximately every minute while the app is running, when the window becomes active, or with **⌘R**. The menu bar item shows target progress and reopens the window. Closing the window keeps the app running; quitting stops updates. Updates depend on GitHub's search indexing and API availability. No webhooks or server are required.

The last successful activity stays available offline. A failed refresh shows an error and retains its previous snapshot and update time. Missing work repositories usually mean that the credential needs repository access, organization approval, or SSO authorization.

## Local data

Credentials live only in macOS Keychain. Targets, repository selections, and fetched activity are saved under `~/Library/Application Support/GitHub Maxxer/state.json`, with access restricted to your user. The app contacts GitHub directly and has no analytics or backend. Disconnecting removes that connection's Keychain credential and local activity.

## Development checks

Unit tests use in-memory credentials and mocked GitHub responses, so they do not access your Keychain or require account authorization.

```sh
swift test
swift format lint --strict --recursive Package.swift Sources Tests scripts/make-icon.swift
bash -n scripts/build-app.sh scripts/update-icon.sh
```

Run a read only integration check with your existing GitHub CLI session:

```sh
swift run Hammertime --verify-github
```

It prints account identity and counts, never credentials, and does not save a connection.

For a labeled dashboard with sample activity and no account reads or writes:

```sh
swift run Hammertime --preview
```

Use `--preview-dark` instead to inspect dark appearance without changing system settings.

Regenerate the original app icon with `./scripts/update-icon.sh`.
