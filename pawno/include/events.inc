// ============================================================
//  EVENTS.INC - Handler central pentru toate callback-urile
//  Dialog, Pickups, Checkpoint, Text, Area
// ============================================================
#if defined _events_included
    #endinput
#endif
#define _events_included

stock Events_Init()
{
    print("[Events] Handler events incarcat.");
}

// ============================================================
//  DIALOG CENTRAL
// ============================================================

stock Dialog_OnResponse(playerid, dialogid, response, listitem, inputtext[])
{
    // ---- Autentificare ----
    if(dialogid == DIALOG_LOGIN ||
       dialogid == DIALOG_REGISTER ||
       dialogid == DIALOG_REGISTER_PASS)
        return Dialog_Auth_Response(playerid, dialogid, response, listitem, inputtext);

    if(!PlayerData[playerid][pLogged]) return 1;

    // ---- Presedinte ----
    if(dialogid == DIALOG_PRESIDENT_VOTE)
        return President_OnDialog(playerid, dialogid, response, listitem, inputtext);

    // ---- Ziar ----
    if(dialogid == DIALOG_NEWSPAPER_CREATE ||
       dialogid == DIALOG_NEWSPAPER_CREATE + 1 ||
       dialogid == DIALOG_NEWSPAPER_CREATE + 2 ||
       dialogid == DIALOG_NEWSPAPER_CAT ||
       dialogid == DIALOG_NEWSPAPER_CAT + 10 ||
       dialogid == DIALOG_NEWSPAPER_LIST)
        return Newspaper_OnDialog(playerid, dialogid, response, listitem, inputtext);

    // ---- Tururi ----
    if(dialogid == DIALOG_TOUR_SELECT_TYPE ||
       dialogid == DIALOG_TOUR_JOIN)
        return Tour_OnDialog(playerid, dialogid, response, listitem, inputtext);

    // ---- Trade ----
    if(dialogid == DIALOG_TRADE_OFFER ||
       dialogid == DIALOG_TRADE_CONFIRM)
        return Trade_OnDialog(playerid, dialogid, response, listitem, inputtext);

    // ---- Joburi ----
    if(dialogid == DIALOG_JOB_SELECT)
        return Jobs_OnDialog(playerid, dialogid, response, listitem, inputtext);

    // ---- Casa ----
    switch(dialogid)
    {
        case DIALOG_HOUSE_BUY:
        {
            if(!response) return 1;
            new houseid = GetPVarInt(playerid, "BuyHouseID");
            if(houseid >= 0 && houseid < HouseCount)
                House_Buy(playerid, houseid);
        }
        case DIALOG_HOUSE_MENU:
        {
            if(!response) return 1;
            new houseid = GetPlayerOwnedHouse(playerid);
            if(houseid == -1) return 1;
            switch(listitem)
            {
                case 0: House_Enter(playerid, houseid);
                case 1:
                {
                    HouseData[houseid][hLocked] = !HouseData[houseid][hLocked];
                    SendMsgFmt(playerid, COLOR_SUCCESS,
                        "[Casa] Casa %s.", HouseData[houseid][hLocked] ? "incuiata" : "descuiata");
                }
                case 2: SendMsg(playerid, COLOR_YELLOW, "[Casa] Foloseste /pet pentru animale in casa.");
                case 3:
                {
                    HouseData[houseid][hForSale] = 1;
                    new query[128];
                    mysql_format(g_SQL, query, sizeof(query),
                        "UPDATE `houses` SET for_sale=1 WHERE id=%d", HouseData[houseid][hID]);
                    mysql_tquery(g_SQL, query, "", "", 0);
                    SendMsg(playerid, COLOR_SUCCESS, "[Casa] Casa pusa la vanzare!");
                }
                case 4:
                {
                    // Declanseaza /sellhouse
                    new cmd[] = "";
                    cmd[0] = 0;
                    CallLocalFunction("OnPlayerCommandText", "is", playerid, "/sellhouse");
                }
            }
        }

        // ---- Vehicul ----
        case DIALOG_VEHICLE_MENU:
        {
            if(!response) return 1;
            // Afiseaza detalii vehicul selectat
            if(listitem >= PlayerVehicleCount[playerid]) return 1;
            new vid = PlayerVehicles[playerid][listitem];
            new info[256];
            format(info, sizeof(info),
                "{FFD700}Vehicul #%d{FFFFFF}\n\n"
                "Model: %d | Numar: %s\n"
                "Carburant: %.0f%% | Km: %d\n"
                "Incuiat: %s\n"
                "Inmatriculat: %s\n"
                "Asigurare: %s\n"
                "Rovigneta: %s\n"
                "ITP: %s",
                listitem+1, VehicleData[vid][vModel], VehicleData[vid][vPlate],
                VehicleData[vid][vFuel], VehicleData[vid][vMileage],
                VehicleData[vid][vLocked]     ? "DA" : "NU",
                VehicleData[vid][vRegistered] ? "DA" : "NU",
                VehicleData[vid][vInsurance]  ? "DA" : "NU",
                VehicleData[vid][vRovigneta]  ? "DA" : "NU",
                VehicleData[vid][vITP]        ? "DA" : "NU");
            ShowPlayerDialog(playerid, 9996, DIALOG_STYLE_MSGBOX,
                "Detalii Vehicul", info, "Inchide", "");
        }

        // ---- Pet ----
        case DIALOG_PET_MENU:
        {
            if(!response) return 1;
            if(listitem == -1)
            {
                // Cumpara animal
                new info2[] = "Caine ($5000)\nPisica ($5000)\nIepure ($5000)\nPasare ($5000)";
                SetPVarInt(playerid, "BuyPetMode", 1);
                ShowPlayerDialog(playerid, DIALOG_PET_MENU + 1, DIALOG_STYLE_LIST,
                    "Cumpara Animal", info2, "Cumpara", "Anuleaza");
            }
            else
            {
                new pid = Pet_GetPlayerSlot(playerid, listitem);
                if(pid == -1) return 1;
                new info3[256];
                format(info3, sizeof(info3),
                    "{FFD700}%s{FFFFFF}\n\n"
                    "Sanatate: {00FF00}%.0f%%\n"
                    "{FFFFFF}Foame: {FF8C00}%d%%\n"
                    "Fericire: {00FFFF}%d%%\n\n"
                    "In casa: %s",
                    PetData[pid][petName],
                    PetData[pid][petHealth],
                    PetData[pid][petHunger],
                    PetData[pid][petHappiness],
                    PetData[pid][petIsOut] ? "NU" : "DA");
                ShowPlayerDialog(playerid, 9995, DIALOG_STYLE_MSGBOX,
                    "Animal de Companie", info3, "Inchide", "");
            }
        }
        case DIALOG_PET_MENU + 1:
        {
            if(!response) return 1;
            SetPVarInt(playerid, "BuyPetType", listitem);
            Pet_Buy(playerid, listitem);
        }

        // ---- Mafia ----
        case DIALOG_MAFIA_SEIF:
        {
            // Readonly, afisat de /mafiaseif
        }

        // ---- Uber confirm ----
        case DIALOG_UBER_CONFIRM:
        {
            if(!response) return 1;
            // Soferul a confirmat preluarea cursei
        }
    }
    return 1;
}

