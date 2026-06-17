// ============================================================
//  VEHICLES.INC - Vehicule personale, RAR, Asigurare, Rovigneta
// ============================================================
#if defined _vehicles_included
    #endinput
#endif
#define _vehicles_included

enum E_VEHICLE_DATA
{
    vID, vOwnerID, vModel, vPlate[9],
    vColor1, vColor2,
    Float:vX, Float:vY, Float:vZ, Float:vAngle,
    Float:vFuel, vMileage, bool:vLocked,
    bool:vInsurance, vInsuranceExp[12],
    bool:vRovigneta, vRovignetaExp[12],
    bool:vITP, vITPExp[12],
    bool:vRegistered,
    bool:vTrusa, bool:vStingator, bool:vVesta,
    vGameID // ID vehicul in-game
}

new VehicleData[MAX_VEHICLES][E_VEHICLE_DATA];
new PlayerVehicles[MAX_PLAYERS][10]; // max 10 masini per player
new PlayerVehicleCount[MAX_PLAYERS];

// ============================================================
//  INIT
// ============================================================

stock Vehicles_Init()
{
    print("[Vehicles] Sistem vehicule incarcat.");
}

// ============================================================
//  LOAD / SAVE
// ============================================================

stock Vehicles_LoadForPlayer(playerid)
{
    new query[128];
    mysql_format(g_SQL, query, sizeof(query),
        "SELECT * FROM `vehicles` WHERE `owner_id`=%d",
        PlayerData[playerid][pID]);
    mysql_tquery(g_SQL, query, "OnVehiclesLoaded", "i", playerid);
}

forward OnVehiclesLoaded(playerid);
public OnVehiclesLoaded(playerid)
{
    new rows = cache_num_rows();
    PlayerVehicleCount[playerid] = 0;

    for(new i = 0; i < rows && i < 10; i++)
    {
        new vid = -1;
        // Gasim slot liber global
        for(new j = 0; j < MAX_VEHICLES; j++)
        {
            if(VehicleData[j][vID] == 0) { vid = j; break; }
        }
        if(vid == -1) break;

        cache_get_value_name_int(i, "id", VehicleData[vid][vID]);
        cache_get_value_name_int(i, "owner_id", VehicleData[vid][vOwnerID]);
        cache_get_value_name_int(i, "model", VehicleData[vid][vModel]);
        cache_get_value_name(i, "plate", VehicleData[vid][vPlate], 9);
        cache_get_value_name_int(i, "color1", VehicleData[vid][vColor1]);
        cache_get_value_name_int(i, "color2", VehicleData[vid][vColor2]);
        cache_get_value_name_float(i, "pos_x", VehicleData[vid][vX]);
        cache_get_value_name_float(i, "pos_y", VehicleData[vid][vY]);
        cache_get_value_name_float(i, "pos_z", VehicleData[vid][vZ]);
        cache_get_value_name_float(i, "angle", VehicleData[vid][vAngle]);
        cache_get_value_name_float(i, "fuel", VehicleData[vid][vFuel]);
        cache_get_value_name_int(i, "mileage", VehicleData[vid][vMileage]);

        new locked, ins, rov, itp, reg, trusa, sting, vesta;
        cache_get_value_name_int(i, "locked", locked);
        cache_get_value_name_int(i, "insurance", ins);
        cache_get_value_name_int(i, "rovigneta", rov);
        cache_get_value_name_int(i, "itp", itp);
        cache_get_value_name_int(i, "registered", reg);
        cache_get_value_name_int(i, "trusa", trusa);
        cache_get_value_name_int(i, "stingator", sting);
        cache_get_value_name_int(i, "vesta", vesta);

        VehicleData[vid][vLocked]      = (locked == 1);
        VehicleData[vid][vInsurance]   = (ins == 1);
        VehicleData[vid][vRovigneta]   = (rov == 1);
        VehicleData[vid][vITP]         = (itp == 1);
        VehicleData[vid][vRegistered]  = (reg == 1);
        VehicleData[vid][vTrusa]       = (trusa == 1);
        VehicleData[vid][vStingator]   = (sting == 1);
        VehicleData[vid][vVesta]       = (vesta == 1);

        cache_get_value_name(i, "insurance_exp", VehicleData[vid][vInsuranceExp], 12);
        cache_get_value_name(i, "rovigneta_exp", VehicleData[vid][vRovignetaExp], 12);
        cache_get_value_name(i, "itp_exp", VehicleData[vid][vITPExp], 12);

        // Spawneaza vehiculul
        VehicleData[vid][vGameID] = CreateVehicle(
            VehicleData[vid][vModel],
            VehicleData[vid][vX], VehicleData[vid][vY], VehicleData[vid][vZ],
            VehicleData[vid][vAngle],
            VehicleData[vid][vColor1], VehicleData[vid][vColor2], -1
        );
        SetVehicleNumberPlate(VehicleData[vid][vGameID], VehicleData[vid][vPlate]);

        PlayerVehicles[playerid][PlayerVehicleCount[playerid]] = vid;
        PlayerVehicleCount[playerid]++;
    }
}

