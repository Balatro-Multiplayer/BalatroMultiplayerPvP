-- The opponent's facts over the server's match state: my sells and shop slots go to the server as
-- requests, and Taxes and Penny Pincher read what it recorded about my Nemesis ("pvp.nemesis",
-- "pvp.opponent"). lib/opponent_record.lua decides what the state says; this file gathers and acts.
--
-- Each action is one request: my sells, effects and trap plants (pvp.sell, pvp.effect, pvp.trap_plant)
-- and my blind slots: a blind I passed or cleared (pvp.shop with the spend) or skipped (pvp.shop skipped).
-- The request shell resends a pending request under its own request id and the server takes each id once,
-- so nothing here queues, numbers or retries. Nothing is sent outside a live run (practice, replay and
-- spectate playback) or during a crash rejoin's catch-up, which replays actions the server already has.

PVP.OpponentNet = PVP.OpponentNet or {}
local N = PVP.OpponentNet
local pvp_lobby = PVP.NetBasics.pvp_lobby

local ROUND_KEY = "pvp.round"
local NEMESIS_KEY = "pvp.nemesis"
local OPPONENT_KEY = "pvp.opponent"

-- Every key of PVP.GAME that stamps its records with a run id (the carried keys of lib/rejoin.lua).
local RUN_KEYS = {
	"opponent_applied",
	"replies_applied",
	"traps_applied",
	"traps_sent",
	"trap_rewards_applied",
	"pincher_pending",
}

local catching_up = false
local listeners = {}

local function log_error(text)
	PVP.match_log("info", "[pvp] error: " .. text)
end

