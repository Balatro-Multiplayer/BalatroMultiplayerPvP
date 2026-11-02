#!/usr/bin/env bash
# Run one two-client scenario and exit 0 only if host and guest both passed and
# every STATE checkpoint matched (macOS).
#
#   bash scripts/run_pair.sh pair_pvp_blind
#
# Same install requirements as MPAPI scripts/run_scenario.sh: Installed Mods link
# this checkout and MPAPI, plus the Dev mod that starts the runner.
# Env: BALATRO_DIR, SCENARIO_TIMEOUT (seconds, default 300).
# TODO: server. Expects one already reachable; start it here once clients can log in.
set -euo pipefail

NAME="${1:?usage: run_pair.sh <scenario>}"
SELECTOR="MultiplayerPvP:$NAME"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
MODS="$HOME/Library/Application Support/Balatro/Mods"
GAME_DIR="${BALATRO_DIR:-$HOME/Library/Application Support/Steam/steamapps/common/Balatro}"
TIMEOUT="${SCENARIO_TIMEOUT:-300}"
ROLES=(host guest)
pids=()

die() {
  printf 'pair: %s\n' "$*" >&2
  exit 1
}

[[ "$NAME" =~ ^[A-Za-z0-9_-]+$ ]] || die "expected a scenario name"
[[ -f "$REPO/tests/scenarios/$NAME.lua" ]] || die "no tests/scenarios/$NAME.lua"
[[ -f "$GAME_DIR/run_lovely_macos.sh" ]] || die "missing $GAME_DIR/run_lovely_macos.sh"

RUN_DIR="$(mktemp -d "${TMPDIR:-/tmp}/bmp-pair.XXXXXX")"
RUN_ID="${RUN_DIR##*/}"
touch "$RUN_DIR/started"

# Kill only this run's games: each launch script's child, then the script.
cleanup() {
  local pid
  for pid in "${pids[@]}"; do
    [[ -n "$pid" ]] || continue
    pkill -KILL -P "$pid" 2>/dev/null || true
    kill -KILL "$pid" 2>/dev/null || true
  done
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

for role in "${ROLES[@]}"; do
  BMP_SCENARIO="$SELECTOR" BMP_SCENARIO_QUIT=1 BMP_SCENARIO_RUN_ID="$RUN_ID-$role" \
    BMP_ROLE="$role" BMP_PAIR_DIR="$RUN_DIR" \
    bash "$GAME_DIR/run_lovely_macos.sh" >"$RUN_DIR/$role.launch.log" 2>&1 &
  pids+=($!)
done

for ((second = 0; second < TIMEOUT; second++)); do
  running=0
  for pid in "${pids[@]}"; do
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

[[ -s "$RUN_DIR/host.state" ]] || die "no STATE checkpoints"
diff -u "$RUN_DIR/host.state" "$RUN_DIR/guest.state" || die "clients disagree"
[[ "$failed" -eq 0 ]] || die "scenario failed"
printf 'pair: passed, run dir %s\n' "$RUN_DIR"
