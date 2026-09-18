---
version: alpha
name: Skills
description: A native macOS specimen library for discovering, inspecting, and managing global agent skills.
typography:
  headline:
    fontFamily: System
  body-medium:
    fontFamily: System
    fontWeight: 500
  caption:
    fontFamily: System
  monospaced-callout:
    fontFamily: System Monospaced
spacing:
  row-micro: 3
  header-tight: 6
  compact: 8
  control-stack: 10
  group: 12
  section-compact: 16
  inspector-section: 16
  inspector-inset: 24
components:
  top-navigation:
    placement: flat strip below native window titlebar / large icon-and-label tabs
  manager-page:
    width: fills window / 320–520pt leading skill column
    presentation: two-column HSplitView for Browse and Installed / grouped form for Settings
  grouped-skill-row:
    typography: "{typography.body-medium}"
    padding: native Form row metrics
  detail-panel:
    padding: 24pt on every edge
    width: fills trailing split pane
  agent-picker:
    padding: 4pt vertical
    height: 130pt minimum / fills available detail height
    width: 260pt adaptive minimum
    row-height: 38pt minimum
    checkbox-size: 24pt
  prominent-action:
    size: large
    width: fill for the install action
  mutation-progress:
    padding: 24pt
    width: 500pt min
---

# Design System: Skills

## Overview

**Creative North Star: "Native Skills Preferences"**

Skills follows the focused structure of a polished macOS preferences window: the native titlebar stays visually quiet, a flat icon navigation strip sits directly beneath it, and the selected destination appears below. Browse and Installed pair a compact skill list with persistent detail; Settings uses one centered grouped form.

The interface defers visual styling to SwiftUI and AppKit conventions so it remains familiar across appearance, accent, accessibility, and language settings. Hierarchy comes from native navigation, typography, separators, control roles, and semantic mutation status rather than decorative branding.

**Key Characteristics:**
- Flat icon navigation below the native window titlebar
- Lazy skill lists beside persistent detail panels
- System typography, materials, controls, and SF Symbols
- Modal installation and removal feedback with diagnostics kept secondary
- Complete English and Simplified Chinese presentation

## Colors

The palette is entirely semantic and dynamic. Window, toolbar, list, separator, selection, primary action, secondary text, and tertiary metadata colors come from the active macOS appearance and accent rather than project-owned fixed values.

### Primary
- **System Accent:** Selection and prominent actions use the user's macOS accent through native controls.

### Secondary
- **System Green:** A filled checkmark identifies a completed installation or removal.
- **System Orange:** A filled warning triangle identifies a mutation that needs attention.
- **System Destructive:** Remove actions use the native destructive role; color is never the only signal because the action label and trash symbol remain visible.

### Neutral
- **System Primary:** Skill names, titles, labels, and values use the native primary foreground.
- **System Secondary:** Sources, supporting text, labels, and help copy recede with the native secondary foreground.
- **System Tertiary:** Low-priority counts use the native tertiary foreground.
- **System Surfaces and Separators:** Navigation columns, lists, forms, dividers, and dialogs inherit their materials and separators from macOS.

**The Semantic State Rule.** Green means a mutation completed, orange means a mutation needs attention, and the destructive role is reserved for removal; never use these roles as decoration.

**The Dynamic Palette Rule.** Do not replace system roles with fixed light-mode or dark-mode color values.

## Typography

**Display Font:** macOS system typeface  
**Body Font:** macOS system typeface  
**Label/Mono Font:** macOS system monospaced callout for raw output only

**Character:** Quiet, compact, and utilitarian. Named SwiftUI text styles carry native metrics and scaling; weight changes are used sparingly to separate primary entries from metadata.

### Hierarchy
- **Headline:** Detail section labels and grouped controls.
- **Body Medium:** Primary labels in skill rows.
- **Body:** Form labels, values, buttons, picker labels, and supporting content.
- **Caption:** Row descriptions, source metadata, installation help, and counts.
- **Monospaced Callout:** Selectable CLI output inside mutation details.

**The Named Style Rule.** Use SwiftUI text styles instead of hard-coded point sizes so hierarchy follows macOS accessibility settings.

