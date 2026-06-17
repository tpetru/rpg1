#include <a_samp>
#include <core>
#include <float>
#include <a_mysql>
#include <streamer>
#include <string>

#pragma tabsize 0
#pragma warning disable 239

// ============================================================
//  CONFIGURARE BAZA DE DATE
// ============================================================
#define MYSQL_HOST  "127.0.0.1"
#define MYSQL_USER  "root"
#define MYSQL_PASS  ""
#define MYSQL_DB    "rpg1"

// ============================================================
//  CULORI - GENERAL
// ============================================================
#define COLOR_ERROR     0xFF3333FF
#define COLOR_SUCCESS   0x1A8C1AFF
#define COLOR_INFO      0xBB99FFFF
#define COLOR_WHITE     0xFFFFFFFF

#define C_ERROR     "{FF3333}"
#define C_SUCCESS   "{1A8C1A}"
#define C_INFO      "{BB99FF}"
#define C_WHITE     "{FFFFFF}"

// ============================================================
//  CULORI - FACTIUNI
// ============================================================
#define MAX_FACTIONS    7
#define FACTION_NONE    0
#define MAX_HOUSES      50

new const FactionColors[MAX_FACTIONS + 1] = {
    0xFFFFFFFF,  // 0 = nicio factiune
    0x4488FFFF,  // 1 = Politia Romana      (albastru)
    0x003399FF,  // 2 = Registrul Auto Roman (albastru inchis)
    0xFF5500FF,  // 3 = SMURD               (portocaliu-rosu)
    0x3366CCFF,  // 4 = Mafia Europeana     (blue)
    0xAA44AAFF,  // 5 = Mafia Americana     (mov)
    0x44AA44FF,  // 6 = Mafia Africana      (verde)
    0xFFCC00FF   // 7 = Mafia Asiatica      (galben)
};

// ============================================================
//  NATIVE / FORWARD
// ============================================================


forward OnPlayerCheckExists(playerid);
forward OnPlayerRegister(playerid);
forward OnPlayerLogin(playerid);
forward OnFactionsLoaded();
forward OnPayDayLoaded();
forward PayDay_Check();
forward OnHousesLoaded();
forward OnHouseCreated(playerid, idx);
forward OnBusinessesLoaded();
forward OnBusinessCreated(playerid, idx);
forward OnTurfsLoaded();
forward OnVehiclesFactionLoaded();
forward OnVehicleFactionCreated(playerid, idx);
forward Fires_Tick();
forward OnVehiclesPersonalLoaded();
forward OnVehiclePersonalCreated(playerid, idx);
forward OnVehiclePlateChecked(playerid, pvidx, plate[]);
forward OnVehicleITPCheck(playerid, pvidx, vehid);

new MySQL:g_SQL;

// ============================================================
//  PAYDAY - SETARI
// ============================================================
new g_PDMinSalary  = 5000;
new g_PDTax        = 10;
new g_PDCASS       = 10;
new Float:g_PDInterest = 0.25;
new g_LastPayDayHour   = -1;
new g_InsurancePrice   = 500;
new g_MedkitPrice      = 500;
new g_ExtinguisherPrice = 500;
new g_ITPPrice         = 750;
new g_PlatePrice       = 250;
new g_RentBikePrice    = 15;
new g_RentCarDesertPrice = 20;
new g_ExamAPrice       = 200;
new g_ExamBPrice       = 300;

// ============================================================
//  DATE JUCATOR
// ============================================================
enum E_PLAYER_DATA
{
    pID, pName[24], pPass[64], pEmail[64],
    pLevel, pMoney, pBank, pRP, pAdminLevel, pFaction, pFactionRank, pFactionJoin, pHouse, pBusiness,
    pSpawn, Float:pSpawnX, Float:pSpawnY, Float:pSpawnZ,
    pKey1, pKey2, pKey3,
    pDrivingLicA_exp[11], pDrivingLicB_exp[11], pDrivingLicC_exp[11], pDrivingLicD_exp[11],
    bool:pLogged, bool:pRegistered, bool:pOnDuty
}
new PlayerData[MAX_PLAYERS][E_PLAYER_DATA];

// ============================================================
//  FACTIUNI
// ============================================================
enum E_FACTION_DATA
{
    fID, fName[32], fMembers, fLead[24], fBank,
    fPickupID, fMapIconID,
    Float:fHQX, Float:fHQY, Float:fHQZ
}
new FactionData[MAX_FACTIONS + 1][E_FACTION_DATA];

// Invitatie de factiune in asteptare (un singur invite activ per player, cel mai recent il suprascrie)
new g_InviteFaction[MAX_PLAYERS]; // 0 = nicio invitatie
new g_InviteInviter[MAX_PLAYERS];

#define FINVITE_RANGE 15.0

// Amenda RAR in asteptare (o singura amenda activa per player, cea mai recenta o suprascrie)
new g_PendingFineAmount[MAX_PLAYERS]; // 0 = nicio amenda in asteptare
new g_PendingFineOfficer[MAX_PLAYERS];
new g_PendingFineReason[MAX_PLAYERS][128];

#define FINE_RANGE 10.0
#define M_RANGE    50.0

// Returneaza {RRGGBB} pentru culoarea factiunii
stock GetFactionColorCode(fid, out[], len)
{
    if(fid < 0 || fid > MAX_FACTIONS) { out[0] = EOS; return; }
    format(out, len, "{%06x}", (FactionColors[fid] >> 8) & 0xFFFFFF);
}

// ============================================================
//  CONVERSIE UNIX TIMESTAMP <-> DATE (pentru coloanele DATE din DB)
// ============================================================
// Howard Hinnant's days_from_civil algorithm (numar de zile fata de 1970-01-01)
stock DaysFromCivil(y, m, d)
{
    y -= (m <= 2) ? 1 : 0;
    new era = (y >= 0 ? y : y - 399) / 400;
    new yoe = y - era * 400;
    new doy = (153 * (m + (m > 2 ? -3 : 9)) + 2) / 5 + d - 1;
    new doe = yoe * 365 + yoe / 4 - yoe / 100 + doy;
    return era * 146097 + doe - 719468;
}

// Inversul: numar de zile fata de epoch -> (an, luna, zi)
stock CivilFromDays(z, &y, &m, &d)
{
    z += 719468;
    new era = (z >= 0 ? z : z - 146096) / 146097;
    new doe = z - era * 146097;
    new yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365;
    y = yoe + era * 400;
    new doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    new mp = (5 * doy + 2) / 153;
    d = doy - (153 * mp + 2) / 5 + 1;
    m = mp + (mp < 10 ? 3 : -9);
    y += (m <= 2) ? 1 : 0;
}

// Unix timestamp -> "YYYY-MM-DD" (pentru a salva intr-o coloana DATE)
stock UnixToDateStr(ts, out[], len)
{
    new y, m, d;
    CivilFromDays(ts / 86400, y, m, d);
    format(out, len, "%04d-%02d-%02d", y, m, d);
}

// "YYYY-MM-DD" (citit dintr-o coloana DATE) -> unix timestamp (miezul noptii acelei zile)
stock DateStrToUnix(const datestr[])
{
    if(strlen(datestr) < 10) return 0;

    new ys[5], ms[3], ds[3];
    strmid(ys, datestr, 0, 4, 5);
    strmid(ms, datestr, 5, 7, 3);
    strmid(ds, datestr, 8, 10, 3);

    return DaysFromCivil(strval(ys), strval(ms), strval(ds)) * 86400;
}

// Verifica daca un string respecta strict formatul YYYY-MM-DD (cu luna 01-12, ziua 01-31)
stock bool:IsValidDateStr(const str[])
{
    if(strlen(str) != 10) return false;
    if(str[4] != '-' || str[7] != '-') return false;

    for(new i = 0; i < 10; i++)
    {
        if(i == 4 || i == 7) continue;
        if(str[i] < '0' || str[i] > '9') return false;
    }

    new ms[3], ds[3];
    strmid(ms, str, 5, 7, 3);
    strmid(ds, str, 8, 10, 3);

    new m = strval(ms), d = strval(ds);
    if(m < 1 || m > 12) return false;
    if(d < 1 || d > 31) return false;

    return true;
}

// Construieste fragmentul SQL pentru o coloana DATE: NULL daca string-ul e gol, altfel 'YYYY-MM-DD'
stock BuildDateSqlValue(const datestr[], out[], len)
{
    if(!strlen(datestr)) format(out, len, "NULL");
    else format(out, len, "'%s'", datestr);
}

// La fel ca BuildDateSqlValue, dar pornind de la un timestamp unix (0 = NULL)
stock BuildDateSqlValueFromUnix(ts, out[], len)
{
    if(ts <= 0) { format(out, len, "NULL"); return; }

    new dateStr[11];
    UnixToDateStr(ts, dateStr, sizeof(dateStr));
    format(out, len, "'%s'", dateStr);
}

// ============================================================
//  PERMISE AUTO
// ============================================================
#define LIC_NONE 0 // nu necesita niciun permis
#define LIC_A    1
#define LIC_B    2
#define LIC_C    3
#define LIC_D    4

// Returneaza categoria de permis necesara pentru un model de vehicul (LIC_NONE/LIC_A/LIC_B/LIC_C/LIC_D)
stock GetVehicleLicenseCategory(model)
{
    static const exemptModels[7] = {509, 481, 462, 510, 448, 485, 574};
    static const catA[8] = {581, 521, 463, 522, 461, 468, 586, 523};
    static const catC[28] = {408, 552, 416, 433, 427, 490, 528, 407, 544, 601, 428, 499, 609, 498, 524, 578, 486, 406, 573, 455, 588, 403, 523, 414, 443, 515, 514, 456};
    static const catD[2] = {431, 437};

    for(new i = 0; i < sizeof(exemptModels); i++) if(exemptModels[i] == model) return LIC_NONE;
    for(new i = 0; i < sizeof(catA); i++) if(catA[i] == model) return LIC_A;
    for(new i = 0; i < sizeof(catC); i++) if(catC[i] == model) return LIC_C;
    for(new i = 0; i < sizeof(catD); i++) if(catD[i] == model) return LIC_D;
    return LIC_B; // restul masinilor
}

// Verifica daca playerul are un permis valid (existent si neexpirat) pentru categoria data
stock bool:Player_HasValidLicense(playerid, category)
{
    new expTs;

    switch(category)
    {
        case LIC_NONE: return true;
        case LIC_A:
        {
            if(!strlen(PlayerData[playerid][pDrivingLicA_exp])) return false;
            expTs = DateStrToUnix(PlayerData[playerid][pDrivingLicA_exp]);
        }
        case LIC_B:
        {
            if(!strlen(PlayerData[playerid][pDrivingLicB_exp])) return false;
            expTs = DateStrToUnix(PlayerData[playerid][pDrivingLicB_exp]);
        }
        case LIC_C:
        {
            if(!strlen(PlayerData[playerid][pDrivingLicC_exp])) return false;
            expTs = DateStrToUnix(PlayerData[playerid][pDrivingLicC_exp]);
        }
        case LIC_D:
        {
            if(!strlen(PlayerData[playerid][pDrivingLicD_exp])) return false;
            expTs = DateStrToUnix(PlayerData[playerid][pDrivingLicD_exp]);
        }
        default: return true;
    }

    return expTs > gettime();
}

// Returneaza litera categoriei ("A","B","C","D")
stock GetLicenseCategoryName(category, out[], len)
{
    switch(category)
    {
        case LIC_A: format(out, len, "A");
        case LIC_B: format(out, len, "B");
        case LIC_C: format(out, len, "C");
        case LIC_D: format(out, len, "D");
        default: format(out, len, "-");
    }
}

// Formats a license status for display ("None" / "Expired (date)" / "Valid until date")
stock License_FormatStatus(const licStr[], out[], len)
{
    if(!strlen(licStr)) { format(out, len, "None"); return; }

    if(DateStrToUnix(licStr) <= gettime())
        format(out, len, "Expired (%s)", licStr);
    else
        format(out, len, "Valid until %s", licStr);
}

// Adauga bani in contul unei factiuni si salveaza in DB
stock Faction_AddBank(fid, amount)
{
    if(fid < 1 || fid > MAX_FACTIONS) return;

    FactionData[fid][fBank] += amount;

    new q[128];
    mysql_format(g_SQL, q, sizeof(q), "UPDATE `factions` SET `bank`=%d WHERE `id`=%d",
        FactionData[fid][fBank], fid);
    mysql_tquery(g_SQL, q, "", "", 0);
}

new g_TrainID = -1;
new g_FactionPickup[MAX_FACTIONS + 1] = {-1, -1, -1, -1, -1, -1, -1, -1};
new Text3D:g_FactionLabel[MAX_FACTIONS + 1];

// ============================================================
//  BICICLETE DE INCHIRIAT
// ============================================================
#define MAX_RENT_BIKES  5
#define RENT_BIKE_MODEL 510
#define RENT_BIZ_ID     1

new g_RentBikeVehicle[MAX_RENT_BIKES] = {-1, -1, -1, -1, -1};

// Returneaza true daca vehiculul dat e una dintre bicicletele de inchiriat
stock bool:IsRentBikeVehicle(vehid)
{
    for(new i = 0; i < MAX_RENT_BIKES; i++)
        if(g_RentBikeVehicle[i] == vehid) return true;
    return false;
}

// ============================================================
//  MASINI DE INCHIRIAT (PIRAMIDA)
// ============================================================
#define MAX_RENT_CARS    4
#define RENT_CAR_PRICE   30
#define RENT_CAR_BIZ_ID  3

new g_RentCarVehicle[MAX_RENT_CARS] = {-1, -1, -1, -1};

// Returneaza true daca vehiculul dat e una dintre masinile de inchiriat
stock bool:IsRentCarVehicle(vehid)
{
    for(new i = 0; i < MAX_RENT_CARS; i++)
        if(g_RentCarVehicle[i] == vehid) return true;
    return false;
}

// ============================================================
//  MASINI DE INCHIRIAT (RENTCARDMVDESERT)
// ============================================================
#define MAX_RENT_CARS_DESERT    4
#define RENT_CAR_DESERT_BIZ_ID  6

new g_RentCarDesertVehicle[MAX_RENT_CARS_DESERT] = {-1, -1, -1, -1};

// Returneaza true daca vehiculul dat e una dintre masinile de inchiriat de la RentCarDMVDesert
stock bool:IsRentCarDesertVehicle(vehid)
{
    for(new i = 0; i < MAX_RENT_CARS_DESERT; i++)
        if(g_RentCarDesertVehicle[i] == vehid) return true;
    return false;
}

// ============================================================
//  EXAMEN AUTO CATEGORIA A
// ============================================================
#define MAX_EXAMA_CARS        3
#define EXAMA_CAR_MODEL       468 // Sanchez
#define EXAMA_BIZ_ID          5
#define EXAMA_LOC_X           -13.0385
#define EXAMA_LOC_Y           2346.3943
#define EXAMA_LOC_Z           24.1406
#define EXAMA_RANGE           5.0
#define EXAMA_CP_SIZE         5.0
#define EXAMA_STEP_TIME       30000 // 30 secunde, in ms
#define EXAMA_PASS_HEALTH     800.0
#define EXAMA_PASS_DURATION   1123200 // 13 zile, in secunde
#define EXAMA_FAIL_DURATION   259200  // 3 zile, in secunde
#define MAX_EXAMA_CHECKPOINTS 10

#define EXAMA_STATE_NONE        0
#define EXAMA_STATE_WAITING_CAR 1
#define EXAMA_STATE_DRIVING     2

new Float:ExamACheckpoints[MAX_EXAMA_CHECKPOINTS][3] = {
    {-28.5800, 2336.8235, 23.8089},
    {-95.5793, 2371.9023, 16.5861},
    {-158.2541, 2284.8386, 30.0590},
    {-133.5963, 2260.8770, 30.9436},
    {-223.5624, 2229.8826, 38.8588},
    {-331.6229, 2144.8433, 46.3301},
    {-264.6616, 2120.6362, 53.8529},
    {-231.3696, 2154.7949, 46.1665},
    {-162.8979, 2265.0098, 28.9983},
    {-7.4154, 2341.7690, 23.8088}
};

new g_ExamACar[MAX_EXAMA_CARS] = {-1, -1, -1};
new g_ExamAState[MAX_PLAYERS];
new g_ExamACheckpoint[MAX_PLAYERS];
new g_ExamAVehicle[MAX_PLAYERS];
new g_ExamATimer[MAX_PLAYERS] = {-1, ...};

forward ExamA_Timeout(playerid);

// Returneaza true daca vehiculul dat e una dintre motocicletele de scoala (examen categoria A)
stock bool:IsExamACarVehicle(vehid)
{
    for(new i = 0; i < MAX_EXAMA_CARS; i++)
        if(g_ExamACar[i] == vehid) return true;
    return false;
}

// Returneaza playerid-ul care da in prezent examenul cu acest vehicul, sau -1 daca e liber
stock ExamA_GetCarUser(vehid)
{
    for(new i = 0; i < MAX_PLAYERS; i++)
        if(g_ExamAState[i] == EXAMA_STATE_DRIVING && g_ExamAVehicle[i] == vehid)
            return i;
    return -1;
}

stock ExamA_KillTimer(playerid)
{
    if(g_ExamATimer[playerid] != -1)
    {
        KillTimer(g_ExamATimer[playerid]);
        g_ExamATimer[playerid] = -1;
    }
}

stock ExamA_GotoCheckpoint(playerid, cpIdx)
{
    SetPlayerCheckpoint(playerid, ExamACheckpoints[cpIdx][0], ExamACheckpoints[cpIdx][1], ExamACheckpoints[cpIdx][2], EXAMA_CP_SIZE);
    ExamA_KillTimer(playerid);
    g_ExamATimer[playerid] = SetTimerEx("ExamA_Timeout", EXAMA_STEP_TIME, false, "i", playerid);
}

stock ExamA_Fail(playerid, const reason[])
{
    new vehid = g_ExamAVehicle[playerid];

    g_ExamAState[playerid]      = EXAMA_STATE_NONE;
    g_ExamAVehicle[playerid]    = -1;
    g_ExamACheckpoint[playerid] = 0;
    DisablePlayerCheckpoint(playerid);
    ExamA_KillTimer(playerid);

    if(vehid != -1) SetVehicleToRespawn(vehid);

    new msg[160];
    format(msg, sizeof(msg), C_ERROR"Error: "C_WHITE"You failed the category A driving exam. %s Try again.", reason);
    SendClientMessage(playerid, COLOR_ERROR, msg);
}

stock ExamA_Finish(playerid)
{
    new vehid = g_ExamAVehicle[playerid];

    DisablePlayerCheckpoint(playerid);
    ExamA_KillTimer(playerid);
    g_ExamAState[playerid]      = EXAMA_STATE_NONE;
    g_ExamAVehicle[playerid]    = -1;
    g_ExamACheckpoint[playerid] = 0;

    new Float:health = 0.0;
    if(vehid != -1) GetVehicleHealth(vehid, health);

    new bool:fullPass = (health >= EXAMA_PASS_HEALTH);
    new expTs = gettime() + (fullPass ? EXAMA_PASS_DURATION : EXAMA_FAIL_DURATION);

    new dateStr[11];
    UnixToDateStr(expTs, dateStr, sizeof(dateStr));
    format(PlayerData[playerid][pDrivingLicA_exp], 11, "%s", dateStr);
    UpdatePlayer(playerid, pDrivingLicA_exp);

    if(vehid != -1) SetVehicleToRespawn(vehid);

    new msg[160];
    format(msg, sizeof(msg),
        C_SUCCESS"Congratulations, "C_WHITE"your category A license has been extended until "C_INFO"%s"C_WHITE" (Vehicle HP: "C_INFO"%d"C_WHITE").",
        dateStr, floatround(health));
    SendClientMessage(playerid, COLOR_SUCCESS, msg);
}

public ExamA_Timeout(playerid)
{
    if(!IsPlayerConnected(playerid)) return 0;
    if(g_ExamAState[playerid] == EXAMA_STATE_NONE) return 0;

    g_ExamATimer[playerid] = -1;
    ExamA_Fail(playerid, "Time's up.");
    return 1;
}

// ============================================================
//  EXAMEN AUTO CATEGORIA B
// ============================================================
#define MAX_EXAMB_CARS        3
#define EXAMB_CAR_MODEL       480 // Comet
#define EXAMB_BIZ_ID          2
#define EXAMB_LOC_X           2236.2078
#define EXAMB_LOC_Y           1285.5682
#define EXAMB_LOC_Z           10.8203
#define EXAMB_RANGE           5.0
#define EXAMB_CP_SIZE         5.0
#define EXAMB_STEP_TIME       30000 // 30 secunde, in ms
#define EXAMB_PASS_HEALTH     800.0
#define EXAMB_PASS_DURATION   1123200 // 13 zile, in secunde
#define EXAMB_FAIL_DURATION   259200  // 3 zile, in secunde
#define MAX_EXAMB_CHECKPOINTS 7

#define EXAM_STATE_NONE        0
#define EXAM_STATE_WAITING_CAR 1
#define EXAM_STATE_DRIVING     2

new Float:ExamBCheckpoints[MAX_EXAMB_CHECKPOINTS][3] = {
    {2225.1045, 1272.9102, 10.2970},
    {2224.2405, 1221.2789, 10.3328},
    {2258.8892, 1211.1154, 6.7929},
    {2409.6775, 1223.6896, 6.7927},
    {2396.3691, 1355.4850, 6.7965},
    {2241.2742, 1355.4342, 9.7523},
    {2225.1272, 1301.8076, 10.2968}
};

new g_ExamBCar[MAX_EXAMB_CARS] = {-1, -1, -1};
new g_ExamState[MAX_PLAYERS];
new g_ExamCheckpoint[MAX_PLAYERS];
new g_ExamVehicle[MAX_PLAYERS];
new g_ExamTimer[MAX_PLAYERS] = {-1, ...};

forward Exam_Timeout(playerid);

// Returneaza true daca vehiculul dat e una dintre masinile de scoala (examen categoria B)
stock bool:IsExamBCarVehicle(vehid)
{
    for(new i = 0; i < MAX_EXAMB_CARS; i++)
        if(g_ExamBCar[i] == vehid) return true;
    return false;
}

// Returneaza playerid-ul care da in prezent examenul cu acest vehicul, sau -1 daca e liber
stock Exam_GetCarUser(vehid)
{
    for(new i = 0; i < MAX_PLAYERS; i++)
        if(g_ExamState[i] == EXAM_STATE_DRIVING && g_ExamVehicle[i] == vehid)
            return i;
    return -1;
}

stock Exam_KillTimer(playerid)
{
    if(g_ExamTimer[playerid] != -1)
    {
        KillTimer(g_ExamTimer[playerid]);
        g_ExamTimer[playerid] = -1;
    }
}

stock Exam_GotoCheckpoint(playerid, cpIdx)
{
    SetPlayerCheckpoint(playerid, ExamBCheckpoints[cpIdx][0], ExamBCheckpoints[cpIdx][1], ExamBCheckpoints[cpIdx][2], EXAMB_CP_SIZE);
    Exam_KillTimer(playerid);
    g_ExamTimer[playerid] = SetTimerEx("Exam_Timeout", EXAMB_STEP_TIME, false, "i", playerid);
}

stock Exam_Fail(playerid, const reason[])
{
    new vehid = g_ExamVehicle[playerid];

    g_ExamState[playerid]      = EXAM_STATE_NONE;
    g_ExamVehicle[playerid]    = -1;
    g_ExamCheckpoint[playerid] = 0;
    DisablePlayerCheckpoint(playerid);
    Exam_KillTimer(playerid);

    if(vehid != -1) SetVehicleToRespawn(vehid);

    new msg[160];
    format(msg, sizeof(msg), C_ERROR"Error: "C_WHITE"You failed the category B driving exam. %s Try again.", reason);
    SendClientMessage(playerid, COLOR_ERROR, msg);
}

stock Exam_Finish(playerid)
{
    new vehid = g_ExamVehicle[playerid];

    DisablePlayerCheckpoint(playerid);
    Exam_KillTimer(playerid);
    g_ExamState[playerid]      = EXAM_STATE_NONE;
    g_ExamVehicle[playerid]    = -1;
    g_ExamCheckpoint[playerid] = 0;

    new Float:health = 0.0;
    if(vehid != -1) GetVehicleHealth(vehid, health);

    new bool:fullPass = (health >= EXAMB_PASS_HEALTH);
    new expTs = gettime() + (fullPass ? EXAMB_PASS_DURATION : EXAMB_FAIL_DURATION);

    new dateStr[11];
    UnixToDateStr(expTs, dateStr, sizeof(dateStr));
    format(PlayerData[playerid][pDrivingLicB_exp], 11, "%s", dateStr);
    UpdatePlayer(playerid, pDrivingLicB_exp);

    if(vehid != -1) SetVehicleToRespawn(vehid);

    new msg[160];
    format(msg, sizeof(msg),
        C_SUCCESS"Congratulations, "C_WHITE"your category B license has been extended until "C_INFO"%s"C_WHITE" (Vehicle HP: "C_INFO"%d"C_WHITE").",
        dateStr, floatround(health));
    SendClientMessage(playerid, COLOR_SUCCESS, msg);
}

public Exam_Timeout(playerid)
{
    if(!IsPlayerConnected(playerid)) return 0;
    if(g_ExamState[playerid] == EXAM_STATE_NONE) return 0;

    g_ExamTimer[playerid] = -1;
    Exam_Fail(playerid, "Time's up.");
    return 1;
}

// ============================================================
//  EXAMEN AUTO CATEGORIA C
// ============================================================
#define MAX_EXAMC_TRUCKS         2
#define MAX_EXAMC_TRAILERS       2
#define EXAMC_TRUCK_MODEL        403 // Linerunner
#define EXAMC_TRAILER_MODEL      450 // Trailer
#define EXAMC_BIZ_ID             4
#define EXAMC_PRICE              500
#define EXAMC_LOC_X              1375.2307
#define EXAMC_LOC_Y              1019.8265
#define EXAMC_LOC_Z              10.8203
#define EXAMC_RANGE              5.0
#define EXAMC_CP_SIZE            5.0
#define EXAMC_STEP_TIME          30000 // 30 secunde, in ms
#define EXAMC_PASS_HEALTH        800.0
#define EXAMC_PASS_DURATION      1728000 // 20 zile, in secunde
#define EXAMC_FAIL_DURATION      432000  // 5 zile, in secunde
#define MAX_EXAMC_CHECKPOINTS    6

#define EXAMC_STATE_NONE            0
#define EXAMC_STATE_WAITING_TRUCK   1
#define EXAMC_STATE_WAITING_TRAILER 2
#define EXAMC_STATE_DRIVING         3

new Float:ExamCCheckpoints[MAX_EXAMC_CHECKPOINTS][3] = {
    {1424.8381,  988.9763, 11.4167},
    {1482.6425, 1017.5750, 11.4138},
    {1442.8020, 1113.3623, 11.4136},
    {1397.2150, 1118.4844, 11.4066},
    {1406.1770, 1024.8680, 11.4167},
    {1389.1658,  947.0981, 11.4130}
};

new g_ExamCTruck[MAX_EXAMC_TRUCKS]     = {-1, -1};
new g_ExamCTrailer[MAX_EXAMC_TRAILERS] = {-1, -1};
new g_ExamCState[MAX_PLAYERS];
new g_ExamCCheckpoint[MAX_PLAYERS];
new g_ExamCVehicle[MAX_PLAYERS];       // cap tractor folosit la examen
new g_ExamCTrailerVeh[MAX_PLAYERS];    // remorca atasata la examen
new g_ExamCTimer[MAX_PLAYERS] = {-1, ...};

forward ExamC_Timeout(playerid);

// Returneaza true daca vehiculul dat e unul dintre capetele tractor de scoala (examen categoria C)
stock bool:IsExamCTruckVehicle(vehid)
{
    for(new i = 0; i < MAX_EXAMC_TRUCKS; i++)
        if(g_ExamCTruck[i] == vehid) return true;
    return false;
}

// Returneaza true daca vehiculul dat e una dintre remorcile de scoala (examen categoria C)
stock bool:IsExamCTrailerVehicle(vehid)
{
    for(new i = 0; i < MAX_EXAMC_TRAILERS; i++)
        if(g_ExamCTrailer[i] == vehid) return true;
    return false;
}

// Returneaza playerid-ul care da in prezent examenul C cu acest cap tractor, sau -1 daca e liber
stock ExamC_GetTruckUser(vehid)
{
    for(new i = 0; i < MAX_PLAYERS; i++)
        if(g_ExamCState[i] != EXAMC_STATE_NONE && g_ExamCVehicle[i] == vehid)
            return i;
    return -1;
}

stock ExamC_KillTimer(playerid)
{
    if(g_ExamCTimer[playerid] != -1)
    {
        KillTimer(g_ExamCTimer[playerid]);
        g_ExamCTimer[playerid] = -1;
    }
}

stock ExamC_StartStepTimer(playerid)
{
    ExamC_KillTimer(playerid);
    g_ExamCTimer[playerid] = SetTimerEx("ExamC_Timeout", EXAMC_STEP_TIME, false, "i", playerid);
}

stock ExamC_GotoCheckpoint(playerid, cpIdx)
{
    SetPlayerCheckpoint(playerid, ExamCCheckpoints[cpIdx][0], ExamCCheckpoints[cpIdx][1], ExamCCheckpoints[cpIdx][2], EXAMC_CP_SIZE);
    ExamC_StartStepTimer(playerid);
}

stock ExamC_Fail(playerid, const reason[])
{
    new vehid = g_ExamCVehicle[playerid];
    new trailerid = g_ExamCTrailerVeh[playerid];

    g_ExamCState[playerid]      = EXAMC_STATE_NONE;
    g_ExamCVehicle[playerid]    = -1;
    g_ExamCTrailerVeh[playerid] = -1;
    g_ExamCCheckpoint[playerid] = 0;
    DisablePlayerCheckpoint(playerid);
    ExamC_KillTimer(playerid);

    if(vehid != -1) SetVehicleToRespawn(vehid);
    if(trailerid != -1) SetVehicleToRespawn(trailerid);

    new msg[160];
    format(msg, sizeof(msg), C_ERROR"Error: "C_WHITE"You failed the category C driving exam. %s Try again.", reason);
    SendClientMessage(playerid, COLOR_ERROR, msg);
}

stock ExamC_Finish(playerid)
{
    new vehid = g_ExamCVehicle[playerid];
    new trailerid = g_ExamCTrailerVeh[playerid];

    DisablePlayerCheckpoint(playerid);
    ExamC_KillTimer(playerid);
    g_ExamCState[playerid]      = EXAMC_STATE_NONE;
    g_ExamCVehicle[playerid]    = -1;
    g_ExamCTrailerVeh[playerid] = -1;
    g_ExamCCheckpoint[playerid] = 0;

    new Float:truckHealth = 0.0, Float:trailerHealth = 0.0;
    if(vehid != -1) GetVehicleHealth(vehid, truckHealth);
    if(trailerid != -1) GetVehicleHealth(trailerid, trailerHealth);

    new bool:fullPass = (truckHealth >= EXAMC_PASS_HEALTH && trailerHealth >= EXAMC_PASS_HEALTH);
    new expTs = gettime() + (fullPass ? EXAMC_PASS_DURATION : EXAMC_FAIL_DURATION);

    new dateStr[11];
    UnixToDateStr(expTs, dateStr, sizeof(dateStr));
    format(PlayerData[playerid][pDrivingLicC_exp], 11, "%s", dateStr);
    UpdatePlayer(playerid, pDrivingLicC_exp);

    if(vehid != -1) SetVehicleToRespawn(vehid);
    if(trailerid != -1) SetVehicleToRespawn(trailerid);

    new msg[180];
    format(msg, sizeof(msg),
        C_SUCCESS"Congratulations, "C_WHITE"your category C license has been extended until "C_INFO"%s"C_WHITE" (Truck HP: "C_INFO"%d"C_WHITE", Trailer HP: "C_INFO"%d"C_WHITE").",
        dateStr, floatround(truckHealth), floatround(trailerHealth));
    SendClientMessage(playerid, COLOR_SUCCESS, msg);
}

public ExamC_Timeout(playerid)
{
    if(!IsPlayerConnected(playerid)) return 0;
    if(g_ExamCState[playerid] == EXAMC_STATE_NONE) return 0;

    g_ExamCTimer[playerid] = -1;
    ExamC_Fail(playerid, "Time's up.");
    return 1;
}

public OnTrailerUpdate(playerid, vehicleid)
{
    if(g_ExamCState[playerid] == EXAMC_STATE_WAITING_TRAILER && g_ExamCVehicle[playerid] == vehicleid)
    {
        if(IsTrailerAttachedToVehicle(vehicleid))
        {
            new trailerid = GetVehicleTrailer(vehicleid);
            if(IsExamCTrailerVehicle(trailerid))
            {
                g_ExamCState[playerid]      = EXAMC_STATE_DRIVING;
                g_ExamCTrailerVeh[playerid] = trailerid;
                g_ExamCCheckpoint[playerid] = 0;
                ExamC_GotoCheckpoint(playerid, 0);

                SendClientMessage(playerid, COLOR_INFO,
                    C_INFO"Info: "C_WHITE"Trailer attached! The exam has started, you have "C_INFO"30 seconds"C_WHITE" to reach the next checkpoint.");
            }
        }
    }
    else if(g_ExamCState[playerid] == EXAMC_STATE_DRIVING && g_ExamCVehicle[playerid] == vehicleid)
    {
        if(!IsTrailerAttachedToVehicle(vehicleid))
            ExamC_Fail(playerid, "You detached the trailer.");
    }
    return 1;
}
public OnPlayerEnterCheckpoint(playerid)
{
    if(g_ExamAState[playerid] == EXAMA_STATE_DRIVING)
    {
        g_ExamACheckpoint[playerid]++;
        if(g_ExamACheckpoint[playerid] >= MAX_EXAMA_CHECKPOINTS)
        {
            ExamA_Finish(playerid);
        }
        else
        {
            ExamA_GotoCheckpoint(playerid, g_ExamACheckpoint[playerid]);

            new msg[64];
            format(msg, sizeof(msg), C_INFO"Info: "C_WHITE"Checkpoint "C_INFO"%d/%d"C_WHITE"!",
                g_ExamACheckpoint[playerid], MAX_EXAMA_CHECKPOINTS);
            SendClientMessage(playerid, COLOR_INFO, msg);
        }
        return 1;
    }

    if(g_ExamState[playerid] == EXAM_STATE_DRIVING)
    {
        g_ExamCheckpoint[playerid]++;
        if(g_ExamCheckpoint[playerid] >= MAX_EXAMB_CHECKPOINTS)
        {
            Exam_Finish(playerid);
        }
        else
        {
            Exam_GotoCheckpoint(playerid, g_ExamCheckpoint[playerid]);

            new msg[64];
            format(msg, sizeof(msg), C_INFO"Info: "C_WHITE"Checkpoint "C_INFO"%d/%d"C_WHITE"!",
                g_ExamCheckpoint[playerid], MAX_EXAMB_CHECKPOINTS);
            SendClientMessage(playerid, COLOR_INFO, msg);
        }
        return 1;
    }

    if(g_ExamCState[playerid] == EXAMC_STATE_DRIVING)
    {
        g_ExamCCheckpoint[playerid]++;
        if(g_ExamCCheckpoint[playerid] >= MAX_EXAMC_CHECKPOINTS)
        {
            ExamC_Finish(playerid);
        }
        else
        {
            ExamC_GotoCheckpoint(playerid, g_ExamCCheckpoint[playerid]);

            new msg[64];
            format(msg, sizeof(msg), C_INFO"Info: "C_WHITE"Checkpoint "C_INFO"%d/%d"C_WHITE"!",
                g_ExamCCheckpoint[playerid], MAX_EXAMC_CHECKPOINTS);
            SendClientMessage(playerid, COLOR_INFO, msg);
        }
        return 1;
    }

    return 1;
}

