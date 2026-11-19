-- Small World's skip previews must use the allowed tag that skipping actually grants.
-- Run from the repo root: luajit tests/unit/smallworld_skip_tags_test.lua
local active, legacy, ordered, replacement
local rolls, hand_rolls
MPAPI = { Layer = function() end }
PVP = {
	is_layer_active = function() return active end,
	should_use_the_order = function() return ordered end,
	sorted_hand_list = function() return { "Pair", "Flush" } end,
}
SMODS = { showman = function() return false end }
Back = { apply_to_run = function() end }
Card = { apply_to_run = function() end }
add_joker = function() end
Tag = {}
function Tag:init(key, for_collection, blind_type)
	self.key = key
	self.for_collection = for_collection
	self.ability = { blind_type = blind_type }
	if key == "tag_orbital" then
		self.ability.orbital_hand = G.orbital_hand
			or (blind_type and G.GAME.orbital_choices[G.GAME.round_resets.ante][blind_type])
	end
end
setmetatable(Tag, { __call = function(self, ...)
	local tag = setmetatable({}, { __index = self })
	tag:init(...)
	return tag
end })
function get_next_tag_key(append)
	rolls[#rolls + 1] = { append = append, ante = G.GAME.round_resets.ante }
	return replacement
end
function pseudoseed(key) return key end
function pseudorandom_element(pool, seed)
	hand_rolls = hand_rolls + 1
	assert(seed == "orbital_replace")
	return pool[1]
end

dofile("layers/smallworld.lua")

local failures = 0
local function check(name, got, want)
	if got ~= want then
		failures = failures + 1
		print(("FAIL %s: got %s, want %s"):format(name, tostring(got), tostring(want)))
	else
		print("ok   " .. name)
	end
end
local function reset()
	active, legacy, ordered, replacement = true, false, false, "tag_allowed"
	rolls, hand_rolls = {}, 0
	PVP.LOBBY = { code = "TEST", config = { legacy_smallworld = legacy } }
	G = {
		GAME = {
			banned_keys = { tag_banned = true },
			round_resets = {
				ante = 2,
				blind_tags = { Small = "tag_banned", Big = "tag_banned" },
			},
			orbital_choices = { [2] = { Small = "Flush", Big = "Pair" } },
		},
	}
end
local function preview(blind)
	return Tag(G.GAME.round_resets.blind_tags[blind], nil, blind)
end

reset()
local reward = preview("Small")
check("blind select replaces a banned skip", reward.key, "tag_allowed")
check("replacement is saved for this blind", G.GAME.round_resets.blind_tags.Small, reward.key)
check("other blind is untouched", G.GAME.round_resets.blind_tags.Big, "tag_banned")
check("replacement rolls once", #rolls, 1)
check("replacement uses its own stream", rolls[1].append, "replace")
check("normal selection uses the current ante", rolls[1].ante, 2)
replacement = "tag_other"
G.OVERLAY_MENU = {}
check("Blinds tab matches the actual skip reward", preview("Small").key, reward.key)
check("reopening the tab keeps the reward", preview("Small").key, reward.key)
G.OVERLAY_MENU = nil
check("rebuilding blind select keeps the reward", preview("Small").key, reward.key)
check("redrawing never rerolls the replacement", #rolls, 1)

reset()
G.OVERLAY_MENU = {}
local tab_reward = preview("Big")
check("opening Blinds first replaces a banned tag", tab_reward.key, "tag_allowed")
check("Blinds-first replacement is saved", G.GAME.round_resets.blind_tags.Big, tab_reward.key)
G.OVERLAY_MENU = nil
check("later skip reward matches the first preview", preview("Big").key, tab_reward.key)
check("Blinds-first path rolls only once", #rolls, 1)

reset()
replacement, ordered = "tag_orbital", true
G.OVERLAY_MENU = {}
local orbital = preview("Small")
check("replacement can be Orbital", orbital.key, "tag_orbital")
check("Orbital uses this blind's stored hand", orbital.ability.orbital_hand, "Flush")
check("Orbital preview does not roll another hand", hand_rolls, 0)
check("ordered replacement ignores early-ante restrictions", (rolls[1] or {}).ante, 10)
check("ordered replacement restores the ante", G.GAME.round_resets.ante, 2)
check("Orbital replacement restores the global hand", G.orbital_hand, nil)
G.OVERLAY_MENU = nil
check("Orbital redraw keeps the same hand", preview("Small").ability.orbital_hand, "Flush")
check("Orbital redraw does not reroll its tag", #rolls, 1)

reset()
G.GAME.round_resets.blind_tags.Small = "tag_allowed"
check("allowed tags are unchanged", preview("Small").key, "tag_allowed")
check("allowed tags do not roll replacements", #rolls, 0)

reset()
check("collection tags are not replaced", Tag("tag_banned", true, "Small").key, "tag_banned")
check("collection leaves the reward unchanged", G.GAME.round_resets.blind_tags.Small, "tag_banned")
check("collection does not consume RNG", #rolls, 0)
G.OVERLAY_MENU = {}
check("unrelated overlay tags are unchanged", Tag("tag_banned").key, "tag_banned")
check("unrelated overlay does not consume RNG", #rolls, 0)

reset()
active = false
check("other rulesets retain their skip tags", preview("Small").key, "tag_banned")
check("other rulesets do not consume replacement RNG", #rolls, 0)
active = true
PVP.LOBBY.config.legacy_smallworld = true
check("legacy Small World retains its skip tags", preview("Small").key, "tag_banned")
check("legacy mode does not consume replacement RNG", #rolls, 0)

reset()
replacement = "tag_orbital"
G.orbital_hand = "Straight"
local granted = Tag("tag_banned")
check("non-blind tags still get replacements", granted.key, "tag_orbital")
check("non-blind Orbital still rolls a hand", granted.ability.orbital_hand, "Pair")
check("non-blind hand rolls once", hand_rolls, 1)
check("non-blind replacement restores the global hand", G.orbital_hand, "Straight")
check("non-blind replacement does not change skip rewards", G.GAME.round_resets.blind_tags.Small, "tag_banned")

if failures > 0 then
	print(failures .. " failure(s)")
	os.exit(1)
end
print("all passed")
