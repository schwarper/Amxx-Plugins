#pragma semicolon 1

#include <amxmodx>
#include <reapi>

#define TaskId 		1337

enum _:szBoolNames {
	//ini
	bWait_RoundEnd,
	bPreShowHud,
	bPostShowHud,
	bMapWeather,
	//Normal
	bVoteStarted,
	bMapChosen
}
enum _:szClientsBoolNames {
	bClient_VotedMap,
	bClient_VotedWeather,
	bClient_VotedRTV
}
enum _:szValueNames {
	szMapMenuszData[MAX_MENU_LENGTH],
	szWeatherMenuszData[MAX_MENU_LENGTH],
	szPostHudMenuszData[475],
	szCurrentMap[32],
	szLastMap[32],
	szLastSecondMap[32],
	iMapVotes[5],
	iWeatherVotes[3],
	iPreHud_Color[3],
	Float:flPreHud_Coords[2],
	iPostHud_Color[3],
	Float:flPostHud_Coords[2],
	iMapCount,
	iRTVCount,
	iAllVotes,
	iHudsync,
	iVoteTime,
	iMapMenuKey,
	iWeatherMenuKey,
	iPercent,
	iNumRTV,
	HookChain:RoundEnd_Post
}
enum _:szLocalInfoNames {
	szLocalConfigsdir,
	szLocalCurrentWeather,
	szLocalLastMap,
	szLocalLastSecondMap
};

new bool:g_bBools[szBoolNames],
	bool:g_bClientBools[szClientsBoolNames][MAX_CLIENTS + 1],
	g_iValues[szValueNames];

new Array:g_aMapName,
	g_aszMapNames[6][32];

new iForward[4];

new g_szLocalInfoNames[szLocalInfoNames][] = {
	"amxx_configsdir",
	"rmc_currentmap",
	"rmc_lastmap",
	"rmc_lastsecondmap"
};

public plugin_init() {
	register_plugin("ReMapChooser", "0.0.2", "PurposeLess");
	register_dictionary("remapchooser.txt");

	register_menucmd(register_menuid("MapChooser_Map_Menu"), 1023, "@ShowMapVote_Handler");

	if(g_bBools[bMapWeather]) {
		register_menucmd(register_menuid("MapChooser_Weather_Menu"), 1023, "@ShowMapVote_Weather_Handler");
	}

	set_task(45.0, "@Task_Start_Vote", .flags = "d");

	if(g_bBools[bPreShowHud] || g_bBools[bPostShowHud]) {
		g_iValues[iHudsync] = CreateHudSyncObj();
	}

	iForward[0] = CreateMultiForward("rmc_timer_started_post", ET_IGNORE, FP_CELL);
	iForward[1] = CreateMultiForward("rmc_vote_started_post", ET_IGNORE, FP_CELL);
	iForward[2] = CreateMultiForward("rmc_map_chosen_post", ET_IGNORE, FP_CELL);
	iForward[3] = CreateMultiForward("rmc_rtv_voted_post", ET_IGNORE, FP_CELL);
}

public plugin_end() {
	ArrayDestroy(g_aMapName);
}

public client_disconnected(pPlayer) {
	if(g_bClientBools[bClient_VotedRTV][pPlayer]) {
		g_bClientBools[bClient_VotedRTV][pPlayer] = false;
		g_iValues[iRTVCount]--;
	}
}

@Task_Start_Vote() {
	if(g_bBools[bVoteStarted]) {
		return;
	}

	ExecuteForward(iForward[1], _, 0);

	g_bBools[bVoteStarted] = true;
	g_bBools[bMapChosen] = false;
	@SetMaps();
	rg_send_audio(0, "Gman/gman_choose2.wav");
	set_cvar_float("mp_timelimit", 0.0);
	set_task(1.0, "@Task_Vote_Remaining", .flags = "a", .repeat = 10);
	ExecuteForward(iForward[0], _, 0);
}

@SetMaps() {
	for(new i = 0, iMapNums[5]; i < 5; i++) {
		do iMapNums[i] = random(g_iValues[iMapCount]);
		while(AlreadyExists(iMapNums[i], iMapNums, i));
	}
}

