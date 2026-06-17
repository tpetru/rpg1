// ============================================================
//  TRADE.INC - Sistem Schimb Sigur intre Jucatori
//  Nu se pot da tepe: ambele parti confirma inainte de executie
// ============================================================
#if defined _trade_included
    #endinput
#endif
#define _trade_included

// ---- Tipuri de schimb ----
#define TRADE_MONEY     0
#define TRADE_VEHICLE   1
#define TRADE_HOUSE     2
#define TRADE_BUSINESS  3
#define TRADE_PET       4

new TradeTypeNames[][12] = {
    "Bani",
    "Vehicul",
    "Casa",
    "Afacere",
    "Animal"
};

// ---- Date schimb ----
enum E_TRADE
{
    trID,
    trSenderID,
    trReceiverID,
    trType,
    trItemID,           // ID vehicul/casa/afacere/pet (0 pentru money)
    trMoneyAmount,      // suma de bani de la sender catre receiver
    trAskPrice,         // pretul cerut de sender (platit de receiver)
    bool:trSenderReady,
    bool:trReceiverReady,
    bool:trActive,
    trExpireTimer
}

new TradeData[MAX_TRADES][E_TRADE];
new TradeAutoID = 1;

// Informatii afisate pe ecran pentru confirmare
// (stocam datele temporare per player)
new PlayerTradeID[MAX_PLAYERS] = {-1, ...};

// ============================================================
//  CREARE TRADE
// ============================================================

stock Trade_Create(senderid, receiverid, tradetype, itemid, moneyamount, askprice)
{
    // Validari
    if(PlayerTradeID[senderid] != -1)
        return SendMsg(senderid, COLOR_ERROR, "[Trade] Ai deja un schimb activ! Foloseste /canceltrade.");
    if(PlayerTradeID[receiverid] != -1)
        return SendMsg(senderid, COLOR_ERROR, "[Trade] Celalalt jucator are deja un schimb activ!");

    if(GetDistanceBetweenPlayers(senderid, receiverid) > 6.0)
        return SendMsg(senderid, COLOR_ERROR, "[Trade] Trebuie sa fii mai aproape de jucator (max 6m)!");

    // Gaseste slot liber
    new slot = -1;
    for(new i = 0; i < MAX_TRADES; i++)
    {
        if(!TradeData[i][trActive]) { slot = i; break; }
    }
    if(slot == -1)
        return SendMsg(senderid, COLOR_ERROR, "[Trade] Serverul nu mai poate procesa schimburi acum!");

    // Valideaza itemul
    if(tradetype == TRADE_VEHICLE)
    {
        new owned = false;
        for(new v = 0; v < PlayerVehicleCount[senderid]; v++)
        {
            if(PlayerVehicles[senderid][v] == itemid && VehicleData[itemid][vOwnerID] == PlayerData[senderid][pID])
            { owned = true; break; }
        }
        if(!owned) return SendMsg(senderid, COLOR_ERROR, "[Trade] Nu detii vehiculul specificat!");
    }
    else if(tradetype == TRADE_HOUSE)
    {
        if(HouseData[itemid][hOwnerID] != PlayerData[senderid][pID])
            return SendMsg(senderid, COLOR_ERROR, "[Trade] Nu detii casa specificata!");
    }
    else if(tradetype == TRADE_BUSINESS)
    {
        if(BusinessData[itemid][bOwnerID] != PlayerData[senderid][pID])
            return SendMsg(senderid, COLOR_ERROR, "[Trade] Nu detii afacerea specificata!");
    }
    else if(tradetype == TRADE_MONEY)
    {
        if(GetPlayerMoney(senderid) < moneyamount)
            return SendMsg(senderid, COLOR_ERROR, "[Trade] Nu ai suficienti bani!");
    }

    // Seteaza trade
    TradeData[slot][trID]             = TradeAutoID++;
    TradeData[slot][trSenderID]       = senderid;
    TradeData[slot][trReceiverID]     = receiverid;
    TradeData[slot][trType]           = tradetype;
    TradeData[slot][trItemID]         = itemid;
    TradeData[slot][trMoneyAmount]    = moneyamount;
    TradeData[slot][trAskPrice]       = askprice;
    TradeData[slot][trSenderReady]    = false;
    TradeData[slot][trReceiverReady]  = false;
    TradeData[slot][trActive]         = true;

    PlayerTradeID[senderid]   = slot;
    PlayerTradeID[receiverid] = slot;

    // Timer expirare (2 minute)
    TradeData[slot][trExpireTimer] = SetTimerEx("OnTradeExpire", 120000, false, "i", slot);

    // Afiseaza oferta la receiver
    Trade_ShowOffer(receiverid, slot);

    // Confirma senderului
    SendMsgFmt(senderid, COLOR_YELLOW,
        "[Trade] Oferta trimisa lui {FFD700}%s{FFFFFF}! Asteapta acceptul (2 minute).",
        PlayerData[receiverid][pName]);
    return 1;
}

