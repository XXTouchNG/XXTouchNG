-- Compiled format documented in man 5 term

local sunpack = string.unpack or require "compat53.string".unpack

-- Arrays taken from term.h

local Booleans = {}
local Numbers = {}
local Strings = {}

Booleans[0] = "auto_left_margin"
Booleans[1] = "auto_right_margin"
Booleans[2] = "no_esc_ctlc"
Booleans[3] = "ceol_standout_glitch"
Booleans[4] = "eat_newline_glitch"
Booleans[5] = "erase_overstrike"
Booleans[6] = "generic_type"
Booleans[7] = "hard_copy"
Booleans[8] = "has_meta_key"
Booleans[9] = "has_status_line"
Booleans[10] = "insert_null_glitch"
Booleans[11] = "memory_above"
Booleans[12] = "memory_below"
Booleans[13] = "move_insert_mode"
Booleans[14] = "move_standout_mode"
Booleans[15] = "over_strike"
Booleans[16] = "status_line_esc_ok"
Booleans[17] = "dest_tabs_magic_smso"
Booleans[18] = "tilde_glitch"
Booleans[19] = "transparent_underline"
Booleans[20] = "xon_xoff"
Booleans[21] = "needs_xon_xoff"
Booleans[22] = "prtr_silent"
Booleans[23] = "hard_cursor"
Booleans[24] = "non_rev_rmcup"
Booleans[25] = "no_pad_char"
Booleans[26] = "non_dest_scroll_region"
Booleans[27] = "can_change"
Booleans[28] = "back_color_erase"
Booleans[29] = "hue_lightness_saturation"
Booleans[30] = "col_addr_glitch"
Booleans[31] = "cr_cancels_micro_mode"
Booleans[32] = "has_print_wheel"
Booleans[33] = "row_addr_glitch"
Booleans[34] = "semi_auto_right_margin"
Booleans[35] = "cpi_changes_res"
Booleans[36] = "lpi_changes_res"
Numbers[0] = "columns"
Numbers[1] = "init_tabs"
Numbers[2] = "lines"
Numbers[3] = "lines_of_memory"
Numbers[4] = "magic_cookie_glitch"
Numbers[5] = "padding_baud_rate"
Numbers[6] = "virtual_terminal"
Numbers[7] = "width_status_line"
Numbers[8] = "num_labels"
Numbers[9] = "label_height"
Numbers[10] = "label_width"
Numbers[11] = "max_attributes"
Numbers[12] = "maximum_windows"
Numbers[13] = "max_colors"
Numbers[14] = "max_pairs"
Numbers[15] = "no_color_video"
Numbers[16] = "buffer_capacity"
Numbers[17] = "dot_vert_spacing"
Numbers[18] = "dot_horz_spacing"
Numbers[19] = "max_micro_address"
Numbers[20] = "max_micro_jump"
Numbers[21] = "micro_col_size"
Numbers[22] = "micro_line_size"
Numbers[23] = "number_of_pins"
Numbers[24] = "output_res_char"
Numbers[25] = "output_res_line"
Numbers[26] = "output_res_horz_inch"
Numbers[27] = "output_res_vert_inch"
Numbers[28] = "print_rate"
Numbers[29] = "wide_char_size"
Numbers[30] = "buttons"
Numbers[31] = "bit_image_entwining"
Numbers[32] = "bit_image_type"
Strings[0] = "back_tab"
Strings[1] = "bell"
Strings[2] = "carriage_return"
Strings[3] = "change_scroll_region"
Strings[4] = "clear_all_tabs"
Strings[5] = "clear_screen"
Strings[6] = "clr_eol"
Strings[7] = "clr_eos"
Strings[8] = "column_address"
Strings[9] = "command_character"
Strings[10] = "cursor_address"
Strings[11] = "cursor_down"
Strings[12] = "cursor_home"
Strings[13] = "cursor_invisible"
Strings[14] = "cursor_left"
Strings[15] = "cursor_mem_address"
Strings[16] = "cursor_normal"
Strings[17] = "cursor_right"
Strings[18] = "cursor_to_ll"
Strings[19] = "cursor_up"
Strings[20] = "cursor_visible"
Strings[21] = "delete_character"
Strings[22] = "delete_line"
Strings[23] = "dis_status_line"
Strings[24] = "down_half_line"
Strings[25] = "enter_alt_charset_mode"
Strings[26] = "enter_blink_mode"
Strings[27] = "enter_bold_mode"
Strings[28] = "enter_ca_mode"
Strings[29] = "enter_delete_mode"
Strings[30] = "enter_dim_mode"
Strings[31] = "enter_insert_mode"
Strings[32] = "enter_secure_mode"
Strings[33] = "enter_protected_mode"
Strings[34] = "enter_reverse_mode"
Strings[35] = "enter_standout_mode"
Strings[36] = "enter_underline_mode"
Strings[37] = "erase_chars"
Strings[38] = "exit_alt_charset_mode"
Strings[39] = "exit_attribute_mode"
Strings[40] = "exit_ca_mode"
Strings[41] = "exit_delete_mode"
Strings[42] = "exit_insert_mode"
Strings[43] = "exit_standout_mode"
Strings[44] = "exit_underline_mode"
Strings[45] = "flash_screen"
Strings[46] = "form_feed"
Strings[47] = "from_status_line"
Strings[48] = "init_1string"
Strings[49] = "init_2string"
Strings[50] = "init_3string"
Strings[51] = "init_file"
Strings[52] = "insert_character"
Strings[53] = "insert_line"
Strings[54] = "insert_padding"
Strings[55] = "key_backspace"
Strings[56] = "key_catab"
Strings[57] = "key_clear"
Strings[58] = "key_ctab"
Strings[59] = "key_dc"
Strings[60] = "key_dl"
Strings[61] = "key_down"
Strings[62] = "key_eic"
Strings[63] = "key_eol"
Strings[64] = "key_eos"
Strings[65] = "key_f0"
Strings[66] = "key_f1"
Strings[67] = "key_f10"
Strings[68] = "key_f2"
Strings[69] = "key_f3"
Strings[70] = "key_f4"
Strings[71] = "key_f5"
Strings[72] = "key_f6"
Strings[73] = "key_f7"
Strings[74] = "key_f8"
Strings[75] = "key_f9"
Strings[76] = "key_home"
Strings[77] = "key_ic"
Strings[78] = "key_il"
Strings[79] = "key_left"
Strings[80] = "key_ll"
Strings[81] = "key_npage"
Strings[82] = "key_ppage"
Strings[83] = "key_right"
Strings[84] = "key_sf"
Strings[85] = "key_sr"
Strings[86] = "key_stab"
Strings[87] = "key_up"
Strings[88] = "keypad_local"
Strings[89] = "keypad_xmit"
Strings[90] = "lab_f0"
Strings[91] = "lab_f1"
Strings[92] = "lab_f10"
Strings[93] = "lab_f2"
Strings[94] = "lab_f3"
Strings[95] = "lab_f4"
Strings[96] = "lab_f5"
Strings[97] = "lab_f6"
Strings[98] = "lab_f7"
Strings[99] = "lab_f8"
Strings[100] = "lab_f9"
Strings[101] = "meta_off"
Strings[102] = "meta_on"
Strings[103] = "newline"
Strings[104] = "pad_char"
Strings[105] = "parm_dch"
Strings[106] = "parm_delete_line"
Strings[107] = "parm_down_cursor"
Strings[108] = "parm_ich"
Strings[109] = "parm_index"
Strings[110] = "parm_insert_line"
Strings[111] = "parm_left_cursor"
Strings[112] = "parm_right_cursor"
Strings[113] = "parm_rindex"
Strings[114] = "parm_up_cursor"
Strings[115] = "pkey_key"
Strings[116] = "pkey_local"
Strings[117] = "pkey_xmit"
Strings[118] = "print_screen"
Strings[119] = "prtr_off"
Strings[120] = "prtr_on"
Strings[121] = "repeat_char"
Strings[122] = "reset_1string"
Strings[123] = "reset_2string"
Strings[124] = "reset_3string"
Strings[125] = "reset_file"
Strings[126] = "restore_cursor"
Strings[127] = "row_address"
Strings[128] = "save_cursor"
Strings[129] = "scroll_forward"
Strings[130] = "scroll_reverse"
Strings[131] = "set_attributes"
Strings[132] = "set_tab"
Strings[133] = "set_window"
Strings[134] = "tab"
Strings[135] = "to_status_line"
Strings[136] = "underline_char"
Strings[137] = "up_half_line"
Strings[138] = "init_prog"
Strings[139] = "key_a1"
Strings[140] = "key_a3"
Strings[141] = "key_b2"
Strings[142] = "key_c1"
Strings[143] = "key_c3"
Strings[144] = "prtr_non"
Strings[145] = "char_padding"
Strings[146] = "acs_chars"
Strings[147] = "plab_norm"
Strings[148] = "key_btab"
Strings[149] = "enter_xon_mode"
Strings[150] = "exit_xon_mode"
Strings[151] = "enter_am_mode"
Strings[152] = "exit_am_mode"
Strings[153] = "xon_character"
Strings[154] = "xoff_character"
Strings[155] = "ena_acs"
Strings[156] = "label_on"
Strings[157] = "label_off"
Strings[158] = "key_beg"
Strings[159] = "key_cancel"
Strings[160] = "key_close"
Strings[161] = "key_command"
Strings[162] = "key_copy"
Strings[163] = "key_create"
Strings[164] = "key_end"
Strings[165] = "key_enter"
Strings[166] = "key_exit"
Strings[167] = "key_find"
Strings[168] = "key_help"
Strings[169] = "key_mark"
Strings[170] = "key_message"
Strings[171] = "key_move"
Strings[172] = "key_next"
Strings[173] = "key_open"
Strings[174] = "key_options"
Strings[175] = "key_previous"
Strings[176] = "key_print"
Strings[177] = "key_redo"
Strings[178] = "key_reference"
Strings[179] = "key_refresh"
Strings[180] = "key_replace"
Strings[181] = "key_restart"
Strings[182] = "key_resume"
Strings[183] = "key_save"
Strings[184] = "key_suspend"
Strings[185] = "key_undo"
Strings[186] = "key_sbeg"
Strings[187] = "key_scancel"
Strings[188] = "key_scommand"
Strings[189] = "key_scopy"
Strings[190] = "key_screate"
Strings[191] = "key_sdc"
Strings[192] = "key_sdl"
Strings[193] = "key_select"
Strings[194] = "key_send"
Strings[195] = "key_seol"
Strings[196] = "key_sexit"
Strings[197] = "key_sfind"
Strings[198] = "key_shelp"
Strings[199] = "key_shome"
Strings[200] = "key_sic"
Strings[201] = "key_sleft"
Strings[202] = "key_smessage"
Strings[203] = "key_smove"
Strings[204] = "key_snext"
Strings[205] = "key_soptions"
Strings[206] = "key_sprevious"
Strings[207] = "key_sprint"
Strings[208] = "key_sredo"
Strings[209] = "key_sreplace"
Strings[210] = "key_sright"
Strings[211] = "key_srsume"
Strings[212] = "key_ssave"
Strings[213] = "key_ssuspend"
Strings[214] = "key_sundo"
Strings[215] = "req_for_input"
Strings[216] = "key_f11"
Strings[217] = "key_f12"
Strings[218] = "key_f13"
Strings[219] = "key_f14"
Strings[220] = "key_f15"
Strings[221] = "key_f16"
Strings[222] = "key_f17"
Strings[223] = "key_f18"
Strings[224] = "key_f19"
Strings[225] = "key_f20"
Strings[226] = "key_f21"
Strings[227] = "key_f22"
Strings[228] = "key_f23"
Strings[229] = "key_f24"
Strings[230] = "key_f25"
Strings[231] = "key_f26"
Strings[232] = "key_f27"
Strings[233] = "key_f28"
Strings[234] = "key_f29"
Strings[235] = "key_f30"
Strings[236] = "key_f31"
Strings[237] = "key_f32"
Strings[238] = "key_f33"
Strings[239] = "key_f34"
Strings[240] = "key_f35"
Strings[241] = "key_f36"
Strings[242] = "key_f37"
Strings[243] = "key_f38"
Strings[244] = "key_f39"
Strings[245] = "key_f40"
Strings[246] = "key_f41"
Strings[247] = "key_f42"
Strings[248] = "key_f43"
Strings[249] = "key_f44"
Strings[250] = "key_f45"
Strings[251] = "key_f46"
Strings[252] = "key_f47"
Strings[253] = "key_f48"
Strings[254] = "key_f49"
Strings[255] = "key_f50"
Strings[256] = "key_f51"
Strings[257] = "key_f52"
Strings[258] = "key_f53"
Strings[259] = "key_f54"
Strings[260] = "key_f55"
Strings[261] = "key_f56"
Strings[262] = "key_f57"
Strings[263] = "key_f58"
Strings[264] = "key_f59"
Strings[265] = "key_f60"
Strings[266] = "key_f61"
Strings[267] = "key_f62"
Strings[268] = "key_f63"
Strings[269] = "clr_bol"
Strings[270] = "clear_margins"
Strings[271] = "set_left_margin"
Strings[272] = "set_right_margin"
Strings[273] = "label_format"
Strings[274] = "set_clock"
Strings[275] = "display_clock"
Strings[276] = "remove_clock"
Strings[277] = "create_window"
Strings[278] = "goto_window"
Strings[279] = "hangup"
Strings[280] = "dial_phone"
Strings[281] = "quick_dial"
Strings[282] = "tone"
Strings[283] = "pulse"
Strings[284] = "flash_hook"
Strings[285] = "fixed_pause"
Strings[286] = "wait_tone"
Strings[287] = "user0"
Strings[288] = "user1"
Strings[289] = "user2"
Strings[290] = "user3"
Strings[291] = "user4"
Strings[292] = "user5"
Strings[293] = "user6"
Strings[294] = "user7"
Strings[295] = "user8"
Strings[296] = "user9"
Strings[297] = "orig_pair"
Strings[298] = "orig_colors"
Strings[299] = "initialize_color"
Strings[300] = "initialize_pair"
Strings[301] = "set_color_pair"
Strings[302] = "set_foreground"
Strings[303] = "set_background"
Strings[304] = "change_char_pitch"
Strings[305] = "change_line_pitch"
Strings[306] = "change_res_horz"
Strings[307] = "change_res_vert"
Strings[308] = "define_char"
Strings[309] = "enter_doublewide_mode"
Strings[310] = "enter_draft_quality"
Strings[311] = "enter_italics_mode"
Strings[312] = "enter_leftward_mode"
Strings[313] = "enter_micro_mode"
Strings[314] = "enter_near_letter_quality"
Strings[315] = "enter_normal_quality"
Strings[316] = "enter_shadow_mode"
Strings[317] = "enter_subscript_mode"
Strings[318] = "enter_superscript_mode"
Strings[319] = "enter_upward_mode"
Strings[320] = "exit_doublewide_mode"
Strings[321] = "exit_italics_mode"
Strings[322] = "exit_leftward_mode"
Strings[323] = "exit_micro_mode"
Strings[324] = "exit_shadow_mode"
Strings[325] = "exit_subscript_mode"
Strings[326] = "exit_superscript_mode"
Strings[327] = "exit_upward_mode"
Strings[328] = "micro_column_address"
Strings[329] = "micro_down"
Strings[330] = "micro_left"
Strings[331] = "micro_right"
Strings[332] = "micro_row_address"
Strings[333] = "micro_up"
Strings[334] = "order_of_pins"
Strings[335] = "parm_down_micro"
Strings[336] = "parm_left_micro"
Strings[337] = "parm_right_micro"
Strings[338] = "parm_up_micro"
Strings[339] = "select_char_set"
Strings[340] = "set_bottom_margin"
Strings[341] = "set_bottom_margin_parm"
Strings[342] = "set_left_margin_parm"
Strings[343] = "set_right_margin_parm"
Strings[344] = "set_top_margin"
Strings[345] = "set_top_margin_parm"
Strings[346] = "start_bit_image"
Strings[347] = "start_char_set_def"
Strings[348] = "stop_bit_image"
Strings[349] = "stop_char_set_def"
Strings[350] = "subscript_characters"
Strings[351] = "superscript_characters"
Strings[352] = "these_cause_cr"
Strings[353] = "zero_motion"
Strings[354] = "char_set_names"
Strings[355] = "key_mouse"
Strings[356] = "mouse_info"
Strings[357] = "req_mouse_pos"
Strings[358] = "get_mouse"
Strings[359] = "set_a_foreground"
Strings[360] = "set_a_background"
Strings[361] = "pkey_plab"
Strings[362] = "device_type"
Strings[363] = "code_set_init"
Strings[364] = "set0_des_seq"
Strings[365] = "set1_des_seq"
Strings[366] = "set2_des_seq"
Strings[367] = "set3_des_seq"
Strings[368] = "set_lr_margin"
Strings[369] = "set_tb_margin"
Strings[370] = "bit_image_repeat"
Strings[371] = "bit_image_newline"
Strings[372] = "bit_image_carriage_return"
Strings[373] = "color_names"
Strings[374] = "define_bit_image_region"
Strings[375] = "end_bit_image_region"
Strings[376] = "set_color_band"
Strings[377] = "set_page_length"
Strings[378] = "display_pc_char"
Strings[379] = "enter_pc_charset_mode"
Strings[380] = "exit_pc_charset_mode"
Strings[381] = "enter_scancode_mode"
Strings[382] = "exit_scancode_mode"
Strings[383] = "pc_term_options"
Strings[384] = "scancode_escape"
Strings[385] = "alt_scancode_esc"
Strings[386] = "enter_horizontal_hl_mode"
Strings[387] = "enter_left_hl_mode"
Strings[388] = "enter_low_hl_mode"
Strings[389] = "enter_right_hl_mode"
Strings[390] = "enter_top_hl_mode"
Strings[391] = "enter_vertical_hl_mode"
Strings[392] = "set_a_attributes"
Strings[393] = "set_pglen_inch"

