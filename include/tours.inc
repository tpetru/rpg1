// ============================================================
//  TOURS.INC - Plimbari organizate pe munte, plaja, padure, sate
//  Conduse de: Padurari, Salvamari, Ghizi turistici, Admini
// ============================================================
#if defined _tours_included
    #endinput
#endif
#define _tours_included

// ---- Tipuri de tur ----
#define TOUR_MOUNTAIN   1
#define TOUR_BEACH      2
#define TOUR_FOREST     3
#define TOUR_VILLAGE    4
#define TOUR_MAX_TYPE   4

new TourTypeNames[TOUR_MAX_TYPE+1][20] = {
    "Necunoscut",
    "Munte",
    "Plaja",
    "Padure",
    "Sate"
};

// Cine poate conduce fiecare tip de tur
// Munte -> Padurar / Admin
// Plaja  -> Salvamar / Admin
// Padure -> Padurar / Admin
// Sate   -> Orice job special sau Admin

// ---- Puncte tur predefinite (5 puncte per tip) ----
// Format: {x, y, z, descriere implicita in cod}
new Float:TourWaypoints[TOUR_MAX_TYPE][5][3] = {
    // 1 - Munte
    {
        {-2414.0, -385.0,  35.0},
        {-2560.0, -405.0,  60.0},
        {-2680.0, -430.0,  95.0},
        {-2790.0, -460.0, 125.0},
        {-2900.0, -490.0, 155.0}
    },
    // 2 - Plaja
    {
        {-1700.0, -1110.0, 2.0},
        {-1830.0, -1000.0, 2.0},
        {-1960.0,  -900.0, 2.0},
        {-2050.0,  -780.0, 2.0},
        {-2150.0,  -670.0, 2.0}
    },
    // 3 - Padure
    {
        {-1380.0, 2310.0, 32.0},
        {-1500.0, 2200.0, 38.0},
        {-1620.0, 2090.0, 44.0},
        {-1730.0, 1980.0, 38.0},
        {-1840.0, 1870.0, 32.0}
    },
    // 4 - Sate
    {
        { 990.0, -710.0, 20.0},
        {1100.0, -610.0, 22.0},
        {1210.0, -510.0, 25.0},
        {1320.0, -410.0, 24.0},
        {1430.0, -310.0, 23.0}
    }
};

new TourWaypointDesc[TOUR_MAX_TYPE][5][48] = {
    // Munte
    {"Baza muntelui - punct de plecare",
     "Prima pauza - Vedere panoramica",
     "Mijlocul traseului - Cascada",
     "Refugiu montan",
     "Varful - Destinatie finala"},
    // Plaja
    {"Intrare pe plaja - punct de plecare",
     "Zona de inot - atentie la valuri",
     "Stanca mare - punct de belvedere",
     "Zona de picnic",
     "Farul - destinatie finala"},
    // Padure
    {"Marginea padurii - punct de plecare",
     "Poiana cu flori salbatice",
     "Izvor natural",
     "Copacul secular - 300 de ani",
     "Coltul padurii - destinatie finala"},
    // Sate
    {"Intrare in sat - punct de plecare",
     "Piata satului",
     "Biserica veche",
     "Moara de apa",
     "Pensiunea locala - destinatie finala"}
};

// ---- Date tur ----
enum E_TOUR
{
    trID,
    trLeaderID,
    trType,
    trName[64],
    bool:trActive,
    trStep,               // pasul curent (1-5)
    trMemberCount,
    trMembers[20],
    trPayPerMember,       // plata per participant la final
    trStartTime
}

new TourList[MAX_TOURS][E_TOUR];
new ActiveTourCount = 0;
new TourAutoID = 1;

// Costul de participare la tur (platit liderului)
#define TOUR_COST_MOUNTAIN  500
#define TOUR_COST_BEACH     400
#define TOUR_COST_FOREST    450
#define TOUR_COST_VILLAGE   350

new TourCosts[TOUR_MAX_TYPE+1] = {0, 500, 400, 450, 350};

