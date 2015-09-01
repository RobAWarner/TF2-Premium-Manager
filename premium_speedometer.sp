#pragma semicolon 1

#include <sourcemod>
#include <clientprefs>
#include <tf2_stocks>
#undef REQUIRE_PLUGIN
#include <premium_manager>

#define PLUGIN_EFFECT "speedometer"

new bool:g_bIsEnabled[MAXPLAYERS+1];
new bool:g_bCookiesCached[MAXPLAYERS + 1];

new GetVelocityOffset_0;
new GetVelocityOffset_1;
new GetVelocityOffset_2;

new Handle:g_hSpeedoColor = INVALID_HANDLE;
new Handle:g_hSpeedoUnit = INVALID_HANDLE;
new Handle:g_hSpeedoPos = INVALID_HANDLE;

new Handle:g_hSpeedoMenuUnits = INVALID_HANDLE;
new Handle:g_hSpeedoMenuColor = INVALID_HANDLE;
new Handle:g_hSpeedoMenuPosition = INVALID_HANDLE;

new g_fSpeedoColor[MAXPLAYERS + 1][3];
new Float:g_fSpeedoPos[MAXPLAYERS + 1][2];
new String:g_sSpeedoUnit[MAXPLAYERS + 1][4];

public Plugin:myinfo = {
    name = "Premium -> Speedometer",
    author = "Azelphur / Monster Killer",
    description = "Shows a speedometer",
    version = "1.3",
    url = "http://www.azelphur.com"
};

public OnPluginStart() {
    GetVelocityOffset_0 = FindSendPropOffs("CBasePlayer","m_vecVelocity[0]");
    GetVelocityOffset_1 = FindSendPropOffs("CBasePlayer","m_vecVelocity[1]");
    GetVelocityOffset_2 = FindSendPropOffs("CBasePlayer","m_vecVelocity[2]");

    g_hSpeedoColor = RegClientCookie("premium_speedometer_color", "speedometer color", CookieAccess_Public);
    g_hSpeedoUnit = RegClientCookie("premium_speedometer_units", "speedometer units", CookieAccess_Public);
    g_hSpeedoPos = RegClientCookie("premium_speedometer_pos", "speedometer position", CookieAccess_Public);
    
    // Unit Menu
    g_hSpeedoMenuUnits = CreateMenu(MenuHandler_ConfigMenu_Unit);
    SetMenuExitBackButton(g_hSpeedoMenuUnits, true);
    SetMenuTitle(g_hSpeedoMenuUnits, "Speedometer units");
    AddMenuItem(g_hSpeedoMenuUnits, "mph", "Miles per hour (mph)");
    AddMenuItem(g_hSpeedoMenuUnits, "kph", "Kilometers per hour (kph)");
    AddMenuItem(g_hSpeedoMenuUnits, "m/s", "Meters per second (m/s)");
    AddMenuItem(g_hSpeedoMenuUnits, "f/s", "Feet per second (feet/s)");
    // Position Menu
    g_hSpeedoMenuPosition = CreateMenu(MenuHandler_ConfigMenu_Pos);
    SetMenuExitBackButton(g_hSpeedoMenuPosition, true);
    SetMenuTitle(g_hSpeedoMenuPosition, "Speedometer position");
    AddMenuItem(g_hSpeedoMenuPosition, "-1.0;0.2", "Top Center");
    AddMenuItem(g_hSpeedoMenuPosition, "0.1;0.2", "Top Left");
    AddMenuItem(g_hSpeedoMenuPosition, "0.8;0.2", "Top Right");
    AddMenuItem(g_hSpeedoMenuPosition, "-1.0;-1.0", "Middle Center");
    AddMenuItem(g_hSpeedoMenuPosition, "0.1;-1.0", "Middle Left");
    AddMenuItem(g_hSpeedoMenuPosition, "0.8;-1.0", "Middle Right");
    AddMenuItem(g_hSpeedoMenuPosition, "-1.0;0.8", "Bottom Center");
    AddMenuItem(g_hSpeedoMenuPosition, "0.1;0.8", "Bottom Left");
    AddMenuItem(g_hSpeedoMenuPosition, "0.5;0.8", "Bottom Right");
    // Color Menu
    g_hSpeedoMenuColor = CreateMenu(MenuHandler_ConfigMenu_Color);
    SetMenuExitBackButton(g_hSpeedoMenuColor, true);
    SetMenuTitle(g_hSpeedoMenuColor, "Speedometer color");
    AddMenuItem(g_hSpeedoMenuColor, "255;255;255", "White");
    AddMenuItem(g_hSpeedoMenuColor, "255;5;5", "Red");
    AddMenuItem(g_hSpeedoMenuColor, "7;195;7", "Green");
    AddMenuItem(g_hSpeedoMenuColor, "10;10;210", "Blue");
    AddMenuItem(g_hSpeedoMenuColor, "25;220;220", "Cyan");
    AddMenuItem(g_hSpeedoMenuColor, "238;238;0", "Yellow");
    AddMenuItem(g_hSpeedoMenuColor, "210;20;210", "Pink");
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
    Premium_RegEffect(PLUGIN_EFFECT, "Speedometer", EnableEffect, DisableEffect, true);
    Premium_AddMenuOption(PLUGIN_EFFECT, "Change Color", ShowColorOptionMenu);
    Premium_AddMenuOption(PLUGIN_EFFECT, "Change Units", ShowUnitOptionMenu);
    Premium_AddMenuOption(PLUGIN_EFFECT, "Change Position", ShowPositionOptionMenu);
}

