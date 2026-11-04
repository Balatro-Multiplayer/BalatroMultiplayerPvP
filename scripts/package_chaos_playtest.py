#!/usr/bin/env python3
"""Bundle current PvP + matching API worktrees without private/developer files."""

import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import subprocess
import zipfile

EXCLUDED = {"scripts", "tests", "docs", "dev", "dist", "replays", "__pycache__"}
ROOT = Path(__file__).resolve().parents[1]
INSTALL = """CHAOS DECK DRAFT - EXPERIMENTAL PLAYTEST

Requires your own Balatro, Steamodded and Lovely.
Tested locally with Balatro 1.0.1o, Steamodded BETA-1814a and Lovely 0.9.0.
Steamodded, Lovely and the game itself are NOT included.

INSTALL
1. Close Balatro. Back up your Balatro save/profile before testing.
2. Extract MultiplayerAPI and MultiplayerPvP directly into your Balatro Mods
   directory. Each folder should contain its matching .json manifest and core.lua.
3. Remove/disable older copies of these two mods, including the old combined
   Multiplayer mod. Do not install this alongside duplicate copies.
4. Launch Balatro with Lovely.

PLAY SOLO
Main menu -> Custom Solo -> Deck: Chaos (deck draft) -> Play.
Use Vanilla / no manual modifiers for the plain baseline.
Ante 1 starts with no deck effects. At antes 2, 3, 5 and 7, choose one of three decks.
Click once to select; click that same deck again to commit.
Acquisitions accumulate without repeating. Plasma is excluded.
Hover the draw pile to fan up to eight acquired backs.
Click the pile -> Chaos decks to inspect all acquired decks.

KNOWN LIMITATIONS
This bundles the current worktrees as a prototype, not an official release.
Shop reloads have reported "Card area shop_* not instantiated before load".
Shop contents may not restore correctly; prefer uninterrupted playtest runs.
Full multiplayer/rejoin/replay fidelity has not been live-verified.
The public Chaos queue still says Coming Soon.
Existing mod interactions and gameplay balance are not comprehensively tested.

The bundle includes the matching API, Windows/macOS networking libraries and
their notices. Linux networking requires compatible system OpenSSL libraries.
Local .env files, server dev overrides, notes and replays are not included.
"""


def files(repo):
    output = subprocess.check_output(
        ["git", "-C", str(repo), "ls-files", "-z", "--cached", "--others", "--exclude-standard"]
    )
    for relative in sorted(set(output.decode().split("\0")) - {""}):
        path = Path(relative)
        if any(part.startswith(".") or part in EXCLUDED for part in path.parts):
            continue
        if path.name in {"AGENT.md", "AGENTS.md", "CLAUDE.md", "CONTRIBUTING.md", "stylua.toml"}:
            continue
        source = repo / path
        if source.is_symlink():
            raise RuntimeError(f"Refusing to package symlink: {relative}")
        if source.is_file():
            yield relative, source


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--api", type=Path, required=True)
    args = parser.parse_args()
    api = args.api.resolve()
    for repo, mod in ((ROOT, "MultiplayerPvP"), (api, "MultiplayerAPI")):
        manifest = json.loads((repo / f"{mod}.json").read_text())
        assert manifest["id"] == mod
    stamp = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S")
    destination = ROOT / "dist" / f"Chaos-playtest-{stamp}.zip"
    destination.parent.mkdir(exist_ok=True)
    inventory = {}
    with zipfile.ZipFile(destination, "x", compression=zipfile.ZIP_DEFLATED) as bundle:
        bundle.writestr("READ-ME-FIRST.txt", INSTALL)
        for repo, mod in ((ROOT, "MultiplayerPvP"), (api, "MultiplayerAPI")):
            for relative, source in files(repo):
                name = f"{mod}/{relative}"
                data = source.read_bytes()
                bundle.writestr(name, data)
                inventory[name] = hashlib.sha256(data).hexdigest()
        bundle.writestr("CONTENTS-SHA256.json", json.dumps(inventory, indent=2) + "\n")
    with zipfile.ZipFile(destination) as bundle:
        assert bundle.testzip() is None
        for name, digest in inventory.items():
            assert hashlib.sha256(bundle.read(name)).hexdigest() == digest
        for name in (
            "MultiplayerPvP/core.lua", "MultiplayerAPI/core.lua",
            "MultiplayerPvP/lib/chaos_draft.lua", "MultiplayerPvP/ui/chaos_backs.lua",
            "MultiplayerPvP/assets/1x/chaos_back.png", "MultiplayerPvP/assets/2x/chaos_back.png",
            "MultiplayerAPI/networking/NOTICE-OpenSSL.txt",
        ):
            assert name in inventory, f"Missing required file: {name}"
    print(destination)
    print(f"{len(inventory)} files; {destination.stat().st_size / 1048576:.1f} MiB")
    print("ZIP integrity, required files and content hashes verified.")


if __name__ == "__main__":
    main()
