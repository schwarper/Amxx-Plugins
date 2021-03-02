#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>
#include <reapi>

enum _:CvarNames {
	BLOCK_SPRAY,
	RETRY_TERR,
	BLOCK_KILL,
	BLOCK_MONEY
}

const MinClientsToStart = 2;

new pNextTerrorist,
	bool:g_blCvar[CvarNames];

public plugin_init() {
	register_plugin("ReDeathrun", "0.0.2", "PurposeLess");
	register_dictionary("redeathrun.txt");

	@ReapiHooks();
	@FakemetaHooks();
}

public plugin_cfg() {
	bind_pcvar_num(create_cvar("rd_block_spray", "1"), g_blCvar[BLOCK_SPRAY]);
	bind_pcvar_num(create_cvar("rd_retry_terrorist", "1"), g_blCvar[RETRY_TERR]);
	bind_pcvar_num(create_cvar("rd_block_kill", "1"), g_blCvar[BLOCK_KILL]);
	bind_pcvar_num(create_cvar("rd_block_money", "1"), g_blCvar[BLOCK_MONEY]);

	new szFileName[43];
	get_localinfo("amxx_configsdir", szFileName, charsmax(szFileName));
	add(szFileName, charsmax(szFileName), "/redeathrun_core.cfg");

	if(file_exists(szFileName)) {
		server_cmd("exec %s", szFileName);
		server_exec();
	}

	set_member_game(m_bMapHasBombTarget, false);
	set_member_game(m_bMapHasBombZone, false);
	set_member_game(m_bMapHasRescueZone, false);
	set_member_game(m_bMapHasBuyZone, false);
	set_member_game(m_bMapHasEscapeZone, false);
	set_member_game(m_bMapHasVIPSafetyZone, false);
}

public client_putinserver(pPlayer) {
	if(get_member_game(m_bGameStarted)) {
		return;
	}

	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum);

	if(iNum >= MinClientsToStart) {
		set_member_game(m_bGameStarted, true);
		set_pcvar_num(get_cvar_pointer("sv_restart"), 2);
	}
}

/* Thanks fl0wer */
public client_disconnected(pPlayer) {
	if(!get_member_game(m_bGameStarted) || !is_user_connected(pPlayer)) {
		return;
	}

	new iPlayersArray[MAX_PLAYERS], iNum;

	for(new id = 1; id <= MaxClients; id++) {
		if(!is_user_connected(id) || id == pPlayer) {
			continue;
		}

		iPlayersArray[++iNum] = id;
	}

	if(iNum < MinClientsToStart) {
		set_member_game(m_bGameStarted, false);
		return;
	}

	if(g_blCvar[RETRY_TERR] && pNextTerrorist == pPlayer) {
		pNextTerrorist = iPlayersArray[random_num(1, iNum)];
		rg_set_user_team(pNextTerrorist, TEAM_TERRORIST);
		rg_round_respawn(pNextTerrorist);
		client_print_color(0, print_team_red, "%L", LANG_PLAYER, "REDEATHRUN_LEFT_GAME", pPlayer, pNextTerrorist);
	}
}

/* *reapi* */
@ReapiHooks() {
	RegisterHookChain(RG_CSGameRules_RestartRound, "@CSGameRules_RestartRound_Pre", .post = false);
	RegisterHookChain(RG_CBasePlayer_ImpulseCommands, "@CBasePlayer_ImpulseCommands_Pre", .post = false);
	RegisterHookChain(RG_CSGameRules_CheckMapConditions, "@CSGameRules_CheckMapConditions_Pre", .post = false);
	RegisterHookChain(RG_ShowVGUIMenu, "@ShowVGUIMenu_Pre", .post = false);
	RegisterHookChain(RG_HandleMenu_ChooseTeam, "@HandleMenu_ChooseTeam_Pre", .post = false);

	RegisterHookChain(RG_RoundEnd, "@RoundEnd_Post", .post = true);
	RegisterHookChain(RG_CBasePlayer_Killed, "@CBasePlayer_Killed_Post", .post = true);
	RegisterHookChain(RG_CBasePlayer_Spawn, "@CBasePlayer_Spawn_Post", .post = true);
	RegisterHookChain(RG_CSGameRules_CleanUpMap, "@CSGameRules_CleanUpMap_Post", .post = true);
}

