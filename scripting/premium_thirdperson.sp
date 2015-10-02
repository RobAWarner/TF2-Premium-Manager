#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <tf2_stocks>
#undef REQUIRE_PLUGIN
#include <premium_manager>

#define PLUGIN_EFFECT "thirdperson"

new bool:g_bIsEnabled[MAXPLAYERS+1];
new bool:g_bIsZoomed[MAXPLAYERS+1];
new bool:g_bPlayerNotice[MAXPLAYERS+1];

public Plugin:myinfo = {
    name = "Premium -> Thirdperson [TF2]",
    author = "Monster Killer",
    description = "Allows players to toggle third person mode",
    version = "1.2",
    url = "http://monsterprojects.org"
};

public OnPluginStart() {
    HookEvent("player_spawn", Event_PlayerSpawn);
    HookEvent("player_class", Event_PlayerSpawn);
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
            if(IsClientInGame(i) && IsPlayerAlive(i)) {
                SetVariantInt(0);
                AcceptEntityInput(i, "SetForcedTauntCam");
            }
        }
    }
}

public Premium_Loaded() {
    Premium_RegEffect(PLUGIN_EFFECT, "Third Person", Callback_EnableEffect, Callback_DisableEffect, true);
}

public OnPluginEnd() {
    if(LibraryExists("premium_manager"))
        Premium_UnRegEffect(PLUGIN_EFFECT);
}

public OnClientConnected(client) {
    g_bIsEnabled[client] = false;
    g_bIsZoomed[client] = false;
    g_bPlayerNotice[client] = false;
}

public Callback_EnableEffect(client) {
    g_bIsEnabled[client] = true;
    if(IsClientInGame(client) && IsPlayerAlive(client)) {
        SetVariantInt(1);
        AcceptEntityInput(client, "SetForcedTauntCam");
    }
}

public Callback_DisableEffect(client) {
    g_bIsEnabled[client] = false;
    if(IsClientInGame(client) && IsPlayerAlive(client)) {
        SetVariantInt(0);
        AcceptEntityInput(client, "SetForcedTauntCam");
    }
}

public OnEventShutdown() {
    UnhookEvent("player_spawn", Event_PlayerSpawn);
    UnhookEvent("player_class", Event_PlayerSpawn);
}

public Action:Event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast) {
    new userid = GetEventInt(event, "userid");
    new client = GetClientOfUserId(userid);
    if(g_bIsEnabled[client]) {
        if(!g_bPlayerNotice[client]) {
            PrintToChat(client, "%s \x07FE4444While in third person, your crosshair appears higher than it actually is.\x01", PREMIUM_PREFIX);
            g_bPlayerNotice[client] = true;
        }
        CreateTimer(0.2, Timer_SetTPOnSpawn, userid);
    }
}

public Action:Timer_SetTPOnSpawn(Handle:timer, any:userid) {
    new client = GetClientOfUserId(userid);
    if(IsClientInGame(client) && IsPlayerAlive(client) && g_bIsEnabled[client]) {
        SetVariantInt(1);
        AcceptEntityInput(client, "SetForcedTauntCam");
    } 
}

public OnGameFrame() {
    for(new i = 1; i <= MaxClients; i++) {
        if(IsClientInGame(i) && IsPlayerAlive(i) && g_bIsEnabled[i]) {
            if(TF2_IsPlayerInCondition(i, TFCond_Zoomed)) {
                if(g_bIsZoomed[i] == false) {
                    g_bIsZoomed[i] = true;
                    OnPlayerZoom(i);
                }
            } else {
                if(g_bIsZoomed[i] == true) {
                    g_bIsZoomed[i] = false;
                    OnPlayerUnZoom(i);
                }
            }
        }
    }
}

OnPlayerZoom(client) {
    SetVariantInt(0);
    AcceptEntityInput(client, "SetForcedTauntCam");
}

OnPlayerUnZoom(client) {
    SetVariantInt(1);
    AcceptEntityInput(client, "SetForcedTauntCam");
}