@Task_Vote_Remaining() {
	static iTimer = 10;
	iTimer--;

	switch(iTimer) {
		case 0: {
			client_print_prefix(0, print_team_red, "%L", LANG_PLAYER, "RMC_PRINT_COUNTDOWN_END");

			arrayset(g_iValues[iMapVotes], 0, sizeof(g_iValues[iMapVotes]));
			arrayset(g_iValues[iWeatherVotes], 0, sizeof(g_iValues[iWeatherVotes]));
			arrayset(g_bClientBools[bClient_VotedMap], false, MAX_CLIENTS + 1);
			arrayset(g_bClientBools[bClient_VotedWeather], false, MAX_CLIENTS + 1);
			arrayset(g_bClientBools[bClient_VotedRTV], false, MAX_CLIENTS + 1);

			set_task(1.0, "@Task_ShowMenu", TaskId, .flags = "b");

			iTimer = 10;

			if(g_bBools[bPreShowHud] || g_bBools[bPostShowHud]) {
				ClearSyncHud(0, g_iValues[iHudsync]);
			}
		}
		case 1,2,3,4,5: @ShowTimer(iTimer, 6 - iTimer);
		default: client_print_prefix(0, print_team_red, "%L", LANG_PLAYER, "RMC_PRINT_COUNTDOWN_GO", iTimer);
	}
}

@ShowTimer(const iTimer, const iNum) {
	client_print_prefix(0, print_team_red, "%L", LANG_PLAYER, "RMC_PRINT_COUNTDOWN_GO", iTimer);

	if(g_bBools[bPreShowHud]) {
		new szszData[MAX_FMT_LENGTH], iLen;
		iLen = formatex(szszData[iLen], charsmax(szszData) - iLen, "%L", LANG_PLAYER, "RMC_HUD_TITLE_PRE_POST", g_iValues[iVoteTime]);

		for(new i = 0; i < iNum; i++) {
			iLen += formatex(szszData[iLen], charsmax(szszData) - iLen, "^n%d. %s [0%%%%%%]", i + 1, g_aszMapNames[i]);
		}

		set_hudmessage(g_iValues[iPreHud_Color][0], g_iValues[iPreHud_Color][1], g_iValues[iPreHud_Color][2], g_iValues[flPreHud_Coords][0], g_iValues[flPreHud_Coords][1], 0, 0.0, 1.0, 0.0, 0.0);
		ShowSyncHudMsg(0, g_iValues[iHudsync], szszData);
	}
}

@Task_ShowMenu() {
	if(g_iValues[iVoteTime] > 0) {
		g_iValues[iVoteTime]--;
		@ShowMapVote();
	}
	else {
		if(g_bBools[bPostShowHud]) {
			ClearSyncHud(0, g_iValues[iHudsync]);
		}
		show_menu(0, 0, "^n");
		@End_Vote();
		remove_task(TaskId);
	}
}

@ShowMapVote() {
	g_iValues[iPercent] = g_iValues[iAllVotes] ? 100 / g_iValues[iAllVotes] : 0;

	@MapMenu();
	@WeatherMenu();

	if(g_bBools[bPostShowHud]) {
		@PostHudMenu();
	}

	for(new pPlayer = 1; pPlayer <= MaxClients; pPlayer++) {
		if(!is_user_connected(pPlayer) || is_user_bot(pPlayer)) {
			continue;
		}

		if(!g_bClientBools[bClient_VotedMap][pPlayer]) {
			show_menu(pPlayer, g_iValues[iMapMenuKey], g_iValues[szMapMenuszData], -1, "MapChooser_Map_Menu");
		}
		else {
			if(g_bBools[bMapWeather] && !g_bClientBools[bClient_VotedWeather][pPlayer]) {
				show_menu(pPlayer, g_iValues[iWeatherMenuKey], g_iValues[szWeatherMenuszData], -1, "MapChooser_Weather_Menu");
			}
			else {
				if(g_bBools[bPostShowHud]) {
					ShowSyncHudMsg(pPlayer, g_iValues[iHudsync], g_iValues[szPostHudMenuszData]);
				}
			}
		}
	}
}

@MapMenu() {
	new iMapMenuLen;

	iMapMenuLen = formatex(g_iValues[szMapMenuszData][iMapMenuLen], charsmax(g_iValues[szMapMenuszData]) - iMapMenuLen, "%L^n%L", LANG_PLAYER, "RMC_MENU_TITLE_MAP_WEATHER", LANG_PLAYER, "RMC_MENU_TITLE_MAP_WEATHER_COUNTDOWN", g_iValues[iVoteTime]);

	iMapMenuLen += formatex(g_iValues[szMapMenuszData][iMapMenuLen], charsmax(g_iValues[szMapMenuszData]) - iMapMenuLen, "^n^n\r%L", LANG_PLAYER, "RMC_MENU_MAP_NAME");

	for(new i = 0; i < 5; i++) {
		iMapMenuLen += formatex(g_iValues[szMapMenuszData][iMapMenuLen], charsmax(g_iValues[szMapMenuszData]) - iMapMenuLen, "^n\r%d. \w%s \d[\y%d%%\d]", i + 1, g_aszMapNames[i], g_iValues[iMapVotes][i] * g_iValues[iPercent]);
	}

	iMapMenuLen += formatex(g_iValues[szMapMenuszData][iMapMenuLen], charsmax(g_iValues[szMapMenuszData]) - iMapMenuLen, "^n^n\r0. \w%L", LANG_PLAYER, "RMC_MENU_DONT_VOTE");
	iMapMenuLen += formatex(g_iValues[szMapMenuszData][iMapMenuLen], charsmax(g_iValues[szMapMenuszData]) - iMapMenuLen, "^n^n\y%L", LANG_PLAYER, "RMC_MENU_VOTE_COUNT", g_iValues[iAllVotes]);

	g_iValues[iMapMenuKey] |= MENU_KEY_0|MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_4|MENU_KEY_5;
}

