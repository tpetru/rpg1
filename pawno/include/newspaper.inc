// ============================================================
//  NEWSPAPER.INC - Sistem Ziar & Mica Publicitate
//  Reporterii creaza ziare, playerii le cumpara si citesc
// ============================================================
#if defined _newspaper_included
    #endinput
#endif
#define _newspaper_included

// ---- Categorii ----
#define NEWS_CAT_GENERAL    0
#define NEWS_CAT_VAND       1
#define NEWS_CAT_CUMPAR     2
#define NEWS_CAT_ANUNTURI   3
#define NEWS_CAT_STIRI      4

new NewsCatNames[][16] = {
    "General",
    "Vand",
    "Cumpar",
    "Anunturi",
    "Stiri"
};

// ---- Date ziar ----
enum E_NEWSPAPER
{
    npID,
    npReporterID,
    npReporterName[24],
    npTitle[64],
    npCategory,
    npContent[1024],
    npPrice,
    npDate[20],
    bool:npActive
}

new Newspapers[MAX_NEWSPAPERS][E_NEWSPAPER];
new NewspaperCount = 0;

// Stare creare ziar per player (multi-step dialog)
enum E_NP_CREATE
{
    npcStep,          // 0=titlu, 1=categorie, 2=continut, 3=pret
    npcTitle[64],
    npcCategory,
    npcContent[1024],
    npcPrice
}
new NPCreate[MAX_PLAYERS][E_NP_CREATE];

// Ziarul selectat de player pentru citit
new PlayerSelectedNewspaper[MAX_PLAYERS] = {-1, ...};

// ============================================================
//  LOAD DIN DB
// ============================================================

stock Newspaper_LoadAll()
{
    mysql_tquery(g_SQL,
        "SELECT * FROM `newspapers` ORDER BY `created_at` DESC LIMIT 100",
        "OnNewspapersLoaded", "", 0);
}

forward OnNewspapersLoaded();
public OnNewspapersLoaded()
{
    NewspaperCount = cache_num_rows();
    if(NewspaperCount > MAX_NEWSPAPERS) NewspaperCount = MAX_NEWSPAPERS;

    for(new i = 0; i < NewspaperCount; i++)
    {
        cache_get_value_name_int(i, "id",          Newspapers[i][npID]);
        cache_get_value_name_int(i, "reporter_id", Newspapers[i][npReporterID]);
        cache_get_value_name(i,    "title",        Newspapers[i][npTitle],        64);
        cache_get_value_name_int(i, "category",    Newspapers[i][npCategory]);
        cache_get_value_name(i,    "content",      Newspapers[i][npContent],      1024);
        cache_get_value_name_int(i, "price",       Newspapers[i][npPrice]);
        cache_get_value_name(i,    "created_at",   Newspapers[i][npDate],         20);
        Newspapers[i][npActive] = true;

        // Recuperam numele reporterului
        new query[128];
        mysql_format(g_SQL, query, sizeof(query),
            "SELECT `username` FROM `players` WHERE `id`=%d LIMIT 1",
            Newspapers[i][npReporterID]);
        mysql_tquery(g_SQL, query, "OnNPReporterName", "i", i);
    }

    new msg[64];
    format(msg, sizeof(msg), "[Newspaper] %d ziare incarcate.", NewspaperCount);
    print(msg);
}

forward OnNPReporterName(slotid);
public OnNPReporterName(slotid)
{
    if(cache_num_rows() > 0)
        cache_get_value_name(0, "username", Newspapers[slotid][npReporterName], 24);
}

// ============================================================
//  CREARE ZIAR (multi-step)
// ============================================================

stock Newspaper_StartCreate(playerid)
{
    NPCreate[playerid][npcStep] = 0;
    NPCreate[playerid][npcTitle]    = "";
    NPCreate[playerid][npcContent]  = "";
    NPCreate[playerid][npcCategory] = 0;
    NPCreate[playerid][npcPrice]    = 100;

    ShowPlayerDialog(playerid, DIALOG_NEWSPAPER_CREATE, DIALOG_STYLE_INPUT,
        "{FFD700}Creeaza Ziar - Pasul 1/4",
        "{FFFFFF}Introdu {FFD700}titlul{FFFFFF} ziarului:\n(max 60 caractere)",
        "Continua", "Anuleaza");
}

stock Newspaper_StepCategory(playerid)
{
    new info[128];
    for(new i = 0; i < sizeof(NewsCatNames); i++)
    {
        new line[24];
        format(line, sizeof(line), "%s\n", NewsCatNames[i]);
        strcat(info, line);
    }
    ShowPlayerDialog(playerid, DIALOG_NEWSPAPER_CAT, DIALOG_STYLE_LIST,
        "{FFD700}Creeaza Ziar - Pasul 2/4 - Categorie",
        info, "Selecteaza", "Inapoi");
}

