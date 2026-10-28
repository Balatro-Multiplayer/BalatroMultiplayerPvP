return {
	descriptions = {
		Joker = {
			j_broken = {
				name = "BŁĄD",
				text = {
					"Ta karta jest zepsuta lub nie",
					"została dodana to wersji moda,",
					"który jest aktualnie używany.",
				},
			},
			j_mp_defensive_joker = {
				name = "Joker Obrońca",
				text = {
					"{C:chips}+#1#{} żet. o każde {C:red,E:1}życie{}",
					"mniej niż twój {X:purple,C:white}Nemesis{}",
					"{C:inactive}(obecnie {C:chips}+#2#{C:inactive} żet.)",
				},
			},
			j_mp_skip_off = {
				name = "Gra w Klasy",
				text = {
					"{C:blue}+#1#{} do Rąk i {C:red}+#2#{} do Zrzutek",
					"o każdą dodatkową {C:attention}Przeszkadzajkę{} pominiętą",
					"w porównaniu do twojego {X:purple,C:white}Nemesis{}",
					"{C:inactive}(obecnie {C:blue}+#3#{C:inactive}/{C:red}+#4#{C:inactive}, #5#)",
				},
			},
			j_mp_lets_go_gambling = {
				name = "Hazardujmy",
				text = {
					"{C:green}#1# na #2#{} szans na",
					"mnoz. {X:mult,C:white}X#3#{} i {C:money}$#4#{}",
					"{C:green}#5# na #6#{} szans na",
					"danie twojemu {X:purple,C:white}Nemesis{} {C:money}$#7#",
				},
			},
			j_mp_speedrun = {
				name = "SPEEDRUN",
				text = {
					"Jeśli dotrzesz do {C:attention}Przeszkadzajki PVP",
					"przed swoim {X:purple,C:white}Nemesis{},",
					"stwórz losową kartę {C:spectral}Ducha{}",
					"{C:inactive}(wymaga miejsca)",
				},
			},
			j_mp_conjoined_joker = {
				name = "Złączony Joker",
				text = {
					"Gdy jesteś w {C:attention}Przeszkadzajkę PVP{}, ",
					"mnoż. {X:mult,C:white}X#1#{} za każdą {C:blue}Rękę{},",
					"które pozostały twojemu {X:purple,C:white}Nemesis{}",
					"{C:inactive}(maks. mnoż. {X:mult,C:white}X#2#{C:inactive}, obeceny mnoż. {X:mult,C:white}X#3#{C:inactive})",
				},
			},
			j_mp_penny_pincher = {
				name = "Skąpiec",
				text = {
					"Gdy wstąpisz do sklepu, zdobądź",
					"{C:money}$#1#{} za każde {C:money}$#2#{}",
					"twój {X:purple,C:white}Nemesis{} wydał w poprzedniej rundzie",
				},
			},
			j_mp_taxes = {
				name = "Podatki",
				text = {
					"Gdy twój {X:purple,C:white}Nemesis{} sprzeda",
					"kartę, dodaj {C:mult}+#1#{} do mnoż.",
					"{C:inactive}(Obecnie {C:mult}+#2#{C:inactive} do mnoż.)",
				},
			},
			j_mp_magnet = {
				name = "Magnes",
				text = {
					"Po {C:attention}#1#{} rundach,",
					"sprzedaj tę kartę aby {C:attention}zduplikować{}",
					"{C:attention}Jokera{} z największą wartością sprzedaży",
					"twoiego {X:purple,C:white}Nemesis",
					"{C:inactive}(Obecnie {C:attention}#2#{C:inactive}/#3# rund)",
				},
			},
			j_mp_pizza = {
				name = "Pizza",
				text = {
					"{C:red}+#1#{} do zrzutek dla wszystkich graczy",
					"{C:red}-#2#{} do zrzutkek gdy którykolwiek gracz",
					"wybierze przeszkadzajkę",
					"Zniszcona gdy twój {X:purple,C:white}Nemesis{}",
					"pominie przeszkadzajkę",
				},
			},
			j_mp_pacifist = {
				name = "Joker Pacyfista",
				text = {
					"Mnoż. {X:mult,C:white}X#1#{} gdy",
					"nie jesteś w {C:attention}Przeszkadzajce PVP{}",
				},
			},
			j_mp_hanging_chad = {
				name = "Na włosku",
				text = {
					"Aktywuj ponownie {C:attention}pierwszą{}",
					"i drugą zagraną kartę w punktacji",
					"jeszcze {C:attention}#1#{} raz(y)",
				},
			},
		},
		Planet = {
			c_mp_asteroid = {
				name = "Asteroida",
				text = {
					"Odbierz #1# poziom od",
					"{C:legendary,E:1}układu pokerowego{}",
					"z największym poziomem",
					"twojego {X:purple,C:white}Nemesis{}",
				},
			},
		},
		Blind = {
			bl_mp_nemesis = {
				name = "Twój Nemesis",
				text = {
					"Zmierz się z rywalem,",
					"zdobądź więcej żetonów",
					"niż przeciwnik",
				},
			},
		},
		Edition = {
			e_mp_phantom = {
				name = "Widmo",
				text = {
					"{C:attention}Wieczny{} oraz {C:dark_edition}Negatyw{}",
					"Ta karta jest stworzona i może być zniszczona",
					"przez twoiego {X:purple,C:white}Nemesis{}",
				},
			},
		},
		Back = {
			b_mp_cocktail = {
				name = "Koktajlowa talia",
				text = {
					"Kopiuje efekty",
					"{C:attention}3{} innych",
					"losowych talii",
				},
			},
			b_mp_gradient = {
				name = "Gradientowa talia",
				text = {
					"Karty są także traktowane jak",
					"jedna ranga {C:attention}wyższa{} lub {C:attention}niższa",
					"przez wszystkie efekty {C:attention}jokerów{}",
				},
			},
			b_mp_indigo = {
				name = "Talia indigo",
				text = {
					"Wybierz {C:attention}1{} dodatkową kartę",
					"w paczkach wzmacniających",
				},
			},
			b_mp_orange = {
				name = "Pomarańczowa talia",
				text = {
					"Rozpoczynacz podejście z",
					"{C:attention,T:p_mp_standard_giga}gigapaczką standardową{} oraz",
					"{C:attention}2{} kopiami {C:tarot,T:c_hanged_man}Wisielca",
				},
			},
			b_mp_oracle = {
				name = "Wyroczniowa talia",
				text = {
					"Rozpoczynacz podejście z",
					"kartą {C:spectral,T:c_medium}Medium",
					"i {C:attention,T:v_clearance_sale}Wyprzedarz",
					"Limit pieniędzy to {C:money}$50",
				},
			},
			b_mp_violet = {
				name = "Fioletowa talia",
				text = {
					"{C:attention}+1{} kupon w sklepach.",
					"W wejściu {C:attention}1{}, kupony",
					"mają zniżkę {C:attention}50%{}",
				},
			},
			b_mp_heidelberg = {
				name = "Heidelbergowa talia",
				text = {
					"Tworzy {C:dark_edition}Negatyw{}",
					"{C:attention}1{} losowej posiadanej",
					"{C:attention}zużywalnej{} karty",
					"na końcu zakupów w {C:attention}sklepie",
				},
			},
		},
		Other = {
			current_nemesis = {
				name = "Nemesis",
				text = {
					"{X:purple,C:white}#1#{}",
					"Twój jeden i jedyny Nemesis",
				},
			},
			p_mp_standard_giga = {
				name = "Gigapaczka standardowa",
				text = {
					"Wybierz {C:attention}#1#{} z",
					"{C:attention}#2#{} kart {C:attention}rozgrywających{}, by",
					"dodać je do swojej talii",
					"{C:attention}Niepomijalna{}",
				},
			},
		},
		Stake = {
			stake_mp_planet = {
				name = "Planetowa stawka",
				text = {
					"Fajniejsza, starsza siostra {C:attention}pomarańczowej{},",
					"{C:attention}stawki{} która łaskawie oddała ci",
					"{C:red}zrzutkę wsparcia emocjonalnego{}, bo",
					"nawet ona nie jest taka okrutna",
				},
			},
			stake_mp_spectral = {
				name = "Stawka ducha",
				text = {
					"Stosuje efekty {C:planet}planetowej stawki{} plus:",
					"{C:money}Wyporzyczane{} jokery pojawiają się,",
					"Wymagany wynik skaluje się",
					"jeszcze szybciej dla każdego {C:attention}wejścia",
				},
			},
			stake_mp_spectralplus = {
				name = "Stawka ducha+",
				text = {
					"Stosuje efekty {C:planet}stawki ducha{} plus:",
					"Wymagany wynik skaluje się",
					"jeszcze szybciej dla każdego {C:attention}wejścia",
				},
			},
		},
	},
	misc = {
		labels = {
			mp_phantom = "Widmo",
		},
		dictionary = {
			b_singleplayer = "Tryb Jednoosobowy",
			b_join_lobby = "Dołącz do Lobby",
			b_return_lobby = "Powrót do Lobby",
			b_reconnect = "Połącz ponownie",
			b_create_lobby = "Stwórz Lobby",
			b_start_lobby = "Rozpocznij Grę",
			b_ready = "Potwierdź",
			b_unready = "Anuluj Gotowość",
			b_leave_lobby = "Opuść Lobby",
			b_mp_discord = "Serwera Discord Balatro Multiplayer",
			b_start = "START",
			b_wait_for_host_start = {
				"CZEKANIE NA",
				"ROZPOCZĘCZIE GRY",
			},
			b_wait_for_players = {
				"CZEKANIE NA",
				"GRACZY",
			},
			b_lobby_options = "OPCJE GRY",
			b_copy_clipboard = "Skopiuj do schowka",
			b_view_code = "POKAŻ KOD",
			b_copy_code = "SKOPIUJ KOD",
			b_leave = "OPUŚĆ LOBBY",
			b_opts_cb_money = "Dostawanie $ po straconym życiu",
			b_opts_no_gold_on_loss = " Brak nagrody od przeszkadzajki jeśli życie zostało stracone",
			b_opts_death_on_loss = "Tracenie żyć od zwykłych przeszkadzajek",
			b_opts_start_antes = "Wstęp Pierwszej Rundy",
			b_opts_diff_seeds = "Gracze mogą mieć różne rozstawnienia",
			b_opts_lives = "Życia",
			b_opts_multiplayer_jokers = "Włącz Karty Trybu Wieloosoobowego",
			b_opts_player_diff_deck = "Gracze mogą mieć różne talie",
			b_opts_normal_bosses = "Włącz efekty zdonlości Przeszkadzajek Bossowych",
			b_reset = "Resetuj",
			b_set_custom_seed = "Wprowadź rozstawnienie niestandardowe",
			b_mp_kofi_button = "Wspieraj mnie na Ko-fi",
			b_unstuck = "Utknięnto?",
			b_unstuck_blind = "Utknięnto poza PVP?",
			b_misprint_display = "Wyświetl następną karte w talii",
			b_players = "Gracze",
			b_continue_singleplayer = "Kontynuuj w Trybie Jednosobowym",
			b_the_order_integration = "Włącz Integracje modu The Order ",
			k_enemy_score = "Wynik przeciwnika",
			k_enemy_hands = "Pozostałe ręce przeciwnika: ",
			k_coming_soon = "Wkrótce!",
			k_wait_enemy = "Czekanie na koniec ruchu przeciwnika...",
			k_lives = "Życia",
			k_lost_life = "Stracono życie",
			k_total_lives_lost = " Łacznie Stracone Życia (4$ każde)",
			k_attrition_name = "Starcie",
			k_enter_lobby_code = "Wpisz Kod do Lobby",
			k_paste = "Wklej ze schowka",
			k_username = "Psuedonim:",
			k_enter_username = "Stwórz psuedonim",
			k_join_discord = "Dołącz do ",
			k_discord_msg = "Możesz tam zgłośić błedy z modem oraz znaleść innych graczy",
			k_enter_to_save = "Naciśnij Enter aby zapisać",
			k_in_lobby = "W lobby",
			k_connected = "Połaczono z usługą",
			k_warn_service = "UWAGA: Nie można znaleść usługi Multiplayer",
			k_set_name = "Stwórź swoją nazwę w menu głownym! (Mods > Multiplayer > Config)",
			k_mod_hash_warning = "Gracze mają różne mody lub/oraz wersje! To może sprawić problem!",
			k_lobby_options = "Opcje gry",
			k_connect_player = "Gracze w Lobby:",
			k_opts_only_host = "Tylko Gospodarz Gry może zmieniać te ustawienia",
			k_opts_gm = "Modyfikacje",
			k_opts_pvp_start_round = "PVP rozpoczyna się na rundzie",
			k_bl_life = "Życie",
			k_bl_or = "lub",
			k_bl_death = "Śmierć",
			k_bl_mostchips = "Zdobądź więcej żetonów",
			k_current_seed = "Aktualne rozstawienie: ",
			k_random = "Losowe",
			k_standard = "Standardowe",
			k_standard_description = "Standardowy zbiór zasad, posiada karty Multiplayer oraz inne zmiany do bazowej treści, które sprawiają ulepszenia do mety Trybu Wieloosobowego.",
			k_vanilla = "Vanilla",
			k_vanilla_description = "Zbiór zasad Vanilla bez kart Multiplayer i bez zmian do bazowej treści gry.",
			k_weekly = "Tygodniowe",
			k_weekly_description = "Wyjątkowy zbiór zasad który się zmienia cotygodniowo lub codwutygodniowo. Obecny zbiór zasad: ",
			k_tournament = "Turnejowe",
			k_tournament_description = "Zbiór zasad dla Turnejów, taki sam jak zbiór zasad Standardowy tylko bez możliwości do zmienia opcji lobby.",
			k_badlatro = "Badlatro",
			k_badlatro_description = "Cotygodniowy zbiór zasad zaprojektowany przez @dr_monty_the_snek na serwerze discord, który został dodany to tego moda na stałe.",
			k_oops_ex = "Ups!",
			k_timer = "Czas",
			k_mods_list = "Lista Modów",
			k_the_order_credit = "*Twórca: @MathIsFun_",
			k_the_order_integration_desc = "Ten mod sprawi, że kreacja kart nie będzie zależna od wstępu i wybór kart będzie ten sam dla wszystkich graczy.",
			k_requires_restart = "*Wymaga ponownego uruchomienia gry",
			ml_enemy_loc = {
				"Lokacja",
				"prezeciwnika",
			},
			ml_mp_kofi_message = {
				"Ten mod był zaprogramowany",
				"i jest utrzymywany przez",
				"jedną osobę, jeżeli tobie się",
				"spodobał,",
			},
			ml_lobby_info = {
				"Informacje",
				"o Lobby",
			},
			loc_ready = "Gotowość do PVP",
			loc_selecting = "Wybiera Przeszkadzajkę",
			loc_shop = "W Sklepie",
			loc_playing = "Gra w ",
		},
		v_dictionary = {
			a_mp_art = {
				"Zasoby: #1#",
			},
			a_mp_code = {
				"Programowanie: #1#",
			},
			a_mp_idea = {
				"Pomysł: #1#",
			},
			a_mp_skips_ahead = {
				"#1# Pominięć w Przód",
			},
			a_mp_skips_behind = {
				"#1# Pominięć w Tył",
			},
			a_mp_skips_tied = {
				"Remis",
			},
		},
		v_text = {
			ch_c_hanging_chad_rework = {
				"Joker {C:attention}Na włosku{} został {C:dark_edition}przerobiony",
			},
			ch_c_glass_cards_rework = {
				"{C:attention}Karty Szklane{} zostały {C:dark_edition}przerobione",
			},
		},
		challenge_names = {
			c_mp_standard = "Standardowe",
			c_mp_badlatro = "Badlatro",
			c_mp_tournament = "Turnejowe",
			c_mp_weekly = "Tygodniowe",
			c_mp_vanilla = "Vanilla",
			c_mp_misprint_deck = "Talia - Błąd w druku",
			c_mp_legendaries = "Jokery Legendarne",
			c_mp_psychosis = "Psychoza",
			c_mp_scratch = "Od zera",
			c_mp_twin_towers = "Wieże Bliźniacze",
			c_mp_in_the_red = "Zadłużony",
			c_mp_paper_money = "Banknoty",
			c_mp_high_hand = "Wielka Ręka",
			c_mp_chore_list = "Obowiązki",
			c_mp_oops_all_jokers = "Ups! Same Jokery",
			c_mp_divination = "Wróżbiarstwo",
			c_mp_skip_off = "Gra w Klasy",
			c_mp_lets_go_gambling = "Hazardujmy",
			c_mp_speed = "Speedrun",
		},
	},
}
