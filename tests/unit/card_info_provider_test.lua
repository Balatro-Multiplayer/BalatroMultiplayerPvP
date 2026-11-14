-- Run from the repo root: luajit tests/unit/card_info_provider_test.lua
-- The Lobby Info rows for the opponent: a best PvP score the server has not reported is shown as
-- unknown, never as 0.
local failures = 0
local function check(name, got, want)
	if got == want then
		print("ok   " .. name)
	else
		failures = failures + 1
		print(("FAIL %s: got %s, wanted %s"):format(name, tostring(got), tostring(want)))
	end
end

local provider
G = {
	STAGE = "run",
	STAGES = { RUN = "run" },
	UIT = { R = "R", T = "T" },
	C = { UI = { TEXT_DARK = {} } },
	GAME = { skips = 1 },
}
MPAPI = {
	register_card_info_provider = function(_, fn)
		provider = fn
	end,
}
PVP = {
	id = "pvp",
	GAME = { enemy = { skips = 2, highest_score = nil }, highest_pvp_score = "0", lives = 3 },
	LOBBY = { config = { team_based = false, starting_lives = 4 } },
	LobbyAccess = { RANKED = "ranked" },
	is_practice_mode = function()
		return false
	end,
	self_player_id = function()
		return "me"
	end,
	-- The server cache: "me" has 3 lives, "they" has no entry.
	lives_of = function(id)
		return id == "me" and 3 or nil
	end,
	Score = {
		display = function(text)
			return "D:" .. text
		end,
	},
}
-- The real text helper; lives_of stays the stub above.
local stub_lives_of = PVP.lives_of
dofile("lib/lives_lookup.lua")
PVP.lives_of = stub_lives_of
local strings = { k_lives = "Lives", k_skips = "Skips", k_best_pvp_score = "Best", k_best_pvp_score_unknown = "???" }
function localize(key)
	return strings[key]
end
dofile("ui/game/card_info_provider.lua")

local lobby = {
	get_players = function()
		return { {}, {} }
	end,
	get_metadata = function()
		return {}
	end,
}

local function best_row(player_id)
	local rows = provider(lobby, { id = player_id })
	return rows[#rows].nodes[1].config.text
end

check("an opponent with no reported best score shows it as unknown", best_row("they"), "Best: ???")
PVP.GAME.enemy.highest_score = "0"
check("a reported best score of 0 is shown as 0", best_row("they"), "Best: D:0")
PVP.GAME.enemy.highest_score = "500"
check("a reported best score is shown", best_row("they"), "Best: D:500")
check("my own best score is shown", best_row("me"), "Best: D:0")

local function skips_row(player_id)
	local rows = provider(lobby, { id = player_id })
	return rows[#rows - 1].nodes[1].config.text
end

check("an opponent's reported skips are shown", skips_row("they"), "2 Skips")
PVP.GAME.enemy.skips = nil
check("an opponent with unknown skips shows ???, not 0", skips_row("they"), "??? Skips")

local function lives_row_text(player_id)
	return provider(lobby, { id = player_id })[1].nodes[1].config.text
end

check("a player with a cached count shows it", lives_row_text("me"), "3 Lives")
check("a player missing from the cache shows ???", lives_row_text("they"), "??? Lives")

print(failures == 0 and "all passed" or (failures .. " failed"))
os.exit(failures == 0 and 0 or 1)
