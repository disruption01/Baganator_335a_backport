# Changelog

All notable Disruption01 releases for the World of Warcraft 3.3.5a backport are documented here.

## 1.0.0 — 2026-09-18

First release candidate based on the tested `alpha0.42` compatibility baseline.

### Compatibility and stability

- Backported Baganator and Syndicator to World of Warcraft 3.3.5a build 12340.
- Replaced unsupported modern UI/API paths with Wrath-compatible implementations where needed.
- Removed the partial global `Settings` compatibility namespace so unrelated addons do not detect a fake modern Settings API.
- Stabilised bag/bank item-button reuse, dragging, sorting, empty-slot rendering, and cached state cleanup.
- Added classic-safe character selection, saved searches, help/search scrolling, currency display, and gold tooltips.
- Added deterministic keyring/special-container and header-button rendering.

### Release presentation

- Added visible orange `v1.0.0` suffixes to both Baganator and Syndicator in WoW's AddOns list.
- Added maintainer, target-client, upstream, repository, Discord, and support metadata.
- Added visible upstream/Disruption01 attribution in the Baganator settings UI, first-run welcome screen, minimap-button tooltip, and Syndicator settings UI.
- Added a native 3.3.5a Baganator minimap button (left-click bags, right-click settings).
- Added repository-level README, credits, changelog, and license notice.

### Upstream bases

- Baganator: `823-2-ged5d1c8`
- Syndicator: `279`
