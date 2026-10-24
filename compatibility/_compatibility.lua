PVP.DECK = {}

PVP.DECK.BANNED_JOKERS = {}

PVP.DECK.BANNED_CONSUMABLES = {}

PVP.DECK.BANNED_VOUCHERS = {}

PVP.DECK.BANNED_ENHANCEMENTS = {}

PVP.DECK.BANNED_TAGS = {}

PVP.DECK.BANNED_BLINDS = {}

function PVP.DECK.ban_card(card_id)
	if card_id:sub(1, 1) == "j" then
		PVP.DECK.BANNED_JOKERS[#PVP.DECK.BANNED_JOKERS + 1] = card_id
	elseif card_id:sub(1, 1) == "v" then
		PVP.DECK.BANNED_VOUCHERS[#PVP.DECK.BANNED_VOUCHERS + 1] = card_id
	elseif card_id:sub(1, 1) == "m" then
		PVP.DECK.BANNED_ENHANCEMENTS[#PVP.DECK.BANNED_ENHANCEMENTS + 1] = card_id
	end
end

function PVP.DECK.ban_tag(tag_id)
	PVP.DECK.BANNED_TAGS[#PVP.DECK.BANNED_TAGS + 1] = tag_id
end

function PVP.DECK.ban_blind(blind_id)
	PVP.DECK.BANNED_BLINDS[#PVP.DECK.BANNED_BLINDS + 1] = blind_id
end

-- Compat-mod bans (ban_card/ban_tag/ban_blind, called from the individual
-- compatibility/*.lua shims below) aren't part of any ruleset/gamemode's own
-- banned_* fields, so MPAPI.ApplyBans wouldn't see them without this.
MPAPI.register_ban_source(function()
	local keys = {}
	for _, list in ipairs({
		PVP.DECK.BANNED_JOKERS,
		PVP.DECK.BANNED_CONSUMABLES,
		PVP.DECK.BANNED_VOUCHERS,
		PVP.DECK.BANNED_ENHANCEMENTS,
		PVP.DECK.BANNED_TAGS,
		PVP.DECK.BANNED_BLINDS,
	}) do
		for _, key in ipairs(list) do
			keys[#keys + 1] = key
		end
	end
	return keys
end)

local j_broken = {
	order = 1,
	unlocked = true,
	start_alerted = true,
	discovered = true,
	blueprint_compat = true,
	perishable_compat = true,
	eternal_compat = true,
	rarity = 4,
	cost = 10000,
	name = "BROKEN",
	pos = { x = 9, y = 9 },
	set = "Joker",
	effect = "",
	cost_mult = 1.0,
	config = {},
	key = "j_broken",
}

local card_init_ref = Card.init
function Card:init(X, Y, W, H, card, center, params)
	if center == nil then
		sendWarnMessage("Card created without a center, using the BROKEN stand-in\n" .. debug.traceback(), "MULTIPLAYER")
		center = j_broken
	end
	PVP.UTILS.guarded_card_init(card_init_ref, self, X, Y, W, H, card, center, params)
end

PVP.UTILS.install_run_select_guard(PVP.UTILS.in_bmp_run_setup)

PVP.DECK.MAX_STAKE = 0

local stake_queue = {}

function PVP.set_max_stake(stake_key)
	if not SMODS.booted then
		stake_queue[stake_key] = true
		return
	end
	local stake = 1
	repeat
		local key = SMODS.stake_from_index(stake)
		if key == stake_key then
			sendTraceMessage("Setting max stake to " .. stake, "MULTIPLAYER")
			PVP.DECK.MAX_STAKE = math.max(stake, PVP.DECK.MAX_STAKE)
			return
		end
		stake = stake + 1
	until key == "error"
end

local game_update_ref = Game.update
---@diagnostic disable-next-line: duplicate-set-field
function Game:update(dt)
	game_update_ref(self, dt)

	if next(stake_queue) and SMODS.booted then
		for key, _ in pairs(stake_queue) do
			PVP.set_max_stake(key)
			stake_queue[key] = nil
		end
	end
end
