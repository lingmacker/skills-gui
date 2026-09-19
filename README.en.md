# Skills

[简体中文](README.md)

<p align="center">
  <img src="icon.png" width="192" alt="Skills app icon">
</p>

Native macOS manager for globally installed agent skills. Skills keeps the official [`skills`](https://www.npmjs.com/package/skills) CLI authoritative for filesystem changes and provides a SwiftUI interface for discovery and management.

## Features

- Browse the official skills.sh directory with incremental loading and search.
- Install one skill or every skill in a GitHub repository for explicitly selected agents.
- Choose symlink or copy installation.
- Inspect globally installed skills, update one or all skills, remove skills, and link an installed skill to more agents.
- Select a compatible `bunx` or `npx` runtime and choose the `skills` package version to invoke.
- Simplified Chinese and English UI.

## Requirements

### Build and run the app

- macOS 26 or later.
- Xcode 26 or later with the macOS SDK.

### Manage skills at runtime

- A compatible `bunx` or `npx` launcher on `PATH`.
- Node.js 22.20 or later when using `npx`.
- Network access to `skills.sh` for discovery and search.
- Existing Git credential helper, SSH agent, or authenticated `gh` session for private GitHub sources. The app never collects credentials.

## Build

```sh
make build
make run
```

Build output is `.build/Build/Products/Debug/Skills.app`.

Run tests:

```sh
xcodebuild -project skills.xcodeproj -scheme Skills \
  -destination 'platform=macOS' -derivedDataPath .build test
```

## Install a release

Release archives contain an ad-hoc signed, non-notarized `Skills.app`.

1. Download and unzip `Skills-<version>-macos.zip` from [Releases](../../releases).
2. Move `Skills.app` to `/Applications`.
3. Open it in Finder. If macOS blocks it, confirm the prompt or remove the quarantine attribute:

   ```sh
   xattr -dr com.apple.quarantine /Applications/Skills.app
   ```

Ad-hoc signatures verify the archive's code structure but do not identify a developer to Gatekeeper.

## Release automation

Pushing a tag named `v*` runs [`.github/workflows/release.yml`](.github/workflows/release.yml). It tests the project, creates a universal Release (`arm64 + x86_64`) with Xcode's ad-hoc signature intact, verifies the signature, uploads a ZIP artifact, and creates a GitHub Release.

A maintainer can also run the workflow manually and provide the release tag.

## Project layout

- `skills/` — SwiftUI application source and localized resources.
- `skillsTests/` — unit tests.
- `skills.xcodeproj/` — Xcode project.
- `TITLEBAR_SEPARATOR_RESEARCH.md` — first-party AppKit research for the titlebar/content separator.

## Security and scope

Skills only manages global skills. It performs mutations by invoking the selected `skills` CLI package; the CLI and resulting filesystem state are authoritative. Installation targets are explicit, and the last target selection is remembered locally.

## License

This project is licensed under the [MIT License](LICENSE).
