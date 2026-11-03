local networkToUi = love.thread.getChannel("networkToUi")

-- water is wet
function PVP.UTILS.log_mem_debug_messages()
	-- respect opt-out
	if PVP.EXPERIMENTAL.mem_debug then
		MPAPI.match_log("debug", "Lua memory in use: "..(collectgarbage("count")/1024).." MiB", "MULTIPLAYER")
		MPAPI.match_log("debug", "Texture memory in use: "..(love.graphics.getStats().texturememory/1024/1024).." MiB", "MULTIPLAYER")
		if networkToUi:getCount() > 10 then -- look i have no idea what's high but i checked briefly and it doesn't seem to go above 0
			MPAPI.match_log("debug", "High networkToUi count: "..networkToUi:getCount(), "MULTIPLAYER")
		end
		if PVP._DEBUG_PANIC_COLLECTS then
			MPAPI.match_log("debug", "nuGC panic collects: "..PVP._DEBUG_PANIC_COLLECTS, "MULTIPLAYER")
		end
	end
end