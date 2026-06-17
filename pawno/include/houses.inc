// ============================================================
//  HOUSES.INC - Case personale, interior, chirie, animale
// ============================================================
#if defined _houses_included
    #endinput
#endif
#define _houses_included

enum E_HOUSE_DATA
{
    hID, hOwnerID,
    hAddress[64], hPrice,
    hInterior, hForSale, bool:hLocked,
    Float:hX, Float:hY, Float:hZ,
    Float:hInX, Float:hInY, Float:hInZ,
    hRentPrice, hTaxes,
    bool:hHasPets, hMaxPets,
    hPickup, hLabel
}

new HouseData[MAX_HOUSES][E_HOUSE_DATA];
new HouseCount = 0;

// Playerul in ce casa e (interior)
new PlayerInHouse[MAX_PLAYERS] = {-1, ...};

// ============================================================
//  INIT & LOAD
// ============================================================

stock Houses_Init()
{
    mysql_tquery(g_SQL, "SELECT * FROM `houses`", "OnHousesLoaded", "", 0);
}

forward OnHousesLoaded();
public OnHousesLoaded()
{
    HouseCount = cache_num_rows();
    for(new i = 0; i < HouseCount; i++)
    {
        cache_get_value_name_int(i, "id", HouseData[i][hID]);
        cache_get_value_name_int(i, "owner_id", HouseData[i][hOwnerID]);
        cache_get_value_name(i, "address", HouseData[i][hAddress], 64);
        cache_get_value_name_int(i, "price", HouseData[i][hPrice]);
        cache_get_value_name_int(i, "interior", HouseData[i][hInterior]);
        cache_get_value_name_float(i, "pos_x", HouseData[i][hX]);
        cache_get_value_name_float(i, "pos_y", HouseData[i][hY]);
        cache_get_value_name_float(i, "pos_z", HouseData[i][hZ]);
        cache_get_value_name_float(i, "in_x", HouseData[i][hInX]);
        cache_get_value_name_float(i, "in_y", HouseData[i][hInY]);
        cache_get_value_name_float(i, "in_z", HouseData[i][hInZ]);
        cache_get_value_name_int(i, "rent_price", HouseData[i][hRentPrice]);
        cache_get_value_name_int(i, "taxes", HouseData[i][hTaxes]);

        new sale, locked, hpets, maxpets;
        cache_get_value_name_int(i, "for_sale", sale);
        cache_get_value_name_int(i, "locked", locked);
        cache_get_value_name_int(i, "has_pets", hpets);
        cache_get_value_name_int(i, "max_pets", maxpets);
        HouseData[i][hForSale]  = sale;
        HouseData[i][hLocked]   = (locked == 1);
        HouseData[i][hHasPets]  = (hpets == 1);
        HouseData[i][hMaxPets]  = maxpets;

        // Pickup si label
        new labeltext[64];
        if(HouseData[i][hOwnerID] == 0)
            format(labeltext, sizeof(labeltext), "{FFD700}Casa de vanzare\n{FFFFFF}Pret: $%d\n/buthouse", HouseData[i][hPrice]);
        else
            format(labeltext, sizeof(labeltext), "{00FF00}Casa privata\n{FFFFFF}%s\n/knockhouse", HouseData[i][hAddress]);

        HouseData[i][hPickup] = CreatePickup(
            HouseData[i][hOwnerID] == 0 ? 1273 : 1272,
            1,
            HouseData[i][hX], HouseData[i][hY], HouseData[i][hZ],
            -1
        );
        HouseData[i][hLabel] = _:Create3DTextLabel(
            labeltext, 0xFFFFFFFF,
            HouseData[i][hX], HouseData[i][hY], HouseData[i][hZ]+0.5,
            10.0, 0, 0
        );
    }
    new msg[48];
    format(msg, sizeof(msg), "[Houses] %d case incarcate.", HouseCount);
    print(msg);
}

// ============================================================
//  FUNCTII CASA
// ============================================================

stock GetHouseByPickup(pickupid)
{
    for(new i = 0; i < HouseCount; i++)
    {
        if(HouseData[i][hPickup] == pickupid) return i;
    }
    return -1;
}

stock GetPlayerOwnedHouse(playerid)
{
    for(new i = 0; i < HouseCount; i++)
    {
        if(HouseData[i][hOwnerID] == PlayerData[playerid][pID]) return i;
    }
    return -1;
}

