public Plugin myinfo =
{
    name        = "AlwaysWeaponSkins (PTaH)",
    author      = "Kyle",
    description = "",
    version     = "1.4",
    url         = "https://kxnrl.com"
};

#include <sdkhooks>
#include <sdktools>

// https://github.com/komashchenko/PTaH
#include <PTaH>

#pragma semicolon 1
#pragma newdecls required

#define TEAM_CTs 3
#define TEAM_TEs 2
#define TEAM_ANY 1

static Handle g_adtWeapon;
static Handle g_adtMapWpn;
static bool g_bHook;
static int  g_iMapWeapons[MAXPLAYERS+1];


public void OnConfigsExecuted()
{
    bool m_bFind = false;
    
    char map[32];
    GetCurrentMap(map, 32);
    
    // Game Zombie
    if(StrContains(map, "ze_", false) == 0 || StrContains(map, "zr_", false) == 0 || StrContains(map, "zm_", false) == 0)
        m_bFind = true;

    // Game TTT
    if(StrContains(map, "ttt_", false) == 0)
        m_bFind = true;

    // Game MiniGames
    if(StrContains(map, "mg_", false) == 0)
    {
        g_bHook = true; // allow replace map weapon
        m_bFind = true;
        LogMessage("allow replace map weapon");
    }

    // Game Jailbreak
    if(StrContains(map, "jb_", false) == 0)
    {
        g_bHook = true; // allow replace map weapon
        m_bFind = true;
    }
    
    // Game KreedZ / BHop / Surf
    if(StrContains(map, "bkz_", false) == 0 || StrContains(map, "kz_", false) == 0 || StrContains(map, "xc_", false) == 0 || StrContains(map, "kzpro_", false) == 0 || StrContains(map, "bhop_", false) == 0 || StrContains(map, "surf_", false) == 0)
        m_bFind = true;

    // Game Hunger game
    if(StrContains(map, "hg_", false) == 0)
        m_bFind = true;
    
    // Game Deathsourf
    if(StrContains(map, "dr_", false) == 0 || StrContains(map, "deathrun_", false) == 0)
        m_bFind = true;

    if(!m_bFind)
    {
        char m_szPath[2][128];
        BuildPath(Path_SM, m_szPath[0], 128, "plugins/alwaysweaponskins.smx");
        BuildPath(Path_SM, m_szPath[1], 128, "plugins/disabled/alwaysweaponskins.smx");
        if(!RenameFile(m_szPath[1], m_szPath[0]))
             LogError("Failed to move alwaysweaponskins.smx to disable folder.");
        else LogError("alwaysweaponskins is not avaliable on current map.");
        ServerCommand("sm plugins unload alwaysweaponskins.smx");
        return;
    }

    InitWeapons();

    PTaH(PTaH_GiveNamedItemPre, Hook, Hook_GiveItemPre);

    HookEventEx("player_spawn", Event_PlayerSpawn, EventHookMode_Post);
    HookEventEx("round_start",  Event_RoundStart,  EventHookMode_Post);
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    g_iMapWeapons[GetClientOfUserId(event.GetInt("userid"))] = 0;
}

public void OnClientPutInServer(int client)
{
    if(!g_bHook || IsFakeClient(client))
        return;

    g_iMapWeapons[client] = 0;
    SDKHook(client, SDKHook_WeaponEquipPost, Hook_WeaponEquipPost);
}
 
public void OnClientDisconnect(int client)
{
    if(!g_bHook || IsFakeClient(client))
        return;

    SDKUnhook(client, SDKHook_WeaponEquipPost, Hook_WeaponEquipPost);
}

public Action Hook_GiveItemPre(int client, char classname[64], CEconItemView &Item, bool &IgnoredCEconItemView)
{
    // If client is not in-game or not alive, then stop.
    if(!IsClientInGame(client) || !IsPlayerAlive(client) || IsFakeClient(client) || IgnoredCEconItemView)
        return Plugin_Continue;

    // Get weapon origin team, if not m_bFind, then stop.
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
    //    return Plugin_Continue; 

    Item = newItem;

    return Plugin_Changed;
}

public void Hook_WeaponEquipPost(int client, int weapon)
{
    // Ignore map weapon
    if(!IsMapWeapon(weapon))
        return;

    // Ignore this if has PrevOwner
    int m_hPrevOwner = GetEntProp(weapon, Prop_Send, "m_hPrevOwner");
    if(m_hPrevOwner > 0)
        return;
    
    // Ignore maps item
    if(GetEntPropEnt(weapon, Prop_Data, "m_hMoveChild") == -1)
        return;

    // Slay Player if too many pick-up
    if(++g_iMapWeapons[client] > 6)
    {
        ForcePlayerSuicide(client);
        return;
    }

    // Give player a new weapon
    char classname[32];
    GetWeaponClassname(weapon, classname, 32);
    AcceptEntityInput(weapon, "Kill");
    GivePlayerItem(client, classname);
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    if(!g_bHook)
        return;

    CreateTimer(0.1, Timer_RoundStart);
}

