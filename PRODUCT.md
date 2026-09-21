# Product

<!-- impeccable:product-schema 1 -->

## Platform

macOS 26+

## Stack

Native SwiftUI application managed directly by an Xcode project. The app entry point, categorized source, and resources live under `skills/`; tests live in the `SkillsTests/` target. The app is ad-hoc signed and not sandboxed.

## Users

Individual developers who manage agent skills on one Mac and want a native workflow instead of operating the `skills` CLI directly.

## Product Purpose

Skills lets a developer discover, install, inspect, update, and remove globally installed agent skills. Success means a developer can browse or search for a skill, choose explicit target agents, and complete a global installation with one confirmation.

## Positioning

A native macOS manager that keeps the official `skills` CLI as the authority for every filesystem mutation while presenting discovery and management as direct, task-oriented controls rather than a terminal session.

## Operating Context

The app uses the official skills.sh directory and search services for discovery. The Discover list opens on the all-time directory and loads later pages as the user reaches the end. It detects compatible system-provided `bunx` and `npx` runtimes, remembers the user's explicit runtime choice, and invokes the selected `skills` package version (`latest` by default). Private sources reuse existing Git credential-helper, SSH-agent, or authenticated `gh` access; the app does not collect credentials.

## Capabilities and Constraints

- Global scope only; project-local skills are outside the first release.
- Core management only: discover, add, list, update, and remove.
- Target agents are explicitly selected for installation and the last selection is remembered.
- Symlink installation is the default; copy installation is available.
- Updates are explicit mutating actions. The app does not claim a read-only update check or update-availability state because the CLI exposes neither safely.
- Search queries necessarily reach the official skills.sh API.
- Installation and removal show their current phase and final CLI output in a modal sheet; other failures use concise localized alerts.
- The interface is localized in Simplified Chinese and English, follows the system language by default, and allows an in-app override.

## Brand Commitments

The product name is **Skills**. Technical identifiers such as command names, agent identifiers, and source URLs remain in their original form. The interface must feel like a native macOS utility, not a terminal wrapper.

## Evidence on Hand

The implementation contract is grounded in npm package `skills` version 1.7.0 and the official `vercel-labs/skills` source. The user-selected CLI package version defaults to `latest`, so incompatible upstream output must surface as an actionable error rather than be silently interpreted.

## Product Principles

- Keep users in control of every target and mutating operation.
- Treat the CLI and its resulting filesystem state as authoritative.
- Prefer native task controls over exposing shell mechanics.
- Preserve diagnostic evidence without making logs the primary experience.
- Add no account, credential store, telemetry, cloud sync, or local index.

## Accessibility & Inclusion

Use native controls, keyboard navigation, VoiceOver labels, scalable system typography, sufficient contrast, and reduced-motion behavior. Ship complete Simplified Chinese and English UI strings.
