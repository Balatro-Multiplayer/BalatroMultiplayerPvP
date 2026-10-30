-- Localization by @astryder75, @KilledByLava, @FaLNioNe, @sidmeierscivilizationv, @karta_wada, @amnesiaof
return {
	descriptions = {
		Tag = {
			tag_mp_gambling_sandbox = {
				name = "Азартный тег",
				text = {
					"Шанс {C:green}#1# из #2#{}",
					"В магазине бесплатный",
					"{C:red}Редкий Джокер{}",
				},
			},
			tag_mp_juggle_sandbox = {
				name = "Жонглёрский тег",
				text = {
					"{C:attention}+#1#{} размер руки",
					"в следующем {C:attention}PvP блайнде",
				},
			},
			tag_mp_investment_sandbox = {
				name = "Инвестиционный тег",
				text = {
					"После победы над",
					"босс-блайндом, получите:",
					"{C:money}$#1#{} + {C:money}$#2#{} за Анте",
					"{C:inactive}(Сейчас {C:money}$#3#{C:inactive})",
				},
			},
			tag_mp_uncommon_release = {
				name = "Необычный тег",
				text = {
					"В магазине есть",
					"{C:green}Необычный Джокер{}",
				},
			},
			tag_mp_rare_release = {
				name = "Редкий тег",
				text = {
					"В магазине есть",
					"{C:red}Редкий Джокер{}",
				},
			},
			tag_mp_foil_release = {
				name = "Фольгированный тег",
				text = {
					"Следующий базовый",
					"джокер в магазине станет {C:dark_edition}Фольгированным{}",
				},
			},
			tag_mp_holo_release = {
				name = "Голографический тег",
				text = {
					"Следующий базовый",
					"джокер в магазине станет {C:dark_edition}Голографическим",
				},
			},
			tag_mp_poly_release = {
				name = "Полихромный тег",
				text = {
					"Следующий базовый",
					"джокер в магазине станет {C:dark_edition}Полихромным",
				},
			},
			tag_mp_negative_release = {
				name = "Негативный тег",
				text = {
					"Следующий базовый",
					"джокер в магазине станет {C:dark_edition}Негативным",
				},
			},
		},
		Joker = {
			j_mp_seltzer = {
				name = "Сельтерская",
				text = {
					"Повторно активирует все",
					"сыгранные карты",
					"в течение следующих {C:attention}#1#{} рук",
				},
			},
			j_mp_turtle_bean = {
				name = "Черепашья фасоль",
				text = {
					"{C:attention}+#1#{} размер руки,",
					"уменьшается на",
					"{C:red}#2#{} каждый раунд",
				},
			},
			j_mp_idol = {
				name = "Идол",
				text = {
					"Каждая сыгранная {C:attention}#2#",
					"{V:1}#3#{} даёт",
					"{X:mult,C:white} X#1# {} множ. при подсчёте",
					"{s:0.8}Карта меняется каждый раунд",
				},
			},
			j_mp_idol_rare = {
				name = "Идол",
				text = {
					"Каждая сыгранная {C:attention}#2#",
					"{V:1}#3#{} даёт",
					"{X:mult,C:white} X#1# {} множ. при подсчёте",
					"{s:0.8}Карта меняется каждый раунд",
				},
			},
			j_mp_ticket = {
				name = "Золотой билет",
				text = {
					"Сыгранные {C:attention}Золотые{} карты",
					"дают {C:money}$#1#{} при подсчёте",
				},
			},
			j_mp_ticket_experimental = {
				name = "Золотой билет",
				text = {
					"Сыгранные {C:attention}Золотые{} карты",
					"дают {C:money}$#1#{} при подсчёте",
				},
			},
			j_mp_baron = {
				name = "Барон",
				text = {
					"Каждый {C:attention}Король{} в руке",
					"даёт {X:mult,C:white} X#1# {} множ.",
				},
			},
			j_mp_mime = {
				name = "Мим",
				text = {
					"Повторно активирует все",
					"способности карт {C:attention}в руке{}",
				},
			},
			j_mp_todo_list = {
				name = "Список дел",
				text = {
					"Заработайте {C:money}$#1#{}, если {C:attention}сыграна покерная комбинация",
					"{C:attention}#2#{},",
					"покерная комбинация меняется",
					"в конце раунда",
				},
			},
			j_broken = {
				name = "СЛОМАНО",
				text = {
					"Эта карта либо сломана,",
					"либо ещё не добавлена",
					"в данной версии мода.",
				},
			},
			j_to_the_moon_mp = {
				name = "До Луны",
				text = {
					"Получите дополнительно {C:money}$#1#{}",
					"{C:attention}процентов{} за каждые {C:money}$#2#{} у вас",
					"в конце раунда",
				},
			},
			j_mp_defensive_joker = {
				name = "Защитный джокер",
				text = {
					"{C:chips}+#1#{} фишек за каждую {C:red,E:1}жизнь{}",
					"меньше, чем у вашего {X:purple,C:white}Противника{}",
					"{C:inactive}(Сейчас {C:chips}+#2#{C:inactive} фишек)",
					"{C:inactive}(Зависит от ставки)",
				},
			},
			j_mp_skip_off = {
				name = "Проскок",
				text = {
					"{C:blue}+#1#{} Рук и {C:red}+#2#{} Сбросов",
					"за каждый дополнительный {C:attention}Блайнд{}",
					"пропущенный по сравнению с {X:purple,C:white}Противником{}",
					"{C:inactive}(Сейчас {C:blue}+#3#{C:inactive}/{C:red}+#4#{C:inactive}, #5#)",
				},
			},
			j_mp_lets_go_gambling = {
				name = "Вращайте барабан",
				text = {
					"Шанс {C:green}#1# из #2#{} на",
					"{X:mult,C:white}X#3#{} множ. и {C:money}$#4#{}",
					"Шанс {C:green}#5# из #6#{} дать",
					"вашему {X:purple,C:white}Противнику{} {C:money}$#7#{} в {C:attention}PvP блайнде",
				},
			},
			j_mp_speedrun = {
				name = "СПИДРАН",
				text = {
					"Если вы достигнете {C:attention}PvP блайнда",
					"в течение {C:attention}30с{} после {X:purple,C:white}Противника{},",
					"создайте случайную {C:spectral}Спектральную{} карту",
					"{C:inactive}(Должно быть место)",
				},
			},
			j_mp_conjoined_joker = {
				name = "Соединённый джокер",
				text = {
					"В {C:attention}PvP блайнде{} получайте",
					"{X:mult,C:white}X#1#{} множ. за каждую {C:blue}Руку{},",
					"оставшуюся у {X:purple,C:white}Противника{}",
					"{C:inactive}(Макс. {X:mult,C:white}X#2#{C:inactive} множ., Сейчас {X:mult,C:white}X#3#{C:inactive} множ.)",
				},
			},
			j_mp_penny_pincher = {
				name = "Крохобор",
				text = {
					"В конце раунда заработайте {C:money}$#1#{}",
					"за каждые {C:money}$#2#{}, потраченные",
					"вашим {X:purple,C:white}Противником{} в магазине прошлого {C:attention}анте{}",
				},
			},
			j_mp_taxes = {
				name = "Налоги",
				text = {
					"Получает {C:mult}+#1#{} множ. за каждую карту,",
					"проданную вашим {X:purple,C:white}Противником{}",
					"с последнего {C:attention}PvP блайнда{},",
					"обновляется при выборе {C:attention}PvP блайнда{}",
					"{C:inactive}(Сейчас {C:mult}+#2#{C:inactive} множ.)",
				},
			},
			j_mp_pizza = {
				name = "Пицца",
				text = {
					"В конце следующего {C:attention}PvP блайнда{},",
					"съешьте этого джокера и дайте",
					"{C:red}+#1#{} сбросов вам и",
					"{C:red}+#2#{} сбросов вашему {X:purple,C:white}Противнику{} на анте",
				},
			},
			j_mp_pacifist = {
				name = "Пацифист",
				text = {
					"{X:mult,C:white}X#1#{} множ.",
					"вне {C:attention}PvP блайнда{}",
				},
			},
			j_mp_hanging_chad = {
				name = "Надорванный бюллетень",
				text = {
					"Повторно активирует {C:attention}первую{} и {C:attention}вторую{}",
					"сыгранные карты, используемые в подсчёте",
					"{C:attention}#1#{} дополнительный раз",
				},
			},
			j_mp_bloodstone = {
				name = "Гелиотроп",
				text = {
					"Шанс {C:green}#1# из #2#{} для",
					"сыгранных карт масти",
					"{C:hearts}Червы{} давать",
					"{X:mult,C:white} X#3# {} множ. при подсчёте",
				},
			},
			j_mp_magnet_sandbox = {
				name = "Магнит",
				text = {
					"Через {C:attention}#1#{} раундов, продайте",
					"эту карту, чтобы {C:attention}Скопировать{} {X:purple,C:white}Противника{}",
					"самого дорогого {C:attention}Джокера{}",
					"полярность инвертируется через {C:attention}#3#{} раундов",
					"СТАНОВЯСЬ БЕСПОЛЕЗНЫМ МЕТАЛЛОЛОМ!!!!",
					"{C:inactive}(Сейчас {C:attention}#2#{C:inactive}/#1# раундов)",
				},
			},
			j_mp_cloud_9_sandbox = {
				name = "Девятое небо",
				text = {
					"ЧИСЛОВОЙ ФЕРМЕР-МОНОКУЛЬТУРЩИК",
					"превращающий вашу РАЗНООБРАЗНУЮ КОЛОДУ",
					"в ПРИБЫЛЬНУЮ ПЛАНТАЦИЮ ДЕВЯТОК!!!!",
					"{C:inactive}({C:green}#1# из #2#{} {C:inactive}шанс, сейчас {C:money}$#3#{}{C:inactive})",
				},
			},
			j_mp_lucky_cat_sandbox = {
				name = "Счастливый кот",
				text = {
					"ОПЕРАТОР КОНВЕЙЕРА УДАЧИ-В-ХРУПКОСТЬ",
					"счастливые коты становятся СТЕКЛЯННЫМИ КОТАМИ",
					"с ЭКСПОНЕНЦИАЛЬНОЙ СИЛОЙ!!!!",
					"{C:inactive}(Сейчас {X:mult,C:white} X#2# {C:inactive} множ.)",
				},
			},
			j_mp_constellation_sandbox = {
				name = "Созвездие",
				text = {
					"тревожное расстройство обслуживания планет",
					"НАДО КОРМИТЬ ТАМАГОЧИ",
					"ИНАЧЕ ОНО ЗАВЯНЕТ!!!!",
					"{C:inactive}(Сейчас {X:mult,C:white} X#1# {C:inactive} множ.)",
				},
			},
			j_mp_bloodstone_sandbox = {
				name = "Гелиотроп",
				text = {
					"{V:1}СИНДРОМ РЕГРЕССИИ ПАТЧНОУТОВ",
					"откат к ТРАВМЕ ДНЯ ЗАПУСКА",
					"ради НОСТАЛЬГИЧЕСКИХ {X:mult,C:white}X#3#{} ВСПЛЕСКОВ СИЛЫ!!!!",
					"{C:inactive}({C:green}#1# из #2#{} {C:inactive}шанс)",
				},
			},
			j_mp_juggler_sandbox = {
				name = "Жонглёр",
				text = {
					"ПЕРФЕКЦИОНИСТ РАЗМЕРА РУКИ",
					"который должен удерживать ВСЕ КАРТЫ",
					"в воздухе ВСЁ ВРЕМЯ!!!!",
					"{C:inactive}(Сейчас {C:attention}+#1#{C:inactive} размер руки)",
				},
			},
			j_mp_mail_sandbox = {
				name = "Скидка на пересылку",
				text = {
					"Даёт {C:money}$#1#{} за каждую",
					"сброшенную карту с достоинством {C:attention}#2#{},",
					"достоинство никогда не меняется",
				},
			},
			j_mp_hit_the_road_sandbox = {
				name = "В путь-дорогу",
				text = {
					"Этот джокер получает {X:mult,C:white}X0.75{} множ.",
					"за каждого сброшенного {C:attention}Валета{}",
					"Сброшенные валеты {C:attention}уничтожаются{}",
					"{C:inactive}(Сейчас {X:mult,C:white} X#2# {C:inactive} множ.)",
				},
			},
			j_mp_misprint_sandbox = {
				name = "Опечатка",
				text = {
					"{V:1}#1#{} множ.",
					"{C:attention}Значение раскрывается при покупке{}",
					"{C:green}Ошибки печати накапливаются{}",
				},
			},
			j_mp_castle_sandbox = {
				name = "Замок",
				text = {
					"Этот джокер получает {C:chips}+#3#{} фишек",
					"за каждую сброшенную карту масти {V:1}#1#{}",
					"Масть фиксируется при покупке",
					"{C:inactive}(Сейчас {C:chips}+#2#{C:inactive} фишек)",
				},
			},
			j_mp_runner_sandbox = {
				name = "Бегун",
				text = {
					"ПРЕВОСХОДИТЕЛЬ ПОСЛЕДОВАТЕЛЬНЫХ КАРТ",
					"считающий ВСЕ остальные",
					"ПОКЕРНЫЕ РУКИ НЕДОСТОЙНЫМИ!!!!",
					"{C:inactive}(Сейчас {C:chips}+#1#{C:inactive})",
				},
			},
			j_mp_order_sandbox = {
				name = "The Order",
				text = {
					"{X:mult,C:white}X3{} множ., если сыгранная рука содержит {C:attention}Стрит{}",
					"Получает {X:mult,C:white}X#1#{} множ. за каждый",
					"подряд сыгранный {C:attention}Стрит{}",
					"Сбрасывается, если сыграна другая рука",
					"{C:inactive}(Сейчас {X:mult,C:white}X#2#{C:inactive} множ.)",
				},
			},
			j_mp_photograph_sandbox = {
				name = "Фотография",
				text = {
					"ФОТОГРАФ ОДНОГО КАДРА, который делает",
					"ОДИН ИДЕАЛЬНЫЙ СНИМОК ЗА РУКУ!!!!",
				},
			},
			j_mp_ride_the_bus_sandbox = {
				name = "Автобусный тур",
				text = {
					"ПРОГРАММА ТРЕЗВОСТИ ОТ КАРТ С ЛИЦАМИ",
					"ОДНА КАРТА С ЛИЦОМ — и вас",
					"ВЫШВЫРНУТ ИЗ АВТОБУСА!!!!",
					"{C:inactive}(Сейчас {C:mult}+#1#{C:inactive} множ.)",
				},
			},
			j_mp_loyalty_card_sandbox = {
				name = "Карта лояльности",
				text = {
					"{X:mult,C:white}X6{} множ. каждые {C:attention}#3#{}",
					"сыгранных рук {C:attention}#1#{}",
					"{C:inactive}(#2#/#3#)",
				},
			},
			j_mp_faceless_sandbox = {
				name = "Безликий джокер",
				text = {
					"ЭЛИТНЫЙ СОМЕЛЬЕ КАРТ С ЛИЦАМИ",
					"составляющий изысканные",
					"ДЕГУСТАЦИОННЫЕ СЕТЫ ИЗ ТРЁХ СОРТОВ",
					"для ПРЕМИАЛЬНОГО ОПЫТА УТИЛИЗАЦИИ!!!!",
				},
			},
			j_mp_square_sandbox = {
				name = "Квадратный джокер",
				text = {
					"Этот джокер получает {C:chips}+#2#{} фишек,",
					"если сыгранная рука содержит",
					"ровно {C:attention}4{} карты",
					"{C:attention}Применяется только к рукам из 4 карт{}",
					"{C:inactive}(Сейчас {C:chips}+#1#{C:inactive} фишек)",
				},
			},
			j_mp_throwback_sandbox = {
				name = "Возврат",
				text = {
					"{X:mult,C:white}X#2#{} базового множ. за каждый",
					"{C:attention}Блайнд{}, пропущенный в этом забеге",
					"{X:mult,C:white}X#3#{} множ. в следующем блайнде после пропуска",
					"Теряет {X:mult,C:white}X#4#{} когда блайнд не пропущен",
					"{C:inactive}(Сейчас {X:mult,C:white} X#1# {C:inactive} множ.)",
				},
			},
			j_mp_vampire_sandbox = {
				name = "Вампир",
				text = {
					"Этот джокер получает {X:mult,C:white}X#1#{} множ. за каждую",
					"сыгранную {C:attention}улучшенную карту{} при подсчёте",
					"Сыгранные улучшенные карты становятся {C:attention}Каменными{}",
					"Каменные карты дают {C:money}$#3#{} при игре",
					"{C:inactive}(Сейчас {X:mult,C:white} X#2# {C:inactive} множ.)",
				},
			},
			j_mp_baseball_sandbox = {
				name = "Бейсбольная карточка",
				text = {
					"{C:green}Необычные{} Джокеры",
					"каждый даёт",
					"{X:mult,C:white}X#1#{} множ.",
				},
			},
			j_mp_steel_joker_sandbox = {
				name = "Стальной джокер",
				text = {
					"Сыгранные Стальные карты",
					"{C:attention}повторно активируются{}",
				},
			},
			j_mp_golden_ticket_sandbox = {
				name = "Золотой билет",
				text = {
					"Шанс {C:green}#2# из #3#{} для",
					"{C:attention}Золотых{} карт зарабатывать",
					"{C:money}$#1#{} при игре",
				},
			},
			j_mp_satellite_sandbox = {
				name = "Спутник",
				text = {
					"хроническая тревога деградации спутника",
					"ИНФРАСТРУКТУРА МЕДЛЕННО РАЗВАЛИВАЕТСЯ",
					"БЕЗ ПОСТОЯННЫХ ПЛАНЕТАРНЫХ ОБНОВЛЕНИЙ!!!!",
					"{C:inactive}(Сейчас {C:money}$#1#{C:inactive})",
				},
			},
			j_mp_idol_sandbox_zealot = {
				name = "Идол фанатика",
				text = {
					"Каждая сыгранная {C:attention}#1#{}",
					"даёт {X:mult,C:white}X#2#{} множ.",
					"при подсчёте",
					"{s:0.8}Карта меняется каждый раунд",
				},
			},
			j_mp_idol_sandbox_collector = {
				name = "Идол коллекционера",
				text = {
					"Самая частая карта даёт",
					"{X:mult,C:white}X#3#{} множ. при подсчёте",
					"({X:mult,C:white}+X#4#{} за копию в колоде)",
					"{C:inactive}(Сейчас {C:attention}#1#{} из {V:1}#2#{})",
				},
			},
			j_mp_error_sandbox = {
				name = "????",
				text = {
					"{X:purple,C:white,s:0.85}что-то{} {X:purple,C:white,s:0.85}не так",
				},
			},
			j_mp_clowncollege_sandbox = {
				name = "Клоунский колледж",
				text = {
					"{C:attention}Заполняет{} слоты расходников",
					"{C:tarot}Дураком{} после победы",
					"над {C:attention}Босс-блайндом{}",
					"{C:inactive}(Должно быть место)",
				},
			},
			j_mp_alloy_sandbox = {
				name = "Сплав",
				text = {
					"{C:attention}Золотые карты{} также",
					"считаются {C:attention}Стальными картами{}",
					"{C:attention}Стальные карты{} также",
					"считаются {C:attention}Золотыми картами{}",
				},
			},
			j_mp_ambrosia_sandbox = {
				name = "Амброзия",
				text = {
					"{C:attention}Заполняет{} слоты расходников",
					"{C:spectral}Спектральными картами{} при",
					"{C:attention}пропуске{} или уничтожении {C:attention}блайнда{},",
					"уничтожается при {C:attention}продаже{} любой {C:spectral}Спектральной{} карты",
					"{C:inactive}(Должно быть место)",
				},
			},
			j_mp_bobby_sandbox = {
				name = "Бобби",
				text = {
					"При выборе {C:attention}Блайнда{}",
					"потеряйте {C:attention}#1#{} Рук и получите",
					"{C:red}+#1#{} Сбросов за каждую потерянную Руку",
				},
			},
			j_mp_candynecklace_sandbox = {
				name = "Конфетное ожерелье",
				text = {
					"В конце {C:attention}магазина{} создайте",
					"случайный {C:attention}Тег бустерного набора",
					"{C:inactive}(Осталось #1# использований){C:inactive}",
				},
			},
			j_mp_chainlightning_sandbox = {
				name = "Цепная молния",
				text = {
					"Сыгранные {C:attention}Карты множ.{} дают",
					"{X:mult,C:white}X#1#{} множ. при подсчёте,",
					"затем увеличьте это на {X:mult,C:white}X#2#",
					"{C:inactive}(Сбрасывается с каждой рукой)",
				},
			},
			j_mp_clowncar_sandbox = {
				name = "Клоун-кар",
				text = {
					"{C:mult}+#1#{} множ. и {C:money}-$#2#",
					"{C:attention}до{} подсчёта карт",
				},
			},
			j_mp_couponsheet_sandbox = {
				name = "Лист купонов",
				text = {
					"Создаёт {C:attention}Купонный тег",
					"и {C:attention}Ваучерный тег",
					"после победы над {C:attention}Босс-блайндом{}",
				},
			},
			j_mp_doublerainbow_sandbox = {
				name = "Двойная радуга",
				text = {
					"{C:attention}Повторно активирует{} все {C:attention}Счастливые карты{}",
				},
			},
			j_mp_espresso_sandbox = {
				name = "Эспрессо",
				text = {
					"Получите {C:money}$#1#{} и уничтожьте эту",
					"карту при пропуске {C:attention}Блайнда{}",
					"Уменьшается на {C:money}$#2#{} в конце раунда",
				},
			},
			j_mp_farmer_sandbox = {
				name = "Фермер",
				text = {
					"Карты масти {V:1}#2#{}",
					"в руке дают {C:money}$#1#",
					"в конце раунда",
					"{s:0.8}масть меняется в конце раунда",
				},
			},
			j_mp_forklift_sandbox = {
				name = "Погрузчик",
				text = {
					"{C:attention}+#1#{} слотов расходников",
				},
			},
			j_mp_gofish_sandbox = {
				name = "Ловись рыбка",
				text = {
					"В {C:attention}первый раз{}, когда",
					"{C:attention}сыгранная рука{} содержит любые",
					"{C:attention}#1#{} в подсчёте, уничтожьте их",
					"{s:0.8}достоинство меняется в конце раунда",
				},
			},
			j_mp_hoarder_sandbox = {
				name = "Накопитель",
				text = {
					"Этот джокер получает {C:money}$#1#{} к стоимости продажи",
					"каждый раз, когда зарабатываются {C:money}деньги{}",
				},
			},
			j_mp_jokalisa_sandbox = {
				name = "Джока Лиза",
				text = {
					"Получает {X:mult,C:white}X#2#{} множ. за",
					"каждое {C:attention}уникальное улучшение",
					"в подсчитываемой руке",
					"{C:inactive}(Сейчас {X:mult,C:white}X#1#{C:inactive})",
				},
			},
			j_mp_jokeroftheyear_sandbox = {
				name = "Джокер года",
				text = {
					"Если сыгранная рука содержит",
					"{C:attention}5{} подсчитываемых карт,",
					"{C:attention}повторно активируйте{} сыгранные карты",
				},
			},
			j_mp_lucky7_sandbox = {
				name = "Счастливая 7",
				text = {
					"Если сыгранная рука содержит",
					"{C:attention}7{} в подсчёте, все сыгранные",
					"карты считаются {C:attention}Счастливыми картами",
				},
			},
			j_mp_montehaul_sandbox = {
				name = "Монте-Хол",
				text = {
					"Через {C:attention}1 раунд{} продайте эту карту,",
					"чтобы получить {C:attention}2{} случайных {C:attention}Тега Джокера",
					"{C:inactive}(Сейчас {C:attention}#1#{C:inactive} раундов)",
				},
			},
			j_mp_pocketaces_sandbox = {
				name = "Карманные тузы",
				text = {
					"Заработайте {C:money}$#1#{} в конце раунда",
					"Сыгранные {C:attention}Тузы{} увеличивают выплату",
					"на {C:money}$#2#{}, сбрасывается в каждом {C:attention}Анте",
				},
			},
			j_mp_pyromancer_sandbox = {
				name = "Пиромант",
				text = {
					"{C:mult}+#1#{} множ., если",
					"оставшихся {C:attention}Рук{} меньше",
					"или равно {C:attention}Сбросам",
				},
			},
			j_mp_shipoftheseus_sandbox = {
				name = "Корабль Тесея",
				text = {
					"Когда {C:attention}Игровая карта{} {C:attention}уничтожена{},",
					"добавьте её {C:attention}копию{} в вашу {C:attention}колоду",
					"и этот джокер получает {X:mult,C:white}X#2#{} множ.",
					"{C:inactive}(Сейчас {X:mult,C:white}X#1#{C:inactive} множ.)",
				},
			},
			j_mp_starfruit_sandbox = {
				name = "Звёздный фрукт",
				text = {
					"{C:attention}Первая сыгранная рука{} в каждом раунде",
					"имеет шанс {C:green}#2# из #3#{}",
					"повысить уровень на {C:attention}1{}",
					"{C:inactive}({}{C:attention}#1#{}{C:inactive} раундов осталось)",
				},
			},
			j_mp_trafficlight_sandbox = {
				name = "Светофор",
				text = {
					"{X:mult,C:white}X#1#{} множ.",
					"Уменьшается на {X:mult,C:white}X#2#{} после",
					"каждой руки, сбрасывается после {X:mult,C:white}X0.5",
				},
			},
			j_mp_tuxedo_sandbox = {
				name = "Смокинг",
				text = {
					"{C:attention}Повторно активирует{} все карты",
					"масти {V:1}#1#{}",
					"{s:0.8}масть меняется в конце раунда",
				},
			},
			j_mp_warlock_sandbox = {
				name = "Чернокнижник",
				text = {
					"Шанс {C:green}#1# из #2#{} для сыгранных",
					"{C:attention}Счастливых карт{} быть {C:red}уничтоженными",
					"и породить {C:spectral}Спектральную карту",
					"{C:inactive}(Должно быть место)",
				},
			},
			j_mp_werewolf_sandbox = {
				name = "Оборотень",
				text = {
					"Сыгранные карты, которые",
					"{C:attention}улучшены{}, становятся {C:attention}Дикими картами",
				},
			},
			j_mp_8ball_release = {
				name = "Магический шар",
				text = {
					"Создайте {C:planet}Планетную{} карту,",
					"если сыгранная рука содержит",
					"{C:attention}#1#{} или более {C:attention}Восьмёрок{}",
					"{C:inactive}(Должно быть место)",
				},
			},
			j_mp_todo_list_release = {
				name = "Список дел",
				text = {
					"Даёт {C:money}$#1#{}, когда сыграна",
					"покерная комбинация {C:attention}#2#{},",
					"покерная комбинация меняется",
					"при каждой выплате",
				},
			},
			j_mp_swashbuckler_release = {
				name = "Головорез",
				text = {
					"Добавляет стоимость продажи",
					"всех {C:attention}Джокеров{} слева",
					"от этой карты к множ.",
					"{C:inactive}(Сейчас {C:mult}+#1#{C:inactive} множ.)",
				},
			},
			j_mp_hanging_chad_release = {
				name = "Надорванный бюллетень",
				text = {
					"Повторно активирует {C:attention}первую{} сыгранную",
					"карту, используемую в подсчёте",
				},
			},
			j_mp_madness_release = {
				name = "Безумец",
				text = {
					"При выборе {C:attention}Блайнда{}",
					"получите {X:mult,C:white} X#1# {} множ. и",
					"{C:attention}уничтожьте{} случайного Джокера",
					"{C:inactive}(Сейчас {X:mult,C:white} X#2# {} множ.)",
				},
			},
			j_mp_vampire_release = {
				name = "Вампир",
				text = {
					"Этот джокер получает {X:mult,C:white} X#1# {} множ.",
					"за каждую сыгранную {C:attention}улучшенную карту{},",
					"снимает {C:attention}улучшение{} с карты",
					"{C:inactive}(Сейчас {X:mult,C:white} X#2# {C:inactive} множ.)",
				},
			},
			j_mp_midas_mask_release = {
				name = "Маска Мидаса",
				text = {
					"Все сыгранные карты {C:attention}с лицом{}",
					"становятся {C:attention}Золотыми{}",
					"при подсчете",
				},
			},
			j_mp_yorick_release = {
				name = "Йорик",
				text = {
					"{X:mult,C:white} X#1# {} множ. только после",
					"использования {C:attention}#2#{} сбросов",
					"{C:inactive}(Осталось сбросов: {C:attention}#3#{C:inactive})",
				},
			},
			j_mp_flower_pot_release = {
				name = "Цветочный горшок",
				text = {
					"{X:mult,C:white} X#1# {} множ., если сыгранная",
					"рука содержит подсчитываемую",
					"{C:diamonds}Бубновую{}, {C:clubs}Трефовую{},",
					"{C:hearts}Червовую{} и {C:spades}Пиковую{} карты",
				},
			},
		},
		Tarot = {
			c_mp_magician_release = {
				name = "Маг",
				text = {
					"Улучшает {C:attention}#1#{} выбранную",
					"карту в",
					"{C:attention}#2#",
				},
			},
		},
		Planet = {
			c_mp_asteroid = {
				name = "Астероид",
				text = {
					"Снимает #1# уровень с",
					"{C:legendary,E:1}покерной комбинации{} наивысшего уровня",
					"вашего {X:purple,C:white}Противника{}",
					"в начале {C:attention}PvP блайнда{}",
				},
			},
		},
		Blind = {
			bl_mp_nemesis = {
				name = "Ваш Противник",
				text = {
					"Сразитесь с другим игроком,",
					"больше фишек — победа",
				},
			},
		},
		Enhanced = {},
		Back = {
			b_mp_cocktail = {
				name = "Коктейльная колода",
				text = {
					"Копирует все эффекты",
					"{C:attention}3{} других колод",
					"случайным образом",
				},
			},
			b_mp_gradient = {
				name = "Градиентная колода",
				text = {
					"Карты также считаются",
					"на одно достоинство {C:attention}выше{} или {C:attention}ниже",
					"для всех эффектов {C:attention}Джокеров{}",
				},
			},
			b_mp_heidelberg = {
				name = "Гейдельбергская колода",
				text = {
					"Создаёт {C:dark_edition}Негативную{} копию",
					"{C:attention}1{} случайной {C:attention}расходной{}",
					"карты в вашем распоряжении",
					"в конце {C:attention}магазина",
				},
			},
			b_mp_indigo = {
				name = "Индиго-колода",
				text = {
					"Выбирайте {C:attention}+1{} дополнительную карту",
					"из всех бустерных наборов",
					"Бустерные наборы {C:attention}нельзя пропустить{}",
				},
			},
			b_mp_oracle = {
				name = "Оракул-колода",
				text = {
					"Начните забег с {C:spectral,T:c_medium}Медиумом",
					"и {C:attention,T:v_clearance_sale}Распродажей",
					"Баланс ограничен",
					"{C:money}$50{} + {C:attention}текущий лимит процентов{}",
				},
			},
			b_mp_orange = {
				name = "Оранжевая колода",
				text = {
					"Начните забег с",
					"{C:attention,T:p_mp_standard_giga}Гига-стандартным набором{}",
					"и {C:attention}2{} копиями {C:tarot,T:c_hanged_man}Повешенного",
				},
			},
			b_mp_violet = {
				name = "Фиолетовая колода",
				text = {
					"{C:attention}+1{} ваучер в магазине",
					"Ваучеры со скидкой {C:attention}50%{}",
					"в Анте {C:attention}1{}, и {C:attention}30%{}",
					"в Анте {C:attention}2",
				},
			},
			b_mp_white = {
				name = "Белая колода",
				text = {
					"Просмотрите текущую колоду",
					"и джокеров {X:purple,C:white}Противника{}",
					"{C:inactive}(Обновляется у PvP блайнда){}",
				},
			},
		},
		Other = {
			mp_sticker_extra_credit = {
				name = "Доп. кредит",
				text = {
					"Сделано с друзьями из",
					"Balatro University!",
				},
			},
			mp_sticker_balanced = {
				name = "Сбалансировано",
				text = {
					"Эта карта была перебалансирована",
				},
			},
			mp_sticker_balanced_j_mp_hanging_chad = {
				name = "Сбалансировано",
				text = {
					"Повторно активирует первые {C:attention}2{} карты",
					"вместо первой карты дважды",
				},
			},
			mp_sticker_balanced_j_mp_ticket = {
				name = "Сбалансировано",
				text = {
					"Теперь {C:green}Необычный{}",
					"Без требования {C:attention}Золотой{} карты",
				},
			},
			mp_sticker_balanced_j_mp_seltzer = {
				name = "Сбалансировано",
				text = {
					"Длится {C:attention}8{} рук",
					"вместо {C:attention}10{}",
				},
			},
			mp_sticker_balanced_j_mp_turtle_bean = {
				name = "Сбалансировано",
				text = {
					"{C:attention}+4{} размер руки",
					"вместо {C:attention}+5{}",
				},
			},
			mp_sticker_balanced_j_mp_baron = {
				name = "Сбалансировано",
				text = {
					"Теперь {C:green}Необычный{} ({C:money}$5{})",
					"вместо {C:red}Редкого{} ({C:money}$8{})",
				},
			},
			mp_sticker_balanced_j_mp_mime = {
				name = "Сбалансировано",
				text = {
					"Теперь {C:red}Редкий{} ({C:money}$8{})",
					"вместо {C:green}Необычного{} ({C:money}$5{})",
				},
			},
			mp_sticker_balanced_j_mp_todo_list = {
				name = "Сбалансировано",
				text = {
					"Зарабатывает {C:money}$5{} вместо {C:money}$4{}",
					"Выбирает из {C:attention}всех{} покерных рук,",
					"не только открытых",
				},
			},
			mp_sticker_balanced_j_mp_bloodstone = {
				name = "Сбалансировано",
				text = {
					"В {C:attention}PvP{} броски {C:green}1 из 2{}",
					"берутся из {C:attention}фиксированной последовательности{},",
					"общей для обоих игроков и",
					"{C:attention}повторно используемой{} в каждой руке раунда",
				},
			},
			mp_sticker_balanced_c_mp_ouija_standard = {
				name = "Сбалансировано",
				text = {
					"Уничтожает {C:attention}3{} карты вместо",
					"превращения всех карт и потери",
					"{C:attention}-1{} размер руки",
				},
			},
			mp_sticker_balanced_m_gold = {
				name = "Сбалансировано",
				text = {
					"Зарабатывает {C:money}$4{} вместо {C:money}$3{}",
				},
			},
			current_nemesis = {
				name = "Противник",
				text = {
					"{X:purple,C:white}#1#{}",
					"Ваш единственный противник",
				},
			},
			p_mp_standard_giga = {
				name = "Гига-стандартный набор",
				text = {
					"Выберите {C:attention}#1#{} из до",
					"{C:attention}#2#{} {C:attention}Игровых{} карт,",
					"чтобы добавить в колоду",
					"{C:attention}Нельзя пропустить{}",
				},
			},
			mp_transmutations = {
				name = "Трансмутации",
				text = {
					"{C:purple,s:1.1}Превратится в:",
				},
			},
			mp_internal_sell_value = {
				name = "Стоимость продажи",
				text = {
					"{C:money,s:1.3}$#1#",
				},
			},
			mp_sticker_persistent = {
				name = "Постоянный",
				text = {
					"Не может быть уничтожен",
					"Стоит {C:red}${} для продажи",
					"Стоимость увеличивается",
					"на {C:red}$3{} в конце раунда",
				},
			},
			mp_sticker_unreliable = {
				name = "Ненадёжный",
				text = {
					"Не срабатывает",
					"на {C:attention}финальной руке{}",
				},
			},
			mp_sticker_draining = {
				name = "Истощающий",
				text = {
					"{X:mult,C:white}X0.75{} множ.",
				},
			},
			mp_blue_seal_release = {
				name = "Синяя печать",
				text = {
					"Создаёт {C:planet}Планетную{} карту,",
					"если эта карта {C:attention}держится{} в",
					"руке в конце раунда",
				},
			},
		},
		Stake = {
			stake_mp_planet = {
				name = "Планетная ставка",
				text = {
					"Применяет эффекты {C:black}Чёрной ставки{}, плюс:",
					"В магазине могут появиться {C:attention}Недолговечные{} Джокеры",
					"{C:inactive,s:0.8}(Ослаблены после 5 раундов)",
					"Требуемый счёт растёт",
					"быстрее за каждое {C:attention}Анте",
				},
			},
			stake_mp_spectral = {
				name = "Спектральная ставка",
				text = {
					"Применяет эффекты {C:planet}Планетной ставки{}, плюс:",
					"В магазине появляются {C:money}Арендные{} Джокеры",
					"Требуемый счёт растёт",
					"быстрее за каждое {C:attention}Анте",
				},
			},
			stake_mp_spectralplus = {
				name = "Спектральная+ ставка",
				text = {
					"Применяет эффекты {C:planet}Спектральной ставки{}, плюс:",
					"Требуемый счёт растёт",
					"ещё быстрее за каждое {C:attention}Анте",
				},
			},
			stake_mp_plastic = {
				name = "Пластиковая ставка",
				text = {
					"Зарабатывайте {C:money}$1{} процентов за каждые {C:money}$10{}",
					"{C:inactive,s:0.8}(Макс. {C:money,s:0.8}$50{C:inactive,s:0.8})",
					"{s:0.8}Применяет Белую ставку",
				},
			},
			stake_mp_pebble = {
				name = "Галечная ставка",
				text = {
					"Требуемый счёт растёт",
					"быстрее за каждое {C:attention}Анте",
					"{s:0.8}Применяет Пластиковую ставку",
				},
			},
			stake_mp_ferrite = {
				name = "Ферритовая ставка",
				text = {
					"Определённые Джокеры {C:attention}Постоянны",
					"{C:inactive,s:0.8}(Не могут быть уничтожены, растущая цена продажи)",
					"{s:0.8}Применяет Галечную ставку",
				},
			},
			stake_mp_pyrite = {
				name = "Пиритовая ставка",
				text = {
					"Цена обновления увеличивается",
					"на {C:money}$2{} за каждое обновление",
					"{s:0.8}Применяет Ферритовую ставку",
				},
			},
			stake_mp_jade = {
				name = "Нефритовая ставка",
				text = {
					"Требуемый счёт растёт",
					"быстрее за каждое {C:attention}Анте",
					"{s:0.8}Применяет Пиритовую ставку",
				},
			},
			stake_mp_crystal = {
				name = "Хрустальная ставка",
				text = {
					"Определённые Джокеры {C:attention}Ненадёжны",
					"{C:inactive,s:0.8}(Не срабатывают на {C:attention,s:0.8}финальной руке{C:inactive,s:0.8})",
					"{s:0.8}Применяет Нефритовую ставку",
				},
			},
			stake_mp_antimatter = {
				name = "Антиматериальная ставка",
				text = {
					"Определённые Джокеры {C:attention}Истощающие",
					"{C:inactive,s:0.8}({X:mult,C:white,s:0.8} X0.75 {C:inactive,s:0.8} множ.)",
					"{s:0.8}Применяет Хрустальную ставку",
				},
			},
			stake_mp_orange_release = {
				name = "Оранжевая ставка",
				text = {
					"{C:attention}Бустерные наборы{} стоят",
					"{C:money}$1{} дороже за Анте",
					"{s:0.8}Применяет все предыдущие ставки",
				},
			},
			stake_mp_gold_release = {
				name = "Золотая ставка",
				text = {
					"{C:red}-1{} размер руки",
					"{s:0.8}Применяет все предыдущие ставки",
				},
			},
		},
		Spectral = {
			c_mp_ouija_standard = {
				name = "Уиджа",
				text = {
					"Уничтожьте {C:attention}#1#{} случайных карт,",
					"затем превратите все оставшиеся",
					"карты в одно случайное {C:attention}достоинство",
				},
			},
			c_mp_ectoplasm_sandbox = {
				name = "Эктоплазма",
				text = {
					"Добавьте {C:dark_edition}Негативный{}",
					"случайному {C:attention}Джокеру,",
					"Случайно примените одно из:",
					"{C:red}-1{} рука, {C:red}-1{} сброс или {C:red}-1{} размер руки",
				},
			},
		},
	},
	misc = {
		labels = {
			mp_sticker_balanced = "Сбалансировано",
			mp_sticker_extra_credit = "Доп. кредит",
			mp_sticker_persistent = "Постоянный",
			mp_sticker_unreliable = "Ненадёжный",
			mp_sticker_draining = "Истощающий",
		},
		dictionary = {
			b_singleplayer = "Одиночная Игра",
			b_sp_with_ruleset = "Тренировка",
			b_practice = "Тренировка",
			k_unlimited_slots = "Безлимитные слоты",
			k_edition_cycling = "Смена издания (Q)",
			b_join_lobby = "Подключиться к лобби",
			b_join_lobby_clipboard = "Подкл. из буфера",
			b_return_lobby = "Вернуться в лобби",
			b_reconnect = "Переподключиться",
			b_create_lobby = "Создать лобби",
			b_start_lobby = "Начать игру",
			b_ready = "Приготовиться",
			b_unready = "Отменить",
			b_leave_lobby = "Выйти из лобби",
			b_mp_discord = "Discord-сервер Balatro Multiplayer",
			b_start = "НАЧАТЬ",
			b_wait_for_host_start = {
				"ЖДЁМ",
				"ЗАПУСКА ОТ ХОСТА",
			},
			b_wait_for_players = {
				"ЖДЁМ",
				"ИГРОКОВ",
			},
			b_wait_for_guest_ready = {
				"ЖДЁМ",
				"ГОТОВНОСТИ ГОСТЯ",
			},
			b_lobby_options = "ПАРАМЕТРЫ ЛОББИ",
			b_copy_clipboard = "Скопировать",
			b_view_code = "УВИДЕТЬ КОД",
			b_copy_code = "КОПИРОВАТЬ КОД",
			b_leave = "ВЫЙТИ",
			b_opts_cb_money = "Давать компенсацию $ при потере жизни",
			b_opts_no_gold_on_loss = "Не давать награду за блайнд при проигрыше",
			b_opts_death_on_loss = "Терять жизнь при проигрыше не в PvP",
			b_opts_start_antes = "Начальные Анте",
			b_opts_diff_seeds = "Разные сиды у игроков",
			b_opts_lives = "Жизни",
			b_opts_multiplayer_jokers = "Включить карты мультиплеера",
			b_opts_player_diff_deck = "Разные колоды у игроков",
			b_opts_random_loadout = "Случайные колода и ставка",
			b_opts_normal_bosses = "Включить эффекты босс-блайндов",
			b_opts_timer = "Включить таймер",
			b_opts_disable_preview = "Отключить предпросмотр счёта",
			b_opts_the_order = "Включить The Order",
			b_opts_legacy_smallworld = "Старая механика «Мир тесен»",
			b_reset = "Сбросить",
			b_set_custom_seed = "Установить свой сид",
			b_opts_modifier_smallworld = "Мир тесен",
			b_mp_kofi_button = "поддержать меня на Ko-fi",
			b_unstuck = "Выбраться",
			b_unstuck_blind = "Застрял вне PvP",
			b_misprint_display = "Показать следующую карту в колоде",
			b_players = "Игроки",
			b_lobby_info = "Инфо о лобби",
			b_continue_singleplayer = "Продолжить в одиночной игре",
			b_the_order_integration = "Включить интеграцию The Order",
			b_preview_integration = "Включить предпросмотр счёта",
			b_view_nemesis_deck = "Просмотр колод",
			b_toggle_jokers = "Переключить джокеров",
			b_skip_tutorial = "Пропустить обучение",
			k_yes = "Да",
			k_no = "Нет",
			k_are_you_sure = "Вы уверены?",
			k_has_multiplayer_content = "Содержит контент мультиплеера",
			k_forces_lobby_options = "Принудительные настройки лобби",
			k_forces_gamemode = "Принудительный режим игры",
			k_values_are_modifiable = "* Значения можно менять",
			k_rulesets = "Правила",
			k_gamemodes = "Режимы игры",
			k_matchmaking = "Подбор игроков",
			k_tournament = "Турнир",
			k_custom = "Свои",
			k_other = "Другое",
			k_battle = "Битва",
			k_challenge = "Испытание",
			k_info = "Инфо",
			k_continue_singleplayer_tooltip = "Это перезапишет ваш текущий забег в одиночной игре",
			k_enemy_score = "Текущий счёт противника",
			k_enemy_hands = "Рук у противника осталось: ",
			k_coming_soon = "Скоро!",
			k_wait_enemy = "Ожидание завершения противника...",
			k_lives = "Жизни",
			k_skips = "Пропуски",
			k_lost_life = "Потеряна жизнь",
			k_total_lives_lost = " Всего жизней потеряно",
			k_comeback_money_sandbox = " Компенсация ($3 × анте пройдено)",
			k_attrition_name = "Истощение",
			k_enter_lobby_code = "Введите код лобби",
			k_paste = "Вставить из буфера",
			k_username = "Имя:",
			k_enter_username = "Введите имя",
			k_customize_preview = "Настроить текст предпросмотра:",
			k_join_discord = "Присоединяйтесь к ",
			k_discord_msg = "Там вы можете сообщать об ошибках и находить игроков",
			k_enter_to_save = "Нажмите Enter для сохранения",
			k_in_lobby = "В лобби",
			k_connected = "Подключено к сервису",
			k_warn_service = "ПРЕДУПРЕЖДЕНИЕ: Не удалось найти сервис мультиплеера",
			k_set_name = "Введите своё имя в главном меню! (Mods > Multiplayer > Config)",
			k_mod_hash_warning = "У игроков разные моды или версии модов! Это может вызвать проблемы!",
			k_steamodded_warning = "У игроков разные версии Steamodded. Это может привести к расхождению сидов.",
			k_warning_unlock_profile = "Ваш профиль не полностью разблокирован. Если это рейтинговая/турнирная игра, создайте новый профиль и нажмите 'разблокировать всё' в настройках профиля",
			k_warning_nemesis_unlock = "Ваш противник играет на не полностью разблокированном профиле. Попросите их создать новый профиль и нажать 'разблокировать всё'",
			k_warning_no_order = "У одного игрока включена интеграция The Order, а у другого нет. Это вызовет расхождение сидов.",
			k_warning_cheating1 = "Если вы это видите, ваш противник возможно использует читы.",
			k_warning_cheating2 = "Если это рейтинговая игра, отправьте сообщение '%s' и откройте тикет в #support",
			k_warning_banned_mods = "У одного или нескольких игроков установлены запрещённые моды. Они не допускаются в рейтинговых играх.",
			k_message1 = "Минуточку, моя мама сделала пиццу",
			k_message2 = "Сек, надо достать тушёную свинину из мультиварки",
			k_message3 = "Момент, звонок от мамы",
			k_message4 = "Ща вернусь, мой кот горит",
			k_message5 = "Погодите, кажется я оставил плиту включённой",
			k_message6 = "Стоп, мой камень-питомец только что убежал",
			k_message7 = "Сек, мои растения просят воды",
			k_message8 = "Ща вернусь, мои носки что-то замышляют",
			k_message9 = "Извините, мой WiFi переживает экзистенциальный кризис",
			k_lobby_options = "Параметры лобби",
			k_connect_player = "Игроки в лобби:",
			k_opts_only_host = "Только ведущий может менять эти настройки",
			k_lobby_general = "Общие",
			k_lobby_gameplay = "Геймплей",
			k_lobby_modifiers = "Модификаторы",
			k_lobby_advanced = "Продвинутые",
			k_opts_pvp_start_round = "PvP начинается с Анте",
			k_opts_pvp_timer = "Таймер",
			k_opts_pvp_timer_increment = "Прирост таймера",
			k_opts_pvp_countdown_seconds = "Секунд обратного отсчёта PvP",
			k_opts_modifier_timer = "Режим таймера",
			k_experimental_modifiers_timers = {
				"- По умолчанию: обычный таймер {C:chips}150{} {C:inactive}(1x){} секунд",
				" ",
				"- Без анимаций: таймер {C:chips}100{} {C:inactive}(0.67x){} секунд {C:attention}за вычетом времени анимаций{}",
				" ",
				"- Pressure: таймер {C:chips}300{} {C:inactive}(2x){} секунд {C:attention}за вычетом времени анимаций{}",
				"  запускается {C:attention}немедленно{}",
				" ",
				"- Pressure+: то же, что {C:attention}Pressure{} плюс {C:chips}15{} секунд за сыгранную руку",
			},
			b_opts_modifier_pvp_timer = "PvP таймер",
			k_experimental_modifiers_pvp_timer = {
				"- Таймер, доступный во время {C:mult}PvP{} раундов.",
				"  {C:chips}90{} секунд плюс {C:chips}15{} секунд за сыгранную руку {C:attention}за вычетом времени анимаций{}.",
				"  Можете запустить таймер противнику, только если у вас {C:attention}выше{} счёт",
			},
			k_experimental_modifiers_smallworld = {
				"- {C:attention}75%{} джокеров, расходников, ваучеров и тегов",
				"  случайно запрещаются в каждой игре.",
				"- Эффект {C:attention}Шоумена{} всегда активен.",
			},
			k_bl_life = "Жизнь",
			k_bl_or = "или",
			k_bl_death = "Смерть",
			k_bl_mostchips = "Больше фишек — победа",
			k_current_seed = "Текущий сид: ",
			k_random = "Случайный",
			k_standard = "Стандартный",
			k_sandbox = "Песочница: Доп. кредит",
			k_sandbox_description = "26 новых джокеров из Extra Credit присоединяются к ростеру.\nИдол разделяется на два: Фанатика и Коллекционера. Выбираешь один, другой исчезает.\nНовые спектральные, переработанная компенсация, без предпросмотра счёта.\nМета открыта. Сделано с друзьями из Balatro University.\n",
			k_vanilla = "Ванилла",
			k_vanilla_description = "Оригинальный Balatro.\n\nНикаких джокеров мультиплеера, никаких изменений баланса.\nПросто базовая игра, как она была задумана.\n\nФункции мультиплеера, такие как таймер, всё ещё доступны,\nно могут быть отключены в настройках лобби.",
			k_mp_ruleset_expanded_description = "Сбалансированные правила мультиплеера.\n\nВключает джокеров мультиплеера и изменения баланса\nс полным контролем настроек лобби.\n\n(Смотрите вкладки с банами и изменениями)",
			k_experimental = "Экспериментальный",
			k_traditional = "Традиционный",
			k_traditional_description = "Контент мультиплеера без временного давления.\n\nВключает джокеров мультиплеера и изменения баланса,\nно убирает механики, основанные на времени, для размеренной игры.\n\nДжокеры, зависящие от времени, запрещены.\nТаймер отключён.\n\n(Смотрите вкладки с банами и изменениями)",
			k_majorleague = "Major League",
			k_majorleague_description = "Официальные правила Major League Balatro.\n\nВанильные карты с соревновательными настройками:\n- Таймер 180 секунд\n- The Order отключён\n- Первый тайм-аут прощается\n- Режим игры: Истощение",
			k_minorleague = "Minor League",
			k_minorleague_description = "Официальные правила Minor League Balatro.\n\nВанильные карты с соревновательными настройками:\n- Таймер 210 секунд\n- The Order включён\n- Первый тайм-аут прощается\n- Режим игры: Истощение",
			k_mp_ruleset_balanced_description = "Официальные соревновательные правила.\n\nСтандартные правила с заблокированными настройками:\n- Режим игры: Истощение\n- The Order включён\n- Требуется рекомендуемая версия Steamodded",
			k_legacy_ranked = "Устаревший рейтинг",
			k_legacy_ranked_description = "Минимальные соревновательные правила.\n\nБез карт мультиплеера или изменений баланса,\nкроме стекла. Заблокированные настройки:\n- Режим игры: Истощение\n- The Order включён\n- Требуется рекомендуемая версия Steamodded",
			k_experimental_balanced = "Экспериментальный (Стандартный)",
			k_experimental_description = "Передовой край Стандартного.\n\nБолее серьёзные изменения баланса, тестируемые\nдля будущего Стандартного набора правил.\nОжидайте изменений между версиями.\n\n(Смотрите вкладки с банами и изменениями)",
			k_experimental_legacy = "Экспериментальный (Классический)",
			k_experimental_legacy_description = "Субъективный взгляд на Устаревший рейтинг.\n\nСтекло ослаблено, Ещё разок переработан, Правосудие запрещено,\nВращайте барабан.",
			k_badlatro = "Плохлатро",
			k_badlatro_description = "Еженедельный набор правил от @dr_monty_the_snek с discord-сервера,\nдобавленный в мод на постоянной основе.\n\nЭтот набор правил запрещает 48 джокеров, расходников, тегов и т.д.",
			k_attrition = "Истощение",
			k_weekly = "Недельный",
			k_weekly_description = "Особый набор правил, меняющийся еженедельно или раз в две недели. Придётся узнать самим! Сейчас: ",
			k_smallworld = "Мир тесен",
			k_smallworld_description = "Мир тесен.\n\n75% джокеров, расходников, ваучеров и тегов\nслучайно запрещены в каждой игре.\n\nЗапрещённые предметы заменяются доступными.\nДубли разрешены.",
			k_speedlatro = "Спидлатро",
			k_speedlatro_description = "Ускорьте темп с неудобно быстрым таймером в 147 секунд между\nкаждым PvP блайндом. Удачи с Vagabond.",
			k_chaos = "Хаос",
			k_chaos_description = "Всё, везде и сразу.\n\nОбъединяет Стандартный, «Мир тесен», Песочницу и таймер Спидлатро\nв один набор правил. Удачи.",
			k_release = "Релизная вер.",
			k_release_description = "Аллан, пожалуйста, добавь детали",
			k_mp_ruleset_tab_general = "Общие",
			k_mp_ruleset_tab_tournaments = "Турниры",
			k_mp_ruleset_tab_experimental = "Экспериментальные",
			k_cost_up = "Удорожание",
			k_destabilized = "Дестабилизирован",
			k_oops_ex = "Упс!",
			k_asteroids = "Астероиды",
			k_amount_short = "Кол-во",
			k_filed_ex = "Заархивировано!",
			k_timer = "Таймер",
			k_mods_list = "Список модов",
			k_enemy_jokers = "Джокеры противника",
			k_your_jokers = "Ваши джокеры",
			k_nemesis_deck = "Колода противника",
			k_your_deck = "Ваша колода",
			k_customization = "Настройка",
			k_the_order_credit = "*Автор: @MathIsFun_",
			k_the_order_integration_desc = "Это изменит создание карт, чтобы оно не было основано на анте и использовало единый пул для каждого типа/редкости",
			k_preview_credit = "*Авторы: @Fantom, @Divvy",
			k_preview_integration_desc = "Это включит предпросмотр счёта перед сыгранной рукой",
			k_requires_restart = "*Требуется перезапуск для применения",
			k_cocktail_select = "Выберите колоды, чтобы включить их",
			k_cocktail_shiftclick = "Shift+клик для фольги, фольгированные колоды будут выбраны всегда",
			k_cocktail_rightclick = "Правый клик для выбора всех",
			k_bans = "Баны",
			k_reworks = "Изменения",
			k_edit = "Править",
			k_ruleset_disabled_the_order_required = "The Order обязателен",
			k_ruleset_disabled_the_order_banned = "The Order запрещён",
			k_ruleset_not_found = "Неизвестный набор правил",
			k_tutorial_not_complete = "Вы должны пройти обучение, прежде чем играть в мультиплеер",
			k_created_by = "Создатель",
			k_major_contributors = "Основной вклад",
			ml_enemy_loc = {
				"Локация",
				"противника",
			},
			k_show_mp_content_anyway = "Скрыть контент мультиплеера*",
			k_applies_singleplayer_vanilla_rulesets = "*Применяется в одиночной игре и ванильных наборах правил",
			k_timer_sfx = "Звуковые эффекты таймера",
			ml_mp_kofi_message = {
				"Этот мод и игровой сервер",
				"разработаны и поддерживаются",
				"одним человеком, если",
				"он вам нравится, подумайте о",
			},
			ml_lobby_info = {
				"Инфо",
				"лобби",
			},
			ml_mp_timersfx_opt = {
				"Вкл",
				"Раз за Анте",
				"Выкл",
			},
			ml_mp_modifier_timer_opt = {
				"По умолчанию",
				"Без анимаций",
				"Pressure",
				"Pressure+",
			},
			k_sc_title = "БЫСТРЫЕ КЛАВИШИ",
			k_sc_hint = "Нажмите клавишу или отпустите TAB для закрытия",
			b_sc_choose_deck = "Выбрать колоду/ставку",
			loc_ready = "Готов к PvP",
			loc_selecting = "Выбирает",
			loc_shop = "В магазине",
			loc_playing = "Играет",
		},
		v_dictionary = {
			a_mp_art = {
				"Дизайн: #1#",
			},
			a_mp_code = {
				"Код: #1#",
			},
			a_mp_idea = {
				"Идея: #1#",
			},
			a_mp_skips_ahead = {
				"Впереди на #1# пропусков",
			},
			a_mp_skips_behind = {
				"Позади на #1# пропусков",
			},
			a_mp_skips_tied = {
				"Равны",
			},
			k_banned_objs = "Запрещено #1#",
			k_no_banned_objs = "Нет запрещённых #1#",
			k_reworked_objs = "Изменено #1#",
			k_no_reworked_objs = "Нет изменённых #1#",
			k_ruleset_disabled_smods_version = "Требуется SMODS версии #1#",
			k_ruleset_disabled_lovely_version = "Требуется Lovely #1#",
			k_failed_to_join_lobby = "Не удалось подключиться к лобби: #1#",
			k_ante_number = "Анте #1#",
			k_ante_min = "Анте #1#+",
			k_credits_list = "#1# и многие другие!",
		},
		v_text = {
			ch_c_hanging_chad_rework = {
				"{C:attention}Надорванный бюллетень{} {C:dark_edition}переработан",
			},
			ch_c_glass_cards_rework = {
				"{C:attention}Стеклянные карты{} {C:dark_edition}переработаны",
			},
			ch_c_mp_score_instability = {
				"Несбалансированный счёт {C:purple}дестабилизирован{} далее:",
			},
			ch_c_mp_score_instability_EXAMPLE = {
				"  {C:inactive}(пример: {C:chips}30{C:inactive}x{C:mult}24{C:inactive} -> {C:chips}36{C:inactive}x{C:mult}18{C:inactive})",
			},
			ch_c_mp_score_instability_LOC1 = {
				"  {C:inactive}Минимум {C:attention}1 {C:mult}множ.",
			},
			ch_c_mp_score_instability_LOC2 = {
				"  {C:inactive}Минимум {C:attention}0 {C:chips}Фишек",
			},
			ch_c_mp_ante_scaling = {
				"{C:red}X#1#{} базовый размер Блайнда",
			},
			ch_c_mp_no_shop_planets = {
				"{C:planet}Планеты{} больше не появляются в {C:attention}магазине",
			},
			ch_c_mp_only_medium = {
				"Все {C:spectral}Спектральные{} карты — это {C:spectral}Медиумы{}",
			},
			ch_c_mp_only_purple_seals = {
				"Все {C:attention}печати{} — {C:purple}Фиолетовые печати{}",
			},
			ch_c_mp_sibyl_CREDITS = {
				"{C:inactive}(Арт: {C:attention}Ganpan14O{C:inactive})",
			},
			ch_c_mp_polymorph_spam = {
				"При выборе блайнда все {C:attention}Джокеры{} и {C:attention}Расходники{}",
			},
			ch_c_mp_polymorph_spam_EXTENDED1 = {
				"превращаются в {C:attention}N{}-ю следующую карту в своей коллекции,",
			},
			ch_c_mp_polymorph_spam_EXTENDED2 = {
				"где {C:attention}N{} — её текущая позиция в слотах",
			},
			ch_c_mp_vantablack_CREDITS = {
				"{C:inactive}(Арт: {C:attention}aura!{C:inactive})",
			},
			ch_c_mp_indigo = {
				"Сыграно на {C:attention}Индиго-колоде{}",
			},
			ch_c_mp_shop_planets = {
				"{C:planet}Планетные{} карты появляются",
			},
			ch_c_mp_shop_planets_EXTENDED = {
				"{C:attention}40X{} чаще в магазине",
			},
			ch_c_mp_planet_tycoon_CREDITS = {
				"{C:inactive}(Идея: {C:attention}BlockAttack{C:inactive})",
			},
			ch_c_mp_eeeee = {
				"Некоторые случайно выбранные RNG очереди {C:attention}сломаны{} в каждом Анте",
			},
		},
		challenge_names = {
			c_mp_standard = "Стандартный",
			c_mp_sandbox = "Песочница",
			c_mp_badlatro = "Плохлатро",
			c_mp_tournament = "Турнир",
			c_mp_weekly = "Недельный",
			c_mp_vanilla = "Ванилла",
			c_mp_misprint_deck = "Колода с опечаткой",
			c_mp_legendaries = "Легендарки",
			c_mp_psychosis = "Психоз",
			c_mp_scratch = "С нуля",
			c_mp_twin_towers = "Башни-близнецы",
			c_mp_in_the_red = "В минусе",
			c_mp_paper_money = "Бумажные деньги",
			c_mp_high_hand = "Старшая рука",
			c_mp_chore_list = "Список дел",
			c_mp_oops_all_jokers = "Упс! Все джокеры",
			c_mp_divination = "Гадание",
			c_mp_skip_off = "Проскок",
			c_mp_lets_go_gambling = "Вращайте барабан",
			c_mp_speed = "Скорость",
			c_mp_balancing_act = "Балансирование",
			c_mp_salvaged_sibyl = "Восстановленная Сивилла",
			c_mp_polymorph_spam = "Polymorph Spam",
			c_mp_all_must_go = "Всё должно уйти",
			c_mp_vantablack = "Vantablack",
			c_mp_planet_tycoon = "Planet Tycoon",
			c_mp_bacon = "Синий лёд",
			c_mp_eeeee = "EEEEE",
		},
	},
}