public Action Timer_RoundStart(Handle timer)
{
    ClearArray(g_adtMapWpn);
    
    int index;

    char classname[32];
    for(int entity = MaxClients+1; entity <= 2048; ++entity)
    {
        if(!IsValidEdict(entity))
            continue;

        if(!GetEdictClassname(entity, classname, 32))
            continue;
        
        if(StrContains(classname, "weapon_") != 0 || StrContains(classname, "knife") != -1 || StrContains(classname, "healthshot", false) != -1 || StrContains(classname, "taser", false) != -1)
            continue;

        if(GetEntProp(entity, Prop_Send, "m_hPrevOwner") > 0 || GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity") > 0)
            continue;

        index = GetEntProp(entity, Prop_Send, "m_iItemDefinitionIndex");
        
        if(index == 0 || (index > 42 && index < 50))
            continue;

        PushArrayCell(g_adtMapWpn, entity);
    }
    
    return Plugin_Stop;
}

public void OnEntityDestroyed(int entity)
{
    if(!g_bHook) return;
    IsMapWeapon(entity);
}

static bool IsMapWeapon(int entity)
{
    int index = FindValueInArray(g_adtMapWpn, entity);
    
    if(index == -1) return false;
    
    RemoveFromArray(g_adtMapWpn, index);

    return true;
}

static void GetWeaponClassname(int weapon, char[] classname, int maxLen)
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

static void InitWeapons()
{
    g_adtWeapon = CreateTrie();
    g_adtMapWpn = CreateArray();

    // Pistol
    SetTrieValue(g_adtWeapon,    "weapon_cz75a",         TEAM_ANY);
    SetTrieValue(g_adtWeapon,    "weapon_p250",          TEAM_ANY);
    SetTrieValue(g_adtWeapon,    "weapon_deagle",        TEAM_ANY);
    SetTrieValue(g_adtWeapon,    "weapon_revolver",      TEAM_ANY);
    SetTrieValue(g_adtWeapon,    "weapon_elite",         TEAM_ANY);
    SetTrieValue(g_adtWeapon,    "weapon_glock",         TEAM_TEs);
    SetTrieValue(g_adtWeapon,    "weapon_tec9",          TEAM_TEs);
    SetTrieValue(g_adtWeapon,    "weapon_fiveseven",     TEAM_CTs);
    SetTrieValue(g_adtWeapon,    "weapon_hkp2000",       TEAM_CTs);
    SetTrieValue(g_adtWeapon,    "weapon_usp_silencer",  TEAM_CTs);
    
    // Heavy
    SetTrieValue(g_adtWeapon,    "weapon_nova",          TEAM_ANY);
    SetTrieValue(g_adtWeapon,    "weapon_xm1014",        TEAM_ANY);
    SetTrieValue(g_adtWeapon,    "weapon_m249",          TEAM_ANY);
    SetTrieValue(g_adtWeapon,    "weapon_negev",         TEAM_ANY);
    SetTrieValue(g_adtWeapon,    "weapon_mag7",          TEAM_CTs);
    SetTrieValue(g_adtWeapon,    "weapon_swadeoff",      TEAM_TEs);

    // SMG
    SetTrieValue(g_adtWeapon,    "weapon_ump45",         TEAM_ANY);
    SetTrieValue(g_adtWeapon,    "weapon_p90",           TEAM_ANY);
    SetTrieValue(g_adtWeapon,    "weapon_bizon",         TEAM_ANY);
    SetTrieValue(g_adtWeapon,    "weapon_mp7",           TEAM_ANY);
    SetTrieValue(g_adtWeapon,    "weapon_mp9",           TEAM_CTs);
    SetTrieValue(g_adtWeapon,    "weapon_mac10",         TEAM_TEs);

    // Rifle
    SetTrieValue(g_adtWeapon,    "weapon_ssg08",         TEAM_ANY);
    SetTrieValue(g_adtWeapon,    "weapon_awp",           TEAM_ANY);
    SetTrieValue(g_adtWeapon,    "weapon_galilar",       TEAM_TEs);
    SetTrieValue(g_adtWeapon,    "weapon_ak47",          TEAM_TEs);
    SetTrieValue(g_adtWeapon,    "weapon_sg556",         TEAM_TEs);
    SetTrieValue(g_adtWeapon,    "weapon_g3sg1",         TEAM_TEs);
    SetTrieValue(g_adtWeapon,    "weapon_famas",         TEAM_CTs);
    SetTrieValue(g_adtWeapon,    "weapon_m4a1",          TEAM_CTs);
    SetTrieValue(g_adtWeapon,    "weapon_m4a1_silencer", TEAM_CTs);
    SetTrieValue(g_adtWeapon,    "weapon_aug",           TEAM_CTs);
    SetTrieValue(g_adtWeapon,    "weapon_scar20",        TEAM_CTs);
}