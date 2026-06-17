// ============================================================
//  BUSINESSES.INC - Sistem Afaceri Personale
//  Cumparare, vanzare, venit la payday, taxe
// ============================================================
#if defined _businesses_included
    #endinput
#endif
#define _businesses_included

// ============================================================
//  TIPURI AFACERI
// ============================================================

#define BIZ_MAGAZINE        1
#define BIZ_BENZINARIE      2
#define BIZ_RESTAURANT      3
#define BIZ_BAR             4
#define BIZ_CLUB            5
#define BIZ_FARMACIE        6
#define BIZ_ATELIER         7
#define BIZ_HOTEL           8
#define BIZ_CASINO          9
#define BIZ_SPALATORIE      10

new BizTypeNames[][20] = {
    "Necunoscut",
    "Magazin",
    "Benzinarie",
    "Restaurant",
    "Bar",
    "Club",
    "Farmacie",
    "Atelier Auto",
    "Hotel",
    "Casino",
    "Spalatorie Auto"
};

// Venit de baza per tip (la payday)
new BizBaseIncome[] = {
    0,
    1500,   // Magazin
    2000,   // Benzinarie
    2500,   // Restaurant
    1800,   // Bar
    3500,   // Club
    2200,   // Farmacie
    2800,   // Atelier
    4000,   // Hotel
    5000,   // Casino
    1200    // Spalatorie
};

// Taxa de proprietate per tip (scazuta la payday)
new BizBaseTax[] = {
    0,
    200,    // Magazin
    300,    // Benzinarie
    400,    // Restaurant
    250,    // Bar
    600,    // Club
    350,    // Farmacie
    450,    // Atelier
    700,    // Hotel
    900,    // Casino
    150     // Spalatorie
};

// Model pickup per tip
new BizPickupModels[] = {
    1239,   // default
    1239,   // Magazin
    1252,   // Benzinarie
    1318,   // Restaurant
    1279,   // Bar
    1254,   // Club
    1272,   // Farmacie
    1238,   // Atelier
    1273,   // Hotel
    1241,   // Casino
    1239    // Spalatorie
};

// ============================================================
//  DATE AFACERE
// ============================================================

enum E_BUSINESS_DATA
{
    bID,
    bOwnerID,
    bName[32],
    bType,
    bPrice,
    bIncome,
    bTaxes,
    bool:bForSale,
    Float:bX, Float:bY, Float:bZ,
    bPickup,
    bLabel,
    bLevel,        // nivel afacere (1-5, creste odata cu investitiile)
    bUpgradeCost,  // costul urmatorului upgrade
    bTotalEarned   // total castigat din aceasta afacere
}

new BusinessData[MAX_BUSINESSES][E_BUSINESS_DATA];
new BusinessCount = 0;

// Afaceri default inserate daca DB e gol
new Float:DefaultBusinesses[][3] = {
    // x,         y,        z
    { 2096.0, -1800.0,  13.0},  // Magazin LS
    { 1960.0, -1722.0,  13.0},  // Benzinarie LS
    { 1200.0, -1400.0,  13.0},  // Restaurant LS
    {  500.0, -1300.0,  16.0},  // Bar centru
    {  300.0, -1100.0,  10.0},  // Club centru
    { -100.0,  -900.0,   5.0},  // Farmacie
    { -600.0,  -700.0,  10.0},  // Atelier
    {-1000.0,  -500.0,  14.0},  // Hotel
    {-1400.0,  -200.0,  12.0},  // Casino
    {-1800.0,   100.0,  14.0},  // Spalatorie
    { 2300.0, -1600.0,  13.0},  // Magazin 2
    { 1700.0, -1500.0,  13.0},  // Benzinarie 2
    {  800.0, -1000.0,  16.0},  // Restaurant 2
    {  100.0,  -600.0,   5.0},  // Bar 2
    { -500.0,  -200.0,  10.0}   // Club 2
};

new DefaultBizNames[][24] = {
    "Magazin Central",
    "Benzinaria Rapida",
    "Restaurant La Mama",
    "Barul Vechi",
    "Club Nocturn",
    "Farmacia Sanitas",
    "Atelier Marius",
    "Hotel Grand",
    "Casino Royal",
    "Spalatorie Auto",
    "Magazin Nord",
    "Benzinarie Vest",
    "Pizzeria Italiana",
    "Barul de la Colt",
    "Club Underground"
};

