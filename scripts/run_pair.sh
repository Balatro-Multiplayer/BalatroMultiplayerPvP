#!/usr/bin/env bash
# Run one multi-client scenario and exit 0 only if every role passed and every
# STATE checkpoint matched the first role's (macOS).
#
#   bash scripts/run_pair.sh pair_pvp_blind
#
# Roles are host and guest, unless the scenario has a `-- roles: a b c` line.
#
# Installed Mods must link this checkout and MPAPI. The Dev mod (server dev/client/)
# is linked for the run if it isn't installed, and unlinked afterwards.
# The server is reused if 127.0.0.1:7350 answers, else started from
# BMP_SERVER_DIR/compose.local.yml and left running.
# Env: BALATRO_DIR, BMP_SERVER_DIR (default .context/BalatroMultiplayerServer),
# SCENARIO_TIMEOUT (seconds, default 300).
set -euo pipefail

NAME="${1:?usage: run_pair.sh <scenario>}"
SELECTOR="MultiplayerPvP:$NAME"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
MODS="$HOME/Library/Application Support/Balatro/Mods"
GAME_DIR="${BALATRO_DIR:-$HOME/Library/Application Support/Steam/steamapps/common/Balatro}"
SERVER_DIR="${BMP_SERVER_DIR:-$REPO/.context/BalatroMultiplayerServer}"
HEALTH="http://127.0.0.1:7350/healthcheck"
TIMEOUT="${SCENARIO_TIMEOUT:-300}"
pids=()
dev_link=

die() {
  printf 'pair: %s\n' "$*" >&2
  exit 1
}

