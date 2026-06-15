// ============================================================
//  FACTIONS.INC - Sistem Factiuni
// ============================================================
#if defined _factions_included
    #endinput
#endif
#define _factions_included

new FactionColors[MAX_FACTIONS+1] = {
    0xFFFFFFFF,   // 0 - none
    0x003EB2FF,   // 1 - Politie Romana - albastru
    0x005500FF,   // 2 - Politia Animalelor - verde inchis
    0xFF6600FF,   // 3 - RAR - portocaliu
    0xFF0000FF,   // 4 - SMURD - rosu
    0xFFFF00FF,   // 5 - Reporteri - galben
    0x8B0000FF,   // 6 - Mafia EU - rosu inchis
    0x1C1C1CFF,   // 7 - Mafia Africana - negru
    0xFF4500FF,   // 8 - Mafia Asiatica - portocaliu rosu
    0x006400FF    // 9 - Mafia Americana - verde
};

new FactionNameStr[][32] = {
    "Civil",
    "Politia Romana",
    "Politia Animalelor",
    "Registrul Auto Roman",
    "SMURD",
    "Reporteri",
    "Mafia Europeana",
    "Mafia Africana",
    "Mafia Asiatica",
    "Mafia Americana"
};

stock Faction_GetName(factionid)
{
    if(factionid < 0 || factionid > MAX_FACTIONS) return "Necunoscut";
    return FactionNameStr[factionid];
}

stock Faction_GetColor(factionid)
{
    if(factionid < 0 || factionid > MAX_FACTIONS) return COLOR_WHITE;
    return FactionColors[factionid];
}

// Comenzi factiune
CMD:factionmenu(playerid, params[])
{
    if(!PlayerData[playerid][pLogged]) return 1;
    if(PlayerData[playerid][pFaction] == FACTION_NONE)
        return SendMsg(playerid, COLOR_ERROR, "[!] Nu esti in nicio factiune!");

    ShowPlayerDialog(playerid, DIALOG_FACTION_MENU, DIALOG_STYLE_MSGBOX,
        "{FFD700}Factiunea Ta",
        "Factiunea ta si membrii sai:\n"
        "/fmembers - Lista membri\n"
        "/finvite [jucator] - Invita (doar lider)\n"
        "/fkick [jucator] - Elimina (doar lider)\n"
        "/fpromote [jucator] [rang] - Promoveaza",
        "Inchide", "");
    return 1;
}

CMD:fmembers(playerid, params[])
{
    if(!PlayerData[playerid][pLogged]) return 1;
    new fid = PlayerData[playerid][pFaction];
    if(fid == FACTION_NONE) return SendMsg(playerid, COLOR_ERROR, "[!] Nu esti in factiune!");

    new info[512];
    new count = 0;
    for(new i = 0; i < MAX_PLAYERS; i++)
    {
        if(!IsPlayerConnected(i) || PlayerData[i][pFaction] != fid) continue;
        new line[48];
        format(line, sizeof(line), "%s (Rang %d)\n", PlayerData[i][pName], PlayerData[i][pFactionRank]);
        strcat(info, line);
        count++;
    }
    if(!count) format(info, sizeof(info), "Niciun membru online.");
    ShowPlayerDialog(playerid, 9999, DIALOG_STYLE_MSGBOX,
        "Membri Factiune Online", info, "Inchide", "");
    return 1;
}

CMD:finvite(playerid, params[])
{
    if(PlayerData[playerid][pFactionRank] < RANK_LEADER)
        return SendMsg(playerid, COLOR_ERROR, "[!] Doar liderul poate invita!");

    new targetid;
    if(sscanf(params, "u", targetid))
        return SendMsg(playerid, COLOR_ERROR, "Folosire: /finvite [jucator]");

    if(PlayerData[targetid][pFaction] != FACTION_NONE)
        return SendMsg(playerid, COLOR_ERROR, "[!] Jucatorul este deja in o factiune!");

    PlayerData[targetid][pFaction]     = PlayerData[playerid][pFaction];
    PlayerData[targetid][pFactionRank] = RANK_RECRUIT;
    SetPlayerSkin(targetid, FactionSkins[PlayerData[targetid][pFaction]][0]);

    new tname[24], fname[24];
    GetPlayerName(playerid, fname, 24);
    GetPlayerName(targetid, tname, 24);
    SendMsgFmt(targetid, COLOR_SUCCESS, "[Factiune] Ai fost recrutat in %s de catre %s!",
        Faction_GetName(PlayerData[targetid][pFaction]), fname);
    SendMsgFmt(playerid, COLOR_SUCCESS, "[Factiune] L-ai recrutat pe %s.", tname);
    Player_SaveData(targetid);
    return 1;
}

CMD:fkick(playerid, params[])
{
    if(PlayerData[playerid][pFactionRank] < RANK_LEADER)
        return SendMsg(playerid, COLOR_ERROR, "[!] Doar liderul poate elimina membri!");

    new targetid;
    if(sscanf(params, "u", targetid))
        return SendMsg(playerid, COLOR_ERROR, "Folosire: /fkick [jucator]");

    if(PlayerData[targetid][pFaction] != PlayerData[playerid][pFaction])
        return SendMsg(playerid, COLOR_ERROR, "[!] Nu e in factiunea ta!");

    PlayerData[targetid][pFaction]     = FACTION_NONE;
    PlayerData[targetid][pFactionRank] = 0;
    SendMsg(targetid, COLOR_ERROR, "[Factiune] Ai fost eliminat din factiune!");
    SendMsg(playerid, COLOR_SUCCESS, "[Factiune] Jucatorul a fost eliminat.");
    Player_SaveData(targetid);
    return 1;
}

// Politie: Amenda, Wanted, Arestare
CMD:fine(playerid, params[])
{
    if(PlayerData[playerid][pFaction] != FACTION_POLITIE)
        return SendMsg(playerid, COLOR_ERROR, "[!] Doar politistii pot da amenzi!");

    new targetid, amount;
    new reason[32];
    if(sscanf(params, "uis[32]", targetid, amount, reason))
        return SendMsg(playerid, COLOR_ERROR, "Folosire: /fine [jucator] [suma] [motiv]");

    if(!IsPlayerConnected(targetid))
        return SendMsg(playerid, COLOR_ERROR, "[!] Jucator invalid!");
    if(amount <= 0 || amount > 50000)
        return SendMsg(playerid, COLOR_ERROR, "[!] Suma invalida! (1-50000)");

    PlayerData[targetid][pFines] += amount;
    SendMsgFmt(targetid, COLOR_RED, "[Politie] Ai primit o amenda de $%d. Motiv: %s.", amount, reason);
    SendMsgFmt(playerid, COLOR_SUCCESS, "[Politie] Amenda de $%d aplicata.", amount);

    new query[256];
    mysql_format(g_SQL, query, sizeof(query),
        "INSERT INTO `fines_log` (`officer_id`,`player_id`,`reason`,`amount`) VALUES (%d,%d,'%e',%d)",
        PlayerData[playerid][pID], PlayerData[targetid][pID], reason, amount);
    mysql_tquery(g_SQL, query, "", "", 0);
    return 1;
}