new DefaultBizTypes[] = {
    BIZ_MAGAZINE, BIZ_BENZINARIE, BIZ_RESTAURANT, BIZ_BAR, BIZ_CLUB,
    BIZ_FARMACIE, BIZ_ATELIER, BIZ_HOTEL, BIZ_CASINO, BIZ_SPALATORIE,
    BIZ_MAGAZINE, BIZ_BENZINARIE, BIZ_RESTAURANT, BIZ_BAR, BIZ_CLUB
};

new DefaultBizPrices[] = {
    50000, 80000, 100000, 60000, 150000,
    90000, 110000, 200000, 300000, 40000,
    45000, 75000, 95000,  55000, 140000
};

// ============================================================
//  INIT & LOAD
// ============================================================

stock Businesses_Init()
{
    mysql_tquery(g_SQL,
        "SELECT COUNT(*) AS cnt FROM `businesses`",
        "OnBizCountCheck", "", 0);
}

forward OnBizCountCheck();
public OnBizCountCheck()
{
    new cnt;
    cache_get_value_name_int(0, "cnt", cnt);

    if(cnt == 0)
    {
        // Insereaza afaceri default
        for(new i = 0; i < sizeof(DefaultBusinesses); i++)
        {
            new btype = DefaultBizTypes[i];
            new query[512];
            mysql_format(g_SQL, query, sizeof(query),
                "INSERT INTO `businesses` "
                "(owner_id, name, type, price, income, taxes, for_sale, pos_x, pos_y, pos_z, biz_level, upgrade_cost) "
                "VALUES (0, '%e', %d, %d, %d, %d, 1, %.2f, %.2f, %.2f, 1, %d)",
                DefaultBizNames[i],
                btype,
                DefaultBizPrices[i],
                BizBaseIncome[btype],
                BizBaseTax[btype],
                DefaultBusinesses[i][0],
                DefaultBusinesses[i][1],
                DefaultBusinesses[i][2],
                DefaultBizPrices[i] / 2);
            mysql_tquery(g_SQL, query, "", "", 0);
        }
        print("[Businesses] Afaceri default inserate.");
    }

    mysql_tquery(g_SQL,
        "SELECT * FROM `businesses` ORDER BY id ASC",
        "OnBusinessesLoaded", "", 0);
}

forward OnBusinessesLoaded();
public OnBusinessesLoaded()
{
    BusinessCount = cache_num_rows();
    if(BusinessCount > MAX_BUSINESSES) BusinessCount = MAX_BUSINESSES;

    for(new i = 0; i < BusinessCount; i++)
    {
        cache_get_value_name_int(i,   "id",           BusinessData[i][bID]);
        cache_get_value_name_int(i,   "owner_id",     BusinessData[i][bOwnerID]);
        cache_get_value_name(i,       "name",         BusinessData[i][bName], 32);
        cache_get_value_name_int(i,   "type",         BusinessData[i][bType]);
        cache_get_value_name_int(i,   "price",        BusinessData[i][bPrice]);
        cache_get_value_name_int(i,   "income",       BusinessData[i][bIncome]);
        cache_get_value_name_int(i,   "taxes",        BusinessData[i][bTaxes]);
        cache_get_value_name_float(i, "pos_x",        BusinessData[i][bX]);
        cache_get_value_name_float(i, "pos_y",        BusinessData[i][bY]);
        cache_get_value_name_float(i, "pos_z",        BusinessData[i][bZ]);
        cache_get_value_name_int(i,   "biz_level",    BusinessData[i][bLevel]);
        cache_get_value_name_int(i,   "upgrade_cost", BusinessData[i][bUpgradeCost]);
        cache_get_value_name_int(i,   "total_earned", BusinessData[i][bTotalEarned]);

        new sale;
        cache_get_value_name_int(i, "for_sale", sale);
        BusinessData[i][bForSale] = (sale == 1);

        // Spawn pickup + label
        Business_SpawnPickupLabel(i);
    }

    new msg[64];
    format(msg, sizeof(msg), "[Businesses] %d afaceri incarcate.", BusinessCount);
    print(msg);
}

// ============================================================
//  SPAWN PICKUP & LABEL
// ============================================================

