# Balatro Multiplayer PvP

![ModIcon](assets/2x/modicon.png)

Head-to-head Balatro. Everyone plays the same seed with the same shops and packs, and at PvP blinds your target is your opponents' live score. Lose a PvP blind and you lose a life; the last player standing wins.

This is the PvP mod of the Balatro Multiplayer Platform. It runs on top of [MultiplayerAPI](https://github.com/Balatro-Multiplayer/BalatroMultiplayerAPI), which owns the connection, accounts, lobbies, matchmaking, leaderboards, replays and the multiplayer main menu. Sibling mods on the same API include [Speedrunning](https://github.com/Balatro-Multiplayer/BalatroMultiplayerSpeedrunning); the server lives in [BalatroMultiplayerServer](https://github.com/Balatro-Multiplayer/BalatroMultiplayerServer).

> **Looking for the original Balatro Multiplayer mod (v0.5.x, mod id `Multiplayer`)?** It lives on the [`legacy` branch](https://github.com/Balatro-Multiplayer/BalatroMultiplayerPvP/tree/legacy). That code is frozen; new development happens here on `main`.

## Installation

Requirements:

- [Steamodded](https://github.com/Steamodded/smods) (>= 1.0.0~BETA-1814a)
- [Lovely Injector](https://github.com/ethangreen-dev/lovely-injector) (>= 0.9)
- [MultiplayerAPI](https://github.com/Balatro-Multiplayer/BalatroMultiplayerAPI) (required dependency)
- Balatro running through Steam (the API signs in with your Steam account)

Steps:

1. Install Steamodded, Lovely and MultiplayerAPI.
2. Download the latest release of this mod from the [Releases page](https://github.com/Balatro-Multiplayer/BalatroMultiplayerPvP/releases).
3. Extract it into its own folder in your Balatro `Mods` directory. Make sure the folder is not nested inside a second folder of the same name.
4. Launch the game and pick **PvP** from the multiplayer menu.

The old `Multiplayer` mod conflicts with this one; remove it before installing. More help is on [balatromp.com](https://balatromp.com) and in the [Discord](https://discord.gg/balatromp).

## How to play

From the PvP menu:

- **Find Game**: queue for ranked (2 players, rated per ruleset) or casual matches.
- **Create Lobby / Join Lobby**: private lobby by code (typed or from the clipboard), with Lobby Options for the host.
- **Practice**: a solo, local run on any ruleset, for trying content before a real match.
- **Leaderboard**: per-ruleset ranked standings.
- **My Replays / Spectate**: watch your finished matches back, or spectate a live one.

### Match formats

| Format | Players | Notes |
|---|---|---|
| **Nemesis** | 2-16 | Rotating 1v1 duels each ante. With 2 players it is a plain head-to-head. Ranked and casual. |
| **Small World** | 2-16 | Nemesis on the Small World ruleset. Ranked and casual. |
| **Royale** | 2-16 | Everyone against everyone; the lowest scores are cut each PvP round. Casual and private. |
| **Manhunt** | 2-16 | One Runner with a single life against a pack of Hunters. Casual and private. |
| **Teams** | 2-16 | Two teams sharing a life pool. Casual and private. |

Ranked matches open with a deck and stake ban/pick draft.

### Rulesets

A ruleset decides which cards are in the pool, which are reworked, and how the timer behaves. Rulesets are built by composing reusable **layers**.

| Ruleset | What it is |
|---|---|
| **Balanced** | The main competitive ruleset: PvP jokers, balance reworks, PvP timer, locked lobby options. Default for new lobbies. |
| **Expanded** | The standard PvP card pool and reworks, with lobby options left to the host. |
| **Vanilla** | Plays like unmodded Balatro cards-wise: no bans, reworks or PvP-only content. |
| **Small World** | Standard pool with a large, seeded random chunk of it banned each match. |
| **Experimental** | Rebalance playtest ruleset; practice and private lobbies only. |

Balanced, Expanded, Vanilla and Small World each have their own ranked queue and ladder.

More rulesets exist in `rulesets/` (Sandbox, Chaos, Speedlatro, Traditional, Legacy Ranked, Major/Minor League and others) for private play and events. Hosts can also add **modifier** layers (timer variants, economy and shop mutators, trap cards, and so on) on top of any ruleset from Lobby Options.

## Repository layout

| Path | Contents |
|---|---|
| `MultiplayerPvP.json` | Steamodded manifest (mod id `MultiplayerPvP`, prefix `mp`) |
| `core.lua` | Entry point: global state, file loading, registration with MultiplayerAPI |
| `pvp_api/` | Everything that talks to MultiplayerAPI: match formats, lobby bridge, matchmaking queues, host referee, reconnect, spectating, and the `pvp_*` network actions in `pvp_api/actions/` |
| `networking/` | The in-game PvP message handlers that the API transport feeds into |
| `rulesets/` | Ruleset definitions (each a short list of layers plus overrides) |
| `layers/` | Reusable bundles of bans, reworks, scalars and hooks; also modifier layers |
| `gamemodes/` | Blind-selection profiles (Attrition) used by the match formats |
| `objects/` | Jokers, consumables, blinds, decks, stakes, tags, editions, enhancements, boosters, challenges |
| `ui/` | Main menu pages, lobby, in-game HUD, replay/spectate browsers, settings tabs |
| `lib/` | Shared helpers: big-number scores, practice mode, replay playback, rejoin, utilities |
| `overrides/` | Lua wraps of vanilla functions |
| `lovely/` | Lovely patches into vanilla and Steamodded source |
| `compatibility/` | Shims for other popular mods |
| `localization/` | Translations |
| `assets/` | Sprites at 1x and 2x |
| `scripts/` | Release build and asset scaling helpers |

## Contributing

Contributions are welcome. Read [CONTRIBUTING.md](CONTRIBUTING.md) for setup, formatting (StyLua) and the PR process, and [AGENTS.md](AGENTS.md) for the architecture notes and code conventions; both apply to human and AI-assisted contributions alike.

Content changes (new cards, blinds, rulesets, formats, or anything that alters competitive balance) need team sign-off before they are merged, so open an issue or ask on Discord first. Bug fixes and quality-of-life work are always welcome; check the [issues](https://github.com/Balatro-Multiplayer/BalatroMultiplayerPvP/issues), especially those tagged "Help Wanted".

Testing happens against real, running game instances: launch two or more clients, put them in a lobby and play the change through. Include example seeds in your PR where a change is visible in play.

## License

GNU General Public License v3.0. See [LICENSE.md](LICENSE.md).

## Acknowledgements

- LocalThunk, for creating Balatro
- Created by Virtualized, with major contributions from TGMM, Senfinbrare, CUexter, Brawmario, Divvy, Andy, Steph, SleepyG11 and [all the contributors](https://github.com/Balatro-Multiplayer/BalatroMultiplayerPvP/graphs/contributors)
- @MathIsFun_ and the Balatro Multiplayer project, for the ruleset and layer systems
- The Discord community, for feedback, testing and support

[Discord](https://discord.gg/balatromp) | [Website](https://balatromp.com)
