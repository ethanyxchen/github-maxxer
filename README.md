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

## Local data

Credentials live only in macOS Keychain. Targets, repository selections, and fetched activity are saved under `~/Library/Application Support/GitHub Maxxer/state.json`, with access restricted to your user. The app contacts GitHub directly and has no analytics or backend. Disconnecting removes that connection's Keychain credential and local activity.

## Credits

- ["Sledgehammer"](https://sketchfab.com/3d-models/sledgehammer-8194ce123fd64429b183c26df7fba17e) by Yaroslav Lazun, licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).
- ["Studio Small 09"](https://polyhaven.com/a/studio_small_09) HDRI from Poly Haven, licensed under CC0.
- ["Glass Shatter 1"](https://freesound.org/people/Greg_Surr/sounds/554565/) by Greg_Surr, licensed under CC0.
- ["Sound Design Elements Impact SFX PS 089"](https://freesound.org/people/AudioPapkin/sounds/814883/) by AudioPapkin, licensed under CC0.
