# Baganator 3.3.5a Backport

A World of Warcraft **3.3.5a (build 12340)** compatibility backport of **Baganator** and its required companion addon **Syndicator**.

Original Baganator and Syndicator are developed by **plusmouse / The Mouse Nest**.  
3.3.5a backport and compatibility work is maintained by **Disruption01**.

## Status

**Disruption01 release:** `1.0.0`  
**Target:** World of Warcraft 3.3.5a — build 12340  
**Upstream bases:** Baganator `823-2-ged5d1c8`; Syndicator `279`

This repository targets the original 3.3.5a client API. It is not an official Classic build and should not be described as one.

## Features

The 3.3.5a port keeps the Baganator/Syndicator inventory model while adapting the UI and client integration to the Wrath-era API. Tested functionality includes:

- Baganator bags, bank, and guild-bank views.
- Item search and saved searches.
- Built-in sorting adapted to the 3.3.5a container API.
- Character selection and cached/offline inventory browsing.
- Gold and supported 3.3.5a currency summaries.
- Keyring and special-container handling.
- Inventory location information and Syndicator-backed item tracking.
- A native 3.3.5a settings/compatibility UI.

## Disruption01 Additions

The 3.3.5a work includes substantial compatibility and stability changes, including:

- Wrath-era container, guild-bank, tooltip, currency, scrolling, item-button, and frame compatibility.
- A private 3.3.5a options compatibility layer instead of publishing an incomplete modern `Settings` global.
- 3.3.5a-safe sorting with replanning, stale-state cleanup, and watchdog protection.
- 3.3.5a-safe pooled item-button rendering and empty-slot chrome.
- Native Wrath search, saved-search, character-select, help, and currency UI adaptations.
- Deterministic header-button rendering and keyring/special-container icon handling.
- Visible Disruption01 release versions in WoW's AddOns list.
- In-game credits preserving upstream authorship.

Detailed development history is retained in `Baganator/BACKPORT_NOTES.txt` and `Baganator/BACKPORT_NOTES_335.txt`.

## Compatibility

- **World of Warcraft 3.3.5a — build 12340**
- Lua 5.1 / Wrath-era WoW API

Other private-server cores may differ from a stock 12340 client. Server/core-specific behavior should be included in bug reports when relevant.

## Requirements

Both addon folders are required:

- `Baganator`
- `Syndicator`

`Syndicator` is a required dependency of Baganator in this backport.

## Installation

1. Download the latest release ZIP.
2. Extract it.
3. Copy both `Baganator` and `Syndicator` into your WoW `Interface\AddOns` directory.
4. Start or restart World of Warcraft.
5. In the AddOns list, verify that both addons show the same Disruption01 release version.

Do not install only one of the two folders.

## Configuration / Usage

Baganator exposes its 3.3.5a-compatible customisation window from the addon UI. Syndicator also registers a small compatibility page in Interface Options.

The 3.3.5a settings UI is intentionally narrower than the modern upstream configuration because modern `Settings`, `ScrollBox`, and `MenuUtil` systems do not exist on build 12340.

## Known Issues

- Modern Retail/official-Classic-only systems are not available on the 3.3.5a client and are not emulated globally.
- Some modern upstream configuration surfaces are intentionally simplified on 3.3.5a.
- Private-server cores can vary in bag, bank, guild-bank, item, and currency behavior even when the client build is 12340.

If a regression is found, please report the exact action sequence that triggers it rather than resetting SavedVariables unless specifically requested.

## Version

**Disruption01 release:** `1.0.0`

Upstream bases used by this port:

- Baganator: `823-2-ged5d1c8`
- Syndicator: `279`

Disruption01 version numbers are independent from upstream version numbers.

## Updating

Replace both addon folders together when updating a Disruption01 release. Keeping Baganator and Syndicator from different backport builds is not supported.

Normal updates should not require deleting `WTF` or SavedVariables unless a release note explicitly says so.

## Credits

Original Baganator by **plusmouse / The Mouse Nest**.  
Original project: https://www.curseforge.com/wow/addons/baganator

Original Syndicator by **plusmouse / The Mouse Nest**.  
Original project: https://www.curseforge.com/wow/addons/syndicator

Original license for both upstream projects: **All Rights Reserved**.

World of Warcraft 3.3.5a backport and compatibility work by **Disruption01**.

GitHub: https://github.com/disruption01  
Discord: https://discord.gg/eJ5MaVNnBm

See `CREDITS.md` for additional attribution details.

## License

The upstream Baganator and Syndicator source included here is marked **All Rights Reserved** by its original author. This repository does not relicense that upstream code. See `LICENSE` and the original license files inside each addon folder.

**Public redistribution of a modified build requires permission from the upstream rights holder unless a separate permission applies.**

## Bug Reports

Please report tracked bugs through GitHub Issues:

https://github.com/disruption01/Baganator_335a_backport/issues

Please include:

- Disruption01 addon version.
- WoW client/version and build.
- Full Lua error text, if any.
- Exact reproduction steps.
- Screenshots when useful.
- Server/core when relevant.

Discord is suitable for discussion and general help; GitHub Issues are preferred for tracked bugs.

## Contributing

Compatibility fixes and reproducible bug reports are welcome. Keep changes scoped to the real target client and preserve upstream authorship and attribution.

## Support

If you enjoy my addons and would like to support continued development, maintenance, ports, and backports:

https://linktr.ee/disruption01

Support is completely optional and does not unlock addon functionality.
