#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#undef REQUIRE_PLUGIN
#include <premium_manager>

new bool:g_bIsEnabled[MAXPLAYERS+1];

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
    Premium_RegEffect("thirdperson", "Third Person", EnableEffect, DisableEffect, true);
}

public OnPluginEnd() {
    if(LibraryExists("premium_manager"))
        Premium_UnRegEffect("thirdperson");
}

public OnClientConnected(client) {
    g_bIsEnabled[client] = false;
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
    if(Premium_IsClientPremium(GetClientOfUserId(userid)) && g_bIsEnabled[GetClientOfUserId(userid)]) {
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