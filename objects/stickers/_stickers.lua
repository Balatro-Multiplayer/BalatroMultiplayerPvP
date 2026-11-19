SMODS.Atlas({
	key = "alt_stickers",
	path = "alt_stickers.png",
	px = 71,
	py = 95,
})

local set_ability_ref = Card.set_ability
function Card:set_ability(center, initial, delay_sprites)
	set_ability_ref(self, center, initial, delay_sprites)
	for _, v in ipairs({ "persistent", "unreliable", "draining" }) do
		if G.GAME.modifiers and G.GAME.modifiers["mp_enable_" .. v .. "_jokers"] then
			SMODS.Stickers["mp_sticker_" .. v]:apply(self, center["mp_forced_" .. v])
		end
	end
	-- §18.6: mp_balanced marks a card as rebalanced from vanilla (set directly on
	-- ~30 reworked centers' config, or auto-injected by ReworkCenter for any center
	-- with an existing config -- see api/ruleset/reworks.lua). Unlike persistent/
	-- unreliable/draining above, this isn't an optional per-match toggle: it's
	-- always-on transparency, so it's applied unconditionally rather than gated
	-- on a G.GAME.modifiers flag. Read the new center, not self.ability: set_ability
	-- keeps the old center's config keys, so a Glass card turned Steel still has
	-- ability.mp_balanced.
	if self.config.center.config.mp_balanced then
		SMODS.Stickers["mp_sticker_balanced"]:apply(self, true)
	end
end

local PERSISTENT = {
	"j_8_ball", "j_ancient", "j_baron", "j_blueprint", "j_brainstorm",
	"j_card_sharp", "j_cartomancer", "j_cavendish", "j_certificate", "j_chaos",
	"j_constellation", "j_diet_cola", "j_duo", "j_faceless", "j_fibonacci",
	"j_fortune_teller", "j_gluttenous_joker", "j_greedy_joker", "j_hack", "j_hallucination",
	"j_hanging_chad", "j_invisible", "j_lusty_joker", "j_madness", "j_mail",
	"j_midas_mask", "j_onyx_agate", "j_photograph", "j_riff_raff", "j_rocket",
	"j_runner", "j_seeing_double", "j_smiley", "j_supernova", "j_ticket",
	"j_tribe", "j_trousers", "j_walkie_talkie", "j_wee", "j_wrathful_joker",
	"j_yorick",
}
local UNRELIABLE = {
	"j_abstract", "j_baron", "j_baseball", "j_bloodstone", "j_blueprint",
	"j_business", "j_campfire", "j_cavendish", "j_drivers_license", "j_fibonacci",
	"j_gift", "j_green_joker", "j_gros_michel", "j_half", "j_hanging_chad",
	"j_hologram", "j_ice_cream", "j_idol", "j_lucky_cat", "j_midas_mask",
	"j_mp_conjoined_joker", "j_obelisk", "j_odd_todd", "j_popcorn", "j_raised_fist",
	"j_ride_the_bus", "j_smiley", "j_sock_and_buskin", "j_stuntman", "j_triboulet",
	"j_trio",
}
local DRAINING = {
	"j_ancient", "j_arrowhead", "j_blackboard", "j_brainstorm", "j_burnt",
	"j_business", "j_certificate", "j_dna", "j_drunkard", "j_even_steven",
	"j_family", "j_golden", "j_hanging_chad", "j_idol", "j_mail",
	"j_midas_mask", "j_mime", "j_mp_lets_go_gambling", "j_mp_speedrun", "j_mystic_summit",
	"j_oops", "j_perkeo", "j_popcorn", "j_reserved_parking", "j_riff_raff",
	"j_scary_face", "j_selzer", "j_shoot_the_moon", "j_sixth_sense", "j_sock_and_buskin",
	"j_ticket", "j_trading", "j_triboulet", "j_vagabond",
}

local function to_set(list)
	local s = {}
	for _, k in ipairs(list) do s[k] = true end
	return s
end
local P_SET, U_SET, D_SET = to_set(PERSISTENT), to_set(UNRELIABLE), to_set(DRAINING)

G.E_MANAGER:add_event(Event({
	trigger = "immediate",
	func = function()
		for _, joker in pairs(G.P_CENTER_POOLS.Joker) do
			joker.mp_forced_persistent = P_SET[joker.key] or false
			joker.mp_forced_unreliable = U_SET[joker.key] or false
			joker.mp_forced_draining = D_SET[joker.key] or false
		end
		return true
	end,
}))
