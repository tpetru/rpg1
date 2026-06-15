// ============================================================
//  PETS.INC - Animale de companie
// ============================================================
#if defined _pets_included
    #endinput
#endif
#define _pets_included

enum E_PET_DATA
{
    petID, petOwnerID,
    petName[24], petType, petModel,
    Float:petHealth, petHunger, petHappiness,
    petHouseID, bool:petIsOut,
    Float:petX, Float:petY, Float:petZ,
    petActorID  // actorul SAMP care reprezinta pet-ul
}

new PetData[MAX_PETS][E_PET_DATA];
new PetCount = 0;

// Tipuri animale
#define PET_DOG     0
#define PET_CAT     1
#define PET_RABBIT  2
#define PET_BIRD    3

new PetModels[] = {
    109, // caine
    90,  // pisica
    99,  // iepure (placeholder)
    86   // pasare (placeholder)
};

new PetNames[][12] = {
    "Caine", "Pisica", "Iepure", "Pasare"
};

// ============================================================
//  LOAD / SAVE
// ============================================================

stock Pets_LoadForPlayer(playerid)
{
    new query[128];
    mysql_format(g_SQL, query, sizeof(query),
        "SELECT * FROM `pets` WHERE `owner_id`=%d",
        PlayerData[playerid][pID]);
    mysql_tquery(g_SQL, query, "OnPetsLoaded", "i", playerid);
}

forward OnPetsLoaded(playerid);
public OnPetsLoaded(playerid)
{
    new rows = cache_num_rows();
    for(new i = 0; i < rows; i++)
    {
        new pid = -1;
        for(new j = 0; j < MAX_PETS; j++)
        {
            if(PetData[j][petID] == 0) { pid = j; break; }
        }
        if(pid == -1) break;

        cache_get_value_name_int(i, "id", PetData[pid][petID]);
        cache_get_value_name_int(i, "owner_id", PetData[pid][petOwnerID]);
        cache_get_value_name(i, "name", PetData[pid][petName], 24);
        cache_get_value_name_int(i, "type", PetData[pid][petType]);
        cache_get_value_name_int(i, "model", PetData[pid][petModel]);
        cache_get_value_name_float(i, "health", PetData[pid][petHealth]);
        cache_get_value_name_int(i, "hunger", PetData[pid][petHunger]);
        cache_get_value_name_int(i, "happiness", PetData[pid][petHappiness]);
        cache_get_value_name_int(i, "house_id", PetData[pid][petHouseID]);
        cache_get_value_name_float(i, "pos_x", PetData[pid][petX]);
        cache_get_value_name_float(i, "pos_y", PetData[pid][petY]);
        cache_get_value_name_float(i, "pos_z", PetData[pid][petZ]);

        new isout;
        cache_get_value_name_int(i, "is_out", isout);
        PetData[pid][petIsOut] = (isout == 1);

        // Spawn actor la pozitia proprietarului daca e "out"
        if(PetData[pid][petIsOut] && IsPlayerConnected(playerid))
        {
            new Float:px, Float:py, Float:pz;
            GetPlayerPos(playerid, px, py, pz);
            PetData[pid][petActorID] = CreateActor(PetData[pid][petModel], px+1.0, py+1.0, pz, 0.0);
        }
        PetCount++;
    }
}

stock Pets_SaveAll(playerid)
{
    for(new i = 0; i < MAX_PETS; i++)
    {
        if(PetData[i][petOwnerID] != PlayerData[playerid][pID]) continue;
        if(PetData[i][petID] == 0) continue;

        new query[256];
        mysql_format(g_SQL, query, sizeof(query),
            "UPDATE `pets` SET "
            "`health`=%.2f,`hunger`=%d,`happiness`=%d,"
            "`house_id`=%d,`is_out`=%d,"
            "`pos_x`=%.4f,`pos_y`=%.4f,`pos_z`=%.4f "
            "WHERE `id`=%d",
            PetData[i][petHealth], PetData[i][petHunger], PetData[i][petHappiness],
            PetData[i][petHouseID], PetData[i][petIsOut] ? 1 : 0,
            PetData[i][petX], PetData[i][petY], PetData[i][petZ],
            PetData[i][petID]);
        mysql_tquery(g_SQL, query, "", "", 0);

        if(PetData[i][petActorID] > 0)
        {
            DestroyActor(PetData[i][petActorID]);
            PetData[i][petActorID] = 0;
        }
        PetData[i][petID] = 0;
    }
}

