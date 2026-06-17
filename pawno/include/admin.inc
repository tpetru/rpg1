// ============================================================
//  ADMIN.INC - Sistem Administratori Romania RPG
//  Nivel 1-5 | Comenzi complete
// ============================================================
#if defined _admin_included
    #endinput
#endif
#define _admin_included

// Nivel admin:
// 1 - Helper     (ban, kick, mute, teleport)
// 2 - Moderator  (+anunt, +goto, +setjob, +setmoney)
// 3 - Admin      (+setfaction, +setlevel, +givevehicle, +setweather)
// 4 - Manager    (+setadmin, +createdisease, +createtour fortat)
// 5 - Owner      (toate)

// ============================================================
//  HELPER - verifica nivel
// ============================================================

// stock IsAdmin(playerid, level) e definit in utils.inc

// ============================================================
//  COMENZI NIVEL 1
// ============================================================

CMD:kick(playerid, params[])
{
    if(!IsAdmin(playerid, 1)) return SendMsg(playerid, COLOR_ERROR, "[!] Acces interzis!");
    new targetid; new reason[64];
    if(sscanf(params, "uS[64](Fara motiv)", targetid, reason))
        return SendMsg(playerid, COLOR_ERROR, "Folosire: /kick [jucator] [motiv]");
    if(!IsPlayerConnected(targetid))
        return SendMsg(playerid, COLOR_ERROR, "[!] Jucator invalid!");
    if(PlayerData[targetid][pAdminLevel] >= PlayerData[playerid][pAdminLevel])
        return SendMsg(playerid, COLOR_ERROR, "[!] Nu poti kicka un admin de acelasi rang sau superior!");

    new msg[128];
    format(msg, sizeof(msg), "[Admin] {FFD700}%s{FFFFFF} a fost dat afara. Motiv: %s",
        PlayerData[targetid][pName], reason);
    SendMsgAll(COLOR_ORANGE, msg);
    Kick(targetid);
    return 1;
}

CMD:ban(playerid, params[])
{
    if(!IsAdmin(playerid, 1)) return SendMsg(playerid, COLOR_ERROR, "[!] Acces interzis!");
    new targetid; new reason[64];
    if(sscanf(params, "uS[64](Comportament inadecvat)", targetid, reason))
        return SendMsg(playerid, COLOR_ERROR, "Folosire: /ban [jucator] [motiv]");
    if(!IsPlayerConnected(targetid))
        return SendMsg(playerid, COLOR_ERROR, "[!] Jucator invalid!");
    if(PlayerData[targetid][pAdminLevel] >= PlayerData[playerid][pAdminLevel])
        return SendMsg(playerid, COLOR_ERROR, "[!] Nu poti bana un admin de acelasi rang sau superior!");

    new msg[128];
    format(msg, sizeof(msg), "[Admin] {FFD700}%s{FFFFFF} a fost banat. Motiv: %s",
        PlayerData[targetid][pName], reason);
    SendMsgAll(COLOR_RED, msg);

    new query[256];
    mysql_format(g_SQL, query, sizeof(query),
        "UPDATE `players` SET `banned`=1, `ban_reason`='%e' WHERE `id`=%d",
        reason, PlayerData[targetid][pID]);
    mysql_tquery(g_SQL, query, "", "", 0);
    Ban(targetid);
    return 1;
}

CMD:mute(playerid, params[])
{
    if(!IsAdmin(playerid, 1)) return SendMsg(playerid, COLOR_ERROR, "[!] Acces interzis!");
    new targetid, minutes;
    if(sscanf(params, "ui", targetid, minutes))
        return SendMsg(playerid, COLOR_ERROR, "Folosire: /mute [jucator] [minute]");
    if(!IsPlayerConnected(targetid))
        return SendMsg(playerid, COLOR_ERROR, "[!] Jucator invalid!");

    SetPVarInt(targetid, "Muted", 1);
    SetTimerEx("OnUnmute", minutes * 60000, false, "i", targetid);
    SendMsgFmt(targetid, COLOR_RED, "[Admin] Ai fost mutuit pentru %d minute!", minutes);
    SendMsgFmt(playerid, COLOR_SUCCESS, "[Admin] %s mutuit %d minute.", PlayerData[targetid][pName], minutes);
    return 1;
}

