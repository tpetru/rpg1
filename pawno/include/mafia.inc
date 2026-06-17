// ============================================================
//  MAFIA.INC - 4 Mafii, Teritorii, Seif, Cont Bancar
//  EU / Africana / Asiatica / Americana
// ============================================================
#if defined _mafia_included
    #endinput
#endif
#define _mafia_included

// ============================================================
//  DATE MAFIA - FINANTE
// ============================================================

enum E_MAFIA_FINANCE
{
    mfFactionID,
    mfBank,
    Float:mfGold,
    Float:mfDrugs,
    mfMaterials
}

new MafiaFinance[4][E_MAFIA_FINANCE];

// Index in array dupa faction id
stock Mafia_GetIdx(factionid)
{
    switch(factionid)
    {
        case FACTION_MAFIA_EU: return 0;
        case FACTION_MAFIA_AF: return 1;
        case FACTION_MAFIA_AS: return 2;
        case FACTION_MAFIA_AM: return 3;
    }
    return -1;
}

new MafiaFactionIDs[4] = {
    FACTION_MAFIA_EU,
    FACTION_MAFIA_AF,
    FACTION_MAFIA_AS,
    FACTION_MAFIA_AM
};

// ============================================================
//  DATE TERITORII
// ============================================================

enum E_TERRITORY
{
    terID,
    terName[32],
    terOwnerFaction,
    terIncome,
    Float:terX, Float:terY, Float:terZ,
    Float:terRadius,
    terAreaID,
    terPickupID,
    terLabelID
}

new TerritoryData[MAX_TERRITORIES][E_TERRITORY];
new TerritoryCount = 0;

// Teritorii predefinite (se pot adauga si din DB)
// Inserate la prima rulare daca DB e gol
new Float:DefaultTerritories[][7] = {
    // x,        y,        z,      radius, income,  (owner=0)
    { 2496.0, -1692.0,  13.0,  120.0, 8000.0, 0.0, 0.0},
    { 2350.0, -1200.0,  30.0,  100.0, 6000.0, 0.0, 0.0},
    { 2000.0,  -900.0,  20.0,   90.0, 5000.0, 0.0, 0.0},
    { 1500.0,  -600.0,  25.0,  110.0, 7000.0, 0.0, 0.0},
    {  700.0,  -500.0,  16.0,  100.0, 6500.0, 0.0, 0.0},
    {  300.0,  -200.0,  10.0,   80.0, 5500.0, 0.0, 0.0},
    { -200.0,   100.0,   5.0,   90.0, 6000.0, 0.0, 0.0},
    { -800.0,   200.0,  10.0,  100.0, 7500.0, 0.0, 0.0},
    {-1200.0,  -100.0,  14.0,  110.0, 8000.0, 0.0, 0.0},
    {-1600.0,  -400.0,  12.0,   95.0, 5000.0, 0.0, 0.0}
};

new DefaultTerritoryNames[][24] = {
    "Portul de Sud",
    "Zona Industriala",
    "Cartierul Vechi",
    "Piata Centrala",
    "Dealul Vantului",
    "Zona Comerciala",
    "Cartierul Nordic",
    "Uzina Abandonata",
    "Docurile Vestice",
    "Zona Rurala"
};

// ============================================================
//  INIT
// ============================================================

stock Mafia_Init()
{
    // Initializeaza finantele
    for(new i = 0; i < 4; i++)
    {
        MafiaFinance[i][mfFactionID] = MafiaFactionIDs[i];
        MafiaFinance[i][mfBank]      = 0;
        MafiaFinance[i][mfGold]      = 0.0;
        MafiaFinance[i][mfDrugs]     = 0.0;
        MafiaFinance[i][mfMaterials] = 0;
    }

    mysql_tquery(g_SQL,
        "SELECT * FROM `mafia_finance`",
        "OnMafiaFinanceLoad", "", 0);

    mysql_tquery(g_SQL,
        "SELECT COUNT(*) AS cnt FROM `territories`",
        "OnTerritoryCountCheck", "", 0);

    print("[Mafia] Sistem mafia incarcat.");
}