// ============================================================
//  INIT
// ============================================================

stock Tours_Init()
{
    print("[Tours] Sistem tururi incarcat. Asteptam lideri de tur.");
}

// ============================================================
//  HELPER - gaseste slot liber
// ============================================================

stock Tour_GetFreeSlot()
{
    for(new i = 0; i < MAX_TOURS; i++)
        if(!TourList[i][trActive]) return i;
    return -1;
}

stock Tour_GetPlayerSlot(playerid)
{
    for(new i = 0; i < MAX_TOURS; i++)
    {
        if(!TourList[i][trActive]) continue;
        if(TourList[i][trLeaderID] == playerid) return i;
        for(new m = 0; m < TourList[i][trMemberCount]; m++)
            if(TourList[i][trMembers][m] == playerid) return i;
    }
    return -1;
}

stock Tour_IsLeader(playerid, tourid)
{
    return TourList[tourid][trLeaderID] == playerid;
}

stock bool:Player_CanLeadTour(playerid, tourtype)
{
    new job = PlayerData[playerid][pJob];
    if(IsAdmin(playerid, 1)) return true;

    switch(tourtype)
    {
        case TOUR_MOUNTAIN: return (job == JOB_PADURAR);
        case TOUR_BEACH:    return (job == JOB_SALVAMAR);
        case TOUR_FOREST:   return (job == JOB_PADURAR);
        case TOUR_VILLAGE:  return (job == JOB_PADURAR || job == JOB_SALVAMAR);
    }
    return false;
}

// ============================================================
//  CREARE TUR
// ============================================================

stock Tour_Create(playerid, tourtype)
{
    if(!Player_CanLeadTour(playerid, tourtype))
    {
        SendMsg(playerid, COLOR_ERROR, "[Tur] Nu ai dreptul sa conduci acest tip de tur!");
        return -1;
    }

    if(Tour_GetPlayerSlot(playerid) != -1)
    {
        SendMsg(playerid, COLOR_ERROR, "[Tur] Esti deja intr-un tur activ!");
        return -1;
    }

    new slot = Tour_GetFreeSlot();
    if(slot == -1)
    {
        SendMsg(playerid, COLOR_ERROR, "[Tur] Prea multe tururi active acum!");
        return -1;
    }

    TourList[slot][trID]             = TourAutoID++;
    TourList[slot][trLeaderID]       = playerid;
    TourList[slot][trType]           = tourtype;
    TourList[slot][trActive]         = true;
    TourList[slot][trStep]           = 0;
    TourList[slot][trMemberCount]    = 1;
    TourList[slot][trMembers][0]     = playerid;
    TourList[slot][trPayPerMember]   = TourCosts[tourtype];
    TourList[slot][trStartTime]      = gettime();

    format(TourList[slot][trName], 64, "Tur %s #%d condus de %s",
        TourTypeNames[tourtype], TourList[slot][trID], PlayerData[playerid][pName]);

    ActiveTourCount++;

    // Teleporteaza liderul la punctul 1
    new t = tourtype - 1;
    SetPlayerPos(playerid,
        TourWaypoints[t][0][0],
        TourWaypoints[t][0][1],
        TourWaypoints[t][0][2]);
    SetPlayerInterior(playerid, 0);
    SetPlayerVirtualWorld(playerid, 0);

    SendMsgFmt(playerid, COLOR_SUCCESS,
        "[Tur] Tur creat: {FFD700}%s{00FF44}! Participantii platesc $%d. Foloseste /nextstep.",
        TourList[slot][trName], TourCosts[tourtype]);

    // Anunta toti
    new msg[192];
    format(msg, sizeof(msg),
        "[TUR ORGANIZAT] {FFD700}%s{FFFFFF} a organizat un {00FF44}Tur %s{FFFFFF}! "
        "Cost participare: {FFD700}$%d{FFFFFF}. Foloseste {00FF44}/jointour{FFFFFF} pentru a te alatura!",
        PlayerData[playerid][pName], TourTypeNames[tourtype], TourCosts[tourtype]);
    SendMsgAll(COLOR_WHITE, msg);

    // Salveaza in DB
    new query[256];
    mysql_format(g_SQL, query, sizeof(query),
        "INSERT INTO `tours` (`leader_id`,`type`,`name`) VALUES (%d,%d,'%e')",
        PlayerData[playerid][pID], tourtype, TourList[slot][trName]);
    mysql_tquery(g_SQL, query, "", "", 0);

    PlayerData[playerid][pInTour] = true;
    PlayerData[playerid][pTourID] = slot;
    return slot;
}

