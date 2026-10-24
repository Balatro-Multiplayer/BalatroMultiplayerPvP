-- BYTECODE -- functions.lua:4-12
0001    TGETS    1   0   0  ; "children"
0002    TGETB    1   1   1
0003    TGETS    1   1   1  ; "config"
0004    TGETS    1   1   2  ; "ref_table"
0005    TGETS    2   0   0  ; "children"
0006    TGETB    2   2   1
0007    TGETS    2   2   1  ; "config"
0008    TGETS    2   2   3  ; "ref_value"
0009    TGETV    1   1   2
0010    GGET     2   4      ; "localize"
0011    KSTR     4   5      ; "Select"
0012    KSTR     5   6      ; "blind_states"
0013    CALL     2   2   3
0014    ISNEV    1   2
0015    JMP      1 => 0033
0016    TGETS    1   0   1  ; "config"
0017    KSTR     2   8      ; "mp_toggle_ready"
0018    TSETS    2   1   7  ; "button"
0019    TGETS    1   0   1  ; "config"
0020    KPRI     2   1
0021    TSETS    2   1   9  ; "one_press"
0022    TGETS    1   0   0  ; "children"
0023    TGETB    1   1   1
0024    TGETS    1   1   1  ; "config"
0025    GGET     2  10      ; "PVP"
0026    TGETS    2   2  11  ; "GAME"
0027    TSETS    2   1   2  ; "ref_table"
0028    TGETS    1   0   0  ; "children"
0029    TGETB    1   1   1
0030    TGETS    1   1   1  ; "config"
0031    KSTR     2  12      ; "ready_blind_text"
0032    TSETS    2   1   3  ; "ref_value"
0033 => TGETS    1   0   1  ; "config"
0034    TGETS    1   1   7  ; "button"
0035    ISNES    1   8      ; "mp_toggle_ready"
0036    JMP      1 => 0052
0037    TGETS    1   0   1  ; "config"
0038    GGET     2  10      ; "PVP"
0039    TGETS    2   2  11  ; "GAME"
0040    TGETS    2   2  14  ; "ready_blind"
0041    ISF          2
0042    JMP      3 => 0048
0043    GGET     2  15      ; "G"
0044    TGETS    2   2  16  ; "C"
0045    TGETS    2   2  17  ; "GREEN"
0046    IST          2
0047    JMP      3 => 0051
0048 => GGET     2  15      ; "G"
0049    TGETS    2   2  16  ; "C"
0050    TGETS    2   2  18  ; "RED"
0051 => TSETS    2   1  13  ; "colour"
0052 => RET0     0   1

-- BYTECODE -- functions.lua:14-30
0001    GGET     1   0      ; "sendTraceMessage"
0002    KSTR     3   1      ; "Toggling Ready"
0003    KSTR     4   2      ; "MULTIPLAYER"
0004    CALL     1   1   3
0005    GGET     1   3      ; "PVP"
0006    TGETS    1   1   4  ; "GAME"
0007    GGET     2   3      ; "PVP"
0008    TGETS    2   2   4  ; "GAME"
0009    TGETS    2   2   5  ; "ready_blind"
0010    NOT      2   2
0011    TSETS    2   1   5  ; "ready_blind"
0012    GGET     1   3      ; "PVP"
0013    TGETS    1   1   4  ; "GAME"
0014    GGET     2   3      ; "PVP"
0015    TGETS    2   2   4  ; "GAME"
0016    TGETS    2   2   5  ; "ready_blind"
0017    ISF          2
0018    JMP      3 => 0024
0019    GGET     2   7      ; "localize"
0020    KSTR     4   8      ; "b_unready"
0021    CALL     2   2   2
0022    IST          2
0023    JMP      3 => 0027
0024 => GGET     2   7      ; "localize"
0025    KSTR     4   9      ; "b_ready"
0026    CALL     2   2   2
0027 => TSETS    2   1   6  ; "ready_blind_text"
0028    GGET     1   3      ; "PVP"
0029    TGETS    1   1  10  ; "RLOG"
0030    TGETS    1   1  11  ; "record"
0031    KSTR     3   5      ; "ready_blind"
0032    GGET     4   3      ; "PVP"
0033    TGETS    4   4   4  ; "GAME"
0034    TGETS    4   4   5  ; "ready_blind"
0035    ISF          4
0036    JMP      5 => 0039
0037    KSHORT   4   1
0038    JMP      5 => 0040
0039 => KSHORT   4   0
0040 => CALL     1   1   3
0041    GGET     1   3      ; "PVP"
0042    TGETS    1   1   4  ; "GAME"
0043    KPRI     2   2
0044    TSETS    2   1  12  ; "pvp_reached"
0045    GGET     1   3      ; "PVP"
0046    TGETS    1   1   4  ; "GAME"
0047    TGETS    1   1   5  ; "ready_blind"
0048    ISF          1
0049    JMP      2 => 0061
0050    GGET     1   3      ; "PVP"
0051    TGETS    1   1  13  ; "ACTIONS"
0052    TGETS    1   1  14  ; "set_location"
0053    KSTR     3  15      ; "loc_ready"
0054    CALL     1   1   2
0055    GGET     1   3      ; "PVP"
0056    TGETS    1   1  13  ; "ACTIONS"
0057    TGETS    1   1   5  ; "ready_blind"
0058    MOV      3   0
0059    CALL     1   1   2
0060    JMP      1 => 0074
0061 => GGET     1   3      ; "PVP"
0062    TGETS    1   1  13  ; "ACTIONS"
0063    TGETS    1   1  14  ; "set_location"
0064    KSTR     3  16      ; "loc_selecting"
0065    CALL     1   1   2
0066    GGET     1   3      ; "PVP"
0067    TGETS    1   1  13  ; "ACTIONS"
0068    TGETS    1   1  17  ; "pause_ante_timer"
0069    CALL     1   1   1
0070    GGET     1   3      ; "PVP"
0071    TGETS    1   1  13  ; "ACTIONS"
0072    TGETS    1   1  18  ; "unready_blind"
0073    CALL     1   1   1
0074 => RET0     0   1

-- BYTECODE -- functions.lua:33-38
0001    UGET     0   0      ; old_skip_blind
0002    VARG     2   0   0
0003    CALLM    0   1   0
0004    GGET     0   0      ; "PVP"
0005    TGETS    0   0   1  ; "LOBBY"
0006    TGETS    0   0   2  ; "code"
0007    ISF          0
0008    JMP      1 => 0013
0009    GGET     0   0      ; "PVP"
0010    TGETS    0   0   3  ; "ACTIONS"
0011    TGETS    0   0   4  ; "update_location"
0012    CALL     0   1   1
0013 => RET0     0   1

-- BYTECODE -- functions.lua:41-48
0001    GGET     1   0      ; "PVP"
0002    TGETS    1   1   1  ; "in_session"
0003    CALL     1   2   1
0004    ISF          1
0005    JMP      2 => 0023
0006    GGET     1   2      ; "G"
0007    TGETS    1   1   3  ; "GAME"
0008    TGETS    1   1   4  ; "current_round"
0009    TGETS    1   1   5  ; "hands_left"
0010    KSHORT   2   0
0011    ISGT     1   2
0012    JMP      1 => 0023
0013    TGETS    1   0   6  ; "config"
0014    GGET     2   2      ; "G"
0015    TGETS    2   2   8  ; "C"
0016    TGETS    2   2   9  ; "UI"
0017    TGETS    2   2  10  ; "BACKGROUND_INACTIVE"
0018    TSETS    2   1   7  ; "colour"
0019    TGETS    1   0   6  ; "config"
0020    KPRI     2   0
0021    TSETS    2   1  11  ; "button"
0022    JMP      1 => 0026
0023 => UGET     1   0      ; can_play_ref
0024    MOV      3   0
0025    CALL     1   1   2
0026 => RET0     0   1

