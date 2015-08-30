#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#undef REQUIRE_PLUGIN
#include <premium_manager>

new g_clrRender;
new bool:g_bIsEnabled[MAXPLAYERS+1];

public Plugin:myinfo = {
	name = "Premium -> Funny Gibs",
	author = "Monster Killer",
	description = "Gibs of players you kill will instead be ducks.",
	version = "1.1",
	url = "http://monsterprojects.org"
};

public OnPluginStart() {
	g_clrRender = FindSendPropOffs("CBaseEntity", "m_clrRender");
	if(g_clrRender == -1)
		SetFailState("Could not find \"m_clrRender\"");

	HookEvent("player_death", OnPlayerDeath);

	SetConVarBool(FindConVar("tf_playergib"), false);
}

public OnAllPluginsLoaded() {
    Premium_RegisterEffect("fungibs", "Duck Gibs", EnableEffect, DisableEffect, true);
}

public OnPluginEnd() {
    Premium_UnRegisterEffect("fungibs");
}

public OnClientConnected(client) {
    g_bIsEnabled[client] = false;
}

public EnableEffect(client) {
    g_bIsEnabled[client] = true;
}

public DisableEffect(client) {
    g_bIsEnabled[client] = false;
}

public OnEventShutdown() {
	UnhookEvent("player_death", OnPlayerDeath);
}

public OnMapStart() {
	PrecacheModel("models/player/gibs/gibs_duck.mdl", true);
}

public Action:OnPlayerDeath(Handle:event, const String:name[], bool:dontBroadcast) {
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	
	if(g_bIsEnabled[attacker] == true || g_bIsEnabled[client] == true) {
		new String:weaponName[32];
		GetEventString(event, "weapon", weaponName, sizeof(weaponName));
		if(((StrContains(weaponName, "sentrygun", false) > -1) && IsLvl3Sentry(attacker)) ||
			(StrContains(weaponName, "pipe", false) > -1) ||
			(StrContains(weaponName, "rocket", false) > -1) ||
			(StrContains(weaponName, "deflect", false) > -1))
		{
			CreateTimer(0.1, DeleteRagdoll, client);
			ReplaceGibs(client, attacker, 10);
		}
	}

	return Plugin_Continue;
}

public Action:DeleteRagdoll(Handle:Timer, any:client) {
	new ragdoll = GetEntPropEnt(client, Prop_Send, "m_hRagdoll");
	if (ragdoll>0) {
		SetEntPropEnt(client, Prop_Send, "m_hRagdoll", -1);
		RemoveEdict(ragdoll);	
	}
}

public IsLvl3Sentry(any:client) {
	new entity = -1;
	while((entity = FindEntityByClassname(entity, "obj_sentrygun")) != -1) {
		if(GetEntDataEnt2(entity, FindSendPropInfo("CBaseObject", "m_hBuilder")) == client) {
			return (GetEntProp(entity, Prop_Send, "m_iUpgradeLevel") == 3);
        }
    }
	return false;
}

stock Action:ReplaceGibs(any:client, any:attacker, count = 1) {
	if(!IsValidEntity(client)) {
		return;
	}

	decl Float:pos[3];
	GetClientAbsOrigin(client, pos);
  
	for(new i = 0; i < count; i++) {
		new gib = CreateEntityByName("prop_physics");
		decl CollisionOffset;
		DispatchKeyValue(gib, "model", "models/player/gibs/gibs_duck.mdl");
		if(DispatchSpawn(gib)) {
			CollisionOffset = GetEntSendPropOffs(gib, "m_CollisionGroup");
			if(IsValidEntity(gib)) SetEntData(gib, CollisionOffset, 1, 1, true);
			new Float:vec[3];
			vec[0] = GetRandomFloat(-300.0, 300.0);
			vec[1] = GetRandomFloat(-300.0, 300.0);
			vec[2] = GetRandomFloat(100.0, 300.0);
			TeleportEntity(gib, pos, NULL_VECTOR, vec);
			CreateTimer(15.0, DeleteOldGib, gib);
		}
	}
}

public Action:DeleteOldGib(Handle:Timer, any:ent) {
	if(IsValidEntity(ent)) {
		CreateTimer(0.1, FadeGibOut, ent, TIMER_REPEAT);
		SetEntityRenderMode(ent, RENDER_TRANSCOLOR);
	}
}

public Action:FadeGibOut(Handle:Timer, any:ent) {
	if(!IsValidEntity(ent)) {
		KillTimer(Timer);
		return;
	}

	new alpha = GetEntData(ent, g_clrRender + 3, 1);
	if(alpha - 25 <= 0) {
		RemoveEdict(ent);
		KillTimer(Timer);
	} else {
		SetEntData(ent, g_clrRender + 3, alpha - 25, 1, true);
	}
}  