@WeatherMenu() {
	new iWeatherMenuLen;

	iWeatherMenuLen = formatex(g_iValues[szWeatherMenuszData][iWeatherMenuLen], charsmax(g_iValues[szWeatherMenuszData]) - iWeatherMenuLen, "%L^n%L", LANG_PLAYER, "RMC_MENU_TITLE_MAP_WEATHER", LANG_PLAYER, "RMC_MENU_TITLE_MAP_WEATHER_COUNTDOWN", g_iValues[iVoteTime]);

	iWeatherMenuLen += formatex(g_iValues[szWeatherMenuszData][iWeatherMenuLen], charsmax(g_iValues[szWeatherMenuszData]) - iWeatherMenuLen, "^n^n\r%L", LANG_PLAYER, "RMC_MENU_WEATHER_NAME");
	iWeatherMenuLen += formatex(g_iValues[szWeatherMenuszData][iWeatherMenuLen], charsmax(g_iValues[szWeatherMenuszData]) - iWeatherMenuLen, "^n\r1. \w%L \d[\y%d%%\d]", LANG_PLAYER, "RMC_MENU_WEATHER_NORMAL", g_iValues[iWeatherVotes][0] * g_iValues[iPercent]);
	iWeatherMenuLen += formatex(g_iValues[szWeatherMenuszData][iWeatherMenuLen], charsmax(g_iValues[szWeatherMenuszData]) - iWeatherMenuLen, "^n\r2. \w%L \d[\y%d%%\d]", LANG_PLAYER, "RMC_MENU_WEATHER_RAINY", g_iValues[iWeatherVotes][1] * g_iValues[iPercent]);
	iWeatherMenuLen += formatex(g_iValues[szWeatherMenuszData][iWeatherMenuLen], charsmax(g_iValues[szWeatherMenuszData]) - iWeatherMenuLen, "^n\r3. \w%L \d[\y%d%%\d]", LANG_PLAYER, "RMC_MENU_WEATHER_SNOWY", g_iValues[iWeatherVotes][2] * g_iValues[iPercent]);

	iWeatherMenuLen += formatex(g_iValues[szWeatherMenuszData][iWeatherMenuLen], charsmax(g_iValues[szWeatherMenuszData]) - iWeatherMenuLen, "^n^n\r0. \w%L", LANG_PLAYER, "RMC_MENU_DONT_VOTE");
	iWeatherMenuLen += formatex(g_iValues[szWeatherMenuszData][iWeatherMenuLen], charsmax(g_iValues[szWeatherMenuszData]) - iWeatherMenuLen, "^n^n\y%L", LANG_PLAYER, "RMC_MENU_VOTE_COUNT", g_iValues[iAllVotes]);

	g_iValues[iWeatherMenuKey] |= MENU_KEY_0|MENU_KEY_1|MENU_KEY_2|MENU_KEY_3;
}

