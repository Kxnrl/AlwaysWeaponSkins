#include <PTaH>
#include <sdkhooks>
#include <sdktools>

#pragma newdecls required

#define TEAM_CTs 3
#define TEAM_TEs 2
#define TEAM_ANY 1

Handle g_adtWeapon;
Handle g_adtMapWpn;

bool g_bHooked;
bool g_bLastRequest;

public Plugin myinfo =
{
	name		= "AlwaysWeaponSkins (PTaH)",
	author		= "Kyle",
	description = "",
	version		= "1.1",
	url			= "http://steamcommunity.com/id/_xQy_/"
};

public void OnAllPluginsLoaded()
{
	bool found = false;
	
	// Game ZombieEscape
	if(FindPluginByFile("zombiereloaded.smx"))
		found = true;

	// Game TTT
	if(FindPluginByFile("ct.smx"))
		found = true;
	
	// Game MiniGames
	if(FindPluginByFile("mg_stats.smx"))
	{
		g_bHooked = true; // allow replace map weapon
		found = true;
	}
	
	// Game Jailbreak
	if(FindPluginByFile("sm_hosties.smx"))
	{
		g_bHooked = true; // allow replace map weapon
		found = true;
	}

	// Game Hunger game
	if(FindPluginByFile("hg.smx"))
		found = true;
	
	// Game Deathsourf
	if(FindPluginByFile("deathsurf.smx"))
		found = true;

	if(!found)
	{
		LogError("alwaysweaponskins is not avaliable in current server.");
		char m_szPath[128];
		BuildPath(Path_SM, m_szPath, 128, "plugins/alwaysweaponskins.smx");
		if(!FileExists(m_szPath) || !DeleteFile(m_szPath))
			LogError("Delete alwaysweaponskins.smx failed.");
		ServerCommand("sm plugins unload alwaysweaponskins.smx");
		return;
	}

	InitWeapons();
	PTaH(PTaH_GiveNamedItemPre, Hook, Hook_GiveItemPre);

	for(int client = 1; client <= MaxClients; ++client)
		if(IsClientInGame(client))
			OnClientPutInServer(client);
}

public void OnClientPutInServer(int client)
{
	if(!g_bHooked || IsFakeClient(client))
		return;

	SDKHook(client, SDKHook_WeaponEquipPost, Hook_WeaponEquipPost);
}

public void OnClientDisconnect(int client)
{
	if(!g_bHooked || IsFakeClient(client))
		return;

	SDKUnhook(client, SDKHook_WeaponEquipPost, Hook_WeaponEquipPost);
}

public Action Hook_GiveItemPre(int client, char classname[64], CEconItemView &Item) 
{
	// If client is not in-game or not alive, then stop.
	if(!IsClientInGame(client) || !IsPlayerAlive(client) || IsFakeClient(client))
		return Plugin_Continue;

	// Get weapon origin team, if not found, then stop.
	int weaponTeam;
	if(!GetTrieValue(g_adtWeapon, classname, weaponTeam) || weaponTeam == TEAM_ANY)
		return Plugin_Continue;

	// Get item definition
	CEconItemDefinition ItemDefinition = PTaH_GetItemDefinitionByName(classname); 

	// Item definition is null, then stop.
	if(!ItemDefinition)
		return Plugin_Continue;

	// Get item Loadout Slot
	int iLoadoutSlot = ItemDefinition.GetLoadoutSlot();

	// new Item Info
	CEconItemView newItem = PTaH_GetItemInLoadout(client, weaponTeam, iLoadoutSlot);

	// Is Custom Item?
	//if(!newItem.IsCustomItemView())
	//	return Plugin_Continue; 

	Item = newItem;

	return Plugin_Changed;
}

public void Hook_WeaponEquipPost(int client, int weapon)
{
    // If last request is available.
    if(g_bLastRequest)
        return;
    
	// Ignore map weapon
	if(!IsMapWeapon(weapon))
		return;

	int m_hPrevOwner = GetEntProp(weapon, Prop_Send, "m_hPrevOwner");
	if(m_hPrevOwner > 0)
		return;

	char classname[32];
	GetWeaponClassname(weapon, classname, 32);
	AcceptEntityInput(weapon, "Kill");
	GivePlayerItem(client, classname);
}

public void CG_OnRoundStart()
{
	if(!g_bHooked) return;
	CreateTimer(0.15, Timer_RoundStart);
    g_bLastRequest = false;
}

public void OnAvailableLR(int Announced)
{
    g_bLastRequest = true;
}