-- Whether this is a live attached run (not practice, not a playback, not a rejoin's catch-up). The one owner
-- of that fact: the other nets that report over the server ask here.
function N.is_live()
	if catching_up then return false end
	if PVP.SP and PVP.SP.practice then return false end
	local lobby = pvp_lobby()
	if not lobby or lobby._nakama ~= true or lobby._holding then return false end
	return PVP.current_run_id() ~= nil
end

-- The pvp.shop requests sent and not answered yet: while any is out, my recorded slots may not include the shop
-- just left, so a slot count is not taken.
local shops_in_flight = 0
-- The highest state revision named by an answer to a pvp.shop request, and the run it was answered in. An answer
-- can arrive before the state that shows its slot, so my record is not counted until it is at least this
-- revision. Another run's match counts its revisions from the start, so it does not apply to a different run.
local answered = { runId = nil, rev = 0 }

-- Every Penny Pincher credit still waiting for my slot count: one more slot of mine was sent after it.
local function note_shop_sent()
	shops_in_flight = shops_in_flight + 1
	local pending = PVP.GAME.pincher_pending
	if type(pending) ~= "table" then return end
	for _, item in ipairs(pending.items) do
		if item.s == nil then item.later = (item.later or 0) + 1 end
	end
end

-- One request of the live run, stamped with its run.
local function send(kind, fields)
	if not N.is_live() then return end
	local payload = { runId = PVP.current_run_id() }
	for key, value in pairs(fields) do
		payload[key] = value
	end
	local on_refusal = PVP.NetBasics.refusal_logger(kind)
	if kind ~= "pvp.shop" then return MPAPI.request(kind, payload, on_refusal) end
	note_shop_sent()
	MPAPI.request(kind, payload, function(ok, result)
		shops_in_flight = math.max(0, shops_in_flight - 1)
		local rev = type(result) == "table" and tonumber(result.rev) or nil
		if rev and (answered.runId ~= payload.runId or rev > answered.rev) then
			answered = { runId = payload.runId, rev = rev }
		end
		on_refusal(ok, result)
	end)
end

-- Shared with N.send_effect and N.send_plant.
function N.send_request(kind, fields)
	send(kind, fields)
end

-- One sell, in the ante it was made in (G.GAME.round_resets.ante).
function N.report_sell()
	local ante = G and G.GAME and G.GAME.round_resets and G.GAME.round_resets.ante
	if type(ante) ~= "number" then return log_error("pvp.sell not sent: no ante") end
	send("pvp.sell", { ante = ante })
end

-- Leaving a shop: the money spent in it, always sent: 0 when nothing was spent. A spend that is not a number
-- from 0 up is a bug: it is logged and sent without a spend, and the server records that payload as a refused
-- `bad_spend` slot (the Pincher pays $0 for it), so my slots stay in step with the server's.
function N.report_shop(spent)
	if PVP.OPPONENT_RECORD.valid_spend(spent) then return send("pvp.shop", { spent = spent }) end
	if N.is_live() then log_error("shop spend is not a number: " .. tostring(spent)) end
	send("pvp.shop", {})
end

-- Skipping a blind: a skipped slot. Sent whatever the outcome of the pvp.skip request.
function N.report_skip()
	send("pvp.shop", { skipped = true })
end

-- The crash rejoin starts its catch-up: the replayed actions are already the server's.
function N.begin_catch_up()
	catching_up = true
end

-- Records the live lobby's run on every record that has none yet (a whole-log catch-up had no run), so a
-- later step reading them does not take them for another run's.
local function adopt_run(run_id)
	for _, key in ipairs(RUN_KEYS) do
		local record = PVP.GAME[key]
		if type(record) == "table" and record.runId == nil then record.runId = run_id end
	end
end

-- The live lobby is attached and the carried records are restored.
function N.end_catch_up()
	catching_up = false
	local round = MPAPI.get_state(ROUND_KEY)
	local run_id = PVP.current_run_id() or (type(round) == "table" and round.runId ~= nil and tostring(round.runId)) or nil
	if run_id then adopt_run(run_id) end
end

-- The seat was lost before the run went live.
function N.abort_catch_up()
	catching_up = false
end

-- Whether an incoming effect may apply now: at a point that is not mid-scoring, in a live attached run
-- (so never during a rejoin's catch-up).
function N.can_apply()
	if not N.is_live() then return false end
	if not (G and G.STATES) then return false end
	local state = G.STATE
	return state == G.STATES.BLIND_SELECT or state == G.STATES.SHOP or state == G.STATES.SELECTING_HAND
end

-- Taxes: the sells my Nemesis made, by ante. {} when nobody was my Nemesis that ante; nil while unknown.
function N.nemesis_sells()
	local lobby = pvp_lobby()
	if not lobby then return nil end
	local run_id = PVP.current_run_id()
	local R = PVP.OPPONENT_RECORD
	local ante = R.player_ante(MPAPI.get_state(ROUND_KEY), run_id, lobby.player_id)
	local row = R.nemesis_row(MPAPI.get_state(NEMESIS_KEY), run_id, ante)
	if row == nil then return nil end
	if row.one == nil then return {} end
	local record = R.player(MPAPI.get_state(OPPONENT_KEY), run_id, row.one)
	return record and record.sells or nil
end

-- What the shop of my slot `s` pays: the Nemesis I had in the ante my slot was recorded in, and their slot s.
local function pincher_status(s, divisor, dollars)
	local R = PVP.OPPONENT_RECORD
	if type(s) ~= "number" or s < 1 then return R.pincher_payout(nil, nil, s, divisor, dollars) end
	local lobby = pvp_lobby()
	local run_id = PVP.current_run_id()
	if not lobby or not run_id then return { status = R.PENDING } end
	local opponent = MPAPI.get_state(OPPONENT_KEY)
	local mine = R.slot(opponent, run_id, lobby.player_id, s)
	if mine == nil then return { status = R.PENDING } end
	-- My slot refused with no ante (no_progress): final, and no Nemesis can ever be looked up for it.
	if mine.ante == nil and mine.refused ~= nil then return { status = R.NONE, reason = "no ante" } end
	local row = R.nemesis_row(MPAPI.get_state(NEMESIS_KEY), run_id, mine.ante)
	local target = row and row.one ~= nil and R.player(opponent, run_id, row.one) or nil
	return R.pincher_payout(row, target, s, divisor, dollars)
end

-- How many blind slots the server has recorded for me in this run; nil while my record is unknown or older than
-- the last answer to a pvp.shop request of this run.
local function my_slot_count(run_id)
	local lobby = pvp_lobby()
	local opponent, rev = MPAPI.get_state(OPPONENT_KEY)
	if answered.runId == run_id and (tonumber(rev) or 0) < answered.rev then return nil end
	local mine = lobby and PVP.OPPONENT_RECORD.player(opponent, run_id, lobby.player_id)
	if type(mine) ~= "table" or type(mine.slots) ~= "table" then return nil end
	return #mine.slots
end

-- What a credit pays. The blind being cleared is the slot after the ones the server has recorded for me, and it
-- pays from my Nemesis' slot of three before. While my record is unknown or older than the last answer to a
-- pvp.shop request of mine, or one is in flight, the count is not known and the credit stays pending: unknown
-- is never 0. `later` is how many of my slots went out after the credit was made, so a count taken late still
-- names the slot cleared then.
local function credit_status(item)
	if item.s == nil then
		local counted = my_slot_count(PVP.current_run_id())
		if counted == nil or shops_in_flight > 0 then return { status = PVP.OPPONENT_RECORD.PENDING } end
		item.s = counted - (item.later or 0) - 2
	end
	return pincher_status(item.s, item.divisor, item.dollars)
end

-- Penny Pincher at the cash out of a cleared blind: the dollars now (0 when none), or the credit is
-- kept in PVP.GAME.pincher_pending until the fact arrives.
function N.pincher_bonus(divisor, dollars)
	if not N.is_live() then return 0 end
	local run_id = PVP.current_run_id()
	local item = { divisor = divisor, dollars = dollars, later = 0 }
	local status = credit_status(item)
	if status.status == PVP.OPPONENT_RECORD.DOLLARS then return status.dollars end
	if status.status == PVP.OPPONENT_RECORD.PENDING then
		local pending = PVP.GAME.pincher_pending
		if type(pending) ~= "table" or (pending.runId ~= nil and pending.runId ~= run_id) then
			pending = { runId = run_id, items = {} }
			PVP.GAME.pincher_pending = pending
		end
		pending.items[#pending.items + 1] = item
	end
	return 0
end

-- Pays the Pincher credits whose fact has arrived, once each, at an apply point. A credit the server's
-- record turns out to be no shop for is dropped.
function N.pay_pending()
	local pending = PVP.GAME and PVP.GAME.pincher_pending
	if type(pending) ~= "table" or #pending.items == 0 then return end
	if not N.can_apply() then return end
	if pending.runId ~= nil and tostring(pending.runId) ~= PVP.current_run_id() then
		PVP.match_log("info", "[pvp] pincher credits of another run dropped: " .. #pending.items)
		pending.items = {}
		return
	end
	local keep, total = {}, 0
	for _, item in ipairs(pending.items) do
		local status = credit_status(item)
		if status.status == PVP.OPPONENT_RECORD.DOLLARS then
			total = total + status.dollars
		elseif status.status == PVP.OPPONENT_RECORD.PENDING then
			keep[#keep + 1] = item
		end
	end
	pending.items = keep
	if total > 0 then ease_dollars(total) end
end

-- CONNECTED (the lobby attached, or the socket back): the listeners registered with N.on_connected(fn)
-- run. With a function, registers it.
function N.on_connected(fn)
	if type(fn) == "function" then
		listeners[#listeners + 1] = fn
		return
	end
	for _, listener in ipairs(listeners) do
		listener()
	end
end

-- Per frame (pvp_api/frame.lua): the Pincher credits whose fact has arrived are paid.
function N.update()
	N.pay_pending()
end
