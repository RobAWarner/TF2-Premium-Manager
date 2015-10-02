#pragma semicolon 1

#include <clientprefs>
#include <regex>
#undef REQUIRE_PLUGIN
#include <premium_manager>
#include <sourceirc>

#define PLUGIN_EFFECT "premiumchat"
#define IGNORE_CHAT_SYMBOL '@'

/* TODO:
    cvar for chat simbol or put in config?
    Use commandlistener instead of consolecmd?
    Replace colour simbols in IRC?
 */

new bool:g_bIRCLoaded = false;

new bool:g_bIsEnabled[MAXPLAYERS+1];
new bool:g_bCookiesCached[MAXPLAYERS+1];

new Handle:g_hKV = INVALID_HANDLE;
new Handle:g_hmColorItems = INVALID_HANDLE;
new Handle:g_hrHEX = INVALID_HANDLE;
new Handle:g_hrColorEnds = INVALID_HANDLE;
new Handle:g_hrColorShorts = INVALID_HANDLE;
new Handle:g_hChatColorCookie = INVALID_HANDLE;

new String:g_sColorDefault[MAXPLAYERS+1][10];
new String:g_sColorPrifx[2];

public Plugin:myinfo = {
    name = "Premium -> Premium Chat",
    author = "Azelphur / Monster Killer",
    description = "Gives premium members premium chat & coloured chat",
    version = "1.2",
    url = "http://www.azelphur.com"
};

public OnPluginStart() {
    RegConsoleCmd("say", Command_Say);
    RegConsoleCmd("say2", Command_Say);
    RegConsoleCmd("say_team", Command_SayTeam);

    g_hChatColorCookie = RegClientCookie("premium_premiumchat_color", "team", CookieAccess_Public);

    LoadKV();
}

public OnAllPluginsLoaded() {
    if(LibraryExists("premium_manager"))
        Premium_Loaded();
    if(LibraryExists("sourceirc"))
        g_bIRCLoaded = true;
}

public OnLibraryAdded(const String:name[]) {
    if(StrEqual(name, "premium_manager"))
        Premium_Loaded();
    if(LibraryExists("sourceirc"))
        g_bIRCLoaded = true;
}

public OnLibraryRemoved(const String:name[]) {
	if(StrEqual(name, "premium_manager")) {
        for(new i = 1; i <= MaxClients; i++) {
            g_bIsEnabled[i] = false;
        }
    }
	if(StrEqual(name, "sourceirc")) {
        g_bIRCLoaded = false;
    }
}

public Premium_Loaded() {
    Premium_RegEffect(PLUGIN_EFFECT, "Premium Chat", Callback_EnableEffect, Callback_DisableEffect, true);
    Premium_AddMenuOption(PLUGIN_EFFECT, "Change Color", Callback_ShowColorOptionMenu);
}

public OnPluginEnd() {
    if(LibraryExists("premium_manager"))
        Premium_UnRegEffect(PLUGIN_EFFECT);
}

public OnClientConnected(client) {
    g_bIsEnabled[client] = false;
    g_bCookiesCached[client] = false;
}

public OnClientCookiesCached(client) {
    UpdateClientCookies(client);
}

public Callback_EnableEffect(client) {
    g_bIsEnabled[client] = true;
    UpdateClientCookies(client);
}

public Callback_DisableEffect(client) {
    g_bIsEnabled[client] = false;
}

public UpdateClientCookies(client) {
    g_bCookiesCached[client] = true;
    decl String:szColor[64];
    GetClientCookie(client, g_hChatColorCookie, szColor, sizeof(szColor));
    if(g_hKV != INVALID_HANDLE && !StrEqual(szColor, "")) {
        KvRewind(g_hKV);
        if(KvJumpToKey(g_hKV, "Colors")) {
            if(!(KvJumpToKey(g_hKV, szColor))) {
                SetClientCookie(client, g_hChatColorCookie, "T");
                Format(g_sColorDefault[client], sizeof(g_sColorDefault[]), "\x03"); 
            } else {
                decl String:sColorVal[10];
                KvGetString(g_hKV, "Color", sColorVal, sizeof(sColorVal), "");
                Format(g_sColorDefault[client], sizeof(g_sColorDefault[]), sColorVal); 
            }
        }
        KvRewind(g_hKV);
    }
}

