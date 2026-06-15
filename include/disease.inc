// ============================================================
//  DISEASE.INC - Sistem Boli
// ============================================================
#if defined _disease_included
    #endinput
#endif
#define _disease_included

enum E_DISEASE_DATA
{
    dID, dName[32], dDesc[128], dCreatedBy,
    bool:dActive
}

new DiseaseList[MAX_DISEASES][E_DISEASE_DATA];
new DiseaseCount = 0;

// Timere decay
new DiseaseDecayTimer[MAX_PLAYERS];

stock Disease_StartDecay(playerid)
{
    if(DiseaseDecayTimer[playerid])
        KillTimer(DiseaseDecayTimer[playerid]);
    DiseaseDecayTimer[playerid] = SetTimerEx("OnDiseaseDecay", 60000, true, "i", playerid);
}

stock Disease_StopDecay(playerid)
{
    if(DiseaseDecayTimer[playerid])
    {
        KillTimer(DiseaseDecayTimer[playerid]);
        DiseaseDecayTimer[playerid] = 0;
    }
}

forward OnDiseaseDecay(playerid);
public OnDiseaseDecay(playerid)
{
    if(!IsPlayerConnected(playerid) || !PlayerData[playerid][pSick]) return;
    new Float:hp;
    GetPlayerHealth(playerid, hp);
    hp -= DISEASE_HP_DECAY;
    if(hp < 1.0) hp = 1.0;
    SetPlayerHealth(playerid, hp);
    SendMsgFmt(playerid, COLOR_RED, "[Boala] Esti bolnav de %s! HP: %.0f. Mergi la spital!", PlayerData[playerid][pDiseaseName], hp);
}

// Admin creeaza boala noua si infecteaza playerii in raza
CMD:createdisease(playerid, params[])
{
    if(!IsAdmin(playerid, 2)) return SendMsg(playerid, COLOR_ERROR, "[!] Doar adminii pot face asta!");

    new dname[32], ddesc[64];
    if(sscanf(params, "s[32]S[64](Boala necunoscuta)", dname, ddesc))
        return SendMsg(playerid, COLOR_ERROR, "Folosire: /createdisease [nume] [descriere]");

    // Salveaza boala in DB
    new query[256];
    mysql_format(g_SQL, query, sizeof(query),
        "INSERT INTO `diseases` (`name`,`description`,`created_by`) VALUES ('%e','%e',%d)",
        dname, ddesc, PlayerData[playerid][pID]);
    mysql_tquery(g_SQL, query, "", "", 0);

    // Infecteaza playerii in raza
    new Float:px, Float:py, Float:pz;
    GetPlayerPos(playerid, px, py, pz);
    new infected = 0;

    for(new i = 0; i < MAX_PLAYERS; i++)
    {
        if(!IsPlayerConnected(i) || !PlayerData[i][pLogged] || i == playerid) continue;
        new Float:ix, Float:iy, Float:iz;
        GetPlayerPos(i, ix, iy, iz);
        if(VectorSize(px-ix, py-iy, pz-iz) <= DISEASE_RANGE)
        {
            if(!PlayerData[i][pSick])
            {
                PlayerData[i][pSick] = true;
                format(PlayerData[i][pDiseaseName], 32, "%s", dname);
                Disease_StartDecay(i);
                SendMsgFmt(i, COLOR_RED,
                    "[!] Ai fost infectat cu %s! Mergi urgent la spital la un medic SMURD.", dname);
                infected++;
            }
        }
    }

    SendMsgFmt(playerid, COLOR_SUCCESS,
        "[Admin] Boala '%s' creata si %d jucatori infectati in raza de %.0fm.", dname, infected, DISEASE_RANGE);
    return 1;
}

