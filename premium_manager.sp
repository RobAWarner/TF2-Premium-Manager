/* TODO: 
    Player should be alive? Print fail?
    Cooldown
    errors
    translations
    track status here rather than in plugins?
    Function/callback for invisible and disguised?
    Pass userid not client?
    Disable client effects if lose premium on reloadadmins?
    Run all disablecallback's on unload?
    When togglable effect is registered, look for clients that it should fire enable callback?
    Allow command access for anyone but show message to non-premium members?
*/
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <clientprefs>
#include <premium_manager>

#define PREMIUM_ACTION_TRIGGER 1
#define PREMIUM_ACTION_CALLBACK 2

#define PREMIUM_VERSION "0.1.0"

new Handle:g_hEffects = INVALID_HANDLE;
new Handle:g_hEffectNames = INVALID_HANDLE;
new Handle:g_hPremiumMenu = INVALID_HANDLE;
new Handle:g_hPremiumMenuEffectItems = INVALID_HANDLE;
new Handle:g_hPremiumMenuEffectOptions = INVALID_HANDLE;

new bool:g_bIsPremium[MAXPLAYERS+1];
new bool:g_bClientAuthorised[MAXPLAYERS+1];

enum g_ePremiumEffect {
    Handle:enableCallback,
    Handle:disableCallback,
    Handle:clientCookie,
    String:name[64],
    String:displayName[64],
    bool:menuItem,
    bool:togglable,
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
    g_hPremiumMenuEffectItems = CreateArray(64);
    g_hPremiumMenuEffectOptions = CreateArray(64);

    g_hPremiumMenu = CreateMenu(MenuHandler_PremiumTop);
    SetMenuTitle(g_hPremiumMenu, "Premium Effects");

    RegAdminCmd("sm_premium", Command_Premium, ADMFLAG_CUSTOM1, "sm_premium - Open premium menu");
    
    new maxclients = GetMaxClients();
    for(new i = 1; i < maxclients; i++)
    {
        if(IsValidClient(i) && !g_bClientAuthorised[i])
        {
            UpdateClientPremiumStatus(i);
        }
    }
}

public OnPluginEnd() {
    /* Run diable callbacks */
}

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max) {
    RegPluginLibrary("premium_manager");

    CreateNative("Premium_RegEffect", Native_RegEffect);
    CreateNative("Premium_RegBasicEffect", Native_RegBasicEffect);
    CreateNative("Premium_UnRegEffect", Native_UnRegEffect);
    CreateNative("Premium_IsClientPremium", Native_IsClientPremium);
    CreateNative("Premium_ShowMenu", Native_ShowMenu);
    CreateNative("Premium_IsEffectEnabled", Native_IsEffectEnabled);
    CreateNative("Premium_SetEffectState", Native_SetEffectState);
    CreateNative("Premium_AddMenuOption", Native_AddMenuOption);

    return APLRes_Success;
}

public OnClientConnected(client) {
    g_bIsPremium[client] = false;
    g_bClientAuthorised[client] = false;
}

