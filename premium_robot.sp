/* TODO: disable demoman!!!
get working cosmetic list? */
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <tf2_stocks>
#undef REQUIRE_PLUGIN
#include <premium_manager>

new bool:g_bIsStealth[MAXPLAYERS+1];
new bool:g_bRobotEnabled[MAXPLAYERS+1];

public Plugin:myinfo = 
{
	name = "Premium -> Robot",
	author = "Monster Killer",
	description = "Allows Robots",
	version = "1.1",
	url = "http://monsterprojects.org"
};


public OnPluginStart() {
	HookEvent("player_spawn", OnPlayerSpawned);
	HookEvent("player_class", OnPlayerSpawned);
	
	AddCommandListener(OnPlayerTaunt, "taunt");
	AddCommandListener(OnPlayerTaunt, "+taunt");

	AddNormalSoundHook(SoundHook);
}

public OnAllPluginsLoaded() {
    Premium_RegisterEffect("robotmode", "Robot Mode", EnableEffect, DisableEffect, true);
}

public OnPluginEnd() {
    Premium_UnRegisterEffect("robotmode");
}

public OnClientConnected(client) {
    g_bRobotEnabled[client] = false;
}

public EnableEffect(client) {
    g_bRobotEnabled[client] = true;
    SetRobotModel(client);
}

public DisableEffect(client) {
    g_bRobotEnabled[client] = false;
    SetRobotModel(client);
}

public OnEventShutdown()
{
	UnhookEvent("player_spawn", OnPlayerSpawned);
	UnhookEvent("player_class", OnPlayerSpawned);
}

public OnMapStart()
{
	new String:classname[10], String:Mdl[PLATFORM_MAX_PATH];
	for (new TFClassType:i = TFClass_Scout; i <= TFClass_Engineer; i++)
	{
		TF2_GetNameOfClass(i, classname, sizeof(classname));
		Format(Mdl, sizeof(Mdl), "models/bots/%s/bot_%s.mdl", Mdl, Mdl);
		PrecacheModel(Mdl, true);
	}
}

public SetRobotModel(client)
{
	if(IsValidClient(client) && IsPlayerAlive(client)) {
		if(g_bRobotEnabled[client]) {
			new String:classname[10];
			new String:Mdl[PLATFORM_MAX_PATH];
			TF2_GetNameOfClass(TF2_GetPlayerClass(client), classname, sizeof(classname));
			Format(Mdl, sizeof(Mdl), "models/bots/%s/bot_%s.mdl", classname, classname);
			ReplaceString(Mdl, sizeof(Mdl), "demoman", "demo", false);
			SetVariantString(Mdl);
			AcceptEntityInput(client, "SetCustomModel");
			SetEntProp(client, Prop_Send, "m_bUseClassAnimations", 1);
		} else {
			SetVariantString("");
			AcceptEntityInput(client, "SetCustomModel");
		}
	}
}

public Action:OnPlayerSpawned(Handle:event, const String:name[], bool:dontBroadcast)
{
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    if(IsValidClient(client) && g_bRobotEnabled[client])
		CreateTimer(0.2, SetRobotOnSpawn, GetEventInt(event, "userid"));
}

public Action:SetRobotOnSpawn(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	if(client != 0)
		SetRobotModel(client);
}

public Action:OnPlayerTaunt(client, const String:command[], args)
{
	if(g_bRobotEnabled[client])
	{
		new TFClassType:class = TF2_GetPlayerClass(client);
		if(class == TFClass_Engineer)
		{
			return Plugin_Continue;
		} else {
			PrintToChat(client, "[Premium] Taunts are currently disabled while a robot (except for engineer).");
			return Plugin_Handled;
		}
	}
	return Plugin_Continue;
}

public Action:SoundHook(clients[64], &numClients, String:sound[PLATFORM_MAX_PATH], &Ent, &channel, &Float:volume, &level, &pitch, &flags)
{
	if(volume == 0.0 || volume == 0.9997)
		return Plugin_Continue;

	if(!IsValidClient(Ent))
		return Plugin_Continue;

	new client = Ent;
	new TFClassType:class = TF2_GetPlayerClass(client);

	if(g_bRobotEnabled[client] && !g_bIsStealth[client])
	{
		if(StrContains(sound, "vo/", false) == -1) 
			return Plugin_Continue;
		if(StrContains(sound, "announcer", false) != -1)
			return Plugin_Continue;
		if(volume == 0.99997)
			return Plugin_Continue;

		ReplaceString(sound, sizeof(sound), "vo/", "vo/mvm/norm/", false);
		ReplaceString(sound, sizeof(sound), ".wav", ".mp3", false);
		new String:classname[10], String:classname_mvm[15];
		TF2_GetNameOfClass(class, classname, sizeof(classname));
		Format(classname_mvm, sizeof(classname_mvm), "%s_mvm", classname);
		ReplaceString(sound, sizeof(sound), classname, classname_mvm, false);
		new String:soundchk[PLATFORM_MAX_PATH];
		Format(soundchk, sizeof(soundchk), "sound/%s", sound);
		if(!FileExists(soundchk, true))
			return Plugin_Continue;
		PrecacheSound(sound);
		return Plugin_Changed;
	}

	return Plugin_Continue;
}

public OnGameFrame()
{
	new maxclients = GetMaxClients();
	for(new i = 1; i < maxclients; i++)
	{
		if(IsValidClient(i) && g_bRobotEnabled[i])
		{
			if(TF2_IsPlayerInCondition(i, TFCond_Cloaked) || TF2_IsPlayerInCondition(i, TFCond_Disguised))
			{
				if(g_bIsStealth[i] == false)
				{
					g_bIsStealth[i] = true;
					OnCloak(i);
				}
			} else {
				if(g_bIsStealth[i] == true)
				{
					g_bIsStealth[i] = false;
					OnUnCloak(i);
				}
			}
		}
	}
}

OnCloak(client)
{
	SetVariantString("");
	AcceptEntityInput(client, "SetCustomModel");
}

OnUnCloak(client)
{
	SetRobotModel(client);
}

stock TF2_GetNameOfClass(TFClassType:class, String:name[], maxlen)
{
	switch(class)
	{
		case TFClass_Scout: Format(name, maxlen, "scout");
		case TFClass_Soldier: Format(name, maxlen, "soldier");
		case TFClass_Pyro: Format(name, maxlen, "pyro");
		case TFClass_DemoMan: Format(name, maxlen, "demoman");
		case TFClass_Heavy: Format(name, maxlen, "heavy");
		case TFClass_Engineer: Format(name, maxlen, "engineer");
		case TFClass_Medic: Format(name, maxlen, "medic");
		case TFClass_Sniper: Format(name, maxlen, "sniper");
		case TFClass_Spy: Format(name, maxlen, "spy");
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