// ============================================================
//  ALATURARE TUR
// ============================================================

stock Tour_Join(playerid, slot)
{
    if(!TourList[slot][trActive])
        return SendMsg(playerid, COLOR_ERROR, "[Tur] Turul nu mai este activ!");

    if(Tour_GetPlayerSlot(playerid) != -1)
        return SendMsg(playerid, COLOR_ERROR, "[Tur] Esti deja intr-un tur!");

    if(TourList[slot][trMemberCount] >= 20)
        return SendMsg(playerid, COLOR_ERROR, "[Tur] Turul este plin! (max 20 participanti)");

    if(TourList[slot][trStep] > 0)
        return SendMsg(playerid, COLOR_ERROR, "[Tur] Turul a inceput deja. Asteapta urmatorul.");

    // Plateste costul de participare
    new cost = TourList[slot][trPayPerMember];
    if(GetPlayerMoney(playerid) < cost)
        return SendMsgFmt(playerid, COLOR_ERROR, "[Tur] Ai nevoie de $%d pentru a participa!", cost);

    GivePlayerMoney(playerid, -cost);
    PlayerData[playerid][pMoney] -= cost;

    // Plateste liderul
    new leaderid = TourList[slot][trLeaderID];
    GivePlayerMoney(leaderid, cost);
    PlayerData[leaderid][pMoney] += cost;

    // Adauga la tur
    TourList[slot][trMembers][TourList[slot][trMemberCount]] = playerid;
    TourList[slot][trMemberCount]++;

    PlayerData[playerid][pInTour] = true;
    PlayerData[playerid][pTourID] = slot;

    // Teleporteaza la pozitia liderului
    new Float:lx, Float:ly, Float:lz;
    GetPlayerPos(leaderid, lx, ly, lz);
    SetPlayerPos(playerid, lx + 2.0, ly, lz);
    SetPlayerInterior(playerid, 0);

    SendMsgFmt(playerid, COLOR_SUCCESS,
        "[Tur] Te-ai alaturat turului {FFD700}%s{00FF44}! Cost platit: $%d. Urmati liderul!",
        TourList[slot][trName], cost);

    SendMsgFmt(leaderid, COLOR_YELLOW,
        "[Tur] {FFD700}%s{FFFFFF} s-a alaturat turului! Acum aveti %d participanti.",
        PlayerData[playerid][pName], TourList[slot][trMemberCount]);

    // Notifica restul grupului
    for(new m = 0; m < TourList[slot][trMemberCount]; m++)
    {
        new mid = TourList[slot][trMembers][m];
        if(!IsPlayerConnected(mid) || mid == playerid || mid == leaderid) continue;
        SendMsgFmt(mid, COLOR_GREY, "[Tur] %s s-a alaturat grupului.", PlayerData[playerid][pName]);
    }
    return 1;
}

// ============================================================
//  PASUL URMATOR (lider)
// ============================================================