stock House_Buy(playerid, houseid)
{
    if(HouseData[houseid][hOwnerID] != 0)
        return SendMsg(playerid, COLOR_ERROR, "[!] Casa are deja proprietar!");
    if(GetPlayerMoney(playerid) < HouseData[houseid][hPrice])
        return SendMsgFmt(playerid, COLOR_ERROR, "[!] Ai nevoie de $%d!", HouseData[houseid][hPrice]);
    if(GetPlayerOwnedHouse(playerid) != -1)
        return SendMsg(playerid, COLOR_ERROR, "[!] Ai deja o casa! Vinde-o mai intai.");

    GivePlayerMoney(playerid, -HouseData[houseid][hPrice]);
    PlayerData[playerid][pMoney] -= HouseData[houseid][hPrice];
    HouseData[houseid][hOwnerID] = PlayerData[playerid][pID];
    HouseData[houseid][hForSale] = 0;
    HouseData[houseid][hLocked] = true;

    new query[128];
    mysql_format(g_SQL, query, sizeof(query),
        "UPDATE `houses` SET `owner_id`=%d,`for_sale`=0,`locked`=1 WHERE `id`=%d",
        PlayerData[playerid][pID], HouseData[houseid][hID]);
    mysql_tquery(g_SQL, query, "", "", 0);

    // Refresh label
    new name[24];
    GetPlayerName(playerid, name, 24);
    new labeltext[64];
    format(labeltext, sizeof(labeltext), "{00FF00}Casa privata\n{FFFFFF}%s", HouseData[houseid][hAddress]);
    Update3DTextLabelText(Text3D:HouseData[houseid][hLabel], 0xFFFFFFFF, labeltext);

    SendMsgFmt(playerid, COLOR_SUCCESS, "[Casa] Ai cumparat casa din %s pentru $%d!",
        HouseData[houseid][hAddress], HouseData[houseid][hPrice]);
    return 1;
}

stock House_Enter(playerid, houseid)
{
    if(HouseData[houseid][hLocked])
    {
        if(HouseData[houseid][hOwnerID] != PlayerData[playerid][pID])
            return SendMsg(playerid, COLOR_ERROR, "[!] Casa este incuiata!");
    }

    PlayerInHouse[playerid] = houseid;
    SetPlayerPos(playerid, HouseData[houseid][hInX], HouseData[houseid][hInY], HouseData[houseid][hInZ]);
    SetPlayerInterior(playerid, HouseData[houseid][hInterior]);
    SetPlayerVirtualWorld(playerid, playerid + 1000);

    SendMsg(playerid, COLOR_SYSTEM, "[Casa] Ai intrat in casa. Foloseste /exithouse pentru a iesi.");
    return 1;
}

stock House_Exit(playerid)
{
    new houseid = PlayerInHouse[playerid];
    if(houseid == -1) return SendMsg(playerid, COLOR_ERROR, "[!] Nu esti intr-o casa!");

    SetPlayerPos(playerid, HouseData[houseid][hX], HouseData[houseid][hY], HouseData[houseid][hZ]);
    SetPlayerInterior(playerid, 0);
    SetPlayerVirtualWorld(playerid, 0);
    PlayerInHouse[playerid] = -1;
    return 1;
}

stock House_ShowMenu(playerid, houseid)
{
    if(HouseData[houseid][hOwnerID] != PlayerData[playerid][pID])
        return SendMsg(playerid, COLOR_ERROR, "[!] Nu iti apartine casa!");

    new info[256];
    format(info, sizeof(info),
        "Intra in casa\n"
        "Incuie / Descuie\n"
        "Animale de companie\n"
        "Pune la vanzare ($%d)\n"
        "Vinde casa",
        HouseData[houseid][hPrice]);
    ShowPlayerDialog(playerid, DIALOG_HOUSE_MENU, DIALOG_STYLE_LIST,
        "{FFD700}Meniu Casa", info, "Selecteaza", "Inchide");
    return 1;
}

// ============================================================
//  COMENZI
// ============================================================

CMD:house(playerid, params[])
{
    if(!PlayerData[playerid][pLogged]) return 1;
    new houseid = GetPlayerOwnedHouse(playerid);
    if(houseid == -1)
        return SendMsg(playerid, COLOR_ERROR, "[!] Nu ai o casa. Cauta pickupuri galbene de casa!");
    House_ShowMenu(playerid, houseid);
    return 1;
}

CMD:enterhouse(playerid, params[])
{
    if(!PlayerData[playerid][pLogged]) return 1;
    // Cauta casa apropiata
    new Float:px, Float:py, Float:pz;
    GetPlayerPos(playerid, px, py, pz);
    for(new i = 0; i < HouseCount; i++)
    {
        if(VectorSize(px-HouseData[i][hX], py-HouseData[i][hY], pz-HouseData[i][hZ]) < 3.0)
        {
            House_Enter(playerid, i);
            return 1;
        }
    }
    SendMsg(playerid, COLOR_ERROR, "[!] Nu esti langa nicio casa!");
    return 1;
}