stock Business_SpawnPickupLabel(bid)
{
    // Distruge vechi daca exista
    if(BusinessData[bid][bPickup])  DestroyPickup(BusinessData[bid][bPickup]);
    if(BusinessData[bid][bLabel])   Delete3DTextLabel(Text3D:BusinessData[bid][bLabel]);

    new btype = BusinessData[bid][bType];
    new model = (btype >= 1 && btype <= 10) ? BizPickupModels[btype] : 1239;

    BusinessData[bid][bPickup] = CreatePickup(
        model, 1,
        BusinessData[bid][bX],
        BusinessData[bid][bY],
        BusinessData[bid][bZ], -1);

    new labeltext[128];
    Business_BuildLabel(bid, labeltext);

    new color = BusinessData[bid][bOwnerID] == 0 ? 0xFFD700FF : 0x00FF00FF;
    BusinessData[bid][bLabel] = _:Create3DTextLabel(
        labeltext, color,
        BusinessData[bid][bX],
        BusinessData[bid][bY],
        BusinessData[bid][bZ] + 1.0,
        12.0, 0, 0);
}

stock Business_BuildLabel(bid, output[])
{
    if(BusinessData[bid][bOwnerID] == 0)
        format(output, 128,
            "{FFD700}%s{FFFFFF} [%s]\n"
            "De vanzare: {00FF00}$%d\n"
            "Profit/payday: {00FF00}$%d\n"
            "{FFFF00}/buybusiness",
            BusinessData[bid][bName],
            BizTypeNames[BusinessData[bid][bType]],
            BusinessData[bid][bPrice],
            BusinessData[bid][bIncome]);
    else
        format(output, 128,
            "{00FF00}%s{FFFFFF} [%s]\n"
            "Nivel: {FFD700}%d/5\n"
            "Profit/payday: {00FF00}$%d",
            BusinessData[bid][bName],
            BizTypeNames[BusinessData[bid][bType]],
            BusinessData[bid][bLevel],
            BusinessData[bid][bIncome]);
}

// ============================================================
//  SAVE
// ============================================================

stock Business_Save(bid)
{
    new query[512];
    mysql_format(g_SQL, query, sizeof(query),
        "UPDATE `businesses` SET "
        "owner_id=%d, name='%e', for_sale=%d, "
        "income=%d, taxes=%d, biz_level=%d, "
        "upgrade_cost=%d, total_earned=%d "
        "WHERE id=%d",
        BusinessData[bid][bOwnerID],
        BusinessData[bid][bName],
        BusinessData[bid][bForSale] ? 1 : 0,
        BusinessData[bid][bIncome],
        BusinessData[bid][bTaxes],
        BusinessData[bid][bLevel],
        BusinessData[bid][bUpgradeCost],
        BusinessData[bid][bTotalEarned],
        BusinessData[bid][bID]);
    mysql_tquery(g_SQL, query, "", "", 0);
}

// ============================================================
//  CUMPARARE
// ============================================================

stock Business_Buy(playerid, bid)
{
    if(bid < 0 || bid >= BusinessCount)
        return SendMsg(playerid, COLOR_ERROR, "[!] Afacere invalida!");
    if(!BusinessData[bid][bForSale])
        return SendMsg(playerid, COLOR_ERROR, "[!] Afacerea nu este de vanzare!");
    if(GetPlayerMoney(playerid) < BusinessData[bid][bPrice])
        return SendMsgFmt(playerid, COLOR_ERROR,
            "[!] Ai nevoie de {FFD700}$%d{FF4444}!", BusinessData[bid][bPrice]);

    // Verifica daca are deja afacere de acelasi tip
    for(new i = 0; i < BusinessCount; i++)
    {
        if(BusinessData[i][bOwnerID] == PlayerData[playerid][pID] &&
           BusinessData[i][bType]    == BusinessData[bid][bType])
        {
            return SendMsgFmt(playerid, COLOR_ERROR,
                "[!] Ai deja o afacere de tip %s!", BizTypeNames[BusinessData[bid][bType]]);
        }
    }

    GivePlayerMoney(playerid, -BusinessData[bid][bPrice]);
    PlayerData[playerid][pMoney] -= BusinessData[bid][bPrice];

    BusinessData[bid][bOwnerID] = PlayerData[playerid][pID];
    BusinessData[bid][bForSale] = false;
    BusinessData[bid][bLevel]   = 1;
    BusinessData[bid][bUpgradeCost] = BusinessData[bid][bPrice] / 2;

    Business_Save(bid);

    // Refresh pickup + label
    Business_SpawnPickupLabel(bid);

    Player_AddXP(playerid, 500);
    SendMsgFmt(playerid, COLOR_SUCCESS,
        "[Afacere] Ai cumparat {FFD700}%s{00FF44} pentru {FFD700}$%d{00FF44}! "
        "Profit/payday: {FFD700}$%d{00FF44}.",
        BusinessData[bid][bName],
        BusinessData[bid][bPrice],
        BusinessData[bid][bIncome]);
    return 1;
}