// Distruge si recreeaza eticheta 3D la HQ-ul factiunii
stock Factions_RecreateLabel(fid)
{
    if(g_FactionLabel[fid] != Text3D:INVALID_3DTEXT_ID)
    {
        Delete3DTextLabel(g_FactionLabel[fid]);
        g_FactionLabel[fid] = Text3D:INVALID_3DTEXT_ID;
    }
    if(FactionData[fid][fHQX] == 0.0 && FactionData[fid][fHQY] == 0.0) return;

    new label[48], colorcode[9];
    GetFactionColorCode(fid, colorcode, sizeof(colorcode));
    format(label, sizeof(label), "%s[ %s ]", colorcode, FactionData[fid][fName]);
    g_FactionLabel[fid] = Create3DTextLabel(label, FactionColors[fid],
        FactionData[fid][fHQX], FactionData[fid][fHQY], FactionData[fid][fHQZ]-1,
        20.0, 0, 0);
}

// Distruge si recreeaza pickup-ul pentru o factiune
stock Factions_RecreatePickup(fid)
{
    if(g_FactionPickup[fid] != -1)
    {
        DestroyPickup(g_FactionPickup[fid]);
        g_FactionPickup[fid] = -1;
    }
    if(FactionData[fid][fPickupID] != -1 &&
       (FactionData[fid][fHQX] != 0.0 || FactionData[fid][fHQY] != 0.0))
    {
        g_FactionPickup[fid] = CreatePickup(FactionData[fid][fPickupID], 1,
            FactionData[fid][fHQX], FactionData[fid][fHQY], FactionData[fid][fHQZ], -1);
    }
}

// Seteaza map icon-urile factiunilor (MAPICON_LOCAL) pentru un player
stock Factions_SetPlayerIcons(playerid)
{
    for(new i = 1; i <= MAX_FACTIONS; i++)
    {
        if(FactionData[i][fMapIconID] == -1) continue;
        if(FactionData[i][fHQX] == 0.0 && FactionData[i][fHQY] == 0.0) continue;
        SetPlayerMapIcon(playerid, i, FactionData[i][fHQX], FactionData[i][fHQY], FactionData[i][fHQZ],
            FactionData[i][fMapIconID], FactionColors[i], MAPICON_LOCAL);
    }
    SetPlayerMapIcon(playerid, 0, 2859.2053, 1290.6671, 11.3906, 35, 0, MAPICON_GLOBAL); // SPAWN POINT
}

// Actualizeaza icon-urile pentru toti playerii logati
stock Factions_UpdatePlayersIcons()
{
    for(new i = 0; i < MAX_PLAYERS; i++)
    {
        if(IsPlayerConnected(i) && PlayerData[i][pLogged])
            Factions_SetPlayerIcons(i);
    }
}

// ============================================================
//  CASE
// ============================================================
enum E_HOUSE_DATA
{
    hID, hName[32], hOwner[24], hOwnerId, hOwned, hPrice,
    Float:hLocX, Float:hLocY, Float:hLocZ
}
new HouseData[MAX_HOUSES][E_HOUSE_DATA];
new g_HousePickup[MAX_HOUSES];
new Text3D:g_HouseLabel[MAX_HOUSES];
new g_HouseCount = 0;

stock Houses_RecreatePickup(idx)
{
    if(g_HousePickup[idx] != -1)
    {
        DestroyPickup(g_HousePickup[idx]);
        g_HousePickup[idx] = -1;
    }
    g_HousePickup[idx] = CreatePickup(HouseData[idx][hOwned] ? 1272 : 1273, 1,
        HouseData[idx][hLocX], HouseData[idx][hLocY], HouseData[idx][hLocZ], -1);

    if(g_HouseLabel[idx] != Text3D:INVALID_3DTEXT_ID)
    {
        Delete3DTextLabel(g_HouseLabel[idx]);
        g_HouseLabel[idx] = Text3D:INVALID_3DTEXT_ID;
    }

    new label[256];
    if(HouseData[idx][hOwned])
    {
        format(label, sizeof(label),
            "[ House #%d ]\nName: %s\nOwned: Yes\nOwner: %s\nPrice: $%d",
            HouseData[idx][hID], HouseData[idx][hName], HouseData[idx][hOwner], HouseData[idx][hPrice]);
    }
    else
    {
        format(label, sizeof(label),
            "[ House #%d ]\nName: %s\nOwned: No\nPrice: $%d\n\n/buyhouse to buy this house",
            HouseData[idx][hID], HouseData[idx][hName], HouseData[idx][hPrice]);
    }
    g_HouseLabel[idx] = Create3DTextLabel(label, COLOR_WHITE,
        HouseData[idx][hLocX], HouseData[idx][hLocY], HouseData[idx][hLocZ]-1.0, 15.0, 0, 0);
}

// Returneaza indexul (in HouseData) al casei cu hID == hid, sau -1
stock Houses_FindByID(hid)
{
    for(new i = 0; i < g_HouseCount; i++)
        if(HouseData[i][hID] == hid) return i;
    return -1;
}

// Returneaza playerid-ul conectat/logat cu pID == pid, sau INVALID_PLAYER_ID
stock Houses_FindPlayerByPID(pid)
{
    for(new i = 0; i < MAX_PLAYERS; i++)
        if(IsPlayerConnected(i) && PlayerData[i][pLogged] && PlayerData[i][pID] == pid)
            return i;
    return INVALID_PLAYER_ID;
}

// ============================================================
//  BUSINESS-URI PERSONALE
// ============================================================
#define MAX_BUSINESSES          50
#define BUSINESS_RANGE          5.0
#define BUSINESS_ICON_SLOT_BASE 10 // SetPlayerMapIcon iconid e limitat la 0-99; sloturile 1-7 sunt factiunile, 10-59 business-urile, 60-69 incendiile

enum E_BUSINESS_DATA
{
    bID, bName[32], bOwned, bOwner[24], bOwnerId, bPrice, bBank,
    Float:bLocX, Float:bLocY, Float:bLocZ
}
new BusinessData[MAX_BUSINESSES][E_BUSINESS_DATA];
new g_BusinessPickup[MAX_BUSINESSES];
new Text3D:g_BusinessLabel[MAX_BUSINESSES];
new g_BusinessCount = 0;

stock Businesses_RecreatePickup(idx)
{
    if(g_BusinessPickup[idx] != -1)
    {
        DestroyPickup(g_BusinessPickup[idx]);
        g_BusinessPickup[idx] = -1;
    }
    g_BusinessPickup[idx] = CreatePickup(1274, 1,
        BusinessData[idx][bLocX], BusinessData[idx][bLocY], BusinessData[idx][bLocZ], -1);

    if(g_BusinessLabel[idx] != Text3D:INVALID_3DTEXT_ID)
    {
        Delete3DTextLabel(g_BusinessLabel[idx]);
        g_BusinessLabel[idx] = Text3D:INVALID_3DTEXT_ID;
    }

    new label[256];
    if(BusinessData[idx][bOwned])
    {
        format(label, sizeof(label),
            "[ Business #%d ]\nName: %s\nOwned: Yes\nOwner: %s\nPrice: $%d",
            BusinessData[idx][bID], BusinessData[idx][bName], BusinessData[idx][bOwner], BusinessData[idx][bPrice]);
    }
    else
    {
        format(label, sizeof(label),
            "[ Business #%d ]\nName: %s\nOwned: No\nPrice: $%d\n\n/buybiz to buy this business",
            BusinessData[idx][bID], BusinessData[idx][bName], BusinessData[idx][bPrice]);
    }
    g_BusinessLabel[idx] = Create3DTextLabel(label, COLOR_WHITE,
        BusinessData[idx][bLocX], BusinessData[idx][bLocY], BusinessData[idx][bLocZ]-1.0, 15.0, 0, 0);
}

// Seteaza map icon-urile business-urilor (36 = detinut, 52 = de vanzare) pentru un player
stock Businesses_SetPlayerIcons(playerid)
{
    for(new i = 0; i < g_BusinessCount; i++)
    {
        SetPlayerMapIcon(playerid, BUSINESS_ICON_SLOT_BASE + i,
            BusinessData[i][bLocX], BusinessData[i][bLocY], BusinessData[i][bLocZ],
            BusinessData[i][bOwned] ? 36 : 52, 0, MAPICON_LOCAL);
    }
}

// Actualizeaza icon-urile de business pentru toti playerii logati
stock Businesses_UpdatePlayersIcons()
{
    for(new i = 0; i < MAX_PLAYERS; i++)
        if(IsPlayerConnected(i) && PlayerData[i][pLogged])
            Businesses_SetPlayerIcons(i);
}

// Returneaza indexul (in BusinessData) al business-ului cu bID == bid, sau -1
stock Businesses_FindByID(bid)
{
    for(new i = 0; i < g_BusinessCount; i++)
        if(BusinessData[i][bID] == bid) return i;
    return -1;
}

// ============================================================
//  TURFS (TERITORII FACTIUNI)
// ============================================================
#define MAX_TURFS 50

enum E_TURF_DATA
{
    tID, tFactionID, tName[32],
    Float:tX1, Float:tY1, Float:tX2, Float:tY2,
    bool:tAttackable, tColor[9]
}
new TurfData[MAX_TURFS][E_TURF_DATA];
new g_TurfZone[MAX_TURFS] = {-1, ...};
new g_TurfCount = 0;

// Converteste un string hex (ex: "3366CC88") in valoarea sa intreaga (0x3366CC88)
stock HexStrToInt(const str[])
{
    new result = 0;
    for(new i = 0; str[i] != EOS; i++)
    {
        new c = str[i], digit;
        if(c >= '0' && c <= '9') digit = c - '0';
        else if(c >= 'A' && c <= 'F') digit = c - 'A' + 10;
        else if(c >= 'a' && c <= 'f') digit = c - 'a' + 10;
        else continue;
        result = (result << 4) | digit;
    }
    return result;
}

// Distruge si recreeaza gangzone-ul pentru un turf
stock Turfs_RecreateZone(idx)
{
    if(g_TurfZone[idx] != -1)
    {
        GangZoneDestroy(g_TurfZone[idx]);
        g_TurfZone[idx] = -1;
    }
    g_TurfZone[idx] = GangZoneCreate(TurfData[idx][tX1], TurfData[idx][tY1], TurfData[idx][tX2], TurfData[idx][tY2]);
    GangZoneShowForAll(g_TurfZone[idx], HexStrToInt(TurfData[idx][tColor]));
}

stock Turfs_FindByID(tid)
{
    for(new i = 0; i < g_TurfCount; i++)
        if(TurfData[i][tID] == tid) return i;
    return -1;
}

// Arata toate turf-urile incarcate unui singur player (folosit la conectare,
// pentru ca GangZoneShowForAll nu acopera playerii care se conecteaza dupa apel)
stock Turfs_ShowToPlayer(playerid)
{
    for(new i = 0; i < g_TurfCount; i++)
        if(g_TurfZone[i] != -1)
            GangZoneShowForPlayer(playerid, g_TurfZone[i], HexStrToInt(TurfData[i][tColor]));
}

// ============================================================
//  VEHICULE FACTIUNI
// ============================================================
#define MAX_VFACTION_VEHICLES   100

enum E_VFACTION_DATA
{
    vfID, vfFactionID, vfModelID,
    Float:vfLocX, Float:vfLocY, Float:vfLocZ, Float:vfRotation,
    vfColor1, vfColor2
}
new VFactionData[MAX_VFACTION_VEHICLES][E_VFACTION_DATA];
new g_VFactionVehicle[MAX_VFACTION_VEHICLES];
new g_VFactionCount = 0;

// vehicleid (real, din CreateVehicle) -> ID factiune proprietara (0 = niciuna)
new g_VehicleFactionOwner[MAX_VEHICLES];

// Numarul de inmatriculare fix pentru vehiculele de factiune, dupa fID
stock Factions_GetPlate(fid, plate[], len)
{
    switch(fid)
    {
        case 1: format(plate, len, "MAI");
        case 2: format(plate, len, "RAR");
        case 3: format(plate, len, "SMURD");
        case 4: format(plate, len, "M. EUR");
        case 5: format(plate, len, "M. USA");
        case 6: format(plate, len, "M. AFR");
        case 7: format(plate, len, "M. ASIA");
        default: format(plate, len, "N-RP");
    }
}

stock VehiclesFaction_Create(idx)
{
    if(g_VFactionVehicle[idx] != -1)
    {
        DestroyVehicle(g_VFactionVehicle[idx]);
        g_VFactionVehicle[idx] = -1;
    }

    new vehid = CreateVehicle(VFactionData[idx][vfModelID],
        VFactionData[idx][vfLocX], VFactionData[idx][vfLocY], VFactionData[idx][vfLocZ]+0.2,
        VFactionData[idx][vfRotation], VFactionData[idx][vfColor1], VFactionData[idx][vfColor2], -1, false);

    new plate[8];
    Factions_GetPlate(VFactionData[idx][vfFactionID], plate, sizeof(plate));
    SetVehicleNumberPlate(vehid, plate);

    g_VFactionVehicle[idx] = vehid;
    if(vehid >= 0 && vehid < MAX_VEHICLES)
        g_VehicleFactionOwner[vehid] = VFactionData[idx][vfFactionID];
}

// ============================================================
//  INCENDII (SMURD)
// ============================================================
#define MAX_FIRES               10
#define FIRETRUCK_MODEL         407
#define FIRE_MAPICON_ID         20
#define FIRE_ICON_SLOT_BASE     60
#define FIRE_EXTINGUISH_RANGE   25.0
#define DUTY_HQ_RANGE           10.0
#define FACTION_SMURD           3
#define FACTION_RAR             2
#define FACTION_POLICE          1

#define FIRE_VISUAL_REFRESH      4 // recreeaza explozia (vizual) o data la 4 secunde, nu in fiecare tick, ca sa nu se suprapuna si sa para mai mare

enum E_FIRE_DATA
{
    bool:fireActive,
    Float:fireX, Float:fireY, Float:fireZ,
    fireRequired,
    fireProgress,
    fireVisualTick
}
new FireData[MAX_FIRES][E_FIRE_DATA];

// Tine minte daca playerul era deja in raza incendiului tick-ul trecut (pentru gametext la intrare)
new bool:g_FireInRange[MAX_FIRES][MAX_PLAYERS];

// Cauta un slot liber in FireData, sau -1 daca limita e atinsa
stock Fires_FindFree()
{
    for(new i = 0; i < MAX_FIRES; i++)
        if(!FireData[i][fireActive]) return i;
    return -1;
}

// Stinge incendiul: anunta SMURD-ul si sterge map icon-ul de la toti playerii
stock Fires_Extinguish(f, extinguisherId)
{
    FireData[f][fireActive] = false;

    new colorcode[9];
    GetFactionColorCode(FACTION_SMURD, colorcode, sizeof(colorcode));

    new msg[160];
    format(msg, sizeof(msg), "[SMURD] "C_WHITE"Firefighter %s%s "C_WHITE"put out the fire.",
        colorcode, PlayerData[extinguisherId][pName]);

    for(new i = 0; i < MAX_PLAYERS; i++)
    {
        if(!IsPlayerConnected(i)) continue;
        RemovePlayerMapIcon(i, FIRE_ICON_SLOT_BASE + f);
        g_FireInRange[f][i] = false;
        if(PlayerData[i][pLogged] && PlayerData[i][pFaction] == FACTION_SMURD)
            SendClientMessage(i, FactionColors[FACTION_SMURD], msg);
    }
}

// Timer global (1s): tine vie animatia de foc si verifica daca e stins de pompieri
public Fires_Tick()
{
    for(new f = 0; f < MAX_FIRES; f++)
    {
        if(!FireData[f][fireActive]) continue;

        if(++FireData[f][fireVisualTick] >= FIRE_VISUAL_REFRESH)
        {
            FireData[f][fireVisualTick] = 0;
            CreateExplosion(FireData[f][fireX], FireData[f][fireY], FireData[f][fireZ], 1, 0.0);
        }

        new bool:beingExtinguished = false;
        new extinguisherId = INVALID_PLAYER_ID;
        for(new i = 0; i < MAX_PLAYERS; i++)
        {
            if(!IsPlayerConnected(i) || !PlayerData[i][pLogged]) continue;
            if(PlayerData[i][pFaction] != FACTION_SMURD || !PlayerData[i][pOnDuty]) continue;

            new bool:inRange = bool:IsPlayerInRangeOfPoint(i, FIRE_EXTINGUISH_RANGE, FireData[f][fireX], FireData[f][fireY], FireData[f][fireZ]);
            if(inRange && !g_FireInRange[f][i])
                GameTextForPlayer(i, "Put out the fire", 3000, 3);
            g_FireInRange[f][i] = inRange;

            if(!inRange) continue;
            if(!IsPlayerInAnyVehicle(i)) continue;
            if(GetVehicleModel(GetPlayerVehicleID(i)) != FIRETRUCK_MODEL) continue;

            new keys, ud, lr;
            GetPlayerKeys(i, keys, ud, lr);
            if(!(keys & KEY_FIRE)) continue;

            beingExtinguished = true;
            extinguisherId = i;
        }

        if(beingExtinguished)
        {
            FireData[f][fireProgress]++;
            if(FireData[f][fireProgress] >= FireData[f][fireRequired])
                Fires_Extinguish(f, extinguisherId);
        }
        else
        {
            FireData[f][fireProgress] = 0;
        }
    }
    return 1;
}

// ============================================================
//  CAMERE RADAR (POLITIA)
// ============================================================
#define RADAR_RANGE       10.0
#define RADAR_TICK        1000 // 1 secunda, in ms

new bool:g_RadarActive[MAX_PLAYERS];
new Float:g_RadarX[MAX_PLAYERS];
new Float:g_RadarY[MAX_PLAYERS];
new Float:g_RadarZ[MAX_PLAYERS];
new g_RadarSpeedLimit[MAX_PLAYERS];
new g_RadarFlaggedBy[MAX_PLAYERS] = {-1, ...}; // pentru fiecare player, ID-ul ofiterului al carui radar l-a avertizat deja (evita spam la fiecare tick)

forward Radar_Tick();

// Returneaza viteza curenta a vehiculului in care se afla playerid, in km/h (aproximare standard SA-MP)
stock Float:GetPlayerVehicleSpeed(playerid)
{
    new vehid = GetPlayerVehicleID(playerid);
    if(vehid == 0) return 0.0;

    new Float:vx, Float:vy, Float:vz;
    GetVehicleVelocity(vehid, vx, vy, vz);
    return floatsqroot(vx * vx + vy * vy + vz * vz) * 180.0;
}

public Radar_Tick()
{
    for(new i = 0; i < MAX_PLAYERS; i++)
    {
        if(!IsPlayerConnected(i) || !PlayerData[i][pLogged]) continue;

        if(GetPlayerVehicleID(i) == 0)
        {
            g_RadarFlaggedBy[i] = -1;
            continue;
        }

        // Daca e deja semnalat, verifica daca a iesit din raza radarului care l-a semnalat
        if(g_RadarFlaggedBy[i] != -1)
        {
            new j = g_RadarFlaggedBy[i];
            if(!g_RadarActive[j] || !IsPlayerInRangeOfPoint(i, RADAR_RANGE, g_RadarX[j], g_RadarY[j], g_RadarZ[j]))
                g_RadarFlaggedBy[i] = -1;
        }

        if(g_RadarFlaggedBy[i] != -1) continue;

        for(new j = 0; j < MAX_PLAYERS; j++)
        {
            if(i == j || !g_RadarActive[j]) continue;
            if(!IsPlayerInRangeOfPoint(i, RADAR_RANGE, g_RadarX[j], g_RadarY[j], g_RadarZ[j])) continue;

            new Float:speed = GetPlayerVehicleSpeed(i);
            new ispeed = floatround(speed);

            if(ispeed > g_RadarSpeedLimit[j])
            {
                g_RadarFlaggedBy[i] = j;

                new rmsg[160];
                format(rmsg, sizeof(rmsg),
                    C_ERROR"[RADAR] "C_WHITE"You have exceeded the speed limit ("C_INFO"%d km/h"C_WHITE", limit "C_INFO"%d km/h"C_WHITE")! Pull over.",
                    ispeed, g_RadarSpeedLimit[j]);
                SendClientMessage(i, COLOR_ERROR, rmsg);

                format(rmsg, sizeof(rmsg),
                    C_ERROR"[RADAR] "C_INFO"%s"C_WHITE" passed at "C_INFO"%d km/h"C_WHITE" (limit "C_INFO"%d km/h"C_WHITE", +"C_INFO"%d km/h"C_WHITE" over).",
                    PlayerData[i][pName], ispeed, g_RadarSpeedLimit[j], ispeed - g_RadarSpeedLimit[j]);
                SendClientMessage(j, COLOR_ERROR, rmsg);
                break;
            }
        }
    }
    return 1;
}

// ============================================================
//  VEHICULE - CAUTARE DUPA NUME
// ============================================================
new const VehNames[212][24] = {
        "Landstalker",    "Bravura",        "Buffalo",        "Linerunner",     "Perennial",
        "Sentinel",       "Dumper",         "Firetruck",      "Trashmaster",    "Stretch",
        "Manana",         "Infernus",       "Voodoo",         "Pony",           "Mule",
        "Cheetah",        "Ambulance",      "Leviathan",      "Moonbeam",       "Esperanto",
        "Taxi",           "Washington",     "Bobcat",         "Mr Whoopee",     "BF Injection",
        "Hunter",         "Premier",        "Enforcer",       "Securicar",      "Banshee",
        "Predator",       "Bus",            "Rhino",          "Barracks",       "Hotknife",
        "Trailer 1",      "Previon",        "Coach",          "Cabbie",         "Stallion",
        "Rumpo",          "RC Bandit",      "Romero",         "Packer",         "Monster",
        "Admiral",        "Squalo",         "Seasparrow",     "Pizzaboy",       "Tram",
        "Trailer 2",      "Turismo",        "Speeder",        "Reefer",         "Tropic",
        "Flatbed",        "Yankee",         "Caddy",          "Solair",         "Topfun Van",
        "Skimmer",        "PCJ-600",        "Faggio",         "Freeway",        "RC Baron",
        "RC Raider",      "Glendale",       "Oceanic",        "Sanchez",        "Sparrow",
        "Patriot",        "Quad",           "Coastguard",     "Dinghy",         "Hermes",
        "Sabre",          "Rustler",        "ZR-350",         "Walton",         "Regina",
        "Comet",          "BMX",            "Burrito",        "Camper",         "Marquis",
        "Baggage",        "Dozer",          "Maverick",       "Newsvan",        "Rancher",
        "FBI Rancher",    "Virgo",          "Greenwood",      "Jetmax",         "Hotring",
        "Sandking",       "Blista Compact", "Police Maverick","Boxville",       "Benson",
        "Mesa",           "RC Goblin",      "Hotring Racer",  "Hotring Racer B","Bloodring Banger",
        "Rancher",        "Super GT",       "Elegant",        "Journey",        "Bike",
        "Mountain Bike",  "Beagle",         "Cropduster",     "Stuntplane",     "Tanker",
        "Roadtrain",      "Nebula",         "Majestic",       "Buccaneer",      "Shamal",
        "Hydra",          "FCR-900",        "NRG-500",        "HPV1000",        "Cement Truck",
        "Towtruck",       "Fortune",        "Cadrona",        "FBI Truck",      "Willard",
        "Forklift",       "Tractor",        "Combine",        "Feltzer",        "Remington",
        "Slamvan",        "Blade",          "Freight",        "Streak",         "Vortex",
        "Vincent",        "Bullet",         "Clover",         "Sadler",         "Firetruck LA",
        "Hustler",        "Intruder",       "Primo",          "Cargobob",       "Tampa",
        "Sunrise",        "Merit",          "Utility Van",    "Nevada",         "Yosemite",
        "Windsor",        "Monster A",      "Monster B",      "Uranus",         "Jester",
        "Sultan",         "Stratum",        "Elegy",          "Raindance",      "RC Tiger",
        "Flash",          "Tahoma",         "Savanna",        "Bandito",        "Freight Flat",
        "Streak Carriage","Kart",           "Mower",          "Dune",           "Sweeper",
        "Broadway",       "Tornado",        "AT-400",         "DFT-30",         "Huntley",
        "Stafford",       "BF-400",         "Newsvan",        "Tug",            "Trailer 3",
        "Emperor",        "Wayfarer",       "Euros",          "Hotdog",         "Club",
        "Freight Box",    "Article Trailer","Andromada",      "Dodo",           "RC Cam",
        "Launch",         "Police LSPD",    "Police SFPD",    "Police LVPD",    "Police Ranger",
        "Picador",        "SWAT",           "Alpha",          "Phoenix",        "Glendale Wreck",
        "Sadler Wreck",   "Baggage A",      "Baggage B",      "Tug Stairs",     "Boxville 2",
        "Farm Trailer",   "Street"
    };

stock GetVehicleModelByName(const name[])
{
    for(new i = 0; i < sizeof(VehNames); i++)
    {
        if(strfind(VehNames[i], name, true) != -1)
            return i + 400;
    }
    return -1;
}

// Returneaza numele vehiculului dupa modelid (400-611), sau "Necunoscut" daca e in afara intervalului
stock GetVehicleModelName(model, name[], len)
{
    if(model < 400 || model > 611) { format(name, len, "Necunoscut"); return; }
    format(name, len, "%s", VehNames[model - 400]);
}

// ============================================================
//  VEHICULE PERSONALE
// ============================================================
#define MAX_PERSONAL_VEHICLES   200
#define MAX_PLAYER_VEHICLES     3
#define VSELLTO_RANGE           10.0
#define VEHICLE_DOC_DURATION         604800  // 7 zile, in secunde (folosit la /vbuy)
#define VEHICLE_INSURANCE_DURATION   432000  // 5 zile
#define VEHICLE_MEDKIT_DURATION      604800  // 7 zile
#define VEHICLE_EXTINGUISHER_DURATION 864000 // 10 zile
#define VEHICLE_ITP_DURATION         1296000 // 15 zile (la trecerea ITP-ului cu succes)

#define ITP_RANGE       5.0
#define ITP_CHECK_TIME  10000 // 10 secunde, in ms
#define ITP_MIN_HEALTH  900.0
#define ITP_LOC_X       930.0
#define ITP_LOC_Y       2067.0
#define ITP_LOC_Z       12.5

#define PLATE_RANGE     5.0
#define PLATE_LOC_X     930.0
#define PLATE_LOC_Y     2074.0
#define PLATE_LOC_Z     12.5

enum E_PVEHICLE_DATA
{
    pvID, pvOwnerId, pvModelID,
    pvColor1, pvColor2, pvPlate[16], pvPrice,
    Float:pvLocX, Float:pvLocY, Float:pvLocZ, Float:pvRotation,
    pvInsuranceExp, pvMedkitExp, pvExtinguisherExp, pvITPExp
}
new PVehicleData[MAX_PERSONAL_VEHICLES][E_PVEHICLE_DATA];
new g_PVehicleVehicle[MAX_PERSONAL_VEHICLES];
new Text3D:g_PVehicleLabel[MAX_PERSONAL_VEHICLES];
new g_PVehicleCount = 0;

// vehicleid (real) -> index in PVehicleData, sau -1 daca nu e vehicul personal
new g_VehicleToPVIndex[MAX_VEHICLES];

stock PVehicles_Create(idx)
{
    if(g_PVehicleVehicle[idx] != -1)
    {
        DestroyVehicle(g_PVehicleVehicle[idx]);
        g_PVehicleVehicle[idx] = -1;
    }

    new vehid = CreateVehicle(PVehicleData[idx][pvModelID],
        PVehicleData[idx][pvLocX], PVehicleData[idx][pvLocY], PVehicleData[idx][pvLocZ],
        PVehicleData[idx][pvRotation], PVehicleData[idx][pvColor1], PVehicleData[idx][pvColor2], -1, false);

    SetVehicleNumberPlate(vehid, PVehicleData[idx][pvPlate]);

    g_PVehicleVehicle[idx] = vehid;
    if(vehid >= 0 && vehid < MAX_VEHICLES)
        g_VehicleToPVIndex[vehid] = idx;

    PVehicles_RecreateLabel(idx);
}

// Afiseaza eticheta 3D doar daca vehiculul e de vanzare (fara owner)
stock PVehicles_RecreateLabel(idx)
{
    if(g_PVehicleLabel[idx] != Text3D:INVALID_3DTEXT_ID)
    {
        Delete3DTextLabel(g_PVehicleLabel[idx]);
        g_PVehicleLabel[idx] = Text3D:INVALID_3DTEXT_ID;
    }

    if(PVehicleData[idx][pvOwnerId] != 0) return;

    new vname[24];
    GetVehicleModelName(PVehicleData[idx][pvModelID], vname, sizeof(vname));

    new label[96];
    format(label, sizeof(label), "[ %s ]\n[ $%d ]\n[ /vbuy ]", vname, PVehicleData[idx][pvPrice]);

    g_PVehicleLabel[idx] = Create3DTextLabel(label, COLOR_WHITE,
        PVehicleData[idx][pvLocX], PVehicleData[idx][pvLocY], PVehicleData[idx][pvLocZ] + 0.2, 15.0, 0, 0);

    if(g_PVehicleVehicle[idx] != -1)
        Attach3DTextLabelToVehicle(g_PVehicleLabel[idx], g_PVehicleVehicle[idx], 0.0, 0.0, 0.2);
}

// Returneaza indexul (in PVehicleData) al vehiculului cu pvID == vid, sau -1
stock PVehicles_FindByVID(vid)
{
    for(new i = 0; i < g_PVehicleCount; i++)
        if(PVehicleData[i][pvID] == vid) return i;
    return -1;
}

// Formats an expiry timestamp (unix) as "Expired" or "X days"
stock VehicleDoc_Status(exp, out[], len)
{
    if(exp <= gettime()) { format(out, len, "Expired"); return; }
    format(out, len, "%d days", ((exp - gettime()) / 86400) + 1);
}

// Returneaza primul camp pKey liber (pKey1/pKey2/pKey3) al playerului, sau E_PLAYER_DATA:-1 daca e plin
stock E_PLAYER_DATA:PVehicles_FindFreeKeySlot(playerid)
{
    if(PlayerData[playerid][pKey1] == 0) return pKey1;
    if(PlayerData[playerid][pKey2] == 0) return pKey2;
    if(PlayerData[playerid][pKey3] == 0) return pKey3;
    return E_PLAYER_DATA:-1;
}

// Goleste campul pKey care contine vid (daca exista), la playerul dat
stock PVehicles_ClearKeySlot(playerid, vid)
{
    if(PlayerData[playerid][pKey1] == vid) { PlayerData[playerid][pKey1] = 0; UpdatePlayer(playerid, pKey1); }
    else if(PlayerData[playerid][pKey2] == vid) { PlayerData[playerid][pKey2] = 0; UpdatePlayer(playerid, pKey2); }
    else if(PlayerData[playerid][pKey3] == vid) { PlayerData[playerid][pKey3] = 0; UpdatePlayer(playerid, pKey3); }
}

// Recalculeaza si cacheaza pSpawnX/Y/Z in functie de pSpawn, ca sa nu se mai interogheze
// FactionData/HouseData la fiecare spawn. Cade pe civil daca tipul selectat nu e disponibil.
stock Player_RecalcSpawn(playerid)
{
    new type = PlayerData[playerid][pSpawn];

    if(type == 2)
    {
        new fid = PlayerData[playerid][pFaction];
        if(fid >= 1 && fid <= MAX_FACTIONS && (FactionData[fid][fHQX] != 0.0 || FactionData[fid][fHQY] != 0.0))
        {
            PlayerData[playerid][pSpawnX] = FactionData[fid][fHQX];
            PlayerData[playerid][pSpawnY] = FactionData[fid][fHQY];
            PlayerData[playerid][pSpawnZ] = FactionData[fid][fHQZ];
            return;
        }
        type = 3;
    }

    if(type == 3)
    {
        new hidx = (PlayerData[playerid][pHouse] != 999) ? Houses_FindByID(PlayerData[playerid][pHouse]) : -1;
        if(hidx != -1)
        {
            PlayerData[playerid][pSpawnX] = HouseData[hidx][hLocX];
            PlayerData[playerid][pSpawnY] = HouseData[hidx][hLocY];
            PlayerData[playerid][pSpawnZ] = HouseData[hidx][hLocZ];
            return;
        }
        type = 1;
    }

    // Civil (implicit)
    PlayerData[playerid][pSpawnX] = 2859.2053;
    PlayerData[playerid][pSpawnY] = 1290.6671;
    PlayerData[playerid][pSpawnZ] = 11.3906;
}

// ============================================================
//  BAZA DE DATE
// ============================================================
stock DB_Init()
{
    new MySQLOpt:opt = mysql_init_options();
    mysql_set_option(opt, AUTO_RECONNECT, true);
    g_SQL = mysql_connect(MYSQL_HOST, MYSQL_USER, MYSQL_PASS, MYSQL_DB, opt);

    if(g_SQL == MYSQL_INVALID_HANDLE || mysql_errno(g_SQL) != 0)
    {
        print("[DB] EROARE: Nu s-a putut conecta la MySQL!");
        SendRconCommand("exit");
        return 0;
    }
    mysql_log(ERROR | WARNING);
    print("[DB] Conectat la MySQL cu succes!");
    DB_CreateTables();

    return 1;
}

