// // ============================================================
// //  FACTIONS.INC - Sistem Factiuni
// // ============================================================
// #if defined _factions_included
//     #endinput
// #endif
// #define _factions_included

// new FactionColors[MAX_FACTIONS+1] = {
//     0xFFFFFFFF,   // 0 - none
//     0x003EB2FF,   // 1 - Politie Romana - albastru
//     0x005500FF,   // 2 - Politia Animalelor - verde inchis
//     0xFF6600FF,   // 3 - RAR - portocaliu
//     0xFF0000FF,   // 4 - SMURD - rosu
//     0xFFFF00FF,   // 5 - Reporteri - galben
//     0x8B0000FF,   // 6 - Mafia EU - rosu inchis
//     0x1C1C1CFF,   // 7 - Mafia Africana - negru
//     0xFF4500FF,   // 8 - Mafia Asiatica - portocaliu rosu
//     0x006400FF    // 9 - Mafia Americana - verde
// };

// new FactionNameStr[][32] = {
//     "Civil",
//     "Politia Romana",
//     "Politia Animalelor",
//     "Registrul Auto Roman",
//     "SMURD",
//     "Reporteri",
//     "Mafia Europeana",
//     "Mafia Africana",
//     "Mafia Asiatica",
//     "Mafia Americana"
// };

// stock Faction_GetName(factionid)
// {
//     if(factionid < 0 || factionid > MAX_FACTIONS) return "Necunoscut";
//     return FactionNameStr[factionid];
// }

// stock Faction_GetColor(factionid)
// {
//     if(factionid < 0 || factionid > MAX_FACTIONS) return COLOR_WHITE;
//     return FactionColors[factionid];
// }

// // Comenzi factiune
// CMD:factionmenu(playerid, params[])
// {
//     if(!PlayerData[playerid][pLogged]) return 1;
//     if(PlayerData[playerid][pFaction] == FACTION_NONE)
//         return SendMsg(playerid, COLOR_ERROR, "[!] Nu esti in nicio factiune!");

//     ShowPlayerDialog(playerid, DIALOG_FACTION_MENU, DIALOG_STYLE_MSGBOX,
//         "{FFD700}Factiunea Ta",
//         "Factiunea ta si membrii sai:\n"
//         "/fmembers - Lista membri\n"
//         "/finvite [jucator] - Invita (doar lider)\n"
//         "/fkick [jucator] - Elimina (doar lider)\n"
//         "/fpromote [jucator] [rang] - Promoveaza",
//         "Inchide", "");
//     return 1;
// }

// CMD:fmembers(playerid, params[])
// {
//     if(!PlayerData[playerid][pLogged]) return 1;
//     new fid = PlayerData[playerid][pFaction];
//     if(fid == FACTION_NONE) return SendMsg(playerid, COLOR_ERROR, "[!] Nu esti in factiune!");

//     new info[512];
//     new count = 0;
//     for(new i = 0; i < MAX_PLAYERS; i++)
//     {
//         if(!IsPlayerConnected(i) || PlayerData[i][pFaction] != fid) continue;
//         new line[48];
//         format(line, sizeof(line), "%s (Rang %d)\n", PlayerData[i][pName], PlayerData[i][pFactionRank]);
//         strcat(info, line);
//         count++;
//     }
//     if(!count) format(info, sizeof(info), "Niciun membru online.");
//     ShowPlayerDialog(playerid, 9999, DIALOG_STYLE_MSGBOX,
//         "Membri Factiune Online", info, "Inchide", "");
//     return 1;
// }

// CMD:finvite(playerid, params[])
// {
//     if(PlayerData[playerid][pFactionRank] < RANK_LEADER)
//         return SendMsg(playerid, COLOR_ERROR, "[!] Doar liderul poate invita!");

//     new targetid;
//     if(sscanf(params, "u", targetid))
//         return SendMsg(playerid, COLOR_ERROR, "Folosire: /finvite [jucator]");

//     if(PlayerData[targetid][pFaction] != FACTION_NONE)
//         return SendMsg(playerid, COLOR_ERROR, "[!] Jucatorul este deja in o factiune!");

//     PlayerData[targetid][pFaction]     = PlayerData[playerid][pFaction];
//     PlayerData[targetid][pFactionRank] = RANK_RECRUIT;
//     SetPlayerSkin(targetid, FactionSkins[PlayerData[targetid][pFaction]][0]);

//     new tname[24], fname[24];
//     GetPlayerName(playerid, fname, 24);
//     GetPlayerName(targetid, tname, 24);
//     SendMsgFmt(targetid, COLOR_SUCCESS, "[Factiune] Ai fost recrutat in %s de catre %s!",
//         Faction_GetName(PlayerData[targetid][pFaction]), fname);
//     SendMsgFmt(playerid, COLOR_SUCCESS, "[Factiune] L-ai recrutat pe %s.", tname);
//     Player_SaveData(targetid);
//     return 1;
// }

// CMD:fkick(playerid, params[])
// {
//     if(PlayerData[playerid][pFactionRank] < RANK_LEADER)
//         return SendMsg(playerid, COLOR_ERROR, "[!] Doar liderul poate elimina membri!");

//     new targetid;
//     if(sscanf(params, "u", targetid))
//         return SendMsg(playerid, COLOR_ERROR, "Folosire: /fkick [jucator]");

//     if(PlayerData[targetid][pFaction] != PlayerData[playerid][pFaction])
//         return SendMsg(playerid, COLOR_ERROR, "[!] Nu e in factiunea ta!");