-- BYTECODE -- functions.lua:51-58
0001    GGET     1   0      ; "PVP"
0002    TGETS    1   1   1  ; "in_session"
0003    CALL     1   2   1
0004    ISF          1
0005    JMP      2 => 0021
0006    GGET     1   0      ; "PVP"
0007    TGETS    1   1   2  ; "GAME"
0008    TGETS    1   1   3  ; "ready_blind"
0009    ISF          1
0010    JMP      2 => 0021
0011    TGETS    1   0   4  ; "config"
0012    GGET     2   6      ; "G"
0013    TGETS    2   2   7  ; "C"
0014    TGETS    2   2   8  ; "UI"
0015    TGETS    2   2   9  ; "BACKGROUND_INACTIVE"
0016    TSETS    2   1   5  ; "colour"
0017    TGETS    1   0   4  ; "config"
0018    KPRI     2   0
0019    TSETS    2   1  10  ; "button"
0020    RET0     0   1
0021 => UGET     1   0      ; can_open_ref
0022    MOV      3   0
0023    CALL     1   1   2
0024    RET0     0   1

-- BYTECODE -- functions.lua:61-82
0001    GGET     1   0      ; "PVP"
0002    TGETS    1   1   1  ; "GAME"
0003    KPRI     2   1
0004    TSETS    2   1   2  ; "end_pvp"
0005    GGET     1   0      ; "PVP"
0006    TGETS    1   1   1  ; "GAME"
0007    KPRI     2   1
0008    TSETS    2   1   3  ; "prevent_eval"
0009    UGET     1   0      ; select_blind_ref
0010    MOV      3   0
0011    CALL     1   1   2
0012    GGET     1   0      ; "PVP"
0013    TGETS    1   1   4  ; "RECONNECT_TAIL"
0014    ISF          1
0015    JMP      2 => 0025
0016    GGET     1   0      ; "PVP"
0017    TGETS    1   1   5  ; "in_session"
0018    CALL     1   2   1
0019    ISF          1
0020    JMP      2 => 0025
0021    GGET     1   0      ; "PVP"
0022    TGETS    1   1   4  ; "RECONNECT_TAIL"
0023    TGETS    1   1   6  ; "on_checkpoint"
0024    CALL     1   1   1
0025 => GGET     1   0      ; "PVP"
0026    TGETS    1   1   7  ; "is_mp_or_practice"
0027    CALL     1   2   1
0028    ISF          1
0029    JMP      2 => 0082
0030    GGET     1   0      ; "PVP"
0031    TGETS    1   1   1  ; "GAME"
0032    GGET     2   9      ; "tostring"
0033    GGET     4  10      ; "math"
0034    TGETS    4   4  11  ; "random"
0035    CALL     4   0   1
0036    CALLM    2   2   0
0037    TSETS    2   1   8  ; "ante_key"
0038    GGET     1   0      ; "PVP"
0039    TGETS    1   1  12  ; "RLOG"
0040    TGETS    1   1  13  ; "record"
0041    KSTR     3  14      ; "set_ante_key"
0042    GGET     4   0      ; "PVP"
0043    TGETS    4   4   1  ; "GAME"
0044    TGETS    4   4   8  ; "ante_key"
0045    CALL     1   1   3
0046    GGET     1   0      ; "PVP"
0047    TGETS    1   1  15  ; "ACTIONS"
0048    TGETS    1   1  16  ; "play_hand"
0049    KSHORT   3   0
0050    GGET     4  17      ; "G"
0051    TGETS    4   4   1  ; "GAME"
0052    TGETS    4   4  18  ; "round_resets"
0053    TGETS    4   4  19  ; "hands"
0054    KPRI     5   2
0055    CALL     1   1   4
0056    GGET     1   0      ; "PVP"
0057    TGETS    1   1  15  ; "ACTIONS"
0058    TGETS    1   1  20  ; "new_round"
0059    CALL     1   1   1
0060    GGET     1   0      ; "PVP"
0061    TGETS    1   1  15  ; "ACTIONS"
0062    TGETS    1   1  21  ; "set_location"
0063    KSTR     3  22      ; "loc_playing"
0064    TGETS    4   0  23  ; "config"
0065    TGETS    4   4  24  ; "ref_table"
0066    TGETS    4   4  25  ; "key"
0067    IST          4
0068    JMP      5 => 0072
0069    TGETS    4   0  23  ; "config"
0070    TGETS    4   4  24  ; "ref_table"
0071    TGETS    4   4  26  ; "name"
0072 => CALL     1   1   3
0073    GGET     1   0      ; "PVP"
0074    TGETS    1   1  27  ; "UI"
0075    TGETS    1   1  28  ; "hide_enemy_location"
0076    ISF          1
0077    JMP      2 => 0082
0078    GGET     1   0      ; "PVP"
0079    TGETS    1   1  27  ; "UI"
0080    TGETS    1   1  28  ; "hide_enemy_location"
0081    CALL     1   1   1
0082 => RET0     0   1

-- BYTECODE -- functions.lua:85-120
0001    UGET     1   0      ; skip_blind_ref
0002    MOV      3   0
0003    CALL     1   1   2
0004    GGET     1   0      ; "PVP"
0005    TGETS    1   1   1  ; "LOBBY"
0006    TGETS    1   1   2  ; "code"
0007    ISF          1
0008    JMP      2 => 0116
0009    GGET     1   0      ; "PVP"
0010    TGETS    1   1   1  ; "LOBBY"
0011    TGETS    1   1   3  ; "config"
0012    TGETS    1   1   4  ; "timer"
0013    ISF          1
0014    JMP      2 => 0054
0015    GGET     1   0      ; "PVP"
0016    TGETS    1   1   5  ; "GAME"
0017    TGETS    1   1   6  ; "timer_started"
0018    IST          1
0019    JMP      1 => 0054
0020    GGET     1   0      ; "PVP"
0021    TGETS    1   1   5  ; "GAME"
0022    TGETS    1   1   7  ; "nemesis_timer_started"
0023    IST          1
0024    JMP      1 => 0054
0025    GGET     1   0      ; "PVP"
0026    TGETS    1   1   5  ; "GAME"
0027    TGETS    1   1   8  ; "timer_consumed"
0028    IST          1
0029    JMP      1 => 0054
0030    GGET     1   0      ; "PVP"
0031    TGETS    1   1   9  ; "is_any_layer_active"
0032    TDUP     3  10
0033    CALL     1   2   2
0034    IST          1
0035    JMP      1 => 0054
0036    GGET     1   0      ; "PVP"
0037    TGETS    1   1   1  ; "LOBBY"
0038    TGETS    1   1   3  ; "config"
0039    TGETS    1   1  11  ; "timer_increment_seconds"
0040    IST          1
0041    JMP      2 => 0043
0042    KSHORT   1   0
0043 => KSHORT   2   0
0044    ISGE     2   1
0045    JMP      1 => 0054
0046    GGET     1   0      ; "PVP"
0047    TGETS    1   1  12  ; "UI"
0048    TGETS    1   1  13  ; "restore_timer"
0049    GGET     3   0      ; "PVP"
0050    TGETS    3   3   1  ; "LOBBY"
0051    TGETS    3   3   3  ; "config"
0052    TGETS    3   3  11  ; "timer_increment_seconds"
0053    CALL     1   1   2
0054 => GGET     1   0      ; "PVP"
0055    TGETS    1   1  14  ; "ACTIONS"
0056    TGETS    1   1  15  ; "skip"
0057    GGET     3  16      ; "G"
0058    TGETS    3   3   5  ; "GAME"
0059    TGETS    3   3  17  ; "skips"
0060    CALL     1   1   2
0061    KSHORT   1   0
0062    GGET     2  16      ; "G"
0063    TGETS    2   2   5  ; "GAME"
0064    TGETS    2   2  18  ; "round_resets"
0065    TGETS    2   2  19  ; "blind_states"
0066    TGETS    2   2  20  ; "Big"
0067    ISNES    2  21      ; "Skipped"
0068    JMP      2 => 0076
0069    GGET     2  16      ; "G"
0070    TGETS    2   2   5  ; "GAME"
0071    TGETS    2   2  18  ; "round_resets"
0072    TGETS    2   2  22  ; "ante"
0073    MULVN    2   2   0  ; 10
0074    ADDVN    1   2   1  ; 2
0075    JMP      2 => 0089
0076 => GGET     2  16      ; "G"
0077    TGETS    2   2   5  ; "GAME"
0078    TGETS    2   2  18  ; "round_resets"
0079    TGETS    2   2  19  ; "blind_states"
0080    TGETS    2   2  23  ; "Small"
0081    ISNES    2  21      ; "Skipped"
0082    JMP      2 => 0089
0083    GGET     2  16      ; "G"
0084    TGETS    2   2   5  ; "GAME"
0085    TGETS    2   2  18  ; "round_resets"
0086    TGETS    2   2  22  ; "ante"
0087    MULVN    2   2   0  ; 10
0088    ADDVN    1   2   2  ; 1
0089 => GGET     2   0      ; "PVP"
0090    TGETS    2   2   5  ; "GAME"
0091    GGET     3   0      ; "PVP"
0092    TGETS    3   3   5  ; "GAME"
0093    TGETS    3   3  24  ; "pincher_index"
0094    ADDVN    3   3   2  ; 1
0095    TSETS    3   2  24  ; "pincher_index"
0096    GGET     2   0      ; "PVP"
0097    TGETS    2   2   5  ; "GAME"
0098    GGET     3   0      ; "PVP"
0099    TGETS    3   3   5  ; "GAME"
0100    TGETS    3   3  25  ; "furthest_blind"
0101    ISGE     3   1
0102    JMP      3 => 0105
0103    ISTC     3   1
0104    JMP      3 => 0108
0105 => GGET     3   0      ; "PVP"
0106    TGETS    3   3   5  ; "GAME"
0107    TGETS    3   3  25  ; "furthest_blind"
0108 => TSETS    3   2  25  ; "furthest_blind"
0109    GGET     2   0      ; "PVP"
0110    TGETS    2   2  14  ; "ACTIONS"
0111    TGETS    2   2  26  ; "set_furthest_blind"
0112    GGET     4   0      ; "PVP"
0113    TGETS    4   4   5  ; "GAME"
0114    TGETS    4   4  25  ; "furthest_blind"
0115    CALL     2   1   2
0116 => RET0     0   1

