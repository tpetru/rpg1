// ============================================================
//  DISEASE.INC - Sistem Boli
// ============================================================
// #if defined _disease_included
//     #endinput
// #endif
// #define _disease_included

// enum E_DISEASE_DATA
// {
//     dID, dName[32], dDesc[128], dCreatedBy,
//     bool:dActive
// }

// new DiseaseList[MAX_DISEASES][E_DISEASE_DATA];
// new DiseaseCount = 0;

// // Timere decay
// new DiseaseDecayTimer[MAX_PLAYERS];

// stock Disease_StartDecay(playerid)
// {
//     if(DiseaseDecayTimer[playerid])
//         KillTimer(DiseaseDecayTimer[playerid]);
//     DiseaseDecayTimer[playerid] = SetTimerEx("OnDiseaseDecay", 60000, true, "i", playerid);
// }

// stock Disease_StopDecay(playerid)
// {
//     if(DiseaseDecayTimer[playerid])
//     {
//         KillTimer(DiseaseDecayTimer[playerid]);
//         DiseaseDecayTimer[playerid] = 0;
//     }
// }

// forward OnDiseaseDecay(playerid);
// public OnDiseaseDecay(playerid)
// {
//     if(!IsPlayerConnected(playerid) || !PlayerData[playerid][pSick]) return;
//     new Float:hp;
//     GetPlayerHealth(playerid, hp);
//     hp -= DISEASE_HP_DECAY;
//     if(hp < 1.0) hp = 1.0;
//     SetPlayerHealth(playerid, hp);
//     SendMsgFmt(playerid, COLOR_RED, "[Boala] Esti bolnav de %s! HP: %.0f. Mergi la spital!", PlayerData[playerid][pDiseaseName], hp);
// }

// // Admin creeaza boala noua si infecteaza playerii in raza
// CMD:createdisease(playerid, params[])
// {
//     if(!IsAdmin(playerid, 2)) return SendMsg(playerid, COLOR_ERROR, "[!] Doar adminii pot face asta!");

//     new dname[32], ddesc[64];
//     if(sscanf(params, "s[32]S[64](Boala necunoscuta)", dname, ddesc))
//         return SendMsg(playerid, COLOR_ERROR, "Folosire: /createdisease [nume] [descriere]");

//     // Salveaza boala in DB
//     new query[256];
//     mysql_format(g_SQL, query, sizeof(query),
//         "INSERT INTO `diseases` (`name`,`description`,`created_by`) VALUES ('%e','%e',%d)",
//         dname, ddesc, PlayerData[playerid][pID]);
//     mysql_tquery(g_SQL, query, "", "", 0);

//     // Infecteaza playerii in raza
//     new Float:px, Float:py, Float:pz;
//     GetPlayerPos(playerid, px, py, pz);
//     new infected = 0;

//     for(new i = 0; i < MAX_PLAYERS; i++)
//     {
//         if(!IsPlayerConnected(i) || !PlayerData[i][pLogged] || i == playerid) continue;
//         new Float:ix, Float:iy, Float:iz;
//         GetPlayerPos(i, ix, iy, iz);
//         if(VectorSize(px-ix, py-iy, pz-iz) <= DISEASE_RANGE)
//         {
//             if(!PlayerData[i][pSick])
//             {
//                 PlayerData[i][pSick] = true;
//                 format(PlayerData[i][pDiseaseName], 32, "%s", dname);
//                 Disease_StartDecay(i);
//                 SendMsgFmt(i, COLOR_RED,
//                     "[!] Ai fost infectat cu %s! Mergi urgent la spital la un medic SMURD.", dname);
//                 infected++;
//             }
//         }
//     }

//     SendMsgFmt(playerid, COLOR_SUCCESS,
//         "[Admin] Boala '%s' creata si %d jucatori infectati in raza de %.0fm.", dname, infected, DISEASE_RANGE);
//     return 1;
// }

// // SMURD: Trateaza boala la spital
// CMD:treat(playerid, params[])
// {
//     if(PlayerData[playerid][pFaction] != FACTION_SMURD)
//         return SendMsg(playerid, COLOR_ERROR, "[!] Doar SMURD-ul poate trata boli!");

//     new targetid;
//     if(sscanf(params, "u", targetid))
//         return SendMsg(playerid, COLOR_ERROR, "Folosire: /treat [jucator]");

//     if(!IsPlayerConnected(targetid))
//         return SendMsg(playerid, COLOR_ERROR, "[!] Jucator invalid!");

//     if(!PlayerData[targetid][pSick])
//         return SendMsg(playerid, COLOR_ERROR, "[!] Jucatorul nu este bolnav!");

//     // Trebuie sa fie la spital (interior)
//     if(GetPlayerInterior(playerid) == 0 && GetPlayerInterior(targetid) == 0)
//         return SendMsg(playerid, COLOR_ERROR, "[!] Trebuie sa fiti amandoi la spital!");

//     PlayerData[targetid][pSick] = false;
//     PlayerData[targetid][pDiseaseName] = "";
//     Disease_StopDecay(targetid);
//     SetPlayerHealth(targetid, 100.0);

//     new tname[24], dname[24];
//     GetPlayerName(targetid, tname, 24);
//     GetPlayerName(playerid, dname, 24);

//     SendMsgFmt(targetid, COLOR_SUCCESS, "[SMURD] %s te-a vindecat! Esti sanatos acum.", dname);
//     SendMsgFmt(playerid, COLOR_SUCCESS, "[SMURD] L-ai vindecat pe %s!", tname);
//     Player_AddXP(playerid, 100);

//     // Salveaza in DB
//     new query[256];
//     mysql_format(g_SQL, query, sizeof(query),
//         "UPDATE `players` SET `is_sick`=0,`disease_name`='' WHERE `id`=%d",
//         PlayerData[targetid][pID]);
//     mysql_tquery(g_SQL, query, "", "", 0);
//     return 1;
// }