forward OnMafiaFinanceLoad();
public OnMafiaFinanceLoad()
{
    new rows = cache_num_rows();
    for(new r = 0; r < rows; r++)
    {
        new fid;
        cache_get_value_name_int(r, "faction_id", fid);
        new idx = Mafia_GetIdx(fid);
        if(idx == -1) continue;
        cache_get_value_name_int(r,   "bank",       MafiaFinance[idx][mfBank]);
        cache_get_value_name_float(r, "gold",       MafiaFinance[idx][mfGold]);
        cache_get_value_name_float(r, "drugs",      MafiaFinance[idx][mfDrugs]);
        cache_get_value_name_int(r,   "materials",  MafiaFinance[idx][mfMaterials]);
    }
    // Insereaza randuri lipsa
    for(new i = 0; i < 4; i++)
    {
        new query[128];
        mysql_format(g_SQL, query, sizeof(query),
            "INSERT IGNORE INTO `mafia_finance` (faction_id) VALUES (%d)",
            MafiaFactionIDs[i]);
        mysql_tquery(g_SQL, query, "", "", 0);
    }
}

forward OnTerritoryCountCheck();
public OnTerritoryCountCheck()
{
    new cnt;
    cache_get_value_name_int(0, "cnt", cnt);
    if(cnt == 0)
    {
        // Insereaza teritorii default
        for(new i = 0; i < sizeof(DefaultTerritories); i++)
        {
            new query[256];
            mysql_format(g_SQL, query, sizeof(query),
                "INSERT INTO `territories` (name, owner_faction, income, pos_x, pos_y, pos_z, radius) "
                "VALUES ('%e', 0, %d, %.2f, %.2f, %.2f, %.2f)",
                DefaultTerritoryNames[i],
                floatround(DefaultTerritories[i][4]),
                DefaultTerritories[i][0],
                DefaultTerritories[i][1],
                DefaultTerritories[i][2],
                DefaultTerritories[i][3]);
            mysql_tquery(g_SQL, query, "", "", 0);
        }
        print("[Mafia] Teritorii default inserate.");
    }
    mysql_tquery(g_SQL, "SELECT * FROM `territories`", "OnTerritoriesLoad", "", 0);
}

forward OnTerritoriesLoad();
public OnTerritoriesLoad()
{
    TerritoryCount = cache_num_rows();
    if(TerritoryCount > MAX_TERRITORIES) TerritoryCount = MAX_TERRITORIES;

    for(new i = 0; i < TerritoryCount; i++)
    {
        cache_get_value_name_int(i,   "id",             TerritoryData[i][terID]);
        cache_get_value_name(i,       "name",           TerritoryData[i][terName], 32);
        cache_get_value_name_int(i,   "owner_faction",  TerritoryData[i][terOwnerFaction]);
        cache_get_value_name_int(i,   "income",         TerritoryData[i][terIncome]);
        cache_get_value_name_float(i, "pos_x",          TerritoryData[i][terX]);
        cache_get_value_name_float(i, "pos_y",          TerritoryData[i][terY]);
        cache_get_value_name_float(i, "pos_z",          TerritoryData[i][terZ]);
        cache_get_value_name_float(i, "radius",         TerritoryData[i][terRadius]);

        // Zona dinamica streamer
        TerritoryData[i][terAreaID] = CreateDynamicCircle(
            TerritoryData[i][terX], TerritoryData[i][terY],
            TerritoryData[i][terRadius], -1, -1);

        // Pickup si label
        new color = (TerritoryData[i][terOwnerFaction] > 0)
            ? Faction_GetColor(TerritoryData[i][terOwnerFaction])
            : 0xAAAAAA00;

        new labeltext[96];
        Mafia_BuildLabel(i, labeltext);
        TerritoryData[i][terPickupID] = CreatePickup(1318, 1,
            TerritoryData[i][terX], TerritoryData[i][terY], TerritoryData[i][terZ], -1);
        TerritoryData[i][terLabelID] = _:Create3DTextLabel(
            labeltext, color,
            TerritoryData[i][terX], TerritoryData[i][terY], TerritoryData[i][terZ] + 1.5,
            25.0, 0, 0);
    }
    new msg[64];
    format(msg, sizeof(msg), "[Mafia] %d teritorii incarcate.", TerritoryCount);
    print(msg);
}

