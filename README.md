![ModIcon](assets/2x/modicon.png)

# Balatro Multiplayer PvP

Head-to-head Balatro. There are many ways to play but generally 2-16 people in a lobby face off on the same seed, battling another player(s) each boss blind until everyone runs out of lives but one.

This is the PvP mod of the Balatro Multiplayer Platform. It runs on top of [MultiplayerAPI](https://github.com/Balatro-Multiplayer/BalatroMultiplayerAPI), which owns the connection, accounts, lobbies, matchmaking, and leaderboards. Sibling mods on the same API include [Speedrunning](https://github.com/Balatro-Multiplayer/BalatroMultiplayerSpeedrunning). The server lives in [BalatroMultiplayerServer](https://github.com/Balatro-Multiplayer/BalatroMultiplayerServer).

> **Looking for the original Balatro Multiplayer mod (v0.5.x, mod id `Multiplayer`)?** It lives on the [`legacy` branch](https://github.com/Balatro-Multiplayer/BalatroMultiplayerPvP/tree/legacy). That code is frozen`.

## Installation

### Launchers

Launchers are the easiest ways to get modded Balatro running quickly. We have two main launchers we support:

#### R2 Mod Man

We recommend downloading the mod with r2mm if you intend to play it casually. You can download r2mm here: [https://r2modman.com/](https://r2modman.com/)

#### BET

Otherwise you can use own custom closed source launcher called BET, which is intended to be a successor of BMM. You can download BET here: [https://new.balatromp.com/download](https://new.balatromp.com/download)

### Manual

Requirements:

- [Steamodded](https://github.com/Steamodded/smods) (>= 1.0.0~BETA-1814a)
- [Lovely Injector](https://github.com/ethangreen-dev/lovely-injector) (>= 0.10)
- [MultiplayerAPI](https://github.com/Balatro-Multiplayer/BalatroMultiplayerAPI) (required dependency)
- Balatro running through Steam (the API signs in with your Steam account)

Steps:

1. Install Steamodded, Lovely and MultiplayerAPI.
2. Download the latest release of this mod from the [Releases page](https://github.com/Balatro-Multiplayer/BalatroMultiplayerPvP/releases).
3. Extract it into its own folder in your Balatro `Mods` directory. Make sure the folder is not nested inside a second folder of the same name.
4. Launch the game and pick **PvP** from the multiplayer menu.

The old `Multiplayer` mod conflicts with this one; remove it before installing. More help is on [balatromp.com](https://balatromp.com) and in the [Discord](https://discord.gg/balatromp).

## AI Content Disclaimer

This mod does NOT use AI for art or other assets. This mod uses generative AI in it's development as a tool for writing code.

## Custom Solo prototype

Choose **CUSTOM SOLO** below the vanilla main-menu buttons. Pick a base ruleset,
deck, stake, optional seed and manual house rules.

- Normal bosses, win/loss conditions and saving; not Practice's no-fail mode.
- No Steam sign-in, server, opponent or ratings required.
- Purple cells are selected; grey cells are inherited from the base.
- House rules last the whole run. Random Chaos Clock scheduling is not enabled.
- The **Balance** column offers Kind Wraith and Dice Patch. Dice Patch changes
  Oops! All 6s to X1.75, Lucky's $20 chance to 1 in 10, and 8 Ball / Space Joker
  to 1 in 3.
- Custom runs do not earn vanilla unlocks. Opponent-dependent cards still need
  multiplayer to perform their multiplayer interactions.

## Contributing

Contributions are welcome. Read [CONTRIBUTING.md](CONTRIBUTING.md) for setup and guidelines.

Content changes (new cards, blinds, rulesets, formats, or anything that alters competitive balance) are heavily scrutinized, so open an issue or ask on Discord first. Bug fixes and quality-of-life work are always welcome, check the [issues](https://github.com/Balatro-Multiplayer/BalatroMultiplayerPvP/issues), especially those tagged "Help Wanted".

Testing happens against real, running game instances: launch two or more clients, put them in a lobby and play the change through.

## License

GNU General Public License v3.0. See [LICENSE.md](LICENSE.md).
