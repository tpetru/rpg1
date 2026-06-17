// ============================================================
//  PRESIDENT.INC - Sistem Presedinte
//  Vot Duminica 07:00-20:00, anunt la 20:05
//  Presedintele seteaza impozitul si CASS-ul
// ============================================================
#if defined _president_included
    #endinput
#endif
#define _president_included

// ============================================================
//  DATE GLOBALE
// ============================================================

new CurrentPresidentDBID    = 0;
new CurrentPresidentName[24]= "";
new IncomeTax               = 10;   // % implicit
new CASSTax                 = 5;    // % implicit
new bool:VoteOpen           = false;
new PresidentCheckTimer;

// Candidati construiti dinamic la fiecare /vote
new PresidentCandidates[MAX_PLAYERS];
new PresidentCandidateCount = 0;

// ============================================================
//  INIT
// ============================================================

stock President_Init()
{
    mysql_tquery(g_SQL,
        "SELECT p.player_id, p.income_tax, p.cass, pl.username "
        "FROM `president` p "
        "JOIN `players` pl ON pl.id = p.player_id "
        "WHERE p.active = 1 LIMIT 1",
        "OnPresidentLoad", "", 0);

    PresidentCheckTimer = SetTimer("President_TimerCheck", 60000, true);
    print("[President] Sistem presedinte incarcat.");
}

forward OnPresidentLoad();
public OnPresidentLoad()
{
    if(cache_num_rows() == 0)
    {
        print("[President] Niciun presedinte activ.");
        return;
    }
    cache_get_value_name_int(0, "player_id", CurrentPresidentDBID);
    cache_get_value_name_int(0, "income_tax", IncomeTax);
    cache_get_value_name_int(0, "cass", CASSTax);
    cache_get_value_name(0, "username", CurrentPresidentName, 24);

    for(new i = 0; i < MAX_PLAYERS; i++)
    {
        if(IsPlayerConnected(i) && PlayerData[i][pID] == CurrentPresidentDBID)
        {
            PlayerData[i][pIsPresident] = true;
            break;
        }
    }
    new msg[96];
    format(msg, sizeof(msg), "[President] Activ: %s | Tax:%d%% | CASS:%d%%",
        CurrentPresidentName, IncomeTax, CASSTax);
    print(msg);
}

// ============================================================
//  TIMER MINUT - verifica ora si ziua
// ============================================================

forward President_TimerCheck();
public President_TimerCheck()
{
    new h, m, s, year, month, day;
    gettime(h, m, s);
    getdate(year, month, day);

    // Calcul zi saptamana (Zeller)
    new ty = year, tm = month;
    if(tm < 3) { tm += 12; ty--; }
    new k  = ty % 100;
    new j  = ty / 100;
    new dow = (day + (13*(tm+1)/5) + k + (k/4) + (j/4) - 2*j) % 7;
    dow = ((dow % 7) + 7) % 7;
    new bool:isSunday = (dow == 1); // Zeller: 1=Duminica

    // Deschide vot 07:00
    if(isSunday && h == PRESIDENT_VOTE_START && m == 0 && !VoteOpen)
    {
        VoteOpen = true;
        SendMsgAll(COLOR_GOLD,
            "[PRESEDINTE] {FFD700}Votul pentru presedinte a inceput!{FFFFFF} "
            "Foloseste {00FF00}/vote{FFFFFF} pana la 20:00. (Level 5+ necesar)");
        GameTextForAll("~y~Vot Presedinte~n~~g~Deschis! /vote", 8000, 1);
    }

    // Reminder 19:00
    if(isSunday && h == 19 && m == 0 && VoteOpen)
        SendMsgAll(COLOR_YELLOW,
            "[PRESEDINTE] Reminder: mai ai 1 ora sa votezi! /vote");

    // Inchide vot + anunta castigator 20:05
    if(isSunday && h == 20 && m == 5 && VoteOpen)
    {
        VoteOpen = false;
        SendMsgAll(COLOR_GOLD, "[PRESEDINTE] Votul s-a incheiat! Numaratoare in curs...");
        President_CountVotes();
    }
}

// ============================================================
//  NUMARATOARE VOTURI
// ============================================================

stock President_CountVotes()
{
    mysql_tquery(g_SQL,
        "SELECT candidate_id, COUNT(*) AS total "
        "FROM `votes` WHERE DATE(voted_at)=CURDATE() "
        "GROUP BY candidate_id ORDER BY total DESC LIMIT 1",
        "OnPresidentVoteResult", "", 0);
}