// SMURD: Trateaza boala la spital
CMD:treat(playerid, params[])
{
    if(PlayerData[playerid][pFaction] != FACTION_SMURD)
        return SendMsg(playerid, COLOR_ERROR, "[!] Doar SMURD-ul poate trata boli!");

    new targetid;
    if(sscanf(params, "u", targetid))
        return SendMsg(playerid, COLOR_ERROR, "Folosire: /treat [jucator]");

    if(!IsPlayerConnected(targetid))
        return SendMsg(playerid, COLOR_ERROR, "[!] Jucator invalid!");

    if(!PlayerData[targetid][pSick])
        return SendMsg(playerid, COLOR_ERROR, "[!] Jucatorul nu este bolnav!");

    // Trebuie sa fie la spital (interior)
    if(GetPlayerInterior(playerid) == 0 && GetPlayerInterior(targetid) == 0)
        return SendMsg(playerid, COLOR_ERROR, "[!] Trebuie sa fiti amandoi la spital!");

    PlayerData[targetid][pSick] = false;
    PlayerData[targetid][pDiseaseName] = "";
    Disease_StopDecay(targetid);
    SetPlayerHealth(targetid, 100.0);

    new tname[24], dname[24];
    GetPlayerName(targetid, tname, 24);
    GetPlayerName(playerid, dname, 24);

    SendMsgFmt(targetid, COLOR_SUCCESS, "[SMURD] %s te-a vindecat! Esti sanatos acum.", dname);
    SendMsgFmt(playerid, COLOR_SUCCESS, "[SMURD] L-ai vindecat pe %s!", tname);
    Player_AddXP(playerid, 100);

    // Salveaza in DB
    new query[256];
    mysql_format(g_SQL, query, sizeof(query),
        "UPDATE `players` SET `is_sick`=0,`disease_name`='' WHERE `id`=%d",
        PlayerData[targetid][pID]);
    mysql_tquery(g_SQL, query, "", "", 0);
    return 1;
}

// ============================================================
//  NEWSPAPER.INC
// ============================================================

enum E_NEWSPAPER
{
    nID, nReporterID,
    nTitle[64], nCategory[32],
    nContent[1024], nPrice,
    nDate[20]
}

new Newspapers[MAX_NEWSPAPERS][E_NEWSPAPER];
new NewspaperCount = 0;

CMD:createnewspaper(playerid, params[])
{
    if(PlayerData[playerid][pFaction] != FACTION_REPORTERI)
        return SendMsg(playerid, COLOR_ERROR, "[!] Doar reporterii pot crea ziare!");

    ShowPlayerDialog(playerid, DIALOG_NEWSPAPER_CREATE, DIALOG_STYLE_INPUT,
        "{FFD700}Creeaza Ziar",
        "Introdu titlul ziarului:",
        "Continua", "Anuleaza");
    return 1;
}

CMD:newspaper(playerid, params[])
{
    if(!PlayerData[playerid][pLogged]) return 1;
    if(NewspaperCount == 0)
        return SendMsg(playerid, COLOR_ERROR, "[!] Nu exista ziare disponibile!");

    new info[1024];
    for(new i = 0; i < NewspaperCount; i++)
    {
        new line[128];
        format(line, sizeof(line), "%s - %s (Reporter ID: %d) - $%d\n",
            Newspapers[i][nTitle], Newspapers[i][nCategory],
            Newspapers[i][nReporterID], Newspapers[i][nPrice]);
        strcat(info, line);
    }
    ShowPlayerDialog(playerid, DIALOG_NEWSPAPER_LIST, DIALOG_STYLE_LIST,
        "{FFD700}Ziare Disponibile", info, "Cumpara & Citeste", "Inchide");
    return 1;
}

// ============================================================
//  TRADE.INC - Sistem Schimb Sigur
// ============================================================

enum E_TRADE_DATA
{
    tID,
    tSenderID, tReceiverID,
    tType[16],       // "money", "vehicle", "house", "business", "pet"
    tItemID,
    tPrice,
    bool:tSenderOK,
    bool:tReceiverOK,
    bool:tActive
}

new TradeData[MAX_TRADES][E_TRADE_DATA];
new TradeCount = 0;

stock Trade_Create(senderid, receiverid, const type[], itemid, price)
{
    if(PlayerData[senderid][pCurrentTrade] != -1)
        return SendMsg(senderid, COLOR_ERROR, "[!] Ai deja un trade activ!");
    if(PlayerData[receiverid][pCurrentTrade] != -1)
        return SendMsg(senderid, COLOR_ERROR, "[!] Celalalt jucator are deja un trade activ!");

    new tid = -1;
    for(new i = 0; i < MAX_TRADES; i++)
    {
        if(!TradeData[i][tActive]) { tid = i; break; }
    }
    if(tid == -1) return SendMsg(senderid, COLOR_ERROR, "[!] Trade slot plin!");

    TradeData[tid][tID]          = tid;
    TradeData[tid][tSenderID]    = senderid;
    TradeData[tid][tReceiverID]  = receiverid;
    format(TradeData[tid][tType], 16, "%s", type);
    TradeData[tid][tItemID]      = itemid;
    TradeData[tid][tPrice]       = price;
    TradeData[tid][tSenderOK]    = false;
    TradeData[tid][tReceiverOK]  = false;
    TradeData[tid][tActive]      = true;

    PlayerData[senderid][pCurrentTrade]   = tid;
    PlayerData[receiverid][pCurrentTrade] = tid;
    TradeCount++;

    // Notifica receiver
    new sname[24];
    GetPlayerName(senderid, sname, 24);
    new msg[128];
    format(msg, sizeof(msg),
        "[Trade] %s vrea sa faca un schimb cu tine! Tip: %s, Pret: $%d. Foloseste /accepttrade sau /denytrade.",
        sname, type, price);
    SendMsg(receiverid, COLOR_YELLOW, msg);
    SendMsg(senderid, COLOR_YELLOW, "[Trade] Oferta trimisa! Asteapta confirmarea.");
    return 1;
}

