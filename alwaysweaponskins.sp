public Plugin myinfo =
{
    name        = "AlwaysWeaponSkins (PTaH)",
    author      = "Kyle",
    description = "",
    version     = "1.7",
    url         = "https://www.kxnrl.com"
};

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>

// https://github.com/komashchenko/PTaH
#include <PTaH>

#pragma semicolon 1
#pragma newdecls required

#define TEAM_CTs 3
#define TEAM_TEs 2
#define TEAM_ANY 1

static StringMap g_adtWeapon;
static ArrayList g_adtMapWpn;
static bool g_bHook;
static bool g_bLate;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    RegPluginLibrary("AlwaysWeaponSkins");

    CreateNative("AWS_PushWeapon", Native_PushWeapon);
    
    g_bLate = late;

    return APLRes_Success;
}

public void OnPluginStart()
{
    InitWeapons();

    PTaH(PTaH_GiveNamedItemPre, Hook, Hook_GiveItemPre);

    HookEventEx("round_start",  Event_RoundStart,  EventHookMode_Post);
    
    if (g_bLate)
    {
        OnConfigsExecuted();
        
        for(int i=1; i<=MaxClients; ++i) if (IsClientInGame(i)) OnClientPutInServer(i);
    }
}

public any Native_PushWeapon(Handle plugin, int numParams)
{
    int weapon = GetNativeCell(1);
    int target = g_adtMapWpn.FindValue(weapon);
    if (target > -1) return true;
    return (g_adtMapWpn.Push(weapon) > 0);
}

public void OnConfigsExecuted()
{
    bool m_bFind = false;

    char map[32];
    GetCurrentMap(map, 32);

    // Game Zombie
    if (StrContains(map, "ze_", false) == 0 || StrContains(map, "zr_", false) == 0 || StrContains(map, "zm_", false) == 0)
        m_bFind = true;

    // Game TTT
    if (StrContains(map, "ttt_", false) == 0)
    {
        g_bHook = true; // allow replace map weapon
        m_bFind = true;
        LogMessage("allow replace map weapon");
    }

    // Game MiniGames
    if (StrContains(map, "mg_", false) == 0)
    {
        g_bHook = true; // allow replace map weapon
        m_bFind = true;
        LogMessage("allow replace map weapon");
    }

    // Game Jailbreak
    if (StrContains(map, "jb_", false) == 0 || StrContains(map, "ba_", false) == 0)
    {
        g_bHook = true; // allow replace map weapon
        m_bFind = true;
    }
    
    // Game KreedZ / BHop / Surf
    if (StrContains(map, "bkz_", false) == 0 || StrContains(map, "kz_", false) == 0 || StrContains(map, "xc_", false) == 0 || StrContains(map, "kzpro_", false) == 0 || StrContains(map, "bhop_", false) == 0 || StrContains(map, "surf_", false) == 0)
        m_bFind = true;

    // Game Hunger game
    if (StrContains(map, "hg_", false) == 0)
        m_bFind = true;
    
    // Game Deathsourf
    if (StrContains(map, "dr_", false) == 0 || StrContains(map, "deathrun_", false) == 0)
        m_bFind = true;

    if (!m_bFind)
    {
        char m_szPath[2][128];
        BuildPath(Path_SM, m_szPath[0], 128, "plugins/alwaysweaponskins.smx");
        BuildPath(Path_SM, m_szPath[1], 128, "plugins/disabled/alwaysweaponskins.smx");
        RenameFile(m_szPath[1], m_szPath[0]);
        ServerCommand("sm plugins unload alwaysweaponskins.smx");
    }
}

public void OnClientPutInServer(int client)
{
    if (!g_bHook || IsFakeClient(client))
        return;

    SDKHook(client, SDKHook_WeaponEquipPost, Hook_WeaponEquipPost);
}

public void OnClientDisconnect(int client)
{
    if (!g_bHook || IsFakeClient(client))
        return;

    SDKUnhook(client, SDKHook_WeaponEquipPost, Hook_WeaponEquipPost);
}