-- internal caps
Strings[394] = "termcap_init2"
Strings[395] = "termcap_reset"
Numbers[33] = "magic_cookie_glitch_ul"
Booleans[37] = "backspaces_with_bs"
Booleans[38] = "crt_no_scrolling"
Booleans[39] = "no_correctly_working_cr"
Numbers[34] = "carriage_return_delay"
Numbers[35] = "new_line_delay"
Strings[396] = "linefeed_if_not_lf"
Strings[397] = "backspace_if_not_bs"
Booleans[40] = "gnu_has_meta_key"
Booleans[41] = "linefeed_is_newline"
Numbers[36] = "backspace_delay"
Numbers[37] = "horizontal_tab_delay"
Numbers[38] = "number_of_function_keys"
Strings[398] = "other_non_function_keys"
Strings[399] = "arrow_key_map"
Booleans[42] = "has_hardware_tabs"
Booleans[43] = "return_does_clr_eol"
Strings[400] = "acs_ulcorner"
Strings[401] = "acs_llcorner"
Strings[402] = "acs_urcorner"
Strings[403] = "acs_lrcorner"
Strings[404] = "acs_ltee"
Strings[405] = "acs_rtee"
Strings[406] = "acs_btee"
Strings[407] = "acs_ttee"
Strings[408] = "acs_hline"
Strings[409] = "acs_vline"
Strings[410] = "acs_plus"
Strings[411] = "memory_lock"
Strings[412] = "memory_unlock"
Strings[413] = "box_chars_1"

