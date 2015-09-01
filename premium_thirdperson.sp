#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#undef REQUIRE_PLUGIN
#include <premium_manager>

#define PLUGIN_EFFECT "thirdperson"

new bool:g_bIsEnabled[MAXPLAYERS+1];
new bool:g_bPlayerNotice[MAXPLAYERS+1];

public Plugin:myinfo = {
    name = "Premium -> Thirdperson",
    author = "Monster Killer",
    description = "Allows players to toggle third person mode",
    version = "1.2",
    url = "http://monsterprojects.org"
};

public OnPluginStart() {
    HookEvent("player_spawn", OnPlayerSpawned);
    HookEvent("player_class", OnPlayerSpawned);
}

public OnAllPluginsLoaded() {
	if(LibraryExists("premium_manager"))
		Premium_Loaded();
}

public OnLibraryAdded(const String:name[]) {
	if(StrEqual(name, "premium_manager"))
		Premium_Loaded();
}

public Premium_Loaded() {
    Premium_RegEffect(PLUGIN_EFFECT, "Third Person", EnableEffect, DisableEffect, true);
}

public OnPluginEnd() {
    if(LibraryExists("premium_manager"))
        Premium_UnRegEffect(PLUGIN_EFFECT);
}

public OnClientConnected(client) {
    g_bIsEnabled[client] = false;
    g_bPlayerNotice[client] = false;
}

public EnableEffect(client) {
    g_bIsEnabled[client] = true;
    if(Premium_IsClientPremium(client) && IsPlayerAlive(client)) {
        SetVariantInt(1);
        AcceptEntityInput(client, "SetForcedTauntCam");
    }
}

public DisableEffect(client) {
    g_bIsEnabled[client] = false;
    if(IsClientInGame(client) && IsPlayerAlive(client)) {
        SetVariantInt(0);
        AcceptEntityInput(client, "SetForcedTauntCam");
    }
}

public OnEventShutdown() {
    UnhookEvent("player_spawn", OnPlayerSpawned);
    UnhookEvent("player_class", OnPlayerSpawned);
}

public Action:OnPlayerSpawned(Handle:event, const String:name[], bool:dontBroadcast) {
    new userid = GetEventInt(event, "userid");
    new client = GetClientOfUserId(userid);
    if(Premium_IsClientPremium(client) && g_bIsEnabled[client]) {
        if(!g_bPlayerNotice[client]) {
            PrintToChat(client, "%s \x07FE4444While in third person, your crosshair appears higher than it actually is.\x01", PREMIUM_PREFIX);
            g_bPlayerNotice[client] = true;
        }
        CreateTimer(0.2, Timer_SetTPOnSpawn, userid);
    }
}

public Action:Timer_SetTPOnSpawn(Handle:timer, any:userid) {
    new client = GetClientOfUserId(userid);
    if(Premium_IsClientPremium(client) && IsPlayerAlive(client)) {
        SetVariantInt(1);
        AcceptEntityInput(client, "SetForcedTauntCam");
    } 
}