stock Tour_NextStep(playerid)
{
    new slot = -1;
    for(new i = 0; i < MAX_TOURS; i++)
    {
        if(TourList[i][trActive] && TourList[i][trLeaderID] == playerid)
        { slot = i; break; }
    }
    if(slot == -1) return SendMsg(playerid, COLOR_ERROR, "[Tur] Nu conduci niciun tur!");

    new step = TourList[slot][trStep];
    if(step >= 5)
    {
        Tour_Finish(slot);
        return 1;
    }

    TourList[slot][trStep]++;
    step = TourList[slot][trStep];

    new t = TourList[slot][trType] - 1;
    new Float:wx = TourWaypoints[t][step-1][0];
    new Float:wy = TourWaypoints[t][step-1][1];
    new Float:wz = TourWaypoints[t][step-1][2];

    // Trimite checkpoint tuturor
    for(new m = 0; m < TourList[slot][trMemberCount]; m++)
    {
        new mid = TourList[slot][trMembers][m];
        if(!IsPlayerConnected(mid)) continue;

        SetPlayerCheckpoint(mid, wx, wy, wz, 8.0);

        new msg[192];
        format(msg, sizeof(msg),
            "[Tur] {FFD700}Pasul %d/5{FFFFFF}: %s\n"
            "Urmariti liderul sau checkpoint-ul pe harta!",
            step, TourWaypointDesc[t][step-1]);
        SendClientMessage(mid, COLOR_YELLOW, msg);
        GameTextForPlayer(mid, TourWaypointDesc[t][step-1], 5000, 3);
    }

    // Liderul da informatii despre locul curent
    new info[192];
    format(info, sizeof(info),
        "[Tur] Ai mutat grupul la pasul %d: {FFD700}%s{FFFFFF}. "
        "Foloseste /tourinfo pentru a da informatii grupului. "
        "Urmator: /nextstep", step, TourWaypointDesc[t][step-1]);
    SendClientMessage(playerid, COLOR_GREEN, info);
    return 1;
}

// ============================================================
//  FINALIZARE TUR
// ============================================================

stock Tour_Finish(slot)
{
    if(!TourList[slot][trActive]) return;

    new duration = gettime() - TourList[slot][trStartTime];
    new mins = duration / 60;

    // Bonus XP tuturor
    new xp_reward = 150 + (TourList[slot][trMemberCount] * 10);
    new leaderid = TourList[slot][trLeaderID];

    for(new m = 0; m < TourList[slot][trMemberCount]; m++)
    {
        new mid = TourList[slot][trMembers][m];
        if(!IsPlayerConnected(mid)) continue;

        DisablePlayerCheckpoint(mid);
        Player_AddXP(mid, xp_reward);
        PlayerData[mid][pInTour] = false;
        PlayerData[mid][pTourID] = -1;

        if(mid == leaderid)
        {
            SendMsgFmt(mid, COLOR_GOLD,
                "[Tur] Turul s-a incheiat dupa %d minute! Ai primit +%d XP ca lider.",
                mins, xp_reward * 2);
            Player_AddXP(mid, xp_reward); // dublu pentru lider
        }
        else
        {
            SendMsgFmt(mid, COLOR_GOLD,
                "[Tur] Tur finalizat! %d participanti, %d minute. +%d XP",
                TourList[slot][trMemberCount], mins, xp_reward);
        }

        GameTextForPlayer(mid, "~g~Tur finalizat!~n~~w~Multumim!", 5000, 1);
    }

    // Salveaza in DB
    new query[128];
    mysql_format(g_SQL, query, sizeof(query),
        "UPDATE `tours` SET `active`=0 WHERE `leader_id`=%d AND `active`=1",
        PlayerData[leaderid][pID]);
    mysql_tquery(g_SQL, query, "", "", 0);

    // Anunta server
    new msg[128];
    format(msg, sizeof(msg),
        "[TUR] Turul {FFD700}%s{FFFFFF} s-a incheiat! %d participanti in %d minute.",
        TourList[slot][trName], TourList[slot][trMemberCount], mins);
    SendMsgAll(COLOR_ORANGE, msg);

    TourList[slot][trActive] = false;
    ActiveTourCount--;
}

// ============================================================
//  PARASIRE TUR
// ============================================================