-- BYTECODE -- functions.lua:122-131
0001    GGET     0   0      ; "G"
0002    TGETS    0   0   1  ; "SETTINGS"
0003    KPRI     1   2
0004    TSETS    1   0   2  ; "paused"
0005    GGET     0   0      ; "G"
0006    TGETS    0   0   3  ; "deck_preview"
0007    ISF          0
0008    JMP      1 => 0017
0009    GGET     0   0      ; "G"
0010    TGETS    0   0   3  ; "deck_preview"
0011    MOV      2   0
0012    TGETS    0   0   4  ; "remove"
0013    CALL     0   1   2
0014    GGET     0   0      ; "G"
0015    KPRI     1   0
0016    TSETS    1   0   3  ; "deck_preview"
0017 => GGET     0   0      ; "G"
0018    TGETS    0   0   5  ; "FUNCS"
0019    TGETS    0   0   6  ; "overlay_menu"
0020    TDUP     2   9
0021    GGET     3   0      ; "G"
0022    TGETS    3   3   7  ; "UIDEF"
0023    TGETS    3   3   8  ; "create_UIBox_view_nemesis_deck"
0024    CALL     3   2   1
0025    TSETS    3   2  10  ; "definition"
0026    CALL     0   1   2
0027    RET0     0   1

-- BYTECODE -- functions.lua:153-155
0001    RET1     0   2

-- BYTECODE -- functions.lua:167-169
0001    RET1     0   2

-- BYTECODE -- functions.lua:139-172
0001    GGET     0   0      ; "delay"
0002    KNUM     2   0      ; 0.3
0003    CALL     0   1   2
0004    GGET     0   1      ; "G"
0005    TGETS    0   0   2  ; "screenwipe"
0006    IST          0
0007    JMP      0 => 0010
0008    KPRI     0   2
0009    UCLO     0 => 0049
0010 => GGET     0   1      ; "G"
0011    TGETS    0   0   2  ; "screenwipe"
0012    TGETS    0   0   3  ; "children"
0013    TGETS    0   0   4  ; "particles"
0014    KSHORT   1   0
0015    TSETS    1   0   5  ; "max"
0016    GGET     0   1      ; "G"
0017    TGETS    0   0   6  ; "E_MANAGER"
0018    MOV      2   0
0019    TGETS    0   0   7  ; "add_event"
0020    GGET     3   8      ; "Event"
0021    TDUP     5   9
0022    GGET     6   1      ; "G"
0023    TGETS    6   6   2  ; "screenwipe"
0024    TGETS    6   6  10  ; "colours"
0025    TGETS    6   6  11  ; "black"
0026    TSETS    6   5  12  ; "ref_table"
0027    FNEW     6  13      ; functions.lua:153
0028    TSETS    6   5  14  ; "func"
0029    CALL     3   0   2
0030    CALLM    0   1   1
0031    GGET     0   1      ; "G"
0032    TGETS    0   0   6  ; "E_MANAGER"
0033    MOV      2   0
0034    TGETS    0   0   7  ; "add_event"
0035    GGET     3   8      ; "Event"
0036    TDUP     5  15
0037    GGET     6   1      ; "G"
0038    TGETS    6   6   2  ; "screenwipe"
0039    TGETS    6   6  10  ; "colours"
0040    TGETS    6   6  16  ; "white"
0041    TSETS    6   5  12  ; "ref_table"
0042    FNEW     6  17      ; functions.lua:167
0043    TSETS    6   5  14  ; "func"
0044    CALL     3   0   2
0045    CALLM    0   1   1
0046    KPRI     0   2
0047    UCLO     0 => 0048
0048 => RET1     0   2
0049 => RET1     0   2

-- BYTECODE -- functions.lua:180-189
0001    GGET     0   0      ; "G"
0002    TGETS    0   0   1  ; "screenwipe"
0003    IST          0
0004    JMP      0 => 0007
0005    KPRI     0   2
0006    RET1     0   2
0007 => GGET     0   0      ; "G"
0008    TGETS    0   0   2  ; "screenwipecard"
0009    ISF          0
0010    JMP      1 => 0033
0011    GGET     0   0      ; "G"
0012    TGETS    0   0   2  ; "screenwipecard"
0013    MOV      2   0
0014    TGETS    0   0   3  ; "start_dissolve"
0015    TNEW     3   5
0016    GGET     4   0      ; "G"
0017    TGETS    4   4   4  ; "C"
0018    TGETS    4   4   5  ; "BLACK"
0019    TSETB    4   3   1
0020    GGET     4   0      ; "G"
0021    TGETS    4   4   4  ; "C"
0022    TGETS    4   4   6  ; "ORANGE"
0023    TSETB    4   3   2
0024    GGET     4   0      ; "G"
0025    TGETS    4   4   4  ; "C"
0026    TGETS    4   4   7  ; "GOLD"
0027    TSETB    4   3   3
0028    GGET     4   0      ; "G"
0029    TGETS    4   4   4  ; "C"
0030    TGETS    4   4   8  ; "RED"
0031    TSETB    4   3   4
0032    CALL     0   1   3
0033 => GGET     0   0      ; "G"
0034    TGETS    0   0   1  ; "screenwipe"
0035    MOV      2   0
0036    TGETS    0   0   9  ; "get_UIE_by_ID"
0037    KSTR     3  10      ; "text"
0038    CALL     0   2   3
0039    ISF          0
0040    JMP      1 => 0061
0041    GGET     0  11      ; "ipairs"
0042    GGET     2   0      ; "G"
0043    TGETS    2   2   1  ; "screenwipe"
0044    MOV      4   2
0045    TGETS    2   2   9  ; "get_UIE_by_ID"
0046    KSTR     5  10      ; "text"
0047    CALL     2   2   3
0048    TGETS    2   2  12  ; "children"
0049    CALL     0   4   2
0050    JMP      3 => 0059
0051 => TGETS    5   4  12  ; "children"
0052    TGETB    5   5   1
0053    TGETS    5   5  13  ; "config"
0054    TGETS    5   5  14  ; "object"
0055    MOV      7   5
0056    TGETS    5   5  15  ; "pop_out"
0057    KSHORT   8   4
0058    CALL     5   1   3
0059 => ITERC    3   3   3
0060    ITERL    3 => 0051
0061 => KPRI     0   2
0062    RET1     0   2