// ============================================================
//  AFISARE OFERTA
// ============================================================

stock Trade_ShowOffer(playerid, slot)
{
    new senderid = TradeData[slot][trSenderID];
    new info[512];

    new item_desc[128];
    switch(TradeData[slot][trType])
    {
        case TRADE_MONEY:
            format(item_desc, sizeof(item_desc), "Bani: {00FF00}$%d", TradeData[slot][trMoneyAmount]);
        case TRADE_VEHICLE:
            format(item_desc, sizeof(item_desc), "Vehicul: {00FF00}Model %d (Numar: %s)",
                VehicleData[TradeData[slot][trItemID]][vModel],
                VehicleData[TradeData[slot][trItemID]][vPlate]);
        case TRADE_HOUSE:
            format(item_desc, sizeof(item_desc), "Casa: {00FF00}%s",
                HouseData[TradeData[slot][trItemID]][hAddress]);
        case TRADE_BUSINESS:
            format(item_desc, sizeof(item_desc), "Afacere: {00FF00}%s",
                BusinessData[TradeData[slot][trItemID]][bName]);
        case TRADE_PET:
            format(item_desc, sizeof(item_desc), "Animal: {00FF00}%s",
                PetData[TradeData[slot][trItemID]][petName]);
    }

    format(info, sizeof(info),
        "{FFFFFF}Jucatorul {FFD700}%s{FFFFFF} iti ofera:\n\n"
        "%s\n\n"
        "{FFFFFF}In schimbul sumei de: {00FF00}$%d\n\n"
        "{AAAAAA}Ai 2 minute sa accepti sau refuzi.\n"
        "{FF4444}ATENTIE: Tranzactia este definitiva!",
        PlayerData[senderid][pName],
        item_desc,
        TradeData[slot][trAskPrice]);

    ShowPlayerDialog(playerid, DIALOG_TRADE_CONFIRM, DIALOG_STYLE_MSGBOX,
        "{FFD700}Oferta de Schimb", info, "Accepta", "Refuza");
}

// ============================================================
//  ACCEPTA / REFUZA
// ============================================================