forward OnUnmute(playerid);
public OnUnmute(playerid)
{
    if(!IsPlayerConnected(playerid)) return;
    DeletePVar(playerid, "Muted");
    SendMsg(playerid, COLOR_SUCCESS, "[Admin] Ai fost demutuit. Comporta-te!");
}

CMD:unmute(playerid, params[])
{
    if(!IsAdmin(playerid, 1)) return SendMsg(playerid, COLOR_ERROR, "[!] Acces interzis!");
    new targetid;
    if(sscanf(params, "u", targetid))
        return SendMsg(playerid, COLOR_ERROR, "Folosire: /unmute [jucator]");
    DeletePVar(targetid, "Muted");
    SendMsg(targetid, COLOR_SUCCESS, "[Admin] Ai fost demutuit!");
    SendMsgFmt(playerid, COLOR_SUCCESS, "[Admin] %s demutuit.", PlayerData[targetid][pName]);
    return 1;
}

CMD:atp(playerid, params[])
{
    if(!IsAdmin(playerid, 1)) return SendMsg(playerid, COLOR_ERROR, "[!] Acces interzis!");
    new targetid;
    if(sscanf(params, "u", targetid))
        return SendMsg(playerid, COLOR_ERROR, "Folosire: /atp [jucator]");
    if(!IsPlayerConnected(targetid))
        return SendMsg(playerid, COLOR_ERROR, "[!] Jucator invalid!");
    new Float:tx, Float:ty, Float:tz;
    GetPlayerPos(targetid, tx, ty, tz);
    SetPlayerPos(playerid, tx, ty, tz + 1.5);
    SetPlayerInterior(playerid, GetPlayerInterior(targetid));
    SetPlayerVirtualWorld(playerid, GetPlayerVirtualWorld(targetid));
    SendMsgFmt(playerid, COLOR_SUCCESS, "[Admin] Teleportat la %s.", PlayerData[targetid][pName]);
    return 1;
}

CMD:gethere(playerid, params[])
{
    if(!IsAdmin(playerid, 1)) return SendMsg(playerid, COLOR_ERROR, "[!] Acces interzis!");
    new targetid;
    if(sscanf(params, "u", targetid))
        return SendMsg(playerid, COLOR_ERROR, "Folosire: /gethere [jucator]");
    if(!IsPlayerConnected(targetid))
        return SendMsg(playerid, COLOR_ERROR, "[!] Jucator invalid!");
    new Float:px, Float:py, Float:pz;
    GetPlayerPos(playerid, px, py, pz);
    SetPlayerPos(targetid, px + 2.0, py, pz);
    SetPlayerInterior(targetid, GetPlayerInterior(playerid));
    SetPlayerVirtualWorld(targetid, GetPlayerVirtualWorld(playerid));
    SendMsgFmt(targetid, COLOR_ORANGE, "[Admin] %s te-a adus la el.", PlayerData[playerid][pName]);
    SendMsgFmt(playerid, COLOR_SUCCESS, "[Admin] %s adus.", PlayerData[targetid][pName]);
    return 1;
}

CMD:spec(playerid, params[])
{
    if(!IsAdmin(playerid, 1)) return SendMsg(playerid, COLOR_ERROR, "[!] Acces interzis!");
    new targetid;
    if(sscanf(params, "u", targetid))
        return SendMsg(playerid, COLOR_ERROR, "Folosire: /spec [jucator]");
    if(!IsPlayerConnected(targetid))
        return SendMsg(playerid, COLOR_ERROR, "[!] Jucator invalid!");

    if(GetPVarInt(playerid, "Spectating"))
    {
        TogglePlayerSpectating(playerid, false);
        DeletePVar(playerid, "Spectating");
        SpawnPlayer(playerid);
        SendMsg(playerid, COLOR_SUCCESS, "[Admin] Ai iesit din spectate.");
    }
    else
    {
        SetPlayerVirtualWorld(playerid, GetPlayerVirtualWorld(targetid));
        SetPlayerInterior(playerid, GetPlayerInterior(targetid));
        TogglePlayerSpectating(playerid, true);
        PlayerSpectatePlayer(playerid, targetid);
        SetPVarInt(playerid, "Spectating", 1);
        SendMsgFmt(playerid, COLOR_SUCCESS, "[Admin] Spectezi pe %s.", PlayerData[targetid][pName]);
    }
    return 1;
}