-- BYTECODE -- functions.lua:197-205
0001    GGET     0   0      ; "G"
0002    TGETS    0   0   1  ; "screenwipe"
0003    IST          0
0004    JMP      0 => 0007
0005    KPRI     0   2
0006    RET1     0   2
0007 => GGET     0   0      ; "G"
0008    TGETS    0   0   1  ; "screenwipe"
0009    TGETS    0   0   2  ; "children"
0010    TGETS    0   0   3  ; "particles"
0011    MOV      2   0
0012    TGETS    0   0   4  ; "remove"
0013    CALL     0   1   2
0014    GGET     0   0      ; "G"
0015    TGETS    0   0   1  ; "screenwipe"
0016    MOV      2   0
0017    TGETS    0   0   4  ; "remove"
0018    CALL     0   1   2
0019    GGET     0   0      ; "G"
0020    TGETS    0   0   1  ; "screenwipe"
0021    TGETS    0   0   2  ; "children"
0022    KPRI     1   0
0023    TSETS    1   0   3  ; "particles"
0024    GGET     0   0      ; "G"
0025    KPRI     1   0
0026    TSETS    1   0   1  ; "screenwipe"
0027    GGET     0   0      ; "G"
0028    KPRI     1   0
0029    TSETS    1   0   5  ; "screenwipecard"
0030    KPRI     0   2
0031    RET1     0   2

-- BYTECODE -- functions.lua:213-215
0001    KPRI     0   2
0002    RET1     0   2

-- BYTECODE -- functions.lua:136-217
0001    GGET     0   0      ; "G"
0002    TGETS    0   0   1  ; "E_MANAGER"
0003    MOV      2   0
0004    TGETS    0   0   2  ; "add_event"
0005    GGET     3   3      ; "Event"
0006    TDUP     5   4
0007    FNEW     6   5      ; functions.lua:139
0008    TSETS    6   5   6  ; "func"
0009    CALL     3   0   2
0010    CALLM    0   1   1
0011    GGET     0   0      ; "G"
0012    TGETS    0   0   1  ; "E_MANAGER"
0013    MOV      2   0
0014    TGETS    0   0   2  ; "add_event"
0015    GGET     3   3      ; "Event"
0016    TDUP     5   7
0017    FNEW     6   8      ; functions.lua:180
0018    TSETS    6   5   6  ; "func"
0019    CALL     3   0   2
0020    CALLM    0   1   1
0021    GGET     0   0      ; "G"
0022    TGETS    0   0   1  ; "E_MANAGER"
0023    MOV      2   0
0024    TGETS    0   0   2  ; "add_event"
0025    GGET     3   3      ; "Event"
0026    TDUP     5   9
0027    FNEW     6  10      ; functions.lua:197
0028    TSETS    6   5   6  ; "func"
0029    CALL     3   0   2
0030    CALLM    0   1   1
0031    GGET     0   0      ; "G"
0032    TGETS    0   0   1  ; "E_MANAGER"
0033    MOV      2   0
0034    TGETS    0   0   2  ; "add_event"
0035    GGET     3   3      ; "Event"
0036    TDUP     5  11
0037    FNEW     6  12      ; functions.lua:213
0038    TSETS    6   5   6  ; "func"
0039    CALL     3   0   2
0040    CALLM    0   1   1
0041    RET0     0   1

-- BYTECODE -- functions.lua:240-243
0001    GGET     0   0      ; "G"
0002    MOV      2   0
0003    TGETS    0   0   1  ; "start_run"
0004    TDUP     3   2
0005    UGET     4   0      ; snapshot
0006    TSETS    4   3   3  ; "savetext"
0007    CALL     0   1   3
0008    KPRI     0   2
0009    RET1     0   2

-- BYTECODE -- functions.lua:219-246
0001    GGET     2   0      ; "PVP"
0002    TGETS    2   2   1  ; "LOBBY"
0003    KPRI     3   0
0004    TSETS    3   2   2  ; "code"
0005    GGET     2   3      ; "MPAPI"
0006    TGETS    2   2   4  ; "get_current_lobby"
0007    CALL     2   2   1
0008    ISF          2
0009    JMP      3 => 0013
0010    MOV      5   2
0011    TGETS    3   2   5  ; "leave"
0012    CALL     3   1   2
0013 => GGET     3   0      ; "PVP"
0014    TGETS    3   3   6  ; "UI"
0015    TGETS    3   3   7  ; "update_connection_status"
0016    CALL     3   1   1
0017    GGET     3   8      ; "G"
0018    TGETS    3   3   9  ; "SETTINGS"
0019    KSTR     4  11      ; "Continue"
0020    TSETS    4   3  10  ; "current_setup"
0021    GGET     3   8      ; "G"
0022    TGETS    3   3  12  ; "FUNCS"
0023    TGETS    3   3  13  ; "wipe_on"
0024    CALL     3   1   1
0025    GGET     3   0      ; "PVP"
0026    TGETS    3   3  14  ; "take_run_snapshot"
0027    GGET     5   8      ; "G"
0028    GGET     6  15      ; "save_run"
0029    CALL     3   2   3
0030    GGET     4   8      ; "G"
0031    MOV      6   4
0032    TGETS    4   4  16  ; "delete_run"
0033    CALL     4   1   2
0034    GGET     4   8      ; "G"
0035    TGETS    4   4  17  ; "E_MANAGER"
0036    MOV      6   4
0037    TGETS    4   4  18  ; "add_event"
0038    GGET     7  19      ; "Event"
0039    TDUP     9  20
0040    FNEW    10  21      ; functions.lua:240
0041    TSETS   10   9  22  ; "func"
0042    CALL     7   0   2
0043    CALLM    4   1   1
0044    GGET     4   8      ; "G"
0045    TGETS    4   4  12  ; "FUNCS"
0046    TGETS    4   4  23  ; "wipe_off"
0047    CALL     4   1   1
0048    UCLO     0 => 0049
0049 => RET0     0   1

