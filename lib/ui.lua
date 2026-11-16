function PVP.UTILS.save_username(text)
	PVP.ACTIONS.set_username(text)
	PVP.config.username = text
end

function PVP.UTILS.get_username()
	return PVP.config.username
end

function PVP.UTILS.save_blind_col(num)
	PVP.ACTIONS.set_blind_col(num)
	PVP.config.blind_col = num
end

function PVP.UTILS.get_blind_col()
	return PVP.config.blind_col
end

function PVP.UTILS.blind_col_numtokey(num)
	local keys = {
		"tooth",
		"small",
		"big",
		"hook",
		"ox",
		"house",
		"wall",
		"wheel",
		"arm",
		"club",
		"fish",
		"psychic",
		"goad",
		"water",
		"window",
		"manacle",
		"eye",
		"mouth",
		"plant",
		"serpent",
		"pillar",
		"needle",
		"head",
		"flint",
		"mark",
	}
	return "bl_" .. keys[num]
end

function PVP.UTILS.get_nemesis_key(own) -- calling this function assumes the user is currently in a multiplayer game
	-- Manhunt: the boss blind is a reskin target, same "one shared blind object,
	-- just repainted" trick every other call site already relies on (bl_mp_nemesis
	-- itself is untouched -- only its sprite/colour changes, so timers/jokers/HUD
	-- lookups need no changes). Every call site above passes no `own` arg, which
	-- (per the existing xor below) always resolves to "the blind representing my
	-- OPPONENT" -- so a Hunter (facing the Runner) sees the Runner sprite, and the
	-- Runner (facing a/the best Hunter) sees the Hunter sprite.
	if PVP.LOBBY.config.manhunt then
		return (PVP.LOBBY.team_id == "RUNNER") and "bl_mp_manhunt_hunter" or "bl_mp_manhunt_runner"
	end
	local num = ((not own) ~= (not PVP.LOBBY.is_host) and PVP.LOBBY.guest.blind_col or PVP.LOBBY.host.blind_col) or 1 -- cryptic xor fuckery
	local ret = PVP.UTILS.blind_col_numtokey(num)
	if tonumber(PVP.GAME.enemy.lives) <= 1 and tonumber(PVP.GAME.lives) <= 1 then
		if G.STATE ~= G.STATES.ROUND_EVAL then -- very messy fix that mostly works. breaks in a different way... but far harder to notice
			-- random ass showdown blind mapping because i can. surely one day this data will be organised better
			ret = ({
				"heart",
				"bell",
				"acorn",
				"heart",
				"heart",
				"bell",
				"vessel",
				"leaf",
				"vessel",
				"leaf",
				"bell",
				"acorn",
				"vessel",
				"bell",
				"acorn",
				"heart",
				"bell",
				"vessel",
				"leaf",
				"leaf",
				"acorn",
				"leaf",
				"vessel",
				"acorn",
				"heart",
			})[num]
			ret = "bl_final_" .. ret
		end
	end
	return ret
end

function PVP.UTILS.save_preview(table)
	for k, v in pairs(table) do
		PVP.config.preview[k] = v
	end
end

function PVP.UTILS.get_preview_cfg(index)
	local ret = PVP.config.preview[index]
	if not ret or #ret < 1 then
		if index == "text" then
			ret = "CALCULATING"
		else
			ret = "Calculate Score"
		end
	end
	return ret
end

function PVP.UTILS.copy_to_clipboard(text)
	if G.F_LOCAL_CLIPBOARD then
		G.CLIPBOARD = text
	else
		love.system.setClipboardText(text)
	end
end

function PVP.UTILS.get_from_clipboard()
	if G.F_LOCAL_CLIPBOARD then
		return G.F_LOCAL_CLIPBOARD
	else
		return love.system.getClipboardText()
	end
end

function PVP.UTILS.random_message()
	local messages = {
		localize("k_message1"),
		localize("k_message2"),
		localize("k_message3"),
		localize("k_message4"),
		localize("k_message5"),
		localize("k_message6"),
		localize("k_message7"),
		localize("k_message8"),
		localize("k_message9"),
	}
	return messages[math.random(1, #messages)]
end

function PVP.UTILS.add_nemesis_info(info_queue)
	if PVP.LOBBY.code then
		info_queue[#info_queue + 1] = {
			set = "Other",
			key = "current_nemesis",
			vars = { PVP.LOBBY.is_host and PVP.LOBBY.guest.username or PVP.LOBBY.host.username },
		}
	end
end
