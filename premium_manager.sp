/* TODO: 
    Player should be alive? Print fail?
    Cooldown
    validate effect name against plugin
    print enabled/disabled
    errors
    translations
    more validation on items?
    track status here rather than in plugins?
    pre-build menus?
    Function/callback for invisible and disguised
*/
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <clientprefs>
#include <premium_manager>

#define PREMIUM_VERSION "0.1.0"

new Handle:g_hEffects = INVALID_HANDLE;
new Handle:g_hEffectNames = INVALID_HANDLE;
new Handle:g_hPremiumMenu = INVALID_HANDLE;

new bool:g_bIsPremium[MAXPLAYERS+1];
new bool:g_bClientCookiesCached[MAXPLAYERS+1];

enum g_ePremiumEffect {
    Handle:enableCallback,
    Handle:disableCallback,
    Handle:clientCookie,
    String:name[64],
    String:displayName[64],
    bool:menuItem,
    Handle:pluginHandle
}

public Plugin:myinfo = {
    name = "Premium Manager",
    author = "Monster Killer",
    description = "A simple plugin to manage premium/fun effects",
    version = PREMIUM_VERSION,
    url = "http://MonsterProjects.org"
};

public OnPluginStart() {
    g_hEffects = CreateTrie();
    g_hEffectNames = CreateArray(64);

    RegAdminCmd("sm_premium", Command_Premium, ADMFLAG_CUSTOM1, "sm_premium - Open premium menu");
}

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max) {
    RegPluginLibrary("premium_manager");

    CreateNative("Premium_RegisterEffect", Native_RegisterPremiumEffect);
    CreateNative("Premium_UnRegisterEffect", Native_UnRegisterPremiumEffect);
    CreateNative("Premium_IsClientPremium", Native_IsClientPremium);
    CreateNative("Premium_ShowMenu", Native_ShowPremiumMenu);
    CreateNative("Premium_IsEffectEnabled", Native_IsEffectEnabled);
    CreateNative("Premium_SetEffectState", Native_SetPremiumEffectState);
    CreateNative("Premium_AddConfigOption", Native_AddPremiumEffectConfigMenu);

    return APLRes_Success;
}

public OnClientConnected(client) {
    g_bClientCookiesCached[client] = false;
}

public OnClientCookiesCached(client) {
    if(!IsClientSourceTV(client) && !IsClientReplay(client) && !IsFakeClient(client)) {
        g_bClientCookiesCached[client] = true;
        for(new i = 0; i < GetArraySize(g_hEffectNames); i++) {
            decl String:sEffectName[64], Effect[g_ePremiumEffect];
            GetArrayString(g_hEffectNames, i, sEffectName, sizeof(sEffectName));
            GetTrieArray(g_hEffects, sEffectName, Effect, sizeof(Effect));
            if(Effect[clientCookie] != INVALID_HANDLE) {
                decl String:sCookie[6];
                GetClientCookie(client, Effect[clientCookie], sCookie, sizeof(sCookie));
                if(StrEqual(sCookie, "on")) {
                    if(Effect[enableCallback] != INVALID_HANDLE) {
                        Call_StartForward(Effect[enableCallback]);
                        Call_PushCell(client);
                        Call_Finish();
                    }
                }
            }
        }
    }
}

public OnClientPostAdminCheck(client) {
    new AdminId:iId = GetUserAdmin(client);
    if(iId != INVALID_ADMIN_ID) {
        new iFlags = GetAdminFlags(iId, Access_Effective);
        if(iFlags & ADMFLAG_CUSTOM1 || iFlags & ADMFLAG_ROOT)
        {
            g_bIsPremium[client] = true;
            return;
        }
    }
    g_bIsPremium[client] = false;
}

public OnClientDisconnect(client) {
    g_bIsPremium[client] = false;
}

/**********************
|  Command Callbacks  |
**********************/

public Action:Command_Premium(client, args) {
    ShowPremiumMenu(client);
}

public Action:Command_GenericPremium(client, args) {
    decl String:sCommand[70], String:sEffectName[70];
    GetCmdArg(0, sCommand, sizeof(sCommand));
    
    strcopy(sEffectName, sizeof(sEffectName), sCommand[3]);
    
    TriggerEffect(client, sEffectName);

    return Plugin_Handled;
}


/*********************
|  Native Functions  |
*********************/

