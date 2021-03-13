#include <amxmodx>
#include <reapi>

new const g_szBannerFile[] = "gfx/csdspec.tga";

public plugin_init() {
	register_plugin("Spec Banner", AMXX_VERSION_STR, "Schwarper");

	RegisterHookChain(RG_HandleMenu_ChooseTeam, "@HandleMenu_ChooseTeam_Post", .post = true);
}

public plugin_precache() {
	precache_generic(g_szBannerFile);
}

@HandleMenu_ChooseTeam_Post(const pPlayer, const MenuChooseTeam:iSlot) {
	if(!get_member(pPlayer, m_bJustConnected)) {
		return;
	}

	message_begin(MSG_ONE, 51, .player = pPlayer); {
		write_byte(strlen(g_szBannerFile) + 2);
		write_byte(DRC_CMD_BANNER);
		write_string(g_szBannerFile);
	}
	message_end();
}