CMD:wanted(playerid, params[])
{
    if(PlayerData[playerid][pFaction] != FACTION_POLITIE)
        return SendMsg(playerid, COLOR_ERROR, "[!] Doar politistii pot da wanted!");

    new targetid, stars;
    if(sscanf(params, "ui", targetid, stars))
        return SendMsg(playerid, COLOR_ERROR, "Folosire: /wanted [jucator] [stele 1-6]");

    if(stars < 1 || stars > 6) return SendMsg(playerid, COLOR_ERROR, "[!] Stele: 1-6");
    if(!IsPlayerConnected(targetid)) return SendMsg(playerid, COLOR_ERROR, "[!] Jucator invalid!");

    PlayerData[targetid][pWanted] += stars;
    if(PlayerData[targetid][pWanted] > 6) PlayerData[targetid][pWanted] = 6;
    SetPlayerWantedLevel(targetid, PlayerData[targetid][pWanted]);

    new tname[24];
    GetPlayerName(targetid, tname, 24);
    SendMsgFmt(playerid, COLOR_SUCCESS, "[Politie] %d stele wanted date lui %s.", stars, tname);
    SendMsgFmt(targetid, COLOR_RED, "[Politie] Ai primit %d stele wanted!", stars);
    return 1;
}

CMD:arrest(playerid, params[])
{
    if(PlayerData[playerid][pFaction] != FACTION_POLITIE)
        return SendMsg(playerid, COLOR_ERROR, "[!] Doar politistii pot aresta!");

    new targetid, jailtime;
    if(sscanf(params, "ui", targetid, jailtime))
        return SendMsg(playerid, COLOR_ERROR, "Folosire: /arrest [jucator] [minute]");

    if(!IsPlayerConnected(targetid)) return SendMsg(playerid, COLOR_ERROR, "[!] Jucator invalid!");
    if(PlayerData[targetid][pWanted] == 0) return SendMsg(playerid, COLOR_ERROR, "[!] Jucatorul nu are wanted!");
    if(GetDistanceBetweenPlayers(playerid, targetid) > 3.0)
        return SendMsg(playerid, COLOR_ERROR, "[!] Trebuie sa fii mai aproape!");
    if(jailtime < 1 || jailtime > 60) return SendMsg(playerid, COLOR_ERROR, "[!] Timp: 1-60 minute");

    PlayerData[targetid][pJailed]   = true;
    PlayerData[targetid][pJailTime] = jailtime * 60;
    PlayerData[targetid][pWanted]   = 0;
    SetPlayerWantedLevel(targetid, 0);

    SetPlayerPos(targetid, 264.35, 75.62, 1001.04);
    SetPlayerInterior(targetid, 6);

    SendMsgFmt(targetid, COLOR_RED,
        "[Politie] Ai fost arestat pentru %d minute!", jailtime);
    SendMsgFmt(playerid, COLOR_SUCCESS, "[Politie] Jucatorul a fost arestat.");

    SetTimerEx("OnJailRelease", jailtime * 60 * 1000, false, "i", targetid);
    return 1;
}

forward OnJailRelease(playerid);
public OnJailRelease(playerid)
{
    if(!IsPlayerConnected(playerid)) return;
    PlayerData[playerid][pJailed] = false;
    SetPlayerPos(playerid, 264.35, 88.0, 1001.04);
    SetPlayerInterior(playerid, 0);
    SendMsg(playerid, COLOR_SUCCESS, "[Politie] Ai fost eliberat! Comporta-te!");
}

// ============================================================
//  MAFIA.INC
// ============================================================

enum E_MAFIA_FINANCE
{
    mfFactionID, mfBank, Float:mfGold, Float:mfDrugs, mfMaterials
}

new MafiaFinance[4][E_MAFIA_FINANCE]; // 4 mafii: EU/AF/AS/AM

enum E_TERRITORY
{
    tID, tName[32], tOwnerFaction, tIncome,
    Float:tX, Float:tY, Float:tZ, Float:tRadius,
    tAreaID
}

new TerritoryData[MAX_TERRITORIES][E_TERRITORY];
new TerritoryCount = 0;

stock Mafia_Init()
{
    // Initializeaza finantele
    new fids[] = {FACTION_MAFIA_EU, FACTION_MAFIA_AF, FACTION_MAFIA_AS, FACTION_MAFIA_AM};
    for(new i = 0; i < 4; i++)
    {
        MafiaFinance[i][mfFactionID] = fids[i];
        mysql_tquery(g_SQL,
            "SELECT * FROM `mafia_finance` WHERE `faction_id`=?",
            "OnMafiaFinanceLoaded", "i", fids[i]);
    }

    // Incarca teritorii
    mysql_tquery(g_SQL, "SELECT * FROM `territories`", "OnTerritoriesLoaded", "", 0);
    print("[Mafia] Sistem mafia incarcat.");
}

forward OnMafiaFinanceLoaded(factionid);
public OnMafiaFinanceLoaded(factionid)
{
    new idx = -1;
    for(new i = 0; i < 4; i++)
    {
        if(MafiaFinance[i][mfFactionID] == factionid) { idx = i; break; }
    }
    if(idx == -1) return;

    if(cache_num_rows() == 0)
    {
        // Insert row nou
        new query[128];
        mysql_format(g_SQL, query, sizeof(query),
            "INSERT INTO `mafia_finance` (`faction_id`) VALUES (%d)", factionid);
        mysql_tquery(g_SQL, query, "", "", 0);
        return;
    }
    cache_get_value_name_int(0, "bank", MafiaFinance[idx][mfBank]);
    cache_get_value_name_float(0, "gold", MafiaFinance[idx][mfGold]);
    cache_get_value_name_float(0, "drugs", MafiaFinance[idx][mfDrugs]);
    cache_get_value_name_int(0, "materials", MafiaFinance[idx][mfMaterials]);
}