stock Mafia_BuildLabel(tid, output[])
{
    new owner = TerritoryData[tid][terOwnerFaction];
    if(owner == 0)
        format(output, 96, "{FFFFFF}%s\n{AAAAAA}Neutru | Venit: $%d\n{FFFF00}/capturezone",
            TerritoryData[tid][terName], TerritoryData[tid][terIncome]);
    else
        format(output, 96, "{FFFFFF}%s\n{00FF00}%s\n{FFFFFF}Venit: $%d/noapte",
            TerritoryData[tid][terName],
            Faction_GetName(owner),
            TerritoryData[tid][terIncome]);
}

// ============================================================
//  ZONA ENTER
// ============================================================

stock Mafia_OnEnterArea(playerid, areaid)
{
    for(new i = 0; i < TerritoryCount; i++)
    {
        if(TerritoryData[i][terAreaID] != areaid) continue;
        new owner = TerritoryData[i][terOwnerFaction];
        if(owner == 0)
            SendMsgFmt(playerid, COLOR_YELLOW,
                "[Teritoriu] Zona neutra: {FFD700}%s{FFFFFF} | Venit: $%d | /capturezone",
                TerritoryData[i][terName], TerritoryData[i][terIncome]);
        else
            SendMsgFmt(playerid, COLOR_ORANGE,
                "[Teritoriu] {FFD700}%s{FFFFFF} apartine {%06X}%s",
                TerritoryData[i][terName],
                Faction_GetColor(owner) >> 8,
                Faction_GetName(owner));
        return;
    }
}

// ============================================================
//  CAPTURA TERITORIU
// ============================================================

stock Mafia_GetTerritoryAtPlayer(playerid)
{
    new Float:px, Float:py, Float:pz;
    GetPlayerPos(playerid, px, py, pz);
    for(new i = 0; i < TerritoryCount; i++)
    {
        if(VectorSize(px-TerritoryData[i][terX], py-TerritoryData[i][terY], 0.0)
            < TerritoryData[i][terRadius])
            return i;
    }
    return -1;
}

// ============================================================
//  PAYDAY TERITORII (apelat din payday.inc la 00:00)
// ============================================================

stock Mafia_TerritoryPayday()
{
    new incomes[4] = {0, 0, 0, 0};

    for(new t = 0; t < TerritoryCount; t++)
    {
        new idx = Mafia_GetIdx(TerritoryData[t][terOwnerFaction]);
        if(idx != -1) incomes[idx] += TerritoryData[t][terIncome];
    }

    for(new f = 0; f < 4; f++)
    {
        if(incomes[f] == 0) continue;
        MafiaFinance[f][mfBank] += incomes[f];

        new query[128];
        mysql_format(g_SQL, query, sizeof(query),
            "UPDATE `mafia_finance` SET bank=%d WHERE faction_id=%d",
            MafiaFinance[f][mfBank], MafiaFactionIDs[f]);
        mysql_tquery(g_SQL, query, "", "", 0);

        new msg[96];
        format(msg, sizeof(msg),
            "[Mafia] Teritorii: +{FFD700}$%d{FFFFFF} in contul mafiei!", incomes[f]);
        NotifyFaction(MafiaFactionIDs[f], COLOR_GOLD, msg);
    }
}

// ============================================================
//  SALVARE FINANTE
// ============================================================