stock Trade_Accept(receiverid, tid)
{
    if(!TradeData[tid][tActive]) return;

    new senderid   = TradeData[tid][tSenderID];
    new price      = TradeData[tid][tPrice];

    // Verifica bani
    if(GetPlayerMoney(receiverid) < price)
    {
        SendMsg(receiverid, COLOR_ERROR, "[Trade] Nu ai suficienti bani!");
        Trade_Cancel(tid);
        return;
    }

    // Executa schimbul
    GivePlayerMoney(receiverid, -price);
    GivePlayerMoney(senderid, price);
    PlayerData[receiverid][pMoney] -= price;
    PlayerData[senderid][pMoney] += price;

    // Transfera itemul
    if(!strcmp(TradeData[tid][tType], "vehicle", true))
    {
        new vid = TradeData[tid][tItemID];
        VehicleData[vid][vOwnerID] = PlayerData[receiverid][pID];
        new query[128];
        mysql_format(g_SQL, query, sizeof(query),
            "UPDATE `vehicles` SET `owner_id`=%d WHERE `id`=%d",
            PlayerData[receiverid][pID], VehicleData[vid][vID]);
        mysql_tquery(g_SQL, query, "", "", 0);
    }
    else if(!strcmp(TradeData[tid][tType], "house", true))
    {
        new houseid = TradeData[tid][tItemID];
        HouseData[houseid][hOwnerID] = PlayerData[receiverid][pID];
        new query[128];
        mysql_format(g_SQL, query, sizeof(query),
            "UPDATE `houses` SET `owner_id`=%d WHERE `id`=%d",
            PlayerData[receiverid][pID], HouseData[houseid][hID]);
        mysql_tquery(g_SQL, query, "", "", 0);
    }

    SendMsg(senderid, COLOR_SUCCESS, "[Trade] Schimb finalizat cu succes!");
    SendMsg(receiverid, COLOR_SUCCESS, "[Trade] Schimb finalizat cu succes!");
    Trade_Finalize(tid);
}

stock Trade_Cancel(tid)
{
    if(!TradeData[tid][tActive]) return;
    new s = TradeData[tid][tSenderID], r = TradeData[tid][tReceiverID];
    PlayerData[s][pCurrentTrade] = -1;
    PlayerData[r][pCurrentTrade] = -1;
    TradeData[tid][tActive] = false;
    if(IsPlayerConnected(s)) SendMsg(s, COLOR_ERROR, "[Trade] Trade anulat.");
    if(IsPlayerConnected(r)) SendMsg(r, COLOR_ERROR, "[Trade] Trade anulat.");
}

stock Trade_Finalize(tid)
{
    new s = TradeData[tid][tSenderID], r = TradeData[tid][tReceiverID];
    PlayerData[s][pCurrentTrade] = -1;
    PlayerData[r][pCurrentTrade] = -1;
    TradeData[tid][tActive] = false;
    TradeCount--;
}

CMD:trade(playerid, params[])
{
    if(!PlayerData[playerid][pLogged]) return 1;
    new targetid, price;
    new typestr[16];
    if(sscanf(params, "uis[16]i", targetid, price, typestr))
        return SendMsg(playerid, COLOR_ERROR, "Folosire: /trade [jucator] [pret] [tip: money/vehicle/house]");

    if(!IsPlayerConnected(targetid) || targetid == playerid)
        return SendMsg(playerid, COLOR_ERROR, "[!] Jucator invalid!");
    if(GetDistanceBetweenPlayers(playerid, targetid) > 5.0)
        return SendMsg(playerid, COLOR_ERROR, "[!] Trebuie sa fii mai aproape!");

    Trade_Create(playerid, targetid, typestr, 0, price);
    return 1;
}

