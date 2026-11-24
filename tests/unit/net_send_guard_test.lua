-- Run from the repo root: luajit tests/unit/net_send_guard_test.lua
-- Every state change the PvP mod asks of the server goes up through the one numbered input
-- (pvp_api/match_net.lua), which is resent until the view confirms it. A direct lobby call sends once
-- and is lost on a dropped socket, so none may appear outside the files allowed below.
local SENDS = {
	":set_metadata%(",
	":set_player_state%(",
	":set_state%(",
	":set_ready%(",
	":start_game%(",
	":set_catching_up%(",
	":action%(",
	"send_match_input%(",
	"NL%.send%(",
	"nakama_lobby%.send%(",
	"ClientOp%.",
}

-- file -> the one send it may make, and why.
local ALLOWED = {
	-- The envelope itself.
	["./pvp_api/match_net.lua"] = "send_match_input%(",
	-- A local lobby (practice, playback) has no server: it merges the settings itself.
	["./pvp_api/lobby_screen.lua"] = ":set_metadata%(",
	-- Replay log events are diagnostics; one lost costs nothing in play.
	["./pvp_api/replay_log_actions.lua"] = ":action%(",
}

local SKIP_DIRS = { "tests", ".git", ".github", ".context" }

local checks, offenders = 0, {}
local handle = io.popen("find . -name '*.lua' -not -path './.git/*'")
for path in handle:lines() do
	local skip = false
	for _, dir in ipairs(SKIP_DIRS) do
		if path:sub(1, #dir + 3) == "./" .. dir .. "/" then skip = true end
	end
	if not skip then
		local file = assert(io.open(path, "rb"))
		local number = 0
		for line in file:lines() do
			number = number + 1
			local code = line:gsub("%-%-.*$", "")
			for _, pattern in ipairs(SENDS) do
				checks = checks + 1
				if code:find(pattern) and ALLOWED[path] ~= pattern then
					offenders[#offenders + 1] = path .. ":" .. number .. ": " .. line:gsub("^%s+", "")
				end
			end
		end
		file:close()
	end
end
handle:close()

if #offenders > 0 then
	error("sends outside the numbered input (route them through PVP.match_net.send):\n" .. table.concat(offenders, "\n"))
end
print(string.format("net_send_guard_test: %d checks passed", checks))