stock DB_CreateTables()
{
    mysql_tquery(g_SQL,
        "CREATE TABLE IF NOT EXISTS `players` (\
        `id`          INT AUTO_INCREMENT PRIMARY KEY,\
        `username`    VARCHAR(24) NOT NULL UNIQUE,\
        `password`    VARCHAR(64) NOT NULL,\
        `email`       VARCHAR(64) DEFAULT '',\
        `level`       INT DEFAULT 1,\
        `money`       INT DEFAULT 0,\
        `bank`        INT DEFAULT 0,\
        `rp`          INT DEFAULT 0,\
        `admin_level` INT DEFAULT 0,\
        `faction`     INT DEFAULT 0,\
        `faction_rank` INT DEFAULT 1,\
        `faction_join` DATE DEFAULT NULL,\
        `house`       INT DEFAULT 999,\
        `business`    INT DEFAULT 999,\
        `spawn_type`  INT DEFAULT 1,\
        `key1`        INT DEFAULT 0,\
        `key2`        INT DEFAULT 0,\
        `key3`        INT DEFAULT 0,\
        `driving_lic_a_exp` DATE DEFAULT NULL,\
        `driving_lic_b_exp` DATE DEFAULT NULL,\
        `driving_lic_c_exp` DATE DEFAULT NULL,\
        `driving_lic_d_exp` DATE DEFAULT NULL\
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;",
        "", "", 0);
    print("[DB] Tabel `players` verificat/creat.");

    mysql_tquery(g_SQL,
        "ALTER TABLE `players` ADD COLUMN `faction` INT DEFAULT 0",
        "", "", 0);
    mysql_tquery(g_SQL,
        "ALTER TABLE `players` ADD COLUMN `faction_rank` INT DEFAULT 1",
        "", "", 0);
    mysql_tquery(g_SQL,
        "ALTER TABLE `players` ADD COLUMN `faction_join` DATE DEFAULT NULL",
        "", "", 0);
    mysql_tquery(g_SQL,
        "ALTER TABLE `players` MODIFY `faction_join` DATE DEFAULT NULL",
        "", "", 0);
    mysql_tquery(g_SQL,
        "ALTER TABLE `players` ADD COLUMN `house` INT DEFAULT 999",
        "", "", 0);
    mysql_tquery(g_SQL,
        "ALTER TABLE `players` ADD COLUMN `business` INT DEFAULT 999",
        "", "", 0);
    mysql_tquery(g_SQL,
        "ALTER TABLE `players` ADD COLUMN `spawn_type` INT DEFAULT 1",
        "", "", 0);
    mysql_tquery(g_SQL, "ALTER TABLE `players` ADD COLUMN `key1` INT DEFAULT 0", "", "", 0);
    mysql_tquery(g_SQL, "ALTER TABLE `players` ADD COLUMN `key2` INT DEFAULT 0", "", "", 0);
    mysql_tquery(g_SQL, "ALTER TABLE `players` ADD COLUMN `key3` INT DEFAULT 0", "", "", 0);
    mysql_tquery(g_SQL, "ALTER TABLE `players` ADD COLUMN `driving_lic_a_exp` DATE DEFAULT NULL", "", "", 0);
    mysql_tquery(g_SQL, "ALTER TABLE `players` ADD COLUMN `driving_lic_b_exp` DATE DEFAULT NULL", "", "", 0);
    mysql_tquery(g_SQL, "ALTER TABLE `players` ADD COLUMN `driving_lic_c_exp` DATE DEFAULT NULL", "", "", 0);
    mysql_tquery(g_SQL, "ALTER TABLE `players` ADD COLUMN `driving_lic_d_exp` DATE DEFAULT NULL", "", "", 0);

    mysql_tquery(g_SQL,
        "CREATE TABLE IF NOT EXISTS `factions` (\
        `id`         INT PRIMARY KEY,\
        `name`       VARCHAR(32) NOT NULL DEFAULT '',\
        `members`    INT DEFAULT 0,\
        `lead`       VARCHAR(24) DEFAULT '',\
        `bank`       BIGINT DEFAULT 0,\
        `pickup_id`  INT DEFAULT -1,\
        `mapicon_id` INT DEFAULT -1,\
        `hq_x`       FLOAT DEFAULT 0.0,\
        `hq_y`       FLOAT DEFAULT 0.0,\
        `hq_z`       FLOAT DEFAULT 0.0\
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;",
        "", "", 0);

    mysql_tquery(g_SQL, "ALTER TABLE `factions` ADD COLUMN `pickup_id`  INT   DEFAULT -1",  "", "", 0);
    mysql_tquery(g_SQL, "ALTER TABLE `factions` ADD COLUMN `mapicon_id` INT   DEFAULT -1",  "", "", 0);
    mysql_tquery(g_SQL, "ALTER TABLE `factions` ADD COLUMN `hq_x`       FLOAT DEFAULT 0.0", "", "", 0);
    mysql_tquery(g_SQL, "ALTER TABLE `factions` ADD COLUMN `hq_y`       FLOAT DEFAULT 0.0", "", "", 0);
    mysql_tquery(g_SQL, "ALTER TABLE `factions` ADD COLUMN `hq_z`       FLOAT DEFAULT 0.0", "", "", 0);

    mysql_tquery(g_SQL,
        "INSERT IGNORE INTO `factions` (`id`,`name`) VALUES \
        (1,'Politia Romana'),\
        (2,'Registrul Auto Roman'),\
        (3,'SMURD'),\
        (4,'Mafia Europeana'),\
        (5,'Mafia Americana'),\
        (6,'Mafia Africana'),\
        (7,'Mafia Asiatica');",
        "", "", 0);

    mysql_tquery(g_SQL,
        "CREATE TABLE IF NOT EXISTS `payday_setup` (\
        `id`                INT PRIMARY KEY DEFAULT 1,\
        `min_salary`        INT   DEFAULT 5000,\
        `tax`               INT   DEFAULT 10,\
        `cass`              INT   DEFAULT 10,\
        `bank_interest`     FLOAT DEFAULT 0.25,\
        `insurance_price`   INT   DEFAULT 500,\
        `medkit_price`      INT   DEFAULT 500,\
        `extinguisher_price` INT  DEFAULT 500,\
        `itp_price`         INT   DEFAULT 750,\
        `plate_price`       INT   DEFAULT 250,\
        `rent_bike_price`   INT   DEFAULT 15,\
        `rent_car_desert_price` INT DEFAULT 20,\
        `exam_a_price`      INT   DEFAULT 200,\
        `exam_b_price`      INT   DEFAULT 300\
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;",
        "", "", 0);

    mysql_tquery(g_SQL, "ALTER TABLE `payday_setup` ADD COLUMN `insurance_price`    INT DEFAULT 500", "", "", 0);
    mysql_tquery(g_SQL, "ALTER TABLE `payday_setup` ADD COLUMN `medkit_price`       INT DEFAULT 500", "", "", 0);
    mysql_tquery(g_SQL, "ALTER TABLE `payday_setup` ADD COLUMN `extinguisher_price` INT DEFAULT 500", "", "", 0);
    mysql_tquery(g_SQL, "ALTER TABLE `payday_setup` ADD COLUMN `itp_price`          INT DEFAULT 750", "", "", 0);
    mysql_tquery(g_SQL, "ALTER TABLE `payday_setup` ADD COLUMN `plate_price`        INT DEFAULT 250", "", "", 0);
    mysql_tquery(g_SQL, "ALTER TABLE `payday_setup` ADD COLUMN `rent_bike_price`    INT DEFAULT 15",  "", "", 0);
    mysql_tquery(g_SQL, "ALTER TABLE `payday_setup` ADD COLUMN `rent_car_desert_price` INT DEFAULT 20", "", "", 0);
    mysql_tquery(g_SQL, "ALTER TABLE `payday_setup` ADD COLUMN `exam_a_price`       INT DEFAULT 200", "", "", 0);
    mysql_tquery(g_SQL, "ALTER TABLE `payday_setup` ADD COLUMN `exam_b_price`       INT DEFAULT 300", "", "", 0);

    mysql_tquery(g_SQL,
        "CREATE TABLE IF NOT EXISTS `houses` (\
        `id`       INT AUTO_INCREMENT PRIMARY KEY,\
        `name`     VARCHAR(32) DEFAULT 'Casa',\
        `owner`    VARCHAR(24) DEFAULT '',\
        `owner_id` INT DEFAULT 0,\
        `owned`    TINYINT DEFAULT 0,\
        `price`    INT DEFAULT 50000,\
        `loc_x`    FLOAT DEFAULT 0.0,\
        `loc_y`    FLOAT DEFAULT 0.0,\
        `loc_z`    FLOAT DEFAULT 0.0\
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;",
        "", "", 0);

    mysql_tquery(g_SQL, "ALTER TABLE `houses` ADD COLUMN `owner_id` INT DEFAULT 0",    "", "", 0);
    mysql_tquery(g_SQL, "ALTER TABLE `houses` ADD COLUMN `price`    INT DEFAULT 50000", "", "", 0);

    mysql_tquery(g_SQL,
        "CREATE TABLE IF NOT EXISTS `businesses` (\
        `id`       INT AUTO_INCREMENT PRIMARY KEY,\
        `name`     VARCHAR(32) DEFAULT 'Business',\
        `owned`    TINYINT DEFAULT 0,\
        `owner`    VARCHAR(24) DEFAULT '',\
        `owner_id` INT DEFAULT 0,\
        `price`    INT DEFAULT 50000,\
        `bank`     INT DEFAULT 0,\
        `loc_x`    FLOAT DEFAULT 0.0,\
        `loc_y`    FLOAT DEFAULT 0.0,\
        `loc_z`    FLOAT DEFAULT 0.0\
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;",
        "", "", 0);

    mysql_tquery(g_SQL, "ALTER TABLE `businesses` ADD COLUMN `name` VARCHAR(32) DEFAULT 'Business'", "", "", 0);

    mysql_tquery(g_SQL,
        "INSERT IGNORE INTO `payday_setup` (`id`,`min_salary`,`tax`,`cass`,`bank_interest`) \
         VALUES (1, 5000, 10, 10, 0.25);",
        "", "", 0);

    mysql_tquery(g_SQL,
        "CREATE TABLE IF NOT EXISTS `vehicles_faction` (\
        `id`         INT AUTO_INCREMENT PRIMARY KEY,\
        `faction_id` INT NOT NULL,\
        `model_id`   INT NOT NULL,\
        `loc_x`      FLOAT DEFAULT 0.0,\
        `loc_y`      FLOAT DEFAULT 0.0,\
        `loc_z`      FLOAT DEFAULT 0.0,\
        `rotation`   FLOAT DEFAULT 0.0,\
        `color1`     INT DEFAULT 1,\
        `color2`     INT DEFAULT 1\
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;",
        "", "", 0);

    mysql_tquery(g_SQL,
        "CREATE TABLE IF NOT EXISTS `vehicles_personal` (\
        `id`               INT AUTO_INCREMENT PRIMARY KEY,\
        `owner_id`         INT DEFAULT 0,\
        `model_id`         INT NOT NULL,\
        `color1`           INT DEFAULT 1,\
        `color2`           INT DEFAULT 1,\
        `plate`            VARCHAR(16) UNIQUE DEFAULT NULL,\
        `price`            INT DEFAULT 0,\
        `loc_x`            FLOAT DEFAULT 0.0,\
        `loc_y`            FLOAT DEFAULT 0.0,\
        `loc_z`            FLOAT DEFAULT 0.0,\
        `rotation`         FLOAT DEFAULT 0.0,\
        `insurance_exp`    DATE DEFAULT NULL,\
        `medkit_exp`       DATE DEFAULT NULL,\
        `extinguisher_exp` DATE DEFAULT NULL,\
        `itp_exp`          DATE DEFAULT NULL\
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;",
        "", "", 0);

    mysql_tquery(g_SQL, "ALTER TABLE `vehicles_personal` MODIFY `plate` VARCHAR(16) DEFAULT NULL", "", "", 0);
    mysql_tquery(g_SQL, "ALTER TABLE `vehicles_personal` ADD UNIQUE `plate_unique` (`plate`)", "", "", 0);
    mysql_tquery(g_SQL, "ALTER TABLE `vehicles_personal` ADD COLUMN `itp_exp` DATE DEFAULT NULL", "", "", 0);
    mysql_tquery(g_SQL, "ALTER TABLE `vehicles_personal` MODIFY `insurance_exp`    DATE DEFAULT NULL", "", "", 0);
    mysql_tquery(g_SQL, "ALTER TABLE `vehicles_personal` MODIFY `medkit_exp`       DATE DEFAULT NULL", "", "", 0);
    mysql_tquery(g_SQL, "ALTER TABLE `vehicles_personal` MODIFY `extinguisher_exp` DATE DEFAULT NULL", "", "", 0);
    mysql_tquery(g_SQL, "ALTER TABLE `vehicles_personal` MODIFY `itp_exp`          DATE DEFAULT NULL", "", "", 0);

    mysql_tquery(g_SQL,
        "CREATE TABLE IF NOT EXISTS `turfs` (\
        `id`         INT AUTO_INCREMENT PRIMARY KEY,\
        `faction_id` INT DEFAULT 0,\
        `name`       VARCHAR(32) NOT NULL DEFAULT '',\
        `x1`         FLOAT DEFAULT 0.0,\
        `y1`         FLOAT DEFAULT 0.0,\
        `x2`         FLOAT DEFAULT 0.0,\
        `y2`         FLOAT DEFAULT 0.0,\
        `attackable` TINYINT(1) DEFAULT 1,\
        `color`      VARCHAR(8) DEFAULT '000000FF',\
        UNIQUE KEY `uq_turf_name` (`name`)\
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;",
        "", "", 0);

    mysql_tquery(g_SQL, "ALTER TABLE `turfs` MODIFY `color` VARCHAR(8) DEFAULT '000000FF'", "", "", 0);

    mysql_tquery(g_SQL,
        "INSERT IGNORE INTO `turfs` (`faction_id`,`name`,`x1`,`y1`,`x2`,`y2`,`attackable`,`color`) VALUES \
        (4,'HQ {Factiune 4}',-304.0,2583.5,-168.0,2762.5,0,'3366CC88'),\
        (5,'HQ {Factiune 5}',-1563.0,2546.5,-1387.0,2687.5,0,'AA44AA88'),\
        (6,'HQ {Factiune 6}',-845.0,1416.5,-748.0,1608.5,0,'44AA4488'),\
        (7,'HQ {Factiune 7}',30.0,1046.5,130.0,1146.5,0,'FFCC0088');",
        "", "", 0);

    mysql_tquery(g_SQL, "UPDATE `turfs` SET `faction_id`=4,`color`='3366CC88' WHERE `name`='HQ {Factiune 4}'", "", "", 0);
    mysql_tquery(g_SQL, "UPDATE `turfs` SET `faction_id`=5,`color`='AA44AA88' WHERE `name`='HQ {Factiune 5}'", "", "", 0);
    mysql_tquery(g_SQL, "UPDATE `turfs` SET `faction_id`=6,`color`='44AA4488' WHERE `name`='HQ {Factiune 6}'", "", "", 0);
    mysql_tquery(g_SQL, "UPDATE `turfs` SET `faction_id`=7,`color`='FFCC0088' WHERE `name`='HQ {Factiune 7}'", "", "", 0);

    print("[DB] Tabele factiuni si payday verificate/create.");
}

// ============================================================
//  INCARCARE FACTIUNI
// ============================================================
stock Factions_Load()
{
    print("[Factions] Se incarca factiunile din baza de date...");
    mysql_tquery(g_SQL,
        "SELECT `id`,`name`,`members`,`lead`,`bank`,`pickup_id`,`mapicon_id`,`hq_x`,`hq_y`,`hq_z` \
         FROM `factions` ORDER BY `id` ASC",
        "OnFactionsLoaded");
}

public OnFactionsLoaded()
{
    new rows = cache_num_rows();
    for(new i = 0; i < rows; i++)
    {
        new fid;
        cache_get_value_name_int(i, "id", fid);
        if(fid < 1 || fid > MAX_FACTIONS) continue;

        cache_get_value_name    (i, "name",       FactionData[fid][fName],  32);
        cache_get_value_name_int(i, "members",    FactionData[fid][fMembers]);
        cache_get_value_name    (i, "lead",       FactionData[fid][fLead],  24);
        cache_get_value_name_int(i, "bank",       FactionData[fid][fBank]);
        cache_get_value_name_int(i, "pickup_id",  FactionData[fid][fPickupID]);
        cache_get_value_name_int(i, "mapicon_id", FactionData[fid][fMapIconID]);
        cache_get_value_name_float(i, "hq_x",    FactionData[fid][fHQX]);
        cache_get_value_name_float(i, "hq_y",    FactionData[fid][fHQY]);
        cache_get_value_name_float(i, "hq_z",    FactionData[fid][fHQZ]);

        Factions_RecreatePickup(fid);
        Factions_RecreateLabel(fid);
    }
    printf("[Factions] %d factiuni incarcate.", rows);
    return 1;
}

// ============================================================
//  INCARCARE CASE
// ============================================================
stock Houses_Load()
{
    mysql_tquery(g_SQL,
        "SELECT `id`,`name`,`owner`,`owner_id`,`owned`,`price`,`loc_x`,`loc_y`,`loc_z` FROM `houses` ORDER BY `id` ASC",
        "OnHousesLoaded");
}

public OnHousesLoaded()
{
    new rows = cache_num_rows();
    g_HouseCount = 0;
    for(new i = 0; i < rows && g_HouseCount < MAX_HOUSES; i++)
    {
        new idx = g_HouseCount;
        cache_get_value_name_int  (i, "id",       HouseData[idx][hID]);
        cache_get_value_name      (i, "name",     HouseData[idx][hName],  32);
        cache_get_value_name      (i, "owner",    HouseData[idx][hOwner], 24);
        cache_get_value_name_int  (i, "owner_id", HouseData[idx][hOwnerId]);
        cache_get_value_name_int  (i, "owned",    HouseData[idx][hOwned]);
        cache_get_value_name_int  (i, "price",    HouseData[idx][hPrice]);
        cache_get_value_name_float(i, "loc_x", HouseData[idx][hLocX]);
        cache_get_value_name_float(i, "loc_y", HouseData[idx][hLocY]);
        cache_get_value_name_float(i, "loc_z", HouseData[idx][hLocZ]);
        g_HousePickup[idx] = -1;
        Houses_RecreatePickup(idx);
        g_HouseCount++;
    }
    printf("[Houses] %d case incarcate.", g_HouseCount);
    return 1;
}

public OnHouseCreated(playerid, idx)
{
    if(!IsPlayerConnected(playerid)) return 0;
    HouseData[idx][hID] = cache_insert_id();
    Houses_RecreatePickup(idx);
    new msg[128];
    format(msg, sizeof(msg), C_SUCCESS"Success: "C_WHITE"House \""C_INFO"%s"C_WHITE"\" created (ID: "C_INFO"%d"C_WHITE").",
        HouseData[idx][hName], HouseData[idx][hID]);
    SendClientMessage(playerid, COLOR_SUCCESS, msg);
    return 1;
}

// ============================================================
//  INCARCARE BUSINESS-URI
// ============================================================
stock Businesses_Load()
{
    mysql_tquery(g_SQL,
        "SELECT `id`,`name`,`owned`,`owner`,`owner_id`,`price`,`bank`,`loc_x`,`loc_y`,`loc_z` FROM `businesses` ORDER BY `id` ASC",
        "OnBusinessesLoaded");
}

public OnBusinessesLoaded()
{
    new rows = cache_num_rows();
    g_BusinessCount = 0;
    for(new i = 0; i < rows && g_BusinessCount < MAX_BUSINESSES; i++)
    {
        new idx = g_BusinessCount;
        cache_get_value_name_int  (i, "id",       BusinessData[idx][bID]);
        cache_get_value_name      (i, "name",     BusinessData[idx][bName], 32);
        cache_get_value_name_int  (i, "owned",    BusinessData[idx][bOwned]);
        cache_get_value_name      (i, "owner",    BusinessData[idx][bOwner], 24);
        cache_get_value_name_int  (i, "owner_id", BusinessData[idx][bOwnerId]);
        cache_get_value_name_int  (i, "price",    BusinessData[idx][bPrice]);
        cache_get_value_name_int  (i, "bank",     BusinessData[idx][bBank]);
        cache_get_value_name_float(i, "loc_x", BusinessData[idx][bLocX]);
        cache_get_value_name_float(i, "loc_y", BusinessData[idx][bLocY]);
        cache_get_value_name_float(i, "loc_z", BusinessData[idx][bLocZ]);
        g_BusinessPickup[idx] = -1;
        Businesses_RecreatePickup(idx);
        g_BusinessCount++;
    }
    printf("[Businesses] %d business-uri incarcate.", g_BusinessCount);
    Businesses_UpdatePlayersIcons();
    return 1;
}

stock Turfs_Load()
{
    mysql_tquery(g_SQL,
        "SELECT `id`,`faction_id`,`name`,`x1`,`y1`,`x2`,`y2`,`attackable`,`color` FROM `turfs` ORDER BY `id` ASC",
        "OnTurfsLoaded");
}

public OnTurfsLoaded()
{
    new rows = cache_num_rows();
    g_TurfCount = 0;
    for(new i = 0; i < rows && g_TurfCount < MAX_TURFS; i++)
    {
        new idx = g_TurfCount;
        cache_get_value_name_int  (i, "id",         TurfData[idx][tID]);
        cache_get_value_name_int  (i, "faction_id",  TurfData[idx][tFactionID]);
        cache_get_value_name      (i, "name",        TurfData[idx][tName], 32);
        cache_get_value_name_float(i, "x1", TurfData[idx][tX1]);
        cache_get_value_name_float(i, "y1", TurfData[idx][tY1]);
        cache_get_value_name_float(i, "x2", TurfData[idx][tX2]);
        cache_get_value_name_float(i, "y2", TurfData[idx][tY2]);

        new attackable;
        cache_get_value_name_int(i, "attackable", attackable);
        TurfData[idx][tAttackable] = bool:attackable;

        cache_get_value_name(i, "color", TurfData[idx][tColor], 9);

        g_TurfZone[idx] = -1;
        Turfs_RecreateZone(idx);
        g_TurfCount++;
    }
    printf("[Turfs] %d turf-uri incarcate.", g_TurfCount);
    return 1;
}

public OnBusinessCreated(playerid, idx)
{
    if(!IsPlayerConnected(playerid)) return 0;
    BusinessData[idx][bID] = cache_insert_id();
    Businesses_RecreatePickup(idx);
    Businesses_UpdatePlayersIcons();
    new msg[128];
    format(msg, sizeof(msg), C_SUCCESS"Success: "C_WHITE"Business created (ID: "C_INFO"%d"C_WHITE", Price: "C_INFO"$%d"C_WHITE").",
        BusinessData[idx][bID], BusinessData[idx][bPrice]);
    SendClientMessage(playerid, COLOR_SUCCESS, msg);
    return 1;
}

// ============================================================
//  INCARCARE VEHICULE FACTIUNI
// ============================================================
stock VehiclesFaction_Load()
{
    mysql_tquery(g_SQL,
        "SELECT `id`,`faction_id`,`model_id`,`loc_x`,`loc_y`,`loc_z`,`rotation`,`color1`,`color2` \
         FROM `vehicles_faction` ORDER BY `id` ASC",
        "OnVehiclesFactionLoaded");
}

public OnVehiclesFactionLoaded()
{
    new rows = cache_num_rows();
    g_VFactionCount = 0;
    for(new i = 0; i < rows && g_VFactionCount < MAX_VFACTION_VEHICLES; i++)
    {
        new idx = g_VFactionCount;
        cache_get_value_name_int  (i, "id",         VFactionData[idx][vfID]);
        cache_get_value_name_int  (i, "faction_id",  VFactionData[idx][vfFactionID]);
        cache_get_value_name_int  (i, "model_id",    VFactionData[idx][vfModelID]);
        cache_get_value_name_float(i, "loc_x",       VFactionData[idx][vfLocX]);
        cache_get_value_name_float(i, "loc_y",       VFactionData[idx][vfLocY]);
        cache_get_value_name_float(i, "loc_z",       VFactionData[idx][vfLocZ]);
        cache_get_value_name_float(i, "rotation",    VFactionData[idx][vfRotation]);
        cache_get_value_name_int  (i, "color1",      VFactionData[idx][vfColor1]);
        cache_get_value_name_int  (i, "color2",      VFactionData[idx][vfColor2]);
        g_VFactionVehicle[idx] = -1;
        VehiclesFaction_Create(idx);
        g_VFactionCount++;
    }
    printf("[VehiculeFactiuni] %d vehicule incarcate.", g_VFactionCount);
    return 1;
}

public OnVehicleFactionCreated(playerid, idx)
{
    if(!IsPlayerConnected(playerid)) return 0;
    VFactionData[idx][vfID] = cache_insert_id();
    VehiclesFaction_Create(idx);
    new msg[128];
    format(msg, sizeof(msg),
        C_SUCCESS"Success: "C_WHITE"Faction vehicle created (ID: "C_INFO"%d"C_WHITE", Faction: "C_INFO"%d"C_WHITE").",
        VFactionData[idx][vfID], VFactionData[idx][vfFactionID]);
    SendClientMessage(playerid, COLOR_SUCCESS, msg);
    return 1;
}

// ============================================================
//  INCARCARE VEHICULE PERSONALE
// ============================================================
stock PVehicles_Load()
{
    mysql_tquery(g_SQL,
        "SELECT `id`,`owner_id`,`model_id`,`color1`,`color2`,`plate`,`price`,`loc_x`,`loc_y`,`loc_z`,`rotation`,\
         `insurance_exp`,`medkit_exp`,`extinguisher_exp`,`itp_exp` FROM `vehicles_personal` ORDER BY `id` ASC",
        "OnVehiclesPersonalLoaded");
}

public OnVehiclesPersonalLoaded()
{
    new rows = cache_num_rows();
    g_PVehicleCount = 0;
    for(new i = 0; i < rows && g_PVehicleCount < MAX_PERSONAL_VEHICLES; i++)
    {
        new idx = g_PVehicleCount;
        cache_get_value_name_int  (i, "id",               PVehicleData[idx][pvID]);
        cache_get_value_name_int  (i, "owner_id",          PVehicleData[idx][pvOwnerId]);
        cache_get_value_name_int  (i, "model_id",          PVehicleData[idx][pvModelID]);
        cache_get_value_name_int  (i, "color1",            PVehicleData[idx][pvColor1]);
        cache_get_value_name_int  (i, "color2",            PVehicleData[idx][pvColor2]);
        cache_get_value_name      (i, "plate",             PVehicleData[idx][pvPlate], 16);
        cache_get_value_name_int  (i, "price",             PVehicleData[idx][pvPrice]);
        cache_get_value_name_float(i, "loc_x",             PVehicleData[idx][pvLocX]);
        cache_get_value_name_float(i, "loc_y",              PVehicleData[idx][pvLocY]);
        cache_get_value_name_float(i, "loc_z",              PVehicleData[idx][pvLocZ]);
        cache_get_value_name_float(i, "rotation",           PVehicleData[idx][pvRotation]);
        new dateBuf[11];
        cache_get_value_name(i, "insurance_exp", dateBuf, sizeof(dateBuf));
        PVehicleData[idx][pvInsuranceExp] = DateStrToUnix(dateBuf);
        cache_get_value_name(i, "medkit_exp", dateBuf, sizeof(dateBuf));
        PVehicleData[idx][pvMedkitExp] = DateStrToUnix(dateBuf);
        cache_get_value_name(i, "extinguisher_exp", dateBuf, sizeof(dateBuf));
        PVehicleData[idx][pvExtinguisherExp] = DateStrToUnix(dateBuf);
        cache_get_value_name(i, "itp_exp", dateBuf, sizeof(dateBuf));
        PVehicleData[idx][pvITPExp] = DateStrToUnix(dateBuf);
        g_PVehicleVehicle[idx] = -1;
        PVehicles_Create(idx);
        g_PVehicleCount++;
    }
    printf("[VehiculePersonale] %d vehicule incarcate.", g_PVehicleCount);
    return 1;
}

public OnVehiclePersonalCreated(playerid, idx)
{
    if(!IsPlayerConnected(playerid)) return 0;
    PVehicleData[idx][pvID] = cache_insert_id();
    format(PVehicleData[idx][pvPlate], 16, "LV %d", PVehicleData[idx][pvID]);
    PVehicles_Create(idx);

    new q[128];
    mysql_format(g_SQL, q, sizeof(q), "UPDATE `vehicles_personal` SET `plate`='%e' WHERE `id`=%d",
        PVehicleData[idx][pvPlate], PVehicleData[idx][pvID]);
    mysql_tquery(g_SQL, q, "", "", 0);

    new vname[24];
    GetVehicleModelName(PVehicleData[idx][pvModelID], vname, sizeof(vname));

    new msg[160];
    format(msg, sizeof(msg),
        C_SUCCESS"Success: "C_WHITE"The "C_INFO"%s"C_WHITE" has been created and put up for sale for "C_INFO"$%d"C_WHITE".",
        vname, PVehicleData[idx][pvPrice]);
    SendClientMessage(playerid, COLOR_SUCCESS, msg);
    return 1;
}

public OnVehiclePlateChecked(playerid, pvidx, plate[])
{
    if(!IsPlayerConnected(playerid)) return 0;

    if(cache_num_rows() > 0)
    {
        SendClientMessage(playerid, COLOR_ERROR,
            C_ERROR"Error: "C_WHITE"This license plate is already registered. Choose a different combination.");
        return 1;
    }

    if(PlayerData[playerid][pMoney] < g_PlatePrice)
    {
        SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have enough money.");
        return 1;
    }

    PlayerData[playerid][pMoney] -= g_PlatePrice;
    GivePlayerMoney(playerid, -g_PlatePrice);
    UpdatePlayer(playerid, pMoney);
    Faction_AddBank(FACTION_RAR, g_PlatePrice);

    format(PVehicleData[pvidx][pvPlate], 16, "%s", plate);

    new vehid = g_PVehicleVehicle[pvidx];
    if(vehid != -1) SetVehicleNumberPlate(vehid, PVehicleData[pvidx][pvPlate]);

    new q[128];
    mysql_format(g_SQL, q, sizeof(q), "UPDATE `vehicles_personal` SET `plate`='%e' WHERE `id`=%d",
        PVehicleData[pvidx][pvPlate], PVehicleData[pvidx][pvID]);
    mysql_tquery(g_SQL, q, "", "", 0);

    SendClientMessage(playerid, COLOR_SUCCESS, C_SUCCESS"Success: "C_WHITE"The license plate has been changed.");
    return 1;
}

public OnVehicleITPCheck(playerid, pvidx, vehid)
{
    if(!IsPlayerConnected(playerid)) return 0;

    TogglePlayerControllable(playerid, 1);

    // Daca playerul a iesit din masina sau a coborat de pe scaunul de sofer in cele 10 secunde, anuleaza
    if(GetPlayerVehicleID(playerid) != vehid || GetPlayerVehicleSeat(playerid) != 0)
    {
        SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"The vehicle inspection has been cancelled.");
        return 1;
    }

    new Float:health;
    GetVehicleHealth(vehid, health);

    new bool:passed = (health > ITP_MIN_HEALTH)
        && (PVehicleData[pvidx][pvInsuranceExp] > gettime())
        && (PVehicleData[pvidx][pvMedkitExp] > gettime())
        && (PVehicleData[pvidx][pvExtinguisherExp] > gettime());

    if(passed)
    {
        PVehicleData[pvidx][pvITPExp] = gettime() + VEHICLE_ITP_DURATION;

        new dateStr[11];
        UnixToDateStr(PVehicleData[pvidx][pvITPExp], dateStr, sizeof(dateStr));

        new q[128];
        mysql_format(g_SQL, q, sizeof(q), "UPDATE `vehicles_personal` SET `itp_exp`='%s' WHERE `id`=%d",
            dateStr, PVehicleData[pvidx][pvID]);
        mysql_tquery(g_SQL, q, "", "", 0);

        SendClientMessage(playerid, COLOR_SUCCESS,
            C_SUCCESS"Success: "C_WHITE"The vehicle passed inspection! Valid for "C_INFO"15 days"C_WHITE".");
    }
    else
    {
        SendClientMessage(playerid, COLOR_ERROR,
            C_ERROR"Error: "C_WHITE"The vehicle did NOT pass inspection. Check the vehicle's condition, insurance, medical kit and extinguisher.");
    }
    return 1;
}

// ============================================================
//  PAYDAY
// ============================================================
stock PayDay_Load()
{
    mysql_tquery(g_SQL,
        "SELECT `min_salary`,`tax`,`cass`,`bank_interest`,`insurance_price`,`medkit_price`,`extinguisher_price`,`itp_price`,`plate_price`,`rent_bike_price`,`rent_car_desert_price`,`exam_a_price`,`exam_b_price` \
         FROM `payday_setup` WHERE `id`=1 LIMIT 1",
        "OnPayDayLoaded");
}

public OnPayDayLoaded()
{
    if(cache_num_rows() > 0)
    {
        cache_get_value_name_int  (0, "min_salary",        g_PDMinSalary);
        cache_get_value_name_int  (0, "tax",                g_PDTax);
        cache_get_value_name_int  (0, "cass",               g_PDCASS);
        cache_get_value_name_float(0, "bank_interest",      g_PDInterest);
        cache_get_value_name_int  (0, "insurance_price",    g_InsurancePrice);
        cache_get_value_name_int  (0, "medkit_price",       g_MedkitPrice);
        cache_get_value_name_int  (0, "extinguisher_price", g_ExtinguisherPrice);
        cache_get_value_name_int  (0, "itp_price",          g_ITPPrice);
        cache_get_value_name_int  (0, "plate_price",        g_PlatePrice);
        cache_get_value_name_int  (0, "rent_bike_price",    g_RentBikePrice);
        cache_get_value_name_int  (0, "rent_car_desert_price", g_RentCarDesertPrice);
        cache_get_value_name_int  (0, "exam_a_price",       g_ExamAPrice);
        cache_get_value_name_int  (0, "exam_b_price",       g_ExamBPrice);
    }
    printf("[PayDay] Setari: Salar minim $%d | Impozit %d%% | CASS %d%% | Dobanda %.2f%%",
        g_PDMinSalary, g_PDTax, g_PDCASS, g_PDInterest);
    printf("[VehiculePersonale] Asigurare $%d | Kit medical $%d | Extinctor $%d | ITP $%d | Numar inmatriculare $%d | Bicicleta $%d | RentCarDMVDesert $%d | Examen A $%d | Examen B $%d",
        g_InsurancePrice, g_MedkitPrice, g_ExtinguisherPrice, g_ITPPrice, g_PlatePrice, g_RentBikePrice, g_RentCarDesertPrice, g_ExamAPrice, g_ExamBPrice);
    return 1;
}

