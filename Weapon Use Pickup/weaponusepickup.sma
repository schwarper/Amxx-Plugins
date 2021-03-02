#pragma semicolon 1

#include <amxmodx>
#include <hamsandwich>
#include <fakemeta>
#include <reapi>

new const szWeaponNames[WeaponIdType:MAX_WEAPONS][] = {
    "", "228 Compact", "", "SSG 08", "High Explosive Grenage", "XM1014", "C4 Explosive", "MAC-10", "AUG",
    "Smoke Grenade", "Dual Berettas", "Five-SeveN", "UMP-45", "SG-550", "Galil",
    "FAMAS", "USP", "Glock-18", "AWP", "MP5", "M249", "M3", "M4A1", "TMP", "G3SG1",
    "Flashbang", "Desert Eagle", "SG 552", "AK-47", "Knife", "P90", ""
};

new const gArmoury_Mapper[MAX_WEAPONS + 1] = { CSW_MP5NAVY, CSW_TMP, CSW_P90,
	CSW_MAC10, CSW_AK47, CSW_SG552, CSW_M4A1, CSW_AUG, CSW_SCOUT, CSW_G3SG1, CSW_AWP,
	CSW_M3, CSW_XM1014, CSW_M249, CSW_FLASHBANG, CSW_HEGRENADE, CSW_VEST, CSW_VESTHELM,
	CSW_SMOKEGRENADE, CSW_SHIELDGUN, CSW_FAMAS, CSW_SG550, CSW_GALIL, CSW_UMP45,
	CSW_GLOCK18, CSW_USP, CSW_ELITE, CSW_FIVESEVEN, CSW_P228, CSW_DEAGLE
};

enum _:WeaponData {
	Weapon_Entity,
	WeaponIdType:Weapon_Id,
	InventorySlotType:Weapon_Slot,
};

new Float:g_flNextHudPickupTime[MAX_PLAYERS + 1],
	Array:g_aGroundWeapons,
	g_iHudSync_PickUp;

public plugin_init() {
	register_plugin("Weapon Use Pickup", "1.4", "fl0wer & Schwarper");

	RegisterHam(Ham_StopSneaking, "weaponbox", "@CWeaponBox_OnDestroy_Post", true);

	RegisterHookChain(RG_CWeaponBox_SetModel, "@CWeaponBox_SetModel_Post", true);
	RegisterHookChain(RG_CBasePlayer_PreThink, "@CBasePlayer_PreThink_Post", true);

	g_iHudSync_PickUp = CreateHudSyncObj();
}

public plugin_precache() {
	g_aGroundWeapons = ArrayCreate(WeaponData);
	RegisterHam(Ham_Spawn, "armoury_entity", "@CArmoury_Spawn_Post", true);
}

@CWeaponBox_OnDestroy_Post(pEntity)
{
	new aGroundWeapons = ArrayFindValue(g_aGroundWeapons, pEntity);

	if(aGroundWeapons == -1) {
		return;
	}

	ArrayDeleteItem(g_aGroundWeapons, aGroundWeapons);
}

@CWeaponBox_SetModel_Post(const pEntity, const szModelName[])
{
	for(new InventorySlotType:i = PRIMARY_WEAPON_SLOT, pItem; i <= C4_SLOT; i++) {
		pItem = get_member(pEntity, m_WeaponBox_rgpPlayerItems, i);

		if(is_nullent(pItem)) {
			continue;
		}

		new weaponData[WeaponData];

		weaponData[Weapon_Entity] = pEntity;
		weaponData[Weapon_Id] = get_member(pItem, m_iId);
		weaponData[Weapon_Slot] = i;

		ArrayPushArray(g_aGroundWeapons, weaponData);
		break;
	}
}