public LoadKV() {
    g_hKV = CreateKeyValues("PremiumColors");
    decl String:sFile[512];
    BuildPath(Path_SM, sFile, sizeof(sFile), "configs/premium_premiumchat_colors.cfg");
    
    if(!FileExists(sFile)) {
        SetFailState("File Not Found: %s", Path_SM);
    }

    FileToKeyValues(g_hKV, sFile);

    if(!KvJumpToKey(g_hKV, "Settings")) {
        return;
    }

    KvGotoFirstSubKey(g_hKV);
    KvGetString(g_hKV, "prefix", g_sColorPrifx, sizeof(g_sColorPrifx), "^");
    KvRewind(g_hKV);

    g_hmColorItems = CreateMenu(MenuHandler_ColorMenu);
    SetMenuTitle(g_hmColorItems, "Premium Chat Color");
    SetMenuExitBackButton(g_hmColorItems, true);
    
    if(!KvJumpToKey(g_hKV, "Colors"))
        return;

    decl String:szTitle[2], String:szName[32], String:sItem[40], String:RegexBuild[200];
    Format(RegexBuild, sizeof(RegexBuild), "(\\%s([T", g_sColorPrifx); 
    KvGotoFirstSubKey(g_hKV);
    AddMenuItem(g_hmColorItems, "T", "Team Color (^T)");
    do {
        KvGetSectionName(g_hKV, szTitle, sizeof(szTitle));
        KvGetString(g_hKV, "Name", szName, sizeof(szName), "");
        if(!StrEqual(szTitle, "")) {
            Format(sItem, sizeof(sItem), "%s (%s%s)", szName, g_sColorPrifx, szTitle);
            Format(RegexBuild, sizeof(RegexBuild), "%s%s", RegexBuild, szTitle); 
            AddMenuItem(g_hmColorItems, szTitle, sItem);
        }
    } while (KvGotoNextKey(g_hKV));
    KvRewind(g_hKV);
    Format(RegexBuild, sizeof(RegexBuild), "%s]))", RegexBuild); 
    
    StartRegex(RegexBuild);
}

public StartRegex(String:Shorts[]) {
    g_hrHEX = CompileRegex("(\\{#([0-255a-fA-F]{6})\\})");
    g_hrColorEnds = CompileRegex("(\x07[0-255a-fA-F)]{6})$");
    if(!StrEqual(Shorts, "")) {
        g_hrColorShorts = CompileRegex(Shorts, PCRE_CASELESS);
    }
}

public ProcessRegex(String:InputString[], maxlen) {
    decl String:ChatString[maxlen];
    Format(ChatString, maxlen, InputString);
    if(MatchRegex(g_hrHEX, ChatString)) {
        decl String:Hex[7], String:FullHex[10], String:NewColor[10];
        do {
            GetRegexSubString(g_hrHEX, 1, FullHex, sizeof(FullHex));
            GetRegexSubString(g_hrHEX, 2, Hex, sizeof(Hex));
            Format(NewColor, sizeof(NewColor), "\x07%s", Hex);
            ReplaceString(ChatString, maxlen, FullHex, NewColor);
        } while (MatchRegex(g_hrHEX, ChatString) > 0);
        
        if(MatchRegex(g_hrColorEnds, ChatString)) {
            Format(ChatString, maxlen, "%s ", ChatString);
        }
    }

    if(!(g_hrColorShorts == INVALID_HANDLE)) {
        if(MatchRegex(g_hrColorShorts, ChatString)) {
            decl String:ColorL[7], String:Match[10];
            do {
                GetRegexSubString(g_hrColorShorts, 1, Match, sizeof(Match));
                GetRegexSubString(g_hrColorShorts, 2, ColorL, sizeof(ColorL));
                if(StrEqual(ColorL, "T", false)) {
                    ReplaceString(ChatString, maxlen, Match, "\x03");
                } else {
                    KvRewind(g_hKV);
                    if (KvJumpToKey(g_hKV, "Colors")) {
                        if (KvJumpToKey(g_hKV, ColorL)) {
                            decl String:sColor[12];
                            KvGetString(g_hKV, "Color", sColor, sizeof(sColor), " ");
                            Format(sColor, sizeof(sColor), "\x07%s", sColor);
                            ReplaceString(ChatString, maxlen, Match, sColor);
                        } else {
                            ReplaceString(ChatString, maxlen, Match, " ");
                        }
                    } else {
                        ReplaceString(ChatString, maxlen, Match, " ");
                    }
                }
            } while (MatchRegex(g_hrColorShorts, ChatString) > 0);
            
            if(MatchRegex(g_hrColorEnds, ChatString)) {
                Format(ChatString, maxlen, "%s ", ChatString);
            }
        }
    }
    Format(InputString, maxlen, ChatString);
}