## Layout

The native window titlebar remains compact. Directly beneath it, a flat full-width strip inherits the window surface instead of using a separate bar material, so no boundary appears above the app navigation. One divider separates the strip from page content below. Only the selected 68 × 48pt tab receives a native quaternary rounded surface and accent-colored content; the navigation group itself has no enclosing capsule. The window opens at 1040 × 720 points and does not shrink below 900 × 620 points.

Browse and Installed each use a plain two-column `HSplitView`. The narrower 300–440pt leading column pairs a compact fixed control panel with a virtualized inset `List`, leaving the larger share of the default window to detail content. The control panel uses 10pt vertical and 12pt horizontal padding, with 8pt between search and repository actions; a divider separates it from results.

Browse and Installed details use non-scrolling outer containers with 16pt between major sections, 6pt between metadata rows, and 24pt padding on every edge. Browse gives its agent picker the remaining vertical space; only that bounded collection scrolls when its contents exceed the available height.

**The No Nested Navigation Rule.** The manager owns the only navigation strip. Skill columns use `HSplitView`, and non-scrolling detail containers fill the trailing pane without adding secondary navigation chrome.

**The Persistent Detail Rule.** Browse and Installed keep the selected skill and its controls visible side by side; selecting another row updates the right column in place.

## Elevation & Depth

The system is flat by default and defines no custom shadows. Depth comes from the native window titlebar, the divider below app navigation, grouped surfaces, sheets, disclosure, confirmation dialogs, and alerts.

**The Native Layering Rule.** Use the platform's container hierarchy before adding a custom background, border, blur, or shadow.

## Shapes

There is no project-owned corner-radius scale. Grouped forms, buttons, search fields, text fields, segmented controls, checkboxes, sheets, disclosures, alerts, and confirmation dialogs retain their native macOS geometry.

## Components

### Navigation
- **Top Navigation:** Three centered buttons sit in a flat full-width strip beneath the native titlebar and inherit the window surface without a separate bar material. A single divider remains below the strip. Each tab uses a 21pt SF Symbol above a caption label in a 68 × 48pt target. Only the selected item receives accent-colored content on an 8pt continuous native quaternary rounded surface; the navigation group has no enclosing shape.
- **Manager Layout:** Browse and Installed use a 300–440pt skill list beside a wider persistent detail pane. Settings uses one centered grouped form up to 720pt wide.
- **Discover Controls:** Search and GitHub installation form one compact fixed panel above the results list. The repository description stays to one line; one divider, rather than List section spacing, separates controls from results.
- **Installed Management:** Update All and Batch Link use full-width plain action rows in a fixed control panel above the installed skills list.

### Skill Rows
- **Discover Row:** Medium-weight skill name and source truncate in the middle; a fixed-width install count trails clear of the scrollbar. Row separators span the full content width. The initial directory load belongs to the app session and continues across section changes. Rows are virtualized by `List`; the final rendered directory row triggers the next page.
- **Installed Row:** Medium-weight skill name and source truncate in the middle; agent count and suffix form one caption-sized trailing label separated by one typographic space.
- **Behavior:** Native list selection drives the persistent detail column. Browse rows remain virtualized and search results replace rather than mix with the default directory.

### Persistent Skill Detail
- **Layout:** Detail content uses a 16pt section rhythm and 24pt inset on every edge. The Browse agent picker expands and contracts with the window, scrolling internally only when its rows exceed the available height.
- **Metadata:** Native `Grid` rows use 6pt vertical spacing; `LabeledContent` rows follow the same compact detail rhythm.
- **Actions:** Install and Update use bordered-prominent buttons. Installed skills with a recorded source also expose Link to Other Agents; Remove uses the native destructive role.

### GitHub Repository Installer
- **Presentation:** A compact native sheet keeps the current Discover selection in place. The title and one-line scope statement lead directly into the required controls; Cancel and Install All Skills live in a standard footer.
- **Source:** A rounded text field accepts `owner/repository` shorthand or a full `github.com` URL. Concise supporting text covers private-repository authentication; invalid non-empty input shows a semantic inline error.
- **Scope:** Installation explicitly targets every skill discovered in the repository. Agent selection and Symlink/Copy reuse the same controls as directory installs.
- **Action:** “Install All Skills” stays disabled until the source is valid and at least one agent is selected, then transitions the sheet directly to CLI progress without a redundant confirmation step.