stock Mafia_SaveFinance(factionid)
{
    new idx = Mafia_GetIdx(factionid);
    if(idx == -1) return;
    new query[256];
    mysql_format(g_SQL, query, sizeof(query),
        "UPDATE `mafia_finance` SET bank=%d, gold=%.2f, drugs=%.2f, materials=%d "
        "WHERE faction_id=%d",
        MafiaFinance[idx][mfBank],
        MafiaFinance[idx][mfGold],
        MafiaFinance[idx][mfDrugs],
        MafiaFinance[idx][mfMaterials],
        factionid);
    mysql_tquery(g_SQL, query, "", "", 0);
}

// ============================================================
//  COMENZI
// ============================================================

CMD:capturezone(playerid, params[])
{
    if(!PlayerData[playerid][pLogged]) return 1;
    new fid = PlayerData[playerid][pFaction];
    if(fid < FACTION_MAFIA_EU || fid > FACTION_MAFIA_AM)
        return SendMsg(playerid, COLOR_ERROR, "[!] Doar mafiotii pot captura zone!");
    if(PlayerData[playerid][pFactionRank] < RANK_MEMBER)
        return SendMsg(playerid, COLOR_ERROR, "[!] Ai nevoie de rang Membru+!");

    new tid = Mafia_GetTerritoryAtPlayer(playerid);
    if(tid == -1) return SendMsg(playerid, COLOR_ERROR, "[!] Nu esti intr-o zona de capturat!");

    if(TerritoryData[tid][terOwnerFaction] == fid)
        return SendMsg(playerid, COLOR_ERROR, "[!] Aceasta zona apartine deja mafiei tale!");

    // Numaral membrilor mafiei din zona
    new our_count = 0, enemy_count = 0;
    for(new i = 0; i < MAX_PLAYERS; i++)
    {
        if(!IsPlayerConnected(i) || !PlayerData[i][pLogged]) continue;
        new Float:px, Float:py, Float:pz;
        GetPlayerPos(i, px, py, pz);
        if(VectorSize(px-TerritoryData[tid][terX], py-TerritoryData[tid][terY], 0.0)
            >= TerritoryData[tid][terRadius]) continue;

        new pfid = PlayerData[i][pFaction];
        if(pfid == fid) our_count++;
        else if(pfid >= FACTION_MAFIA_EU && pfid <= FACTION_MAFIA_AM) enemy_count++;
    }

    if(our_count < 2)
        return SendMsgFmt(playerid, COLOR_ERROR,
            "[!] Ai nevoie de minim 2 mafio%s in zona! (ai %d)",
            fid == FACTION_MAFIA_EU ? "ti europeni" : "ti", our_count);

    if(enemy_count > our_count)
        return SendMsgFmt(playerid, COLOR_ERROR,
            "[!] Mafia adversa are mai multi oameni in zona (%d vs %d)!", enemy_count, our_count);

    // Captura reusita
    new old_owner = TerritoryData[tid][terOwnerFaction];
    TerritoryData[tid][terOwnerFaction] = fid;

    new query[128];
    mysql_format(g_SQL, query, sizeof(query),
        "UPDATE `territories` SET owner_faction=%d WHERE id=%d",
        fid, TerritoryData[tid][terID]);
    mysql_tquery(g_SQL, query, "", "", 0);

    // Refresh label
    new labeltext[96];
    Mafia_BuildLabel(tid, labeltext);
    Update3DTextLabelText(Text3D:TerritoryData[tid][terLabelID],
        Faction_GetColor(fid), labeltext);

    // Anunt server
    new msg[192];
    format(msg, sizeof(msg),
        "[TERITORIU] {%06X}%s{FFFFFF} a capturat {FFD700}%s{FFFFFF}! "
        "(fost: %s | Venit: $%d/noapte)",
        Faction_GetColor(fid) >> 8,
        Faction_GetName(fid),
        TerritoryData[tid][terName],
        old_owner == 0 ? "neutru" : Faction_GetName(old_owner),
        TerritoryData[tid][terIncome]);
    SendMsgAll(COLOR_ORANGE, msg);

    // Bonus XP
    for(new i = 0; i < MAX_PLAYERS; i++)
    {
        if(!IsPlayerConnected(i) || PlayerData[i][pFaction] != fid) continue;
        new Float:px, Float:py, Float:pz;
        GetPlayerPos(i, px, py, pz);
        if(VectorSize(px-TerritoryData[tid][terX], py-TerritoryData[tid][terY], 0.0)
            < TerritoryData[tid][terRadius])
            Player_AddXP(i, 300);
    }
    return 1;
}