public Action Hook_GiveItemPre(int client, char classname[64], CEconItemView &Item, bool &IgnoredCEconItemView, bool &OriginIsNULL, float Origin[3])
{
    // If client is not in-game or not alive, then stop.
    if (!IsClientInGame(client) || !IsPlayerAlive(client) || IsFakeClient(client))
        return Plugin_Continue;

    // skip knife
    if (IsKnife(classname))
        return Plugin_Continue;

    if (IgnoredCEconItemView)
        return Plugin_Continue;

    // Get weapon origin team, if not find, then stop.
    int weaponTeam = -1;
    if (!g_adtWeapon.GetValue(classname, weaponTeam))
        return Plugin_Continue;

    // Get item definition
    CEconItemDefinition ItemDefinition = PTaH_GetItemDefinitionByName(classname);

    // Item definition is null, then stop.
    if (!ItemDefinition)
        return Plugin_Continue;

    // Get item Loadout Slot
    int iLoadoutSlot = ItemDefinition.GetLoadoutSlot();

    // new Item Info
    CCSPlayerInventory inventory = PTaH_GetPlayerInventory(client);
    if (!inventory)
        return Plugin_Continue;

    CEconItemView newItem = inventory.GetItemInLoadout(weaponTeam, iLoadoutSlot);
    if (!newItem)
        return Plugin_Continue;

    if (!newItem.IsCustomItemView())
    {
        if (weaponTeam == TEAM_ANY)
        {
            int team = GetClientTeam(client);
            newItem = inventory.GetItemInLoadout(team, iLoadoutSlot);
            if (newItem.IsCustomItemView() && SameClassname(classname, newItem))
            {
                Item = newItem;
                return Plugin_Changed;
            }
            else if (team == TEAM_CTs) team = TEAM_TEs;
            else if (team == TEAM_TEs) team = TEAM_CTs;

            newItem = inventory.GetItemInLoadout(team, iLoadoutSlot);
            if (newItem.IsCustomItemView() && SameClassname(classname, newItem))
            {
                Item = newItem;
                return Plugin_Changed;
            }
        }
        return Plugin_Continue;
    }

    if (!newItem)
        return Plugin_Continue;

    if (SameClassname(classname, newItem))
    {
        Item = newItem;
        return Plugin_Changed;
    }

    return Plugin_Continue;
}

bool SameClassname(const char[] classname, CEconItemView item)
{
    char class[64];
    item.GetItemDefinition().GetDefinitionName(class, 64);
    return (strcmp(classname, class) == 0);
}

public void Hook_WeaponEquipPost(int client, int weapon)
{
    // Ignore this if has PrevOwner
    int m_hPrevOwner = GetEntProp(weapon, Prop_Send, "m_hPrevOwner");
    if (m_hPrevOwner > 0)
        return;

    // Ignore map weapon
    if (!IsMapWeapon(weapon))
        return;

    // Give player a new weapon
    char classname[32];
    GetWeaponClassname(weapon, -1, classname, 32);
    AcceptEntityInput(weapon, "KillHierarchy");
    GivePlayerItem(client, classname);
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_bHook)
        return;

    CreateTimer(0.1, Timer_RoundStart);
}