@PostHudMenu() {
	new iPostHudMenuLen;

	iPostHudMenuLen = formatex(g_iValues[szPostHudMenuszData][iPostHudMenuLen], charsmax(g_iValues[szPostHudMenuszData]) - iPostHudMenuLen, "%L^n^n%L", LANG_PLAYER, "RMC_HUD_TITLE_PRE_POST", g_iValues[iVoteTime], LANG_PLAYER, "RMC_MENU_MAP_NAME");

	for(new i = 0; i < 5; i++) {
		iPostHudMenuLen += formatex(g_iValues[szPostHudMenuszData][iPostHudMenuLen], charsmax(g_iValues[szPostHudMenuszData]) - iPostHudMenuLen, "^n%d. %s [%d%%%%%%]", i + 1, g_aszMapNames[i], g_iValues[iMapVotes][i] * g_iValues[iPercent]);
	}

	if(g_bBools[bMapWeather]) {
		iPostHudMenuLen += formatex(g_iValues[szPostHudMenuszData][iPostHudMenuLen], charsmax(g_iValues[szPostHudMenuszData]) - iPostHudMenuLen, "^n^n%L", LANG_PLAYER, "RMC_MENU_WEATHER_NAME");
		iPostHudMenuLen += formatex(g_iValues[szPostHudMenuszData][iPostHudMenuLen], charsmax(g_iValues[szPostHudMenuszData]) - iPostHudMenuLen, "^n1. %L [%d%%%%%%]", LANG_PLAYER, "RMC_MENU_WEATHER_NORMAL", g_iValues[iWeatherVotes][0] * g_iValues[iPercent]);
		iPostHudMenuLen += formatex(g_iValues[szPostHudMenuszData][iPostHudMenuLen], charsmax(g_iValues[szPostHudMenuszData]) - iPostHudMenuLen, "^n2. %L [%d%%%%%%]", LANG_PLAYER, "RMC_MENU_WEATHER_RAINY", g_iValues[iWeatherVotes][1] * g_iValues[iPercent]);
		iPostHudMenuLen += formatex(g_iValues[szPostHudMenuszData][iPostHudMenuLen], charsmax(g_iValues[szPostHudMenuszData]) - iPostHudMenuLen, "^n3. %L [%d%%%%%%]", LANG_PLAYER, "RMC_MENU_WEATHER_SNOWY", g_iValues[iWeatherVotes][2] * g_iValues[iPercent]);
	}

	iPostHudMenuLen += formatex(g_iValues[szPostHudMenuszData][iPostHudMenuLen], charsmax(g_iValues[szPostHudMenuszData]) - iPostHudMenuLen, "^n^n%L", LANG_PLAYER, "RMC_HUD_VOTE_COUNT", g_iValues[iAllVotes]);

	set_hudmessage(g_iValues[iPostHud_Color][0], g_iValues[iPostHud_Color][1], g_iValues[iPostHud_Color][2], g_iValues[flPostHud_Coords][0], g_iValues[flPostHud_Coords][1], 0, 0.0, 1.0, 0.0, 0.0);
}

@ShowMapVote_Handler(const pPlayer, const iKey) {
	if(iKey == 9) {
		client_print_prefix(0, print_team_red, "%L", LANG_PLAYER, "RMC_PRINT_NOT_VOTED", pPlayer);
		g_bClientBools[bClient_VotedMap][pPlayer] = true;
		return;
	}

	g_iValues[iAllVotes]++;
	g_iValues[iMapVotes][iKey]++;
	g_bClientBools[bClient_VotedMap][pPlayer] = true;
	rg_send_audio(pPlayer, "Gman/gman_noreg.wav");
	client_print_prefix(0, print_team_red, "%L", LANG_PLAYER, "RMC_PRINT_VOTED", pPlayer, g_aszMapNames[iKey]);
}

@ShowMapVote_Weather_Handler(const pPlayer, const iKey) {
	if(iKey == 9) {
		g_bClientBools[bClient_VotedWeather][pPlayer] = true;
		return;
	}

	g_iValues[iWeatherVotes][iKey]++;
	g_bClientBools[bClient_VotedWeather][pPlayer] = true;
	rg_send_audio(pPlayer, "Gman/gman_noreg.wav");
}

@End_Vote() {
	new iNextMap;

	for(new i = 0, iBest; i < 5; i++) {
		if(g_iValues[iMapVotes][i] > iBest) {
			iNextMap = i;
			iBest = g_iValues[iMapVotes][i];
		}
	}

	if(g_bBools[bMapWeather]) {
		new iNextWeather;
		for(new i = 0, iBest; i < 3; i++) {
			if(g_iValues[iWeatherVotes][i] > iBest) {
				iNextWeather = i;
			}
		}

		set_localinfo(g_szLocalInfoNames[szLocalCurrentWeather], fmt("%i", iNextWeather));
	}

	copy(g_aszMapNames[5], charsmax(g_aszMapNames[]), g_aszMapNames[iNextMap]);

	g_bBools[bVoteStarted] = false;
	g_bBools[bMapChosen] = true;

	ExecuteForward(iForward[2], _, 0);

	client_print_prefix(0, print_team_red, "%L", LANG_PLAYER, "RMC_PRINT_RESULT_NEXTMAP", g_aszMapNames[5]);

	if(g_bBools[bWait_RoundEnd]) {
		EnableHookChain(g_iValues[RoundEnd_Post]);

		set_dhudmessage(149, 68, 0, -1.0, -0.70, 2, 4.0, 11.0, 0.0, 1.5);
		show_dhudmessage(0, "%L", LANG_PLAYER, "RMC_DHUD_ROUNDEND", g_aszMapNames[5]);
	}
	else {
		set_task(1.0, "@Task_Changelevel");
	}
}

