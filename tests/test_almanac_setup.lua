-- Five-stake setup and White- voucher contracts. No rendered/live-game evidence.
local checks = 0
local function check(value, message)
	assert(value, message)
	checks = checks + 1
end
PVP = {}
G = {
	FUNCS = {},
	C = { WHITE = {} },
	P_CENTERS = { b_mp_almanac = { name = "Almanac" } },
	P_CENTER_POOLS = { Back = {}, Stake = {} },
}
dofile("lib/_random.lua")
dofile("lib/draft.lua")
local D = PVP.DRAFT
local keys = {
	"stake_white",
	"stake_red",
	"stake_green",
	"stake_black",
	"stake_blue",
	"stake_purple",
	"stake_orange",
	"stake_gold",
	"stake_mp_planet",
	"stake_mp_spectral",
	"stake_mp_spectralplus",
	"stake_mp_white_minus",
}
local function rolls(first, second)
	local calls = 0
	return function()
		calls = calls + 1
		assert(calls <= 2, "Almanac rolls exactly two independent substitutions")
		return calls == 1 and first or second
	end
end
for _, a in ipairs({ 0, 0.499999, 0.5, 0.999999 }) do
	for _, b in ipairs({ 0, 0.499999, 0.5, 0.999999 }) do
		local board = D.almanac_board(keys, { rng = rolls(a, b) })
		local stakes, ids = {}, {}
		check(#board == 5, "exactly five tiles")
		for _, tile in ipairs(board) do
			check(tile.key == "b_mp_almanac", "mandatory Almanac deck")
			check(tile.id == tile.key .. "@" .. tile.stake and not ids[tile.id], "unique deck/stake tile IDs")
			ids[tile.id], stakes[tile.stake] = true, true
		end
		check(stakes[3] and stakes[4] and stakes[6], "Green, Black and Purple always offered")
		check(stakes[a < 0.5 and 12 or 1] and not stakes[a < 0.5 and 1 or 12], "White- replaces White at 50%")
		check(
			stakes[b < 0.5 and 11 or 8] and not stakes[b < 0.5 and 8 or 11],
			"Spectral+ replaces Gold independently at 50%"
		)
	end
end
local bad_rng = function()
	error("Invalid configurations must not consume RNG")
end
local valid, reason = pcall(D.almanac_board, keys, { max_stake = 8, rng = bad_rng })
check(not valid and tostring(reason):find("stake cap", 1, true), "unsupported cap is not silently substituted")
local missing = {}
for i = 1, #keys - 1 do
	missing[i] = keys[i]
end
valid, reason = pcall(D.almanac_board, missing, { rng = bad_rng })
check(
	not valid and tostring(reason):find("stake_mp_white_minus", 1, true),
	"missing White- is not silently substituted"
)

-- Real layer resolver and the real run-start Draft config.
local api = os.getenv("MPAPI_DIR") or "../BalatroMultiplayerAPI/"
if api:sub(-1) ~= "/" then api = api .. "/" end
MPAPI = {}
dofile(api .. "api/layers/registry.lua")
dofile(api .. "api/layers/fields.lua")
dofile(api .. "api/ruleset/current.lua")
MPAPI.MODIFIERS, MPAPI.Rulesets = {}, {}
PVP.Rulesets = MPAPI.Rulesets
function PVP.Ruleset(init)
	PVP.Rulesets["ruleset_mp_" .. init.key] = MPAPI.resolve_layers(init)
	return { inject = function() end }
end
for _, name in ipairs({ "balanced", "expanded", "expanded_draft", "pvp_timer", "almanac" }) do
	dofile("layers/" .. name .. ".lua")
end
dofile("rulesets/expanded.lua")
dofile("rulesets/zz_almanac.lua")
local expanded, almanac = PVP.Rulesets.ruleset_mp_expanded, PVP.Rulesets.ruleset_mp_almanac
for i, layer in ipairs(expanded._layer_order) do
	check(almanac._layer_order[i] == layer, "Almanac inherits Expanded's actual layer chain")
end
check(almanac.pvp_timer_base_seconds == expanded.pvp_timer_base_seconds, "Expanded's timer is retained")
check(almanac.multiplayer_content == expanded.multiplayer_content, "Expanded's multiplayer content is retained")
PVP.LOBBY = { config = {}, deck = {} }
almanac.force_lobby_options()
check(
	PVP.LOBBY.config.back == "Almanac" and PVP.LOBBY.deck.back == "Almanac",
	"required deck is pinned on both loadouts"
)
check(
	PVP.LOBBY.config.sleeve == "sleeve_casl_none" and PVP.LOBBY.deck.sleeve == "sleeve_casl_none",
	"no sleeve changes the carrier"
)
for i, key in ipairs(keys) do
	G.P_CENTER_POOLS.Stake[i] = { key = key }
end
PVP.DECK = { MAX_STAKE = 0 }
PVP._pvp_action_helpers = { A = function() end, A_host = function() end, relay = function() end }
dofile("pvp_api/setup.lua")
dofile("pvp_api/actions/run_lifecycle.lua")
local config = PVP._ban_pick_config_for({ ban_pick = { pool_size = 9 } }, "ruleset_mp_almanac")
check(config.pool_size == 5 and config.schedule == D.almanac_policy.schedule, "real setup selects five-stake policy")
local board = config.build_pool()
check(#board == 5, "real setup builds five tiles")
for _, tile in ipairs(board) do
	check(tile.key == "b_mp_almanac", "real setup never offers another deck")
end
check(#config.schedule == 4 and config.schedule[4].action == "pick", "three alternating bans then a pick from two")
for i, turn in ipairs(config.schedule) do
	check(turn.count == 1 and turn.actor == (i % 2 == 1 and 1 or 2), "same first/second roles as Expanded")
end

local players, messages, starts = { { id = "a" }, { id = "b" } }, {}, 0
local format = "pvp_nemesis"
local lobby = {
	is_host = true,
	server_features = { almanac_draft = 1, shared_pvp_rules = 2 },
	_game = { started = { players = players } },
	get_players = function()
		return players
	end,
	get_metadata = function()
		return { ruleset = "ruleset_mp_almanac", queue_mode = format, deck = "Red Deck" }
	end,
	start_game = function()
		starts = starts + 1
	end,
	set_metadata = function() end,
}
MPAPI.Party, MPAPI.GameModes = { KIND = "party" }, { pvp_nemesis = { ban_pick = { pool_size = 9, schedule = {} } } }
MPAPI.get_current_lobby = function()
	return lobby
end
MPAPI.has_server_referee = function()
	return true
end
PVP.UI = { UTILS = {
	overlay_message = function(text)
		messages[#messages + 1] = text
	end,
} }
PVP.UTILS = {
	version_mismatches = function()
		return {}
	end,
}
PVP.SHARED_RULES = {
	supported = function(value)
		return value.server_features.shared_pvp_rules == 2
	end,
}
PVP.GamemodeKey = { PVP_NEMESIS = "pvp_nemesis" }
localize = function(key)
	return key
end
dofile("pvp_api/flow.lua")
PVP.LOBBY.config.ruleset = "ruleset_mp_almanac"
PVP._pvp_kind = "ranked"
players[3] = { id = "c" }
PVP.pvp_start_match()
check(starts == 0 and messages[#messages] == "k_almanac_two_players", "Almanac refuses a larger lobby")
players[3] = nil
format = "pvp_teams"
PVP.pvp_start_match()
check(
	starts == 0 and messages[#messages] == "k_almanac_nemesis_required",
	"unsupported private formats do not bypass boss drafts"
)
format = "pvp_nemesis"
lobby.server_features.almanac_draft = nil
PVP.pvp_start_match()
check(starts == 0 and messages[#messages] == "k_almanac_server_required", "older server is rejected before starting")
lobby.server_features.almanac_draft = 1
PVP.DECK.MAX_STAKE = 8
PVP.pvp_start_match()
check(
	starts == 0 and messages[#messages] == "k_almanac_stakes_required",
	"incompatible stake cap is explained before starting"
)
PVP.DECK.MAX_STAKE = 0
PVP.pvp_start_match()
check(starts == 1, "compatible two-player lobby starts normally")
PVP._pvp_kind = "private"
PVP.is_matchmaking = function()
	return false
end
local plan, sent
PVP.SETUP.begin = function(_, value, start_draft, done)
	plan = value
	start_draft(done)
end
MPAPI.BanPick = {
	start = function(_, value, done)
		check(value.pool_size == 5, "private Almanac uses the five-stake draft")
		done({ { key = "b_red", stake = 12 } }) -- The carrier cannot be overridden by a stale/wrong deck.
	end,
}
PVP.referee_reset = function() end
PVP.dispatch_action = function(_, params)
	sent = params
end
PVP.on_game_start({ seed = "SETUP", stake = 1 })
check(plan.draft and not plan.votes, "private Almanac drafts stakes without casual votes")
check(
	sent.stake == 12 and PVP.LOBBY.deck.back == "Almanac",
	"drafted White- and mandatory deck reach the real run-start path"
)

-- The actual White- stake and queued voucher hook.
local stake
SMODS = {
	Stake = function(def)
		stake = def
	end,
}
dofile("objects/stakes/zz_white_minus.lua")
check(
	stake.key == "white_minus" and stake.applied_stakes[1] == "white" and #stake.applied_stakes == 1,
	"White- inherits only White"
)
check(not stake.above_stake, "White- appends without moving existing stake indices")
check(stake.prefix_config.applied_stakes.mod == false, "White is a vanilla stake, not a mod-prefixed stake")
local queue, grants = {}, {}
Event = function(event)
	return event
end
G.E_MANAGER = {
	add_event = function(_, event)
		queue[#queue + 1] = event
	end,
}
G.P_CENTERS.v_grabber, G.P_CENTERS.v_wasteful = { key = "v_grabber" }, { key = "v_wasteful" }
Card = {
	apply_to_run = function(_, center)
		grants[#grants + 1] = center.key
		local field = center.key == "v_grabber" and "hands" or "discards"
		G.GAME.round_resets[field] = G.GAME.round_resets[field] + 1
	end,
}
Back = {
	apply_to_run = function()
		return "original"
	end,
}
dofile("overrides/white_minus.lua")
local function fresh()
	G.GAME = { modifiers = {}, used_vouchers = {}, round_resets = { hands = 4, discards = 3 } }
	queue, grants = {}, {}
end
local function drain()
	for _, event in ipairs(queue) do
		event.func()
	end
	queue = {}
end
fresh()
stake.modifiers()
check(Back.apply_to_run({}) == "original", "original back setup and return value are preserved")
Back.apply_to_run({})
check(#grants == 0 and not G.GAME.mp_white_minus_vouchers, "vouchers wait until card areas exist")
drain()
check(#grants == 2 and grants[1] == "v_grabber" and grants[2] == "v_wasteful", "both starting vouchers are granted")
check(
	G.GAME.round_resets.hands == 5 and G.GAME.round_resets.discards == 4,
	"White- starts with one extra hand and discard"
)
Back.apply_to_run({})
drain()
check(#grants == 2, "a repeated back setup or restored completion marker cannot grant twice")
fresh()
stake.modifiers()
G.GAME.used_vouchers.v_grabber = true
Back.apply_to_run({})
drain()
check(#grants == 1 and grants[1] == "v_wasteful", "an already-owned voucher is never applied again")
fresh()
Back.apply_to_run({})
drain()
check(#grants == 0 and not G.GAME.mp_white_minus_vouchers, "ordinary White and other stakes are unchanged")
fresh()
stake.modifiers()
Back.apply_to_run({})
local stale = queue
fresh()
for _, event in ipairs(stale) do
	event.func()
end
check(#grants == 0, "an abandoned run cannot grant vouchers to a later run")
print("Almanac setup: " .. checks .. " checks passed")
