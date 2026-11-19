SMODS.Atlas({
	key = "error_sandbox",
	path = "j_ERROR_sandbox.png",
	px = 71,
	py = 95,
})

SMODS.Joker({
	key = "error_sandbox",
	loc_vars = function(self, info_queue, card)
		local r_mults = {}
		for i = 1, 333 do
			r_mults[#r_mults + 1] = tostring(i)
		end
		local loc_mult = "(CURRENTLY " .. math.random(1, 333) .. ")"
		main_end = {
			{ n = G.UIT.T, config = { text = loc_mult, colour = lighten(G.C.PURPLE, 0.2), scale = 0.4 } },
			{
				n = G.UIT.O,
				config = {
					object = DynaText({
						string = r_mults,
						colours = { G.C.MONEY },
						pop_in_rate = 9999999,
						silent = true,
						random_element = true,
						pop_delay = 1.52,
						scale = 0.32,
						min_cycle_time = 0,
					}),
				},
			},
			{
				n = G.UIT.O,
				config = {
					object = DynaText({
						string = {
							{ string = "SYSTEM_SERVICE_EXCEPTION", colour = lighten(G.C.BLUE, 0.3) },
							{ string = "KERNEL_DATA_INPAGE_ERROR", colour = G.C.BLUE },
							{ string = "IRQL_NOT_LESS_OR_EQUAL", colour = lighten(G.C.BLUE, 0.4) },
							{ string = "PAGE_FAULT_IN_NONPAGED_AREA", colour = G.C.CHIPS },
							{ string = "KMODE_EXCEPTION_NOT_HANDLED", colour = lighten(G.C.BLUE, 0.2) },
							{ string = "DRIVER_POWER_STATE_FAILURE", colour = G.C.SECONDARY_SET.Planet },
							{ string = "CRITICAL_PROCESS_DIED", colour = G.C.RED },
							{ string = "BAD_POOL_HEADER", colour = lighten(G.C.CHIPS, 0.3) },
							{ string = "MEMORY_MANAGEMENT", colour = G.C.BLUE },
							{ string = "SYSTEM_THREAD_EXCEPTION", colour = lighten(G.C.BLUE, 0.5) },
							{ string = "DPC_WATCHDOG_VIOLATION", colour = G.C.CHIPS },
							{ string = "CLOCK_WATCHDOG_TIMEOUT", colour = lighten(G.C.BLUE, 0.1) },
							{ string = "WHEA_UNCORRECTABLE_ERROR", colour = G.C.SECONDARY_SET.Planet },
							{ string = "PFN_LIST_CORRUPT", colour = lighten(G.C.CHIPS, 0.4) },
							{ string = "DRIVER_VERIFIER_DETECTED", colour = G.C.BLUE },
							{ string = "THREAD_STUCK_IN_DEVICE_DRIVER", colour = lighten(G.C.BLUE, 0.2) },
							{ string = "VIDEO_TDR_TIMEOUT_DETECTED", colour = G.C.CHIPS },
							{ string = "APC_INDEX_MISMATCH", colour = lighten(G.C.BLUE, 0.6) },
							{ string = "DRIVER_IRQL_NOT_LESS_OR_EQUAL", colour = G.C.SECONDARY_SET.Planet },
							{ string = "BUGCODE_USB_DRIVER", colour = lighten(G.C.CHIPS, 0.2) },
							{ string = "HYPERVISOR_ERROR", colour = G.C.BLUE },
							{ string = "UNEXPECTED_KERNEL_MODE_TRAP", colour = lighten(G.C.BLUE, 0.3) },
							{ string = "ATTEMPTED_WRITE_TO_READONLY_MEMORY", colour = G.C.CHIPS },
							{ string = "DRIVER_CORRUPTED_EXPOOL", colour = lighten(G.C.BLUE, 0.4) },
							{ string = "NTFS_FILE_SYSTEM", colour = G.C.SECONDARY_SET.Planet },
							{ string = "FAT_FILE_SYSTEM", colour = lighten(G.C.CHIPS, 0.3) },
							{ string = "KERNEL_SECURITY_CHECK_FAILURE", colour = G.C.BLUE },
							{ string = "STOP: 0x0000007E", colour = lighten(G.C.BLUE, 0.2) },
							{ string = "STOP: 0x000000D1", colour = G.C.CHIPS },
							{ string = "STOP: 0x0000001E", colour = lighten(G.C.BLUE, 0.5) },
							{ string = "STOP: 0x00000050", colour = G.C.SECONDARY_SET.Planet },
							{ string = "STOP: 0x000000A", colour = lighten(G.C.CHIPS, 0.4) },
							{ string = "corrupted heap", colour = G.C.BLIND.Boss },
							{ string = "BSOD", colour = G.C.BLUE },
							{ string = "malloc(): corrupted top size", colour = G.C.RED },
							{ string = "use after free", colour = G.C.PERISHABLE },
							{ string = "stack smashing detected", colour = G.C.ETERNAL },
							{ string = "double free or corruption", colour = lighten(G.C.RED, 0.2) },
							{ string = "zombie process", colour = lighten(G.C.L_BLACK, 0.5) },
							{ string = "killed by signal 9", colour = G.C.SO_1.Hearts },
							{
								string = "0x" .. string.format("%08X", math.random(0, 0xFFFFFFFF)),
								colour = G.C.MONEY,
							},
							"$",
							"€",
							"¥",
							"despair",
							"£",
							"₹",
							"₽",
							"₩",
							"¢",
							"₿",
							"◊",
						},
						colours = { G.C.UI.TEXT_DARK },
						pop_in_rate = 1,
						silent = true,
						random_element = true,
						pop_delay = 0.38,
						scale = 0.32,
						min_cycle_time = 0,
					}),
				},
			},
		}
		return { main_end = main_end }
	end,

	atlas = "error_sandbox",
	no_collection = PVP.sandbox_no_collection,
	unlocked = true,
	discovered = true,
	mp_include = function(self)
		return false
	end,
	mp_credits = { art = { "aura?" } },
})
