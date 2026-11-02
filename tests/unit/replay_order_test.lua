-- Run from the repo root: luajit tests/unit/replay_order_test.lua
local function noop() end
SMODS = { current_mod = {
	id = "MultiplayerPvP", path = ".",
	config = { integrations = {}, preview = {} },
	Score = { ZERO = 0 },
	UTILS = { timer_base = noop, get_username = noop, get_blind_col = noop, get_weekly = noop },
} }
NFS = { getInfo = noop, getDirectoryItemsInfo = function() return {} end }
G = { C = {}, E_MANAGER = { add_event = noop } }
HEX, Event, localize = noop, noop, function(key) return key end
sendDebugMessage = noop
local order_gate, rejoin_hooks
MPAPI = {
	OPCODE = { MATCH_MANIFEST = "match_manifest", LOBBY_INFO = "lobby_info", RUN_INFO = "run_info" },
	register_order_gate = function(fn) order_gate = fn end,
	register_voucher_queue_gate = noop,
	register_idol_gate = noop,
	playback = { register_rejoin_hooks = function(_, hooks) rejoin_hooks = hooks end },
}
dofile("core.lua")
dofile("lib/replay_bootstrap.lua")
dofile("lib/rejoin.lua")
local practice = false
PVP.is_practice_mode = function() return practice end

local function check(name, got, want)
	assert(got == want, name .. ": got " .. tostring(got) .. ", want " .. tostring(want))
	print("ok   " .. name)
end
local function recording(enabled)
	return {
		{ player_id = "me", opcode = "lobby_info", args = {
			ruleset = "ruleset_mp_vanilla", gamemode = "gamemode_mp_attrition",
			options = { the_order_enabled = enabled },
		} },
		{ player_id = "me", opcode = "run_info", args = { seed = "REJOIN01", deck = "Red Deck", stake = 1 } },
	}
end

for _, enabled in ipairs({ false, true }) do
	local timeline = recording(enabled)
	local bootstrap = PVP.replay_bootstrap(timeline, "me")
	check("replay preserves " .. tostring(enabled), bootstrap.the_order_enabled, enabled)
	local rejoin = {}
	rejoin_hooks.read_lobby_info(timeline[1].args, rejoin)
	check("rejoin preserves " .. tostring(enabled), rejoin.the_order_enabled, enabled)
	PVP.apply_replay_loadout(PVP.LOBBY, bootstrap)
	practice = true
	check("playback gate honors " .. tostring(enabled), order_gate(), enabled)
	practice = false
	PVP.LOBBY.code = "test"
	check("live gate honors " .. tostring(enabled), order_gate(), enabled)
	PVP.LOBBY.code = nil
	check("outside session stays off", order_gate(), false)
end

PVP.apply_replay_loadout(PVP.LOBBY, PVP.replay_bootstrap(recording(nil), "me"))
practice = true
check("older recording keeps default on", order_gate(), true)
PVP.LOBBY.config.the_order = false
PVP.reset_lobby_config()
check("fresh practice resets default on", order_gate(), true)