stock Tour_Leave(playerid)
{
    new slot = Tour_GetPlayerSlot(playerid);
    if(slot == -1) return SendMsg(playerid, COLOR_ERROR, "[Tur] Nu esti in niciun tur!");

    if(Tour_IsLeader(playerid, slot))
    {
        // Liderul paraseste -> tur se incheie
        SendMsg(playerid, COLOR_ERROR, "[Tur] Ai parasit turul ca lider. Turul se incheie!");
        for(new m = 0; m < TourList[slot][trMemberCount]; m++)
        {
            new mid = TourList[slot][trMembers][m];
            if(IsPlayerConnected(mid) && mid != playerid)
                SendMsg(mid, COLOR_ERROR, "[Tur] Liderul a parasit turul. Turul s-a incheiat.");
            if(IsPlayerConnected(mid))
            {
                DisablePlayerCheckpoint(mid);
                PlayerData[mid][pInTour] = false;
            }
        }
        TourList[slot][trActive] = false;
        ActiveTourCount--;
    }
    else
    {
        // Participant paraseste
        for(new m = 0; m < TourList[slot][trMemberCount]; m++)
        {
            if(TourList[slot][trMembers][m] == playerid)
            {
                // Shift
                for(new j = m; j < TourList[slot][trMemberCount]-1; j++)
                    TourList[slot][trMembers][j] = TourList[slot][trMembers][j+1];
                TourList[slot][trMemberCount]--;
                break;
            }
        }
        DisablePlayerCheckpoint(playerid);
        PlayerData[playerid][pInTour] = false;
        PlayerData[playerid][pTourID] = -1;
        SendMsg(playerid, COLOR_GREY, "[Tur] Ai parasit turul.");

        new leaderid = TourList[slot][trLeaderID];
        if(IsPlayerConnected(leaderid))
            SendMsgFmt(leaderid, COLOR_GREY, "[Tur] %s a parasit grupul. Raman %d participanti.",
                PlayerData[playerid][pName], TourList[slot][trMemberCount]);
    }
    return 1;
}

// ============================================================
//  DIALOG HANDLER TURURI
// ============================================================

stock Tour_OnDialog(playerid, dialogid, response, listitem, inputtext[])
{
    switch(dialogid)
    {
        case DIALOG_TOUR_SELECT_TYPE:
        {
            if(!response) return 1;
            new tourtype = listitem + 1;
            Tour_Create(playerid, tourtype);
        }
        case DIALOG_TOUR_JOIN:
        {
            if(!response) return 1;
            // Gaseste al listitem-lea tur activ
            new count = 0;
            for(new i = 0; i < MAX_TOURS; i++)
            {
                if(!TourList[i][trActive]) continue;
                if(TourList[i][trLeaderID] == playerid) continue; // nu te poti alatura turului tau
                if(count == listitem) { Tour_Join(playerid, i); return 1; }
                count++;
            }
        }
    }
    return 1;
}

// ============================================================
//  COMENZI
// ============================================================

CMD:createtour(playerid, params[])
{
    if(!PlayerData[playerid][pLogged]) return 1;

    new job = PlayerData[playerid][pJob];
    if(!IsAdmin(playerid, 1) && job != JOB_PADURAR && job != JOB_SALVAMAR)
        return SendMsg(playerid, COLOR_ERROR, "[!] Doar padurarii, salvamarii si adminii pot crea tururi!");

    new info[] =
        "Tur Munte ($500/participant)\n"
        "Tur Plaja ($400/participant)\n"
        "Tur Padure ($450/participant)\n"
        "Tur Sate ($350/participant)";

    ShowPlayerDialog(playerid, DIALOG_TOUR_SELECT_TYPE, DIALOG_STYLE_LIST,
        "{FFD700}Tip Tur", info, "Creeaza", "Anuleaza");
    return 1;
}