stock Vehicles_SaveAll(playerid)
{
    for(new i = 0; i < PlayerVehicleCount[playerid]; i++)
    {
        new vid = PlayerVehicles[playerid][i];
        if(VehicleData[vid][vID] == 0) continue;

        new Float:x, Float:y, Float:z, Float:a;
        GetVehiclePos(VehicleData[vid][vGameID], x, y, z);
        GetVehicleZAngle(VehicleData[vid][vGameID], a);

        new query[512];
       mysql_format(g_SQL, query, sizeof(query),
            "UPDATE `vehicles` SET "
            "`pos_x`=%.4f,`pos_y`=%.4f,`pos_z`=%.4f,`angle`=%.2f,"
            "`fuel`=%.2f,`mileage`=%d,`locked`=%d "
            "WHERE `id`=%d",
            x, y, z, a,
            VehicleData[vid][vFuel],
            VehicleData[vid][vMileage],
            VehicleData[vid][vLocked] ? 1 : 0,
            VehicleData[vid][vID]
        );

        mysql_tquery(g_SQL, query);

        DestroyVehicle(VehicleData[vid][vGameID]);
        VehicleData[vid][vGameID] = 0;
        VehicleData[vid][vID] = 0;
    }
    PlayerVehicleCount[playerid] = 0;
}

// ============================================================
//  CALLBACKS
// ============================================================

stock Vehicles_OnDeath(vehicleid, killerid)
{
    // Marcheaza vehiculul ca distrus
    for(new i = 0; i < MAX_VEHICLES; i++)
    {
        if(VehicleData[i][vGameID] == vehicleid)
        {
            VehicleData[i][vFuel] = 0.0;
            break;
        }
    }
}

stock Vehicles_OnEnter(playerid, vehicleid, ispassenger)
{
    // Verifica daca e vehiculul playerului
    for(new i = 0; i < PlayerVehicleCount[playerid]; i++)
    {
        new vid = PlayerVehicles[playerid][i];
        if(VehicleData[vid][vGameID] == vehicleid)
        {
            if(VehicleData[vid][vLocked] && !ispassenger)
            {
                RemovePlayerFromVehicle(playerid);
                SendMsg(playerid, COLOR_ERROR, "[!] Vehiculul este incuiat!");
            }
            return;
        }
    }
}

stock Vehicles_OnExit(playerid, vehicleid)
{
    // Salveaza pozitia
    for(new i = 0; i < PlayerVehicleCount[playerid]; i++)
    {
        new vid = PlayerVehicles[playerid][i];
        if(VehicleData[vid][vGameID] == vehicleid)
        {
            GetVehiclePos(vehicleid, VehicleData[vid][vX], VehicleData[vid][vY], VehicleData[vid][vZ]);
            GetVehicleZAngle(vehicleid, VehicleData[vid][vAngle]);
            break;
        }
    }
}

