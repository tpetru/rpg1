// ============================================================
//  JOBS.INC - Sistem Joburi Complete
//  Detectiv, Bolt Food, Uber, Mecanic, Fermier,
//  Truck Driver, Pescar Legal, Padurar, Salvamar
// ============================================================
#if defined _jobs_included
    #endinput
#endif
#define _jobs_included

// ---- Joburi ----
#define JOB_NONE        0
#define JOB_DETECTIV    1
#define JOB_BOLT_FOOD   2
#define JOB_UBER        3
#define JOB_MECANIC     4
#define JOB_FERMIER     5
#define JOB_TRUCK       6
#define JOB_FISHERMAN   7
#define JOB_PADURAR     8
#define JOB_SALVAMAR    9
#define JOB_COUNT       10

new JobNames[JOB_COUNT][20] = {
    "Niciun job",
    "Detectiv",
    "Bolt Food",
    "Uber",
    "Mecanic",
    "Fermier",
    "Truck Driver",
    "Pescar Legal",
    "Padurar",
    "Salvamar"
};

new JobSalaries[JOB_COUNT] = {
    0,    // none
    800,  // detectiv
    500,  // bolt food
    600,  // uber
    700,  // mecanic
    400,  // fermier
    1200, // truck
    300,  // pescar
    500,  // padurar
    450   // salvamar
};

new JobMinLevel[JOB_COUNT] = {
    0, // none
    3, // detectiv
    1, // bolt food
    1, // uber
    2, // mecanic
    1, // fermier
    2, // truck
    1, // pescar
    2, // padurar
    2  // salvamar
};

stock Job_GetName(jobid)
{
    if(jobid < 0 || jobid >= JOB_COUNT) return "Necunoscut";
    return JobNames[jobid];
}

// ============================================================
//  STATE PER PLAYER
// ============================================================

// Uber
new bool:UberOnDuty[MAX_PLAYERS];
new UberClient[MAX_PLAYERS];       // clientul curent al uberului
new UberDriver[MAX_PLAYERS];       // soferul uber al clientului

// Bolt Food
new BoltFoodOrder[MAX_PLAYERS];    // catre ce casa livreaza
new BoltFoodActive[MAX_PLAYERS];

// Truck
new TruckDestination[MAX_PLAYERS]; // index destinatie
new TruckActive[MAX_PLAYERS];

// Pescar legal
new FishermanBag[MAX_PLAYERS];     // pesti prinsi legal

// Fermier
new FarmerTimer[MAX_PLAYERS];
new FarmerActive[MAX_PLAYERS];

// Padurar - zone de verificat copaci
new Float:TreeZones[][4] = {
    {-1400.0, 2300.0, 0.0, 300.0},
    {-800.0,  1900.0, 0.0, 200.0},
    {300.0,   1700.0, 0.0, 180.0}
};

// Salvamar - puncte de curatat plaja
new Float:BeachCleanPoints[][3] = {
    {-1700.0, -1110.0, 2.0},
    {-1830.0, -1000.0, 2.0},
    {-1960.0,  -900.0, 2.0},
    {-2050.0,  -780.0, 2.0}
};

// Locatii livrarare Bolt Food (case random)
// In practica ar fi case reale; simplificat:
new Float:BoltFoodDeliveryPoints[][3] = {
    {2233.0, -1115.0, 26.5},
    {2270.0, -1200.0, 26.5},
    {2310.0, -1100.0, 26.5},
    {2200.0, -1050.0, 26.5},
    {2350.0, -1150.0, 26.5}
};

// Locatii livrare Truck
new Float:TruckDeliveryPoints[][3] = {
    { 446.0, -1494.0, 27.0},  // Port LS
    {-1670.0, -25.0,  14.0},  // Port SF
    {-103.0,  1064.0, 20.0},  // Las Venturas nord
    { 2840.0,  -40.0, 28.0},  // Zona industriala
    { 685.0,   503.0, 16.0}   // Centru
};

// Locatii de pescuit legal (port / piata)
new Float:FishermanSellPoints[][3] = {
    {-1670.0, -25.0, 14.0},   // Port SF
    { 446.0, -1494.0, 27.0}   // Port LS
};

// ============================================================
//  SELECTIE JOB
// ============================================================

CMD:job(playerid, params[])
{
    if(!PlayerData[playerid][pLogged]) return 1;

    new info[512];
    for(new i = 1; i < JOB_COUNT; i++)
    {
        new line[64];
        format(line, sizeof(line),
            "{FFD700}%s{FFFFFF} | Salariu: $%d | Level minim: %d\n",
            JobNames[i], JobSalaries[i], JobMinLevel[i]);
        strcat(info, line);
    }
    ShowPlayerDialog(playerid, DIALOG_JOB_SELECT, DIALOG_STYLE_LIST,
        "{FFD700}Alege Job", info, "Selecteaza", "Inchide");
    return 1;
}