// ============================================================
//  CUMPARARE PET
// ============================================================

stock Pet_Buy(playerid, type)
{
    if(type < 0 || type > 3) return SendMsg(playerid, COLOR_ERROR, "[!] Tip invalid!");

    new petcount = 0;
    for(new i = 0; i < MAX_PETS; i++)
    {
        if(PetData[i][petOwnerID] == PlayerData[playerid][pID]) petcount++;
    }
    if(petcount >= 3) return SendMsg(playerid, COLOR_ERROR, "[!] Ai deja 3 animale de companie!");

    new price = 5000;
    if(GetPlayerMoney(playerid) < price)
        return SendMsgFmt(playerid, COLOR_ERROR, "[!] Ai nevoie de $%d!", price);

    GivePlayerMoney(playerid, -price);
    PlayerData[playerid][pMoney] -= price;

    new pid = -1;
    for(new i = 0; i < MAX_PETS; i++)
    {
        if(PetData[i][petID] == 0) { pid = i; break; }
    }
    if(pid == -1) return SendMsg(playerid, COLOR_ERROR, "[!] Server plin de animale!");

    new query[256];
    mysql_format(g_SQL, query, sizeof(query),
        "INSERT INTO `pets` (`owner_id`,`name`,`type`,`model`,`health`,`hunger`,`happiness`,`is_out`) "
        "VALUES (%d,'%e',%d,%d,100.0,100,100,1)",
        PlayerData[playerid][pID], PetNames[type], type, PetModels[type]);
    mysql_tquery(g_SQL, query, "OnPetBought", "ii", playerid, pid);
    return 1;
}

forward OnPetBought(playerid, slotid);
public OnPetBought(playerid, slotid)
{
    PetData[slotid][petID]       = cache_insert_id();
    PetData[slotid][petOwnerID]  = PlayerData[playerid][pID];
    PetData[slotid][petType]     = GetPVarInt(playerid, "BuyPetType");
    PetData[slotid][petModel]    = PetModels[PetData[slotid][petType]];
    PetData[slotid][petHealth]   = 100.0;
    PetData[slotid][petHunger]   = 100;
    PetData[slotid][petHappiness]= 100;
    PetData[slotid][petIsOut]    = true;
    format(PetData[slotid][petName], 24, "%s", PetNames[PetData[slotid][petType]]);

    new Float:px, Float:py, Float:pz;
    GetPlayerPos(playerid, px, py, pz);
    PetData[slotid][petActorID] = CreateActor(PetData[slotid][petModel], px+1.0, py, pz, 0.0);
    PetCount++;

    SendMsgFmt(playerid, COLOR_SUCCESS, "[Pet] Ai cumparat un %s! Il poti numi cu /namepet.", PetNames[PetData[slotid][petType]]);
}

// ============================================================
//  HRĂNIRE / INTERACTIUNE
// ============================================================

stock Pet_GetPlayerSlot(playerid, index)
{
    new count = 0;
    for(new i = 0; i < MAX_PETS; i++)
    {
        if(PetData[i][petOwnerID] == PlayerData[playerid][pID])
        {
            if(count == index) return i;
            count++;
        }
    }
    return -1;
}

stock Pet_Feed(playerid, slotid)
{
    if(PetData[slotid][petOwnerID] != PlayerData[playerid][pID])
        return SendMsg(playerid, COLOR_ERROR, "[!] Nu iti apartine!");

    new cost = 200;
    if(GetPlayerMoney(playerid) < cost)
        return SendMsgFmt(playerid, COLOR_ERROR, "[!] Ai nevoie de $%d pentru mancare!", cost);

    GivePlayerMoney(playerid, -cost);
    PlayerData[playerid][pMoney] -= cost;
    PetData[slotid][petHunger] = 100;
    PetData[slotid][petHappiness] = (PetData[slotid][petHappiness] + 10 > 100) ? 100 : PetData[slotid][petHappiness] + 10;

    SendMsgFmt(playerid, COLOR_SUCCESS, "[Pet] %s a mancat cu pofta!", PetData[slotid][petName]);
    return 1;
}

// ============================================================
//  PAYDAY DECAY
// ============================================================

