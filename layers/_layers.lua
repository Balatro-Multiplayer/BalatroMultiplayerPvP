-- Credit to @MathIsFun_ and the Balatro Multiplayer project for the layer system this is based on.
-- PvP layer content registers directly into MPAPI.Layer (no PvP-side wrapper --
-- MPAPI.Layer already provides the shared MPAPI.Layers registry and its
-- reworked_* reverse-index tables for free, so MPAPI's own pool-gating register
-- hook (api/layers/pool_gating.lua) auto-gates PvP content the same way it
-- already does for MPAPI/Speed content).
--
-- Pool-inclusion enforcement itself (the should_exclude_from_pool check + the
-- Lovely patch that wires it into get_current_pool) now lives entirely in MPAPI
-- (BalatroMultiplayerAPI/lovely/pool_gating.toml) so any MPAPI-consumer mod gets
-- the same isolation for free. PvP just registers how to tell whether its own
-- content should be active right now -- individual jokers/consumables no longer
-- need their own mp_include for the common case (see objects/ for the handful
-- that still define one, for logic beyond this default).
-- CONFIRMED LIVE BUG #1, fixed by the multiplayer_content check: this gate is what every
-- PvP joker/consumable/tag/voucher/enhancement/blind with no layer membership of its
-- own falls back to (defensive_joker/skip_off/lets_go_gambling/speedrun/conjoined_joker/
-- penny_pincher/taxes/pizza/pacifist -- the whole "brand-new, no vanilla equivalent"
-- core pool) -- it never consulted the active ruleset's own multiplayer_content flag,
-- only LOBBY.code (any live match) and multiplayer_jokers (a lobby-config field
-- defaulted true in core.lua and never set false anywhere in this codebase). Reproduced
-- live: a real private lobby with the "Vanilla" ruleset selected -- explicitly meant to
-- play exactly like unmodded Balatro, and correctly hiding PvP-only decks/stakes via
-- overrides/hide_content.lua's own multiplayer_content check -- still had all 9 of
-- those jokers eligible in the shop pool (get_current_pool('Joker') actually drew 4 of
-- them). multiplayer_content resolves correctly through the ruleset's layer chain
-- (confirmed live for balanced/expanded/smallworld, all inheriting `true`
-- from the "expanded" layer) via PVP.current_ruleset(), which -- unlike checking
-- PVP.LOBBY.config.ruleset directly -- also already knows about practice mode's
-- separate resolution path (see rulesets/_rulesets.lua's own comment on why PvP keeps
-- this resolution local instead of delegating to MPAPI's).
--
-- CONFIRMED LIVE BUG #2, fixed by is_mp_or_practice() replacing a bare LOBBY.code check:
-- practice_mode.lua's _start_practice() deliberately never allocates a real lobby code
-- (lobby.suppress_lobby_view = true, a client-only local lobby) -- so this gate, keyed
-- on LOBBY.code alone, evaluated false for the ENTIRE duration of every practice run
-- regardless of ruleset, wrongly excluding those same 9 core jokers from ever naturally
-- appearing in a Practice shop even on Balanced (reproduced live: should_exclude_from_pool
-- returned true -- excluded -- for defensive_joker/conjoined_joker in a live Balanced
-- practice run, while a layer-gated card like hanging_chad correctly stayed included).
-- That's backwards from bug #1: not a leak, an unwanted suppression of a ruleset's own
-- real content in the one mode whose entire purpose is letting a player try that content
-- before a real match. is_mp_or_practice() (practice_mode.lua) is the existing helper for
-- exactly "real match or practice", already used by is_layer_active's own chain for this.
MPAPI.register_mod_isolation(PVP.id, function()
	return PVP.is_mp_or_practice() and PVP.LOBBY.config.multiplayer_jokers and PVP.current_ruleset().multiplayer_content
end)

-- ----------------------------------------------------------------------------
-- Modifier layers
-- ----------------------------------------------------------------------------
-- MPAPI.MODIFIERS/add_modifier/etc. already exist (identical shape, same "not
-- materialized onto the ruleset" design) -- delegate rather than keep a second
-- copy. modifiers_parse is called from networking/action_handlers.lua and
-- apply_default_modifiers from pvp_api/lobby_bridge.lua's mirror_metadata.
PVP.modifiers_parse = MPAPI.modifiers_parse

-- PVP.active_layer_chain()/get_active_ruleset() (rulesets/_rulesets.lua) resolve the
-- same lobby metadata MPAPI's own equivalents do, but additionally know about PvP's
-- practice-mode case that MPAPI doesn't -- kept as the PvP-owned resolution layer
-- for that reason, even though the two agree for any live lobby.
function PVP.is_layer_active(layer_name)
	if not layer_name then return false end
	for _, name in ipairs(PVP.active_layer_chain()) do
		if name == layer_name then return true end
	end
	return false
end

function PVP.is_any_layer_active(layers)
	for _, layer_name in pairs(layers) do
		if PVP.is_layer_active(layer_name) then return true end
	end
	return false
end
