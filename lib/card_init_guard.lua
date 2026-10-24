-- A Card registers itself for per-frame updates (G.MOVEABLES) in Moveable.init, before
-- set_ability gives it an `ability`. When init throws and something upstream swallows the
-- error (an MPAPI event handler pcall), the half-built Card keeps being updated and the
-- game dies later in vanilla Card:update_alert on `self.ability` being nil, hiding the real error.
local function remove_from(list, card)
	for i = #list, 1, -1 do
		if list[i] == card then table.remove(list, i) end
	end
end

function PVP.UTILS.guarded_card_init(card_init, card, ...)
	local ok, err = pcall(card_init, card, ...)
	if ok then return end
	remove_from(G.MOVEABLES, card)
	remove_from(G.I.MOVEABLE, card)
	remove_from(G.I.CARD, card)
	sendWarnMessage("Card:init failed, dropped the half-built Card: " .. tostring(err), "MULTIPLAYER")
	error(err, 0)
end