// ============================================================
//  COMENZI NIVEL 2
// ============================================================

CMD:ann(playerid, params[])
{
    if(!IsAdmin(playerid, 2)) return SendMsg(playerid, COLOR_ERROR, "[!] Acces interzis!");
    if(!params[0]) return SendMsg(playerid, COLOR_ERROR, "Folosire: /ann [mesaj]");
    new msg[192];
    format(msg, sizeof(msg), "[{FF8C00}ANUNT{FFFFFF}] %s", params);
    SendMsgAll(COLOR_ORANGE, msg);
    GameTextForAll(params, 6000, 3);
    return 1;
}

CMD:setmoney(playerid, params[])
{
    if(!IsAdmin(playerid, 2)) return SendMsg(playerid, COLOR_ERROR, "[!] Acces interzis!");
    new targetid, amount;
    if(sscanf(params, "ui", targetid, amount))
        return SendMsg(playerid, COLOR_ERROR, "Folosire: /setmoney [jucator] [suma]");
    if(!IsPlayerConnected(targetid))
        return SendMsg(playerid, COLOR_ERROR, "[!] Jucator invalid!");
    GivePlayerMoney(targetid, -GetPlayerMoney(targetid));
    GivePlayerMoney(targetid, amount);
    PlayerData[targetid][pMoney] = amount;
    SendMsgFmt(playerid, COLOR_SUCCESS, "[Admin] Bani setati: %s -> $%d", PlayerData[targetid][pName], amount);
    SendMsgFmt(targetid, COLOR_YELLOW, "[Admin] Banii tai au fost modificati la $%d.", amount);
    return 1;
}

CMD:givemoney(playerid, params[])
{
    if(!IsAdmin(playerid, 2)) return SendMsg(playerid, COLOR_ERROR, "[!] Acces interzis!");
    new targetid, amount;
    if(sscanf(params, "ui", targetid, amount))
        return SendMsg(playerid, COLOR_ERROR, "Folosire: /givemoney [jucator] [suma]");
    if(!IsPlayerConnected(targetid))
        return SendMsg(playerid, COLOR_ERROR, "[!] Jucator invalid!");
    GivePlayerMoney(targetid, amount);
    PlayerData[targetid][pMoney] += amount;
    SendMsgFmt(playerid, COLOR_SUCCESS, "[Admin] $%d dati lui %s.", amount, PlayerData[targetid][pName]);
    SendMsgFmt(targetid, COLOR_YELLOW, "[Admin] Ai primit $%d de la admin.", amount);
    return 1;
}

CMD:setjob(playerid, params[])
{
    if(!IsAdmin(playerid, 2)) return SendMsg(playerid, COLOR_ERROR, "[!] Acces interzis!");
    new targetid, jobid;
    if(sscanf(params, "ui", targetid, jobid))
        return SendMsg(playerid, COLOR_ERROR, "Folosire: /setjob [jucator] [id_job 0-9]");
    if(!IsPlayerConnected(targetid))
        return SendMsg(playerid, COLOR_ERROR, "[!] Jucator invalid!");
    if(jobid < 0 || jobid >= JOB_COUNT)
        return SendMsg(playerid, COLOR_ERROR, "[!] ID job invalid (0-9)!");
    PlayerData[targetid][pJob]    = jobid;
    PlayerData[targetid][pOnDuty] = false;
    Player_SaveData(targetid);
    SendMsgFmt(playerid, COLOR_SUCCESS, "[Admin] %s -> Job: %s", PlayerData[targetid][pName], Job_GetName(jobid));
    SendMsgFmt(targetid, COLOR_YELLOW, "[Admin] Jobul tau a fost schimbat in: %s.", Job_GetName(jobid));
    return 1;
}

CMD:sethp(playerid, params[])
{
    if(!IsAdmin(playerid, 2)) return SendMsg(playerid, COLOR_ERROR, "[!] Acces interzis!");
    new targetid; new Float:hp;
    if(sscanf(params, "uf", targetid, hp))
        return SendMsg(playerid, COLOR_ERROR, "Folosire: /sethp [jucator] [hp]");
    if(!IsPlayerConnected(targetid))
        return SendMsg(playerid, COLOR_ERROR, "[!] Jucator invalid!");
    if(hp < 0.0 || hp > 100.0) return SendMsg(playerid, COLOR_ERROR, "[!] HP: 0-100!");
    SetPlayerHealth(targetid, hp);
    SendMsgFmt(playerid, COLOR_SUCCESS, "[Admin] HP setat: %s -> %.0f", PlayerData[targetid][pName], hp);
    return 1;
}