public OnClientCookiesCached(client) {
    if(!IsClientSourceTV(client) && !IsClientReplay(client) && !IsFakeClient(client)) {
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
    UpdateClientPremiumStatus(client);
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

public Native_RegEffect(Handle:plugin, numParams) {
    // Effect name (Used for cookie, command etc)
    decl String:sEffectName[64];
    GetNativeString(1, sEffectName, sizeof(sEffectName));
    
    // Is it already registered?
    if(FindStringInArray(g_hEffectNames, sEffectName) != -1) {
        return false;
    }

    // Effect display name (Displayed to players)
    decl String:sEffectDisplayName[64];
    GetNativeString(2, sEffectDisplayName, sizeof(sEffectDisplayName));

    decl Effect[g_ePremiumEffect];
    strcopy(Effect[name], sizeof(Effect[name]), sEffectName);
    strcopy(Effect[displayName], sizeof(Effect[displayName]), sEffectDisplayName);

    // Function called to activate effect (By player toggle or connect)
    new Handle:hForwardEnable = CreateForward(ET_Event, Param_Cell);
    AddToForward(hForwardEnable, plugin, Function:GetNativeCell(3));
    Effect[enableCallback] = hForwardEnable;

    // Function called to end effect (By player toggle or disconnect)
    new Handle:hForwardDisable = CreateForward(ET_Event, Param_Cell);
    AddToForward(hForwardDisable, plugin, Function:GetNativeCell(4));
    Effect[disableCallback] = hForwardDisable;
    
    // Client Cookie
    decl String:sCookieName[72] = "premium_";
    StrCat(sCookieName, sizeof(sCookieName), sEffectName);
    new Handle:hCookie = RegClientCookie(sCookieName, sEffectDisplayName, CookieAccess_Public);
    Effect[clientCookie] = hCookie;

    // Add a menu item?
    Effect[menuItem] = GetNativeCell(5);
    
    // Togglable?
    Effect[togglable] = true;

    Effect[pluginHandle] = plugin;

    // Add array/trie values
    SetTrieArray(g_hEffects, sEffectName, Effect, sizeof(Effect));
    PushArrayString(g_hEffectNames, sEffectName);

    // Register command
    decl String:sCommand[67] = "sm_", String:sCommandDescription[128];
    StrCat(sCommand, sizeof(sCommand), sEffectName);
    Format(sCommandDescription, sizeof(sCommandDescription), "%s - Toggle %s on/off", sCommand, sEffectDisplayName);
    RegAdminCmd(sCommand, Command_GenericPremium, ADMFLAG_CUSTOM1, sCommandDescription);

    // Build Menu
    RebuildPremiumMenu();
    
    return true;
}

public Native_RegBasicEffect(Handle:plugin, numParams) {
    // Effect name (Used for cookie, command etc)
    decl String:sEffectName[64];
    GetNativeString(1, sEffectName, sizeof(sEffectName));

    // Is it already registered?
    if(FindStringInArray(g_hEffectNames, sEffectName) != -1) {
        return false;
    }

    // Effect display name (Displayed to players)
    decl String:sEffectDisplayName[64];
    GetNativeString(2, sEffectDisplayName, sizeof(sEffectDisplayName));

    decl Effect[g_ePremiumEffect];
    strcopy(Effect[name], sizeof(Effect[name]), sEffectName);
    strcopy(Effect[displayName], sizeof(Effect[displayName]), sEffectDisplayName);

    // Function called to run effect
    new Handle:hForwardEnable = CreateForward(ET_Event, Param_Cell);
    AddToForward(hForwardEnable, plugin, Function:GetNativeCell(3));
    Effect[enableCallback] = hForwardEnable;

    // Function called to end effect (Not needed here)
    Effect[disableCallback] = INVALID_HANDLE;

    // Client Cookie (not needed here)
    Effect[clientCookie] = INVALID_HANDLE;

    // Add a menu item?
    Effect[menuItem] = GetNativeCell(4);

    // Togglable?
    Effect[togglable] = false;

    Effect[pluginHandle] = plugin;

    // Add array/trie values
    SetTrieArray(g_hEffects, sEffectName, Effect, sizeof(Effect));
    PushArrayString(g_hEffectNames, sEffectName);

    // Register command
    decl String:sCommand[67] = "sm_", String:sCommandDescription[128];
    StrCat(sCommand, sizeof(sCommand), sEffectName);
    Format(sCommandDescription, sizeof(sCommandDescription), "%s - %s", sCommand, sEffectDisplayName);
    RegAdminCmd(sCommand, Command_GenericPremium, ADMFLAG_CUSTOM1, sCommandDescription);

    // Build Menu
    RebuildPremiumMenu();

    return true;
}

public Native_UnRegEffect(Handle:plugin, numParams) {
    decl String:sEffectName[64];
    GetNativeString(1, sEffectName, sizeof(sEffectName));

    new Index = FindStringInArray(g_hEffectNames, sEffectName);
    // Is it registered?
    if(Index == -1) {
        return false;
    }

    decl Effect[g_ePremiumEffect];
    GetTrieArray(g_hEffects, sEffectName, Effect, sizeof(Effect));

    if(Effect[pluginHandle] == plugin) {
        if(Effect[disableCallback] != INVALID_HANDLE) {
            new maxclients = GetMaxClients();
            for(new i = 1; i < maxclients; i++) {
                if(IsClientPremium(i)) {
                    Call_StartForward(Effect[disableCallback]);
                    Call_PushCell(i);
                    Call_Finish();
                }
            }
        }
        RemoveEffectMenuOptions(sEffectName);
        RemoveFromArray(g_hEffectNames, Index);
        RemoveFromTrie(g_hEffects, sEffectName);

        // Build Menu
        RebuildPremiumMenu();

        return true;
    }

    return false;
}

public Native_ShowMenu(Handle:plugin, numParams) {
    new client = GetNativeCell(1);

    if(!IsClientPremium(client))
        return false;

    ShowPremiumMenu(client);
    return true;
}

public Native_IsClientPremium(Handle:plugin, numParams) {
    new client = GetNativeCell(1);

    return IsClientPremium(client);
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

public Native_SetEffectState(Handle:plugin, numParams) {
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

public Native_AddMenuOption(Handle:plugin, numParams) {
    decl String:sEffectName[64], String:sItemTitle[64];
    GetNativeString(1, sEffectName, sizeof(sEffectName));
    GetNativeString(2, sItemTitle, sizeof(sItemTitle));

    new MenuOptionsIndex = FindStringInArray(g_hPremiumMenuEffectItems, sEffectName);

    // Already Registered?
    if(MenuOptionsIndex != -1) {
        new Handle:hOptionArray = GetArrayCell(g_hPremiumMenuEffectOptions, MenuOptionsIndex);
        for(new i = 0; i < GetArraySize(hOptionArray); i++) {
            new Handle:hOptionDataPack = GetArrayCell(hOptionArray, i);
            decl String:sItemTitle2[64];
            
            ResetPack(hOptionDataPack);
            ReadPackString(hOptionDataPack, sItemTitle2, sizeof(sItemTitle2));

            if(StrEqual(sItemTitle2, sItemTitle)) {
                return;
            }
        }
    }

    new Function:hCallback = GetNativeCell(3);

    new Handle:hForward = CreateForward(ET_Event, Param_Cell);
    AddToForward(hForward, plugin, Function:hCallback);

    new Handle:hDatapack = CreateDataPack();
    WritePackString(hDatapack, sItemTitle);
    WritePackCell(hDatapack, hForward);
    
    if(MenuOptionsIndex == -1) {
        new Handle:hOptionArray = CreateArray(64);
        PushArrayCell(hOptionArray, hDatapack);

        PushArrayString(g_hPremiumMenuEffectItems, sEffectName);
        PushArrayCell(g_hPremiumMenuEffectOptions, hOptionArray);
    } else {
        new Handle:hOptionArray = GetArrayCell(g_hPremiumMenuEffectOptions, MenuOptionsIndex);
        PushArrayCell(hOptionArray, hDatapack);

        SetArrayCell(g_hPremiumMenuEffectOptions, MenuOptionsIndex, hOptionArray);
    }
}

/********************
|  Other Functions  |
********************/

public bool:IsClientPremium(client) {
    if(!IsValidClient(client))
        return false;

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

public UpdateClientPremiumStatus(client) {
    g_bClientAuthorised[client] = true;
    new AdminId:iId = GetUserAdmin(client);
    if(iId != INVALID_ADMIN_ID) {
        new iFlags = GetAdminFlags(iId, Access_Effective);
        if(iFlags & ADMFLAG_CUSTOM1 || iFlags & ADMFLAG_ROOT) {
            
            if(g_bIsPremium[client]){
                return 0;
            } else {
                g_bIsPremium[client] = true;
                return 1;
            }
        } else {
            if(g_bIsPremium[client]) {
                g_bIsPremium[client] = false;
                return -1;
            }
        }
    }
    if(g_bIsPremium[client]) {
        g_bIsPremium[client] = false;
        return -1;
    }

    return 0;
}

public bool:TriggerEffect(client, String:sEffectName[]) {
    if(!IsValidClient(client) || !IsClientPremium(client)) {
        return false;
    }

    decl Effect[g_ePremiumEffect];
    if(!GetTrieArray(g_hEffects, sEffectName, Effect, sizeof(Effect))) {
        return false;
    }

    if(Effect[togglable]) {
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
    } else {
        if(Effect[enableCallback] != INVALID_HANDLE) {
            Call_StartForward(Effect[enableCallback]);
            Call_PushCell(client);
            Call_Finish();
            return true;
        }
    }
    return false;
}

public RemoveEffectMenuOptions(String:sEffectName[]) {
    new Index = FindStringInArray(g_hPremiumMenuEffectItems, sEffectName);

    if(Index == -1) {
        return;
    }

    RemoveFromArray(g_hPremiumMenuEffectItems, Index);
    RemoveFromArray(g_hPremiumMenuEffectOptions, Index);
}

/*******************
|  Menu Functions  |
*******************/

public RebuildPremiumMenu() {
    if(g_hPremiumMenu == INVALID_HANDLE) {
        g_hPremiumMenu = CreateMenu(MenuHandler_PremiumTop);
        SetMenuTitle(g_hPremiumMenu, "Premium Effects");
    } else {
        RemoveAllMenuItems(g_hPremiumMenu);
    }

    for(new i = 0; i < GetArraySize(g_hEffectNames); i++) {
        decl String:sEffectName[64], Effect[g_ePremiumEffect];
        GetArrayString(g_hEffectNames, i, sEffectName, sizeof(sEffectName));
        GetTrieArray(g_hEffects, sEffectName, Effect, sizeof(Effect));
        if(Effect[menuItem]) {
            AddMenuItem(g_hPremiumMenu, sEffectName, Effect[displayName]);
        }
    }
}

public ShowPremiumMenu(client) {
    if(g_hPremiumMenu != INVALID_HANDLE)
        DisplayMenu(g_hPremiumMenu, client, 120);
}

public MenuHandler_PremiumTop(Handle:menu, MenuAction:action, param1, param2) {
    if(action == MenuAction_Select) {
        decl String:sEffectName[64], String:sMenuItem[73];
        GetMenuItem(menu, param2, sEffectName, sizeof(sEffectName));

        decl Effect[g_ePremiumEffect];
        GetTrieArray(g_hEffects, sEffectName, Effect, sizeof(Effect));

        new Handle:hMenu = CreateMenu(MenuHandler_PremiumEffect);
        SetMenuTitle(hMenu, "Premium / %s", Effect[displayName]);
        
        new MenuOptionsIndex = FindStringInArray(g_hPremiumMenuEffectItems, sEffectName);
        new bHasItems = false;

        if(Effect[togglable]) {
            Format(sMenuItem, sizeof(sMenuItem), "Turn %s ", Effect[displayName]);
            if(Premium_IsEffectEnabled(param1, sEffectName)) {
                StrCat(sMenuItem, sizeof(sMenuItem), "Off");
            } else {
                StrCat(sMenuItem, sizeof(sMenuItem), "On");
            }
            
            new Handle:hDataPack = CreateDataPack();
            WritePackString(hDataPack, sEffectName);
            WritePackCell(hDataPack, PREMIUM_ACTION_TRIGGER);
            WritePackCell(hDataPack, INVALID_HANDLE);
            
            decl String:sDataFormat[64];
            Format(sDataFormat, sizeof(sDataFormat), "%d", hDataPack);
            
            AddMenuItem(hMenu, sDataFormat, sMenuItem);
            bHasItems = true;
        }

        if(MenuOptionsIndex >= 0) {
            new Handle:hOptionArray = GetArrayCell(g_hPremiumMenuEffectOptions, MenuOptionsIndex);
            for(new i = 0; i < GetArraySize(hOptionArray); i++) {
                new Handle:hOptionDataPack = GetArrayCell(hOptionArray, i);
                decl String:sItemTitle[64];
                
                ResetPack(hOptionDataPack);
                ReadPackString(hOptionDataPack, sItemTitle, sizeof(sItemTitle));
                new Handle:hItemCallback = ReadPackCell(hOptionDataPack);
                
                new Handle:hDataPack = CreateDataPack();
                WritePackString(hDataPack, sEffectName);
                WritePackCell(hDataPack, PREMIUM_ACTION_CALLBACK);
                WritePackCell(hDataPack, hItemCallback);
                
                decl String:sDataFormat[64];
                Format(sDataFormat, sizeof(sDataFormat), "%d", hDataPack);
                
                AddMenuItem(hMenu, sDataFormat, sItemTitle);
            }
            bHasItems = true;
        }

        if(!Effect[togglable] && !bHasItems) {
            TriggerEffect(param1, sEffectName);
            ShowPremiumMenu(param1);
        }

        SetMenuExitBackButton(hMenu, true);
        DisplayMenu(hMenu, param1, 120);
    }
}

public MenuHandler_PremiumEffect(Handle:menu, MenuAction:action, param1, param2) {
    if(action == MenuAction_Select) {
        decl String:sHandle[64], String:sEffectName[64];
        GetMenuItem(menu, param2, sHandle, sizeof(sHandle));
        new Handle:hDataPack = Handle:StringToInt(sHandle);
        ResetPack(hDataPack);
        
        ReadPackString(hDataPack, sEffectName, sizeof(sEffectName));
        new Type = ReadPackCell(hDataPack);
        
        if(Type == PREMIUM_ACTION_CALLBACK) {
            new Handle:hCallback = ReadPackCell(hDataPack);

            if(hCallback != INVALID_HANDLE) {
                Call_StartForward(hCallback);
                Call_PushCell(param1);
                Call_Finish();
            }
        } else if(Type == PREMIUM_ACTION_TRIGGER) {
            if(FindStringInArray(g_hEffectNames, sEffectName) != -1) {
                TriggerEffect(param1, sEffectName);
                ShowPremiumMenu(param1);
            }
        }

    } else if(action == MenuAction_Cancel && param2 == MenuCancel_ExitBack) {
        ShowPremiumMenu(param1);
    }
}