-- BYTECODE -- functions.lua:280-352
0001    UGET     0   0      ; args
0002    GGET     1   1      ; "UIBox"
0003    TDUP     3   6
0004    TDUP     4   5
0005    UGET     5   0      ; args
0006    TGETS    5   5   2  ; "pos"
0007    TGETS    5   5   3  ; "x"
0008    TSETB    5   4   1
0009    UGET     5   0      ; args
0010    TGETS    5   5   2  ; "pos"
0011    TGETS    5   5   4  ; "y"
0012    TSETB    5   4   2
0013    TSETS    4   3   7  ; "T"
0014    TDUP     4  11
0015    GGET     5   8      ; "G"
0016    TGETS    5   5   9  ; "UIT"
0017    TGETS    5   5  10  ; "ROOT"
0018    TSETS    5   4  12  ; "n"
0019    TDUP     5  14
0020    UGET     6   0      ; args
0021    TGETS    6   6  13  ; "cover_align"
0022    IST          6
0023    JMP      7 => 0025
0024    KSTR     6  15      ; "cm"
0025 => TSETS    6   5  16  ; "align"
0026    UGET     6   0      ; args
0027    TGETS    6   6  17  ; "cover"
0028    ISF          6
0029    JMP      7 => 0036
0030    UGET     6   0      ; args
0031    TGETS    6   6  17  ; "cover"
0032    TGETS    6   6   7  ; "T"
0033    TGETS    6   6  18  ; "w"
0034    IST          6
0035    JMP      7 => 0037
0036 => KNUM     6   0      ; 0.001
0037 => UGET     7   0      ; args
0038    TGETS    7   7  19  ; "cover_padding"
0039    IST          7
0040    JMP      8 => 0042
0041    KSHORT   7   0
0042 => ADDVV    6   6   7
0043    TSETS    6   5  20  ; "minw"
0044    UGET     6   0      ; args
0045    TGETS    6   6  17  ; "cover"
0046    ISF          6
0047    JMP      7 => 0054
0048    UGET     6   0      ; args
0049    TGETS    6   6  17  ; "cover"
0050    TGETS    6   6   7  ; "T"
0051    TGETS    6   6  21  ; "h"
0052    IST          6
0053    JMP      7 => 0055
0054 => KNUM     6   0      ; 0.001
0055 => UGET     7   0      ; args
0056    TGETS    7   7  19  ; "cover_padding"
0057    IST          7
0058    JMP      8 => 0060
0059    KSHORT   7   0
0060 => ADDVV    6   6   7
0061    TSETS    6   5  22  ; "minh"
0062    UGET     6   0      ; args
0063    TGETS    6   6  23  ; "emboss"
0064    TSETS    6   5  23  ; "emboss"
0065    UGET     6   0      ; args
0066    TGETS    6   6  24  ; "cover_colour"
0067    TSETS    6   5  25  ; "colour"
0068    TSETS    5   4  26  ; "config"
0069    TNEW     5   3
0070    TDUP     6  28
0071    GGET     7   8      ; "G"
0072    TGETS    7   7   9  ; "UIT"
0073    TGETS    7   7  27  ; "O"
0074    TSETS    7   6  12  ; "n"
0075    TDUP     7  29
0076    GGET     8  30      ; "DynaText"
0077    TDUP    10  32
0078    UGET    11   0      ; args
0079    TGETS   11  11  31  ; "scale"
0080    TSETS   11  10  31  ; "scale"
0081    UGET    11   0      ; args
0082    TGETS   11  11  33  ; "text"
0083    TSETS   11  10  34  ; "string"
0084    UGET    11   0      ; args
0085    TGETS   11  11  35  ; "maxw"
0086    TSETS   11  10  35  ; "maxw"
0087    TNEW    11   3
0088    UGET    12   0      ; args
0089    TGETS   12  12  25  ; "colour"
0090    TSETB   12  11   1
0091    TSETS   11  10  36  ; "colours"
0092    UGET    11   0      ; args
0093    TGETS   11  11  37  ; "noisy"
0094    NOT     11  11
0095    TSETS   11  10  38  ; "silent"
0096    UGET    11   0      ; args
0097    TGETS   11  11  31  ; "scale"
0098    TSETB   11  10   1
0099    UGET    11   0      ; args
0100    TGETS   11  11  39  ; "rotate"
0101    IST         11
0102    JMP     12 => 0104
0103    KPRI    11   0
0104 => TSETS   11  10  39  ; "rotate"
0105    CALL     8   2   2
0106    TSETS    8   7  40  ; "object"
0107    TSETS    7   6  26  ; "config"
0108    TSETB    6   5   1
0109    TSETS    5   4  41  ; "nodes"
0110    TSETS    4   3  42  ; "definition"
0111    UGET     4   0      ; args
0112    TGETS    4   4  43  ; "uibox_config"
0113    TSETS    4   3  26  ; "config"
0114    CALL     1   2   2
0115    TSETS    1   0   0  ; "AT"
0116    UGET     0   0      ; args
0117    TGETS    0   0   0  ; "AT"
0118    KPRI     1   2
0119    TSETS    1   0  44  ; "attention_text"
0120    UGET     0   0      ; args
0121    UGET     1   0      ; args
0122    TGETS    1   1   0  ; "AT"
0123    TGETS    1   1  45  ; "UIRoot"
0124    TGETS    1   1  46  ; "children"
0125    TGETB    1   1   1
0126    TGETS    1   1  26  ; "config"
0127    TGETS    1   1  40  ; "object"
0128    TSETS    1   0  33  ; "text"
0129    UGET     0   0      ; args
0130    TGETS    0   0  33  ; "text"
0131    MOV      2   0
0132    TGETS    0   0  47  ; "pulse"
0133    KNUM     3   1      ; 0.5
0134    CALL     0   1   3
0135    UGET     0   0      ; args
0136    TGETS    0   0  17  ; "cover"
0137    ISF          0
0138    JMP      1 => 0165
0139    GGET     0  48      ; "Particles"
0140    UGET     2   0      ; args
0141    TGETS    2   2   2  ; "pos"
0142    TGETS    2   2   3  ; "x"
0143    UGET     3   0      ; args
0144    TGETS    3   3   2  ; "pos"
0145    TGETS    3   3   4  ; "y"
0146    KSHORT   4   0
0147    KSHORT   5   0
0148    TDUP     6  49
0149    UGET     7   0      ; args
0150    TGETS    7   7   0  ; "AT"
0151    TGETS    7   7  45  ; "UIRoot"
0152    TSETS    7   6  50  ; "attach"
0153    TNEW     7   4
0154    UGET     8   0      ; args
0155    TGETS    8   8  24  ; "cover_colour"
0156    TSETB    8   7   1
0157    UGET     8   0      ; args
0158    TGETS    8   8  51  ; "cover_colour_l"
0159    TSETB    8   7   2
0160    UGET     8   0      ; args
0161    TGETS    8   8  52  ; "cover_colour_d"
0162    TSETB    8   7   3
0163    TSETS    7   6  36  ; "colours"
0164    CALL     0   1   6
0165 => UGET     0   0      ; args
0166    TGETS    0   0  53  ; "backdrop_colour"
0167    ISF          0
0168    JMP      1 => 0201
0169    UGET     0   0      ; args
0170    GGET     1  54      ; "copy_table"
0171    UGET     3   0      ; args
0172    TGETS    3   3  53  ; "backdrop_colour"
0173    CALL     1   2   2
0174    TSETS    1   0  53  ; "backdrop_colour"
0175    GGET     0  48      ; "Particles"
0176    UGET     2   0      ; args
0177    TGETS    2   2   2  ; "pos"
0178    TGETS    2   2   3  ; "x"
0179    UGET     3   0      ; args
0180    TGETS    3   3   2  ; "pos"
0181    TGETS    3   3   4  ; "y"
0182    KSHORT   4   0
0183    KSHORT   5   0
0184    TDUP     6  55
0185    UGET     7   0      ; args
0186    TGETS    7   7  56  ; "backdrop_scale"
0187    IST          7
0188    JMP      8 => 0190
0189    KSHORT   7   1
0190 => MULNV    7   7   2  ; 2.4
0191    TSETS    7   6  31  ; "scale"
0192    UGET     7   0      ; args
0193    TGETS    7   7   0  ; "AT"
0194    TSETS    7   6  50  ; "attach"
0195    TNEW     7   3
0196    UGET     8   0      ; args
0197    TGETS    8   8  53  ; "backdrop_colour"
0198    TSETB    8   7   1
0199    TSETS    7   6  36  ; "colours"
0200    CALL     0   1   6
0201 => KPRI     0   2
0202    RET1     0   2

