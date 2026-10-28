--translation by Phrog
return {
	descriptions = {
		Joker = {
			j_broken = {
				name = "DEFEKT",
				text = {
					"Diese Karte ist defekt oder nicht",
					"Implementiert in der jetzigen",
					"version der Mod die benutzt wird.",
				},
			},
			j_mp_defensive_joker = {
				name = "Defensiver Joker",
				text = {
					"{C:chips}+#1#{} Chips für jedes {C:red,E:1}Leben{}",
					"weniger als dein{X:purple,C:white} Erzfeind{}",
					"{C:inactive}(Zurzeit {C:chips}+#2#{C:inactive} Chips)",
				},
			},
			j_mp_skip_off = {
				name = "Skip-Off",
				text = {
					"{C:blue}+#1#{} Hände und {C:red}+#2#{} Abwürfe ",
					"pro zusätzliche übersprungene {C:attention}Blinds{} ",
					"im Vergleich zu deinem  {X:purple,C:white}Erzfeind {}",
					"{C:inactive}(Currently {C:blue}+#3#{C:inactive}/{C:red}+#4#{C:inactive}, #5#)",
				},
			},
			j_mp_lets_go_gambling = {
				name = "Let's Go Gambling",
				text = {
					"{C:green}#1# in #2#{} Chance für",
					"{X:mult,C:white}X#3#{} Mult und {C:money}$#4#{}",
					"{C:green}#5# in #6#{} Chance",
					"deinen {X:purple,C:white} Erzfeind{} {C:money}$#7# zu geben",
				},
			},
			j_mp_speedrun = {
				name = "SPEEDRUN",
				text = {
					"Falls du eine {C:attention}PvP Blind",
					"bevor deinen{X:purple,C:white} Erzfeind{} erreichst,",
					"Erscheint eine zufällige {C:spectral}Geister{} Karte",
					"{C:inactive}(Muss Platz haben)",
				},
			},
			j_mp_conjoined_joker = {
				name = "Verbundener Joker",
				text = {
					"Während einer{C:attention}PvP Blind{}, erhalte",
					"{X:mult,C:white}X#1#{} Mult für jede {C:blue}Hand{}",
					"die dein {X:purple,C:white} Erzfeind{} Übrig hat",
					"{C:inactive}(Max {X:mult,C:white}X#2#{C:inactive} Mult, Zurzeit {X:mult,C:white}X#3#{C:inactive} Mult)",
				},
			},
			j_mp_penny_pincher = {
				name = "Pfennigfuchs",
				text = {
					"Beim Anfang des shop, erhalte",
					"{C:money}$#1#{} für jede{C:money}$#2#{}",
					"die dein {X:purple,C:white} Erzfeind{} im letzen shop benutzt hat",
				},
			},
			j_mp_taxes = {
				name = "Steuern",
				text = {
					"Wenn dein {X:purple,C:white} Erzfeind'{} eine ",
					"Karte verkauft erhalte {C:mult}+#1#{} Mult",
					"{C:inactive}(Zurzeit {C:mult}+#2#{C:inactive} Mult)",
				},
			},
			j_mp_magnet = {
				name = "Magnet",
				text = {
					"Nach {C:attention}#1#{} Runden,",
					"verkaufe diese Karte um eine {C:attention} Kopie{}",
					"deines {X:purple,C:white} Erzfeinds'{}",
					"{C:attention}Joker{} mit dem größten verkaufs wert",
					"{C:inactive}(Zurzeit {C:attention}#2#{C:inactive}/#3# Runden)",
				},
			},
			j_mp_pizza = {
				name = "Pizza",
				text = {
					"{C:red}+#1#{} Abwürfe für alle Spieler",
					"{C:red}-#2#{} Abwürfe wenn irgendein Spieler",
					"eine Blind auswählt",
					"Aufgegessen wenn dein {X:purple,C:white} Erzfeind {} eine Runde Überspringt",
				},
			},
			j_mp_pacifist = {
				name = "Pazifist",
				text = {
					"{X:mult,C:white}X#1#{} Mult wenn",
					"nicht in einer {C:attention}PvP Blind{}",
				},
			},
			j_mp_hanging_chad = {
				name = "Stanzrest",
				text = {
					"Löse die{C:attention} Erste{} und {C:attention}zweite{}",
					"gespielte Karte die für die Wertung benutzt wurde",
					"{C:attention}#1#{} weiteres Mal aus",
				},
			},
		},
		Planet = {
			c_mp_asteroid = {
				name = "Asteroid",
				text = {
					"Entferne #1# level von",
					"deinem {X:purple,C:white}Erzfeinds'{}",
					"meist verbesserten",
					"{C:legendary,E:1}Poker Hand{}",
				},
			},
		},
		Blind = {
			bl_mp_nemesis = {
				name = "Dein Erzfeind",
				text = {
					"Stelle dich einem anderen Spieler,",
					"Größte Punktzahl gewinnt",
				},
			},
		},
		Edition = {
			e_mp_phantom = {
				name = "Phantom",
				text = {
					"{C:attention}Ewig{} und {C:dark_edition}Negative{}",
					"Erzeugt und zerstört bei deinen  {X:purple,C:white}Erzfeind{}",
				},
			},
		},
		Other = {
			current_nemesis = {
				name = "Erzfeind",
				text = {
					"{X:purple,C:white}#1#{}",
					"Dein Größter und schlimmster Gegner",
				},
			},
		},
	},
	misc = {
		labels = {
			mp_phantom = "Phantom",
		},
		challenge_names = {
			c_mp_standard = "Standard",
			c_mp_badlatro = "Badlatro",
			c_mp_tournament = "Turnier",
			c_mp_weekly = "Wöchentlich",
			c_mp_vanilla = "Vanilla",
		},
		dictionary = {
			b_singleplayer = "Einzelspieler",
			b_join_lobby = "Lobby Beitreten",
			b_return_lobby = "Zurück zur Lobby",
			b_reconnect = "Wiederverbinden",
			b_create_lobby = "Lobby Herstellen",
			b_start_lobby = "Lobby Starten",
			b_ready = "Bereit",
			b_unready = "Nicht Bereit",
			b_leave_lobby = "Lobby Verlassen",
			b_mp_discord = "Balatro Mehrspieler Discord Server",
			b_start = "START",
			b_wait_for_host_start = {
				"WARTEN AUF DEN",
				"HOST ZUM STARTEN",
			},
			b_wait_for_players = {
				"WARTEN AUF",
				"SPIELER",
			},
			b_lobby_options = "LOBBY OPTIONEN",
			b_copy_clipboard = "Kopier zur Zwischenablage",
			b_view_code = "CODE ZEIGEN",
			b_copy_code = "KOPIER CODE",
			b_leave = "VERLASSEN",
			b_opts_cb_money = "Gebe comeback $ wenn Leben verloren werden",
			b_opts_no_gold_on_loss = "Kriege keine Blind Belohnung für verlieren",
			b_opts_death_on_loss = "Verliere ein Leben bei Nicht-PVP Blind Niederlage",
			b_opts_start_antes = "Starter Antes",
			b_opts_diff_seeds = "Spieler haben unterschiedliche Code",
			b_opts_lives = "Leben",
			b_opts_multiplayer_jokers = "Füge Mehrspieler Karten hinzu",
			b_opts_player_diff_deck = "Spieler haben unterschiedliche decks",
			b_reset = "Neustart",
			b_set_custom_seed = "Setzt eigenen Code fest",
			b_mp_kofi_button = "Support mich auf Ko-fi",
			b_unstuck = "Stecken geblieben",
			b_unstuck_arcana = "Im Booster Pack stecken geblieben",
			b_unstuck_blind = "Außerhalb der Pvp blind stecken geblieben",
			k_enemy_score = "Gegners Punktzahl",
			k_enemy_hands = "Gegners Übrige Hände: ",
			k_coming_soon = "Kommt Noch!",
			k_wait_enemy = "Warte auf dein Gegner...",
			k_lives = "Leben",
			k_lost_life = "Leben verloren",
			k_total_lives_lost = " Gesamtzahl Verlorener Leben($4 each)",
			k_attrition_name = "Attrition",
			k_enter_lobby_code = "Lobby Code Einfügen",
			k_paste = "Einfügen von der Zwischenablage",
			k_username = "Benutzername:",
			k_enter_username = "Benutzername Einfügen",
			k_join_discord = "Finde uns auf ",
			k_discord_msg = "Hier kannst du Bugs reporten und Spieler zum spielen finden",
			k_enter_to_save = "Drück ENTER zum Speichern",
			k_in_lobby = "In Der Lobby",
			k_connected = "Verbunden zum Service",
			k_warn_service = "WARNUNG: Konnten denn Mehrspieler service nicht finden",
			k_set_name = "Setzt dein Benutzername im Hauptmenü! (Mods > Multiplayer > Config)",
			k_mod_hash_warning = "Spieler haben unterschiedliche mods oder mod versionen! Dies kann probleme erzeugen!",
			k_lobby_options = "Lobby Optionen",
			k_connect_player = "Verbundene Spieler:",
			k_opts_only_host = "Nur der Lobby Host kann diese Option ändern",
			k_opts_gm = "Spielemodus Modifikationen",
			k_bl_life = "Leben",
			k_bl_or = "oder",
			k_bl_death = "Sterben",
			k_current_seed = "jetziger Code: ",
			k_random = "Zufällig",
			k_standard = "Standard",
			k_standard_description = "Der Standard Regelsatz,fügt Mehrspieler Karten und Änderungen hinzu um sich der Mehrspieler Meta anzupassen.",
			k_vanilla = "Vanilla",
			k_vanilla_description = "Der Vanilla Regelsatz, Keine Mehrspieler Karten oder Änderungen zum standard Spiel.",
			k_weekly = "Wöchentlich",
			k_weekly_description = "Ein spezieller Regelsatz der sich wöchentlich oder jede andere woche ändert . Schätze du must selbst herausfinden was diesmal geändert wurde!Zurzeit: ",
			k_tournament = "Turnier",
			k_tournament_description = "Der Turnier Regelsatz, das selbe wie der standard Regelsatz aber du kannst nicht die Lobby Optionen ändern.",
			k_badlatro = "Badlatro",
			k_badlatro_description = "Ein wöchentlicher Regelsatz  designed bei @dr_monty_the_snek Auf dem Discord Server dee permanent zur mod hinzufügt wurde.",
			k_oops_ex = "Ups!",
			ml_enemy_loc = {
				"Gegner",
				"Standort",
			},
			ml_mp_kofi_message = {
				"Diese mod und der Spiel Server ist",
				"Programmiert und beibehalten",
				"von einer einzigen Person,",
				"fallst du es magst dann vielleicht",
			},
			loc_ready = "Bereit für PvP",
			loc_selecting = "Am Blind auswählen",
			loc_shop = "Beim Einkaufen",
			loc_playing = "Am Spielen ",
		},
		v_dictionary = {
			a_mp_art = {
				"Design: #1#",
			},
			a_mp_code = {
				"Code: #1#",
			},
			a_mp_idea = {
				"Idee: #1#",
			},
			a_mp_skips_ahead = {
				"#1# Runden voraus",
			},
			a_mp_skips_behind = {
				"#1# Runden hinter dir",
			},
			a_mp_skips_tied = {
				"Unentschieden",
			},
		},
		v_text = {
			ch_c_hanging_chad_rework = {
				"{C:attention}Stanzrest{} ist {C:dark_edition} Verändert",
			},
			ch_c_glass_cards_rework = {
				"{C:attention}Glass Karten{} sind {C:dark_edition} Verändert",
			},
		},
	},
}