forward OnPresidentVoteResult();
public OnPresidentVoteResult()
{
    if(cache_num_rows() == 0)
    {
        SendMsgAll(COLOR_YELLOW,
            "[PRESEDINTE] Niciun vot astazi. Presedintele anterior ramane in functie.");
        return;
    }
    new winner_id, total;
    cache_get_value_name_int(0, "candidate_id", winner_id);
    cache_get_value_name_int(0, "total", total);

    // Verifica eligibilitate (nu a fost presedinte luna aceasta)
    new query[256];
    mysql_format(g_SQL, query, sizeof(query),
        "SELECT id FROM `players` WHERE id=%d "
        "AND last_president_term >= DATE_FORMAT(NOW(),'%%Y-%%m-01') LIMIT 1",
        winner_id);
    mysql_tquery(g_SQL, query, "OnPresidentEligCheck", "ii", winner_id, total);
}

forward OnPresidentEligCheck(winner_id, total);
public OnPresidentEligCheck(winner_id, total)
{
    if(cache_num_rows() > 0)
    {
        // Deja presedinte luna asta -> urmatorul clasat
        SendMsgAll(COLOR_YELLOW,
            "[PRESEDINTE] Castigatorul a mai fost presedinte luna aceasta. Verificam urmatorul...");
        mysql_tquery(g_SQL,
            "SELECT candidate_id, COUNT(*) AS total "
            "FROM `votes` WHERE DATE(voted_at)=CURDATE() "
            "GROUP BY candidate_id ORDER BY total DESC LIMIT 1 OFFSET 1",
            "OnPresidentFallbackResult", "", 0);
        return;
    }
    President_Elect(winner_id, total);
}

forward OnPresidentFallbackResult();
public OnPresidentFallbackResult()
{
    if(cache_num_rows() == 0)
    {
        SendMsgAll(COLOR_YELLOW,
            "[PRESEDINTE] Niciun candidat eligibil. Presedintele anterior ramane.");
        return;
    }
    new winner_id, total;
    cache_get_value_name_int(0, "candidate_id", winner_id);
    cache_get_value_name_int(0, "total", total);
    President_Elect(winner_id, total);
}

// ============================================================
//  ALEGERE PRESEDINTE
// ============================================================

stock President_Elect(winner_dbid, total_votes)
{
    // Sterge presedinte vechi
    mysql_tquery(g_SQL, "UPDATE `president` SET active=0 WHERE active=1", "", "", 0);
    mysql_tquery(g_SQL, "UPDATE `players` SET is_president=0", "", "", 0);

    for(new i = 0; i < MAX_PLAYERS; i++)
        if(IsPlayerConnected(i)) PlayerData[i][pIsPresident] = false;

    // Insereaza noul presedinte (pastreaza taxele anterioare)
    new query[256];
    mysql_format(g_SQL, query, sizeof(query),
        "INSERT INTO `president` (player_id, income_tax, cass, active, term_end) "
        "VALUES (%d, %d, %d, 1, DATE_ADD(NOW(), INTERVAL 7 DAY))",
        winner_dbid, IncomeTax, CASSTax);
    mysql_tquery(g_SQL, query, "", "", 0);

    mysql_format(g_SQL, query, sizeof(query),
        "UPDATE `players` SET is_president=1, last_president_term=CURDATE() WHERE id=%d",
        winner_dbid);
    mysql_tquery(g_SQL, query, "", "", 0);

    CurrentPresidentDBID = winner_dbid;

    new winner_name[24] = "Necunoscut";
    for(new i = 0; i < MAX_PLAYERS; i++)
    {
        if(!IsPlayerConnected(i) || PlayerData[i][pID] != winner_dbid) continue;
        PlayerData[i][pIsPresident] = true;
        format(winner_name, 24, "%s", PlayerData[i][pName]);
        format(CurrentPresidentName, 24, "%s", winner_name);
        GameTextForPlayer(i, "~y~Felicitari!~n~~g~Esti noul Presedinte!", 10000, 1);
        SendMsg(i, COLOR_GOLD,
            "[PRESEDINTE] Felicitari! Esti noul presedinte! Seteaza taxele cu /settax [impozit] [cass].");
        break;
    }

    new msg[192];
    format(msg, sizeof(msg),
        "[PRESEDINTE] {FFD700}%s{FFFFFF} este noul presedinte cu {00FF00}%d voturi{FFFFFF}! "
        "Impozit: {FFD700}%d%%{FFFFFF} | CASS: {FFD700}%d%%",
        winner_name, total_votes, IncomeTax, CASSTax);
    SendMsgAll(COLOR_GOLD, msg);
    GameTextForAll("~y~Nou Presedinte Ales!", 6000, 1);
}