// ============================================================
//  PICKUP CENTRAL
// ============================================================

stock Pickups_OnPickup(playerid, pickupid)
{
    if(!PlayerData[playerid][pLogged]) return 1;

    // Case
    for(new i = 0; i < HouseCount; i++)
    {
        if(HouseData[i][hPickup] != pickupid) continue;
        if(HouseData[i][hOwnerID] == PlayerData[playerid][pID])
            House_ShowMenu(playerid, i);
        else if(HouseData[i][hForSale])
        {
            SetPVarInt(playerid, "BuyHouseID", i);
            new info[128];
            format(info, sizeof(info),
                "Cumperi casa din {FFD700}%s{FFFFFF} pentru {00FF00}$%d{FFFFFF}?",
                HouseData[i][hAddress], HouseData[i][hPrice]);
            ShowPlayerDialog(playerid, DIALOG_HOUSE_BUY, DIALOG_STYLE_MSGBOX,
                "Cumpara Casa", info, "Cumpara", "Anuleaza");
        }
        else
            SendMsg(playerid, COLOR_GREY, "[Casa] Casa privata. Nu este de vanzare.");
        return 1;
    }

    // Afaceri
    for(new i = 0; i < BusinessCount; i++)
    {
        if(BusinessData[i][bPickup] != pickupid) continue;
        if(BusinessData[i][bOwnerID] == PlayerData[playerid][pID])
        {
            new info[128];
            format(info, sizeof(info),
                "{FFD700}%s{FFFFFF}\nProfit per payday: {00FF00}$%d{FFFFFF}\nTaxa: $%d",
                BusinessData[i][bName], BusinessData[i][bIncome], BusinessData[i][bTaxes]);
            ShowPlayerDialog(playerid, 9994, DIALOG_STYLE_MSGBOX,
                "Afacerea Ta", info, "Inchide", "");
        }
        else if(BusinessData[i][bForSale])
        {
            new info[128];
            format(info, sizeof(info),
                "Cumperi {FFD700}%s{FFFFFF} pentru {00FF00}$%d{FFFFFF}?\n"
                "Profit/payday: +$%d",
                BusinessData[i][bName], BusinessData[i][bPrice], BusinessData[i][bIncome]);
            SetPVarInt(playerid, "BuyBizID", i);
            ShowPlayerDialog(playerid, DIALOG_BUSINESS_BUY, DIALOG_STYLE_MSGBOX,
                "Cumpara Afacere", info, "Cumpara", "Anuleaza");
        }
        else
            SendMsg(playerid, COLOR_GREY, "[Afacere] Aceasta afacere nu este de vanzare.");
        return 1;
    }

    // Teritorii mafia (pickup informativ)
    for(new i = 0; i < TerritoryCount; i++)
    {
        if(TerritoryData[i][terPickupID] != pickupid) continue;
        new fid = PlayerData[playerid][pFaction];
        if(fid >= FACTION_MAFIA_EU && fid <= FACTION_MAFIA_AM)
            SendMsg(playerid, COLOR_ORANGE,
                "[Teritoriu] Foloseste /capturezone pentru a cuceri aceasta zona!");
        else
            SendMsgFmt(playerid, COLOR_GREY,
                "[Teritoriu] %s | Proprietar: %s | Venit: $%d",
                TerritoryData[i][terName],
                TerritoryData[i][terOwnerFaction] == 0 ?
                    "Neutru" : Faction_GetName(TerritoryData[i][terOwnerFaction]),
                TerritoryData[i][terIncome]);
        return 1;
    }

    // Pesti (pescuit ilegal prin pickup)
    for(new i = 0; i < FishCount; i++)
    {
        if(FishData[i][fhPickupID] != pickupid || !FishData[i][fhAlive]) continue;
        FishData[i][fhAlive]    = false;
        FishData[i][fhPickupID] = 0;
        PlayerFishBag[playerid]++;
        Player_AddXP(playerid, 10);
        SendMsgFmt(playerid, COLOR_SUCCESS,
            "[Pescuit] Ai prins un peste! Total: %d | /sellfish", PlayerFishBag[playerid]);
        return 1;
    }

    return 1;
}