stock Newspaper_StepContent(playerid)
{
    ShowPlayerDialog(playerid, DIALOG_NEWSPAPER_CREATE + 1, DIALOG_STYLE_INPUT,
        "{FFD700}Creeaza Ziar - Pasul 3/4",
        "{FFFFFF}Scrie {FFD700}continutul{FFFFFF} ziarului:\n(max 1000 caractere)",
        "Continua", "Inapoi");
}

stock Newspaper_StepPrice(playerid)
{
    ShowPlayerDialog(playerid, DIALOG_NEWSPAPER_CREATE + 2, DIALOG_STYLE_INPUT,
        "{FFD700}Creeaza Ziar - Pasul 4/4",
        "{FFFFFF}Seteaza {FFD700}pretul{FFFFFF} unui exemplar:\n(ex: 100)",
        "Publica", "Inapoi");
}

stock Newspaper_Publish(playerid)
{
    new cost = 500; // costul de publicare
    if(GetPlayerMoney(playerid) < cost)
    {
        SendMsgFmt(playerid, COLOR_ERROR, "[Ziar] Ai nevoie de $%d pentru a publica!", cost);
        return;
    }

    GivePlayerMoney(playerid, -cost);
    PlayerData[playerid][pMoney] -= cost;

    // Salveaza in DB
    new query[1300];
    mysql_format(g_SQL, query, sizeof(query),
        "INSERT INTO `newspapers` (`reporter_id`,`title`,`category`,`content`,`price`) "
        "VALUES (%d,'%e',%d,'%e',%d)",
        PlayerData[playerid][pID],
        NPCreate[playerid][npcTitle],
        NPCreate[playerid][npcCategory],
        NPCreate[playerid][npcContent],
        NPCreate[playerid][npcPrice]
    );
    mysql_tquery(g_SQL, query, "OnNewspaperPublished", "i", playerid);
}

forward OnNewspaperPublished(playerid);
public OnNewspaperPublished(playerid)
{
    // Adauga local
    if(NewspaperCount < MAX_NEWSPAPERS)
    {
        new i = NewspaperCount;
        Newspapers[i][npID]         = cache_insert_id();
        Newspapers[i][npReporterID] = PlayerData[playerid][pID];
        format(Newspapers[i][npReporterName], 24, "%s", PlayerData[playerid][pName]);
        format(Newspapers[i][npTitle],   64,   "%s", NPCreate[playerid][npcTitle]);
        format(Newspapers[i][npContent], 1024, "%s", NPCreate[playerid][npcContent]);
        Newspapers[i][npCategory] = NPCreate[playerid][npcCategory];
        Newspapers[i][npPrice]    = NPCreate[playerid][npcPrice];
        Newspapers[i][npActive]   = true;
        NewspaperCount++;
    }

    SendMsgFmt(playerid, COLOR_SUCCESS,
        "[Ziar] Ziarul '{FFD700}%s{00FF44}' a fost publicat! Cititorii il pot gasi cu /newspaper.",
        NPCreate[playerid][npcTitle]);

    // Anunta toti jucatorii
    new msg[128];
    format(msg, sizeof(msg),
        "[ZIAR NOU] %s a publicat: \"%s\" | Categorie: %s | Pret: $%d",
        PlayerData[playerid][pName],
        NPCreate[playerid][npcTitle],
        NewsCatNames[NPCreate[playerid][npcCategory]],
        NPCreate[playerid][npcPrice]);
    SendMsgAll(COLOR_YELLOW, msg);

    Player_AddXP(playerid, 200);
}

// ============================================================
//  CITIRE ZIAR
// ============================================================

stock Newspaper_ShowList(playerid, filter_cat)
{
    new info[2048];
    new count = 0;

    for(new i = 0; i < NewspaperCount; i++)
    {
        if(!Newspapers[i][npActive]) continue;
        if(filter_cat != -1 && Newspapers[i][npCategory] != filter_cat) continue;

        new line[128];
        format(line, sizeof(line),
            "{FFD700}%s{FFFFFF} - %s - Reporter: %s - $%d\n",
            Newspapers[i][npTitle],
            NewsCatNames[Newspapers[i][npCategory]],
            Newspapers[i][npReporterName],
            Newspapers[i][npPrice]);
        strcat(info, line);
        count++;
    }

    if(count == 0)
    {
        SendMsg(playerid, COLOR_GREY, "[Ziar] Nu exista ziare in aceasta categorie.");
        return;
    }

    SetPVarInt(playerid, "NPFilterCat", filter_cat);
    ShowPlayerDialog(playerid, DIALOG_NEWSPAPER_LIST, DIALOG_STYLE_LIST,
        "{FFD700}Ziare Disponibile", info, "Cumpara & Citeste", "Inchide");
}

