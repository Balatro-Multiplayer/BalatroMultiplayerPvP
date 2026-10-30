-- Localization by @themike_71
-- Corrections and further updates by ElTioRata
return {
	descriptions = {
		Tag = {
			tag_mp_gambling_sandbox = {
				name = "Etiqueta de apostador",
				text = {
					"Prob. de {C:green}#1# en #2#{} de que",
					"la tienda tenga un",
					"{C:red}Comodín raro{} gratis",
				},
			},
			tag_mp_juggle_sandbox = {
				name = "Etiqueta de malabares",
				text = {
					"{C:attention}+#1#{} tamaño de mano",
					"en la siguiente {C:attention}Ciega JcJ{}",
				},
			},
			tag_mp_investment_sandbox = {
				name = "Etiqueta de inversión",
				text = {
					"Después de derrotar",
					"la Ciega Jefe, gana:",
					"{C:money}$#1#{} + {C:money}$#2#{} por apuesta",
					"{C:inactive}(Actualmente {C:money}$#3#{C:inactive})",
				},
			},
		},
		Joker = {
			j_broken = {
				name = "ERROR :(",
				text = {
					"Esta carta está rota o no está",
					"implementada en la versión actual",
					"de un mod que estás usando.",
				},
			},
			j_to_the_moon = {
				name = "A la Luna",
				text = {
					"Gana {C:money}$#1#{} extra de",
					"{C:attention}interés{} por cada {C:money}$#2#{} que",
					"tengas al final de la ronda",
				},
			},
			j_mp_defensive_joker = {
				name = "Comodín defensivo", -- themike_71: Personalmente prefiero "Jokers" antes que "Comodines" pero tomaré de base la traducción oficial de Balatro -- Marffe: la verdad me gusta más Comodín
				text = {
					"{C:chips}+#1#{} fichas por cada {C:red,E:1}vida{}",
					"menos que tu {X:purple,C:white}némesis{}",
					"{C:inactive}(Actualmente {C:chips}+#2#{C:inactive} fichas)",
				},
			},
			j_mp_skip_off = {
				name = "Avioncito", -- themike_71: "Skip-Off" a traducción literal sería "Saltalo"/"Saltado" pero lo cambié acorde al arte de la carta ya que pierde un poco el juego de palabras. | ElTioRata: Skip-Off proviene de "Take-Off" ("despegue", por eso el avión).
				text = {
					"{C:blue}+#1#{} manos y {C:red}+#2#{} descartes",
					"por {C:attention}ciega{} adicional omitida",
					"en comparación con tu {X:purple,C:white}némesis{}",
					"{C:inactive}(Actualmente {C:blue}+#3#{C:inactive}/{C:red}+#4#{C:inactive}, #5#)",
				},
			},
			j_mp_lets_go_gambling = {
				name = "Let's Go Gambling", -- themike_71: La traducción sería "Vamos a apostar" pero lo dejareos así para mantener el meme
				text = {
					"Prob. de {C:green}#1# en #2#{} de",
					"otorgar {X:mult,C:white}X#3#{} multi y {C:money}#4# ${}", -- ElTioRata: Signo de dólar a la derecha para mantener consistencia con localización del juego base
					"Prob. de {C:green}#5# en #6#{} de dar",
					"{C:money}#7# $ a tu {X:purple,C:white}némesis{}",
				},
			},
			j_mp_speedrun = {
				name = "Contrarreloj", -- ElTioRata: Sé que el término queda más largo pero así suelen ponerlo en traducciones oficiales -- Marffe: La RAE sugiera Contrarreloj para este contexto
				text = {
					"Si llegas a la {C:attention}ciega JcJ",
					"antes que tu {X:purple,C:white}némesis{},",
					"crea un carta {C:spectral}espectral{}",
					"{C:inactive}(Debe haber espacio)",
				},
			},
			j_mp_conjoined_joker = {
				name = "Comodín siamés",
				text = {
					"Mientras estés en una {C:attention}ciega JcJ{},",
					"ganas {X:mult,C:white}X#1#{} multi por cada {C:blue}mano{}",
					"que tenga tu {X:purple,C:white}némesis{}",
					"{C:inactive,s:0.8}(Máximo {X:mult,C:white}X#2#{C:inactive,s:0.8} multi, actualmente {X:mult,C:white,s:0.8}X#3#{C:inactive,s:0.8} multi)",
				},
			},
			j_mp_penny_pincher = {
				name = "Tacaño",
				text = {
					"Al inicio de cada tienda, gana",
					"{C:money}#1# ${} por cada {C:money}#2# ${} que gastó",
					"tu {X:purple,C:white}némesis{} en la última tienda",
				},
			},
			j_mp_taxes = {
				name = "Impuestos", -- themike_71: Pensaba poner SAT pero me aguanté las ganas
				text = {
					"Cuando tu {X:purple,C:white}némesis{} vende",
					"una carta ganas {C:mult}+#1#{} multi",
					"{C:inactive}(Actualmente {C:mult}+#2#{C:inactive} multi)",
				},
			},
			j_mp_magnet = {
				name = "Imán",
				text = {
					"Después de {C:attention}#1#{} rondas,",
					"vende esta carta para {C:attention}copiar{}",
					"el {C:attention}comodín{} con mayor valor de venta",
					"que tenga tu {X:purple,C:white}némesis{}",
					"{C:inactive}(Actualmente {C:attention}#2#{C:inactive}/#3# rondas)",
				},
			},
			j_mp_pizza = {
				name = "Pizza", -- themike_71: Sí, esta carta es una referencia a Breaking Bad
				text = {
					"{C:red}+#1#{} descartes para todos los jugadores",
					"{C:red}-#2#{} descarte cuando un jugador",
					"selecciona una ciega.",
					"Se consume cuando tu",
					"{X:purple,C:white}némesis{} omite una ciega",
				},
			},
			j_mp_pacifist = {
				name = "Comodín Pacifista", -- Marffe: Si veo la oportunidad de escribir comodín, lo hago xd
				text = {
					"{X:mult,C:white}X#1#{} multi mientras no",
					"estés en una {C:attention}ciega JcJ{}",
				},
			},
			j_mp_hanging_chad = {
				name = "Papel perforado",
				text = {
					"Reactiva la {C:attention}primera{} y {C:attention}segunda{}",
					"carta jugada al anotar",
					"{C:attention}#1#{} veces adicionales",
				},
			},
			j_mp_hanging_chad = {
				name = "Papel perforado",
				text = {
					"Reactiva la {C:attention}primera{} y {C:attention}segunda{}",
					"carta jugada al anotar",
					"{C:attention}#1#{} veces adicionales",
				},
			},
			j_mp_bloodstone = {
				name = "Heliotropo",
				text = {
					"Prob. de {C:green}#1# en #2#{} de que",
					"las cartas jugadas de",
					"{C:hearts}Corazones{} otorguen",
					"{X:mult,C:white} X#3# {} multi al anotar",
				},
			},
			j_mp_magnet_sandbox = {
				name = "Imán",
				text = {
					"Después de {C:attention}#1#{} rondas, vende",
					"esta carta para {C:attention}copiar{} el",
					"{C:attention}comodín{} con mayor valor de venta",
					"de tu {X:purple,C:white}némesis{}",
					"la polaridad se invierte tras {C:attention}#3#{} rondas",
					"VOLVIÉNDOSE CHATARRA INÚTIL!!!!",
					"{C:inactive}(Actualmente {C:attention}#2#{C:inactive}/#1# rondas)",
				},
			},
			j_mp_cloud_9_sandbox = {
				name = "La Novena Puerta",
				text = {
					"GRANJERO DE MONOCULTIVO NUMÉRICO",
					"convirtiendo tu BARAJA DIVERSA en",
					"UNA PLANTACIÓN DE NUEVES RENTABLE!!!!",
					"{C:inactive}Prob. de ({C:green}#1# en #2#{} {C:inactive}, actualmente {C:money}$#3#{}{C:inactive})",
				},
			},
			j_mp_lucky_cat_sandbox = {
				name = "Gato de la Suerte",
				text = {
					"OPERADOR DEL CICLO FORTUNA-A-FRAGILIDAD",
					"los gatos de la suerte se vuelven GATOS DE VIDRIO",
					"con PODER EXPONENCIAL!!!!",
					"{C:inactive}(Actualmente {X:mult,C:white} X#2# {C:inactive} multi)",
				},
			},
			j_mp_constellation_sandbox = {
				name = "Constelación",
				text = {
					"Trastorno de ansiedad por mantenimiento planetario",
					"DEBES ALIMENTAR EL TAMAGOCHI",
					"O SE MARCHITA!!!!",
					"{C:inactive}(Actualmente {X:mult,C:white} X#1# {C:inactive} multi)",
				},
			},
			j_mp_bloodstone_sandbox = {
				name = "Heliotropo",
				text = {
					"{V:1}SÍNDROME DE REGRESIÓN DE NOTAS DE PARCHE",
					"volviendo al TRAUMA DEL DÍA DE LANZAMIENTO",
					"por PICOS DE PODER {X:mult,C:white}X#3#{} NOSTÁLGICOS!!!!",
					"{C:inactive}({C:green}#1# en #2#{} {C:inactive}prob.)",
				},
			},
			j_mp_juggler_sandbox = {
				name = "Malabarista",
				text = {
					"PERFECCIONISTA DEL TAMAÑO DE MANO",
					"que debe mantener TODAS LAS CARTAS",
					"en el aire TODO EL TIEMPO!!!!",
					"{C:inactive}(Actualmente {C:attention}+#1#{C:inactive} tamaño de mano)",
				},
			},
			j_mp_mail_sandbox = {
				name = "Reembolso por correo",
				text = {
					"Gana {C:money}$#1#{} por cada",
					"{C:attention}#2#{} descartado",
					"{s:0.8}El valor nunca cambia",
				},
			},
			j_mp_hit_the_road_sandbox = { -- Nerf a Hit the Roas? xd
				name = "Al Camino",
				text = {
					"Este comodín gana {X:mult,C:white}X0.75{} multi",
					"por cada {C:attention}J{} descartada",
					"Las J descartadas se {C:attention}destruyen{}",
					"{C:inactive}(Actualmente {X:mult,C:white} X#2# {C:inactive} multi)",
				},
			},
			j_mp_misprint_sandbox = {
				name = "Mala Impresión",
				text = {
					"{V:1}#1#{} multi",
					"{C:attention}Valor revelado al comprar{}",
					"{C:green}Los errores de impresión se acumulan{}",
				},
			},
			j_mp_castle_sandbox = {
				name = "Castillo",
				text = {
					"Este comodín gana {C:chips}#3{} fichas",
					"por cada {V:1}#1#{} descartado",
					"El palo se fija al comprar",
					"{C:inactive}(Actualmente {C:chips}+#2#{C:inactive} fichas)",
				},
			},
			j_mp_runner_sandbox = {
				name = "Corredor",
				text = {
					"SUPREMACISTA DE CARTAS SECUENCIALES",
					"cree que TODAS las demás MANOS DE PÓKER",
					"son INFERIORES!!!!",
					"{C:inactive}(Hizo una tesis para demostrarlo){}",
					"{C:inactive}(Actualmente {C:chips}+#1#{C:inactive})",
				},
			},
			j_mp_order_sandbox = {
				name = "El Orden",
				text = {
					"{X:mult,C:white}X3{} multi si la mano jugada contiene una {C:attention}Escalera{}",
					"Gana {X:mult,C:white}X#1#{} multi por cada {C:attention}Escalera{} consecutiva",
					"Se reinicia al jugar cualquier otra mano",
					"{C:inactive}(Actualmente {X:mult,C:white}X#2#{C:inactive} multi)",
				},
			},
			j_mp_photograph_sandbox = {
				name = "Fotografía",
				text = {
					"FOTÓGRAFO DE UNA SOLA TOMA que consigue",
					"UN ENCUADRE PERFECTO POR MANO!!!!",
				},
			},
			j_mp_ride_the_bus_sandbox = {
				name = "Ride the Bus",
				text = {
					"PROGRAMA DE SOBRIEDAD DE FIGURAS",
					"UNA FIGURA y te",
					"BAJAN DEL CAMIÓN!!!!",
					"{C:inactive}(Actualmente {C:mult}+#1#{C:inactive} multi)",
				},
			},
			j_mp_loyalty_card_sandbox = {
				name = "Tarjeta de lealtad",
				text = {
					"{X:mult,C:white}X6{} multi cada {C:attention}#3#{}",
					"manos jugadas de {C:attention}#1#{}",
					"{C:inactive}(#2#/#3#)",
				},
			},
			j_mp_faceless_sandbox = {
				name = "Comodín sin rostro",
				text = {
					"SOMMELIER ÉLITE DE FIGURAS",
					"que prepara muestras artesanales",
					"DE TRES VARIEDADES",
					"para DESCARTES PREMIUM!!!!",
				},
			},
			j_mp_square_sandbox = {
				name = "Comodín cuadrado",
				text = {
					"Este comodín gana {C:chips}+#2#{} fichas",
					"si la mano jugada tiene",
					"exactamente {C:attention}4{} cartas",
					"{C:attention}Solo aplica con manos de 4 cartas{}",
					"{C:inactive}(Actualmente {C:chips}+#1#{C:inactive} fichas)",
				},
			},
			j_mp_throwback_sandbox = {
				name = "Retro",
				text = {
					"{X:mult,C:white}X#2#{} multi base por cada",
					"{C:attention}Ciega{} omitida en esta partida",
					"{X:mult,C:white}X#3#{} multi en la siguiente ciega tras omitir",
					"Pierde {X:mult,C:white}X#4#{} si no se omite la ciega",
					"{C:inactive}(Actualmente {X:mult,C:white} X#1# {C:inactive} multi)",
				},
			},
			j_mp_vampire_sandbox = {
				name = "Vampiro",
				text = {
					"Este comodín gana {X:mult,C:white}X#1#{} multi",
					"por cada {C:attention}carta mejorada{} anotada",
					"Las cartas mejoradas jugadas se vuelven {C:attention}Piedra{}",
					"Las cartas de piedra dan {C:money}$#3#{} al jugarse",
					"{C:inactive}(Actualmente {X:mult,C:white} X#2# {C:inactive} multi)",
				},
			},
			j_mp_baseball_sandbox = {
				name = "Carta de béisbol",
				text = {
					"Los comodines {C:green}Inusuales{}",
					"otorgan {X:mult,C:white}X#1#{} multi",
				},
			},
			j_mp_steel_joker_sandbox = {
				name = "Comodín de acero",
				text = {
					"Las cartas de acero jugadas",
					"se {C:attention}reactivan{}",
				},
			},
			j_mp_satellite_sandbox = {
				name = "Satélite",
				text = {
					"ansiedad crónica por degradación de satélites",
					"LA INFRAESTRUCTURA SE DESMORONA",
					"SIN MEJORAS PLANETARIAS CONSTANTES!!!!",
					"{C:inactive}(Actualmente {C:money}$#1#{C:inactive})",
				},
			},
			j_mp_idol_sandbox_zealot = {
				name = "Ídolo fanático",
				text = {
					"Cada {C:attention}#1#{} jugada",
					"da {X:mult,C:white}X#2#{} multi",
					"al anotar",
					"{s:0.8}La carta cambia cada ronda",
				},
			},
			j_mp_idol_sandbox_collector = {
				name = "Ídolo meta",
				text = {
					"La carta más común da",
					"{X:mult,C:white}X#3#{} Multi al anotar",
					"({X:mult,C:white}+X#4#{} por copia en la baraja)",
					"{C:inactive}(Actualmente {C:attention}#1#{} de {V:1}#2#{})",
				},
			},
			j_mp_error_sandbox = {
				name = "????",
				text = {
					"{X:purple,C:white,s:0.85}algo{} {X:purple,C:white,s:0.85}anda{} {X:purple,C:white,s:0.85}mal{}",
				},
			},
		},
		Planet = {
			c_mp_asteroid = {
				name = "Asteroide",
				text = {
					"Disminuye #1# nivel de la",
					"{C:legendary,E:1}mano de póker{}",
					"con mayor nivel",
					"de tu {X:purple,C:white}némesis{}",
				},
			},
		},
		Blind = {
			bl_mp_nemesis = {
				name = "Tu némesis",
				text = {
					"Tú contra tu propio némesis,",
					"quien tenga más fichas gana",
				},
			},
		},
		Back = {
			b_mp_cocktail = {
				name = "Baraja Cóctel",
				text = {
					"Copia todos los",
					"efectosde {C:attention}3{} barajas",
					"al azar",
				},
			},
			b_mp_gradient = {
				name = "Baraja Gradiente",
				text = {
					"Las cartas también cuentan como",
					"la categoría {C:attention}mayor{} o {C:attention}menor{}",
					"para todos los efectos de {C:attention}comodines{}",
				},
			},
			b_mp_heidelberg = {
				name = "Baraja de Heidelberg",
				text = {
					"Crea una copia {C:dark_edition}negativa{} de",
					"{C:attention}1 consumible{} al azar",
					"que tengas al final de la",
					"{C:attention}tienda{}",
				},
			},
			b_mp_indigo = {
				name = "Baraja Índigo",
				text = {
					"Elige {C:attention}+1{} carta adicional",
					"en todos los paquetes potenciadores",
					"Los paquetes potenciadores",
					"no se pueden {C:attention}omitir{}",
				},
			},
			b_mp_oracle = {
				name = "Baraja del Oráculo",
				text = {
					"Comienzas con {C:spectral,T:c_medium}Medium",
					"y {C:attention,T:v_clearance_sale}Liquidación",
					"Sólo puedes tener hasta {C:money}$50{}",
					"+ {C:money}límite de interés{}",
				},
			},
			b_mp_orange = {
				name = "Baraja Naranja",
				text = {
					"Comienzas con un",
					"{C:attention,T:p_mp_standard_giga}Giga Paquete Estándar{}, y",
					"{C:attention}2{} copias de {C:tarot,T:c_hanged_man}El Colgado",
				},
			},
			b_mp_violet = {
				name = "Baraja Violeta",
				text = {
					"Hay {C:attention}1{} vale adicional",
					"Durante la {C:attention}primera{} apuesta,",
					"los vales cuestan {C:attention}50%{} menos",
				},
			},
			b_mp_white = {
				name = "Baraja Blanca",
				text = {
					"Puedes ver la baraja y los comodines",
					"actuales de tu {X:purple,C:white}némesis{}",
					"{C:inactive}(Se actualiza en la ciega JcJ){}",
				},
			},
		},
		Stake = {
			stake_mp_planet = {
				name = "Pozo Planetario",
				text = {
					"Aplica efectos de {C:black}Pozo Negro{}, más:",
					"La tienda puede tener comodines {C:attention}perecederos{}",
					"{C:inactive,s:0.8}(Se debilitan tras 5 rondas)",
					"La puntuación requerida escala",
					"más rápido por cada {C:attention}apuesta{}",
				},
			},
			stake_mp_spectral = {
				name = "Pozo Espectral",
				text = {
					"Aplica efectos de {C:planet}Pozo Planetario{}, más:",
					"Los comodines {C:money}de alquiler{} aparecen en la tienda",
					"La puntuación requerida escala",
					"más rápido por cada {C:attention}apuesta{}",
				},
			},
			stake_mp_spectralplus = {
				name = "Pozo Espectral+",
				text = {
					"Aplica efectos de {C:planet}Pozo Espectral{}, más:",
					"La puntuación requerida escala",
					"aún más rápido por cada {C:attention}apuesta{}",
				},
			},
			stake_mp_plastic = {
				name = "Pozo Plástico",
				text = {
					"Gana {C:money}$1{} de interés por cada {C:money}$10{}",
					"{C:inactive,s:0.8}(Máximo de {C:money,s:0.8}$50{C:inactive,s:0.8})",
					"{s:0.8}Aplica Apuesta Blanca",
				},
			},
			stake_mp_pebble = {
				name = "Pozo Guijarro",
				text = {
					"La puntuación requerida escala",
					"más rápido por cada {C:attention}apuesta{}",
					"{s:0.8}Aplica Apuesta Plástica",
				},
			},
			stake_mp_ferrite = {
				name = "Pozo Ferrita",
				text = {
					"Comodines específicos son {C:attention}Persistentes",
					"{C:inactive,s:0.8}(No se pueden destruir, aumenta el valor de venta)",
					"{s:0.8}Aplica Apuesta Guijarro",
				},
			},
			stake_mp_pyrite = {
				name = "Pozo Pirita",
				text = {
					"El precio de rebarajar aumenta",
					"en {C:money}$2{} con cada rebaraje",
					"{s:0.8}Aplica Apuesta Ferrita",
				},
			},
			stake_mp_jade = {
				name = "Pozo de Jade",
				text = {
					"La puntuación requerida escala",
					"más rápido por cada {C:attention}apuesta{}",
					"{s:0.8}Aplica Apuesta Pirita",
				},
			},
			stake_mp_crystal = {
				name = "Pozo de Cristal",
				text = {
					"Comodines específicos son {C:attention}Poco confiables",
					"{C:inactive,s:0.8}(No activan en la {C:attention,s:0.8}mano final{C:inactive,s:0.8})",
					"{s:0.8}Aplica Apuesta Jade",
				},
			},
			stake_mp_antimatter = {
				name = "Pozo Antimateria",
				text = {
					"Comodines específicos son {C:attention}Drenantes",
					"{C:inactive,s:0.8}({X:mult,C:white,s:0.8} X0.75 {C:inactive,s:0.8} multi)",
					"{s:0.8}Aplica Apuesta Cristal",
				},
			},
		},
		Spectral = {
			c_mp_ouija_standard = {
				name = "Ouija",
				text = {
					"Destruye {C:attention}#1#{} cartas al azar,",
					"luego convierte las restantes",
					"al mismo {C:attention}valor{} al azar",
				},
			},
			c_mp_ectoplasm_sandbox = {
				name = "Ectoplasma",
				text = {
					"Añade {C:dark_edition}Negativo{} a",
					"un {C:attention}comodín{} al azar,",
					"Aplica al azar uno de:",
					"{C:red}-1{} mano,",
					"{C:red}-1{} descarte,",
					"{C:red}-1{} tamaño de mano",
				},
			},
		},
		Other = {
			current_nemesis = {
				name = "Némesis",
				text = {
					"{X:purple,C:white}#1#{}",
					"Tu único e inigualable némesis",
				},
			},
			p_mp_standard_giga = {
				name = "Giga Paquete Estándar",
				text = {
					"Elige {C:attention}#1#{} de hasta",
					"{C:attention}#2#{C:attention} cartas{} para",
					"agregar a tu baraja",
					"{C:attention}No se puede omitir{}",
				},
			},
			mp_transmutations = {
				name = "Transmutaciones",
				text = {
					"{C:purple,s:1.1}Se transmutará en:",
				},
			},
			mp_internal_sell_value = {
				name = "Valor de venta",
				text = {
					"{C:money,s:1.3}$#1#",
				},
			},
			mp_sticker_persistent = {
				name = "Persistente",
				text = {
					"No se puede destruir",
					"Cuesta {C:red}${} vender",
					"El costo aumenta",
					"{C:red}$3{} al final de la ronda",
				},
			},
			mp_sticker_unreliable = {
				name = "Inconsistente",
				text = {
					"No se activa en",
					"la {C:attention}mano final{}",
				},
			},
			mp_sticker_draining = {
				name = "Drenante",
				text = {
					"{X:mult,C:white}X0.75{} multi",
				},
			},
		},
	},
	misc = {
		labels = {
			mp_sticker_persistent = "Persistente",
			mp_sticker_unreliable = "Inconsistente",
			mp_sticker_draining = "Drenante",
		},
		dictionary = {
			b_singleplayer = "Un jugador",
			b_join_lobby = "Unirse a sala",
			b_join_lobby_clipboard = "Unirse desde el portapapeles",
			b_return_lobby = "Volver a sala",
			b_reconnect = "Reconectar",
			b_create_lobby = "Crear sala",
			b_start_lobby = "Iniciar sala",
			b_ready = "Prepararse",
			b_unready = "Desprepararse", -- ElTioRata: Este término no está reconocido por la RAE pero tampoco existe un equivalente real de "Unready" así que queda como está.
			b_leave_lobby = "Abandonar sala",
			b_mp_discord = "Servidor de Discord del multijugador de Balatro",
			b_start = "INICIAR",
			b_wait_for_host_start = {
				"ESPERANDO AL",
				"ANFITRIÓN PARA INICIAR",
			},
			b_wait_for_players = {
				"ESPERANDO",
				"JUGADORES",
			},
			b_wait_for_guest_ready = {
				"ESPERANDO",
				"AL INVITADO",
			},
			b_lobby_options = "OPCIONES DE SALA",
			b_copy_clipboard = "Copiar al portapapeles",
			b_view_code = "VER CÓDIGO",
			b_copy_code = "COPIAR CÓDIGO",
			b_leave = "ABANDONAR",
			b_opts_cb_money = "Recibe $ al perder una vida",
			b_opts_no_gold_on_loss = "No obtener recompensa al perder una ronda",
			b_opts_death_on_loss = "Pierde una vida al perder en rondas no-JcJ",
			b_opts_start_antes = "Apuestas iniciales",
			b_opts_diff_seeds = "Los jugadores estan en semillas diferentes",
			b_opts_lives = "Vidas",
			b_opts_multiplayer_jokers = "Habilitar cartas de multijugador",
			b_opts_player_diff_deck = "Los jugadores tienen barajas diferentes",
			b_opts_normal_bosses = "Habilitar efectos de Ciega Jefe",
			b_opts_timer = "Habilitar temporizador",
			b_opts_disable_preview = "Deshabilitar previsualización de puntuación",
			b_opts_the_order = "Habilitar El Orden",
			b_opts_legacy_smallworld = "Mecánicas antiguas de Small World",
			b_reset = "Reiniciar",
			b_set_custom_seed = "Agregar semilla personalizada",
			b_mp_kofi_button = "Donar en Ko-fi",
			b_unstuck = "Desatascar", -- themike_71: No sé que quiere decir realmente "Unstuck", sé que es como "Desatascar/Destrabar" pero lo dejaré así por ahora
			b_unstuck_arcana = "Atascado en paquete potenciadores",
			b_unstuck_blind = "Atascado fuera de JcJ",
			b_misprint_display = "Muestra la siguiente carta de la baraja",
			b_players = "Jugadores",
			b_lobby_info = "Info de sala",
			b_continue_singleplayer = "Continuar partida individual",
			b_the_order_integration = "Habilitar integración con El Orden",
			b_preview_integration = "Habilitar previsualización de puntuación",
			b_view_nemesis_deck = "Ver barajas",
			b_toggle_jokers = "Alternar comodines",
			b_skip_tutorial = "Omitir tutorial",
			k_yes = "Sí",
			k_no = "No",
			k_are_you_sure = "¿Seguro?",
			k_has_multiplayer_content = "Tiene contenido multijugador",
			k_forces_lobby_options = "Forzar opciones de sala",
			k_forces_gamemode = "Forzar modo de juego",
			k_values_are_modifiable = "* Los valores son modificables",
			k_rulesets = "Reglas",
			k_gamemodes = "Modos de juego",
			k_competitive = "Competitivo",
			k_other = "Otro",
			k_battle = "Batalla",
			k_challenge = "Desafío",
			k_info = "Info",
			k_continue_singleplayer_tooltip = "Esto sobrescribirá tu partida individual actual",
			k_enemy_score = "Puntuación del Némesis:",
			k_enemy_hands = "Manos del Némesis: ", -- ElTioRata: Esta línea y la anterior se acortan para que el texto no quede tan finito -- Marffe ¿Porque no némesis?
			k_coming_soon = "¡Próximamente!",
			k_wait_enemy = "Esperando que termine tu némesis...",
			k_lives = "Vidas",
			k_lost_life = "-1 vida", -- themike_71: Realmente es "Perdió una vida", mucho texto, -1 tambien sirve creo yo
			k_total_lives_lost = " Vidas perdidas en total (4 $ c/u)",
			k_comeback_money_sandbox = " Dinero de remontada ($3 × apuesta superada)",
			k_attrition_name = "Atrición", -- ElTioRata: "Desgaste" sería más correcto pero es mejor dejar la palabra original para ser más preciso
			k_enter_lobby_code = "Agregar código de sala",
			k_paste = "Pegar desde portapapeles",
			k_username = "Nombre de usuario:",
			k_enter_username = "Agregar nombre de usuario",
			k_customize_preview = "Personalizar texto de previsualización:",
			k_join_discord = "Unirse al ",
			k_discord_msg = "Puedes reportar cualquier error y encontrar jugadores allí",
			k_enter_to_save = "Oprime ENTER para guardar",
			k_in_lobby = "En sala",
			k_connected = "Conectado al servidor",
			k_warn_service = "ADVERTENCIA: No se encontró el servidor multijugador",
			k_set_name = "¡Agrega tu usuario en el menú pricipal! (Mods > Multijugador > Configuración)",
			k_mod_hash_warning = "¡Los jugadores tienen diferentes mods o diferentes versiones de mods! ¡Esto puede causar problemas!",
			k_steamodded_warning = "Los jugadores tienen versiones diferentes de Steamodded instaladas. Esto puede causar que las semillas difieran.",
			k_warning_unlock_profile = "El perfil que estás usando no está completamente desbloqueado. Si es una partida con ranking/torneo, crea un perfil nuevo y usa 'Desbloquear todo' en ajustes del perfil.",
			k_warning_nemesis_unlock = "Tu oponente está jugando en un perfil que no está completamente desbloqueado. Pídele que cree un perfil nuevo y use 'Desbloquear todo' en ajustes del perfil.",
			k_warning_no_order = "Un jugador tiene habilitada la integración con La Orden y el otro no. Esto hará que las semillas difieran.",
			k_warning_cheating1 = "Si estás viendo esto, tu oponente podría estar haciendo trampa.",
			k_warning_cheating2 = "Si es una partida con ranking, envía el mensaje '%s' y abre un ticket de soporte en #support.",
			k_warning_banned_mods = "Uno o más jugadores tienen mods prohibidos instalados. No están permitidos en partidas con ranking.",
			k_message1 = "Espera, mi mamá hizo pizza",
			k_message2 = "Un segundo, tengo que agarrar mi estofado",
			k_message3 = "Un momento, me está llamando mi mamá",
			k_message4 = "Vuelvo, mi gato está en llamas",
			k_message5 = "Espera, creo que dejé la estufa encendida",
			k_message6 = "Aguanta, mi roca mascota se escapó",
			k_message7 = "Un segundo, mis plantas están pidiendo agua",
			k_message8 = "Vuelvo, mis calcetines están conspirando contra mí",
			k_message9 = "Perdón, mi WiFi está teniendo una crisis existencial",
			k_lobby_options = "Opciones de sala",
			k_connect_player = "Jugadores conectados:",
			k_opts_only_host = "Solo el anfitrión puede modificar estas opciones",
			k_lobby_general = "General",
			k_lobby_gameplay = "Jugabilidad",
			k_lobby_modifiers = "Modificadores",
			k_lobby_advanced = "Avanzado",
			k_opts_pvp_start_round = "JcJ empieza en apuesta",
			k_opts_pvp_timer = "Temporizador",
			k_opts_pvp_timer_increment = "Incremento del temporizador",
			k_opts_pvp_countdown_seconds = "Cuenta regresiva JcJ (segundos)",
			k_bl_life = "VIDA",
			k_bl_or = "o",
			k_bl_death = "MUERTE", -- ElTioRata: En mayúsculas tiene más gancho ;)
			k_bl_mostchips = "Gana quien tenga más fichas",
			k_current_seed = "Semilla actual: ",
			k_random = "Al azar",
			k_standard = "Estándar",
			k_standard_description = "Reglas del modo estándar, agrega cartas del multijugador y algunos cambios del juego base para adaptarse al meta del mod.",
			k_vanilla = "Vainilla",
			k_vanilla_description = "Reglas del modo vainilla, sin cartas del multijugador y no modifica nada del juego base.",
			k_weekly = "Semanal",
			k_weekly_description = "Reglas especiales que cambian semanal o quincenalmente. ¡Supongo que tendrás que descubrirlo por tu cuenta! Actualmente: ",
			k_tournament = "Torneo",
			k_tournament_description = "Reglas de torneo, igual que las reglas del modo estándar pero no se permite cambiar las opciones de sala.",
			k_badlatro = "Badlatro",
			k_badlatro_description = "Reglas semanales diseñadas por @dr_monty_the_snek en nuestro servidor de Discord que se agregaron de forma permanente.",
			k_mp_ruleset_expanded_description = "Este reglamento incluye cartas y funciones que fomentan jugar rápido y\nusar el tiempo como un recurso.\n\nAlgunas cartas están balanceadas aquí para ajustarse mejor al meta del multijugador:\n- Papel perforado está modificado\n- Justicia se elimina\n- Vidrio está modificado\n\n(Ver las pestañas de prohibiciones y ajustes para más info)",
			k_traditional = "Tradicional",
			k_traditional_description = "Este reglamento quita los aspectos del multijugador que usan el tiempo como recurso.\n\nPermite jugar con el contenido multijugador\nmientras mantienes una partida metódica.\n\nAlgunas cartas están balanceadas aquí para ajustarse mejor al meta del multijugador:\n- Papel perforado está modificado\n- Justicia se elimina\n- Vidrio está modificado\n\n(Ver las pestañas de prohibiciones y ajustes para más info)",
			k_majorleague = "Major League",
			k_majorleague_description = "Este es el reglamento oficial para Major League Balatro.\n\nEs igual al reglamento Vainilla con algunas excepciones:\n- La integración con La Orden está deshabilitada\n- El temporizador se fija en 180 segundos\n- La primera vez que el temporizador llegue a 0 no perderás una vida",
			k_minorleague = "Minor League",
			k_minorleague_description = "Este es el reglamento oficial para Minor League Balatro.\n\nEs igual al reglamento Vainilla con algunas excepciones:\n- La integración con La Orden está habilitada\n- El temporizador se fija en 180 segundos\n- La primera vez que el temporizador llegue a 0 no perderás una vida",
			k_ranked = "Ranked",
			k_ranked_description = "Este es el reglamento oficial para jugar Ranked Balatro Multiplayer.\n\nEs igual al reglamento Estándar con algunas excepciones:\n- La integración con La Orden está habilitada\n- Debes usar la versión recomendada de Steamodded",
			k_attrition = "Atrición",
			k_smallworld = "Small World",
			k_smallworld_description = "Un reglamento muy experimental, donde por alguna razón\nse prohíbe al azar 3/4 de todo lo del juego",
			k_speedlatro = "Speedlatro",
			k_speedlatro_description = "Sube el ritmo con un temporizador incómodamente rápido de 147 segundos entre\ncada ciega JcJ. Buena suerte usando Vagabond",
			k_cost_up = "Costo arriba",
			k_destabilized = "Desestabilizado",
			k_oops_ex = "¡Ups!",
			k_asteroids = "Asteroides",
			k_amount_short = "Cant.",
			k_filed_ex = "Archivado!",
			k_timer = "Temporizador",
			k_mods_list = "Lista de mods",
			k_enemy_jokers = "Comodínes del enemigo",
			k_your_jokers = "Tus comodines",
			k_nemesis_deck = "Baraja del némesis",
			k_your_deck = "Tu baraja",
			k_customization = "Personalización",
			k_the_order_credit = "*Créditos a @MathIsFun_",
			k_the_order_integration_desc = "Esto ajusta la creación de cartas para que no dependa de la apuesta y use un solo grupo para cada tipo/rareza",
			k_preview_credit = "*Créditos a @Fantom, @Divvy",
			k_preview_integration_desc = "Esto habilita la previsualización de puntuación antes de jugar una mano",
			k_requires_restart = "*Requiere reiniciar para aplicarse",
			k_cocktail_select = "Selecciona cartas de baraja para incluirlas",
			k_cocktail_shiftclick = "Shift-clic para poner foil; las barajas con foil siempre se seleccionan",
			k_cocktail_rightclick = "Clic derecho para seleccionar todas",
			k_bans = "Prohibiciones",
			k_reworks = "Ajustes",
			k_edit = "Editar",
			k_ruleset_disabled_the_order_required = "La Orden es requerida",
			k_ruleset_disabled_the_order_banned = "La Orden está prohibida",
			k_ruleset_not_found = "Reglamento desconocido",
			k_tutorial_not_complete = "Debes completar el tutorial antes de jugar Multijugador",
			k_created_by = "Creado por",
			k_major_contributors = "Con contribuciones principales de",
			k_show_mp_content_anyway = "Ocultar contenido multijugador*",
			k_applies_singleplayer_vanilla_rulesets = "*Aplica en modo individual y reglamentos vainilla",
			k_timer_sfx = "Efectos de sonido del temporizador",
			ml_enemy_loc = {
				"Enemigo",
				"ubicación",
			},
			ml_mp_kofi_message = {
				"Este mod y sus servidores son",
				"desarrollados y mantenidos por",
				"una sola persona, si te gusta",
				"puedes considerar",
			},
			ml_lobby_info = {
				"Sala",
				"Info",
			},
			ml_mp_timersfx_opt = {
				"Activado",
				"Una vez por apuesta",
				"Desactivado",
			},
			loc_ready = "Listo para JcJ",
			loc_selecting = "Seleccionando ciega",
			loc_shop = "En la tienda",
			loc_playing = "Jugando ",
		},
		v_dictionary = {
			a_mp_art = {
				"Arte: #1#",
			},
			a_mp_code = {
				"Código: #1#",
			},
			a_mp_idea = {
				"Idea: #1#",
			},
			a_mp_skips_ahead = {
				"#1# omisiones por delante",
			},
			a_mp_skips_behind = {
				"#1# omisiones por detrás",
			},
			a_mp_skips_tied = {
				"empatadas",
			},
			k_banned_objs = "#1# prohibidos",
			k_no_banned_objs = "Sin #1# prohibidos",
			k_reworked_objs = "#1# modificados",
			k_no_reworked_objs = "Sin #1# modificados",
			k_ruleset_disabled_smods_version = "Se requiere SMODS #1#",
			k_failed_to_join_lobby = "No se pudo unir a la sala: #1#",
			k_ante_number = "Apuesta #1#",
			k_ante_min = "Apuesta #1#+",
			k_credits_list = "#1# y muchos más!",
		},
		v_text = {
			ch_c_hanging_chad_rework = {
				"{C:attention}Papel perforado{} está {C:dark_edition}modificado",
			},
			ch_c_glass_cards_rework = {
				"{C:attention}Cartas de vidrio{} están {C:dark_edition}modificadas",
			},
			ch_c_mp_score_instability = {
				"La puntuación desbalanceada se {C:purple}desestabiliza{} más:",
			},
			ch_c_mp_score_instability_EXAMPLE = {
				"  {C:inactive}(ej: {C:chips}30{C:inactive}x{C:mult}24{C:inactive} -> {C:chips}36{C:inactive}x{C:mult}18{C:inactive})",
			},
			ch_c_mp_score_instability_LOC1 = {
				"  {C:inactive}Mínimo de {C:attention}1 {C:mult}Multi",
			},
			ch_c_mp_score_instability_LOC2 = {
				"  {C:inactive}Mínimo de {C:attention}0 {C:chips}Fichas",
			},
			ch_c_mp_ante_scaling = {
				"{C:red}X#1#{} tamaño base de la ciega",
			},
			ch_c_mp_no_shop_planets = {
				"Los {C:planet}Planetas{} ya no aparecen en la {C:attention}tienda",
			},
			ch_c_mp_only_medium = {
				"Todas las cartas {C:spectral}Espectrales{} son {C:spectral}Mediums{}",
			},
			ch_c_mp_only_purple_seals = {
				"Todos los {C:attention}sellos{} son {C:purple}Sellos Morados{}",
			},
			ch_c_mp_sibyl_CREDITS = {
				"{C:inactive}(Arte por {C:attention}Ganpan14O{C:inactive})",
			},
			ch_c_mp_polymorph_spam = {
				"Al seleccionar una ciega, todos los {C:attention}comodines{} y {C:attention}consumibles{}",
			},
			ch_c_mp_polymorph_spam_EXTENDED1 = {
				"se transmutan a la {C:attention}N{}-ésima carta siguiente en su colección,",
			},
			ch_c_mp_polymorph_spam_EXTENDED2 = {
				"donde {C:attention}N{} es su posición actual en los espacios",
			},
		},
		challenge_names = {
			c_mp_standard = "Estándar",
			c_mp_sandbox = "Sandbox",
			c_mp_badlatro = "Badlatro",
			c_mp_tournament = "Torneo",
			c_mp_weekly = "Semanal",
			c_mp_vanilla = "Vainilla",
			c_mp_misprint_deck = "Baraja mal impresa",
			c_mp_legendaries = "Legendarios",
			c_mp_psychosis = "Psicosis",
			c_mp_scratch = "Desde cero",
			c_mp_twin_towers = "Torres gemelas",
			c_mp_in_the_red = "Con déficit",
			c_mp_paper_money = "Papel moneda",
			c_mp_high_hand = "Mano más alta",
			c_mp_chore_list = "Lista de pendientes",
			c_mp_oops_all_jokers = "Solo comodínes", -- ElTioRata: "Oops! All 6s" se localizó como "Todos séises", saco el "¡Ups!" por consistencia aunque la referencia al cereal se pierda.
			c_mp_divination = "Divinidad",
			c_mp_skip_off = "Avioncito",
			c_mp_lets_go_gambling = "Let's Go Gambling",
			c_mp_speed = "Velocidad",
			c_mp_balancing_act = "Acto de equilibrio",
			c_mp_salvaged_sibyl = "Sibila rescatada",
			c_mp_polymorph_spam = "Spam de polimorfismo",
			c_mp_all_must_go = "Todo debe irse",
		},
	},
}