stock Job_Select(playerid, jobid)
{
    if(jobid < 1 || jobid >= JOB_COUNT)
        return SendMsg(playerid, COLOR_ERROR, "[Job] Job invalid!");

    if(PlayerData[playerid][pLevel] < JobMinLevel[jobid])
    {
        SendMsgFmt(playerid, COLOR_ERROR,
            "[Job] Ai nevoie de level %d pentru jobul %s!", JobMinLevel[jobid], JobNames[jobid]);
        return 1;
    }

    // Curata job vechi
    Job_ClearState(playerid);

    PlayerData[playerid][pJob]    = jobid;
    PlayerData[playerid][pOnDuty] = false;
    Player_SaveData(playerid);

    SendMsgFmt(playerid, COLOR_SUCCESS,
        "[Job] Ai ales jobul: {FFD700}%s{00FF44}! Foloseste /duty pentru a intra in serviciu.",
        JobNames[jobid]);
    SendMsgFmt(playerid, COLOR_GREY,
        "[Job] Salariu per actiune: {FFD700}$%d{FFFFFF}. Comenzi specifice: /jobinfo",
        JobSalaries[jobid]);
    return 1;
}

stock Job_ClearState(playerid)
{
    // Curata starea jobului anterior
    if(PlayerData[playerid][pJob] == JOB_UBER)
    {
        UberOnDuty[playerid] = false;
        if(UberClient[playerid] != INVALID_PLAYER_ID && IsPlayerConnected(UberClient[playerid]))
        {
            SendMsg(UberClient[playerid], COLOR_ERROR, "[Uber] Soferul tau a renuntat la job.");
            UberDriver[UberClient[playerid]] = INVALID_PLAYER_ID;
        }
        UberClient[playerid] = INVALID_PLAYER_ID;
    }
    if(FarmerTimer[playerid]) { KillTimer(FarmerTimer[playerid]); FarmerTimer[playerid] = 0; }
    FarmerActive[playerid] = 0;
    BoltFoodActive[playerid] = 0;
    TruckActive[playerid] = 0;
    DisablePlayerCheckpoint(playerid);
}

// ============================================================
//  /duty - Intra/iesi din serviciu
// ============================================================

CMD:duty(playerid, params[])
{
    if(!PlayerData[playerid][pLogged]) return 1;
    if(PlayerData[playerid][pJob] == JOB_NONE)
        return SendMsg(playerid, COLOR_ERROR, "[!] Nu ai un job! Foloseste /job.");

    PlayerData[playerid][pOnDuty] = !PlayerData[playerid][pOnDuty];
    new isOn = PlayerData[playerid][pOnDuty];

    switch(PlayerData[playerid][pJob])
    {
        case JOB_UBER:
        {
            UberOnDuty[playerid] = isOn;
            if(isOn)
            {
                // Schimba culoarea masinii in negru
                new vehicleid = GetPlayerVehicleID(playerid);
                if(vehicleid) ChangeVehicleColor(vehicleid, 0, 0);
                SendMsg(playerid, COLOR_SUCCESS, "[Uber] Esti acum ON DUTY! Vei primi cereri de curse.");
            }
            else
            {
                SendMsg(playerid, COLOR_GREY, "[Uber] Esti acum OFF DUTY.");
                // Restaureaza culoarea originala
                new vehicleid = GetPlayerVehicleID(playerid);
                if(vehicleid)
                {
                    new vid = GetVehicleDataID(vehicleid);
                    if(vid != -1) ChangeVehicleColor(vehicleid, VehicleData[vid][vColor1], VehicleData[vid][vColor2]);
                }
            }
        }
        case JOB_FERMIER:
        {
            if(isOn)
            {
                SendMsg(playerid, COLOR_SUCCESS, "[Fermier] Esti ON DUTY! Urca pe tractor si mergi pe ferma.");
                Job_Farmer_Start(playerid);
            }
            else
            {
                SendMsg(playerid, COLOR_GREY, "[Fermier] Esti OFF DUTY.");
                if(FarmerTimer[playerid]) { KillTimer(FarmerTimer[playerid]); FarmerTimer[playerid] = 0; }
                FarmerActive[playerid] = 0;
            }
        }
        case JOB_BOLT_FOOD:
        {
            if(isOn)
            {
                SendMsg(playerid, COLOR_SUCCESS, "[Bolt Food] Esti ON DUTY! Foloseste /takeorder pentru o comanda.");
            }
            else
            {
                SendMsg(playerid, COLOR_GREY, "[Bolt Food] Esti OFF DUTY.");
                BoltFoodActive[playerid] = 0;
                DisablePlayerCheckpoint(playerid);
            }
        }
        case JOB_TRUCK:
        {
            if(isOn)
            {
                SendMsg(playerid, COLOR_SUCCESS, "[Truck] Esti ON DUTY! Foloseste /takeload pentru o livrare.");
            }
            else
            {
                SendMsg(playerid, COLOR_GREY, "[Truck] Esti OFF DUTY.");
                TruckActive[playerid] = 0;
                DisablePlayerCheckpoint(playerid);
            }
        }
        case JOB_FISHERMAN:
        {
            if(isOn)
            {
                SendMsg(playerid, COLOR_SUCCESS, "[Pescar] Esti ON DUTY! Mergi la /fishspot si prinde pesti legal.");
            }
            else
            {
                SendMsg(playerid, COLOR_GREY, "[Pescar] Esti OFF DUTY.");
                DisablePlayerCheckpoint(playerid);
            }
        }
        case JOB_PADURAR:
        {
            if(isOn)
                SendMsg(playerid, COLOR_SUCCESS, "[Padurar] ON DUTY! Foloseste /checktrees si /createtour.");
            else
                SendMsg(playerid, COLOR_GREY, "[Padurar] OFF DUTY.");
        }
        case JOB_SALVAMAR:
        {
            if(isOn)
            {
                SendMsg(playerid, COLOR_SUCCESS, "[Salvamar] ON DUTY! Foloseste /cleanbeach si /createtour.");
                Job_Salvamar_StartClean(playerid);
            }
            else
            {
                SendMsg(playerid, COLOR_GREY, "[Salvamar] OFF DUTY.");
                DisablePlayerCheckpoint(playerid);
            }
        }
        default:
        {
            SendMsgFmt(playerid, COLOR_SUCCESS, "[Job] %s: %s",
                Job_GetName(PlayerData[playerid][pJob]),
                isOn ? "ON DUTY" : "OFF DUTY");
        }
    }
    return 1;
}