local short_to_long = {
	-- Boolean
	bw = "auto_left_margin";
	am = "auto_right_margin";
	bce = "back_color_erase";
	ccc = "can_change";
	xhp = "ceol_standout_glitch";
	xhpa = "col_addr_glitch";
	cpix = "cpi_changes_res";
	crxm = "cr_cancels_micro_mode";
	xt = "dest_tabs_magic_smso";
	xenl = "eat_newline_glitch";
	eo = "erase_overstrike";
	gn = "generic_type";
	hc = "hard_copy";
	chts = "hard_cursor";
	km = "has_meta_key";
	daisy = "has_print_wheel";
	hs = "has_status_line";
	hls = "hue_lightness_saturation";
	["in"] = "insert_null_glitch";
	lpix = "lpi_changes_res";
	da = "memory_above";
	db = "memory_below";
	mir = "move_insert_mode";
	msgr = "move_standout_mode";
	nxon = "needs_xon_xoff";
	xsb = "no_esc_ctlc";
	npc = "no_pad_char";
	ndscr = "non_dest_scroll_region";
	nrrmc = "non_rev_rmcup";
	os = "over_strike";
	mc5i = "prtr_silent";
	xvpa = "row_addr_glitch";
	sam = "semi_auto_right_margin";
	eslok = "status_line_esc_ok";
	hz = "tilde_glitch";
	ul = "transparent_underline";
	xon = "xon_xoff";

	-- Numeric
	cols = "columns";
	it = "init_tabs";
	lh = "label_height";
	lw = "label_width";
	lines = "lines";
	lm = "lines_of_memory";
	xmc = "magic_cookie_glitch";
	ma = "max_attributes";
	colors = "max_colors";
	pairs = "max_pairs";
	wnum = "maximum_windows";
	ncv = "no_color_video";
	nlab = "num_labels";
	pb = "padding_baud_rate";
	vt = "virtual_terminal";
	wsl = "width_status_line";

	-- Non-SVr4.0 Numeric
	bitwin = "bit_image_entwining";
	bitype = "bit_image_type";
	bufsz = "buffer_capacity";
	btns = "buttons";
	spinh = "dot_horz_spacing";
	spinv = "dot_vert_spacing";
	maddr = "max_micro_address";
	mjump = "max_micro_jump";
	mcs = "micro_col_size";
	mls = "micro_line_size";
	npins = "number_of_pins";
	orc = "output_res_char";
	orhi = "output_res_horz_inch";
	orl = "output_res_line";
	orvi = "output_res_vert_inch";
	cps = "print_rate";
	widcs = "wide_char_size";

	-- String
	acsc = "acs_chars";
	cbt = "back_tab";
	bel = "bell";
	cr = "carriage_return";
	cpi = "change_char_pitch";
	lpi = "change_line_pitch";
	chr = "change_res_horz";
	cvr = "change_res_vert";
	csr = "change_scroll_region";
	rmp = "char_padding";
	tbc = "clear_all_tabs";
	mgc = "clear_margins";
	clear = "clear_screen";
	el1 = "clr_bol";
	el = "clr_eol";
	ed = "clr_eos";
	hpa = "column_address";
	cmdch = "command_character";
	cwin = "create_window";
	cup = "cursor_address";
	cud1 = "cursor_down";
	home = "cursor_home";
	civis = "cursor_invisible";
	cub1 = "cursor_left";
	mrcup = "cursor_mem_address";
	cnorm = "cursor_normal";
	cuf1 = "cursor_right";
	ll = "cursor_to_ll";
	cuu1 = "cursor_up";
	cvvis = "cursor_visible";
	defc = "define_char";
	dch1 = "delete_character";
	dl1 = "delete_line";
	dial = "dial_phone";
	dsl = "dis_status_line";
	dclk = "display_clock";
	hd = "down_half_line";
	enacs = "ena_acs";
	smacs = "enter_alt_charset_mode";
	smam = "enter_am_mode";
	blink = "enter_blink_mode";
	bold = "enter_bold_mode";
	smcup = "enter_ca_mode";
	smdc = "enter_delete_mode";
	dim = "enter_dim_mode";
	swidm = "enter_doublewide_mode";
	sdrfq = "enter_draft_quality";
	smir = "enter_insert_mode";
	sitm = "enter_italics_mode";
	slm = "enter_leftward_mode";
	smicm = "enter_micro_mode";
	snlq = "enter_near_letter_quality";
	snrmq = "enter_normal_quality";
	prot = "enter_protected_mode";
	rev = "enter_reverse_mode";
	invis = "enter_secure_mode";
	sshm = "enter_shadow_mode";
	smso = "enter_standout_mode";
	ssubm = "enter_subscript_mode";
	ssupm = "enter_superscript_mode";
	smul = "enter_underline_mode";
	sum = "enter_upward_mode";
	smxon = "enter_xon_mode";
	ech = "erase_chars";
	rmacs = "exit_alt_charset_mode";
	rmam = "exit_am_mode";
	sgr0 = "exit_attribute_mode";
	rmcup = "exit_ca_mode";
	rmdc = "exit_delete_mode";
	rwidm = "exit_doublewide_mode";
	rmir = "exit_insert_mode";
	ritm = "exit_italics_mode";
	rlm = "exit_leftward_mode";
	rmicm = "exit_micro_mode";
	rshm = "exit_shadow_mode";
	rmso = "exit_standout_mode";
	rsubm = "exit_subscript_mode";
	rsupm = "exit_superscript_mode";
	rmul = "exit_underline_mode";
	rum = "exit_upward_mode";
	rmxon = "exit_xon_mode";
	pause = "fixed_pause";
	hook = "flash_hook";
	flash = "flash_screen";
	ff = "form_feed";
	fsl = "from_status_line";
	wingo = "goto_window";
	hup = "hangup";
	is1 = "init_1string";
	is2 = "init_2string";
	is3 = "init_3string";
	["if"] = "init_file";
	iprog = "init_prog";
	initc = "initialize_color";
	initp = "initialize_pair";
	ich1 = "insert_character";
	il1 = "insert_line";
	ip = "insert_padding";
	ka1 = "key_a1";
	ka3 = "key_a3";
	kb2 = "key_b2";
	kbs = "key_backspace";
	kbeg = "key_beg";
	kcbt = "key_btab";
	kc1 = "key_c1";
	kc3 = "key_c3";
	kcan = "key_cancel";
	ktbc = "key_catab";
	kclr = "key_clear";
	kclo = "key_close";
	kcmd = "key_command";
	kcpy = "key_copy";
	kcrt = "key_create";
	kctab = "key_ctab";
	kdch1 = "key_dc";
	kdl1 = "key_dl";
	kcud1 = "key_down";
	krmir = "key_eic";
	kend = "key_end";
	kent = "key_enter";
	kel = "key_eol";
	ked = "key_eos";
	kext = "key_exit";
	kf0 = "key_f0";
	kf1 = "key_f1";
	kf10 = "key_f10";
	kf11 = "key_f11";
	kf12 = "key_f12";
	kf13 = "key_f13";
	kf14 = "key_f14";
	kf15 = "key_f15";
	kf16 = "key_f16";
	kf17 = "key_f17";
	kf18 = "key_f18";
	kf19 = "key_f19";
	kf2 = "key_f2";
	kf20 = "key_f20";
	kf21 = "key_f21";
	kf22 = "key_f22";
	kf23 = "key_f23";
	kf24 = "key_f24";
	kf25 = "key_f25";
	kf26 = "key_f26";
	kf27 = "key_f27";
	kf28 = "key_f28";
	kf29 = "key_f29";
	kf3 = "key_f3";
	kf30 = "key_f30";
	kf31 = "key_f31";
	kf32 = "key_f32";
	kf33 = "key_f33";
	kf34 = "key_f34";
	kf35 = "key_f35";
	kf36 = "key_f36";
	kf37 = "key_f37";
	kf38 = "key_f38";
	kf39 = "key_f39";
	kf4 = "key_f4";
	kf40 = "key_f40";
	kf41 = "key_f41";
	kf42 = "key_f42";
	kf43 = "key_f43";
	kf44 = "key_f44";
	kf45 = "key_f45";
	kf46 = "key_f46";
	kf47 = "key_f47";
	kf48 = "key_f48";
	kf49 = "key_f49";
	kf5 = "key_f5";
	kf50 = "key_f50";
	kf51 = "key_f51";
	kf52 = "key_f52";
	kf53 = "key_f53";
	kf54 = "key_f54";
	kf55 = "key_f55";
	kf56 = "key_f56";
	kf57 = "key_f57";
	kf58 = "key_f58";
	kf59 = "key_f59";
	kf6 = "key_f6";
	kf60 = "key_f60";
	kf61 = "key_f61";
	kf62 = "key_f62";
	kf63 = "key_f63";
	kf7 = "key_f7";
	kf8 = "key_f8";
	kf9 = "key_f9";
	kfnd = "key_find";
	khlp = "key_help";
	khome = "key_home";
	kich1 = "key_ic";
	kil1 = "key_il";
	kcub1 = "key_left";
	kll = "key_ll";
	kmrk = "key_mark";
	kmsg = "key_message";
	kmov = "key_move";
	knxt = "key_next";
	knp = "key_npage";
	kopn = "key_open";
	kopt = "key_options";
	kpp = "key_ppage";
	kprv = "key_previous";
	kprt = "key_print";
	krdo = "key_redo";
	kref = "key_reference";
	krfr = "key_refresh";
	krpl = "key_replace";
	krst = "key_restart";
	kres = "key_resume";
	kcuf1 = "key_right";
	ksav = "key_save";
	kBEG = "key_sbeg";
	kCAN = "key_scancel";
	kCMD = "key_scommand";
	kCPY = "key_scopy";
	kCRT = "key_screate";
	kDC = "key_sdc";
	kDL = "key_sdl";
	kslt = "key_select";
	kEND = "key_send";
	kEOL = "key_seol";
	kEXT = "key_sexit";
	kind = "key_sf";
	kFND = "key_sfind";
	kHLP = "key_shelp";
	kHOM = "key_shome";
	kIC = "key_sic";
	kLFT = "key_sleft";
	kMSG = "key_smessage";
	kMOV = "key_smove";
	kNXT = "key_snext";
	kOPT = "key_soptions";
	kPRV = "key_sprevious";
	kPRT = "key_sprint";
	kri = "key_sr";
	kRDO = "key_sredo";
	kRPL = "key_sreplace";
	kRIT = "key_sright";
	kRES = "key_srsume";
	kSAV = "key_ssave";
	kSPD = "key_ssuspend";
	khts = "key_stab";
	kUND = "key_sundo";
	kspd = "key_suspend";
	kund = "key_undo";
	kcuu1 = "key_up";
	rmkx = "keypad_local";
	smkx = "keypad_xmit";
	lf0 = "lab_f0";
	lf1 = "lab_f1";
	lf10 = "lab_f10";
	lf2 = "lab_f2";
	lf3 = "lab_f3";
	lf4 = "lab_f4";
	lf5 = "lab_f5";
	lf6 = "lab_f6";
	lf7 = "lab_f7";
	lf8 = "lab_f8";
	lf9 = "lab_f9";
	fln = "label_format";
	rmln = "label_off";
	smln = "label_on";
	rmm = "meta_off";
	smm = "meta_on";
	mhpa = "micro_column_address";
	mcud1 = "micro_down";
	mcub1 = "micro_left";
	mcuf1 = "micro_right";
	mvpa = "micro_row_address";
	mcuu1 = "micro_up";
	nel = "newline";
	porder = "order_of_pins";
	oc = "orig_colors";
	op = "orig_pair";
	pad = "pad_char";
	dch = "parm_dch";
	dl = "parm_delete_line";
	cud = "parm_down_cursor";
	mcud = "parm_down_micro";
	ich = "parm_ich";
	indn = "parm_index";
	il = "parm_insert_line";
	cub = "parm_left_cursor";
	mcub = "parm_left_micro";
	cuf = "parm_right_cursor";
	mcuf = "parm_right_micro";
	rin = "parm_rindex";
	cuu = "parm_up_cursor";
	mcuu = "parm_up_micro";
	pfkey = "pkey_key";
	pfloc = "pkey_local";
	pfx = "pkey_xmit";
	pln = "plab_norm";
	mc0 = "print_screen";
	mc5p = "prtr_non";
	mc4 = "prtr_off";
	mc5 = "prtr_on";
	pulse = "pulse";
	qdial = "quick_dial";
	rmclk = "remove_clock";
	rep = "repeat_char";
	rfi = "req_for_input";
	rs1 = "reset_1string";
	rs2 = "reset_2string";
	rs3 = "reset_3string";
	rf = "reset_file";
	rc = "restore_cursor";
	vpa = "row_address";
	sc = "save_cursor";
	ind = "scroll_forward";
	ri = "scroll_reverse";
	scs = "select_char_set";
	sgr = "set_attributes";
	setb = "set_background";
	smgb = "set_bottom_margin";
	smgbp = "set_bottom_margin_parm";
	sclk = "set_clock";
	scp = "set_color_pair";
	setf = "set_foreground";
	smgl = "set_left_margin";
	smglp = "set_left_margin_parm";
	smgr = "set_right_margin";
	smgrp = "set_right_margin_parm";
	hts = "set_tab";
	smgt = "set_top_margin";
	smgtp = "set_top_margin_parm";
	wind = "set_window";
	sbim = "start_bit_image";
	scsd = "start_char_set_def";
	rbim = "stop_bit_image";
	rcsd = "stop_char_set_def";
	subcs = "subscript_characters";
	supcs = "superscript_characters";
	ht = "tab";
	docr = "these_cause_cr";
	tsl = "to_status_line";
	tone = "tone";
	uc = "underline_char";
	hu = "up_half_line";
	u0 = "user0";
	u1 = "user1";
	u2 = "user2";
	u3 = "user3";
	u4 = "user4";
	u5 = "user5";
	u6 = "user6";
	u7 = "user7";
	u8 = "user8";
	u9 = "user9";
	wait = "wait_tone";
	xoffc = "xoff_character";
	xonc = "xon_character";
	zerom = "zero_motion";

	-- Non-SVr4.0 String
	scesa = "alt_scancode_esc";
	bicr = "bit_image_carriage_return";
	binel = "bit_image_newline";
	birep = "bit_image_repeat";
	csnm = "char_set_names";
	csin = "code_set_init";
	colornm = "color_names";
	defbi = "define_bit_image_region";
	devt = "device_type";
	dispc = "display_pc_char";
	endbi = "end_bit_image_region";
	smpch = "enter_pc_charset_mode";
	smsc = "enter_scancode_mode";
	rmpch = "exit_pc_charset_mode";
	rmsc = "exit_scancode_mode";
	getm = "get_mouse";
	kmous = "key_mouse";
	minfo = "mouse_info";
	pctrm = "pc_term_options";
	pfxl = "pkey_plab";
	reqmp = "req_mouse_pos";
	scesc = "scancode_escape";
	s0ds = "set0_des_seq";
	s1ds = "set1_des_seq";
	s2ds = "set2_des_seq";
	s3ds = "set3_des_seq";
	setab = "set_a_background";
	setaf = "set_a_foreground";
	setcolor = "set_color_band";
	smglr = "set_lr_margin";
	slines = "set_page_length";
	smgtb = "set_tb_margin";

	-- XSI
	ehhlm = "enter_horizontal_hl_mode";
	elhlm = "enter_left_hl_mode";
	elohlm = "enter_low_hl_mode";
	erhlm = "enter_right_hl_mode";
	ethlm = "enter_top_hl_mode";
	evhlm = "enter_vertical_hl_mode";
	sgr1 = "set_a_attributes";
	slength = "set_pglen_inch";
}

