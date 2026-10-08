# Hammertime

A native macOS app for tracking the pull requests you merge, across personal projects and work repositories.

Set daily, weekly, and monthly targets for personal work and each organisation. Connect multiple GitHub accounts, choose entire repository owners or individual repositories, and see your progress against them.

## Install

Requires macOS 26 or newer.

```sh
brew install --cask ethanyxchen/tap/hammertime
```

Update to the latest release with `brew upgrade --cask hammertime`.

## Connect GitHub

Choose **Connect GitHub**, name the connection Personal or Work, and click **Sign in with GitHub**. The app opens your browser and shows a short code. Enter that code on GitHub and approve access; your activity loads automatically. No manual access token or GitHub CLI installation is needed.

**Include private repositories** requests GitHub's `repo`, `read:user`, and `read:org` OAuth scopes. GitHub's `repo` permission also grants write access; this app only reads data. Turn the option off to request just `read:user` and `read:org` for public activity. Organizations may require approval or SSO authorization before private activity is accessible.

Credentials are saved in macOS Keychain after the app validates the account and loads its activity. You can add multiple GitHub accounts. Signing in to the same account again updates its credential and activity while keeping its name and repository selections. Reconnect or disconnect from **Targets & Accounts**. Disconnect removes the local credential; revoke the app's access separately in GitHub's authorized applications settings if desired.

**Use GitHub CLI** imports the account already signed in to `github.com` through `gh auth login`. This option uses your CLI credential's existing permissions rather than the private repositories toggle, which configures browser sign in only.

## How activity is counted

- Set a daily PR target for **Personal** and each organisation in **Targets & Accounts**, or 0 for none. **All activity** targets the sum of them. Weekly and monthly targets update automatically using 5 days per week and 20 days per month: a daily target of 3 gives weekly and monthly targets of 15 and 60.
- Personal and each organisation have their own colour, used for their sidebar icon, their meters, and their part of the **All activity** meters, with a legend showing each one's count against its own target. On their own page, meters turn green once the target is reached. New organisations take the least used colour; right-click Personal or an organisation in the sidebar to change it. PRs in repositories that are neither yours nor an organisation's appear as **Other**.
- The activity view leads with today's count against your target, then week and month meters. Below them, merged PRs are listed by day with that day's count against the daily target, starting with the last 7 days. **Older** and **Newer** step through the 90-day history a week at a time. Search looks through all 90 days by title, repository, or PR number.
- While a week or month target is unmet, a marker shows where you should be after the weekdays elapsed so far, and the note says how far ahead or behind pace you are.
- Targets count PRs **you authored**, using the time they were **merged**, including merges performed by someone else. Closed but unmerged PRs do not count.
- Daily and monthly targets use your Mac's time zone. Weeks start Monday.
- **Repositories** controls which repositories count toward PR targets. Choosing an organisation or account under **Count repositories from** includes all of its current and future accessible repositories. Only PRs you author ever count. Individual selections use GitHub repository IDs, so renaming a repository preserves its selection.
- The sidebar lists **All activity**, **Personal**, and each organisation. Selecting one filters target progress and the merge list to that owner's repositories. Once the sidebar has focus, the arrow keys move between items and typing a name jumps to it.
- Right-click an organisation to pin it to the top, rename it, or remove it from the sidebar. Names and pins only change how Hammertime shows the organisation. A removed organisation no longer counts toward **All activity**: its merges and target are left out until you bring it back, which restores its target and colour. Bring removed organisations back from **Show in Sidebar** at the top of **Repositories**.
- Merged PR history covers the last 90 calendar days. Large searches are split into smaller date ranges to avoid GitHub's 1,000-result search limit.

Activity refreshes approximately every minute while the app is running, when the window becomes active, or with **⌘R**. The menu bar item shows target progress and reopens the window. Closing the window keeps the app running; quitting stops updates. Updates depend on GitHub's search indexing and API availability. No webhooks or server are required.

The last successful activity stays available offline. A failed refresh shows an error and retains its previous snapshot and update time. Missing work repositories usually mean that the credential needs repository access, organization approval, or SSO authorization.

## Local data

Credentials live only in macOS Keychain. Targets, repository selections, and fetched activity are saved under `~/Library/Application Support/GitHub Maxxer/state.json`, with access restricted to your user. The app contacts GitHub directly and has no analytics or backend. Disconnecting removes that connection's Keychain credential and local activity.

## Credits

- ["Sledgehammer"](https://sketchfab.com/3d-models/sledgehammer-8194ce123fd64429b183c26df7fba17e) by Yaroslav Lazun, licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).
- ["Studio Small 09"](https://polyhaven.com/a/studio_small_09) HDRI from Poly Haven, licensed under CC0.
- ["Glass Shatter 1"](https://freesound.org/people/Greg_Surr/sounds/554565/) by Greg_Surr, licensed under CC0.
- ["Sound Design Elements Impact SFX PS 089"](https://freesound.org/people/AudioPapkin/sounds/814883/) by AudioPapkin, licensed under CC0.
