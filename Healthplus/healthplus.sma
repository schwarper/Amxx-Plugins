#pragma semicolon 1

#include <amxmodx>
#include <reapi>

enum {
	TASKID_HEALTH = 1,
	TASKID_ARMORVALUE
};

new bool:blCvars[3],
	Float:flCvars[6],
	szCvar_touch[4],
	HookChain:HC_Spawn,
	iModelIndex,
	msgScreenFade;

public plugin_init() {
	register_plugin("Healthplus", "1.0.9", "PurposeLess");

	DisableHookChain((HC_Spawn = RegisterHookChain(RG_CBasePlayer_Spawn, "@CBasePlayer_Spawn", .post=true)));
	RegisterHookChain(RG_CBasePlayer_Killed, "@CBasePlayer_Killed", .post=true);

	new cvar_reality_f = create_cvar("hp_reality_heal", "0", .has_min = true, .min_val = 0.0, .has_max = true, .max_val = 1.0);
	bind_pcvar_num(cvar_reality_f, blCvars[0]);
	hook_cvar_change(cvar_reality_f, "@hp_reality_heal");

	bind_pcvar_float(create_cvar("hp_max_hp", "100"), flCvars[0]);
	bind_pcvar_float(create_cvar("hp_max_armor", "100"), flCvars[1]);
	bind_pcvar_float(create_cvar("hp_add_hp", "10"), flCvars[2]);
	bind_pcvar_float(create_cvar("hp_add_armor", "10"), flCvars[3]);
	bind_pcvar_float(create_cvar("hp_task", "1.0"), flCvars[4]);
	bind_pcvar_float(create_cvar("hp_stay_sec", "7"), flCvars[5]);
	bind_pcvar_string(create_cvar("hp_touch_team", "any"), szCvar_touch, charsmax(szCvar_touch));
	bind_pcvar_num(create_cvar("hp_only_owner_visibility", "0", .has_min = true, .min_val = 0.0, .has_max = true, .max_val = 1.0), blCvars[1]);
	bind_pcvar_num(create_cvar("hp_increase_until_max", "1", .has_min = true, .min_val = 0.0, .has_max = true, .max_val = 1.0), blCvars[2]);

	msgScreenFade = get_user_msgid("ScreenFade");
}

public plugin_precache() {
	iModelIndex = precache_model("models/healthplus.mdl");
}

public plugin_cfg() {
	if(blCvars[0]) {
		EnableHookChain(HC_Spawn);
	}
}

@hp_reality_heal(pcvar, const old_value[], const new_value[]) {
	if(str_to_num(new_value)) {
		EnableHookChain(HC_Spawn);
	}
	else {
		DisableHookChain(HC_Spawn);

		for(new pPlayer = 1; pPlayer <= MaxClients; pPlayer++) {
			if(is_user_alive(pPlayer)) {
				RemoveTask(pPlayer);
			}
		}
	}
}

public client_disconnected(pPlayer) {
	if(blCvars[0]) {
		RemoveTask(pPlayer);
	}
}

@CBasePlayer_Spawn(const pPlayer) {
	if(blCvars[0]) {
		RemoveTask(pPlayer);
	}
}

@CBasePlayer_Killed(const pVictim, pAttacker, iGib) {
	if(blCvars[0]) {
		RemoveTask(pVictim);
	}

	if(blCvars[1] && !is_user_connected(pAttacker)) {
		return;
	}

	new Float:fOrigin[3];
	get_entvar(pVictim, var_origin, fOrigin);

	CreateHealth(pAttacker, fOrigin);
}

