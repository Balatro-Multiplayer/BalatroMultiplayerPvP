-- Arcane Lock: the Trap card goes face-down into the taker's own consumables and the lock's
-- Trapper becomes its Trapper. The lock fires outside its calculate, so PVP.TRAP.fire sends its notice.
function PVP.TRAP.bounce_to_taker(card, lock)
	card.ability.mp_trap_owner_id = lock.ability.mp_trap_owner_id
	local bounced = MPAPI.rebuild_card(MPAPI.serialize_card(card), G.consumeables)
	if bounced then
		PVP.TRAP.disguise(bounced)
	end
	PVP.TRAP.fire(lock, {})
end