// ============================================================
//  VANZARE
// ============================================================

stock Business_Sell(playerid, bid)
{
    if(bid < 0 || bid >= BusinessCount)
        return SendMsg(playerid, COLOR_ERROR, "[!] Afacere invalida!");
    if(BusinessData[bid][bOwnerID] != PlayerData[playerid][pID])
        return SendMsg(playerid, COLOR_ERROR, "[!] Nu detii aceasta afacere!");

    new refund = (BusinessData[bid][bPrice] * 60) / 100; // 60% rambursare

    GivePlayerMoney(playerid, refund);
    PlayerData[playerid][pMoney] += refund;

    BusinessData[bid][bOwnerID]    = 0;
    BusinessData[bid][bForSale]    = true;
    BusinessData[bid][bLevel]      = 1;
    BusinessData[bid][bTotalEarned]= 0;
    BusinessData[bid][bIncome]     = BizBaseIncome[BusinessData[bid][bType]];
    BusinessData[bid][bUpgradeCost]= BusinessData[bid][bPrice] / 2;

    Business_Save(bid);
    Business_SpawnPickupLabel(bid);

    SendMsgFmt(playerid, COLOR_SUCCESS,
        "[Afacere] Ai vandut {FFD700}%s{00FF44} si ai primit {FFD700}$%d{00FF44} (60%% din valoare).",
        BusinessData[bid][bName], refund);
    return 1;
}

// ============================================================
//  UPGRADE AFACERE
// ============================================================

stock Business_Upgrade(playerid, bid)
{
    if(bid < 0 || bid >= BusinessCount)
        return SendMsg(playerid, COLOR_ERROR, "[!] Afacere invalida!");
    if(BusinessData[bid][bOwnerID] != PlayerData[playerid][pID])
        return SendMsg(playerid, COLOR_ERROR, "[!] Nu detii aceasta afacere!");
    if(BusinessData[bid][bLevel] >= 5)
        return SendMsg(playerid, COLOR_ERROR, "[!] Afacerea este deja la nivelul maxim (5)!");

    new cost = BusinessData[bid][bUpgradeCost];
    if(GetPlayerMoney(playerid) < cost)
        return SendMsgFmt(playerid, COLOR_ERROR,
            "[!] Upgrade costa {FFD700}$%d{FF4444}!", cost);

    GivePlayerMoney(playerid, -cost);
    PlayerData[playerid][pMoney] -= cost;

    BusinessData[bid][bLevel]++;

    // Creste profitul cu 30% per nivel
    BusinessData[bid][bIncome] = (BizBaseIncome[BusinessData[bid][bType]] *
        (100 + (BusinessData[bid][bLevel] - 1) * 30)) / 100;

    // Creste taxa cu 15% per nivel
    BusinessData[bid][bTaxes] = (BizBaseTax[BusinessData[bid][bType]] *
        (100 + (BusinessData[bid][bLevel] - 1) * 15)) / 100;

    // Costul urmatorului upgrade
    BusinessData[bid][bUpgradeCost] = cost * 2;

    Business_Save(bid);
    Business_SpawnPickupLabel(bid);

    SendMsgFmt(playerid, COLOR_SUCCESS,
        "[Afacere] {FFD700}%s{00FF44} upgradata la nivelul {FFD700}%d{00FF44}! "
        "Noul profit: {FFD700}$%d/payday{00FF44}.",
        BusinessData[bid][bName],
        BusinessData[bid][bLevel],
        BusinessData[bid][bIncome]);
    Player_AddXP(playerid, 200);
    return 1;
}

// ============================================================
//  REDENUMIRE
// ============================================================

stock Business_Rename(playerid, bid, const newname[])
{
    if(BusinessData[bid][bOwnerID] != PlayerData[playerid][pID])
        return SendMsg(playerid, COLOR_ERROR, "[!] Nu detii aceasta afacere!");
    if(strlen(newname) < 3 || strlen(newname) > 31)
        return SendMsg(playerid, COLOR_ERROR, "[!] Numele trebuie sa aiba 3-31 caractere!");

    new cost = 5000;
    if(GetPlayerMoney(playerid) < cost)
        return SendMsgFmt(playerid, COLOR_ERROR,
            "[!] Redenumirea costa {FFD700}$%d{FF4444}!", cost);

    GivePlayerMoney(playerid, -cost);
    PlayerData[playerid][pMoney] -= cost;

    format(BusinessData[bid][bName], 32, "%s", newname);
    Business_Save(bid);
    Business_SpawnPickupLabel(bid);

    SendMsgFmt(playerid, COLOR_SUCCESS,
        "[Afacere] Afacerea a fost redenumita in {FFD700}%s{00FF44}! Cost: $%d",
        newname, cost);
    return 1;
}

