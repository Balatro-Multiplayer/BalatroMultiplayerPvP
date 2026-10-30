return {
	descriptions = {
		Tag = {
			tag_mp_gambling_sandbox = {
				name = "Gambling Tag",
				text = {
					"{C:green}#1# in #2#{} chance",
					"Shop has a free",
					"{C:red}Rare Joker{}",
				},
			},
			tag_mp_ward = {
				name = "Ward Tag",
				text = {
					"Gives a free",
					"{C:spectral}Jumbo Spectral Pack",
				},
			},
			tag_mp_juggle_sandbox = {
				name = "Juggle Tag",
				text = {
					"{C:attention}+#1#{} hand size",
					"next {C:attention}PvP Blind",
				},
			},
			tag_mp_investment_sandbox = {
				name = "Investment Tag",
				text = {
					"After defeating",
					"the Boss Blind, gain:",
					"{C:money}$#1#{} + {C:money}$#2#{} per Ante",
					"{C:inactive}(Currently {C:money}$#3#{C:inactive})",
				},
			},
			tag_mp_uncommon_release = {
				name = "Uncommon Tag",
				text = {
					"Shop has an",
					"{C:green}Uncommon Joker",
				},
			},
			tag_mp_rare_release = {
				name = "Rare Tag",
				text = {
					"Shop has a",
					"{C:red}Rare Joker",
				},
			},
			tag_mp_foil_release = {
				name = "Foil Tag",
				text = {
					"Next base edition shop",
					"Joker becomes {C:dark_edition}Foil",
				},
			},
			tag_mp_holo_release = {
				name = "Holographic Tag",
				text = {
					"Next base edition shop",
					"Joker becomes {C:dark_edition}Holographic",
				},
			},
			tag_mp_poly_release = {
				name = "Polychrome Tag",
				text = {
					"Next base edition shop",
					"Joker becomes {C:dark_edition}Polychrome",
				},
			},
			tag_mp_negative_release = {
				name = "Negative Tag",
				text = {
					"Next base edition shop",
					"Joker becomes {C:dark_edition}Negative",
				},
			},
		},
		Joker = {
			j_mp_seltzer = {
				name = "Seltzer",
				text = {
					"Retrigger all",
					"cards played for",
					"the next {C:attention}#1#{} hands",
				},
			},
			j_mp_turtle_bean = {
				name = "Turtle Bean",
				text = {
					"{C:attention}+#1#{} hand size,",
					"reduces by",
					"{C:red}#2#{} every round",
				},
			},
			j_mp_idol = {
				name = "The Idol",
				text = {
					"Each played {C:attention}#2#",
					"of {V:1}#3#{} gives",
					"{X:mult,C:white} X#1# {} Mult when scored",
					"{s:0.8}Card changes every round",
				},
			},
			j_mp_idol_rare = {
				name = "The Idol",
				text = {
					"Each played {C:attention}#2#",
					"of {V:1}#3#{} gives",
					"{X:mult,C:white} X#1# {} Mult when scored",
					"{s:0.8}Card changes every round",
				},
			},
			j_mp_ticket = {
				name = "Golden Ticket",
				text = {
					"Played {C:attention}Gold{} cards",
					"earn {C:money}$#1#{} when scored",
				},
			},
			j_mp_ticket_experimental = {
				name = "Golden Ticket",
				text = {
					"Played {C:attention}Gold{} cards",
					"earn {C:money}$#1#{} when scored",
				},
			},
			j_mp_baron = {
				name = "Baron",
				text = {
					"Each {C:attention}King{} held in hand",
					"gives {X:mult,C:white} X#1# {} Mult",
				},
			},
			j_mp_mime = {
				name = "Mime",
				text = {
					"Retrigger all card",
					"{C:attention}held in hand{} abilities",
				},
			},
			j_mp_todo_list = {
				name = "To Do List",
				text = {
					"Earn {C:money}$#1#{} if {C:attention}poker hand",
					"played is a {C:attention}#2#{},",
					"poker hand changes",
					"at end of round",
				},
			},
			j_broken = {
				name = "BROKEN",
				text = {
					"This card is either broken or",
					"not implemented in the current",
					"version of a mod you are using.",
				},
			},
			j_to_the_moon_mp = {
				name = "To the Moon",
				text = {
					"Earn an extra {C:money}$#1#{} of",
					"{C:attention}interest{} for every {C:money}$#2#{} you",
					"have at end of round",
				},
			},
			j_mp_defensive_joker = {
				name = "Defensive Joker",
				text = {
					"{C:chips}+#1#{} Chips for every {C:red,E:1}life{}",
					"less than your {X:purple,C:white}Nemesis{}",
					"{C:inactive}(Currently {C:chips}+#2#{C:inactive} Chips)",
					"{C:inactive}(Stake-dependent)",
				},
			},
			j_mp_skip_off = {
				name = "Skip-Off",
				text = {
					"{C:blue}+#1#{} Hands and {C:red}+#2#{} Discards",
					"per additional {C:attention}Blind{} skipped",
					"compared to your {X:purple,C:white}Nemesis{}",
					"{C:inactive}(Currently {C:blue}+#3#{C:inactive}/{C:red}+#4#{C:inactive}, #5#)",
				},
			},
			j_mp_lets_go_gambling = {
				name = "Let's Go Gambling",
				text = {
					"{C:green}#1# in #2#{} chance for",
					"{X:mult,C:white}X#3#{} Mult and {C:money}$#4#{}",
					"{C:green}#5# in #6#{} chance to give",
					"your {X:purple,C:white}Nemesis{} {C:money}$#7#{} in {C:attention}PvP Blind",
				},
			},
			j_mp_speedrun = {
				name = "SPEEDRUN",
				text = {
					"If you reach a {C:attention}PvP Blind",
					"within {C:attention}30s{} of your {X:purple,C:white}Nemesis{},",
					"create a random {C:spectral}Spectral{} card",
					"{C:inactive}(Must have room)",
				},
			},
			j_mp_conjoined_joker = {
				name = "Conjoined Joker",
				text = {
					"While in a {C:attention}PvP Blind{}, gain",
					"{X:mult,C:white}X#1#{} Mult for every {C:blue}Hand{}",
					"your {X:purple,C:white}Nemesis{} has left",
					"{C:inactive}(Max {X:mult,C:white}X#2#{C:inactive} Mult, Currently {X:mult,C:white}X#3#{C:inactive} Mult)",
				},
			},
			j_mp_penny_pincher = {
				name = "Penny Pincher",
				text = {
					"At end of round, earn {C:money}$#1#{} for",
					"every {C:money}$#2#{} your {X:purple,C:white}Nemesis{} spent",
					"in corresponding shop {C:attention}last ante{}",
				},
			},
			j_mp_taxes = {
				name = "Taxes",
				text = {
					"Gains {C:mult}+#1#{} Mult for every card your",
					"{X:purple,C:white}Nemesis{} {C:attention}sold{} since last {C:attention}PvP Blind{},",
					"updates when {C:attention}PvP Blind{} is selected",
					"{C:inactive}(Currently {C:mult}+#2#{C:inactive} Mult)",
				},
			},
			j_mp_pizza = {
				name = "Pizza",
				text = {
					"At the end of the next {C:attention}PvP Blind{},",
					"consume this Joker and grant",
					"{C:red}+#1#{} discards to you and",
					"{C:red}+#2#{} discards to your {X:purple,C:white}Nemesis{} for the ante",
				},
			},
			j_mp_pacifist = {
				name = "Pacifist",
				text = {
					"{X:mult,C:white}X#1#{} Mult while",
					"not in a {C:attention}PvP Blind{}",
				},
			},
			j_mp_hanging_chad = {
				name = "Hanging Chad",
				text = {
					"Retrigger {C:attention}first{} and {C:attention}second{}",
					"played card used in scoring",
					"{C:attention}#1#{} additional time",
				},
			},
			j_mp_bloodstone = {
				name = "Bloodstone",
				text = {
					"{C:green}#1# in #2#{} chance for",
					"played cards with",
					"{C:hearts}Heart{} suit to give",
					"{X:mult,C:white} X#3# {} Mult when scored",
				},
			},
			j_mp_magnet_sandbox = {
				name = "Magnet",
				text = {
					"After {C:attention}#1#{} rounds, sell",
					"this card to {C:attention}Copy{} your {X:purple,C:white}Nemesis'{}",
					"highest sell cost {C:attention}Joker{}",
					"polarity inverts after {C:attention}#3#{} rounds",
					"BECOMING WORTHLESS SCRAP METAL!!!!",
					"{C:inactive}(Currently {C:attention}#2#{C:inactive}/#1# rounds)",
				},
			},
			j_mp_cloud_9_sandbox = {
				name = "Cloud 9",
				text = {
					"NUMERAL MONOCULTURE FARMER",
					"converting your DIVERSE DECK into",
					"PROFITABLE NINE PLANTATION!!!!",
					"{C:inactive}({C:green}#1# in #2#{} {C:inactive}chance, currently {C:money}$#3#{}{C:inactive})",
				},
			},
			j_mp_lucky_cat_sandbox = {
				name = "Lucky Cat",
				text = {
					"FORTUNE-TO-FRAGILITY PIPELINE OPERATOR",
					"lucky cats become GLASS CATS",
					"with EXPONENTIAL POWER!!!!",
					"{C:inactive}(Currently {X:mult,C:white} X#2# {C:inactive} Mult)",
				},
			},
			j_mp_constellation_sandbox = {
				name = "Constellation",
				text = {
					"planet maintenance anxiety disorder",
					"MUST FEED THE TAMAGOCHI",
					"or it WITHERS AWAY!!!!",
					"{C:inactive}(Currently {X:mult,C:white} X#1# {C:inactive} Mult)",
				},
			},
			j_mp_bloodstone_sandbox = {
				name = "Bloodstone",
				text = {
					"{V:1}PATCH NOTE REGRESSION SYNDROME",
					"reverting to LAUNCH DAY TRAUMA",
					"for NOSTALGIC {X:mult,C:white}X#3#{} POWER SPIKES!!!!",
					"{C:inactive}({C:green}#1# in #2#{} {C:inactive}chance)",
				},
			},
			j_mp_juggler_sandbox = {
				name = "Juggler",
				text = {
					"HAND SIZE PERFECTIONIST",
					"who must keep ALL THE CARDS",
					"in the air AT ALL TIMES!!!!",
					"{C:inactive}(Currently {C:attention}+#1#{C:inactive} hand size)",
				},
			},
			j_mp_mail_sandbox = {
				name = "Mail-in Rebate",
				text = {
					"Earn {C:money}$#1#{} for each",
					"discarded {C:attention}#2#{}",
					"{s:0.8}Rank never changes",
				},
			},
			j_mp_hit_the_road_sandbox = {
				name = "Hit the Road",
				text = {
					"This Joker gains {X:mult,C:white}X0.75{} Mult",
					"for every {C:attention}Jack{} discarded",
					"Discarded Jacks are {C:attention}destroyed{}",
					"{C:inactive}(Currently {X:mult,C:white} X#2# {C:inactive} Mult)",
				},
			},
			j_mp_misprint_sandbox = {
				name = "Misprint",
				text = {
					"{V:1}#1#{} Mult",
					"{C:attention}Value revealed on purchase{}",
					"{C:green}Printing errors compound{}",
				},
			},
			j_mp_castle_sandbox = {
				name = "Castle",
				text = {
					"This Joker gains {C:chips}+#3#{} Chips",
					"per discarded {V:1}#1#{}",
					"Suit locked on purchase",
					"{C:inactive}(Currently {C:chips}+#2#{C:inactive} Chips)",
				},
			},
			j_mp_runner_sandbox = {
				name = "Runner",
				text = {
					"SEQUENTIAL CARD SUPREMACIST",
					"who believes ALL other",
					"POKER HANDS are INFERIOR!!!!",
					"{C:inactive}(Currently {C:chips}+#1#{C:inactive})",
				},
			},
			j_mp_order_sandbox = {
				name = "The Order",
				text = {
					"{X:mult,C:white}X3{} Mult if played hand contains a {C:attention}Straight{}",
					"Gains {X:mult,C:white}X#1#{} Mult for each consecutive {C:attention}Straight{} played",
					"Resets when any other hand is played",
					"{C:inactive}(Currently {X:mult,C:white}X#2#{C:inactive} Mult)",
				},
			},
			j_mp_photograph_sandbox = {
				name = "Photograph",
				text = {
					"SINGLE SHOT PHOTOGRAPHER who gets",
					"ONE PERFECT FRAME PER HAND!!!!",
				},
			},
			j_mp_ride_the_bus_sandbox = {
				name = "Ride the Bus",
				text = {
					"FACE CARD SOBRIETY PROGRAM",
					"ONE FACE CARD and you're",
					"KICKED OFF THE BUS!!!!",
					"{C:inactive}(Currently {C:mult}+#1#{C:inactive} Mult)",
				},
			},
			j_mp_loyalty_card_sandbox = {
				name = "Loyalty Card",
				text = {
					"{X:mult,C:white}X6{} Mult every {C:attention}#3#{}",
					"hands played of {C:attention}#1#{}",
					"{C:inactive}(#2#/#3#)",
				},
			},
			j_mp_faceless_sandbox = {
				name = "Faceless Joker",
				text = {
					"ELITE FACE CARD SOMMELIER",
					"who curates artisanal",
					"THREE-VARIETY TASTING FLIGHTS",
					"for PREMIUM DISPOSAL EXPERIENCES!!!!",
				},
			},
			j_mp_square_sandbox = {
				name = "Square Joker",
				text = {
					"This Joker gains {C:chips}+#2#{} Chips",
					"if played hand has",
					"exactly {C:attention}4{} cards",
					"{C:attention}Only applies with 4-card hands{}",
					"{C:inactive}(Currently {C:chips}+#1#{C:inactive} Chips)",
				},
			},
			j_mp_throwback_sandbox = {
				name = "Throwback",
				text = {
					"{X:mult,C:white}X#2#{} Base Mult for each",
					"{C:attention}Blind{} skipped this run",
					"{X:mult,C:white}X#3#{} Mult next Blind after skipping",
					"Loses {X:mult,C:white}X#4#{} when Blind not skipped",
					"{C:inactive}(Currently {X:mult,C:white} X#1# {C:inactive} Mult)",
				},
			},
			j_mp_vampire_sandbox = {
				name = "Vampire",
				text = {
					"This Joker gains {X:mult,C:white}X#1#{} Mult per",
					"scoring {C:attention}Enhanced card{} played",
					"Played enhanced cards become {C:attention}Stone{}",
					"Stone cards give {C:money}$#3#{} when played",
					"{C:inactive}(Currently {X:mult,C:white} X#2# {C:inactive} Mult)",
				},
			},
			j_mp_baseball_sandbox = {
				name = "Baseball Card",
				text = {
					"{C:green}Uncommon{} Jokers",
					"each give",
					"{X:mult,C:white}X#1#{} Mult",
				},
			},
			j_mp_steel_joker_sandbox = {
				name = "Steel Joker",
				text = {
					"Played Steel cards",
					"are {C:attention}retriggered{}",
				},
			},
			j_mp_golden_ticket_sandbox = {
				name = "Golden Ticket",
				text = {
					"{C:green}#2# in #3#{} chance for",
					"{C:attention}Gold{} cards to earn",
					"{C:money}$#1#{} when played",
				},
			},
			j_mp_satellite_sandbox = {
				name = "Satellite",
				text = {
					"chronic satellite degradation anxiety",
					"INFRASTRUCTURE SLOWLY FALLS APART",
					"WITHOUT CONSTANT PLANETARY UPGRADES!!!!",
					"{C:inactive}(Currently {C:money}$#1#{C:inactive})",
				},
			},
			j_mp_idol_sandbox_zealot = {
				name = "Zealot Idol",
				text = {
					"Each played {C:attention}#1#{}",
					"gives {X:mult,C:white}X#2#{} Mult",
					"when scored",
					"{s:0.8}Card changes every round",
				},
			},
			j_mp_idol_sandbox_collector = {
				name = "Collector's Idol",
				text = {
					"Most common card gives",
					"{X:mult,C:white}X#3#{} Mult when scored",
					"({X:mult,C:white}+X#4#{} per copy in deck)",
					"{C:inactive}(Currently {C:attention}#1#{} of {V:1}#2#{})",
				},
			},
			j_mp_error_sandbox = {
				name = "????",
				text = {
					"{X:purple,C:white,s:0.85}something's{} {X:purple,C:white,s:0.85}wrong",
				},
			},
			j_mp_clowncollege_sandbox = {
				name = "Clown College",
				text = {
					"{C:attention}Fill{} consumable slots with",
					"{C:tarot}The Fool{} after",
					"{C:attention}Boss Blind{} is defeated",
					"{C:inactive}(Must have room)",
				},
			},
			j_mp_alloy_sandbox = {
				name = "Alloy",
				text = {
					"{C:attention}Gold Cards{} are also",
					"considered {C:attention}Steel Cards{}",
					"{C:attention}Steel Cards{} are also",
					"considered {C:attention}Gold Cards{}",
				},
			},
			j_mp_ambrosia_sandbox = {
				name = "Ambrosia",
				text = {
					"{C:attention}Fill{} consumable slots with",
					"{C:spectral}Spectral Cards{} whenever a",
					"{C:attention}blind{} is {C:attention}skipped{}, destroyed",
					"when any {C:spectral}Spectral Card{} is {C:attention}sold",
					"{C:inactive}(Must have room)",
				},
			},
			j_mp_bobby_sandbox = {
				name = "Bobby",
				text = {
					"When {C:attention}Blind{} is selected,",
					"lose {C:attention}#1#{} Hands and gain",
					"{C:red}+#1#{} Discards for each Hand lost",
				},
			},
			j_mp_candynecklace_sandbox = {
				name = "Candy Necklace",
				text = {
					"At end of {C:attention}shop{}, create",
					"a random {C:attention}Booster Pack Tag",
					"{C:inactive}(#1# uses left){C:inactive}",
				},
			},
			j_mp_chainlightning_sandbox = {
				name = "Chain Lightning",
				text = {
					"Played {C:attention}Mult Cards{} give",
					"{X:mult,C:white}X#1#{} Mult when scored,",
					"then increase this by {X:mult,C:white}X#2#",
					"{C:inactive}(Resets each hand)",
				},
			},
			j_mp_clowncar_sandbox = {
				name = "Clown Car",
				text = {
					"{C:mult}+#1#{} Mult and {C:money}-$#2#",
					"{C:attention}before{} cards are scored",
				},
			},
			j_mp_couponsheet_sandbox = {
				name = "Coupon Sheet",
				text = {
					"Create a {C:attention}Coupon Tag",
					"and a {C:attention}Voucher Tag",
					"after {C:attention}Boss Blind{} is defeated",
				},
			},
			j_mp_doublerainbow_sandbox = {
				name = "Double Rainbow",
				text = {
					"{C:attention}Retrigger{} all {C:attention}Lucky Cards{}",
				},
			},
			j_mp_espresso_sandbox = {
				name = "Espresso",
				text = {
					"Gain {C:money}$#1#{} and destroy this",
					"card when {C:attention}Blind{} is skipped",
					"Decreases by {C:money}$#2#{} at end of round",
				},
			},
			j_mp_farmer_sandbox = {
				name = "Farmer",
				text = {
					"Cards with {V:1}#2#{} suit",
					"held in hand give {C:money}$#1#",
					"at end of round",
					"{s:0.8}suit changes at end of round",
				},
			},
			j_mp_forklift_sandbox = {
				name = "Forklift",
				text = {
					"{C:attention}+#1#{} Consumable Slots",
				},
			},
			j_mp_gofish_sandbox = {
				name = "Go Fish",
				text = {
					"The {C:attention}first time{} that a",
					"{C:attention}played hand{} contains any",
					"scoring {C:attention}#1#s{}, destroy them",
					"{s:0.8}rank changes at end of round",
				},
			},
			j_mp_hoarder_sandbox = {
				name = "Hoarder",
				text = {
					"This Joker gains {C:money}$#1#{} of sell value",
					"whenever {C:money}money{} is earned",
				},
			},
			j_mp_jokalisa_sandbox = {
				name = "Joka Lisa",
				text = {
					"Gains {X:mult,C:white}X#2#{} Mult for",
					"each {C:attention}unique enhancement",
					"in scoring hand",
					"{C:inactive}(Currently {X:mult,C:white}X#1#{C:inactive})",
				},
			},
			j_mp_jokeroftheyear_sandbox = {
				name = "Joker of the Year",
				text = {
					"If played hand has",
					"{C:attention}5{} scoring cards,",
					"{C:attention}retrigger{} played cards",
				},
			},
			j_mp_lucky7_sandbox = {
				name = "Lucky 7",
				text = {
					"If played hand contains",
					"a scoring {C:attention}7{}, all played",
					"cards count as {C:attention}Lucky Cards",
				},
			},
			j_mp_montehaul_sandbox = {
				name = "Monte Haul",
				text = {
					"After {C:attention}1 round{}, sell this card",
					"to gain {C:attention}2{} random {C:attention}Joker Tags",
					"{C:inactive}(Currently {C:attention}#1#{C:inactive} rounds)",
				},
			},
			j_mp_pocketaces_sandbox = {
				name = "Pocket Aces",
				text = {
					"Earn {C:money}$#1#{} at end of round",
					"Played {C:attention}Aces{} increase payout",
					"by {C:money}$#2#{}, resets each {C:attention}Ante",
				},
			},
			j_mp_pyromancer_sandbox = {
				name = "Pyromancer",
				text = {
					"{C:mult}+#1#{} Mult if",
					"remaining {C:attention}Hands{} are less",
					"than or equal to {C:attention}Discards",
				},
			},
			j_mp_shipoftheseus_sandbox = {
				name = "Ship of Theseus",
				text = {
					"Whenever a {C:attention}Playing Card{} is {C:attention}destroyed",
					"add a {C:attention}copy{} of it to your {C:attention}deck",
					"and this joker gains {X:mult,C:white}X#2#{} Mult",
					"{C:inactive}(Currently {X:mult,C:white}X#1#{C:inactive} Mult)",
				},
			},
			j_mp_starfruit_sandbox = {
				name = "Starfruit",
				text = {
					"{C:attention}First played hand{} each round",
					"has a {C:green}#2# in #3#{} chance",
					"to gain {C:attention}1{} level",
					"{C:inactive}({}{C:attention}#1#{}{C:inactive} rounds remaining)",
				},
			},
			j_mp_trafficlight_sandbox = {
				name = "Traffic Light",
				text = {
					"{X:mult,C:white}X#1#{} Mult",
					"Decreases by {X:mult,C:white}X#2#{} after",
					"each hand, resets after {X:mult,C:white}X0.5",
				},
			},
			j_mp_tuxedo_sandbox = {
				name = "Tuxedo",
				text = {
					"{C:attention}Retrigger{} all cards",
					"with {V:1}#1#{} suit",
					"{s:0.8}suit changes at end of round",
				},
			},
			j_mp_warlock_sandbox = {
				name = "Warlock",
				text = {
					"{C:green}#1# in #2#{} chance for played",
					"{C:attention}Lucky Cards{} to be {C:red}destroyed",
					"and spawn a {C:spectral}Spectral Card",
					"{C:inactive}(Must have room)",
				},
			},
			j_mp_werewolf_sandbox = {
				name = "Werewolf",
				text = {
					"Played cards that are",
					"{C:attention}enhanced{} become {C:attention}Wild Cards",
				},
			},
			j_mp_8ball_release = {
				name = "8 Ball",
				text = {
					"Create a {C:planet}Planet{} card",
					"if played hand contains",
					"{C:attention}#1#{} or more {C:attention}8s{}",
					"{C:inactive}(Must have room)",
				},
			},
			j_mp_todo_list_release = {
				name = "To Do List",
				text = {
					"Earn {C:money}$#1#{} if {C:attention}poker hand{}",
					"is a {C:attention}#2#{},",
					"poker hand changes",
					"on every payout",
				},
			},
			j_mp_swashbuckler_release = {
				name = "Swashbuckler",
				text = {
					"Adds the sell value of",
					"all owned {C:attention}Jokers{} left",
					"of this card to Mult",
					"{C:inactive}(Currently {C:mult}+#1#{C:inactive} Mult)",
				},
			},
			j_mp_hanging_chad_release = {
				name = "Hanging Chad",
				text = {
					"Retrigger {C:attention}first{} played",
					"card used in scoring",
				},
			},
			j_mp_madness_release = {
				name = "Madness",
				text = {
					"When {C:attention}Blind{} is selected,",
					"gain {X:mult,C:white} X#1# {} Mult and",
					"{C:attention}destroy{} a random Joker",
					"{C:inactive}(Currently {X:mult,C:white} X#2# {} Mult)",
				},
			},
			j_mp_vampire_release = {
				name = "Vampire",
				text = {
					"This Joker gains {X:mult,C:white} X#1# {} Mult",
					"per {C:attention}Enhanced card{} played,",
					"removes card {C:attention}Enhancement",
					"{C:inactive}(Currently {X:mult,C:white} X#2# {C:inactive} Mult)",
				},
			},
			j_mp_midas_mask_release = {
				name = "Midas Mask",
				text = {
					"All {C:attention}face{} cards",
					"become {C:attention}Gold{} cards",
					"when played",
				},
			},
			j_mp_yorick_release = {
				name = "Yorick",
				text = {
					"{X:mult,C:white} X#1# {} Mult only after",
					"using {C:attention}#2#{} discards",
					"{C:inactive}(Discards left: {C:attention}#3#{C:inactive})",
				},
			},
			j_mp_flower_pot_release = {
				name = "Flower Pot",
				text = {
					"{X:mult,C:white} X#1# {} Mult if played",
					"hand has a scoring",
					"{C:diamonds}Diamond{} card, {C:clubs}Club{} card,",
					"{C:hearts}Heart{} card, and {C:spades}Spade{} card",
				},
			},
		},
		Tarot = {
			c_mp_magician_release = {
				name = "The Magician",
				text = {
					"Enhances {C:attention}#1#{} selected",
					"card into a",
					"{C:attention}#2#",
				},
			},
		},
		Planet = {
			c_mp_asteroid = {
				name = "Asteroid",
				text = {
					"Remove #1# level from",
					"your {X:purple,C:white}Nemesis'{}",
					"highest level {C:legendary,E:1}poker hand{}",
					"at start of {C:attention}PvP Blind{}",
				},
			},
		},
		Blind = {
			bl_mp_nemesis = {
				name = "Your Nemesis",
				text = {
					"Face another player,",
					"most chips wins",
				},
			},
			bl_mp_manhunt_hunter = {
				name = "The Hunters",
				text = {
					"Manhunt: the Runner faces",
					"the Hunters in the PvP Blind",
				},
			},
			bl_mp_manhunt_runner = {
				name = "The Runner",
				text = {
					"Manhunt: the Hunters face",
					"the Runner in the PvP Blind",
				},
			},
		},
		Enhanced = {},
		Back = {
			b_mp_cocktail = {
				name = "Cocktail Deck",
				text = {
					"Copies all effects",
					"of {C:attention}3{} other decks",
					"at random",
				},
			},
			b_mp_gradient = {
				name = "Gradient Deck",
				text = {
					"Cards are also considered",
					"one rank {C:attention}higher{} or {C:attention}lower",
					"for all {C:attention}Joker{} effects",
				},
			},
			b_mp_heidelberg = {
				name = "Heidelberg Deck",
				text = {
					"Creates a {C:dark_edition}Negative{} copy of",
					"{C:attention}1{} random {C:attention}consumable{}",
					"card in your possession",
					"at the end of the {C:attention}shop",
				},
			},
			b_mp_indigo = {
				name = "Indigo Deck",
				text = {
					"Choose {C:attention}+1{} additional card",
					"from all Booster Packs",
					"Booster Packs are {C:attention}unskippable{}",
				},
			},
			b_mp_oracle = {
				name = "Oracle Deck",
				text = {
					"Start run with {C:spectral,T:c_medium}Medium",
					"and {C:attention,T:v_clearance_sale}Clearance Sale",
					"Balance is capped at",
					"{C:money}$50{} + {C:attention}current interest cap{}",
				},
			},
			b_mp_orange = {
				name = "Orange Deck",
				text = {
					"Start run with a",
					"{C:attention,T:p_mp_standard_giga}Giga Standard Pack{}, and",
					"{C:attention}2{} copies of {C:tarot,T:c_hanged_man}The Hanged Man",
				},
			},
			b_mp_violet = {
				name = "Violet Deck",
				text = {
					"{C:attention}+1{} Voucher in shop",
					"Vouchers are {C:attention}50%{} off ",
					"during Ante {C:attention}1{}, and {C:attention}30%{} off",
					"during Ante {C:attention}2",
				},
			},
			b_mp_white = {
				name = "White Deck",
				text = {
					"View {X:purple,C:white}Nemesis'{} current",
					"deck and Joker setup",
					"{C:inactive}(Updates at PvP blind){}",
				},
			},
		},
		Other = {
			mp_sticker_extra_credit = {
				name = "Extra Credit",
				text = {
					"Made with friends from",
					"Balatro University!",
				},
			},
			mp_sticker_balanced = {
				name = "Balanced",
				text = {
					"This card has been rebalanced",
				},
			},
			mp_sticker_balanced_j_mp_hanging_chad = {
				name = "Balanced",
				text = {
					"Retriggers first {C:attention}2{} cards",
					"instead of first card twice",
				},
			},
			mp_sticker_balanced_j_mp_ticket = {
				name = "Balanced",
				text = {
					"Now {C:green}Uncommon{}",
					"No {C:attention}Gold{} card requirement",
				},
			},
			mp_sticker_balanced_j_mp_seltzer = {
				name = "Balanced",
				text = {
					"Lasts {C:attention}8{} hands",
					"instead of {C:attention}10{}",
				},
			},
			mp_sticker_balanced_j_mp_turtle_bean = {
				name = "Balanced",
				text = {
					"{C:attention}+4{} hand size",
					"instead of {C:attention}+5{}",
				},
			},
			mp_sticker_balanced_j_mp_baron = {
				name = "Balanced",
				text = {
					"Now {C:green}Uncommon{} ({C:money}$5{})",
					"instead of {C:red}Rare{} ({C:money}$8{})",
				},
			},
			mp_sticker_balanced_j_mp_mime = {
				name = "Balanced",
				text = {
					"Now {C:red}Rare{} ({C:money}$8{})",
					"instead of {C:green}Uncommon{} ({C:money}$5{})",
				},
			},
			mp_sticker_balanced_j_mp_todo_list = {
				name = "Balanced",
				text = {
					"Earns {C:money}$5{} instead of {C:money}$4{}",
					"Picks from {C:attention}all{} poker hands,",
					"not just discovered ones",
				},
			},
			mp_sticker_balanced_j_mp_bloodstone = {
				name = "Balanced",
				text = {
					"In {C:attention}PvP{}, the {C:green}1 in 2{} rolls",
					"come from a {C:attention}fixed sequence{}",
					"shared between both players and",
					"{C:attention}reused{} every hand of the round",
				},
			},
			mp_sticker_balanced_c_mp_ouija_standard = {
				name = "Balanced",
				text = {
					"Destroys {C:attention}3{} cards instead of",
					"converting all cards and losing",
					"{C:attention}-1{} hand size",
				},
			},
			mp_sticker_balanced_c_mp_wraith = {
				name = "Balanced",
				text = {
					"Creates an {C:green}Uncommon{} instead of a",
					"{C:red}Rare{}, and gains {C:money}$5{} instead of",
					"setting your money to {C:money}$0{}",
				},
			},
			mp_sticker_balanced_m_gold = {
				name = "Balanced",
				text = {
					"Earns {C:money}$4{} instead of {C:money}$3{}",
				},
			},
			current_nemesis = {
				name = "Nemesis",
				text = {
					"{X:purple,C:white}#1#{}",
					"Your one and only Nemesis",
				},
			},
			p_mp_standard_giga = {
				name = "Giga Standard Pack",
				text = {
					"Choose {C:attention}#1#{} of up to",
					"{C:attention}#2#{C:attention} Playing{} cards to",
					"add to your deck",
					"{C:attention}Unskippable{}",
				},
			},
			p_mp_trap_normal = {
				name = "Trap Pack",
				text = {
					"Choose {C:attention}#1#{} of up to",
					"{C:attention}#2#{} {C:attention}Trap{} cards",
				},
			},
			p_mp_trap_jumbo = {
				name = "Jumbo Trap Pack",
				text = {
					"Choose {C:attention}#1#{} of up to",
					"{C:attention}#2#{} {C:attention}Trap{} cards",
				},
			},
			mp_transmutations = {
				name = "Transmutations",
				text = {
					"{C:purple,s:1.1}Will transmute into:",
				},
			},
			mp_internal_sell_value = {
				name = "Sell Value",
				text = {
					"{C:money,s:1.3}$#1#",
				},
			},
			mp_sticker_persistent = {
				name = "Persistent",
				text = {
					"Can't be destroyed",
					"Costs {C:red}${} to sell",
					"Cost increases by",
					"{C:red}$3{} at end of round",
				},
			},
			mp_sticker_unreliable = {
				name = "Unreliable",
				text = {
					"Doesn't trigger on",
					"{C:attention}final hand{}",
				},
			},
			mp_sticker_draining = {
				name = "Draining",
				text = {
					"{X:mult,C:white}X0.75{} Mult",
				},
			},
			mp_blue_seal_release = {
				name = "Blue Seal",
				text = {
					"Creates a {C:planet}Planet{} card",
					"if this card is {C:attention}held{} in",
					"hand at end of round",
				},
			},
		},
		Stake = {
			stake_mp_planet = {
				name = "Planet Stake",
				text = {
					"Applies {C:black}Black Stake{} effects, plus:",
					"Shop can have {C:attention}Perishable{} Jokers",
					"{C:inactive,s:0.8}(Debuffed after 5 Rounds)",
					"Required score scales",
					"faster for each {C:attention}Ante",
				},
			},
			stake_mp_spectral = {
				name = "Spectral Stake",
				text = {
					"Applies {C:planet}Planet Stake{} effects, plus:",
					"{C:money}Rental{} Jokers appear in shop",
					"Required score scales",
					"faster for each {C:attention}Ante",
				},
			},
			stake_mp_spectralplus = {
				name = "Spectral+ Stake",
				text = {
					"Applies {C:planet}Spectral Stake{} effects, plus:",
					"Required score scales",
					"even faster for each {C:attention}Ante",
				},
			},
			stake_mp_plastic = {
				name = "Plastic Stake",
				text = {
					"Earn {C:money}$1{} of interest per {C:money}$10{}",
					"{C:inactive,s:0.8}(Max of {C:money,s:0.8}$50{C:inactive,s:0.8})",
					"{s:0.8}Applies White Stake",
				},
			},
			stake_mp_pebble = {
				name = "Pebble Stake",
				text = {
					"Required score scales",
					"faster for each {C:attention}Ante",
					"{s:0.8}Applies Plastic Stake",
				},
			},
			stake_mp_ferrite = {
				name = "Ferrite Stake",
				text = {
					"Specific Jokers are {C:attention}Persistent",
					"{C:inactive,s:0.8}(Can't be destroyed, increasing sell cost)",
					"{s:0.8}Applies Pebble Stake",
				},
			},
			stake_mp_pyrite = {
				name = "Pyrite Stake",
				text = {
					"Reroll price increases",
					"by {C:money}$2{} each reroll",
					"{s:0.8}Applies Ferrite Stake",
				},
			},
			stake_mp_jade = {
				name = "Jade Stake",
				text = {
					"Required score scales",
					"faster for each {C:attention}Ante",
					"{s:0.8}Applies Pyrite Stake",
				},
			},
			stake_mp_crystal = {
				name = "Crystal Stake",
				text = {
					"Specific Jokers are {C:attention}Unreliable",
					"{C:inactive,s:0.8}(Doesn't trigger on {C:attention,s:0.8}final hand{C:inactive,s:0.8})",
					"{s:0.8}Applies Jade Stake",
				},
			},
			stake_mp_antimatter = {
				name = "Antimatter Stake",
				text = {
					"Specific Jokers are {C:attention}Draining",
					"{C:inactive,s:0.8}({X:mult,C:white,s:0.8} X0.75 {C:inactive,s:0.8} Mult)",
					"{s:0.8}Applies Crystal Stake",
				},
			},
			stake_mp_orange_release = {
				name = "Orange Stake",
				text = {
					"{C:attention}Booster Packs{} cost",
					"{C:money}$1{} more per Ante",
					"{s:0.8}Applies all previous Stakes",
				},
			},
			stake_mp_gold_release = {
				name = "Gold Stake",
				text = {
					"{C:red}-1{} hand size",
					"{s:0.8}Applies all previous Stakes",
				},
			},
		},
		Spectral = {
			c_mp_ouija_standard = {
				name = "Ouija",
				text = {
					"Destroy {C:attention}#1#{} random cards,",
					"then convert all remaining",
					"cards to a single random {C:attention}rank",
				},
			},
			c_mp_ectoplasm_sandbox = {
				name = "Ectoplasm",
				text = {
					"Add {C:dark_edition}Negative{} to",
					"a random {C:attention}Joker,",
					"Randomly apply one of:",
					"{C:red}-1{} hand, {C:red}-1{} discard, or {C:red}-1{} hand size",
				},
			},
			c_mp_wraith = {
				name = "Wraith",
				text = {
					"Creates a random {C:green}Uncommon{} Joker",
					"Gain {C:money}$#1#{}",
				},
			},
		},
		Trap = {
			c_mp_trap_alarm = {
				name = "Alarm",
				text = {
					"When your {X:purple,C:white}Nemesis{} rerolls",
					"the shop, gain {C:attention}2{} free rerolls",
				},
			},
			c_mp_trap_phase_door = {
				name = "Phase Door",
				text = {
					"When your {X:purple,C:white}Nemesis{} is paid for",
					"held gold cards, gain {C:money}$4{} for",
					"every gold card in their hand",
				},
			},
			c_mp_trap_fire_trap = {
				name = "Fire Trap",
				text = {
					"When your {X:purple,C:white}Nemesis{} plays a",
					"hand that contains a {C:attention}Pair{},",
					"decrease the rank of all",
					"scored cards by {C:attention}1{}",
				},
			},
			c_mp_trap_forbiddance = {
				name = "Forbiddance",
				text = {
					"When your {X:purple,C:white}Nemesis{} discards,",
					"the cards drawn to refill their",
					"hand are {C:attention}face-down{}",
				},
			},
			c_mp_trap_guards_and_wards = {
				name = "Guards and Wards",
				text = {
					"When your {X:purple,C:white}Nemesis{} adds a",
					"playing card to their deck,",
					"add {C:attention}2{} Stone Cards to",
					"their deck",
				},
			},
			c_mp_trap_faithful_hound = {
				name = "Faithful Hound",
				text = {
					"When your {X:purple,C:white}Nemesis{} uses a",
					"Planet card, gain {C:attention}3{} levels",
					"for the same poker hand",
				},
			},
			c_mp_trap_programmed_illusion = {
				name = "Programmed Illusion",
				text = {
					"When your {X:purple,C:white}Nemesis{} opens a",
					"booster pack, add a",
					"{C:attention}fake{} card to the pack",
				},
			},
			c_mp_trap_arcane_lock = {
				name = "Arcane Lock",
				text = {
					"When your {X:purple,C:white}Nemesis{} uses a",
					"{C:attention}Trap{} card, they get",
					"trapped instead",
				},
			},
			c_mp_trap_mental_prison = {
				name = "Mental Prison",
				text = {
					"When your {X:purple,C:white}Nemesis{} fails to",
					"use a {C:attention}Wheel of Fortune{}",
					"they see, create {C:attention}2{}",
					"Wheel of Fortunes",
				},
			},
			c_mp_trap_magic_mouth = {
				name = "Magic Mouth",
				text = {
					"When your {X:purple,C:white}Nemesis{} triggers a",
					"{C:blue}Blue{} or {C:purple}Purple{} Seal,",
					"steal the consumable",
				},
			},
			c_mp_trap_explosive_runes = {
				name = "Explosive Runes",
				text = {
					"When your {X:purple,C:white}Nemesis{} plays a",
					"hand with a {C:attention}Glass{} card,",
					"every scored Glass card",
					"breaks after it scores",
				},
			},
			c_mp_trap_sepia_snake_sigil = {
				name = "Sepia Snake Sigil",
				text = {
					"When your {X:purple,C:white}Nemesis{} buys a",
					"{C:attention}Rare{} Joker, gain a",
					"copy of it",
				},
			},
			c_mp_trap_snare = {
				name = "Snare",
				text = {
					"When your {X:purple,C:white}Nemesis{} skips a",
					"Blind, gain a copy of",
					"the Tag",
				},
			},
			c_mp_trap_symbol = {
				name = "Symbol",
				text = {
					"When your {X:purple,C:white}Nemesis{} plays a",
					"hand that contains a",
					"{C:attention}Flush{}, convert all scored",
					"cards to random suits",
				},
			},
			c_mp_trap_glyph_of_warding = {
				name = "Glyph of Warding",
				text = {
					"When your {X:purple,C:white}Nemesis{} uses a",
					"{C:attention}Spectral{} card, open a",
					"{C:attention}Jumbo{} Spectral pack",
				},
			},
			c_mp_trap_web = {
				name = "Web",
				text = {
					"When your {X:purple,C:white}Nemesis{} uses a",
					"consumable, gain a",
					"{C:attention}Negative{} copy of it",
				},
			},
		},
	},
	misc = {
		labels = {
			mp_sticker_balanced = "Balanced",
			mp_sticker_extra_credit = "Extra Credit",
			mp_sticker_persistent = "Persistent",
			mp_sticker_unreliable = "Unreliable",
			mp_sticker_draining = "Draining",
		},
		dictionary = {
			-- Find Game (ui/main_menu/find_game.lua)
			k_pvp_ranked = "Ranked",
			-- Pending death waiting screen (ui/game/pending_death.lua)
			k_pvp_pending_death_title = "OUT OF LIVES",
			k_pvp_pending_death_result = "Your result is pending.",
			k_pvp_pending_death_wait = "Your Nemesis must beat the same blind.",
			k_pvp_pending_death_wait_many = "The others must beat the same blind.",
			k_pvp_pending_death_leave = "Leaving is not a forfeit. The result still counts.",
			k_pvp_pending_death_survivor = "Opponent lost their last life to the blind, finish this blind to end the game!",
			-- Forfeit or Contest modal (ui/contest_modal.lua)
			k_pvp_contest_title = "Forfeit or Contest match?",
			k_pvp_contest_pick_title = "Contest which player?",
			k_pvp_contest_pick_text = "Pick the player who breaks the rules or stalls.",
			k_pvp_contest_warn_1 = "Contest only if your opponent is breaking the rules on purpose or stalling.",
			k_pvp_contest_warn_2 = "A moderator will review the match.",
			k_pvp_contest_warn_3 = "Contesting a fair match can result in punishment.",
			b_pvp_forfeit = "Forfeit",
			b_pvp_contest = "Contest",
			b_pvp_contest_cancel = "Cancel",
			k_pvp_contest_failed = "Could not contest the match. Try again.",
			k_pvp_contest_already = "This match is already contested.",
			k_pvp_contest_over = "The match is over. It can no longer be contested.",
			k_pvp_contest_old_server = "This server does not support contests yet.",
			k_pvp_contested_title = "MATCH CONTESTED",
			k_pvp_contested_text_1 = "A moderator will review this match.",
			k_pvp_contested_text_2 = "No win or loss is recorded and your rating does not change.",
			-- Setup votes (pvp_api/setup.lua)
			k_pvp_setup_title_ruleset = "Vote: Ruleset",
			k_pvp_setup_title_traps = "Vote: Trap Cards",
			k_pvp_setup_traps_on = "Traps On",
			k_pvp_setup_traps_off = "Traps Off",
			k_pvp_setup_your_vote = "Your turn: vote",
			k_pvp_setup_vote_sent = "Vote sent. Waiting for the vote to close...",
			k_pvp_setup_your_vote_tag = "Your vote",
			k_pvp_setup_confirm_vote = "Confirm Vote",
			k_pvp_setup_waiting = "Setting up the game...",
			k_pvp_lobby_trap_cards = "Trap Cards",
			k_trap_pack = "Trap Pack",
			b_singleplayer = "Singleplayer",
			b_sp_with_ruleset = "Practice Mode",
			b_practice = "Practice",
			k_unlimited_slots = "Unlimited Slots",
			k_edition_cycling = "Edition Cycling (Q)",
			k_practice_options = "Practice Options...",
			b_join_lobby = "Join Lobby",
			b_join_lobby_clipboard = "Join From Clipboard",
			b_return_lobby = "Return to Lobby",
			b_reconnect = "Reconnect",
			b_create_lobby = "Create Lobby",
			b_start_lobby = "Start Lobby",
			b_ready = "Ready",
			b_unready = "Unready",
			b_leave_lobby = "Leave Lobby",
			b_mp_discord = "Balatro Multiplayer Discord Server",
			b_start = "START",
			b_wait_for_host_start = {
				"WAITING FOR",
				"HOST TO START",
			},
			b_wait_for_players = {
				"WAITING FOR",
				"PLAYERS",
			},
			b_wait_for_guest_ready = {
				"WAITING FOR",
				"GUEST TO READY UP",
			},
			b_lobby_options = "LOBBY OPTIONS",
			b_copy_clipboard = "Copy to clipboard",
			b_view_code = "VIEW CODE",
			b_copy_code = "COPY CODE",
			b_leave = "LEAVE",
			b_opts_cb_money = "Give comeback $ on life loss",
			b_opts_no_gold_on_loss = "Don't get blind rewards on round loss",
			b_opts_death_on_loss = "Lose a life on non-PvP round loss",
			b_opts_start_antes = "Starting Antes",
			b_opts_diff_seeds = "Players have different seeds",
			b_opts_lives = "Lives",
			b_opts_multiplayer_jokers = "Enable Multiplayer Cards",
			b_opts_player_diff_deck = "Players have different decks",
			b_opts_random_loadout = "Randomize deck & stake",
			b_opts_normal_bosses = "Enable Boss Blind effects",
			b_opts_hide_score = "Hide opponent score until you play",
			b_opts_timer = "Enable Timer",
			b_opts_disable_preview = "Disable Score Preview",
			b_opts_the_order = "Enable The Order",
			b_opts_legacy_smallworld = "Legacy Small World mechanics",
			b_reset = "Reset",
			b_set_custom_seed = "Set Custom Seed",
			b_opts_modifier_smallworld = "Small World",
			b_mp_kofi_button = "Supporting me on Ko-fi",
			b_unstuck = "Unstuck",
			b_unstuck_blind = "Stuck Outside PvP",
			b_misprint_display = "Display the next card in the deck",
			b_players = "Players",
			b_lobby_info = "Lobby Info",
			b_continue_singleplayer = "Continue in Singleplayer",
			b_the_order_integration = "Enable The Order Integration",
			b_preview_integration = "Enable Score Preview",
			b_skip_tutorial = "Skip Tutorial",
			k_yes = "Yes",
			k_no = "No",
			k_are_you_sure = "Are you sure?",
			k_has_multiplayer_content = "Has Multiplayer Content",
			k_forces_lobby_options = "Forces Lobby Options",
			k_forces_gamemode = "Forces Gamemode",
			k_may_roll_stickers = "May Roll Stickers",
			k_values_are_modifiable = "* Values are modifiable",
			k_rulesets = "Rulesets",
			k_gamemodes = "Gamemodes",
			k_matchmaking = "Matchmaking",
			k_tournament = "Tournament",
			k_custom = "Custom",
			k_other = "Other",
			k_battle = "Battle",
			k_challenge = "Challenge",
			k_info = "Info",
			k_continue_singleplayer_tooltip = "This will overwrite your current singleplayer run",
			k_enemy_score = "Current Enemy score",
			k_enemy_hands = "Enemy hands left: ",
			k_royale_beat = "Beat:",
			k_royale_leading = "Leading:",
			-- The PvP boss's name for a player with no nemesis this ante.
			k_bye = "Bye",
			k_coming_soon = "Coming Soon!",
			k_wait_enemy = "Waiting for enemy to finish...",
			k_pvp_sync_failed = "Round sync unconfirmed. Reconnect to retry.",
			k_lives = "Lives",
			k_skips = "Skips",
			k_lost_life = "Lost a life",
			k_total_lives_lost = " Total Lives Lost",
			k_comeback_money_sandbox = " Comeback Money ($3 × ante cleared)",
			k_attrition_name = "Attrition",
			k_enter_lobby_code = "Enter Lobby Code",
			k_paste = "Paste From Clipboard",
			k_username = "Username:",
			k_enter_username = "Enter username",
			k_customize_preview = "Customize Preview Text:",
			k_join_discord = "Join the ",
			k_discord_msg = "You can report any bugs and find players to play there",
			k_enter_to_save = "Press enter to save",
			k_in_lobby = "In the lobby",
			k_connected = "Connected to Service",
			k_warn_service = "WARN: Cannot Find Multiplayer Service",
			k_set_name = "Set your username in the main menu! (Mods > Multiplayer > Config)",
			k_mod_hash_warning = "Players have different mods or mod versions! This can cause problems!",
			k_steamodded_warning = "Players have different versions of Steamodded installed. This may cause the seeds to differ.",
			k_mp_version_warning = "Players are on different Multiplayer versions! Seeds and jokers will desync - update so you both match.",
			k_warning_unlock_profile = "The profile you are playing on is not fully unlocked. If this is a ranked/tournament game, please create a new profile and hit unlock all in the profile settings",
			k_warning_nemesis_unlock = "Your opponent is playing on a profile that is not fully unlocked. Please instruct them to create a new profile and hit unlock all in the profile settings",
			k_warning_no_order = "One player has The Order integration enabled while the other does not. This will cause the seeds to differ.",
			k_warning_cheating1 = "If you are seeing this, your opponent may be cheating.",
			k_warning_cheating2 = "If this is a ranked game, please send the message '%s' and then open a support ticket in #support",
			k_warning_banned_mods = "One or more players have banned mods installed. These mods are not allowed in ranked games.",
			k_message1 = "Hold on, my mom made pizza pops",
			k_message2 = "One sec, i gotta grab my slow cooker pork roast",
			k_message3 = "One moment, getting a call from my mom",
			k_message4 = "Brb, my cat is on fire",
			k_message5 = "Wait, I think I left the stove on",
			k_message6 = "Hold up, my pet rock just ran away",
			k_message7 = "One sec, my plants are asking for water",
			k_message8 = "Brb, my socks are plotting against me",
			k_message9 = "Sorry, my WiFi is having an existential crisis",
			k_lobby_options = "Lobby Options",
			k_connect_player = "Connected Players:",
			k_opts_only_host = "Only the Lobby Host can change these options",
			k_lobby_general = "General",
			k_lobby_gameplay = "Gameplay",
			k_lobby_modifiers = "Modifiers",
			k_lobby_advanced = "Advanced",
			k_opts_pvp_start_round = "PVP Starts at Ante",
			k_opts_pvp_timer = "Timer",
			k_opts_pvp_timer_increment = "Timer Increment",
			k_opts_pvp_countdown_seconds = "PvP Countdown Seconds",
			k_opts_modifier_timer = "Timer Implementation",
            k_experimental_modifiers_timers = {
                "- Default: regular {C:chips}150{} {C:inactive}(1x){} seconds timer",
                " ",
                "- No Animations: {C:chips}100{} {C:inactive}(0.67x){} seconds timer {C:attention}minus animations{}",
                " ",
                "- Pressure: {C:chips}300{} {C:inactive}(2x){} seconds timer {C:attention}minus animations{}",
                "  which starts {C:attention}immediately{}",
                " ",
                "- Pressure+: Same as {C:attention}Pressure{} plus {C:chips}15{} seconds per hand played",
            },
            b_opts_modifier_pvp_timer = "PvP Timer",
            k_experimental_modifiers_pvp_timer = {
                "- Timer which available during {C:mult}PvP{} rounds.",
                "  {C:chips}90{} seconds plus {C:chips}15{} seconds per hand played {C:attention}minus animations{}.",
                "  Can \"timer\" opponent only when you have {C:attention}higher{} score"
            },
            k_experimental_modifiers_smallworld = {
                "- {C:attention}75%{} of jokers, consumables, vouchers and tags",
                "  are randomly banned each game.",
                "- {C:attention}Showman{} effect always active.",
            },
			k_bl_life = "Life",
			k_bl_or = "or",
			k_bl_death = "Death",
			k_bl_mostchips = "Most chips wins",
			k_current_seed = "Current seed: ",
			k_random = "Random",
			k_standard = "Standard",
			k_sandbox = "Sandbox: Extra Credit",
			k_sandbox_description = "26 new jokers from Extra Credit join the roster.\nIdol splits into two: Zealot and Collector's. You pick one, the other's gone.\nNew Spectrals, reworked comeback gold, no score preview.\nThe meta's wide open. Built with friends at Balatro University.\n",
			k_vanilla = "Vanilla",
			k_vanilla_description = "The original Balatro experience.\n\nNo Multiplayer jokers, no balance changes.\nJust the base game as it was designed.\n\nMultiplayer features like the timer are still available\nbut can be disabled in Lobby Options.",
			k_mp_ruleset_expanded = "Expanded",
			k_mp_ruleset_expanded_description = "Balanced plus more reworks and Multiplayer cards.\n\nReworks Ticket, Seltzer, Turtle Bean and Ouija.\nAdds the Multiplayer jokers and decks.\nBans Speedrun, Conjoined and Defensive Joker.\n\n(See bans and reworks tabs for details)",
			k_experimental = "Experimental",
			k_traditional = "Traditional",
			k_traditional_description = "Multiplayer content without time pressure.\n\nIncludes Multiplayer jokers and balance changes,\nbut removes time-based mechanics for methodical play.\n\nTime-based jokers are banned.\nTimer is disabled.\n\n(See bans and reworks tabs for details)",
			k_majorleague = "Major League",
			k_majorleague_description = "Official Major League Balatro ruleset.\n\nVanilla cards with competitive settings:\n- 180+60 second timer, but it is hidden above 180\n- No Enemy Locations\n- The Order disabled except for Vouchers, Bloodstone, and The Idol\n- Attrition gamemode",
			k_minorleague = "Minor League",
			k_minorleague_description = "Official Minor League Balatro ruleset.\n\nVanilla cards with competitive settings:\n- 210 second timer\n- The Order enabled\n- First timeout forgiven\n- Attrition gamemode",
			k_wsob = "WSOB",
			k_wsob_description = "World Series of Balatro ruleset.\n\nNear-vanilla card pool with minimal balance changes:\n- Hanging Chad, Bloodstone, and Glass reworked\n- Justice banned\n- No Multiplayer-original content\n\n(See bans and reworks tabs for details)",
			k_mp_ruleset_balanced = "Balanced",
			k_mp_ruleset_balanced_description = "Near-vanilla Balatro with a few balance changes.\n\nReworks Hanging Chad, Bloodstone and Glass.\nJustice is banned.\nNo Multiplayer-original cards.\n\n(See bans and reworks tabs for details)",
			k_legacy_ranked = "Legacy Ranked",
			k_legacy_ranked_description = "A minimal competitive ruleset.\n\nNo Multiplayer cards or balance changes\nexcept Glass. Has locked settings:\n- Attrition gamemode\n- The Order enabled\n- Requires recommended Steamodded version",
			k_experimental_balanced = "Experimental (Balanced)",
			k_experimental_description = "Balanced's bleeding edge.\n\nHeavier balance changes being trialed\nfor a future Balanced ruleset.\n\n(See bans and reworks tabs for details)",
			k_experimental_legacy = "Experimental (Classic)",
			k_experimental_legacy_description = "An opinionated take on Legacy Ranked.\n\nGlass nerfed, Hanging Chad reworked, Justice banned,\nLet's Go Gambling.",
			k_badlatro = "Badlatro",
			k_badlatro_description = "A weekly ruleset designed by @dr_monty_the_snek on the discord server\nthat has been added to the mod permanently.\n\nThis ruleset bans 48 jokers, consumables, tags, etc.",
			k_attrition = "Attrition",
			k_weekly = "Weekly",
			k_weekly_description = "A special ruleset that changes weekly or bi-weekly. I guess you'll have to find out what it is! Currently: ",
			k_smallworld = "Small World",
			k_smallworld_description = "It's a small world after all.\n\n75% of jokers, consumables, vouchers, and tags\nare randomly banned each game.\n\nBanned items get replaced with what's available.\nDuplicates allowed.",
			k_speedlatro = "Speedlatro",
			k_speedlatro_description = "Up the pace with an uncomfortably fast 147 second timer between\neach PvP blind. Good luck using Vagabond",
			k_chaos = "Chaos",
			k_chaos_description = "Everything, everywhere, all at once.\n\nCombines Standard, Small World, Sandbox, and Speedlatro timer\ninto one ruleset. Good luck.",
			k_release = "Release Ver.",
			k_release_description = "Allan please add details",
			k_mp_ruleset_tab_general = "General",
			k_mp_ruleset_tab_tournaments = "Tournaments",
			k_mp_ruleset_tab_experimental = "Experimental",
			k_cost_up = "Cost Up",
			k_destabilized = "Destabilized",
			k_oops_ex = "Oops!",
			k_asteroids = "Asteroids",
			k_amount_short = "Amt.",
			k_filed_ex = "Filed!",
			k_timer = "Timer",
			k_mods_list = "Mods List",
			k_nemesis_deck = "Nemesis Deck",
			k_your_deck = "Your Deck",
			k_customization = "Customization",
			k_the_order_credit = "*Credit to @MathIsFun_",
			k_the_order_integration_desc = "This will patch card creation to not be ante-based and use a single pool for every type/rarity",
			k_preview_credit = "*Credit to @Fantom, @Divvy",
			k_preview_integration_desc = "This will enable score preview before playing a hand",
			k_requires_restart = "*Requires a restart to take effect",
			k_cocktail_select = "Select deck cards to include them",
			k_cocktail_shiftclick = "Shift-click to foil, foiled decks will always be selected",
			k_cocktail_rightclick = "Right-click to select all",
			k_bans = "Bans",
			k_reworks = "Reworks",
			k_edit = "Edit",
			k_ruleset_disabled_the_order_required = "The Order is Required",
			k_ruleset_disabled_the_order_banned = "The Order is Banned",
			k_ruleset_not_found = "Unknown ruleset",
			k_version_mismatch_refused = "Everyone in a game needs the same MultiplayerPvP version.\nUpdate the mod and try again.",
			k_tutorial_not_complete = "You must complete the tutorial before you can play Multiplayer",
			k_created_by = "Created by",
			k_major_contributors = "Major contributions by",
			ml_enemy_loc = {
				"Enemy",
				"location",
			},
			k_show_mp_content_anyway = "Show Multiplayer content anyway*",
			k_applies_singleplayer_vanilla_rulesets = "*Applies in singleplayer and vanilla rulesets",
			k_timer_sfx = "Timer Sound Effects",
			k_nemesis_layout = "Nemesis layout",
			ml_nemesis_layout_opt = {
				"Standard",
				"Mirrored",
				"Classic",
			},
			ml_mp_kofi_message = {
				"This game server is",
				"funded by the community,",
				"if you enjoy BMP",
				"consider",
			},
			ml_lobby_info = {
				"Lobby",
				"Info",
			},
			ml_mp_timersfx_opt = {
				"On",
				"Once per Ante",
				"Off",
			},
			ml_mp_modifier_timer_opt = {
				"Default",
				"No Animations",
				"Pressure",
				"Pressure+",
			},
			k_sc_title = "SHORTCUTS",
			k_sc_hint = "Press key or release TAB to close",
			b_sc_choose_deck = "Choose Deck/Stake",
			loc_ready = "Ready for PvP",
			loc_selecting = "Selecting",
			loc_shop = "Shopping before",
			loc_playing = "Playing",
		},
		v_dictionary = {
			k_start_refused = "Start refused: #1#",
			k_version_mismatch = "A player runs MultiplayerPvP #1#, you run #2#.\nEveryone in a game needs the same version.",
			k_pvp_contest_by = "#1# contested the match with another player.",
			k_pvp_placement_progress = "Placement: #1#/#2#",
			k_end_player_jokers = "#1#'s Jokers",
			k_end_player_left = "#1# -- left the match",
			k_end_player_playing = "#1# -- still playing...",
			a_mp_art = {
				"Art: #1#",
			},
			a_mp_code = {
				"Code: #1#",
			},
			a_mp_idea = {
				"Idea: #1#",
			},
			a_mp_skips_ahead = {
				"#1# Skips Ahead",
			},
			a_mp_skips_behind = {
				"#1# Skips Behind",
			},
			a_mp_skips_tied = {
				"Tied",
			},
			k_banned_objs = "Banned #1#",
			k_no_banned_objs = "No Banned #1#",
			k_reworked_objs = "Reworked #1#",
			k_no_reworked_objs = "No Reworked #1#",
			k_ruleset_disabled_smods_version = "Needs Steamodded #1# or newer",
			k_ruleset_disabled_lovely_version = "Needs Lovely #1# or newer",
			k_failed_to_join_lobby = "Failed to join lobby: #1#",
			k_ante_number = "Ante #1#",
			k_ante_min = "Ante #1#+", -- For example, "Ante 2+"
			k_credits_list = "#1# and many more!", -- #1# gets replaced with a list of names
		},
		v_text = {
			ch_c_hanging_chad_rework = {
				"{C:attention}Hanging Chad{} is {C:dark_edition}reworked",
			},
			ch_c_glass_cards_rework = {
				"{C:attention}Glass Cards{} are {C:dark_edition}reworked",
			},
			ch_c_mp_score_instability = {
				"Unbalanced score is {C:purple}destabilized{} further:",
			},
			ch_c_mp_score_instability_EXAMPLE = {
				"  {C:inactive}(ex: {C:chips}30{C:inactive}x{C:mult}24{C:inactive} -> {C:chips}36{C:inactive}x{C:mult}18{C:inactive})",
			},
			ch_c_mp_score_instability_LOC1 = {
				"  {C:inactive}Minimum of {C:attention}1 {C:mult}Mult",
			},
			ch_c_mp_score_instability_LOC2 = {
				"  {C:inactive}Minimum of {C:attention}0 {C:chips}Chips",
			},
			ch_c_mp_ante_scaling = {
				"{C:red}X#1#{} base Blind size",
			},
			ch_c_mp_no_shop_planets = {
				"{C:planet}Planets{} no longer appear in the {C:attention}shop",
			},
			ch_c_mp_only_medium = {
				"All {C:spectral}Spectral{} cards are {C:spectral}Mediums{}",
			},
			ch_c_mp_only_purple_seals = {
				"All {C:attention}seals{} are {C:purple}Purple Seals{}",
			},
			ch_c_mp_sibyl_CREDITS = {
				"{C:inactive}(Art by {C:attention}Ganpan14O{C:inactive})",
			},
			ch_c_mp_polymorph_spam = {
				"On selecting blind, all held {C:attention}Jokers{} and {C:attention}Consumables{}",
			},
			ch_c_mp_polymorph_spam_EXTENDED1 = {
				"are transmuted into the {C:attention}N{}th next card in their collection,",
			},
			ch_c_mp_polymorph_spam_EXTENDED2 = {
				"where {C:attention}N{} is its current position in slots",
			},
			ch_c_mp_vantablack_CREDITS = {
				"{C:inactive}(Art by {C:attention}aura!{C:inactive})",
			},
			ch_c_mp_indigo = {
				"Played on {C:attention}Indigo Deck{}",
			},
			ch_c_mp_shop_planets = {
				"{C:planet}Planet{} cards appear",
			},
			ch_c_mp_shop_planets_EXTENDED = {
				"{C:attention}40X{} more frequently in the shop",
			},
			ch_c_mp_planet_tycoon_CREDITS = {
				"{C:inactive}(Idea by {C:attention}BlockAttack{C:inactive})",
			},
			ch_c_mp_eeeee = {
				"Some randomly selected RNG queues are {C:attention}bugged{} each Ante",
			},
			ch_c_mp_shared_pockets = {
				"{C:attention}Hand size{}, {C:attention}Joker Slots{}, and {C:attention}Consumable Slots{} are shared",
			},
		},
		challenge_names = {
			c_mp_standard = "Standard",
			c_mp_sandbox = "Sandbox",
			c_mp_badlatro = "Badlatro",
			c_mp_tournament = "Tournament",
			c_mp_weekly = "Weekly",
			c_mp_vanilla = "Vanilla",
			c_mp_misprint_deck = "Misprint Deck",
			c_mp_legendaries = "Legendaries",
			c_mp_psychosis = "Psychosis",
			c_mp_scratch = "From Scratch",
			c_mp_twin_towers = "Twin Towers",
			c_mp_in_the_red = "In the Red",
			c_mp_paper_money = "Paper Money",
			c_mp_high_hand = "High Hand",
			c_mp_chore_list = "Chore List",
			c_mp_oops_all_jokers = "Oops! All Jokers",
			c_mp_divination = "Divination",
			c_mp_skip_off = "Skip-Off",
			c_mp_lets_go_gambling = "Let's Go Gambling",
			c_mp_speed = "Speed",
			c_mp_balancing_act = "Balancing Act",
			c_mp_salvaged_sibyl = "Salvaged Sibyl",
			c_mp_polymorph_spam = "Polymorph Spam",
			c_mp_all_must_go = "All Must Go",
			c_mp_vantablack = "Vantablack",
			c_mp_planet_tycoon = "Planet Tycoon",
			c_mp_bacon = "Blue Ice",
			c_mp_eeeee = "EEEEE",
			c_mp_shared_pockets = "Shared Pockets",
		},
	},
}
