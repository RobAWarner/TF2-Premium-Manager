#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#undef REQUIRE_PLUGIN
#include <premium_manager>

new bool:g_bIsEnabled[MAXPLAYERS+1];

public Plugin:myinfo = 
{
	name = "Premium -> Thirdperson",
	author = "Monster Killer",
	description = "Allows players to toggle third person mode",
	version = "1.2",
	url = "http://monsterprojects.org"
};

public OnPluginStart()
{
	HookEvent("player_spawn", OnPlayerSpawned);
	HookEvent("player_class", OnPlayerSpawned);
}

public OnAllPluginsLoaded() {
    Premium_RegisterEffect("thirdperson", "Third Person", EnableEffect, DisableEffect, true);
}

public OnPluginEnd() {
    Premium_UnRegisterEffect("thirdperson");
}

public OnClientConnected(client) {
    g_bIsEnabled[client] = false;
}

public EnableEffect(client) {
    g_bIsEnabled[client] = true;
    SetVariantInt(1);
    AcceptEntityInput(client, "SetForcedTauntCam");
}

public DisableEffect(client) {
    g_bIsEnabled[client] = false;
    SetVariantInt(0);
    AcceptEntityInput(client, "SetForcedTauntCam");
}

public OnEventShutdown() {
	UnhookEvent("player_spawn", OnPlayerSpawned);
	UnhookEvent("player_class", OnPlayerSpawned);
}

public Action:OnPlayerSpawned(Handle:event, const String:name[], bool:dontBroadcast) {
	new userid = GetEventInt(event, "userid");
	if(IsValidClient(GetClientOfUserId(userid)) && g_bIsEnabled[GetClientOfUserId(userid)]) {
		CreateTimer(0.2, SetTPOnSpawn, userid);
	}
}

public Action:SetTPOnSpawn(Handle:timer, any:userid) {
	new client = GetClientOfUserId(userid);
	if(IsValidClient(client) && IsPlayerAlive(client)) {
		SetVariantInt(1);
		AcceptEntityInput(client, "SetForcedTauntCam");
	} 
}

stock bool:IsValidClient(client)
{
	if(client <= 0 || client > MaxClients)
		return false;
	if(!IsClientInGame(client))
		return false;
	if(IsClientSourceTV(client) || IsClientReplay(client) || IsFakeClient(client))
		return false;
	return true;
}