CreateHealth(const pPlayer, const Float:fOrigin[3]) {
	new pEntity = rg_create_entity("info_target");

	if(is_nullent(pEntity)) {
		return;
	}

	new Float:GameTime = get_gametime();

	set_entvar(pEntity, var_origin, fOrigin);

	set_entvar(pEntity, var_modelindex, iModelIndex);
	set_entvar(pEntity, var_solid, SOLID_TRIGGER);
	set_entvar(pEntity, var_movetype, MOVETYPE_FLY);
	set_entvar(pEntity, var_renderfx, kRenderFxGlowShell);
	set_entvar(pEntity, var_rendercolor, {0.0,255.0,0.0});
	set_entvar(pEntity, var_renderamt, 7.0);
	set_entvar(pEntity, var_animtime, GameTime + 1.0);
	set_entvar(pEntity, var_framerate, 1.0);
	set_entvar(pEntity, var_sequence, 1);

	if(blCvars[1]) {
		set_entvar(pEntity, var_owner, pPlayer);
		set_entvar(pEntity, var_effects, get_entvar(pEntity, var_effects) | EF_OWNER_VISIBILITY);
	}

	SetTouch(pEntity, "@SetTouch_Entity");
	SetThink(pEntity, "@SetThink_Entity");
	set_entvar(pEntity, var_nextthink, GameTime + flCvars[5]);
}

@SetTouch_Entity(const pEntity, const pPlayer) {
	if(!is_user_alive(pPlayer) || !CheckPlayerTeam(pPlayer, pEntity)) {
		return;
	}

	set_entvar(pEntity, var_flags, FL_KILLME);

	SetHealthArmorPub(pPlayer, "@heal_health", TASKID_HEALTH, var_health, flCvars[0], flCvars[2]);
	SetHealthArmorPub(pPlayer, "@heal_armor", TASKID_ARMORVALUE, var_armorvalue, flCvars[1], flCvars[3]);

	message_begin(MSG_ONE, msgScreenFade, .player = pPlayer); {
		write_short(1<<14);
		write_short(1<<9);
		write_short(1<<11);
		write_byte(0);
		write_byte(255);
		write_byte(0);
		write_byte(35);
	}
	message_end();
}

@SetThink_Entity(const pEntity) {
	set_entvar(pEntity, var_gravity, -0.1);
	set_entvar(pEntity, var_movetype, MOVETYPE_TOSS);
	SetThink(pEntity, "@SetThink_Entity_Post");
	set_entvar(pEntity, var_nextthink, get_gametime() + 0.8);
}

@SetThink_Entity_Post(const pEntity) {
	set_entvar(pEntity, var_flags, FL_KILLME);
}

SetHealthArmorPub(const pPlayer, const taskname[], const TaskId, const EntVars:var, const Float:cvar, const Float:addhparmor) {
	if(!cvar || !addhparmor) {
		return;
	}

	if(blCvars[0]) {
		if(!task_exists(pPlayer)) {
			set_task(flCvars[4], taskname, pPlayer + TaskId, .flags = "b");
		}
	}
	else {
		if(blCvars[2]) {
			set_entvar(pPlayer, var, cvar);
		}
		else {
			new Float:iHPArmor = Float:get_entvar(pPlayer, var);
			iHPArmor += addhparmor;

			set_entvar(pPlayer, var, (iHPArmor >= cvar) ? cvar : iHPArmor);
		}
	}
}

@heal_health(TaskId) {
	new id = TaskId - TASKID_HEALTH;

	new Float:health = get_entvar(id, var_health);
	health += flCvars[2];

	if(health >= flCvars[0]) {
		set_entvar(id, var_health, flCvars[0]);
		remove_task(id + TASKID_HEALTH);
		return;
	}

	set_entvar(id, var_health, health);
}

@heal_armor(TaskId) {
	new id = TaskId - TASKID_ARMORVALUE;

	new Float:armorvalue = get_entvar(id, var_armorvalue);
	armorvalue += flCvars[3];

	if(armorvalue >= flCvars[1]) {
		set_entvar(id, var_armorvalue, flCvars[1]);
		remove_task(id + TASKID_ARMORVALUE);
		return;
	}

	set_entvar(id, var_armorvalue, armorvalue);
}

RemoveTask(const pPlayer) {
	remove_task(pPlayer + TASKID_HEALTH);
	remove_task(pPlayer + TASKID_ARMORVALUE);
}

bool:CheckPlayerTeam(const pPlayer, const pEntity) {
	if(blCvars[1]) {
		return bool:(get_entvar(pEntity, var_owner) == pPlayer);
	}

	switch(szCvar_touch[0]) {
		case 'C','c': {
			return bool:(get_member(pPlayer, m_iTeam) == TEAM_CT);
		}
		case 'T','t': {
			return bool:(get_member(pPlayer, m_iTeam) == TEAM_TERRORIST);
		}
	}
	return true;
}