stock Newspaper_ShowCategoryFilter(playerid)
{
    new info[] =
        "Toate categoriile\n"
        "General\n"
        "Vand\n"
        "Cumpar\n"
        "Anunturi\n"
        "Stiri";
    ShowPlayerDialog(playerid, DIALOG_NEWSPAPER_CAT + 10, DIALOG_STYLE_LIST,
        "{FFD700}Filtreaza Ziarul", info, "Selecteaza", "Inchide");
}

stock Newspaper_Buy(playerid, slot)
{
    if(slot < 0 || slot >= NewspaperCount) return;

    // Recalculeaza slot-ul in functie de filtru
    new filter_cat = GetPVarInt(playerid, "NPFilterCat");
    new real_slot = -1, count = 0;

    for(new i = 0; i < NewspaperCount; i++)
    {
        if(!Newspapers[i][npActive]) continue;
        if(filter_cat != -1 && Newspapers[i][npCategory] != filter_cat) continue;
        if(count == slot) { real_slot = i; break; }
        count++;
    }

    if(real_slot == -1) return SendMsg(playerid, COLOR_ERROR, "[Ziar] Ziar inexistent.");

    new price = Newspapers[real_slot][npPrice];
    if(GetPlayerMoney(playerid) < price)
    {
        SendMsgFmt(playerid, COLOR_ERROR, "[Ziar] Ai nevoie de $%d pentru acest ziar!", price);
        return;
    }

    GivePlayerMoney(playerid, -price);
    PlayerData[playerid][pMoney] -= price;

    // Plateste reporterul (daca e online)
    new reporter_share = price / 2;
    for(new i = 0; i < MAX_PLAYERS; i++)
    {
        if(IsPlayerConnected(i) && PlayerData[i][pID] == Newspapers[real_slot][npReporterID])
        {
            GivePlayerMoney(i, reporter_share);
            PlayerData[i][pMoney] += reporter_share;
            SendMsgFmt(i, COLOR_GOLD, "[Ziar] Cineva a cumparat ziarul tau! +$%d", reporter_share);
            break;
        }
    }

    PlayerSelectedNewspaper[playerid] = real_slot;
    Newspaper_Read(playerid, real_slot);
}

stock Newspaper_Read(playerid, slot)
{
    new title[128];
    format(title, sizeof(title), "{FFD700}%s {FFFFFF}| %s",
        Newspapers[slot][npTitle], NewsCatNames[Newspapers[slot][npCategory]]);

    new content[1100];
    format(content, sizeof(content),
        "{AAAAAA}Reporter: %s | Data: %s\n"
        "{FFD700}Pret exemplar: $%d\n\n"
        "{FFFFFF}%s",
        Newspapers[slot][npReporterName],
        Newspapers[slot][npDate],
        Newspapers[slot][npPrice],
        Newspapers[slot][npContent]);

    ShowPlayerDialog(playerid, DIALOG_NEWSPAPER_READ, DIALOG_STYLE_MSGBOX,
        title, content, "Inchide", "");
}

// ============================================================
//  HANDLER DIALOG ZIAR
// ============================================================

stock Newspaper_OnDialog(playerid, dialogid, response, listitem, inputtext[])
{
    switch(dialogid)
    {
        // --- Creare: titlu ---
        case DIALOG_NEWSPAPER_CREATE:
        {
            if(!response) return 1;
            if(strlen(inputtext) < 3 || strlen(inputtext) > 60)
            {
                SendMsg(playerid, COLOR_ERROR, "[Ziar] Titlul trebuie sa aiba 3-60 caractere!");
                Newspaper_StartCreate(playerid);
                return 1;
            }
            format(NPCreate[playerid][npcTitle], 64, "%s", inputtext);
            NPCreate[playerid][npcStep] = 1;
            Newspaper_StepCategory(playerid);
        }

        // --- Creare: categorie ---
        case DIALOG_NEWSPAPER_CAT:
        {
            if(!response)
            {
                Newspaper_StartCreate(playerid);
                return 1;
            }
            NPCreate[playerid][npcCategory] = listitem;
            NPCreate[playerid][npcStep] = 2;
            Newspaper_StepContent(playerid);
        }

        // --- Creare: continut ---
        case DIALOG_NEWSPAPER_CREATE + 1:
        {
            if(!response)
            {
                Newspaper_StepCategory(playerid);
                return 1;
            }
            if(strlen(inputtext) < 10)
            {
                SendMsg(playerid, COLOR_ERROR, "[Ziar] Continutul trebuie sa aiba minim 10 caractere!");
                Newspaper_StepContent(playerid);
                return 1;
            }
            format(NPCreate[playerid][npcContent], 1024, "%s", inputtext);
            NPCreate[playerid][npcStep] = 3;
            Newspaper_StepPrice(playerid);
        }

        // --- Creare: pret ---
        case DIALOG_NEWSPAPER_CREATE + 2:
        {
            if(!response)
            {
                Newspaper_StepContent(playerid);
                return 1;
            }
            new price = strval(inputtext);
            if(price < 50 || price > 10000)
            {
                SendMsg(playerid, COLOR_ERROR, "[Ziar] Pretul trebuie sa fie intre $50 si $10000!");
                Newspaper_StepPrice(playerid);
                return 1;
            }
            NPCreate[playerid][npcPrice] = price;
            Newspaper_Publish(playerid);
        }

        // --- Citire: filtru categorie ---
        case DIALOG_NEWSPAPER_CAT + 10:
        {
            if(!response) return 1;
            new cat = (listitem == 0) ? -1 : listitem - 1;
            Newspaper_ShowList(playerid, cat);
        }

        // --- Citire: lista ziare ---
        case DIALOG_NEWSPAPER_LIST:
        {
            if(!response) return 1;
            Newspaper_Buy(playerid, listitem);
        }
    }
    return 1;
}

