#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <tf2_stocks>
#include <clientprefs>
#undef REQUIRE_PLUGIN
#include <premium_manager>

#define NO_ATTACH 0
#define ATTACH_NORMAL 1
#define ATTACH_HEAD 2

#define PLUGIN_EFFECT "particletrails"

/* TODO:
    Particle limit? 20 or so?
 */

new Handle:g_hParticles[MAXPLAYERS+1]; // List of particle edicts so we can remove them at appropriate times
new Handle:g_hParticleNames[MAXPLAYERS+1]; // List of particle names so we can remove them at appropriate times
new Handle:g_hParticleTrie[MAXPLAYERS+1];
new Handle:g_hEffects[MAXPLAYERS+1]; // List of enabled effect titles so we can re-enable the particles at appropriate times

new Handle:g_hConfig;

new bool:g_bIsEnabled[MAXPLAYERS+1];
new bool:g_bIsStealth[MAXPLAYERS+1];
new bool:g_bCookiesCached[MAXPLAYERS+1];

public Plugin:myinfo = {
    name        = "Premium -> Particles [TF2]",
    author      = "Azelphur / Monster Killer",
    description = "Place cool particle effects on players.",
    version     = "1.3",
    url         = "http://www.azelphur.com"
};

public OnPluginStart() {
    HookEvent("player_death", Event_PlayerDeath);
    HookEvent("player_spawn", Event_PlayerSpawn);
    
    g_hConfig = CreateKeyValues("Particles");
    decl String:szPath[256];
    BuildPath(Path_SM, szPath, sizeof(szPath), "configs/premium_particletrails_particles.cfg");
    if(FileExists(szPath)) {
        FileToKeyValues(g_hConfig, szPath);
    } else {
        SetFailState("File Not Found: %s", szPath);
    }

    for(new i = 0; i < MAXPLAYERS; i++) {
        g_hParticles[i] = CreateArray();
        g_hParticleNames[i] = CreateArray(256);
        g_hParticleTrie[i] = CreateTrie();
        g_hEffects[i] = CreateArray(256);
    }
    
    new Handle:hCookie;
    decl String:szTitle[64];
    KvGotoFirstSubKey(g_hConfig);
    do {
        KvGetSectionName(g_hConfig, szTitle, sizeof(szTitle));
        hCookie = RegClientCookie(szTitle, szTitle, CookieAccess_Public);
        CloseHandle(hCookie);
    } while (KvGotoNextKey(g_hConfig));
    KvRewind(g_hConfig);
}

public OnPluginEnd() {
    if(LibraryExists("premium_manager")) {
        Premium_UnRegEffect(PLUGIN_EFFECT);
    } else {
        for(new i = 1; i <= MaxClients; i++) {
            if(IsClientInGame(i) && g_bIsEnabled[i]) {
                RemoveAllParticles(i);
            }
        }
    }
}

public OnAllPluginsLoaded() {
    if(LibraryExists("premium_manager"))
        Premium_Loaded();
}

public OnLibraryAdded(const String:name[]) {
    if(StrEqual(name, "premium_manager"))
        Premium_Loaded();
}

public OnLibraryRemoved(const String:name[]) {
	if(StrEqual(name, "premium_manager")) {
        for(new i = 1; i <= MaxClients; i++) {
            g_bIsEnabled[i] = false;
        }
    }
}

public Premium_Loaded() {
    Premium_RegEffect(PLUGIN_EFFECT, "Particle Trails", Callback_EnableEffect, Callback_DisableEffect, true);
    Premium_AddEffectCooldown(PLUGIN_EFFECT, 5, PREMIUM_COOLDOWN_ENABLE);
    Premium_AddMenuOption(PLUGIN_EFFECT, "Choose Particles", Callback_ChooseParticles);
    Premium_AddMenuOption(PLUGIN_EFFECT, "Reset All Particles", Callback_ResetParticles);
}

/**************
|  Callbacks  |
**************/

public Callback_EnableEffect(client) {
    g_bIsEnabled[client] = true;
    if(!g_bCookiesCached[client] && AreClientCookiesCached(client)) {
        LoadClientParticles(client);
    }
    if(IsClientInGame(client) && g_bCookiesCached[client] && IsPlayerAlive(client)) {
        AddAllParticles(client);
    }
}

public Callback_DisableEffect(client) {
    g_bIsEnabled[client] = false;
    RemoveAllParticles(client);
}

public Callback_ChooseParticles(client) {
    ShowParticleMenu(client);
}

public Callback_ResetParticles(client) {
    /* Add 'are you sure' menu? */
    ResetAllParticles(client);
    PrintToChat(client, "%s All particles set to off", PREMIUM_PREFIX);
    Premium_ShowLastMenu(client);
}

/***********
|  Client  |
***********/

public OnClientCookiesCached(client) {
    LoadClientParticles(client);
}