public OnPluginEnd() {
    if(LibraryExists("premium_manager"))
        Premium_UnRegEffect(PLUGIN_EFFECT);
}

public OnClientConnected(client) {
    g_bIsEnabled[client] = false;
    g_bCookiesCached[client] = false;
}

public EnableEffect(client) {
    g_bIsEnabled[client] = true;
    if(!g_bCookiesCached[client]) {
        PrintToChatAll("Firing speedo!");
        UpdateClientCookies(client);
    }
}

public DisableEffect(client) {
    g_bIsEnabled[client] = false;
}

public OnClientCookiesCached(client) {
    UpdateClientCookies(client);
}

public UpdateClientCookies(client) {
    g_bCookiesCached[client] = true;
    decl String:szCookie[64];
    GetClientCookie(client, g_hSpeedoColor, szCookie, sizeof(szCookie));
    if(StrEqual(szCookie, "")) {
        SetSpeedoColor(client, "255;255;255");
    } else {
        SetSpeedoColor(client, szCookie);
    }
    
    GetClientCookie(client, g_hSpeedoPos, szCookie, sizeof(szCookie));
    if(StrEqual(szCookie, "")) {
        SetSpeedoPos(client, "-1.0;0.2");
    } else {
        SetSpeedoPos(client, szCookie);
    }
    
    GetClientCookie(client, g_hSpeedoUnit, szCookie, sizeof(szCookie));
    if(StrEqual(szCookie, "")) {
        g_sSpeedoUnit[client] = "mph";
        Format(g_sSpeedoUnit[client], sizeof(g_sSpeedoUnit[]), "mph");
    } else {
        Format(g_sSpeedoUnit[client], sizeof(g_sSpeedoUnit[]), szCookie);
    }
}

public SetSpeedoPos(client, String:Pos[]) {
    new String:PosStore[2][5];
    ExplodeString(Pos, ";", PosStore, sizeof(PosStore), sizeof(PosStore[]));
    g_fSpeedoPos[client][0] = StringToFloat(PosStore[0]);
    g_fSpeedoPos[client][1] = StringToFloat(PosStore[1]);
}

public SetSpeedoColor(client, String:Color[]) {
    new String:RGBStore[3][5];
    ExplodeString(Color, ";", RGBStore, sizeof(RGBStore), sizeof(RGBStore[]));
    g_fSpeedoColor[client][0] = StringToInt(RGBStore[0]);
    g_fSpeedoColor[client][1] = StringToInt(RGBStore[1]);
    g_fSpeedoColor[client][2] = StringToInt(RGBStore[2]);
}

public OnGameFrame() {
    new Float:speed;
    new Float:x;
    new Float:y;
    new Float:z;
    new clientCount = GetMaxClients();
    for(new client = 1; client <= clientCount; client++) {
        if(IsClientInGame(client) && IsPlayerAlive(client) && g_bIsEnabled[client]) {
            x=GetEntDataFloat(client,GetVelocityOffset_0);
            y=GetEntDataFloat(client,GetVelocityOffset_1);
            z=GetEntDataFloat(client,GetVelocityOffset_2);
            speed = SquareRoot(x*x + y*y + z*z)/20.0;

            if(speed >= 100 && Premium_IsClientPremium(client)) {
                if(TF2_IsPlayerInCondition(client, TFCond_OnFire)) {
                    TF2_RemoveCondition(client, TFCond_OnFire);
                    ClientCommand(client, "playgamesound \"player/flame_out.wav\"");
                }
            }

            if(StrEqual(g_sSpeedoUnit[client], "mph")) {
                PrintToClientCenter(client, 0.0, 0.0, 1.0, "Speed: %dmph", RoundToNearest(speed));
            } else if(StrEqual(g_sSpeedoUnit[client], "kph") && Premium_IsClientPremium(client)) {
                speed = speed * 1.60934;
                PrintToClientCenter(client, 0.0, 0.0, 1.0, "Speed: %dkph", RoundToNearest(speed));
            } else if(StrEqual(g_sSpeedoUnit[client], "m/s") && Premium_IsClientPremium(client)) {
                speed = speed * 0.44704;
                PrintToClientCenter(client, 0.0, 0.0, 1.0, "Speed: %dm/s", RoundToNearest(speed));
            } else if(StrEqual(g_sSpeedoUnit[client], "f/s") && Premium_IsClientPremium(client)) {
                speed = speed * 1.46667;
                PrintToClientCenter(client, 0.0, 0.0, 1.0, "Speed: %dfeet/s", RoundToNearest(speed));
            } else {
                PrintToClientCenter(client, 0.0, 0.0, 1.0, "Speed: %dmph", RoundToNearest(speed));
            }
        }
    }
}

