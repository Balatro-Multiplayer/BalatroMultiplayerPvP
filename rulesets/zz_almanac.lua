-- Load after Expanded and copy its actual layer chain, not a second list that
-- can drift. Almanac changes the deck and draft policy, not Expanded's content.
local layers = {}
-- HACK: reaches into Expanded's private _layer_order; "Expanded + almanac" should be one declared line. Fix when layers get decomposed.
for _, layer in ipairs(PVP.Rulesets.ruleset_mp_expanded._layer_order) do
	layers[#layers + 1] = layer
end
layers[#layers + 1] = "almanac"
PVP.Ruleset({ key = "almanac", layers = layers }):inject()