forward OnTerritoriesLoaded();
public OnTerritoriesLoaded()
{
    TerritoryCount = cache_num_rows();
    for(new i = 0; i < TerritoryCount; i++)
    {
        cache_get_value_name_int(i, "id", TerritoryData[i][tID]);
        cache_get_value_name(i, "name", TerritoryData[i][tName], 32);
        cache_get_value_name_int(i, "owner_faction", TerritoryData[i][tOwnerFaction]);
        cache_get_value_name_int(i, "income", TerritoryData[i][tIncome]);
        cache_get_value_name_float(i, "pos_x", TerritoryData[i][tX]);
        cache_get_value_name_float(i, "pos_y", TerritoryData[i][tY]);
        cache_get_value_name_float(i, "pos_z", TerritoryData[i][tZ]);
        cache_get_value_name_float(i, "radius", TerritoryData[i][tRadius]);

        TerritoryData[i][tAreaID] = CreateDynamicCircle(
            TerritoryData[i][tX], TerritoryData[i][tY],
            TerritoryData[i][tRadius], -1, -1
        );
    }
    new msg[48];
    format(msg, sizeof(msg), "[Mafia] %d teritorii incarcate.", TerritoryCount);
    print(msg);
}

stock Mafia_GetFinanceIdx(factionid)
{
    for(new i = 0; i < 4; i++)
        if(MafiaFinance[i][mfFactionID] == factionid) return i;
    return -1;
}

stock Mafia_OnEnterArea(playerid, areaid)
{
    for(new i = 0; i < TerritoryCount; i++)
    {
        if(TerritoryData[i][tAreaID] == areaid)
        {
            new owner = TerritoryData[i][tOwnerFaction];
            if(owner == FACTION_NONE)
                SendMsgFmt(playerid, COLOR_YELLOW, "[Teritoriu] Zona neutra: %s. Captura cu /capturezone.", TerritoryData[i][tName]);
            else
                SendMsgFmt(playerid, COLOR_ORANGE, "[Teritoriu] Zona %s apartine %s.",
                    TerritoryData[i][tName], Faction_GetName(owner));
            return;
        }
    }
}

CMD:capturezone(playerid, params[])
{
    new fid = PlayerData[playerid][pFaction];
    if(fid < FACTION_MAFIA_EU || fid > FACTION_MAFIA_AM)
        return SendMsg(playerid, COLOR_ERROR, "[!] Doar mafiotii pot captura zone!");

    new Float:px, Float:py, Float:pz;
    GetPlayerPos(playerid, px, py, pz);
    new tid = -1;
    for(new i = 0; i < TerritoryCount; i++)
    {
        if(VectorSize(px-TerritoryData[i][tX], py-TerritoryData[i][tY], 0.0) < TerritoryData[i][tRadius])
        {
            tid = i; break;
        }
    }
    if(tid == -1) return SendMsg(playerid, COLOR_ERROR, "[!] Nu esti intr-o zona de capturat!");
    if(TerritoryData[tid][tOwnerFaction] == fid)
        return SendMsg(playerid, COLOR_ERROR, "[!] Zona apartine deja mafiei tale!");

    // Captura simplificata (in realitate ar dura 60 secunde si ar necesita mai multi membri)
    new old = TerritoryData[tid][tOwnerFaction];
    TerritoryData[tid][tOwnerFaction] = fid;

    new query[128];
    mysql_format(g_SQL, query, sizeof(query),
        "UPDATE `territories` SET `owner_faction`=%d WHERE `id`=%d",
        fid, TerritoryData[tid][tID]);
    mysql_tquery(g_SQL, query, "", "", 0);

    new msg[128];
    format(msg, sizeof(msg), "[Teritoriu] %s a capturat zona '%s' de la %s!",
        Faction_GetName(fid), TerritoryData[tid][tName],
        old == 0 ? "neutru" : Faction_GetName(old));
    SendMsgAll(COLOR_ORANGE, msg);
    return 1;
}

CMD:mafiabank(playerid, params[])
{
    new fid = PlayerData[playerid][pFaction];
    if(fid < FACTION_MAFIA_EU || fid > FACTION_MAFIA_AM)
        return SendMsg(playerid, COLOR_ERROR, "[!] Nu esti in nicio mafia!");

    new idx = Mafia_GetFinanceIdx(fid);
    if(idx == -1) return 1;

    new action[8], amount;
    if(sscanf(params, "si", action, amount))
        return SendMsg(playerid, COLOR_ERROR, "Folosire: /mafiabank [depune/retrage] [suma]");

    if(!strcmp(action, "depune", true))
    {
        if(GetPlayerMoney(playerid) < amount)
            return SendMsg(playerid, COLOR_ERROR, "[!] Nu ai suficienti bani!");
        GivePlayerMoney(playerid, -amount);
        PlayerData[playerid][pMoney] -= amount;
        MafiaFinance[idx][mfBank] += amount;
        SendMsgFmt(playerid, COLOR_SUCCESS, "[Mafia] Ai depus $%d in banca mafiei.", amount);
    }
    else if(!strcmp(action, "retrage", true))
    {
        if(PlayerData[playerid][pFactionRank] < RANK_OFFICER)
            return SendMsg(playerid, COLOR_ERROR, "[!] Nevoie de rang Ofiter+!");
        if(MafiaFinance[idx][mfBank] < amount)
            return SendMsg(playerid, COLOR_ERROR, "[!] Banca mafiei nu are suficienti bani!");
        GivePlayerMoney(playerid, amount);
        PlayerData[playerid][pMoney] += amount;
        MafiaFinance[idx][mfBank] -= amount;
        SendMsgFmt(playerid, COLOR_SUCCESS, "[Mafia] Ai retras $%d din banca mafiei.", amount);
    }

    // Salveaza
    new query[128], idx2 = idx;
    mysql_format(g_SQL, query, sizeof(query),
        "UPDATE `mafia_finance` SET `bank`=%d WHERE `faction_id`=%d",
        MafiaFinance[idx2][mfBank], fid);
    mysql_tquery(g_SQL, query, "", "", 0);
    return 1;
}

// ============================================================
//  JOBS.INC - Joburi
// ============================================================

new JobNames[][20] = {
    "Niciun job",
    "Detectiv",
    "Bolt Food",
    "Uber",
    "Mecanic",
    "Fermier",
    "Truck Driver",
    "Pescar (Legal)",
    "Padurar",
    "Salvamar"
};

stock Job_GetName(jobid)
{
    if(jobid < 0 || jobid >= sizeof(JobNames)) return "Necunoscut";
    return JobNames[jobid];
}

// Uber
new bool:UberOnDuty[MAX_PLAYERS] = {false, ...};

