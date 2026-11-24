-- Run from the repo root: luajit tests/unit/comeback_owner_test.lua
-- The comeback bonus has one owner, the comebackBonus inbox item (pvp_api/net/inbox.lua): a life
-- dropping (pvp_api/ui/match.lua show_lives) pays nothing by itself.
local T = dofile("tests/support/check.lua")
local eq = T.eq


local eased = {}
local function player_info(config, lives_before)
	G = { GAME = { blind = { dollars = 5 }, round_resets = { ante = 1 } } }
	PVP = {
		LOBBY = { config = config },
		GAME = { lives = lives_before, comeback_bonus = 0, comeback_payout = "none" },
		UI = { ease_lives = function(change) eased[#eased + 1] = change end },
	}
	dofile("pvp_api/ui/match.lua")
	return function(p) PVP.UI.match.show_lives(p.lives) end
end

local info = player_info({ gold_on_life_loss = true }, 4)
info({ lives = 3 })
eq(PVP.GAME.lives, 3, "the new lives are kept")
eq(eased[#eased], -1, "the lives on screen move")
eq(PVP.GAME.comeback_bonus, 0, "a life dropping pays no comeback bonus by itself")
eq(PVP.GAME.comeback_payout, "none", "and does not open one")

info = player_info({ gold_on_life_loss = true }, 4)
info({ lives = 1 })
eq(PVP.GAME.comeback_bonus, 0, "also for several lives at once")

info = player_info({ gold_on_life_loss = true }, 4)
info({ lives = 0 })
eq(PVP.GAME.comeback_bonus, 0, "also on the last life")

info = player_info({ no_gold_on_pvp_loss = true }, 4)
info({ lives = 3 })
eq(G.GAME.blind.dollars, 0, "a ruleset with no gold on a lost blind still zeroes it")

-- the inbox item is the one payer: the real item through the real game calls
PVP = { NET = {}, READ = {}, GAME = { comeback_bonus = 2, comeback_payout = "given" } }
dofile("pvp_api/read/_view.lua")
dofile("pvp_api/net/inbox.lua")
sendWarnMessage = function() end
PVP.NET.inbox.effects.comebackBonus({ effect = "comebackBonus", itemNumber = 1, amount = 1 })
eq(PVP.GAME.comeback_bonus, 3, "it raises the bonus by its amount")
eq(PVP.GAME.comeback_payout, "pending", "and opens the next payout")
eq(pcall(PVP.NET.inbox.effects.comebackBonus, { effect = "comebackBonus", itemNumber = 2 }), false, "an item with no amount is refused")
eq(PVP.GAME.comeback_bonus, 3, "and changes nothing")

T.done("comeback_owner_test")