public Action:Command_Say(client, args) {
    if(IsChatTrigger() || !g_bIsEnabled[client]) {
        return Plugin_Continue;
    }
    new String:text[192];
    GetCmdArgString(text, sizeof(text));
    new startidx = 0;
    if(text[0] == '"') {
        startidx = 1;
        new len = strlen(text);
        if (text[len-1] == '"')
            text[len-1] = '\0';
    }

    if(text[startidx] == IGNORE_CHAT_SYMBOL) {
        return Plugin_Continue;
    }
    
    decl String:name[64], String:str[512], String:ColorChat[12];
    GetClientName(client, name, sizeof(name));

    if(!(StrEqual(g_sColorDefault[client], "\x03")) && !(StrEqual(g_sColorDefault[client], "\x01"))) {
        Format(ColorChat, sizeof(ColorChat), "\x07%s", g_sColorDefault[client]);
    } else {
        Format(ColorChat, sizeof(ColorChat), "%s", g_sColorDefault[client]);
    }
    Format(str, sizeof(str), "\x03(Premium) %s :  %s%s", name, ColorChat, text[startidx]);
    
    ProcessRegex(str, sizeof(str));
    
    SayText2All(client, str);
    
    if(g_bIRCLoaded) {
        new team = IRC_GetTeamColor(GetClientTeam(client));
        if (team == -1)
            IRC_MsgFlaggedChannels("relay", "(Premium) %s: %s", name, text[startidx]);
        else
            IRC_MsgFlaggedChannels("relay", "\x03%02d(Premium) %s: %s\x03", team, name, text[startidx]);
    }

    return Plugin_Handled;
}

public Action:Command_SayTeam(client, args) {
    if (IsChatTrigger() || !g_bIsEnabled[client])
        return Plugin_Continue;
    new String:text[192];
    GetCmdArgString(text, sizeof(text));
    new startidx = 0;
    if (text[0] == '"') {
        startidx = 1;
        new len = strlen(text);
        if (text[len-1] == '"')
            text[len-1] = '\0';
    }
    
    decl String:name[64], String:str[512], String:ColorChat[12];
    GetClientName(client, name, sizeof(name));
    
    if(!(StrEqual(g_sColorDefault[client], "\x03")) && !(StrEqual(g_sColorDefault[client], "\x01")))
        Format(ColorChat, sizeof(ColorChat), "\x07%s", g_sColorDefault[client]);
    else
        Format(ColorChat, sizeof(ColorChat), "%s", g_sColorDefault[client]);
    
    Format(str, sizeof(str), "\x03(Premium) (TEAM) %s :  %s%s", name, ColorChat, text[startidx]);
    
    ProcessRegex(str, sizeof(str));
    
    SayText2Team(client, str);
    
    if(g_bIRCLoaded) {
        new team = IRC_GetTeamColor(GetClientTeam(client));
        if (team == -1)
            IRC_MsgFlaggedChannels("relay", "(Premium) (TEAM) %s: %s", name, text[startidx]);
        else
            IRC_MsgFlaggedChannels("relay", "\x03%02d(Premium) (TEAM) %s: %s\x03", team, name, text[startidx]);
    }
    return Plugin_Handled;
}

stock SayText2(client, author, const String:message[]) {
    new Handle:buffer = StartMessageOne("SayText2", client); 
    if (buffer != INVALID_HANDLE) {
        BfWriteByte(buffer, author); 
        BfWriteByte(buffer, true); 
        BfWriteString(buffer, message); 
        EndMessage(); 
    } 
}

stock SayText2Team(author_index, const String:message[]) {
    new authorteam = GetClientTeam(author_index);

    for(new i=1;i<=MaxClients;i++) {
        if(IsClientInGame(i)) {
            new clientteam = GetClientTeam(i);

            if(clientteam == authorteam) {
                SayText2(i, author_index, message);
            }
        }
    }
}

stock SayText2All(author_index, const String:message[]) {
    for(new i=1;i<=MaxClients;i++) {
        if(IsClientInGame(i)) {
            SayText2(i, author_index, message);
        }
    }
}

/*******************
|  Menu Functions  |
*******************/

public Callback_ShowColorOptionMenu(client) {
    if(g_hmColorItems != INVALID_HANDLE) {
        DisplayMenu(g_hmColorItems, client, PREMIUM_MENU_TIME);
    }
}

public MenuHandler_ColorMenu(Handle:menu, MenuAction:action, param1, param2) {
    if(action == MenuAction_Select) {
        decl String:info[64];
        GetMenuItem(menu, param2, info, sizeof(info));
        if(StrEqual(info, "T", false)) {
            SetClientCookie(param1, g_hChatColorCookie, "T");
            Format(g_sColorDefault[param1], sizeof(g_sColorDefault[]), "\x03"); 
        } else {
            KvRewind(g_hKV);
            if(KvJumpToKey(g_hKV, "Colors")) {
                if(KvJumpToKey(g_hKV, info)) {
                    decl String:szName[32], String:sColor[10];
                    KvGetString(g_hKV, "Name", szName, sizeof(szName), "");
                    KvGetString(g_hKV, "Color", sColor, sizeof(sColor), "");
                    SetClientCookie(param1, g_hChatColorCookie, info);
                    Format(g_sColorDefault[param1], sizeof(g_sColorDefault[]), sColor); 
                }
            }
            KvRewind(g_hKV);
        }
        Premium_ShowLastMenu(param1);
    } else if(action == MenuAction_Cancel && param2 == MenuCancel_ExitBack) {
        Premium_ShowLastMenu(param1);
    }
}