public Action Timer_RoundStart(Handle timer)
{
    g_adtMapWpn.Clear();

    int index;

//((weaponIndex = FindEntityByClassname(weaponIndex, "weapon_*")) != -1 )
    char classname[32];
    for(int entity = MaxClients+1; entity <= 2048; ++entity)
    {
        if (!IsValidEdict(entity))
            continue;

        if (!GetEdictClassname(entity, classname, 32))
            continue;
        
        if (StrContains(classname, "weapon_") != 0 || StrContains(classname, "knife") != -1 || StrContains(classname, "healthshot", false) != -1 || StrContains(classname, "taser", false) != -1)
            continue;

        if (GetEntProp(entity, Prop_Send, "m_hPrevOwner") > 0 || GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity") > 0)
            continue;

        index = GetEntProp(entity, Prop_Send, "m_iItemDefinitionIndex");
        
        if (index == 0 || (index > 42 && index < 50))
            continue;

        g_adtMapWpn.Push(entity);
    }

    return Plugin_Stop;
}

public void OnEntityDestroyed(int entity)
{
    if (!g_bHook) return;
    IsMapWeapon(entity);
}

static bool IsMapWeapon(int entity)
{
    int index = FindValueInArray(g_adtMapWpn, entity);
    
    if (index == -1) return false;
    
    RemoveFromArray(g_adtMapWpn, index);

    return true;
}

stock int GetWeaponClassname(int weapon, int index, char[] classname, int maxLen)
{
    switch(GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex"))
    {
        case 41 : return strcopy(classname, maxLen, "weapon_knifegg");
        case 42 : return strcopy(classname, maxLen, "weapon_knife");
        case 59 : return strcopy(classname, maxLen, "weapon_knife_t");
        case 60 : return strcopy(classname, maxLen, "weapon_m4a1_silencer");
        case 61 : return strcopy(classname, maxLen, "weapon_usp_silencer");
        case 63 : return strcopy(classname, maxLen, "weapon_cz75a");
        case 64 : return strcopy(classname, maxLen, "weapon_revolver");
        case 500: return strcopy(classname, maxLen, "weapon_bayonet");
        case 503: return strcopy(classname, maxLen, "weapon_knife_css");
        case 505: return strcopy(classname, maxLen, "weapon_knife_flip");
        case 506: return strcopy(classname, maxLen, "weapon_knife_gut");
        case 507: return strcopy(classname, maxLen, "weapon_knife_karambit");
        case 508: return strcopy(classname, maxLen, "weapon_knife_m9_bayonet");
        case 509: return strcopy(classname, maxLen, "weapon_knife_tactical");
        case 512: return strcopy(classname, maxLen, "weapon_knife_falchion");
        case 514: return strcopy(classname, maxLen, "weapon_knife_survival_bowie");
        case 515: return strcopy(classname, maxLen, "weapon_knife_butterfly");   
        case 516: return strcopy(classname, maxLen, "weapon_knife_push");
        case 517: return strcopy(classname, maxLen, "weapon_knife_cord");
        case 518: return strcopy(classname, maxLen, "weapon_knife_canis");
        case 519: return strcopy(classname, maxLen, "weapon_knife_ursus");
        case 520: return strcopy(classname, maxLen, "weapon_knife_gypsy_jackknife");
        case 521: return strcopy(classname, maxLen, "weapon_knife_outdoor");
        case 522: return strcopy(classname, maxLen, "weapon_knife_stiletto");
        case 523: return strcopy(classname, maxLen, "weapon_knife_widowmaker");
        case 525: return strcopy(classname, maxLen, "weapon_knife_skeleton");
    }

    GetEdictClassname(weapon, classname, maxLen);
    return strlen(classname);
}

static void InitWeapons()
{
    g_adtWeapon = new StringMap();
    g_adtMapWpn = new ArrayList();

    // Pistol
    g_adtWeapon.SetValue("weapon_cz75a",         TEAM_ANY);
    g_adtWeapon.SetValue("weapon_p250",          TEAM_ANY);
    g_adtWeapon.SetValue("weapon_deagle",        TEAM_ANY);
    g_adtWeapon.SetValue("weapon_revolver",      TEAM_ANY);
    g_adtWeapon.SetValue("weapon_elite",         TEAM_ANY);
    g_adtWeapon.SetValue("weapon_glock",         TEAM_TEs);
    g_adtWeapon.SetValue("weapon_tec9",          TEAM_TEs);
    g_adtWeapon.SetValue("weapon_fiveseven",     TEAM_CTs);
    g_adtWeapon.SetValue("weapon_hkp2000",       TEAM_CTs);
    g_adtWeapon.SetValue("weapon_usp_silencer",  TEAM_CTs);
    
    // Heavy
    g_adtWeapon.SetValue("weapon_nova",          TEAM_ANY);
    g_adtWeapon.SetValue("weapon_xm1014",        TEAM_ANY);
    g_adtWeapon.SetValue("weapon_m249",          TEAM_ANY);
    g_adtWeapon.SetValue("weapon_negev",         TEAM_ANY);
    g_adtWeapon.SetValue("weapon_mag7",          TEAM_CTs);
    g_adtWeapon.SetValue("weapon_swadeoff",      TEAM_TEs);

    // SMG
    g_adtWeapon.SetValue("weapon_ump45",         TEAM_ANY);
    g_adtWeapon.SetValue("weapon_p90",           TEAM_ANY);
    g_adtWeapon.SetValue("weapon_bizon",         TEAM_ANY);
    g_adtWeapon.SetValue("weapon_mp7",           TEAM_ANY);
    g_adtWeapon.SetValue("weapon_mp5sd",         TEAM_ANY);
    g_adtWeapon.SetValue("weapon_mp9",           TEAM_CTs);
    g_adtWeapon.SetValue("weapon_mac10",         TEAM_TEs);

    // Rifle
    g_adtWeapon.SetValue("weapon_ssg08",         TEAM_ANY);
    g_adtWeapon.SetValue("weapon_awp",           TEAM_ANY);
    g_adtWeapon.SetValue("weapon_galilar",       TEAM_TEs);
    g_adtWeapon.SetValue("weapon_ak47",          TEAM_TEs);
    g_adtWeapon.SetValue("weapon_sg556",         TEAM_TEs);
    g_adtWeapon.SetValue("weapon_g3sg1",         TEAM_TEs);
    g_adtWeapon.SetValue("weapon_famas",         TEAM_CTs);
    g_adtWeapon.SetValue("weapon_m4a1",          TEAM_CTs);
    g_adtWeapon.SetValue("weapon_m4a1_silencer", TEAM_CTs);
    g_adtWeapon.SetValue("weapon_aug",           TEAM_CTs);
    g_adtWeapon.SetValue("weapon_scar20",        TEAM_CTs);
}

stock bool IsKnife(const char[] classname)
{
    if (
        strcmp(classname, "weapon_knife") == 0 ||
        strcmp(classname, "weapon_knife_t") == 0 ||
        strcmp(classname, "weapon_knifegg") == 0 ||
        strcmp(classname, "weapon_bayonet") == 0 ||
        strcmp(classname, "weapon_knife_gut") == 0 ||
        strcmp(classname, "weapon_knife_flip") == 0 ||
        strcmp(classname, "weapon_knife_m9_bayonet") == 0 ||
        strcmp(classname, "weapon_knife_karambit") == 0 ||
        strcmp(classname, "weapon_knife_tactical") == 0 ||
        strcmp(classname, "weapon_knife_butterfly") == 0 ||
        strcmp(classname, "weapon_knife_falchion") == 0 ||
        strcmp(classname, "weapon_knife_push") == 0 ||
        strcmp(classname, "weapon_knife_survival_bowie") == 0 ||
        strcmp(classname, "weapon_knife_ursus") == 0 ||
        strcmp(classname, "weapon_knife_windowmaker") == 0 ||
        strcmp(classname, "weapon_knife_stiletto") == 0 ||
        strcmp(classname, "weapon_knife_jackknife") == 0 || 
        strcmp(classname, "weapon_knife_css") == 0 ||
        strcmp(classname, "weapon_knife_widowmaker") == 0 ||
        strcmp(classname, "weapon_knife_skeleton") == 0 ||
        strcmp(classname, "weapon_knife_canis") == 0 ||
        strcmp(classname, "weapon_knife_cord") == 0 ||
        strcmp(classname, "weapon_knife_outdoor") == 0 ||
        strcmp(classname, "weapon_knife_gypsy_jackknife") == 0
      )
    return true;

    return false;
}