CMD:accepttrade(playerid, params[])
{
    if(!PlayerData[playerid][pLogged]) return 1;
    new tid = PlayerData[playerid][pCurrentTrade];
    if(tid == -1) return SendMsg(playerid, COLOR_ERROR, "[!] Nu ai un trade activ!");
    if(TradeData[tid][tReceiverID] != playerid)
        return SendMsg(playerid, COLOR_ERROR, "[!] Nu esti destinatarul acestui trade!");
    Trade_Accept(playerid, tid);
    return 1;
}

CMD:denytrade(playerid, params[])
{
    if(!PlayerData[playerid][pLogged]) return 1;
    new tid = PlayerData[playerid][pCurrentTrade];
    if(tid == -1) return SendMsg(playerid, COLOR_ERROR, "[!] Nu ai un trade activ!");
    Trade_Cancel(tid);
    return 1;
}

// ============================================================
//  PRESIDENT.INC
// ============================================================

new CurrentPresident = 0;        // player ID
new PresidentPlayerID = 0;       // DB id
new IncomeTax = 10;              // % implicit
new CASSTax   = 5;
new PresidentTimer;
new bool:VoteOpen = false;
new PresidentElectionTimer;

stock President_Init()
{
    // Incarca presedintele activ din DB
    mysql_tquery(g_SQL,
        "SELECT `p`.`id`,`p`.`player_id`,`p`.`income_tax`,`p`.`cass` FROM `president` `p` WHERE `p`.`active`=1 LIMIT 1",
        "OnPresidentLoaded", "", 0);

    // Timer de verificare vot (la fiecare minut)
    PresidentTimer = SetTimer("President_CheckTime", 60000, true);
    print("[President] Sistem presedinte incarcat.");
}

forward OnPresidentLoaded();
public OnPresidentLoaded()
{
    if(cache_num_rows() == 0) return;
    cache_get_value_name_int(0, "player_id", PresidentPlayerID);
    cache_get_value_name_int(0, "income_tax", IncomeTax);
    cache_get_value_name_int(0, "cass", CASSTax);
    print("[President] Presedinte activ incarcat.");
}

forward President_CheckTime();
public President_CheckTime()
{
    new h = GetServerHour(), m = GetServerMinute();

    // Duminica = zi de vot (GetWeekDay() == 1 in conventie noastra)
    // Pornim votul la 07:00
    if(h == PRESIDENT_VOTE_START && m == 0 && !VoteOpen)
    {
        VoteOpen = true;
        SendMsgAll(COLOR_GOLD, "[Presedinte] Votul pentru presedinte a inceput! Foloseste /vote pana la 20:00. (Level 5+)");
    }

    // Inchidem votul si anuntam castigatorul la 20:05
    if(h == 20 && m == 5 && VoteOpen)
    {
        VoteOpen = false;
        President_Announce();
    }
}

stock President_Announce()
{
    mysql_tquery(g_SQL,
        "SELECT `candidate_id`, COUNT(*) as `votes` FROM `votes` "
        "WHERE DATE(`voted_at`)=CURDATE() "
        "GROUP BY `candidate_id` ORDER BY `votes` DESC LIMIT 1",
        "OnPresidentAnnounce", "", 0);
}

forward OnPresidentAnnounce();
public OnPresidentAnnounce()
{
    if(cache_num_rows() == 0)
    {
        SendMsgAll(COLOR_YELLOW, "[Presedinte] Niciun vot inregistrat astazi. Presedintele ramane acelasi.");
        return;
    }

    new winner_dbid, votes;
    cache_get_value_name_int(0, "candidate_id", winner_dbid);
    cache_get_value_name_int(0, "votes", votes);

    // Sterge presedintele anterior activ
    mysql_tquery(g_SQL, "UPDATE `president` SET `active`=0 WHERE `active`=1", "", "", 0);
    mysql_tquery(g_SQL, "UPDATE `players` SET `is_president`=0", "", "", 0);

    // Seteaza noul presedinte
    new query[256];
    mysql_format(g_SQL, query, sizeof(query),
        "INSERT INTO `president` (`player_id`,`income_tax`,`cass`,`active`,`term_end`) "
        "VALUES (%d,%d,%d,1,DATE_ADD(NOW(),INTERVAL 7 DAY))",
        winner_dbid, IncomeTax, CASSTax);
    mysql_tquery(g_SQL, query, "", "", 0);

    mysql_format(g_SQL, query, sizeof(query),
        "UPDATE `players` SET `is_president`=1,`last_president_term`=CURDATE() WHERE `id`=%d",
        winner_dbid);
    mysql_tquery(g_SQL, query, "", "", 0);

    PresidentPlayerID = winner_dbid;

    // Anunta
    new wmsg[128];
    format(wmsg, sizeof(wmsg),
        "[PRESEDINTE] Noul presedinte a fost ales cu %d voturi! (ID DB: %d)",
        votes, winner_dbid);
    SendMsgAll(COLOR_GOLD, wmsg);
}