// ============================================================
//  CHECKPOINT CENTRAL
// ============================================================

// Apelat din OnPlayerEnterCheckpoint in main
// Jobs_OnCheckpoint este definit in jobs.inc

// ============================================================
//  TEXT CENTRAL (chat)
// ============================================================

stock Player_OnText(playerid, const text[])
{
    if(!PlayerData[playerid][pLogged]) return 0;

    // Verificare mute
    if(Admin_IsMuted(playerid))
    {
        SendMsg(playerid, COLOR_ERROR, "[!] Esti mutuit! Nu poti scrie in chat.");
        return 0;
    }

    new name[24];
    GetPlayerName(playerid, name, 24);

    // Chat colorat dupa factiune
    new color = COLOR_WHITE;
    if(PlayerData[playerid][pFaction] > 0)
        color = Faction_GetColor(PlayerData[playerid][pFaction]);

    new msg[200];
    new prefix[48] = "";

    // Prefix presedinte
    if(PlayerData[playerid][pIsPresident])
        format(prefix, sizeof(prefix), "{FFD700}[PRESEDINTE]{FFFFFF} ");

    // Prefix admin
    if(PlayerData[playerid][pAdminLevel] >= 4)
        format(prefix, sizeof(prefix), "{FF8C00}[ADMIN]{FFFFFF} ");

    format(msg, sizeof(msg), "%s{FFFFFF}(%d) %s: %s",
        prefix,
        PlayerData[playerid][pLevel],
        name,
        text);
    SendClientMessageToAll(color, msg);
    return 0;
}

// ============================================================
//  BUSINESS BUY DIALOG
// ============================================================
// (handler inline in Dialog_OnResponse - DIALOG_BUSINESS_BUY)
// Adaugam si cazul Business_Buy apelat:

// In Dialog_OnResponse de mai sus, case DIALOG_BUSINESS_BUY:
// apeleaza direct /buybusiness

// ============================================================
//  AREA ENTER CENTRAL
// ============================================================

// Apelat din OnPlayerEnterDynamicArea in main.pwn:
// Mafia_OnEnterArea + HuntingFishing_OnEnterArea

// ============================================================
//  SAVE AUTOMAT LA 5 MINUTE
// ============================================================

new AutosaveTimer;

forward Autosave_Execute();
public Autosave_Execute()
{
    new saved = 0;
    for(new i = 0; i < MAX_PLAYERS; i++)
    {
        if(!IsPlayerConnected(i) || !PlayerData[i][pLogged]) continue;
        Player_SaveData(i);
        saved++;
    }
    if(saved > 0)
    {
        new msg[48];
        format(msg, sizeof(msg), "[Server] Autosave: %d jucatori salvati.", saved);
        print(msg);
    }
}

// Apelat din Events_Init dupa initializare
stock Events_StartAutosave()
{
    AutosaveTimer = SetTimer("Autosave_Execute", 300000, true); // 5 minute
    print("[Events] Autosave pornit (5 minute).");
}
