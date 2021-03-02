#pragma semicolon 1

#include <amxmodx>
#include <reapi>

new	bool:g_colorful,
	bool:g_speed[MAX_CLIENTS +1],
	g_skipFrames[MAX_CLIENTS + 1],
	g_hudSync;

new Float:g_pos[2],
	Float:cvar_maxspeed,
	Float:cvar_minspeed,
	bool:cvar_only_horisontal_speed,
	cvar_updatepersec,
	g_colors[3];

public plugin_init() {
	register_plugin("ReSpeedometer", "1.1b", "PurposeLess & wopox1337");

	register_clcmd("say /speed", "@clcmd_speed");

	RegisterHookChain(RG_CBasePlayer_PostThink, "@CBasePlayer_PostThink", .post=true);

	bind_pcvar_num(create_cvar("rsm_updatepersec", "5",.has_min = true, .min_val = 0.0, .has_max = true, .max_val = 100.0), cvar_updatepersec);
	bind_pcvar_float(create_cvar("rsm_minspeed", "40"), cvar_minspeed);
	bind_pcvar_float(create_cvar("rsm_maxspeed", "300"), cvar_maxspeed);
	bind_pcvar_num(create_cvar("rsm_only_horisontal_speed", "1",.has_min = true, .min_val = 0.0, .has_max = true, .max_val = 1.0), cvar_only_horisontal_speed);

	hook_cvar_change(create_cvar("rsm_colors", "0 0 0"), "@hook_cvar_change_rsm_colors");
	hook_cvar_change(create_cvar("rsm_pos", "-1.0 0.75"), "@hook_cvar_change_rsm_pos");

	g_hudSync = CreateHudSyncObj();
}

public client_putinserver(id) {
	g_speed[id] = bool:(!is_user_bot(id) && !is_user_hltv(id));
}

public client_disconnected(id) {
	ClearSyncHud(id, g_hudSync);
}

@clcmd_speed(const id) {
	g_speed[id] = !g_speed[id];

	if(!g_speed[id]) {
		ClearSyncHud(id, g_hudSync);
	}
}

@CBasePlayer_PostThink(const id) {
	if(!cvar_updatepersec || !g_speed[id]) {
		return;
	}

	static skipFrames;
	skipFrames = (100 / cvar_updatepersec);

	if(++g_skipFrames[id] < skipFrames) {
		return;
	}

	static target;
	target = get_entvar(id, var_iuser2);

	if(!is_user_alive(target)) {
		target = id;
	}

	if(target == id && !is_user_alive(id)) {
		return;
	}

	static Float:velocity[3];
	get_entvar(target, var_velocity, velocity);

	static Float:speed;
	if(cvar_only_horisontal_speed) {
		speed = floatsqroot(floatpower(velocity[0], 2.0) + floatpower(velocity[1], 2.0));
	}
	else {
		speed = vector_length(velocity);
	}

	if(speed < cvar_minspeed) {
		ClearSyncHud(id, g_hudSync);
		return;
	}

	if(g_colorful)
	{
		static Float:val;
		val = convertToRange(floatmin(speed, cvar_maxspeed), cvar_minspeed, cvar_maxspeed);

		RGBBetweenColors(val, g_colors);
	}

	set_hudmessage(
	g_colors[0], g_colors[1], g_colors[2],
	g_pos[0], g_pos[1],
	.holdtime = convertToRange(float(skipFrames), 0.001, 1.0, 0.1),
	.fadeintime = 0.0,
	.fadeouttime = 0.0,
	.channel = 1
	);

	ShowSyncHudMsg(id, g_hudSync, "%.2f u/s", speed);

	g_skipFrames[id] = 0;
}

RGBBetweenColors(const Float:val, colors[3], const colorA[3] = {255, 0, 0}, const colorB[3] = {0, 255, 0}) {
	colors[0] = floatround(float(colorB[0] - colorA[0]) * val + colorA[0]);
	colors[1] = floatround(float(colorB[1] - colorA[1]) * val + colorA[1]);
	colors[2] = floatround(float(colorB[2] - colorA[2]) * val + colorA[2]);
}

stock Float: convertToRange(Float:value, Float:FromMin, Float:FromMax, Float:ToMin = 0.0, Float:ToMax = 1.0) {
	return floatclamp((value-FromMin) / (FromMax-FromMin) * (ToMax-ToMin + ToMin), ToMin, ToMax);
}

public plugin_cfg() {
	new value[15];
	get_cvar_string("rsm_pos", value, charsmax(value));
	SetPos(value);

	get_cvar_string("rsm_colors", value, charsmax(value));
	SetColors(value);
}

@hook_cvar_change_rsm_colors(pcvar, const old_value[], const new_value[]) {
	SetColors(new_value);
}

@hook_cvar_change_rsm_pos(pcvar, const old_value[], const new_value[]) {
	SetPos(new_value);
}

SetColors(const text[]) {
	new s_colors[3][4];
	parse(text, s_colors[0], charsmax(s_colors[]), s_colors[1], charsmax(s_colors[]), s_colors[2], charsmax(s_colors[]));

	for(new i = 0; i < sizeof s_colors; i++)
	{
		g_colors[i] = str_to_num(s_colors[i]);
	}

	g_colorful = (!g_colors[0] && !g_colors[1] && !g_colors[2]) ? true : false;
}

SetPos(const value[]) {
	new left[5], right[5];
	argbreak(value, left, charsmax(left), right, charsmax(right));

	g_pos[0] = str_to_float(left);
	g_pos[1] = str_to_float(right);
}