stock Pets_PaydayDecay(playerid)
{
    for(new i = 0; i < MAX_PETS; i++)
    {
        if(PetData[i][petOwnerID] != PlayerData[playerid][pID]) continue;
        if(PetData[i][petID] == 0) continue;

        PetData[i][petHunger]    -= 10;
        PetData[i][petHappiness] -= 5;

        if(PetData[i][petHunger] < 0) PetData[i][petHunger] = 0;
        if(PetData[i][petHappiness] < 0) PetData[i][petHappiness] = 0;

        if(PetData[i][petHunger] == 0)
        {
            PetData[i][petHealth] -= 10.0;
            if(PetData[i][petHealth] < 0.0) PetData[i][petHealth] = 0.0;
            SendMsgFmt(playerid, COLOR_ERROR, "[Pet] %s este flamand si slab!", PetData[i][petName]);
        }
    }
}

// ============================================================
//  COMENZI
// ============================================================

CMD:pet(playerid, params[])
{
    if(!PlayerData[playerid][pLogged]) return 1;

    new info[256];
    new count = 0;
    for(new i = 0; i < MAX_PETS; i++)
    {
        if(PetData[i][petOwnerID] == PlayerData[playerid][pID] && PetData[i][petID] != 0)
        {
            new line[64];
            format(line, sizeof(line), "%s | Sanatate: %.0f%% | Foame: %d%% | Fericire: %d%%\n",
                PetData[i][petName], PetData[i][petHealth], PetData[i][petHunger], PetData[i][petHappiness]);
            strcat(info, line);
            count++;
        }
    }

    if(count == 0)
    {
        format(info, sizeof(info),
            "Nu ai animale de companie.\n\nCumpara de la magazinul de animale!\n"
            "Tipuri: Caine ($5000), Pisica ($5000), Iepure ($5000), Pasare ($5000)");
        ShowPlayerDialog(playerid, DIALOG_PET_MENU, DIALOG_STYLE_MSGBOX,
            "{FFD700}Animale de Companie", info, "Cumpara", "Inchide");
    }
    else
    {
        ShowPlayerDialog(playerid, DIALOG_PET_MENU, DIALOG_STYLE_LIST,
            "{FFD700}Animale de Companie", info, "Selecteaza", "Inchide");
    }
    return 1;
}

CMD:namepet(playerid, params[])
{
    if(!PlayerData[playerid][pLogged]) return 1;
    new newname[24];
    if(sscanf(params, "s[24]", newname))
        return SendMsg(playerid, COLOR_ERROR, "Folosire: /namepet [nume]");

    new pid = Pet_GetPlayerSlot(playerid, 0);
    if(pid == -1) return SendMsg(playerid, COLOR_ERROR, "[!] Nu ai animale!");

    format(PetData[pid][petName], 24, "%s", newname);
    new query[128];
    mysql_format(g_SQL, query, sizeof(query),
        "UPDATE `pets` SET `name`='%e' WHERE `id`=%d",
        newname, PetData[pid][petID]);
    mysql_tquery(g_SQL, query, "", "", 0);

    SendMsgFmt(playerid, COLOR_SUCCESS, "[Pet] Animal redenumit in %s!", newname);
    return 1;
}

CMD:feedpet(playerid, params[])
{
    if(!PlayerData[playerid][pLogged]) return 1;
    new idx = 0;
    sscanf(params, "i", idx);
    new pid = Pet_GetPlayerSlot(playerid, idx);
    if(pid == -1) return SendMsg(playerid, COLOR_ERROR, "[!] Animal invalid!");
    Pet_Feed(playerid, pid);
    return 1;
}

CMD:pethome(playerid, params[])
{
    if(!PlayerData[playerid][pLogged]) return 1;
    // Pune animalul in casa
    new houseid = GetPlayerOwnedHouse(playerid);
    if(houseid == -1) return SendMsg(playerid, COLOR_ERROR, "[!] Nu ai casa!");
    if(!HouseData[houseid][hHasPets]) return SendMsg(playerid, COLOR_ERROR, "[!] Casa nu permite animale!");

    new idx = 0;
    sscanf(params, "i", idx);
    new pid = Pet_GetPlayerSlot(playerid, idx);
    if(pid == -1) return SendMsg(playerid, COLOR_ERROR, "[!] Animal invalid!");

    PetData[pid][petIsOut] = false;
    PetData[pid][petHouseID] = HouseData[houseid][hID];

    if(PetData[pid][petActorID] > 0)
    {
        DestroyActor(PetData[pid][petActorID]);
        PetData[pid][petActorID] = 0;
    }
    SendMsgFmt(playerid, COLOR_SUCCESS, "[Pet] %s a fost dus acasa!", PetData[pid][petName]);
    return 1;
}
