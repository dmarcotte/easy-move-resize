# ![icon](easy-move-resize/Images.xcassets/AppIcon.appiconset/icon_32x32.png) Easy Move+Resize

Adds easy `modifier key + mouse drag` move and resize to OSX

## Usage

**Easy Move+Resize** is based on behavior found in many X11/Linux window managers

![Menu](asset-sources/doc-img/menu.png)

- `Cmd + Ctrl + Left Mouse` anywhere inside a window, then drag to ***move***.
- `Cmd + Ctrl + Right Mouse` anywhere inside a window, then drag to ***resize***,
    - The resize direction is determined by which region of the window is clicked. *i.e.* a right-click in roughly the top-left corner of a window will act as if you grabbed the top left corner, whereas a right-click in roughly the top-center of a window will act as if you grabbed the top of the window.
    - To use the middle mouse button as the resize modifier, select the `Middle Click resize` menu item.
- The choice of modifier keys to hold down to activate dragging or resizing can be customized by toggling the appropriate modifier key name in the application icon menu.
    - Click the menu item to toggle it.
    - All keys toggled to selected must be held down for activation.
- Behavior can be disabled by toggling the `Disabled` item in the application icon menu.
- If you are dragging or resizing a window in the background and want it to rise to the top, select the `Bring Window to Front` menu item.
- To restore application settings, select the `Reset to Defaults` menu item.
- To disable for a particular app, select `Disable for ...` from the menu after using **Easy Move+Resize** on that app.

---

If you want the same edge-snapping behavior as dragging the menu bar, use the native support for move:

1. In a terminal, run: `defaults write -g NSWindowShouldDragOnGesture -bool true` \
   (enables native `Ctrl+Cmd+left-mouse` move)
2. Logout for this to have an effect
3. In Easy Move+Resize settings, enable `Resize only` OR choose different modifiers.

## Installation

### brew

```sh
brew install --cask easy-move-plus-resize
```

### manually

* Grab the latest version from the [Releases page](https://github.com/dmarcotte/easy-move-resize/releases)
* Unzip and run!

### troubleshooting

- If MacOS refuses to launch **Easy Move+Resize** because it "cannot check it for malicious software": [see here](https://github.com/dmarcotte/easy-move-resize/issues/84#issuecomment-1184946746)
- If Accessibility permission for **Easy Move+Resize** is not working: [see here](https://github.com/dmarcotte/easy-move-resize/issues/79#issuecomment-1109070242) 

## Contributing

[Contributions](contributing.md) welcome!

## Release process

### Automated (GitHub Actions)

Releases can be built, signed, notarized, and published automatically via the [`release`](.github/workflows/release.yml) workflow.

Prerequisites — the following secrets must be configured in the repository's GitHub Actions settings:

- `APPLE_ID` — Apple ID email used for notarization
- `APPLE_TEAM_ID` — Apple Developer Team ID
- `APPLE_APP_PASSWORD` — app-specific password for the Apple ID
- `DEVELOPER_ID_APPLICATION` — full name of the Developer ID Application signing identity (e.g. `Developer ID Application: Your Name (TEAMID)`)
- `DEVELOPER_ID_CERT_P12_BASE64` — base64-encoded `.p12` export of the Developer ID Application certificate
- `DEVELOPER_ID_CERT_PASSWORD` — password for the `.p12` file

Steps:

- Choose a new version number following [semantic versioning guidelines](https://semver.org)
- Update the version number in [`easy-move-resize/easy-move-resize-Info.plist`](easy-move-resize/easy-move-resize-Info.plist), ([example](https://github.com/dmarcotte/easy-move-resize/commit/18d759dec2caf7a33b0625c17c181a195191bc92))
- Commit and push the version number update
- `git tag <chosen version number>`
- `git push origin --tags`
- On GitHub, go to the [Actions tab](https://github.com/dmarcotte/easy-move-resize/actions), select the **release** workflow, and click **Run workflow**
- Enter the release version (e.g. `v1.2.3`), toggle **Mark as pre-release** if applicable, then click **Run workflow**
- The workflow validates the repo, builds the `.app` with `xcodebuild`, signs/notarizes/staples it, creates the git tag, and publishes a GitHub Release with the signed zip attached
- Once the workflow completes, the new release will appear on the [Releases page](https://github.com/dmarcotte/easy-move-resize/releases)

### Manual (backup)

- Choose a new version number following [semantic versioning guidelines](https://semver.org)
- Update the version number in [`easy-move-resize/easy-move-resize-Info.plist`](easy-move-resize/easy-move-resize-Info.plist), ([example](https://github.com/dmarcotte/easy-move-resize/commit/18d759dec2caf7a33b0625c17c181a195191bc92))
- Commit and push the version number update
- `git tag <chosen version number>`
- `git push origin --tags`
- In XCode, choose `Product->Archive`
- Click "Distribute App", select "Custom...", "Next", then "Copy App", "Next" 
- In a shell, navigate to the directory created, then:
- `zip -r Easy.Move+Resize.app.zip Easy\ Move+Resize.app`
- Upload the resulting zip file to the appropriate tag on the [Releases](https://github.com/dmarcotte/easy-move-resize/releases) page