CMD:exithouse(playerid, params[])
{
    House_Exit(playerid);
    return 1;
}

CMD:houselock(playerid, params[])
{
    if(!PlayerData[playerid][pLogged]) return 1;
    new houseid = GetPlayerOwnedHouse(playerid);
    if(houseid == -1) return SendMsg(playerid, COLOR_ERROR, "[!] Nu ai o casa!");
    HouseData[houseid][hLocked] = !HouseData[houseid][hLocked];
    SendMsgFmt(playerid, COLOR_SUCCESS, "[Casa] Casa %s.",
        HouseData[houseid][hLocked] ? "incuiata" : "descuiata");
    return 1;
}

CMD:buthouse(playerid, params[])
{
    if(!PlayerData[playerid][pLogged]) return 1;
    new Float:px, Float:py, Float:pz;
    GetPlayerPos(playerid, px, py, pz);
    for(new i = 0; i < HouseCount; i++)
    {
        if(HouseData[i][hForSale] && VectorSize(px-HouseData[i][hX], py-HouseData[i][hY], pz-HouseData[i][hZ]) < 3.0)
        {
            new info[128];
            format(info, sizeof(info), "Vrei sa cumperi casa din {FFD700}%s{FFFFFF} pentru {00FF00}$%d{FFFFFF}?",
                HouseData[i][hAddress], HouseData[i][hPrice]);
            ShowPlayerDialog(playerid, DIALOG_HOUSE_BUY, DIALOG_STYLE_MSGBOX,
                "Cumpara Casa", info, "Cumpara", "Anuleaza");
            SetPVarInt(playerid, "BuyHouseID", i);
            return 1;
        }
    }
    SendMsg(playerid, COLOR_ERROR, "[!] Nu esti langa nicio casa de vanzare!");
    return 1;
}

CMD:sellhouse(playerid, params[])
{
    if(!PlayerData[playerid][pLogged]) return 1;
    new houseid = GetPlayerOwnedHouse(playerid);
    if(houseid == -1) return SendMsg(playerid, COLOR_ERROR, "[!] Nu ai o casa!");

    new refund = HouseData[houseid][hPrice] / 2;
    GivePlayerMoney(playerid, refund);
    PlayerData[playerid][pMoney] += refund;

    HouseData[houseid][hOwnerID] = 0;
    HouseData[houseid][hForSale] = 1;
    HouseData[houseid][hLocked] = true;

    new query[128];
    mysql_format(g_SQL, query, sizeof(query),
        "UPDATE `houses` SET `owner_id`=0,`for_sale`=1,`locked`=1 WHERE `id`=%d",
        HouseData[houseid][hID]);
    mysql_tquery(g_SQL, query, "", "", 0);

    new labeltext[64];
    format(labeltext, sizeof(labeltext), "{FFD700}Casa de vanzare\n{FFFFFF}Pret: $%d\n/buthouse", HouseData[houseid][hPrice]);
    Update3DTextLabelText(Text3D:HouseData[houseid][hLabel], 0xFFFFFFFF, labeltext);

    SendMsgFmt(playerid, COLOR_SUCCESS, "[Casa] Casa vanduta. Ai primit $%d (50%% din valoare).", refund);
    return 1;
}

// ---- Politia animalelor: verifica conditii casa ----
CMD:checkhousepets(playerid, params[])
{
    if(PlayerData[playerid][pFaction] != FACTION_POLITIE_ANIMALE)
        return SendMsg(playerid, COLOR_ERROR, "[!] Nu ai permisiunea!");

    new targetid;
    if(sscanf(params, "u", targetid))
        return SendMsg(playerid, COLOR_ERROR, "Folosire: /checkhousepets [jucator]");

    new houseid = GetPlayerOwnedHouse(targetid);
    if(houseid == -1)
        return SendMsg(playerid, COLOR_ERROR, "[!] Jucatorul nu are casa!");

    new info[256];
    format(info, sizeof(info),
        "{FFD700}== Verificare Casa: %s ==\n\n"
        "{FFFFFF}Adresa: {00FF00}%s\n"
        "Animale permise: {00FF00}%s\n"
        "Max animale: {00FF00}%d\n"
        "Interior: {00FF00}%d",
        PlayerData[targetid][pName],
        HouseData[houseid][hAddress],
        HouseData[houseid][hHasPets] ? "DA" : "NU",
        HouseData[houseid][hMaxPets],
        HouseData[houseid][hInterior]
    );
    ShowPlayerDialog(playerid, 9999, DIALOG_STYLE_MSGBOX, "Verificare Casa", info, "Inchide", "");
    return 1;
}