CMD:freeze(playerid, params[])
{
    if(!IsAdmin(playerid, 2)) return SendMsg(playerid, COLOR_ERROR, "[!] Acces interzis!");
    new targetid;
    if(sscanf(params, "u", targetid))
        return SendMsg(playerid, COLOR_ERROR, "Folosire: /freeze [jucator]");
    if(!IsPlayerConnected(targetid))
        return SendMsg(playerid, COLOR_ERROR, "[!] Jucator invalid!");
    new frozen = GetPVarInt(targetid, "Frozen");
    if(frozen) { TogglePlayerControllable(targetid, true); DeletePVar(targetid, "Frozen"); }
    else       { TogglePlayerControllable(targetid, false); SetPVarInt(targetid, "Frozen", 1); }
    SendMsgFmt(playerid, COLOR_SUCCESS, "[Admin] %s %s.",
        PlayerData[targetid][pName], frozen ? "deinghetat" : "inghetat");
    SendMsgFmt(targetid, COLOR_ORANGE, "[Admin] Ai fost %s de un administrator.",
        frozen ? "deinghetat" : "inghetat");
    return 1;
}

CMD:setweather(playerid, params[])
{
    if(!IsAdmin(playerid, 2)) return SendMsg(playerid, COLOR_ERROR, "[!] Acces interzis!");
    new weather;
    if(sscanf(params, "i", weather))
        return SendMsg(playerid, COLOR_ERROR, "Folosire: /setweather [0-45]");
    if(weather < 0 || weather > 45)
        return SendMsg(playerid, COLOR_ERROR, "[!] Weather: 0-45!");
    SetWeather(weather);
    SendMsgFmt(playerid, COLOR_SUCCESS, "[Admin] Vreme schimbata la %d.", weather);
    return 1;
}

CMD:settime(playerid, params[])
{
    if(!IsAdmin(playerid, 2)) return SendMsg(playerid, COLOR_ERROR, "[!] Acces interzis!");
    new hour;
    if(sscanf(params, "i", hour))
        return SendMsg(playerid, COLOR_ERROR, "Folosire: /settime [0-23]");
    if(hour < 0 || hour > 23) return SendMsg(playerid, COLOR_ERROR, "[!] Ora: 0-23!");
    SetWorldTime(hour);
    SendMsgFmt(playerid, COLOR_SUCCESS, "[Admin] Ora setata la %d:00.", hour);
    return 1;
}

// ============================================================
//  COMENZI NIVEL 3
// ============================================================

CMD:setfaction(playerid, params[])
{
    if(!IsAdmin(playerid, 3)) return SendMsg(playerid, COLOR_ERROR, "[!] Acces interzis!");
    new targetid, fid, rank;
    if(sscanf(params, "uii", targetid, fid, rank))
        return SendMsg(playerid, COLOR_ERROR, "Folosire: /setfaction [jucator] [factiune_id] [rang 1-5]");
    if(!IsPlayerConnected(targetid))
        return SendMsg(playerid, COLOR_ERROR, "[!] Jucator invalid!");
    if(fid < 0 || fid > MAX_FACTIONS)
        return SendMsg(playerid, COLOR_ERROR, "[!] Factiune invalida (0-9)!");
    if(rank < 0 || rank > RANK_LEADER)
        return SendMsg(playerid, COLOR_ERROR, "[!] Rang invalid (0-5)!");
    PlayerData[targetid][pFaction]     = fid;
    PlayerData[targetid][pFactionRank] = rank;
    if(fid > 0) SetPlayerSkin(targetid, FactionSkins[fid][rank < 5 ? rank : 4]);
    Player_SaveData(targetid);
    SendMsgFmt(playerid, COLOR_SUCCESS,
        "[Admin] %s -> Factiune: %s (Rang %d)", PlayerData[targetid][pName], Faction_GetName(fid), rank);
    SendMsgFmt(targetid, COLOR_YELLOW,
        "[Admin] Factiunea ta: {FFD700}%s{FFFFFF} | Rang: %d", Faction_GetName(fid), rank);
    return 1;
}