public Native_RegisterPremiumEffect(Handle:plugin, numParams) {
    // Effect name (Used for cookie, command etc)
    decl String:sEffectName[64];
    GetNativeString(1, sEffectName, sizeof(sEffectName));

    // Effect display name (Displayed to players)
    decl String:sEffectDisplayName[64];
    GetNativeString(2, sEffectDisplayName, sizeof(sEffectDisplayName));

    decl Effect[g_ePremiumEffect];
    strcopy(Effect[name], sizeof(Effect[name]), sEffectName);
    strcopy(Effect[displayName], sizeof(Effect[displayName]), sEffectDisplayName);

    // Function called to activate effect (By player toggle or connect)
    new Handle:hForwardEnable = CreateForward(ET_Event, Param_Cell);
    AddToForward(hForwardEnable, plugin, GetNativeCell(3));
    Effect[enableCallback] = hForwardEnable;

    // Function called to end effect (By player toggle or disconnect)
    new Handle:hForwardDisable = CreateForward(ET_Event, Param_Cell);
    AddToForward(hForwardDisable, plugin, GetNativeCell(4));
    Effect[disableCallback] = hForwardDisable;
    
    // Client Cookie
    decl String:sCookieName[72] = "premium_";
    StrCat(sCookieName, sizeof(sCookieName), sEffectName);
    new Handle:hCookie = RegClientCookie(sCookieName, sEffectDisplayName, CookieAccess_Public);
    Effect[clientCookie] = hCookie;

    // Add a menu item?
    Effect[menuItem] = GetNativeCell(5);

    Effect[pluginHandle] = plugin;

    SetTrieArray(g_hEffects, sEffectName, Effect, sizeof(Effect));
    PushArrayString(g_hEffectNames, sEffectName);

    // Register command
    decl String:sCommand[67] = "sm_", String:sCommandDescription[128];
    StrCat(sCommand, sizeof(sCommand), sEffectName);
    Format(sCommandDescription, sizeof(sCommandDescription), "%s - Toggle %s on/off", sCommand, sEffectDisplayName);
    RegAdminCmd(sCommand, Command_GenericPremium, ADMFLAG_CUSTOM1, sCommandDescription);
}

public Native_UnRegisterPremiumEffect(Handle:plugin, numParams) {
    /* IMPORTANT! This looks at plugin and not effect name, it should do both! */
    for(new i = 0; i < GetArraySize(g_hEffectNames); i++) {
        decl String:sEffectName[64], Effect[g_ePremiumEffect];
        GetArrayString(g_hEffectNames, i, sEffectName, sizeof(sEffectName));
        GetTrieArray(g_hEffects, sEffectName, Effect, sizeof(Effect));
        if(Effect[pluginHandle] == plugin) {
            RemoveFromArray(g_hEffectNames, i);
            RemoveFromTrie(g_hEffects, sEffectName);
            // Perform disable callback?
        }
    }
}

public Native_ShowPremiumMenu(Handle:plugin, numParams) {
    new client = GetNativeCell(1);

    if(!IsValidClient(client) || !IsClientPremium(client))
        return false;

    ShowPremiumMenu(client);
    return true;
}

public Native_IsClientPremium(Handle:plugin, numParams) {
    new client = GetNativeCell(1);

    if(!IsValidClient(client))
        return false;

    return IsClientPremium(client);
}

public Native_AddPremiumEffectConfigMenu(Handle:plugin, numParams) {
    
}

public Native_IsEffectEnabled(Handle:plugin, numParams) {
    decl String:sEffectName[64], Effect[g_ePremiumEffect];
    new client = GetNativeCell(1);
    GetNativeString(2, sEffectName, sizeof(sEffectName));

    if(!GetTrieArray(g_hEffects, sEffectName, Effect, sizeof(Effect))) {
        return false;
    }

    if(Effect[clientCookie] != INVALID_HANDLE) {
        decl String:sCookie[6];
        GetClientCookie(client, Effect[clientCookie], sCookie, sizeof(sCookie));
        if(StrEqual(sCookie, "on")) {
            return true;
        } else {
            return false;
        }
    }
    return false;
}

public Native_SetPremiumEffectState(Handle:plugin, numParams) {
    decl String:sEffectName[64], Effect[g_ePremiumEffect];
    new client = GetNativeCell(1);
    GetNativeString(2, sEffectName, sizeof(sEffectName));
    
    new iState = GetNativeCell(3);

    if(!GetTrieArray(g_hEffects, sEffectName, Effect, sizeof(Effect))) {
        return false;
    }

    if(Effect[clientCookie] != INVALID_HANDLE) {
        decl String:sCookie[6];
        GetClientCookie(client, Effect[clientCookie], sCookie, sizeof(sCookie));
        if(iState == 1) {
            SetClientCookie(client, Effect[clientCookie], "on");
        } else {
            SetClientCookie(client, Effect[clientCookie], "off");
        }
    }
    return true;
}