[[ "$NAME" =~ ^[A-Za-z0-9_-]+$ ]] || die "expected a scenario name"
[[ -f "$REPO/tests/scenarios/$NAME.lua" ]] || die "no tests/scenarios/$NAME.lua"
read -r -a ROLES <<<"$(sed -n 's/^-- roles: *//p' "$REPO/tests/scenarios/$NAME.lua" | head -1)"
[[ ${#ROLES[@]} -gt 0 ]] || ROLES=(host guest)
for role in "${ROLES[@]}"; do [[ "$role" =~ ^[A-Za-z0-9_]+$ ]] || die "bad role $role"; done
[[ -f "$GAME_DIR/run_lovely_macos.sh" ]] || die "missing $GAME_DIR/run_lovely_macos.sh"
[[ "$(cd "$MODS/MultiplayerPvP" 2>/dev/null && pwd -P)" == "$REPO" ]] ||
  die "Mods/MultiplayerPvP must link $REPO"
if pgrep -f 'Balatro.app/Contents/MacOS/love' >/dev/null; then die "Balatro is already running"; fi

server_up() {
  if curl -fs "$HEALTH" >/dev/null; then
    printf 'pair: reusing server on :7350 (%s)\n' \
      "$(docker inspect bmp-nakama --format '{{index .Config.Labels "com.docker.compose.project.working_dir"}}' 2>/dev/null || echo unknown)"
    return
  fi
  [[ -f "$SERVER_DIR/compose.local.yml" ]] || die "no server at $SERVER_DIR; set BMP_SERVER_DIR"
  docker compose -f "$SERVER_DIR/compose.local.yml" up -d nakama >&2
  local second
  for ((second = 0; second < 60; second++)); do
    curl -fs "$HEALTH" >/dev/null && return
    sleep 1
  done
  die "server did not answer $HEALTH"
}

dev_mod() {
  local entry
  for entry in "$MODS"/*; do
    [[ -f "$entry/MultiplayerDev.json" ]] && return
  done
  [[ -f "$SERVER_DIR/dev/client/MultiplayerDev.json" ]] || die "no Dev mod at $SERVER_DIR/dev/client"
  dev_link="$MODS/MultiplayerDev"
  ln -s "$SERVER_DIR/dev/client" "$dev_link"
}

RUN_DIR="$(mktemp -d "${TMPDIR:-/tmp}/bmp-pair.XXXXXX")"
RUN_ID="${RUN_DIR##*/}"
touch "$RUN_DIR/started"

# Kill only this run's games: each launch script's child, then the script.
cleanup() {
  local pid
  for pid in ${pids[@]+"${pids[@]}"}; do
    [[ -n "$pid" ]] || continue
    pkill -KILL -P "$pid" 2>/dev/null || true
    kill -KILL "$pid" 2>/dev/null || true
  done
  [[ -z "$dev_link" ]] || rm -f "$dev_link"
  docker logs --since "$started_at" bmp-nakama >"$RUN_DIR/nakama.log" 2>&1 || true
}
started_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

server_up
dev_mod

# Fresh test accounts (Device login via the Dev mod) per role and run, so no
# account has a seat left over from a killed run (the Reconnect prompt).
for role in "${ROLES[@]}"; do
  BMP_SCENARIO="$SELECTOR" BMP_SCENARIO_QUIT=1 BMP_SCENARIO_RUN_ID="$RUN_ID-$role" \
    BMP_IMPERSONATE_NAME="pair-$role-${RUN_ID##*.}" BMP_ROLE="$role" BMP_ROLES="${ROLES[*]}" BMP_PAIR_DIR="$RUN_DIR" \
    bash "$GAME_DIR/run_lovely_macos.sh" >"$RUN_DIR/$role.launch.log" 2>&1 &
  pids+=($!)
  sleep 2 # Lovely names logs by the second; same-second launches share one file.
done

for ((second = 0; second < TIMEOUT; second++)); do
  running=0
  for pid in ${pids[@]+"${pids[@]}"}; do
    if kill -0 "$pid" 2>/dev/null; then running=1; fi
  done
  [[ "$running" -eq 0 ]] && break
  sleep 1
done
[[ "$running" -eq 0 ]] || die "timed out after ${TIMEOUT}s; launch output in $RUN_DIR"

# Each game writes its own Lovely log; the START line's run id says whose it is.
results() {
  local role="$1" start="BMP_SCENARIO START $SELECTOR run=$RUN_ID-$1" log candidate
  for candidate in "$MODS/lovely/log/"*; do
    [[ -f "$candidate" && "$candidate" -nt "$RUN_DIR/started" ]] || continue
    if grep -Fq "$start" "$candidate"; then log="$candidate"; fi
  done
  [[ -n "${log:-}" ]] || die "$role: no Lovely log from this run"
  printf '%s: %s\n' "$role" "$log"
  ln -sf "$log" "$RUN_DIR/$role.lovely.log"
  grep -o 'BMP_SCENARIO .*' "$log" | \
    awk -v start="$start" '{ sub(/[[:space:]]+$/, "") } $0 == start { started=1 } started { print }' \
    >"$RUN_DIR/$role.results" || true
  sed "s/^/$role | /" "$RUN_DIR/$role.results"
  grep '^BMP_SCENARIO STATE ' "$RUN_DIR/$role.results" >"$RUN_DIR/$role.state" || true
}

failed=0
for role in "${ROLES[@]}"; do
  results "$role"
  if grep -q '^BMP_SCENARIO FAIL ' "$RUN_DIR/$role.results" ||
    ! grep -Eq '^BMP_SCENARIO DONE pass=[1-9][0-9]* fail=0$' "$RUN_DIR/$role.results"; then
    printf 'pair: %s failed\n' "$role" >&2
    failed=1
  fi
done

first="${ROLES[0]}"
[[ -s "$RUN_DIR/$first.state" ]] || die "no STATE checkpoints; run dir $RUN_DIR"
for role in "${ROLES[@]:1}"; do
  diff -u "$RUN_DIR/$first.state" "$RUN_DIR/$role.state" || die "$first and $role disagree; run dir $RUN_DIR"
done
[[ "$failed" -eq 0 ]] || die "scenario failed; run dir $RUN_DIR"
printf 'pair: passed, run dir %s\n' "$RUN_DIR"