@RoundEnd_Post() {
	set_task(1.0, "@Task_Changelevel");
}

@Task_Changelevel() {
	set_dhudmessage(0, 255, 0, -1.0, -0.40, 0, 0.0, 8.0, 0.0, 0.0);
	show_dhudmessage(0, "%L", LANG_PLAYER, "RMC_DHUD_CHANGELEVEL", g_aszMapNames[5]);

	for(new id = 1; id <= MaxClients; id++) {
		if(!is_user_connected(id)) {
			continue;
		}

		set_entvar(id, var_flags, FL_FROZEN);
	}

	new szModName[10];
	get_modname(szModName, charsmax(szModName));

	if(!equal(szModName, "zp")) {
		set_task(3.3, "@Task_Changelevel_1");
	}

	set_task(5.3, "@Task_Changelevel_2");
}

@Task_Changelevel_1() {
	message_begin(MSG_ALL, SVC_INTERMISSION);
	message_end();
}

@Task_Changelevel_2() {
	server_cmd("changelevel %s", g_aszMapNames[5]);
}

@clcmd_rtv(const pPlayer) {
	if(g_bBools[bVoteStarted]) {
		client_print_prefix(pPlayer, print_team_red, "%L", LANG_PLAYER, "RMC_PRINT_RTV_VOTESTARTED");
		return PLUGIN_HANDLED;
	}
	if(g_bBools[bMapChosen]) {
		client_print_prefix(pPlayer, print_team_red, "%L", LANG_PLAYER, "RMC_PRINT_RTV_MAPCHOSEN");
		return PLUGIN_HANDLED;
	}
	if(g_bClientBools[bClient_VotedRTV][pPlayer]) {
		client_print_prefix(pPlayer, print_team_red, "%L", LANG_PLAYER, "RMC_PRINT_RTV_VOTED");
		return PLUGIN_HANDLED;
	}

	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");

	if(iNum < g_iValues[iNumRTV]) {
		client_print_prefix(pPlayer, print_team_red, "%L", LANG_PLAYER, "RMC_PRINT_RTV_MAX_PLAYERS", g_iValues[iNumRTV]);
		return PLUGIN_HANDLED;
	}

	g_bClientBools[bClient_VotedRTV][pPlayer] = true;
	g_iValues[iRTVCount]++;

	ExecuteForward(iForward[3], _, 0);

	new iRTV_PercentCount = g_iValues[iRTVCount] * 10 / 7;
	if(iRTV_PercentCount >= iNum) {
		client_print_prefix(0, print_team_red, "%L", LANG_PLAYER, "RMC_PRINT_RTV_PERCENT", g_iValues[iRTVCount]);
		@Task_Start_Vote();
	}
	else {
		client_print_prefix(0, print_team_red, "%L", LANG_PLAYER, "RMC_PRINT_RTV_ENOUGH", iNum - iRTV_PercentCount);
	}

	return PLUGIN_HANDLED;
}

@clcmd_maps(const pPlayer) {
	client_print_prefix(pPlayer, print_team_red, "%L", LANG_PLAYER, "RMC_PRINT_CLCMD_MAPS", g_iValues[szLastSecondMap], g_iValues[szLastMap], g_iValues[szCurrentMap]);
	return PLUGIN_HANDLED;
}

@cmd_nextmap(const pPlayer) {
	if(!g_bBools[bMapChosen]) {
		client_print_prefix(pPlayer, print_team_red, "%L", LANG_PLAYER, "RMC_PRINT_CLCMD_NEXTMAP_NOT");
	}
	else {
		client_print_prefix(pPlayer, print_team_red, "%L", LANG_PLAYER, "RMC_PRINT_CLCMD_NEXTMAP", g_aszMapNames[5]);
	}

	return PLUGIN_HANDLED;
}

@cmd_timeleft(const pPlayer) {
	if(get_cvar_float("mp_timelimit")) {
		new gtimelimit = get_timeleft();
		new svoice[128];
		@SetTimeVoice(svoice, charsmax(svoice), 0, gtimelimit);
		client_cmd(pPlayer, "%s", svoice);
		client_print_prefix(pPlayer, print_team_red, "%L", LANG_PLAYER, "RMC_PRINT_CLCMD_TIMELEFT", (gtimelimit / 60), (gtimelimit % 60));
	}
	else {
		client_print_prefix(pPlayer, print_team_red, "%L", LANG_PLAYER, "RMC_PRINT_CLCMD_TIMELEFT_ZERO");
	}
	return PLUGIN_HANDLED;
}

