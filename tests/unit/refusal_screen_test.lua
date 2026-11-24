-- Run from the repo root: luajit tests/unit/refusal_screen_test.lua
-- pvp_api/ui/refusal.lua: which refusals show a notice, and that each shows one.
local T = dofile("tests/support/check.lua")
local eq = T.eq

local shown = {}
G = {}
local function overlay_message(text)
	shown[#shown + 1] = text
	G.OVERLAY_MENU = {}
end
PVP = { UI = { UTILS = { overlay_message = overlay_message } } }
function localize(key)
	if type(key) == "table" then return "text:" .. key.key .. ":" .. table.concat(key.vars, ",") end
	return "text:" .. key
end
dofile("pvp_api/ui/refusal.lua")
local screen = PVP.UI.refusal

-- Which errors show a notice, and which key: every case on a closed overlay.
local function shown_for(err)
	G.OVERLAY_MENU = nil
	local before = #shown
	screen.show(err)
	return shown[before + 1]
end
for _, row in ipairs({
	{ "a join refused for an old mod", "pvp_update_required", "text:k_pvp_update_required" },
	{ "a code the server does not send", "update_required", nil },
	{ "a join the server could not set up", "hook_failed", "text:k_pvp_join_hook_failed" },
	{ "a join failure from the queue", "lobby join failed: pvp_update_required", "text:k_pvp_update_required" },
	{ "the setup failure from the queue", "lobby join failed: hook_failed", "text:k_pvp_join_hook_failed" },
	{ "an error with a message", { message = "hook_failed" }, "text:k_pvp_join_hook_failed" },
	{ "an error with a code", { code = "pvp_update_required" }, "text:k_pvp_update_required" },
	{ "a second login (the API shows its own notice)", "opened_elsewhere", nil },
	{ "a second login as an error", { message = "opened_elsewhere" }, nil },
	{ "a refused relay (for the log)", "server_referee", nil },
	{ "an unknown code", "something else", nil },
	{ "no error", nil, nil },
	{ "an error with nothing in it", {}, nil },
}) do
	eq(shown_for(row[2]), row[3], row[1])
end
shown = {}
G.OVERLAY_MENU = nil

screen.show("hook_failed")
eq(#shown, 1, "a known refusal shows one notice")
eq(shown[1], "text:k_pvp_join_hook_failed", "with its own words")
screen.show("lobby join failed: hook_failed")
eq(#shown, 1, "the same refusal again while its notice is open shows nothing")
G.OVERLAY_MENU = nil
screen.show("lobby join failed: hook_failed")
eq(#shown, 2, "once it was closed, a new one shows")
screen.show("pvp_update_required")
eq(shown[3], "text:k_pvp_update_required", "another refusal shows its own notice")
screen.show("opened_elsewhere")
screen.show("server_referee")
screen.show(nil)
eq(#shown, 3, "the rest show none")
screen.show("odd", "k_start_refused")
eq(shown[4], "text:k_start_refused:odd", "an unknown refusal shows the fallback text with the error")
G.OVERLAY_MENU = nil
screen.show("not_all_ready", "k_start_refused")
eq(shown[5], "text:k_start_refused:not_all_ready", "a start refused while a player is not ready shows the fallback text")
screen.show_no_stake()
eq(shown[6], "text:k_start_no_stake", "no stake is its own notice")

T.done("refusal_screen_test")
