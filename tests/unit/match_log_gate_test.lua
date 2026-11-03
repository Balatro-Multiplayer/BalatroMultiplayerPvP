--[[
  Match log gate guard.

  PvP is all match code, so its debug, info and trace lines carry match data.
  They must go through MPAPI.match_log, which writes only with the Dev mod.
  This test fails when a PvP source file calls sendDebugMessage,
  sendInfoMessage or sendTraceMessage directly, and when the log checksum
  helper comes back.

  Run from the repo root:
    luajit tests/unit/match_log_gate_test.lua
]]

local BANNED = { "sendDebugMessage", "sendInfoMessage", "sendTraceMessage", "emit_log_checksum" }
local SKIP_DIRS = { "tests", ".git", ".github" }

local handle = io.popen("find . -name '*.lua' -not -path './.git/*'")
local offenders = {}
for path in handle:lines() do
	local skip = false
	for _, dir in ipairs(SKIP_DIRS) do
		if path:sub(1, #dir + 3) == "./" .. dir .. "/" then
			skip = true
		end
	end
	if not skip then
		local file = io.open(path, "rb")
		local n = 0
		for line in file:lines() do
			n = n + 1
			for _, name in ipairs(BANNED) do
				if line:find(name, 1, true) then
					offenders[#offenders + 1] = path .. ":" .. n .. " " .. name
				end
			end
		end
		file:close()
	end
end
handle:close()

if #offenders > 0 then
	io.stderr:write("FAIL: PvP lines must use MPAPI.match_log:\n  " .. table.concat(offenders, "\n  ") .. "\n")
	os.exit(1)
end
print("ok: no direct match log calls")
