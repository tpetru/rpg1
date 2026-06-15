// ============================================================
//  PLAYER.INC - Sistem Jucatori, Register/Login, Level, Payday
// ============================================================
#if defined _player_included
    #endinput
#endif
#define _player_included

// ============================================================
//  DATE JUCATOR
// ============================================================

enum E_PLAYER_DATA
{
    pID, pName[24], pPass[64], pEmail[64],
    pLevel, pXP, pMoney, pBank, pRP,
    Float:pHealth, Float:pArmour,
    pSkin, pFaction, pFactionRank, pJob,
    Float:pX, Float:pY, Float:pZ,
    pInterior, pVW,
    pWanted, bool:pJailed, pJailTime,
    pFines, bool:pSick, pDiseaseName[32],
    pLastVoteDate[12], pVotedCandidate,
    pLastPresidentTerm[12], bool:pIsPresident,
    pKills, pDeaths, pPlayHours,
    pAdminLevel,
    bool:pLogged, bool:pRegistered,
    pLoginAttempts,
    pDiseaseTimer,
    pPlayTimer,
    bool:pOnDuty,           // uber/job duty
    pUberRating,
    bool:pInTour, pTourID,
    pCurrentTrade,
    pCarryItem, pCarryItemID // pentru bolt food/truck
}

new PlayerData[MAX_PLAYERS][E_PLAYER_DATA];

// ============================================================
//  CONNECT / DISCONNECT
// ============================================================

stock Player_OnConnect(playerid)
{
    // Resetare date
    PlayerData[playerid][pID]           = 0;
    PlayerData[playerid][pLevel]        = 1;
    PlayerData[playerid][pXP]           = 0;
    PlayerData[playerid][pMoney]        = 500;
    PlayerData[playerid][pBank]         = 0;
    PlayerData[playerid][pRP]           = 0;
    PlayerData[playerid][pHealth]       = 100.0;
    PlayerData[playerid][pArmour]       = 0.0;
    PlayerData[playerid][pSkin]         = 0;
    PlayerData[playerid][pFaction]      = FACTION_NONE;
    PlayerData[playerid][pFactionRank]  = 0;
    PlayerData[playerid][pJob]          = JOB_NONE;
    PlayerData[playerid][pWanted]       = 0;
    PlayerData[playerid][pJailed]       = false;
    PlayerData[playerid][pJailTime]     = 0;
    PlayerData[playerid][pFines]        = 0;
    PlayerData[playerid][pSick]         = false;
    PlayerData[playerid][pLogged]       = false;
    PlayerData[playerid][pRegistered]   = false;
    PlayerData[playerid][pLoginAttempts]= 0;
    PlayerData[playerid][pAdminLevel]   = 0;
    PlayerData[playerid][pOnDuty]       = false;
    PlayerData[playerid][pInTour]       = false;
    PlayerData[playerid][pCurrentTrade] = -1;

    GetPlayerName(playerid, PlayerData[playerid][pName], 24);
    TogglePlayerSpectating(playerid, 1);
    Player_CheckExists(playerid);
}

stock Player_OnDisconnect(playerid, reason)
{
    if(PlayerData[playerid][pLogged])
    {
        Player_SaveData(playerid);
        Pets_SaveAll(playerid);
        Vehicles_SaveAll(playerid);
    }

    // Oprire timere
    if(PlayerData[playerid][pDiseaseTimer])
        KillTimer(PlayerData[playerid][pDiseaseTimer]);
    if(PlayerData[playerid][pPlayTimer])
        KillTimer(PlayerData[playerid][pPlayTimer]);

    // Curata trade activ
    if(PlayerData[playerid][pCurrentTrade] != -1)
        Trade_Cancel(PlayerData[playerid][pCurrentTrade]);
}

stock Player_OnSpawn(playerid)
{
    if(!PlayerData[playerid][pLogged]) return;

    SetPlayerSkin(playerid, PlayerData[playerid][pSkin]);
    SetPlayerHealth(playerid, PlayerData[playerid][pHealth]);
    SetPlayerArmour(playerid, PlayerData[playerid][pArmour]);
    GivePlayerMoney(playerid, -GetPlayerMoney(playerid));
    GivePlayerMoney(playerid, PlayerData[playerid][pMoney]);

    if(PlayerData[playerid][pJailed])
    {
        SetPlayerPos(playerid, 264.35, 75.62, 1001.04);
        SetPlayerInterior(playerid, 6);
        return;
    }

    SetPlayerPos(playerid, PlayerData[playerid][pX], PlayerData[playerid][pY], PlayerData[playerid][pZ]);
    SetPlayerInterior(playerid, PlayerData[playerid][pInterior]);
    SetPlayerVirtualWorld(playerid, PlayerData[playerid][pVW]);

    Player_StartPlayTimer(playerid);

    if(PlayerData[playerid][pSick])
        Disease_StartDecay(playerid);

    // HUD info
    Player_ShowHUD(playerid);
}