// ============================================================
//  HELPER - gasire afacere
// ============================================================

stock GetPlayerOwnedBusiness(playerid)
{
    for(new i = 0; i < BusinessCount; i++)
    {
        if(BusinessData[i][bOwnerID] == PlayerData[playerid][pID])
            return i;
    }
    return -1;
}

stock GetAllPlayerBusinesses(playerid, out_ids[], &count)
{
    count = 0;
    for(new i = 0; i < BusinessCount; i++)
    {
        if(BusinessData[i][bOwnerID] == PlayerData[playerid][pID])
        {
            out_ids[count++] = i;
            if(count >= 10) break; // max 10 afaceri
        }
    }
}

stock GetNearestBusiness(playerid)
{
    new Float:px, Float:py, Float:pz;
    GetPlayerPos(playerid, px, py, pz);
    new nearest = -1;
    new Float:minD = 5.0;
    for(new i = 0; i < BusinessCount; i++)
    {
        new Float:d = VectorSize(
            px - BusinessData[i][bX],
            py - BusinessData[i][bY],
            pz - BusinessData[i][bZ]);
        if(d < minD) { minD = d; nearest = i; }
    }
    return nearest;
}

// ============================================================
//  MENIU AFACERE (proprietar)
// ============================================================

stock Business_ShowMenu(playerid, bid)
{
    new info[512];
    format(info, sizeof(info),
        "Detalii afacere\n"
        "Upgradeaza ($%d)\n"
        "Redenumeste ($5000)\n"
        "Pune la vanzare\n"
        "Vinde afacerea (60%%)",
        BusinessData[bid][bUpgradeCost]);
    SetPVarInt(playerid, "MenuBizID", bid);
    ShowPlayerDialog(playerid, DIALOG_BUSINESS_MENU, DIALOG_STYLE_LIST,
        "{FFD700}Afacerea Ta", info, "Selecteaza", "Inchide");
}

stock Business_ShowDetails(playerid, bid)
{
    new info[384];
    format(info, sizeof(info),
        "{FFD700}%s{FFFFFF} [%s]\n\n"
        "Nivel: {FFD700}%d/5\n"
        "{FFFFFF}Profit/payday: {00FF00}$%d\n"
        "Taxa/payday: {FF4444}$%d\n"
        "Net/payday: {00FF00}$%d\n"
        "Total castigat: {00FF00}$%d\n"
        "Cost upgrade la Niv.%d: {FFD700}$%d\n"
        "Pret vanzare (60%%): {FFD700}$%d",
        BusinessData[bid][bName],
        BizTypeNames[BusinessData[bid][bType]],
        BusinessData[bid][bLevel],
        BusinessData[bid][bIncome],
        BusinessData[bid][bTaxes],
        BusinessData[bid][bIncome] - BusinessData[bid][bTaxes],
        BusinessData[bid][bTotalEarned],
        BusinessData[bid][bLevel] + 1,
        BusinessData[bid][bUpgradeCost],
        (BusinessData[bid][bPrice] * 60) / 100);
    ShowPlayerDialog(playerid, 9993, DIALOG_STYLE_MSGBOX,
        "Detalii Afacere", info, "Inapoi", "");
}

// ============================================================
//  PAYDAY - venit afaceri (apelat din payday.inc)
// ============================================================

stock Businesses_PaydayEarning(playerid)
{
    new total = 0;
    for(new i = 0; i < BusinessCount; i++)
    {
        if(BusinessData[i][bOwnerID] != PlayerData[playerid][pID]) continue;
        new net = BusinessData[i][bIncome] - BusinessData[i][bTaxes];
        if(net < 0) net = 0;
        total += net;
        BusinessData[i][bTotalEarned] += net;

        // Salveaza total earned periodic
        new query[128];
        mysql_format(g_SQL, query, sizeof(query),
            "UPDATE `businesses` SET total_earned=%d WHERE id=%d",
            BusinessData[i][bTotalEarned], BusinessData[i][bID]);
        mysql_tquery(g_SQL, query, "", "", 0);
    }
    return total;
}