stock Trade_Accept(receiverid)
{
    new slot = PlayerTradeID[receiverid];
    if(slot == -1 || !TradeData[slot][trActive])
        return SendMsg(receiverid, COLOR_ERROR, "[Trade] Nu ai niciun schimb activ!");
    if(TradeData[slot][trReceiverID] != receiverid)
        return SendMsg(receiverid, COLOR_ERROR, "[Trade] Nu esti destinatarul acestui schimb!");

    // Verifica banii receiverului
    new askprice = TradeData[slot][trAskPrice];
    if(GetPlayerMoney(receiverid) < askprice)
    {
        SendMsgFmt(receiverid, COLOR_ERROR, "[Trade] Nu ai $%d pentru a finaliza schimbul!", askprice);
        Trade_Cancel(slot, false);
        return 1;
    }

    new senderid = TradeData[slot][trSenderID];

    // Executa transferul
    switch(TradeData[slot][trType])
    {
        case TRADE_MONEY:
        {
            // Sender da bani, primeste pretul cerut
            GivePlayerMoney(senderid, -TradeData[slot][trMoneyAmount]);
            GivePlayerMoney(senderid, askprice);
            GivePlayerMoney(receiverid, TradeData[slot][trMoneyAmount]);
            GivePlayerMoney(receiverid, -askprice);
            PlayerData[senderid][pMoney] = GetPlayerMoney(senderid);
            PlayerData[receiverid][pMoney] = GetPlayerMoney(receiverid);
        }
        case TRADE_VEHICLE:
        {
            // Transfer vehicul
            new vid = TradeData[slot][trItemID];
            VehicleData[vid][vOwnerID] = PlayerData[receiverid][pID];
            // Actualizeaza listele
            // (in practica ar trebui reconstruite listele per player)
            new query[128];
            mysql_format(g_SQL, query, sizeof(query),
                "UPDATE `vehicles` SET `owner_id`=%d WHERE `id`=%d",
                PlayerData[receiverid][pID], VehicleData[vid][vID]);
            mysql_tquery(g_SQL, query, "", "", 0);

            // Muta banii
            GivePlayerMoney(receiverid, -askprice);
            GivePlayerMoney(senderid,   askprice);
            PlayerData[senderid][pMoney]   = GetPlayerMoney(senderid);
            PlayerData[receiverid][pMoney] = GetPlayerMoney(receiverid);
        }
        case TRADE_HOUSE:
        {
            new hid = TradeData[slot][trItemID];
            HouseData[hid][hOwnerID] = PlayerData[receiverid][pID];
            new query[128];
            mysql_format(g_SQL, query, sizeof(query),
                "UPDATE `houses` SET `owner_id`=%d WHERE `id`=%d",
                PlayerData[receiverid][pID], HouseData[hid][hID]);
            mysql_tquery(g_SQL, query, "", "", 0);

            // Refresh label casa
            new labeltext[64];
            format(labeltext, sizeof(labeltext), "{00FF00}Casa privata\n{FFFFFF}%s", HouseData[hid][hAddress]);
            Update3DTextLabelText(Text3D:HouseData[hid][hLabel], 0xFFFFFFFF, labeltext);

            GivePlayerMoney(receiverid, -askprice);
            GivePlayerMoney(senderid,   askprice);
            PlayerData[senderid][pMoney]   = GetPlayerMoney(senderid);
            PlayerData[receiverid][pMoney] = GetPlayerMoney(receiverid);
        }
        case TRADE_BUSINESS:
        {
            new bid = TradeData[slot][trItemID];
            BusinessData[bid][bOwnerID] = PlayerData[receiverid][pID];
            new query[128];
            mysql_format(g_SQL, query, sizeof(query),
                "UPDATE `businesses` SET `owner_id`=%d WHERE `id`=%d",
                PlayerData[receiverid][pID], BusinessData[bid][bID]);
            mysql_tquery(g_SQL, query, "", "", 0);

            GivePlayerMoney(receiverid, -askprice);
            GivePlayerMoney(senderid,   askprice);
            PlayerData[senderid][pMoney]   = GetPlayerMoney(senderid);
            PlayerData[receiverid][pMoney] = GetPlayerMoney(receiverid);
        }
        case TRADE_PET:
        {
            new pid = TradeData[slot][trItemID];
            PetData[pid][petOwnerID] = PlayerData[receiverid][pID];
            new query[128];
            mysql_format(g_SQL, query, sizeof(query),
                "UPDATE `pets` SET `owner_id`=%d WHERE `id`=%d",
                PlayerData[receiverid][pID], PetData[pid][petID]);
            mysql_tquery(g_SQL, query, "", "", 0);

            GivePlayerMoney(receiverid, -askprice);
            GivePlayerMoney(senderid,   askprice);
            PlayerData[senderid][pMoney]   = GetPlayerMoney(senderid);
            PlayerData[receiverid][pMoney] = GetPlayerMoney(receiverid);
        }
    }

    // Mesaje finale
    SendMsgFmt(senderid, COLOR_SUCCESS,
        "[Trade] {FFD700}Schimb finalizat!{00FF44} Ai primit $%d de la %s.",
        askprice, PlayerData[receiverid][pName]);
    SendMsgFmt(receiverid, COLOR_SUCCESS,
        "[Trade] {FFD700}Schimb finalizat!{00FF44} Ai platit $%d si ai primit %s.",
        askprice, TradeTypeNames[TradeData[slot][trType]]);

    // Log in consola
    new logmsg[192];
    format(logmsg, sizeof(logmsg),
        "[TRADE] %s -> %s | Tip: %s | ItemID: %d | Pret: $%d",
        PlayerData[senderid][pName], PlayerData[receiverid][pName],
        TradeTypeNames[TradeData[slot][trType]],
        TradeData[slot][trItemID], askprice);
    print(logmsg);

    Trade_Finalize(slot);
    return 1;
}

stock Trade_Cancel(slot, bool:notify)
{
    if(!TradeData[slot][trActive]) return;

    new s = TradeData[slot][trSenderID];
    new r = TradeData[slot][trReceiverID];

    if(notify)
    {
        if(IsPlayerConnected(s)) SendMsg(s, COLOR_ERROR, "[Trade] Schimbul a fost anulat.");
        if(IsPlayerConnected(r)) SendMsg(r, COLOR_ERROR, "[Trade] Schimbul a fost anulat.");
    }

    KillTimer(TradeData[slot][trExpireTimer]);
    PlayerTradeID[s] = -1;
    PlayerTradeID[r] = -1;
    TradeData[slot][trActive] = false;
}