// ============================================================
//  HELPER - gaseste vid dupa game vehicleid
// ============================================================

stock GetVehicleDataID(vehicleid)
{
    for(new i = 0; i < MAX_VEHICLES; i++)
    {
        if(VehicleData[i][vGameID] == vehicleid) return i;
    }
    return -1;
}

stock GetPlayerVehicleSlot(playerid, vehicleid)
{
    for(new i = 0; i < PlayerVehicleCount[playerid]; i++)
    {
        new vid = PlayerVehicles[playerid][i];
        if(VehicleData[vid][vGameID] == vehicleid) return vid;
    }
    return -1;
}

// ============================================================
//  COMENZI VEHICULE
// ============================================================

CMD:vlock(playerid, params[])
{
    if(!PlayerData[playerid][pLogged]) return 1;
    new vehicleid = GetPlayerVehicleID(playerid);
    if(!vehicleid) return SendMsg(playerid, COLOR_ERROR, "[!] Nu esti in niciun vehicul!");

    new vid = GetPlayerVehicleSlot(playerid, vehicleid);
    if(vid == -1) return SendMsg(playerid, COLOR_ERROR, "[!] Nu iti apartine acest vehicul!");

    VehicleData[vid][vLocked] = !VehicleData[vid][vLocked];
    SendMsgFmt(playerid, COLOR_SUCCESS, "[Vehicul] Vehicul %s.",
        VehicleData[vid][vLocked] ? "incuiat" : "descuiat");
    return 1;
}

CMD:engine(playerid, params[])
{
    if(!PlayerData[playerid][pLogged]) return 1;
    new vehicleid = GetPlayerVehicleID(playerid);
    if(!vehicleid) return SendMsg(playerid, COLOR_ERROR, "[!] Nu esti in niciun vehicul!");

    new vid = GetPlayerVehicleSlot(playerid, vehicleid);
    if(vid == -1) return SendMsg(playerid, COLOR_ERROR, "[!] Nu iti apartine acest vehicul!");

    if(VehicleData[vid][vFuel] <= 0.0)
        return SendMsg(playerid, COLOR_ERROR, "[!] Vehiculul nu are combustibil!");

    new engine, lights, alarm, doors, bonnet, boot, objective;
    GetVehicleParamsEx(vehicleid, engine, lights, alarm, doors, bonnet, boot, objective);
    engine = (engine == 1) ? 0 : 1;
    SetVehicleParamsEx(vehicleid, engine, lights, alarm, doors, bonnet, boot, objective);

    SendMsgFmt(playerid, COLOR_SUCCESS, "[Vehicul] Motor %s.", engine ? "pornit" : "oprit");
    return 1;
}

CMD:refuel(playerid, params[])
{
    if(!PlayerData[playerid][pLogged]) return 1;
    new vehicleid = GetPlayerVehicleID(playerid);
    if(!vehicleid) return SendMsg(playerid, COLOR_ERROR, "[!] Nu esti in niciun vehicul!");

    new vid = GetPlayerVehicleSlot(playerid, vehicleid);
    if(vid == -1) return SendMsg(playerid, COLOR_ERROR, "[!] Nu iti apartine acest vehicul!");

    new cost = floatround((100.0 - VehicleData[vid][vFuel]) * 10.0);
    if(GetPlayerMoney(playerid) < cost)
        return SendMsgFmt(playerid, COLOR_ERROR, "[!] Ai nevoie de $%d pentru plin.", cost);

    GivePlayerMoney(playerid, -cost);
    PlayerData[playerid][pMoney] -= cost;
    VehicleData[vid][vFuel] = 100.0;
    SendMsgFmt(playerid, COLOR_SUCCESS, "[Benzinarie] Plin facut! Ai platit $%d.", cost);
    return 1;
}