@cmd_thetime(const pPlayer) {
	new mhours[6], mmins[6], whours[32], wmins[32], wpm[6];
	get_time("%H", mhours, charsmax(mhours));
	get_time("%M",mmins,charsmax(mmins));
	new mins = str_to_num(mmins);
	new hrs = str_to_num(mhours);

	if(mins) {
		num_to_word(mins, wmins, charsmax(wmins));
	}
	else {
		wmins[0] = 0;
	}

	if(hrs < 12) {
		wpm = "am ";
	}
	else {
		if(hrs > 12) hrs -= 12;
		wpm = "pm ";
	}

	if(hrs) {
		num_to_word(hrs, whours, charsmax(whours));
	}
	else {
		whours = "twelve ";
	}

	client_cmd(pPlayer, "spk ^"fvox/time_is_now %s_period %s%s^"", whours, wmins, wpm);

	new ctime[64];
	get_time("%m^3/^4%d^3/^4%Y ^1- ^4%H^3:^4%M^3:^4%S", ctime, charsmax(ctime));
	client_print_prefix(pPlayer, print_team_red, "%L", LANG_PLAYER, "RMC_PRINT_CLCMD_THETIME", ctime);
	return PLUGIN_HANDLED;
}

@cmd_currentmap(const pPlayer) {
	client_print_prefix(pPlayer, print_team_red, "%L", LANG_PLAYER, "RMC_PRINT_CLCMD_CURRENTMAP", g_iValues[szCurrentMap]);
	return PLUGIN_HANDLED;
}

@SetTimeVoice(szData[], const len, const flags, const tmlf) {
	new temp[7][32];
	new secs = tmlf % 60;
	new mins = tmlf / 60;

	for(new a = 0; a < sizeof(temp); ++a) {
		temp[a][0] = 0;
	}

	if(secs > 0) {
		num_to_word(secs,temp[4],charsmax(temp[]));
		if (!(flags & 8)) temp[5] = "seconds ";
	}

	if(mins > 59) {
		new hours = mins / 60;
		num_to_word(hours,temp[0],charsmax(temp[]));
		if (!(flags & 8)) temp[1] = "hours ";
		mins = mins % 60;
	}

	if(mins > 0) {
		num_to_word(mins ,temp[2],charsmax(temp[]));
		if (!(flags & 8)) temp[3] =  "minutes ";
	}

	if(!(flags & 4)) {
		temp[6] = "remaining ";
	}

	return formatex(szData, len, "spk ^"vox/%s%s%s%s%s%s%s^"", temp[0],temp[1],temp[2],temp[3],temp[4],temp[5],temp[6]);
}

SetWeather(const szAddWeather[], const szRemoveWeather[]) {
	new iEnt = NULLENT;

	if(!rg_find_ent_by_class(iEnt, szAddWeather)) {
		rg_create_entity(szAddWeather);
	}

	if(rg_find_ent_by_class(iEnt, szRemoveWeather)) {
		set_entvar(iEnt, var_flags, FL_KILLME);
	}
}

RemoveWeathers() {
	new const szWeatherNames[][] = {
		"env_rain",
		"env_snow"
	};

	for(new i = 0, iEnt = NULLENT; i < sizeof(szWeatherNames); i++) {
		if(rg_find_ent_by_class(iEnt, szWeatherNames[i])) {
			set_entvar(iEnt, var_flags, FL_KILLME);
		}
	}
}

bool:AlreadyExists(const iNum, const szArray[], const iSize) {
	for(new i = 0; i < iSize; i++) {
		if(szArray[i] == iNum) {
			return true;
		}
	}

	ArrayGetString(g_aMapName, iNum, g_aszMapNames[iSize], charsmax(g_aszMapNames[]));
	return false;
}