CMD:jointour(playerid, params[])
{
    if(!PlayerData[playerid][pLogged]) return 1;

    if(ActiveTourCount == 0)
        return SendMsg(playerid, COLOR_ERROR, "[!] Nu exista tururi active momentan!");

    new info[1024];
    new count = 0;
    for(new i = 0; i < MAX_TOURS; i++)
    {
        if(!TourList[i][trActive]) continue;
        if(TourList[i][trLeaderID] == playerid) continue;

        new line[128];
        format(line, sizeof(line),
            "{FFD700}%s{FFFFFF} | Lider: %s | Membri: %d/20 | Cost: $%d | Pas: %d/5\n",
            TourTypeNames[TourList[i][trType]],
            PlayerData[TourList[i][trLeaderID]][pName],
            TourList[i][trMemberCount],
            TourList[i][trPayPerMember],
            TourList[i][trStep]);
        strcat(info, line);
        count++;
    }

    if(!count) return SendMsg(playerid, COLOR_ERROR, "[!] Nu exista tururi la care te poti alatura.");

    ShowPlayerDialog(playerid, DIALOG_TOUR_JOIN, DIALOG_STYLE_LIST,
        "{FFD700}Tururi Active", info, "Alatura-te", "Inchide");
    return 1;
}

CMD:nextstep(playerid, params[])
{
    if(!PlayerData[playerid][pLogged]) return 1;
    Tour_NextStep(playerid);
    return 1;
}

CMD:leavetour(playerid, params[])
{
    if(!PlayerData[playerid][pLogged]) return 1;
    Tour_Leave(playerid);
    return 1;
}

CMD:tourinfo(playerid, params[])
{
    if(!PlayerData[playerid][pLogged]) return 1;
    if(!params[0]) return SendMsg(playerid, COLOR_ERROR, "Folosire: /tourinfo [mesaj]");

    new slot = Tour_GetPlayerSlot(playerid);
    if(slot == -1) return SendMsg(playerid, COLOR_ERROR, "[!] Nu esti in niciun tur!");
    if(!Tour_IsLeader(playerid, slot)) return SendMsg(playerid, COLOR_ERROR, "[!] Doar liderul poate folosi /tourinfo!");

    new msg[192];
    format(msg, sizeof(msg), "[Tur - Lider] {FFD700}%s{FFFFFF}: %s",
        PlayerData[playerid][pName], params);

    for(new m = 0; m < TourList[slot][trMemberCount]; m++)
    {
        new mid = TourList[slot][trMembers][m];
        if(IsPlayerConnected(mid))
            SendClientMessage(mid, COLOR_YELLOW, msg);
    }
    return 1;
}

CMD:tourgroup(playerid, params[])
{
    if(!PlayerData[playerid][pLogged]) return 1;

    new slot = Tour_GetPlayerSlot(playerid);
    if(slot == -1) return SendMsg(playerid, COLOR_ERROR, "[!] Nu esti in niciun tur!");

    new info[512];
    format(info, sizeof(info),
        "{FFD700}Tur: %s\n"
        "{FFFFFF}Tip: %s | Pas: %d/5\n\n"
        "Participanti (%d):\n",
        TourList[slot][trName],
        TourTypeNames[TourList[slot][trType]],
        TourList[slot][trStep],
        TourList[slot][trMemberCount]);

    for(new m = 0; m < TourList[slot][trMemberCount]; m++)
    {
        new mid = TourList[slot][trMembers][m];
        new line[48];
        if(mid == TourList[slot][trLeaderID])
            format(line, sizeof(line), "{FFD700}[Lider] %s\n", PlayerData[mid][pName]);
        else
            format(line, sizeof(line), "{FFFFFF}%s\n", IsPlayerConnected(mid) ? PlayerData[mid][pName] : "(offline)");
        strcat(info, line);
    }

    ShowPlayerDialog(playerid, 9999, DIALOG_STYLE_MSGBOX,
        "Grupul Tau de Tur", info, "Inchide", "");
    return 1;
}

CMD:endtour(playerid, params[])
{
    if(!PlayerData[playerid][pLogged]) return 1;
    new slot = -1;
    for(new i = 0; i < MAX_TOURS; i++)
    {
        if(TourList[i][trActive] && TourList[i][trLeaderID] == playerid)
        { slot = i; break; }
    }
    if(slot == -1) return SendMsg(playerid, COLOR_ERROR, "[!] Nu conduci niciun tur!");
    Tour_Finish(slot);
    return 1;
}