local caps_mt = {
	__name = "tui.terminfo capabilities";
}

function caps_mt:__index(k)
	k = short_to_long[k]
	if k ~= nil then
		return rawget(self, k)
	end
end

local function read_compiled_terminfo(contents)
	local magic, name_size, n_booleans, n_numbers, n_offsets, s_string, pos = sunpack("<I2 I2 I2 I2 I2 I2", contents)
	assert(magic == 282)
	local names = {}
	if name_size ~= 65535 and name_size > 1 then
		for name in contents:sub(pos, pos-2+name_size):gmatch("[^|]+") do
			table.insert(names, name)
		end
		pos = pos + name_size
	end
	local caps = setmetatable({}, caps_mt)
	if n_booleans ~= 65535 then
		for i=0, n_booleans-1 do
			if contents:byte(pos+i) ~= 0 then
				caps[Booleans[i]] = true
			end
		end
		pos = pos + n_booleans
	end
	-- pad to even offset
	if pos % 2 == 0 then
		assert(contents:byte(pos) == 0)
		pos = pos + 1
	end
	if n_numbers ~= 65535 then
		for i=0, n_numbers-1 do
			local n = sunpack("<I2", contents, pos+i*2)
			if n ~= 65535 then
				caps[Numbers[i]] = n
			end
		end
		pos = pos + n_numbers*2
	end
	if n_offsets ~= 65535 then
		local string_table_offset = pos + n_offsets*2
		for i=0, n_offsets-1 do
			local offset = sunpack("<I2", contents, pos+i*2)
			if offset ~= 65535 then
				assert(offset < s_string)
				local s = sunpack("z", contents, string_table_offset+offset)
				caps[Strings[i]] = s
			end
		end
	end
	return caps, names