CMD:vote(playerid, params[])
{
    if(!PlayerData[playerid][pLogged]) return 1;

    if(!VoteOpen) return SendMsg(playerid, COLOR_ERROR, "[!] Votul nu este deschis. Duminica 7:00-20:00.");
    if(PlayerData[playerid][pLevel] < MIN_LEVEL_VOTE)
        return SendMsgFmt(playerid, COLOR_ERROR, "[!] Ai nevoie de level %d pentru a vota!", MIN_LEVEL_VOTE);

    // Verifica daca a votat azi
    new query[256];
    mysql_format(g_SQL, query, sizeof(query),
        "SELECT `id` FROM `votes` WHERE `voter_id`=%d AND DATE(`voted_at`)=CURDATE() LIMIT 1",
        PlayerData[playerid][pID]);
    SetPVarInt(playerid, "VoteCheck", 1);
    mysql_tquery(g_SQL, query, "OnVoteCheck", "i", playerid);
    return 1;
}

forward OnVoteCheck(playerid);
public OnVoteCheck(playerid)
{
    if(cache_num_rows() > 0)
        return SendMsg(playerid, COLOR_ERROR, "[!] Ai votat deja astazi!");

    // Lista candidati online
    new info[512];
    new count = 0;
    for(new i = 0; i < MAX_PLAYERS; i++)
    {
        if(!IsPlayerConnected(i) || !PlayerData[i][pLogged]) continue;
        if(PlayerData[i][pLevel] < MIN_LEVEL_CANDIDATE) continue;
        if(PlayerData[i][pIsPresident]) continue; // nu poate fi de 2 ori la rand

        new line[64];
        format(line, sizeof(line), "%s (Level %d)\n", PlayerData[i][pName], PlayerData[i][pLevel]);
        strcat(info, line);
        count++;
    }

    if(count == 0)
        return SendMsg(playerid, COLOR_ERROR, "[!] Nu exista candidati valabili online acum.");

    ShowPlayerDialog(playerid, DIALOG_PRESIDENT_VOTE, DIALOG_STYLE_LIST,
        "{FFD700}Voteaza Presedinte", info, "Voteaza", "Anuleaza");
    return 1;
}

// Presedintele seteaza taxele
CMD:settax(playerid, params[])
{
    if(!PlayerData[playerid][pIsPresident])
        return SendMsg(playerid, COLOR_ERROR, "[!] Doar presedintele poate seta taxele!");

    new tax, cass;
    if(sscanf(params, "ii", tax, cass))
        return SendMsg(playerid, COLOR_ERROR, "Folosire: /settax [impozit%] [cass%]");

    if(tax < TAX_MIN || tax > TAX_MAX)
        return SendMsgFmt(playerid, COLOR_ERROR, "[!] Impozitul trebuie sa fie intre %d si %d%%!", TAX_MIN, TAX_MAX);
    if(cass < CASS_MIN || cass > CASS_MAX)
        return SendMsgFmt(playerid, COLOR_ERROR, "[!] CASS trebuie sa fie intre %d si %d%%!", CASS_MIN, CASS_MAX);

    IncomeTax = tax;
    CASSTax   = cass;

    new query[128];
    mysql_format(g_SQL, query, sizeof(query),
        "UPDATE `president` SET `income_tax`=%d,`cass`=%d WHERE `active`=1",
        IncomeTax, CASSTax);
    mysql_tquery(g_SQL, query, "", "", 0);

    new msg[128];
    format(msg, sizeof(msg),
        "[Presedinte] Taxe actualizate: Impozit=%d%%, CASS=%d%% (valabil de la urmatorul payday)",
        IncomeTax, CASSTax);
    SendMsgAll(COLOR_GOLD, msg);
    return 1;
}