CMD:duty(playerid, params[])
{
    if(!PlayerData[playerid][pLogged]) return 1;
    new job = PlayerData[playerid][pJob];
    if(job == JOB_NONE) return SendMsg(playerid, COLOR_ERROR, "[!] Nu ai un job! Foloseste /job.");

    PlayerData[playerid][pOnDuty] = !PlayerData[playerid][pOnDuty];

    if(job == JOB_UBER)
    {
        UberOnDuty[playerid] = PlayerData[playerid][pOnDuty];
        new vehicleid = GetPlayerVehicleID(playerid);
        if(vehicleid)
        {
            if(PlayerData[playerid][pOnDuty])
            {
                ChangeVehicleColor(vehicleid, 0, 0); // negru
                new label[32];
                format(label, sizeof(label), "~b~Uber~n~~w~Disponibil");
                // In practica: Attach3DTextLabel la vehicul
            }
        }
    }

    SendMsgFmt(playerid, COLOR_SUCCESS, "[Job] %s: %s",
        Job_GetName(job), PlayerData[playerid][pOnDuty] ? "ON DUTY" : "OFF DUTY");
    return 1;
}

CMD:service(playerid, params[])
{
    if(!PlayerData[playerid][pLogged]) return 1;
    new service[16];
    if(sscanf(params, "s[16]", service))
        return SendMsg(playerid, COLOR_ERROR, "Folosire: /service [uber/mecanic]");

    if(!strcmp(service, "uber", true))
    {
        // Gaseste cei mai apropiati 5 uberi
        new Float:px, Float:py, Float:pz;
        GetPlayerPos(playerid, px, py, pz);

        new ubers[5], ucnt = 0;
        // Sortare simpla dupa distanta
        for(new i = 0; i < MAX_PLAYERS && ucnt < 5; i++)
        {
            if(!IsPlayerConnected(i) || !UberOnDuty[i] || i == playerid) continue;
            if(PlayerData[i][pJob] != JOB_UBER) continue;
            ubers[ucnt++] = i;
        }

        if(ucnt == 0) return SendMsg(playerid, COLOR_ERROR, "[!] Niciun Uber disponibil acum!");

        new pname[24];
        GetPlayerName(playerid, pname, 24);
        for(new j = 0; j < ucnt; j++)
        {
            SetPVarInt(ubers[j], "UberRequestFrom", playerid);
            SendMsgFmt(ubers[j], COLOR_YELLOW,
                "[UBER] Cerere noua de la %s! Foloseste /acceptuber pentru a accepta.", pname);
        }
        SendMsg(playerid, COLOR_YELLOW, "[UBER] Cerere trimisa! Asteapta confirmarea unui sofer.");
    }
    else if(!strcmp(service, "mecanic", true))
    {
        // Similar cu uber, notifica mecanicii disponibili
        new count = 0;
        for(new i = 0; i < MAX_PLAYERS; i++)
        {
            if(!IsPlayerConnected(i) || PlayerData[i][pJob] != JOB_MECANIC || !PlayerData[i][pOnDuty]) continue;
            SetPVarInt(i, "MechanicRequestFrom", playerid);
            SendMsgFmt(i, COLOR_YELLOW, "[Mecanic] Cerere de la %s! Foloseste /acceptmechanic.", PlayerData[playerid][pName]);
            count++;
            if(count >= 3) break;
        }
        if(!count) return SendMsg(playerid, COLOR_ERROR, "[!] Niciun mecanic disponibil!");
        SendMsg(playerid, COLOR_YELLOW, "[Mecanic] Cerere trimisa mecanicilor disponibili!");
    }
    return 1;
}

CMD:acceptuber(playerid, params[])
{
    if(PlayerData[playerid][pJob] != JOB_UBER || !PlayerData[playerid][pOnDuty])
        return SendMsg(playerid, COLOR_ERROR, "[!] Nu esti uber on-duty!");

    new clientid = GetPVarInt(playerid, "UberRequestFrom");
    if(!clientid || !IsPlayerConnected(clientid))
        return SendMsg(playerid, COLOR_ERROR, "[!] Nu ai cereri active!");

    new cname[24];
    GetPlayerName(clientid, cname, 24);
    SendMsgFmt(playerid, COLOR_SUCCESS, "[UBER] Cursa acceptata! Client: %s.", cname);
    SendMsgFmt(clientid, COLOR_SUCCESS, "[UBER] Soferul %s vine spre tine!", PlayerData[playerid][pName]);

    SetPVarInt(playerid, "UberClient", clientid);
    SetPVarInt(clientid, "UberDriver", playerid);
    DeletePVar(playerid, "UberRequestFrom");
    return 1;
}

CMD:job(playerid, params[])
{
    if(!PlayerData[playerid][pLogged]) return 1;
    new info[] =
        "Detectiv ($800/misiune)\n"
        "Bolt Food ($500/livrare)\n"
        "Uber ($600/cursa)\n"
        "Mecanic ($700/reparatie)\n"
        "Fermier ($400/ora)\n"
        "Truck Driver ($1200/livrare)\n"
        "Pescar Legal ($300/vanzare)\n"
        "Padurar ($500/tura)\n"
        "Salvamar ($450/tura)";
    ShowPlayerDialog(playerid, DIALOG_JOB_SELECT, DIALOG_STYLE_LIST,
        "{FFD700}Alege Job", info, "Selecteaza", "Inchide");
    return 1;
}

CMD:find(playerid, params[])
{
    if(PlayerData[playerid][pJob] != JOB_DETECTIV)
        return SendMsg(playerid, COLOR_ERROR, "[!] Doar detectivii pot folosi /find!");

    new cost = 500;
    if(GetPlayerMoney(playerid) < cost)
        return SendMsgFmt(playerid, COLOR_ERROR, "[!] Ai nevoie de $%d.", cost);

    new targetid;
    if(sscanf(params, "u", targetid))
        return SendMsg(playerid, COLOR_ERROR, "Folosire: /find [jucator]");

    if(!IsPlayerConnected(targetid))
        return SendMsg(playerid, COLOR_ERROR, "[!] Jucatorul nu este online!");

    GivePlayerMoney(playerid, -cost);
    PlayerData[playerid][pMoney] -= cost;

    new Float:tx, Float:ty, Float:tz;
    GetPlayerPos(targetid, tx, ty, tz);
    new tname[24];
    GetPlayerName(targetid, tname, 24);

    SendMsgFmt(playerid, COLOR_YELLOW,
        "[Detectiv] %s se afla la coordonatele: X=%.2f Y=%.2f Z=%.2f (Interior: %d)",
        tname, tx, ty, tz, GetPlayerInterior(targetid));

    SetPlayerCheckpoint(playerid, tx, ty, tz, 5.0);
    return 1;
}