// ============================================================
//  JOBINFO
// ============================================================

CMD:jobinfo(playerid, params[])
{
    if(!PlayerData[playerid][pLogged]) return 1;
    new job = PlayerData[playerid][pJob];

    new info[512];
    switch(job)
    {
        case JOB_NONE:      format(info, sizeof(info), "Nu ai niciun job. Foloseste /job pentru a alege.");
        case JOB_DETECTIV:  format(info, sizeof(info), "{FFD700}Detectiv{FFFFFF}\n\n/find [jucator] - Gaseste un jucator ($500)\n/duty - Intra/iesi din serviciu\nCastig per misiune: $%d", JobSalaries[job]);
        case JOB_BOLT_FOOD: format(info, sizeof(info), "{FFD700}Bolt Food{FFFFFF}\n\n/duty - Intra in serviciu\n/takeorder - Ia o comanda\nUrmeaza checkpoint-ul!\nCastig per livrare: $%d", JobSalaries[job]);
        case JOB_UBER:      format(info, sizeof(info), "{FFD700}Uber{FFFFFF}\n\n/duty - Intra in serviciu\n/acceptuber - Accepta o cursa\nMasina ta devine neagra on-duty\nCastig per cursa: $%d", JobSalaries[job]);
        case JOB_MECANIC:   format(info, sizeof(info), "{FFD700}Mecanic{FFFFFF}\n\n/duty - Intra in serviciu\n/repair [jucator] - Repara masina\nNu iti poti repara propria masina!\nCastig per reparatie: $%d", JobSalaries[job]);
        case JOB_FERMIER:   format(info, sizeof(info), "{FFD700}Fermier{FFFFFF}\n\n/duty - Intra in serviciu\nUrca pe tractor si mergi pe ferma.\nCastig orar: $%d", JobSalaries[job]);
        case JOB_TRUCK:     format(info, sizeof(info), "{FFD700}Truck Driver{FFFFFF}\n\n/duty - Intra in serviciu\n/takeload - Ia o livrare\nUrmeaza checkpoint-ul!\nCastig per livrare: $%d", JobSalaries[job]);
        case JOB_FISHERMAN: format(info, sizeof(info), "{FFD700}Pescar Legal{FFFFFF}\n\n/duty - Intra in serviciu\n/fishspot - Mergi la locul de pescuit\n/catchfish - Prinde un peste\n/sellfish2 - Vinde la port/piata\nCastig: $%d/peste", JobSalaries[job]);
        case JOB_PADURAR:   format(info, sizeof(info), "{FFD700}Padurar{FFFFFF}\n\n/duty - Intra in serviciu\n/checktrees - Verifica copacii\n/createtour - Organizeaza tur padure/munte\nCastig per tura: $%d", JobSalaries[job]);
        case JOB_SALVAMAR:  format(info, sizeof(info), "{FFD700}Salvamar{FFFFFF}\n\n/duty - Intra in serviciu\n/cleanbeach - Curata plaja\n/createtour - Organizeaza tur plaja\nCastig per tura: $%d", JobSalaries[job]);
    }
    ShowPlayerDialog(playerid, 9999, DIALOG_STYLE_MSGBOX, "Informatii Job", info, "Inchide", "");
    return 1;
}

// ============================================================
//  DETECTIV
// ============================================================

CMD:find(playerid, params[])
{
    if(!PlayerData[playerid][pLogged]) return 1;
    if(PlayerData[playerid][pJob] != JOB_DETECTIV)
        return SendMsg(playerid, COLOR_ERROR, "[!] Doar detectivii pot folosi /find!");
    if(!PlayerData[playerid][pOnDuty])
        return SendMsg(playerid, COLOR_ERROR, "[!] Trebuie sa fii ON DUTY. Foloseste /duty.");

    new cost = 500;
    if(GetPlayerMoney(playerid) < cost)
        return SendMsgFmt(playerid, COLOR_ERROR, "[!] Ai nevoie de $%d pentru o investigatie.", cost);

    new targetid;
    if(sscanf(params, "u", targetid))
        return SendMsg(playerid, COLOR_ERROR, "Folosire: /find [jucator]");

    if(!IsPlayerConnected(targetid) || !PlayerData[targetid][pLogged])
        return SendMsg(playerid, COLOR_ERROR, "[!] Jucatorul nu este online!");

    GivePlayerMoney(playerid, -cost);
    PlayerData[playerid][pMoney] -= cost;

    new Float:tx, Float:ty, Float:tz;
    GetPlayerPos(targetid, tx, ty, tz);

    new tname[24];
    GetPlayerName(targetid, tname, 24);

    SendMsgFmt(playerid, COLOR_YELLOW,
        "[Detectiv] Locatia lui {FFD700}%s{FFFFFF}: X=%.1f | Y=%.1f | Z=%.1f | Interior: %d | VW: %d",
        tname, tx, ty, tz,
        GetPlayerInterior(targetid), GetPlayerVirtualWorld(targetid));

    SetPlayerCheckpoint(playerid, tx, ty, tz, 5.0);
    Player_AddXP(playerid, 50);
    return 1;
}