// ============================================================
//  DIALOG HANDLER
// ============================================================

stock Business_OnDialog(playerid, dialogid, response, listitem, inputtext[])
{
    switch(dialogid)
    {
        case DIALOG_BUSINESS_BUY:
        {
            if(!response) return 1;
            new bid = GetPVarInt(playerid, "BuyBizID");
            Business_Buy(playerid, bid);
        }
        case DIALOG_BUSINESS_MENU:
        {
            if(!response) return 1;
            new bid = GetPVarInt(playerid, "MenuBizID");
            if(bid < 0 || bid >= BusinessCount) return 1;

            switch(listitem)
            {
                case 0: Business_ShowDetails(playerid, bid);
                case 1: // Upgrade
                {
                    if(BusinessData[bid][bLevel] >= 5)
                        return SendMsg(playerid, COLOR_ERROR,
                            "[!] Nivelul maxim atins!");
                    new info[128];
                    format(info, sizeof(info),
                        "Upgradezi {FFD700}%s{FFFFFF} la nivelul {FFD700}%d{FFFFFF}?\n\n"
                        "Cost: {FF4444}$%d\n"
                        "{FFFFFF}Noul profit: {00FF00}$%d/payday",
                        BusinessData[bid][bName],
                        BusinessData[bid][bLevel] + 1,
                        BusinessData[bid][bUpgradeCost],
                        (BizBaseIncome[BusinessData[bid][bType]] *
                            (100 + BusinessData[bid][bLevel] * 30)) / 100);
                    SetPVarInt(playerid, "UpgradeBizID", bid);
                    ShowPlayerDialog(playerid, DIALOG_BUSINESS_MENU + 1,
                        DIALOG_STYLE_MSGBOX, "Upgrade Afacere",
                        info, "Upgradeaza", "Anuleaza");
                }
                case 2: // Redenumeste
                {
                    SetPVarInt(playerid, "RenameBizID", bid);
                    ShowPlayerDialog(playerid, DIALOG_BUSINESS_MENU + 2,
                        DIALOG_STYLE_INPUT,
                        "Redenumeste Afacerea",
                        "Introdu noul nume al afacerii (3-31 caractere):\nCost: $5000",
                        "Confirma", "Anuleaza");
                }
                case 3: // Pune la vanzare
                {
                    if(BusinessData[bid][bForSale])
                    {
                        BusinessData[bid][bForSale] = false;
                        Business_Save(bid);
                        Business_SpawnPickupLabel(bid);
                        SendMsg(playerid, COLOR_SUCCESS,
                            "[Afacere] Afacerea nu mai este la vanzare.");
                    }
                    else
                    {
                        BusinessData[bid][bForSale] = true;
                        Business_Save(bid);
                        Business_SpawnPickupLabel(bid);
                        SendMsgFmt(playerid, COLOR_SUCCESS,
                            "[Afacere] {FFD700}%s{00FF44} pusa la vanzare la pretul de $%d.",
                            BusinessData[bid][bName], BusinessData[bid][bPrice]);
                    }
                }
                case 4: // Vinde
                {
                    new info2[128];
                    format(info2, sizeof(info2),
                        "Esti sigur ca vrei sa vinzi {FFD700}%s{FFFFFF}?\n\n"
                        "Vei primi {00FF00}$%d{FFFFFF} (60%% din $%d).",
                        BusinessData[bid][bName],
                        (BusinessData[bid][bPrice] * 60) / 100,
                        BusinessData[bid][bPrice]);
                    SetPVarInt(playerid, "SellBizID", bid);
                    ShowPlayerDialog(playerid, DIALOG_BUSINESS_MENU + 3,
                        DIALOG_STYLE_MSGBOX, "Vinde Afacerea",
                        info2, "Vinde", "Anuleaza");
                }
            }
        }
        case DIALOG_BUSINESS_MENU + 1: // Confirma upgrade
        {
            if(!response) return 1;
            new bid = GetPVarInt(playerid, "UpgradeBizID");
            Business_Upgrade(playerid, bid);
        }
        case DIALOG_BUSINESS_MENU + 2: // Confirma redenumire
        {
            if(!response) return 1;
            new bid = GetPVarInt(playerid, "RenameBizID");
            Business_Rename(playerid, bid, inputtext);
        }
        case DIALOG_BUSINESS_MENU + 3: // Confirma vanzare
        {
            if(!response) return 1;
            new bid = GetPVarInt(playerid, "SellBizID");
            Business_Sell(playerid, bid);
        }
    }
    return 1;
}