CMD:repair(playerid, params[])
{
    if(PlayerData[playerid][pJob] != JOB_MECANIC || !PlayerData[playerid][pOnDuty])
        return SendMsg(playerid, COLOR_ERROR, "[!] Esti mecanic on-duty?");

    new targetid;
    if(sscanf(params, "u", targetid))
        return SendMsg(playerid, COLOR_ERROR, "Folosire: /repair [jucator]");

    if(targetid == playerid)
        return SendMsg(playerid, COLOR_ERROR, "[!] Nu iti poti repara propria masina!");

    new vehicleid = GetPlayerVehicleID(targetid);
    if(!vehicleid) return SendMsg(playerid, COLOR_ERROR, "[!] Jucatorul nu e in vehicul!");

    if(GetDistanceBetweenPlayers(playerid, targetid) > 5.0)
        return SendMsg(playerid, COLOR_ERROR, "[!] Trebuie sa fii mai aproape!");

    RepairVehicle(vehicleid);
    new cost = 1500;
    if(GetPlayerMoney(targetid) >= cost)
    {
        GivePlayerMoney(targetid, -cost);
        GivePlayerMoney(playerid, cost);
        PlayerData[targetid][pMoney] -= cost;
        PlayerData[playerid][pMoney] += cost;
    }

    new tname[24];
    GetPlayerName(targetid, tname, 24);
    SendMsgFmt(playerid, COLOR_SUCCESS, "[Mecanic] Masina lui %s reparata! Ai primit $%d.", tname, cost);
    SendMsgFmt(targetid, COLOR_SUCCESS, "[Mecanic] Masina ta a fost reparata de %s. Cost: $%d.",
        PlayerData[playerid][pName], cost);
    Player_AddXP(playerid, 30);
    return 1;
}

stock Jobs_OnCheckpoint(playerid)
{
    // Checkpoint BoltFood/Truck
    if(PlayerData[playerid][pJob] == JOB_BOLT_FOOD && PlayerData[playerid][pOnDuty])
    {
        SendMsg(playerid, COLOR_SUCCESS, "[Bolt Food] Livrare finalizata! Ai primit $500.");
        GivePlayerMoney(playerid, 500);
        PlayerData[playerid][pMoney] += 500;
        Player_AddXP(playerid, 20);
        DisablePlayerCheckpoint(playerid);
    }
    else if(PlayerData[playerid][pJob] == JOB_TRUCK && PlayerData[playerid][pOnDuty])
    {
        SendMsg(playerid, COLOR_SUCCESS, "[Truck] Livrare finalizata! Ai primit $1200.");
        GivePlayerMoney(playerid, 1200);
        PlayerData[playerid][pMoney] += 1200;
        Player_AddXP(playerid, 50);
        DisablePlayerCheckpoint(playerid);
    }
    return 1;
}

// ============================================================
//  PAYDAY.INC
// ============================================================

new PaydayTimer;

stock Payday_Init()
{
    PaydayTimer = SetTimer("OnPayday", PAYDAY_INTERVAL, true);
    print("[Payday] Timer payday setat la 30 minute.");
}

forward OnPayday();
public OnPayday()
{
    new h = GetServerHour();
    new msg[128];
    format(msg, sizeof(msg), "[PAYDAY] Payday! Toti jucatorii logati isi primesc salariul.");
    SendMsgAll(COLOR_GOLD, msg);

    for(new i = 0; i < MAX_PLAYERS; i++)
    {
        if(!IsPlayerConnected(i) || !PlayerData[i][pLogged]) continue;

        // Calcul salariu
        new salary = SALARY_BASE + (PlayerData[i][pLevel] * SALARY_PER_LEVEL);

        // Impozit presedinte
        new tax   = (salary * IncomeTax) / 100;
        new cass  = (salary * CASSTax)   / 100;
        new final_salary = salary - tax - cass;
        if(final_salary < 0) final_salary = 0;

        // Business income
        new business_income = 0;
        for(new b = 0; b < MAX_BUSINESSES; b++)
        {
            // inclus in business.inc; placeholder
            // if(BusinessData[b][bOwnerID] == PlayerData[i][pID]) business_income += BusinessData[b][bIncome];
        }

        GivePlayerMoney(i, final_salary + business_income);
        PlayerData[i][pMoney] += final_salary + business_income;
        PlayerData[i][pRP]    += RP_PER_PAYDAY;
        Player_AddXP(i, 50);

        // Taxe casa
        new houseid = GetPlayerOwnedHouse(i);
        if(houseid != -1 && HouseData[houseid][hTaxes] > 0)
        {
            if(GetPlayerMoney(i) >= HouseData[houseid][hTaxes])
            {
                GivePlayerMoney(i, -HouseData[houseid][hTaxes]);
                PlayerData[i][pMoney] -= HouseData[houseid][hTaxes];
            }
        }

        // Decay pet
        Pets_PaydayDecay(i);

        SendMsgFmt(i, COLOR_GOLD,
            "[PAYDAY] Salariu: $%d | Impozit: $%d | CASS: $%d | Net: $%d | +%d RP",
            salary, tax, cass, final_salary, RP_PER_PAYDAY);
    }

    // Payday mafia (teritorii) la ora 00:00
    if(h == 0)
    {
        Mafia_TerritoryPayday();
    }

    // Respawn animale la payday
    HuntingFishing_SpawnAll();
}

stock Mafia_TerritoryPayday()
{
    new incomes[4] = {0, 0, 0, 0};
    new fids[] = {FACTION_MAFIA_EU, FACTION_MAFIA_AF, FACTION_MAFIA_AS, FACTION_MAFIA_AM};

    for(new t = 0; t < TerritoryCount; t++)
    {
        for(new f = 0; f < 4; f++)
        {
            if(TerritoryData[t][tOwnerFaction] == fids[f])
                incomes[f] += TerritoryData[t][tIncome];
        }
    }

    for(new f = 0; f < 4; f++)
    {
        if(incomes[f] == 0) continue;
        new idx = Mafia_GetFinanceIdx(fids[f]);
        if(idx == -1) continue;
        MafiaFinance[idx][mfBank] += incomes[f];

        new query[128];
        mysql_format(g_SQL, query, sizeof(query),
            "UPDATE `mafia_finance` SET `bank`=%d WHERE `faction_id`=%d",
            MafiaFinance[idx][mfBank], fids[f]);
        mysql_tquery(g_SQL, query, "", "", 0);

        // Notifica membrii online
        new msg[64];
        format(msg, sizeof(msg), "[Mafia] Teritorii: +$%d in contul mafiei!", incomes[f]);
        NotifyFaction(fids[f], COLOR_GOLD, msg);
    }
}