// ============================================================
//  BOLT FOOD
// ============================================================

CMD:takeorder(playerid, params[])
{
    if(!PlayerData[playerid][pLogged]) return 1;
    if(PlayerData[playerid][pJob] != JOB_BOLT_FOOD)
        return SendMsg(playerid, COLOR_ERROR, "[!] Nu esti Bolt Food!");
    if(!PlayerData[playerid][pOnDuty])
        return SendMsg(playerid, COLOR_ERROR, "[!] Trebuie sa fii ON DUTY!");
    if(BoltFoodActive[playerid])
        return SendMsg(playerid, COLOR_ERROR, "[!] Ai deja o comanda activa! Livreaza-o mai intai.");

    new dest = random(sizeof(BoltFoodDeliveryPoints));
    BoltFoodOrder[playerid] = dest;
    BoltFoodActive[playerid] = 1;

    SetPlayerCheckpoint(playerid,
        BoltFoodDeliveryPoints[dest][0],
        BoltFoodDeliveryPoints[dest][1],
        BoltFoodDeliveryPoints[dest][2], 5.0);

    SendMsg(playerid, COLOR_SUCCESS, "[Bolt Food] Comanda preluata! Urmeaza checkpoint-ul pentru livrare.");
    return 1;
}

stock Job_BoltFood_Deliver(playerid)
{
    if(!BoltFoodActive[playerid]) return;
    BoltFoodActive[playerid] = 0;
    DisablePlayerCheckpoint(playerid);

    new reward = JobSalaries[JOB_BOLT_FOOD] + random(200);
    GivePlayerMoney(playerid, reward);
    PlayerData[playerid][pMoney] += reward;
    Player_AddXP(playerid, 30);

    SendMsgFmt(playerid, COLOR_SUCCESS,
        "[Bolt Food] Livrare finalizata! Ai castigat {FFD700}$%d{00FF44}!", reward);
    GameTextForPlayer(playerid, "~g~Livrare Reusita!", 3000, 1);
}

// ============================================================
//  UBER
// ============================================================

CMD:service(playerid, params[])
{
    if(!PlayerData[playerid][pLogged]) return 1;
    new service[16];
    if(sscanf(params, "s[16]", service))
    {
        SendMsg(playerid, COLOR_ERROR, "Folosire: /service [uber/mecanic]");
        return 1;
    }

    if(!strcmp(service, "uber", true))
    {
        // Gaseste top 5 uberi disponibili cei mai apropiati
        new Float:px, Float:py, Float:pz;
        GetPlayerPos(playerid, px, py, pz);

        new found = 0;
        new pname[24];
        GetPlayerName(playerid, pname, 24);

        for(new i = 0; i < MAX_PLAYERS && found < 5; i++)
        {
            if(!IsPlayerConnected(i)) continue;
            if(PlayerData[i][pJob] != JOB_UBER || !UberOnDuty[i] || i == playerid) continue;
            if(UberClient[i] != INVALID_PLAYER_ID) continue; // deja are client

            SetPVarInt(i, "UberReqFrom", playerid);
            SendMsgFmt(i, COLOR_YELLOW,
                "[{FFD700}UBER{FFFFFF}] Cerere noua de la {FFD700}%s{FFFFFF}! "
                "Foloseste {00FF00}/acceptuber{FFFFFF} in urmatoarele 30 secunde.",
                pname);
            found++;
        }

        if(!found) return SendMsg(playerid, COLOR_ERROR, "[Uber] Niciun sofer disponibil acum! Incearca mai tarziu.");

        SetPVarInt(playerid, "UberRequested", 1);
        SendMsg(playerid, COLOR_YELLOW, "[Uber] Cerere trimisa! Asteapta confirmarea unui sofer...");
    }
    else if(!strcmp(service, "mecanic", true))
    {
        new found = 0;
        new pname[24];
        GetPlayerName(playerid, pname, 24);

        for(new i = 0; i < MAX_PLAYERS && found < 3; i++)
        {
            if(!IsPlayerConnected(i)) continue;
            if(PlayerData[i][pJob] != JOB_MECANIC || !PlayerData[i][pOnDuty] || i == playerid) continue;
            SendMsgFmt(i, COLOR_YELLOW,
                "[Mecanic] Cerere de la {FFD700}%s{FFFFFF}! Foloseste {00FF00}/repair{FFFFFF}.", pname);
            found++;
        }
        if(!found) return SendMsg(playerid, COLOR_ERROR, "[Mecanic] Niciun mecanic disponibil!");
        SendMsg(playerid, COLOR_YELLOW, "[Mecanic] Cerere trimisa! Un mecanic vine curand.");
    }
    return 1;
}