stock Player_OnDeath(playerid, killerid, reason)
{
    PlayerData[playerid][pDeaths]++;
    if(killerid != INVALID_PLAYER_ID)
        PlayerData[killerid][pKills]++;

    // Salvare pozitie spital
    PlayerData[playerid][pX] = 1185.89;
    PlayerData[playerid][pY] = -1322.34;
    PlayerData[playerid][pZ] = 13.58;
    PlayerData[playerid][pInterior] = 0;
    PlayerData[playerid][pHealth] = 50.0;
    Player_SaveData(playerid);
}

stock Player_OnText(playerid, text[])
{
    if(!PlayerData[playerid][pLogged]) return 0;

    new msg[144];
    new name[24];
    GetPlayerName(playerid, name, 24);

    // Chat colorat dupa factiune
    new color = COLOR_WHITE;
    if(PlayerData[playerid][pFaction] > 0)
        color = Faction_GetColor(PlayerData[playerid][pFaction]);

    format(msg, sizeof(msg), "[Lv.%d] %s: %s",
        PlayerData[playerid][pLevel], name, text);
    SendClientMessageToAll(color, msg);
    return 0;
}

// ============================================================
//  VERIFICARE / INREGISTRARE / LOGIN
// ============================================================

stock Player_CheckExists(playerid)
{
    new query[128];
    mysql_format(g_SQL, query, sizeof(query),
        "SELECT `id`,`password` FROM `players` WHERE `username`='%e' LIMIT 1",
        PlayerData[playerid][pName]);
    mysql_tquery(g_SQL, query, "OnPlayerCheckExists", "i", playerid);
}

forward OnPlayerCheckExists(playerid);
public OnPlayerCheckExists(playerid)
{
    if(cache_num_rows() > 0)
    {
        cache_get_value_name_int(0, "id", PlayerData[playerid][pID]);
        cache_get_value_name(0, "password", PlayerData[playerid][pPass], 64);
        PlayerData[playerid][pRegistered] = true;
        Player_ShowLogin(playerid);
    }
    else
    {
        PlayerData[playerid][pRegistered] = false;
        Player_ShowRegister(playerid);
    }
}

stock Player_ShowRegister(playerid)
{
    ShowPlayerDialog(playerid, DIALOG_REGISTER, DIALOG_STYLE_MSGBOX, 
        "{FFD700}Romania RPG - Inregistrare",
        "{FFFFFF}Bun venit pe {FFD700}Romania RPG{FFFFFF}!\n\n"
        "Acest cont nu exista. Apasa {00FF00}Inregistreaza{FFFFFF} pentru a-ti crea contul.",
        "Inregistreaza", "Iesi");
}

forward OnDialogRegister(playerid, response, listitem, inputtext[]);

stock Player_ShowRegisterPass(playerid)
{
    ShowPlayerDialog(playerid, DIALOG_REGISTER_PASS, DIALOG_STYLE_PASSWORD,
        "{FFD700}Romania RPG - Seteaza Parola",
        "{FFFFFF}Introdu o {00FF00}parola{FFFFFF} pentru contul tau:\n"
        "(minim 6 caractere)",
        "Continua", "Inapoi");
}

stock Player_ShowLogin(playerid)
{
    ShowPlayerDialog(playerid, DIALOG_LOGIN, DIALOG_STYLE_PASSWORD,
        "{FFD700}Romania RPG - Autentificare",
        "{FFFFFF}Bun venit inapoi! Introdu {00FF00}parola{FFFFFF} pentru a te loga:",
        "Logheaza-te", "Iesi");
}

stock Player_Register(playerid, const pass[])
{
    if(strlen(pass) < 6)
    {
        SendMsg(playerid, COLOR_ERROR, "[!] Parola trebuie sa aiba minim 6 caractere!");
        Player_ShowRegisterPass(playerid);
        return;
    }

    new hash[33];
    HashPassword(pass, hash);

    new query[256];
    mysql_format(g_SQL, query, sizeof(query),
        "INSERT INTO `players` (`username`,`password`) VALUES ('%e','%e')",
        PlayerData[playerid][pName], hash);
    mysql_tquery(g_SQL, query, "OnPlayerRegisterComplete", "i", playerid);
}

