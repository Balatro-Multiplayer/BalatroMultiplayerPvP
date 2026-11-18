-- BMP_ENTRY_FAULT=start bash scripts/run_pair.sh pair_pvp_entry_recovery
-- Other faults: ready, ack, reconnect. See pair.md for harness setup.
-- Both clients are real. Drop a handshake delivery or close the guest's lobby socket.
local P = assert(SMODS.load_file("tests/scenarios/lib/pair.lua", "MultiplayerPvP"))()
local fault = os.getenv("BMP_ENTRY_FAULT")
assert(fault == "ready" or fault == "start" or fault == "ack" or fault == "reconnect", "unknown BMP_ENTRY_FAULT")

local dropped, entered = false, 0
local allow_ack = false
local fault_at
local recovery_delivered = false
local function now()
	return love.timer.getTime()
end

local function install_fault()
	local dispatch = PVP.dispatch_action
	PVP.dispatch_action = function(name, ...)
		if name == "startBlind" then entered = entered + 1 end
		return dispatch(name, ...)
	end
	if P.role ~= "guest" then return end
	if fault == "reconnect" then
		P.put("guest_id", MPAPI.get_current_lobby().player_id)
	elseif fault == "start" then
		local action = MPAPI.ActionTypes.pvp_start_blind
		local receive = action.on_receive
		action.on_receive = function(self, from, params)
			if not dropped then
				dropped = true
				P.note("dropped initial Start from host (round " .. tostring(params.round_id) .. ")")
				P.put("dropped", params.round_id or "")
				return
			end
			recovery_delivered = params.round_id ~= nil and params.round_id == P.get("dropped")
			P.note("received recovered Start twice for round " .. tostring(params.round_id))
			receive(self, from, params)
			return receive(self, from, params)
		end
	else
		local transmit = MPAPI._internal.transmit_action
		MPAPI._internal.transmit_action = function(lobby, envelope)
			if
				(fault == "ready" and envelope.action == "pvp_ready_blind" and not dropped)
				or (fault == "ack" and envelope.action == "pvp_ready_ack" and not allow_ack)
			then
				if not dropped then
					dropped = true
					fault_at = now()
					P.put("dropped", envelope.action)
					P.note("dropped " .. envelope.action)
				end
				return false
			end
			return transmit(lobby, envelope)
		end
	end
end

local function boss_button()
	local boss = G.blind_select_opts and G.blind_select_opts.boss
	return boss and boss:get_UIE_by_ID("select_blind_button")
end

local function ready_up()
	return {
		until_ = function()
			local button = boss_button()
			return button and button.config.button == "mp_toggle_ready"
		end,
		timeout = 20,
		run = function(S)
			S.check(G.GAME.round_resets.blind_choices.Boss == "bl_mp_nemesis", "ready at the PvP boss")
			boss_button():click()
		end,
	}
end

local function ready_with_reconnect()
	if fault ~= "reconnect" then return ready_up() end
	return {
		P.only("guest", ready_up()),
		P.only("host", {
			until_ = function()
				local guest = PVP.REF.players[P.get("guest_id")]
				return guest and guest.is_ready
			end,
			timeout = 15,
			run = function(S)
				S.check(true, "host saw guest Ready before the drop")
				MPAPI.get_current_lobby():on(MPAPI.LobbyEvent.PLAYER_RECONNECTED, function(id)
					if id == P.get("guest_id") then P.put("reconnected", id) end
				end)
			end,
		}),
		P.sync("guest_ready_seen"),
		P.only("guest", {
			run = function()
				P.note("closing guest's Nakama socket after the host saw Ready")
				MPAPI.networking.nakama_lobby._drop_socket()
				P.put("dropped", "socket")
			end,
		}),
		{
			until_ = function()
				return P.get("reconnected") ~= nil
			end,
			timeout = 25,
			run = function(S)
				S.check(true, "host saw the guest rejoin")
				if P.role == "guest" then S.check(PVP.GAME.ready_blind, "guest still shows Ready after rejoin") end
			end,
		},
		P.sync("reconnected"),
		P.only("host", ready_up()),
	}
end

local function release_ready_replies()
	if fault ~= "ack" then return {} end
	return P.only("guest", {
		-- Hold answers past the referee's two-second check timeout.
		until_ = function()
			return now() - fault_at >= 3.5
		end,
		timeout = 10,
		run = function(S)
			S.check(entered == 0, "missing Ready reply did not let the host start")
			allow_ack = true
		end,
	})
end

local function check_blind_entry()
	-- Record the actual screen and number of starts instead of just timing out.
	local deadline
	return {
		wait = 0,
		until_ = function()
			deadline = deadline or now() + 14
			return G.STATE == G.STATES.SELECTING_HAND or now() >= deadline
		end,
		timeout = 20,
		run = function(S)
			local screen = G.STATE == G.STATES.BLIND_SELECT and "BLIND_SELECT"
				or G.STATE == G.STATES.SELECTING_HAND and "SELECTING_HAND"
				or tostring(G.STATE)
			P.note(("screen=%s ready=%s starts=%d"):format(screen, tostring(PVP.GAME.ready_blind), entered))
			S.check(G.STATE == G.STATES.SELECTING_HAND, "entered the blind without another click")
			S.check(entered == 1, "Start applied exactly once")
			if fault == "start" and P.role == "guest" then
				S.check(recovery_delivered, "recovered Start kept the original round ID")
			end
		end,
	}
end

return P.steps(
	P.connect(),
	P.lobby(PVP.GamemodeKey.PVP_NEMESIS),
	P.sync("in_lobby"),
	P.start(),
	P.reach_blind_select(),
	P.jump_to_pvp(2),
	{ run = install_fault },
	P.sync("fault_armed"),
	ready_with_reconnect(),
	{
		until_ = function()
			return P.get("dropped") ~= nil
		end,
		timeout = 15,
		run = function(S)
			S.check(true, "confirmed injected loss: " .. fault)
		end,
	},
	release_ready_replies(),
	check_blind_entry(),
	P.snapshot("after_entry_fault")
)