// ============================================================
//  TOURS.INC - Plimbari organizate
// ============================================================

enum E_TOUR_DATA
{
    tourID, tourLeaderID, tourType,
    tourName[64], bool:tourActive,
    tourMemberCount,
    tourMembers[20]
}

new TourList[MAX_TOURS][E_TOUR_DATA];
new ActiveTours = 0;

new TourTypeNames[][16] = {"Munte", "Plaja", "Padure", "Sate"};

// Puncte de tur predefinite
new Float:TourPoints[4][5][3] = {
    // Munte
    {{-2400.0, -380.0, 35.0}, {-2600.0, -400.0, 55.0}, {-2700.0, -420.0, 80.0}, {-2800.0, -450.0, 110.0}, {-2900.0, -470.0, 130.0}},
    // Plaja
    {{-1700.0, -1100.0, 0.0}, {-1800.0, -1000.0, 0.0}, {-1900.0, -900.0, 0.0}, {-2000.0, -800.0, 0.0}, {-2100.0, -700.0, 0.0}},
    // Padure
    {{-1400.0, 2300.0, 30.0}, {-1500.0, 2200.0, 35.0}, {-1600.0, 2100.0, 40.0}, {-1700.0, 2000.0, 35.0}, {-1800.0, 1900.0, 30.0}},
    // Sate
    {{1000.0, -700.0, 20.0}, {1100.0, -600.0, 22.0}, {1200.0, -500.0, 25.0}, {1300.0, -400.0, 24.0}, {1400.0, -300.0, 23.0}}
};

stock Tours_Init()
{
    print("[Tours] Sistem tururi incarcat.");
}

stock Tour_GetSlot()
{
    for(new i = 0; i < MAX_TOURS; i++)
        if(!TourList[i][tourActive]) return i;
    return -1;
}

CMD:createtour(playerid, params[])
{
    if(!PlayerData[playerid][pLogged]) return 1;

    // Doar padurari, salvamari, ghizi (job JOB_PADURAR sau JOB_SALVAMAR)
    new job = PlayerData[playerid][pJob];
    if(job != JOB_PADURAR && job != JOB_SALVAMAR && !IsAdmin(playerid, 1))
        return SendMsg(playerid, COLOR_ERROR, "[!] Doar padurarii, salvamarii si adminii pot crea tururi!");

    new info[] = "Munte\nPlaja\nPadure\nSate";
    ShowPlayerDialog(playerid, DIALOG_TOUR_SELECT_TYPE, DIALOG_STYLE_LIST,
        "{FFD700}Tip Tur", info, "Creeaza", "Anuleaza");
    return 1;
}

CMD:jointour(playerid, params[])
{
    if(!PlayerData[playerid][pLogged]) return 1;
    if(ActiveTours == 0) return SendMsg(playerid, COLOR_ERROR, "[!] Nu exista tururi active acum!");

    new info[512];
    for(new i = 0; i < MAX_TOURS; i++)
    {
        if(!TourList[i][tourActive]) continue;
        new line[80];
        format(line, sizeof(line), "Tur %s condus de %s (%d membri)\n",
            TourTypeNames[TourList[i][tourType]-1],
            PlayerData[TourList[i][tourLeaderID]][pName],
            TourList[i][tourMemberCount]);
        strcat(info, line);
    }
    ShowPlayerDialog(playerid, DIALOG_TOUR_JOIN, DIALOG_STYLE_LIST,
        "{FFD700}Tururi Active", info, "Alatura-te", "Inchide");
    return 1;
}

CMD:tourwaypoint(playerid, params[])
{
    // Liderul da urmatorul punct de tur
    new tid = -1;
    for(new i = 0; i < MAX_TOURS; i++)
    {
        if(TourList[i][tourLeaderID] == playerid && TourList[i][tourActive])
        { tid = i; break; }
    }
    if(tid == -1) return SendMsg(playerid, COLOR_ERROR, "[!] Nu conduci niciun tur!");

    new step;
    if(sscanf(params, "i", step) || step < 1 || step > 5)
        return SendMsg(playerid, COLOR_ERROR, "Folosire: /tourwaypoint [1-5]");

    new t = TourList[tid][tourType] - 1;
    new Float:wx = TourPoints[t][step-1][0];
    new Float:wy = TourPoints[t][step-1][1];
    new Float:wz = TourPoints[t][step-1][2];

    // Seteaza checkpoint tuturor membrilor
    for(new m = 0; m < TourList[tid][tourMemberCount]; m++)
    {
        new mid = TourList[tid][tourMembers][m];
        if(IsPlayerConnected(mid))
        {
            SetPlayerCheckpoint(mid, wx, wy, wz, 5.0);
            SendMsgFmt(mid, COLOR_YELLOW, "[Tur] Urmatorul punct: #%d! Urmeaza indicatiile.", step);
        }
    }
    return 1;
}

// ============================================================
//  BUSINESSES.INC
// ============================================================

enum E_BUSINESS_DATA
{
    bID, bOwnerID, bName[32], bType,
    bPrice, bIncome, bTaxes, bForSale,
    Float:bX, Float:bY, Float:bZ,
    bPickup, bLabel
}

new BusinessData[MAX_BUSINESSES][E_BUSINESS_DATA];
new BusinessCount = 0;

stock Businesses_Init()
{
    mysql_tquery(g_SQL, "SELECT * FROM `businesses`", "OnBusinessesLoaded", "", 0);
}

