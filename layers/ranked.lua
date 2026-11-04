MPAPI.Layer("ranked", {
    is_disabled = function(self)
		return PVP.UTILS.check_smods_version() or PVP.UTILS.check_lovely_version()
	end,
	force_lobby_options = function(self)
		PVP.LOBBY.config.the_order = true
		return true
	end,
})