CMD:setlevel(playerid, params[])
{
    if(!IsAdmin(playerid, 3)) return SendMsg(playerid, COLOR_ERROR, "[!] Acces interzis!");
    new targetid, lvl;
    if(sscanf(params, "ui", targetid, lvl))
        return SendMsg(playerid, COLOR_ERROR, "Folosire: /setlevel [jucator] [level]");
    if(!IsPlayerConnected(targetid))
        return SendMsg(playerid, COLOR_ERROR, "[!] Jucator invalid!");
    if(lvl < 1 || lvl > MAX_LEVEL)
        return SendMsgFmt(playerid, COLOR_ERROR, "[!] Level: 1-%d!", MAX_LEVEL);
    PlayerData[targetid][pLevel] = lvl;
    SetPlayerScore(targetid, lvl);
    Player_SaveData(targetid);
    SendMsgFmt(playerid, COLOR_SUCCESS, "[Admin] %s -> Level %d.", PlayerData[targetid][pName], lvl);
    SendMsgFmt(targetid, COLOR_YELLOW, "[Admin] Levelul tau a fost setat la %d.", lvl);
    return 1;
}

CMD:givevehicle(playerid, params[])
{
    if(!IsAdmin(playerid, 3)) return SendMsg(playerid, COLOR_ERROR, "[!] Acces interzis!");
    new targetid, model;
    if(sscanf(params, "ui", targetid, model))
        return SendMsg(playerid, COLOR_ERROR, "Folosire: /givevehicle [jucator] [model 400-611]");
    if(!IsPlayerConnected(targetid))
        return SendMsg(playerid, COLOR_ERROR, "[!] Jucator invalid!");
    if(model < 400 || model > 611)
        return SendMsg(playerid, COLOR_ERROR, "[!] Model: 400-611!");
    new Float:px, Float:py, Float:pz;
    GetPlayerPos(targetid, px, py, pz);
    new veh = CreateVehicle(model, px + 4.0, py, pz, 0.0, random(128), random(128), -1);
    PutPlayerInVehicle(targetid, veh, 0);
    SendMsgFmt(playerid, COLOR_SUCCESS,
        "[Admin] Vehicul model %d dat lui %s.", model, PlayerData[targetid][pName]);
    SendMsgFmt(targetid, COLOR_YELLOW, "[Admin] Ai primit un vehicul (model %d).", model);
    return 1;
}

CMD:teleport(playerid, params[])
{
    if(!IsAdmin(playerid, 3)) return SendMsg(playerid, COLOR_ERROR, "[!] Acces interzis!");
    new Float:x, Float:y, Float:z;
    if(sscanf(params, "fff", x, y, z))
        return SendMsg(playerid, COLOR_ERROR, "Folosire: /teleport [x] [y] [z]");
    SetPlayerPos(playerid, x, y, z);
    SetPlayerInterior(playerid, 0);
    SendMsgFmt(playerid, COLOR_SUCCESS, "[Admin] Teleportat la %.1f %.1f %.1f.", x, y, z);
    return 1;
}

CMD:clearwanted(playerid, params[])
{
    if(!IsAdmin(playerid, 3)) return SendMsg(playerid, COLOR_ERROR, "[!] Acces interzis!");
    new targetid;
    if(sscanf(params, "u", targetid))
        return SendMsg(playerid, COLOR_ERROR, "Folosire: /clearwanted [jucator]");
    if(!IsPlayerConnected(targetid))
        return SendMsg(playerid, COLOR_ERROR, "[!] Jucator invalid!");
    PlayerData[targetid][pWanted] = 0;
    SetPlayerWantedLevel(targetid, 0);
    SendMsgFmt(playerid, COLOR_SUCCESS, "[Admin] Wanted sters: %s.", PlayerData[targetid][pName]);
    SendMsg(targetid, COLOR_SUCCESS, "[Admin] Wanted-ul tau a fost sters de un administrator.");
    return 1;
}