public OnClientConnected(client) {
    ClearArray(g_hParticles[client]);
    ClearArray(g_hParticleNames[client]);
    ClearTrie(g_hParticleTrie[client]);
    ClearArray(g_hEffects[client]);
    
    g_bIsEnabled[client] = false;
    g_bCookiesCached[client] = false;
}

public LoadClientParticles(client) {
    if(g_bCookiesCached[client]) {
        return;
    }
    g_bCookiesCached[client] = true;

    KvGotoFirstSubKey(g_hConfig);
    new Handle:hCookie;
    decl String:szTitle[64], String:szCookie[64];
    do {
        KvGetSectionName(g_hConfig, szTitle, sizeof(szTitle));
        hCookie = FindClientCookie(szTitle);
        if(hCookie == INVALID_HANDLE) {
            continue;
        }
        GetClientCookie(client, hCookie, szCookie, sizeof(szCookie));
        if(StrEqual(szCookie, "1")) {
            SetTrieValue(g_hParticleTrie[client], szTitle, 1);
            PushArrayString(g_hEffects[client], szTitle);
        }
        CloseHandle(hCookie);
    } while (KvGotoNextKey(g_hConfig));
    KvRewind(g_hConfig);
}

/***********
|  Events  |
***********/

public Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast) {
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    RemoveAllParticles(client);
}

public Event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast) {
    new userid = GetEventInt(event, "userid");
    new client = GetClientOfUserId(userid);
    if(Premium_IsClientPremium(client) && g_bIsEnabled[client]){
        CreateTimer(0.0, Timer_SpawnPost, userid);
    }
}

public Action:Timer_SpawnPost(Handle:timer, any:userid) {
    new client = GetClientOfUserId(userid);
    if(client) {
        RemoveAllParticles(client);
        AddAllParticles(client);
    }
}

/******************
|  Particle Menu  |
******************/

ShowParticleMenu(client, slot=0) {
    decl String:szTitle[256], String:szMenuItem[256];
    new Handle:hMenu = CreateMenu(MenuHandler_ParticleMenuHandler);
    SetMenuExitBackButton(hMenu, true);
    SetMenuTitle(hMenu, "Choose Particles");

    KvGotoFirstSubKey(g_hConfig);  

    do {
        KvGetSectionName(g_hConfig, szTitle, sizeof(szTitle));
        new iEnabled = 0;
        GetTrieValue(g_hParticleTrie[client], szTitle, iEnabled);
        if(iEnabled) {
            Format(szMenuItem, sizeof(szMenuItem), "Turn off %s", szTitle);
        } else {
            Format(szMenuItem, sizeof(szMenuItem), "Turn on %s", szTitle);
        }
        AddMenuItem(hMenu, szTitle, szMenuItem);
    } while (KvGotoNextKey(g_hConfig));

    KvRewind(g_hConfig);
    DisplayMenuAtItem(hMenu, client, slot, MENU_TIME_FOREVER);
}

public MenuHandler_ParticleMenuHandler(Handle:menu, MenuAction:action, param1, param2) {
    if(action == MenuAction_Select) {
        new String:info[256];
        GetMenuItem(menu, param2, info, sizeof(info));
        new iEnabled = 0;
        GetTrieValue(g_hParticleTrie[param1], info, iEnabled);
        if(iEnabled) {
            DisableParticle(param1, info);
        } else {
            Particle(param1, info);
        }
        ShowParticleMenu(param1, (param2/7)*7);
    } else if(action == MenuAction_Cancel && param2 == MenuCancel_ExitBack) {
        Premium_ShowLastMenu(param1);
    }
}

/*******************
|  Particle state  |
*******************/

ResetAllParticles(client) {
    decl String:szTitle[256];
    for(new i = (GetArraySize(g_hEffects[client]) - 1); i >= 0; i--) {
        GetArrayString(g_hEffects[client], i, szTitle, sizeof(szTitle));
        DisableParticle(client, szTitle);
    }
}

DisableParticle(client, const String:effect[]) {
    decl String:szTitle[256], String:szClassName[256];
    new iParticle;
    for(new i = 0; i < GetArraySize(g_hParticles[client]); i++) {
        GetArrayString(g_hParticleNames[client], i, szTitle, sizeof(szTitle));
        if(StrEqual(effect, szTitle)) {
            iParticle = GetArrayCell(g_hParticles[client], i);
            if(IsValidEdict(iParticle)) {
                GetEdictClassname(iParticle, szClassName, sizeof(szClassName));
                if(StrEqual(szClassName, "info_particle_system", false)) {
                    RemoveEdict(iParticle);
                }
            }
            RemoveFromArray(g_hParticles[client], i);
            RemoveFromArray(g_hParticleNames[client], i);
            i--;
        }
    }
    new Handle:hCookie;
    for(new i = 0; i < GetArraySize(g_hEffects[client]); i++) {
        GetArrayString(g_hEffects[client], i, szTitle, sizeof(szTitle));
        if(StrEqual(effect, szTitle)) {
            RemoveFromArray(g_hEffects[client], i);
            hCookie = FindClientCookie(szTitle);
            SetClientCookie(client, hCookie, "0");
            CloseHandle(hCookie);
        }
    }

    RemoveFromTrie(g_hParticleTrie[client], effect);
}