forward OnPlayerRegisterComplete(playerid);
public OnPlayerRegisterComplete(playerid)
{
    PlayerData[playerid][pID] = cache_insert_id();
    PlayerData[playerid][pLogged] = true;
    PlayerData[playerid][pRegistered] = true;
    PlayerData[playerid][pLevel] = 1;
    PlayerData[playerid][pMoney] = 500;

    TogglePlayerSpectating(playerid, 0);
    SetSpawnInfo(playerid, 0, 0, 1958.33, 1343.12, 15.36, 0.0, 0,0,0,0,0,0);
    SpawnPlayer(playerid);

    SendMsg(playerid, COLOR_SUCCESS, "[!] Cont creat cu succes! Bun venit pe Romania RPG!");
    SendMsg(playerid, COLOR_YELLOW, "[!] Incepe cu /help pentru comenzi si /job pentru un loc de munca.");
    GameTextForPlayer(playerid, "~g~Bun venit pe Romania RPG!", 5000, 1);
}

stock Player_Login(playerid, const pass[])
{
    PlayerData[playerid][pLoginAttempts]++;
    if(PlayerData[playerid][pLoginAttempts] > 3)
    {
        SendMsg(playerid, COLOR_ERROR, "[!] Prea multe incercari! Ai fost deconectat.");
        Kick(playerid);
        return;
    }

    new hash[33];
    HashPassword(pass, hash);

    if(!strcmp(hash, PlayerData[playerid][pPass], true))
    {
        Player_LoadData(playerid);
    }
    else
    {
        new attempts = 3 - PlayerData[playerid][pLoginAttempts];
        new msg[64];
        format(msg, sizeof(msg), "[!] Parola gresita! Incercari ramase: %d", attempts);
        SendMsg(playerid, COLOR_ERROR, msg);
        Player_ShowLogin(playerid);
    }
}

stock Player_LoadData(playerid)
{
    new query[128];
    mysql_format(g_SQL, query, sizeof(query),
        "SELECT * FROM `players` WHERE `id`=%d LIMIT 1",
        PlayerData[playerid][pID]);
    mysql_tquery(g_SQL, query, "OnPlayerDataLoaded", "i", playerid);
}

forward OnPlayerDataLoaded(playerid);
public OnPlayerDataLoaded(playerid)
{
    if(cache_num_rows() == 0) return;

    cache_get_value_name_int(0, "level", PlayerData[playerid][pLevel]);
    cache_get_value_name_int(0, "xp", PlayerData[playerid][pXP]);
    cache_get_value_name_int(0, "money", PlayerData[playerid][pMoney]);
    cache_get_value_name_int(0, "bank", PlayerData[playerid][pBank]);
    cache_get_value_name_int(0, "rp", PlayerData[playerid][pRP]);
    cache_get_value_name_float(0, "health", PlayerData[playerid][pHealth]);
    cache_get_value_name_float(0, "armour", PlayerData[playerid][pArmour]);
    cache_get_value_name_int(0, "skin", PlayerData[playerid][pSkin]);
    cache_get_value_name_int(0, "faction", PlayerData[playerid][pFaction]);
    cache_get_value_name_int(0, "faction_rank", PlayerData[playerid][pFactionRank]);
    cache_get_value_name_int(0, "job", PlayerData[playerid][pJob]);
    cache_get_value_name_float(0, "pos_x", PlayerData[playerid][pX]);
    cache_get_value_name_float(0, "pos_y", PlayerData[playerid][pY]);
    cache_get_value_name_float(0, "pos_z", PlayerData[playerid][pZ]);
    cache_get_value_name_int(0, "interior", PlayerData[playerid][pInterior]);
    cache_get_value_name_int(0, "vw", PlayerData[playerid][pVW]);
    cache_get_value_name_int(0, "wanted", PlayerData[playerid][pWanted]);
    cache_get_value_name_int(0, "fines", PlayerData[playerid][pFines]);
    cache_get_value_name_int(0, "kills", PlayerData[playerid][pKills]);
    cache_get_value_name_int(0, "deaths", PlayerData[playerid][pDeaths]);
    cache_get_value_name_int(0, "play_hours", PlayerData[playerid][pPlayHours]);

    new sick;
    cache_get_value_name_int(0, "is_sick", sick);
    PlayerData[playerid][pSick] = (sick == 1);
    cache_get_value_name(0, "disease_name", PlayerData[playerid][pDiseaseName], 32);

    new jailed;
    cache_get_value_name_int(0, "jailed", jailed);
    PlayerData[playerid][pJailed] = (jailed == 1);
    cache_get_value_name_int(0, "jail_time", PlayerData[playerid][pJailTime]);

    new is_pres;
    cache_get_value_name_int(0, "is_president", is_pres);
    PlayerData[playerid][pIsPresident] = (is_pres == 1);
    cache_get_value_name(0, "last_voted_president", PlayerData[playerid][pLastVoteDate], 12);

    PlayerData[playerid][pLogged] = true;
    PlayerData[playerid][pLoginAttempts] = 0;

    TogglePlayerSpectating(playerid, 0);
    SetSpawnInfo(playerid, 0, PlayerData[playerid][pSkin],
        PlayerData[playerid][pX], PlayerData[playerid][pY], PlayerData[playerid][pZ],
        0.0, 0,0,0,0,0,0);
    SpawnPlayer(playerid);

    // Update last login
    new query[128];
    mysql_format(g_SQL, query, sizeof(query),
        "UPDATE `players` SET `last_login`=NOW() WHERE `id`=%d",
        PlayerData[playerid][pID]);
    mysql_tquery(g_SQL, query, "", "", 0);

    SendMsg(playerid, COLOR_SUCCESS, "[!] Autentificat cu succes!");

    // Incarca vehicule, animale
    Vehicles_LoadForPlayer(playerid);
    Pets_LoadForPlayer(playerid);
}

