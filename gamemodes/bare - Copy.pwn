#include <a_samp>
#include <core>
#include <float>
#include <a_mysql>

#pragma tabsize 0
#pragma warning disable 239

// ============================================================
//  CONFIGURARE BAZA DE DATE
// ============================================================
#define MYSQL_HOST  "127.0.0.1"
#define MYSQL_USER  "root"
#define MYSQL_PASS  ""
#define MYSQL_DB    "rpg1"

new MySQL:g_SQL;

// ============================================================
//  DATE JUCATOR
// ============================================================
enum E_PLAYER_DATA
{
    pID, pName[24], pPass[64], pEmail[64],
    pLevel, pMoney, pBank, pRP, pAdminLevel,
    bool:pLogged, bool:pRegistered
}
new PlayerData[MAX_PLAYERS][E_PLAYER_DATA];

// ============================================================
//  BAZA DE DATE
// ============================================================
stock DB_Init()
{
    new MySQLOpt:opt = mysql_init_options();
    mysql_set_option(opt, AUTO_RECONNECT, true);
    g_SQL = mysql_connect(MYSQL_HOST, MYSQL_USER, MYSQL_PASS, MYSQL_DB, opt);

    if(g_SQL == MYSQL_INVALID_HANDLE || mysql_errno(g_SQL) != 0)
    {
        print("[DB] EROARE: Nu s-a putut conecta la MySQL!");
        SendRconCommand("exit");
        return 0;
    }
    print("[DB] Conectat la MySQL cu succes!");
    DB_CreateTables();

    return 1;
}

stock DB_CreateTables()
{
    mysql_tquery(g_SQL,
        "CREATE TABLE IF NOT EXISTS `players` (\
        `id`          INT AUTO_INCREMENT PRIMARY KEY,\
        `username`    VARCHAR(24) NOT NULL UNIQUE,\
        `password`    VARCHAR(64) NOT NULL,\
        `email`       VARCHAR(64) DEFAULT '',\
        `level`       INT DEFAULT 1,\
        `money`       INT DEFAULT 0,\
        `bank`        INT DEFAULT 0,\
        `rp`          INT DEFAULT 0,\
        `admin_level` INT DEFAULT 0\
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;",
        "", "", 0);
    print("[DB] Tabel `players` verificat/creat.");
}

// ============================================================
//  VERIFICARE / INCARCARE JUCATOR
// ============================================================
stock Player_CheckExists(playerid)
{
    new query[128];
    mysql_format(g_SQL, query, sizeof(query),
        "SELECT `id`,`password`,`level`,`money`,`bank`,`rp`,`admin_level` \
         FROM `players` WHERE `username`='%e' LIMIT 1",
        PlayerData[playerid][pName]);
    mysql_tquery(g_SQL, query, "OnPlayerCheckExists", "i", playerid);
}

public OnPlayerCheckExists(playerid)
{
    if(!IsPlayerConnected(playerid)) return 0;

    if(cache_num_rows() > 0)
    {
        PlayerData[playerid][pRegistered] = true;

        cache_get_value_name_int(0, "id",          PlayerData[playerid][pID]);
        cache_get_value_name    (0, "password",    PlayerData[playerid][pPass], 64);
        cache_get_value_name_int(0, "level",       PlayerData[playerid][pLevel]);
        cache_get_value_name_int(0, "money",       PlayerData[playerid][pMoney]);
        cache_get_value_name_int(0, "bank",        PlayerData[playerid][pBank]);
        cache_get_value_name_int(0, "rp",          PlayerData[playerid][pRP]);
        cache_get_value_name_int(0, "admin_level", PlayerData[playerid][pAdminLevel]);

        SendClientMessage(playerid, 0x00FF00FF, "Cont gasit. Foloseste /login [parola] pentru a te loga.");
    }
    else
    {
        PlayerData[playerid][pRegistered] = false;
        SendClientMessage(playerid, 0xFFFF00FF, "Nu esti inregistrat. Foloseste /register [parola].");
    }
    return 1;
}

// ============================================================
//  INREGISTRARE
// ============================================================
stock Player_Register(playerid, const pass[])
{
    new query[256];
    mysql_format(g_SQL, query, sizeof(query),
        "INSERT INTO `players` (`username`,`password`) VALUES ('%e','%e')",
        PlayerData[playerid][pName], pass);
    mysql_tquery(g_SQL, query, "OnPlayerRegister", "i", playerid);
}