CMD:mafiabank(playerid, params[])
{
    if(!PlayerData[playerid][pLogged]) return 1;
    new fid = PlayerData[playerid][pFaction];
    if(fid < FACTION_MAFIA_EU || fid > FACTION_MAFIA_AM)
        return SendMsg(playerid, COLOR_ERROR, "[!] Nu esti intr-o mafia!");

    new idx = Mafia_GetIdx(fid);
    if(idx == -1) return 1;

    new action[8], amount;
    if(sscanf(params, "s[8]i", action, amount))
    {
        SendMsg(playerid, COLOR_ERROR, "Folosire: /mafiabank [depune/retrage] [suma]");
        SendMsgFmt(playerid, COLOR_GREY, "Sold curent: {FFD700}$%d", MafiaFinance[idx][mfBank]);
        return 1;
    }

    if(!strcmp(action, "depune", true))
    {
        if(amount <= 0 || GetPlayerMoney(playerid) < amount)
            return SendMsg(playerid, COLOR_ERROR, "[!] Suma invalida sau insuficienta!");
        GivePlayerMoney(playerid, -amount);
        PlayerData[playerid][pMoney] -= amount;
        MafiaFinance[idx][mfBank] += amount;
        Mafia_SaveFinance(fid);
        SendMsgFmt(playerid, COLOR_SUCCESS,
            "[Mafia] Ai depus {FFD700}$%d{00FF44} in banca mafiei. Sold: $%d",
            amount, MafiaFinance[idx][mfBank]);
    }
    else if(!strcmp(action, "retrage", true))
    {
        if(PlayerData[playerid][pFactionRank] < RANK_OFFICER)
            return SendMsg(playerid, COLOR_ERROR, "[!] Ai nevoie de rang Ofiter+ pentru retrageri!");
        if(amount <= 0 || MafiaFinance[idx][mfBank] < amount)
            return SendMsg(playerid, COLOR_ERROR, "[!] Suma invalida sau fond insuficient!");
        GivePlayerMoney(playerid, amount);
        PlayerData[playerid][pMoney] += amount;
        MafiaFinance[idx][mfBank] -= amount;
        Mafia_SaveFinance(fid);
        SendMsgFmt(playerid, COLOR_SUCCESS,
            "[Mafia] Ai retras {FFD700}$%d{00FF44} din banca mafiei. Sold: $%d",
            amount, MafiaFinance[idx][mfBank]);
    }
    else
        return SendMsg(playerid, COLOR_ERROR, "[!] Actiune invalida. Foloseste depune sau retrage.");
    return 1;
}

CMD:mafiaseif(playerid, params[])
{
    if(!PlayerData[playerid][pLogged]) return 1;
    new fid = PlayerData[playerid][pFaction];
    if(fid < FACTION_MAFIA_EU || fid > FACTION_MAFIA_AM)
        return SendMsg(playerid, COLOR_ERROR, "[!] Nu esti intr-o mafia!");
    new idx = Mafia_GetIdx(fid);
    new info[320];
    format(info, sizeof(info),
        "{FFD700}Seiful %s\n\n"
        "{FFFFFF}Cont bancar: {00FF00}$%d\n"
        "Aur: {FFD700}%.1f kg\n"
        "Droguri: {FF4444}%.1f kg\n"
        "Materiale: {AAAAAA}%d unitati\n\n"
        "{FFFFFF}/mafiabank depune/retrage [suma]\n"
        "/mafiadepunitem [aur/droguri/materiale] [cant]",
        Faction_GetName(fid),
        MafiaFinance[idx][mfBank],
        MafiaFinance[idx][mfGold],
        MafiaFinance[idx][mfDrugs],
        MafiaFinance[idx][mfMaterials]);
    ShowPlayerDialog(playerid, DIALOG_MAFIA_SEIF, DIALOG_STYLE_MSGBOX,
        "Seiful Mafiei", info, "Inchide", "");
    return 1;
}

