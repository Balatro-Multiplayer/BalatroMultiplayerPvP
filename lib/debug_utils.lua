local networkToUi = love.thread.getChannel("networkToUi")

-- water is wet
function PVP.UTILS.log_mem_debug_messages()
	-- respect opt-out
	if PVP.EXPERIMENTAL.mem_debug then
		PVP.match_log("debug", "Lua memory in use: " .. (collectgarbage("count") / 1024) .. " MiB")
		PVP.match_log(
			"debug",
			"Texture memory in use: " .. (love.graphics.getStats().texturememory / 1024 / 1024) .. " MiB"
		)
		if networkToUi:getCount() > 10 then -- look i have no idea what's high but i checked briefly and it doesn't seem to go above 0
			PVP.match_log("debug", "High networkToUi count: " .. networkToUi:getCount())
		end
		if PVP._DEBUG_PANIC_COLLECTS then
			PVP.match_log("debug", "nuGC panic collects: " .. PVP._DEBUG_PANIC_COLLECTS)
		end
	end
end