Particle(client, const String:effect[], bool:update=true) {
    if(!IsClientInGame(client)) {
        return;
    }

    decl String:szTitle[256], String:szAttach[32];
    new Handle:hCookie;
    KvGotoFirstSubKey(g_hConfig);
    do {
        KvGetSectionName(g_hConfig, szTitle, sizeof(szTitle));
        if(StrEqual(szTitle, effect, false)) {
            if(update) {
                PushArrayString(g_hEffects[client], effect);
            }

            SetTrieValue(g_hParticleTrie[client], szTitle, 1);
            hCookie = FindClientCookie(szTitle);
            SetClientCookie(client, hCookie, "1");
            CloseHandle(hCookie);
            KvGotoFirstSubKey(g_hConfig);
            do {
                KvGetSectionName(g_hConfig, szTitle, sizeof(szTitle));
                KvGetString(g_hConfig, "attach", szAttach, sizeof(szAttach));
                if(StrEqual(szAttach, "NORMAL", false)) {
                    if(g_bIsEnabled[client] && IsPlayerAlive(client)) {
                        CreateParticle(szTitle, 300.0, client, ATTACH_NORMAL, KvGetFloat(g_hConfig, "x", 0.0), KvGetFloat(g_hConfig, "y", 0.0), KvGetFloat(g_hConfig, "z", 0.0), effect);
                    }
                }
            } while (KvGotoNextKey(g_hConfig));
            KvGoBack(g_hConfig);
        }
    } while (KvGotoNextKey(g_hConfig));
    KvRewind(g_hConfig);
}

RemoveAllParticles(client) {
    new iParticle;
    decl String:szClassName[64];
    for(new i = 0; i < GetArraySize(g_hParticles[client]); i++) {
        iParticle = GetArrayCell(g_hParticles[client], i);
        if(IsValidEdict(iParticle)) {
            GetEdictClassname(iParticle, szClassName, sizeof(szClassName));
            if(StrEqual(szClassName, "info_particle_system", false)) {
                RemoveEdict(iParticle);
            }
        }
    }
    ClearArray(g_hParticles[client]);
}

AddAllParticles(client) {
    if(!IsPlayerAlive(client)) {
        return;
    }
    decl String:szTitle[256];
    for(new i = 0; i < GetArraySize(g_hEffects[client]); i++) {
        GetArrayString(g_hEffects[client], i, szTitle, sizeof(szTitle));
        Particle(client, szTitle, false);
    }
}


stock CreateParticle(String:type[], Float:time, entity, attach=NO_ATTACH, Float:xOffs=0.0, Float:yOffs=0.0, Float:zOffs=0.0, const String:effect[]) {
    new particle = CreateEntityByName("info_particle_system");
    
    if(IsValidEdict(particle)) {
        decl Float:pos[3];
        GetEntPropVector(entity, Prop_Send, "m_vecOrigin", pos);
        pos[0] += xOffs;
        pos[1] += yOffs;
        pos[2] += zOffs;
        TeleportEntity(particle, pos, NULL_VECTOR, NULL_VECTOR);
        DispatchKeyValue(particle, "effect_name", type);

        if(attach != NO_ATTACH) {
            SetVariantString("!activator");
            AcceptEntityInput(particle, "SetParent", entity, particle, 0);
        
            if(attach == ATTACH_HEAD) {
                SetVariantString("head");
                AcceptEntityInput(particle, "SetParentAttachmentMaintainOffset", particle, particle, 0);
            }
        }
        DispatchKeyValue(particle, "targetname", "present");
        DispatchSpawn(particle);
        ActivateEntity(particle);
        AcceptEntityInput(particle, "Start");
        PushArrayCell(g_hParticles[entity], particle);
        PushArrayString(g_hParticleNames[entity], effect);
        return particle;
    } else {
        LogError("Presents (CreateParticle): Could not create info_particle_system");
    }
    
    return -1;
}

public OnGameFrame() {
    for(new i = 1; i <= MaxClients; i++) {
        if(Premium_IsClientPremium(i) && IsPlayerAlive(i) && g_bIsEnabled[i]) {
            if(TF2_IsPlayerInCondition(i, TFCond_Cloaked) || TF2_IsPlayerInCondition(i, TFCond_Disguised)) {
                if(g_bIsStealth[i] == false) {
                    g_bIsStealth[i] = true;
                    OnPlayerCloak(i);
                }
            } else {
                if(g_bIsStealth[i] == true) {
                    g_bIsStealth[i] = false;
                    OnPlayerUnCloak(i);
                }
            }
        }
    }
}

public OnPlayerCloak(client) {
    RemoveAllParticles(client);
}

public OnPlayerUnCloak(client) {
    AddAllParticles(client);
}