//     PlayerData[targetid][pFaction]     = FACTION_NONE;
//     PlayerData[targetid][pFactionRank] = 0;
//     SendMsg(targetid, COLOR_ERROR, "[Factiune] Ai fost eliminat din factiune!");
//     SendMsg(playerid, COLOR_SUCCESS, "[Factiune] Jucatorul a fost eliminat.");
//     Player_SaveData(targetid);
//     return 1;
// }

// // Politie: Amenda, Wanted, Arestare
// CMD:fine(playerid, params[])
// {
//     if(PlayerData[playerid][pFaction] != FACTION_POLITIE)
//         return SendMsg(playerid, COLOR_ERROR, "[!] Doar politistii pot da amenzi!");

//     new targetid, amount;
//     new reason[32];
//     if(sscanf(params, "uis[32]", targetid, amount, reason))
//         return SendMsg(playerid, COLOR_ERROR, "Folosire: /fine [jucator] [suma] [motiv]");

//     if(!IsPlayerConnected(targetid))
//         return SendMsg(playerid, COLOR_ERROR, "[!] Jucator invalid!");
//     if(amount <= 0 || amount > 50000)
//         return SendMsg(playerid, COLOR_ERROR, "[!] Suma invalida! (1-50000)");

//     PlayerData[targetid][pFines] += amount;
//     SendMsgFmt(targetid, COLOR_RED, "[Politie] Ai primit o amenda de $%d. Motiv: %s.", amount, reason);
//     SendMsgFmt(playerid, COLOR_SUCCESS, "[Politie] Amenda de $%d aplicata.", amount);

//     new query[256];
//     mysql_format(g_SQL, query, sizeof(query),
//         "INSERT INTO `fines_log` (`officer_id`,`player_id`,`reason`,`amount`) VALUES (%d,%d,'%e',%d)",
//         PlayerData[playerid][pID], PlayerData[targetid][pID], reason, amount);
//     mysql_tquery(g_SQL, query, "", "", 0);
//     return 1;
// }

// CMD:wanted(playerid, params[])
// {
//     if(PlayerData[playerid][pFaction] != FACTION_POLITIE)
//         return SendMsg(playerid, COLOR_ERROR, "[!] Doar politistii pot da wanted!");

//     new targetid, stars;
//     if(sscanf(params, "ui", targetid, stars))
//         return SendMsg(playerid, COLOR_ERROR, "Folosire: /wanted [jucator] [stele 1-6]");

//     if(stars < 1 || stars > 6) return SendMsg(playerid, COLOR_ERROR, "[!] Stele: 1-6");
//     if(!IsPlayerConnected(targetid)) return SendMsg(playerid, COLOR_ERROR, "[!] Jucator invalid!");

//     PlayerData[targetid][pWanted] += stars;
//     if(PlayerData[targetid][pWanted] > 6) PlayerData[targetid][pWanted] = 6;
//     SetPlayerWantedLevel(targetid, PlayerData[targetid][pWanted]);

//     new tname[24];
//     GetPlayerName(targetid, tname, 24);
//     SendMsgFmt(playerid, COLOR_SUCCESS, "[Politie] %d stele wanted date lui %s.", stars, tname);
//     SendMsgFmt(targetid, COLOR_RED, "[Politie] Ai primit %d stele wanted!", stars);
//     return 1;
// }

// CMD:arrest(playerid, params[])
// {
//     if(PlayerData[playerid][pFaction] != FACTION_POLITIE)
//         return SendMsg(playerid, COLOR_ERROR, "[!] Doar politistii pot aresta!");

//     new targetid, jailtime;
//     if(sscanf(params, "ui", targetid, jailtime))
//         return SendMsg(playerid, COLOR_ERROR, "Folosire: /arrest [jucator] [minute]");

//     if(!IsPlayerConnected(targetid)) return SendMsg(playerid, COLOR_ERROR, "[!] Jucator invalid!");
//     if(PlayerData[targetid][pWanted] == 0) return SendMsg(playerid, COLOR_ERROR, "[!] Jucatorul nu are wanted!");
//     if(GetDistanceBetweenPlayers(playerid, targetid) > 3.0)
//         return SendMsg(playerid, COLOR_ERROR, "[!] Trebuie sa fii mai aproape!");
//     if(jailtime < 1 || jailtime > 60) return SendMsg(playerid, COLOR_ERROR, "[!] Timp: 1-60 minute");

//     PlayerData[targetid][pJailed]   = true;
//     PlayerData[targetid][pJailTime] = jailtime * 60;
//     PlayerData[targetid][pWanted]   = 0;
//     SetPlayerWantedLevel(targetid, 0);

//     SetPlayerPos(targetid, 264.35, 75.62, 1001.04);
//     SetPlayerInterior(targetid, 6);

//     SendMsgFmt(targetid, COLOR_RED,
//         "[Politie] Ai fost arestat pentru %d minute!", jailtime);
//     SendMsgFmt(playerid, COLOR_SUCCESS, "[Politie] Jucatorul a fost arestat.");

//     SetTimerEx("OnJailRelease", jailtime * 60 * 1000, false, "i", targetid);
//     return 1;
// }

// forward OnJailRelease(playerid);
// public OnJailRelease(playerid)
// {
//     if(!IsPlayerConnected(playerid)) return;
//     PlayerData[playerid][pJailed] = false;
//     SetPlayerPos(playerid, 264.35, 88.0, 1001.04);
//     SetPlayerInterior(playerid, 0);
//     SendMsg(playerid, COLOR_SUCCESS, "[Politie] Ai fost eliberat! Comporta-te!");
// }