// ============================================================
//  COMENZI
// ============================================================

CMD:buybusiness(playerid, params[])
{
    if(!PlayerData[playerid][pLogged]) return 1;

    new bid = GetNearestBusiness(playerid);
    if(bid == -1)
        return SendMsg(playerid, COLOR_ERROR,
            "[!] Nu esti langa nicio afacere de vanzare! (max 5m)");
    if(!BusinessData[bid][bForSale])
        return SendMsg(playerid, COLOR_ERROR, "[!] Afacerea nu este de vanzare!");

    new info[256];
    format(info, sizeof(info),
        "Cumperi {FFD700}%s{FFFFFF} [%s]?\n\n"
        "Pret: {00FF00}$%d\n"
        "{FFFFFF}Profit/payday: {00FF00}$%d\n"
        "Taxa/payday: {FF4444}$%d\n"
        "Net/payday: {00FF00}$%d",
        BusinessData[bid][bName],
        BizTypeNames[BusinessData[bid][bType]],
        BusinessData[bid][bPrice],
        BusinessData[bid][bIncome],
        BusinessData[bid][bTaxes],
        BusinessData[bid][bIncome] - BusinessData[bid][bTaxes]);

    SetPVarInt(playerid, "BuyBizID", bid);
    ShowPlayerDialog(playerid, DIALOG_BUSINESS_BUY, DIALOG_STYLE_MSGBOX,
        "Cumpara Afacere", info, "Cumpara", "Anuleaza");
    return 1;
}

CMD:mybusiness(playerid, params[])
{
    if(!PlayerData[playerid][pLogged]) return 1;

    new bids[10], count;
    GetAllPlayerBusinesses(playerid, bids, count);

    if(!count)
        return SendMsg(playerid, COLOR_ERROR,
            "[!] Nu detii nicio afacere. Cauta pickupuri galbene pe harta!");

    if(count == 1)
    {
        Business_ShowMenu(playerid, bids[0]);
        return 1;
    }

    // Mai multe afaceri -> lista
    new info[512];
    for(new i = 0; i < count; i++)
    {
        new bid = bids[i];
        new line[80];
        format(line, sizeof(line),
            "{FFD700}%s{FFFFFF} [Niv.%d] | Net: $%d/payday\n",
            BusinessData[bid][bName],
            BusinessData[bid][bLevel],
            BusinessData[bid][bIncome] - BusinessData[bid][bTaxes]);
        strcat(info, line);
    }
    SetPVarInt(playerid, "BizListMode", 1);
    ShowPlayerDialog(playerid, DIALOG_BUSINESS_MENU + 10, DIALOG_STYLE_LIST,
        "{FFD700}Afacerile Tale", info, "Selecteaza", "Inchide");
    return 1;
}

CMD:sellbusiness(playerid, params[])
{
    if(!PlayerData[playerid][pLogged]) return 1;

    new bid = GetNearestBusiness(playerid);
    if(bid == -1 || BusinessData[bid][bOwnerID] != PlayerData[playerid][pID])
    {
        // Incearca sa gaseasca una detinuta in apropiere
        bid = GetPlayerOwnedBusiness(playerid);
        if(bid == -1)
            return SendMsg(playerid, COLOR_ERROR, "[!] Nu detii nicio afacere!");
    }

    new info[128];
    format(info, sizeof(info),
        "Vinzi {FFD700}%s{FFFFFF}?\n\nPrimesti {00FF00}$%d{FFFFFF} (60%% din $%d).",
        BusinessData[bid][bName],
        (BusinessData[bid][bPrice] * 60) / 100,
        BusinessData[bid][bPrice]);
    SetPVarInt(playerid, "SellBizID", bid);
    ShowPlayerDialog(playerid, DIALOG_BUSINESS_MENU + 3, DIALOG_STYLE_MSGBOX,
        "Vinde Afacerea", info, "Vinde", "Anuleaza");
    return 1;
}

CMD:upgradebusiness(playerid, params[])
{
    if(!PlayerData[playerid][pLogged]) return 1;

    new bid = GetNearestBusiness(playerid);
    if(bid == -1 || BusinessData[bid][bOwnerID] != PlayerData[playerid][pID])
        bid = GetPlayerOwnedBusiness(playerid);
    if(bid == -1)
        return SendMsg(playerid, COLOR_ERROR, "[!] Nu detii nicio afacere in apropiere!");

    Business_Upgrade(playerid, bid);
    return 1;
}

