#include <clientprefs>
#undef REQUIRE_PLUGIN
#include <premium_manager>

/* 
    Global cooldown? once failled cannot vote again for x seconds. Once success cannot vote at all 
    Use cvar or mp_timelimit with current timeleft instead of tracking start time manually?
    cvar for cooldown time etc?
*/

#define PLUGIN_EFFECT "forcethevote"

new g_iMapStartTime;
new Handle:g_hMapMenu = INVALID_HANDLE;

public Plugin:myinfo = {
    name        = "Premium -> Force The Vote",
    author      = "Azelphur / Monster Killer",
    description = "Allows premium users to force a vote for a specific map.",
    version     = "1.2",
    url         = "http://www.azelphur.com"
};

public OnPluginEnd() {
    if(LibraryExists("premium_manager")) {
        Premium_UnRegEffect(PLUGIN_EFFECT);
    }
}

public OnAllPluginsLoaded() {
    if(LibraryExists("premium_manager")) {
        Premium_Loaded();
    }
}

public OnLibraryAdded(const String:name[]) {
    if(StrEqual(name, "premium_manager")) {
        Premium_Loaded();
    }
}

public Premium_Loaded() {
    Premium_RegBasicEffect(PLUGIN_EFFECT, "Force The Vote", Callback_CallVote, true);
    Premium_AddEffectCooldown(PLUGIN_EFFECT, 3600, PREMIUM_COOLDOWN_ENABLE);
}

public OnMapStart() {
    g_iMapStartTime = GetTime();

    new Handle:hMapList = CreateArray(64);
    ReadMapList(hMapList);
    g_hMapMenu = CreateMenu(MenuHandler_MapList); 
    SetMenuExitBackButton(g_hMapMenu, true);
    decl String:szMap[64];
    SetMenuTitle(g_hMapMenu, "Select a map to start vote for");
    for(new i = 0; i < GetArraySize(hMapList); i++) {
        GetArrayString(hMapList, i, szMap, sizeof(szMap));
        AddMenuItem(g_hMapMenu, szMap, szMap);
    }
}

public Callback_CallVote(client) {
    new iSeconds = (GetTime() - g_iMapStartTime);
    if(iSeconds < 300) {
        new remaining = 300-iSeconds;
        PrintToChat(client, "%s You must wait %d:%02d to use vote map.", PREMIUM_PREFIX, remaining / 60, remaining % 60);
        return PREMIUM_RETURN_STOP;
    }

    if(g_hMapMenu != INVALID_HANDLE) {
        DisplayMenu(g_hMapMenu, client, MENU_TIME_FOREVER);
    }

    return PREMIUM_RETURN_STOP;
}

public MenuHandler_MapList(Handle:hMenu, MenuAction:action, param1, param2) {
    if(action == MenuAction_Select) {
        if(IsVoteInProgress()) {
            PrintToChat(param1, "%s You cannot start a map vote while another vote is ongoing", PREMIUM_PREFIX);
            return;
        }

        decl String:szMap[64], String:szPlayerName[128];
        GetMenuItem(hMenu, param2, szMap, sizeof(szMap));
        GetClientName(param1, szPlayerName, sizeof(szPlayerName));
        PrintToChatAll("%s %s used premium to start a map vote for: %s", PREMIUM_PREFIX, szPlayerName, szMap);
        LogAction(param1, -1, "%s player used premium to start map vote for: %s", PREMIUM_PREFIX_NOCOLOR, szMap);
        
        Premium_ActivateClientCooldown(param1, PLUGIN_EFFECT, true);

        DoVoteMenu(szMap);
    } else if(action == MenuAction_Cancel && param2 == MenuCancel_ExitBack) {
        Premium_ShowLastMenu(param1);
    }
}
 
DoVoteMenu(const String:map[]) {
    new Handle:hMenu2 = CreateMenu(MenuHandler_VoteMenu);
    SetMenuTitle(hMenu2, "Change map to: %s?", map);
    AddMenuItem(hMenu2, map, "Yes");
    AddMenuItem(hMenu2, "no", "No");
    SetMenuExitButton(hMenu2, false);
    VoteMenuToAll(hMenu2, 20);
}

public MenuHandler_VoteMenu(Handle:menu, MenuAction:action, param1, param2) {
    if (action == MenuAction_End) {
        /* This is called after VoteEnd */
        CloseHandle(menu);
    } else if (action == MenuAction_VoteEnd) {
        /* 0=yes, 1=no */
        new String:sMap[64];
        GetMenuItem(menu, param1, sMap, sizeof(sMap));
        if(param1 == 0) {
            PrintToChatAll("%s Changing map to: %s in 20 seconds", PREMIUM_PREFIX, sMap);
            ServerCommand("wait 2000;changelevel %s", sMap);
        } else if(param1 == 1) {
            PrintToChatAll("%s Map vote failed, no enough players voted yes", PREMIUM_PREFIX, sMap);
        }
    }
}