forward OnBusinessesLoaded();
public OnBusinessesLoaded()
{
    BusinessCount = cache_num_rows();
    for(new i = 0; i < BusinessCount; i++)
    {
        cache_get_value_name_int(i, "id", BusinessData[i][bID]);
        cache_get_value_name_int(i, "owner_id", BusinessData[i][bOwnerID]);
        cache_get_value_name(i, "name", BusinessData[i][bName], 32);
        cache_get_value_name_int(i, "type", BusinessData[i][bType]);
        cache_get_value_name_int(i, "price", BusinessData[i][bPrice]);
        cache_get_value_name_int(i, "income", BusinessData[i][bIncome]);
        cache_get_value_name_int(i, "taxes", BusinessData[i][bTaxes]);
        cache_get_value_name_int(i, "for_sale", BusinessData[i][bForSale]);
        cache_get_value_name_float(i, "pos_x", BusinessData[i][bX]);
        cache_get_value_name_float(i, "pos_y", BusinessData[i][bY]);
        cache_get_value_name_float(i, "pos_z", BusinessData[i][bZ]);

        new labeltext[64];
        if(BusinessData[i][bOwnerID] == 0)
            format(labeltext, sizeof(labeltext), "{FFD700}Afacere de vanzare\n{FFFFFF}$%d\n/buybusiness", BusinessData[i][bPrice]);
        else
            format(labeltext, sizeof(labeltext), "{00FF00}%s\n{FFFFFF}Profit/payday: $%d", BusinessData[i][bName], BusinessData[i][bIncome]);

        BusinessData[i][bPickup] = CreatePickup(1239, 1, BusinessData[i][bX], BusinessData[i][bY], BusinessData[i][bZ], -1);
        BusinessData[i][bLabel] = _:Create3DTextLabel(labeltext, 0xFFFFFFFF,
            BusinessData[i][bX], BusinessData[i][bY], BusinessData[i][bZ]+0.5, 10.0, 0, 0);
    }
    new msg[48];
    format(msg, sizeof(msg), "[Businesses] %d afaceri incarcate.", BusinessCount);
    print(msg);
}

CMD:buybusiness(playerid, params[])
{
    if(!PlayerData[playerid][pLogged]) return 1;
    new Float:px, Float:py, Float:pz;
    GetPlayerPos(playerid, px, py, pz);

    for(new i = 0; i < BusinessCount; i++)
    {
        if(!BusinessData[i][bForSale]) continue;
        if(VectorSize(px-BusinessData[i][bX], py-BusinessData[i][bY], pz-BusinessData[i][bZ]) < 3.0)
        {
            if(GetPlayerMoney(playerid) < BusinessData[i][bPrice])
                return SendMsgFmt(playerid, COLOR_ERROR, "[!] Ai nevoie de $%d!", BusinessData[i][bPrice]);

            GivePlayerMoney(playerid, -BusinessData[i][bPrice]);
            PlayerData[playerid][pMoney] -= BusinessData[i][bPrice];
            BusinessData[i][bOwnerID] = PlayerData[playerid][pID];
            BusinessData[i][bForSale] = 0;

            new query[128];
            mysql_format(g_SQL, query, sizeof(query),
                "UPDATE `businesses` SET `owner_id`=%d,`for_sale`=0 WHERE `id`=%d",
                PlayerData[playerid][pID], BusinessData[i][bID]);
            mysql_tquery(g_SQL, query, "", "", 0);

            new labeltext[64];
            format(labeltext, sizeof(labeltext), "{00FF00}%s\n{FFFFFF}Profit/payday: $%d",
                BusinessData[i][bName], BusinessData[i][bIncome]);
            Update3DTextLabelText(Text3D:BusinessData[i][bLabel], 0xFFFFFFFF, labeltext);

            SendMsgFmt(playerid, COLOR_SUCCESS, "[Afacere] Ai cumparat %s pentru $%d! Profiti $%d/payday.",
                BusinessData[i][bName], BusinessData[i][bPrice], BusinessData[i][bIncome]);
            return 1;
        }
    }
    SendMsg(playerid, COLOR_ERROR, "[!] Nu esti langa nicio afacere de vanzare!");
    return 1;
}

// ============================================================
//  ADMIN.INC
// ============================================================

CMD:setfaction(playerid, params[])
{
    if(!IsAdmin(playerid, 3)) return SendMsg(playerid, COLOR_ERROR, "[!] Acces interzis!");
    new targetid, fid, rank;
    if(sscanf(params, "uii", targetid, fid, rank))
        return SendMsg(playerid, COLOR_ERROR, "Folosire: /setfaction [jucator] [factiuneid] [rang]");

    PlayerData[targetid][pFaction]     = fid;
    PlayerData[targetid][pFactionRank] = rank;
    if(fid > 0) SetPlayerSkin(targetid, FactionSkins[fid][0]);
    Player_SaveData(targetid);
    SendMsgFmt(playerid, COLOR_SUCCESS, "[Admin] %s -> Factiune %d Rang %d", PlayerData[targetid][pName], fid, rank);
    SendMsgFmt(targetid, COLOR_YELLOW, "[Admin] Factiunea ta a fost schimbata in %s (Rang %d).", Faction_GetName(fid), rank);
    return 1;
}

CMD:setjob(playerid, params[])
{
    if(!IsAdmin(playerid, 2)) return SendMsg(playerid, COLOR_ERROR, "[!] Acces interzis!");
    new targetid, jobid;
    if(sscanf(params, "ui", targetid, jobid))
        return SendMsg(playerid, COLOR_ERROR, "Folosire: /setjob [jucator] [jobid]");
    PlayerData[targetid][pJob] = jobid;
    Player_SaveData(targetid);
    SendMsgFmt(playerid, COLOR_SUCCESS, "[Admin] Job setat: %s -> %s", PlayerData[targetid][pName], Job_GetName(jobid));
    return 1;
}

CMD:setlevel(playerid, params[])
{
    if(!IsAdmin(playerid, 3)) return SendMsg(playerid, COLOR_ERROR, "[!] Acces interzis!");
    new targetid, lvl;
    if(sscanf(params, "ui", targetid, lvl))
        return SendMsg(playerid, COLOR_ERROR, "Folosire: /setlevel [jucator] [level]");
    if(lvl < 1 || lvl > MAX_LEVEL) return SendMsg(playerid, COLOR_ERROR, "[!] Level invalid!");
    PlayerData[targetid][pLevel] = lvl;
    SetPlayerScore(targetid, lvl);
    Player_SaveData(targetid);
    SendMsgFmt(playerid, COLOR_SUCCESS, "[Admin] %s -> Level %d", PlayerData[targetid][pName], lvl);
    return 1;
}

CMD:setadmin(playerid, params[])
{
    if(!IsAdmin(playerid, 5)) return SendMsg(playerid, COLOR_ERROR, "[!] Doar super-adminii pot seta admini!");
    new targetid, alv;
    if(sscanf(params, "ui", targetid, alv))
        return SendMsg(playerid, COLOR_ERROR, "Folosire: /setadmin [jucator] [nivel 1-5]");
    PlayerData[targetid][pAdminLevel] = alv;
    Player_SaveData(targetid);
    SendMsgFmt(playerid, COLOR_SUCCESS, "[Admin] %s are acum nivel admin %d.", PlayerData[targetid][pName], alv);
    return 1;
}

