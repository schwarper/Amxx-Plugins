#pragma semicolon 1

#include <amxmodx>
#include <reapi>

new g_iClientEntity[MAX_CLIENTS + 1],
	g_iEntityIndex,
	bool:g_blAlive[MAX_CLIENTS + 1],
	bool:g_blParachuteModel,
	bool:g_blGravitySave,
	bool:g_blFirstStart,
	g_szAuthorization_Flag[64],
	g_iAuthorization_Flag,
	Float:g_flUserGravity[MAX_CLIENTS + 1],
	HookChain:g_iHookChain_PreThink_Pre;

public plugin_init() {
	register_plugin("Parachute", AMXX_VERSION_STR, "Schwarper");

	g_iHookChain_PreThink_Pre = RegisterHookChain(RG_CBasePlayer_PreThink, "@CBasePlayer_PreThink_Pre", .post = false);
	RegisterHookChain(RG_CBasePlayer_Spawn, "@CBasePlayer_Spawn_Post", .post = true);
	RegisterHookChain(RG_CBasePlayer_Killed, "@CBasePlayer_Killed_Post", .post = true);

	hook_cvar_change(create_cvar("sv_parachute", "1", .description = "Enable/Disable Parachute", .has_min = true, .min_val = 0.0, .has_max = true, .max_val = 1.0), "@sv_parachute_callback");

	if(!g_blFirstStart) {
		set_cvar_num("sv_parachute", 0);
		DisableHookChain(g_iHookChain_PreThink_Pre);
	}
	else {
		set_cvar_num("sv_parachute", 1);
	}
}

public client_disconnected(pPlayer) {
	g_blAlive[pPlayer] = false;
	ResetParachute(pPlayer);
}

@sv_parachute_callback(const iCvar, const szOldCvar[], const szNewCvar[]) {
	if(str_to_num(szNewCvar)) {
		EnableHookChain(g_iHookChain_PreThink_Pre);
	}
	else {
		DisableHookChain(g_iHookChain_PreThink_Pre);

		for(new pPlayer = 1; pPlayer <= MaxClients; pPlayer++) {
			if(g_blAlive[pPlayer]) {
				ResetParachute(pPlayer);
			}
		}
	}
}

@CBasePlayer_Spawn_Post(const pPlayer) {
	g_blAlive[pPlayer] = true;
	g_flUserGravity[pPlayer] = 1.0;
	ResetParachute(pPlayer);
}

@CBasePlayer_Killed_Post(const pVictim, const pAttacker) {
	g_blAlive[pVictim] = false;
	ResetParachute(pVictim);
}

@CBasePlayer_PreThink_Pre(const pPlayer) {
	if(!g_blAlive[pPlayer]) {
		return;
	}

	if(g_iAuthorization_Flag && ~get_user_flags(pPlayer) & g_iAuthorization_Flag) {
		ResetParachute(pPlayer);
		return;
	}

	static iWaterLevel;
	iWaterLevel = get_entvar(pPlayer, var_waterlevel);

	if(iWaterLevel > 0) {
		ResetParachute(pPlayer);
		return;
	}

	static iButton, iOldButtons;
	iButton = get_entvar(pPlayer, var_button);
	iOldButtons = get_entvar(pPlayer, var_oldbuttons);

	if(iButton & IN_USE) {
		static Float:flVelocity[3];
		get_entvar(pPlayer, var_velocity, flVelocity);

		if(flVelocity[2] < 0.0) {
			if(g_blParachuteModel && !g_iClientEntity[pPlayer]) {
				g_iClientEntity[pPlayer] = rg_create_entity("info_target");

				set_entvar(g_iClientEntity[pPlayer], var_modelindex, g_iEntityIndex);
				set_entvar(g_iClientEntity[pPlayer], var_movetype, MOVETYPE_FOLLOW);
				set_entvar(g_iClientEntity[pPlayer], var_aiment, pPlayer);
			}

			static Float:iGravity;
			iGravity = get_entvar(pPlayer, var_gravity);

			if(g_blGravitySave && iGravity != 0.1) {
				g_flUserGravity[pPlayer] = iGravity;
			}

			flVelocity[2] = floatmin(flVelocity[2] + 40.0, -100.0);
			set_entvar(pPlayer, var_sequence, 3);
			set_entvar(pPlayer, var_gaitsequence, 1);
			set_entvar(pPlayer, var_velocity, flVelocity);
			set_entvar(pPlayer, var_gravity, 0.1);
		}
		else {
			ResetParachute(pPlayer);
		}
	}
	else if(iOldButtons & IN_USE) {
		ResetParachute(pPlayer);
	}
}

ResetParachute(const pPlayer) {
	if(g_blParachuteModel && g_iClientEntity[pPlayer]) {
		set_entvar(g_iClientEntity[pPlayer], var_flags, FL_KILLME);
		g_iClientEntity[pPlayer] = 0;
	}

	if(g_blAlive[pPlayer] && get_entvar(pPlayer, var_gravity) == 0.1) {
		set_entvar(pPlayer, var_gravity, g_blGravitySave ? g_flUserGravity[pPlayer] : 1.0);
	}
}

public plugin_precache() {
	new szFileName[39];
	get_localinfo("amxx_configsdir", szFileName, charsmax(szFileName));
	format(szFileName, charsmax(szFileName), "%s/reparachute.ini", szFileName);

	if(!file_exists(szFileName)) {
		pause("d");
		return;
	}

	new iFile = fopen(szFileName, "rt");

	if(iFile) {
		new szBuffer[MAX_FMT_LENGTH], szLeft[32], szRight[64];

		while(!feof(iFile)) {
			fgets(iFile, szBuffer, charsmax(szBuffer));
			trim(szBuffer);

			if(szBuffer[0] == EOS || szBuffer[0] == ';') {
				continue;
			}

			strtok2(szBuffer, szLeft, charsmax(szLeft), szRight, charsmax(szRight), '=', TRIM_FULL);
			remove_quotes(szRight);

			switch(szLeft[12]) {
				case 'm': {
					if(szRight[0]) {
						g_blParachuteModel = true;
						g_iEntityIndex = precache_model(szRight);
					}
				}
				case 'g': {
					g_blGravitySave = bool:(szRight[1] == 'N');
				}
				case 'a': {
					if(szRight[0]) {
						formatex(g_szAuthorization_Flag, charsmax(g_szAuthorization_Flag), szRight);
						g_iAuthorization_Flag = read_flags(g_szAuthorization_Flag);
					}
				}
				case 's': {
					g_blFirstStart = bool:(szRight[1] == 'N');
				}		
			}
		}
		fclose(iFile);
	}
}