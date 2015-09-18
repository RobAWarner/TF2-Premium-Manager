/* TODO: 
    Cosmetics appear on death?
    Set robot on spawn not instantly?
    Demoman feet disappear when sticky jumping?
 */
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>
#undef REQUIRE_PLUGIN
#include <premium_manager>

#define PLUGIN_EFFECT "robot"

new bool:g_bIsStealth[MAXPLAYERS+1];
new bool:g_bIsEnabled[MAXPLAYERS+1];
new bool:g_bDemoNotice[MAXPLAYERS+1];

public Plugin:myinfo = {
    name = "Premium -> Robot [TF2]",
    author = "Monster Killer",
    description = "Allows Robots",
    version = "1.3",
    url = "http://monsterprojects.org"
};


public OnPluginStart() {
    HookEvent("player_spawn", Event_PlayerSpawn);
    HookEvent("player_class", Event_PlayerSpawn);
    
    AddCommandListener(Listener_PlayerTaunt, "taunt");
    AddCommandListener(Listener_PlayerTaunt, "+taunt");

    AddNormalSoundHook(Hook_SoundHook);
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
    Premium_RegEffect(PLUGIN_EFFECT, "Robot Mode", Callback_EnableEffect, Callback_DisableEffect, true);
    Premium_AddEffectCooldown(PLUGIN_EFFECT, 5, PREMIUM_COOLDOWN_ENABLE);
}

public OnPluginEnd() {
    if(LibraryExists("premium_manager"))
        Premium_UnRegEffect(PLUGIN_EFFECT);
    
    RemoveNormalSoundHook(Hook_SoundHook);
}

public OnClientConnected(client) {
    g_bIsEnabled[client] = false;
    g_bDemoNotice[client] = false;
}

public Callback_EnableEffect(client) {
    g_bIsEnabled[client] = true;
    SetRobotModel(client);
}

public Callback_DisableEffect(client) {
    g_bIsEnabled[client] = false;
    SetRobotModel(client);
}

public OnEventShutdown() {
    UnhookEvent("player_spawn", Event_PlayerSpawn);
    UnhookEvent("player_class", Event_PlayerSpawn);
}

public OnMapStart() {
    new String:sClassName[10], String:sModel[PLATFORM_MAX_PATH];
    for(new TFClassType:i = TFClass_Scout; i <= TFClass_Engineer; i++) {
        TF2_GetNameOfClass(i, sClassName, sizeof(sClassName));
        Format(sModel, sizeof(sModel), "models/bots/%s/bot_%s.mdl", sModel, sModel);
        PrecacheModel(sModel, true);
    }
}

SetRobotModel(client) {
    if(Premium_IsClientPremium(client) && IsPlayerAlive(client)) {
        if(g_bIsEnabled[client]) {
            EnableRobot(client);
        } else {
            DisableRobot(client);
        }
    }
}

public Action:Event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast) {
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    if(Premium_IsClientPremium(client) && g_bIsEnabled[client])
        CreateTimer(0.2, Timer_SetRobotOnSpawn, GetEventInt(event, "userid"));
}

public Action:Timer_SetRobotOnSpawn(Handle:timer, any:userid) {
    new client = GetClientOfUserId(userid);
    if(client != 0 && Premium_IsClientPremium(client) && IsPlayerAlive(client)) {
        SetRobotModel(client);
    }
}

public Action:Listener_PlayerTaunt(client, const String:command[], args) {
    if(g_bIsEnabled[client]) {
        new TFClassType:playerClass = TF2_GetPlayerClass(client);
        if(playerClass == TFClass_Engineer) {
            return Plugin_Continue;
        } else {
            PrintToChat(client, "%s \x07FE4444Taunts are disabled when in robot mode (except for engineer).\x01", PREMIUM_PREFIX);
            return Plugin_Handled;
        }
    }
    return Plugin_Continue;
}