@CSGameRules_RestartRound_Pre() {
	if(!get_member_game(m_bGameStarted)) {
		return;
	}

	if(!is_user_connected(pNextTerrorist)) {
		new iPlayers[32], iNum;
		get_players(iPlayers, iNum);
		pNextTerrorist = iPlayers[random(iNum)];

		client_print_color(0, print_team_red, "%L", LANG_PLAYER, "REDEATHRUN_NEXT_TERRORIST", pNextTerrorist);
	}

	for(new pPlayer = 1; pPlayer <= MaxClients; pPlayer++) {
		if(!is_user_alive(pPlayer) || pPlayer == pNextTerrorist) {
			continue;
		}

		rg_set_user_team(pPlayer, TEAM_CT);
	}
	rg_set_user_team(pNextTerrorist, TEAM_TERRORIST);
}

@CBasePlayer_ImpulseCommands_Pre(const pPlayer) {
	if(!g_blCvar[BLOCK_SPRAY]) {
		return HC_CONTINUE;
	}

	static iImpulse;
	iImpulse = get_entvar(pPlayer, var_impulse);

	if(iImpulse == 201) {
		set_entvar(pPlayer, var_impulse, 0);
		return HC_SUPERCEDE;
	}
	return HC_CONTINUE;
}

@CSGameRules_CheckMapConditions_Pre() {
	set_member_game(m_bCTCantBuy, true);
	set_member_game(m_bTCantBuy, true);
	return HC_SUPERCEDE;
}

/* Thanks F@nt0M from Block Change Team */
@ShowVGUIMenu_Pre(const pPlayer, const VGUIMenu:menuType) {
	if(menuType != VGUI_Menu_Team || get_member(pPlayer, m_bJustConnected)) {
		return HC_CONTINUE;
	}
	set_member(pPlayer, m_iMenu, 0);
	return HC_SUPERCEDE;
}

@HandleMenu_ChooseTeam_Pre(const pPlayer) {
	if(get_member(pPlayer, m_bJustConnected)) {
		return HC_CONTINUE;
	}
	SetHookChainReturn(ATYPE_INTEGER, false);
	return HC_SUPERCEDE;
}

@RoundEnd_Post() {
	if(!get_member_game(m_bGameStarted)) {
		return;
	}

	new iPlayers[32], iNum;
	get_players(iPlayers, iNum);
	pNextTerrorist = iPlayers[random(iNum)];

	client_print_color(0, print_team_red, "%L", LANG_PLAYER, "REDEATHRUN_NEXT_TERRORIST", pNextTerrorist);
}

@CBasePlayer_Killed_Post(const pVictim, pAttacker, iGib) {
	if(get_member(pVictim, m_iTeam) == TEAM_TERRORIST) {
		rg_set_user_team(pVictim, TEAM_CT);
	}
}

@CBasePlayer_Spawn_Post(const pPlayer) {
	if(!is_user_alive(pPlayer)) {
		return;
	}

	rg_remove_all_items(pPlayer);
	rg_give_item(pPlayer, "weapon_knife");

	if(g_blCvar[BLOCK_MONEY]) {
		set_member(pPlayer, m_iHideHUD, get_member(pPlayer, m_iHideHUD) | HIDEHUD_MONEY);
	}
}

@CSGameRules_CleanUpMap_Post() {
	new iEnt;
	while((iEnt = rg_find_ent_by_class(iEnt, "hostage_entity"))) {
		RemoveEntity(iEnt);
	}
	while((iEnt = rg_find_ent_by_class(iEnt, "monster_scientist"))) {
		RemoveEntity(iEnt);
	}
	while((iEnt = rg_find_ent_by_class(iEnt, "player_weaponstrip"))) {
		set_entvar(iEnt, var_targetname, "stripper_dummy");
	}
	while((iEnt = rg_find_ent_by_class(iEnt, "game_player_equip"))) {
		set_entvar(iEnt, var_targetname,"equipment_dummy");
	}
}

RemoveEntity(const pEntity) {
	set_entvar(pEntity, var_health, 0.0);
	set_entvar(pEntity, var_takedamage, DAMAGE_NO);
	set_entvar(pEntity, var_movetype, MOVETYPE_TOSS);
	set_entvar(pEntity, var_deadflag, DEAD_DEAD);
	set_entvar(pEntity, var_effects, EF_NODRAW);
	set_entvar(pEntity, var_solid, SOLID_NOT);
}

/* *fakemeta* */
@FakemetaHooks() {
	register_forward(FM_ClientKill, "@ClientKill_Pre", ._post = false);
}

@ClientKill_Pre(const pPlayer) {
	return g_blCvar[BLOCK_KILL] ? FMRES_SUPERCEDE : FMRES_IGNORED;
}