CMD:acceptuber(playerid, params[])
{
    if(!PlayerData[playerid][pLogged]) return 1;
    if(PlayerData[playerid][pJob] != JOB_UBER || !UberOnDuty[playerid])
        return SendMsg(playerid, COLOR_ERROR, "[!] Nu esti Uber on-duty!");

    new clientid = GetPVarInt(playerid, "UberReqFrom");
    if(!clientid || !IsPlayerConnected(clientid))
        return SendMsg(playerid, COLOR_ERROR, "[!] Cererea a expirat sau clientul a deconectat!");

    UberClient[playerid] = clientid;
    UberDriver[clientid] = playerid;
    DeletePVar(playerid, "UberReqFrom");
    DeletePVar(clientid, "UberRequested");

    // Checkpoint la client pentru sofer
    new Float:cx, Float:cy, Float:cz;
    GetPlayerPos(clientid, cx, cy, cz);
    SetPlayerCheckpoint(playerid, cx, cy, cz, 5.0);

    new cname[24];
    GetPlayerName(clientid, cname, 24);
    SendMsgFmt(playerid, COLOR_SUCCESS,
        "[Uber] Cursa acceptata! Client: {FFD700}%s{FFFFFF}. Checkpoint setat.", cname);
    SendMsgFmt(clientid, COLOR_SUCCESS,
        "[Uber] Soferul {FFD700}%s{FFFFFF} vine spre tine! Asteapta.", PlayerData[playerid][pName]);
    return 1;
}

CMD:finishuber(playerid, params[])
{
    if(!PlayerData[playerid][pLogged]) return 1;
    if(PlayerData[playerid][pJob] != JOB_UBER || !UberOnDuty[playerid])
        return SendMsg(playerid, COLOR_ERROR, "[!] Nu esti Uber on-duty!");
    if(UberClient[playerid] == INVALID_PLAYER_ID)
        return SendMsg(playerid, COLOR_ERROR, "[!] Nu ai o cursa activa!");

    new clientid = UberClient[playerid];
    new reward = JobSalaries[JOB_UBER] + random(300);

    // Clientul plateste
    if(GetPlayerMoney(clientid) >= reward)
    {
        GivePlayerMoney(clientid, -reward);
        PlayerData[clientid][pMoney] -= reward;
        GivePlayerMoney(playerid, reward);
        PlayerData[playerid][pMoney] += reward;
        SendMsgFmt(playerid, COLOR_SUCCESS, "[Uber] Cursa incheiata! Ai castigat {FFD700}$%d{00FF44}.", reward);
        SendMsgFmt(clientid, COLOR_GREY, "[Uber] Ai platit $%d pentru cursa. Multumim!", reward);
    }
    else
    {
        // Client fara bani - platit automat
        SendMsg(playerid, COLOR_ERROR, "[Uber] Clientul nu a avut bani suficienti!");
    }

    Player_AddXP(playerid, 40);
    DisablePlayerCheckpoint(playerid);
    UberClient[playerid] = INVALID_PLAYER_ID;
    UberDriver[clientid] = INVALID_PLAYER_ID;
    return 1;
}

// ============================================================
//  MECANIC
// ============================================================

CMD:repair(playerid, params[])
{
    if(!PlayerData[playerid][pLogged]) return 1;
    if(PlayerData[playerid][pJob] != JOB_MECANIC)
        return SendMsg(playerid, COLOR_ERROR, "[!] Esti mecanic?");
    if(!PlayerData[playerid][pOnDuty])
        return SendMsg(playerid, COLOR_ERROR, "[!] Trebuie sa fii ON DUTY!");

    new targetid;
    if(sscanf(params, "u", targetid))
        return SendMsg(playerid, COLOR_ERROR, "Folosire: /repair [jucator]");

    if(targetid == playerid)
        return SendMsg(playerid, COLOR_ERROR, "[!] Nu iti poti repara propria masina!");
    if(!IsPlayerConnected(targetid))
        return SendMsg(playerid, COLOR_ERROR, "[!] Jucator invalid!");

    new vehicleid = GetPlayerVehicleID(targetid);
    if(!vehicleid)
        return SendMsg(playerid, COLOR_ERROR, "[!] Jucatorul nu este in niciun vehicul!");

    if(GetDistanceBetweenPlayers(playerid, targetid) > 6.0)
        return SendMsg(playerid, COLOR_ERROR, "[!] Esti prea departe de vehicul (max 6m)!");

    // Animatie mecanic
    ApplyAnimation(playerid, "MISC", "LEAN_Relaxed", 4.1, 0, 1, 1, 0, 3000, 1);

    SetTimerEx("OnRepairComplete", 3000, false, "ii", playerid, targetid);
    SendMsg(playerid, COLOR_YELLOW, "[Mecanic] Repari vehiculul... (3 secunde)");
    return 1;
}