stock PayDay_Apply()
{
    new hour, minute, second;
    gettime(hour, minute, second);
    printf("[PayDay] Distribuit la %02d:00.", hour);

    for(new i = 0; i < MAX_PLAYERS; i++)
    {
        if(!IsPlayerConnected(i) || !PlayerData[i][pLogged]) continue;

        new level    = PlayerData[i][pLevel];
        new salary   = g_PDMinSalary + 2500 * level + random(2501);
        new tax      = salary * g_PDTax  / 100;
        new cass     = salary * g_PDCASS / 100;
        new net      = salary - tax - cass;
        new interest = floatround(float(PlayerData[i][pBank]) * g_PDInterest / 100.0);

        PlayerData[i][pMoney] += net;
        PlayerData[i][pBank]  += interest;
        PlayerData[i][pRP]    += 1;

        GivePlayerMoney(i, net);
        GameTextForPlayer(i, "~g~Payday", 3000, 1);

        new msg[160];
        SendClientMessage(i, COLOR_INFO, C_INFO"===== PayDay ===================");
        format(msg, sizeof(msg),
            C_WHITE"  Gross: "C_SUCCESS"$%d"C_WHITE"  Tax: "C_ERROR"-$%d"C_WHITE"  CASS: "C_ERROR"-$%d"C_WHITE"  Net: "C_SUCCESS"$%d",
            salary, tax, cass, net);
        SendClientMessage(i, COLOR_WHITE, msg);
        format(msg, sizeof(msg),
            C_WHITE"  Bank interest: "C_SUCCESS"+$%d"C_WHITE"  RP: "C_SUCCESS"+1",
            interest);
        SendClientMessage(i, COLOR_WHITE, msg);
        SendClientMessage(i, COLOR_INFO, C_INFO"================================");

        FullUpdatePlayer(i);
    }
}

public PayDay_Check()
{
    new hour, minute, second;
    gettime(hour, minute, second);
    if(minute == 0 && hour != g_LastPayDayHour)
    {
        g_LastPayDayHour = hour;
        PayDay_Apply();
    }
}

// ============================================================
//  VERIFICARE / INCARCARE JUCATOR
// ============================================================
stock Player_CheckExists(playerid)
{
    new query[128];
    mysql_format(g_SQL, query, sizeof(query),
        "SELECT `id`,`password`,`level`,`money`,`bank`,`rp`,`admin_level` \
         FROM `players` WHERE `username`='%e' LIMIT 1",
        PlayerData[playerid][pName]);
    mysql_tquery(g_SQL, query, "OnPlayerCheckExists", "i", playerid);
}

public OnPlayerCheckExists(playerid)
{
    if(!IsPlayerConnected(playerid)) return 0;

    if(cache_num_rows() > 0)
    {
        PlayerData[playerid][pRegistered] = true;

        cache_get_value_name_int(0, "id",          PlayerData[playerid][pID]);
        cache_get_value_name    (0, "password",    PlayerData[playerid][pPass], 64);
        cache_get_value_name_int(0, "level",       PlayerData[playerid][pLevel]);
        cache_get_value_name_int(0, "money",       PlayerData[playerid][pMoney]);
        cache_get_value_name_int(0, "bank",        PlayerData[playerid][pBank]);
        cache_get_value_name_int(0, "rp",          PlayerData[playerid][pRP]);
        cache_get_value_name_int(0, "admin_level", PlayerData[playerid][pAdminLevel]);

        SendClientMessage(playerid, COLOR_INFO,
            C_INFO"Info: "C_WHITE"Account found. Use "C_INFO"/login [password]"C_WHITE" to log in.");
    }
    else
    {
        PlayerData[playerid][pRegistered] = false;
        SendClientMessage(playerid, COLOR_INFO,
            C_INFO"Info: "C_WHITE"You are not registered. Use "C_INFO"/register [password]"C_WHITE".");
    }
    return 1;
}

// ============================================================
//  INREGISTRARE
// ============================================================
stock Player_Register(playerid, const pass[])
{
    new query[256];
    mysql_format(g_SQL, query, sizeof(query),
        "INSERT INTO `players` (`username`,`password`) VALUES ('%e','%e')",
        PlayerData[playerid][pName], pass);
    mysql_tquery(g_SQL, query, "OnPlayerRegister", "i", playerid);
}

public OnPlayerRegister(playerid)
{
    if(!IsPlayerConnected(playerid)) return 0;

    PlayerData[playerid][pID]         = cache_insert_id();
    PlayerData[playerid][pRegistered] = true;
    PlayerData[playerid][pLogged]     = true;
    PlayerData[playerid][pLevel]      = 1;
    PlayerData[playerid][pMoney]      = 0;
    PlayerData[playerid][pBank]       = 0;
    PlayerData[playerid][pRP]         = 0;
    PlayerData[playerid][pAdminLevel] = 0;
    PlayerData[playerid][pFaction]    = 0;
    PlayerData[playerid][pFactionRank]= 1;
    PlayerData[playerid][pFactionJoin]= 0;
    PlayerData[playerid][pHouse]      = 999;
    PlayerData[playerid][pBusiness]   = 999;
    PlayerData[playerid][pSpawn]      = 1;
    PlayerData[playerid][pOnDuty]     = false;
    PlayerData[playerid][pKey1]       = 0;
    PlayerData[playerid][pKey2]       = 0;
    PlayerData[playerid][pKey3]       = 0;
    PlayerData[playerid][pDrivingLicA_exp][0] = EOS;
    PlayerData[playerid][pDrivingLicB_exp][0] = EOS;
    PlayerData[playerid][pDrivingLicC_exp][0] = EOS;
    PlayerData[playerid][pDrivingLicD_exp][0] = EOS;
    Player_RecalcSpawn(playerid);

    SetPlayerVirtualWorld(playerid, 0);
    SetPlayerMapIcon(playerid, 0, 2859.2053, 1290.6671, 11.3906, 35, 0, MAPICON_LOCAL);
    SetPlayerColor(playerid, FactionColors[FACTION_NONE]);
    Factions_SetPlayerIcons(playerid);
    Businesses_SetPlayerIcons(playerid);

    SendClientMessage(playerid, COLOR_SUCCESS,
        C_SUCCESS"Success: "C_WHITE"Registration successful! You are now logged in.");
    SpawnPlayer(playerid);
    return 1;
}

// ============================================================
//  LOGIN
// ============================================================
stock Player_Login(playerid, const pass[])
{
    if(strcmp(pass, PlayerData[playerid][pPass], false) != 0)
    {
        SendClientMessage(playerid, COLOR_ERROR,
            C_ERROR"Error: "C_WHITE"Incorrect password!");
        return;
    }

    new query[400];
    mysql_format(g_SQL, query, sizeof(query),
        "SELECT `id`,`password`,`email`,`level`,`money`,`bank`,`rp`,`admin_level`,`faction`,`faction_rank`,`faction_join`,`house`,`business`,`spawn_type`,`key1`,`key2`,`key3`,\
         `driving_lic_a_exp`,`driving_lic_b_exp`,`driving_lic_c_exp`,`driving_lic_d_exp` \
         FROM `players` WHERE `id`=%d LIMIT 1",
        PlayerData[playerid][pID]);
    mysql_tquery(g_SQL, query, "OnPlayerLogin", "i", playerid);
}

public OnPlayerLogin(playerid)
{
    if(!IsPlayerConnected(playerid)) return 0;

    cache_get_value_name_int(0, "id",          PlayerData[playerid][pID]);
    cache_get_value_name    (0, "password",    PlayerData[playerid][pPass],  64);
    cache_get_value_name    (0, "email",       PlayerData[playerid][pEmail], 64);
    cache_get_value_name_int(0, "level",       PlayerData[playerid][pLevel]);
    cache_get_value_name_int(0, "money",       PlayerData[playerid][pMoney]);
    cache_get_value_name_int(0, "bank",        PlayerData[playerid][pBank]);
    cache_get_value_name_int(0, "rp",          PlayerData[playerid][pRP]);
    cache_get_value_name_int(0, "admin_level", PlayerData[playerid][pAdminLevel]);
    cache_get_value_name_int(0, "faction",      PlayerData[playerid][pFaction]);
    cache_get_value_name_int(0, "faction_rank", PlayerData[playerid][pFactionRank]);

    new factionJoinStr[11];
    cache_get_value_name(0, "faction_join", factionJoinStr, sizeof(factionJoinStr));
    PlayerData[playerid][pFactionJoin] = DateStrToUnix(factionJoinStr);

    cache_get_value_name_int(0, "house",       PlayerData[playerid][pHouse]);
    cache_get_value_name_int(0, "business",    PlayerData[playerid][pBusiness]);
    cache_get_value_name_int(0, "spawn_type",  PlayerData[playerid][pSpawn]);
    cache_get_value_name_int(0, "key1",        PlayerData[playerid][pKey1]);
    cache_get_value_name_int(0, "key2",        PlayerData[playerid][pKey2]);
    cache_get_value_name_int(0, "key3",        PlayerData[playerid][pKey3]);
    cache_get_value_name(0, "driving_lic_a_exp", PlayerData[playerid][pDrivingLicA_exp], 11);
    cache_get_value_name(0, "driving_lic_b_exp", PlayerData[playerid][pDrivingLicB_exp], 11);
    cache_get_value_name(0, "driving_lic_c_exp", PlayerData[playerid][pDrivingLicC_exp], 11);
    cache_get_value_name(0, "driving_lic_d_exp", PlayerData[playerid][pDrivingLicD_exp], 11);

    PlayerData[playerid][pLogged]  = true;
    PlayerData[playerid][pOnDuty]  = false;
    Player_RecalcSpawn(playerid);

    SetPlayerVirtualWorld(playerid, 0);
    SetPlayerColor(playerid, FactionColors[PlayerData[playerid][pFaction]]);
    Factions_SetPlayerIcons(playerid);
    Businesses_SetPlayerIcons(playerid);

    GivePlayerMoney(playerid, PlayerData[playerid][pMoney]);
    SetPlayerScore(playerid, PlayerData[playerid][pLevel]);

    SendClientMessage(playerid, COLOR_SUCCESS,
        C_SUCCESS"Success: "C_WHITE"You have logged in successfully!");
    SpawnPlayer(playerid);
    return 1;
}

// ============================================================
//  SALVARE DATE JUCATOR
// ============================================================
stock FullUpdatePlayer(playerid)
{
    if(!PlayerData[playerid][pLogged]) return;

    new licA[14], licB[14], licC[14], licD[14], facJoin[14];
    BuildDateSqlValue(PlayerData[playerid][pDrivingLicA_exp], licA, sizeof(licA));
    BuildDateSqlValue(PlayerData[playerid][pDrivingLicB_exp], licB, sizeof(licB));
    BuildDateSqlValue(PlayerData[playerid][pDrivingLicC_exp], licC, sizeof(licC));
    BuildDateSqlValue(PlayerData[playerid][pDrivingLicD_exp], licD, sizeof(licD));
    BuildDateSqlValueFromUnix(PlayerData[playerid][pFactionJoin], facJoin, sizeof(facJoin));

    new query[640];
    mysql_format(g_SQL, query, sizeof(query),
        "UPDATE `players` SET \
        `password`='%e', `level`=%d, `money`=%d, `bank`=%d, \
        `rp`=%d, `admin_level`=%d, `faction`=%d, `faction_rank`=%d, `faction_join`=%s, `house`=%d, `business`=%d, `spawn_type`=%d, \
        `key1`=%d, `key2`=%d, `key3`=%d, \
        `driving_lic_a_exp`=%s, `driving_lic_b_exp`=%s, `driving_lic_c_exp`=%s, `driving_lic_d_exp`=%s \
        WHERE `id`=%d",
        PlayerData[playerid][pPass],
        PlayerData[playerid][pLevel],
        PlayerData[playerid][pMoney],
        PlayerData[playerid][pBank],
        PlayerData[playerid][pRP],
        PlayerData[playerid][pAdminLevel],
        PlayerData[playerid][pFaction],
        PlayerData[playerid][pFactionRank],
        facJoin,
        PlayerData[playerid][pHouse],
        PlayerData[playerid][pBusiness],
        PlayerData[playerid][pSpawn],
        PlayerData[playerid][pKey1],
        PlayerData[playerid][pKey2],
        PlayerData[playerid][pKey3],
        licA, licB, licC, licD,
        PlayerData[playerid][pID]);
    mysql_tquery(g_SQL, query, "", "", 0);
}

stock UpdatePlayer(playerid, E_PLAYER_DATA:field)
{
    if(!PlayerData[playerid][pLogged]) return;

    new query[256];
    switch(field)
    {
        case pPass:
            mysql_format(g_SQL, query, sizeof(query),
                "UPDATE `players` SET `password`='%e' WHERE `id`=%d",
                PlayerData[playerid][pPass], PlayerData[playerid][pID]);

        case pLevel:
            mysql_format(g_SQL, query, sizeof(query),
                "UPDATE `players` SET `level`=%d WHERE `id`=%d",
                PlayerData[playerid][pLevel], PlayerData[playerid][pID]);

        case pMoney:
            mysql_format(g_SQL, query, sizeof(query),
                "UPDATE `players` SET `money`=%d WHERE `id`=%d",
                PlayerData[playerid][pMoney], PlayerData[playerid][pID]);

        case pBank:
            mysql_format(g_SQL, query, sizeof(query),
                "UPDATE `players` SET `bank`=%d WHERE `id`=%d",
                PlayerData[playerid][pBank], PlayerData[playerid][pID]);

        case pRP:
            mysql_format(g_SQL, query, sizeof(query),
                "UPDATE `players` SET `rp`=%d WHERE `id`=%d",
                PlayerData[playerid][pRP], PlayerData[playerid][pID]);

        case pAdminLevel:
            mysql_format(g_SQL, query, sizeof(query),
                "UPDATE `players` SET `admin_level`=%d WHERE `id`=%d",
                PlayerData[playerid][pAdminLevel], PlayerData[playerid][pID]);

        case pEmail:
            mysql_format(g_SQL, query, sizeof(query),
                "UPDATE `players` SET `email`='%e' WHERE `id`=%d",
                PlayerData[playerid][pEmail], PlayerData[playerid][pID]);

        case pFaction:
            mysql_format(g_SQL, query, sizeof(query),
                "UPDATE `players` SET `faction`=%d WHERE `id`=%d",
                PlayerData[playerid][pFaction], PlayerData[playerid][pID]);

        case pFactionRank:
            mysql_format(g_SQL, query, sizeof(query),
                "UPDATE `players` SET `faction_rank`=%d WHERE `id`=%d",
                PlayerData[playerid][pFactionRank], PlayerData[playerid][pID]);

        case pFactionJoin:
        {
            new facJoin[14];
            BuildDateSqlValueFromUnix(PlayerData[playerid][pFactionJoin], facJoin, sizeof(facJoin));
            mysql_format(g_SQL, query, sizeof(query),
                "UPDATE `players` SET `faction_join`=%s WHERE `id`=%d",
                facJoin, PlayerData[playerid][pID]);
        }

        case pHouse:
            mysql_format(g_SQL, query, sizeof(query),
                "UPDATE `players` SET `house`=%d WHERE `id`=%d",
                PlayerData[playerid][pHouse], PlayerData[playerid][pID]);

        case pBusiness:
            mysql_format(g_SQL, query, sizeof(query),
                "UPDATE `players` SET `business`=%d WHERE `id`=%d",
                PlayerData[playerid][pBusiness], PlayerData[playerid][pID]);

        case pSpawn:
            mysql_format(g_SQL, query, sizeof(query),
                "UPDATE `players` SET `spawn_type`=%d WHERE `id`=%d",
                PlayerData[playerid][pSpawn], PlayerData[playerid][pID]);

        case pKey1:
            mysql_format(g_SQL, query, sizeof(query),
                "UPDATE `players` SET `key1`=%d WHERE `id`=%d",
                PlayerData[playerid][pKey1], PlayerData[playerid][pID]);

        case pKey2:
            mysql_format(g_SQL, query, sizeof(query),
                "UPDATE `players` SET `key2`=%d WHERE `id`=%d",
                PlayerData[playerid][pKey2], PlayerData[playerid][pID]);

        case pKey3:
            mysql_format(g_SQL, query, sizeof(query),
                "UPDATE `players` SET `key3`=%d WHERE `id`=%d",
                PlayerData[playerid][pKey3], PlayerData[playerid][pID]);

        case pDrivingLicA_exp:
            mysql_format(g_SQL, query, sizeof(query),
                "UPDATE `players` SET `driving_lic_a_exp`='%s' WHERE `id`=%d",
                PlayerData[playerid][pDrivingLicA_exp], PlayerData[playerid][pID]);

        case pDrivingLicB_exp:
            mysql_format(g_SQL, query, sizeof(query),
                "UPDATE `players` SET `driving_lic_b_exp`='%s' WHERE `id`=%d",
                PlayerData[playerid][pDrivingLicB_exp], PlayerData[playerid][pID]);

        case pDrivingLicC_exp:
            mysql_format(g_SQL, query, sizeof(query),
                "UPDATE `players` SET `driving_lic_c_exp`='%s' WHERE `id`=%d",
                PlayerData[playerid][pDrivingLicC_exp], PlayerData[playerid][pID]);

        case pDrivingLicD_exp:
            mysql_format(g_SQL, query, sizeof(query),
                "UPDATE `players` SET `driving_lic_d_exp`='%s' WHERE `id`=%d",
                PlayerData[playerid][pDrivingLicD_exp], PlayerData[playerid][pID]);

        default: return;
    }
    mysql_tquery(g_SQL, query, "", "", 0);
}

// ============================================================
//  GAMEMODE
// ============================================================
main()
{
    print("\n----------------------------------");
    print("  NostalgiaRP by Nikolas Maduro  \n");
    print("----------------------------------\n");
}

public OnGameModeInit()
{
    SetGameModeText("N-RP");
    ShowPlayerMarkers(0);
    ShowNameTags(1);
    AllowAdminTeleport(1);

    AddPlayerClass(294, 2859.2053, 1290.6671, 11.3906, 88.9431, 0, 0, 0, 0, 0, 0);

    AddStaticVehicle(559, 2794.7180, 1295.5698, 10.3750, 180.9595, 3, 8);
    AddStaticVehicle(565, 2791.6089, 1295.4680, 10.3748, 179.1351, 6, 8);
    AddStaticVehicle(541, 2785.1243, 1295.4415, 10.3750, 178.1488, 8, 13);

    g_TrainID = AddStaticVehicle(538, 2864.7500, 1329.6376, 12.1256, 0.0009,0, 0); // tren

    // Biciclete de inchiriat
    g_RentBikeVehicle[0] = AddStaticVehicle(510, 2840.0, 1287.0, 11.0, 45.5, 6, 6);
    g_RentBikeVehicle[1] = AddStaticVehicle(510, 2845.0, 1287.0, 11.0, 45.0, 6, 6);
    g_RentBikeVehicle[2] = AddStaticVehicle(510, 2850.0, 1287.0, 11.0, 45.0, 6, 6);
    g_RentBikeVehicle[3] = AddStaticVehicle(510, 2855.0, 1287.0, 11.0, 45.0, 6, 6);
    g_RentBikeVehicle[4] = AddStaticVehicle(510, 2840.0, 1286.0, 11.0, 45.0, 6, 6);

    // Masini de inchiriat piramida
    g_RentCarVehicle[0] = AddStaticVehicle(545, 2220.0, 1278.0, 10.6, 90.0, 6, 6);
    g_RentCarVehicle[1] = AddStaticVehicle(565, 2200.0, 1283.0, 10.6, 90.0, 6, 6);
    g_RentCarVehicle[2] = AddStaticVehicle(477, 2200.0, 1288.0, 10.6, 90.0, 6, 6);
    g_RentCarVehicle[3] = AddStaticVehicle(559, 2200.0, 1293.0, 10.6, 90.0, 6, 6);

    // Masini de inchiriat RentCarDMVDesert
    g_RentCarDesertVehicle[0] = AddStaticVehicle(471, -17.0106, 2325.4922, 23.6235, 0.5196, 6, 6);
    g_RentCarDesertVehicle[1] = AddStaticVehicle(471, -19.7723, 2325.7161, 23.6209, 359.8743, 6, 6);
    g_RentCarDesertVehicle[2] = AddStaticVehicle(468, -26.1589, 2324.3223, 23.8033, 2.3033, 6, 6);
    g_RentCarDesertVehicle[3] = AddStaticVehicle(468, -28.8546, 2324.5056, 23.8053, 2.8901, 6, 6);

    // Motociclete scoala (examen categoria A)
    g_ExamACar[0] = AddStaticVehicle(468, -13.5, 2340.0, 23.8097, 91.1855, 226, 226);
    g_ExamACar[1] = AddStaticVehicle(468, -13.5, 2337.0, 23.8096, 90.2720, 226, 226);
    g_ExamACar[2] = AddStaticVehicle(468, -13.5, 2334.0, 23.8133, 91.6934, 226, 226);

    // Masini scoala (examen categoria B)
    g_ExamBCar[0] = AddStaticVehicle(480, 2215.0, 1280.0, 10.5, 270.0, 226, 226);
    g_ExamBCar[1] = AddStaticVehicle(480, 2215.0, 1285.0, 10.5, 270.0, 226, 226);
    g_ExamBCar[2] = AddStaticVehicle(480, 2215.0, 1290.0, 10.5, 270.0, 226, 226);

    // Capete tractor + remorci scoala (examen categoria C)
    g_ExamCTruck[0]   = AddStaticVehicle(403, 1379.0, 1025.0, 11.5, 240.0, 226, 226);
    g_ExamCTruck[1]   = AddStaticVehicle(403, 1387.0, 1027.0, 11.5, 240.0, 226, 226);
    g_ExamCTrailer[0] = AddStaticVehicle(450, 1389.0, 1043.0, 11.5, 270.0, 226, 226); // scade 1 la X daca remorca nu se aliniaza
    g_ExamCTrailer[1] = AddStaticVehicle(450, 1389.0, 1035.0, 11.5, 270.0, 226, 226); // scade 1 la X daca remorca nu se aliniaza

    // 3D Text:
    Create3DTextLabel("[ Vehicle Inspection Service ]\n[ Use /vitp ]\n[ Price: 750$ ]", COLOR_WHITE,
        ITP_LOC_X, ITP_LOC_Y, ITP_LOC_Z - 1.0, 25.0, 0, 0);

    Create3DTextLabel("[ Vehicle Inspection Service ]\n[ Use /vplate ]\n[ Price: 250$ ]", COLOR_WHITE,
        PLATE_LOC_X, PLATE_LOC_Y, PLATE_LOC_Z - 1.0, 25.0, 0, 0);

    CreatePickup(1210, 1, EXAMA_LOC_X, EXAMA_LOC_Y, EXAMA_LOC_Z, -1);
    Create3DTextLabel("[ Category A Exam ]\n[ /examA ]", COLOR_WHITE,
        EXAMA_LOC_X, EXAMA_LOC_Y, EXAMA_LOC_Z - 0.0, 25.0, 0, 0);

    CreatePickup(1210, 1, EXAMB_LOC_X, EXAMB_LOC_Y, EXAMB_LOC_Z, -1);
    Create3DTextLabel("[ Category B Exam ]\n[ /examB ]", COLOR_WHITE,
        EXAMB_LOC_X, EXAMB_LOC_Y, EXAMB_LOC_Z - 0.0, 25.0, 0, 0);

    CreatePickup(1210, 1, EXAMC_LOC_X, EXAMC_LOC_Y, EXAMC_LOC_Z, -1);
    Create3DTextLabel("[ Category C Exam ]\n[ /examC ]", COLOR_WHITE,
        EXAMC_LOC_X, EXAMC_LOC_Y, EXAMC_LOC_Z - 0.0, 25.0, 0, 0);

	// HQ RAR
    CreateDynamicObject(19817, 932.00000, 2081.00000, 9.70000,   0.00000, 0.00000, 90.00000);
	CreateDynamicObject(19817, 932.00000, 2074.00000, 9.70000,   0.00000, 0.00000, 90.00000);
	CreateDynamicObject(19817, 932.00000, 2067.00000, 9.70000,   0.00000, 0.00000, 90.00000);
	CreateDynamicObject(19817, 932.00000, 2060.00000, 9.70000,   0.00000, 0.00000, 90.00000);
	CreateDynamicObject(19899, 934.00000, 2063.50000, 9.79790,   0.00000, 0.00000, 0.00000);
	CreateDynamicObject(19899, 934.00000, 2070.50000, 9.79790,   0.00000, 0.00000, 0.00000);
	CreateDynamicObject(19899, 934.00000, 2077.50000, 9.79790,   0.00000, 0.00000, 0.00000);
	CreateDynamicObject(19966, 925.00000, 2067.00000, 10.00000,   0.00000, 0.00000, 90.00000);
	CreateDynamicObject(19966, 925.00000, 2060.00000, 10.00000,   0.00000, 0.00000, 90.00000);
	CreateDynamicObject(19966, 925.00000, 2074.00000, 10.00000,   0.00000, 0.00000, 90.00000);
	CreateDynamicObject(19966, 925.00000, 2081.00000, 10.00000,   0.00000, 0.00000, 90.00000);
	CreateDynamicObject(19121, 932.00000, 2060.00000, 10.00000,   0.00000, 0.00000, 0.00000);
	CreateDynamicObject(19121, 932.00000, 2067.00000, 10.00000,   0.00000, 0.00000, 0.00000);
	CreateDynamicObject(19121, 932.00000, 2073.00000, 10.00000,   0.00000, 0.00000, 0.00000);
	CreateDynamicObject(19121, 932.00000, 2081.00000, 10.00000,   0.00000, 0.00000, 0.00000);
	CreateDynamicObject(2789, 925.00000, 2063.50000, 14.00000,   0.00000, 0.00000, 90.00000);
	CreateDynamicObject(2789, 925.00000, 2070.50000, 14.00000,   0.00000, 0.00000, 90.00000);
	CreateDynamicObject(2789, 925.00000, 2077.50000, 14.00000,   0.00000, 0.00000, 90.00000);
	CreateDynamicObject(3881, 981.06696, 2084.04980, 11.58000,   0.00000, 0.00000, 180.00000);
	CreateDynamicObject(763, 988.02002, 2053.74072, 9.76790,   0.00000, 0.00000, 0.00000);
	CreateDynamicObject(763, 998.00000, 2120.18652, 9.76790,   0.00000, 0.00000, 70.00000);
	CreateDynamicObject(763, 998.00000, 2145.46509, 9.76790,   0.00000, 0.00000, 20.00000);
	CreateDynamicObject(3509, 996.15002, 2207.34229, 9.77720,   0.00000, 0.00000, 120.00000);
	CreateDynamicObject(3509, 995.44269, 2233.48462, 9.77720,   0.00000, 0.00000, 40.00000);
	CreateDynamicObject(3509, 996.01624, 2217.32813, 9.77720,   0.00000, 0.00000, 20.00000);
	CreateDynamicObject(3509, 986.14801, 2206.09521, 9.77720,   0.00000, 0.00000, 60.00000);
	CreateDynamicObject(1597, 972.00000, 2077.00000, 12.28000,   0.00000, 0.00000, 90.00000);
	CreateDynamicObject(1597, 962.00000, 2078.00000, 12.28000,   0.00000, 0.00000, 90.00000);
	CreateDynamicObject(1597, 972.00000, 2068.00000, 12.28000,   0.00000, 0.00000, 90.00000);
	CreateDynamicObject(1597, 962.00000, 2066.00000, 12.28000,   0.00000, 0.00000, 90.00000);
	CreateDynamicObject(1597, 953.00000, 2061.50000, 12.28000,   0.00000, 0.00000, -45.00000);
	CreateDynamicObject(1597, 953.00000, 2083.00000, 12.28000,   0.00000, 0.00000, 45.00000);



    for(new i = 0; i <= MAX_FACTIONS; i++) g_FactionLabel[i] = Text3D:INVALID_3DTEXT_ID;

    for(new i = 0; i < MAX_HOUSES; i++)
    {
        g_HousePickup[i] = -1;
        g_HouseLabel[i] = Text3D:INVALID_3DTEXT_ID;
    }

    for(new i = 0; i < MAX_BUSINESSES; i++)
    {
        g_BusinessPickup[i] = -1;
        g_BusinessLabel[i] = Text3D:INVALID_3DTEXT_ID;
    }

    for(new i = 0; i < MAX_TURFS; i++) g_TurfZone[i] = -1;

    for(new i = 0; i < MAX_VFACTION_VEHICLES; i++) g_VFactionVehicle[i] = -1;
    for(new i = 0; i < MAX_VEHICLES; i++) g_VehicleFactionOwner[i] = 0;
    for(new i = 0; i < MAX_FIRES; i++) FireData[i][fireActive] = false;
    for(new i = 0; i < MAX_PERSONAL_VEHICLES; i++)
    {
        g_PVehicleVehicle[i] = -1;
        g_PVehicleLabel[i] = Text3D:INVALID_3DTEXT_ID;
    }
    for(new i = 0; i < MAX_VEHICLES; i++) g_VehicleToPVIndex[i] = -1;

    DB_Init();
    Factions_Load();
    Houses_Load();
    Businesses_Load();
    Turfs_Load();
    VehiclesFaction_Load();
    PVehicles_Load();
    PayDay_Load();

    SetTimer("PayDay_Check", 60000, true);
    SetTimer("Fires_Tick", 1000, true);
    SetTimer("Radar_Tick", RADAR_TICK, true);

    return 1;
}

public OnGameModeExit()
{
    mysql_close(g_SQL);
    return 1;
}

public OnPlayerConnect(playerid)
{
    g_InviteFaction[playerid] = 0;
    g_InviteInviter[playerid] = 0;

    g_PendingFineAmount[playerid] = 0;
    g_PendingFineOfficer[playerid] = 0;
    g_PendingFineReason[playerid][0] = EOS;

    g_RadarActive[playerid]    = false;
    g_RadarFlaggedBy[playerid] = -1;

    PlayerData[playerid][pID]         = 0;
    PlayerData[playerid][pLevel]      = 1;
    PlayerData[playerid][pMoney]      = 0;
    PlayerData[playerid][pBank]       = 0;
    PlayerData[playerid][pRP]         = 0;
    PlayerData[playerid][pAdminLevel] = 0;
    PlayerData[playerid][pFaction]    = 0;
    PlayerData[playerid][pFactionRank]= 1;
    PlayerData[playerid][pFactionJoin]= 0;
    PlayerData[playerid][pHouse]      = 999;
    PlayerData[playerid][pBusiness]   = 999;
    PlayerData[playerid][pSpawn]      = 1;
    PlayerData[playerid][pSpawnX]     = 2859.2053;
    PlayerData[playerid][pSpawnY]     = 1290.6671;
    PlayerData[playerid][pSpawnZ]     = 11.3906;
    PlayerData[playerid][pKey1]       = 0;
    PlayerData[playerid][pKey2]       = 0;
    PlayerData[playerid][pKey3]       = 0;
    PlayerData[playerid][pDrivingLicA_exp][0] = EOS;
    PlayerData[playerid][pDrivingLicB_exp][0] = EOS;
    PlayerData[playerid][pDrivingLicC_exp][0] = EOS;
    PlayerData[playerid][pDrivingLicD_exp][0] = EOS;
    PlayerData[playerid][pLogged]     = false;
    PlayerData[playerid][pRegistered] = false;
    PlayerData[playerid][pOnDuty]     = false;
    PlayerData[playerid][pPass][0]    = EOS;
    PlayerData[playerid][pEmail][0]   = EOS;

    GetPlayerName(playerid, PlayerData[playerid][pName], 24);
    SetPlayerVirtualWorld(playerid, -1);

    GameTextForPlayer(playerid, "~g~Welcome to\n~y~Old is Gold", 5000, 5);

    Turfs_ShowToPlayer(playerid);

    Player_CheckExists(playerid);
    return 1;
}