stock Trade_Finalize(slot)
{
    KillTimer(TradeData[slot][trExpireTimer]);
    new s = TradeData[slot][trSenderID];
    new r = TradeData[slot][trReceiverID];
    PlayerTradeID[s] = -1;
    PlayerTradeID[r] = -1;
    TradeData[slot][trActive] = false;
}

// Timer expirare
forward OnTradeExpire(slot);
public OnTradeExpire(slot)
{
    if(!TradeData[slot][trActive]) return;
    new s = TradeData[slot][trSenderID];
    new r = TradeData[slot][trReceiverID];
    if(IsPlayerConnected(s)) SendMsg(s, COLOR_ERROR, "[Trade] Schimbul a expirat (2 minute).");
    if(IsPlayerConnected(r)) SendMsg(r, COLOR_ERROR, "[Trade] Schimbul a expirat (2 minute).");
    Trade_Cancel(slot, false);
}

// ============================================================
//  DIALOG HANDLER
// ============================================================

stock Trade_OnDialog(playerid, dialogid, response, listitem, inputtext[])
{
    switch(dialogid)
    {
        case DIALOG_TRADE_OFFER:
        {
            // Player selecteaza ce ofera (tipul de trade)
            if(!response) return 1;
            SetPVarInt(playerid, "TradeType", listitem);

            // Afiseaza dialog suma
            ShowPlayerDialog(playerid, DIALOG_TRADE_CONFIRM, DIALOG_STYLE_INPUT,
                "{FFD700}Trade - Suma ceruta",
                "{FFFFFF}Introdu suma {FFD700}ceruta{FFFFFF} in schimbul itemului:\n(0 = gratis)",
                "Continua", "Anuleaza");
        }
        case DIALOG_TRADE_CONFIRM:
        {
            if(!response)
            {
                // Receiver a refuzat
                new slot = PlayerTradeID[playerid];
                if(slot != -1 && TradeData[slot][trReceiverID] == playerid)
                {
                    new senderid = TradeData[slot][trSenderID];
                    SendMsgFmt(senderid, COLOR_ERROR,
                        "[Trade] %s a refuzat oferta ta.", PlayerData[playerid][pName]);
                    Trade_Cancel(slot, false);
                    SendMsg(playerid, COLOR_GREY, "[Trade] Ai refuzat schimbul.");
                }
                return 1;
            }
            // Receiver a acceptat
            Trade_Accept(playerid);
        }
    }
    return 1;
}

// ============================================================
//  COMENZI
// ============================================================

CMD:trade(playerid, params[])
{
    if(!PlayerData[playerid][pLogged]) return 1;

    new targetid;
    new typestr[12];
    new askprice;

    if(sscanf(params, "us[12]i", targetid, typestr, askprice))
    {
        SendMsg(playerid, COLOR_ERROR,
            "Folosire: /trade [jucator] [tip] [pret_cerut]");
        SendMsg(playerid, COLOR_GREY,
            "Tipuri: money, vehicle, house, business, pet");
        SendMsg(playerid, COLOR_GREY,
            "Ex: /trade 5 vehicle 50000 -> oferi vehiculul tau pentru $50000");
        return 1;
    }

    if(!IsPlayerConnected(targetid) || targetid == playerid)
        return SendMsg(playerid, COLOR_ERROR, "[Trade] Jucator invalid!");

    // Determina tipul
    new tradetype = -1;
    if(!strcmp(typestr, "money",    true)) tradetype = TRADE_MONEY;
    if(!strcmp(typestr, "vehicle",  true)) tradetype = TRADE_VEHICLE;
    if(!strcmp(typestr, "house",    true)) tradetype = TRADE_HOUSE;
    if(!strcmp(typestr, "business", true)) tradetype = TRADE_BUSINESS;
    if(!strcmp(typestr, "pet",      true)) tradetype = TRADE_PET;

    if(tradetype == -1)
    {
        SendMsg(playerid, COLOR_ERROR, "[Trade] Tip invalid! Foloseste: money, vehicle, house, business, pet");
        return 1;
    }

    if(askprice < 0) return SendMsg(playerid, COLOR_ERROR, "[Trade] Pretul nu poate fi negativ!");

    // Pentru tipuri cu item, trebuie sa specifica si ID-ul
    new itemid = 0;

    if(tradetype == TRADE_MONEY)
    {
        // Cat vrei sa dai?
        new moneyamount;
        if(sscanf(params, "us[12]ii", targetid, typestr, askprice, moneyamount))
        {
            SendMsg(playerid, COLOR_ERROR, "Folosire: /trade [jucator] money [pret_cerut] [suma_data]");
            return 1;
        }
        Trade_Create(playerid, targetid, TRADE_MONEY, 0, moneyamount, askprice);
    }
    else if(tradetype == TRADE_VEHICLE)
    {
        if(sscanf(params, "us[12]ii", targetid, typestr, askprice, itemid))
        {
            SendMsg(playerid, COLOR_ERROR, "Folosire: /trade [jucator] vehicle [pret] [slot_vehicul 0-9]");
            return 1;
        }
        if(itemid < 0 || itemid >= PlayerVehicleCount[playerid])
            return SendMsg(playerid, COLOR_ERROR, "[Trade] Slot vehicul invalid!");
        Trade_Create(playerid, targetid, TRADE_VEHICLE, PlayerVehicles[playerid][itemid], 0, askprice);
    }
    else if(tradetype == TRADE_HOUSE)
    {
        new hid = GetPlayerOwnedHouse(playerid);
        if(hid == -1) return SendMsg(playerid, COLOR_ERROR, "[Trade] Nu ai casa!");
        Trade_Create(playerid, targetid, TRADE_HOUSE, hid, 0, askprice);
    }
    else if(tradetype == TRADE_BUSINESS)
    {
        new bid = -1;
        for(new i = 0; i < BusinessCount; i++)
        {
            if(BusinessData[i][bOwnerID] == PlayerData[playerid][pID]) { bid = i; break; }
        }
        if(bid == -1) return SendMsg(playerid, COLOR_ERROR, "[Trade] Nu ai afacere!");
        Trade_Create(playerid, targetid, TRADE_BUSINESS, bid, 0, askprice);
    }
    else if(tradetype == TRADE_PET)
    {
        new pid = Pet_GetPlayerSlot(playerid, 0);
        if(pid == -1) return SendMsg(playerid, COLOR_ERROR, "[Trade] Nu ai animale de companie!");
        Trade_Create(playerid, targetid, TRADE_PET, pid, 0, askprice);
    }

    return 1;
}