/********************
|  Other Functions  |
********************/

public bool:IsClientPremium(client) {
    if(g_bIsPremium[client])
        return true;

    return false;
}

public bool:IsValidClient(client) {
    if(client <= 0 || client > MaxClients)
        return false;

    if(!IsClientInGame(client))
        return false;

    if(IsClientSourceTV(client) || IsClientReplay(client) || IsFakeClient(client))
        return false;

    return true;
}

public bool:TriggerEffect(client, String:sEffectName[]) {
    if(!IsValidClient(client)) {
        return false;
    }

    decl Effect[g_ePremiumEffect];
    if(!GetTrieArray(g_hEffects, sEffectName, Effect, sizeof(Effect))) {
        return false;
    }

    if(Effect[clientCookie] != INVALID_HANDLE) {
        decl String:sCookie[6];
        GetClientCookie(client, Effect[clientCookie], sCookie, sizeof(sCookie));
        if(StrEqual(sCookie, "on")) {
            SetClientCookie(client, Effect[clientCookie], "off");
            if(Effect[disableCallback] != INVALID_HANDLE) {
                Call_StartForward(Effect[disableCallback]);
                Call_PushCell(client);
                Call_Finish();
                PrintToChat(client, "%s %s Disabled!", PREMIUM_PREFIX, Effect[displayName]);
                return true;
            }
        } else {
            SetClientCookie(client, Effect[clientCookie], "on");
            if(Effect[enableCallback] != INVALID_HANDLE) {
                Call_StartForward(Effect[enableCallback]);
                Call_PushCell(client);
                Call_Finish();
                PrintToChat(client, "%s %s Enabled!", PREMIUM_PREFIX, Effect[displayName]);
                return true;
            }
        }
    }
    return false;
}

/*******************
|  Menu Functions  |
*******************/

public ShowPremiumMenu(client) {
    new Handle:hMenu = CreateMenu(MenuHandler_PremiumTop);
    SetMenuTitle(hMenu, "Premium Effects");
    
    for (new i = 0; i < GetArraySize(g_hEffectNames); i++) {
        decl String:sEffectName[64], Effect[g_ePremiumEffect];
        GetArrayString(g_hEffectNames, i, sEffectName, sizeof(sEffectName));
        GetTrieArray(g_hEffects, sEffectName, Effect, sizeof(Effect));
        if(Effect[menuItem]) {
            AddMenuItem(hMenu, sEffectName, Effect[displayName]);
        }
    }

    DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
}

public MenuHandler_PremiumTop(Handle:menu, MenuAction:action, param1, param2) {
    if(action == MenuAction_End) {
        CloseHandle(menu);
    } else if(action == MenuAction_Select) {
        /* TODO: is valid item? */
        decl String:sEffectName[64], String:sMenuItem[73];
        GetMenuItem(menu, param2, sEffectName, sizeof(sEffectName));

        decl Effect[g_ePremiumEffect];
        GetTrieArray(g_hEffects, sEffectName, Effect, sizeof(Effect));

        new Handle:hMenu = CreateMenu(MenuHandler_PremiumEffect);
        SetMenuTitle(hMenu, "Premium / %s", Effect[displayName]);

        Format(sMenuItem, sizeof(sMenuItem), "Turn %s ", Effect[displayName]);
        if(Premium_IsEffectEnabled(param1, sEffectName)) {
            StrCat(sMenuItem, sizeof(sMenuItem), "Off");
        } else {
            StrCat(sMenuItem, sizeof(sMenuItem), "On");
        }
        AddMenuItem(hMenu, sEffectName, sMenuItem);

        SetMenuExitBackButton(hMenu, true);
        DisplayMenu(hMenu, param1, MENU_TIME_FOREVER);
    }
}

public MenuHandler_PremiumEffect(Handle:menu, MenuAction:action, param1, param2) {
    if(action == MenuAction_End) {
        CloseHandle(menu);
    } else if(action == MenuAction_Select) {
        /* TODO: is valid item? */
        decl String:sEffectName[64];
        GetMenuItem(menu, param2, sEffectName, sizeof(sEffectName));

        TriggerEffect(param1, sEffectName);
    } else if(action == MenuAction_Cancel && param2 == MenuCancel_ExitBack) {
        ShowPremiumMenu(param1);
    }
}