end

local escapes = {
	e = "\27";
	E = "\27";
	["\\"] = "\\";
	["^"] = "^";
	[","] = ",";
	[":"] = ":";
	["0"] = "\0";
	n = "\n";
	l = "\n"; -- line feed?
	r = "\r";
	t = "\t";
	b = "\b";
	f = "\f";
	s = " ";
}
local function read_text_terminfo(contents)
	local caps = setmetatable({}, caps_mt)
	local names = {}

	-- strip comments
	contents = contents:gsub("%f[^\n%z]#\n", "")

	local iter, state, last = contents:gmatch("[^,%s][^,]*")
	do
		local name_list
		name_list, last = iter(state, last)
		for name in name_list:gmatch("[^|]+") do
			names[name] = true
		end
	end
	for item in iter, state, last do
		local k, type, v = item:match("^([^=#]+)([=#]?)(.*)$")
		k = short_to_long[k] or k
		if type == "#" then
			if v:match("^0[^x]") then
				v = tonumber(v, 8)
			else
				v = tonumber(v)
			end
		elseif type == "" then
			v = true
		else -- string
			v = v:gsub("%^(.)", function(c)
				return string.char(string.byte(c) % 32)
			end)
			-- TODO: fix bug here when input has \\\\000
			v = v:gsub("\\([0-7][0-7][0-7])", function(o)
				return string.char(tonumber(o, 8))
			end)
			v = v:gsub("\\(.)", escapes)
		end
		caps[k] = v
	end
	return caps, names
