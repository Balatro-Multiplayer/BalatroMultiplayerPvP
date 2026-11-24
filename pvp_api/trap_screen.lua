-- The trap inputs (plant, fire, lost) and my traps shown from the net's view (trap_reader.lua decides).
-- Each sender is called from the place in the game where the thing happens and sends once. Nothing
-- here changes my run through a reward: a trap going off on its owner arrives through their inbox
-- only (inbox_handlers.lua). The server numbers the traps; a trap I hold gets its card here when the
-- view lists it.
local screen = {}
PVP.trap_screen = screen

local function net()
	return PVP.match_net
end

local function warn(message)
	sendWarnMessage("[trap_screen] " .. message, "MULTIPLAYER")
end

-- A replay, a fast-forward or a rejoin load plays my run again through the same game calls: nothing is
-- sent and no total counted while one runs.
local function playing_back()
	return MPAPI.playback.is_driving("pvp")
end

local function send(kind, body)
	return net().send_live(kind, body)
end

local function pvp_net()
	return G.GAME and G.GAME.pvp_net
end

-- The traps that went off or were lost in this run, kept with the run (G.GAME.pvp_net.traps_gone, a set
-- by trap number as text), so a loaded game neither sends one again nor deals it again.
local function is_gone(trap_number)
	local gone = pvp_net() and pvp_net().traps_gone
	return gone ~= nil and gone[tostring(trap_number)] == true
end

local function mark_gone(trap_number)
	local record = pvp_net()
	record.traps_gone = record.traps_gone or {}
	record.traps_gone[tostring(trap_number)] = true
end

-- A trap card taken from a pack: the server decides who gets it, and whether a lock sends it back.
-- With no view, or when the send is refused, nothing is counted.
function screen.planted(key)
	if not net().view then return nil end
	return (PVP.run_totals.count_sent(pvp_net(), "trap:" .. key, function(total)
		return send("trapPlant", PVP.trap_reader.plant(key, total))
	end))
end

-- Nil when the trap card's fire can be built from these fields (_trap_data.lua), else why not. Asked
-- before a trap takes anything from me.
function screen.fire_problem(card, values)
	local body, problem = PVP.trap_reader.fire(card.ability.mp_trap_id, card.config.center.key, values)
	if body then return nil end
	return tostring(problem)
end

-- The trap went off here and its fire cannot reach the server. It is gone here all the same, or the
-- view's live copy would be dealt to me again; the server is told it was lost when that can be sent.
local function give_up(trap_number, why)
	local lost = PVP.trap_reader.lost(trap_number)
	if not lost then return warn("trap fire not sent: " .. why) end
	mark_gone(trap_number)
	if not send("trapLost", lost) then warn("trap " .. trap_number .. " is gone here and the server was not told: " .. why) end
end

-- The trap card I hold went off; values are the fields its trap names (_trap_data.lua).
function screen.fired(card, values)
	local trap_number = card.ability.mp_trap_id
	if is_gone(trap_number) or playing_back() then return nil end
	local body, problem = PVP.trap_reader.fire(trap_number, card.config.center.key, values)
	if not body then return give_up(trap_number, tostring(problem)) end
	local sent, why = send("trapFire", body)
	if not sent then return give_up(trap_number, tostring(why)) end
	mark_gone(trap_number)
	return sent
end

-- The trap card I hold was destroyed without going off.
function screen.lost(card)
	local trap_number = card.ability.mp_trap_id
	if is_gone(trap_number) then return nil end
	local sent = send("trapLost", PVP.trap_reader.lost(trap_number))
	if sent then mark_gone(trap_number) end
	return sent
end

local function held_cards()
	local cards = {}
	for _, card in ipairs(G.consumeables and G.consumeables.cards or {}) do
		local ability = card.ability
		if ability.mp_trap_hidden and ability.mp_trap_id then
			cards[#cards + 1] = { id = ability.mp_trap_id, fired = ability.mp_trap_fired == true, card = card }
		end
	end
	return cards
end

-- Built directly, as the Wheels are: SMODS.add_card would poll shared random streams.
local function add_held(trap)
	local center = G.P_CENTERS[trap.key]
	if not center then return warn("no trap card " .. trap.key) end
	local area = G.consumeables
	local card = Card(area.T.x + area.T.w / 2, area.T.y, G.CARD_W, G.CARD_H, nil, center)
	card.ability.mp_trap_id = trap.id
	card.ability.mp_trap_owner_id = trap.owner
	card:add_to_deck()
	area:emplace(card)
	PVP.TRAP.disguise(card)
end

local function reveal_held(trap_number)
	for _, held in ipairs(held_cards()) do
		if held.id == trap_number then
			held.card.ability.mp_trap_fired = true
			PVP.TRAP.reveal_and_consume(held.card)
			mark_gone(trap_number)
		end
	end
end

-- Once per frame: my own trap cards match the traps I hold, and the Nemesis row matches the traps
-- I planted. Only for the view of my own run.
function screen.update()
	local view = net().view
	local traps = PVP.trap_reader.traps(view)
	if not (traps and PVP.view.is_my_run(view, pvp_net()) and G.consumeables) then
		PVP.view.changed("trap signature", nil)
		return
	end
	local work = PVP.trap_reader.reconcile(traps, view.me, held_cards(), is_gone)
	for _, trap in ipairs(work.add) do add_held(trap) end
	for _, trap_number in ipairs(work.reveal) do reveal_held(trap_number) end
	if PVP.view.changed("trap signature", PVP.trap_reader.signature(traps)) then PVP.TRAP_ROW.refresh() end
end


-- Only a trap destroyed while hidden is lost: one that went off is revealed and dissolved by its own
-- code, which marks it fired first.
local start_dissolve_ref = Card.start_dissolve
function Card:start_dissolve(...)
	local ability = self.ability
	if PVP.in_session() and ability and ability.mp_trap_hidden and not ability.mp_trap_fired then
		screen.lost(self)
	end
	return start_dissolve_ref(self, ...)
end

return screen