public Action Timer_RoundStart(Handle timer)
{
	ClearArray(g_adtMapWpn);

	char classname[32];
	for(int entity = MaxClients+1; entity <= 2048; ++entity)
	{
		if(!IsValidEdict(entity))
			continue;

		if(!GetEdictClassname(entity, classname, 32))
			continue;
		
		if(StrContains(classname, "weapon_") != 0 || StrContains(classname, "knife") != -1)
			continue;

		if(GetEntProp(entity, Prop_Send, "m_hPrevOwner") > 0 || GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity") > 0)
			continue;

		PushArrayCell(g_adtMapWpn, entity);
	}
}

public void OnEntityDestroyed(int entity)
{
	if(!g_bHooked) return;
	IsMapWeapon(entity);
}

bool IsMapWeapon(int entity)
{
	int index = FindValueInArray(g_adtMapWpn, entity);
	
	if(index == -1) return false;
	
	RemoveFromArray(g_adtMapWpn, index);

	return true;
}

void GetWeaponClassname(int weapon, char[] classname, int maxLen)
{
	GetEdictClassname(weapon, classname, maxLen);
	switch(GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex"))
	{
		case 60: strcopy(classname, maxLen, "weapon_m4a1_silencer");
		case 61: strcopy(classname, maxLen, "weapon_usp_silencer");
		case 63: strcopy(classname, maxLen, "weapon_cz75a");
		case 64: strcopy(classname, maxLen, "weapon_revolver");
	}
}

void InitWeapons()
{
	g_adtWeapon = CreateTrie();
	g_adtMapWpn = CreateArray();

	// Pistol
	SetTrieValue(g_adtWeapon,	"weapon_cz75a",			TEAM_ANY);
	SetTrieValue(g_adtWeapon,	"weapon_p250",			TEAM_ANY);
	SetTrieValue(g_adtWeapon,	"weapon_deagle",		TEAM_ANY);
	SetTrieValue(g_adtWeapon,	"weapon_revolver",		TEAM_ANY);
	SetTrieValue(g_adtWeapon,	"weapon_elite",			TEAM_ANY);
	SetTrieValue(g_adtWeapon,	"weapon_glock",			TEAM_TEs);
	SetTrieValue(g_adtWeapon,	"weapon_tec9",			TEAM_TEs);
	SetTrieValue(g_adtWeapon,	"weapon_fiveseven",		TEAM_CTs);
	SetTrieValue(g_adtWeapon,	"weapon_hkp2000",		TEAM_CTs);
	SetTrieValue(g_adtWeapon,	"weapon_usp_silencer",	TEAM_CTs);
	
	// Heavy
	SetTrieValue(g_adtWeapon,	"weapon_nova",			TEAM_ANY);
	SetTrieValue(g_adtWeapon,	"weapon_xm1014",		TEAM_ANY);
	SetTrieValue(g_adtWeapon,	"weapon_m249",			TEAM_ANY);
	SetTrieValue(g_adtWeapon,	"weapon_negev",			TEAM_ANY);
	SetTrieValue(g_adtWeapon,	"weapon_mag7",			TEAM_CTs);
	SetTrieValue(g_adtWeapon,	"weapon_swadeoff",		TEAM_TEs);

	// SMG
	SetTrieValue(g_adtWeapon,	"weapon_ump45",			TEAM_ANY);
	SetTrieValue(g_adtWeapon,	"weapon_p90",			TEAM_ANY);
	SetTrieValue(g_adtWeapon,	"weapon_bizon",			TEAM_ANY);
	SetTrieValue(g_adtWeapon,	"weapon_mp7",			TEAM_ANY);
	SetTrieValue(g_adtWeapon,	"weapon_mp9",			TEAM_CTs);
	SetTrieValue(g_adtWeapon,	"weapon_mac10",			TEAM_TEs);

	// Rifle
	SetTrieValue(g_adtWeapon,	"weapon_ssg08",			TEAM_ANY);
	SetTrieValue(g_adtWeapon,	"weapon_awp",			TEAM_ANY);
	SetTrieValue(g_adtWeapon,	"weapon_galilar",		TEAM_TEs);
	SetTrieValue(g_adtWeapon,	"weapon_ak47",			TEAM_TEs);
	SetTrieValue(g_adtWeapon,	"weapon_sg556",			TEAM_TEs);
	SetTrieValue(g_adtWeapon,	"weapon_g3sg1",			TEAM_TEs);
	SetTrieValue(g_adtWeapon,	"weapon_famas",			TEAM_CTs);
	SetTrieValue(g_adtWeapon,	"weapon_m4a1",			TEAM_CTs);
	SetTrieValue(g_adtWeapon,	"weapon_m4a1_silencer",	TEAM_CTs);
	SetTrieValue(g_adtWeapon,	"weapon_aug",			TEAM_CTs);
	SetTrieValue(g_adtWeapon,	"weapon_scar20",		TEAM_CTs);
}