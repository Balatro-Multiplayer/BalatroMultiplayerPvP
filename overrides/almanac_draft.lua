local D = PVP.ALMANAC_DRAFT

-- Block state construction, not just clicks: the first shop of an ante must
-- generate its stock AFTER voucher/pool acquisitions have resolved.
function D.gate()
	local state = G.GAME and G.GAME.almanac_draft
	if not state then return false end
	if state.busy then return true end
	if state.seed_pending then
		state.seed = D.new(G.GAME.pseudorandom.seed, state.seed_pending).seed
		state.seed_pending = nil
	end
	if G.GAME.round_resets.ante > state.last_ante and not MPAPI.playback._queues_empty() then return true end
	if D.networked and D.networked() then return D.network_gate(state) end
	local pending = D.offer(state, G.GAME.round_resets.ante, G.P_CENTERS)
	if pending then
		if not G.OVERLAY_MENU and D.show then
			save_run()
			D.show()
		end
		return true
	end
	return false
end

for _, method in ipairs({ "update_shop", "update_blind_select" }) do
	local original = Game[method]
	Game[method] = function(self, dt)
		if D.gate() then return end
		return original(self, dt)
	end
end

local update = Game.update
function Game:update(dt)
	update(self, dt)
	local state = G.GAME and G.GAME.almanac_draft
	if not state or G.STAGE ~= G.STAGES.RUN then return end
	if state.busy and MPAPI.playback._queues_empty() then
		state.busy = nil
		save_run()
	end
	-- An interrupted gift pack reopens from the saved pack_due checkpoint. Never
	-- save selected cards without also saving completion of the pack entitlement.
	if state.pack_active then
		if G.STATE ~= G.STATES.SHOP and G.STATE ~= G.STATES.BLIND_SELECT then
			state.pack_seen = true
		elseif state.pack_seen and G.STATE_COMPLETE and MPAPI.playback._queues_empty() then
			state.pack_active, state.pack_seen = nil, nil
			save_run()
		end
	end
	if
		state.pack_due
		and not state.busy
		and not G.OVERLAY_MENU
		and (G.STATE == G.STATES.SHOP or G.STATE == G.STATES.BLIND_SELECT)
		and G.STATE_COMPLETE
	then
		save_run()
		state.pack_due = nil
		state.pack_active = true
		local card = Card(
			G.play.T.x,
			G.play.T.y,
			G.CARD_W * 1.27,
			G.CARD_H * 1.27,
			G.P_CARDS.empty,
			G.P_CENTERS.p_mp_standard_giga,
			{ bypass_discovery_center = true, bypass_discovery_ui = true }
		)
		card.cost, card.from_tag = 0, true
		G.FUNCS.use_card({ config = { ref_table = card } })
	end
end

-- Never persist a partially applied acquisition (voucher/destruction animations
-- can enqueue more events). The prior saved pending offer remains the checkpoint.
local save = save_run
function save_run(...)
	local state = G.GAME and G.GAME.almanac_draft
	if state and (state.busy or state.pack_active) then return end
	return save(...)
end
