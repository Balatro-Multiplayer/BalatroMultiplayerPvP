-- Shows the server's refusals a player must understand, from the error a join or a queue gives, as one
-- notice. A failed join reaches here twice (the lobby's error and the queue's); the second finds the first
-- still open and shows nothing. A kick for opening the game somewhere else ("opened_elsewhere") has the API's
-- own notice, and a relay refused for "server_referee" is for the log: both show nothing here.
local screen = {}
PVP.refusal_screen = screen

local JOIN_PREFIX = "lobby join failed: "
local TEXT_KEYS = {
	pvp_update_required = "k_pvp_update_required",
	hook_failed = "k_pvp_join_hook_failed",
	too_few_players = "k_pvp_start_too_few_players",
}

local open_notice

-- The localize key to show for this error, or nil.
local function text_key(err)
	local code = type(err) == "table" and (err.code or err.message) or err
	if type(code) ~= "string" then return nil end
	if code:sub(1, #JOIN_PREFIX) == JOIN_PREFIX then code = code:sub(#JOIN_PREFIX + 1) end
	return TEXT_KEYS[code]
end

local function notice(key, text)
	if open_notice and open_notice.key == key and open_notice.menu and G.OVERLAY_MENU == open_notice.menu then return end
	PVP.UI.UTILS.overlay_message(text)
	open_notice = { key = key, menu = G.OVERLAY_MENU }
end

-- A refusal not known here shows nothing, unless `unknown_key` names a text with the error in it.
function screen.show(err, unknown_key)
	local key = text_key(err)
	if key then return notice(key, localize(key)) end
	if unknown_key then
		notice(unknown_key, localize({ type = "variable", key = unknown_key, vars = { tostring(err) } }))
	end
end

-- A start the host cannot ask for: no stake is picked.
function screen.show_no_stake()
	notice("k_start_no_stake", localize("k_start_no_stake"))
end

return screen
