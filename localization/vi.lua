-- Localization by @theambushingbush and @minotour4869
-- Bản dịch của HuyTheKiller và Minotour, yêu cầu cài thêm VietnameseBalatro
-- https://github.com/HuyTheKiller/VietnameseBalatro
return {
	descriptions = {
		Tag = {
			tag_mp_sandbox_rare = {
				name = "Nhãn Con Bạc",
				text = {
					"Xác suất {C:green}#1# trên #2#{}",
					"để shop có một {C:red}Joker Hiếm",
					"miễn phí",
				},
			},
			tag_mp_uncommon_release = {
				name = "Nhãn Ít Phổ Biến",
				text = {
					"Shop có một",
					"{C:green}Joker Ít Phổ Biến",
				},
			},
			tag_mp_rare_release = {
				name = "Nhãn Hiếm",
				text = {
					"Shop có một",
					"{C:red}Joker Hiếm",
				},
			},
			tag_mp_foil_release = {
				name = "Nhãn Ánh Kim",
				text = {
					"Joker bản chuẩn tiếp theo",
					"trở thành {C:dark_edition}Ánh Kim",
				},
			},
			tag_mp_holo_release = {
				name = "Nhãn Lấp Lánh",
				text = {
					"Joker bản chuẩn tiếp theo",
					"trở thành {C:dark_edition}Lấp Lánh",
				},
			},
			tag_mp_poly_release = {
				name = "Nhãn Đa Sắc",
				text = {
					"Joker bản chuẩn tiếp theo",
					"trở thành {C:dark_edition}Đa Sắc",
				},
			},
			tag_mp_negative_release = {
				name = "Nhãn Âm Bản",
				text = {
					"Joker bản chuẩn tiếp theo",
					"trở thành {C:dark_edition}Âm Bản",
				},
			},
		},
		Joker = {
			j_mp_seltzer = {
				name = "Khoáng Có Ga",
                text = {
                    "Tái kích mọi lá bài",
                    "đã chơi cho",
                    "{C:attention}#1#{} tay sắp tới",
                },
			},
			j_mp_turtle_bean = {
				name = "Đậu Đen",
                text = {
                    "{C:attention}+#1#{} lá giữ trong tay,",
                    "giảm đi {C:red}#2#{} mỗi ván"
                },
			},
			j_mp_idol = {
				name = "Thần Tượng",
                text = {
                    "Mỗi lá {C:attention}#2# {V:1}#3#",
                    "ghi thêm {X:mult,C:white} X#1# {} Nhân",
                    "khi ghi điểm",
                    "{s:0.8}Lá bài thay đổi sau mỗi ván"
                },
			},
			j_mp_idol_rare = {
				name = "Thần Tượng",
                text = {
                    "Mỗi lá {C:attention}#2# {V:1}#3#",
                    "ghi thêm {X:mult,C:white} X#1# {} Nhân",
                    "khi ghi điểm",
                    "{s:0.8}Lá bài thay đổi sau mỗi ván"
                },
			},
			j_mp_ticket = {
				name = "Tấm Vé Vàng",
                text = {
                    "Lá {C:attention}Vàng{} đã chơi nhận",
                    "thêm {C:money}$#1#{} khi ghi điểm",
                },
			},
			j_mp_ticket_experimental = {
				name = "Tấm Vé Vàng",
                text = {
                    "Lá {C:attention}Vàng{} đã chơi nhận",
                    "thêm {C:money}$#1#{} khi ghi điểm",
                },
			},
			j_mp_baron = {
				name = "Nam Tước",
                text = {
                    "Mỗi lá {C:attention}Già{} giữ",
                    "trong tay ghi thêm",
                    "{X:mult,C:white} X#1# {} Nhân",
                },
			},
			j_mp_mime = {
				name = "Kịch Câm",
                text = {
                    "Tái kích khả năng",
                    "của mọi lá bài {C:attention}giữ",
                    "{C:attention}trong tay"
                },
			},
			j_mp_todo_list = {
				name = "Danh Sách Công Việc",
                text = {
                    "Nhận {C:money}$#1#{} nếu {C:attention}tay poker",
                    "là {C:attention}#2#{},",
                    "tay poker thay đổi",
                    "ở cuối ván"
                },
			},
			j_broken = {
				name = "HỎNG",
				text = {
					"Lá này hoặc là bị hỏng, hoặc là",
					"chưa được thêm vào ở phiên bản",
					"hiện tại của một mod bạn đang sử dụng.",
				},
			},
			j_mp_defensive_joker = {
				name = "Joker Phòng Ngự",
				text = {
					"{C:chips}+#1#{} Chip cho mỗi {C:red,E:1}mạng{}",
					"ít hơn {X:purple,C:white}Đối_Thủ{}",
					"{C:inactive}(Hiện tại là {C:chips}+#2#{C:inactive} Chip)",
					"{C:inactive}(Phụ thuộc mức Cược)",
				},
			},
			j_mp_skip_off = {
				name = "Nhảy Lò Cò",
				text = {
					"{C:blue}+#1#{} Tay bài và {C:red}+#2#{} Lượt bỏ bài",
					"cho mỗi {C:attention}Blind{} đã bỏ qua",
					"nhiều hơn {X:purple,C:white}Đối_Thủ{}",
					"{C:inactive}(Hiện tại là {C:blue}+#3#{C:inactive}/{C:red}+#4#{C:inactive})",
				},
			},
			j_mp_lets_go_gambling = {
				name = "Cờ Bạc Là Bác Thằng Bần",
				text = {
					"Xác suất {C:green}#1# trên #2#{} được",
					"{X:mult,C:white}X#3#{} Nhân và {C:money}$#4#{}",
					"Xác suất {C:green}#5# trên #6#{} để cho",
					"{X:purple,C:white}Đối_Thủ{} {C:money}$#7#{} ở {C:attention}Blind Đối Đầu",
				},
			},
			-- j_mp_hanging_bad = {
			-- 	name = "Bêu Riếu",
			-- 	text = {
			-- 		"Ở {C:attention}Blind{} {X:purple,C:white}Đối Đầu{}",
			-- 		"lá đã chơi {C:attention}đầu tiên{} tính điểm",
			-- 		"bị {C:attention}vô hiệu{} cho cả hai người chơi",
			-- 	},
			-- },
			j_mp_speedrun = {
				name = "NHANH GỌN LẸ",
				text = {
					"Nếu bạn đến {C:attention}Blind Đối Đầu",
					"trước {X:purple,C:white}Đối_Thủ{}, tạo ra",
					"một lá {C:spectral}Siêu Linh{} ngẫu nhiên",
					"{C:inactive}(Phải có ô trống)",
				},
			},
			j_mp_conjoined_joker = {
				name = "Joker Kết Hợp",
				text = {
					"Khi ở {C:attention}Blind Đối Đầu{}, thêm",
					"{X:mult,C:white}X#1#{} Nhân cho mỗi {C:blue}Tay bài{}",
					"còn lại của {X:purple,C:white}Đối_Thủ{}",
					"{C:inactive}(Tối đa {X:mult,C:white}X#2#{C:inactive} Nhân, Hiện tại là {X:mult,C:white}X#3#{C:inactive} Nhân)",
				},
			},
			j_mp_penny_pincher = {
				name = "Kẻ Trộm Xu",
				text = {
					"Ở đầu shop, nhận {C:money}$#1#{}",
					"cho mỗi {C:money}$#2#{} mà {X:purple,C:white}Đối_Thủ{} đã tiêu",
					"ở cùng shop trong {C:attention}ante trước đó{}",
				},
			},
			j_mp_taxes = {
				name = "Thuế",
				text = {
					"Rhêm {C:mult}+#1#{} Nhân cho mỗi lá bài",
					"{X:purple,C:white}Đối_Thủ{} đã bán kể từ {C:attention}Blind Đối Đầu{}",
					"cập nhật khi {C:attention}Blind Đối Đầu{} được chọn",
					"{C:inactive}(Hiện tại là {C:mult}+#2#{C:inactive} Nhân)",
				},
			},
			j_mp_magnet = {
				name = "Nam Châm",
				text = {
					"Sau {C:attention}#1#{} ván, bán",
					"lá này để {C:attention}Sao Chép{}",
					"{C:attention}Joker{} có giá bán",
					"cao nhất của {X:purple,C:white}Đối_Thủ{}",
					"{C:inactive}(Hiện tại là {C:attention}#2#{C:inactive}/#3# ván)",
				},
			},
			j_mp_pizza = {
				name = "Pizza",
				text = {
					"Ở cuối {C:attention}Blind Đối Đầu{} tiếp theo,",
					"tiêu thụ Joker này và thêm",
					"{C:red}+#1#{} lượt bỏ bài cho bạn và",
					"{C:red}+#2#{} lượt bỏ bài cho {X:purple,C:white}Đối_Thủ{} trong ante này",
				},
			},
			j_mp_pacifist = {
				name = "Yêu Hoà Bình",
				text = {
					"{X:mult,C:white}X#1#{} Nhân khi",
					"không ở {C:attention}Blind Đối Đầu{}",
				},
			},
			j_mp_hanging_chad = {
				name = "Phiếu Đục Lỗ",
				text = {
					"Tái kích lá ghi điểm",
					"{C:attention}đầu tiên{} và {C:attention}thứ hai{}",
					"thêm {C:attention}#1#{} lần",
				},
			},
			-- j_mp_cloud_9 = {
			-- 	name = "Chín Tầng Mây",
			-- 	text = {
			-- 		"Nhận {C:money}$1{} cho mỗi lá {C:attention}9{} trong bộ bài",
			-- 		"(tối đa {C:money}$4{}) và thêm {C:money}$#1#{} cho mỗi",
			-- 		"lá {C:attention}9{} thêm ở cuối ván",
			-- 		"{C:inactive}(Hiện tại là {C:money}$#2#{}{C:inactive})",
			-- 	},
			-- },
			j_mp_bloodstone = {
				name = "Đá Đốm Đỏ",
				text = {
					"Xác suất {C:green}#1# trên #2#{} để",
					"lá bài đã chơi có",
					"chất {C:hearts}Cơ{} ghi thêm",
					"{X:mult,C:white} X#3# {} Nhân khi ghi điểm",
				},
			},
			j_mp_magnet_sandbox = {
				name = "Nam Châm",
				text = {
					"Sau {C:attention}#1#{} ván, bán",
					"lá này để {C:attention}Sao Chép {C:attention}Joker{} có",
					"giá bán cao nhất của {X:purple,C:white}Đối_Thủ{}",
					"nghịch đảo từ sau {C:attention}#3#{} ván",
					"TRỞ THÀNH CỤC SẮT VÔ DỤNG!!!!",
					"{C:inactive}(Hiện tại là {C:attention}#2#{C:inactive}/#1# ván)",
				},
			},
			j_mp_cloud_9_sandbox = {
				name = "Chín Tầng Mây",
				text = {
					"NÔNG DÂN ĐƠN CANH SỐ HỌC",
					"biến BỘ BÀI ĐA DẠNG thành",
					"BÃI TRỒNG CÂY CHÍN QUẢ!!!!",
					"{C:inactive}(xác suát {C:green}#1# trên #2#{} {C:inactive}, hiện tại là {C:money}$#3#{}{C:inactive})",
				},
			},
			j_mp_lucky_cat_sandbox = {
				name = "Mèo Thần Tài",
				text = {
					"BỘ CHUYỂN ĐỔI VẬN MAY THÀNH MONG MANH",
					"mèo thần tài trở thành MÈO THUỶ TINH",
					"với SỨC MẠNH CẤP SỐ NHÂN!!!!",
					"{C:inactive}(Hiện tại là {X:mult,C:white} X#2# {C:inactive} Nhân)",
				},
			},
			j_mp_constellation_sandbox = {
				name = "Chòm Sao",
				text = {
					"rối loạn lo âu bảo trì hành tinh",
					"PHẢI CHO TAMAGOCHI ĂN",
					"nếu không nó HẸO LUÔN ĐÓ!!!!",
					"{C:inactive}(Hiện tại là {X:mult,C:white} X#1# {C:inactive} Nhân)",
				},
			},
			j_mp_bloodstone_sandbox = {
				name = "Đá Đốm Đỏ",
				text = {
					"HỘI CHỨNG THOÁI LỤI BẢN VÁ",
					"trả về NỖI ÁM ẢNH NGÀY RA MẮT",
					"đế lấy SỨC MẠNH SIÊU CẤP HOÀI NIỆM!!!!",
					"{C:inactive}(Xác suất {C:green}#1# trên #2#{}{C:inactive})",
				},
			},
			j_mp_juggler_sandbox = {
				name = "Nười Tung Hứng",
				text = {
					"CẦU TOÀN LÁ TRÊN TAY",
					"cần phẩi cho MẤY LÁ BÀI",
					"LUÔN LUÔN LƠ LỬNG TRÊN KHÔNG!!!!",
					"{C:inactive}(Hiện tại là {C:attention}+#1#{C:inactive} lá giữ trong tay)",
				},
			},
			j_mp_mail_sandbox = {
				name = "Tiền Hoàn Thư",
				text = {
					"PHIẾU HOÀN TIỀN CỨNG BẬC",
					"ai đó lỡ viết {C:attention}#2#{} bằng",
					"BÚT DẦU CMNR!!!!",
				},
			},
			j_mp_hit_the_road_sandbox = {
				name = "Lên Đường",
				text = {
					"ĐƯỜNG CAO TỐC VỨT BỒI",
					"ném văng {C:attention}Bồi{}",
					"LÊN NHỰA ĐƯỜNG MÃI MÃI!!!!",
					"{C:inactive}(Hiện tại là {X:mult,C:white} X#2# {C:inactive} Nhân)",
				},
			},
			j_mp_misprint_sandbox = {
				name = "Lỗi In",
				text = {
					"NGƯỜI CHƠI XỔ SỐ SCHRODINGER",
					"vé VỪA THẮNG VỪA THUA",
					"cho đến khi kiểm tra!!!!",
					"{C:inactive}({V:1}#1#{C:inactive} Nhân)",
				},
			},
			j_mp_castle_sandbox = {
				name = "Lâu Đài",
				text = {
					"EM ƠI, LÂU ĐÀI TÌNH ÁI ĐÓ",
					"CHẮC KHÔNG CÓ {V:1}#1#{} TRÊN TRẦN GIAN",
					"ANH ĐƯA EM VÀO BẰNG TIẾNG HÁT",
					"CHẮP ĐÔI CÁNH NHUNG THIÊN THẦN",
					"{C:inactive}(Hiện tại là {C:chips}+#2#{C:inactive} Chip)",
				},
			},
			j_mp_runner_sandbox = {
				name = "Chay Việt Dã",
				text = {
					"KHỨA UY QUYỀN CHUYÊN SẢNH",
					"nghĩ rẳng MỌI TAY POKER",
					"khác đầu HẠ ĐẲNG!!!!",
					"{C:inactive}(Hiện tại là {C:chips}+#1#{C:inactive})",
				},
			},
			j_mp_order_sandbox = {
				name = "Chuẩn Dãy",
				text = {
					"NÔNG DÂN TRỖI DẬY lãnh đạo",
					"những CON SỐ để lật đổ",
					"BỌN LÁ MẶT ÁP BỨC!!!!",
				},
			},
			j_mp_photograph_sandbox = {
				name = "Bức Ảnh",
				text = {
					"NHIẾP ẢNH GIA PHÁT MỘT chụp được",
					"MỘT BỨC HOÀN HẢO MỖI TAY BÀI!!!!",
				},
			},
			j_mp_ride_the_bus_sandbox = {
				name = "Đi Xe Buýt",
				text = {
					"CHƯƠNG TRÌNH LÁ MẶT ĐIỀM ĐẠM",
					"MỘT LÁ MẶT tức là",
					"CÚT KHỎI XE BUÝT!!!!",
					"{C:inactive}(Hiện tại là {C:mult}+#1#{C:inactive} Nhân)",
				},
			},
			j_mp_loyalty_card_sandbox = {
				name = "Thẻ Hội Viên",
				text = {
					"CHƯƠNG TRÌNH TAY BÀI THÂN THIẾT",
					"hãy phản bội {C:attention}#1#{}",
					"và chống ĐẶT LẠI!!!!",
					"{C:inactive}(Trung thành trong {C:attention}#2#/#3#{} {C:inactive}tay bài)",
				},
			},
			j_mp_faceless_sandbox = {
				name = "Joker Vô Diện",
				text = {
					"LÁ MẶT HẦU RƯỢU CAO CẤP",
					"chế ra BA HƯƠNG VỊ BAY",
					"TÍT LÊN TRỜI cho TRẢI",
					"NGHIỆM VỨT BỎ CAO CẤP!!!!",
				},
			},
			j_mp_square_sandbox = {
				name = "Joker Vuông",
				text = {
					"BỐN LÁ CẦU TOÀN",
					"thờ phụng HÌNH HỌC LINH THIÊNG",
					"CỦA XẾP HÌNH VUÔNG SIÊU CÂN BẰNG!!!!",
					"{C:inactive}(Hiện tại là {C:chips}+#1#{C:inactive} Chip)",
				},
			},
			j_mp_throwback_sandbox = {
				name = "Hồi Tổ",
				text = {
					"DỊCH VỤ TƯ VẤN NHÁT CẤY CHUYÊN NGHIỆP",
					"Tôi được TRẢ để chim cút khỏi mọi thứ",
					"VÀ CÀNG CAO CHẠY XA BAY TÔI CÀNG MẠNH MẼ!!!!",
					"{C:inactive}(Hiện tại là {X:mult,C:white} X#1# {C:inactive} Nhân)",
				},
			},
			j_mp_vampire_sandbox = {
				name = "Ma Cà Rồng",
				text = {
					"nhà kinh tế cà rồng TẠO RA",
					"TIỀN TỆ CHUẨN THẠCH",
					"TỪ SINH LỰC!!!!",
					"{C:inactive}(Hiện tại là {X:mult,C:white} X#2# {C:inactive} Nhân)",
				},
			},
			j_mp_baseball_sandbox = {
				name = "Thẻ Bóng Chày",
				text = {
					'THẺ THỂ THAO "GÂY TRANH CÃI"',
					"đóng giả làm THAY ĐỔI CÂN BẰNG!!!!",
				},
			},
			j_mp_steel_joker_sandbox = {
				name = "Joker Thép",
				text = {
					"CHUYÊN GIA THÉP THỪA THÃI",
					"mỗi HỢP KIM ĐÃ CHƠI đều",
					"ĐƯỢC KIỂM LẠI!!!!",
				},
			},
			j_mp_satellite_sandbox = {
				name = "Vệ Tinh",
				text = {
					"lo âu vệ tinh suy tàn quỹ đạo",
					"HẠ TẦNG TỪ TỪ SỤP ĐỔ KHI KHÔNG CÓ",
					"NÂNG CẤP HÀNH TINH THƯỜNG XUYÊN!!!!",
					"{C:inactive}(Hiện tại là {C:money}$#1#{C:inactive})",
				},
			},
			j_mp_error_sandbox = {
				name = "????",
				text = {
					-- "PREVIEW DISABLED",
					"{B:purple,C:white,s:0.85}Có gì đó{} {B:purple,C:white,s:0.85}sai sai ở đây",
					-- "PREVIEW DISABLED",
					-- "PREVIEW DISABLED",
					-- "{C:inactive}(CURRENTLY {C:money}$7{C:inactive})",
				},
			},
			j_mp_8ball_release = {
				name = "Bi 8",
				text = {
					"Tạo ra một lá {C:planet}Hành Tinh{}",
					"nếu tay bài chứa",
					"{C:attention}#1#{} hoặc nhiều hơn lá {C:attention}8{}",
					"{C:inactive}(Phải có ô trống)",
				},
			},
			j_mp_todo_list_release = {
				name = "Danh Sách Công Việc",
				text = {
					"Nhận {C:money}$#1#{} nếu {C:attention}tay poker{}",
					"là {C:attention}#2#{},",
					"tay poker thay đổi",
					"ở cuối ván",
				},
			},
			j_mp_swashbuckler_release = {
				name = "Hảo Hán",
				text = {
					"Thêm tổng giá bán của các",
					"{C:attention}Jokers{} khác bên trái",
					"lá này vào Nhân",
					"{C:inactive}(Hiện tại là {C:mult}+#1#{C:inactive} Nhân)",
				},
			},
			j_mp_hanging_chad_release = {
				name = "Phiếu Đục Lỗ",
				text = {
					"Tái kích hoạt lá ghi điểm",
					"{C:attention}đầu tiên{} trong tay bài",
				},
			},
			j_mp_madness_release = {
				name = "Điên Loạn",
                text = {
                    "Khi {C:attention}Blind{} được chọn,",
                    "thêm {X:mult,C:white} X#1# {} Nhân",
                    "và {C:attention}phá huỷ{} một Joker ngẫu nhiên",
                    "{C:inactive}(Hiện tại là {X:mult,C:white} X#2# {C:inactive} Nhân)"
                }
            },
			j_mp_vampire_release = {
				name = "Ma Cà Rồng",
                text = {
                    "Joker này thêm {X:mult,C:white} X#1# {} Nhân",
                    "mỗi {C:attention}lá Cường Hoá{} đã chơi ghi điểm,",
                    "loại bỏ {C:attention}Cường Hoá",
                    "{C:inactive}(Hiện tại là {X:mult,C:white} X#2# {C:inactive} Nhân)"
                }
            },
			j_mp_midas_mask_release = {
				name = "Mặt Nạ Midas",
                text = {
                    "Mọi lá {C:attention}mặt{} đã chơi",
                    "trở thành lá {C:attention}Vàng",
                    "khi ghi điểm",
                }
            },
			j_mp_yorick_release = {
				name = "Yorick",
				text = {
					"{X:mult,C:white} X#1# {} Nhân sau khi sử dụng",
					"using {C:attention}#2#{} lượt bỏ bài",
					"{C:inactive}(Lượt bỏ còn lại: {C:attention}#3#{C:inactive})",
				},
			},
			j_mp_flower_pot_release = {
				name = "Bình Hoa",
                text = {
                    "{X:mult,C:white} X#1# {} Nhân nếu",
                    "tay poker chứa một",
                    "lá {C:diamonds}Rô{}, lá {C:clubs}Tép{},",
                    "lá {C:hearts}Cơ{} và lá {C:spades}Bích"
                },
			},
		},
		Tarot = {
			c_mp_magician_release = {
				name = "Pháp Sư",
                text = {
                    "Cường hoá {C:attention}#1#",
                    "lá đã chọn thành",
                    "{C:attention}#2#"
                }
			},
		},
		Planet = {
			c_mp_asteroid = {
				name = "Thiên Thạch",
				text = {
					"Giảm #1# level từ",
					"{C:legendary,E:1}tay poker{}",
					"có level cao nhất",
					"của {X:purple,C:white}Đối_Thủ{}",
					"ở đầu {C:attention}Blind Đối Đầu{}",
				},
			},
		},
		Blind = {
			bl_mp_nemesis = {
				name = "Đối Đầu",
				text = {
					"Gặp một người chơi khác,",
					"nhiều điểm nhất sẽ chiến thắng",
				},
			},
			-- bl_precision = {
			-- 	name = "Kẻ Chuẩn Xác",
			-- 	text = {
			-- 		"Gặp một người chơi khác,",
			-- 		"gần mục tiêu nhất sẽ chiến thắng",
			-- 	},
			-- },
		},
		Back = {
			b_mp_cocktail = {
				name = "Bộ Bài Cocktail",
				text = {
					"Sao chép mọi khả năng",
					"của {C:attention}3{} bộ bài",
					"ngẫu nhiên khác",
				},
			},
			b_mp_gradient = {
				name = "Bộ Bài Màu Dốc",
				text = {
					"Lá bài thường đươc xem như",
					"một bậc {C:attention}cao hơn{} hoặc {C:attention}thấp",
					"{C:attention}hơn{} cho mọi hiệu ứng {C:attention}Joker",
				},
			},
			b_mp_indigo = {
				name = "Bộ Bài Chàm",
				text = {
					"Chọn thêm {C:attention}1{} lá bài",
					"từ mọi Gói Bài",
				},
			},
			b_mp_orange = {
				name = "Bộ Bài Cam",
				text = {
					"Bằt đầu trận với",
					"{C:attention,T:p_mp_standard_giga}Gói Tiêu Chuẩn Cực Đại{}, và",
					"{C:attention}2{} bản sao của {C:tarot,T:c_hanged_man}Kẻ Treo Ngược",
				},
			},
			b_mp_oracle = {
				name = "Bộ Bài Sấm Truyền",
				text = {
					"Bắt đầu trận với {C:spectral,T:c_medium}Thầy Đồng",
					"và {C:attention,T:v_clearance_sale}Bán Hạ Giá",
					"Số dư tối đa chỉ còn lại",
					"{C:money}$50{} + {C:attention}tổng tiền lãi tối đa",
				},
			},
			b_mp_violet = {
				name = "Bộ Bài Tía",
				text = {
					"{C:attention}+1{} Ô Phiếu trong shop",
					"Ở Ante {C:attention}1{}, Phiếu",
					"được giảm giá {C:attention}50%{}",
				},
			},
			b_mp_heidelberg = {
				name = "Bộ Bài Heidelberg",
				text = {
					"Tạo ra bản sao {C:dark_edition}Âm Bản{} của",
					"{C:attention}1{} lá {C:attention}tiêu thụ{} ngẫu",
					"nhiên thuộc sở hữu của bạn",
					"ở cuối {C:attention}shop",
				},
			},
			b_mp_white = {
				name = "Bộ Bài Trắng",
				text = {
					"Có thể xem bộ bài và Joker",
					"hiện tại của {X:purple,C:white}Đối Thủ'{}",
					"{C:inactive}(Làm mới sau mỗi blind Đối Đầu){}",
				},
			},
		},
		Other = {
			mp_sticker_balanced = {
				name = "Cân Bằng",
				text = {
					"Lá bài này đã được tái cân bằng",
				},
			},
			mp_sticker_balanced_j_mp_hanging_chad = {
				name = "Cân Bằng",
				text = {
					"Tái kích hoạt {C:attention}2{} lá bài",
					"thay vì lá đầu tiên 2 lần",
				},
			},
			mp_sticker_balanced_j_mp_ticket = {
				name = "Cân Bằng",
				text = {
					"Trở thành {C:green}Ít Phổ Biến{}",
					"Không còn yêu cầu bài {C:attention}Vàng{}",
				},
			},
			mp_sticker_balanced_j_mp_seltzer = {
				name = "Cân Bằng",
				text = {
					"Có hiệu lực trong {C:attention}8{} tay bài",
					"thay vì {C:attention}10{}",
				},
			},
			mp_sticker_balanced_j_mp_turtle_bean = {
				name = "Cân Bằng",
				text = {
					"{C:attention}+4{} lá giữ trong tay",
					"thay vì {C:attention}+5{}",
				},
			},
			mp_sticker_balanced_j_mp_baron = {
				name = "Cân Bằng",
				text = {
					"Trở thành {C:green}Ít Phổ Biến{} ({C:money}$5{})",
					"thay vì {C:red}Hiếm{} ({C:money}$8{})",
				},
			},
			mp_sticker_balanced_j_mp_mime = {
				name = "Cân Bằng",
				text = {
					"Trở thành {C:red}Hiếm{} ({C:money}$8{})",
					"thay vì {C:green}Ít Phổ Biến{} ({C:money}$5{})",
				},
			},
			mp_sticker_balanced_j_mp_todo_list = {
				name = "Cân Bằng",
				text = {
					"Nhận {C:money}$5{} thay vì {C:money}$4{}",
					"Tay poker được chọn từ {C:attention}tất cả{} các tay poker,",
					"dù được khám phá hay chưa",
				},
			},
			mp_sticker_balanced_j_mp_bloodstone = {
				name = "Cân Bằng",
				text = {
					"Khi {C:attention}Đối Đầu{}, xác suất {C:green}1 trên 2{}",
					"đến từ một {C:attention}chuỗi cố định{}",
					"được tất cả người chơi sử dụng",
					"và {C:attention}tái sử dụng{} cho mọi tay bài ván đó",
				},
			},
			mp_sticker_balanced_c_mp_ouija_standard = {
				name = "Balanced",
				text = {
					"Phá hủy {C:attention}3{} lá bài thay vì",
					"biến đổi mọi lá và loại bỏ hiệu ứng",
					"{C:attention}-1{} lá giữ trong tay",
				},
			},
			mp_sticker_balanced_m_gold = {
				name = "Cân Bằng",
				text = {
					"Nhận {C:money}$4{} thay vì {C:money}$3{}",
				},
			},
			current_nemesis = {
				name = "Đối Thủ",
				text = {
					"{X:purple,C:white}#1#{}",
					"Kẻ địch duy nhất của bạn",
				},
			},
			p_mp_standard_giga = {
				name = "Gói Tiêu Chuẩn Cực Đại",
				text = {
					"Chọn {C:attention}#1#{} trong tối đa",
					"{C:attention}#2#{C:attention} lá bài {C:attention}Thường{}",
					"để thêm vào bộ bài",
					"{C:attention}Không thể bỏ qua{}",
				},
			},
		},
		Stake = {
			stake_mp_planet = {
				name = "Cược Hành Tinh",
				text = {
					"Người anh trai ngầu lòi của {C:attention}Cược Cam{}",
					"này sẽ trả lại cho bạn {C:red}lượt",
					"{C:red}bỏ bài quý giá{} bỏi vì",
					"họ không tàn nhẫn đến thế đâu",
				},
			},
			stake_mp_spectral = {
				name = "Cược Siêu Linh",
				text = {
					"Áp dụng {C:planet}Cược Hành Tinh{}, thêm:",
					"Joker {C:money}Cho thuê{} xuất hiện trong shop",
					"Điểm yêu cầu tăng",
					"nhanh hơn sau mỗi {C:attention}Ante",
				},
			},
			stake_mp_spectralplus = {
				name = "Cược Siêu Linh+",
				text = {
					"Áp dụng {C:planet}Cược Siêu Linh{}, thêm:",
					"Điểm yêu cầu tăng",
					"nhanh hơn sau mỗi {C:attention}Ante",
				},
			},
		},
		Spectral = {
			c_mp_ouija_standard = {
				name = "Cầu Cơ",
				text = {
					"Phá hủy {C:attention}#1#{} lá bài ngẫu nhiên,",
					"sau đó biến đổi toàn bộ lá bài còn lại",
					"trong tay thành một {C:attention}bậc{}",
					"ngẫu nhiên"
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
		},
	},
	misc = {
		dictionary = {
			b_singleplayer = "Chơi Đơn",
			b_sp_with_ruleset = "Luyện Tập",
			b_join_lobby = "Vào Phòng",
			b_join_lobby_clipboard = "Vào Từ Bộ Nhớ Đệm",
			k_unlimited_slots = "Vô Hạn Ô Trống",
			k_edition_cycling = "Thay Đổi Ấn Bản (Q)",
			k_practice_options = "Tùy chọn Luyện Tập...",
			b_return_lobby = "Quay lại Phòng",
			b_reconnect = "Kết nối lại",
			b_create_lobby = "Tạo Phòng",
			b_start_lobby = "Mở Phòng",
			b_ready = "Sẵn sàng",
			b_unready = "Huỷ sẵn sàng",
			b_leave_lobby = "Rời Phòng",
			b_mp_discord = "Máy Chủ Discord Balatro Multiplayer",
			b_start = "BẮT ĐẦU",
			b_wait_for_host_start = {
				"ĐANG CHỜ CHỦ",
				"PHÒNG BẮT ĐẦU",
			},
			b_wait_for_players = {
				"ĐANG CHỜ",
				"NGƯỜI CHƠI",
			},
			b_wait_for_guest_ready = {
				"ĐANG CHỜ NGƯỜI CHƠI",
				"KHÁC SẴN SÀNG",
			},
			b_lobby_options = "TUỲ CHỈNH PHÒNG",
			b_copy_clipboard = "Sao chép vào bộ nhớ đệm",
			b_view_code = "XEM MÃ",
			b_copy_code = "SAO CHÉP MÃ",
			b_leave = "THOÁT",
			b_opts_cb_money = "Bù $ cho người chơi mất mạng",
			b_opts_no_gold_on_loss = "Không nhận thưởng blind khi thua ván",
			b_opts_death_on_loss = "Mất mạng khi thua blind thường",
			b_opts_start_antes = "Ante khởi đầu",
			b_opts_diff_seeds = "Người chơi có Giống khác nhau",
			b_opts_lives = "Mạng",
			b_opts_multiplayer_jokers = "Cho phép Lá Chơi Mạng",
			b_opts_player_diff_deck = "Bộ bài người chơi khác nhau",
			b_opts_random_loadout = "Bộ bài và mức cược ngẫu nhiên",
			b_opts_normal_bosses = "Kích hoạt hiệu ứng Boss Blind",
			b_opts_timer = "Cho Phép Đếm Ngược",
			b_opts_disable_preview = "Tắt Xem Trước Điểm",
			b_opts_the_order = "Bật The Order",
			b_opts_legacy_smallworld = "Cơ chế Small World Cổ Điểm",
			b_reset = "Đặt lại",
			b_set_custom_seed = "Đặt Giống Tuỳ Chỉnh",
			b_mp_kofi_button = "Ủng hộ tôi trên Ko-fi",
			b_unstuck = "Bỏ kẹt",
			b_unstuck_blind = "Kẹt bên ngoài Đối Đầu",
			b_misprint_display = "Hiển thị lá tiếp theo trong bộ bài",
			b_players = "Người chơi",
			b_lobby_info = "T.Tin Phòng",
			b_continue_singleplayer = "Tiếp tục trong Chơi Đơn",
			b_the_order_integration = "Bật Tích Hợp The Order",
			b_preview_integration = "Bật Xem Trước Điểm",
			b_view_nemesis_deck = "Xem Bộ Bài",
			b_toggle_jokers = "Bật Joker",
			b_skip_tutorial = "Bỏ Qua Hướng Dẫn",
			k_yes = "Có",
			k_no = "Không",
			k_are_you_sure = "Bạn chắc chứ?",
			k_has_multiplayer_content = "Có Vật Phẩm Chơi Mạng",
			k_forces_lobby_options = "Ép Tuỳ Chỉnh Phòng",
			k_forces_gamemode = "Ép Chế Độ Chơi",
			k_may_roll_stickers = "Có thể Gieo lại Nhãn",
			k_values_are_modifiable = "* Giá trị tuỳ biến",
			k_rulesets = "Luật Lệ",
			k_gamemodes = "Chế Độ Chơi",
			k_matchmaking = "Ghép Trận",
			k_competitive = "Tranh Đấu",
			k_tournament = "Giải Đấu",
			k_custom = "Tùy Chọn",
			k_other = "Khác",
			k_battle = "Cuộc Chiến",
			k_challenge = "Thử Thách",
			k_info = "Thông Tin",
			k_continue_singleplayer_tooltip = "Hành động này sẽ ghi đè lên trận chơi đơn hiện tại",
			k_enemy_score = "Điểm Đối Thủ",
			k_enemy_hands = "Tay bài còn lại: ",
			k_coming_soon = "Sắp ra mắt!",
			k_wait_enemy = "Đang chờ đối thủ hoàn thành ván...",
			k_lives = "Mạng",
			k_skips = "Bỏ Qua",
			k_lost_life = "Mất 1 mạng",
			k_total_lives_lost = " Mạng đã mất",
			k_attrition_name = "Hao Mòn",
			k_enter_lobby_code = "Nhập Mã Phòng",
			k_paste = "Dán Từ Bộ Nhớ Đệm",
			k_username = "Tên:",
			k_enter_username = "Nhập tên",
			k_customize_preview = "Tuỳ Chỉnh Chữ Xem Trước:",
			k_join_discord = "Tham gia ",
			k_discord_msg = "Bạn có thể báo cáo lỗi cũng như tìm người chơi cùng ở đó",
			k_enter_to_save = "Nhấn enter để lưu",
			k_in_lobby = "Trong phòng",
			k_connected = "Đã kết nối tới Máy chủ",
			k_warn_service = "CHÚ Ý: Không thể tìm thấy Máy chủ Multiplayer",
			k_set_name = "Đặt tên của bạn trong menu chính! (Mod > Multiplayer > Tuỳ Chọn)",
			k_mod_hash_warning = "Người chơi đang có mod hoặc phiên bản mod khác nhau, có thể gây vấn đề khi chơi!",
			k_steamodded_warning = "Người chơi đang có phiên bản Steamodded khác nhau. Có thể gây chênh lệch giống.",
			k_mp_version_warning = "Người chơi đang có phiên bản Multiplayer khác nhau! Giống và joker sẽ không khớp nhau - cập nhật cùng phiên bản nhé.",
			k_warning_unlock_profile = "Hồ sơ bạn đang chơi chưa được mở khoá toàn bộ. Nếu đây là trận xếp hạng/giải đấu, hãy tạo hồ sơ mới và nhấn mở khoá toàn bộ trong cài đặt hồ sơ",
			k_warning_nemesis_unlock = "Đối thủ của bạn đang chơi trên hồ sơ chưa được mở khoá toàn bộ. Hãy hướng dẫn họ tạo hồ sơ mới và nhấn mở khoá toàn bộ trong cài đặt hồ sơ",
			k_warning_no_order = "Một người chơi đang bật tích hợo The Order trong khi người kia thì không. Điều nãy sẽ khiến cùng một giống bị khác nhau.",
			k_warning_cheating1 = "Nếu bạn thấy cái này, đối thủ có thể đang gian lận.",
			k_warning_cheating2 = "Nếu đây là trận xếp hạng, hãy gửi tin nhắn '%s' rồi mở một vé hỗ trợ trong #support",
			k_warning_banned_mods = "Một hoặc nhiều người chơi đã cài mod bị cấm. Những mod này không được phép dùng trong trận xếp hạng.",
			k_message1 = "Hold on, my mom made pizza pops", --These are suuposed to be "fake excuses" to stall\
			k_message2 = "One sec, i gotta grab my slow cooker pork roast", --opponents while you're working your way out.\
			k_message3 = "One moment, getting a call from my mom", --The majority of players use English anyway\
			k_message4 = "Brb, my cat is on fire", --so I'm not touching any of this.
			k_message5 = "Wait, I think I left the stove on",
			k_message6 = "Hold up, my pet rock just ran away",
			k_message7 = "One sec, my plants are asking for water",
			k_message8 = "Brb, my socks are plotting against me",
			k_message9 = "Sorry, my WiFi is having an existential crisis",
			k_lobby_options = "Tuỳ Chỉnh Phòng",
			k_connect_player = "Người chơi đã Kết nối:",
			k_opts_only_host = "Chỉ Chủ Phòng có thể chỉnh sửa những tuỳ chỉnh này",
			k_lobby_general = "Chung",
			k_lobby_gameplay = "Kiểu Chơi",
			k_lobby_modifiers = "Tuỳ Chỉnh",
			k_lobby_advanced = "Nâng Cao",
			k_opts_pvp_start_round = "Đối Đầu Bắt đầu ở Ante",
			k_opts_pvp_timer = "Đếm Ngược",
			k_opts_pvp_timer_increment = "Tăng Đếm Ngược",
			k_opts_pvp_countdown_seconds = "Giây Đếm Ngược Đối Đầu",
			k_opts_modifier_timer = "Thi Triển Đếm Ngược", -- feel free to fix this text if you don't like huy, i can't find a better word for this
            k_experimental_modifiers_timers = {
                "- Mặc định: Đếm ngược {C:chips}150{} {C:inactive}(1x){} giây",
                " ",
                "- Không Hiệu ứng: Đếm ngược {C:chips}100{} {C:inactive}(0.67x){} giây {C:attention}trừ hiệu ứng{}",
                " ",
                "- Áp lực: Đếm ngược {C:chips}300{} {C:inactive}(2x){} giây {C:attention}trừ hiệu ứng{},",
                "  bắt đầu {C:attention}ngay lập tức{}",
                " ",
                "- Áp lực+: Giống {C:attention}Áp lực{} thêm {C:chips}15{} giây cho mỗi tay bài đã chơi",
            },
            b_opts_modifier_pvp_timer = "Đếm Ngược trong Đối Đầu",
            k_experimental_modifiers_pvp_timer = {
                "- Đếm ngược được sử dụng trong các ván {C:mult}Đối Đầu{}.",
                "  {C:chips}90{} giây thêm {C:chips}15{} giây cho mỗi tay bài đã chơi {C:attention}trừ hiệu ứng{}.",
                "  Chỉ có thể \"đếm ngược\" đối thủ khi bạn có điểm {C:attention}cao hơn{}"
            },
            k_experimental_modifiers_smallworld = {
                "- {C:attention}75%{} joker, lá tiêu thụ, phiếu và nhãn",
                "bị cấm ngẫu nhiên mỗi trận đấu.",
                "- Hiệu ứng {C:attention}Ông Bầu{} luôn được kích hoạt.",
            },
			k_bl_life = "Sống",
			k_bl_or = "hoặc",
			k_bl_death = "Chết",
			k_bl_mostchips = "Nhiều điểm hơn sẽ chiến thắng",
			k_current_seed = "Giống hiện tại: ",
			k_random = "Ngẫu nhiên",
			k_standard = "Tiêu Chuẩn",
			-- k_standard_description = "Thể thức tiêu chuẩn, bao gồm lá Chơi Mạng và điều chỉnh game gốc để phù hợp với meta Chơi Mạng.",
			k_sandbox = "Sandbox",
			k_sandbox_description = "Như tiêu chuẩn nhưng mấy lá bài thích tám chuyện với nốc cà phê nhiều quá.",
			k_vanilla = "Cơ Bản",
			k_vanilla_description = "Thể thức này bỏ hết vật phẩm Chơi Mạng,\ncho phép bạn chơi game đúng theo thiết kế của nó.\n\nThể thức này vẫn bao gồm tính năng Chơi Mạng như đếm ngược.\n\n(Có thể tắt ở Tuỳ Chỉnh Phòng)",
			k_mp_ruleset_expanded_description = "Thể thức cân bằng của Multiplayer,\nvới các lá Joker Multiplayer và các cân bằng\ncùng toàn quyền điểu khiển tùy chỉnh phòng của bạn\n\n(xem mục bị cấm và làm lại để biết thêm thông tin)",
			k_traditional = "Truyền Thống",
			k_traditional_description = "Thể thức này loại bỏ cơ chế Chơi Mạng dùng thời gian làm tài nguyên.\n\nThể thức này cho phép bạn chơi với vật phẩn Chơi Mạng,\ntrong khi vẫn giữ vững tính chiến thuật.\n\nMột só lá bài được cân bằng lại để phù hợp với meta Chơi mạng:\n- Làm lại Phiếu Đục Lỗ\n- Loại bỏ Công Lý\n- Làm lại Lá Kính\n\n(xem mục bị cấm và làm lại để biết thêm thông tin)",
			k_majorleague = "Giải Chính",
			k_majorleague_description = "Đây là điều lệ chính thức cho Giải Chính Balatro.\n\nThể thức này giống thể thức Cơ Bản với một số ngoại lệ::\n- Bạn phải tắt Tích Hợp The Order\n- Thời gian đếm ngược la 180 giây\n- Lần đầu thời gian chạm mốc 0 giây sẽ không bị mất mạng",
			k_minorleague = "Giải Phụ",
			k_minorleague_description = "Đây là điều lệ chính thức cho Giải Phụ Balatro.\n\nThể thức này giống thể thức Cơ Bản với một số ngoại lệ::\n- You phải bật Tích Hợp The Order\n- Thời gian đếm ngược la 180 giây\n- Lần đầu thời gian chạm mốc 0 giây sẽ không bị mất mạng",
			k_mp_ruleset_balanced_description = "Đây là điều lệ chính thức cho Xếp Hạng của Balatro Multiplayer.\n\nThể thức này giống thể thức Tiêu Chuẩn với một số ngoại lệ:\n- Bạn phải bật Tích Hợp The Order\n- Bạn phải dùng phiên bản Steamodded được khuyến nghị",
			k_legacy_ranked = "Xếp Hạng Cổ Điển",
			k_legacy_ranked_description = "Đây là điều lệ tranh đấu đã được tối giản.\n\nThể thức này không có sự thay đổi gì của Multiplayer\ntrừ Lá Kính cùng các tùy chỉnh cố định:\n- Chế độ Hao Mòn\n- Bạn phải bật Tích Hợp The Order\n- Bạn phải dùng phiên bản Steamodded được khuyến nghị",
			k_experimental_balanced = "Thử Nghiệm (Tiêu Chuẩn)",
			k_experimental_description = "Đây là điều lệ thử nghiệm Tiêu Chuẩn.\n\nCác bản cân bằng sẽ liên tục được thử nghiệm tại đây\ntrước khi đưa vào điều lệ Tiêu Chuẩn.\n\n(xem mục bị cấm và làm lại để biết thêm thông tin)",
			k_experimental_legacy = "Thử Nghiệm (Cổ Điển)",
			k_experimental_legacy_description = "Đây là điều lệ mang ý kiến cá nhân với Xếp Hạng Truyền Thống.\n\nGiảm sức mạnh Lá Kính, làm lại Phiếu Đục Lỗ, cấm Công Lý,\nCờ bạc là bác thằng đần.",
            k_badlatro = "Badlatro",
			k_badlatro_description = "Một thể thức tuần được thiết kế bởi @dr_monty_the_snek trong máy chủ đã được thêm vĩnh viễn vào mod.\n\nThể thức này cấm 48 joker, lá tiêu thụ, nhãn bỏ qua, v.v...",
			k_attrition = "Hao Mòn",
			k_weekly = "Giải Tuần",
			k_weekly_description = "Một thể thức đặc biệt được thay đổi sau mỗi 1 hoặc 2 tuần. Có vẻ ta phải tự khám phá luật là gì rồi! Hiện tại là: ",
			k_smallworld = "Small World",
			k_smallworld_description = "Thế giới nhỏ bé mà, đúng không?\n3/4 số vật phẩm trong game sẽ bị cấm ngẫu nhiên,\nvà sẽ được thay thế thành các vật phẩm còn lại.\nCó tồn tại Trùng Lặp",
		    k_speedlatro = "Speedlatro",
			k_speedlatro_description = "147 giây, phóng như bay tới Đối Đầu.\nĂn Mày thoải mái nhé mấy đứa :>",
			k_chaos = "Hỗn Loạn",
			k_chaos_description = "Gi gỉ gì gi, cái gì cũng có.\n\nKết hợp Tiêu Chuẩn, Small World, Sandbox/nvà đếm ngược của Speedlatro vào một thể thức. Chúc may mắn.",
            k_release = "Phiên Bản Ra Mắt",
			k_release_description = "Allan thông tin đâu?",
			k_mp_ruleset_tab_general = "Cơ Bản",
			k_mp_ruleset_tab_tournaments = "Giải Đấu",
			k_mp_ruleset_tab_experimental = "Thử Nghiệm",
			k_cost_up = "Tăng Giá",
            k_destabilized = "Phi Ổn Định",
			k_oops_ex = "Úi!",
			k_asteroids = "Thiên Thạch",
			k_amount_short = "Lượg",
			k_filed_ex = "Đã Gọt!",
			k_timer = "Đếm Ngược",
			k_mods_list = "Danh Sách Mod",
			k_enemy_jokers = "Joker của Đối Thủ",
			k_your_jokers = "Joker của bạn",
			k_nemesis_deck = "Bộ bài của Đối Thủ",
			k_your_deck = "Bộ bài của bạn",
			k_customization = "Tùy chỉnh",
			k_the_order_credit = "*Công nhận cho @MathIsFun_",
			k_the_order_integration_desc = "Vá quy trình tạo lá bài để không còn bị phụ thuộc vào ante và dùng một tập hợp duy nhất cho mỗi loại/độ hiếm",
			k_preview_credit = "*Công nhận cho @Fantom, @Divvy",
			k_preview_integration_desc = "Cái này sẽ bật xem trước điểm trước khi chơi một tay bài",
			k_requires_restart = "*Yêu cầu khởi động lại để có hiệu lực",
			k_cocktail_select = "Chọn bộ bài để thêm vào",
			k_cocktail_shiftclick = "Shift-click để ánh kim bộ bài, bộ bài ánh kim sẽ luôn được chọn",
			k_cocktail_rightclick = "Chuột Phải để chọn tất cả",
			k_new_weekly_ruleset = "Một thể thức tuần mới đang khả dụng!",
			k_currently_colon = "Hiện tại là: ",
			k_sync_locally = "Đồng bộ cục bộ (Khỏi động lại game)",
			k_bans = "Cấm",
			k_reworks = "Thêm vào/Sửa lại",
			k_edit = "Chỉnh sửa",
			k_ruleset_disabled_the_order_required = "Bắt Buộc dùng The Order",
			k_ruleset_disabled_the_order_banned = "Cấm dùng The Order",
			k_ruleset_not_found = "Thể thức chưa rõ",
			k_tutorial_not_complete = "Bạn phải hoàn thành màn hướng dẫn trước khi chơi Multiplayer",
			k_created_by = "Tạo nởi",
			k_major_contributors = "Đóng góp chính bởi",
			ml_enemy_loc = {
				"Vị trí",
				"Đối Thủ",
			},
			k_show_mp_content_anyway = "Ẩn nội dung Multiplayer*",
			k_applies_singleplayer_vanilla_rulesets = "*Áp dụng với Chơi Đơn và các thể thức cơ bản",
			k_timer_sfx = "Hiệu ứng âm thanh Đếm Ngược",
			ml_mp_timersfx_opt = {
				"Bật",
				"Một lần mỗi Ante",
				"Tắt",
			},
			ml_mp_kofi_message = {
				"Mod và máy chủ này được",
				"lập trình và bảo trì bởi",
				"một người, nếu bạn",
				"thích nó, hãy",
			},
			ml_lobby_info = {
				"T.Tin",
				"Phòng",
			},
			ml_mp_modifier_timer_opt = {
				"Mặc định",
				"Không Hiệu ứng",
				"Áp lực",
				"Áp lực+",
			},
			k_sc_title = "PHÍM TẮT",
			k_sc_hint = "Chọn phím hoặc thả Tab để tắt",
			b_sc_choose_deck = "Chọn Bộ Bài/Mức Cược",
			loc_ready = "Sẵn sàng Đối Đầu",
			loc_selecting = "Đang chọn",
			loc_shop = "Đang đi chợ trước",
			loc_playing = "Đang đánh",
		},
		v_dictionary = {
			a_mp_art = {
				"Người vẽ: #1#",
			},
			a_mp_code = {
				"Người tạo: #1#",
			},
			a_mp_idea = {
				"Ý tưởng: #1#",
			},
			a_mp_skips_ahead = {
				"Hơn #1# lần Bỏ Qua",
			},
			a_mp_skips_behind = {
				"Kém #1# lần Bỏ Qua",
			},
			a_mp_skips_tied = {
				"Hoà",
			},
			k_banned_objs = "Đã Cấm #1#",
			k_no_banned_objs = "Không Cấm #1#",
			k_reworked_objs = "Đã Thêm/Sửa Lại #1#",
			k_no_reworked_objs = "Không Thêm/Sửa Lại #1#",
			k_ruleset_disabled_smods_version = "Yêu cần phiên bản SMODS #1#",
			k_failed_to_join_lobby = "Không thể tham gia phòng: #1#",
			k_ante_number = "Ante #1#",
			k_ante_min = "Ante #1#+", -- For example, "Ante 2+"
			k_credits_list = "#1# và nhiều người nữa!", -- #1# gets replaced with a list of names
		},
		v_text = {
			ch_c_hanging_chad_rework = {
				"{C:attention}Phiếu Đục Lỗ{} được {C:dark_edition}làm lại",
			},
			ch_c_glass_cards_rework = {
				"{C:attention}Lá Kính{} được {C:dark_edition}làm lại",
			},
			ch_c_mp_score_instability = {
				"Điểm không cân bằng bị {C:purple}chêch lệch{} nhiều hơn:",
			},
			ch_c_mp_score_instability_EXAMPLE = {
				"  {C:inactive}(VD: {C:chips}30{C:inactive}x{C:mult}24{C:inactive} -> {C:chips}36{C:inactive}x{C:mult}18{C:inactive})",
			},
			ch_c_mp_score_instability_LOC1 = {
				"  {C:inactive}Tối thiểu {C:attention}1 {C:mult}Nhân",
			},
			ch_c_mp_score_instability_LOC2 = {
				"  {C:inactive}Tối thiểu {C:attention}0 {C:chips}Chip",
			},
			ch_c_mp_ante_scaling = {
				"{C:red}X#1#{} điểm Blind sàn",
			},
		},
		challenge_names = {
			c_mp_standard = "Tiêu Chuẩn",
			c_mp_sandbox = "Sandbox",
			c_mp_badlatro = "Badlatro",
			c_mp_tournament = "Giải Đấu",
			c_mp_weekly = "Giải Tuần",
			c_mp_vanilla = "Cơ Bản",
			c_mp_misprint_deck = "Bộ Bài Lỗi In",
			c_mp_legendaries = "Huyền Thoại",
			c_mp_psychosis = "Rối Loạn Tâm Thần",
			c_mp_scratch = "Múa Từ Đầu",
			c_mp_twin_towers = "Tháp Đôi",
			c_mp_in_the_red = "Vỡ Nợ",
			c_mp_paper_money = "Tiền Giấy",
			c_mp_high_hand = "Tay Siêu Bự",
			c_mp_chore_list = "Danh Sách Việc Nhà",
			c_mp_oops_all_jokers = "Úi! Toàn Joker",
			c_mp_divination = "Tiên Tri",
			c_mp_skip_off = "Nhảy Lò Cò",
			c_mp_lets_go_gambling = "Cờ Bạc Level MAX",
			c_mp_speed = "Siêu Tốc",
			c_mp_balancing_act = "Hồi Cân Bằng",
			c_mp_bacon = "Băng Xanh",
			c_mp_eeeee = "EEEEE",
			c_mp_shared_pockets = "Chung Túi",
		},
	},
}