-- BYTECODE -- functions.lua:361-377
0001    UGET     0   0      ; args
0002    TGETS    0   0   0  ; "start_time"
0003    IST          0
0004    JMP      0 => 0017
0005    UGET     0   0      ; args
0006    GGET     1   1      ; "G"
0007    TGETS    1   1   2  ; "TIMERS"
0008    TGETS    1   1   3  ; "TOTAL"
0009    TSETS    1   0   0  ; "start_time"
0010    UGET     0   0      ; args
0011    TGETS    0   0   4  ; "text"
0012    MOV      2   0
0013    TGETS    0   0   5  ; "pop_out"
0014    KSHORT   3   3
0015    CALL     0   1   3
0016    JMP      0 => 0115
0017 => UGET     0   0      ; args
0018    GGET     1   7      ; "math"
0019    TGETS    1   1   8  ; "max"
0020    KSHORT   3   0
0021    GGET     4   1      ; "G"
0022    TGETS    4   4   2  ; "TIMERS"
0023    TGETS    4   4   3  ; "TOTAL"
0024    UGET     5   0      ; args
0025    TGETS    5   5   0  ; "start_time"
0026    SUBVV    4   4   5
0027    MULNV    4   4   0  ; 3
0028    SUBNV    4   4   1  ; 1
0029    CALL     1   2   3
0030    TSETS    1   0   6  ; "fade"
0031    UGET     0   0      ; args
0032    TGETS    0   0   9  ; "cover_colour"
0033    ISF          0
0034    JMP      1 => 0047
0035    UGET     0   0      ; args
0036    TGETS    0   0   9  ; "cover_colour"
0037    GGET     1   7      ; "math"
0038    TGETS    1   1  10  ; "min"
0039    UGET     3   0      ; args
0040    TGETS    3   3   9  ; "cover_colour"
0041    TGETB    3   3   4
0042    UGET     4   0      ; args
0043    TGETS    4   4   6  ; "fade"
0044    MULNV    4   4   2  ; 2
0045    CALL     1   2   3
0046    TSETB    1   0   4
0047 => UGET     0   0      ; args
0048    TGETS    0   0  11  ; "cover_colour_l"
0049    ISF          0
0050    JMP      1 => 0062
0051    UGET     0   0      ; args
0052    TGETS    0   0  11  ; "cover_colour_l"
0053    GGET     1   7      ; "math"
0054    TGETS    1   1  10  ; "min"
0055    UGET     3   0      ; args
0056    TGETS    3   3  11  ; "cover_colour_l"
0057    TGETB    3   3   4
0058    UGET     4   0      ; args
0059    TGETS    4   4   6  ; "fade"
0060    CALL     1   2   3
0061    TSETB    1   0   4
0062 => UGET     0   0      ; args
0063    TGETS    0   0  12  ; "cover_colour_d"
0064    ISF          0
0065    JMP      1 => 0077
0066    UGET     0   0      ; args
0067    TGETS    0   0  12  ; "cover_colour_d"
0068    GGET     1   7      ; "math"
0069    TGETS    1   1  10  ; "min"
0070    UGET     3   0      ; args
0071    TGETS    3   3  12  ; "cover_colour_d"
0072    TGETB    3   3   4
0073    UGET     4   0      ; args
0074    TGETS    4   4   6  ; "fade"
0075    CALL     1   2   3
0076    TSETB    1   0   4
0077 => UGET     0   0      ; args
0078    TGETS    0   0  13  ; "backdrop_colour"
0079    ISF          0
0080    JMP      1 => 0092
0081    UGET     0   0      ; args
0082    TGETS    0   0  13  ; "backdrop_colour"
0083    GGET     1   7      ; "math"
0084    TGETS    1   1  10  ; "min"
0085    UGET     3   0      ; args
0086    TGETS    3   3  13  ; "backdrop_colour"
0087    TGETB    3   3   4
0088    UGET     4   0      ; args
0089    TGETS    4   4   6  ; "fade"
0090    CALL     1   2   3
0091    TSETB    1   0   4
0092 => UGET     0   0      ; args
0093    TGETS    0   0  14  ; "colour"
0094    GGET     1   7      ; "math"
0095    TGETS    1   1  10  ; "min"
0096    UGET     3   0      ; args
0097    TGETS    3   3  14  ; "colour"
0098    TGETB    3   3   4
0099    UGET     4   0      ; args
0100    TGETS    4   4   6  ; "fade"
0101    CALL     1   2   3
0102    TSETB    1   0   4
0103    UGET     0   0      ; args
0104    TGETS    0   0   6  ; "fade"
0105    KSHORT   1   0
0106    ISGT     0   1
0107    JMP      0 => 0115
0108    UGET     0   0      ; args
0109    TGETS    0   0  15  ; "AT"
0110    MOV      2   0
0111    TGETS    0   0  16  ; "remove"
0112    CALL     0   1   2
0113    KPRI     0   2
0114    RET1     0   2
0115 => RET0     0   1

-- BYTECODE -- functions.lua:248-379
0001    IST          0
0002    JMP      1 => 0004
0003    TNEW     0   0
0004 => TGETS    1   0   0  ; "text"
0005    IST          1
0006    JMP      2 => 0008
0007    KSTR     1   1      ; "test"
0008 => TSETS    1   0   0  ; "text"
0009    TGETS    1   0   2  ; "scale"
0010    IST          1
0011    JMP      2 => 0013
0012    KSHORT   1   1
0013 => TSETS    1   0   2  ; "scale"
0014    GGET     1   4      ; "copy_table"
0015    TGETS    3   0   3  ; "colour"
0016    IST          3
0017    JMP      4 => 0021
0018    GGET     3   5      ; "G"
0019    TGETS    3   3   6  ; "C"
0020    TGETS    3   3   7  ; "WHITE"
0021 => CALL     1   2   2
0022    TSETS    1   0   3  ; "colour"
0023    TGETS    1   0   8  ; "hold"
0024    IST          1
0025    JMP      2 => 0027
0026    KSHORT   1   0
0027 => TSETS    1   0   8  ; "hold"
0028    TGETS    1   0   9  ; "pos"
0029    IST          1
0030    JMP      2 => 0032
0031    TDUP     1  10
0032 => TSETS    1   0   9  ; "pos"
0033    TGETS    1   0  11  ; "align"
0034    IST          1
0035    JMP      2 => 0037
0036    KSTR     1  12      ; "cm"
0037 => TSETS    1   0  11  ; "align"
0038    TGETS    1   0  13  ; "emboss"
0039    IST          1
0040    JMP      2 => 0042
0041    KPRI     1   0
0042 => TSETS    1   0  13  ; "emboss"
0043    KSHORT   1   1
0044    TSETS    1   0  14  ; "fade"
0045    TGETS    1   0  15  ; "cover"
0046    ISF          1
0047    JMP      2 => 0072
0048    GGET     1   4      ; "copy_table"
0049    TGETS    3   0  16  ; "cover_colour"
0050    IST          3
0051    JMP      4 => 0055
0052    GGET     3   5      ; "G"
0053    TGETS    3   3   6  ; "C"
0054    TGETS    3   3  17  ; "RED"
0055 => CALL     1   2   2
0056    TSETS    1   0  16  ; "cover_colour"
0057    GGET     1   4      ; "copy_table"
0058    GGET     3  19      ; "lighten"
0059    TGETS    5   0  16  ; "cover_colour"
0060    KNUM     6   0      ; 0.2
0061    CALL     3   0   3
0062    CALLM    1   2   0
0063    TSETS    1   0  18  ; "cover_colour_l"
0064    GGET     1   4      ; "copy_table"
0065    GGET     3  21      ; "darken"
0066    TGETS    5   0  16  ; "cover_colour"
0067    KNUM     6   0      ; 0.2
0068    CALL     3   0   3
0069    CALLM    1   2   0
0070    TSETS    1   0  20  ; "cover_colour_d"
0071    JMP      1 => 0078
0072 => GGET     1   4      ; "copy_table"
0073    GGET     3   5      ; "G"
0074    TGETS    3   3   6  ; "C"
0075    TGETS    3   3  22  ; "CLEAR"
0076    CALL     1   2   2
0077    TSETS    1   0  16  ; "cover_colour"
0078 => TDUP     1  24
0079    TGETS    2   0  11  ; "align"
0080    IST          2
0081    JMP      3 => 0083
0082    KSTR     2  12      ; "cm"
0083 => TSETS    2   1  11  ; "align"
0084    TGETS    2   0  25  ; "offset"
0085    IST          2
0086    JMP      3 => 0088
0087    TDUP     2  26
0088 => TSETS    2   1  25  ; "offset"
0089    TGETS    2   0  15  ; "cover"
0090    IST          2
0091    JMP      3 => 0096
0092    TGETS    2   0  27  ; "major"
0093    IST          2
0094    JMP      3 => 0096
0095    KPRI     2   0
0096 => TSETS    2   1  27  ; "major"
0097    TSETS    1   0  23  ; "uibox_config"
0098    GGET     1   5      ; "G"
0099    TGETS    1   1  28  ; "E_MANAGER"
0100    MOV      3   1
0101    TGETS    1   1  29  ; "add_event"
0102    GGET     4  30      ; "Event"
0103    TDUP     6  31
0104    FNEW     7  32      ; functions.lua:280
0105    TSETS    7   6  33  ; "func"
0106    CALL     4   0   2
0107    CALLM    1   1   1
0108    GGET     1   5      ; "G"
0109    TGETS    1   1  28  ; "E_MANAGER"
0110    MOV      3   1
0111    TGETS    1   1  29  ; "add_event"
0112    GGET     4  30      ; "Event"
0113    TDUP     6  34
0114    TGETS    7   0   8  ; "hold"
0115    TSETS    7   6  35  ; "delay"
0116    FNEW     7  36      ; functions.lua:361
0117    TSETS    7   6  33  ; "func"
0118    CALL     4   0   2
0119    CALLM    1   1   1
0120    UCLO     0 => 0121
0121 => RET0     0   1