CMD:jail(playerid, params[])
{
    if(!IsAdmin(playerid, 3)) return SendMsg(playerid, COLOR_ERROR, "[!] Acces interzis!");
    new targetid, minutes;
    if(sscanf(params, "ui", targetid, minutes))
        return SendMsg(playerid, COLOR_ERROR, "Folosire: /jail [jucator] [minute]");
    if(!IsPlayerConnected(targetid))
        return SendMsg(playerid, COLOR_ERROR, "[!] Jucator invalid!");
    if(minutes < 1 || minutes > 120) return SendMsg(playerid, COLOR_ERROR, "[!] Minute: 1-120!");
    PlayerData[targetid][pJailed]   = true;
    PlayerData[targetid][pJailTime] = minutes * 60;
    SetPlayerPos(targetid, 264.35, 75.62, 1001.04);
    SetPlayerInterior(targetid, 6);
    SendMsgFmt(targetid, COLOR_RED, "[Admin] Ai fost inchis pentru %d minute!", minutes);
    SendMsgFmt(playerid, COLOR_SUCCESS, "[Admin] %s inchis %d minute.", PlayerData[targetid][pName], minutes);
    SetTimerEx("OnJailRelease", minutes * 60000, false, "i", targetid);
    return 1;
}

CMD:unjail(playerid, params[])
{
    if(!IsAdmin(playerid, 3)) return SendMsg(playerid, COLOR_ERROR, "[!] Acces interzis!");
    new targetid;
    if(sscanf(params, "u", targetid))
        return SendMsg(playerid, COLOR_ERROR, "Folosire: /unjail [jucator]");
    if(!IsPlayerConnected(targetid))
        return SendMsg(playerid, COLOR_ERROR, "[!] Jucator invalid!");
    PlayerData[targetid][pJailed] = false;
    SetPlayerPos(targetid, 264.35, 88.0, 1001.04);
    SetPlayerInterior(targetid, 0);
    SendMsg(targetid, COLOR_SUCCESS, "[Admin] Ai fost eliberat din inchisoare!");
    SendMsgFmt(playerid, COLOR_SUCCESS, "[Admin] %s eliberat.", PlayerData[targetid][pName]);
    return 1;
}

CMD:createdisease(playerid, params[])
{
    if(!IsAdmin(playerid, 2)) return SendMsg(playerid, COLOR_ERROR, "[!] Acces interzis!");
    new dname[32], ddesc[64];
    if(sscanf(params, "s[32]S[64](Boala necunoscuta)", dname, ddesc))
        return SendMsg(playerid, COLOR_ERROR, "Folosire: /createdisease [nume] [descriere]");

    new query[256];
    mysql_format(g_SQL, query, sizeof(query),
        "INSERT INTO `diseases` (name, description, created_by) VALUES ('%e','%e',%d)",
        dname, ddesc, PlayerData[playerid][pID]);
    mysql_tquery(g_SQL, query, "", "", 0);

    new Float:px, Float:py, Float:pz;
    GetPlayerPos(playerid, px, py, pz);
    new infected = 0;

    for(new i = 0; i < MAX_PLAYERS; i++)
    {
        if(!IsPlayerConnected(i) || !PlayerData[i][pLogged] || i == playerid) continue;
        new Float:ix, Float:iy, Float:iz;
        GetPlayerPos(i, ix, iy, iz);
        if(VectorSize(px-ix, py-iy, pz-iz) > DISEASE_RANGE) continue;
        if(PlayerData[i][pSick]) continue;

        PlayerData[i][pSick] = true;
        format(PlayerData[i][pDiseaseName], 32, "%s", dname);
        Disease_StartDecay(i);
        SendMsgFmt(i, COLOR_RED,
            "[!] Ai fost infectat cu {FF4444}%s{FFFFFF}! Mergi urgent la spital!", dname);
        infected++;
    }

    SendMsgFmt(playerid, COLOR_SUCCESS,
        "[Admin] Boala '{FFD700}%s{00FF44}' creata. %d jucatori infectati in raza de %.0fm.",
        dname, infected, DISEASE_RANGE);
    return 1;
}

// ============================================================
//  COMENZI NIVEL 4
// ============================================================