stock Player_SaveData(playerid)
{
    if(!PlayerData[playerid][pLogged]) return;

    new Float:hp, Float:arm, Float:x, Float:y, Float:z;
    GetPlayerHealth(playerid, hp);
    GetPlayerArmour(playerid, arm);
    GetPlayerPos(playerid, x, y, z);
    PlayerData[playerid][pHealth] = hp;
    PlayerData[playerid][pArmour] = arm;
    PlayerData[playerid][pX] = x;
    PlayerData[playerid][pY] = y;
    PlayerData[playerid][pZ] = z;
    PlayerData[playerid][pInterior] = GetPlayerInterior(playerid);
    PlayerData[playerid][pVW] = GetPlayerVirtualWorld(playerid);
    PlayerData[playerid][pMoney] = GetPlayerMoney(playerid);

    new query[512];
    mysql_format(g_SQL, query, sizeof(query),
        "UPDATE `players` SET "
        "`level`=%d,`xp`=%d,`money`=%d,`bank`=%d,`rp`=%d,"
        "`health`=%.2f,`armour`=%.2f,`skin`=%d,"
        "`faction`=%d,`faction_rank`=%d,`job`=%d,"
        "`pos_x`=%.4f,`pos_y`=%.4f,`pos_z`=%.4f,"
        "`interior`=%d,`vw`=%d,`wanted`=%d,"
        "`jailed`=%d,`jail_time`=%d,`fines`=%d,"
        "`is_sick`=%d,`disease_name`='%e',"
        "`is_president`=%d,`last_voted_president`='%e',"
        "`kills`=%d,`deaths`=%d,`play_hours`=%d "
        "WHERE `id`=%d",
        PlayerData[playerid][pLevel], PlayerData[playerid][pXP],
        PlayerData[playerid][pMoney], PlayerData[playerid][pBank],
        PlayerData[playerid][pRP],
        PlayerData[playerid][pHealth], PlayerData[playerid][pArmour],
        PlayerData[playerid][pSkin],
        PlayerData[playerid][pFaction], PlayerData[playerid][pFactionRank],
        PlayerData[playerid][pJob],
        PlayerData[playerid][pX], PlayerData[playerid][pY], PlayerData[playerid][pZ],
        PlayerData[playerid][pInterior], PlayerData[playerid][pVW],
        PlayerData[playerid][pWanted],
        PlayerData[playerid][pJailed] ? 1 : 0, PlayerData[playerid][pJailTime],
        PlayerData[playerid][pFines],
        PlayerData[playerid][pSick] ? 1 : 0, PlayerData[playerid][pDiseaseName],
        PlayerData[playerid][pIsPresident] ? 1 : 0, PlayerData[playerid][pLastVoteDate],
        PlayerData[playerid][pKills], PlayerData[playerid][pDeaths],
        PlayerData[playerid][pPlayHours],
        PlayerData[playerid][pID]);
    mysql_tquery(g_SQL, query, "", "", 0);
}