forward OnRepairComplete(playerid, targetid);
public OnRepairComplete(playerid, targetid)
{
    if(!IsPlayerConnected(playerid) || !IsPlayerConnected(targetid)) return;

    new vehicleid = GetPlayerVehicleID(targetid);
    if(!vehicleid) return;

    RepairVehicle(vehicleid);

    new cost = JobSalaries[JOB_MECANIC] + random(300);
    if(GetPlayerMoney(targetid) >= cost)
    {
        GivePlayerMoney(targetid, -cost);
        GivePlayerMoney(playerid, cost);
        PlayerData[targetid][pMoney] -= cost;
        PlayerData[playerid][pMoney] += cost;
        SendMsgFmt(playerid, COLOR_SUCCESS,
            "[Mecanic] Reparatie completa! Ai castigat {FFD700}$%d{00FF44}.", cost);
        SendMsgFmt(targetid, COLOR_SUCCESS,
            "[Mecanic] Masina ta a fost reparata de {FFD700}%s{FFFFFF}. Cost: $%d.",
            PlayerData[playerid][pName], cost);
    }
    else
    {
        RepairVehicle(vehicleid);
        SendMsg(playerid, COLOR_ERROR, "[Mecanic] Clientul nu a avut destui bani!");
        SendMsg(targetid, COLOR_ERROR, "[Mecanic] Nu ai putut plati mecanicul!");
    }
    Player_AddXP(playerid, 35);
}

// ============================================================
//  FERMIER
// ============================================================

stock Job_Farmer_Start(playerid)
{
    // Teleporteaza pe ferma
    SetPlayerPos(playerid, 1210.0, -1157.0, 25.0);
    SetPlayerInterior(playerid, 0);
    FarmerActive[playerid] = 1;

    // Spawneaza tractor daca nu are
    new vehicleid = CreateVehicle(369, 1210.0, -1160.0, 25.0, 0.0, 40, 40, -1); // Tractor
    PutPlayerInVehicle(playerid, vehicleid, 0);

    FarmerTimer[playerid] = SetTimerEx("OnFarmerPayment", 300000, true, "i", playerid); // la 5 min
    SendMsg(playerid, COLOR_SUCCESS, "[Fermier] Esti pe ferma! Plimba-te cu tractorul. Platit la 5 minute.");
}

forward OnFarmerPayment(playerid);
public OnFarmerPayment(playerid)
{
    if(!IsPlayerConnected(playerid) || !FarmerActive[playerid] || !PlayerData[playerid][pOnDuty]) return;

    // Verifica daca e pe ferma
    new Float:px, Float:py, Float:pz;
    GetPlayerPos(playerid, px, py, pz);

    // Zona ferma: intre 1000-1500 x, -1400 - -900 y
    if(px < 900.0 || px > 1600.0 || py < -1500.0 || py > -800.0)
    {
        SendMsg(playerid, COLOR_ERROR, "[Fermier] Nu esti pe ferma! Nu ai primit plata.");
        return;
    }

    // Trebuie sa fie in tractor
    if(!GetPlayerVehicleID(playerid))
    {
        SendMsg(playerid, COLOR_ERROR, "[Fermier] Nu esti in tractor! Nu ai primit plata.");
        return;
    }

    new reward = JobSalaries[JOB_FERMIER] + random(150);
    GivePlayerMoney(playerid, reward);
    PlayerData[playerid][pMoney] += reward;
    Player_AddXP(playerid, 25);
    SendMsgFmt(playerid, COLOR_SUCCESS, "[Fermier] Plata de 5 minute: +{FFD700}$%d{00FF44}!", reward);
}

// ============================================================
//  TRUCK DRIVER
// ============================================================

CMD:takeload(playerid, params[])
{
    if(!PlayerData[playerid][pLogged]) return 1;
    if(PlayerData[playerid][pJob] != JOB_TRUCK)
        return SendMsg(playerid, COLOR_ERROR, "[!] Nu esti Truck Driver!");
    if(!PlayerData[playerid][pOnDuty])
        return SendMsg(playerid, COLOR_ERROR, "[!] Trebuie sa fii ON DUTY!");
    if(TruckActive[playerid])
        return SendMsg(playerid, COLOR_ERROR, "[!] Ai deja o livrare in desfasurare!");

    // Verifica sa fie in truck
    new vehicleid = GetPlayerVehicleID(playerid);
    if(!vehicleid) return SendMsg(playerid, COLOR_ERROR, "[!] Trebuie sa fii in camion/vehicul!");

    new dest = random(sizeof(TruckDeliveryPoints));
    TruckDestination[playerid] = dest;
    TruckActive[playerid] = 1;

    SetPlayerCheckpoint(playerid,
        TruckDeliveryPoints[dest][0],
        TruckDeliveryPoints[dest][1],
        TruckDeliveryPoints[dest][2], 8.0);

    SendMsg(playerid, COLOR_SUCCESS, "[Truck] Livrare preluata! Urmeaza checkpoint-ul de pe harta.");
    return 1;
}

stock Job_Truck_Deliver(playerid)
{
    if(!TruckActive[playerid]) return;
    TruckActive[playerid] = 0;
    DisablePlayerCheckpoint(playerid);

    new reward = JobSalaries[JOB_TRUCK] + random(500);
    GivePlayerMoney(playerid, reward);
    PlayerData[playerid][pMoney] += reward;
    Player_AddXP(playerid, 75);

    SendMsgFmt(playerid, COLOR_SUCCESS,
        "[Truck] Livrare finalizata! Ai castigat {FFD700}$%d{00FF44}!", reward);
    GameTextForPlayer(playerid, "~g~Livrare Reusita!", 3000, 1);
}