stock PrintToClientCenter(client, Float:fadeInTime, Float:fadeOutTime, Float:holdTime, const String:msg[], any:...) {
    decl String:fmsg[221];
    VFormat(fmsg, sizeof(fmsg), msg, 6);

    new Handle:hBf = StartMessageOne("HudMsg", client);
    
    if(hBf == INVALID_HANDLE) {
        return;
    }
    
    new Float:iX = -1.0;
    new Float:iY = 0.2;
    new iR = 255;
    new iG = 255;
    new iB = 255;
    
    if(Premium_IsClientPremium(client)) {
        iX = g_fSpeedoPos[client][0];
        iY = g_fSpeedoPos[client][1];
        iR = g_fSpeedoColor[client][0];
        iG = g_fSpeedoColor[client][1];
        iB = g_fSpeedoColor[client][2];
    }
    
    // Position
    BfWriteByte(hBf, 1);              // channel
    BfWriteFloat(hBf, iX);            // X
    BfWriteFloat(hBf, iY);            // Y
    
    // Second Color
    BfWriteByte(hBf, iR);             // r
    BfWriteByte(hBf, iG);             // g
    BfWriteByte(hBf, iB);             // b
    BfWriteByte(hBf, 255);            // a
    
    // First Color
    BfWriteByte(hBf, iR);             // r
    BfWriteByte(hBf, iG);             // g
    BfWriteByte(hBf, iB);             // b
    BfWriteByte(hBf, 255);            // a
    
    // Effect
    BfWriteByte(hBf, 0);              // effect (0 is fade in/fade out; 1 is flickery credits; 2 is write out)
    BfWriteFloat(hBf, fadeInTime);    // fadeinTime (message fade in time - per character in effect 2)
    BfWriteFloat(hBf, fadeOutTime);   // fadeoutTime
    BfWriteFloat(hBf, holdTime);      // holdtime
    BfWriteFloat(hBf, 0.0);           // fxtime (effect type(2) used)
    
    // Message
    BfWriteString(hBf, fmsg);         // message
    
    EndMessage();
    
    return;
}

/*******************
|  Menu Functions  |
*******************/

public ShowColorOptionMenu(client) {
    if(Premium_IsClientPremium(client)) {
        DisplayMenu(g_hSpeedoMenuColor, client, 120);
    }
}

public ShowUnitOptionMenu(client) {
    if(Premium_IsClientPremium(client)) {
        DisplayMenu(g_hSpeedoMenuUnits, client, 120);
    }
}

public ShowPositionOptionMenu(client) {
    if(Premium_IsClientPremium(client)) {
        DisplayMenu(g_hSpeedoMenuPosition, client, 120);
    }
}

public MenuHandler_ConfigMenu_Unit(Handle:menu, MenuAction:action, param1, param2) {
    if(action == MenuAction_Select) {
        decl String:info[64];
        GetMenuItem(menu, param2, info, sizeof(info));
        if(IsClientConnected(param1)) {
            SetClientCookie(param1, g_hSpeedoUnit, info);
            Format(g_sSpeedoUnit[param1], sizeof(g_sSpeedoUnit[]), info);
        }
        Premium_ShowLastMenu(param1);
    } else if(action == MenuAction_Cancel && param2 == MenuCancel_ExitBack) {
        Premium_ShowLastMenu(param1);
    }
}

public MenuHandler_ConfigMenu_Pos(Handle:menu, MenuAction:action, param1, param2) {
    if(action == MenuAction_Select) {
        decl String:info[64];
        GetMenuItem(menu, param2, info, sizeof(info));
        if(IsClientConnected(param1)) {
            SetClientCookie(param1, g_hSpeedoPos, info);
            SetSpeedoPos(param1, info);
        }
        Premium_ShowLastMenu(param1);
    } else if(action == MenuAction_Cancel && param2 == MenuCancel_ExitBack) {
        Premium_ShowLastMenu(param1);
    }
}

public MenuHandler_ConfigMenu_Color(Handle:menu, MenuAction:action, param1, param2) {
    if(action == MenuAction_Select) {
        decl String:info[64];
        GetMenuItem(menu, param2, info, sizeof(info));
        if(IsClientConnected(param1)) {
            SetClientCookie(param1, g_hSpeedoColor, info);
            SetSpeedoColor(param1, info);
        }
        Premium_ShowLastMenu(param1);
    } else if(action == MenuAction_Cancel && param2 == MenuCancel_ExitBack) {
        Premium_ShowLastMenu(param1);
    }
}