// ============================================================
//  COMENZI
// ============================================================

CMD:createnewspaper(playerid, params[])
{
    if(!PlayerData[playerid][pLogged]) return 1;
    if(PlayerData[playerid][pFaction] != FACTION_REPORTERI)
        return SendMsg(playerid, COLOR_ERROR, "[!] Doar reporterii pot crea ziare!");

    Newspaper_StartCreate(playerid);
    return 1;
}

CMD:newspaper(playerid, params[])
{
    if(!PlayerData[playerid][pLogged]) return 1;
    Newspaper_ShowCategoryFilter(playerid);
    return 1;
}

CMD:mynewspapers(playerid, params[])
{
    if(!PlayerData[playerid][pLogged]) return 1;
    if(PlayerData[playerid][pFaction] != FACTION_REPORTERI)
        return SendMsg(playerid, COLOR_ERROR, "[!] Doar reporterii au aceasta comanda!");

    new info[1024], count = 0;
    for(new i = 0; i < NewspaperCount; i++)
    {
        if(Newspapers[i][npReporterID] != PlayerData[playerid][pID]) continue;
        new line[128];
        format(line, sizeof(line), "%s | %s | $%d/exemplar\n",
            Newspapers[i][npTitle], NewsCatNames[Newspapers[i][npCategory]], Newspapers[i][npPrice]);
        strcat(info, line);
        count++;
    }
    if(!count) format(info, sizeof(info), "Nu ai publicat niciun ziar inca.");
    ShowPlayerDialog(playerid, 9999, DIALOG_STYLE_MSGBOX,
        "{FFD700}Ziarele Tale", info, "Inchide", "");
    return 1;
}

CMD:deletenewspaper(playerid, params[])
{
    if(!PlayerData[playerid][pLogged]) return 1;
    if(PlayerData[playerid][pFaction] != FACTION_REPORTERI)
        return SendMsg(playerid, COLOR_ERROR, "[!] Acces interzis!");

    new npid;
    if(sscanf(params, "i", npid))
        return SendMsg(playerid, COLOR_ERROR, "Folosire: /deletenewspaper [id_ziar]");

    for(new i = 0; i < NewspaperCount; i++)
    {
        if(Newspapers[i][npID] == npid && Newspapers[i][npReporterID] == PlayerData[playerid][pID])
        {
            Newspapers[i][npActive] = false;
            new query[64];
            mysql_format(g_SQL, query, sizeof(query),
                "DELETE FROM `newspapers` WHERE `id`=%d", npid);
            mysql_tquery(g_SQL, query, "", "", 0);
            SendMsgFmt(playerid, COLOR_SUCCESS, "[Ziar] Ziarul #%d a fost sters.", npid);
            return 1;
        }
    }
    SendMsg(playerid, COLOR_ERROR, "[Ziar] Ziar negasit sau nu iti apartine!");
    return 1;
}

// Live-uri reporter
CMD:live(playerid, params[])
{
    if(!PlayerData[playerid][pLogged]) return 1;
    if(PlayerData[playerid][pFaction] != FACTION_REPORTERI)
        return SendMsg(playerid, COLOR_ERROR, "[!] Doar reporterii pot face live-uri!");
    if(!params[0]) return SendMsg(playerid, COLOR_ERROR, "Folosire: /live [mesaj]");

    new msg[256];
    format(msg, sizeof(msg),
        "[{FF0000}LIVE{FFFFFF}] {FFD700}%s{FFFFFF}: %s",
        PlayerData[playerid][pName], params);
    SendMsgAll(COLOR_WHITE, msg);
    GameTextForAll(msg, 4000, 3);
    return 1;
}