// ============================================================
//  NIVEL / XP
// ============================================================

stock Player_AddXP(playerid, amount)
{
    PlayerData[playerid][pXP] += amount;
    new needed = PlayerData[playerid][pLevel] * XP_PER_LEVEL;
    if(PlayerData[playerid][pXP] >= needed && PlayerData[playerid][pLevel] < MAX_LEVEL)
    {
        PlayerData[playerid][pXP] -= needed;
        PlayerData[playerid][pLevel]++;
        Player_OnLevelUp(playerid);
    }
    Player_UpdateHUD(playerid);
}

stock Player_OnLevelUp(playerid)
{
    new msg[64];
    format(msg, sizeof(msg), "~y~Felicitari! Ai urcat la nivelul %d!", PlayerData[playerid][pLevel]);
    GameTextForPlayer(playerid, msg, 5000, 1);
    SendMsgFmt(playerid, COLOR_GOLD,
        "[LEVEL UP] Ai ajuns la nivelul %d! Salariul tau a crescut.",
        PlayerData[playerid][pLevel]);
    SetPlayerScore(playerid, PlayerData[playerid][pLevel]);
}

// ============================================================
//  HUD
// ============================================================

new Text:HUD_Bg[MAX_PLAYERS];
new Text:HUD_Info[MAX_PLAYERS];

stock Player_ShowHUD(playerid)
{
    Player_UpdateHUD(playerid);
}

stock Player_UpdateHUD(playerid)
{
    if(HUD_Info[playerid] != Text:INVALID_TEXT_DRAW)
        TextDrawHideForPlayer(playerid, HUD_Info[playerid]);

    // Recream textdraw-ul
    // In practica, s-ar folosi textdraw-uri persistente
}

// ============================================================
//  PLAY TIMER (ore jucate)
// ============================================================

stock Player_StartPlayTimer(playerid)
{
    if(PlayerData[playerid][pPlayTimer])
        KillTimer(PlayerData[playerid][pPlayTimer]);
    PlayerData[playerid][pPlayTimer] = SetTimerEx("OnPlayerPlayHour", 3600000, true, "i", playerid);
}

forward OnPlayerPlayHour(playerid);
public OnPlayerPlayHour(playerid)
{
    if(!IsPlayerConnected(playerid) || !PlayerData[playerid][pLogged]) return;
    PlayerData[playerid][pPlayHours]++;
    Player_AddXP(playerid, 50);
}

// ============================================================
//  DIALOG HANDLER - AUTH
// ============================================================

stock Dialog_Auth_Response(playerid, dialogid, response, listitem, inputtext[])
{
    switch(dialogid)
    {
        case DIALOG_REGISTER:
        {
            if(!response) { Kick(playerid); return 1; }
            Player_ShowRegisterPass(playerid);
        }
        case DIALOG_REGISTER_PASS:
        {
            if(!response) { Player_ShowRegister(playerid); return 1; }
            Player_Register(playerid, inputtext);
        }
        case DIALOG_LOGIN:
        {
            if(!response) { Kick(playerid); return 1; }
            Player_Login(playerid, inputtext);
        }
    }
    return 1;
}

// ============================================================
//  COMENZI PLAYER
// ============================================================

CMD:stats(playerid, params[])
{
    if(!PlayerData[playerid][pLogged]) return 1;

    new info[512], name[24];
    GetPlayerName(playerid, name, 24);
    format(info, sizeof(info),
        "{FFD700}== Statistici: %s ==\n\n"
        "{FFFFFF}Nivel: {00FF00}%d {FFFFFF}| XP: {00FF00}%d/%d\n"
        "Bani: {00FF00}$%d {FFFFFF}| Banca: {00FF00}$%d\n"
        "RP: {00FF00}%d\n"
        "Job: {00FF00}%s\n"
        "Factiune: {00FF00}%s {FFFFFF}(Rang %d)\n"
        "Kills: {FF4444}%d {FFFFFF}| Deaths: {FF4444}%d\n"
        "Ore jucate: {00FF00}%d\n"
        "Amenzi: {FF4444}$%d\n"
        "Wanted: {FF4444}%d\n"
        "Stare sanatate: {00FF00}%s",
        name,
        PlayerData[playerid][pLevel], PlayerData[playerid][pXP], PlayerData[playerid][pLevel]*XP_PER_LEVEL,
        PlayerData[playerid][pMoney], PlayerData[playerid][pBank],
        PlayerData[playerid][pRP],
        Job_GetName(PlayerData[playerid][pJob]),
        Faction_GetName(PlayerData[playerid][pFaction]), PlayerData[playerid][pFactionRank],
        PlayerData[playerid][pKills], PlayerData[playerid][pDeaths],
        PlayerData[playerid][pPlayHours],
        PlayerData[playerid][pFines],
        PlayerData[playerid][pWanted],
        PlayerData[playerid][pSick] ? "Bolnav" : "Sanatos"
    );

    ShowPlayerDialog(playerid, 9999, DIALOG_STYLE_MSGBOX, "{FFD700}Statistici", info, "Inchide", "");
    return 1;
}

