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

    //SetConVarBool(FindConVar("tf_playergib"), false);
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
    Premium_RegEffect("fungibs", "Duck Gibs", EnableEffect, DisableEffect, true);
}

public OnPluginEnd() {
    Premium_UnRegEffect("fungibs");
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
    
    new String:sWeapon[32];
    GetEventString(event, "weapon", sWeapon, sizeof(sWeapon));
    
    if(g_bIsEnabled[attacker] == true || g_bIsEnabled[client] == true) {
        new customKill = GetEventInt(event, "customkill");
        if(ShouldGib(sWeapon, customKill, attacker)) {
            CreateTimer(0.1, DeleteRagdoll, client);
            AddGibs(client, 10);
        }
    }

    return Plugin_Continue;
}

public Action:DeleteRagdoll(Handle:Timer, any:client) {
    new ragdoll = GetEntPropEnt(client, Prop_Send, "m_hRagdoll");
    if (ragdoll > 0) {
        SetEntPropEnt(client, Prop_Send, "m_hRagdoll", -1);
        RemoveEdict(ragdoll);    
    }
}

public ShouldGib(String:sWeapon[], any:customKill, any:attacker) {
    if(StrContains(sWeapon, "pipe", false) > -1)
        return true;
    if(StrContains(sWeapon, "rocket", false) > -1)
        return true;
    if(StrContains(sWeapon, "deflect", false) > -1)
        return true;
    if(((StrContains(sWeapon, "sentrygun", false) > -1) || (StrContains(weaponName, "wrangler", false) > -1)) && IsLvl3Sentry(attacker))
        return true;
    if(customKill == 1) // Headshot
        return true;
    if(customKill == 2) // Backstab
        return true;
    
    return false;
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

public AddGibs(any:client, count = 1) {
    if(!IsValidEntity(client)) {
        return;
    }

    decl Float:pos[3];
    GetClientAbsOrigin(client, pos);
  
    for(new i = 0; i < count; i++) {
        new gib = CreateEntityByName("prop_physics_override");
        
        decl CollisionOffset;
        DispatchKeyValue(gib, "model", "models/player/gibs/gibs_duck.mdl");

        if(DispatchSpawn(gib)) {
            if(IsValidEntity(gib)) {
                CollisionOffset = GetEntSendPropOffs(gib, "m_CollisionGroup");
                SetEntData(gib, CollisionOffset, 1, 1, true);
                
                new Float:fVel[3];
                fVel[0] = GetRandomFloat(-250.0, 250.0);
                fVel[1] = GetRandomFloat(-250.0, 250.0);
                fVel[2] = GetRandomFloat(100.0, 250.0);
                TeleportEntity(gib, pos, NULL_VECTOR, fVel);
                CreateTimer(15.0, Timer_DeleteOldGib, gib);
            }
        }
    }
}

public Action:Timer_DeleteOldGib(Handle:Timer, any:ent) {
    if(IsValidEntity(ent)) {
        CreateTimer(0.1, Timer_FadeGibOut, ent, TIMER_REPEAT);
        SetEntityRenderMode(ent, RENDER_TRANSCOLOR);
    }
}

public Action:Timer_FadeGibOut(Handle:Timer, any:ent) {
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