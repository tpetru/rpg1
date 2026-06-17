// ============================================================
//  PLAYER.INC - Sistem Jucatori, Register/Login, Level, Payday
// ============================================================
#if defined _player_included
    #endinput
#endif
#define _player_included


// ============================================================
//  CONNECT / DISCONNECT
// ============================================================

// stock Player_OnConnect(playerid)
// {
//     // Resetare date
//     PlayerData[playerid][pID]           = 0;
//     PlayerData[playerid][pLevel]        = 1;
//     PlayerData[playerid][pXP]           = 0;
//     PlayerData[playerid][pMoney]        = 500;
//     PlayerData[playerid][pBank]         = 0;
//     PlayerData[playerid][pRP]           = 0;
//     PlayerData[playerid][pHealth]       = 100.0;
//     PlayerData[playerid][pArmour]       = 0.0;
//     PlayerData[playerid][pSkin]         = 0;
//     PlayerData[playerid][pFaction]      = FACTION_NONE;
//     PlayerData[playerid][pFactionRank]  = 0;
//     PlayerData[playerid][pJob]          = JOB_NONE;
//     PlayerData[playerid][pWanted]       = 0;
//     PlayerData[playerid][pJailed]       = false;
//     PlayerData[playerid][pJailTime]     = 0;
//     PlayerData[playerid][pFines]        = 0;
//     PlayerData[playerid][pSick]         = false;
//     PlayerData[playerid][pLogged]       = false;
//     PlayerData[playerid][pRegistered]   = false;
//     PlayerData[playerid][pLoginAttempts]= 0;
//     PlayerData[playerid][pAdminLevel]   = 0;
//     PlayerData[playerid][pOnDuty]       = false;
//     PlayerData[playerid][pInTour]       = false;
//     PlayerData[playerid][pCurrentTrade] = -1;

//     GetPlayerName(playerid, PlayerData[playerid][pName], 24);
//     TogglePlayerSpectating(playerid, 1);
//     Player_CheckExists(playerid);
// }

// stock Player_OnDisconnect(playerid, reason)
// {
//     if(PlayerData[playerid][pLogged])
//     {
//         Player_SaveData(playerid);
//         Pets_SaveAll(playerid);
//         Vehicles_SaveAll(playerid);
//     }

//     // Oprire timere
//     if(PlayerData[playerid][pDiseaseTimer])
//         KillTimer(PlayerData[playerid][pDiseaseTimer]);
//     if(PlayerData[playerid][pPlayTimer])
//         KillTimer(PlayerData[playerid][pPlayTimer]);

//     // Curata trade activ
//     if(PlayerData[playerid][pCurrentTrade] != -1)
//         Trade_Cancel(PlayerData[playerid][pCurrentTrade]);
// }

// stock Player_OnSpawn(playerid)
// {
//     if(!PlayerData[playerid][pLogged]) return;

//     SetPlayerSkin(playerid, PlayerData[playerid][pSkin]);
//     SetPlayerHealth(playerid, PlayerData[playerid][pHealth]);
//     SetPlayerArmour(playerid, PlayerData[playerid][pArmour]);
//     GivePlayerMoney(playerid, -GetPlayerMoney(playerid));
//     GivePlayerMoney(playerid, PlayerData[playerid][pMoney]);

//     if(PlayerData[playerid][pJailed])
//     {
//         SetPlayerPos(playerid, 264.35, 75.62, 1001.04);
//         SetPlayerInterior(playerid, 6);
//         return;
//     }

//     SetPlayerPos(playerid, PlayerData[playerid][pX], PlayerData[playerid][pY], PlayerData[playerid][pZ]);
//     SetPlayerInterior(playerid, PlayerData[playerid][pInterior]);
//     SetPlayerVirtualWorld(playerid, PlayerData[playerid][pVW]);

//     Player_StartPlayTimer(playerid);

//     if(PlayerData[playerid][pSick])
//         Disease_StartDecay(playerid);

//     // HUD info
//     Player_ShowHUD(playerid);
// }

// stock Player_OnDeath(playerid, killerid, reason)
// {
//     PlayerData[playerid][pDeaths]++;
//     if(killerid != INVALID_PLAYER_ID)
//         PlayerData[killerid][pKills]++;

//     // Salvare pozitie spital
//     PlayerData[playerid][pX] = 1185.89;
//     PlayerData[playerid][pY] = -1322.34;
//     PlayerData[playerid][pZ] = 13.58;
//     PlayerData[playerid][pInterior] = 0;
//     PlayerData[playerid][pHealth] = 50.0;
//     Player_SaveData(playerid);
// }

// stock Player_OnText(playerid, text[])
// {
//     if(!PlayerData[playerid][pLogged]) return 0;

//     new msg[144];
//     new name[24];
//     GetPlayerName(playerid, name, 24);

//     // Chat colorat dupa factiune
//     new color = COLOR_WHITE;
//     if(PlayerData[playerid][pFaction] > 0)
//         color = Faction_GetColor(PlayerData[playerid][pFaction]);

//     format(msg, sizeof(msg), "[Lv.%d] %s: %s",
//         PlayerData[playerid][pLevel], name, text);
//     SendClientMessageToAll(color, msg);
//     return 0;
// }