public OnPlayerRegister(playerid)
{
    if(!IsPlayerConnected(playerid)) return 0;

    PlayerData[playerid][pID]         = cache_insert_id();
    PlayerData[playerid][pRegistered] = true;
    PlayerData[playerid][pLogged]     = true;
    PlayerData[playerid][pLevel]      = 1;
    PlayerData[playerid][pMoney]      = 0;
    PlayerData[playerid][pBank]       = 0;
    PlayerData[playerid][pRP]         = 0;
    PlayerData[playerid][pAdminLevel] = 0;

    SendClientMessage(playerid, 0x00FF00FF, "Inregistrare reusita! Esti acum logat.");
    SpawnPlayer(playerid);
    return 1;
}

// ============================================================
//  LOGIN
// ============================================================
stock Player_Login(playerid, const pass[])
{
    if(strcmp(pass, PlayerData[playerid][pPass], false) != 0)
    {
        SendClientMessage(playerid, 0xFF0000FF, "Parola incorecta!");
        return;
    }

    PlayerData[playerid][pLogged] = true;

    GivePlayerMoney(playerid, PlayerData[playerid][pMoney]);

    SendClientMessage(playerid, 0x00FF00FF, "Te-ai logat cu succes!");
    SpawnPlayer(playerid);
}

// ============================================================
//  GAMEMODE
// ============================================================
main()
{
    print("\n----------------------------------");
    print("  Bare Script by Nikolas Maduro\n");
    print("----------------------------------\n");
}

public OnGameModeInit()
{
    SetGameModeText("Old is Gold");
    ShowPlayerMarkers(1);
    ShowNameTags(1);
    AllowAdminTeleport(1);

    AddPlayerClass(265, 1958.3783, 1343.1572, 15.3746, 270.1425, 0, 0, 0, 0, -1, -1);

    DB_Init();

    return 1;
}

public OnGameModeExit()
{
    mysql_close(g_SQL);
    return 1;
}

public OnPlayerConnect(playerid)
{
    GetPlayerName(playerid, PlayerData[playerid][pName], 24);

    GameTextForPlayer(playerid, "~g~Welcome\n~y~Old is Gold", 5000, 5);

    Player_CheckExists(playerid);
    return 1;
}

public OnPlayerCommandText(playerid, cmdtext[])
{
    new idx;
    new cmd[256];
    cmd = strtok(cmdtext, idx);

    // ---- /register [parola] ----
    if(strcmp(cmd, "/register", true) == 0)
    {
        if(PlayerData[playerid][pRegistered])
            return SendClientMessage(playerid, 0xFF0000FF, "Esti deja inregistrat."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new pass[64];
        strmid(pass, cmdtext, idx, strlen(cmdtext), 64);

        if(!strlen(pass))
            return SendClientMessage(playerid, 0xFFFF00FF, "Foloseste: /register [parola]"), 1;

        Player_Register(playerid, pass);
        return 1;
    }

    // ---- /login [parola] ----
    if(strcmp(cmd, "/login", true) == 0)
    {
        if(!PlayerData[playerid][pRegistered])
            return SendClientMessage(playerid, 0xFF0000FF, "Nu esti inregistrat. Foloseste /register [parola]."), 1;

        if(PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, 0xFF0000FF, "Esti deja logat."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new pass[64];
        strmid(pass, cmdtext, idx, strlen(cmdtext), 64);

        if(!strlen(pass))
            return SendClientMessage(playerid, 0xFFFF00FF, "Foloseste: /login [parola]"), 1;

        Player_Login(playerid, pass);
        return 1;
    }

    return 0;
}

public OnPlayerSpawn(playerid)
{
    SetPlayerInterior(playerid, 0);
    TogglePlayerClock(playerid, 0);
    return 1;
}

public OnPlayerDeath(playerid, killerid, reason)
{
    return 1;
}

SetupPlayerForClassSelection(playerid)
{
    SetPlayerInterior(playerid, 14);
    SetPlayerPos(playerid, 258.4893, -41.4008, 1002.0234);
    SetPlayerFacingAngle(playerid, 270.0);
    SetPlayerCameraPos(playerid, 256.0815, -43.0475, 1004.0234);
    SetPlayerCameraLookAt(playerid, 258.4893, -41.4008, 1002.0234);
}

public OnPlayerRequestClass(playerid, classid)
{
    SetupPlayerForClassSelection(playerid);
    return 1;
}

strtok(const string[], &index)
{
    new length = strlen(string);
    while((index < length) && (string[index] <= ' '))
        index++;

    new offset = index;
    new result[256];
    while((index < length) && (string[index] > ' ') && ((index - offset) < (sizeof(result) - 1)))
    {
        result[index - offset] = string[index];
        index++;
    }
    result[index - offset] = EOS;
    return result;
}