CMD:setadmin(playerid, params[])
{
    if(!IsAdmin(playerid, 4)) return SendMsg(playerid, COLOR_ERROR, "[!] Acces interzis!");
    new targetid, alv;
    if(sscanf(params, "ui", targetid, alv))
        return SendMsg(playerid, COLOR_ERROR, "Folosire: /setadmin [jucator] [nivel 0-5]");
    if(!IsPlayerConnected(targetid))
        return SendMsg(playerid, COLOR_ERROR, "[!] Jucator invalid!");
    if(alv < 0 || alv > 5) return SendMsg(playerid, COLOR_ERROR, "[!] Nivel: 0-5!");
    if(alv >= PlayerData[playerid][pAdminLevel])
        return SendMsg(playerid, COLOR_ERROR,
            "[!] Nu poti acorda un nivel admin egal sau superior cu al tau!");

    PlayerData[targetid][pAdminLevel] = alv;
    Player_SaveData(targetid);

    new query[128];
    mysql_format(g_SQL, query, sizeof(query),
        "UPDATE `players` SET admin_level=%d WHERE id=%d",
        alv, PlayerData[targetid][pID]);
    mysql_tquery(g_SQL, query, "", "", 0);

    SendMsgFmt(playerid, COLOR_SUCCESS,
        "[Admin] %s -> Admin nivel %d.", PlayerData[targetid][pName], alv);
    if(alv > 0)
        SendMsgFmt(targetid, COLOR_GOLD,
            "[Admin] Ai primit rang de administrator nivel %d!", alv);
    else
        SendMsg(targetid, COLOR_ERROR, "[Admin] Drepturile tale de administrator au fost retrase.");
    return 1;
}

CMD:forcevote(playerid, params[])
{
    if(!IsAdmin(playerid, 4)) return SendMsg(playerid, COLOR_ERROR, "[!] Acces interzis!");
    VoteOpen = !VoteOpen;
    SendMsgFmt(playerid, COLOR_SUCCESS,
        "[Admin] Vot presedinte: %s", VoteOpen ? "DESCHIS" : "INCHIS");
    if(VoteOpen)
        SendMsgAll(COLOR_GOLD, "[PRESEDINTE] Votul a fost deschis de un administrator! /vote");
    return 1;
}

CMD:forcepayday(playerid, params[])
{
    if(!IsAdmin(playerid, 4)) return SendMsg(playerid, COLOR_ERROR, "[!] Acces interzis!");
    Payday_Execute();
    SendMsgFmt(playerid, COLOR_SUCCESS, "[Admin] Payday fortat de %s.", PlayerData[playerid][pName]);
    return 1;
}

// ============================================================
//  COMENZI NIVEL 5 (Owner)
// ============================================================

CMD:reloadserver(playerid, params[])
{
    if(!IsAdmin(playerid, 5)) return SendMsg(playerid, COLOR_ERROR, "[!] Acces interzis!");
    SendMsgAll(COLOR_RED, "[SERVER] Serverul se restarteaza in 10 secunde!");
    SetTimer("OnServerRestart", 10000, false);
    return 1;
}

forward OnServerRestart();
public OnServerRestart()
{
    SendRconCommand("gmx");
}

// ============================================================
//  COMANDA /adminhelp
// ============================================================

CMD:adminhelp(playerid, params[])
{
    if(!IsAdmin(playerid, 1)) return SendMsg(playerid, COLOR_ERROR, "[!] Acces interzis!");

    new lv = PlayerData[playerid][pAdminLevel];
    new info[1024];
    format(info, sizeof(info), "{FFD700}Comenzi Admin (Nivel %d)\n\n", lv);

    if(lv >= 1) strcat(info,
        "{FFFFFF}[Niv.1] /kick /ban /mute /unmute /atp /gethere /spec\n");
    if(lv >= 2) strcat(info,
        "[Niv.2] /ann /setmoney /givemoney /setjob /sethp /freeze /setweather /settime /createdisease\n");
    if(lv >= 3) strcat(info,
        "[Niv.3] /setfaction /setlevel /givevehicle /teleport /clearwanted /jail /unjail\n");
    if(lv >= 4) strcat(info,
        "[Niv.4] /setadmin /forcevote /forcepayday\n");
    if(lv >= 5) strcat(info,
        "[Niv.5] /reloadserver\n");

    ShowPlayerDialog(playerid, 9997, DIALOG_STYLE_MSGBOX,
        "Comenzi Administrator", info, "Inchide", "");
    return 1;
}

// ============================================================
//  MUTE CHECK in OnPlayerText (apelat din events.inc)
// ============================================================

stock Admin_IsMuted(playerid)
{
    return GetPVarInt(playerid, "Muted");
}