CMD:vehicle(playerid, params[])
{
    if(!PlayerData[playerid][pLogged]) return 1;
    if(PlayerVehicleCount[playerid] == 0)
        return SendMsg(playerid, COLOR_ERROR, "[!] Nu ai nicio masina personala!");

    new info[512];
    for(new i = 0; i < PlayerVehicleCount[playerid]; i++)
    {
        new vid = PlayerVehicles[playerid][i];
        new line[64];
        format(line, sizeof(line), "Masina #%d: Model %d | Numar: %s | Carburant: %.0f%%\n",
            i+1, VehicleData[vid][vModel], VehicleData[vid][vPlate], VehicleData[vid][vFuel]);
        strcat(info, line);
    }
    ShowPlayerDialog(playerid, DIALOG_VEHICLE_MENU, DIALOG_STYLE_LIST,
        "{FFD700}Vehiculele Tale", info, "Selecteaza", "Inchide");
    return 1;
}

// ---- RAR: Verifica acte ----
CMD:checkcar(playerid, params[])
{
    if(PlayerData[playerid][pFaction] != FACTION_RAR &&
       PlayerData[playerid][pFaction] != FACTION_POLITIE)
        return SendMsg(playerid, COLOR_ERROR, "[!] Nu ai permisiunea!");

    new targetid;
    if(sscanf(params, "u", targetid))
        return SendMsg(playerid, COLOR_ERROR, "Folosire: /checkcar [jucator]");

    new vehicleid = GetPlayerVehicleID(targetid);
    if(!vehicleid)
        return SendMsg(playerid, COLOR_ERROR, "[!] Jucatorul nu este intr-un vehicul!");

    new vid = -1;
    for(new i = 0; i < MAX_VEHICLES; i++)
    {
        if(VehicleData[i][vGameID] == vehicleid) { vid = i; break; }
    }

    if(vid == -1)
        return SendMsg(playerid, COLOR_ERROR, "[!] Vehiculul nu este inregistrat in sistem!");

    new info[512], tname[24];
    GetPlayerName(targetid, tname, 24);
    format(info, sizeof(info),
        "{FFD700}== Verificare Vehicul: %s ==\n\n"
        "{FFFFFF}Numar inmatriculare: {00FF00}%s\n"
        "Model: {00FF00}%d\n"
        "Inmatriculat: %s\n"
        "Asigurare: %s (exp: %s)\n"
        "Rovigneta: %s (exp: %s)\n"
        "ITP: %s (exp: %s)\n"
        "Trusa medicala: %s\n"
        "Stingator: %s\n"
        "Vesta reflectorizanta: %s",
        tname,
        VehicleData[vid][vPlate],
        VehicleData[vid][vModel],
        VehicleData[vid][vRegistered] ? "{00FF00}DA" : "{FF4444}NU",
        VehicleData[vid][vInsurance]  ? "{00FF00}DA" : "{FF4444}NU", VehicleData[vid][vInsuranceExp],
        VehicleData[vid][vRovigneta]  ? "{00FF00}DA" : "{FF4444}NU", VehicleData[vid][vRovignetaExp],
        VehicleData[vid][vITP]        ? "{00FF00}DA" : "{FF4444}NU", VehicleData[vid][vITPExp],
        VehicleData[vid][vTrusa]      ? "{00FF00}DA" : "{FF4444}NU",
        VehicleData[vid][vStingator]  ? "{00FF00}DA" : "{FF4444}NU",
        VehicleData[vid][vVesta]      ? "{00FF00}DA" : "{FF4444}NU"
    );

    ShowPlayerDialog(playerid, DIALOG_RAR_CHECK, DIALOG_STYLE_MSGBOX,
        "Verificare Acte Vehicul", info, "Inchide", "Amenda");
    return 1;
}
