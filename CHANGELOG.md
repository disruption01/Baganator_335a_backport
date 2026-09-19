# Changelog

All notable Disruption01 releases for the World of Warcraft 3.3.5a backport are documented here.

## 1.0.2 — 2026-09-19

**Restack / Sort Compatibility Fix**

Patch release fixing a 3.3.5a restack/sort edge case discovered after the Whitemane compatibility release. The functional code is the already validated sort-sync build; no SavedVariables reset is required.

### Sorting / restack fixes

- Corrected the 3.3.5a compatibility implementation of `tFilter()` so indexed-table filtering returns a dense sequential array, matching the semantics expected by upstream Baganator.
- Fixed a case where manually splitting or moving a stack and immediately pressing Sort could leave an outlier stack behind instead of restacking it.
- Waits for the pending Syndicator bag-cache refresh before planning the combine-stacks pass on 3.3.5a.
- Added a defensive guard so transient/inconsistent stack snapshots cannot produce a nil-source Lua error during restacking.

### Validation

- Validated with manually split and repositioned stacks before and after sorting.
- Confirmed normal sorting behavior remains intact on the existing stock 3.3.5a test environment.
- Keeps the Whitemane/custom-SharedXML compatibility fixes introduced in `1.0.1`.

## 1.0.1 — 2026-09-19

**Whitemane Compatibility Fix**

Patch release focused on compatibility with the Whitemane 3.3.5a client/UI environment while preserving the already working stock 3.3.5a path.

### Compatibility fixes

- Hardened atlas handling for clients/UI packs that expose partial modern SharedXML atlas APIs without the full modern atlas set.
- Isolated Baganator from incompatible custom `CreateFramePool` implementations by using the private 3.3.5a frame-pool implementation.
- Made Syndicator item-summary tooltips tolerate stale or missing character/guild summary records instead of aborting on tooltip hover.
- Added a private tooltip color wrapper for clients that expose modern font-color globals without `WrapTextInColorCode()`.
- Preserved the stock 3.3.5a behavior path: no new fake modern globals are published and no SavedVariables reset is required.

### Validation

- Validated on the existing stock 3.3.5a test environment.
- Compatibility path also validated against the Whitemane client/UI environment that originally exposed the SharedXML edge cases.

## 1.0.0 — 2026-09-18

Initial public Disruption01 release based on the tested `alpha0.42` compatibility baseline, including the final in-game attribution and minimap/settings polish completed immediately before release.

### Compatibility and stability

- Backported Baganator and Syndicator to World of Warcraft 3.3.5a build 12340.
- Replaced unsupported modern UI/API paths with Wrath-compatible implementations where needed.
- Removed the partial global `Settings` compatibility namespace so unrelated addons do not detect a fake modern Settings API.
- Stabilised bag/bank item-button reuse, dragging, sorting, empty-slot rendering, and cached state cleanup.
- Added classic-safe character selection, saved searches, help/search scrolling, currency display, and gold tooltips.
- Added deterministic keyring/special-container and header-button rendering.
- Fixed stale empty-slot visuals after moving or sorting items and then dragging the bag window.
- Fixed intermittent keyring icon visibility.

### Release presentation and attribution

- Added visible orange `v1.0.0` suffixes to both Baganator and Syndicator in WoW's AddOns list.
- Added maintainer, target-client, upstream, repository, Discord, and support metadata.
- Added a native 3.3.5a Baganator minimap button.
- Left-clicking the minimap button opens an **About & Credits** panel with original authorship, backport attribution, upstream project/community links, Disruption01 links, and copyable URLs.
- Right-clicking the minimap button opens Baganator settings.
- Expanded the minimap-button tooltip with project, Discord, and support information.
- Added a dedicated **Credits** tab to the 3.3.5a Baganator settings window.
- Added visible upstream/Disruption01 attribution to the first-run welcome screen and Syndicator settings UI.
- Fixed the 3.3.5a first-run welcome panel backdrop and aligned the two Choose buttons so they no longer collide with the attribution line.
- Added repository-level README, credits, changelog, and license notice.

### Upstream bases

- Baganator: `823-2-ged5d1c8`
- Syndicator: `279`