-- BYTECODE -- functions.lua:390-402
0001    GGET     0   0      ; "G"
0002    TGETS    0   0   1  ; "OVERLAY_MENU"
0003    ISF          0
0004    JMP      1 => 0062
0005    GGET     0   0      ; "G"
0006    TGETS    0   0   1  ; "OVERLAY_MENU"
0007    MOV      2   0
0008    TGETS    0   0   2  ; "get_UIE_by_ID"
0009    KSTR     3   3      ; "jimbo_spot"
0010    CALL     0   2   3
0011    ISF          0
0012    JMP      1 => 0062
0013    GGET     0   4      ; "Card_Character"
0014    TDUP     2   5
0015    CALL     0   2   2
0016    GGET     1   0      ; "G"
0017    TGETS    1   1   1  ; "OVERLAY_MENU"
0018    MOV      3   1
0019    TGETS    1   1   2  ; "get_UIE_by_ID"
0020    KSTR     4   3      ; "jimbo_spot"
0021    CALL     1   2   3
0022    TGETS    2   1   6  ; "config"
0023    TGETS    2   2   7  ; "object"
0024    MOV      4   2
0025    TGETS    2   2   8  ; "remove"
0026    CALL     2   1   2
0027    TGETS    2   1   6  ; "config"
0028    TSETS    0   2   7  ; "object"
0029    KPRI     2   2
0030    TSETS    2   0   9  ; "ui_object_updated"
0031    GGET     2  10      ; "PVP"
0032    TGETS    2   2  11  ; "GAME"
0033    TGETS    2   2  12  ; "won"
0034    ISF          2
0035    JMP      3 => 0045
0036    KSTR     2  13      ; "wq_"
0037    GGET     3  14      ; "math"
0038    TGETS    3   3  15  ; "random"
0039    KSHORT   5   1
0040    KSHORT   6   7
0041    CALL     3   2   3
0042    CAT      2   2   3
0043    IST          2
0044    JMP      3 => 0052
0045 => KSTR     2  16      ; "lq_"
0046    GGET     3  14      ; "math"
0047    TGETS    3   3  15  ; "random"
0048    KSHORT   5   1
0049    KSHORT   6  10
0050    CALL     3   2   3
0051    CAT      2   2   3
0052 => MOV      5   0
0053    TGETS    3   0  17  ; "add_speech_bubble"
0054    MOV      6   2
0055    KPRI     7   0
0056    TDUP     8  18
0057    CALL     3   1   5
0058    MOV      5   0
0059    TGETS    3   0  19  ; "say_stuff"
0060    KSHORT   6   5
0061    CALL     3   1   3
0062 => KPRI     0   2
0063    RET1     0   2

-- BYTECODE -- functions.lua:381-404
0001    GGET     0   0      ; "G"
0002    TGETS    0   0   1  ; "FUNCS"
0003    TGETS    0   0   2  ; "overlay_menu"
0004    TDUP     2   8
0005    GGET     3   3      ; "PVP"
0006    TGETS    3   3   4  ; "GAME"
0007    TGETS    3   3   5  ; "won"
0008    ISF          3
0009    JMP      4 => 0014
0010    GGET     3   6      ; "create_UIBox_win"
0011    CALL     3   2   1
0012    IST          3
0013    JMP      4 => 0016
0014 => GGET     3   7      ; "create_UIBox_game_over"
0015    CALL     3   2   1
0016 => TSETS    3   2   9  ; "definition"
0017    TDUP     3  10
0018    TSETS    3   2  11  ; "config"
0019    CALL     0   1   2
0020    GGET     0   0      ; "G"
0021    TGETS    0   0  12  ; "E_MANAGER"
0022    MOV      2   0
0023    TGETS    0   0  13  ; "add_event"
0024    GGET     3  14      ; "Event"
0025    TDUP     5  15
0026    FNEW     6  16      ; functions.lua:390
0027    TSETS    6   5  17  ; "func"
0028    CALL     3   0   2
0029    CALLM    0   1   1
0030    RET0     0   1

-- BYTECODE -- functions.lua:410-440
0001    GGET     0   0      ; "G"
0002    TGETS    0   0   1  ; "hand_text_area"
0003    IST          0
0004    JMP      0 => 0006
0005    RET0     0   1
0006 => GGET     0   2      ; "PVP"
0007    TGETS    0   0   3  ; "LOBBY"
0008    TGETS    0   0   4  ; "config"
0009    TGETS    0   0   5  ; "disable_live_and_timer_hud"
0010    ISF          0
0011    JMP      1 => 0014
0012    KPRI     0   2
0013    RET1     0   2
0014 => GGET     0   0      ; "G"
0015    TGETS    0   0   1  ; "hand_text_area"
0016    TGETS    0   0   6  ; "ante"
0017    ISF          0
0018    JMP      1 => 0023
0019    TGETS    1   0   4  ; "config"
0020    TGETS    1   1   7  ; "object"
0021    IST          1
0022    JMP      1 => 0025
0023 => KPRI     1   2
0024    RET1     1   2
0025 => UGET     1   0      ; mod
0026    IST          1
0027    JMP      2 => 0029
0028    KSHORT   1   0
0029 => USETV    0   1      ; mod
0030    KSTR     1   8      ; "+"
0031    GGET     2   0      ; "G"
0032    TGETS    2   2   9  ; "C"
0033    TGETS    2   2  10  ; "IMPORTANT"
0034    UGET     3   0      ; mod
0035    KSHORT   4   0
0036    ISGE     3   4
0037    JMP      3 => 0042
0038    KSTR     1  11      ; "-"
0039    GGET     3   0      ; "G"
0040    TGETS    3   3   9  ; "C"
0041    TGETS    2   3  12  ; "RED"
0042 => TGETS    3   0   4  ; "config"
0043    TGETS    3   3   7  ; "object"
0044    MOV      5   3
0045    TGETS    3   3  13  ; "update"
0046    CALL     3   1   2
0047    GGET     3   0      ; "G"
0048    TGETS    3   3  14  ; "HUD"
0049    MOV      5   3
0050    TGETS    3   3  15  ; "recalculate"
0051    CALL     3   1   2
0052    GGET     3  16      ; "attention_text"
0053    TDUP     5  20
0054    MOV      6   1
0055    GGET     7  17      ; "tostring"
0056    GGET     9  18      ; "math"
0057    TGETS    9   9  19  ; "abs"
0058    UGET    11   0      ; mod
0059    CALL     9   0   2
0060    CALLM    7   2   0
0061    CAT      6   6   7
0062    TSETS    6   5  21  ; "text"
0063    TGETS    6   0  22  ; "parent"
0064    TSETS    6   5  23  ; "cover"
0065    TSETS    2   5  24  ; "cover_colour"
0066    CALL     3   1   2
0067    GGET     3  25      ; "play_sound"
0068    KSTR     5  26      ; "highlight2"
0069    KNUM     6   0      ; 0.685
0070    KNUM     7   1      ; 0.2
0071    CALL     3   1   4
0072    GGET     3  25      ; "play_sound"
0073    KSTR     5  27      ; "generic1"
0074    CALL     3   1   2
0075    KPRI     3   2
0076    RET1     3   2

