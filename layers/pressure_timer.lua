-- The server owns the Pressure clocks (rules.clocks). The layer stays as a name for default_modifiers;
-- the preview delay is the one value the client still reads from it.
MPAPI.Layer("pressure_timer", {
	preview_calculate_delay = 1.5,
})