// ============================================================
//  COMENZI
// ============================================================

CMD:vote(playerid, params[])
{
    if(!PlayerData[playerid][pLogged])
        return SendMsg(playerid, COLOR_ERROR, "[!] Trebuie sa fii logat!");
    if(!VoteOpen)
        return SendMsg(playerid, COLOR_ERROR,
            "[!] Votul nu e deschis. Are loc Duminica 07:00-20:00.");
    if(PlayerData[playerid][pLevel] < MIN_LEVEL_VOTE)
        return SendMsgFmt(playerid, COLOR_ERROR,
            "[!] Ai nevoie de minim level %d pentru a vota!", MIN_LEVEL_VOTE);

    new query[128];
    mysql_format(g_SQL, query, sizeof(query),
        "SELECT id FROM `votes` WHERE voter_id=%d AND DATE(voted_at)=CURDATE() LIMIT 1",
        PlayerData[playerid][pID]);
    mysql_tquery(g_SQL, query, "OnVoteCheck", "i", playerid);
    return 1;
}

forward OnVoteCheck(playerid);
public OnVoteCheck(playerid)
{
    if(cache_num_rows() > 0)
        return SendMsg(playerid, COLOR_ERROR, "[!] Ai votat deja astazi!");

    PresidentCandidateCount = 0;
    new info[1024] = "";

    for(new i = 0; i < MAX_PLAYERS; i++)
    {
        if(!IsPlayerConnected(i) || !PlayerData[i][pLogged] || i == playerid) continue;
        if(PlayerData[i][pLevel] < MIN_LEVEL_CANDIDATE) continue;
        if(PlayerData[i][pIsPresident]) continue;

        PresidentCandidates[PresidentCandidateCount++] = i;

        new line[96];
        format(line, sizeof(line), "{FFD700}%s{FFFFFF} | Level %d | %s\n",
            PlayerData[i][pName], PlayerData[i][pLevel],
            Faction_GetName(PlayerData[i][pFaction]));
        strcat(info, line);
    }

    if(!PresidentCandidateCount)
        return SendMsg(playerid, COLOR_ERROR,
            "[!] Niciun candidat eligibil online. (Level 10+, sa nu fi fost presedinte luna aceasta)");

    ShowPlayerDialog(playerid, DIALOG_PRESIDENT_VOTE, DIALOG_STYLE_LIST,
        "{FFD700}Voteaza Presedinte", info, "Voteaza", "Anuleaza");
    return 1;
}

CMD:settax(playerid, params[])
{
    if(!PlayerData[playerid][pLogged]) return 1;
    if(!PlayerData[playerid][pIsPresident])
        return SendMsg(playerid, COLOR_ERROR, "[!] Doar presedintele poate seta taxele!");

    new tax, cass;
    if(sscanf(params, "ii", tax, cass))
    {
        SendMsg(playerid, COLOR_ERROR, "Folosire: /settax [impozit%] [cass%]");
        SendMsgFmt(playerid, COLOR_GREY, "Limite: impozit %d-%d%%, cass %d-%d%%",
            TAX_MIN, TAX_MAX, CASS_MIN, CASS_MAX);
        return 1;
    }
    if(tax < TAX_MIN || tax > TAX_MAX)
        return SendMsgFmt(playerid, COLOR_ERROR,
            "[!] Impozit intre %d-%d%%!", TAX_MIN, TAX_MAX);
    if(cass < CASS_MIN || cass > CASS_MAX)
        return SendMsgFmt(playerid, COLOR_ERROR,
            "[!] CASS intre %d-%d%%!", CASS_MIN, CASS_MAX);

    IncomeTax = tax;
    CASSTax   = cass;

    new query[128];
    mysql_format(g_SQL, query, sizeof(query),
        "UPDATE `president` SET income_tax=%d, cass=%d WHERE active=1",
        IncomeTax, CASSTax);
    mysql_tquery(g_SQL, query, "", "", 0);

    new msg[192];
    format(msg, sizeof(msg),
        "[PRESEDINTE] {FFD700}%s{FFFFFF} a modificat taxele: "
        "Impozit {FFD700}%d%%{FFFFFF} | CASS {FFD700}%d%%{FFFFFF} (valabil la urmatorul payday)",
        PlayerData[playerid][pName], IncomeTax, CASSTax);
    SendMsgAll(COLOR_GOLD, msg);
    return 1;
}