CMD:mafiadepunitem(playerid, params[])
{
    if(!PlayerData[playerid][pLogged]) return 1;
    new fid = PlayerData[playerid][pFaction];
    if(fid < FACTION_MAFIA_EU || fid > FACTION_MAFIA_AM)
        return SendMsg(playerid, COLOR_ERROR, "[!] Nu esti intr-o mafia!");
    new idx = Mafia_GetIdx(fid);

    new itemstr[16]; new Float:amount;
    if(sscanf(params, "sf", itemstr, amount))
        return SendMsg(playerid, COLOR_ERROR,
            "Folosire: /mafiadepunitem [aur/droguri/materiale] [cantitate]");

    if(!strcmp(itemstr, "aur", true))
    {
        MafiaFinance[idx][mfGold] += amount;
        SendMsgFmt(playerid, COLOR_SUCCESS,
            "[Seif] Ai depus %.1f kg de aur. Total: %.1f kg", amount, MafiaFinance[idx][mfGold]);
    }
    else if(!strcmp(itemstr, "droguri", true))
    {
        MafiaFinance[idx][mfDrugs] += amount;
        SendMsgFmt(playerid, COLOR_SUCCESS,
            "[Seif] Ai depus %.1f kg de droguri. Total: %.1f kg", amount, MafiaFinance[idx][mfDrugs]);
    }
    else if(!strcmp(itemstr, "materiale", true))
    {
        MafiaFinance[idx][mfMaterials] += floatround(amount);
        SendMsgFmt(playerid, COLOR_SUCCESS,
            "[Seif] Ai depus %d materiale. Total: %d", floatround(amount), MafiaFinance[idx][mfMaterials]);
    }
    else
        return SendMsg(playerid, COLOR_ERROR, "[!] Item invalid. Foloseste: aur, droguri, materiale");

    Mafia_SaveFinance(fid);
    return 1;
}

CMD:territories(playerid, params[])
{
    if(!PlayerData[playerid][pLogged]) return 1;
    new info[1024];
    new counts[4] = {0, 0, 0, 0};

    for(new i = 0; i < TerritoryCount; i++)
    {
        new idx = Mafia_GetIdx(TerritoryData[i][terOwnerFaction]);
        if(idx != -1) counts[idx]++;
    }

    format(info, sizeof(info),
        "{FFD700}Situatia Teritoriilor (%d total)\n\n"
        "{FFFFFF}Zona libera: {AAAAAA}%d\n"
        "{%06X}Mafia Europeana: %d\n"
        "{%06X}Mafia Africana: %d\n"
        "{%06X}Mafia Asiatica: %d\n"
        "{%06X}Mafia Americana: %d",
        TerritoryCount,
        TerritoryCount - counts[0] - counts[1] - counts[2] - counts[3],
        Faction_GetColor(FACTION_MAFIA_EU) >> 8, counts[0],
        Faction_GetColor(FACTION_MAFIA_AF) >> 8, counts[1],
        Faction_GetColor(FACTION_MAFIA_AS) >> 8, counts[2],
        Faction_GetColor(FACTION_MAFIA_AM) >> 8, counts[3]);

    ShowPlayerDialog(playerid, DIALOG_MAFIA_TERRITORY, DIALOG_STYLE_MSGBOX,
        "Harti Teritorii", info, "Inchide", "");
    return 1;
}