public Action:Hook_SoundHook(clients[64], &numClients, String:sound[PLATFORM_MAX_PATH], &Ent, &channel, &Float:volume, &level, &pitch, &flags) {
    if(volume == 0.0 || volume == 0.9997)
        return Plugin_Continue;

    if(!Premium_IsClientPremium(Ent))
        return Plugin_Continue;

    new client = Ent;
    new TFClassType:playerClass = TF2_GetPlayerClass(client);

    if(playerClass != TFClass_DemoMan && g_bIsEnabled[client] && !g_bIsStealth[client]) {
        if(StrContains(sound, "vo/", false) == -1) 
            return Plugin_Continue;
        if(StrContains(sound, "announcer", false) != -1)
            return Plugin_Continue;
        if(volume == 0.99997)
            return Plugin_Continue;

        ReplaceString(sound, sizeof(sound), "vo/", "vo/mvm/norm/", false);
        ReplaceString(sound, sizeof(sound), ".wav", ".mp3", false);

        new String:sClassName[10], String:sClassNameMVM[15];
        TF2_GetNameOfClass(playerClass, sClassName, sizeof(sClassName));
        Format(sClassNameMVM, sizeof(sClassNameMVM), "%s_mvm", sClassName);
        ReplaceString(sound, sizeof(sound), sClassName, sClassNameMVM, false);

        new String:sSoundCheck[PLATFORM_MAX_PATH];
        Format(sSoundCheck, sizeof(sSoundCheck), "sound/%s", sound);
        if(!FileExists(sSoundCheck, true))
            return Plugin_Continue;

        PrecacheSound(sound);
        return Plugin_Changed;
    }
    return Plugin_Continue;
}

EnableRobot(client) {
    if(TF2_GetPlayerClass(client) == TFClass_DemoMan) {
        if(!g_bDemoNotice[client]) {
            PrintToChat(client, "%s \x07FE4444Due to an issue with the model, you cannot be a robot Demoman. Sorry :(\x01", PREMIUM_PREFIX);
            g_bDemoNotice[client] = true;
        }
        return;
    }
    decl String:sClassName[10], String:sModel[PLATFORM_MAX_PATH];
    TF2_GetNameOfClass(TF2_GetPlayerClass(client), sClassName, sizeof(sClassName));
    Format(sModel, sizeof(sModel), "models/bots/%s/bot_%s.mdl", sClassName, sClassName);
    ReplaceString(sModel, sizeof(sModel), "demoman", "demo", false);
    SetVariantString(sModel);
    AcceptEntityInput(client, "SetCustomModel");
    SetEntProp(client, Prop_Send, "m_bUseClassAnimations", 1);
    
    RemoveWearables(client);
}

DisableRobot(client) {
    SetVariantString("");
    AcceptEntityInput(client, "SetCustomModel");
}

public OnGameFrame() {
    new maxclients = GetMaxClients();
    for(new i = 1; i < maxclients; i++) {
        if(IsClientInGame(i) && IsPlayerAlive(i) && g_bIsEnabled[i]) {
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

OnPlayerCloak(client) {
    DisableRobot(client);
}

OnPlayerUnCloak(client) {
    SetRobotModel(client);
}

RemoveWearables(client) {
    /* Items come back on resupply?! */
    new maxclients = GetMaxClients();
    for(new i = maxclients + 1; i <= 2048; i++) {
        if(!IsValidEntity(i))
            continue;

        decl String:sClassName[35], String:sModel[256];
        GetEntityClassname(i, sClassName, sizeof(sClassName));
        GetEntPropString(i, Prop_Data, "m_ModelName", sModel, sizeof(sModel));

        if(!StrEqual(sClassName, "tf_wearable") && !StrEqual(sClassName, "tf_powerup_bottle"))
            continue;
        if(StrContains(sModel, "croc_shield") != -1 || StrContains(sModel, "c_rocketboots_soldier") != -1 || StrContains(sModel, "knife_shield") != -1 || StrContains(sModel, "c_paratrooper_pack") != -1)
            continue;

        if(client != GetEntPropEnt(i, Prop_Send, "m_hOwnerEntity"))
            continue;

        SDKHook(i, SDKHook_SetTransmit, cbTransmit);
    }
}

public OnEntityCreated(entity, const String:sClassname[]) {
    if(StrEqual(sClassname, "tf_wearable")) {
        CreateTimer(0.1, Timer_EntityHook, entity);
    }
}

public Action:Timer_EntityHook(Handle:Timer, any:entity) {
    if(IsValidEdict(entity)) {
        new owner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
        if(!Premium_IsClientPremium(owner) || !g_bIsEnabled[owner])
            return;

        decl String:sModel[256];
        GetEntPropString(entity, Prop_Data, "m_ModelName", sModel, sizeof(sModel));

        if(StrContains(sModel, "croc_shield") != -1 || StrContains(sModel, "c_rocketboots_soldier") != -1 || StrContains(sModel, "knife_shield") != -1 || StrContains(sModel, "c_paratrooper_pack") != -1)
            return;

        SDKHook(entity, SDKHook_SetTransmit, cbTransmit);
    }
}

public Action:cbTransmit(Entity, Client) {
    if(Premium_IsClientPremium(Client) && g_bIsEnabled[Client]) {
        return Plugin_Handled;
    }
    return Plugin_Continue;
}

stock TF2_GetNameOfClass(TFClassType:class, String:name[], maxlen) {
    switch(class) {
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