CMD:atp(playerid, params[])
{
    if(!IsAdmin(playerid, 2)) return SendMsg(playerid, COLOR_ERROR, "[!] Acces interzis!");
    new targetid;
    if(sscanf(params, "u", targetid))
        return SendMsg(playerid, COLOR_ERROR, "Folosire: /atp [jucator]");
    new Float:tx, Float:ty, Float:tz;
    GetPlayerPos(targetid, tx, ty, tz);
    SetPlayerPos(playerid, tx, ty, tz+1.0);
    SendMsgFmt(playerid, COLOR_SUCCESS, "[Admin] Teleportat la %s.", PlayerData[targetid][pName]);
    return 1;
}

CMD:ann(playerid, params[])
{
    if(!IsAdmin(playerid, 2)) return SendMsg(playerid, COLOR_ERROR, "[!] Acces interzis!");
    if(!params[0]) return SendMsg(playerid, COLOR_ERROR, "Folosire: /ann [mesaj]");
    new msg[128];
    format(msg, sizeof(msg), "[ANUNT] %s", params);
    SendMsgAll(COLOR_ORANGE, msg);
    return 1;
}

// ============================================================
//  EVENTS.INC - Callback-uri si handler dialog global
// ============================================================

stock Events_Init()
{
    print("[Events] Handler events incarcat.");
}

stock Dialog_OnResponse(playerid, dialogid, response, listitem, inputtext[])
{
    // Auth
    if(dialogid == DIALOG_LOGIN || dialogid == DIALOG_REGISTER || dialogid == DIALOG_REGISTER_PASS)
        return Dialog_Auth_Response(playerid, dialogid, response, listitem, inputtext);

    if(!PlayerData[playerid][pLogged]) return 1;

    switch(dialogid)
    {
        case DIALOG_HOUSE_BUY:
        {
            if(!response) return 1;
            new houseid = GetPVarInt(playerid, "BuyHouseID");
            House_Buy(playerid, houseid);
        }
        case DIALOG_JOB_SELECT:
        {
            if(!response) return 1;
            new job = listitem + 1;
            PlayerData[playerid][pJob] = job;
            PlayerData[playerid][pOnDuty] = false;
            Player_SaveData(playerid);
            SendMsgFmt(playerid, COLOR_SUCCESS, "[Job] Ai ales jobul: %s. Foloseste /duty pentru a intra in serviciu.", Job_GetName(job));
        }
        case DIALOG_PRESIDENT_VOTE:
        {
            if(!response || !VoteOpen) return 1;
            // Gaseste candidatul online (listitem-ul)
            new count = 0;
            for(new i = 0; i < MAX_PLAYERS; i++)
            {
                if(!IsPlayerConnected(i) || !PlayerData[i][pLogged]) continue;
                if(PlayerData[i][pLevel] < MIN_LEVEL_CANDIDATE) continue;
                if(PlayerData[i][pIsPresident]) continue;
                if(count == listitem)
                {
                    // Voteaza
                    new query[256];
                    mysql_format(g_SQL, query, sizeof(query),
                        "INSERT INTO `votes` (`voter_id`,`candidate_id`) VALUES (%d,%d)",
                        PlayerData[playerid][pID], PlayerData[i][pID]);
                    mysql_tquery(g_SQL, query, "", "", 0);
                    SendMsgFmt(playerid, COLOR_SUCCESS, "[Presedinte] Ai votat pentru %s!", PlayerData[i][pName]);
                    break;
                }
                count++;
            }
        }
        case DIALOG_TOUR_SELECT_TYPE:
        {
            if(!response) return 1;
            new tid = Tour_GetSlot();
            if(tid == -1) return SendMsg(playerid, COLOR_ERROR, "[!] Prea multe tururi active!");

            TourList[tid][tourLeaderID]   = playerid;
            TourList[tid][tourType]       = listitem + 1;
            TourList[tid][tourActive]     = true;
            TourList[tid][tourMemberCount]= 1;
            TourList[tid][tourMembers][0] = playerid;
            format(TourList[tid][tourName], 64, "Tur %s condus de %s",
                TourTypeNames[listitem], PlayerData[playerid][pName]);
            ActiveTours++;

            SendMsgFmt(playerid, COLOR_SUCCESS, "[Tur] Tur de tip %s creat! Jucatorii pot folosi /jointour.", TourTypeNames[listitem]);
            new msg[128];
            format(msg, sizeof(msg), "[TUR] %s a organizat un tur de tip %s! Foloseste /jointour.",
                PlayerData[playerid][pName], TourTypeNames[listitem]);
            SendMsgAll(COLOR_YELLOW, msg);
        }
        case DIALOG_TOUR_JOIN:
        {
            if(!response) return 1;
            new count = 0;
            for(new i = 0; i < MAX_TOURS; i++)
            {
                if(!TourList[i][tourActive]) continue;
                if(count == listitem)
                {
                    if(TourList[i][tourMemberCount] >= 20)
                        return SendMsg(playerid, COLOR_ERROR, "[!] Turul este plin!");

                    TourList[i][tourMembers][TourList[i][tourMemberCount]] = playerid;
                    TourList[i][tourMemberCount]++;
                    PlayerData[playerid][pInTour] = true;
                    PlayerData[playerid][pTourID]  = i;

                    SendMsgFmt(playerid, COLOR_SUCCESS, "[Tur] Te-ai alaturat turului: %s!", TourList[i][tourName]);
                    SendMsgFmt(TourList[i][tourLeaderID], COLOR_YELLOW, "[Tur] %s s-a alaturat turului tau!", PlayerData[playerid][pName]);
                    break;
                }
                count++;
            }
        }
    }
    return 1;
}

stock Pickups_OnPickup(playerid, pickupid)
{
    // Case
    for(new i = 0; i < HouseCount; i++)
    {
        if(HouseData[i][hPickup] == pickupid)
        {
            if(HouseData[i][hOwnerID] == PlayerData[playerid][pID])
                House_ShowMenu(playerid, i);
            else if(HouseData[i][hForSale])
                SendMsg(playerid, COLOR_YELLOW, "[Casa] Aceasta casa e de vanzare! Foloseste /buthouse.");
            else
                SendMsg(playerid, COLOR_GREY, "[Casa] Casa privata.");
            return 1;
        }
    }
    // Pesti
    for(new i = 0; i < FishCount; i++)
    {
        if(FishData[i][fhPickupID] == pickupid && FishData[i][fhAlive])
        {
            // Pescuit ilegal prin pickup direct
            FishData[i][fhAlive] = false;
            FishData[i][fhPickupID] = 0;
            PlayerFishBag[playerid]++;
            SendMsgFmt(playerid, COLOR_SUCCESS, "[Pescuit] Ai prins un peste! Total: %d", PlayerFishBag[playerid]);
            return 1;
        }
    }
    return 1;
}