public plugin_precache() {
	new szFileName[32];
	get_localinfo(g_szLocalInfoNames[szLocalConfigsdir], szFileName, charsmax(szFileName));
	add(szFileName, charsmax(szFileName), "/maps.ini");

	if(!file_exists(szFileName)) {
		log_amx("%L", LANG_SERVER, "RMC_ERROR_FILE_NOT_EXIST", szFileName);
		pause("d");
		return;
	}

	g_aMapName = ArrayCreate(32);

	new iFile = fopen(szFileName, "rt");

	if(iFile) {
		enum _:szFileValuesName {
			szBuffer[MAX_FMT_LENGTH],
			szCurrentMap_Ex[32],
			szPostfix[32],
			szData[32],
			szLeft[32],
			szRight[32],
			iLen,
			iWeather,
			bool:blFound
		}
		new iFileValues[szFileValuesName];

		get_mapname(g_iValues[szCurrentMap], charsmax(g_iValues[szCurrentMap]));
		copy(iFileValues[szCurrentMap_Ex], charsmax(iFileValues[szCurrentMap_Ex]), g_iValues[szCurrentMap]);

		while(!feof(iFile)) {
			fgets(iFile, iFileValues[szBuffer], charsmax(iFileValues[szBuffer]));
			trim(iFileValues[szBuffer]);

			if(iFileValues[szBuffer][0] == '/' || iFileValues[szBuffer][0] == EOS) {
				continue;
			}

			switch(iFileValues[szBuffer][0]) {
				case 'R': {
					strtok2(iFileValues[szBuffer], iFileValues[szLeft], charsmax(iFileValues[szLeft]), iFileValues[szRight], charsmax(iFileValues[szRight]), '=', TRIM_FULL);

					switch(iFileValues[szBuffer][7]) {
						case 'W': {
							if(iFileValues[szRight][1] == 'n') {
								DisableHookChain((g_iValues[RoundEnd_Post] = RegisterHookChain(RG_RoundEnd, "@RoundEnd_Post", .post = true)));
								g_bBools[bWait_RoundEnd] = true;
							}
							else {
								g_bBools[bWait_RoundEnd] = false;
							}
						}
						case 'R': {
							if(iFileValues[szRight][1] == 'n') {
								register_clcmd("say /rtv", "@clcmd_rtv");
							}
						}
						case 'N': {
							if(iFileValues[szRight][1] == 'n') {
								register_clcmd("say nextmap", "@cmd_nextmap");
							}
						}
						case 'C': {
							if(iFileValues[szRight][1] == 'n') {
								register_clcmd("say currentmap", "@cmd_currentmap");
							}
						}
						case 'T': {
							if(iFileValues[szRight][1] == 'n') {
								register_clcmd("say timeleft", "@cmd_timeleft");
							}
						}
						case 'H': {
							if(iFileValues[szRight][1] == 'n') {
								register_clcmd("say thetime", "@cmd_thetime");
							}
						}
						case 'M': {
							if(iFileValues[szRight][1] == 'n') {
								register_clcmd("say /maps", "@clcmd_maps");
							}
						}
						case 'P': {
							g_bBools[bPreShowHud] = bool:(iFileValues[szRight][1] == 'n');
						}
						case 'S': {
							g_bBools[bPostShowHud] = bool:(iFileValues[szRight][1] == 'n');
						}
						case 'V': {
							if(iFileValues[szRight][1] == 'n') {
								g_bBools[bMapWeather] = true;

								new szWeatherName[32];
								get_localinfo(g_szLocalInfoNames[szLocalCurrentWeather], szWeatherName, charsmax(szWeatherName));
								iFileValues[iWeather] = str_to_num(szWeatherName);
							}
						}
						case 'F': {
							g_iValues[iVoteTime] = str_to_num(iFileValues[szRight]);
						}
						case 'I': {
							g_iValues[iNumRTV] = str_to_num(iFileValues[szRight]);
						}
					}
				}
				case '[': {
					iFileValues[iLen] = strlen(iFileValues[szBuffer]);
					copyc(iFileValues[szData], charsmax(iFileValues[szData]), iFileValues[szBuffer][1], iFileValues[szBuffer][iFileValues[iLen] - 1]);
					continue;
				}
			}

			switch(iFileValues[szData][0]) {
				case 'P': {
					if(!g_bBools[bMapWeather]) {
						continue;
					}

					strtok2(iFileValues[szBuffer], iFileValues[szLeft], charsmax(iFileValues[szLeft]), iFileValues[szRight], charsmax(iFileValues[szRight]), '=', TRIM_FULL);

					if(iFileValues[szRight][0] == EOS) {
						continue;
					}

					remove_quotes(iFileValues[szRight]);

					switch(iFileValues[szBuffer][8]) {
						case 'N': {
							if(iFileValues[iWeather] == 0) {
								copy(iFileValues[szPostfix], charsmax(iFileValues[szPostfix]), iFileValues[szRight]);
								RemoveWeathers();
							}
						}
						case 'R': {
							if(iFileValues[iWeather] == 1) {
								copy(iFileValues[szPostfix], charsmax(iFileValues[szPostfix]), iFileValues[szRight]);
								SetWeather("env_rain", "env_snow");
							}
						}
						case 'S': {
							if(iFileValues[iWeather] == 2) {
								copy(iFileValues[szPostfix], charsmax(iFileValues[szPostfix]), iFileValues[szRight]);
								SetWeather("env_snow", "env_rain");
							}
						}

					}
				}
				case 'S': {
					argbreak(iFileValues[szBuffer], iFileValues[szLeft], charsmax(iFileValues[szLeft]), iFileValues[szRight], charsmax(iFileValues[szRight]));
					remove_quotes(iFileValues[szRight]);

					if(equali(g_iValues[szCurrentMap], iFileValues[szLeft])) {
						formatex(g_iValues[szCurrentMap], charsmax(g_iValues[szCurrentMap]), "%s%s", iFileValues[szRight], iFileValues[szPostfix]);
						rh_set_mapname(g_iValues[szCurrentMap]);
						iFileValues[blFound] = true;
					}
				}
				case 'M': {
					if(equali(iFileValues[szBuffer], g_iValues[szLastMap]) || equali(iFileValues[szBuffer], g_iValues[szLastSecondMap]) || equali(iFileValues[szBuffer], iFileValues[szCurrentMap_Ex])) {
						continue;
					}
					if(iFileValues[szBuffer][0] == '[' || !is_map_valid(iFileValues[szBuffer])) {
						continue;
					}

					ArrayPushString(g_aMapName, iFileValues[szBuffer]);
					g_iValues[iMapCount]++;
				}
				case 'C': {
					strtok2(iFileValues[szBuffer], iFileValues[szLeft], charsmax(iFileValues[szLeft]), iFileValues[szRight], charsmax(iFileValues[szRight]), '=', TRIM_FULL);
					remove_quotes(iFileValues[szRight]);

					switch(iFileValues[szBuffer][0]) {
						case 'A': {
							SetColor(iFileValues[szRight], g_iValues[iPreHud_Color], g_bBools[bPreShowHud]);
						}
						case 'B': {
							SetCoords(iFileValues[szRight], g_iValues[flPreHud_Coords], g_bBools[bPostShowHud]);
						}
						case 'C': {
							SetColor(iFileValues[szRight], g_iValues[iPostHud_Color], g_bBools[bPreShowHud]);
						}
						case 'D': {
							SetCoords(iFileValues[szRight], g_iValues[flPostHud_Coords], g_bBools[bPostShowHud]);
						}
					}
				}
			}
		}
		fclose(iFile);

		if(!iFileValues[blFound]) {
			add(g_iValues[szCurrentMap], charsmax(g_iValues[szCurrentMap]), iFileValues[szPostfix]);
			rh_set_mapname(g_iValues[szCurrentMap]);
		}

		get_localinfo(g_szLocalInfoNames[szLocalLastSecondMap], g_iValues[szLastSecondMap], charsmax(g_iValues[szLastSecondMap]));
		get_localinfo(g_szLocalInfoNames[szLocalLastMap], g_iValues[szLastMap], charsmax(g_iValues[szLastMap]));
		set_localinfo(g_szLocalInfoNames[szLocalLastSecondMap], g_iValues[szLastMap]);
		set_localinfo(g_szLocalInfoNames[szLocalLastMap], iFileValues[szCurrentMap_Ex]);
	}
}