@CBasePlayer_PreThink_Post(const pPlayer) {
	if(!is_user_alive(pPlayer)) {
		return;
	}

	if(~get_entvar(pPlayer, var_button) & IN_USE && get_entvar(pPlayer, var_oldbuttons) & IN_USE) {
		static pWeapon;
		pWeapon = FindWeaponByView(pPlayer);

		if(pWeapon == NULLENT) {
			return;
		}

		static weaponData[WeaponData];
		ArrayGetArray(g_aGroundWeapons, pWeapon, weaponData);

		if(weaponData[Weapon_Slot] == PRIMARY_WEAPON_SLOT || weaponData[Weapon_Slot] == PISTOL_SLOT) {
			static pEntity;
			pEntity = weaponData[Weapon_Entity];

			rg_drop_items_by_slot(pPlayer, weaponData[Weapon_Slot]);
			set_entvar(pEntity, var_flags, get_entvar(pEntity, var_flags) | FL_ONGROUND);
			ExecuteHamB(Ham_Touch, pEntity, pPlayer);
		}
		return;
	}

	static Float:time;
	time = get_gametime();

	if(g_flNextHudPickupTime[pPlayer] > time) {
		return;
	}

	g_flNextHudPickupTime[pPlayer] = time + 0.2;

	static pWeapon;
	pWeapon = FindWeaponByView(pPlayer);

	if(pWeapon == NULLENT) {
		return;
	}

	static weaponData[WeaponData];
	ArrayGetArray(g_aGroundWeapons, pWeapon, weaponData);

	static WeaponIdType:weaponId, pItem;
	weaponId = weaponData[Weapon_Id];
	pItem = get_member(pPlayer, m_rgpPlayerItems, weaponData[Weapon_Slot]);

	set_hudmessage(255, 255, 255, -1.0, 0.55, 0, 6.0, 0.21, 0.01, 0.01);

	if(is_nullent(pItem)) {
		ShowSyncHudMsg(pPlayer, g_iHudSync_PickUp, "%s", szWeaponNames[weaponId]);
	}
	else {
		ShowSyncHudMsg(pPlayer, g_iHudSync_PickUp, "[E] change to %s", szWeaponNames[weaponId]);
	}
}

FindWeaponByView(const pPlayer)
{
	static Float:vecSrc[3];
	static Float:vecEnd[3];
	static Float:vecViewAngle[3];
	static Float:vecPunchAngle[3];
	static Float:vecViewForward[3];

	ExecuteHam(Ham_Player_GetGunPosition, pPlayer, vecSrc);
	get_entvar(pPlayer, var_v_angle, vecViewAngle);
	get_entvar(pPlayer, var_punchangle, vecPunchAngle);

	for(new i = 0; i < 3; i++) {
		vecViewAngle[i] += vecPunchAngle[i];
	}

	angle_vector(vecViewAngle, ANGLEVECTOR_FORWARD, vecViewForward);

	for(new i = 0; i < 3; i++) {
		vecEnd[i] = vecSrc[i] + vecViewForward[i] * 128.0;
	}

	static pWeapon;
	static weaponData[WeaponData];
	static weaponsNum;
	weaponsNum = ArraySize(g_aGroundWeapons);

	for(new i = 0; i < weaponsNum; i++) {
		ArrayGetArray(g_aGroundWeapons, i, weaponData);

		pWeapon = weaponData[Weapon_Entity];

		if(is_nullent(pWeapon) || get_entvar(pWeapon, var_effects) & EF_NODRAW) {
			continue;
		}

		engfunc(EngFunc_TraceModel, vecSrc, vecEnd, HULL_POINT, pWeapon, 0);

		if(is_nullent(get_tr2(0, TR_pHit))) {
			continue;
		}

		return i;
	}

	return NULLENT;
}

@CArmoury_Spawn_Post(const pEntity) {
	new pItemId = get_member(pEntity, m_Armoury_iItem);

	if(pItemId == any:ARMOURY_KEVLAR || pItemId == any:ARMOR_VESTHELM) {
		return;
	}

	new weaponId = gArmoury_Mapper[pItemId];
	new weaponData[WeaponData];

	weaponData[Weapon_Entity] = pEntity;
	weaponData[Weapon_Id] = WeaponIdType:weaponId;

	if((1<<weaponId) & ((1<<CSW_HEGRENADE) | (1<<CSW_FLASHBANG) | (1<<CSW_SMOKEGRENADE))) {
		weaponData[Weapon_Slot] = GRENADE_SLOT;
	}
	else {
		weaponData[Weapon_Slot] = pItemId < 24 ? PRIMARY_WEAPON_SLOT : PISTOL_SLOT;
	}

	ArrayPushArray(g_aGroundWeapons, weaponData);
}