CMD:president(playerid, params[])
{
    if(!PlayerData[playerid][pLogged]) return 1;
    new info[320];
    if(!CurrentPresidentDBID)
        format(info, sizeof(info),
            "{FFFFFF}Niciun presedinte ales.\n\n"
            "Votul are loc {FFD700}Duminica{FFFFFF} 07:00-20:00.\n"
            "Impozit curent: {FFD700}%d%%{FFFFFF} | CASS: {FFD700}%d%%",
            IncomeTax, CASSTax);
    else
        format(info, sizeof(info),
            "{FFD700}Presedinte:{FFFFFF} %s\n\n"
            "Impozit pe venit: {FFD700}%d%%\n"
            "{FFFFFF}CASS: {FFD700}%d%%\n\n"
            "{FFFFFF}Votul are loc {FFD700}Duminica{FFFFFF} 07:00-20:00 | Rezultate la 20:05\n"
            "Voteaza cu {00FF00}/vote",
            CurrentPresidentName, IncomeTax, CASSTax);
    ShowPlayerDialog(playerid, 9998, DIALOG_STYLE_MSGBOX,
        "{FFD700}Presedintele Romaniei", info, "Inchide", "");
    return 1;
}

CMD:voterinfo(playerid, params[])
{
    if(!IsAdmin(playerid, 2))
        return SendMsg(playerid, COLOR_ERROR, "[!] Acces interzis!");
    mysql_tquery(g_SQL,
        "SELECT pl.username, COUNT(v.id) AS total "
        "FROM `votes` v JOIN `players` pl ON pl.id=v.candidate_id "
        "WHERE DATE(v.voted_at)=CURDATE() "
        "GROUP BY v.candidate_id ORDER BY total DESC",
        "OnVoterInfo", "i", playerid);
    return 1;
}

forward OnVoterInfo(playerid);
public OnVoterInfo(playerid)
{
    new rows = cache_num_rows();
    if(!rows) return SendMsg(playerid, COLOR_GREY, "[Presedinte] Niciun vot astazi.");
    new info[512];
    strcat(info, "{FFD700}Situatia voturilor:\n\n");
    for(new i = 0; i < rows; i++)
    {
        new uname[24]; new total;
        cache_get_value_name(i, "username", uname, 24);
        cache_get_value_name_int(i, "total", total);
        new line[64];
        format(line, sizeof(line), "%s: {00FF00}%d voturi\n", uname, total);
        strcat(info, line);
    }
    ShowPlayerDialog(playerid, 9998, DIALOG_STYLE_MSGBOX, "Voturi Astazi", info, "Inchide", "");
    return 1;
}

// Handler dialog (apelat din events.inc)
stock President_OnDialog(playerid, dialogid, response, listitem, inputtext[])
{
    if(dialogid == DIALOG_PRESIDENT_VOTE && response)
    {
        if(listitem < 0 || listitem >= PresidentCandidateCount) return 1;
        new cid = PresidentCandidates[listitem];
        new query[128];
        mysql_format(g_SQL, query, sizeof(query),
            "INSERT INTO `votes` (voter_id, candidate_id) VALUES (%d,%d)",
            PlayerData[playerid][pID], PlayerData[cid][pID]);
        mysql_tquery(g_SQL, query, "", "", 0);
        SendMsgFmt(playerid, COLOR_SUCCESS,
            "[PRESEDINTE] Ai votat pentru {FFD700}%s{00FF44}!", PlayerData[cid][pName]);
        SendMsgFmt(cid, COLOR_YELLOW,
            "[PRESEDINTE] {FFD700}%s{FFFFFF} a votat pentru tine!", PlayerData[playerid][pName]);
    }
    return 1;
}

// Getteri pentru payday.inc
stock President_GetIncomeTax() { return IncomeTax; }
stock President_GetCASS()      { return CASSTax; }