public OnPlayerCommandText(playerid, cmdtext[])
{
    new idx;
    new cmd[256];
    cmd = strtok(cmdtext, idx);

    // ---- /register [parola] ----
    if(strcmp(cmd, "/register", true) == 0)
    {
        if(PlayerData[playerid][pRegistered])
            return SendClientMessage(playerid, COLOR_ERROR,
                C_ERROR"Error: "C_WHITE"You are already registered."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new pass[64];
        strmid(pass, cmdtext, idx, strlen(cmdtext), 64);

        if(!strlen(pass))
            return SendClientMessage(playerid, COLOR_INFO,
                C_INFO"Info: "C_WHITE"Use "C_INFO"/register [password]"C_WHITE"."), 1;

        Player_Register(playerid, pass);
        return 1;
    }

    // ---- /login [parola] ----
    if(strcmp(cmd, "/login", true) == 0)
    {
        if(!PlayerData[playerid][pRegistered])
            return SendClientMessage(playerid, COLOR_ERROR,
                C_ERROR"Error: "C_WHITE"You are not registered. Use "C_INFO"/register [password]"C_WHITE"."), 1;

        if(PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR,
                C_ERROR"Error: "C_WHITE"You are already logged in."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new pass[64];
        strmid(pass, cmdtext, idx, strlen(cmdtext), 64);

        if(!strlen(pass))
            return SendClientMessage(playerid, COLOR_INFO,
                C_INFO"Info: "C_WHITE"Use "C_INFO"/login [password]"C_WHITE"."), 1;

        Player_Login(playerid, pass);
        return 1;
    }

    // ---- /stats ----
    if(strcmp(cmd, "/stats", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR,
                C_ERROR"Error: "C_WHITE"You must be logged in to view your stats."), 1;

        new line[256];
        new email[80] = "not set";
        if(strlen(PlayerData[playerid][pEmail]))
            format(email, sizeof(email), "%s", PlayerData[playerid][pEmail]);

        new fid = PlayerData[playerid][pFaction];
        new colorcode[9], fname[32];
        if(fid > 0 && fid <= MAX_FACTIONS)
        {
            GetFactionColorCode(fid, colorcode, sizeof(colorcode));
            format(fname, sizeof(fname), "%s%s (%d)", colorcode, FactionData[fid][fName], PlayerData[playerid][pFactionRank]);
        }
        else fname = "No faction";

        SendClientMessage(playerid, COLOR_INFO, "\n\n__ Stats _____________________________________________________");
        format(line, sizeof(line), "[Account] Name: %s | Email: %s | Level: %d | RP: %d | Faction: %s",
            PlayerData[playerid][pName],
            email,
            PlayerData[playerid][pLevel],
            PlayerData[playerid][pRP],
            fname
        );
        SendClientMessage(playerid, COLOR_WHITE, line);

        format(line, sizeof(line), "[Finance] Cash: $%d | Bank: $%d | House: %d | Keys: %d | %d | %d",
            PlayerData[playerid][pMoney],
            PlayerData[playerid][pBank],
            PlayerData[playerid][pHouse],
            PlayerData[playerid][pKey1],
            PlayerData[playerid][pKey2],
            PlayerData[playerid][pKey3]);
        SendClientMessage(playerid, COLOR_WHITE, line);

        if(PlayerData[playerid][pAdminLevel] > 0)
        {
            format(line, sizeof(line), "Admin level: %d",
                PlayerData[playerid][pAdminLevel]);
            SendClientMessage(playerid, COLOR_WHITE, line);
        }

        SendClientMessage(playerid, COLOR_INFO, "________________________________________________________________");
        return 1;
    }

    // ---- /veh [nume] ----
    if(strcmp(cmd, "/veh", true) == 0)
    {
        if(PlayerData[playerid][pAdminLevel] < 3)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have access. Requires admin level 3."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new vehname[64];
        strmid(vehname, cmdtext, idx, strlen(cmdtext), 32);

        if(!strlen(vehname))
            return SendClientMessage(playerid, COLOR_INFO,
                C_INFO"Info: "C_WHITE"Use "C_INFO"/veh [vehicle name]"C_WHITE". Ex: "C_INFO"/veh Infernus"C_WHITE"."), 1;

        new model = GetVehicleModelByName(vehname);
        if(model == -1)
        {
            new errmsg[128];
            format(errmsg, sizeof(errmsg), C_ERROR"Error: "C_WHITE"Vehicle \""C_INFO"%s"C_WHITE"\" not found.", vehname);
            return SendClientMessage(playerid, COLOR_ERROR, errmsg), 1;
        }

        new Float:x, Float:y, Float:z, Float:angle;
        GetPlayerPos(playerid, x, y, z);
        GetPlayerFacingAngle(playerid, angle);

        new vehid = CreateVehicle(model, x + 3.0, y, z, angle, -1, -1, -1);
        PutPlayerInVehicle(playerid, vehid, 0);

        new realName[24];
        GetVehicleModelName(model, realName, sizeof(realName));

        new msg[128];
        format(msg, sizeof(msg), C_SUCCESS"Success: "C_WHITE"You spawned a "C_INFO"%s"C_WHITE" (model %d).", realName, model);
        SendClientMessage(playerid, COLOR_SUCCESS, msg);
        return 1;
    }

    // ---- /rac (respawn all cars) ----
    if(strcmp(cmd, "/rac", true) == 0)
    {
        if(PlayerData[playerid][pAdminLevel] < 3)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have access. Requires admin level 3."), 1;

        for(new i = 1; i < MAX_VEHICLES; i++)
            SetVehicleToRespawn(i);

        SendClientMessage(playerid, COLOR_SUCCESS,
            C_SUCCESS"Success: "C_WHITE"All vehicles have been respawned.");
        return 1;
    }

    // ---- /createfire ----
    if(strcmp(cmd, "/createfire", true) == 0)
    {
        if(PlayerData[playerid][pAdminLevel] < 2)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have access. Requires admin level 2."), 1;

        new fidx = Fires_FindFree();
        if(fidx == -1)
            return SendClientMessage(playerid, COLOR_ERROR,
                C_ERROR"Error: "C_WHITE"Limit of "C_INFO#MAX_FIRES C_WHITE" simultaneous fires reached."), 1;

        new Float:fx, Float:fy, Float:fz;
        GetPlayerPos(playerid, fx, fy, fz);

        FireData[fidx][fireActive]   = true;
        FireData[fidx][fireX]        = fx;
        FireData[fidx][fireY]        = fy;
        FireData[fidx][fireZ]        = fz;
        FireData[fidx][fireRequired] = 5 + random(6); // 5-10 secunde
        FireData[fidx][fireProgress] = 0;
        FireData[fidx][fireVisualTick] = 0;
        for(new i = 0; i < MAX_PLAYERS; i++) g_FireInRange[fidx][i] = false;

        CreateExplosion(fx, fy, fz-1, 1, 0.0);

        new fmsg[160];
        format(fmsg, sizeof(fmsg),
            "[SMURD] "C_WHITE"A fire has broken out! Take the firetruck and put it out with water.");

        for(new i = 0; i < MAX_PLAYERS; i++)
        {
            if(!IsPlayerConnected(i) || !PlayerData[i][pLogged] || PlayerData[i][pFaction] != FACTION_SMURD) continue;
            if(!PlayerData[i][pOnDuty]) continue;
            SendClientMessage(i, COLOR_INFO, fmsg);
            SetPlayerMapIcon(i, FIRE_ICON_SLOT_BASE + fidx, fx, fy, fz, FIRE_MAPICON_ID, 0, MAPICON_LOCAL);
        }

        SendClientMessage(playerid, COLOR_SUCCESS, C_SUCCESS"[ADM] Success: "C_WHITE"Fire created.");
        return 1;
    }

    // ---- /f [mesaj] (chat factiune) ----
    if(strcmp(cmd, "/f", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        new fid = PlayerData[playerid][pFaction];
        if(fid < 1 || fid > MAX_FACTIONS)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You are not part of a faction."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new text[128];
        strmid(text, cmdtext, idx, strlen(cmdtext), 128);

        if(!strlen(text))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/f [message]"C_WHITE"."), 1;

        new colorcode[9];
        GetFactionColorCode(fid, colorcode, sizeof(colorcode));

        new fmsg[256];
        format(fmsg, sizeof(fmsg), C_INFO"[fChat] "C_WHITE"%s%s "C_INFO"(rank %d)"C_WHITE": %s",
            colorcode, PlayerData[playerid][pName], PlayerData[playerid][pFactionRank], text);

        for(new i = 0; i < MAX_PLAYERS; i++)
        {
            if(IsPlayerConnected(i) && PlayerData[i][pLogged] && PlayerData[i][pFaction] == fid)
                SendClientMessage(i, COLOR_WHITE, fmsg);
        }
        return 1;
    }

    // ---- /finvite [targetid] ----
    if(strcmp(cmd, "/finvite", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        new fid = PlayerData[playerid][pFaction];
        if(fid < 1 || fid > MAX_FACTIONS)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You are not part of a faction."), 1;

        if(PlayerData[playerid][pFactionRank] < 4)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Requires rank 4 or 5 in the faction."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new p1[8];
        strmid(p1, cmdtext, idx, strlen(cmdtext), 8);

        if(!strlen(p1))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/finvite [playerid]"C_WHITE"."), 1;

        new targetid = strval(p1);
        if(!IsPlayerConnected(targetid) || !PlayerData[targetid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"The player is not connected."), 1;

        if(targetid == playerid)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You can't invite yourself."), 1;

        if(PlayerData[targetid][pFaction] != 0)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"The player is already part of a faction."), 1;

        new Float:px, Float:py, Float:pz;
        GetPlayerPos(playerid, px, py, pz);
        if(!IsPlayerInRangeOfPoint(targetid, FINVITE_RANGE, px, py, pz))
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"The player must be within 15m."), 1;

        g_InviteFaction[targetid] = fid;
        g_InviteInviter[targetid] = playerid;

        new fmsg2[160];
        format(fmsg2, sizeof(fmsg2), C_SUCCESS"Success: "C_WHITE"You invited "C_INFO"%s"C_WHITE" to the faction "C_INFO"%s"C_WHITE".",
            PlayerData[targetid][pName], FactionData[fid][fName]);
        SendClientMessage(playerid, COLOR_SUCCESS, fmsg2);

        new fcolor[9];
        GetFactionColorCode(fid, fcolor, sizeof(fcolor));

        format(fmsg2, sizeof(fmsg2),
            C_WHITE"Player "C_INFO"%s"C_WHITE" invited you to %s%s"C_WHITE". Type "C_INFO"/accept finvite %d"C_WHITE" to accept the invitation.",
            PlayerData[playerid][pName], fcolor, FactionData[fid][fName], playerid);
        SendClientMessage(targetid, COLOR_WHITE, fmsg2);
        return 1;
    }

    // ---- /accept finvite [playerid] / /accept fine [playerid] ----
    if(strcmp(cmd, "/accept", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new subStart = idx;
        while(cmdtext[idx] > ' ') idx++;
        new sub[16];
        strmid(sub, cmdtext, subStart, idx, 16);
        while(cmdtext[idx] == ' ') idx++;
        new p1[8];
        strmid(p1, cmdtext, idx, strlen(cmdtext), 8);

        if(!strlen(p1) || (strcmp(sub, "finvite", true) != 0 && strcmp(sub, "fine", true) != 0))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/accept finvite [playerid]"C_WHITE" or "C_INFO"/accept fine [playerid]"C_WHITE"."), 1;

        if(strcmp(sub, "fine", true) == 0)
        {
            new officerid = strval(p1);

            if(g_PendingFineAmount[playerid] == 0 || g_PendingFineOfficer[playerid] != officerid)
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have a pending fine from this player."), 1;

            if(!IsPlayerConnected(officerid) || !PlayerData[officerid][pLogged])
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"The officer is no longer connected."), 1;

            new Float:ox, Float:oy, Float:oz;
            GetPlayerPos(officerid, ox, oy, oz);
            if(!IsPlayerInRangeOfPoint(playerid, FINE_RANGE, ox, oy, oz))
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be within 10m of the officer who fined you."), 1;

            new amount = g_PendingFineAmount[playerid];
            new reason[128];
            format(reason, 128, "%s", g_PendingFineReason[playerid]);

            if(PlayerData[playerid][pMoney] < amount)
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have enough money to pay this fine."), 1;

            PlayerData[playerid][pMoney] -= amount;
            GivePlayerMoney(playerid, -amount);
            UpdatePlayer(playerid, pMoney);

            PlayerData[officerid][pMoney] += amount;
            GivePlayerMoney(officerid, amount);
            UpdatePlayer(officerid, pMoney);

            g_PendingFineAmount[playerid]  = 0;
            g_PendingFineOfficer[playerid] = 0;
            g_PendingFineReason[playerid][0] = EOS;

            new amsg2[160];
            format(amsg2, sizeof(amsg2), C_SUCCESS"Success: "C_WHITE"You paid the "C_INFO"$%d"C_WHITE" fine for: "C_INFO"%s"C_WHITE".", amount, reason);
            SendClientMessage(playerid, COLOR_SUCCESS, amsg2);

            format(amsg2, sizeof(amsg2), C_SUCCESS"Success: "C_WHITE"%s"C_WHITE" paid the "C_INFO"$%d"C_WHITE" fine you issued.", PlayerData[playerid][pName], amount);
            SendClientMessage(officerid, COLOR_SUCCESS, amsg2);
            return 1;
        }

        new inviterid = strval(p1);

        if(g_InviteFaction[playerid] == 0 || g_InviteInviter[playerid] != inviterid)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have a valid invitation from this player."), 1;

        if(!IsPlayerConnected(inviterid) || !PlayerData[inviterid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"The player who invited you is no longer connected."), 1;

        new Float:ix, Float:iy, Float:iz;
        GetPlayerPos(inviterid, ix, iy, iz);
        if(!IsPlayerInRangeOfPoint(playerid, FINVITE_RANGE, ix, iy, iz))
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be within 15m of the player who invited you."), 1;

        new fid = g_InviteFaction[playerid];

        if(PlayerData[playerid][pFaction] != 0)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You are already part of a faction."), 1;

        PlayerData[playerid][pFaction]     = fid;
        PlayerData[playerid][pFactionRank] = 1;
        PlayerData[playerid][pFactionJoin] = gettime();
        SetPlayerColor(playerid, FactionColors[fid]);
        Factions_SetPlayerIcons(playerid);

        FactionData[fid][fMembers]++;

        g_InviteFaction[playerid] = 0;
        g_InviteInviter[playerid] = 0;

        new facJoin[14];
        BuildDateSqlValueFromUnix(PlayerData[playerid][pFactionJoin], facJoin, sizeof(facJoin));

        new q[256];
        mysql_format(g_SQL, q, sizeof(q),
            "UPDATE `players` SET `faction`=%d, `faction_rank`=1, `faction_join`=%s WHERE `id`=%d",
            fid, facJoin, PlayerData[playerid][pID]);
        mysql_tquery(g_SQL, q, "", "", 0);

        mysql_format(g_SQL, q, sizeof(q), "UPDATE `factions` SET `members`=%d WHERE `id`=%d",
            FactionData[fid][fMembers], fid);
        mysql_tquery(g_SQL, q, "", "", 0);

        new amsg[160];
        format(amsg, sizeof(amsg), C_SUCCESS"Success: "C_WHITE"You joined the faction "C_INFO"%s"C_WHITE"!", FactionData[fid][fName]);
        SendClientMessage(playerid, COLOR_SUCCESS, amsg);

        format(amsg, sizeof(amsg), C_INFO"Info: "C_WHITE"%s"C_WHITE" accepted your invitation and joined the faction.", PlayerData[playerid][pName]);
        SendClientMessage(inviterid, COLOR_INFO, amsg);
        return 1;
    }

    // ---- /fmembers ----
    if(strcmp(cmd, "/fmembers", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        new fid = PlayerData[playerid][pFaction];
        if(fid < 1 || fid > MAX_FACTIONS)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You are not part of a faction."), 1;

        new colorcode[9];
        GetFactionColorCode(fid, colorcode, sizeof(colorcode));

        SendClientMessage(playerid, COLOR_INFO, C_INFO"_____ Faction Members (online) ____________________");

        for(new rank = 1; rank <= 5; rank++)
        {
            new line[256];
            format(line, sizeof(line), "%sRank %d"C_WHITE": ", colorcode, rank);

            new bool:any = false;
            for(new i = 0; i < MAX_PLAYERS; i++)
            {
                if(!IsPlayerConnected(i) || !PlayerData[i][pLogged]) continue;
                if(PlayerData[i][pFaction] != fid || PlayerData[i][pFactionRank] != rank) continue;

                if(any) strcat(line, ", ");
                strcat(line, PlayerData[i][pName]);
                any = true;
            }

            if(any) SendClientMessage(playerid, COLOR_WHITE, line);
        }

        SendClientMessage(playerid, COLOR_INFO, C_INFO"_____________________________________________________");
        return 1;
    }

    // ---- /fbank ----
    if(strcmp(cmd, "/fbank", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        new fid = PlayerData[playerid][pFaction];
        if(fid < 1 || fid > MAX_FACTIONS)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You are not part of a faction."), 1;

        if(PlayerData[playerid][pFactionRank] < 4)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Requires rank 4 or higher."), 1;

        new bmsg[128];
        format(bmsg, sizeof(bmsg), C_INFO"Info: "C_WHITE"The faction "C_INFO"%s"C_WHITE" account has "C_INFO"$%d"C_WHITE".",
            FactionData[fid][fName], FactionData[fid][fBank]);
        SendClientMessage(playerid, COLOR_INFO, bmsg);
        return 1;
    }

    // ---- /fbankwithdraw [suma] ----
    if(strcmp(cmd, "/fbankwithdraw", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        new fid = PlayerData[playerid][pFaction];
        if(fid < 1 || fid > MAX_FACTIONS)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You are not part of a faction."), 1;

        if(PlayerData[playerid][pFactionRank] < 5)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Requires rank 5 (Lead)."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new p1[16];
        strmid(p1, cmdtext, idx, strlen(cmdtext), 16);

        if(!strlen(p1))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/fbankwithdraw [amount]"C_WHITE"."), 1;

        new amount = strval(p1);
        if(amount <= 0)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Invalid amount."), 1;

        if(amount > FactionData[fid][fBank])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"The faction doesn't have enough money."), 1;

        FactionData[fid][fBank] -= amount;
        PlayerData[playerid][pMoney] += amount;
        GivePlayerMoney(playerid, amount);
        UpdatePlayer(playerid, pMoney);

        new q[128];
        mysql_format(g_SQL, q, sizeof(q), "UPDATE `factions` SET `bank`=%d WHERE `id`=%d", FactionData[fid][fBank], fid);
        mysql_tquery(g_SQL, q, "", "", 0);

        new wmsg[128];
        format(wmsg, sizeof(wmsg), C_SUCCESS"Success: "C_WHITE"You withdrew "C_INFO"$%d"C_WHITE" from the faction account.", amount);
        SendClientMessage(playerid, COLOR_SUCCESS, wmsg);
        return 1;
    }

    // ---- /fsetrank [playerid] [rank 1-5] ----
    if(strcmp(cmd, "/fsetrank", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        new fid = PlayerData[playerid][pFaction];
        if(fid < 1 || fid > MAX_FACTIONS)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You are not part of a faction."), 1;

        if(PlayerData[playerid][pFactionRank] < 5)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Requires rank 5 (Lead)."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new p1[8], p2[8];
        strmid(p1, cmdtext, idx, strlen(cmdtext), 8);
        new targetid = strval(p1);
        while(cmdtext[idx] > ' ') idx++;
        while(cmdtext[idx] == ' ') idx++;
        strmid(p2, cmdtext, idx, strlen(cmdtext), 8);

        if(!strlen(p1) || !strlen(p2))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/fsetrank [playerid] [rank 1-5]"C_WHITE"."), 1;

        new newRank = strval(p2);
        if(newRank < 1 || newRank > 5)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Invalid rank (1-5)."), 1;

        if(!IsPlayerConnected(targetid) || !PlayerData[targetid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"The player is not connected."), 1;

        if(PlayerData[targetid][pFaction] != fid)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"The player is not part of your faction."), 1;

        PlayerData[targetid][pFactionRank] = newRank;
        UpdatePlayer(targetid, pFactionRank);

        new rmsg[128];
        format(rmsg, sizeof(rmsg), C_SUCCESS"Success: "C_INFO"%s"C_WHITE"'s rank was changed to "C_INFO"%d"C_WHITE".",
            PlayerData[targetid][pName], newRank);
        SendClientMessage(playerid, COLOR_SUCCESS, rmsg);

        format(rmsg, sizeof(rmsg), C_INFO"Info: "C_WHITE"Your rank in the faction was changed to "C_INFO"%d"C_WHITE" by the leader.", newRank);
        SendClientMessage(targetid, COLOR_INFO, rmsg);
        return 1;
    }

    // ---- /fhelp ----
    if(strcmp(cmd, "/fhelp", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        new fid = PlayerData[playerid][pFaction];
        if(fid < 1 || fid > MAX_FACTIONS)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You are not part of a faction."), 1;

        new rank = PlayerData[playerid][pFactionRank];

        SendClientMessage(playerid, COLOR_INFO, C_INFO"_____ Faction Commands ____________________");
        SendClientMessage(playerid, COLOR_WHITE, C_INFO"[Rank 1+] "C_WHITE"/f [message], /fmembers, /fhelp");

        if(fid >= 1 && fid <= 3)
            SendClientMessage(playerid, COLOR_WHITE, C_INFO"[Rank 1+] "C_WHITE"/duty");

        if(rank >= 4)
            SendClientMessage(playerid, COLOR_WHITE, C_INFO"[Rank 4+] "C_WHITE"/finvite [playerid], /fbank");

        if(rank >= 5)
            SendClientMessage(playerid, COLOR_WHITE, C_INFO"[Rank 5] "C_WHITE"/fbankwithdraw [amount], /fsetrank [playerid] [rank 1-5]");

        if(fid == FACTION_RAR)
            SendClientMessage(playerid, COLOR_WHITE, C_INFO"[RAR, On-Duty] "C_WHITE"/inspectcar [playerid], /fine [playerid] [amount] [reason], /m [playerid]");

        if(fid == FACTION_POLICE && rank >= 2)
            SendClientMessage(playerid, COLOR_WHITE, C_INFO"[Police, Rank 2+] "C_WHITE"/installradar [speedLimit], /removeradar");

        SendClientMessage(playerid, COLOR_INFO, C_INFO"____________________________________________");
        return 1;
    }

    // ---- /duty ----
    if(strcmp(cmd, "/duty", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        new fid = PlayerData[playerid][pFaction];
        if(fid < 1 || fid > 3)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Only factions 1-3 have a duty system."), 1;

        if(FactionData[fid][fHQX] == 0.0 && FactionData[fid][fHQY] == 0.0)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Your faction doesn't have an HQ set."), 1;

        if(!IsPlayerInRangeOfPoint(playerid, DUTY_HQ_RANGE, FactionData[fid][fHQX], FactionData[fid][fHQY], FactionData[fid][fHQZ]))
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be near the faction HQ to change your duty status."), 1;

        PlayerData[playerid][pOnDuty] = !PlayerData[playerid][pOnDuty];

        if(PlayerData[playerid][pOnDuty])
            SendClientMessage(playerid, COLOR_SUCCESS, C_INFO"Info: "C_WHITE"You are now "C_SUCCESS"ON-DUTY"C_WHITE".");
        else
            SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"You are now "C_ERROR"OFF-DUTY"C_WHITE".");
        return 1;
    }

    // ---- /inspectcar [playerid] ----
    if(strcmp(cmd, "/inspectcar", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        if(PlayerData[playerid][pFaction] != FACTION_RAR)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You are not part of the Registrul Auto Roman."), 1;

        if(!PlayerData[playerid][pOnDuty])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be on-duty to use this command."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new p1[8];
        strmid(p1, cmdtext, idx, strlen(cmdtext), 8);

        if(!strlen(p1))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/inspectcar [playerid]"C_WHITE"."), 1;

        new targetid = strval(p1);
        if(!IsPlayerConnected(targetid) || !PlayerData[targetid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"The player is not connected."), 1;

        new Float:px, Float:py, Float:pz;
        GetPlayerPos(playerid, px, py, pz);
        if(!IsPlayerInRangeOfPoint(targetid, FINE_RANGE, px, py, pz))
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"The player must be within 10m."), 1;

        new vehid = GetPlayerVehicleID(targetid);
        if(vehid == 0)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"The player is not in a vehicle."), 1;

        new pvidx = g_VehicleToPVIndex[vehid];
        if(pvidx == -1)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"This vehicle is not a registered personal vehicle."), 1;

        new vname[24];
        GetVehicleModelName(PVehicleData[pvidx][pvModelID], vname, sizeof(vname));

        new medStatus[16], extStatus[16], itpStatus[16];
        VehicleDoc_Status(PVehicleData[pvidx][pvMedkitExp], medStatus, sizeof(medStatus));
        VehicleDoc_Status(PVehicleData[pvidx][pvExtinguisherExp], extStatus, sizeof(extStatus));
        VehicleDoc_Status(PVehicleData[pvidx][pvITPExp], itpStatus, sizeof(itpStatus));

        new Float:health;
        GetVehicleHealth(vehid, health);

        new line[160];
        SendClientMessage(playerid, COLOR_INFO, C_INFO"_____ Vehicle Inspection ____________________________");
        format(line, sizeof(line), C_WHITE"Driver: "C_INFO"%s"C_WHITE" | Vehicle: "C_INFO"%s"C_WHITE" | Plate: "C_INFO"%s",
            PlayerData[targetid][pName], vname, PVehicleData[pvidx][pvPlate]);
        SendClientMessage(playerid, COLOR_WHITE, line);
        format(line, sizeof(line), C_WHITE"Medical Kit: "C_INFO"%s"C_WHITE" | Extinguisher: "C_INFO"%s"C_WHITE" | ITP: "C_INFO"%s",
            medStatus, extStatus, itpStatus);
        SendClientMessage(playerid, COLOR_WHITE, line);
        format(line, sizeof(line), C_WHITE"Vehicle Health: "C_INFO"%d", floatround(health));
        SendClientMessage(playerid, COLOR_WHITE, line);
        SendClientMessage(playerid, COLOR_INFO, C_INFO"_______________________________________________________");
        return 1;
    }

    // ---- /fine [playerid] [amount] [reason] ----
    if(strcmp(cmd, "/fine", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        if(PlayerData[playerid][pFaction] != FACTION_RAR)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You are not part of the Registrul Auto Roman."), 1;

        if(!PlayerData[playerid][pOnDuty])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be on-duty to use this command."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new p1[8], p2[8];
        strmid(p1, cmdtext, idx, strlen(cmdtext), 8);
        while(cmdtext[idx] > ' ') idx++;
        while(cmdtext[idx] == ' ') idx++;
        strmid(p2, cmdtext, idx, strlen(cmdtext), 8);
        while(cmdtext[idx] > ' ') idx++;
        while(cmdtext[idx] == ' ') idx++;
        new reason[128];
        strmid(reason, cmdtext, idx, strlen(cmdtext), 128);

        if(!strlen(p1) || !strlen(p2) || !strlen(reason))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/fine [playerid] [amount] [reason]"C_WHITE"."), 1;

        new targetid = strval(p1);
        new amount = strval(p2);

        if(!IsPlayerConnected(targetid) || !PlayerData[targetid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"The player is not connected."), 1;

        if(targetid == playerid)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You can't fine yourself."), 1;

        if(amount <= 0)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Invalid amount."), 1;

        new Float:px, Float:py, Float:pz;
        GetPlayerPos(playerid, px, py, pz);
        if(!IsPlayerInRangeOfPoint(targetid, FINE_RANGE, px, py, pz))
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"The player must be within 10m."), 1;

        g_PendingFineAmount[targetid]  = amount;
        g_PendingFineOfficer[targetid] = playerid;
        format(g_PendingFineReason[targetid], 128, "%s", reason);

        new fmsg[160];
        format(fmsg, sizeof(fmsg), C_SUCCESS"Success: "C_WHITE"You issued a "C_INFO"$%d"C_WHITE" fine to "C_INFO"%s"C_WHITE" for: "C_INFO"%s"C_WHITE". Waiting for them to accept.",
            amount, PlayerData[targetid][pName], reason);
        SendClientMessage(playerid, COLOR_SUCCESS, fmsg);

        format(fmsg, sizeof(fmsg),
            C_ERROR"[RAR] "C_WHITE"Officer "C_INFO"%s"C_WHITE" fined you "C_INFO"$%d"C_WHITE" for: "C_INFO"%s"C_WHITE". Type "C_INFO"/accept fine %d"C_WHITE" to accept it.",
            PlayerData[playerid][pName], amount, reason, playerid);
        SendClientMessage(targetid, COLOR_ERROR, fmsg);
        return 1;
    }

    // ---- /m [playerid] ----
    if(strcmp(cmd, "/m", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        if(PlayerData[playerid][pFaction] != FACTION_RAR)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You are not part of the Registrul Auto Roman."), 1;

        if(!PlayerData[playerid][pOnDuty])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be on-duty to use this command."), 1;

        new myVehid = GetPlayerVehicleID(playerid);
        if(myVehid == 0 || g_VehicleFactionOwner[myVehid] != FACTION_RAR)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be in a faction vehicle to use this command."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new p1[8];
        strmid(p1, cmdtext, idx, strlen(cmdtext), 8);

        if(!strlen(p1))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/m [playerid]"C_WHITE"."), 1;

        new targetid = strval(p1);
        if(!IsPlayerConnected(targetid) || !PlayerData[targetid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"The player is not connected."), 1;

        if(GetPlayerVehicleID(targetid) == 0)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"The player is not in a vehicle."), 1;

        new Float:px, Float:py, Float:pz;
        GetPlayerPos(playerid, px, py, pz);
        if(!IsPlayerInRangeOfPoint(targetid, M_RANGE, px, py, pz))
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"The player must be within 50m."), 1;

        new mmsg[160];
        format(mmsg, sizeof(mmsg),
            C_ERROR"[RAR] "C_WHITE"Officer "C_INFO"%s"C_WHITE" orders you to pull over: stop the car and remain inside the vehicle.",
            PlayerData[playerid][pName]);
        SendClientMessage(targetid, COLOR_ERROR, mmsg);

        format(mmsg, sizeof(mmsg), C_SUCCESS"Success: "C_INFO"%s"C_WHITE" has received your order to pull over.", PlayerData[targetid][pName]);
        SendClientMessage(playerid, COLOR_SUCCESS, mmsg);
        return 1;
    }

    // ---- /installradar [speedLimit] ----
    if(strcmp(cmd, "/installradar", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        if(PlayerData[playerid][pFaction] != FACTION_POLICE)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You are not part of the Politia Romana."), 1;

        if(PlayerData[playerid][pFactionRank] < 2)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Requires rank 2 or higher."), 1;

        if(g_RadarActive[playerid])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You already have a radar installed. Use "C_INFO"/removeradar"C_WHITE" first."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new p1[8];
        strmid(p1, cmdtext, idx, strlen(cmdtext), 8);

        if(!strlen(p1))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/installradar [speedLimit]"C_WHITE"."), 1;

        new speedLimit = strval(p1);
        if(speedLimit <= 0)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Invalid speed limit."), 1;

        GetPlayerPos(playerid, g_RadarX[playerid], g_RadarY[playerid], g_RadarZ[playerid]);
        g_RadarSpeedLimit[playerid] = speedLimit;
        g_RadarActive[playerid]     = true;

        new imsg[128];
        format(imsg, sizeof(imsg), C_SUCCESS"Success: "C_WHITE"Radar camera installed with a "C_INFO"%d km/h"C_WHITE" speed limit.", speedLimit);
        SendClientMessage(playerid, COLOR_SUCCESS, imsg);
        return 1;
    }

    // ---- /removeradar ----
    if(strcmp(cmd, "/removeradar", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        if(PlayerData[playerid][pFaction] != FACTION_POLICE)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You are not part of the Politia Romana."), 1;

        if(PlayerData[playerid][pFactionRank] < 2)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Requires rank 2 or higher."), 1;

        if(!g_RadarActive[playerid])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have an installed radar."), 1;

        g_RadarActive[playerid] = false;

        SendClientMessage(playerid, COLOR_SUCCESS, C_SUCCESS"Success: "C_WHITE"Radar camera removed.");
        return 1;
    }

    // ---- /factions ----
    if(strcmp(cmd, "/factions", true) == 0)
    {
        SendClientMessage(playerid, COLOR_INFO, C_INFO"_____ Factions ____________________");
        new line[128], colorcode[9], lead[24];
        for(new i = 1; i <= MAX_FACTIONS; i++)
        {
            GetFactionColorCode(i, colorcode, sizeof(colorcode));
            lead[0] = EOS;
            if(strlen(FactionData[i][fLead])) format(lead, sizeof(lead), "%s", FactionData[i][fLead]);
            else lead = "nobody";
            format(line, sizeof(line), "%s%d. %s | Lead: %s | Members: %d",
                colorcode, i, FactionData[i][fName], lead, FactionData[i][fMembers]);
            SendClientMessage(playerid, FactionColors[i], line);
        }
        SendClientMessage(playerid, COLOR_INFO, C_INFO"________________________________________");
        return 1;
    }

    // ---- /respawn [target_player] ----
    if(strcmp(cmd, "/respawn", true) == 0)
    {
        if(PlayerData[playerid][pAdminLevel] < 1)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have access. Requires admin level 1."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new p1[8];
        strmid(p1, cmdtext, idx, strlen(cmdtext), 8);

        if(!strlen(p1))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/respawn [target_player]"C_WHITE"."), 1;

        new targetid = strval(p1);

        if(!IsPlayerConnected(targetid) || !PlayerData[targetid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"The player is not connected."), 1;

        SpawnPlayer(targetid);

        new adminName[24];
        GetPlayerName(playerid, adminName, 24);

        new msg[128];
        format(msg, sizeof(msg), C_SUCCESS"[ADM]Success: "C_WHITE"You successfully respawned "C_INFO"%s"C_WHITE".",
            PlayerData[targetid][pName]);
        SendClientMessage(playerid, COLOR_SUCCESS, msg);

        format(msg, sizeof(msg), C_INFO"Info: "C_WHITE"You were respawned by admin "C_INFO"%s"C_WHITE".", adminName);
        SendClientMessage(targetid, COLOR_INFO, msg);
        return 1;
    }

    // ---- /aheal [playerid] ----
    if(strcmp(cmd, "/aheal", true) == 0)
    {
        if(PlayerData[playerid][pAdminLevel] < 1)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have access. Requires admin level 1."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new p1[8];
        strmid(p1, cmdtext, idx, strlen(cmdtext), 8);

        if(!strlen(p1))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/aheal [playerid]"C_WHITE"."), 1;

        new targetid = strval(p1);

        if(!IsPlayerConnected(targetid) || !PlayerData[targetid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"The player is not connected."), 1;

        SetPlayerHealth(targetid, 100.0);

        new adminName[24];
        GetPlayerName(playerid, adminName, 24);

        new msg[128];
        format(msg, sizeof(msg), C_SUCCESS"[ADM]Success: "C_WHITE"You successfully healed "C_INFO"%s"C_WHITE".",
            PlayerData[targetid][pName]);
        SendClientMessage(playerid, COLOR_SUCCESS, msg);

        format(msg, sizeof(msg), C_INFO"Info: "C_WHITE"You were healed by admin "C_INFO"%s"C_WHITE".", adminName);
        SendClientMessage(targetid, COLOR_INFO, msg);
        return 1;
    }

    // ---- /healall ----
    if(strcmp(cmd, "/healall", true) == 0)
    {
        if(PlayerData[playerid][pAdminLevel] < 2)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have access. Requires admin level 2."), 1;

        new adminName[24];
        GetPlayerName(playerid, adminName, 24);

        new msg[128];
        format(msg, sizeof(msg), C_INFO"Info: "C_WHITE"You were healed by admin "C_INFO"%s"C_WHITE".", adminName);

        for(new i = 0; i < MAX_PLAYERS; i++)
        {
            if(!IsPlayerConnected(i) || !PlayerData[i][pLogged]) continue;
            SetPlayerHealth(i, 100.0);
            SendClientMessage(i, COLOR_INFO, msg);
        }

        SendClientMessage(playerid, COLOR_SUCCESS,
            C_SUCCESS"[ADM]Success: "C_WHITE"You successfully healed all players.");
        return 1;
    }

    // ---- /help ----
    if(strcmp(cmd, "/help", true) == 0)
    {
        SendClientMessage(playerid, COLOR_INFO, C_INFO"===== Player Commands =================");

        SendClientMessage(playerid, COLOR_WHITE, C_INFO"[Account] "C_WHITE"/register [password], /login [password], /stats, /help");
        SendClientMessage(playerid, COLOR_WHITE, C_INFO"[Spawn] "C_WHITE"/cspawn");
        SendClientMessage(playerid, COLOR_WHITE,
            C_INFO"[Factions] "C_WHITE"/factions, /f [message], /finvite [playerid], /accept finvite [playerid], /fmembers, /fhelp, /duty");
        SendClientMessage(playerid, COLOR_WHITE,
            C_INFO"[Factions] "C_WHITE"/fbank, /fbankwithdraw [amount], /fsetrank [playerid] [rank 1-5]");
        SendClientMessage(playerid, COLOR_WHITE, C_INFO"[Houses] "C_WHITE"/buyhouse, /sellhouse");
        SendClientMessage(playerid, COLOR_WHITE,
            C_INFO"[Vehicles] "C_WHITE"/vbuy, /vsell, /vsellto [playerid], /vcolor [1/2] [colorID], /vplate [number]");
        SendClientMessage(playerid, COLOR_WHITE,
            C_INFO"[Vehicles] "C_WHITE"/vinsurance, /vmedicalkit, /vextinctor, /vitp, /vpark, /vstats, /rentbike, /rentcar");
        SendClientMessage(playerid, COLOR_WHITE, C_INFO"[Licenses] "C_WHITE"/licenses, /examA, /examB, /examC");
        SendClientMessage(playerid, COLOR_WHITE, C_INFO"[Business] "C_WHITE"/buybiz, /sellbiz, /bbank, /bwithdraw [amount]");

        SendClientMessage(playerid, COLOR_INFO, C_INFO"========================================");
        return 1;
    }

    // ---- /ahelp ----
    if(strcmp(cmd, "/ahelp", true) == 0)
    {
        new alv = PlayerData[playerid][pAdminLevel];
        if(alv < 1)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have access to admin commands."), 1;

        SendClientMessage(playerid, COLOR_INFO, C_INFO"===== Admin Commands ======================");

        if(alv >= 1)
            SendClientMessage(playerid, COLOR_WHITE, C_INFO"[1] "C_WHITE"/ahelp /respawn /aheal");
        if(alv >= 2)
            SendClientMessage(playerid, COLOR_WHITE, C_INFO"[2] "C_WHITE"/createFire /healall");
        if(alv >= 3)
        {
            SendClientMessage(playerid, COLOR_WHITE, C_INFO"[3] "C_WHITE"/veh /rac");
            SendClientMessage(playerid, COLOR_WHITE,
                C_INFO"[3] "C_WHITE"/setdrivingLicAexp /setdrivingLicBexp /setdrivingLicCexp /setdrivingLicDexp");
        }
        if(alv >= 5)
        {
            SendClientMessage(playerid, COLOR_WHITE, C_INFO"[5] "C_WHITE"/payday");
            SendClientMessage(playerid, COLOR_WHITE,
                C_INFO"[5] [PVehicles] "C_WHITE"/vchangeINSURANCEexp /vchangeMEDKITexp /vchangeEXTINCTORexp /vchangeITPexp");
        }
        if(alv >= 6)
        {
            SendClientMessage(playerid, COLOR_WHITE, C_INFO"[6] [Factions] "C_WHITE"/changeFactionHQ /changeFactionhqIcon /changeFactionPickup /changeFactionLead");
            SendClientMessage(playerid, COLOR_WHITE, C_INFO"[6] [Factions] "C_WHITE"/createFactionVeh /removeFactionLead");
            SendClientMessage(playerid, COLOR_WHITE, C_INFO"[6] [Houses] "C_WHITE"/createHouse /changeHousePrice /changeHouseOwner ");
            SendClientMessage(playerid, COLOR_WHITE, C_INFO"[6] [PVehicles] "C_WHITE"/vCreate /vSetPrice");
            SendClientMessage(playerid, COLOR_WHITE, C_INFO"[6] [Business] "C_WHITE"/createBiz /changeBizName /changeBizPrice /changeBizLoc");
        }

        SendClientMessage(playerid, COLOR_INFO, C_INFO"==========================================");
        return 1;
    }

    // ---- /createhouse [nume] ----
    if(strcmp(cmd, "/createhouse", true) == 0)
    {
        if(PlayerData[playerid][pAdminLevel] < 6)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have access. Requires admin level 6."), 1;

        if(g_HouseCount >= MAX_HOUSES)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Limit of "C_INFO#MAX_HOUSES C_WHITE" houses reached."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new hname[32];
        strmid(hname, cmdtext, idx, strlen(cmdtext), 32);

        if(!strlen(hname))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/createhouse [name]"C_WHITE"."), 1;

        new Float:hx, Float:hy, Float:hz;
        GetPlayerPos(playerid, hx, hy, hz);

        new newIdx = g_HouseCount;
        format(HouseData[newIdx][hName], 32, "%s", hname);
        HouseData[newIdx][hOwner][0] = EOS;
        HouseData[newIdx][hOwnerId]  = 0;
        HouseData[newIdx][hOwned]    = 0;
        HouseData[newIdx][hPrice]    = 999999999;
        HouseData[newIdx][hLocX]     = hx;
        HouseData[newIdx][hLocY]     = hy;
        HouseData[newIdx][hLocZ]     = hz;
        g_HousePickup[newIdx]        = -1;
        g_HouseCount++;

        new q[256];
        mysql_format(g_SQL, q, sizeof(q),
            "INSERT INTO `houses` (`name`,`owner`,`owner_id`,`owned`,`price`,`loc_x`,`loc_y`,`loc_z`) \
             VALUES ('%e','',0,0,50000,%.4f,%.4f,%.4f)",
            hname, hx, hy, hz);
        mysql_tquery(g_SQL, q, "OnHouseCreated", "ii", playerid, newIdx);
        return 1;
    }

    // ---- /createfactionveh [faction_id] ----
    if(strcmp(cmd, "/createfactionveh", true) == 0)
    {
        if(PlayerData[playerid][pAdminLevel] < 6)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have access. Requires admin level 6."), 1;

        if(g_VFactionCount >= MAX_VFACTION_VEHICLES)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Limit of "C_INFO#MAX_VFACTION_VEHICLES C_WHITE" faction vehicles reached."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new p1[8];
        strmid(p1, cmdtext, idx, strlen(cmdtext), 8);

        if(!strlen(p1))
            return SendClientMessage(playerid, COLOR_INFO,
                C_INFO"Info: "C_WHITE"Use "C_INFO"/createfactionveh [faction_id]"C_WHITE"."), 1;

        new fid = strval(p1);
        if(fid < 1 || fid > MAX_FACTIONS)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Invalid faction ID (1-"#MAX_FACTIONS")."), 1;

        new vehid = GetPlayerVehicleID(playerid);
        if(vehid == 0)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be in a vehicle."), 1;

        new Float:vx, Float:vy, Float:vz, Float:vangle;
        GetVehiclePos(vehid, vx, vy, vz);
        GetVehicleZAngle(vehid, vangle);
        new model = GetVehicleModel(vehid);

        new newIdx = g_VFactionCount;
        VFactionData[newIdx][vfFactionID] = fid;
        VFactionData[newIdx][vfModelID]   = model;
        VFactionData[newIdx][vfLocX]      = vx;
        VFactionData[newIdx][vfLocY]      = vy;
        VFactionData[newIdx][vfLocZ]      = vz;
        VFactionData[newIdx][vfRotation]  = vangle;
        VFactionData[newIdx][vfColor1]    = -1;
        VFactionData[newIdx][vfColor2]    = -1;
        g_VFactionVehicle[newIdx]         = -1;
        g_VFactionCount++;

        new q2[256];
        mysql_format(g_SQL, q2, sizeof(q2),
            "INSERT INTO `vehicles_faction` (`faction_id`,`model_id`,`loc_x`,`loc_y`,`loc_z`,`rotation`,`color1`,`color2`) \
             VALUES (%d,%d,%.4f,%.4f,%.4f,%.4f,-1,-1)",
            fid, model, vx, vy, vz, vangle);
        mysql_tquery(g_SQL, q2, "OnVehicleFactionCreated", "ii", playerid, newIdx);
        return 1;
    }

    // ---- /buyhouse ----
    if(strcmp(cmd, "/buyhouse", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        if(PlayerData[playerid][pHouse] != 999)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You already own a house. Use "C_INFO"/sellhouse"C_WHITE" first."), 1;

        new hidx = -1;
        for(new i = 0; i < g_HouseCount; i++)
        {
            if(HouseData[i][hOwned]) continue;
            if(IsPlayerInRangeOfPoint(playerid, 5.0, HouseData[i][hLocX], HouseData[i][hLocY], HouseData[i][hLocZ]))
            {
                hidx = i;
                break;
            }
        }

        if(hidx == -1)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You are not near a house for sale."), 1;

        if(PlayerData[playerid][pMoney] < HouseData[hidx][hPrice])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have enough money."), 1;

        PlayerData[playerid][pMoney] -= HouseData[hidx][hPrice];
        GivePlayerMoney(playerid, -HouseData[hidx][hPrice]);
        UpdatePlayer(playerid, pMoney);

        HouseData[hidx][hOwned]   = 1;
        HouseData[hidx][hOwnerId] = PlayerData[playerid][pID];
        GetPlayerName(playerid, HouseData[hidx][hOwner], 24);
        PlayerData[playerid][pHouse] = HouseData[hidx][hID];

        Houses_RecreatePickup(hidx);
        UpdatePlayer(playerid, pHouse);

        new q[256];
        mysql_format(g_SQL, q, sizeof(q),
            "UPDATE `houses` SET `owner`='%e', `owner_id`=%d, `owned`=1 WHERE `id`=%d",
            HouseData[hidx][hOwner], HouseData[hidx][hOwnerId], HouseData[hidx][hID]);
        mysql_tquery(g_SQL, q, "", "", 0);

        new lmsg[128];
        format(lmsg, sizeof(lmsg), C_SUCCESS"Success: "C_WHITE"You bought the house "C_INFO"%s"C_WHITE" for "C_INFO"$%d"C_WHITE".",
            HouseData[hidx][hName], HouseData[hidx][hPrice]);
        SendClientMessage(playerid, COLOR_SUCCESS, lmsg);
        return 1;
    }

    // ---- /sellhouse ----
    if(strcmp(cmd, "/sellhouse", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        if(PlayerData[playerid][pHouse] == 999)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't own a house."), 1;

        new hidx = Houses_FindByID(PlayerData[playerid][pHouse]);
        if(hidx == -1)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"House not found."), 1;

        new price = HouseData[hidx][hPrice];
        PlayerData[playerid][pMoney] += price;
        GivePlayerMoney(playerid, price);
        UpdatePlayer(playerid, pMoney);
        PlayerData[playerid][pHouse] = 999;

        HouseData[hidx][hOwned]    = 0;
        HouseData[hidx][hOwnerId]  = 0;
        HouseData[hidx][hOwner][0] = EOS;

        Houses_RecreatePickup(hidx);
        UpdatePlayer(playerid, pHouse);

        new q[256];
        mysql_format(g_SQL, q, sizeof(q),
            "UPDATE `houses` SET `owner`='', `owner_id`=0, `owned`=0 WHERE `id`=%d",
            HouseData[hidx][hID]);
        mysql_tquery(g_SQL, q, "", "", 0);

        new lmsg[128];
        format(lmsg, sizeof(lmsg), C_SUCCESS"Success: "C_WHITE"You sold the house "C_INFO"%s"C_WHITE" for "C_INFO"$%d"C_WHITE".",
            HouseData[hidx][hName], price);
        SendClientMessage(playerid, COLOR_SUCCESS, lmsg);
        return 1;
    }

    // ---- /buybiz ----
    if(strcmp(cmd, "/buybiz", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        new bidx = -1;
        for(new i = 0; i < g_BusinessCount; i++)
        {
            if(BusinessData[i][bOwned]) continue;
            if(IsPlayerInRangeOfPoint(playerid, BUSINESS_RANGE, BusinessData[i][bLocX], BusinessData[i][bLocY], BusinessData[i][bLocZ]))
            {
                bidx = i;
                break;
            }
        }

        if(bidx == -1)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You are not near a business for sale."), 1;

        if(PlayerData[playerid][pMoney] < BusinessData[bidx][bPrice])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have enough money."), 1;

        PlayerData[playerid][pMoney] -= BusinessData[bidx][bPrice];
        GivePlayerMoney(playerid, -BusinessData[bidx][bPrice]);
        UpdatePlayer(playerid, pMoney);

        BusinessData[bidx][bOwned]   = 1;
        BusinessData[bidx][bOwnerId] = PlayerData[playerid][pID];
        GetPlayerName(playerid, BusinessData[bidx][bOwner], 24);

        PlayerData[playerid][pBusiness] = BusinessData[bidx][bID];
        UpdatePlayer(playerid, pBusiness);

        Businesses_RecreatePickup(bidx);
        Businesses_UpdatePlayersIcons();

        new q[256];
        mysql_format(g_SQL, q, sizeof(q),
            "UPDATE `businesses` SET `owner`='%e', `owner_id`=%d, `owned`=1 WHERE `id`=%d",
            BusinessData[bidx][bOwner], BusinessData[bidx][bOwnerId], BusinessData[bidx][bID]);
        mysql_tquery(g_SQL, q, "", "", 0);

        new lmsg[128];
        format(lmsg, sizeof(lmsg), C_SUCCESS"Success: "C_WHITE"You bought the business (ID: "C_INFO"%d"C_WHITE") for "C_INFO"$%d"C_WHITE".",
            BusinessData[bidx][bID], BusinessData[bidx][bPrice]);
        SendClientMessage(playerid, COLOR_SUCCESS, lmsg);
        return 1;
    }

    // ---- /sellbiz ----
    if(strcmp(cmd, "/sellbiz", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        new bidx = -1;
        for(new i = 0; i < g_BusinessCount; i++)
        {
            if(BusinessData[i][bOwnerId] != PlayerData[playerid][pID]) continue;
            if(IsPlayerInRangeOfPoint(playerid, BUSINESS_RANGE, BusinessData[i][bLocX], BusinessData[i][bLocY], BusinessData[i][bLocZ]))
            {
                bidx = i;
                break;
            }
        }

        if(bidx == -1)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You are not near a business you own."), 1;

        new refund = BusinessData[bidx][bPrice] / 2;
        PlayerData[playerid][pMoney] += refund;
        GivePlayerMoney(playerid, refund);
        UpdatePlayer(playerid, pMoney);

        BusinessData[bidx][bOwned]    = 0;
        BusinessData[bidx][bOwnerId]  = 0;
        BusinessData[bidx][bOwner][0] = EOS;
        BusinessData[bidx][bBank]     = 0;

        if(PlayerData[playerid][pBusiness] == BusinessData[bidx][bID])
        {
            PlayerData[playerid][pBusiness] = 999;
            UpdatePlayer(playerid, pBusiness);
        }

        Businesses_RecreatePickup(bidx);
        Businesses_UpdatePlayersIcons();

        new q[256];
        mysql_format(g_SQL, q, sizeof(q),
            "UPDATE `businesses` SET `owner`='', `owner_id`=0, `owned`=0, `bank`=0 WHERE `id`=%d",
            BusinessData[bidx][bID]);
        mysql_tquery(g_SQL, q, "", "", 0);

        new lmsg[128];
        format(lmsg, sizeof(lmsg), C_SUCCESS"Success: "C_WHITE"You sold the business (ID: "C_INFO"%d"C_WHITE") for "C_INFO"$%d"C_WHITE".",
            BusinessData[bidx][bID], refund);
        SendClientMessage(playerid, COLOR_SUCCESS, lmsg);
        return 1;
    }

    // ---- /bbank ----
    if(strcmp(cmd, "/bbank", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        new bidx = -1;
        for(new i = 0; i < g_BusinessCount; i++)
        {
            if(BusinessData[i][bOwnerId] != PlayerData[playerid][pID]) continue;
            if(IsPlayerInRangeOfPoint(playerid, BUSINESS_RANGE, BusinessData[i][bLocX], BusinessData[i][bLocY], BusinessData[i][bLocZ]))
            {
                bidx = i;
                break;
            }
        }

        if(bidx == -1)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You are not near a business you own."), 1;

        new bmsg[128];
        format(bmsg, sizeof(bmsg), C_INFO"Info: "C_WHITE"The business account (ID: "C_INFO"%d"C_WHITE") has "C_INFO"$%d"C_WHITE".",
            BusinessData[bidx][bID], BusinessData[bidx][bBank]);
        SendClientMessage(playerid, COLOR_INFO, bmsg);
        return 1;
    }

    // ---- /bwithdraw [suma] ----
    if(strcmp(cmd, "/bwithdraw", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        new bidx = -1;
        for(new i = 0; i < g_BusinessCount; i++)
        {
            if(BusinessData[i][bOwnerId] != PlayerData[playerid][pID]) continue;
            if(IsPlayerInRangeOfPoint(playerid, BUSINESS_RANGE, BusinessData[i][bLocX], BusinessData[i][bLocY], BusinessData[i][bLocZ]))
            {
                bidx = i;
                break;
            }
        }

        if(bidx == -1)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You are not near a business you own."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new p1[16];
        strmid(p1, cmdtext, idx, strlen(cmdtext), 16);

        if(!strlen(p1))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/bwithdraw [amount]"C_WHITE"."), 1;

        new amount = strval(p1);
        if(amount <= 0)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Invalid amount."), 1;

        if(amount > BusinessData[bidx][bBank])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"The business doesn't have enough money."), 1;

        BusinessData[bidx][bBank] -= amount;
        PlayerData[playerid][pMoney] += amount;
        GivePlayerMoney(playerid, amount);
        UpdatePlayer(playerid, pMoney);

        new q[128];
        mysql_format(g_SQL, q, sizeof(q), "UPDATE `businesses` SET `bank`=%d WHERE `id`=%d",
            BusinessData[bidx][bBank], BusinessData[bidx][bID]);
        mysql_tquery(g_SQL, q, "", "", 0);

        new wmsg[128];
        format(wmsg, sizeof(wmsg), C_SUCCESS"Success: "C_WHITE"You withdrew "C_INFO"$%d"C_WHITE" from the business account.", amount);
        SendClientMessage(playerid, COLOR_SUCCESS, wmsg);
        return 1;
    }

    // ---- /createbiz ----
    if(strcmp(cmd, "/createbiz", true) == 0)
    {
        if(PlayerData[playerid][pAdminLevel] < 6)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have access. Requires admin level 6."), 1;

        if(g_BusinessCount >= MAX_BUSINESSES)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Limit of "C_INFO#MAX_BUSINESSES C_WHITE" businesses reached."), 1;

        new Float:bx, Float:by, Float:bz;
        GetPlayerPos(playerid, bx, by, bz);

        new newIdx = g_BusinessCount;
        format(BusinessData[newIdx][bName], 32, "Business");
        BusinessData[newIdx][bOwner][0] = EOS;
        BusinessData[newIdx][bOwnerId]  = 0;
        BusinessData[newIdx][bOwned]    = 0;
        BusinessData[newIdx][bPrice]    = 50000;
        BusinessData[newIdx][bBank]     = 0;
        BusinessData[newIdx][bLocX]     = bx;
        BusinessData[newIdx][bLocY]     = by;
        BusinessData[newIdx][bLocZ]     = bz;
        g_BusinessPickup[newIdx]        = -1;
        g_BusinessCount++;

        new q[256];
        mysql_format(g_SQL, q, sizeof(q),
            "INSERT INTO `businesses` (`name`,`owned`,`owner`,`owner_id`,`price`,`bank`,`loc_x`,`loc_y`,`loc_z`) \
             VALUES ('Business',0,'',0,50000,0,%.4f,%.4f,%.4f)",
            bx, by, bz);
        mysql_tquery(g_SQL, q, "OnBusinessCreated", "ii", playerid, newIdx);
        return 1;
    }

    // ---- /changebizname [id] [nume] ----
    if(strcmp(cmd, "/changebizname", true) == 0)
    {
        if(PlayerData[playerid][pAdminLevel] < 6)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have access. Requires admin level 6."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new p1[8];
        strmid(p1, cmdtext, idx, strlen(cmdtext), 8);
        new bid = strval(p1);
        while(cmdtext[idx] > ' ') idx++;
        while(cmdtext[idx] == ' ') idx++;
        new bname[32];
        strmid(bname, cmdtext, idx, strlen(cmdtext), 32);

        if(!strlen(p1) || !strlen(bname))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/changebizname [id] [name]"C_WHITE"."), 1;

        new bidx = Businesses_FindByID(bid);
        if(bidx == -1)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Business not found."), 1;

        format(BusinessData[bidx][bName], 32, "%s", bname);
        Businesses_RecreatePickup(bidx);

        new q[160];
        mysql_format(g_SQL, q, sizeof(q), "UPDATE `businesses` SET `name`='%e' WHERE `id`=%d",
            BusinessData[bidx][bName], BusinessData[bidx][bID]);
        mysql_tquery(g_SQL, q, "", "", 0);

        new lmsg[128];
        format(lmsg, sizeof(lmsg), C_SUCCESS"[ADM]Success: "C_WHITE"The name of business (ID: "C_INFO"%d"C_WHITE") was changed to "C_INFO"%s"C_WHITE".",
            BusinessData[bidx][bID], BusinessData[bidx][bName]);
        SendClientMessage(playerid, COLOR_SUCCESS, lmsg);
        return 1;
    }

    // ---- /changebizprice [id] [pret_nou] ----
    if(strcmp(cmd, "/changebizprice", true) == 0)
    {
        if(PlayerData[playerid][pAdminLevel] < 6)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have access. Requires admin level 6."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new p1[8], p2[16];
        strmid(p1, cmdtext, idx, strlen(cmdtext), 8);
        new bid = strval(p1);
        while(cmdtext[idx] > ' ') idx++;
        while(cmdtext[idx] == ' ') idx++;
        strmid(p2, cmdtext, idx, strlen(cmdtext), 16);
        new newPrice = strval(p2);

        if(!strlen(p1) || !strlen(p2))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/changebizprice [id] [new_price]"C_WHITE"."), 1;

        new bidx = Businesses_FindByID(bid);
        if(bidx == -1)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Business not found."), 1;

        if(newPrice <= 0)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Invalid price."), 1;

        BusinessData[bidx][bPrice] = newPrice;
        Businesses_RecreatePickup(bidx);

        new q[128];
        mysql_format(g_SQL, q, sizeof(q), "UPDATE `businesses` SET `price`=%d WHERE `id`=%d", newPrice, BusinessData[bidx][bID]);
        mysql_tquery(g_SQL, q, "", "", 0);

        new lmsg[128];
        format(lmsg, sizeof(lmsg), C_SUCCESS"[ADM]Success: "C_WHITE"The price of business (ID: "C_INFO"%d"C_WHITE") was changed to "C_INFO"$%d"C_WHITE".",
            BusinessData[bidx][bID], newPrice);
        SendClientMessage(playerid, COLOR_SUCCESS, lmsg);
        return 1;
    }

    // ---- /changebizloc [id] ----
    if(strcmp(cmd, "/changebizloc", true) == 0)
    {
        if(PlayerData[playerid][pAdminLevel] < 6)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have access. Requires admin level 6."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new p1[8];
        strmid(p1, cmdtext, idx, strlen(cmdtext), 8);

        if(!strlen(p1))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/changebizloc [id]"C_WHITE"."), 1;

        new bid = strval(p1);
        new bidx = Businesses_FindByID(bid);
        if(bidx == -1)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Business not found."), 1;

        GetPlayerPos(playerid, BusinessData[bidx][bLocX], BusinessData[bidx][bLocY], BusinessData[bidx][bLocZ]);
        Businesses_RecreatePickup(bidx);
        Businesses_UpdatePlayersIcons();

        new q[256];
        mysql_format(g_SQL, q, sizeof(q),
            "UPDATE `businesses` SET `loc_x`=%.4f, `loc_y`=%.4f, `loc_z`=%.4f WHERE `id`=%d",
            BusinessData[bidx][bLocX], BusinessData[bidx][bLocY], BusinessData[bidx][bLocZ], BusinessData[bidx][bID]);
        mysql_tquery(g_SQL, q, "", "", 0);

        new lmsg[128];
        format(lmsg, sizeof(lmsg), C_SUCCESS"[ADM]Success: "C_WHITE"The location of business (ID: "C_INFO"%d"C_WHITE") was updated.",
            BusinessData[bidx][bID]);
        SendClientMessage(playerid, COLOR_SUCCESS, lmsg);
        return 1;
    }

    // ---- /rentbike ----
    if(strcmp(cmd, "/rentbike", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        new vehid = GetPlayerVehicleID(playerid);
        if(vehid == 0 || !IsRentBikeVehicle(vehid))
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be on a rental bike."), 1;

        if(PlayerData[playerid][pMoney] < g_RentBikePrice)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have enough money."), 1;

        PlayerData[playerid][pMoney] -= g_RentBikePrice;
        GivePlayerMoney(playerid, -g_RentBikePrice);
        UpdatePlayer(playerid, pMoney);

        new bidx = Businesses_FindByID(RENT_BIZ_ID);
        if(bidx != -1)
        {
            BusinessData[bidx][bBank] += g_RentBikePrice;

            new q[128];
            mysql_format(g_SQL, q, sizeof(q), "UPDATE `businesses` SET `bank`=%d WHERE `id`=%d",
                BusinessData[bidx][bBank], BusinessData[bidx][bID]);
            mysql_tquery(g_SQL, q, "", "", 0);
        }

        TogglePlayerControllable(playerid, 1);

        new lmsg[128];
        format(lmsg, sizeof(lmsg), C_SUCCESS"Success: "C_WHITE"You rented the bike for "C_INFO"$%d"C_WHITE".", g_RentBikePrice);
        SendClientMessage(playerid, COLOR_SUCCESS, lmsg);
        return 1;
    }

    // ---- /rentcar ----
    if(strcmp(cmd, "/rentcar", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        new vehid = GetPlayerVehicleID(playerid);
        new price, bizid;
        if(vehid != 0 && IsRentCarVehicle(vehid))
        {
            price = RENT_CAR_PRICE;
            bizid = RENT_CAR_BIZ_ID;
        }
        else if(vehid != 0 && IsRentCarDesertVehicle(vehid))
        {
            price = g_RentCarDesertPrice;
            bizid = RENT_CAR_DESERT_BIZ_ID;
        }
        else
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be in a rental car."), 1;

        if(PlayerData[playerid][pMoney] < price)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have enough money."), 1;

        PlayerData[playerid][pMoney] -= price;
        GivePlayerMoney(playerid, -price);
        UpdatePlayer(playerid, pMoney);

        new bidx = Businesses_FindByID(bizid);
        if(bidx != -1)
        {
            BusinessData[bidx][bBank] += price;

            new q[128];
            mysql_format(g_SQL, q, sizeof(q), "UPDATE `businesses` SET `bank`=%d WHERE `id`=%d",
                BusinessData[bidx][bBank], BusinessData[bidx][bID]);
            mysql_tquery(g_SQL, q, "", "", 0);
        }

        TogglePlayerControllable(playerid, 1);

        new lmsg[128];
        format(lmsg, sizeof(lmsg), C_SUCCESS"Success: "C_WHITE"You rented the car for "C_INFO"$%d"C_WHITE".", price);
        SendClientMessage(playerid, COLOR_SUCCESS, lmsg);
        return 1;
    }

    // ---- /examA ----
    if(strcmp(cmd, "/examA", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        if(!IsPlayerInRangeOfPoint(playerid, EXAMA_RANGE, EXAMA_LOC_X, EXAMA_LOC_Y, EXAMA_LOC_Z))
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be at the exam location."), 1;

        if(g_ExamAState[playerid] != EXAMA_STATE_NONE)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You already have an exam in progress."), 1;

        if(PlayerData[playerid][pMoney] < g_ExamAPrice)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have enough money."), 1;

        PlayerData[playerid][pMoney] -= g_ExamAPrice;
        GivePlayerMoney(playerid, -g_ExamAPrice);
        UpdatePlayer(playerid, pMoney);

        new bidx = Businesses_FindByID(EXAMA_BIZ_ID);
        if(bidx != -1)
        {
            BusinessData[bidx][bBank] += g_ExamAPrice;

            new q[128];
            mysql_format(g_SQL, q, sizeof(q), "UPDATE `businesses` SET `bank`=%d WHERE `id`=%d",
                BusinessData[bidx][bBank], BusinessData[bidx][bID]);
            mysql_tquery(g_SQL, q, "", "", 0);
        }

        g_ExamAState[playerid]      = EXAMA_STATE_WAITING_CAR;
        g_ExamACheckpoint[playerid] = 0;
        g_ExamAVehicle[playerid]    = -1;
        ExamA_KillTimer(playerid);
        g_ExamATimer[playerid] = SetTimerEx("ExamA_Timeout", EXAMA_STEP_TIME, false, "i", playerid);

        SendClientMessage(playerid, COLOR_INFO,
            C_INFO"Info: "C_WHITE"Get into a "C_INFO"Sanchez"C_WHITE" within "C_INFO"30 seconds"C_WHITE" to start the exam.");
        return 1;
    }

    // ---- /examB ----
    if(strcmp(cmd, "/examB", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        if(!IsPlayerInRangeOfPoint(playerid, EXAMB_RANGE, EXAMB_LOC_X, EXAMB_LOC_Y, EXAMB_LOC_Z))
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be at the exam location."), 1;

        if(g_ExamState[playerid] != EXAM_STATE_NONE)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You already have an exam in progress."), 1;

        if(PlayerData[playerid][pMoney] < g_ExamBPrice)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have enough money."), 1;

        PlayerData[playerid][pMoney] -= g_ExamBPrice;
        GivePlayerMoney(playerid, -g_ExamBPrice);
        UpdatePlayer(playerid, pMoney);

        new bidx = Businesses_FindByID(EXAMB_BIZ_ID);
        if(bidx != -1)
        {
            BusinessData[bidx][bBank] += g_ExamBPrice;

            new q[128];
            mysql_format(g_SQL, q, sizeof(q), "UPDATE `businesses` SET `bank`=%d WHERE `id`=%d",
                BusinessData[bidx][bBank], BusinessData[bidx][bID]);
            mysql_tquery(g_SQL, q, "", "", 0);
        }

        g_ExamState[playerid]      = EXAM_STATE_WAITING_CAR;
        g_ExamCheckpoint[playerid] = 0;
        g_ExamVehicle[playerid]    = -1;
        Exam_KillTimer(playerid);
        g_ExamTimer[playerid] = SetTimerEx("Exam_Timeout", EXAMB_STEP_TIME, false, "i", playerid);

        SendClientMessage(playerid, COLOR_INFO,
            C_INFO"Info: "C_WHITE"Get into a "C_INFO"Comet"C_WHITE" within "C_INFO"30 seconds"C_WHITE" to start the exam.");
        return 1;
    }

    // ---- /examC ----
    if(strcmp(cmd, "/examC", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        if(!IsPlayerInRangeOfPoint(playerid, EXAMC_RANGE, EXAMC_LOC_X, EXAMC_LOC_Y, EXAMC_LOC_Z))
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be at the exam location."), 1;

        if(g_ExamCState[playerid] != EXAMC_STATE_NONE)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You already have an exam in progress."), 1;

        if(PlayerData[playerid][pMoney] < EXAMC_PRICE)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have enough money."), 1;

        PlayerData[playerid][pMoney] -= EXAMC_PRICE;
        GivePlayerMoney(playerid, -EXAMC_PRICE);
        UpdatePlayer(playerid, pMoney);

        new bidx = Businesses_FindByID(EXAMC_BIZ_ID);
        if(bidx != -1)
        {
            BusinessData[bidx][bBank] += EXAMC_PRICE;

            new q[128];
            mysql_format(g_SQL, q, sizeof(q), "UPDATE `businesses` SET `bank`=%d WHERE `id`=%d",
                BusinessData[bidx][bBank], BusinessData[bidx][bID]);
            mysql_tquery(g_SQL, q, "", "", 0);
        }

        g_ExamCState[playerid]      = EXAMC_STATE_WAITING_TRUCK;
        g_ExamCCheckpoint[playerid] = 0;
        g_ExamCVehicle[playerid]    = -1;
        g_ExamCTrailerVeh[playerid] = -1;
        ExamC_StartStepTimer(playerid);

        SendClientMessage(playerid, COLOR_INFO,
            C_INFO"Info: "C_WHITE"Get into a "C_INFO"truck"C_WHITE" within "C_INFO"30 seconds"C_WHITE" to start the exam.");
        return 1;
    }

    // ---- /changehouseprice [id] [pret_nou] ----
    if(strcmp(cmd, "/changehouseprice", true) == 0)
    {
        if(PlayerData[playerid][pAdminLevel] < 6)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have access. Requires admin level 6."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new p1[8], p2[16];
        strmid(p1, cmdtext, idx, strlen(cmdtext), 8);
        new hid = strval(p1);
        while(cmdtext[idx] > ' ') idx++;
        while(cmdtext[idx] == ' ') idx++;
        strmid(p2, cmdtext, idx, strlen(cmdtext), 16);
        new newPrice = strval(p2);

        if(!strlen(p1) || !strlen(p2))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/changehouseprice [id] [new_price]"C_WHITE"."), 1;

        new hidx = Houses_FindByID(hid);
        if(hidx == -1)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"House not found."), 1;

        if(newPrice <= 0)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Invalid price."), 1;

        HouseData[hidx][hPrice] = newPrice;

        new q[128];
        mysql_format(g_SQL, q, sizeof(q), "UPDATE `houses` SET `price`=%d WHERE `id`=%d", newPrice, hid);
        mysql_tquery(g_SQL, q, "", "", 0);

        new lmsg[128];
        format(lmsg, sizeof(lmsg), C_SUCCESS"[ADM]Success: "C_WHITE"The price of house "C_INFO"%s"C_WHITE" was changed to "C_INFO"$%d"C_WHITE".",
            HouseData[hidx][hName], newPrice);
        SendClientMessage(playerid, COLOR_SUCCESS, lmsg);
        return 1;
    }

    // ---- /changehouseowner [id] [playerid] ----
    if(strcmp(cmd, "/changehouseowner", true) == 0)
    {
        if(PlayerData[playerid][pAdminLevel] < 6)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have access. Requires admin level 6."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new p1[8], p2[8];
        strmid(p1, cmdtext, idx, strlen(cmdtext), 8);
        new hid = strval(p1);
        while(cmdtext[idx] > ' ') idx++;
        while(cmdtext[idx] == ' ') idx++;
        strmid(p2, cmdtext, idx, strlen(cmdtext), 8);
        new targetid = strval(p2);

        if(!strlen(p1) || !strlen(p2))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/changehouseowner [id] [playerid]"C_WHITE"."), 1;

        new hidx = Houses_FindByID(hid);
        if(hidx == -1)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"House not found."), 1;

        if(!IsPlayerConnected(targetid) || !PlayerData[targetid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"The player is not connected."), 1;

        // Daca exista un vechi Owner, ii resetam pHouse
        if(HouseData[hidx][hOwned] && HouseData[hidx][hOwnerId] != 0)
        {
            new oldOwnerPID = HouseData[hidx][hOwnerId];
            new oldOwnerPlayer = Houses_FindPlayerByPID(oldOwnerPID);
            if(oldOwnerPlayer != INVALID_PLAYER_ID)
            {
                PlayerData[oldOwnerPlayer][pHouse] = 999;
                UpdatePlayer(oldOwnerPlayer, pHouse);
            }
            else
            {
                new qold[128];
                mysql_format(g_SQL, qold, sizeof(qold), "UPDATE `players` SET `house`=999 WHERE `id`=%d", oldOwnerPID);
                mysql_tquery(g_SQL, qold, "", "", 0);
            }
        }

        PlayerData[targetid][pHouse] = HouseData[hidx][hID];
        UpdatePlayer(targetid, pHouse);

        HouseData[hidx][hOwnerId] = PlayerData[targetid][pID];
        HouseData[hidx][hOwned]   = 1;
        GetPlayerName(targetid, HouseData[hidx][hOwner], 24);

        Houses_RecreatePickup(hidx);

        new q[256];
        mysql_format(g_SQL, q, sizeof(q),
            "UPDATE `houses` SET `owner`='%e', `owner_id`=%d, `owned`=1 WHERE `id`=%d",
            HouseData[hidx][hOwner], HouseData[hidx][hOwnerId], HouseData[hidx][hID]);
        mysql_tquery(g_SQL, q, "", "", 0);

        new lmsg[128];
        format(lmsg, sizeof(lmsg), C_SUCCESS"[ADM] Success: "C_WHITE"The owner of house "C_INFO"%s"C_WHITE" was changed to "C_INFO"%s"C_WHITE".",
            HouseData[hidx][hName], HouseData[hidx][hOwner]);
        SendClientMessage(playerid, COLOR_SUCCESS, lmsg);
        return 1;
    }

    // ---- /vbuy ----
    if(strcmp(cmd, "/vbuy", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        new vehid = GetPlayerVehicleID(playerid);
        if(vehid == 0)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be in a vehicle."), 1;

        new pvidx = g_VehicleToPVIndex[vehid];
        if(pvidx == -1)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"This is not a personal vehicle."), 1;

        if(PVehicleData[pvidx][pvOwnerId] != 0)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"This vehicle already has an owner."), 1;

        new E_PLAYER_DATA:slot = PVehicles_FindFreeKeySlot(playerid);
        if(slot == E_PLAYER_DATA:-1)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You already own "C_INFO#MAX_PLAYER_VEHICLES C_WHITE" personal vehicles."), 1;

        if(PlayerData[playerid][pMoney] < PVehicleData[pvidx][pvPrice])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have enough money."), 1;

        PlayerData[playerid][pMoney] -= PVehicleData[pvidx][pvPrice];
        GivePlayerMoney(playerid, -PVehicleData[pvidx][pvPrice]);
        UpdatePlayer(playerid, pMoney);

        PVehicleData[pvidx][pvOwnerId] = PlayerData[playerid][pID];
        PlayerData[playerid][slot] = PVehicleData[pvidx][pvID];
        UpdatePlayer(playerid, slot);
        PVehicles_RecreateLabel(pvidx);

        new engine, lights, alarm, doors, bonnet, boot, objective;
        GetVehicleParamsEx(vehid, engine, lights, alarm, doors, bonnet, boot, objective);
        SetVehicleParamsEx(vehid, 1, lights, alarm, doors, bonnet, boot, objective);

        PVehicleData[pvidx][pvInsuranceExp]    = gettime() + VEHICLE_DOC_DURATION;
        PVehicleData[pvidx][pvMedkitExp]       = gettime() + VEHICLE_DOC_DURATION;
        PVehicleData[pvidx][pvExtinguisherExp] = gettime() + VEHICLE_DOC_DURATION;
        PVehicleData[pvidx][pvITPExp]          = gettime() + VEHICLE_DOC_DURATION;

        new insDate[11], medDate[11], extDate[11], itpDate[11];
        UnixToDateStr(PVehicleData[pvidx][pvInsuranceExp], insDate, sizeof(insDate));
        UnixToDateStr(PVehicleData[pvidx][pvMedkitExp], medDate, sizeof(medDate));
        UnixToDateStr(PVehicleData[pvidx][pvExtinguisherExp], extDate, sizeof(extDate));
        UnixToDateStr(PVehicleData[pvidx][pvITPExp], itpDate, sizeof(itpDate));

        new q[256];
        mysql_format(g_SQL, q, sizeof(q),
            "UPDATE `vehicles_personal` SET `owner_id`=%d, `insurance_exp`='%s', `medkit_exp`='%s', `extinguisher_exp`='%s', `itp_exp`='%s' WHERE `id`=%d",
            PVehicleData[pvidx][pvOwnerId], insDate, medDate, extDate, itpDate, PVehicleData[pvidx][pvID]);
        mysql_tquery(g_SQL, q, "", "", 0);

        new lmsg[160];
        format(lmsg, sizeof(lmsg),
            C_SUCCESS"Success: "C_WHITE"You bought the vehicle (ID: "C_INFO"%d"C_WHITE") for "C_INFO"$%d"C_WHITE". \
The insurance, medkit, extinguisher and ITP are valid for "C_INFO"7 days"C_WHITE".",
            PVehicleData[pvidx][pvID], PVehicleData[pvidx][pvPrice]);
        SendClientMessage(playerid, COLOR_SUCCESS, lmsg);
        return 1;
    }

    // ---- /vsell ----
    if(strcmp(cmd, "/vsell", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        new vehid = GetPlayerVehicleID(playerid);
        if(vehid == 0)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be in a vehicle."), 1;

        new pvidx = g_VehicleToPVIndex[vehid];
        if(pvidx == -1)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"This is not a personal vehicle."), 1;

        if(PVehicleData[pvidx][pvOwnerId] != PlayerData[playerid][pID])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't own this vehicle."), 1;

        new refund = PVehicleData[pvidx][pvPrice] / 2;
        PlayerData[playerid][pMoney] += refund;
        GivePlayerMoney(playerid, refund);
        UpdatePlayer(playerid, pMoney);

        PVehicles_ClearKeySlot(playerid, PVehicleData[pvidx][pvID]);
        PVehicleData[pvidx][pvOwnerId] = 0;
        PVehicles_RecreateLabel(pvidx);

        new engine, lights, alarm, doors, bonnet, boot, objective;
        GetVehicleParamsEx(vehid, engine, lights, alarm, doors, bonnet, boot, objective);
        SetVehicleParamsEx(vehid, 0, lights, alarm, doors, bonnet, boot, objective);

        new q[128];
        mysql_format(g_SQL, q, sizeof(q), "UPDATE `vehicles_personal` SET `owner_id`=0 WHERE `id`=%d", PVehicleData[pvidx][pvID]);
        mysql_tquery(g_SQL, q, "", "", 0);

        new lmsg[128];
        format(lmsg, sizeof(lmsg), C_SUCCESS"Success: "C_WHITE"You sold the vehicle (ID: "C_INFO"%d"C_WHITE") for "C_INFO"$%d"C_WHITE".",
            PVehicleData[pvidx][pvID], refund);
        SendClientMessage(playerid, COLOR_SUCCESS, lmsg);
        return 1;
    }

    // ---- /vsellto [playerid] ----
    if(strcmp(cmd, "/vsellto", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        new vehid = GetPlayerVehicleID(playerid);
        if(vehid == 0)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be in a vehicle."), 1;

        new pvidx = g_VehicleToPVIndex[vehid];
        if(pvidx == -1)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"This is not a personal vehicle."), 1;

        if(PVehicleData[pvidx][pvOwnerId] != PlayerData[playerid][pID])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't own this vehicle."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new p1[8];
        strmid(p1, cmdtext, idx, strlen(cmdtext), 8);

        if(!strlen(p1))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/vsellto [playerid]"C_WHITE"."), 1;

        new targetid = strval(p1);
        if(!IsPlayerConnected(targetid) || !PlayerData[targetid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"The player is not connected."), 1;

        if(targetid == playerid)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You can't sell to yourself."), 1;

        new Float:px, Float:py, Float:pz;
        GetPlayerPos(playerid, px, py, pz);
        if(!IsPlayerInRangeOfPoint(targetid, VSELLTO_RANGE, px, py, pz))
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"The player must be within 10m."), 1;

        new E_PLAYER_DATA:slot = PVehicles_FindFreeKeySlot(targetid);
        if(slot == E_PLAYER_DATA:-1)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"The player already owns "C_INFO#MAX_PLAYER_VEHICLES C_WHITE" personal vehicles."), 1;

        PVehicles_ClearKeySlot(playerid, PVehicleData[pvidx][pvID]);

        PVehicleData[pvidx][pvOwnerId] = PlayerData[targetid][pID];
        PlayerData[targetid][slot] = PVehicleData[pvidx][pvID];
        UpdatePlayer(targetid, slot);

        new q[128];
        mysql_format(g_SQL, q, sizeof(q), "UPDATE `vehicles_personal` SET `owner_id`=%d WHERE `id`=%d",
            PVehicleData[pvidx][pvOwnerId], PVehicleData[pvidx][pvID]);
        mysql_tquery(g_SQL, q, "", "", 0);

        new lmsg[128];
        format(lmsg, sizeof(lmsg), C_SUCCESS"Success: "C_WHITE"You transferred the vehicle (ID: "C_INFO"%d"C_WHITE") to "C_INFO"%s"C_WHITE".",
            PVehicleData[pvidx][pvID], PlayerData[targetid][pName]);
        SendClientMessage(playerid, COLOR_SUCCESS, lmsg);

        format(lmsg, sizeof(lmsg), C_INFO"Info: "C_WHITE"You received the vehicle (ID: "C_INFO"%d"C_WHITE") from "C_INFO"%s"C_WHITE".",
            PVehicleData[pvidx][pvID], PlayerData[playerid][pName]);
        SendClientMessage(targetid, COLOR_INFO, lmsg);
        return 1;
    }

    // ---- /vcolor [1/2] [colorID] ----
    if(strcmp(cmd, "/vcolor", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        new vehid = GetPlayerVehicleID(playerid);
        if(vehid == 0)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be in a vehicle."), 1;

        new pvidx = g_VehicleToPVIndex[vehid];
        if(pvidx == -1)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"This is not a personal vehicle."), 1;

        if(PVehicleData[pvidx][pvOwnerId] != PlayerData[playerid][pID])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't own this vehicle."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new p1[4], p2[8];
        strmid(p1, cmdtext, idx, strlen(cmdtext), 4);
        while(cmdtext[idx] > ' ') idx++;
        while(cmdtext[idx] == ' ') idx++;
        strmid(p2, cmdtext, idx, strlen(cmdtext), 8);

        if(!strlen(p1) || !strlen(p2))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/vcolor [1/2] [colorID]"C_WHITE"."), 1;

        new slotNum = strval(p1);
        new colorId = strval(p2);
        if(slotNum != 1 && slotNum != 2)
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/vcolor [1/2] [colorID]"C_WHITE"."), 1;

        if(slotNum == 1) PVehicleData[pvidx][pvColor1] = colorId;
        else PVehicleData[pvidx][pvColor2] = colorId;

        ChangeVehicleColor(vehid, PVehicleData[pvidx][pvColor1], PVehicleData[pvidx][pvColor2]);

        new q[128];
        mysql_format(g_SQL, q, sizeof(q), "UPDATE `vehicles_personal` SET `color1`=%d, `color2`=%d WHERE `id`=%d",
            PVehicleData[pvidx][pvColor1], PVehicleData[pvidx][pvColor2], PVehicleData[pvidx][pvID]);
        mysql_tquery(g_SQL, q, "", "", 0);

        SendClientMessage(playerid, COLOR_SUCCESS, C_SUCCESS"Success: "C_WHITE"The vehicle's color has been changed.");
        return 1;
    }

    // ---- /vplate [text] ----
    if(strcmp(cmd, "/vplate", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        new vehid = GetPlayerVehicleID(playerid);
        if(vehid == 0)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be in a vehicle."), 1;

        new pvidx = g_VehicleToPVIndex[vehid];
        if(pvidx == -1)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"This is not a personal vehicle."), 1;

        if(PVehicleData[pvidx][pvOwnerId] != PlayerData[playerid][pID])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't own this vehicle."), 1;

        if(!IsPlayerInRangeOfPoint(playerid, PLATE_RANGE, PLATE_LOC_X, PLATE_LOC_Y, PLATE_LOC_Z))
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be at the R.A.R. headquarters."), 1;

        if(PlayerData[playerid][pMoney] < g_PlatePrice)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have enough money."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new plate[11];
        strmid(plate, cmdtext, idx, strlen(cmdtext), 10);

        if(!strlen(plate))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/vplate [NUMBER] (Ex: LV 001 AAA)"C_WHITE" (max 10 characters)."), 1;

        new q[160];
        mysql_format(g_SQL, q, sizeof(q),
            "SELECT `id` FROM `vehicles_personal` WHERE `plate`='%e' AND `id`!=%d LIMIT 1",
            plate, PVehicleData[pvidx][pvID]);
        mysql_tquery(g_SQL, q, "OnVehiclePlateChecked", "iis", playerid, pvidx, plate);
        return 1;
    }

    // ---- /vinsurance ----
    if(strcmp(cmd, "/vinsurance", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        new vehid = GetPlayerVehicleID(playerid);
        if(vehid == 0)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be in a vehicle."), 1;

        new pvidx = g_VehicleToPVIndex[vehid];
        if(pvidx == -1)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"This is not a personal vehicle."), 1;

        if(PVehicleData[pvidx][pvOwnerId] != PlayerData[playerid][pID])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't own this vehicle."), 1;

        if(PVehicleData[pvidx][pvInsuranceExp] > gettime())
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"The insurance is still valid."), 1;

        if(PlayerData[playerid][pMoney] < g_InsurancePrice)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have enough money."), 1;

        PlayerData[playerid][pMoney] -= g_InsurancePrice;
        GivePlayerMoney(playerid, -g_InsurancePrice);
        UpdatePlayer(playerid, pMoney);

        PVehicleData[pvidx][pvInsuranceExp] = gettime() + VEHICLE_INSURANCE_DURATION;

        new dateStr[11];
        UnixToDateStr(PVehicleData[pvidx][pvInsuranceExp], dateStr, sizeof(dateStr));

        new q[128];
        mysql_format(g_SQL, q, sizeof(q), "UPDATE `vehicles_personal` SET `insurance_exp`='%s' WHERE `id`=%d",
            dateStr, PVehicleData[pvidx][pvID]);
        mysql_tquery(g_SQL, q, "", "", 0);

        new lmsg[128];
        format(lmsg, sizeof(lmsg), C_SUCCESS"Success: "C_WHITE"You bought insurance ("C_INFO"5 days"C_WHITE") for "C_INFO"$%d"C_WHITE".", g_InsurancePrice);
        SendClientMessage(playerid, COLOR_SUCCESS, lmsg);
        return 1;
    }

    // ---- /vmedicalkit ----
    if(strcmp(cmd, "/vmedicalkit", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        new vehid = GetPlayerVehicleID(playerid);
        if(vehid == 0)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be in a vehicle."), 1;

        new pvidx = g_VehicleToPVIndex[vehid];
        if(pvidx == -1)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"This is not a personal vehicle."), 1;

        if(PVehicleData[pvidx][pvOwnerId] != PlayerData[playerid][pID])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't own this vehicle."), 1;

        if(PVehicleData[pvidx][pvMedkitExp] > gettime())
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"The medical kit is still valid."), 1;

        if(PlayerData[playerid][pMoney] < g_MedkitPrice)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have enough money."), 1;

        PlayerData[playerid][pMoney] -= g_MedkitPrice;
        GivePlayerMoney(playerid, -g_MedkitPrice);
        UpdatePlayer(playerid, pMoney);

        PVehicleData[pvidx][pvMedkitExp] = gettime() + VEHICLE_MEDKIT_DURATION;

        new dateStr[11];
        UnixToDateStr(PVehicleData[pvidx][pvMedkitExp], dateStr, sizeof(dateStr));

        new q[128];
        mysql_format(g_SQL, q, sizeof(q), "UPDATE `vehicles_personal` SET `medkit_exp`='%s' WHERE `id`=%d",
            dateStr, PVehicleData[pvidx][pvID]);
        mysql_tquery(g_SQL, q, "", "", 0);

        new lmsg[128];
        format(lmsg, sizeof(lmsg), C_SUCCESS"Success: "C_WHITE"You bought a medical kit ("C_INFO"7 days"C_WHITE") for "C_INFO"$%d"C_WHITE".", g_MedkitPrice);
        SendClientMessage(playerid, COLOR_SUCCESS, lmsg);
        return 1;
    }

    // ---- /vextinctor ----
    if(strcmp(cmd, "/vextinctor", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        new vehid = GetPlayerVehicleID(playerid);
        if(vehid == 0)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be in a vehicle."), 1;

        new pvidx = g_VehicleToPVIndex[vehid];
        if(pvidx == -1)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"This is not a personal vehicle."), 1;

        if(PVehicleData[pvidx][pvOwnerId] != PlayerData[playerid][pID])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't own this vehicle."), 1;

        if(PVehicleData[pvidx][pvExtinguisherExp] > gettime())
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"The extinguisher is still valid."), 1;

        if(PlayerData[playerid][pMoney] < g_ExtinguisherPrice)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have enough money."), 1;

        PlayerData[playerid][pMoney] -= g_ExtinguisherPrice;
        GivePlayerMoney(playerid, -g_ExtinguisherPrice);
        UpdatePlayer(playerid, pMoney);

        PVehicleData[pvidx][pvExtinguisherExp] = gettime() + VEHICLE_EXTINGUISHER_DURATION;

        new dateStr[11];
        UnixToDateStr(PVehicleData[pvidx][pvExtinguisherExp], dateStr, sizeof(dateStr));

        new q[128];
        mysql_format(g_SQL, q, sizeof(q), "UPDATE `vehicles_personal` SET `extinguisher_exp`='%s' WHERE `id`=%d",
            dateStr, PVehicleData[pvidx][pvID]);
        mysql_tquery(g_SQL, q, "", "", 0);

        new lmsg[128];
        format(lmsg, sizeof(lmsg), C_SUCCESS"Success: "C_WHITE"You bought an extinguisher ("C_INFO"10 days"C_WHITE") for "C_INFO"$%d"C_WHITE".", g_ExtinguisherPrice);
        SendClientMessage(playerid, COLOR_SUCCESS, lmsg);
        return 1;
    }

    // ---- /vpark ----
    if(strcmp(cmd, "/vpark", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        new vehid = GetPlayerVehicleID(playerid);
        if(vehid == 0)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be in a vehicle."), 1;

        new pvidx = g_VehicleToPVIndex[vehid];
        if(pvidx == -1)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"This is not a personal vehicle."), 1;

        if(PVehicleData[pvidx][pvOwnerId] != PlayerData[playerid][pID])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't own this vehicle."), 1;

        GetVehiclePos(vehid, PVehicleData[pvidx][pvLocX], PVehicleData[pvidx][pvLocY], PVehicleData[pvidx][pvLocZ]);
        GetVehicleZAngle(vehid, PVehicleData[pvidx][pvRotation]);

        new q[256];
        mysql_format(g_SQL, q, sizeof(q),
            "UPDATE `vehicles_personal` SET `loc_x`=%.4f, `loc_y`=%.4f, `loc_z`=%.4f, `rotation`=%.4f WHERE `id`=%d",
            PVehicleData[pvidx][pvLocX], PVehicleData[pvidx][pvLocY], PVehicleData[pvidx][pvLocZ], PVehicleData[pvidx][pvRotation],
            PVehicleData[pvidx][pvID]);
        mysql_tquery(g_SQL, q, "", "", 0);

        SendClientMessage(playerid, COLOR_SUCCESS, C_SUCCESS"Success: "C_WHITE"The vehicle has been parked (position saved).");
        return 1;
    }

    // ---- /licenses ----
    if(strcmp(cmd, "/licenses", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        new statusA[24], statusB[24], statusC[24], statusD[24];
        License_FormatStatus(PlayerData[playerid][pDrivingLicA_exp], statusA, sizeof(statusA));
        License_FormatStatus(PlayerData[playerid][pDrivingLicB_exp], statusB, sizeof(statusB));
        License_FormatStatus(PlayerData[playerid][pDrivingLicC_exp], statusC, sizeof(statusC));
        License_FormatStatus(PlayerData[playerid][pDrivingLicD_exp], statusD, sizeof(statusD));

        SendClientMessage(playerid, COLOR_INFO, C_INFO"_____ Your Licenses ____________________");

        new line[128];
        format(line, sizeof(line), "Category A (Moto/ATV): "C_INFO"%s", statusA);
        SendClientMessage(playerid, COLOR_WHITE, line);
        format(line, sizeof(line), "Category B (Cars): "C_INFO"%s", statusB);
        SendClientMessage(playerid, COLOR_WHITE, line);
        format(line, sizeof(line), "Category C (Trucks): "C_INFO"%s", statusC);
        SendClientMessage(playerid, COLOR_WHITE, line);
        format(line, sizeof(line), "Category D (Bus): "C_INFO"%s", statusD);
        SendClientMessage(playerid, COLOR_WHITE, line);

        SendClientMessage(playerid, COLOR_INFO, C_INFO"___________________________________________");
        return 1;
    }

    // ---- /vstats ----
    if(strcmp(cmd, "/vstats", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        new keys[MAX_PLAYER_VEHICLES];
        keys[0] = PlayerData[playerid][pKey1];
        keys[1] = PlayerData[playerid][pKey2];
        keys[2] = PlayerData[playerid][pKey3];

        SendClientMessage(playerid, COLOR_INFO, C_INFO"_____ Your Vehicles ____________________________");

        new bool:any = false;
        for(new k = 0; k < MAX_PLAYER_VEHICLES; k++)
        {
            if(keys[k] == 0) continue;
            new pvidx = PVehicles_FindByVID(keys[k]);
            if(pvidx == -1) continue;
            any = true;

            new vname[24];
            GetVehicleModelName(PVehicleData[pvidx][pvModelID], vname, sizeof(vname));

            new insStatus[16], medStatus[16], extStatus[16], itpStatus[16];
            VehicleDoc_Status(PVehicleData[pvidx][pvInsuranceExp], insStatus, sizeof(insStatus));
            VehicleDoc_Status(PVehicleData[pvidx][pvMedkitExp], medStatus, sizeof(medStatus));
            VehicleDoc_Status(PVehicleData[pvidx][pvExtinguisherExp], extStatus, sizeof(extStatus));
            VehicleDoc_Status(PVehicleData[pvidx][pvITPExp], itpStatus, sizeof(itpStatus));

            new line[256];
            format(line, sizeof(line),
                "[ID: %d] %s | Plate: %s | Insurance: %s | Medkit: %s | Extinguisher: %s | ITP: %s",
                PVehicleData[pvidx][pvID], vname, PVehicleData[pvidx][pvPlate], insStatus, medStatus, extStatus, itpStatus);
            SendClientMessage(playerid, COLOR_WHITE, line);
        }

        if(!any)
            SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"You don't own any personal vehicles.");

        SendClientMessage(playerid, COLOR_INFO, C_INFO"___________________________________________________");
        return 1;
    }

    // ---- /vitp ----
    if(strcmp(cmd, "/vitp", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        if(!IsPlayerInRangeOfPoint(playerid, ITP_RANGE, ITP_LOC_X, ITP_LOC_Y, ITP_LOC_Z))
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be at the R.A.R. headquarters."), 1;

        new vehid = GetPlayerVehicleID(playerid);
        if(vehid == 0 || GetPlayerVehicleSeat(playerid) != 0)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be the driver of a personal vehicle."), 1;

        new pvidx = g_VehicleToPVIndex[vehid];
        if(pvidx == -1)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"This is not a personal vehicle."), 1;

        if(PVehicleData[pvidx][pvOwnerId] != PlayerData[playerid][pID])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't own this vehicle."), 1;

        if(PVehicleData[pvidx][pvITPExp] > gettime())
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"The ITP is still valid."), 1;

        if(PlayerData[playerid][pMoney] < g_ITPPrice)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have enough money."), 1;

        PlayerData[playerid][pMoney] -= g_ITPPrice;
        GivePlayerMoney(playerid, -g_ITPPrice);
        UpdatePlayer(playerid, pMoney);
        Faction_AddBank(FACTION_RAR, g_ITPPrice);

        GameTextForPlayer(playerid, "~w~Checking the car...", ITP_CHECK_TIME, 3);
        TogglePlayerControllable(playerid, 0);

        SetTimerEx("OnVehicleITPCheck", ITP_CHECK_TIME, false, "iii", playerid, pvidx, vehid);

        SendClientMessage(playerid, COLOR_INFO,
            C_INFO"Info: "C_WHITE"The ITP check has started. Wait "C_INFO"10 seconds"C_WHITE".");
        return 1;
    }

    // ---- /vcreate [pret] ----
    if(strcmp(cmd, "/vcreate", true) == 0)
    {
        if(PlayerData[playerid][pAdminLevel] < 6)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have access. Requires admin level 6."), 1;

        if(g_PVehicleCount >= MAX_PERSONAL_VEHICLES)
            return SendClientMessage(playerid, COLOR_ERROR,
                C_ERROR"Error: "C_WHITE"Limit of "C_INFO#MAX_PERSONAL_VEHICLES C_WHITE" personal vehicles reached."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new p1[16];
        strmid(p1, cmdtext, idx, strlen(cmdtext), 16);

        if(!strlen(p1))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/vcreate [price]"C_WHITE"."), 1;

        new price = strval(p1);
        if(price <= 0)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Invalid price."), 1;

        new vehid = GetPlayerVehicleID(playerid);
        if(vehid == 0)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be in a vehicle."), 1;

        new Float:vx, Float:vy, Float:vz, Float:vangle;
        GetVehiclePos(vehid, vx, vy, vz);
        GetVehicleZAngle(vehid, vangle);
        new model = GetVehicleModel(vehid);

        new newIdx = g_PVehicleCount;
        PVehicleData[newIdx][pvOwnerId]         = 0;
        PVehicleData[newIdx][pvModelID]         = model;
        PVehicleData[newIdx][pvColor1]          = 1;
        PVehicleData[newIdx][pvColor2]          = 1;
        format(PVehicleData[newIdx][pvPlate], 16, "NoRP");
        PVehicleData[newIdx][pvPrice]           = price;
        PVehicleData[newIdx][pvLocX]            = vx;
        PVehicleData[newIdx][pvLocY]            = vy;
        PVehicleData[newIdx][pvLocZ]            = vz;
        PVehicleData[newIdx][pvRotation]        = vangle;
        PVehicleData[newIdx][pvInsuranceExp]    = 0;
        PVehicleData[newIdx][pvMedkitExp]       = 0;
        PVehicleData[newIdx][pvExtinguisherExp] = 0;
        PVehicleData[newIdx][pvITPExp]          = 0;
        g_PVehicleVehicle[newIdx]               = -1;
        g_PVehicleCount++;

        new q[256];
        mysql_format(g_SQL, q, sizeof(q),
            "INSERT INTO `vehicles_personal` (`owner_id`,`model_id`,`color1`,`color2`,`plate`,`price`,`loc_x`,`loc_y`,`loc_z`,`rotation`) \
             VALUES (0,%d,1,1,NULL,%d,%.4f,%.4f,%.4f,%.4f)",
            model, price, vx, vy, vz, vangle);
        mysql_tquery(g_SQL, q, "OnVehiclePersonalCreated", "ii", playerid, newIdx);
        return 1;
    }

    // ---- /vsetprice [new_price] ----
    if(strcmp(cmd, "/vsetprice", true) == 0)
    {
        if(PlayerData[playerid][pAdminLevel] < 6)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have access. Requires admin level 6."), 1;

        new vehid = GetPlayerVehicleID(playerid);
        if(vehid == 0)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be in a vehicle."), 1;

        new pvidx = g_VehicleToPVIndex[vehid];
        if(pvidx == -1)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"This is not a personal vehicle."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new p1[16];
        strmid(p1, cmdtext, idx, strlen(cmdtext), 16);

        if(!strlen(p1))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/vsetprice [new_price]"C_WHITE"."), 1;

        new newPrice = strval(p1);
        if(newPrice <= 0)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Invalid price."), 1;

        PVehicleData[pvidx][pvPrice] = newPrice;
        PVehicles_RecreateLabel(pvidx);

        new q[128];
        mysql_format(g_SQL, q, sizeof(q), "UPDATE `vehicles_personal` SET `price`=%d WHERE `id`=%d",
            newPrice, PVehicleData[pvidx][pvID]);
        mysql_tquery(g_SQL, q, "", "", 0);

        new lmsg[128];
        format(lmsg, sizeof(lmsg), C_SUCCESS"[ADM]Success: "C_WHITE"The price of vehicle (ID: "C_INFO"%d"C_WHITE") was changed to "C_INFO"$%d"C_WHITE".",
            PVehicleData[pvidx][pvID], newPrice);
        SendClientMessage(playerid, COLOR_SUCCESS, lmsg);
        return 1;
    }

    // ---- /vchangeinsuranceexp [new_date] ----
    if(strcmp(cmd, "/vchangeinsuranceexp", true) == 0)
    {
        if(PlayerData[playerid][pAdminLevel] < 5)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have access. Requires admin level 5."), 1;

        new vehid = GetPlayerVehicleID(playerid);
        if(vehid == 0)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be in a vehicle."), 1;

        new pvidx = g_VehicleToPVIndex[vehid];
        if(pvidx == -1)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"This is not a personal vehicle."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new dateStr[16];
        strmid(dateStr, cmdtext, idx, strlen(cmdtext), 16);

        if(!strlen(dateStr))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/vchangeinsuranceexp [YYYY-MM-DD]"C_WHITE"."), 1;

        if(!IsValidDateStr(dateStr))
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Invalid format. Use "C_INFO"YYYY-MM-DD"C_WHITE"."), 1;

        PVehicleData[pvidx][pvInsuranceExp] = DateStrToUnix(dateStr);

        new q[128];
        mysql_format(g_SQL, q, sizeof(q), "UPDATE `vehicles_personal` SET `insurance_exp`='%s' WHERE `id`=%d",
            dateStr, PVehicleData[pvidx][pvID]);
        mysql_tquery(g_SQL, q, "", "", 0);

        new lmsg[128];
        format(lmsg, sizeof(lmsg),
            C_SUCCESS"[ADM]Success: "C_WHITE"The insurance expiry date (ID: "C_INFO"%d"C_WHITE") was changed to "C_INFO"%s"C_WHITE".",
            PVehicleData[pvidx][pvID], dateStr);
        SendClientMessage(playerid, COLOR_SUCCESS, lmsg);
        return 1;
    }

    // ---- /vchangemedkitexp [new_date] ----
    if(strcmp(cmd, "/vchangemedkitexp", true) == 0)
    {
        if(PlayerData[playerid][pAdminLevel] < 5)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have access. Requires admin level 5."), 1;

        new vehid = GetPlayerVehicleID(playerid);
        if(vehid == 0)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be in a vehicle."), 1;

        new pvidx = g_VehicleToPVIndex[vehid];
        if(pvidx == -1)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"This is not a personal vehicle."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new dateStr[16];
        strmid(dateStr, cmdtext, idx, strlen(cmdtext), 16);

        if(!strlen(dateStr))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/vchangemedkitexp [YYYY-MM-DD]"C_WHITE"."), 1;

        if(!IsValidDateStr(dateStr))
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Invalid format. Use "C_INFO"YYYY-MM-DD"C_WHITE"."), 1;

        PVehicleData[pvidx][pvMedkitExp] = DateStrToUnix(dateStr);

        new q[128];
        mysql_format(g_SQL, q, sizeof(q), "UPDATE `vehicles_personal` SET `medkit_exp`='%s' WHERE `id`=%d",
            dateStr, PVehicleData[pvidx][pvID]);
        mysql_tquery(g_SQL, q, "", "", 0);

        new lmsg[128];
        format(lmsg, sizeof(lmsg),
            C_SUCCESS"[ADM]Success: "C_WHITE"The medkit expiry date (ID: "C_INFO"%d"C_WHITE") was changed to "C_INFO"%s"C_WHITE".",
            PVehicleData[pvidx][pvID], dateStr);
        SendClientMessage(playerid, COLOR_SUCCESS, lmsg);
        return 1;
    }

    // ---- /vchangeextinctorexp [new_date] ----
    if(strcmp(cmd, "/vchangeextinctorexp", true) == 0)
    {
        if(PlayerData[playerid][pAdminLevel] < 5)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have access. Requires admin level 5."), 1;

        new vehid = GetPlayerVehicleID(playerid);
        if(vehid == 0)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be in a vehicle."), 1;

        new pvidx = g_VehicleToPVIndex[vehid];
        if(pvidx == -1)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"This is not a personal vehicle."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new dateStr[16];
        strmid(dateStr, cmdtext, idx, strlen(cmdtext), 16);

        if(!strlen(dateStr))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/vchangeextinctorexp [YYYY-MM-DD]"C_WHITE"."), 1;

        if(!IsValidDateStr(dateStr))
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Invalid format. Use "C_INFO"YYYY-MM-DD"C_WHITE"."), 1;

        PVehicleData[pvidx][pvExtinguisherExp] = DateStrToUnix(dateStr);

        new q[128];
        mysql_format(g_SQL, q, sizeof(q), "UPDATE `vehicles_personal` SET `extinguisher_exp`='%s' WHERE `id`=%d",
            dateStr, PVehicleData[pvidx][pvID]);
        mysql_tquery(g_SQL, q, "", "", 0);

        new lmsg[128];
        format(lmsg, sizeof(lmsg),
            C_SUCCESS"[ADM]Success: "C_WHITE"The extinguisher expiry date (ID: "C_INFO"%d"C_WHITE") was changed to "C_INFO"%s"C_WHITE".",
            PVehicleData[pvidx][pvID], dateStr);
        SendClientMessage(playerid, COLOR_SUCCESS, lmsg);
        return 1;
    }

    // ---- /vchangeitpexp [new_date] ----
    if(strcmp(cmd, "/vchangeitpexp", true) == 0)
    {
        if(PlayerData[playerid][pAdminLevel] < 5)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have access. Requires admin level 5."), 1;

        new vehid = GetPlayerVehicleID(playerid);
        if(vehid == 0)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be in a vehicle."), 1;

        new pvidx = g_VehicleToPVIndex[vehid];
        if(pvidx == -1)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"This is not a personal vehicle."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new dateStr[16];
        strmid(dateStr, cmdtext, idx, strlen(cmdtext), 16);

        if(!strlen(dateStr))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/vchangeitpexp [YYYY-MM-DD]"C_WHITE"."), 1;

        if(!IsValidDateStr(dateStr))
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Invalid format. Use "C_INFO"YYYY-MM-DD"C_WHITE"."), 1;

        PVehicleData[pvidx][pvITPExp] = DateStrToUnix(dateStr);

        new q[128];
        mysql_format(g_SQL, q, sizeof(q), "UPDATE `vehicles_personal` SET `itp_exp`='%s' WHERE `id`=%d",
            dateStr, PVehicleData[pvidx][pvID]);
        mysql_tquery(g_SQL, q, "", "", 0);

        new lmsg[128];
        format(lmsg, sizeof(lmsg),
            C_SUCCESS"[ADM]Success: "C_WHITE"The ITP expiry date (ID: "C_INFO"%d"C_WHITE") was changed to "C_INFO"%s"C_WHITE".",
            PVehicleData[pvidx][pvID], dateStr);
        SendClientMessage(playerid, COLOR_SUCCESS, lmsg);
        return 1;
    }

    // ---- /setdrivingLicAexp [playerid] [date] ----
    if(strcmp(cmd, "/setdrivingLicAexp", true) == 0)
    {
        if(PlayerData[playerid][pAdminLevel] < 3)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have access. Requires admin level 3."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new p1[8];
        strmid(p1, cmdtext, idx, strlen(cmdtext), 8);
        new targetid = strval(p1);
        while(cmdtext[idx] > ' ') idx++;
        while(cmdtext[idx] == ' ') idx++;
        new dateStr[16];
        strmid(dateStr, cmdtext, idx, strlen(cmdtext), 16);

        if(!strlen(p1) || !strlen(dateStr))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/setdrivingLicAexp [playerid] [YYYY-MM-DD]"C_WHITE"."), 1;

        if(!IsPlayerConnected(targetid) || !PlayerData[targetid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"The player is not connected."), 1;

        if(!IsValidDateStr(dateStr))
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Invalid format. Use "C_INFO"YYYY-MM-DD"C_WHITE"."), 1;

        format(PlayerData[targetid][pDrivingLicA_exp], 11, "%s", dateStr);
        UpdatePlayer(targetid, pDrivingLicA_exp);

        new lmsg[150];
        format(lmsg, sizeof(lmsg),
            C_SUCCESS"[ADM]Success: "C_INFO"%s"C_WHITE"'s category "C_INFO"A"C_WHITE" license expires on "C_INFO"%s"C_WHITE".",
            PlayerData[targetid][pName], dateStr);
        SendClientMessage(playerid, COLOR_SUCCESS, lmsg);

        format(lmsg, sizeof(lmsg), C_INFO"Info: "C_WHITE"Your category "C_INFO"A"C_WHITE" license expires on "C_INFO"%s"C_WHITE".", dateStr);
        SendClientMessage(targetid, COLOR_INFO, lmsg);
        return 1;
    }

    // ---- /setdrivingLicBexp [playerid] [date] ----
    if(strcmp(cmd, "/setdrivingLicBexp", true) == 0)
    {
        if(PlayerData[playerid][pAdminLevel] < 3)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have access. Requires admin level 3."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new p1[8];
        strmid(p1, cmdtext, idx, strlen(cmdtext), 8);
        new targetid = strval(p1);
        while(cmdtext[idx] > ' ') idx++;
        while(cmdtext[idx] == ' ') idx++;
        new dateStr[16];
        strmid(dateStr, cmdtext, idx, strlen(cmdtext), 16);

        if(!strlen(p1) || !strlen(dateStr))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/setdrivingLicBexp [playerid] [YYYY-MM-DD]"C_WHITE"."), 1;

        if(!IsPlayerConnected(targetid) || !PlayerData[targetid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"The player is not connected."), 1;

        if(!IsValidDateStr(dateStr))
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Invalid format. Use "C_INFO"YYYY-MM-DD"C_WHITE"."), 1;

        format(PlayerData[targetid][pDrivingLicB_exp], 11, "%s", dateStr);
        UpdatePlayer(targetid, pDrivingLicB_exp);

        new lmsg[150];
        format(lmsg, sizeof(lmsg),
            C_SUCCESS"[ADM]Success: "C_INFO"%s"C_WHITE"'s category "C_INFO"B"C_WHITE" license expires on "C_INFO"%s"C_WHITE".",
            PlayerData[targetid][pName], dateStr);
        SendClientMessage(playerid, COLOR_SUCCESS, lmsg);

        format(lmsg, sizeof(lmsg), C_INFO"Info: "C_WHITE"Your category "C_INFO"B"C_WHITE" license expires on "C_INFO"%s"C_WHITE".", dateStr);
        SendClientMessage(targetid, COLOR_INFO, lmsg);
        return 1;
    }

    // ---- /setdrivingLicCexp [playerid] [date] ----
    if(strcmp(cmd, "/setdrivingLicCexp", true) == 0)
    {
        if(PlayerData[playerid][pAdminLevel] < 3)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have access. Requires admin level 3."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new p1[8];
        strmid(p1, cmdtext, idx, strlen(cmdtext), 8);
        new targetid = strval(p1);
        while(cmdtext[idx] > ' ') idx++;
        while(cmdtext[idx] == ' ') idx++;
        new dateStr[16];
        strmid(dateStr, cmdtext, idx, strlen(cmdtext), 16);

        if(!strlen(p1) || !strlen(dateStr))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/setdrivingLicCexp [playerid] [YYYY-MM-DD]"C_WHITE"."), 1;

        if(!IsPlayerConnected(targetid) || !PlayerData[targetid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"The player is not connected."), 1;

        if(!IsValidDateStr(dateStr))
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Invalid format. Use "C_INFO"YYYY-MM-DD"C_WHITE"."), 1;

        format(PlayerData[targetid][pDrivingLicC_exp], 11, "%s", dateStr);
        UpdatePlayer(targetid, pDrivingLicC_exp);

        new lmsg[150];
        format(lmsg, sizeof(lmsg),
            C_SUCCESS"[ADM]Success: "C_INFO"%s"C_WHITE"'s category "C_INFO"C"C_WHITE" license expires on "C_INFO"%s"C_WHITE".",
            PlayerData[targetid][pName], dateStr);
        SendClientMessage(playerid, COLOR_SUCCESS, lmsg);

        format(lmsg, sizeof(lmsg), C_INFO"Info: "C_WHITE"Your category "C_INFO"C"C_WHITE" license expires on "C_INFO"%s"C_WHITE".", dateStr);
        SendClientMessage(targetid, COLOR_INFO, lmsg);
        return 1;
    }

    // ---- /setdrivingLicDexp [playerid] [date] ----
    if(strcmp(cmd, "/setdrivingLicDexp", true) == 0)
    {
        if(PlayerData[playerid][pAdminLevel] < 3)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have access. Requires admin level 3."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new p1[8];
        strmid(p1, cmdtext, idx, strlen(cmdtext), 8);
        new targetid = strval(p1);
        while(cmdtext[idx] > ' ') idx++;
        while(cmdtext[idx] == ' ') idx++;
        new dateStr[16];
        strmid(dateStr, cmdtext, idx, strlen(cmdtext), 16);

        if(!strlen(p1) || !strlen(dateStr))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/setdrivingLicDexp [playerid] [YYYY-MM-DD]"C_WHITE"."), 1;

        if(!IsPlayerConnected(targetid) || !PlayerData[targetid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"The player is not connected."), 1;

        if(!IsValidDateStr(dateStr))
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Invalid format. Use "C_INFO"YYYY-MM-DD"C_WHITE"."), 1;

        format(PlayerData[targetid][pDrivingLicD_exp], 11, "%s", dateStr);
        UpdatePlayer(targetid, pDrivingLicD_exp);

        new lmsg[150];
        format(lmsg, sizeof(lmsg),
            C_SUCCESS"[ADM]Success: "C_INFO"%s"C_WHITE"'s category "C_INFO"D"C_WHITE" license expires on "C_INFO"%s"C_WHITE".",
            PlayerData[targetid][pName], dateStr);
        SendClientMessage(playerid, COLOR_SUCCESS, lmsg);

        format(lmsg, sizeof(lmsg), C_INFO"Info: "C_WHITE"Your category "C_INFO"D"C_WHITE" license expires on "C_INFO"%s"C_WHITE".", dateStr);
        SendClientMessage(targetid, COLOR_INFO, lmsg);
        return 1;
    }

    // ---- /cspawn ----
    if(strcmp(cmd, "/cspawn", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        // Cicleaza 1->2->3->1, sarind peste tipurile indisponibile (fara factiune / fara casa)
        new newType = PlayerData[playerid][pSpawn];
        for(new tries = 0; tries < 3; tries++)
        {
            newType = (newType >= 3) ? 1 : (newType + 1);

            if(newType == 2)
            {
                new fid = PlayerData[playerid][pFaction];
                if(fid < 1 || fid > MAX_FACTIONS || (FactionData[fid][fHQX] == 0.0 && FactionData[fid][fHQY] == 0.0))
                    continue;
            }
            else if(newType == 3)
            {
                if(PlayerData[playerid][pHouse] == 999 || Houses_FindByID(PlayerData[playerid][pHouse]) == -1)
                    continue;
            }
            break;
        }
        PlayerData[playerid][pSpawn] = newType;

        Player_RecalcSpawn(playerid);
        UpdatePlayer(playerid, pSpawn);

        new spawnName[24];
        switch(PlayerData[playerid][pSpawn])
        {
            case 2: format(spawnName, sizeof(spawnName), "Faction HQ");
            case 3: format(spawnName, sizeof(spawnName), "Personal house");
            default: format(spawnName, sizeof(spawnName), "Civilian spawn");
        }

        new lmsg[128];
        format(lmsg, sizeof(lmsg), C_SUCCESS"Success: "C_WHITE"Spawn point set to: "C_INFO"%s"C_WHITE".", spawnName);
        SendClientMessage(playerid, COLOR_SUCCESS, lmsg);
        return 1;
    }

    // ---- /payday ----
    if(strcmp(cmd, "/payday", true) == 0)
    {
        if(PlayerData[playerid][pAdminLevel] < 5)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have access. Requires admin level 5."), 1;

        PayDay_Apply();
        new lmsg[128];
        format(lmsg, sizeof(lmsg), C_SUCCESS"[ADM]Success: "C_WHITE"You have successfully issued "C_INFO"PayDay"C_WHITE".");
        SendClientMessage(playerid, COLOR_SUCCESS, lmsg);
        return 1;
    }

    // ---- /changefactionhq [id] ----
    if(strcmp(cmd, "/changefactionhq", true) == 0)
    {
        if(PlayerData[playerid][pAdminLevel] < 6)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have access. Requires admin level 6."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new param[8];
        strmid(param, cmdtext, idx, strlen(cmdtext), 8);
        new fid = strval(param);

        if(fid < 1 || fid > MAX_FACTIONS)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Invalid faction ID (1-7)."), 1;

        new Float:hx, Float:hy, Float:hz;
        GetPlayerPos(playerid, hx, hy, hz);

        FactionData[fid][fHQX] = hx;
        FactionData[fid][fHQY] = hy;
        FactionData[fid][fHQZ] = hz;

        new q[256];
        mysql_format(g_SQL, q, sizeof(q),
            "UPDATE `factions` SET `hq_x`=%.4f, `hq_y`=%.4f, `hq_z`=%.4f WHERE `id`=%d",
            hx, hy, hz, fid);
        mysql_tquery(g_SQL, q, "", "", 0);

        Factions_RecreatePickup(fid);
        Factions_RecreateLabel(fid);
        Factions_UpdatePlayersIcons();

        new lmsg[128];
        format(lmsg, sizeof(lmsg), C_SUCCESS"Success: "C_WHITE"HQ for "C_INFO"%s"C_WHITE" set to your position.", FactionData[fid][fName]);
        SendClientMessage(playerid, COLOR_SUCCESS, lmsg);
        return 1;
    }

    // ---- /changefactionhqicon [id] [icon_id] ----
    if(strcmp(cmd, "/changefactionhqicon", true) == 0)
    {
        if(PlayerData[playerid][pAdminLevel] < 6)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have access. Requires admin level 6."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new p1[8], p2[8];
        strmid(p1, cmdtext, idx, strlen(cmdtext), 8);
        new fid = strval(p1);
        while(cmdtext[idx] > ' ') idx++;
        while(cmdtext[idx] == ' ') idx++;
        strmid(p2, cmdtext, idx, strlen(cmdtext), 8);
        new iconid = strval(p2);

        if(fid < 1 || fid > MAX_FACTIONS)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Invalid faction ID (1-7)."), 1;

        FactionData[fid][fMapIconID] = iconid;

        new q[128];
        mysql_format(g_SQL, q, sizeof(q), "UPDATE `factions` SET `mapicon_id`=%d WHERE `id`=%d", iconid, fid);
        mysql_tquery(g_SQL, q, "", "", 0);

        Factions_UpdatePlayersIcons();

        new lmsg[128];
        format(lmsg, sizeof(lmsg), C_SUCCESS"Success: "C_WHITE"Map icon for "C_INFO"%s"C_WHITE" changed to %d.", FactionData[fid][fName], iconid);
        SendClientMessage(playerid, COLOR_SUCCESS, lmsg);
        return 1;
    }

    // ---- /changefactionpickup [id] [pickup_id] ----
    if(strcmp(cmd, "/changefactionpickup", true) == 0)
    {
        if(PlayerData[playerid][pAdminLevel] < 6)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have access. Requires admin level 6."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new p1[8], p2[8];
        strmid(p1, cmdtext, idx, strlen(cmdtext), 8);
        new fid = strval(p1);
        while(cmdtext[idx] > ' ') idx++;
        while(cmdtext[idx] == ' ') idx++;
        strmid(p2, cmdtext, idx, strlen(cmdtext), 8);
        new pickupid = strval(p2);

        if(fid < 1 || fid > MAX_FACTIONS)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Invalid faction ID (1-7)."), 1;

        FactionData[fid][fPickupID] = pickupid;

        new q[128];
        mysql_format(g_SQL, q, sizeof(q), "UPDATE `factions` SET `pickup_id`=%d WHERE `id`=%d", pickupid, fid);
        mysql_tquery(g_SQL, q, "", "", 0);

        Factions_RecreatePickup(fid);

        new lmsg[128];
        format(lmsg, sizeof(lmsg), C_SUCCESS"Success: "C_WHITE"Pickup for "C_INFO"%s"C_WHITE" changed to %d.", FactionData[fid][fName], pickupid);
        SendClientMessage(playerid, COLOR_SUCCESS, lmsg);
        return 1;
    }

    // ---- /changefactionlead [id] [playerid] ----
    if(strcmp(cmd, "/changefactionlead", true) == 0)
    {
        if(PlayerData[playerid][pAdminLevel] < 6)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have access. Requires admin level 6."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new p1[8], p2[8];
        strmid(p1, cmdtext, idx, strlen(cmdtext), 8);
        new fid = strval(p1);
        while(cmdtext[idx] > ' ') idx++;
        while(cmdtext[idx] == ' ') idx++;
        strmid(p2, cmdtext, idx, strlen(cmdtext), 8);
        new targetid = strval(p2);

        if(fid < 1 || fid > MAX_FACTIONS)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Invalid faction ID (1-7)."), 1;

        if(!IsPlayerConnected(targetid) || !PlayerData[targetid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"The player is not connected."), 1;

        // Ajusteaza fMembers: scade la vechea factiune, adauga la noua
        new oldFaction = PlayerData[targetid][pFaction];
        if(oldFaction >= 1 && oldFaction <= MAX_FACTIONS && oldFaction != fid)
        {
            FactionData[oldFaction][fMembers]--;
            if(FactionData[oldFaction][fMembers] < 0) FactionData[oldFaction][fMembers] = 0;
            FactionData[oldFaction][fLead][0] = EOS;
            new qold[128];
            mysql_format(g_SQL, qold, sizeof(qold),
                "UPDATE `factions` SET `lead`='', `members`=%d WHERE `id`=%d",
                FactionData[oldFaction][fMembers], oldFaction);
            mysql_tquery(g_SQL, qold, "", "", 0);
        }

        FactionData[fid][fMembers]++;
        PlayerData[targetid][pFaction]     = fid;
        PlayerData[targetid][pFactionRank] = 5; // fRank 5 = Lead
        SetPlayerColor(targetid, FactionColors[fid]);

        // Daca targetid avea selectat spawn la HQ, recalculeaza coordonatele cu noul HQ
        if(PlayerData[targetid][pSpawn] == 2)
            Player_RecalcSpawn(targetid);

        GetPlayerName(targetid, FactionData[fid][fLead], 24);

        new q[512];
        mysql_format(g_SQL, q, sizeof(q),
            "UPDATE `factions` SET `lead`='%e', `members`=%d WHERE `id`=%d",
            FactionData[fid][fLead], FactionData[fid][fMembers], fid);
        mysql_tquery(g_SQL, q, "", "", 0);

        mysql_format(g_SQL, q, sizeof(q),
            "UPDATE `players` SET `faction`=%d, `faction_rank`=5 WHERE `id`=%d",
            fid, PlayerData[targetid][pID]);
        mysql_tquery(g_SQL, q, "", "", 0);

        // Anunt global cu culorile factiunii
        new announce[192], cFaction[9], cPlayer[9];
        GetFactionColorCode(fid, cFaction, sizeof(cFaction));
        GetFactionColorCode(fid, cPlayer, sizeof(cPlayer));
        format(announce, sizeof(announce),
            C_WHITE">>> %s%s"C_WHITE" is the new leader of %s%s"C_WHITE"! <<<",
            cPlayer, FactionData[fid][fLead], cFaction, FactionData[fid][fName]);
        SendClientMessageToAll(FactionColors[fid], announce);

        new lmsg[128];
        format(lmsg, sizeof(lmsg), C_SUCCESS"Success: "C_WHITE"Lead for "C_INFO"%s"C_WHITE" changed to "C_INFO"%s"C_WHITE".",
            FactionData[fid][fName], FactionData[fid][fLead]);
        SendClientMessage(playerid, COLOR_SUCCESS, lmsg);
        return 1;
    }

    // ---- /removefactionlead [id_factiune] ----
    if(strcmp(cmd, "/removefactionlead", true) == 0)
    {
        if(PlayerData[playerid][pAdminLevel] < 6)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have access. Requires admin level 6."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new p1[8];
        strmid(p1, cmdtext, idx, strlen(cmdtext), 8);

        if(!strlen(p1))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/removefactionlead [faction_id]"C_WHITE"."), 1;

        new fid = strval(p1);
        if(fid < 1 || fid > MAX_FACTIONS)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Invalid faction ID (1-7)."), 1;

        if(!strlen(FactionData[fid][fLead]))
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"The faction doesn't have a leader."), 1;

        // Cauta leaderul online (rank 5 in aceasta factiune) ca sa-i resetam direct datele in memorie
        new leaderOnline = INVALID_PLAYER_ID;
        for(new i = 0; i < MAX_PLAYERS; i++)
        {
            if(IsPlayerConnected(i) && PlayerData[i][pLogged] && PlayerData[i][pFaction] == fid && PlayerData[i][pFactionRank] == 5)
            {
                leaderOnline = i;
                break;
            }
        }

        if(leaderOnline != INVALID_PLAYER_ID)
        {
            PlayerData[leaderOnline][pFaction]     = 0;
            PlayerData[leaderOnline][pFactionRank] = 1;
            SetPlayerColor(leaderOnline, FactionColors[FACTION_NONE]);
            Factions_SetPlayerIcons(leaderOnline);

            new ql[128];
            mysql_format(g_SQL, ql, sizeof(ql), "UPDATE `players` SET `faction`=0, `faction_rank`=1 WHERE `id`=%d",
                PlayerData[leaderOnline][pID]);
            mysql_tquery(g_SQL, ql, "", "", 0);

            SendClientMessage(leaderOnline, COLOR_ERROR,
                C_ERROR"Info: "C_WHITE"You are no longer the faction leader. You have been removed from the faction.");
        }
        else
        {
            new ql[160];
            mysql_format(g_SQL, ql, sizeof(ql), "UPDATE `players` SET `faction`=0, `faction_rank`=1 WHERE `username`='%e'",
                FactionData[fid][fLead]);
            mysql_tquery(g_SQL, ql, "", "", 0);
        }

        FactionData[fid][fMembers]--;
        if(FactionData[fid][fMembers] < 0) FactionData[fid][fMembers] = 0;
        FactionData[fid][fLead][0] = EOS;

        new q[128];
        mysql_format(g_SQL, q, sizeof(q), "UPDATE `factions` SET `lead`='', `members`=%d WHERE `id`=%d",
            FactionData[fid][fMembers], fid);
        mysql_tquery(g_SQL, q, "", "", 0);

        new rmsg[128];
        format(rmsg, sizeof(rmsg), C_SUCCESS"[ADM]Success: "C_WHITE"The leader of faction "C_INFO"%s"C_WHITE" has been removed.",
            FactionData[fid][fName]);
        SendClientMessage(playerid, COLOR_SUCCESS, rmsg);
        return 1;
    }

    return 0;
}

public OnPlayerSpawn(playerid)
{
    SetPlayerInterior(playerid, 0);
    TogglePlayerClock(playerid, 0);
    if(PlayerData[playerid][pLogged])
    {
        SetPlayerVirtualWorld(playerid, 0);
        SetPlayerPos(playerid,
            PlayerData[playerid][pSpawnX],
            PlayerData[playerid][pSpawnY],
            PlayerData[playerid][pSpawnZ]);
    }
    return 1;
}

#define LOCAL_CHAT_RANGE 37.5

public OnPlayerText(playerid, text[])
{
    if(!PlayerData[playerid][pLogged]) return 0;

    new colorcode[9], msg[144];
    GetFactionColorCode(PlayerData[playerid][pFaction], colorcode, sizeof(colorcode));
    format(msg, sizeof(msg), "%s%s"C_WHITE": %s", colorcode, PlayerData[playerid][pName], text);

    new Float:x, Float:y, Float:z;
    GetPlayerPos(playerid, x, y, z);

    for(new i = 0; i < MAX_PLAYERS; i++)
    {
        if(IsPlayerConnected(i) && PlayerData[i][pLogged] && IsPlayerInRangeOfPoint(i, LOCAL_CHAT_RANGE, x, y, z))
            SendClientMessage(i, COLOR_WHITE, msg);
    }
    return 0;
}

public OnPlayerDeath(playerid, killerid, reason)
{
    return 1;
}

public OnPlayerDisconnect(playerid, reason)
{
    ExamA_KillTimer(playerid);
    g_ExamAState[playerid] = EXAMA_STATE_NONE;

    Exam_KillTimer(playerid);
    g_ExamState[playerid] = EXAM_STATE_NONE;

    ExamC_KillTimer(playerid);
    g_ExamCState[playerid] = EXAMC_STATE_NONE;

    g_RadarActive[playerid] = false;

    FullUpdatePlayer(playerid);
    return 1;
}

public OnPlayerStateChange(playerid, newstate, oldstate)
{
    if(newstate == PLAYER_STATE_DRIVER && GetPlayerVehicleID(playerid) == g_TrainID)
        RemovePlayerFromVehicle(playerid);

    // A iesit din masina in timpul examenului (inainte de ultimul checkpoint) -> pica si masina respawneaza
    if(oldstate == PLAYER_STATE_DRIVER && newstate != PLAYER_STATE_DRIVER && g_ExamAState[playerid] == EXAMA_STATE_DRIVING)
        ExamA_Fail(playerid, "You got out of the bike.");

    // A iesit din masina in timpul examenului (inainte de ultimul checkpoint) -> pica si masina respawneaza
    if(oldstate == PLAYER_STATE_DRIVER && newstate != PLAYER_STATE_DRIVER && g_ExamState[playerid] == EXAM_STATE_DRIVING)
        Exam_Fail(playerid, "You got out of the car.");

    // A coborat din capul tractor in timpul examenului C -> pica si vehiculele respawneaza
    if(oldstate == PLAYER_STATE_DRIVER && newstate != PLAYER_STATE_DRIVER &&
       (g_ExamCState[playerid] == EXAMC_STATE_WAITING_TRAILER || g_ExamCState[playerid] == EXAMC_STATE_DRIVING))
        ExamC_Fail(playerid, "You got out of the truck.");

    if(newstate == PLAYER_STATE_PASSENGER)
    {
        new vehid = GetPlayerVehicleID(playerid);
        if(vehid >= 0 && vehid < MAX_VEHICLES && IsExamACarVehicle(vehid))
        {
            new examUser = ExamA_GetCarUser(vehid);
            if(examUser != -1 && examUser != playerid)
            {
                RemovePlayerFromVehicle(playerid);
                SendClientMessage(playerid, COLOR_ERROR,
                    C_ERROR"Error: "C_WHITE"This bike is being used for an exam.");
            }
        }
        if(vehid >= 0 && vehid < MAX_VEHICLES && IsExamBCarVehicle(vehid))
        {
            new examUser = Exam_GetCarUser(vehid);
            if(examUser != -1 && examUser != playerid)
            {
                RemovePlayerFromVehicle(playerid);
                SendClientMessage(playerid, COLOR_ERROR,
                    C_ERROR"Error: "C_WHITE"This car is being used for an exam.");
            }
        }
        if(vehid >= 0 && vehid < MAX_VEHICLES && IsExamCTruckVehicle(vehid))
        {
            new examUser = ExamC_GetTruckUser(vehid);
            if(examUser != -1 && examUser != playerid)
            {
                RemovePlayerFromVehicle(playerid);
                SendClientMessage(playerid, COLOR_ERROR,
                    C_ERROR"Error: "C_WHITE"This truck is being used for an exam.");
            }
        }
    }

    if(newstate == PLAYER_STATE_DRIVER)
    {
        new vehid = GetPlayerVehicleID(playerid);
        if(vehid >= 0 && vehid < MAX_VEHICLES)
        {
            new fid = g_VehicleFactionOwner[vehid];
            if(fid != 0 && PlayerData[playerid][pFaction] != fid)
            {
                RemovePlayerFromVehicle(playerid);
                SendClientMessage(playerid, COLOR_ERROR,
                    C_ERROR"Error: "C_WHITE"This vehicle belongs to a faction. You cannot drive it.");
            }

            new pvidx = g_VehicleToPVIndex[vehid];
            if(pvidx != -1 && PVehicleData[pvidx][pvOwnerId] == 0)
            {
                new engine, lights, alarm, doors, bonnet, boot, objective;
                GetVehicleParamsEx(vehid, engine, lights, alarm, doors, bonnet, boot, objective);
                SetVehicleParamsEx(vehid, 0, lights, alarm, doors, bonnet, boot, objective);
                SendClientMessage(playerid, COLOR_ERROR,
                    C_ERROR"Error: "C_WHITE"This vehicle has not been bought yet. Use "C_INFO"/vbuy"C_WHITE" to be able to start it.");
            }

            if(!IsExamACarVehicle(vehid) && !IsExamBCarVehicle(vehid) && !IsExamCTruckVehicle(vehid) && !IsRentCarVehicle(vehid) && !IsRentCarDesertVehicle(vehid))
            {
                new category = GetVehicleLicenseCategory(GetVehicleModel(vehid));
                if(!Player_HasValidLicense(playerid, category))
                {
                    RemovePlayerFromVehicle(playerid);

                    new catName[2], lmsg[128];
                    GetLicenseCategoryName(category, catName, sizeof(catName));
                    format(lmsg, sizeof(lmsg),
                        C_ERROR"Error: "C_WHITE"You need a valid category "C_INFO"%s"C_WHITE" license to drive this vehicle.",
                        catName);
                    SendClientMessage(playerid, COLOR_ERROR, lmsg);
                }
            }

            if(IsRentBikeVehicle(vehid))
            {
                TogglePlayerControllable(playerid, 0);
                SendClientMessage(playerid, COLOR_INFO,
                    C_INFO"Info: "C_WHITE"This bike is for rent. Use "C_INFO"/rentbike"C_WHITE" to be able to use it.");
            }

            if(IsRentCarVehicle(vehid) || IsRentCarDesertVehicle(vehid))
            {
                TogglePlayerControllable(playerid, 0);
                SendClientMessage(playerid, COLOR_INFO,
                    C_INFO"Info: "C_WHITE"This car is for rent. Use "C_INFO"/rentcar"C_WHITE" to be able to use it.");
            }

            if(IsExamACarVehicle(vehid))
            {
                new examUser = ExamA_GetCarUser(vehid);
                if(examUser != -1 && examUser != playerid)
                {
                    RemovePlayerFromVehicle(playerid);
                    SendClientMessage(playerid, COLOR_ERROR,
                        C_ERROR"Error: "C_WHITE"This bike is being used for an exam.");
                }
                else if(g_ExamAState[playerid] != EXAMA_STATE_WAITING_CAR)
                {
                    RemovePlayerFromVehicle(playerid);
                    SendClientMessage(playerid, COLOR_ERROR,
                        C_ERROR"Error: "C_WHITE"You must use "C_INFO"/examA"C_WHITE" to use this bike.");
                }
                else
                {
                    ExamA_KillTimer(playerid);
                    g_ExamAState[playerid]      = EXAMA_STATE_DRIVING;
                    g_ExamAVehicle[playerid]    = vehid;
                    g_ExamACheckpoint[playerid] = 0;
                    ExamA_GotoCheckpoint(playerid, 0);

                    SendClientMessage(playerid, COLOR_INFO,
                        C_INFO"Info: "C_WHITE"The exam has started! You have "C_INFO"30 seconds"C_WHITE" to reach the next checkpoint.");
                }
            }

            if(IsExamBCarVehicle(vehid))
            {
                new examUser = Exam_GetCarUser(vehid);
                if(examUser != -1 && examUser != playerid)
                {
                    RemovePlayerFromVehicle(playerid);
                    SendClientMessage(playerid, COLOR_ERROR,
                        C_ERROR"Error: "C_WHITE"This car is being used for an exam.");
                }
                else if(g_ExamState[playerid] != EXAM_STATE_WAITING_CAR)
                {
                    RemovePlayerFromVehicle(playerid);
                    SendClientMessage(playerid, COLOR_ERROR,
                        C_ERROR"Error: "C_WHITE"You must use "C_INFO"/examB"C_WHITE" to use this car.");
                }
                else
                {
                    Exam_KillTimer(playerid);
                    g_ExamState[playerid]      = EXAM_STATE_DRIVING;
                    g_ExamVehicle[playerid]    = vehid;
                    g_ExamCheckpoint[playerid] = 0;
                    Exam_GotoCheckpoint(playerid, 0);

                    SendClientMessage(playerid, COLOR_INFO,
                        C_INFO"Info: "C_WHITE"The exam has started! You have "C_INFO"30 seconds"C_WHITE" to reach the next checkpoint.");
                }
            }

            if(IsExamCTruckVehicle(vehid))
            {
                new examUser = ExamC_GetTruckUser(vehid);
                if(examUser != -1 && examUser != playerid)
                {
                    RemovePlayerFromVehicle(playerid);
                    SendClientMessage(playerid, COLOR_ERROR,
                        C_ERROR"Error: "C_WHITE"This truck is being used for an exam.");
                }
                else if(g_ExamCState[playerid] != EXAMC_STATE_WAITING_TRUCK)
                {
                    RemovePlayerFromVehicle(playerid);
                    SendClientMessage(playerid, COLOR_ERROR,
                        C_ERROR"Error: "C_WHITE"You must use "C_INFO"/examC"C_WHITE" to use this truck.");
                }
                else
                {
                    ExamC_KillTimer(playerid);
                    g_ExamCState[playerid]   = EXAMC_STATE_WAITING_TRAILER;
                    g_ExamCVehicle[playerid] = vehid;
                    ExamC_StartStepTimer(playerid);

                    SendClientMessage(playerid, COLOR_INFO,
                        C_INFO"Info: "C_WHITE"Now attach a "C_INFO"trailer"C_WHITE" within "C_INFO"30 seconds"C_WHITE" to continue the exam.");
                }
            }
        }
    }
    return 1;
}

public OnPlayerRequestClass(playerid, classid)
{
    SpawnPlayer(playerid);
    return 1;
}

// La respawn natural (gol, neutilizat) sau /rac, vehiculele personale trebuie sa reapara la
// coordonatele salvate in baza de date (ultima pozitie din /vpark), nu la pozitia de creare.
public OnVehicleSpawn(vehicleid)
{
    if(vehicleid >= 0 && vehicleid < MAX_VEHICLES)
    {
        new pvidx = g_VehicleToPVIndex[vehicleid];
        if(pvidx != -1)
        {
            SetVehiclePos(vehicleid, PVehicleData[pvidx][pvLocX], PVehicleData[pvidx][pvLocY], PVehicleData[pvidx][pvLocZ]);
            SetVehicleZAngle(vehicleid, PVehicleData[pvidx][pvRotation]);
        }
    }
    return 1;
}

strtok(const string[], &index)
{
    new length = strlen(string);
    while((index < length) && (string[index] <= ' '))
        index++;

    new offset = index;
    new result[256];
    while((index < length) && (string[index] > ' ') && ((index - offset) < (sizeof(result) - 1)))
    {
        result[index - offset] = string[index];
        index++;
    }
    result[index - offset] = EOS;
    return result;
}