### Installed Skill Linking
- **Presentation:** Link to Other Agents opens a compact native sheet and preserves the selected installed skill behind it. Batch Link in the Installed management group opens the same sheet with an additional two-column skill selector.
- **Context:** Single-skill mode names the skill and summarizes its current agent links. Batch mode starts with no skills selected, lists every linkable installed skill, and filters the two-column skill grid by case-insensitive skill name or recorded repository before presenting the shared searchable two-column agent picker. Select Visible affects only the filtered skill results.
- **Action:** Agent selection starts empty and existing links remain unchanged. Batch execution groups selected skills by recorded source, emits the exact command for every source, runs each source once, and refreshes the installed list once after completion.

### Agent Target Picker
- **Filter:** Rounded native text field with Select Visible and Clear actions.
- **Selection:** Adaptive grid of checkbox toggles. A 24pt checkbox is vertically centered beside both text lines, so the agent name and its global skill directory form one label to the checkbox's right. Each row is a 38pt-minimum full-width hit target; paths use secondary caption-sized monospaced text and middle truncation. A localized “Selected” label precedes the count beside the section heading.
- **State:** Install and link actions are disabled when no agent is selected or while a mutation is active.

### Installation Method
- **Control:** Native segmented picker with Symlink and Copy.
- **Explanation:** A secondary caption immediately below changes with the selected method.
- **Default:** Symlink is the initial selection.

### Confirmation and Mutation Feedback
- **Confirmation:** Individual skill installation, Update All, and Remove use native confirmation dialogs with localized explanations. Repository installation submits directly from its focused sheet.
- **Mutation Sheet:** Installation, linking, update, and removal open the same modal sheet immediately after any required confirmation. An indeterminate native progress indicator identifies CLI execution and installed-list refresh; success and failure use semantic icons and action-specific labels.
- **Command:** Install, link, update, and remove sheets always show the exact copyable `bunx` or `npx` command in a horizontally scrolling monospaced line.
- **Diagnostics:** Final CLI output is stripped of ANSI terminal formatting, opens by default in a selectable two-axis scrolling disclosure, and can be collapsed. The sheet cannot be dismissed while a mutation is running.
- **Summary Alert:** Search and list failures use concise localized native alerts.

### Runtime Repair State
- **Checking:** A large native progress indicator replaces the manager while the runtime is being located.
- **Missing:** A focused `ContentUnavailableView` replaces the manager with retry, Install Bun, and Install Node.js actions.
- **Available:** Expanded top navigation exposes the grouped Browse, Installed, and Settings pages.

### Settings and Localization
- **Settings:** Settings uses the same centered grouped page as Browse and Installed, with sections for language, runtime repair, runtime selection, and an editable Skills CLI version. Runtime rechecks keep the current page visible, and the version field uses a compact `skills@` prefix with no duplicate helper text.
- **Locale:** System Default, English, and Simplified Chinese are immediate in-app choices and apply to both the main window and Settings scene.

## Do's and Don'ts

### Do:
- **Do** use native SwiftUI controls, text styles, focus, keyboard behavior, VoiceOver semantics, and Reduce Motion behavior as the baseline.
- **Do** keep skill selection and its controls visible together in the list and detail columns.
- **Do** pair every semantic state color with an SF Symbol and localized text.
- **Do** preserve technical identifiers, source URLs, paths, and raw output as selectable text where implemented.
- **Do** keep diagnostics available but collapsed until requested.

### Don't:
- **Don't** add custom cards, decorative glass, gradients, fixed palette values, or ornamental shadows.
- **Don't** turn the interface into a terminal transcript or lead with stdout and stderr.
- **Don't** use success, attention, or destructive colors without their native icon, label, or control role.
- **Don't** add custom animation timing where native selection, progress, disclosure, dialog, and content behavior already responds to accessibility settings.
- **Don't** translate native controls into cross-platform approximations or fixed visual recipes.