end

local function read_terminfo(contents)
	if contents:sub(1,2) == "\26\1" then
		return read_compiled_terminfo(contents)
	else
		return read_text_terminfo(contents)
	end
end

local function open_terminfo(path)
	local fd, err, errno = io.open(path , "rb")
	if not fd then
		return nil, err, errno
	end
	local contents, err2, errno2 = fd:read("*a")
	fd:close()
	if not contents then
		return nil, err2, errno2
	end
	return read_terminfo(contents)
end

local ENOENT = 2
local default_system_dir = "/usr/share/terminfo"

local function find_terminfo(TERM, dirs)
	if TERM == nil then
		TERM = assert(os.getenv "TERM", "no $TERM set")
	end
	if dirs == nil then
		local TERMINFO = os.getenv "TERMINFO"
		if TERMINFO then
			dirs = { TERMINFO:gsub("/?$", "") }
		else
			dirs = { }
			local HOME = os.getenv "HOME"
			if HOME then
				dirs[1] = os.getenv "HOME" .. "/.terminfo"
			end
			local TERMINFO_DIRS = os.getenv "TERMINFO_DIRS"
			if TERMINFO_DIRS then
				for dir in TERMINFO_DIRS:gmatch("[^:]*") do
					if dir == "" then
						dir = default_system_dir
					else
						dir = dir:gsub("/?$", "")
					end
					table.insert(dirs, dir)
				end
			else
				table.insert(dirs, default_system_dir)
			end
		end
	end
	local caps, names, errno
	for _, dir in ipairs(dirs) do
		local path = string.format("%s/%s/%s", dir, TERM:sub(1, 1), TERM)
		caps, names, errno = open_terminfo(path)

		-- On some system, the subdirectory is the first char's byte
		-- See: https://invisible-island.net/ncurses/NEWS.html#t20071117
		if caps == nil or errno == ENOENT then
			path = string.format("%s/%02x/%s", dir, TERM:byte(1), TERM)
			caps, names, errno = open_terminfo(path)
		end

		if caps ~= nil or errno ~= ENOENT then
			break
		end
	end
	return caps, names, errno
end

return {
	read_compiled = read_compiled_terminfo;
	read_text = read_text_terminfo;
	read = read_terminfo;
	open = open_terminfo;
	find = find_terminfo;
}