// ============================================================
//  PESCAR LEGAL
// ============================================================

CMD:fishspot(playerid, params[])
{
    if(!PlayerData[playerid][pLogged]) return 1;
    if(PlayerData[playerid][pJob] != JOB_FISHERMAN)
        return SendMsg(playerid, COLOR_ERROR, "[!] Nu esti Pescar Legal!");
    if(!PlayerData[playerid][pOnDuty])
        return SendMsg(playerid, COLOR_ERROR, "[!] Trebuie sa fii ON DUTY!");

    // Teleporteaza la portul cel mai apropiat
    SetPlayerPos(playerid, -1670.0, -25.0, 14.0);
    SetPlayerInterior(playerid, 0);
    SendMsg(playerid, COLOR_SUCCESS, "[Pescar] Esti la port! Foloseste /catchfish pentru a prinde pesti.");
    return 1;
}

CMD:catchfish(playerid, params[])
{
    if(!PlayerData[playerid][pLogged]) return 1;
    if(PlayerData[playerid][pJob] != JOB_FISHERMAN)
        return SendMsg(playerid, COLOR_ERROR, "[!] Nu esti Pescar Legal!");
    if(!PlayerData[playerid][pOnDuty])
        return SendMsg(playerid, COLOR_ERROR, "[!] Trebuie sa fii ON DUTY!");

    // Verifica daca e la apa (aproape de port)
    new Float:px, Float:py, Float:pz;
    GetPlayerPos(playerid, px, py, pz);

    new at_water = false;
    for(new i = 0; i < sizeof(FishermanSellPoints); i++)
    {
        if(VectorSize(px-FishermanSellPoints[i][0], py-FishermanSellPoints[i][1], 0.0) < 80.0)
        { at_water = true; break; }
    }
    // Verifica si zone de pescuit ilegal (legal e permis in orice zona cu apa)
    for(new i = 0; i < sizeof(FishZones) && !at_water; i++)
    {
        if(VectorSize(px-FishZones[i][0], py-FishZones[i][1], 0.0) < FishZones[i][3])
        { at_water = true; break; }
    }

    if(!at_water) return SendMsg(playerid, COLOR_ERROR, "[!] Trebuie sa fii la apa! Foloseste /fishspot.");

    // Sansa de prindere
    if(random(100) < 70) // 70% sansa
    {
        FishermanBag[playerid]++;
        Player_AddXP(playerid, 10);
        SendMsgFmt(playerid, COLOR_SUCCESS,
            "[Pescar] Ai prins un peste! Total in plasa: %d. Vinde cu /sellfish2.", FishermanBag[playerid]);
    }
    else
    {
        SendMsg(playerid, COLOR_GREY, "[Pescar] Pestele a scapat... Incearca din nou!");
    }
    return 1;
}

CMD:sellfish2(playerid, params[])
{
    if(!PlayerData[playerid][pLogged]) return 1;
    if(PlayerData[playerid][pJob] != JOB_FISHERMAN)
        return SendMsg(playerid, COLOR_ERROR, "[!] Nu esti Pescar Legal!");
    if(FishermanBag[playerid] == 0)
        return SendMsg(playerid, COLOR_ERROR, "[!] Nu ai pesti! Foloseste /catchfish mai intai.");

    // Verifica daca e la port sau piata
    new Float:px, Float:py, Float:pz;
    GetPlayerPos(playerid, px, py, pz);
    new at_sell = false;
    for(new i = 0; i < sizeof(FishermanSellPoints); i++)
    {
        if(VectorSize(px-FishermanSellPoints[i][0], py-FishermanSellPoints[i][1], 0.0) < 80.0)
        { at_sell = true; break; }
    }
    if(!at_sell) return SendMsg(playerid, COLOR_ERROR, "[!] Mergi la port sau piata pentru a vinde! /fishspot.");

    new reward = FishermanBag[playerid] * (JobSalaries[JOB_FISHERMAN] + random(100));
    GivePlayerMoney(playerid, reward);
    PlayerData[playerid][pMoney] += reward;
    Player_AddXP(playerid, FishermanBag[playerid] * 8);

    SendMsgFmt(playerid, COLOR_SUCCESS,
        "[Pescar] Ai vandut {FFD700}%d pesti{00FF44} pentru {FFD700}$%d{00FF44}!",
        FishermanBag[playerid], reward);
    FishermanBag[playerid] = 0;
    return 1;
}

// ============================================================
//  PADURAR
// ============================================================