client_print_prefix(id, sender, message[], any:...) {
	new szBuffer[190];
	vformat(szBuffer, charsmax(szBuffer), message, 4);

	client_print_color(id, sender, "%L%s", LANG_PLAYER, "RMC_PRINT_PREFIX", szBuffer);
}

SetColor(const szData[], iColor[], const blContinue) {
	if(!blContinue) {
		return;
	}

	new szColors[3][4];
	parse(szData, szColors[0], charsmax(szColors[]), szColors[1], charsmax(szColors[]), szColors[2], charsmax(szColors[]));

	for(new i = 0; i < sizeof szColors; i++) {
		iColor[i] = str_to_num(szColors[i]);
	}
}

SetCoords(const szData[], Float:flCoords[], const blContinue) {
	if(!blContinue) {
		return;
	}

	new szLeft[5], szRight[5];
	argbreak(szData, szLeft, charsmax(szLeft), szRight, charsmax(szRight));

	flCoords[0] = str_to_float(szLeft);
	flCoords[1] = str_to_float(szRight);
}

public plugin_natives() {
	register_native("rmc_start_vote", "@Task_Start_Vote");
	register_native("rmc_is_vote_started", "@rmc_is_vote_started");
	register_native("rmc_is_map_chosen", "@rmc_is_map_chosen");
}

@rmc_is_vote_started() {
	return bool:g_bBools[bVoteStarted];
}

@rmc_is_map_chosen() {
	return bool:g_bBools[bMapChosen];
}