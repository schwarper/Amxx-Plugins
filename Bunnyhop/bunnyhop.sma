#pragma semicolon 1

#include <amxmodx>
#include <reapi>

new HookChain:g_iHookChain_Jump_Pre;

public plugin_init() {
	register_plugin("Bunnyhop", AMXX_VERSION_STR, "Schwarper");

	g_iHookChain_Jump_Pre = RegisterHookChain(RG_CBasePlayer_Jump, "@CBasePlayer_Jump_Pre", .post = false);

	new iCvar = create_cvar("bh_enabled", "1", .description = "Enable/Disable Bunnyhop", .has_min = true, .min_val = 0.0, .has_max = true, .max_val = 1.0);
	hook_cvar_change(iCvar, "@bh_enabled_callback");

	if(!get_pcvar_num(iCvar)) {
		DisableHookChain(g_iHookChain_Jump_Pre);
	}
}

@bh_enabled_callback(iCvar, const szOldValue[], const szNewValue[]) {
	str_to_num(szNewValue) ? EnableHookChain(g_iHookChain_Jump_Pre) : DisableHookChain(g_iHookChain_Jump_Pre);
}

@CBasePlayer_Jump_Pre(const pPlayer) {
	if(~get_entvar(pPlayer, var_flags) & FL_ONGROUND) {
		return;
	}

	new Float:flVelocity[3];
	get_entvar(pPlayer, var_velocity, flVelocity);
	flVelocity[2] = 268.0;
	set_entvar(pPlayer, var_velocity, flVelocity);
}