CMD:deposit(playerid, params[])
{
    if(!PlayerData[playerid][pLogged]) return 1;
    new amount;
    if(sscanf(params, "i", amount)) return SendMsg(playerid, COLOR_ERROR, "Folosire: /deposit [suma]");
    if(amount <= 0 || amount > GetPlayerMoney(playerid))
        return SendMsg(playerid, COLOR_ERROR, "[!] Suma invalida!");

    GivePlayerMoney(playerid, -amount);
    PlayerData[playerid][pBank] += amount;
    PlayerData[playerid][pMoney] = GetPlayerMoney(playerid);
    SendMsgFmt(playerid, COLOR_SUCCESS, "[Banca] Ai depus $%d in cont.", amount);
    return 1;
}

CMD:withdraw(playerid, params[])
{
    if(!PlayerData[playerid][pLogged]) return 1;
    new amount;
    if(sscanf(params, "i", amount)) return SendMsg(playerid, COLOR_ERROR, "Folosire: /withdraw [suma]");
    if(amount <= 0 || amount > PlayerData[playerid][pBank])
        return SendMsg(playerid, COLOR_ERROR, "[!] Nu ai suficienti bani in banca!");

    GivePlayerMoney(playerid, amount);
    PlayerData[playerid][pBank] -= amount;
    PlayerData[playerid][pMoney] = GetPlayerMoney(playerid);
    SendMsgFmt(playerid, COLOR_SUCCESS, "[Banca] Ai retras $%d din cont.", amount);
    return 1;
}

CMD:pay(playerid, params[])
{
    if(!PlayerData[playerid][pLogged]) return 1;
    new targetid, amount;
    if(sscanf(params, "ui", targetid, amount))
        return SendMsg(playerid, COLOR_ERROR, "Folosire: /pay [jucator] [suma]");
    if(!IsPlayerConnected(targetid) || targetid == playerid)
        return SendMsg(playerid, COLOR_ERROR, "[!] Jucator invalid!");
    if(amount <= 0 || amount > GetPlayerMoney(playerid))
        return SendMsg(playerid, COLOR_ERROR, "[!] Suma invalida!");

    GivePlayerMoney(playerid, -amount);
    GivePlayerMoney(targetid, amount);
    PlayerData[playerid][pMoney] -= amount;
    PlayerData[targetid][pMoney] += amount;

    new name[24], tname[24];
    GetPlayerName(playerid, name, 24);
    GetPlayerName(targetid, tname, 24);
    SendMsgFmt(playerid, COLOR_SUCCESS, "[Pay] Ai trimis $%d lui %s.", amount, tname);
    SendMsgFmt(targetid, COLOR_SUCCESS, "[Pay] Ai primit $%d de la %s.", amount, name);
    return 1;
}

CMD:help(playerid, params[])
{
    new info[] =
        "{FFD700}== Romania RPG - Comenzi de baza ==\n\n"
        "{FFFFFF}/stats - Statisticile tale\n"
        "/deposit [suma] - Depune bani la banca\n"
        "/withdraw [suma] - Retrage bani de la banca\n"
        "/pay [jucator] [suma] - Trimite bani\n"
        "/job - Meniu joburi\n"
        "/trade [jucator] - Incepe un schimb\n"
        "/house - Meniu casa\n"
        "/vehicle - Meniu vehicul\n"
        "/pet - Meniu animale de companie\n"
        "/newspaper - Citeste ziarul\n"
        "/vote - Voteaza presedintele\n"
        "/duty - On/off duty (uber, mecanic etc.)\n"
        "/find [jucator] - Detectiv: gaseste un jucator\n"
        "/service uber - Comanda un uber";
    ShowPlayerDialog(playerid, 9999, DIALOG_STYLE_MSGBOX, "{FFD700}Ajutor", info, "Inchide", "");
    return 1;
}