CMD:checktrees(playerid, params[])
{
    if(!PlayerData[playerid][pLogged]) return 1;
    if(PlayerData[playerid][pJob] != JOB_PADURAR)
        return SendMsg(playerid, COLOR_ERROR, "[!] Nu esti Padurar!");
    if(!PlayerData[playerid][pOnDuty])
        return SendMsg(playerid, COLOR_ERROR, "[!] Trebuie sa fii ON DUTY!");

    // Verifica daca e in zona de padure
    new Float:px, Float:py, Float:pz;
    GetPlayerPos(playerid, px, py, pz);

    new in_zone = false;
    new zone_idx = -1;
    for(new i = 0; i < sizeof(TreeZones); i++)
    {
        if(VectorSize(px-TreeZones[i][0], py-TreeZones[i][1], 0.0) < TreeZones[i][3])
        { in_zone = true; zone_idx = i; break; }
    }
    if(!in_zone) return SendMsg(playerid, COLOR_ERROR, "[!] Nu esti intr-o zona de padure!");

    // Genereaza un raport random
    new stare[3][16] = {"Sanatosi", "Bolnavi", "Periculosi"};
    new nr_copaci = 50 + random(200);
    new nr_bolnavi = random(20);
    new danger = random(3);

    new info[256];
    format(info, sizeof(info),
        "{FFD700}Raport Zona Padure #%d{FFFFFF}\n\n"
        "Copaci inventariati: {00FF00}%d\n"
        "{FFFFFF}Copaci bolnavi: {FF4444}%d\n"
        "Stare generala: {FFD700}%s\n\n"
        "{AAAAAA}Raport generat cu succes.",
        zone_idx+1, nr_copaci, nr_bolnavi, stare[danger]);

    ShowPlayerDialog(playerid, 9999, DIALOG_STYLE_MSGBOX, "Verificare Copaci", info, "Inchide", "");

    new reward = JobSalaries[JOB_PADURAR];
    GivePlayerMoney(playerid, reward);
    PlayerData[playerid][pMoney] += reward;
    Player_AddXP(playerid, 40);
    SendMsgFmt(playerid, COLOR_SUCCESS, "[Padurar] Raport completat! +{FFD700}$%d{00FF44} +40 XP.", reward);
    return 1;
}

// ============================================================
//  SALVAMAR
// ============================================================

CMD:cleanbeach(playerid, params[])
{
    if(!PlayerData[playerid][pLogged]) return 1;
    if(PlayerData[playerid][pJob] != JOB_SALVAMAR)
        return SendMsg(playerid, COLOR_ERROR, "[!] Nu esti Salvamar!");
    if(!PlayerData[playerid][pOnDuty])
        return SendMsg(playerid, COLOR_ERROR, "[!] Trebuie sa fii ON DUTY!");

    // Seteaza checkpoint la un punct de curatat
    new pt = random(sizeof(BeachCleanPoints));
    SetPlayerCheckpoint(playerid,
        BeachCleanPoints[pt][0],
        BeachCleanPoints[pt][1],
        BeachCleanPoints[pt][2], 5.0);
    SetPVarInt(playerid, "CleanBeachActive", 1);
    SetPVarInt(playerid, "CleanBeachPt", pt);
    SendMsg(playerid, COLOR_SUCCESS, "[Salvamar] Mergi la checkpoint pentru a curata plaja!");
    return 1;
}

stock Job_Salvamar_StartClean(playerid)
{
    // Se apeleaza automat la duty on
}

stock Job_Salvamar_CleanDone(playerid)
{
    if(!GetPVarInt(playerid, "CleanBeachActive")) return;
    DeletePVar(playerid, "CleanBeachActive");
    DisablePlayerCheckpoint(playerid);

    new reward = JobSalaries[JOB_SALVAMAR] + random(200);
    GivePlayerMoney(playerid, reward);
    PlayerData[playerid][pMoney] += reward;
    Player_AddXP(playerid, 30);
    SendMsgFmt(playerid, COLOR_SUCCESS,
        "[Salvamar] Zona curatata! +{FFD700}$%d{00FF44} +30 XP.", reward);

    // Genereaza urmatorul punct automat
    SetTimerEx("OnSalvamarNextClean", 5000, false, "i", playerid);
}

forward OnSalvamarNextClean(playerid);
public OnSalvamarNextClean(playerid)
{
    if(!IsPlayerConnected(playerid) || !PlayerData[playerid][pOnDuty]) return;
    if(PlayerData[playerid][pJob] != JOB_SALVAMAR) return;

    new pt = random(sizeof(BeachCleanPoints));
    SetPlayerCheckpoint(playerid,
        BeachCleanPoints[pt][0],
        BeachCleanPoints[pt][1],
        BeachCleanPoints[pt][2], 5.0);
    SetPVarInt(playerid, "CleanBeachActive", 1);
    SendMsg(playerid, COLOR_YELLOW, "[Salvamar] Urmatoarea zona de curatat marcata pe harta!");
}

// ============================================================
//  CHECKPOINT HANDLER (apelat din main)
// ============================================================

stock Jobs_OnCheckpoint(playerid)
{
    if(!PlayerData[playerid][pLogged] || !PlayerData[playerid][pOnDuty]) return 1;

    switch(PlayerData[playerid][pJob])
    {
        case JOB_BOLT_FOOD:  Job_BoltFood_Deliver(playerid);
        case JOB_TRUCK:      Job_Truck_Deliver(playerid);
        case JOB_SALVAMAR:   Job_Salvamar_CleanDone(playerid);
    }
    return 1;
}

// ============================================================
//  DIALOG HANDLER JOBURI
// ============================================================

stock Jobs_OnDialog(playerid, dialogid, response, listitem, inputtext[])
{
    if(dialogid == DIALOG_JOB_SELECT)
    {
        if(!response) return 1;
        Job_Select(playerid, listitem + 1);
    }
    return 1;
}
