-- roles: a_host a_guest b_host b_guest
-- Two Party lobbies of two group-queue Battle Royale and meet in one public lobby. Every client
-- gets the roster reveal (a lobby of more than two has no single opponent): it fills to four,
-- restarts its countdown on each arrival, and slides off when the public host starts the game.
-- Then each client votes and drafts through the panels on screen, into the first blind.
-- Run with scripts/run_pair.sh party_roster_reveal.
local P = assert(SMODS.load_file("tests/scenarios/lib/pair.lua", "MultiplayerPvP"))()

local MODE = "pvp_royale"
local PLAYERS = #P.roles
local party = P.role:sub(1, 1)
local hosts = { "a_host", "b_host" }
local guests = { "a_guest", "b_guest" }
local Reveal = PVP.QUEUE_REVEAL

local function lobby()
	return MPAPI.get_current_lobby()
end

local function now()
	return love.timer.getTime()
end

-- Accounts are pair-<role>-<run>; the roster draws ourselves as "You".
local function role_of(name)
	if name == localize("k_pvp_you") then return P.role end
	return name and name:match("^pair%-(.-)%-[^-]+$") or tostring(name)
end

-- Every text the roster panel draws, in order: the "N players" label, then one name per player.
local function roster_texts()
	local box = Reveal.view and Reveal.view.roster
	local container = box and box:get_UIE_by_ID("pvp_reveal_roster")
	local texts = {}
	local function walk(node)
		if node.config and type(node.config.text) == "string" then texts[#texts + 1] = node.config.text end
		for _, child in ipairs(node.children or {}) do
			walk(child)
		end
	end
	if container then walk(container) end
	return texts
end

local seen = { arrivals = 0, restarts = 0, n = 0, max_n = 0 }

-- A live button on screen: a visible node whose `button` its check func has armed. `check`
-- finds the button by its check func instead, armed or not (the panel is up).
local function find_node(match)
	local function walk(node)
		if not node or (node.states and node.states.visible == false) then return nil end
		if node.config and match(node.config) then return node end
		for _, child in ipairs(node.children or {}) do
			local found = walk(child)
			if found then return found end
		end
	end
	for _, box in ipairs(G.I.UIBOX) do
		local found = walk(box.UIRoot)
		if found then return found end
	end
end

local function armed(name)
	return find_node(function(config)
		return config.button == name
	end)
end

local function panel(check)
	return find_node(function(config)
		return config.func == check
	end) ~= nil
end

-- After the reveal: the Casual votes, then the Draft, then the run. Every vote and pick goes
-- through the panel's own Random and Confirm buttons, so a panel nobody can see fails here.
local setup = { votes = {}, missing = {}, shots = {} }

local function shoot(name)
	if not setup.shots[name] then
		setup.shots[name] = true
		P.screenshot(name)
	end
end

local function press(random, confirm)
	local button = armed(confirm) or armed(random)
	if button and not G.CONTROLLER.locked then button:click() end
end

local function play_setup()
	P.note_state()
	local page = MPAPI.pages.current_key and MPAPI.pages.current_key() or "-"
	if page ~= setup.page then
		setup.page = page
		P.note("page " .. tostring(page))
	end
	local lobby = MPAPI.get_current_lobby()
	local open = lobby and MPAPI.Setup.open_step(lobby)
	local step = open and open.kind == "vote" and open.id or (MPAPI.BanPick.is_active() and "draft") or nil
	if step ~= setup.step then
		setup.step, setup.step_at = step, now()
		if step then P.note("setup step " .. step) end
	end
	-- A sent vote leaves the panel without its buttons; only an unsent one needs them.
	if step and (step == "draft" or not MPAPI.Setup.has_voted(lobby)) then
		local up = step == "draft" and panel("mpapi_ban_pick_random_check") or panel("pvp_setup_random_check")
		setup.votes[step] = setup.votes[step] or up
		if up then
			if now() - setup.step_at > 0.5 then shoot("setup_" .. step) end
			if step == "draft" then
				press("mpapi_ban_pick_random", "mpapi_ban_pick_confirm")
			else
				press("pvp_setup_random", "pvp_setup_confirm")
			end
		elseif now() - setup.step_at > 3 and not setup.missing[step] then
			setup.missing[step] = true
			P.note("setup step " .. step .. " open but its panel isn't on screen (page " .. tostring(page) .. ")")
			shoot("missing_" .. step)
		end
	end
	return G.STATE == G.STATES.BLIND_SELECT and G.blind_select_opts ~= nil
end

local function watch()
	local view = Reveal.view
	if not view then
		if seen.duel == nil then return false end
		-- The reveal is over: finish() keeps the cards for their outro, dismiss() doesn't.
		seen.outro = Reveal.leaving ~= nil
		seen.ended_at = now()
		P.note("reveal ended, outro=" .. tostring(seen.outro))
		return true
	end
	if seen.duel == nil then
		seen.duel = view.duel
		P.note("reveal up, duel=" .. tostring(view.duel))
	end
	local n = Reveal.lobby and #Reveal.lobby:get_players() or 0
	if n ~= seen.n then
		if n > seen.n and n > 1 then seen.arrivals = seen.arrivals + 1 end
		P.note("reveal lobby has " .. n)
		seen.n, seen.max_n = n, math.max(seen.max_n, n)
	end
	if view.starts_at ~= seen.starts_at then
		if view.starts_at then seen.restarts = seen.restarts + 1 end
		seen.starts_at = view.starts_at
		P.note("countdown from " .. n .. " players")
	end
	if view.roster and n == PLAYERS then
		local texts = roster_texts()
		if #texts == PLAYERS + 1 then
			seen.texts = texts
			if not seen.shot_at then seen.shot_at = now() end
			-- The panel slides in and juices; give it a moment before the picture.
			if not seen.shot and now() - seen.shot_at > 0.6 then
				seen.shot = true
				P.screenshot("roster")
			end
		end
	end
	return false
end

return P.steps(
	P.connect(),

	-- Into PvP's menu, as the Multiplayer panel's PvP button does: MPAPI draws the lobby view
	-- (and the Setup panels in it) only for the mod in focus.
	{
		until_ = function()
			return find_node(function(config)
				return config.button == "mpapi_mod_button" and config.ref_table and config.ref_table.mod_id == PVP.id
			end)
		end,
		timeout = 20,
		run = function()
			local button = find_node(function(config)
				return config.button == "mpapi_mod_button" and config.ref_table and config.ref_table.mod_id == PVP.id
			end)
			button:click()
		end,
	},

	-- Each host makes a Party lobby and hands its code to its guest.
	P.only(hosts, {
		wait = 1,
		run = function()
			G.FUNCS.mp_pvp_create_lobby_party()
		end,
	}),
	P.only(hosts, {
		until_ = function()
			return lobby() and lobby().code and lobby().is_host
		end,
		timeout = 20,
		run = function()
			P.put("party_" .. party, lobby().code)
		end,
	}),
	P.only(guests, {
		until_ = function()
			return P.get("party_" .. party) ~= nil
		end,
		timeout = 30,
		run = function()
			PVP.pvp_join_lobby(P.get("party_" .. party))
		end,
	}),
	{
		until_ = function()
			return lobby() and #lobby():get_players() == 2 and MPAPI.Party.is_party_lobby(lobby())
		end,
		timeout = 30,
		run = function(S)
			S.check(true, P.role .. " in a Party lobby of two")
		end,
	},

	-- Find Game needs every guest ready.
	P.only(guests, {
		wait = 1,
		run = function()
			G.FUNCS.mp_pvp_toggle_ready()
		end,
	}),
	P.only(hosts, {
		until_ = function()
			return MPAPI.Party.find_game_enabled(MPAPI.Party.find_game_facts(PVP.lobby.ref, PVP.lobby.ready))
		end,
		timeout = 30,
	}),

	-- Both parties queue together, so neither waits out the other's launch.
	P.sync("parties_ready", 60),
	P.only(hosts, {
		run = function()
			G.FUNCS.mp_pvp_group_queue_mode({ config = { ref_table = { gamemode_key = MODE } } })
		end,
	}),
	P.only(hosts, {
		until_ = function()
			return lobby() and lobby().group_queue ~= nil
		end,
		timeout = 10,
		run = function(S)
			S.check(true, P.role .. " group-queued " .. MODE)
		end,
	}),

	-- The matchmaker settles for four once it gives up on more (up to 16).
	{
		wait = 0,
		until_ = watch,
		timeout = 240,
		run = function(S)
			S.check(seen.duel == false, P.role .. " reveal is a roster, not a VS")
			S.check(seen.max_n == PLAYERS, P.role .. " reveal lobby reached " .. PLAYERS .. ", saw " .. seen.max_n)
			S.check(
				seen.texts and seen.texts[1] == PLAYERS .. " players",
				P.role .. " roster label reads " .. tostring(seen.texts and seen.texts[1])
			)
			S.check(
				seen.texts and seen.texts[2] == localize("k_pvp_you"),
				P.role .. " roster lists itself first as You"
			)
			S.check(
				seen.restarts >= 1 and seen.restarts == seen.arrivals,
				P.role .. " countdown restarted per arrival: " .. seen.restarts .. " for " .. seen.arrivals
			)
			S.check(seen.outro, P.role .. " reveal ended in the outro (game start), not a dismiss")
		end,
	},
	-- Halfway through the slide-off (OUTRO_SECONDS is 0.5).
	{
		wait = 0.25,
		run = function()
			P.screenshot("outro")
		end,
	},
	{
		wait = 0.75,
		run = function(S)
			S.check(Reveal.leaving == nil and Reveal.view == nil, P.role .. " outro removed its cards")
			local names = {}
			for i = 2, #(seen.texts or {}) do
				names[#names + 1] = role_of(seen.texts[i])
			end
			table.sort(names)
			sendInfoMessage(
				("BMP_SCENARIO STATE reveal duel=%s outro=%s players=%s roster=%s"):format(
					tostring(seen.duel),
					tostring(seen.outro),
					tostring(seen.texts and seen.texts[1]:match("%d+")),
					table.concat(names, ",")
				),
				"MPAPI"
			)
		end,
	},

	-- Votes, Draft, first blind. The votes' clock closes them for anyone whose panel is missing.
	{
		wait = 0,
		until_ = play_setup,
		timeout = 240,
		run = function(S)
			shoot("blind_select")
			for _, step in ipairs({ "ruleset", "traps", "draft" }) do
				if setup.votes[step] ~= nil or setup.missing[step] then
					S.check(
						setup.votes[step] and not setup.missing[step],
						P.role .. " " .. step .. " panel was on screen to " .. (step == "draft" and "pick" or "vote")
					)
				end
			end
			S.check(setup.votes.ruleset ~= nil, P.role .. " ran the ruleset vote")
			S.check(setup.votes.draft ~= nil, P.role .. " ran the Draft")
			S.check(G.GAME.round_resets.ante == 1, P.role .. " in ante 1 blind select")
			sendInfoMessage(
				("BMP_SCENARIO STATE run ruleset=%s deck=%s stake=%s seed=%s"):format(
					tostring(PVP.LOBBY.config.ruleset),
					tostring(G.GAME.selected_back and G.GAME.selected_back.name),
					tostring(G.GAME.stake),
					tostring(G.GAME.pseudorandom and G.GAME.pseudorandom.seed)
				),
				"MPAPI"
			)
		end,
	},

	-- Nobody quits (and leaves the public lobby) until everyone is in the run.
	P.sync("in_run", 120)
)
