-- small file because it feels wrong to add it somewhere else

-- Default-deny, consistent with the joker/consumable pool mechanism
-- (MPAPI.should_exclude_from_pool): PvP's own Stakes/Decks/Challenges are hidden
-- from the picker unless we're in a private lobby, in a real PvP lobby whose ruleset
-- uses MP content, or the player has explicitly opted into seeing them anyway.
function PVP.should_hide_mp_content()
	return PVP.MpContentVisibility.should_hide(
		PVP.LOBBY.code ~= nil,
		PVP._pvp_kind,
		PVP.current_ruleset().multiplayer_content,
		PVP.config.show_mp_content_anyway
	)
end

local hidden_tbl = { "Stake", "Back" } -- Challenges are at bottom of file

local inject_ref = SMODS.injectItems
function SMODS.injectItems()
	local ret = inject_ref()
	for _, hidden in ipairs(hidden_tbl) do
		G.P_CENTER_POOLS[hidden .. "_non_mp"] = {}
		for i, v in ipairs(G.P_CENTER_POOLS[hidden]) do
			if not v.mod or v.mod.id ~= PVP.id then table.insert(G.P_CENTER_POOLS[hidden .. "_non_mp"], v) end
		end
	end
	G.CHALLENGES_non_mp = {}
	for i, v in ipairs(G.CHALLENGES) do
		if not v.mod or v.mod.id ~= PVP.id then table.insert(G.CHALLENGES_non_mp, v) end
	end
	return ret
end

local function hook(orig, type)
	return function(...)
		local temp = G.P_CENTER_POOLS[type]
		if PVP.should_hide_mp_content() then G.P_CENTER_POOLS[type] = G.P_CENTER_POOLS[type .. "_non_mp"] end
		local results = orig(...)
		G.P_CENTER_POOLS[type] = temp
		return results
	end
end

-- The deck option cycle (G.FUNCS.change_viewed_back) is shared by the run setup
-- screen and the Collection. Only the run setup swaps the pool, because its
-- cycle is built from the hidden pool. The Collection cycle is built from the
-- full pool, so a swapped pool there would point at the wrong deck (and
-- Back:change_to(nil) falls back to Red Deck). run_setup_option tags the cycles
-- it builds, and the callback swaps only for a tagged cycle.
local RUN_SETUP_CYCLE = "pvp_run_setup_cycle"

local function tag_run_setup_cycles(orig)
	return function(...)
		local create_option_cycle_ref = create_option_cycle
		create_option_cycle = function(args)
			if args and args.opt_callback == "change_viewed_back" then args[RUN_SETUP_CYCLE] = true end
			return create_option_cycle_ref(args)
		end
		local ok, results = pcall(orig, ...)
		create_option_cycle = create_option_cycle_ref
		if not ok then error(results, 0) end
		return results
	end
end

local function hide_in_run_setup_cycle(orig, type)
	local hidden = hook(orig, type)
	return function(args, ...)
		if args and args.cycle_config and args.cycle_config[RUN_SETUP_CYCLE] then return hidden(args, ...) end
		return orig(args, ...)
	end
end

local hooks = {
	Stake = {
		{ tbl = G.UIDEF, str = "deck_stake_column" },
		{ tbl = G.UIDEF, str = "current_stake" },
		{ tbl = G.UIDEF, str = "stake_option" },
		{ tbl = G.UIDEF, str = "run_setup_option" },
	},
	Back = {
		{ tbl = G.UIDEF, str = "run_setup_option" },
		{ tbl = G.FUNCS, str = "change_selected_back" },
	},
}

G.UIDEF.run_setup_option = tag_run_setup_cycles(G.UIDEF.run_setup_option)
G.FUNCS.change_viewed_back = hide_in_run_setup_cycle(G.FUNCS.change_viewed_back, "Back")

for k, v in pairs(hooks) do
	for i, vv in ipairs(v) do
		local orig = vv.tbl[vv.str]
		vv.tbl[vv.str] = hook(orig, k)
	end
end

-- slightly modified exception code for challenges

local ch_hooks = {
	{ tbl = G.UIDEF, str = "challenges" },
	{ tbl = G.UIDEF, str = "challenge_list" },
	{ tbl = G.UIDEF, str = "challenge_list_page" },
}

local function ch_hook(orig)
	return function(...)
		local temp = G.CHALLENGES
		if PVP.should_hide_mp_content() then G.CHALLENGES = G.CHALLENGES_non_mp end
		local results = orig(...)
		G.CHALLENGES = temp
		return results
	end
end

for i, v in pairs(ch_hooks) do
	local orig = v.tbl[v.str]
	v.tbl[v.str] = ch_hook(orig)
end