-- BYTECODE -- functions.lua:406-442
0001    GGET     2   0      ; "G"
0002    TGETS    2   2   1  ; "E_MANAGER"
0003    MOV      4   2
0004    TGETS    2   2   2  ; "add_event"
0005    GGET     5   3      ; "Event"
0006    TDUP     7   4
0007    NOT      8   1
0008    TSETS    8   7   5  ; "blockable"
0009    FNEW     8   6      ; functions.lua:410
0010    TSETS    8   7   7  ; "func"
0011    CALL     5   0   2
0012    CALLM    2   1   1
0013    UCLO     0 => 0014
0014 => RET0     0   1

-- BYTECODE -- functions.lua:444-477
0001    TDUP     0   0
0002    KSTR     1   1      ; "High Card"
0003    KSHORT   2   0
0004    GGET     3   2      ; "pairs"
0005    GGET     5   3      ; "G"
0006    TGETS    5   5   4  ; "GAME"
0007    TGETS    5   5   5  ; "hands"
0008    CALL     3   4   2
0009    ISNEXT   6 => 0043
0010 => GGET     8   6      ; "SMODS"
0011    TGETS    8   8   7  ; "is_poker_hand_visible"
0012    MOV     10   6
0013    CALL     8   2   2
0014    ISF          8
0015    JMP      9 => 0043
0016    TGETV    8   0   6
0017    ISNEP    8   0
0018    JMP      8 => 0021
0019    KSHORT   8   0
0020    TSETV    8   0   6
0021 => GGET     8   8      ; "to_big"
0022    TGETS   10   7   9  ; "level"
0023    CALL     8   2   2
0024    GGET     9   8      ; "to_big"
0025    MOV     11   2
0026    CALL     9   2   2
0027    ISLT     9   8
0028    JMP      8 => 0041
0029    GGET     8   8      ; "to_big"
0030    TGETS   10   7   9  ; "level"
0031    CALL     8   2   2
0032    GGET     9   8      ; "to_big"
0033    MOV     11   2
0034    CALL     9   2   2
0035    ISNEV    8   9
0036    JMP      8 => 0043
0037    TGETV    8   0   6
0038    TGETV    9   0   1
0039    ISGE     8   9
0040    JMP      8 => 0043
0041 => MOV      1   6
0042    TGETS    2   7   9  ; "level"
0043 => ITERN    6   3   3
0044    ITERL    6 => 0010
0045    GGET     3   6      ; "SMODS"
0046    TGETS    3   3  10  ; "upgrade_poker_hands"
0047    TDUP     5  11
0048    TSETS    1   5   5  ; "hands"
0049    CALL     3   1   2
0050    RET0     0   1

-- BYTECODE -- functions.lua:0-553
0001    GGET     0   0      ; "G"
0002    TGETS    0   0   1  ; "FUNCS"
0003    FNEW     1   3      ; functions.lua:4
0004    TSETS    1   0   2  ; "pvp_ready_button"
0005    GGET     0   0      ; "G"
0006    TGETS    0   0   1  ; "FUNCS"
0007    FNEW     1   5      ; functions.lua:14
0008    TSETS    1   0   4  ; "mp_toggle_ready"
0009    GGET     0   0      ; "G"
0010    TGETS    0   0   1  ; "FUNCS"
0011    TGETS    0   0   6  ; "skip_blind"
0012    GGET     1   0      ; "G"
0013    TGETS    1   1   1  ; "FUNCS"
0014    FNEW     2   7      ; functions.lua:33
0015    TSETS    2   1   6  ; "skip_blind"
0016    GGET     1   0      ; "G"
0017    TGETS    1   1   1  ; "FUNCS"
0018    TGETS    1   1   8  ; "can_play"
0019    GGET     2   0      ; "G"
0020    TGETS    2   2   1  ; "FUNCS"
0021    FNEW     3   9      ; functions.lua:41
0022    TSETS    3   2   8  ; "can_play"
0023    GGET     2   0      ; "G"
0024    TGETS    2   2   1  ; "FUNCS"
0025    TGETS    2   2  10  ; "can_open"
0026    GGET     3   0      ; "G"
0027    TGETS    3   3   1  ; "FUNCS"
0028    FNEW     4  11      ; functions.lua:51
0029    TSETS    4   3  10  ; "can_open"
0030    GGET     3   0      ; "G"
0031    TGETS    3   3   1  ; "FUNCS"
0032    TGETS    3   3  12  ; "select_blind"
0033    GGET     4   0      ; "G"
0034    TGETS    4   4   1  ; "FUNCS"
0035    FNEW     5  13      ; functions.lua:61
0036    TSETS    5   4  12  ; "select_blind"
0037    GGET     4   0      ; "G"
0038    TGETS    4   4   1  ; "FUNCS"
0039    TGETS    4   4   6  ; "skip_blind"
0040    GGET     5   0      ; "G"
0041    TGETS    5   5   1  ; "FUNCS"
0042    FNEW     6  14      ; functions.lua:85
0043    TSETS    6   5   6  ; "skip_blind"
0044    GGET     5   0      ; "G"
0045    TGETS    5   5   1  ; "FUNCS"
0046    FNEW     6  16      ; functions.lua:122
0047    TSETS    6   5  15  ; "view_nemesis_deck"
0048    GGET     5   0      ; "G"
0049    TGETS    5   5   1  ; "FUNCS"
0050    FNEW     6  18      ; functions.lua:136
0051    TSETS    6   5  17  ; "wipe_off"
0052    GGET     5   0      ; "G"
0053    TGETS    5   5   1  ; "FUNCS"
0054    FNEW     6  20      ; functions.lua:219
0055    TSETS    6   5  19  ; "continue_in_singleplayer"
0056    GGET     5   0      ; "G"
0057    TGETS    5   5   1  ; "FUNCS"
0058    FNEW     6  22      ; functions.lua:248
0059    TSETS    6   5  21  ; "attention_text_realtime"
0060    GGET     5   0      ; "G"
0061    TGETS    5   5   1  ; "FUNCS"
0062    FNEW     6  24      ; functions.lua:381
0063    TSETS    6   5  23  ; "overlay_endgame_menu"
0064    GGET     5  25      ; "PVP"
0065    TGETS    5   5  26  ; "UI"
0066    FNEW     6  28      ; functions.lua:406
0067    TSETS    6   5  27  ; "ease_lives"
0068    GGET     5  25      ; "PVP"
0069    TGETS    5   5  26  ; "UI"
0070    FNEW     6  30      ; functions.lua:444
0071    TSETS    6   5  29  ; "show_asteroid_hand_level_up"
0072    UCLO     0 => 0073
0073 => RET0     0   1