CMD:accepttrade(playerid, params[])
{
    if(!PlayerData[playerid][pLogged]) return 1;
    new slot = PlayerTradeID[playerid];
    if(slot == -1 || !TradeData[slot][trActive])
        return SendMsg(playerid, COLOR_ERROR, "[Trade] Nu ai niciun schimb activ!");
    if(TradeData[slot][trReceiverID] != playerid)
        return SendMsg(playerid, COLOR_ERROR, "[Trade] Nu esti destinatarul acestui schimb!");
    Trade_Accept(playerid);
    return 1;
}

CMD:denytrade(playerid, params[])
{
    if(!PlayerData[playerid][pLogged]) return 1;
    new slot = PlayerTradeID[playerid];
    if(slot == -1) return SendMsg(playerid, COLOR_ERROR, "[Trade] Nu ai niciun schimb activ!");
    new senderid = TradeData[slot][trSenderID];
    Trade_Cancel(slot, false);
    SendMsg(playerid, COLOR_GREY, "[Trade] Ai refuzat schimbul.");
    if(IsPlayerConnected(senderid))
        SendMsgFmt(senderid, COLOR_ERROR, "[Trade] %s a refuzat oferta ta.", PlayerData[playerid][pName]);
    return 1;
}

CMD:canceltrade(playerid, params[])
{
    if(!PlayerData[playerid][pLogged]) return 1;
    new slot = PlayerTradeID[playerid];
    if(slot == -1) return SendMsg(playerid, COLOR_ERROR, "[Trade] Nu ai niciun schimb activ!");
    Trade_Cancel(slot, true);
    return 1;
}

CMD:tradestatus(playerid, params[])
{
    if(!PlayerData[playerid][pLogged]) return 1;
    new slot = PlayerTradeID[playerid];
    if(slot == -1) return SendMsg(playerid, COLOR_GREY, "[Trade] Nu ai niciun schimb activ.");

    new senderid   = TradeData[slot][trSenderID];
    new receiverid = TradeData[slot][trReceiverID];
    new info[256];
    format(info, sizeof(info),
        "{FFD700}Schimb activ:\n\n"
        "{FFFFFF}Sender: {00FF00}%s\n"
        "Receiver: {00FF00}%s\n"
        "Tip: {00FF00}%s\n"
        "Pret cerut: {00FF00}$%d",
        PlayerData[senderid][pName],
        PlayerData[receiverid][pName],
        TradeTypeNames[TradeData[slot][trType]],
        TradeData[slot][trAskPrice]);

    ShowPlayerDialog(playerid, 9999, DIALOG_STYLE_MSGBOX, "Status Trade", info, "Inchide", "");
    return 1;
}
