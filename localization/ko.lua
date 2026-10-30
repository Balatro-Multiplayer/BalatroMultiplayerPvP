return {
	descriptions = {
		Tag = {
			tag_mp_gambling_sandbox = {
				name = "갬블링 태그",
				text = {
					"{C:green}#1# / #2#{} 확률",
					"상점에서 무료",
					"{C:red}레어 조커{} 획득",
				},
			},
			tag_mp_juggle_sandbox = {
				name = "저글 태그",
				text = {
					"다음 {C:attention}PvP 블라인드{}에서",
					"손패 크기 {C:attention}+#1#{}",
				},
			},
			tag_mp_investment_sandbox = {
				name = "인베스트먼트 태그",
				text = {
					"보스 블라인드를 처치한 뒤 획득:",
					"{C:money}$#1#{} + {C:money}$#2#{} (앤티당)",
					"{C:inactive}(현재 {C:money}$#3#{C:inactive})",
				},
			},
		},

		Joker = {
			j_broken = {
				name = "BROKEN",
				text = {
					"이 카드는 고장났거나,",
					"현재 사용 중인 모드 버전에",
					"아직 구현되지 않았습니다.",
				},
			},

			j_mp_defensive_joker = {
				name = "디펜시브 조커",
				text = {
					"{X:purple,C:white}Nemesis{}보다 {C:red,E:1}라이프{}가",
					"적을 때마다 {C:chips}+#1#{} 칩",
					"{C:inactive}(현재 {C:chips}+#2#{C:inactive} 칩)",
					"{C:inactive}(스테이크에 따라 달라짐)",
				},
			},

			j_mp_skip_off = {
				name = "스킵-오프",
				text = {
					"{X:purple,C:white}Nemesis{}보다 더 많이 스킵한",
					"추가 {C:attention}블라인드{} 1개당",
					"{C:blue}+#1#{} 핸드, {C:red}+#2#{} 디스카드",
					"{C:inactive}(현재 {C:blue}+#3#{C:inactive}/{C:red}+#4#{C:inactive}, #5#)",
				},
			},

			j_mp_lets_go_gambling = {
				name = "렛츠 고 갬블링",
				text = {
					"{C:green}#1# / #2#{} 확률로",
					"{X:mult,C:white}X#3#{} 배수 + {C:money}$#4#{}",
					"{C:green}#5# / #6#{} 확률로",
					"{C:attention}PvP 블라인드{}에서",
					"{X:purple,C:white}Nemesis{}에게 {C:money}$#7#{} 지급",
				},
			},

			j_mp_speedrun = {
				name = "SPEEDRUN",
				text = {
					"{X:purple,C:white}Nemesis{}보다 먼저",
					"{C:attention}PvP 블라인드{}에 도달하면",
					"무작위 {C:spectral}스펙트럴{} 카드 1장 생성",
					"{C:inactive}(공간이 있어야 함)",
				},
			},

			j_mp_conjoined_joker = {
				name = "컨조인드 조커",
				text = {
					"{C:attention}PvP 블라인드{} 중일 때,",
					"{X:purple,C:white}Nemesis{}의 남은 {C:blue}핸드{} 1개당",
					"{X:mult,C:white}X#1#{} 배수 획득",
					"{C:inactive}(최대 {X:mult,C:white}X#2#{C:inactive}, 현재 {X:mult,C:white}X#3#{C:inactive})",
				},
			},

			j_mp_penny_pincher = {
				name = "페니 핀처",
				text = {
					"라운드 종료 시, {X:purple,C:white}Nemesis{}가",
					"해당 상점에서 {C:attention}지난 앤티{}에 사용한 금액",
					"{C:money}$#2#{}마다 {C:money}$#1#{} 획득",
				},
			},

			j_mp_taxes = {
				name = "택스",
				text = {
					"마지막 {C:attention}PvP 블라인드{} 이후",
					"{X:purple,C:white}Nemesis{}가 {C:attention}판매{}한 카드 1장당",
					"{C:mult}+#1#{} 배수 획득",
					"{C:attention}PvP 블라인드{} 선택 시 갱신",
					"{C:inactive}(현재 {C:mult}+#2#{C:inactive})",
				},
			},

			j_mp_pizza = {
				name = "피자",
				text = {
					"다음 {C:attention}PvP 블라인드{} 종료 시",
					"이 조커를 소모하고",
					"당신에게 {C:red}+#1#{} 디스카드,",
					"{X:purple,C:white}Nemesis{}에게 {C:red}+#2#{} 디스카드를",
					"이번 앤티 동안 부여",
				},
			},

			j_mp_pacifist = {
				name = "패시피스트",
				text = {
					"{C:attention}PvP 블라인드{}가 아닐 때",
					"{X:mult,C:white}X#1#{} 배수",
				},
			},

			j_mp_hanging_chad = {
				name = "행잉 채드",
				text = {
					"점수 계산에 사용된",
					"{C:attention}첫 번째{}와 {C:attention}두 번째{}로 낸 카드를",
					"{C:attention}추가로 #1#회{} 재발동",
				},
			},

			j_mp_bloodstone = {
				name = "블러드스톤",
				text = {
					"{C:green}#1# / #2#{} 확률로",
					"{C:hearts}하트{} 문양의 플레이된 카드가",
					"점수 계산 시 {X:mult,C:white}X#3#{} 배수 제공",
				},
			},

			j_mp_magnet_sandbox = {
				name = "마그넷",
				text = {
					"{C:attention}#1#{} 라운드 후 이 카드를 판매하면",
					"{X:purple,C:white}Nemesis{}의 최고 판매가 {C:attention}조커{}를 {C:attention}복사{}",
					"{C:attention}#3#{} 라운드 후 극성(polarity)이 반전되어",
					"쓸모없는 고철이 되어버림!!!!",
					"{C:inactive}(현재 {C:attention}#2#{C:inactive}/#1# 라운드)",
				},
			},

			j_mp_cloud_9_sandbox = {
				name = "클라우드 9",
				text = {
					"숫자 단일재배 농부",
					"당신의 다양한 덱을",
					"수익성 좋은 9번 농장으로 바꿔버림!!!!",
					"{C:inactive}({C:green}#1# / #2#{} {C:inactive}확률, 현재 {C:money}$#3#{}{C:inactive})",
				},
			},

			j_mp_lucky_cat_sandbox = {
				name = "럭키 캣",
				text = {
					"행운 → 취약성 파이프라인 운영자",
					"럭키 캣이 글래스 캣이 되어",
					"지수적으로 강해진다!!!!",
					"{C:inactive}(현재 {X:mult,C:white}X#2#{C:inactive})",
				},
			},

			j_mp_constellation_sandbox = {
				name = "컨스텔레이션",
				text = {
					"행성 관리 불안장애",
					"다마고치에게 먹이를 줘야 한다",
					"안 그러면 시들어버림!!!!",
					"{C:inactive}(현재 {X:mult,C:white}X#1#{C:inactive})",
				},
			},

			j_mp_bloodstone_sandbox = {
				name = "블러드스톤",
				text = {
					"{V:1}패치노트 퇴행 증후군",
					"출시일 트라우마로 되돌아가",
					"추억의 {X:mult,C:white}X#3#{} 파워 스파이크!!!!",
					"{C:inactive}({C:green}#1# / #2#{} {C:inactive}확률)",
				},
			},

			j_mp_juggler_sandbox = {
				name = "저글러",
				text = {
					"손패 크기 완벽주의자",
					"모든 카드를",
					"언제나 공중에 띄워야만 한다!!!!",
					"{C:inactive}(현재 손패 크기 {C:attention}+#1#{C:inactive})",
				},
			},

			j_mp_mail_sandbox = {
				name = "메일-인 리베이트",
				text = {
					"버린 {C:attention}#2#{} 1장당",
					"{C:money}$#1#{} 획득",
					"{s:0.8}랭크는 절대 바뀌지 않음",
				},
			},

			j_mp_hit_the_road_sandbox = {
				name = "히트 더 로드",
				text = {
					"버린 {C:attention}잭{} 1장당",
					"이 조커가 {X:mult,C:white}X0.75{} 배수를 획득",
					"버린 잭은 {C:attention}파괴{}됨",
					"{C:inactive}(현재 {X:mult,C:white}X#2#{C:inactive})",
				},
			},

			j_mp_misprint_sandbox = {
				name = "미스프린트",
				text = {
					"{V:1}#1#{} 배수",
					"{C:attention}구매 시 값이 공개됨{}",
					"{C:green}인쇄 오류는 누적된다{}",
				},
			},

			j_mp_castle_sandbox = {
				name = "캐슬",
				text = {
					"버린 {V:1}#1#{} 1장당",
					"이 조커가 {C:chips}#3{} 칩 획득",
					"문양은 구매 시 고정",
					"{C:inactive}(현재 {C:chips}+#2#{C:inactive} 칩)",
				},
			},

			j_mp_runner_sandbox = {
				name = "러너",
				text = {
					"연속 카드 우월주의자",
					"다른 모든 포커 핸드는",
					"열등하다고 믿는다!!!!",
					"{C:inactive}(현재 {C:chips}+#1#{C:inactive})",
				},
			},

			j_mp_order_sandbox = {
				name = "더 오더",
				text = {
					"낸 패에 {C:attention}스트레이트{}가 있으면 {X:mult,C:white}X3{} 배수",
					"연속으로 {C:attention}스트레이트{}를 낼 때마다 {X:mult,C:white}X#1#{} 배수 획득",
					"다른 패를 내면 초기화",
					"{C:inactive}(현재 {X:mult,C:white}X#2#{C:inactive})",
				},
			},

			j_mp_photograph_sandbox = {
				name = "포토그래프",
				text = {
					"한 손당 단 한 번의 완벽한 장면만을",
					"노리는 단발 촬영 사진가!!!!",
				},
			},

			j_mp_ride_the_bus_sandbox = {
				name = "라이드 더 버스",
				text = {
					"페이스 카드 금주 프로그램",
					"페이스 카드 한 장만 나와도",
					"버스에서 쫓겨난다!!!!",
					"{C:inactive}(현재 {C:mult}+#1#{C:inactive} 배수)",
				},
			},

			j_mp_loyalty_card_sandbox = {
				name = "로열티 카드",
				text = {
					"{C:attention}#1#{}를 {C:attention}#3#{}번 낼 때마다",
					"{X:mult,C:white}X6{} 배수",
					"{C:inactive}(#2#/#3#)",
				},
			},

			j_mp_faceless_sandbox = {
				name = "페이스리스 조커",
				text = {
					"엘리트 페이스 카드 소믈리에",
					"장인의",
					"3종 시음 플라이트를 큐레이팅해",
					"프리미엄 폐기 경험을 제공한다!!!!",
				},
			},

			j_mp_square_sandbox = {
				name = "스퀘어 조커",
				text = {
					"낸 패가 정확히 {C:attention}4{}장일 때",
					"이 조커가 {C:chips}+#2#{} 칩 획득",
					"{C:attention}4장 패에서만 적용{}",
					"{C:inactive}(현재 {C:chips}+#1#{C:inactive} 칩)",
				},
			},

			j_mp_throwback_sandbox = {
				name = "스로우백",
				text = {
					"이번 런에서 스킵한 {C:attention}블라인드{} 1개당",
					"기본 배수 {X:mult,C:white}X#2#{}",
					"스킵 직후 다음 블라인드에 {X:mult,C:white}X#3#{} 배수",
					"블라인드를 스킵하지 않으면 {X:mult,C:white}X#4#{} 배수 감소",
					"{C:inactive}(현재 {X:mult,C:white}X#1#{C:inactive})",
				},
			},

			j_mp_vampire_sandbox = {
				name = "뱀파이어",
				text = {
					"점수 계산에 사용된 {C:attention}강화 카드{} 1장당",
					"이 조커가 {X:mult,C:white}X#1#{} 배수 획득",
					"플레이된 강화 카드는 {C:attention}스톤{}으로 변함",
					"스톤 카드는 플레이 시 {C:money}$#3#{} 획득",
					"{C:inactive}(현재 {X:mult,C:white}X#2#{C:inactive})",
				},
			},

			j_mp_baseball_sandbox = {
				name = "베이스볼 카드",
				text = {
					"{C:green}언커먼{} 조커는 각각",
					"{X:mult,C:white}X#1#{} 배수 제공",
				},
			},

			j_mp_steel_joker_sandbox = {
				name = "스틸 조커",
				text = {
					"플레이된 스틸 카드를",
					"{C:attention}재발동{}",
				},
			},

			j_mp_satellite_sandbox = {
				name = "새틀라이트",
				text = {
					"만성 위성 열화 불안",
					"행성 업그레이드를 꾸준히 하지 않으면",
					"인프라가 서서히 무너져내린다!!!!",
					"{C:inactive}(현재 {C:money}$#1#{C:inactive})",
				},
			},

			j_mp_idol_sandbox_zealot = {
				name = "질럿 아이돌",
				text = {
					"플레이된 {C:attention}#1#{}마다",
					"점수 계산 시 {X:mult,C:white}X#2#{} 배수 제공",
					"{s:0.8}카드는 라운드마다 바뀜",
				},
			},
			j_mp_idol_sandbox_collector = {
				name = "메타 아이돌",
				text = {
					"가장 흔한 카드가 점수 계산 시",
					"{X:mult,C:white}X#3#{} 배수 제공",
					"({X:mult,C:white}+X#4#{} : 덱 내 해당 카드 1장당)",
					"{C:inactive}(현재 {C:attention}#1#{} / {V:1}#2#{})",
				},
			},

			j_mp_error_sandbox = {
				name = "????",
				text = {
					"{X:purple,C:white,s:0.85}뭔가{} {X:purple,C:white,s:0.85}잘못됐다",
				},
			},
		},

		Planet = {
			c_mp_asteroid = {
				name = "애스터로이드",
				text = {
					"{C:attention}PvP 블라인드{} 시작 시",
					"{X:purple,C:white}Nemesis{}의",
					"가장 높은 레벨의 {C:legendary,E:1}포커 핸드{}에서",
					"레벨 {C:attention}#1#{} 감소",
				},
			},
		},

		Blind = {
			bl_mp_nemesis = {
				name = "네메시스",
				text = {
					"다른 플레이어와 대결",
					"칩이 더 많은 쪽이 승리",
				},
			},
		},



		Back = {
			b_mp_cocktail = {
				name = "칵테일 덱",
				text = {
					"{C:attention}3{}개의 다른 덱 효과를",
					"무작위로 복사",
				},
			},

			b_mp_gradient = {
				name = "그라디언트 덱",
				text = {
					"카드는 모든 {C:attention}조커{} 효과에 대해",
					"랭크가 {C:attention}1{} 높거나",
					"{C:attention}1{} 낮은 것으로 취급됨",
				},
			},

			b_mp_heidelberg = {
				name = "하이델베르크 덱",
				text = {
					"{C:attention}상점{} 종료 시",
					"보유 중인 무작위 {C:attention}소모품{} 카드",
					"{C:attention}1{}장에",
					"{C:dark_edition}네거티브{} 복사본 생성",
				},
			},

			b_mp_indigo = {
				name = "인디고 덱",
				text = {
					"모든 부스터 팩에서",
					"카드를 {C:attention}+1{}장 더 선택",
					"부스터 팩은 {C:attention}스킵 불가{}",
				},
			},

			b_mp_oracle = {
				name = "오라클 덱",
				text = {
					"런 시작 시 {C:spectral,T:c_medium}미디엄{}과",
					"{C:attention,T:v_clearance_sale}클리어런스 세일{} 획득",
					"보유 금액 상한:",
					"{C:money}$50{} + 현재 이자 상한",
				},
			},

			b_mp_orange = {
				name = "오렌지 덱",
				text = {
					"런 시작 시",
					"{C:attention,T:p_mp_standard_giga}기가 스탠다드 팩{}과",
					"{C:attention}2{}장의",
					"{C:tarot,T:c_hanged_man}행드 맨{} 획득",
				},
			},

			b_mp_violet = {
				name = "바이올렛 덱",
				text = {
					"상점에 {C:attention}+1{} 바우처",
					"{C:attention}앤티 1{} 동안",
					"바우처 {C:attention}50%{} 할인",
				},
			},

			b_mp_white = {
				name = "화이트 덱",
				text = {
					"{X:purple,C:white}Nemesis{}의",
					"현재 덱과 조커 구성을 확인",
					"{C:inactive}(PvP 블라인드 시 갱신)",
				},
			},
		},

		Other = {
			current_nemesis = {
				name = "네메시스",
				text = {
					"{X:purple,C:white}#1#{}",
					"당신의 유일한 네메시스",
				},
			},

			p_mp_standard_giga = {
				name = "기가 스탠다드 팩",
				text = {
					"최대 {C:attention}#2#{}장의",
					"{C:attention}플레이 카드{} 중",
					"{C:attention}#1#{}장 선택하여",
					"덱에 추가",
					"{C:attention}스킵 불가{}",
				},
			},

			mp_transmutations = {
				name = "변환",
				text = {
					"{C:purple,s:1.1}다음으로 변환됨:",
				},
			},
			mp_internal_sell_value = {
				name = "판매가",
				text = {
					"{C:money,s:1.3}$#1#",
				},
			},

			mp_sticker_persistent = {
				name = "영구",
				text = {
					"파괴될 수 없음",
					"판매 시 {C:red}${} 소모",
					"라운드 종료 시",
					"{C:red}$3{}만큼 비용 증가",
				},
			},

			mp_sticker_unreliable = {
				name = "불안정",
				text = {
					"{C:attention}마지막 핸드{}에서는",
					"발동하지 않음",
				},
			},

			mp_sticker_draining = {
				name = "흡수",
				text = {
					"{X:mult,C:white}X0.75{} 배율",
				},
			},
		},

		Stake = {
			stake_mp_planet = {
				name = "플래닛 스테이크",
				text = {
					"{C:black}블랙 스테이크{} 효과 적용, 추가로:",
					"상점에 {C:attention}퍼리셔블{} 조커 등장 가능",
					"{C:inactive,s:0.8}(5라운드 후 디버프)",
					"요구 점수가",
					"{C:attention}앤티{}마다 더 빠르게 증가",
				},
			},

			stake_mp_spectral = {
				name = "스펙트럴 스테이크",
				text = {
					"{C:planet}플래닛 스테이크{} 효과 적용, 추가로:",
					"{C:money}렌탈{} 조커가 상점에 등장",
					"요구 점수가",
					"{C:attention}앤티{}마다 더 빠르게 증가",
				},
			},

			stake_mp_spectralplus = {
				name = "스펙트럴+ 스테이크",
				text = {
					"{C:planet}스펙트럴 스테이크{} 효과 적용, 추가로:",
					"요구 점수가",
					"{C:attention}앤티{}마다 훨씬 더 빠르게 증가",
				},
			},
			stake_mp_plastic = {
				name = "플라스틱 스테이크",
				text = {
					"{C:money}$10{}당 이자 {C:money}$1{} 획득",
					"{C:inactive,s:0.8}(최대 {C:money,s:0.8}$50{C:inactive,s:0.8})",
					"{s:0.8}화이트 스테이크 효과 적용",
				},
			},

			stake_mp_pebble = {
				name = "페블 스테이크",
				text = {
					"요구 점수가",
					"{C:attention}앤티{}마다 더 빠르게 증가",
					"{s:0.8}플라스틱 스테이크 효과 적용",
				},
			},

			stake_mp_ferrite = {
				name = "페라이트 스테이크",
				text = {
					"특정 조커가 {C:attention}영구{} 상태가 됨",
					"{C:inactive,s:0.8}(파괴 불가, 판매 비용 증가)",
					"{s:0.8}페블 스테이크 효과 적용",
				},
			},

			stake_mp_pyrite = {
				name = "파이라이트 스테이크",
				text = {
					"리롤 가격이",
					"리롤할 때마다 {C:money}$2{}씩 증가",
					"{s:0.8}페라이트 스테이크 효과 적용",
				},
			},

			stake_mp_jade = {
				name = "제이드 스테이크",
				text = {
					"요구 점수가",
					"{C:attention}앤티{}마다 더 빠르게 증가",
					"{s:0.8}파이라이트 스테이크 효과 적용",
				},
			},

			stake_mp_crystal = {
				name = "크리스탈 스테이크",
				text = {
					"특정 조커가 {C:attention}불안정{} 상태가 됨",
					"{C:inactive,s:0.8}({C:attention,s:0.8}마지막 핸드{C:inactive,s:0.8}에서는 발동하지 않음)",
					"{s:0.8}제이드 스테이크 효과 적용",
				},
			},

			stake_mp_antimatter = {
				name = "안티매터 스테이크",
				text = {
					"특정 조커가 {C:attention}흡수{} 상태가 됨",
					"{C:inactive,s:0.8}({X:mult,C:white,s:0.8}X0.75{C:inactive,s:0.8} 배율)",
					"{s:0.8}크리스탈 스테이크 효과 적용",
				},
			},
		},

		Spectral = {
			c_mp_ouija_sandbox = {
				name = "위자",
				text = {
					"무작위 카드 {C:attention}#1#{}장 파괴 후",
					"남은 모든 카드를",
					"무작위 {C:attention}랭크{} 하나로 변환",
				},
			},

			c_mp_ectoplasm_sandbox = {
				name = "엑토플라즘",
				text = {
					"무작위 {C:attention}조커{} 1장에",
					"{C:dark_edition}네거티브{} 부여",
					"다음 중 하나 무작위 적용:",
					"{C:red}-1{} 핸드, {C:red}-1{} 버림, 또는 {C:red}-1{} 손패 크기",
				},
			},
		},
	},

	misc = {

		challenge_names = {
			c_mp_standard = "스탠다드",
			c_mp_sandbox = "샌드박스",
			c_mp_badlatro = "배드라트로",
			c_mp_tournament = "토너먼트",
			c_mp_weekly = "위클리",
			c_mp_vanilla = "바닐라",
		},

		dictionary = {
			b_singleplayer = "싱글플레이",
			b_join_lobby = "로비 참가",
			b_join_lobby_clipboard = "클립보드로 참가",
			b_return_lobby = "로비로 돌아가기",
			b_reconnect = "재접속",
			b_create_lobby = "로비 생성",
			b_start_lobby = "로비 시작",
			b_ready = "준비",
			b_unready = "준비 해제",
			b_leave_lobby = "로비 나가기",
			b_mp_discord = "Balatro Multiplayer 디스코드 서버",
			b_start = "시작",
			b_wait_for_host_start = {
				"대기 중:",
				"호스트 시작",
			},
			b_wait_for_players = {
				"대기 중:",
				"플레이어",
			},
			b_wait_for_guest_ready = {
				"대기 중:",
				"게스트 준비",
			},
			b_lobby_options = "로비 옵션",
			b_copy_clipboard = "클립보드로 복사",
			b_view_code = "코드 보기",
			b_copy_code = "코드 복사",
			b_leave = "나가기",

			b_opts_cb_money = "생명를 잃으면 컴백 머니 지급",
			b_opts_no_gold_on_loss = "라운드 패배 시 블라인드 보상 없음",
			b_opts_death_on_loss = "PvP가 아닌 라운드 패배 시 생명 1개 잃음",
			b_opts_start_antes = "시작 앤티",
			b_opts_diff_seeds = "플레이어마다 시드가 다름",
			b_opts_lives = "Lives",
			b_opts_multiplayer_jokers = "멀티플레이어 카드 활성화",
			b_opts_player_diff_deck = "플레이어마다 덱이 다름",
			b_opts_normal_bosses = "보스 블라인드 효과 활성화",
			b_opts_timer = "타이머 활성화",
			b_opts_disable_preview = "점수 미리보기 비활성화",
			b_opts_the_order = "The Order 활성화",
			b_opts_legacy_smallworld = "레거시 Small World 메커니즘",

			b_reset = "초기화",
			b_set_custom_seed = "커스텀 시드 설정",
			b_mp_kofi_button = "Ko-fi로 후원하기",
			b_unstuck = "막힘 해제",
			b_unstuck_blind = "PvP 밖에서 막힘",
			b_misprint_display = "덱의 다음 카드 표시",
			b_players = "플레이어",
			b_lobby_info = "로비 정보",
			b_continue_singleplayer = "싱글플레이로 계속",
			b_the_order_integration = "The Order 연동 활성화",
			b_preview_integration = "점수 미리보기 활성화",
			b_view_nemesis_deck = "덱 보기",
			b_toggle_jokers = "조커 토글",
			b_skip_tutorial = "튜토리얼 건너뛰기",

			k_yes = "예",
			k_no = "아니요",
			k_are_you_sure = "정말로 하시겠습니까?",
			k_has_multiplayer_content = "멀티플레이어 콘텐츠 포함",
			k_forces_lobby_options = "로비 옵션 강제",
			k_forces_gamemode = "게임모드 강제",
			k_values_are_modifiable = "* 값은 변경될 수 있습니다",
			k_rulesets = "룰셋",
			k_gamemodes = "게임모드",
			k_competitive = "경쟁",
			k_other = "기타",
			k_battle = "배틀",
			k_challenge = "챌린지",
			k_info = "정보",

			k_continue_singleplayer_tooltip = "이 작업은 현재 싱글플레이 런을 덮어씁니다",
			k_enemy_score = "현재 상대 점수",
			k_enemy_hands = "상대 남은 핸드: ",
			k_coming_soon = "Coming Soon!",
			k_wait_enemy = "상대가 끝낼 때까지 대기 중...",

			k_lives = "Lives",
			k_lost_life = "생명를 잃었습니다",
			k_total_lives_lost = " 총 잃은 Lives ($4씩)",
			k_comeback_money_sandbox = " 컴백 머니 ($3 × 클리어한 앤티)",

			k_attrition_name = "어트리션",
			k_enter_lobby_code = "로비 코드 입력",
			k_paste = "클립보드에서 붙여넣기",
			k_username = "유저네임:",
			k_enter_username = "유저네임 입력",
			k_customize_preview = "미리보기 문구 커스터마이즈:",
			k_join_discord = "참여하기: ",
			k_discord_msg = "버그 신고와 함께 같이 플레이할 사람을 찾을 수 있어요",
			k_enter_to_save = "Enter를 눌러 저장",
			k_in_lobby = "로비에 있음",
			k_connected = "서비스에 연결됨",
			k_warn_service = "경고: 멀티플레이어 서비스를 찾을 수 없음",
			k_set_name = "메인 메뉴에서 유저네임을 설정하세요! (Mods > Multiplayer > Config)",

			k_mod_hash_warning = "플레이어들의 모드 또는 모드 버전이 다릅니다! 문제가 발생할 수 있어요!",
			k_steamodded_warning = "플레이어들의 Steamodded 버전이 다릅니다. 시드가 달라질 수 있어요.",
			k_warning_unlock_profile = "현재 플레이 중인 프로필이 완전히 해금되지 않았습니다. 랭크/토너먼트 게임이라면 새 프로필을 만들고 프로필 설정에서 'unlock all'을 눌러주세요.",
			k_warning_nemesis_unlock = "상대가 완전히 해금되지 않은 프로필로 플레이 중입니다. 새 프로필 생성 후 프로필 설정에서 'unlock all'을 누르도록 안내해주세요.",
			k_warning_no_order = "한 플레이어는 The Order 연동이 켜져 있고, 다른 플레이어는 꺼져 있습니다. 이 경우 시드가 달라질 수 있어요.",
			k_warning_cheating1 = "이 메시지가 보인다면, 상대가 치트를 쓰고 있을 수 있습니다.",
			k_warning_cheating2 = "랭크 게임이라면 '%s' 메시지를 보낸 뒤 #support에 지원 티켓을 열어주세요.",
			k_warning_banned_mods = "한 명 이상이 금지된 모드를 설치했습니다. 이런 모드는 랭크 게임에서 허용되지 않습니다.",

			k_message1 = "잠깐만, 우리 엄마가 피자팝을 만들어줬어",
			k_message2 = "1초만, 슬로우쿠커 돼지구이 좀 챙길게",
			k_message3 = "잠시만, 엄마한테 전화 왔어",
			k_message4 = "잠깐 비움, 우리 고양이가 불타고 있어",
			k_message5 = "잠깐, 나 가스불 안 껐나?",
			k_message6 = "잠깐만, 우리 애완용 돌이 도망갔어",
			k_message7 = "1초만, 내 식물들이 물 달래",
			k_message8 = "잠깐 비움, 내 양말들이 반란을 모의 중이야",
			k_message9 = "미안, 우리 와이파이가 실존적 위기를 겪는 중이야",

			k_lobby_options = "로비 옵션",
			k_connect_player = "연결된 플레이어:",
			k_opts_only_host = "로비 호스트만 이 옵션을 변경할 수 있습니다",
			k_lobby_general = "일반",
			k_lobby_gameplay = "게임플레이",
			k_lobby_modifiers = "수정치",
			k_lobby_advanced = "고급",

			k_opts_pvp_start_round = "PvP가 앤티에서 시작",
			k_opts_pvp_timer = "타이머",
			k_opts_pvp_timer_increment = "타이머 증가량",
			k_opts_pvp_countdown_seconds = "PvP 카운트다운(초)",
			k_bl_life = "생명",
			k_bl_or = "또는",
			k_bl_death = "죽음",
			k_bl_mostchips = "칩이 가장 많은 쪽이 승리",
			k_current_seed = "현재 시드: ",
			k_random = "무작위",
			k_standard = "스탠다드",
			k_sandbox = "샌드박스",
			k_sandbox_description = "질투심 많은 아이돌 셋이당신의 런을 두고 경쟁합니다.\n조커 일부가 특이한 효과로 교체되며\n게임 규칙이 크게 달라집니다.\n\n(자세한 내용은 위키 참고)",

			k_vanilla = "바닐라",
			k_vanilla_description = "Balatro의 오리지널 경험.\n멀티플레이어 전용 조커와밸런스 변경 없이\n기본 게임 그대로 플레이합니다.\n(멀티플레이어 기능은 옵션에서 비활성화 가능)",

			k_mp_ruleset_expanded_description = "균형 잡힌 멀티플레이어 룰셋.\n멀티플레이어 조커와밸런스 변경을 포함하며\n로비 설정을 자유롭게 조절할 수 있습니다.\n(자세한 내용은 금지/리워크 탭 참고)",

			k_traditional = "트래디셔널",
			k_traditional_description = "시간 압박 없는 멀티플레이어 룰셋.\n멀티플레이어 조커와밸런스 변경을 포함하지만\n시간 기반 요소는 제거됩니다.\n(자세한 내용은 금지/리워크 탭 참고)",

			k_majorleague = "메이저 리그",
			k_majorleague_description = "공식 메이저 리그 룰셋.\n\n경쟁 설정의 바닐라 카드로\n빠른 템포의 대전을 진행합니다.",

			k_minorleague = "마이너 리그",
			k_minorleague_description = "공식 마이너 리그 룰셋.\n\n메이저 리그보다\n조금 여유 있는 타이머로\n경쟁전을 진행합니다.",

			k_ranked = "랭크",
			k_ranked_description = "공식 경쟁 룰셋.\n\n설정이 고정된 스탠다드 규칙으로\n실력을 겨루는 모드입니다.\n\n(권장 Steamodded 버전 필요)",

			k_badlatro = "배드라트로",
			k_badlatro_description = "디스코드 커뮤니티에서 제작된\n주간 룰셋입니다.\n\n다수의 카드와 아이템이\n대규모로 금지됩니다.",

			k_attrition = "어트리션",



			k_weekly = "위클리",
			k_weekly_description = "주기적으로 변경되는\n특별 룰셋입니다.\n\n이번 주 규칙을 직접 확인하세요!",

			k_smallworld = "스몰 월드",
			k_smallworld_description = "조커, 소모품, 바우처,\n태그의 대부분이\n매 게임 무작위로 금지됩니다.\n\n중복은 허용됩니다.",

			k_speedlatro = "스피드라트로",
			k_speedlatro_description = "각 PvP 블라인드 사이에\n147초의 빠른 타이머가 적용됩니다.\n\n빠른 판단이 요구됩니다.",

			k_cost_up = "비용 증가",
			k_destabilized = "불안정화",
			k_oops_ex = "웁스!",
			k_asteroids = "소행성",
			k_amount_short = "수량",
			k_filed_ex = "접수 완료!",
			k_timer = "타이머",
			k_mods_list = "모드 목록",
			k_enemy_jokers = "상대 조커",
			k_your_jokers = "내 조커",
			k_nemesis_deck = "네메시스 덱",
			k_your_deck = "내 덱",
			k_customization = "커스터마이즈",
			k_the_order_credit = "*제작자: @MathIsFun_",
			k_the_order_integration_desc = "카드 생성을 앤티 기반이 아닌 단일 풀로 패치하여 모든 타입/희귀도를 공유합니다",
			k_preview_credit = "*제작자: @Fantom, @Divvy",
			k_preview_integration_desc = "핸드를 내기 전에 점수 미리보기를 활성화합니다",
			k_requires_restart = "*적용하려면 재시작이 필요합니다",
			k_cocktail_select = "포함할 덱 카드를 선택",
			k_cocktail_shiftclick = "Shift-클릭: 포일 처리 (포일 덱은 항상 선택됨)",
			k_cocktail_rightclick = "우클릭: 전체 선택",
			k_bans = "금지",
			k_reworks = "리워크",
			k_edit = "편집",
			k_ruleset_disabled_the_order_required = "The Order 필요",
			k_ruleset_disabled_the_order_banned = "The Order 금지됨",
			k_ruleset_not_found = "알 수 없는 룰셋",
			k_tutorial_not_complete = "멀티플레이어를 플레이하려면 튜토리얼을 완료해야 합니다",
			k_created_by = "제작",
			k_major_contributors = "주요 기여자",
			ml_enemy_loc = {
				"상대",
				"위치",
			},
			k_show_mp_content_anyway = "멀티플레이어 콘텐츠 숨기기*",
			k_applies_singleplayer_vanilla_rulesets = "*싱글플레이 및 바닐라 룰셋에도 적용",
			k_timer_sfx = "타이머 효과음",
			ml_mp_kofi_message = {
				"이 모드와 게임 서버는",
				"한 사람이 개발하고",
				"유지보수하고 있습니다.",
				"마음에 드신다면 후원을 고려해주세요",
			},

			k_bl_life = "라이프",
			loc_ready = "PvP 준비 완료",
			loc_selecting = "블라인드 선택 중",
			loc_shop = "쇼핑 중",
			loc_playing = "플레이 중 ",
		},
	},
	v_dictionary = {
		a_mp_art = {
			"아트: #1#",
		},
		a_mp_code = {
			"코드: #1#",
		},
		a_mp_idea = {
			"아이디어: #1#",
		},
		a_mp_skips_ahead = {
			"#1# 스킵 앞섬",
		},
		a_mp_skips_behind = {
			"#1# 스킵 뒤처짐",
		},
		a_mp_skips_tied = {
			"동률",
		},

		k_banned_objs = "금지된 #1#",
		k_no_banned_objs = "금지된 #1# 없음",
		k_reworked_objs = "리워크된 #1#",
		k_no_reworked_objs = "리워크된 #1# 없음",
		k_ruleset_disabled_smods_version = "SMODS 버전 #1# 필요",
		k_failed_to_join_lobby = "로비 참가 실패: #1#",

		k_ante_number = "앤티 #1#",
		k_ante_min = "앤티 #1#+",
		k_credits_list = "#1# 외 다수!",
	},

	v_text = {
		ch_c_hanging_chad_rework = {
			"{C:attention}행잉 채드{}가 {C:dark_edition}리워크{}되었습니다",
		},
		ch_c_glass_cards_rework = {
			"{C:attention}글래스 카드{}가 {C:dark_edition}리워크{}되었습니다",
		},
		ch_c_mp_score_instability = {
			"불균형한 점수가 {C:purple}더 불안정{}해집니다:",
		},
		ch_c_mp_score_instability_EXAMPLE = {
			"  {C:inactive}(예: {C:chips}30{C:inactive}x{C:mult}24{C:inactive} → {C:chips}36{C:inactive}x{C:mult}18{C:inactive})",
		},
		ch_c_mp_score_instability_LOC1 = {
			"  {C:inactive}{C:attention}최소 1 {C:mult}배수",
		},
		ch_c_mp_score_instability_LOC2 = {
			"  {C:inactive}{C:attention}최소 0 {C:chips}칩",
		},

		ch_c_mp_ante_scaling = {
			"{C:red}기본 블라인드 크기 X#1#",
		},
		ch_c_mp_no_shop_planets = {
			"{C:planet}플래닛{}이 {C:attention}상점{}에 더 이상 등장하지 않음",
		},
		ch_c_mp_only_medium = {
			"모든 {C:spectral}스펙트럴{} 카드가 {C:spectral}미디엄{}이 됨",
		},
		ch_c_mp_only_purple_seals = {
			"모든 {C:attention}실{}이 {C:purple}퍼플 실{}이 됨",
		},

		ch_c_mp_sibyl_CREDITS = {
			"{C:inactive}(아트: {C:attention}Ganpan14O{C:inactive})",
		},

		ch_c_mp_polymorph_spam = {
			"블라인드 선택 시, 보유 중인 모든 {C:attention}조커{}와 {C:attention}소모품{}이",
		},
		ch_c_mp_polymorph_spam_EXTENDED1 = {
			"컬렉션에서 다음 {C:attention}N{}번째 카드로 변환되며,",
		},
		ch_c_mp_polymorph_spam_EXTENDED2 = {
			"{C:attention}N{}은 현재 슬롯 위치입니다",
		},
	},

	challenge_names = {
		c_mp_standard = "스탠다드",
		c_mp_sandbox = "샌드박스",
		c_mp_badlatro = "배드라트로",
		c_mp_tournament = "토너먼트",
		c_mp_weekly = "위클리",
		c_mp_vanilla = "바닐라",
		c_mp_misprint_deck = "미스프린트 덱",
		c_mp_legendaries = "레전더리",
		c_mp_psychosis = "사이코시스",
		c_mp_scratch = "맨바닥부터",
		c_mp_twin_towers = "트윈 타워",
		c_mp_in_the_red = "적자",
		c_mp_paper_money = "지폐",
		c_mp_high_hand = "하이 핸드",
		c_mp_chore_list = "집안일 목록",
		c_mp_oops_all_jokers = "웁스! 전부 조커",
		c_mp_divination = "점술",
		c_mp_skip_off = "스킵-오프",
		c_mp_lets_go_gambling = "렛츠 고 갬블링",
		c_mp_speed = "스피드",
		c_mp_balancing_act = "균형 잡기",
		c_mp_salvaged_sibyl = "구출된 시빌",
		c_mp_polymorph_spam = "폴리모프 스팸",
	},
}