CMD:renamebusiness(playerid, params[])
{
    if(!PlayerData[playerid][pLogged]) return 1;
    if(!params[0])
        return SendMsg(playerid, COLOR_ERROR, "Folosire: /renamebusiness [nume nou]");

    new bid = GetNearestBusiness(playerid);
    if(bid == -1 || BusinessData[bid][bOwnerID] != PlayerData[playerid][pID])
        bid = GetPlayerOwnedBusiness(playerid);
    if(bid == -1)
        return SendMsg(playerid, COLOR_ERROR, "[!] Nu detii nicio afacere!");

    Business_Rename(playerid, bid, params);
    return 1;
}

CMD:businessinfo(playerid, params[])
{
    if(!PlayerData[playerid][pLogged]) return 1;

    new bid = GetNearestBusiness(playerid);
    if(bid == -1)
        return SendMsg(playerid, COLOR_ERROR, "[!] Nu esti langa nicio afacere!");

    new info[384];
    if(BusinessData[bid][bOwnerID] == 0)
    {
        format(info, sizeof(info),
            "{FFD700}%s{FFFFFF} [%s]\n\n"
            "Stare: {FF4444}De vanzare\n"
            "{FFFFFF}Pret: {00FF00}$%d\n"
            "Profit/payday: {00FF00}$%d\n"
            "Taxa/payday: {FF4444}$%d\n"
            "Net/payday: {00FF00}$%d\n\n"
            "{FFFF00}Foloseste /buybusiness pentru a cumpara!",
            BusinessData[bid][bName],
            BizTypeNames[BusinessData[bid][bType]],
            BusinessData[bid][bPrice],
            BusinessData[bid][bIncome],
            BusinessData[bid][bTaxes],
            BusinessData[bid][bIncome] - BusinessData[bid][bTaxes]);
    }
    else
    {
        new owner_name[24] = "Necunoscut";
        for(new i = 0; i < MAX_PLAYERS; i++)
        {
            if(IsPlayerConnected(i) && PlayerData[i][pID] == BusinessData[bid][bOwnerID])
            {
                format(owner_name, 24, "%s", PlayerData[i][pName]);
                break;
            }
        }
        format(info, sizeof(info),
            "{00FF00}%s{FFFFFF} [%s]\n\n"
            "Proprietar: {FFD700}%s\n"
            "{FFFFFF}Nivel: {FFD700}%d/5\n"
            "Profit/payday: {00FF00}$%d\n"
            "Taxa/payday: {FF4444}$%d",
            BusinessData[bid][bName],
            BizTypeNames[BusinessData[bid][bType]],
            owner_name,
            BusinessData[bid][bLevel],
            BusinessData[bid][bIncome],
            BusinessData[bid][bTaxes]);
    }
    ShowPlayerDialog(playerid, 9993, DIALOG_STYLE_MSGBOX,
        "Info Afacere", info, "Inchide", "");
    return 1;
}

CMD:businesses(playerid, params[])
{
    if(!PlayerData[playerid][pLogged]) return 1;

    new info[1024], free_count = 0, owned_count = 0;
    strcat(info, "{FFD700}Afaceri de vanzare:\n\n");

    for(new i = 0; i < BusinessCount; i++)
    {
        if(!BusinessData[i][bForSale]) { owned_count++; continue; }
        new line[80];
        format(line, sizeof(line),
            "%s [%s] - {00FF00}$%d{FFFFFF} (+$%d/payday)\n",
            BusinessData[i][bName],
            BizTypeNames[BusinessData[i][bType]],
            BusinessData[i][bPrice],
            BusinessData[i][bIncome] - BusinessData[i][bTaxes]);
        strcat(info, line);
        free_count++;
    }

    if(!free_count)
        strcat(info, "{AAAAAA}Nicio afacere disponibila momentan.\n");

    new footer[64];
    format(footer, sizeof(footer),
        "\n{FFFFFF}Total: %d ocupate | %d disponibile",
        owned_count, free_count);
    strcat(info, footer);

    ShowPlayerDialog(playerid, 9993, DIALOG_STYLE_MSGBOX,
        "{FFD700}Afaceri Disponibile", info, "Inchide", "");
    return 1;
}
