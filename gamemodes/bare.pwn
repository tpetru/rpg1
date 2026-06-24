#include <a_samp>
#include <core>
#include <float>
#include <a_mysql>
#include <streamer>
#include <string>
#include <mysql_config>

#pragma tabsize 0
#pragma warning disable 239

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
forward OnAnimalsLoaded();
forward OnHouseCreated(playerid, idx);
forward OnBusinessesLoaded();
forward OnBusinessCreated(playerid, idx);
forward OnTurfsLoaded();
forward War_StartActive(tidx);
forward War_CheckTimeUp(tidx);
forward OnLocationsLoaded();
forward OnGPSLoaded();
forward OnVehiclesFactionLoaded();
forward OnVehicleFactionCreated(playerid, idx);
forward Fires_Tick();
forward OnVehiclesPersonalLoaded();
forward OnVehiclePersonalCreated(playerid, idx);
forward OnVehiclePlateChecked(playerid, pvidx, plate[]);
forward OnVehicleITPCheck(playerid, pvidx, vehid);
forward OnCaravansLoaded();
forward OnCaravanCreated(playerid, idx);
forward OnBBallHoopsLoaded();
forward OnBBallSpawnsLoaded();
forward BBall_CountdownTick();
forward BBall_PlayThrowAnim(playerid, power);
forward BBall_ReleaseBall(playerid, power);
forward BBall_StartArc(playerid);

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
new g_ExamCPrice       = 500;
new g_ExamDPrice       = 400;
new g_PizzaPrice       = 50;
new g_BurgerPrice      = 55;

// ============================================================
//  PRESEDINTE (alegeri saptamanale prin vot)
// ============================================================
// Edge-trigger guards: retin ziua (din getdate) cand s-a rulat ultima oara fiecare moment cheie,
// ca sa nu se declanseze de mai multe ori in acelasi minut/aceeasi duminica.
new g_LastVoteClearDay  = -1; // duminica 06:00 - golire voturi
new g_LastVoteWinnerDay = -1; // duminica 20:00 - calcul castigator
#define VOTE_WINDOW_START_HOUR  8     // fereastra de vot: 08:00 ...
#define VOTE_WINDOW_END_HOUR    19    // ... pana la 19:30
#define VOTE_WINDOW_END_MINUTE  30

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
    bool:pLogged, bool:pRegistered, bool:pOnDuty,
    bool:pDiseased, pDiseasePaydays,
    pCaravanKey,
    bool:pIsPresident, bool:pVoted, bool:pWasPresident
}
new PlayerData[MAX_PLAYERS][E_PLAYER_DATA];

// ============================================================
//  FACTIUNI
// ============================================================
enum E_FACTION_DATA
{
    fID, fName[32], fMembers, fLead[24], fBank,
    fPickupID, fMapIconID,
    Float:fHQX, Float:fHQY, Float:fHQZ,
    Float:fInteriorX, Float:fInteriorY, Float:fInteriorZ,
    fInterior, fvw
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

#define FINE_RANGE 15.0
#define M_RANGE    50.0
#define LOCK_RANGE 5.0

// Returneaza {RRGGBB} pentru culoarea factiunii
stock GetFactionColorCode(fid, out[], len)
{
    if(fid < 0 || fid > MAX_FACTIONS) { out[0] = EOS; return; }
    format(out, len, "{%06x}", (FactionColors[fid] >> 8) & 0xFFFFFF);
}

// Formateaza o suma cu separator de mii (punct), ex: 1000000 -> "1.000.000"
// Foloseste un pool de buffere rotative, asa ca poate fi apelata de mai multe ori in acelasi format()
#define MONEY_STR_POOL 6
static g_MoneyStrBuf[MONEY_STR_POOL][20];
static g_MoneyStrIdx = 0;

stock MoneyStr(amount)
{
    g_MoneyStrIdx = (g_MoneyStrIdx + 1) % MONEY_STR_POOL;
    new idx = g_MoneyStrIdx;

    new bool:neg = (amount < 0);
    if(neg) amount = -amount;

    new digits[12], dlen = 0;
    if(amount == 0)
        digits[dlen++] = '0';
    while(amount > 0)
    {
        digits[dlen++] = '0' + (amount % 10);
        amount /= 10;
    }

    new pos = 0;
    if(neg) g_MoneyStrBuf[idx][pos++] = '-';
    for(new i = dlen - 1; i >= 0; i--)
    {
        g_MoneyStrBuf[idx][pos++] = digits[i];
        if(i > 0 && (i % 3) == 0)
            g_MoneyStrBuf[idx][pos++] = '.';
    }
    g_MoneyStrBuf[idx][pos] = EOS;
    return g_MoneyStrBuf[idx];
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

// Unix timestamp -> "YYYY-MM-DD HH:MM:SS" (pentru o coloana DATETIME)
stock UnixToDateTimeStr(ts, out[], len)
{
    new y, m, d;
    CivilFromDays(ts / 86400, y, m, d);
    new secs = ts % 86400;
    format(out, len, "%04d-%02d-%02d %02d:%02d:%02d", y, m, d, secs / 3600, (secs % 3600) / 60, secs % 60);
}

// "YYYY-MM-DD HH:MM:SS" (citit dintr-o coloana DATETIME) -> unix timestamp
stock DateTimeStrToUnix(const datestr[])
{
    if(strlen(datestr) < 19) return 0;

    new ys[5], ms[3], ds[3], hs[3], mis[3], ss[3];
    strmid(ys, datestr, 0, 4, 5);
    strmid(ms, datestr, 5, 7, 3);
    strmid(ds, datestr, 8, 10, 3);
    strmid(hs, datestr, 11, 13, 3);
    strmid(mis, datestr, 14, 16, 3);
    strmid(ss, datestr, 17, 19, 3);

    return DaysFromCivil(strval(ys), strval(ms), strval(ds)) * 86400
        + strval(hs) * 3600 + strval(mis) * 60 + strval(ss);
}

// La fel ca BuildDateSqlValueFromUnix, dar pentru o coloana DATETIME (pastreaza si ora, nu doar ziua)
stock BuildDateTimeSqlValueFromUnix(ts, out[], len)
{
    if(ts <= 0) { format(out, len, "NULL"); return; }

    new dtStr[20];
    UnixToDateTimeStr(ts, dtStr, sizeof(dtStr));
    format(out, len, "'%s'", dtStr);
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
new g_FactionInteriorPickup[MAX_FACTIONS + 1] = {-1, -1, -1, -1, -1, -1, -1, -1};
new Text3D:g_FactionInteriorLabel[MAX_FACTIONS + 1];
#define FACTION_INTERIOR_PICKUP_MODEL 19197

// ============================================================
//  BICICLETE DE INCHIRIAT
// ============================================================
#define MAX_RENT_BIKES  9
#define RENT_BIKE_MODEL 510
#define RENT_BIZ_ID     1

new g_RentBikeVehicle[MAX_RENT_BIKES] = {-1, ...};

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
//  MASINI DE INCHIRIAT (zona noua, langa spawn-urile civile)
// ============================================================
#define MAX_RENT_CARS2    7
#define RENT_CAR2_PRICE   30
#define RENT_CAR2_BIZ_ID  14

new g_RentCarVehicle2[MAX_RENT_CARS2] = {-1, ...};

// Returneaza true daca vehiculul dat e una dintre masinile de inchiriat din zona noua
stock bool:IsRentCarVehicle2(vehid)
{
    for(new i = 0; i < MAX_RENT_CARS2; i++)
        if(g_RentCarVehicle2[i] == vehid) return true;
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
#define EXAMA_STEP_TIME       45000 // 45 secunde, in ms
#define EXAMA_PASS_HEALTH     800.0
#define EXAMA_PASS_DURATION   950400  // 11 zile, in secunde
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

    if(vehid != -1) { Vehicle_SetLocked(vehid, false); SetVehicleToRespawn(vehid); }

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

    if(vehid != -1) { Vehicle_SetLocked(vehid, false); SetVehicleToRespawn(vehid); }

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
#define EXAMB_STEP_TIME       45000 // 45 secunde, in ms
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

    if(vehid != -1) { Vehicle_SetLocked(vehid, false); SetVehicleToRespawn(vehid); }

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

    if(vehid != -1) { Vehicle_SetLocked(vehid, false); SetVehicleToRespawn(vehid); }

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
#define EXAMC_LOC_X              1375.2307
#define EXAMC_LOC_Y              1019.8265
#define EXAMC_LOC_Z              10.8203
#define EXAMC_RANGE              5.0
#define EXAMC_CP_SIZE            5.0
#define EXAMC_STEP_TIME          45000 // 45 secunde, in ms
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

    if(vehid != -1) { Vehicle_SetLocked(vehid, false); SetVehicleToRespawn(vehid); }
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

    if(vehid != -1) { Vehicle_SetLocked(vehid, false); SetVehicleToRespawn(vehid); }
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

// Verifica daca jucatorul (in starea WAITING_TRAILER) si-a atasat remorca de examen; daca da, porneste examenul.
// Apelata atat din OnTrailerUpdate (reactie instant), cat si dintr-un timer de control (ExamC_TrailerTick),
// pentru ca OnTrailerUpdate nu se declanseaza intotdeauna fiabil pentru vehiculele statice.
stock ExamC_CheckTrailerAttached(playerid)
{
    if(g_ExamCState[playerid] != EXAMC_STATE_WAITING_TRAILER) return;

    new truckid = g_ExamCVehicle[playerid];
    if(truckid == -1 || !IsTrailerAttachedToVehicle(truckid)) return;

    new trailerid = GetVehicleTrailer(truckid);
    if(!IsExamCTrailerVehicle(trailerid)) return;

    g_ExamCState[playerid]      = EXAMC_STATE_DRIVING;
    g_ExamCTrailerVeh[playerid] = trailerid;
    g_ExamCCheckpoint[playerid] = 0;
    ExamC_GotoCheckpoint(playerid, 0);

    SendClientMessage(playerid, COLOR_INFO,
        C_INFO"Info: "C_WHITE"Trailer attached! The exam has started, you have "C_INFO"45 seconds"C_WHITE" to reach the next checkpoint.");
}

forward ExamC_TrailerTick();
public ExamC_TrailerTick()
{
    for(new i = 0; i < MAX_PLAYERS; i++)
    {
        if(!IsPlayerConnected(i) || !PlayerData[i][pLogged]) continue;

        if(g_ExamCState[i] == EXAMC_STATE_WAITING_TRAILER)
        {
            ExamC_CheckTrailerAttached(i);
        }
        else if(g_ExamCState[i] == EXAMC_STATE_DRIVING && g_ExamCVehicle[i] != -1 && !IsTrailerAttachedToVehicle(g_ExamCVehicle[i]))
        {
            ExamC_Fail(i, "You detached the trailer.");
        }
    }
    return 1;
}

public OnTrailerUpdate(playerid, vehicleid)
{
    ExamC_CheckTrailerAttached(playerid);

    if(g_ExamCState[playerid] == EXAMC_STATE_DRIVING && g_ExamCVehicle[playerid] != -1 && !IsTrailerAttachedToVehicle(g_ExamCVehicle[playerid]))
        ExamC_Fail(playerid, "You detached the trailer.");
    return 1;
}
// ============================================================
//  EXAMEN AUTO CATEGORIA D
// ============================================================
#define MAX_EXAMD_CARS        2
#define EXAMD_CAR_MODEL       437 // Bus
#define EXAMD_BIZ_ID          7
#define EXAMD_LOC_X           1896.1573
#define EXAMD_LOC_Y           2586.3149
#define EXAMD_LOC_Z           11.0234
#define EXAMD_RANGE           5.0
#define EXAMD_CP_SIZE         5.0
#define EXAMD_STEP_TIME       45000 // 45 secunde, in ms
#define EXAMD_PASS_HEALTH     800.0
#define EXAMD_PASS_DURATION   1382400 // 16 zile, in secunde
#define EXAMD_FAIL_DURATION   259200  // 3 zile, in secunde
#define MAX_EXAMD_CHECKPOINTS 9

#define EXAMD_STATE_NONE        0
#define EXAMD_STATE_WAITING_CAR 1
#define EXAMD_STATE_DRIVING     2

new Float:ExamDCheckpoints[MAX_EXAMD_CHECKPOINTS][3] = {
    {1892.1851, 2602.1150, 10.9534},
    {1819.4514, 2625.2698, 10.9537},
    {1606.1790, 2592.3164, 10.8111},
    {1434.1677, 2608.5732, 10.8038},
    {1249.9764, 2619.0249, 10.8100},
    {1432.4775, 2671.2361, 10.8052},
    {1543.3169, 2685.1956, 10.8067},
    {1584.8079, 2606.0190, 10.8151},
    {1772.9580, 2614.5146, 10.9089}
};

new g_ExamDCar[MAX_EXAMD_CARS] = {-1, -1};
new g_ExamDState[MAX_PLAYERS];
new g_ExamDCheckpoint[MAX_PLAYERS];
new g_ExamDVehicle[MAX_PLAYERS];
new g_ExamDTimer[MAX_PLAYERS] = {-1, ...};

forward ExamD_Timeout(playerid);

// Returneaza true daca vehiculul dat e unul dintre autobuzele de scoala (examen categoria D)
stock bool:IsExamDCarVehicle(vehid)
{
    for(new i = 0; i < MAX_EXAMD_CARS; i++)
        if(g_ExamDCar[i] == vehid) return true;
    return false;
}

// Returneaza playerid-ul care da in prezent examenul cu acest vehicul, sau -1 daca e liber
stock ExamD_GetCarUser(vehid)
{
    for(new i = 0; i < MAX_PLAYERS; i++)
        if(g_ExamDState[i] == EXAMD_STATE_DRIVING && g_ExamDVehicle[i] == vehid)
            return i;
    return -1;
}

stock ExamD_KillTimer(playerid)
{
    if(g_ExamDTimer[playerid] != -1)
    {
        KillTimer(g_ExamDTimer[playerid]);
        g_ExamDTimer[playerid] = -1;
    }
}

stock ExamD_GotoCheckpoint(playerid, cpIdx)
{
    SetPlayerCheckpoint(playerid, ExamDCheckpoints[cpIdx][0], ExamDCheckpoints[cpIdx][1], ExamDCheckpoints[cpIdx][2], EXAMD_CP_SIZE);
    ExamD_KillTimer(playerid);
    g_ExamDTimer[playerid] = SetTimerEx("ExamD_Timeout", EXAMD_STEP_TIME, false, "i", playerid);
}

stock ExamD_Fail(playerid, const reason[])
{
    new vehid = g_ExamDVehicle[playerid];

    g_ExamDState[playerid]      = EXAMD_STATE_NONE;
    g_ExamDVehicle[playerid]    = -1;
    g_ExamDCheckpoint[playerid] = 0;
    DisablePlayerCheckpoint(playerid);
    ExamD_KillTimer(playerid);

    if(vehid != -1) { Vehicle_SetLocked(vehid, false); SetVehicleToRespawn(vehid); }

    new msg[160];
    format(msg, sizeof(msg), C_ERROR"Error: "C_WHITE"You failed the category D driving exam. %s Try again.", reason);
    SendClientMessage(playerid, COLOR_ERROR, msg);
}

stock ExamD_Finish(playerid)
{
    new vehid = g_ExamDVehicle[playerid];

    DisablePlayerCheckpoint(playerid);
    ExamD_KillTimer(playerid);
    g_ExamDState[playerid]      = EXAMD_STATE_NONE;
    g_ExamDVehicle[playerid]    = -1;
    g_ExamDCheckpoint[playerid] = 0;

    new Float:health = 0.0;
    if(vehid != -1) GetVehicleHealth(vehid, health);

    new bool:fullPass = (health >= EXAMD_PASS_HEALTH);
    new expTs = gettime() + (fullPass ? EXAMD_PASS_DURATION : EXAMD_FAIL_DURATION);

    new dateStr[11];
    UnixToDateStr(expTs, dateStr, sizeof(dateStr));
    format(PlayerData[playerid][pDrivingLicD_exp], 11, "%s", dateStr);
    UpdatePlayer(playerid, pDrivingLicD_exp);

    if(vehid != -1) { Vehicle_SetLocked(vehid, false); SetVehicleToRespawn(vehid); }

    new msg[160];
    format(msg, sizeof(msg),
        C_SUCCESS"Congratulations, "C_WHITE"your category D license has been extended until "C_INFO"%s"C_WHITE" (Vehicle HP: "C_INFO"%d"C_WHITE").",
        dateStr, floatround(health));
    SendClientMessage(playerid, COLOR_SUCCESS, msg);
}

public ExamD_Timeout(playerid)
{
    if(!IsPlayerConnected(playerid)) return 0;
    if(g_ExamDState[playerid] == EXAMD_STATE_NONE) return 0;

    g_ExamDTimer[playerid] = -1;
    ExamD_Fail(playerid, "Time's up.");
    return 1;
}
// ============================================================
//  GPS (locatii navigabile de catre playeri, populate treptat in DB)
// ============================================================
#define MAX_GPS_LOCATIONS 200
#define GPS_CP_SIZE        5.0

enum E_GPS_DATA
{
    glID, glCategory[32], glName[32], Float:glLocX, Float:glLocY, Float:glLocZ
}
new GPSData[MAX_GPS_LOCATIONS][E_GPS_DATA];
new g_GPSCount = 0;
new bool:g_GPSActive[MAX_PLAYERS];

stock GPS_FindByName(const name[])
{
    for(new i = 0; i < g_GPSCount; i++)
        if(strcmp(GPSData[i][glName], name, true) == 0) return i;
    return -1;
}

#define DIALOG_GPS_CATEGORY  9001
#define DIALOG_GPS_LOCATION  9002
#define DIALOG_BUSINESS_LIST 9003
#define DIALOG_RADAR_LIST    9004
#define DIALOG_BIZZLIST      9005

// Nume afisate playerului (titlul celui de-al doilea dialog)
new const GPS_CATEGORY_NAMES[5][16] = {"DMV Locations", "FACTIONS", "BUSINESS", "Others", "Shops"};
// Aliasuri text vechi acceptate din DB (separat de GPS_CATEGORY_NAMES, ca sa nu stricam matching-ul cand redenumim afisarea)
new const GPS_CATEGORY_ALIAS[5][16] = {"DMV", "FACTIONS", "BUSINESS", "OTHERS", "SHOPS"};
new g_GPSDialogCategory[MAX_PLAYERS];

// Verifica daca o categorie din DB se potriveste cu categoria catIdx (0=DMV, 1=FACTIONS, 2=BUSINESS, 3=OTHERS, 4=SHOPS).
// Accepta atat numele text vechi ("DMV") cat si numarul ("1"), ca sa functioneze indiferent cum a fost populata baza de date.
stock bool:GPS_CategoryMatches(const category[], catIdx)
{
    if(strcmp(category, GPS_CATEGORY_ALIAS[catIdx], true) == 0) return true;

    new numStr[4];
    format(numStr, sizeof(numStr), "%d", catIdx + 1);
    if(strcmp(category, numStr, true) == 0) return true;

    return false;
}

// Numara cate locatii GPS exista pentru categoria data (0=DMV, 1=FACTIONS, 2=BUSINESS, 3=OTHERS)
stock GPS_CountInCategory(catIdx)
{
    new count = 0;
    for(new i = 0; i < g_GPSCount; i++)
        if(GPS_CategoryMatches(GPSData[i][glCategory], catIdx)) count++;
    return count;
}

// Returneaza indexul din GPSData[] al celei de-a n-a (0-based) locatii din categoria data, sau -1
stock GPS_GetNthInCategory(catIdx, n)
{
    new count = 0;
    for(new i = 0; i < g_GPSCount; i++)
    {
        if(GPS_CategoryMatches(GPSData[i][glCategory], catIdx))
        {
            if(count == n) return i;
            count++;
        }
    }
    return -1;
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
        }
        return 1;
    }

    if(g_ExamDState[playerid] == EXAMD_STATE_DRIVING)
    {
        g_ExamDCheckpoint[playerid]++;
        if(g_ExamDCheckpoint[playerid] >= MAX_EXAMD_CHECKPOINTS)
        {
            ExamD_Finish(playerid);
        }
        else
        {
            ExamD_GotoCheckpoint(playerid, g_ExamDCheckpoint[playerid]);
        }
        return 1;
    }

    if(g_GPSActive[playerid])
    {
        DisablePlayerCheckpoint(playerid);
        g_GPSActive[playerid] = false;
        SendClientMessage(playerid, COLOR_SUCCESS, C_SUCCESS"Success: "C_WHITE"You have arrived at your destination.");
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

    new label[96], colorcode[9];
    GetFactionColorCode(fid, colorcode, sizeof(colorcode));
    // Daca interiorul e configurat, afiseaza si invitatia de a intra
    if(FactionData[fid][fInteriorX] != 0.0 || FactionData[fid][fInteriorY] != 0.0)
        format(label, sizeof(label), "%s[ %s ]\n"C_WHITE"[ Press ENTER to enter ]", colorcode, FactionData[fid][fName]);
    else
        format(label, sizeof(label), "%s[ %s ]", colorcode, FactionData[fid][fName]);
    g_FactionLabel[fid] = Create3DTextLabel(label, FactionColors[fid],
        FactionData[fid][fHQX], FactionData[fid][fHQY], FactionData[fid][fHQZ]-1,
        15.0, 0, 0);
}

// Distruge si recreeaza pickup-ul + eticheta din interiorul factiunii
stock Factions_RecreateInteriorPickup(fid)
{
    if(g_FactionInteriorPickup[fid] != -1)
    {
        DestroyPickup(g_FactionInteriorPickup[fid]);
        g_FactionInteriorPickup[fid] = -1;
    }
    if(g_FactionInteriorLabel[fid] != Text3D:INVALID_3DTEXT_ID)
    {
        Delete3DTextLabel(g_FactionInteriorLabel[fid]);
        g_FactionInteriorLabel[fid] = Text3D:INVALID_3DTEXT_ID;
    }
    if(FactionData[fid][fInteriorX] == 0.0 && FactionData[fid][fInteriorY] == 0.0) return;

    g_FactionInteriorPickup[fid] = CreatePickup(FACTION_INTERIOR_PICKUP_MODEL, 1,
        FactionData[fid][fInteriorX], FactionData[fid][fInteriorY], FactionData[fid][fInteriorZ],
        FactionData[fid][fvw]);

    g_FactionInteriorLabel[fid] = Create3DTextLabel(C_WHITE"[ Press ENTER to exit ]", FactionColors[fid],
        FactionData[fid][fInteriorX], FactionData[fid][fInteriorY], FactionData[fid][fInteriorZ]-1,
        15.0, FactionData[fid][fvw], 0);
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

// Membru de factiune: intra/iesi din interiorul factiunii (apasand KEY_SECONDARY_ATTACK langa pickup)
stock Factions_InteriorToggle(playerid)
{
    new fid = PlayerData[playerid][pFaction];
    if(fid < 1 || fid > MAX_FACTIONS) return;

    new bool:hqSet  = (FactionData[fid][fHQX] != 0.0 || FactionData[fid][fHQY] != 0.0);
    new bool:intSet = (FactionData[fid][fInteriorX] != 0.0 || FactionData[fid][fInteriorY] != 0.0);
    if(!hqSet || !intSet) return;

    // Langa HQ-ul exterior (vw 0) -> intra in interior
    if(GetPlayerVirtualWorld(playerid) == 0 &&
       IsPlayerInRangeOfPoint(playerid, 2.5, FactionData[fid][fHQX], FactionData[fid][fHQY], FactionData[fid][fHQZ]))
    {
        SetPlayerPos(playerid, FactionData[fid][fInteriorX], FactionData[fid][fInteriorY], FactionData[fid][fInteriorZ]);
        SetPlayerVirtualWorld(playerid, FactionData[fid][fvw]);
        SetPlayerInterior(playerid, FactionData[fid][fInterior]);
        return;
    }

    // Langa pickup-ul din interior (vw-ul factiunii) -> iesi afara
    if(GetPlayerVirtualWorld(playerid) == FactionData[fid][fvw] &&
       IsPlayerInRangeOfPoint(playerid, 2.5, FactionData[fid][fInteriorX], FactionData[fid][fInteriorY], FactionData[fid][fInteriorZ]))
    {
        SetPlayerPos(playerid, FactionData[fid][fHQX], FactionData[fid][fHQY], FactionData[fid][fHQZ]);
        SetPlayerVirtualWorld(playerid, 0);
        SetPlayerInterior(playerid, 0);
    }
}

// Returneaza true daca playerul se afla in interiorul HQ-ului propriei factiuni
stock bool:Factions_IsInOwnInterior(playerid)
{
    new fid = PlayerData[playerid][pFaction];
    if(fid < 1 || fid > MAX_FACTIONS) return false;
    if(FactionData[fid][fInteriorX] == 0.0 && FactionData[fid][fInteriorY] == 0.0) return false;
    if(GetPlayerVirtualWorld(playerid) != FactionData[fid][fvw]) return false;
    if(GetPlayerInterior(playerid) != FactionData[fid][fInterior]) return false;
    return (IsPlayerInRangeOfPoint(playerid, 50.0, FactionData[fid][fInteriorX], FactionData[fid][fInteriorY], FactionData[fid][fInteriorZ]) != 0);
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
    SetPlayerMapIcon(playerid, 0, 1385.0, 750.0, 10.8203, 35, 0, MAPICON_LOCAL); // SPAWN POINT
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
    hType, hMaxPets, hPets,
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
            "[ House #%d ]\nName: %s\nOwned: Yes\nOwner: %s\nPrice: $%s",
            HouseData[idx][hID], HouseData[idx][hName], HouseData[idx][hOwner], MoneyStr(HouseData[idx][hPrice]));
    }
    else
    {
        format(label, sizeof(label),
            "[ House #%d ]\nName: %s\nOwned: No\nPrice: $%s\n\n/buyhouse to buy this house",
            HouseData[idx][hID], HouseData[idx][hName], MoneyStr(HouseData[idx][hPrice]));
    }
    g_HouseLabel[idx] = Create3DTextLabel(label, COLOR_WHITE,
        HouseData[idx][hLocX], HouseData[idx][hLocY], HouseData[idx][hLocZ]-0.5, 15.0, 0, 0);
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
//  ANIMALE (pets la case de tip 1) - obiecte dinamice
// ============================================================
#define MAX_ANIMALS    200
#define ANIMAL_PRICE   5000   // pretul unui animal la /buyanimal (modificabil)

// Catalog de animale: /buyanimal [nr] foloseste pozitia (1-based) din acest tabel.
// aType stocat in DB = modelul obiectului.
enum E_ANIMAL_CATALOG { acModel, acName[32] }
new const g_AnimalCatalog[][E_ANIMAL_CATALOG] = {
    { 1609,  "Broasca" },
    { 19833, "Vaca" },
    { 19315, "Caprioara" }
};

enum E_ANIMAL_DATA
{
    aID, aType, aPlayerID, aHouseID, aName[32]
}
new AnimalData[MAX_ANIMALS][E_ANIMAL_DATA];
new STREAMER_TAG_OBJECT:g_AnimalObject[MAX_ANIMALS];
new g_AnimalCount = 0;

// Spawneaza obiectul (animalul) la casa lui, la coordonate usor randomizate
stock Animals_Spawn(idx)
{
    new hidx = Houses_FindByID(AnimalData[idx][aHouseID]);
    if(hidx == -1) { g_AnimalObject[idx] = STREAMER_TAG_OBJECT:INVALID_STREAMER_ID; return; }

    new Float:x = HouseData[hidx][hLocX] + float(random(10));
    new Float:y = HouseData[hidx][hLocY] + float(random(10));
    new Float:z = HouseData[hidx][hLocZ];
    g_AnimalObject[idx] = CreateDynamicObject(AnimalData[idx][aType], x, y, z, 0.0, 0.0, float(random(360)));
}

// Distruge toate obiectele-animale din lume si reseteaza contorul (datele din DB raman intacte)
stock Animals_DestroyAll()
{
    for(new i = 0; i < g_AnimalCount; i++)
    {
        if(IsValidDynamicObject(g_AnimalObject[i]))
            DestroyDynamicObject(g_AnimalObject[i]);
        g_AnimalObject[i] = STREAMER_TAG_OBJECT:INVALID_STREAMER_ID;
    }
    g_AnimalCount = 0;
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
            "[ Business #%d ]\nName: %s\nOwned: Yes\nOwner: %s\nPrice: $%s",
            BusinessData[idx][bID], BusinessData[idx][bName], BusinessData[idx][bOwner], MoneyStr(BusinessData[idx][bPrice]));
    }
    else
    {
        format(label, sizeof(label),
            "[ Business #%d ]\nName: %s\nOwned: No\nPrice: $%s\n\n/buybiz to buy this business",
            BusinessData[idx][bID], BusinessData[idx][bName], MoneyStr(BusinessData[idx][bPrice]));
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

// Constante razboi de teritorii (folosite mai jos in functiile Turfs_* si War_*)
#define MAFIA_FID_MIN             4
#define MAFIA_FID_MAX             7
#define WAR_MIN_FACTION_ONLINE    2
#define WAR_PENDING_DURATION      120  // 2 minute, inainte sa inceapa lupta efectiva
#define WAR_ACTIVE_DURATION       900  // 15 minute de lupta
#define WAR_SURRENDER_MIN_TIME    300  // 5 minute de la inceputul fazei active, ca /warsurrender sa fie permis
#define WAR_OVERTIME_KILLS_TO_WIN 3    // la egalitate dupa cele 15 minute, prima factiune cu atatea kill-uri castiga
#define WAR_FLASH_COLOR           0xFF0000AA // culoarea cu care flashuieste gangzone-ul cat timp turful e in razboi

enum E_TURF_DATA
{
    tID, tFactionID, tName[32],
    Float:tX1, Float:tY1, Float:tX2, Float:tY2,
    bool:tAttackable, tColor[9],
    // stare razboi (0=niciunul, 1=pending/2min, 2=activ/15min, 3=sudden death) - tranzitorie, nu se salveaza in DB
    tWarState, tWarAttackerFaction, tWarDefenderFaction,
    tWarAttackerScore, tWarDefenderScore,
    tWarOvertimeAttackerKills, tWarOvertimeDefenderKills,
    tWarActiveStartTime, tWarPhaseEndTime
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
    {
        if(g_TurfZone[i] == -1) continue;
        GangZoneShowForPlayer(playerid, g_TurfZone[i], HexStrToInt(TurfData[i][tColor]));

        // resincronizeaza flash-ul de razboi pt playerii care se conecteaza in timp ce un turf e deja in razboi
        if(TurfData[i][tWarState] != 0)
            GangZoneFlashForPlayer(playerid, g_TurfZone[i], WAR_FLASH_COLOR);
    }
}

// ============================================================
//  RAZBOI DE TERITORII (intre mafii, factiunile 4-7)
// ============================================================
#define WAR_STATE_NONE     0
#define WAR_STATE_PENDING  1
#define WAR_STATE_ACTIVE   2
#define WAR_STATE_OVERTIME 3

stock bool:IsMafiaFaction(fid)
{
    return (fid >= MAFIA_FID_MIN && fid <= MAFIA_FID_MAX);
}

// Numara membrii online+logati ai unei factiuni
stock War_CountOnline(fid)
{
    new c = 0;
    for(new i = 0; i < MAX_PLAYERS; i++)
        if(IsPlayerConnected(i) && PlayerData[i][pLogged] && PlayerData[i][pFaction] == fid) c++;
    return c;
}

// Trimite un mesaj tuturor membrilor online ai unei factiuni
stock War_NotifyFaction(fid, color, const text[])
{
    for(new i = 0; i < MAX_PLAYERS; i++)
        if(IsPlayerConnected(i) && PlayerData[i][pLogged] && PlayerData[i][pFaction] == fid)
            SendClientMessage(i, color, text);
}

// O factiune poate avea un singur razboi activ (ca atacator sau aparator) in orice moment -
// verifica daca fid e deja implicata in vreun razboi nerezolvat (pending/activ/overtime), pe orice turf
stock bool:War_FactionHasActiveWar(fid)
{
    for(new i = 0; i < g_TurfCount; i++)
    {
        if(TurfData[i][tWarState] == WAR_STATE_NONE) continue;
        if(TurfData[i][tWarAttackerFaction] == fid || TurfData[i][tWarDefenderFaction] == fid) return true;
    }
    return false;
}

// Initializeaza starea de razboi (pending) pe turful tidx si anunta ambele factiuni - folosit de /war si /forcewar
stock War_Declare(tidx, atkFid, defFid)
{
    TurfData[tidx][tWarState]                 = WAR_STATE_PENDING;
    TurfData[tidx][tWarAttackerFaction]        = atkFid;
    TurfData[tidx][tWarDefenderFaction]        = defFid;
    TurfData[tidx][tWarAttackerScore]          = 0;
    TurfData[tidx][tWarDefenderScore]          = 0;
    TurfData[tidx][tWarOvertimeAttackerKills]  = 0;
    TurfData[tidx][tWarOvertimeDefenderKills]  = 0;
    TurfData[tidx][tWarActiveStartTime]        = 0;
    TurfData[tidx][tWarPhaseEndTime]           = gettime() + WAR_PENDING_DURATION;

    if(g_TurfZone[tidx] != -1)
        GangZoneFlashForAll(g_TurfZone[tidx], WAR_FLASH_COLOR);

    new warMsg[220];
    format(warMsg, sizeof(warMsg), C_ERROR"[War] "C_WHITE"%s"C_WHITE" is attacking territory "C_INFO"#%d"C_WHITE" (%s) of "C_WHITE"%s"C_WHITE"! The war starts in "C_INFO"2 minutes"C_WHITE".",
        FactionData[atkFid][fName], TurfData[tidx][tID], TurfData[tidx][tName], FactionData[defFid][fName]);
    War_NotifyFaction(atkFid, COLOR_ERROR, warMsg);
    War_NotifyFaction(defFid, COLOR_ERROR, warMsg);

    SetTimerEx("War_StartActive", WAR_PENDING_DURATION * 1000, false, "i", tidx);
}

// Verifica daca punctul (x,y) e in interiorul dreptunghiului turfului (indiferent de ordinea colturilor in DB)
stock bool:War_PointInTurf(tidx, Float:x, Float:y)
{
    new Float:minX = (TurfData[tidx][tX1] < TurfData[tidx][tX2]) ? TurfData[tidx][tX1] : TurfData[tidx][tX2];
    new Float:maxX = (TurfData[tidx][tX1] < TurfData[tidx][tX2]) ? TurfData[tidx][tX2] : TurfData[tidx][tX1];
    new Float:minY = (TurfData[tidx][tY1] < TurfData[tidx][tY2]) ? TurfData[tidx][tY1] : TurfData[tidx][tY2];
    new Float:maxY = (TurfData[tidx][tY1] < TurfData[tidx][tY2]) ? TurfData[tidx][tY2] : TurfData[tidx][tY1];
    return (x >= minX && x <= maxX && y >= minY && y <= maxY);
}

// Gaseste turful in interiorul caruia se afla playerul acum (sau -1)
stock War_FindTurfPlayerStandsIn(playerid)
{
    new Float:x, Float:y, Float:z;
    GetPlayerPos(playerid, x, y, z);
    for(new i = 0; i < g_TurfCount; i++)
        if(War_PointInTurf(i, x, y)) return i;
    return -1;
}

// Gaseste turful cu razboi activ/overtime a carui zona contine (x,y) si in care factionId e implicata (atacator/aparator)
stock War_FindActiveWarForFactionAt(factionId, Float:x, Float:y)
{
    for(new i = 0; i < g_TurfCount; i++)
    {
        if(TurfData[i][tWarState] != WAR_STATE_ACTIVE && TurfData[i][tWarState] != WAR_STATE_OVERTIME) continue;
        if(TurfData[i][tWarAttackerFaction] != factionId && TurfData[i][tWarDefenderFaction] != factionId) continue;
        if(War_PointInTurf(i, x, y)) return i;
    }
    return -1;
}

// Construieste culoarea de gangzone (RRGGBB88) corespunzatoare unei factiuni, pe baza FactionColors
stock War_FactionTurfColor(fid, out[], len)
{
    format(out, len, "%06X88", (FactionColors[fid] >> 8) & 0xFFFFFF);
}

// Aplica delta la scorul factiunii date pe turful tidx; in overtime, verifica si pragul de victorie
stock War_AddScore(tidx, factionId, delta)
{
    new bool:isAttacker = (factionId == TurfData[tidx][tWarAttackerFaction]);
    if(isAttacker) TurfData[tidx][tWarAttackerScore] += delta;
    else TurfData[tidx][tWarDefenderScore] += delta;

    if(TurfData[tidx][tWarState] == WAR_STATE_OVERTIME && delta > 0)
    {
        if(isAttacker)
        {
            TurfData[tidx][tWarOvertimeAttackerKills]++;
            if(TurfData[tidx][tWarOvertimeAttackerKills] >= WAR_OVERTIME_KILLS_TO_WIN)
                War_EndWar(tidx, TurfData[tidx][tWarAttackerFaction], false);
        }
        else
        {
            TurfData[tidx][tWarOvertimeDefenderKills]++;
            if(TurfData[tidx][tWarOvertimeDefenderKills] >= WAR_OVERTIME_KILLS_TO_WIN)
                War_EndWar(tidx, TurfData[tidx][tWarDefenderFaction], false);
        }
    }
}

// Incheie razboiul: anunta ambele factiuni, transfera turful daca atacatorul a castigat, reseteaza starea
stock War_EndWar(tidx, winnerFid, bool:surrendered)
{
    if(g_TurfZone[tidx] != -1)
        GangZoneStopFlashForAll(g_TurfZone[tidx]);

    new atkFid = TurfData[tidx][tWarAttackerFaction];
    new defFid = TurfData[tidx][tWarDefenderFaction];
    new loserFid = (winnerFid == atkFid) ? defFid : atkFid;

    new wmsg[250];
    wmsg[0] = EOS;
    if(surrendered)
        format(wmsg, sizeof(wmsg), C_ERROR"[War] "C_WHITE"%s"C_WHITE" surrendered! ", FactionData[loserFid][fName]);

    new tail[200];
    if(winnerFid == atkFid)
        format(tail, sizeof(tail), C_SUCCESS"%s"C_WHITE" has conquered territory "C_INFO"#%d"C_WHITE" (%s) from "C_WHITE"%s"C_WHITE"!",
            FactionData[atkFid][fName], TurfData[tidx][tID], TurfData[tidx][tName], FactionData[defFid][fName]);
    else
        format(tail, sizeof(tail), C_SUCCESS"%s"C_WHITE" successfully defended territory "C_INFO"#%d"C_WHITE" (%s) against "C_WHITE"%s"C_WHITE"!",
            FactionData[defFid][fName], TurfData[tidx][tID], TurfData[tidx][tName], FactionData[atkFid][fName]);
    strcat(wmsg, tail);

    War_NotifyFaction(atkFid, COLOR_SUCCESS, wmsg);
    War_NotifyFaction(defFid, COLOR_SUCCESS, wmsg);

    if(winnerFid == atkFid)
    {
        TurfData[tidx][tFactionID] = winnerFid;
        War_FactionTurfColor(winnerFid, TurfData[tidx][tColor], 9);
        Turfs_RecreateZone(tidx);

        new tq[200];
        mysql_format(g_SQL, tq, sizeof(tq), "UPDATE `turfs` SET `faction_id`=%d, `color`='%s' WHERE `id`=%d",
            winnerFid, TurfData[tidx][tColor], TurfData[tidx][tID]);
        mysql_tquery(g_SQL, tq, "", "", 0);
    }

    TurfData[tidx][tWarState]                 = WAR_STATE_NONE;
    TurfData[tidx][tWarAttackerFaction]       = 0;
    TurfData[tidx][tWarDefenderFaction]       = 0;
    TurfData[tidx][tWarAttackerScore]         = 0;
    TurfData[tidx][tWarDefenderScore]         = 0;
    TurfData[tidx][tWarOvertimeAttackerKills] = 0;
    TurfData[tidx][tWarOvertimeDefenderKills] = 0;
    TurfData[tidx][tWarActiveStartTime]       = 0;
    TurfData[tidx][tWarPhaseEndTime]          = 0;
}

// La 2 minute dupa /war: incepe faza activa de 15 minute
public War_StartActive(tidx)
{
    if(TurfData[tidx][tWarState] != WAR_STATE_PENDING) return 1;

    TurfData[tidx][tWarState] = WAR_STATE_ACTIVE;
    TurfData[tidx][tWarActiveStartTime] = gettime();
    TurfData[tidx][tWarPhaseEndTime] = gettime() + WAR_ACTIVE_DURATION;

    new atkFid = TurfData[tidx][tWarAttackerFaction];
    new defFid = TurfData[tidx][tWarDefenderFaction];

    new wmsg[200];
    format(wmsg, sizeof(wmsg), C_ERROR"[War] "C_WHITE"The war for territory "C_INFO"#%d"C_WHITE" (%s) has begun! Fight for "C_INFO"15 minutes"C_WHITE".",
        TurfData[tidx][tID], TurfData[tidx][tName]);
    War_NotifyFaction(atkFid, COLOR_ERROR, wmsg);
    War_NotifyFaction(defFid, COLOR_ERROR, wmsg);

    SetTimerEx("War_CheckTimeUp", WAR_ACTIVE_DURATION * 1000, false, "i", tidx);
    return 1;
}

// La 15 minute dupa inceperea fazei active: declara castigatorul, sau intra in sudden death daca e egalitate
public War_CheckTimeUp(tidx)
{
    if(TurfData[tidx][tWarState] != WAR_STATE_ACTIVE) return 1;

    if(TurfData[tidx][tWarAttackerScore] != TurfData[tidx][tWarDefenderScore])
    {
        new winnerFid = (TurfData[tidx][tWarAttackerScore] > TurfData[tidx][tWarDefenderScore])
            ? TurfData[tidx][tWarAttackerFaction] : TurfData[tidx][tWarDefenderFaction];
        War_EndWar(tidx, winnerFid, false);
        return 1;
    }

    TurfData[tidx][tWarState] = WAR_STATE_OVERTIME;
    TurfData[tidx][tWarOvertimeAttackerKills] = 0;
    TurfData[tidx][tWarOvertimeDefenderKills] = 0;
    TurfData[tidx][tWarPhaseEndTime] = 0;

    new atkFid = TurfData[tidx][tWarAttackerFaction];
    new defFid = TurfData[tidx][tWarDefenderFaction];

    new wmsg[200];
    format(wmsg, sizeof(wmsg), C_ERROR"[War] "C_WHITE"The war for territory "C_INFO"#%d"C_WHITE" is "C_INFO"tied"C_WHITE"! Sudden death - first faction to "C_INFO"%d kills"C_WHITE" wins.",
        TurfData[tidx][tID], WAR_OVERTIME_KILLS_TO_WIN);
    War_NotifyFaction(atkFid, COLOR_ERROR, wmsg);
    War_NotifyFaction(defFid, COLOR_ERROR, wmsg);
    return 1;
}

// Aplica scorul corespunzator unei morti, daca victima (si, daca aplicabil, ucigasul) erau intr-un razboi activ relevant
stock War_HandleDeath(victimid, killerid)
{
    if(!PlayerData[victimid][pLogged]) return;

    new vFid = PlayerData[victimid][pFaction];
    if(!IsMafiaFaction(vFid)) return;

    new Float:vx, Float:vy, Float:vz;
    GetPlayerPos(victimid, vx, vy, vz);

    new tidx = War_FindActiveWarForFactionAt(vFid, vx, vy);
    if(tidx == -1) return;

    if(killerid == INVALID_PLAYER_ID || killerid == victimid)
    {
        War_AddScore(tidx, vFid, -1);
        return;
    }

    if(!IsPlayerConnected(killerid) || !PlayerData[killerid][pLogged]) return;

    new kFid = PlayerData[killerid][pFaction];
    new atkFid = TurfData[tidx][tWarAttackerFaction];
    new defFid = TurfData[tidx][tWarDefenderFaction];
    if(kFid != atkFid && kFid != defFid) return;

    new Float:kx, Float:ky, Float:kz;
    GetPlayerPos(killerid, kx, ky, kz);
    if(!War_PointInTurf(tidx, kx, ky)) return; // ucigasul nu era in zona turfului

    if(kFid == vFid)
        War_AddScore(tidx, kFid, -1); // friendly fire
    else
        War_AddScore(tidx, kFid, 1);  // kill pe inamic
}

// ============================================================
//  LOCATII IMPORTANTE
// ============================================================
#define MAX_LOCATIONS 100

enum E_LOCATION_DATA
{
    locID, locName[32], Float:locX, Float:locY, Float:locZ
}
new LocationData[MAX_LOCATIONS][E_LOCATION_DATA];
new g_LocationCount = 0;

stock Locations_FindByName(const name[])
{
    for(new i = 0; i < g_LocationCount; i++)
        if(strcmp(LocationData[i][locName], name, true) == 0) return i;
    return -1;
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
#define AMBULANCE_MODEL         416
#define HEAL_PRICE              50
#define FIRE_MAPICON_ID         20
#define FIRE_ICON_SLOT_BASE     60
#define FIRE_EXTINGUISH_RANGE   25.0
#define FACTION_SMURD           3

// ---- Boli (Diseases) ----
#define DISEASE_RADIUS       500.0
#define DISEASE_DECAY_AMOUNT 3.0
#define DISEASE_CURE_PAYDAYS 3
#define DISEASE_DRUNK_LEVEL  3000
#define HOSPITAL_RANGE       10.0
#define HOSPITAL_LOC_X       1582.5594
#define HOSPITAL_LOC_Y       1769.1219
#define HOSPITAL_LOC_Z       10.8203
#define DISEASE_CURE_PRICE   200
#define DISEASE_FREEZE_TIME  10000 // 10 secunde, in ms

#define MAX_MEDSHOPS             6
#define MEDSHOP_ICON_SLOT_BASE   70 // sloturile 70-75 (10-59 = business-uri, 60-69 = incendii)
#define MEDSHOP_MAPICON_ID       11
#define MEDSHOP_PICKUP_MODEL     2690
#define MEDSHOP_RANGE            10.0

new Float:MedShopLocations[MAX_MEDSHOPS][3] = {
    {1536.3281, 1044.9326, 10.8203},
    {2194.0332, 1990.9806, 12.2969},
    {1920.2715, 2447.3835, 11.1782},
    {1378.2955, 2355.3503, 10.8203},
    {662.2972,  1717.1869, 7.1875},
    {-87.7910,  1378.0410, 10.2734}
};

// Creeaza pickup-urile si etichetele 3D pentru shop-urile de medkit/extinctor (o singura data, la pornire)
stock MedShops_CreateWorld()
{
    new label[96];
    format(label, sizeof(label), "[ Shop ]\n[ /vMedicalKit - %s$ ]\n[ /vExtinctor - %s$ ]",
        MoneyStr(g_MedkitPrice), MoneyStr(g_ExtinguisherPrice));

    for(new i = 0; i < MAX_MEDSHOPS; i++)
    {
        CreatePickup(MEDSHOP_PICKUP_MODEL, 1, MedShopLocations[i][0], MedShopLocations[i][1], MedShopLocations[i][2], -1);
        Create3DTextLabel(label, COLOR_WHITE, MedShopLocations[i][0], MedShopLocations[i][1], MedShopLocations[i][2] - 0.0, 15.0, 0, 0);
    }
}

// Seteaza map icon-urile shop-urilor de medkit/extinctor pentru un player
stock MedShops_SetPlayerIcons(playerid)
{
    for(new i = 0; i < MAX_MEDSHOPS; i++)
    {
        SetPlayerMapIcon(playerid, MEDSHOP_ICON_SLOT_BASE + i,
            MedShopLocations[i][0], MedShopLocations[i][1], MedShopLocations[i][2],
            MEDSHOP_MAPICON_ID, 0, MAPICON_LOCAL);
    }
}

// Verifica daca playerid e in raza unuia dintre cele 6 shop-uri de medkit/extinctor
stock bool:MedShops_PlayerInRange(playerid)
{
    for(new i = 0; i < MAX_MEDSHOPS; i++)
        if(IsPlayerInRangeOfPoint(playerid, MEDSHOP_RANGE, MedShopLocations[i][0], MedShopLocations[i][1], MedShopLocations[i][2]))
            return true;
    return false;
}

// ============================================================
//  MANCARE (/pizza, /burger)
// ============================================================
#define MAX_FOOD_LOCATIONS   5
#define FOOD_RANGE            10.0

#define PIZZA_HEAL_AMOUNT     20.0
#define PIZZA_BIZ_ID          12
#define PIZZA_ICON_SLOT_BASE  76 // sloturile 76-80
#define PIZZA_MAPICON_ID      29
#define PIZZA_PICKUP_MODEL    1582

#define BURGER_HEAL_AMOUNT    25.0
#define BURGER_BIZ_ID         13
#define BURGER_ICON_SLOT_BASE 81 // sloturile 81-85
#define BURGER_MAPICON_ID     10
#define BURGER_PICKUP_MODEL   19320

new Float:PizzaLocations[MAX_FOOD_LOCATIONS][3] = {
    {2393.1387, 2042.6146, 10.8203}, // pizza1
    {2638.1370, 1849.6857, 11.0234}, // pizza2
    {173.1981,  1176.2303, 14.7645}, // pizza3
    {1368.8596, 685.2029,  10.8203}, // pizza4
    {0.0, 0.0, 0.0}
};

new Float:BurgerLocations[MAX_FOOD_LOCATIONS][3] = {
    {2163.9583, 2795.4819, 10.8203}, // burger1
    {2366.2407, 2071.1733, 10.8203}, // burger2
    {2478.7034, 2034.2334, 11.0625}, // burger3
    {1158.2510, 2072.0894, 11.0625}, // burger4
    {1873.1813, 2071.5874, 11.0625}  // burger5
};

// Verifica daca playerid e in raza uneia dintre cele 5 locatii de /pizza
stock bool:Pizza_PlayerInRange(playerid)
{
    for(new i = 0; i < MAX_FOOD_LOCATIONS; i++)
        if(IsPlayerInRangeOfPoint(playerid, FOOD_RANGE, PizzaLocations[i][0], PizzaLocations[i][1], PizzaLocations[i][2]))
            return true;
    return false;
}

// Verifica daca playerid e in raza uneia dintre cele 5 locatii de /burger
stock bool:Burger_PlayerInRange(playerid)
{
    for(new i = 0; i < MAX_FOOD_LOCATIONS; i++)
        if(IsPlayerInRangeOfPoint(playerid, FOOD_RANGE, BurgerLocations[i][0], BurgerLocations[i][1], BurgerLocations[i][2]))
            return true;
    return false;
}

// Creeaza pickup-urile si etichetele 3D pentru cele 5 locatii de /pizza (o singura data, la pornire)
stock Pizza_CreateWorld()
{
    new label[96];
    format(label, sizeof(label), "[ Buy Food ]\n[ /pizza ]\n[ +%d hp = %s$ ]", floatround(PIZZA_HEAL_AMOUNT), MoneyStr(g_PizzaPrice));

    for(new i = 0; i < MAX_FOOD_LOCATIONS; i++)
    {
        CreatePickup(PIZZA_PICKUP_MODEL, 1, PizzaLocations[i][0], PizzaLocations[i][1], PizzaLocations[i][2], -1);
        Create3DTextLabel(label, COLOR_WHITE, PizzaLocations[i][0], PizzaLocations[i][1], PizzaLocations[i][2] - 0.0, 15.0, 0, 0);
    }
}

// Seteaza map icon-urile locatiilor de /pizza pentru un player
stock Pizza_SetPlayerIcons(playerid)
{
    for(new i = 0; i < MAX_FOOD_LOCATIONS; i++)
    {
        SetPlayerMapIcon(playerid, PIZZA_ICON_SLOT_BASE + i,
            PizzaLocations[i][0], PizzaLocations[i][1], PizzaLocations[i][2],
            PIZZA_MAPICON_ID, 0, MAPICON_LOCAL);
    }
}

// Creeaza pickup-urile si etichetele 3D pentru cele 5 locatii de /burger (o singura data, la pornire)
stock Burger_CreateWorld()
{
    new label[96];
    format(label, sizeof(label), "[ Buy Food ]\n[ /burger ]\n[ +%d hp = %s$ ]", floatround(BURGER_HEAL_AMOUNT), MoneyStr(g_BurgerPrice));

    for(new i = 0; i < MAX_FOOD_LOCATIONS; i++)
    {
        CreatePickup(BURGER_PICKUP_MODEL, 1, BurgerLocations[i][0], BurgerLocations[i][1], BurgerLocations[i][2], -1);
        Create3DTextLabel(label, COLOR_WHITE, BurgerLocations[i][0], BurgerLocations[i][1], BurgerLocations[i][2] - 0.0, 15.0, 0, 0);
    }
}

// Seteaza map icon-urile locatiilor de /burger pentru un player
stock Burger_SetPlayerIcons(playerid)
{
    for(new i = 0; i < MAX_FOOD_LOCATIONS; i++)
    {
        SetPlayerMapIcon(playerid, BURGER_ICON_SLOT_BASE + i,
            BurgerLocations[i][0], BurgerLocations[i][1], BurgerLocations[i][2],
            BURGER_MAPICON_ID, 0, MAPICON_LOCAL);
    }
}

// ============================================================
//  PARTY (camera privata, virtual world izolat)
// ============================================================
#define VW_PARTY                 501
#define PARTY_RANGE              5.0
#define PARTY_TICKET_PRICE       5
#define PARTY_MUSIC_PRICE        25
#define PARTY_DRINK_PRICE        10
#define PARTY_BIZ_ID             15
#define PARTY_DRINK_MODEL        19570 // <-- schimba aici modelul paharului de bere (placeholder)
#define PARTY_ATTACH_INDEX       1     // diferit de BBALL_ATTACH_INDEX (0), ca sa nu se suprapuna
#define PARTY_ATTACH_BONE        6     // 6 = Right Hand (bone SA-MP)
#define PARTY_DRINK_HEAL         2.0
#define PARTY_DRINK_DRUNK_AMOUNT 1000  // cat de "beat" te face un pahar (vezi SetPlayerDrunkLevel)
#define PARTY_GRILL_PRICE        10
#define PARTY_GRILL_HEAL         5.0

new Float:PartyJoinLoc[3]  = {-690.6676, 941.6799, 13.6328};
new Float:PartyMusicLoc[3] = {-684.4459, 935.7082, 12.5};
new Float:PartyDrinkLoc[3] = {-691.6090, 933.9803, 12.5};
new Float:PartyGrillLoc[3] = {-688.4540, 920.1392, 11.5};

new bool:g_PartyHoldingDrink[MAX_PLAYERS];
new g_PartyMusicURL[128];

// Trimite suma data catre banca business-ului PARTY_BIZ_ID (daca exista), si persista in DB
stock Party_AddBizIncome(amount)
{
    new bidx = Businesses_FindByID(PARTY_BIZ_ID);
    if(bidx == -1) return;

    BusinessData[bidx][bBank] += amount;

    new q[128];
    mysql_format(g_SQL, q, sizeof(q), "UPDATE `businesses` SET `bank`=%d WHERE `id`=%d",
        BusinessData[bidx][bBank], BusinessData[bidx][bID]);
    mysql_tquery(g_SQL, q, "", "", 0);
}

// Consuma berea pe care o tine playerul in mana: +drunk, +HP, scoate obiectul din mana
stock Party_DrinkBeer(playerid)
{
    RemovePlayerAttachedObject(playerid, PARTY_ATTACH_INDEX);
    g_PartyHoldingDrink[playerid] = false;

    new drunk = GetPlayerDrunkLevel(playerid);
    SetPlayerDrunkLevel(playerid, drunk + PARTY_DRINK_DRUNK_AMOUNT);

    new Float:health;
    GetPlayerHealth(playerid, health);
    health += PARTY_DRINK_HEAL;
    if(health > 100.0) health = 100.0;
    SetPlayerHealth(playerid, health);

    SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"You drink the beer. Cheers!");
}

// ============================================================
//  TURNEU DE GOLF (eliminatoriu pe runde)
// ============================================================
#define GOLF_ADMIN_LEVEL     2
#define GOLF_MAX_ROUNDS      5
#define GOLF_BALL_MODEL      1974
#define GOLF_HOLE_OBJECT_MODEL 19306
#define GOLF_HOLE_RADIUS     3.0
#define GOLF_BALL_RANGE      2.0   // cat de aproape trebuie sa fie playerul de mingea lui ca sa o loveasca
#define GOLF_HIT_MAX_POWER     200   // valoarea maxima permisa pentru [numar] (puterea) la /hitball
#define GOLF_POWER_TO_DISTANCE 0.25  // 1 punct de putere = 0.25 unitati de distanta
#define GOLF_CLUB_WEAPON_ID  2     // Golf Club

// Viteza mingii (unitati/secunda), constanta pe tot traseul (MoveDynamicObject)
#define GOLF_BALL_SPEED 6.8

#define GOLF_STATUS_CLOSED   0
#define GOLF_STATUS_OPEN     1
#define GOLF_STATUS_PROGRESS 2

new g_GolfStatus = GOLF_STATUS_CLOSED;
new g_GolfRound  = 0;

// Tee (start), per runda (index 0 = runda 1). Completeaza coordonatele reale ulterior.
// X, Y, Z, unghi (directia in care e orientat playerul la tee)
new Float:GolfTeeLocations[GOLF_MAX_ROUNDS][4] = {
    {1407.9103, 2788.7463, 10.8203, 140.0},
    {1410.1445, 2755.3176, 11.3605, 140.0},
    {1418.1429, 2726.7859, 10.8203, 140.0},
    {1383.1753, 2790.1079, 10.9387, 140.0},
    {1343.0795, 2840.8035, 10.8203, 140.0}
};

// Gaurile (g1-g5). Ordinea in care sunt jucate pe runde e amestecata la fiecare /startgolf (vezi g_GolfHoleOrder).
new Float:GolfHoleLocations[GOLF_MAX_ROUNDS][3] = {
    {1148.9257, 2836.0691, 10.8203}, // g1
    {1167.4847, 2820.2939, 10.8203}, // g2
    {1145.8853, 2802.7761, 10.8203}, // g3
    {1136.6375, 2771.0535, 10.8922}, // g4
    {1129.6167, 2748.2361, 10.8203}  // g5
};

// Ordinea (indecsi in GolfHoleLocations) in care se joaca gaurile in turneul curent, amestecata la /startgolf
new g_GolfHoleOrder[GOLF_MAX_ROUNDS] = {0, 1, 2, 3, 4};

// Amesteca g_GolfHoleOrder (Fisher-Yates)
stock Golf_ShuffleHoleOrder()
{
    for(new i = 0; i < GOLF_MAX_ROUNDS; i++)
        g_GolfHoleOrder[i] = i;

    for(new i = GOLF_MAX_ROUNDS - 1; i > 0; i--)
    {
        new j = random(i + 1);
        new tmp = g_GolfHoleOrder[i];
        g_GolfHoleOrder[i] = g_GolfHoleOrder[j];
        g_GolfHoleOrder[j] = tmp;
    }
}

new bool:g_GolfJoined[MAX_PLAYERS];
new bool:g_GolfActive[MAX_PLAYERS];
new g_GolfStrokes[MAX_PLAYERS];
new g_GolfLastPower[MAX_PLAYERS];
new bool:g_GolfFinishedHole[MAX_PLAYERS];

new g_GolfHoleObject = -1;

new STREAMER_TAG_OBJECT:g_GolfBallObject[MAX_PLAYERS];
new STREAMER_TAG_3D_TEXT_LABEL:g_GolfBallLabel[MAX_PLAYERS];
new Float:g_GolfBallTarget[MAX_PLAYERS][3];
new bool:g_GolfBallMoving[MAX_PLAYERS];
new g_GolfBallLabelTimer[MAX_PLAYERS] = {-1, ...};

// Opreste (daca exista) timer-ul de resincronizare a etichetei 3D a mingii unui player
stock Golf_StopLabelTimer(playerid)
{
    if(g_GolfBallLabelTimer[playerid] != -1)
    {
        KillTimer(g_GolfBallLabelTimer[playerid]);
        g_GolfBallLabelTimer[playerid] = -1;
    }
}

// Porneste timer-ul (la fiecare 2 secunde) care recreeaza eticheta 3D la pozitia curenta a mingii -
// fallback in caz ca atasarea native (Streamer_SetIntData ATTACHED_OBJECT) nu functioneaza vizual
stock Golf_StartLabelTimer(playerid)
{
    Golf_StopLabelTimer(playerid);
    g_GolfBallLabelTimer[playerid] = SetTimerEx("Golf_LabelResync", 2000, true, "i", playerid);
}

// Recreeaza eticheta 3D a mingii la pozitia ei curenta (apelat din timer-ul de mai sus)
forward Golf_LabelResync(playerid);
public Golf_LabelResync(playerid)
{
    if(!IsPlayerConnected(playerid) || !g_GolfActive[playerid] || !IsValidDynamicObject(g_GolfBallObject[playerid]))
    {
        Golf_StopLabelTimer(playerid);
        return 1;
    }

    new Float:bx, Float:by, Float:bz;
    GetDynamicObjectPos(g_GolfBallObject[playerid], bx, by, bz);

    if(IsValidDynamic3DTextLabel(g_GolfBallLabel[playerid]))
        DestroyDynamic3DTextLabel(g_GolfBallLabel[playerid]);

    new ballLabel[32];
    format(ballLabel, sizeof(ballLabel), "[ %d ]", playerid);
    g_GolfBallLabel[playerid] = CreateDynamic3DTextLabel(ballLabel, COLOR_WHITE, bx, by, bz + 0.1, 100.0);
    Streamer_SetIntData(STREAMER_TYPE_3D_TEXT_LABEL, g_GolfBallLabel[playerid], E_STREAMER_ATTACHED_OBJECT, _:g_GolfBallObject[playerid]);
    return 1;
}

// Distruge mingea (obiect + eticheta 3D) unui player, daca exista, si opreste timer-ul de resincronizare
stock Golf_DestroyBall(playerid)
{
    if(IsValidDynamicObject(g_GolfBallObject[playerid]))
        DestroyDynamicObject(g_GolfBallObject[playerid]);
    if(IsValidDynamic3DTextLabel(g_GolfBallLabel[playerid]))
        DestroyDynamic3DTextLabel(g_GolfBallLabel[playerid]);
    Golf_StopLabelTimer(playerid);
}

stock Float:Golf_Distance(Float:x1, Float:y1, Float:z1, Float:x2, Float:y2, Float:z2)
{
    #pragma unused z1, z2
    return floatsqroot(floatpower(x2 - x1, 2.0) + floatpower(y2 - y1, 2.0));
}

// Cauta playerid-ul caruia ii apartine mingea cu obiectul dat (reverse lookup)
stock Golf_FindBallOwner(STREAMER_TAG_OBJECT:objectid)
{
    for(new i = 0; i < MAX_PLAYERS; i++)
        if(g_GolfBallObject[i] == objectid) return i;
    return -1;
}

// Porneste miscarea mingii spre g_GolfBallTarget, cu viteza constanta GOLF_BALL_SPEED
stock Golf_StartBallMove(playerid)
{
    g_GolfBallMoving[playerid] = true;
    MoveDynamicObject(g_GolfBallObject[playerid],
        g_GolfBallTarget[playerid][0], g_GolfBallTarget[playerid][1], g_GolfBallTarget[playerid][2], GOLF_BALL_SPEED);
}

// Porneste o runda noua: muta toti jucatorii activi la tee, le creeaza minge noua, reseteaza loviturile
stock Golf_StartRound(round)
{
    g_GolfRound = round;
    new holeIdx = round - 1;

    if(holeIdx < 0 || holeIdx >= GOLF_MAX_ROUNDS)
    {
        Golf_EndTournament(-1);
        return;
    }

    new msg[160];
    format(msg, sizeof(msg), C_INFO"[Golf Tournament] "C_WHITE"Round "C_INFO"%d"C_WHITE" has started!", round);
    SendClientMessageToAll(COLOR_INFO, msg);

    new actualHoleIdx = g_GolfHoleOrder[holeIdx];

    if(g_GolfHoleObject != -1)
    {
        DestroyObject(g_GolfHoleObject);
        g_GolfHoleObject = -1;
    }
    g_GolfHoleObject = CreateObject(GOLF_HOLE_OBJECT_MODEL,
        GolfHoleLocations[actualHoleIdx][0], GolfHoleLocations[actualHoleIdx][1], GolfHoleLocations[actualHoleIdx][2] - 1, 0.0, 0.0, 0.0);

    for(new i = 0; i < MAX_PLAYERS; i++)
    {
        if(!IsPlayerConnected(i) || !g_GolfActive[i]) continue;

        g_GolfStrokes[i] = 0;
        g_GolfFinishedHole[i] = false;
        g_GolfBallMoving[i] = false;

        Golf_DestroyBall(i);

        g_GolfBallObject[i] = CreateDynamicObject(GOLF_BALL_MODEL,
            GolfTeeLocations[holeIdx][0], GolfTeeLocations[holeIdx][1], GolfTeeLocations[holeIdx][2]-0.90, 0.0, 0.0, 0.0);

        new ballLabel[32];
        format(ballLabel, sizeof(ballLabel), "[ %d ]", i);
        g_GolfBallLabel[i] = CreateDynamic3DTextLabel(ballLabel, COLOR_WHITE,
            GolfTeeLocations[holeIdx][0], GolfTeeLocations[holeIdx][1], GolfTeeLocations[holeIdx][2]-0.80, 100.0);
        Streamer_SetIntData(STREAMER_TYPE_3D_TEXT_LABEL, g_GolfBallLabel[i], E_STREAMER_ATTACHED_OBJECT, _:g_GolfBallObject[i]);
        Golf_StartLabelTimer(i);

        SetPlayerPos(i, GolfTeeLocations[holeIdx][0], GolfTeeLocations[holeIdx][1], GolfTeeLocations[holeIdx][2] + 0.5);
        SetPlayerFacingAngle(i, GolfTeeLocations[holeIdx][3]);

        SetPlayerCheckpoint(i, GolfHoleLocations[actualHoleIdx][0], GolfHoleLocations[actualHoleIdx][1], GolfHoleLocations[actualHoleIdx][2], 1.0);

        SendClientMessage(i, COLOR_INFO, C_INFO"Info: "C_WHITE"Get close to your ball and use "C_INFO"/hitball [1-3]"C_WHITE" to hit it toward the hole.");
    }
}

// Cand un player isi termina gaura (mingea s-a oprit in raza GOLF_HOLE_RADIUS de groapa)
stock Golf_PlayerFinishedHole(playerid)
{
    g_GolfFinishedHole[playerid] = true;
    DisablePlayerCheckpoint(playerid);

    new fmsg[128];
    format(fmsg, sizeof(fmsg), C_SUCCESS"[Golf] "C_WHITE"%s"C_WHITE" finished the hole in "C_INFO"%d"C_WHITE" strokes!",
        PlayerData[playerid][pName], g_GolfStrokes[playerid]);
    SendClientMessageToAll(COLOR_INFO, fmsg);

    Golf_CheckRoundComplete();
}

// Verifica daca toti jucatorii activi au terminat gaura curenta
stock Golf_CheckRoundComplete()
{
    if(g_GolfStatus != GOLF_STATUS_PROGRESS) return;

    for(new i = 0; i < MAX_PLAYERS; i++)
    {
        if(!IsPlayerConnected(i) || !g_GolfActive[i]) continue;
        if(!g_GolfFinishedHole[i]) return; // mai e cineva care nu a terminat inca
    }

    Golf_FinishRound();
}

// Toti au terminat gaura: doar cel/cei cu cele mai putine lovituri trec mai departe, restul sunt eliminati
stock Golf_FinishRound()
{
    new best = 2147483647;
    for(new i = 0; i < MAX_PLAYERS; i++)
    {
        if(!IsPlayerConnected(i) || !g_GolfActive[i]) continue;
        if(g_GolfStrokes[i] < best) best = g_GolfStrokes[i];
    }

    new advancing = 0, winner = -1;
    for(new i = 0; i < MAX_PLAYERS; i++)
    {
        if(!IsPlayerConnected(i) || !g_GolfActive[i]) continue;

        if(g_GolfStrokes[i] == best)
        {
            advancing++;
            winner = i;
        }
        else
        {
            g_GolfActive[i] = false;
            DisablePlayerCheckpoint(i);
            g_GolfBallMoving[i] = false;
            Golf_DestroyBall(i);

            new emsg[128];
            format(emsg, sizeof(emsg), C_ERROR"[Golf] "C_WHITE"%s"C_WHITE" was eliminated ("C_INFO"%d strokes"C_WHITE").",
                PlayerData[i][pName], g_GolfStrokes[i]);
            SendClientMessageToAll(COLOR_ERROR, emsg);
        }
    }

    if(advancing <= 1)
    {
        Golf_EndTournament(winner);
        return;
    }

    Golf_StartRound(g_GolfRound + 1);
}

// Incheie turneul (winnerid == -1 daca nu mai sunt gauri pregatite / fara castigator)
stock Golf_EndTournament(winnerid)
{
    if(winnerid != -1 && IsPlayerConnected(winnerid))
    {
        new wmsg[160];
        format(wmsg, sizeof(wmsg), C_SUCCESS"[Golf Tournament] "C_INFO"%s"C_WHITE" won the golf tournament! Congratulations!",
            PlayerData[winnerid][pName]);
        SendClientMessageToAll(COLOR_SUCCESS, wmsg);
    }
    else
    {
        SendClientMessageToAll(COLOR_INFO, C_INFO"[Golf Tournament] "C_WHITE"The tournament has ended with no winner.");
    }

    if(g_GolfHoleObject != -1)
    {
        DestroyObject(g_GolfHoleObject);
        g_GolfHoleObject = -1;
    }

    for(new i = 0; i < MAX_PLAYERS; i++)
    {
        Golf_DestroyBall(i);
        if(IsPlayerConnected(i)) DisablePlayerCheckpoint(i);
        g_GolfJoined[i]       = false;
        g_GolfActive[i]       = false;
        g_GolfStrokes[i]      = 0;
        g_GolfFinishedHole[i] = false;
        g_GolfBallMoving[i]   = false;
    }

    g_GolfStatus = GOLF_STATUS_CLOSED;
    g_GolfRound  = 0;
}

// Cand un player se deconecteaza in timpul unei runde active, e eliminat pe loc ca sa nu blocheze runda
stock Golf_PlayerLeftMidRound(playerid)
{
    Golf_DestroyBall(playerid);

    if(IsPlayerConnected(playerid)) DisablePlayerCheckpoint(playerid);

    g_GolfJoined[playerid]     = false;
    g_GolfBallMoving[playerid] = false;

    if(g_GolfStatus == GOLF_STATUS_PROGRESS && g_GolfActive[playerid])
    {
        g_GolfActive[playerid] = false;
        Golf_CheckRoundComplete();
    }
}

// Mingea a ajuns la destinatie (MoveDynamicObject) - opreste si verifica daca a intrat in gaura
public OnDynamicObjectMoved(STREAMER_TAG_OBJECT:objectid)
{
    new playerid = Golf_FindBallOwner(objectid);
    if(playerid == -1 || !g_GolfBallMoving[playerid])
    {
        BBall_OnBallMoved(objectid);
        return 1;
    }

    g_GolfBallMoving[playerid] = false;

    if(IsPlayerConnected(playerid) && g_GolfActive[playerid] && !g_GolfFinishedHole[playerid])
    {
        new roundSlot = g_GolfRound - 1;
        if(roundSlot >= 0 && roundSlot < GOLF_MAX_ROUNDS)
        {
            new holeIdx = g_GolfHoleOrder[roundSlot];
            new Float:bx, Float:by, Float:bz;
            GetDynamicObjectPos(objectid, bx, by, bz);
            new Float:remaining = Golf_Distance(bx, by, bz, GolfHoleLocations[holeIdx][0], GolfHoleLocations[holeIdx][1], GolfHoleLocations[holeIdx][2]);
            if(remaining <= GOLF_HOLE_RADIUS)
            {
                Golf_PlayerFinishedHole(playerid);
            }
            else
            {
                new dmsg[144];
                format(dmsg, sizeof(dmsg), C_SUCCESS"Success: "C_WHITE"You hit the ball with "C_INFO"%d"C_WHITE" power! ("C_INFO"Stroke #%d"C_WHITE") - "C_INFO"%.1f"C_WHITE" meters left until the hole.",
                    g_GolfLastPower[playerid], g_GolfStrokes[playerid], remaining);
                SendClientMessage(playerid, COLOR_SUCCESS, dmsg);
            }
        }
    }
    return 1;
}

// ============================================================
//  BASCHET (runde bazate pe /joinbasket, 8 cosuri in ordine random pe runda)
// ============================================================
#define BBALL_MAX_HOOPS         8
#define BBALL_SPAWNS_PER_HOOP   4
#define BBALL_MIN_PLAYERS       1
#define BBALL_COUNTDOWN_TIME    1     // secunde
#define BBALL_LOBBY_RANGE       5.0   // cat de aproape de locatia din DB trebuie sa fie playerul pentru /joinbasket
#define BBALL_HOOP_RADIUS       0.6   // raza (2D) in care mingea trebuie sa aterizeze ca sa fie considerata cos
#define BBALL_BALL_RANGE        10.0  // cat de aproape de cosul curent trebuie sa fie playerul ca sa arunce
#define BBALL_THROW_MAX_POWER   20    // valoarea maxima permisa pentru [putere] la /throwball
#define BBALL_THROW_ANIM_DELAY  100   // ms intre /throwball si aparitia mingii (sincronizat cu animatia)
#define BBALL_BALL_SPEED        1.5   // viteza mingii (unitati/secunda)
#define BBALL_BALL_MODEL        1946
#define BBALL_LOBBY_PICKUP_MODEL 1248 // pickup-ul de la /joinbasket
#define BBALL_MAPICON_ID        25    // map icon-ul afisat la locatia /joinbasket
#define BBALL_ICON_SLOT         86    // urmeaza dupa burger (81-85); vezi BUSINESS_ICON_SLOT_BASE etc.
#define BBALL_ADMIN_LEVEL       6
#define BBALL_ATTACH_INDEX      0  // slot SetPlayerAttachedObject folosit pentru mingea tinuta in mana
#define BBALL_ATTACH_BONE       6  // 6 = Right Hand (bone SA-MP)

#define BBALL_STATUS_OPEN       0
#define BBALL_STATUS_PROGRESS   1

new g_BBallStatus = BBALL_STATUS_OPEN;

new bool:g_BBallLobbyFound = false;
new Float:g_BBallLobbyX, Float:g_BBallLobbyY, Float:g_BBallLobbyZ;
new g_BBallLobbyPickup = -1;
new Text3D:g_BBallLobbyLabel = Text3D:INVALID_3DTEXT_ID;

new bool:g_BBallCountdownActive = false;
new g_BBallCountdownLeft = 0;
new g_BBallCountdownTimer = -1;

new Float:BBallHoopData[BBALL_MAX_HOOPS][3];
new Float:BBallSpawnData[BBALL_MAX_HOOPS][BBALL_SPAWNS_PER_HOOP][3];
new Float:BBallSpawnRot[BBALL_MAX_HOOPS][BBALL_SPAWNS_PER_HOOP][3]; // rx, ry, rz
new bool:BBallSpawnSet[BBALL_MAX_HOOPS][BBALL_SPAWNS_PER_HOOP];

new g_BBallHoopOrder[BBALL_MAX_HOOPS];

new bool:g_BBallJoined[MAX_PLAYERS];
new bool:g_BBallActive[MAX_PLAYERS];
new g_BBallScore[MAX_PLAYERS];
new g_BBallHoopSlot[MAX_PLAYERS];
new bool:g_BBallSpawnedHere[MAX_PLAYERS];
new bool:g_BBallBallMoving[MAX_PLAYERS];
new STREAMER_TAG_OBJECT:g_BBallBallObject[MAX_PLAYERS];
new Float:g_BBallTargetX[MAX_PLAYERS];
new Float:g_BBallTargetY[MAX_PLAYERS];
new Float:g_BBallTargetZ[MAX_PLAYERS];
new Float:g_BBallThrowX[MAX_PLAYERS];
new Float:g_BBallThrowY[MAX_PLAYERS];
new Float:g_BBallThrowZ[MAX_PLAYERS];
new Float:g_BBallThrowAngle[MAX_PLAYERS];
new Float:g_BBallThrowDist[MAX_PLAYERS];
new bool:g_BBallDropped[MAX_PLAYERS];

new STREAMER_TAG_3D_TEXT_LABEL:g_BBallHoopLabel[MAX_PLAYERS][BBALL_MAX_HOOPS];

stock BBallHoops_Load()
{
    mysql_tquery(g_SQL, "SELECT `id`,`x`,`y`,`z` FROM `basket_hoops` ORDER BY `id` ASC", "OnBBallHoopsLoaded");
}

public OnBBallHoopsLoaded()
{
    new rows = cache_num_rows();
    for(new i = 0; i < rows && i < BBALL_MAX_HOOPS; i++)
    {
        cache_get_value_name_float(i, "x", BBallHoopData[i][0]);
        cache_get_value_name_float(i, "y", BBallHoopData[i][1]);
        cache_get_value_name_float(i, "z", BBallHoopData[i][2]);
    }
    printf("[Basketball] %d cosuri incarcate.", rows);
    return 1;
}

stock BBallSpawns_Load()
{
    mysql_tquery(g_SQL,
        "SELECT `hoop_id`,`spawn_id`,`x`,`y`,`z`,`rx`,`ry`,`rz` FROM `basket_spawns` ORDER BY `hoop_id` ASC, `spawn_id` ASC",
        "OnBBallSpawnsLoaded");
}

public OnBBallSpawnsLoaded()
{
    new rows = cache_num_rows();
    new hoopId, spawnId;
    for(new i = 0; i < rows; i++)
    {
        cache_get_value_name_int(i, "hoop_id", hoopId);
        cache_get_value_name_int(i, "spawn_id", spawnId);
        if(hoopId < 1 || hoopId > BBALL_MAX_HOOPS || spawnId < 1 || spawnId > BBALL_SPAWNS_PER_HOOP) continue;

        cache_get_value_name_float(i, "x", BBallSpawnData[hoopId-1][spawnId-1][0]);
        cache_get_value_name_float(i, "y", BBallSpawnData[hoopId-1][spawnId-1][1]);
        cache_get_value_name_float(i, "z", BBallSpawnData[hoopId-1][spawnId-1][2]);
        cache_get_value_name_float(i, "rx", BBallSpawnRot[hoopId-1][spawnId-1][0]);
        cache_get_value_name_float(i, "ry", BBallSpawnRot[hoopId-1][spawnId-1][1]);
        cache_get_value_name_float(i, "rz", BBallSpawnRot[hoopId-1][spawnId-1][2]);
        BBallSpawnSet[hoopId-1][spawnId-1] = true;
    }
    printf("[Basketball] %d spawn-uri incarcate.", rows);
    return 1;
}

// Creeaza etichetele 3D "[ #1 ]".."[ #8 ]" la fiecare cos, vizibile doar pentru acest player (cei de la /joinbasket)
stock BBall_CreateHoopLabels(playerid)
{
    new text[16];
    for(new h = 0; h < BBALL_MAX_HOOPS; h++)
    {
        format(text, sizeof(text), "[ #%d ]", h + 1);
        g_BBallHoopLabel[playerid][h] = CreateDynamic3DTextLabel(text, COLOR_WHITE,
            BBallHoopData[h][0], BBallHoopData[h][1], BBallHoopData[h][2] - 0.3, 50.0, .playerid = playerid);
    }
}

stock BBall_DestroyHoopLabels(playerid)
{
    for(new h = 0; h < BBALL_MAX_HOOPS; h++)
    {
        if(IsValidDynamic3DTextLabel(g_BBallHoopLabel[playerid][h]))
            DestroyDynamic3DTextLabel(g_BBallHoopLabel[playerid][h]);
    }
}

// Cauta locatia "Basket Game" in locations_gps (adaugata manual in DB) si creeaza pickup-ul + 3D textul
stock BBall_FindLobby()
{
    new idx = GPS_FindByName("Basket Game");
    if(idx == -1)
    {
        print("[Basketball] Locatia 'Basket Game' nu a fost gasita in locations_gps.");
        return;
    }

    g_BBallLobbyX = GPSData[idx][glLocX];
    g_BBallLobbyY = GPSData[idx][glLocY];
    g_BBallLobbyZ = GPSData[idx][glLocZ];
    g_BBallLobbyFound = true;

    BBall_CreateLobby();
}

stock BBall_CreateLobby()
{
    if(!g_BBallLobbyFound) return;

    if(g_BBallLobbyPickup != -1) DestroyPickup(g_BBallLobbyPickup);
    g_BBallLobbyPickup = CreatePickup(BBALL_LOBBY_PICKUP_MODEL, 1, g_BBallLobbyX, g_BBallLobbyY, g_BBallLobbyZ, -1);

    BBall_UpdateLobbyLabel();
}

// Actualizeaza textul 3D al lobby-ului in functie de statusul curent (OPEN/CLOSED)
stock BBall_UpdateLobbyLabel()
{
    if(!g_BBallLobbyFound) return;

    new text[96];
    if(g_BBallStatus == BBALL_STATUS_OPEN)
        format(text, sizeof(text), "[ OPEN ]\nBasketball\nUse /joinbasket");
    else
        format(text, sizeof(text), "[ CLOSED ]\nBasketball\nRound in progress");

    if(g_BBallLobbyLabel == Text3D:INVALID_3DTEXT_ID)
        g_BBallLobbyLabel = Create3DTextLabel(text, COLOR_WHITE, g_BBallLobbyX, g_BBallLobbyY, g_BBallLobbyZ + 0.5, 20.0, 0, 0);
    else
        Update3DTextLabelText(g_BBallLobbyLabel, COLOR_WHITE, text);
}

// Map icon local (vizibil doar pentru acest player) la locatia /joinbasket
stock BBall_SetPlayerIcon(playerid)
{
    if(!g_BBallLobbyFound) return;
    SetPlayerMapIcon(playerid, BBALL_ICON_SLOT, g_BBallLobbyX, g_BBallLobbyY, g_BBallLobbyZ, BBALL_MAPICON_ID, 0, MAPICON_LOCAL);
}

stock BBall_CountJoined()
{
    new c = 0;
    for(new i = 0; i < MAX_PLAYERS; i++)
        if(IsPlayerConnected(i) && g_BBallJoined[i]) c++;
    return c;
}

// Amesteca ordinea celor 8 cosuri (Fisher-Yates), la fel ca la golf
stock BBall_ShuffleHoopOrder()
{
    for(new i = 0; i < BBALL_MAX_HOOPS; i++)
        g_BBallHoopOrder[i] = i;

    for(new i = BBALL_MAX_HOOPS - 1; i > 0; i--)
    {
        new j = random(i + 1);
        new tmp = g_BBallHoopOrder[i];
        g_BBallHoopOrder[i] = g_BBallHoopOrder[j];
        g_BBallHoopOrder[j] = tmp;
    }
}

stock BBall_StartCountdown()
{
    g_BBallCountdownActive = true;
    g_BBallCountdownLeft = BBALL_COUNTDOWN_TIME;

    for(new i = 0; i < MAX_PLAYERS; i++)
    {
        if(!IsPlayerConnected(i) || !g_BBallJoined[i]) continue;
        SendClientMessage(i, COLOR_SUCCESS, C_SUCCESS"[Basket] "C_WHITE"There are enough players!");
        SendClientMessage(i, COLOR_SUCCESS, C_SUCCESS"[Basket] "C_WHITE"The basketball round starts in 1 second.");
    }

    g_BBallCountdownTimer = SetTimer("BBall_CountdownTick", 1000, true);
}

public BBall_CountdownTick()
{
    new text[8];
    format(text, sizeof(text), "%d", g_BBallCountdownLeft);

    for(new i = 0; i < MAX_PLAYERS; i++)
    {
        if(!IsPlayerConnected(i) || !g_BBallJoined[i]) continue;
        GameTextForPlayer(i, text, 1100, 3);
    }

    g_BBallCountdownLeft--;

    if(g_BBallCountdownLeft <= 0)
    {
        KillTimer(g_BBallCountdownTimer);
        g_BBallCountdownTimer = -1;
        g_BBallCountdownActive = false;

        if(BBall_CountJoined() >= BBALL_MIN_PLAYERS)
        {
            BBall_StartRound();
        }
        else
        {
            SendClientMessageToAll(COLOR_ERROR, C_ERROR"[Basket] "C_WHITE"Not enough players, the round was cancelled.");
        }
    }
    return 1;
}

stock BBall_StartRound()
{
    g_BBallStatus = BBALL_STATUS_PROGRESS;
    BBall_UpdateLobbyLabel();

    BBall_ShuffleHoopOrder();

    SendClientMessageToAll(COLOR_SUCCESS, C_SUCCESS"[Basket] "C_WHITE"Registration closed. The round has started!");

    for(new i = 0; i < MAX_PLAYERS; i++)
    {
        if(!IsPlayerConnected(i) || !g_BBallJoined[i]) continue;

        g_BBallActive[i]       = true;
        g_BBallScore[i]        = 0;
        g_BBallHoopSlot[i]     = 0;
        g_BBallSpawnedHere[i]  = false;
        g_BBallBallMoving[i]   = false;

        BBall_TeleportToCurrentHoop(i);
    }
}

// Teleporteaza playerul la unul dintre cele 4 spawn-uri (random) ale cosului curent din ordinea sa
stock BBall_TeleportToCurrentHoop(playerid)
{
    new slot = g_BBallHoopSlot[playerid];
    new hoopIdx = g_BBallHoopOrder[slot];
    new spawnIdx = random(BBALL_SPAWNS_PER_HOOP);

    new Float:sx, Float:sy, Float:sz;
    if(BBallSpawnSet[hoopIdx][spawnIdx])
    {
        sx = BBallSpawnData[hoopIdx][spawnIdx][0];
        sy = BBallSpawnData[hoopIdx][spawnIdx][1];
        sz = BBallSpawnData[hoopIdx][spawnIdx][2];
    }
    else
    {
        sx = BBallHoopData[hoopIdx][0];
        sy = BBallHoopData[hoopIdx][1];
        sz = BBallHoopData[hoopIdx][2];
    }

    // mereu orientat automat spre cosul curent, indiferent de rotatia salvata la /setbballspawn
    new Float:faceAngle = atan2(sx - BBallHoopData[hoopIdx][0], BBallHoopData[hoopIdx][1] - sy);

    SetPlayerPos(playerid, sx, sy, sz);
    SetPlayerVirtualWorld(playerid, 0);

    SetPlayerFacingAngle(playerid, faceAngle);
    SetCameraBehindPlayer(playerid); // forteaza si camera sa se resincronizeze pe noul unghi, imediat

    TogglePlayerControllable(playerid, 0); // freeze pana la /throwball, ca sa nu se miste din unghiul de aruncare

    g_BBallSpawnedHere[playerid] = true;

    new tmsg[128];
    format(tmsg, sizeof(tmsg), C_INFO"[Basket] [Hole %d/%d]: "C_WHITE"Now throwing at hoop #%d. Use /throwball [power] to shoot.",
        slot + 1, BBALL_MAX_HOOPS, hoopIdx + 1);
    SendClientMessage(playerid, COLOR_INFO, tmsg);
}

stock BBall_FindBallOwner(STREAMER_TAG_OBJECT:objectid)
{
    for(new i = 0; i < MAX_PLAYERS; i++)
        if(g_BBallBallObject[i] == objectid) return i;
    return -1;
}

stock Float:BBall_Distance2D(Float:x1, Float:y1, Float:x2, Float:y2)
{
    return floatsqroot(floatpower(x2 - x1, 2.0) + floatpower(y2 - y1, 2.0));
}

// Mingea de baschet a ajuns la destinatia curenta (MoveDynamicObject). Prima oara: evalueaza imediat
// GOAL/MISS si porneste caderea la nivelul solului (Z=9.95). A doua oara (a ajuns la sol): curata si avanseaza.
stock BBall_OnBallMoved(STREAMER_TAG_OBJECT:objectid)
{
    new playerid = BBall_FindBallOwner(objectid);
    if(playerid == -1 || !g_BBallBallMoving[playerid]) return;

    if(!g_BBallDropped[playerid])
    {
        g_BBallDropped[playerid] = true;
        BBall_EvaluateShot(playerid);
        MoveDynamicObject(g_BBallBallObject[playerid], g_BBallTargetX[playerid], g_BBallTargetY[playerid], 9.95, BBALL_BALL_SPEED);
        return;
    }

    if(IsValidDynamicObject(g_BBallBallObject[playerid]))
        DestroyDynamicObject(g_BBallBallObject[playerid]);

    g_BBallBallMoving[playerid] = false;

    if(IsPlayerConnected(playerid) && g_BBallActive[playerid])
        BBall_AdvanceHoop(playerid);
}

// Verifica daca mingea a intrat in cos (raza 2D) si anunta imediat GOAL/MISS, de cum a ajuns la cos
stock BBall_EvaluateShot(playerid)
{
    new slot = g_BBallHoopSlot[playerid];
    new hoopIdx = g_BBallHoopOrder[slot];

    new Float:dist = BBall_Distance2D(g_BBallTargetX[playerid], g_BBallTargetY[playerid],
        BBallHoopData[hoopIdx][0], BBallHoopData[hoopIdx][1]);

    new dmsg[160];
    format(dmsg, sizeof(dmsg), C_INFO"[Basket] [Hole %d/%d]: "C_WHITE"The ball traveled "C_INFO"%.1fm"C_WHITE" - "C_INFO"%.1fm"C_WHITE" left until the hoop.",
        slot + 1, BBALL_MAX_HOOPS, g_BBallThrowDist[playerid], dist);
    SendClientMessage(playerid, COLOR_INFO, dmsg);

    if(dist <= BBALL_HOOP_RADIUS)
    {
        g_BBallScore[playerid]++;

        new gmsg[128];
        format(gmsg, sizeof(gmsg), C_SUCCESS"[Basket] [Hole %d/%d]: "C_WHITE"GOAL! You scored a point.", slot + 1, BBALL_MAX_HOOPS);
        SendClientMessage(playerid, COLOR_SUCCESS, gmsg);
        GameTextForPlayer(playerid, "~g~GOAL!", 2000, 3);
    }
    else
    {
        GameTextForPlayer(playerid, "~r~MISS!", 2000, 3);

        // compara distanta aruncata cu distanta reala pana la cos (de la punctul de unde a aruncat),
        // ca sa-i spunem daca a dat cu prea multa/putina putere, sau doar a tintit gresit
        new Float:neededDist = BBall_Distance2D(g_BBallThrowX[playerid], g_BBallThrowY[playerid],
            BBallHoopData[hoopIdx][0], BBallHoopData[hoopIdx][1]);
        new Float:powerDiff = g_BBallThrowDist[playerid] - neededDist;

        new hmsg[160];
        if(powerDiff > 1.0)
            format(hmsg, sizeof(hmsg), C_ERROR"[Basket] [Hole %d/%d]: "C_WHITE"Too much power - the ball went past the hoop.", slot + 1, BBALL_MAX_HOOPS);
        else if(powerDiff < -1.0)
            format(hmsg, sizeof(hmsg), C_ERROR"[Basket] [Hole %d/%d]: "C_WHITE"Not enough power - the ball fell short.", slot + 1, BBALL_MAX_HOOPS);
        else
            hmsg[0] = EOS;

        if(hmsg[0] != EOS)
            SendClientMessage(playerid, COLOR_ERROR, hmsg);
    }
}

// Apelat la 500ms dupa /throwball (cat timp mingea sta in mana): aplica animatia de aruncare
public BBall_PlayThrowAnim(playerid, power)
{
    if(!IsPlayerConnected(playerid) || !g_BBallBallMoving[playerid]) return 1;

    ApplyAnimation(playerid, "BSKTBALL", "BBALL_Jump_Shot", 4.1, 0, 0, 0, 0, 0, 1);
    SetTimerEx("BBall_ReleaseBall", BBALL_THROW_ANIM_DELAY, false, "ii", playerid, power);
    return 1;
}

// Apelat dupa intarzierea animatiei: creeaza mingea si o porneste spre destinatie
public BBall_ReleaseBall(playerid, power)
{
    if(!IsPlayerConnected(playerid))
    {
        g_BBallBallMoving[playerid] = false;
        return 1;
    }

    RemovePlayerAttachedObject(playerid, BBALL_ATTACH_INDEX);

    if(g_BBallStatus != BBALL_STATUS_PROGRESS || !g_BBallActive[playerid])
    {
        g_BBallBallMoving[playerid] = false;
        return 1;
    }

    new Float:px = g_BBallThrowX[playerid];
    new Float:py = g_BBallThrowY[playerid];
    new Float:pz = g_BBallThrowZ[playerid];
    new Float:angle = g_BBallThrowAngle[playerid];

    new slot = g_BBallHoopSlot[playerid];
    new hoopIdx = g_BBallHoopOrder[slot];

    new Float:throwDist = float(power) * 0.5 + float((power / 8 > 0) ? random(power / 8) : 0);
    g_BBallThrowDist[playerid] = throwDist;
    g_BBallDropped[playerid] = false;

    new Float:originX = px + 0.5 * floatsin(-angle, degrees);
    new Float:originY = py + 0.5 * floatcos(angle, degrees);
    new Float:originZ = pz + 1.1;

    g_BBallTargetX[playerid] = px + floatsin(-angle, degrees) * throwDist;
    g_BBallTargetY[playerid] = py + floatcos(angle, degrees) * throwDist;

    // daca puterea a fost prea mare/mica fata de distanta reala pana la cos, mingea aterizeaza
    // vizibil deasupra (prea multa putere) sau sub (prea putina) inaltimea cosului
    new Float:neededDist = BBall_Distance2D(px, py, BBallHoopData[hoopIdx][0], BBallHoopData[hoopIdx][1]);
    new Float:powerDiff = throwDist - neededDist;

    if(powerDiff > 1.0)
        g_BBallTargetZ[playerid] = BBallHoopData[hoopIdx][2] + 1.0;
    else if(powerDiff < -1.0)
        g_BBallTargetZ[playerid] = BBallHoopData[hoopIdx][2] - 1.0;
    else
        g_BBallTargetZ[playerid] = BBallHoopData[hoopIdx][2];

    g_BBallBallObject[playerid] = CreateDynamicObject(BBALL_BALL_MODEL, originX, originY, originZ, 0.0, 0.0, 0.0);

    if(!IsValidDynamicObject(g_BBallBallObject[playerid]))
    {
        g_BBallBallMoving[playerid] = false;
        SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Failed to create the ball object (invalid model). Try again.");
        return 1;
    }

    // forteaza imediat reevaluarea streamer-ului pentru acest player (altfel, daca sta nemiscat,
    // obiectul nou-creat poate ramane nestream-uit pana la urmatorul tick automat / urmatoarea miscare)
    Streamer_Update(playerid);

    // intarziere mica intre creare si prima miscare, ca obiectul sa apuce sa fie stream-uit la client
    // inainte sa primeasca si comanda de MoveDynamicObject (altfel risca sa nu apara deloc vizual)
    SetTimerEx("BBall_StartArc", 100, false, "i", playerid);
    return 1;
}

// Porneste miscarea mingii in linie dreapta (fara arc) catre destinatia finala
public BBall_StartArc(playerid)
{
    if(!IsPlayerConnected(playerid) || !g_BBallBallMoving[playerid]) return 1;
    if(!IsValidDynamicObject(g_BBallBallObject[playerid])) return 1;

    MoveDynamicObject(g_BBallBallObject[playerid],
        g_BBallTargetX[playerid], g_BBallTargetY[playerid], g_BBallTargetZ[playerid], BBALL_BALL_SPEED);
    return 1;
}

// Trece playerul la urmatorul cos din ordinea sa, sau il marcheaza terminat daca le-a parcurs pe toate cele 8
stock BBall_AdvanceHoop(playerid)
{
    g_BBallHoopSlot[playerid]++;
    g_BBallSpawnedHere[playerid] = false;

    if(g_BBallHoopSlot[playerid] >= BBALL_MAX_HOOPS)
    {
        g_BBallActive[playerid] = false;

        new fmsg[128];
        format(fmsg, sizeof(fmsg), C_SUCCESS"[Basket] "C_WHITE"%s"C_WHITE" finished all hoops with "C_INFO"%d"C_WHITE" point(s)!",
            PlayerData[playerid][pName], g_BBallScore[playerid]);
        SendClientMessageToAll(COLOR_INFO, fmsg);

        BBall_CheckRoundComplete();
        return;
    }

    BBall_TeleportToCurrentHoop(playerid);
}

// Verifica daca toti participantii activi au terminat cele 8 cosuri
stock BBall_CheckRoundComplete()
{
    for(new i = 0; i < MAX_PLAYERS; i++)
    {
        if(!IsPlayerConnected(i) || !g_BBallJoined[i]) continue;
        if(g_BBallActive[i]) return; // mai e cineva activ
    }

    BBall_EndRound();
}

// Compara scorurile tuturor participantilor si anunta castigatorul (sau egalitate)
stock BBall_EndRound()
{
    new best = -1, winner = -1, tieCount = 0;
    for(new i = 0; i < MAX_PLAYERS; i++)
    {
        if(!IsPlayerConnected(i) || !g_BBallJoined[i]) continue;

        if(g_BBallScore[i] > best)
        {
            best = g_BBallScore[i];
            winner = i;
            tieCount = 1;
        }
        else if(g_BBallScore[i] == best)
        {
            tieCount++;
        }
    }

    SendClientMessageToAll(COLOR_INFO, C_INFO"[Basket] "C_WHITE"Round finished!");

    if(winner != -1 && tieCount == 1)
    {
        new wmsg[128];
        format(wmsg, sizeof(wmsg), C_SUCCESS"[Basket] "C_WHITE"Winner: "C_INFO"%s"C_WHITE" - "C_INFO"%d"C_WHITE" point(s)",
            PlayerData[winner][pName], best);
        SendClientMessageToAll(COLOR_SUCCESS, wmsg);
    }
    else
    {
        SendClientMessageToAll(COLOR_INFO, C_INFO"[Basket] "C_WHITE"It was a tie.");
    }

    BBall_ResetAll();
}

// Reseteaza tot sistemul la starea initiala (status OPEN), gata pentru o noua runda
stock BBall_ResetAll()
{
    for(new i = 0; i < MAX_PLAYERS; i++)
    {
        if(IsValidDynamicObject(g_BBallBallObject[i]))
            DestroyDynamicObject(g_BBallBallObject[i]);

        if(IsPlayerConnected(i))
        {
            RemovePlayerAttachedObject(i, BBALL_ATTACH_INDEX);
            TogglePlayerControllable(i, 1);
        }

        BBall_DestroyHoopLabels(i);

        g_BBallJoined[i]       = false;
        g_BBallActive[i]       = false;
        g_BBallScore[i]        = 0;
        g_BBallHoopSlot[i]     = 0;
        g_BBallSpawnedHere[i]  = false;
        g_BBallBallMoving[i]   = false;
    }

    g_BBallStatus = BBALL_STATUS_OPEN;
    g_BBallCountdownActive = false;
    g_BBallCountdownLeft = 0;
    if(g_BBallCountdownTimer != -1)
    {
        KillTimer(g_BBallCountdownTimer);
        g_BBallCountdownTimer = -1;
    }

    BBall_UpdateLobbyLabel();
}

// Cand un player se deconecteaza: curata mingea/starea lui si, daca era activ intr-o runda, verifica daca runda se incheie
stock BBall_PlayerLeftMidRound(playerid)
{
    if(IsValidDynamicObject(g_BBallBallObject[playerid]))
        DestroyDynamicObject(g_BBallBallObject[playerid]);

    if(IsPlayerConnected(playerid))
    {
        RemovePlayerAttachedObject(playerid, BBALL_ATTACH_INDEX);
        TogglePlayerControllable(playerid, 1);
    }

    BBall_DestroyHoopLabels(playerid);

    new bool:wasActiveInRound = (g_BBallStatus == BBALL_STATUS_PROGRESS && g_BBallActive[playerid]);

    g_BBallJoined[playerid]      = false;
    g_BBallActive[playerid]      = false;
    g_BBallBallMoving[playerid]  = false;
    g_BBallSpawnedHere[playerid] = false;
    g_BBallHoopSlot[playerid]    = 0;
    g_BBallScore[playerid]       = 0;

    if(wasActiveInRound)
    {
        BBall_CheckRoundComplete();
        return;
    }

    if(g_BBallCountdownActive && BBall_CountJoined() < BBALL_MIN_PLAYERS)
    {
        if(g_BBallCountdownTimer != -1)
        {
            KillTimer(g_BBallCountdownTimer);
            g_BBallCountdownTimer = -1;
        }
        g_BBallCountdownActive = false;
        g_BBallCountdownLeft = 0;
        SendClientMessageToAll(COLOR_ERROR, C_ERROR"[Basket] "C_WHITE"Not enough players left, the round start was cancelled.");
    }
}

// ============================================================
//  RULOTE PERSONALE (tractare)
// ============================================================
#define CARAVAN_MODEL_1          3174
#define CARAVAN_MODEL_2          3171
#define CARAVAN_MODEL_3          3172
#define CARAVAN_ATTACH_OFFSET_Y -6  // distanta in spatele masinii unde sta rulota cand e atasata
#define CARAVAN_ATTACH_OFFSET_Z -0.8 // cat de jos sta rulota fata de masina cand e atasata
#define CARAVAN_PARK_OFFSET_Z   -0.5  // cat de jos se pozitioneaza rulota fata de masina la /detach
#define MAX_PERSONAL_CARAVANS   100
#define CARAVAN_CAMP_DURATION   10800 // 3 ore (= 3 payday-uri, paydayul ruleaza o data pe ora) - vezi /camp
#define CARAVAN_CAMP_SPAWN_TYPE 4     // valoarea pSpawn cat timp playerul "campeaza" la rulota lui
#define CARAVAN_ATTACH_RANGE    10.0  // cat de aproape de rulota (deja existenta undeva) trebuie sa fii ca s-o atasezi

enum E_CARAVAN_DATA
{
    rID, rOwned, rOwner, rType, rPrice, bool:rCamping, rCampingStartDate,
    Float:rParkLocX, Float:rParkLocY, Float:rParkLocZ,
    Float:rCampLocX, Float:rCampLocY, Float:rCampLocZ,
    Float:rParkRX, Float:rParkRY, Float:rParkRZ,
    Float:rCampRX, Float:rCampRY, Float:rCampRZ
}
new CaravanData[MAX_PERSONAL_CARAVANS][E_CARAVAN_DATA];
new g_CaravanCount = 0;

new STREAMER_TAG_OBJECT:g_CaravanObject[MAX_PLAYERS]; // un singur obiect per owner (un singur pCaravanKey per player)
new g_CaravanAttachedVeh[MAX_PLAYERS]; // 0 = parcata (neatasata), altfel = vehicleid de care e atasata in acest moment
new STREAMER_TAG_OBJECT:g_CaravanOfflineObject[MAX_PERSONAL_CARAVANS]; // obiect persistent pt rulotele cu owner offline (vezi Caravans_RebuildAll)

stock Caravan_GetModel(type)
{
    if(type == 2) return CARAVAN_MODEL_2;
    if(type == 3) return CARAVAN_MODEL_3;
    return CARAVAN_MODEL_1;
}

// Intoarce rotatia COMPLETA (rx/ry/rz, in grade) a unui vehicul, inclusiv panta/inclinarea, nu doar directia.
// SA-MP nu are un native direct pentru asta (doar GetVehicleZAngle, care da exclusiv directia) - se calculeaza
// din quaternion (GetVehicleRotationQuat), folosind formula standard "GetVehicleRotation" din comunitatea SA-MP.
stock GetVehicleRotation(vehicleid, &Float:rx, &Float:ry, &Float:rz)
{
    new Float:w, Float:x, Float:y, Float:z;
    GetVehicleRotationQuat(vehicleid, w, x, y, z);

    new Float:sqw = w * w;
    new Float:sqx = x * x;
    new Float:sqy = y * y;
    new Float:sqz = z * z;

    // rx/rz sunt schimbate intre ele fata de formula standard "GetVehicleRotation" - testat empiric
    // (vezi /detach debug log): unghiul de yaw cade pe axa Z (rz), nu pe X, pentru obiectele SA-MP
    rz = atan2(2.0 * (x*y + z*w), sqx - sqy - sqz + sqw);

    new Float:sinp = -2.0 * (x*z - y*w);
    if(sinp > 1.0) sinp = 1.0;
    else if(sinp < -1.0) sinp = -1.0;
    ry = -asin(sinp); // semn inversat fata de formula standard - de testat daca rezolva eroarea reziduala

    rx = atan2(2.0 * (y*z + x*w), -sqx - sqy + sqz + sqw);

    // NOTA: atan2()/asin() din SA-MP intorc deja grade, nu radiani (spre deosebire de C standard) -
    // nu se mai inmulteste cu RAD2DEG aici, altfel valorile se umfla de ~57x (bug confirmat din /detach debug log)

    if(rx < 0.0) rx += 360.0;
    if(ry < 0.0) ry += 360.0;
    if(rz < 0.0) rz += 360.0;
}

// Cauta rândul din CaravanData detinut de un anumit player (dupa pID), sau -1
stock Caravan_FindByOwner(ownerId)
{
    for(new i = 0; i < g_CaravanCount; i++)
        if(CaravanData[i][rOwned] && CaravanData[i][rOwner] == ownerId) return i;
    return -1;
}

stock Caravans_Load()
{
    mysql_tquery(g_SQL,
        "SELECT `rID`,`rOwned`,`rOwner`,`rType`,`rPrice`,`rCamping`,`rCampingStartDate`,\
         `rParkLocX`,`rParkLocY`,`rParkLocZ`,`rCampLocX`,`rCampLocY`,`rCampLocZ`,\
         `parkRX`,`parkRY`,`parkRZ`,`campRX`,`campRY`,`campRZ` \
         FROM `rulote_personale` ORDER BY `rID` ASC",
        "OnCaravansLoaded");
}

public OnCaravansLoaded()
{
    new rows = cache_num_rows();
    g_CaravanCount = 0;
    for(new i = 0; i < rows && g_CaravanCount < MAX_PERSONAL_CARAVANS; i++)
    {
        new idx = g_CaravanCount;
        cache_get_value_name_int(i, "rID",    CaravanData[idx][rID]);
        cache_get_value_name_int(i, "rOwned", CaravanData[idx][rOwned]);
        cache_get_value_name_int(i, "rOwner", CaravanData[idx][rOwner]);
        cache_get_value_name_int(i, "rType",  CaravanData[idx][rType]);
        cache_get_value_name_int(i, "rPrice", CaravanData[idx][rPrice]);

        new campingInt;
        cache_get_value_name_int(i, "rCamping", campingInt);
        CaravanData[idx][rCamping] = bool:campingInt;

        new dateBuf[20];
        cache_get_value_name(i, "rCampingStartDate", dateBuf, sizeof(dateBuf));
        CaravanData[idx][rCampingStartDate] = DateTimeStrToUnix(dateBuf);

        cache_get_value_name_float(i, "rParkLocX", CaravanData[idx][rParkLocX]);
        cache_get_value_name_float(i, "rParkLocY", CaravanData[idx][rParkLocY]);
        cache_get_value_name_float(i, "rParkLocZ", CaravanData[idx][rParkLocZ]);
        cache_get_value_name_float(i, "rCampLocX", CaravanData[idx][rCampLocX]);
        cache_get_value_name_float(i, "rCampLocY", CaravanData[idx][rCampLocY]);
        cache_get_value_name_float(i, "rCampLocZ", CaravanData[idx][rCampLocZ]);
        cache_get_value_name_float(i, "parkRX", CaravanData[idx][rParkRX]);
        cache_get_value_name_float(i, "parkRY", CaravanData[idx][rParkRY]);
        cache_get_value_name_float(i, "parkRZ", CaravanData[idx][rParkRZ]);
        cache_get_value_name_float(i, "campRX", CaravanData[idx][rCampRX]);
        cache_get_value_name_float(i, "campRY", CaravanData[idx][rCampRY]);
        cache_get_value_name_float(i, "campRZ", CaravanData[idx][rCampRZ]);

        g_CaravanCount++;
    }
    printf("[Rulote] %d rulote incarcate.", g_CaravanCount);
    return 1;
}

// Completeaza rID-ul real (alocat de DB) pentru rândul rezervat sincron in /createcaravan
public OnCaravanCreated(playerid, idx)
{
    CaravanData[idx][rID] = cache_insert_id();
    return 1;
}

// La fiecare payday: reseteaza camping-ul rulotelor care au depasit CARAVAN_CAMP_DURATION (3 ore = 3 payday-uri)
stock Caravan_CheckCampingExpiry()
{
    new now = gettime();
    for(new i = 0; i < g_CaravanCount; i++)
    {
        if(!CaravanData[i][rOwned] || !CaravanData[i][rCamping]) continue;
        if(CaravanData[i][rCampingStartDate] <= 0) continue;
        if(now - CaravanData[i][rCampingStartDate] < CARAVAN_CAMP_DURATION) continue;

        CaravanData[i][rCamping]          = false;
        CaravanData[i][rCampingStartDate] = 0;
        CaravanData[i][rCampLocX]         = 0.0;
        CaravanData[i][rCampLocY]         = 0.0;
        CaravanData[i][rCampLocZ]         = 0.0;
        CaravanData[i][rCampRX]           = 0.0;
        CaravanData[i][rCampRY]           = 0.0;
        CaravanData[i][rCampRZ]           = 0.0;

        new cq[256];
        mysql_format(g_SQL, cq, sizeof(cq),
            "UPDATE `rulote_personale` SET `rCamping`=0, `rCampingStartDate`=NULL, `rCampLocX`=0, `rCampLocY`=0, `rCampLocZ`=0, `campRX`=0, `campRY`=0, `campRZ`=0 WHERE `rID`=%d",
            CaravanData[i][rID]);
        mysql_tquery(g_SQL, cq, "", "", 0);

        new ownerId = CaravanData[i][rOwner];

        // acopera si playerii offline: casa daca are, altfel factiune daca are, altfel civil
        new oq[300];
        mysql_format(g_SQL, oq, sizeof(oq),
            "UPDATE `players` p LEFT JOIN `houses` h ON h.owner_id = p.id AND h.owned = 1 \
             SET p.spawn_type = CASE WHEN h.id IS NOT NULL THEN 3 WHEN p.faction != 0 THEN 2 ELSE 1 END \
             WHERE p.id = %d",
            ownerId);
        mysql_tquery(g_SQL, oq, "", "", 0);

        new ownerPlayerid = Houses_FindPlayerByPID(ownerId);
        if(ownerPlayerid != INVALID_PLAYER_ID)
        {
            new newSpawn = 1;
            if(PlayerData[ownerPlayerid][pHouse] != 999 && Houses_FindByID(PlayerData[ownerPlayerid][pHouse]) != -1)
                newSpawn = 3;
            else if(PlayerData[ownerPlayerid][pFaction] >= 1 && PlayerData[ownerPlayerid][pFaction] <= MAX_FACTIONS)
                newSpawn = 2;

            PlayerData[ownerPlayerid][pSpawn] = newSpawn;
            Player_RecalcSpawn(ownerPlayerid);

            SendClientMessage(ownerPlayerid, COLOR_INFO,
                C_INFO"Info: "C_WHITE"Your camping spot at the caravan has expired. Your spawn point has been reset.");
        }
    }
}

// La login: daca playerul detine o rulota si a fost parcata/campata cel putin o data, o recreeaza la ultima
// pozitie salvata (rCampLoc daca e populat, altfel rParkLoc) si curata obiectul "offline" lasat de payday
stock Caravan_ShowParked(playerid)
{
    if(PlayerData[playerid][pCaravanKey] == 0) return;

    new cidx = Caravan_FindByOwner(PlayerData[playerid][pID]);
    if(cidx == -1) return;

    if(IsValidDynamicObject(g_CaravanOfflineObject[cidx]))
        DestroyDynamicObject(g_CaravanOfflineObject[cidx]);

    if(IsValidDynamicObject(g_CaravanObject[playerid])) return;

    new bool:useCamp = (CaravanData[cidx][rCampLocX] != 0.0 || CaravanData[cidx][rCampLocY] != 0.0 || CaravanData[cidx][rCampLocZ] != 0.0);
    if(!useCamp && CaravanData[cidx][rParkLocX] == 0.0 && CaravanData[cidx][rParkLocY] == 0.0 && CaravanData[cidx][rParkLocZ] == 0.0) return;

    g_CaravanObject[playerid] = useCamp
        ? CreateDynamicObject(Caravan_GetModel(PlayerData[playerid][pCaravanKey]),
            CaravanData[cidx][rCampLocX], CaravanData[cidx][rCampLocY], CaravanData[cidx][rCampLocZ],
            CaravanData[cidx][rCampRX], CaravanData[cidx][rCampRY], CaravanData[cidx][rCampRZ])
        : CreateDynamicObject(Caravan_GetModel(PlayerData[playerid][pCaravanKey]),
            CaravanData[cidx][rParkLocX], CaravanData[cidx][rParkLocY], CaravanData[cidx][rParkLocZ],
            CaravanData[cidx][rParkRX], CaravanData[cidx][rParkRY], CaravanData[cidx][rParkRZ]);
}

// La fiecare payday: distruge si recreeaza obiectele TUTUROR rulotelor detinute (online sau offline),
// neatasate de un vehicul in acel moment - la rCampLoc daca e populat, altfel la rParkLoc
stock Caravans_RebuildAll()
{
    new countPark = 0, countCamp = 0;

    for(new cidx = 0; cidx < g_CaravanCount; cidx++)
    {
        if(!CaravanData[cidx][rOwned]) continue;

        new ownerPlayerid = Houses_FindPlayerByPID(CaravanData[cidx][rOwner]);
        new bool:online = (ownerPlayerid != INVALID_PLAYER_ID);

        if(online && g_CaravanAttachedVeh[ownerPlayerid] != 0) continue; // atasata de un vehicul acum - nu o atingem

        new bool:useCamp = (CaravanData[cidx][rCampLocX] != 0.0 || CaravanData[cidx][rCampLocY] != 0.0 || CaravanData[cidx][rCampLocZ] != 0.0);

        new Float:px, Float:py, Float:pz, Float:rx, Float:ry, Float:rz;
        if(useCamp)
        {
            px = CaravanData[cidx][rCampLocX];
            py = CaravanData[cidx][rCampLocY];
            pz = CaravanData[cidx][rCampLocZ];
            rx = CaravanData[cidx][rCampRX];
            ry = CaravanData[cidx][rCampRY];
            rz = CaravanData[cidx][rCampRZ];
            countCamp++;
        }
        else
        {
            if(CaravanData[cidx][rParkLocX] == 0.0 && CaravanData[cidx][rParkLocY] == 0.0 && CaravanData[cidx][rParkLocZ] == 0.0) continue; // niciodata parcata

            px = CaravanData[cidx][rParkLocX];
            py = CaravanData[cidx][rParkLocY];
            pz = CaravanData[cidx][rParkLocZ];
            rx = CaravanData[cidx][rParkRX];
            ry = CaravanData[cidx][rParkRY];
            rz = CaravanData[cidx][rParkRZ];
            countPark++;
        }

        new model = Caravan_GetModel(CaravanData[cidx][rType]);

        if(online)
        {
            if(IsValidDynamicObject(g_CaravanObject[ownerPlayerid]))
                DestroyDynamicObject(g_CaravanObject[ownerPlayerid]);
            g_CaravanObject[ownerPlayerid] = CreateDynamicObject(model, px, py, pz, rx, ry, rz);
        }
        else
        {
            if(IsValidDynamicObject(g_CaravanOfflineObject[cidx]))
                DestroyDynamicObject(g_CaravanOfflineObject[cidx]);
            g_CaravanOfflineObject[cidx] = CreateDynamicObject(model, px, py, pz, rx, ry, rz);
        }
    }

    printf("[Rulote] Caravanele au fost refacute: %d la rParkLoc, %d la rCampLoc.", countPark, countCamp);
}

#define FACTION_RAR             2
#define FACTION_POLICE          1

// ============================================================
//  GARAJ POLITIE (teleport garaj <-> intrare)
// ============================================================
#define POLICE_GARAGE_X     2287.2419
#define POLICE_GARAGE_Y     2431.6370
#define POLICE_GARAGE_Z     10.9
#define POLICE_ENTRANCE_X   2296.5811
#define POLICE_ENTRANCE_Y   2451.4043
#define POLICE_ENTRANCE_Z   10.9
#define POLICE_TP_RANGE     7.0

// Teleporteaza playerul (sau vehiculul, daca se afla in unul) la coordonatele date
stock Police_TeleportTo(playerid, Float:x, Float:y, Float:z)
{
    new vehid = GetPlayerVehicleID(playerid);
    if(vehid != 0)
        SetVehiclePos(vehid, x, y, z);
    else
        SetPlayerPos(playerid, x, y, z);
}

// Daca playerul e in raza garajului sau a intrarii, il teleporteaza la celalalt punct.
// Returneaza true daca a fost teleportat, false daca nu era in raza niciunui punct.
stock bool:Police_GarageEntranceToggle(playerid)
{
    if(IsPlayerInRangeOfPoint(playerid, POLICE_TP_RANGE, POLICE_GARAGE_X, POLICE_GARAGE_Y, POLICE_GARAGE_Z))
    {
        Police_TeleportTo(playerid, POLICE_ENTRANCE_X, POLICE_ENTRANCE_Y, POLICE_ENTRANCE_Z);
        return true;
    }
    if(IsPlayerInRangeOfPoint(playerid, POLICE_TP_RANGE, POLICE_ENTRANCE_X, POLICE_ENTRANCE_Y, POLICE_ENTRANCE_Z))
    {
        Police_TeleportTo(playerid, POLICE_GARAGE_X, POLICE_GARAGE_Y, POLICE_GARAGE_Z);
        return true;
    }
    return false;
}

#define FIRE_OBJECT_MODEL        18691 // obiect cu animatie de foc in bucla, spre deosebire de CreateExplosion poate fi distrus instant

enum E_FIRE_DATA
{
    bool:fireActive,
    Float:fireX, Float:fireY, Float:fireZ,
    fireRequired,
    fireProgress,
    fireObject
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

// Stinge incendiul: distruge obiectul de foc pe loc, anunta SMURD-ul si sterge map icon-ul de la toti playerii
stock Fires_Extinguish(f, extinguisherId)
{
    FireData[f][fireActive] = false;

    if(FireData[f][fireObject] != 0)
    {
        DestroyObject(FireData[f][fireObject]);
        FireData[f][fireObject] = 0;
    }

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

// Timer global (1s): verifica daca e stins de pompieri (animatia de foc ruleaza singura, in bucla, pe obiect)
public Fires_Tick()
{
    for(new f = 0; f < MAX_FIRES; f++)
    {
        if(!FireData[f][fireActive]) continue;

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

#define RADAR_OBJECT_MODEL 18654

new bool:g_RadarActive[MAX_PLAYERS];
new Float:g_RadarX[MAX_PLAYERS];
new Float:g_RadarY[MAX_PLAYERS];
new Float:g_RadarZ[MAX_PLAYERS];
new g_RadarSpeedLimit[MAX_PLAYERS];
new g_RadarFlaggedBy[MAX_PLAYERS] = {-1, ...}; // pentru fiecare player, ID-ul ofiterului al carui radar l-a avertizat deja (evita spam la fiecare tick)
new g_RadarObject[MAX_PLAYERS] = {-1, ...};
new Text3D:g_RadarLabel[MAX_PLAYERS] = {Text3D:INVALID_3DTEXT_ID, ...};

// Distruge obiectul si eticheta 3D ale radarului unui player, daca exista
stock Radar_DestroyProps(playerid)
{
    if(g_RadarObject[playerid] != -1)
    {
        DestroyObject(g_RadarObject[playerid]);
        g_RadarObject[playerid] = -1;
    }
    if(g_RadarLabel[playerid] != Text3D:INVALID_3DTEXT_ID)
    {
        Delete3DTextLabel(g_RadarLabel[playerid]);
        g_RadarLabel[playerid] = Text3D:INVALID_3DTEXT_ID;
    }
}

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

// vehicleid (real) -> index in PVehicleData, sau -1 daca nu e vehicul personal
new g_VehicleToPVIndex[MAX_VEHICLES];

// ============================================================
//  SPEEDOMETER (viteza / HP / lock)
// ============================================================
#define SPEEDOMETER_TICK 200 // 0.2 secunde, in ms

new PlayerText:Speedometer_Text[MAX_PLAYERS][4];
new bool:g_SpeedometerShown[MAX_PLAYERS];
new bool:g_SpeedometerLockShown[MAX_PLAYERS]; // textdraw-ul de lock/unlock apare doar la masinile personale

forward Speedometer_Tick();

// Creeaza cele 3 textdraw-uri (viteza/HP/lock) pentru un player, ascunse initial
stock Speedometer_Create(playerid)
{
    Speedometer_Text[playerid][0] = CreatePlayerTextDraw(playerid, 607.000, 400.000, "999 km/h");
    PlayerTextDrawLetterSize(playerid, Speedometer_Text[playerid][0], 0.160, 0.999);
    PlayerTextDrawTextSize(playerid, Speedometer_Text[playerid][0], 50.000, 58.000);
    PlayerTextDrawAlignment(playerid, Speedometer_Text[playerid][0], 2);
    PlayerTextDrawColor(playerid, Speedometer_Text[playerid][0], 255);
    PlayerTextDrawUseBox(playerid, Speedometer_Text[playerid][0], 1);
    PlayerTextDrawBoxColor(playerid, Speedometer_Text[playerid][0], -757935435);
    PlayerTextDrawSetShadow(playerid, Speedometer_Text[playerid][0], 0);
    PlayerTextDrawSetOutline(playerid, Speedometer_Text[playerid][0], 0);
    PlayerTextDrawBackgroundColor(playerid, Speedometer_Text[playerid][0], 255);
    PlayerTextDrawFont(playerid, Speedometer_Text[playerid][0], 1);
    PlayerTextDrawSetProportional(playerid, Speedometer_Text[playerid][0], 1);

    Speedometer_Text[playerid][1] = CreatePlayerTextDraw(playerid, 607.000, 412.000, "9999 hp");
    PlayerTextDrawLetterSize(playerid, Speedometer_Text[playerid][1], 0.160, 0.999);
    PlayerTextDrawTextSize(playerid, Speedometer_Text[playerid][1], 50.000, 58.000);
    PlayerTextDrawAlignment(playerid, Speedometer_Text[playerid][1], 2);
    PlayerTextDrawColor(playerid, Speedometer_Text[playerid][1], 255);
    PlayerTextDrawUseBox(playerid, Speedometer_Text[playerid][1], 1);
    PlayerTextDrawBoxColor(playerid, Speedometer_Text[playerid][1], -757935537);
    PlayerTextDrawSetShadow(playerid, Speedometer_Text[playerid][1], 0);
    PlayerTextDrawSetOutline(playerid, Speedometer_Text[playerid][1], 0);
    PlayerTextDrawBackgroundColor(playerid, Speedometer_Text[playerid][1], 255);
    PlayerTextDrawFont(playerid, Speedometer_Text[playerid][1], 1);
    PlayerTextDrawSetProportional(playerid, Speedometer_Text[playerid][1], 1);

    Speedometer_Text[playerid][2] = CreatePlayerTextDraw(playerid, 607.000, 424.000, "Engine ON/OFF");
    PlayerTextDrawLetterSize(playerid, Speedometer_Text[playerid][2], 0.160, 0.999);
    PlayerTextDrawTextSize(playerid, Speedometer_Text[playerid][2], 50.000, 58.000);
    PlayerTextDrawAlignment(playerid, Speedometer_Text[playerid][2], 2);
    PlayerTextDrawColor(playerid, Speedometer_Text[playerid][2], 255);
    PlayerTextDrawUseBox(playerid, Speedometer_Text[playerid][2], 1);
    PlayerTextDrawBoxColor(playerid, Speedometer_Text[playerid][2], -757935537);
    PlayerTextDrawSetShadow(playerid, Speedometer_Text[playerid][2], 0);
    PlayerTextDrawSetOutline(playerid, Speedometer_Text[playerid][2], 0);
    PlayerTextDrawBackgroundColor(playerid, Speedometer_Text[playerid][2], 255);
    PlayerTextDrawFont(playerid, Speedometer_Text[playerid][2], 1);
    PlayerTextDrawSetProportional(playerid, Speedometer_Text[playerid][2], 1);

    Speedometer_Text[playerid][3] = CreatePlayerTextDraw(playerid, 607.000, 436.000, "unlocked");
    PlayerTextDrawLetterSize(playerid, Speedometer_Text[playerid][3], 0.160, 0.999);
    PlayerTextDrawTextSize(playerid, Speedometer_Text[playerid][3], 50.000, 58.000);
    PlayerTextDrawAlignment(playerid, Speedometer_Text[playerid][3], 2);
    PlayerTextDrawColor(playerid, Speedometer_Text[playerid][3], 255);
    PlayerTextDrawUseBox(playerid, Speedometer_Text[playerid][3], 1);
    PlayerTextDrawBoxColor(playerid, Speedometer_Text[playerid][3], -757935537);
    PlayerTextDrawSetShadow(playerid, Speedometer_Text[playerid][3], 0);
    PlayerTextDrawSetOutline(playerid, Speedometer_Text[playerid][3], 0);
    PlayerTextDrawBackgroundColor(playerid, Speedometer_Text[playerid][3], 255);
    PlayerTextDrawFont(playerid, Speedometer_Text[playerid][3], 1);
    PlayerTextDrawSetProportional(playerid, Speedometer_Text[playerid][3], 1);

    g_SpeedometerShown[playerid] = false;
    g_SpeedometerLockShown[playerid] = false;
}

stock Speedometer_Destroy(playerid)
{
    for(new i = 0; i < 4; i++)
    {
        if(Speedometer_Text[playerid][i] != PlayerText:INVALID_TEXT_DRAW)
        {
            PlayerTextDrawDestroy(playerid, Speedometer_Text[playerid][i]);
            Speedometer_Text[playerid][i] = PlayerText:INVALID_TEXT_DRAW;
        }
    }
    g_SpeedometerShown[playerid] = false;
    g_SpeedometerLockShown[playerid] = false;
}

public Speedometer_Tick()
{
    for(new i = 0; i < MAX_PLAYERS; i++)
    {
        if(!IsPlayerConnected(i) || !PlayerData[i][pLogged]) continue;

        new vehid = GetPlayerVehicleID(i);
        if(vehid == 0)
        {
            if(g_SpeedometerShown[i])
            {
                PlayerTextDrawHide(i, Speedometer_Text[i][0]);
                PlayerTextDrawHide(i, Speedometer_Text[i][1]);
                PlayerTextDrawHide(i, Speedometer_Text[i][2]);
                PlayerTextDrawHide(i, Speedometer_Text[i][3]);
                g_SpeedometerShown[i] = false;
                g_SpeedometerLockShown[i] = false;
            }
            continue;
        }

        new Float:speed = GetPlayerVehicleSpeed(i);
        new Float:health;
        GetVehicleHealth(vehid, health);
        if(health > 1000.0) health = 1000.0;

        new engine, lights, alarm, doors, bonnet, boot, objective;
        GetVehicleParamsEx(vehid, engine, lights, alarm, doors, bonnet, boot, objective);

        new text[16];
        format(text, sizeof(text), "%d km/h", floatround(speed));
        PlayerTextDrawSetString(i, Speedometer_Text[i][0], text);

        format(text, sizeof(text), "%d hp", floatround(health));
        PlayerTextDrawSetString(i, Speedometer_Text[i][1], text);

        PlayerTextDrawSetString(i, Speedometer_Text[i][2], engine ? "engine ON" : "engine OFF");

        new bool:isPersonal = bool:(g_VehicleToPVIndex[vehid] != -1);
        if(isPersonal)
        {
            PlayerTextDrawSetString(i, Speedometer_Text[i][3], doors ? "locked" : "unlocked");
            if(!g_SpeedometerLockShown[i])
            {
                PlayerTextDrawShow(i, Speedometer_Text[i][3]);
                g_SpeedometerLockShown[i] = true;
            }
        }
        else if(g_SpeedometerLockShown[i])
        {
            PlayerTextDrawHide(i, Speedometer_Text[i][3]);
            g_SpeedometerLockShown[i] = false;
        }

        if(!g_SpeedometerShown[i])
        {
            PlayerTextDrawShow(i, Speedometer_Text[i][0]);
            PlayerTextDrawShow(i, Speedometer_Text[i][1]);
            PlayerTextDrawShow(i, Speedometer_Text[i][2]);
            g_SpeedometerShown[i] = true;
        }
    }
    return 1;
}

// ============================================================
//  CEAS SERVER (ora curenta, afisata global)
// ============================================================
#define SERVER_CLOCK_TICK 1000 // 1 secunda, in ms

new Text:ServerClock_Text[2];

forward ServerClock_Tick();

// Creeaza cele 2 textdraw-uri globale (ora + iconita), o singura data la pornirea gamemode-ului
stock ServerClock_Create()
{
    ServerClock_Text[0] = TextDrawCreate(565.000, 20.000, "23:59");
    TextDrawLetterSize(ServerClock_Text[0], 0.429, 2.799);
    TextDrawTextSize(ServerClock_Text[0], 93.000, -37.000);
    TextDrawAlignment(ServerClock_Text[0], 2);
    TextDrawColor(ServerClock_Text[0], 3014898670);
    TextDrawUseBox(ServerClock_Text[0], 1);
    TextDrawBoxColor(ServerClock_Text[0], -255);
    TextDrawSetShadow(ServerClock_Text[0], 0);
    TextDrawSetOutline(ServerClock_Text[0], -1);
    TextDrawBackgroundColor(ServerClock_Text[0], 1);
    TextDrawFont(ServerClock_Text[0], 1);
    TextDrawSetProportional(ServerClock_Text[0], 1);
}

// Arata ceasul unui singur player (folosit la conectare, pentru ca TextDrawShowForAll
// nu acopera playerii care se conecteaza dupa apel)
stock ServerClock_ShowToPlayer(playerid)
{
    TextDrawShowForPlayer(playerid, ServerClock_Text[0]);
    TextDrawShowForPlayer(playerid, ServerClock_Text[1]);
}

// Actualizeaza textul ceasului la fiecare secunda; jucatorii care il vad deja primesc update-ul live
public ServerClock_Tick()
{
    new hour, minute, second;
    gettime(hour, minute, second);

    new text[8];
    format(text, sizeof(text), "%02d:%02d", hour, minute);
    TextDrawSetString(ServerClock_Text[0], text);
    return 1;
}

// ============================================================
//  BACKGROUND LOGIN/REGISTER
// ============================================================
new PlayerText:LoginBG_Text[MAX_PLAYERS] = {PlayerText:INVALID_TEXT_DRAW, ...};

// Creeaza si arata fundalul de login/register pentru un player nou conectat
stock LoginBG_Show(playerid)
{
    LoginBG_Text[playerid] = CreatePlayerTextDraw(playerid, -6.000, -6.000, "LOAD0UK:load0uk");
    PlayerTextDrawTextSize(playerid, LoginBG_Text[playerid], 656.000, 464.000);
    PlayerTextDrawAlignment(playerid, LoginBG_Text[playerid], 1);
    PlayerTextDrawColor(playerid, LoginBG_Text[playerid], -1);
    PlayerTextDrawSetShadow(playerid, LoginBG_Text[playerid], 0);
    PlayerTextDrawSetOutline(playerid, LoginBG_Text[playerid], 0);
    PlayerTextDrawBackgroundColor(playerid, LoginBG_Text[playerid], 255);
    PlayerTextDrawFont(playerid, LoginBG_Text[playerid], 4);
    PlayerTextDrawSetProportional(playerid, LoginBG_Text[playerid], 1);
    PlayerTextDrawShow(playerid, LoginBG_Text[playerid]);
}

// Distruge fundalul de login/register dupa ce playerul s-a logat (register sau login), daca exista
stock LoginBG_Destroy(playerid)
{
    if(LoginBG_Text[playerid] != PlayerText:INVALID_TEXT_DRAW)
    {
        PlayerTextDrawDestroy(playerid, LoginBG_Text[playerid]);
        LoginBG_Text[playerid] = PlayerText:INVALID_TEXT_DRAW;
    }
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
    pvInsuranceExp, pvMedkitExp, pvExtinguisherExp, pvITPExp,
    bool:pvLocked
}
new PVehicleData[MAX_PERSONAL_VEHICLES][E_PVEHICLE_DATA];
new g_PVehicleVehicle[MAX_PERSONAL_VEHICLES];
new Text3D:g_PVehicleLabel[MAX_PERSONAL_VEHICLES];
new g_PVehicleCount = 0;

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

    if(PVehicleData[idx][pvLocked])
    {
        new engine, lights, alarm, doors, bonnet, boot, objective;
        GetVehicleParamsEx(vehid, engine, lights, alarm, doors, bonnet, boot, objective);
        SetVehicleParamsEx(vehid, engine, lights, alarm, 1, bonnet, boot, objective);
    }

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
    format(label, sizeof(label), "[ %s ]\n[ $%s ]\n[ /vbuy ]", vname, MoneyStr(PVehicleData[idx][pvPrice]));

    g_PVehicleLabel[idx] = Create3DTextLabel(label, COLOR_WHITE,
        PVehicleData[idx][pvLocX], PVehicleData[idx][pvLocY], PVehicleData[idx][pvLocZ] + 0.2, 10.0, 0, 0);

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

// Un document de vehicul (asigurare/kit medical/extinctor/ITP) e valabil pe toata
// durata zilei calendaristice in care expira - doar ziua urmatoare devine "Expired"
stock bool:VehicleDoc_IsValid(exp)
{
    new todayStart = gettime() - (gettime() % 86400);
    new expDayStart = exp - (exp % 86400);
    return (expDayStart >= todayStart);
}

// Formats an expiry timestamp (unix) as "Expired" or "X days"
stock VehicleDoc_Status(exp, out[], len)
{
    if(!VehicleDoc_IsValid(exp)) { format(out, len, "Expired"); return; }
    new diff = exp - gettime();
    if(diff < 0) diff = 0;
    format(out, len, "%d days", (diff / 86400) + 1);
}

// Porneste/opreste motorul vehiculului in care se afla playerid (trebuie sa fie soferul)
stock Vehicle_ToggleEngine(playerid)
{
    new vehid = GetPlayerVehicleID(playerid);
    if(vehid == 0 || GetPlayerVehicleSeat(playerid) != 0)
        return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be driving a vehicle to use this."), 0;

    new pvidx = g_VehicleToPVIndex[vehid];
    if(pvidx != -1 && PVehicleData[pvidx][pvOwnerId] == 0)
        return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"This vehicle has not been bought yet. Use "C_INFO"/vbuy"C_WHITE" to be able to start it."), 0;

    new engine, lights, alarm, doors, bonnet, boot, objective;
    GetVehicleParamsEx(vehid, engine, lights, alarm, doors, bonnet, boot, objective);
    engine = engine ? 0 : 1;
    SetVehicleParamsEx(vehid, engine, lights, alarm, doors, bonnet, boot, objective);

    return 1;
}

// Aprinde/stinge farurile vehiculului in care se afla playerid (trebuie sa fie soferul)
stock Vehicle_ToggleLights(playerid)
{
    new vehid = GetPlayerVehicleID(playerid);
    if(vehid == 0 || GetPlayerVehicleSeat(playerid) != 0)
        return 0;

    new engine, lights, alarm, doors, bonnet, boot, objective;
    GetVehicleParamsEx(vehid, engine, lights, alarm, doors, bonnet, boot, objective);
    lights = lights ? 0 : 1;
    SetVehicleParamsEx(vehid, engine, lights, alarm, doors, bonnet, boot, objective);

    return 1;
}

// Incuie/descuie usile vehiculului (folosit de masinile de examen la inceputul/sfarsitul examenului)
stock Vehicle_SetLocked(vehid, bool:locked)
{
    if(vehid == -1) return;
    new engine, lights, alarm, doors, bonnet, boot, objective;
    GetVehicleParamsEx(vehid, engine, lights, alarm, doors, bonnet, boot, objective);
    SetVehicleParamsEx(vehid, engine, lights, alarm, locked ? 1 : 0, bonnet, boot, objective);
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

// Cele 8 locatii intre care se alege random spawn-ul civil (pSpawn==1)
#define CIVIL_SPAWN_COUNT 8
new Float:CivilSpawnLocations[CIVIL_SPAWN_COUNT][4] = {
    {1362.4468, 788.8919, 10.8203, 288.7621}, // spawn1
    {1370.1937, 791.0197, 10.8203, 168.5368}, // spawn2
    {1389.8796, 790.6416, 10.8203, 111.1963}, // spawn3
    {1389.8354, 781.3478, 10.8203, 90.8294},  // spawn4
    {1392.5699, 746.9161, 10.8203, 190.8562}, // spawn5
    {1388.7506, 731.7965, 10.8203, 44.4323},  // spawn6
    {1364.1913, 728.9312, 10.8203, 11.2420},  // spawn7
    {1366.0541, 750.7808, 10.8203, 263.0685}  // spawn8
};

// Recalculeaza si cacheaza pSpawnX/Y/Z in functie de pSpawn, ca sa nu se mai interogheze
// FactionData/HouseData la fiecare spawn. Cade pe civil daca tipul selectat nu e disponibil.
stock Player_RecalcSpawn(playerid)
{
    new type = PlayerData[playerid][pSpawn];

    if(type == CARAVAN_CAMP_SPAWN_TYPE)
    {
        new cidx = Caravan_FindByOwner(PlayerData[playerid][pID]);
        if(cidx != -1 && (CaravanData[cidx][rCampLocX] != 0.0 || CaravanData[cidx][rCampLocY] != 0.0 || CaravanData[cidx][rCampLocZ] != 0.0))
        {
            PlayerData[playerid][pSpawnX] = CaravanData[cidx][rCampLocX];
            PlayerData[playerid][pSpawnY] = CaravanData[cidx][rCampLocY];
            PlayerData[playerid][pSpawnZ] = CaravanData[cidx][rCampLocZ] + 4.0;
            return;
        }
        type = 1;
    }

    if(type == 2)
    {
        new fid = PlayerData[playerid][pFaction];
        if(fid >= 1 && fid <= MAX_FACTIONS)
        {
            // Prefera locatia interiorului (daca e setata), altfel cade pe HQ-ul exterior
            if(FactionData[fid][fInteriorX] != 0.0 || FactionData[fid][fInteriorY] != 0.0)
            {
                PlayerData[playerid][pSpawnX] = FactionData[fid][fInteriorX];
                PlayerData[playerid][pSpawnY] = FactionData[fid][fInteriorY];
                PlayerData[playerid][pSpawnZ] = FactionData[fid][fInteriorZ];
                return;
            }
            if(FactionData[fid][fHQX] != 0.0 || FactionData[fid][fHQY] != 0.0)
            {
                PlayerData[playerid][pSpawnX] = FactionData[fid][fHQX];
                PlayerData[playerid][pSpawnY] = FactionData[fid][fHQY];
                PlayerData[playerid][pSpawnZ] = FactionData[fid][fHQZ];
                return;
            }
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

    // Civil (implicit) - random intre cele 8 locatii
    new civIdx = random(CIVIL_SPAWN_COUNT);
    PlayerData[playerid][pSpawnX] = CivilSpawnLocations[civIdx][0];
    PlayerData[playerid][pSpawnY] = CivilSpawnLocations[civIdx][1];
    PlayerData[playerid][pSpawnZ] = CivilSpawnLocations[civIdx][2];
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
        `driving_lic_d_exp` DATE DEFAULT NULL,\
        `diseased`         TINYINT DEFAULT 0,\
        `disease_paydays`  INT     DEFAULT 0,\
        `caravan_key`      INT     DEFAULT 0,\
        `is_president`     TINYINT DEFAULT 0,\
        `voted`            TINYINT DEFAULT 0,\
        `was_president`    TINYINT DEFAULT 0\
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
    mysql_tquery(g_SQL, "ALTER TABLE `players` ADD COLUMN `diseased`        TINYINT DEFAULT 0", "", "", 0);
    mysql_tquery(g_SQL, "ALTER TABLE `players` ADD COLUMN `disease_paydays` INT     DEFAULT 0", "", "", 0);
    mysql_tquery(g_SQL, "ALTER TABLE `players` ADD COLUMN `caravan_key`      INT   DEFAULT 0",   "", "", 0);
    mysql_tquery(g_SQL, "ALTER TABLE `players` ADD COLUMN `is_president`  TINYINT DEFAULT 0", "", "", 0);
    mysql_tquery(g_SQL, "ALTER TABLE `players` ADD COLUMN `voted`         TINYINT DEFAULT 0", "", "", 0);
    mysql_tquery(g_SQL, "ALTER TABLE `players` ADD COLUMN `was_president` TINYINT DEFAULT 0", "", "", 0);

    mysql_tquery(g_SQL,
        "CREATE TABLE IF NOT EXISTS `rulote_personale` (\
        `rID`               INT AUTO_INCREMENT PRIMARY KEY,\
        `rOwned`            TINYINT DEFAULT 0,\
        `rOwner`            INT     DEFAULT 0,\
        `rType`             INT     DEFAULT 1,\
        `rPrice`            INT     DEFAULT 0,\
        `rCamping`          TINYINT  DEFAULT 0,\
        `rCampingStartDate` DATETIME DEFAULT NULL,\
        `rParkLocX`         FLOAT   DEFAULT 0.0,\
        `rParkLocY`         FLOAT   DEFAULT 0.0,\
        `rParkLocZ`         FLOAT   DEFAULT 0.0,\
        `rCampLocX`         FLOAT   DEFAULT 0.0,\
        `rCampLocY`         FLOAT   DEFAULT 0.0,\
        `rCampLocZ`         FLOAT   DEFAULT 0.0,\
        `parkRX`            FLOAT   DEFAULT 0.0,\
        `parkRY`            FLOAT   DEFAULT 0.0,\
        `parkRZ`            FLOAT   DEFAULT 0.0,\
        `campRX`            FLOAT   DEFAULT 0.0,\
        `campRY`            FLOAT   DEFAULT 0.0,\
        `campRZ`            FLOAT   DEFAULT 0.0\
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;",
        "", "", 0);
    mysql_tquery(g_SQL, "ALTER TABLE `rulote_personale` ADD COLUMN `parkRX` FLOAT DEFAULT 0.0", "", "", 0);
    mysql_tquery(g_SQL, "ALTER TABLE `rulote_personale` ADD COLUMN `parkRY` FLOAT DEFAULT 0.0", "", "", 0);
    mysql_tquery(g_SQL, "ALTER TABLE `rulote_personale` ADD COLUMN `parkRZ` FLOAT DEFAULT 0.0", "", "", 0);
    mysql_tquery(g_SQL, "ALTER TABLE `rulote_personale` ADD COLUMN `campRX` FLOAT DEFAULT 0.0", "", "", 0);
    mysql_tquery(g_SQL, "ALTER TABLE `rulote_personale` ADD COLUMN `campRY` FLOAT DEFAULT 0.0", "", "", 0);
    mysql_tquery(g_SQL, "ALTER TABLE `rulote_personale` ADD COLUMN `campRZ` FLOAT DEFAULT 0.0", "", "", 0);
    mysql_tquery(g_SQL, "ALTER TABLE `rulote_personale` MODIFY `rCampingStartDate` DATETIME DEFAULT NULL", "", "", 0);
    mysql_tquery(g_SQL, "ALTER TABLE `rulote_personale` ADD COLUMN `rType` INT DEFAULT 1", "", "", 0);
    // backfill o singura data pentru randurile vechi (dinainte sa existe coloana rType), din players.caravan_key
    mysql_tquery(g_SQL,
        "UPDATE `rulote_personale` r JOIN `players` p ON p.id = r.rOwner SET r.rType = p.caravan_key WHERE p.caravan_key > 0",
        "", "", 0);
    print("[DB] Tabel `rulote_personale` verificat/creat.");

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
        `hq_z`       FLOAT DEFAULT 0.0,\
        `interior_x` FLOAT DEFAULT 0.0,\
        `interior_y` FLOAT DEFAULT 0.0,\
        `interior_z` FLOAT DEFAULT 0.0,\
        `interior`   INT DEFAULT 0,\
        `vw`         INT DEFAULT 0\
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;",
        "", "", 0);

    mysql_tquery(g_SQL, "ALTER TABLE `factions` ADD COLUMN `pickup_id`  INT   DEFAULT -1",  "", "", 0);
    mysql_tquery(g_SQL, "ALTER TABLE `factions` ADD COLUMN `mapicon_id` INT   DEFAULT -1",  "", "", 0);
    mysql_tquery(g_SQL, "ALTER TABLE `factions` ADD COLUMN `hq_x`       FLOAT DEFAULT 0.0", "", "", 0);
    mysql_tquery(g_SQL, "ALTER TABLE `factions` ADD COLUMN `hq_y`       FLOAT DEFAULT 0.0", "", "", 0);
    mysql_tquery(g_SQL, "ALTER TABLE `factions` ADD COLUMN `hq_z`       FLOAT DEFAULT 0.0", "", "", 0);
    mysql_tquery(g_SQL, "ALTER TABLE `factions` ADD COLUMN `interior_x` FLOAT DEFAULT 0.0", "", "", 0);
    mysql_tquery(g_SQL, "ALTER TABLE `factions` ADD COLUMN `interior_y` FLOAT DEFAULT 0.0", "", "", 0);
    mysql_tquery(g_SQL, "ALTER TABLE `factions` ADD COLUMN `interior_z` FLOAT DEFAULT 0.0", "", "", 0);
    mysql_tquery(g_SQL, "ALTER TABLE `factions` ADD COLUMN `interior`   INT   DEFAULT 0",   "", "", 0);
    mysql_tquery(g_SQL, "ALTER TABLE `factions` ADD COLUMN `vw`         INT   DEFAULT 0",   "", "", 0);

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
        `exam_b_price`      INT   DEFAULT 300,\
        `exam_c_price`      INT   DEFAULT 500,\
        `exam_d_price`      INT   DEFAULT 400,\
        `pizza_price`       INT   DEFAULT 50,\
        `burger_price`      INT   DEFAULT 55\
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
    mysql_tquery(g_SQL, "ALTER TABLE `payday_setup` ADD COLUMN `exam_c_price`       INT DEFAULT 500", "", "", 0);
    mysql_tquery(g_SQL, "ALTER TABLE `payday_setup` ADD COLUMN `exam_d_price`       INT DEFAULT 400", "", "", 0);
    mysql_tquery(g_SQL, "ALTER TABLE `payday_setup` ADD COLUMN `pizza_price`        INT DEFAULT 50",  "", "", 0);
    mysql_tquery(g_SQL, "ALTER TABLE `payday_setup` ADD COLUMN `burger_price`       INT DEFAULT 55",  "", "", 0);

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
        `loc_z`    FLOAT DEFAULT 0.0,\
        `type`     INT DEFAULT 1,\
        `max_pets` INT DEFAULT 0,\
        `pets`     INT DEFAULT 0\
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;",
        "", "", 0);

    mysql_tquery(g_SQL, "ALTER TABLE `houses` ADD COLUMN `owner_id` INT DEFAULT 0",    "", "", 0);
    mysql_tquery(g_SQL, "ALTER TABLE `houses` ADD COLUMN `price`    INT DEFAULT 50000", "", "", 0);
    mysql_tquery(g_SQL, "ALTER TABLE `houses` ADD COLUMN `type`     INT DEFAULT 1",     "", "", 0); // 1=casa, 2=apartament, 3=other
    mysql_tquery(g_SQL, "ALTER TABLE `houses` ADD COLUMN `max_pets` INT DEFAULT 0",     "", "", 0);
    mysql_tquery(g_SQL, "ALTER TABLE `houses` ADD COLUMN `pets`     INT DEFAULT 0",     "", "", 0);

    mysql_tquery(g_SQL,
        "CREATE TABLE IF NOT EXISTS `animals` (\
        `aID`       INT AUTO_INCREMENT PRIMARY KEY,\
        `aType`     INT DEFAULT 0,\
        `aPlayerID` INT DEFAULT 0,\
        `aHouseID`  INT DEFAULT 0,\
        `aName`     VARCHAR(32) NOT NULL DEFAULT 'Animal'\
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;",
        "", "", 0);

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
        `itp_exp`          DATE DEFAULT NULL,\
        `locked`           TINYINT DEFAULT 0\
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;",
        "", "", 0);

    mysql_tquery(g_SQL, "ALTER TABLE `vehicles_personal` MODIFY `plate` VARCHAR(16) DEFAULT NULL", "", "", 0);
    mysql_tquery(g_SQL, "ALTER TABLE `vehicles_personal` ADD UNIQUE `plate_unique` (`plate`)", "", "", 0);
    mysql_tquery(g_SQL, "ALTER TABLE `vehicles_personal` ADD COLUMN `itp_exp` DATE DEFAULT NULL", "", "", 0);
    mysql_tquery(g_SQL, "ALTER TABLE `vehicles_personal` MODIFY `insurance_exp`    DATE DEFAULT NULL", "", "", 0);
    mysql_tquery(g_SQL, "ALTER TABLE `vehicles_personal` MODIFY `medkit_exp`       DATE DEFAULT NULL", "", "", 0);
    mysql_tquery(g_SQL, "ALTER TABLE `vehicles_personal` MODIFY `extinguisher_exp` DATE DEFAULT NULL", "", "", 0);
    mysql_tquery(g_SQL, "ALTER TABLE `vehicles_personal` MODIFY `itp_exp`          DATE DEFAULT NULL", "", "", 0);
    mysql_tquery(g_SQL, "ALTER TABLE `vehicles_personal` ADD COLUMN `locked`       TINYINT DEFAULT 0", "", "", 0);

    mysql_tquery(g_SQL,
        "CREATE TABLE IF NOT EXISTS `president_votes` (\
        `vID`        INT AUTO_INCREMENT PRIMARY KEY,\
        `vVotant`    VARCHAR(24) NOT NULL DEFAULT '',\
        `vVotantId`  INT DEFAULT 0,\
        `vVotatPe`   VARCHAR(24) NOT NULL DEFAULT '',\
        `vVotatPeId` INT DEFAULT 0\
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;",
        "", "", 0);

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
        `label_z`    FLOAT DEFAULT 15.0,\
        UNIQUE KEY `uq_turf_name` (`name`)\
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;",
        "", "", 0);

    mysql_tquery(g_SQL, "ALTER TABLE `turfs` MODIFY `color` VARCHAR(8) DEFAULT '000000FF'", "", "", 0);
    mysql_tquery(g_SQL, "ALTER TABLE `turfs` ADD COLUMN `label_z` FLOAT DEFAULT 15.0", "", "", 0); // <-- ajusteaza per-turf daca eticheta #ID apare ingropata/plutind

    // mysql_tquery(g_SQL,
    //     "INSERT IGNORE INTO `turfs` (`faction_id`,`name`,`x1`,`y1`,`x2`,`y2`,`attackable`,`color`) VALUES \
    //     (4,'HQ {Factiune 4}',-304.0,2583.5,-168.0,2762.5,0,'3366CC88'),\
    //     (5,'HQ {Factiune 5}',-1563.0,2546.5,-1387.0,2687.5,0,'AA44AA88'),\
    //     (6,'HQ {Factiune 6}',-845.0,1416.5,-748.0,1608.5,0,'44AA4488'),\
    //     (7,'HQ {Factiune 7}',30.0,1046.5,130.0,1146.5,0,'FFCC0088');",
    //     "", "", 0);

    // mysql_tquery(g_SQL, "UPDATE `turfs` SET `faction_id`=4,`color`='3366CC88' WHERE `name`='HQ {Factiune 4}'", "", "", 0);
    // mysql_tquery(g_SQL, "UPDATE `turfs` SET `faction_id`=5,`color`='AA44AA88' WHERE `name`='HQ {Factiune 5}'", "", "", 0);
    // mysql_tquery(g_SQL, "UPDATE `turfs` SET `faction_id`=6,`color`='44AA4488' WHERE `name`='HQ {Factiune 6}'", "", "", 0);
    // mysql_tquery(g_SQL, "UPDATE `turfs` SET `faction_id`=7,`color`='FFCC0088' WHERE `name`='HQ {Factiune 7}'", "", "", 0);

    // 8 turfuri noi atacabile, faction_id distribuit 4/5/6/7, culoarea = culoarea factiunii respective.
    // `name` e UNIQUE NOT NULL si trebuie cunoscut ID-ul (AUTO_INCREMENT) inainte sa-l folosim ca nume, deci
    // inseram cu un nume temporar unic, apoi il redenumim cu id-ul real alocat de DB. Idempotenta NU se poate
    // baza pe INSERT IGNORE + numele temporar (dupa redenumire, numele temporar e liber din nou si s-ar
    // reinsera la fiecare restart) - verificam in schimb pe coordonate (x1,y1), care raman fixe.
    mysql_tquery(g_SQL,
        "INSERT INTO `turfs` (`faction_id`,`name`,`x1`,`y1`,`x2`,`y2`,`attackable`,`color`) \
         SELECT 4,'TurfSeed_1',-1129,2241.171875,-1037,2359.171875,1,'3366CC88' \
         WHERE NOT EXISTS (SELECT 1 FROM `turfs` WHERE `x1`=-1129 AND `y1`=2241.171875)",
        "", "", 0);
    mysql_tquery(g_SQL,
        "INSERT INTO `turfs` (`faction_id`,`name`,`x1`,`y1`,`x2`,`y2`,`attackable`,`color`) \
         SELECT 5,'TurfSeed_2',-829,2369.5,-749,2465.5,1,'AA44AA88' \
         WHERE NOT EXISTS (SELECT 1 FROM `turfs` WHERE `x1`=-829 AND `y1`=2369.5)",
        "", "", 0);
    mysql_tquery(g_SQL,
        "INSERT INTO `turfs` (`faction_id`,`name`,`x1`,`y1`,`x2`,`y2`,`attackable`,`color`) \
         SELECT 6,'TurfSeed_3',-460,2196.1000061035156,-345,2271.1000061035156,1,'44AA4488' \
         WHERE NOT EXISTS (SELECT 1 FROM `turfs` WHERE `x1`=-460 AND `y1`=2196.1000061035156)",
        "", "", 0);
    mysql_tquery(g_SQL,
        "INSERT INTO `turfs` (`faction_id`,`name`,`x1`,`y1`,`x2`,`y2`,`attackable`,`color`) \
         SELECT 7,'TurfSeed_4',85.0001220703125,2386.0999908447266,224.0001220703125,2468.0999908447266,1,'FFCC0088' \
         WHERE NOT EXISTS (SELECT 1 FROM `turfs` WHERE `x1`=85.0001220703125 AND `y1`=2386.0999908447266)",
        "", "", 0);
    mysql_tquery(g_SQL,
        "INSERT INTO `turfs` (`faction_id`,`name`,`x1`,`y1`,`x2`,`y2`,`attackable`,`color`) \
         SELECT 4,'TurfSeed_5',224.0001220703125,2386.0999908447266,372.0001220703125,2468.0999908447266,1,'3366CC88' \
         WHERE NOT EXISTS (SELECT 1 FROM `turfs` WHERE `x1`=224.0001220703125 AND `y1`=2386.0999908447266)",
        "", "", 0);
    mysql_tquery(g_SQL,
        "INSERT INTO `turfs` (`faction_id`,`name`,`x1`,`y1`,`x2`,`y2`,`attackable`,`color`) \
         SELECT 5,'TurfSeed_6',261.64306640625,2560.785701751709,347.64306640625,2666.785701751709,1,'AA44AA88' \
         WHERE NOT EXISTS (SELECT 1 FROM `turfs` WHERE `x1`=261.64306640625 AND `y1`=2560.785701751709)",
        "", "", 0);
    mysql_tquery(g_SQL,
        "INSERT INTO `turfs` (`faction_id`,`name`,`x1`,`y1`,`x2`,`y2`,`attackable`,`color`) \
         SELECT 6,'TurfSeed_7',189.640625,2560.7890625,262.640625,2666.7890625,1,'44AA4488' \
         WHERE NOT EXISTS (SELECT 1 FROM `turfs` WHERE `x1`=189.640625 AND `y1`=2560.7890625)",
        "", "", 0);
    mysql_tquery(g_SQL,
        "INSERT INTO `turfs` (`faction_id`,`name`,`x1`,`y1`,`x2`,`y2`,`attackable`,`color`) \
         SELECT 7,'TurfSeed_8',967.9307861328125,959.3505554199219,1170.9307861328125,1163.3505554199219,1,'FFCC0088' \
         WHERE NOT EXISTS (SELECT 1 FROM `turfs` WHERE `x1`=967.9307861328125 AND `y1`=959.3505554199219)",
        "", "", 0);

    mysql_tquery(g_SQL, "UPDATE `turfs` SET `name` = CONVERT(`id`, CHAR) WHERE `name` LIKE 'TurfSeed\\_%'", "", "", 0);

    // Migrare: redenumeste tabelele vechi daca exista (pastreaza datele); nu face nimic daca tabela noua
    // exista deja sau daca cea veche nu a existat niciodata (eroarea e doar logata, nu opreste serverul)
    mysql_tquery(g_SQL, "RENAME TABLE `locations` TO `locations_admin`", "", "", 0);
    mysql_tquery(g_SQL, "RENAME TABLE `gps_locations` TO `locations_gps`", "", "", 0);

    mysql_tquery(g_SQL,
        "CREATE TABLE IF NOT EXISTS `locations_admin` (\
        `locID`   INT AUTO_INCREMENT PRIMARY KEY,\
        `locName` VARCHAR(32) NOT NULL DEFAULT '',\
        `locX`    FLOAT DEFAULT 0.0,\
        `locY`    FLOAT DEFAULT 0.0,\
        `locZ`    FLOAT DEFAULT 0.0,\
        UNIQUE KEY `uq_location_name` (`locName`)\
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;",
        "", "", 0);

    mysql_tquery(g_SQL,
        "DELETE l1 FROM `locations_admin` l1 INNER JOIN `locations_admin` l2 \
         WHERE l1.locID > l2.locID AND l1.locName = l2.locName",
        "", "", 0);
    mysql_tquery(g_SQL, "ALTER TABLE `locations_admin` ADD UNIQUE `uq_location_name` (`locName`)", "", "", 0);

    mysql_tquery(g_SQL,
        "INSERT IGNORE INTO `locations_admin` (`locName`,`locX`,`locY`,`locZ`) VALUES \
        ('examA', -13.0385, 2346.3943, 24.1406),\
        ('examB', 2236.2078, 1285.5682, 10.8203),\
        ('examC', 1375.2307, 1019.8265, 10.8203),\
        ('examD', 1896.1573, 2586.3149, 11.0234),\
        ('vplate', 930.0, 2074.0, 12.5),\
        ('vitp', 930.0, 2067.0, 12.5),\
        ('hospital', 1582.5594, 1769.1219, 10.8203);",
        "", "", 0);

    mysql_tquery(g_SQL,
        "CREATE TABLE IF NOT EXISTS `locations_gps` (\
        `glID`           INT AUTO_INCREMENT PRIMARY KEY,\
        `glCategory`     VARCHAR(32) NOT NULL DEFAULT '',\
        `glCategoryName` VARCHAR(32) NOT NULL DEFAULT '',\
        `glName`         VARCHAR(32) NOT NULL DEFAULT '',\
        `glLocX`         FLOAT DEFAULT 0.0,\
        `glLocY`         FLOAT DEFAULT 0.0,\
        `glLocZ`         FLOAT DEFAULT 0.0,\
        UNIQUE KEY `uq_gps_name` (`glName`)\
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;",
        "", "", 0);

    mysql_tquery(g_SQL, "ALTER TABLE `locations_gps` ADD COLUMN `glCategoryName` VARCHAR(32) NOT NULL DEFAULT ''", "", "", 0);

    // Completeaza numele categoriei pentru randurile existente, pe baza vechii valori glCategory
    mysql_tquery(g_SQL, "UPDATE `locations_gps` SET `glCategoryName`='DMV Locations' WHERE `glCategory` IN ('1','DMV')", "", "", 0);
    mysql_tquery(g_SQL, "UPDATE `locations_gps` SET `glCategoryName`='FACTIONS' WHERE `glCategory` IN ('2','FACTIONS')", "", "", 0);
    mysql_tquery(g_SQL, "UPDATE `locations_gps` SET `glCategoryName`='BUSINESS' WHERE `glCategory` IN ('3','BUSINESS')", "", "", 0);
    mysql_tquery(g_SQL, "UPDATE `locations_gps` SET `glCategoryName`='Others' WHERE `glCategory` IN ('4','OTHERS')", "", "", 0);

    mysql_tquery(g_SQL,
        "INSERT IGNORE INTO `locations_gps` (`glCategory`,`glCategoryName`,`glName`,`glLocX`,`glLocY`,`glLocZ`) VALUES \
        ('4', 'Others', 'Hospitalization', 1582.5594, 1769.1219, 10.8203),\
        ('5', 'Shops', 'Medical Shop 1', 1536.3281, 1044.9326, 10.8203),\
        ('5', 'Shops', 'Medical Shop 2', 2194.0332, 1990.9806, 12.2969),\
        ('5', 'Shops', 'Medical Shop 3', 1920.2715, 2447.3835, 11.1782),\
        ('5', 'Shops', 'Medical Shop 4', 1378.2955, 2355.3503, 10.8203),\
        ('5', 'Shops', 'Medical Shop 5', 662.2972, 1717.1869, 7.1875),\
        ('5', 'Shops', 'Medical Shop 6', -87.7910, 1378.0410, 10.2734),\
        ('5', 'Shops', 'Pizza 1', 2393.1387, 2042.6146, 10.8203),\
        ('5', 'Shops', 'Pizza 2', 2638.1370, 1849.6857, 11.0234),\
        ('5', 'Shops', 'Pizza 3', 173.1981, 1176.2303, 14.7645),\
        ('5', 'Shops', 'Burger 1', 2163.9583, 2795.4819, 10.8203),\
        ('5', 'Shops', 'Burger 2', 2366.2407, 2071.1733, 10.8203),\
        ('5', 'Shops', 'Burger 3', 2478.7034, 2034.2334, 11.0625),\
        ('5', 'Shops', 'Burger 4', 1158.2510, 2072.0894, 11.0625),\
        ('5', 'Shops', 'Burger 5', 1873.1813, 2071.5874, 11.0625);",
        "", "", 0);

    mysql_tquery(g_SQL,
        "CREATE TABLE IF NOT EXISTS `basket_hoops` (\
        `id` INT PRIMARY KEY,\
        `x`  FLOAT DEFAULT 0.0,\
        `y`  FLOAT DEFAULT 0.0,\
        `z`  FLOAT DEFAULT 0.0\
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;",
        "", "", 0);

    mysql_tquery(g_SQL,
        "INSERT IGNORE INTO `basket_hoops` (`id`,`x`,`y`,`z`) VALUES \
        (1, 2480.35010, 1297.50000, 12.86000),\
        (2, 2480.13013, 1286.42004, 12.86000),\
        (3, 2514.89990, 1297.55005, 12.86000),\
        (4, 2514.69995, 1286.50000, 12.86000),\
        (5, 2514.89990, 1277.55005, 12.86000),\
        (6, 2514.69849, 1266.48950, 12.86000),\
        (7, 2480.10010, 1266.43506, 12.86000),\
        (8, 2480.28003, 1277.49500, 12.86000);",
        "", "", 0);

    mysql_tquery(g_SQL,
        "CREATE TABLE IF NOT EXISTS `basket_spawns` (\
        `id`       INT AUTO_INCREMENT PRIMARY KEY,\
        `hoop_id`  INT NOT NULL,\
        `spawn_id` INT NOT NULL,\
        `x`        FLOAT DEFAULT 0.0,\
        `y`        FLOAT DEFAULT 0.0,\
        `z`        FLOAT DEFAULT 0.0,\
        `rx`       FLOAT DEFAULT 0.0,\
        `ry`       FLOAT DEFAULT 0.0,\
        `rz`       FLOAT DEFAULT 0.0,\
        UNIQUE KEY `uq_hoop_spawn` (`hoop_id`,`spawn_id`)\
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;",
        "", "", 0);

    mysql_tquery(g_SQL, "ALTER TABLE `basket_spawns` ADD COLUMN `rx` FLOAT DEFAULT 0.0", "", "", 0);
    mysql_tquery(g_SQL, "ALTER TABLE `basket_spawns` ADD COLUMN `ry` FLOAT DEFAULT 0.0", "", "", 0);
    mysql_tquery(g_SQL, "ALTER TABLE `basket_spawns` ADD COLUMN `rz` FLOAT DEFAULT 0.0", "", "", 0);

    print("[DB] Tabele factiuni si payday verificate/create.");
}

// ============================================================
//  INCARCARE FACTIUNI
// ============================================================
stock Factions_Load()
{
    print("[Factions] Se incarca factiunile din baza de date...");
    mysql_tquery(g_SQL,
        "SELECT `id`,`name`,`members`,`lead`,`bank`,`pickup_id`,`mapicon_id`,`hq_x`,`hq_y`,`hq_z`,\
         `interior_x`,`interior_y`,`interior_z`,`interior`,`vw` \
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
        cache_get_value_name_float(i, "interior_x", FactionData[fid][fInteriorX]);
        cache_get_value_name_float(i, "interior_y", FactionData[fid][fInteriorY]);
        cache_get_value_name_float(i, "interior_z", FactionData[fid][fInteriorZ]);
        cache_get_value_name_int  (i, "interior",   FactionData[fid][fInterior]);
        cache_get_value_name_int  (i, "vw",         FactionData[fid][fvw]);

        Factions_RecreatePickup(fid);
        Factions_RecreateLabel(fid);
        Factions_RecreateInteriorPickup(fid);
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
        "SELECT `id`,`name`,`owner`,`owner_id`,`owned`,`price`,`type`,`max_pets`,`pets`,`loc_x`,`loc_y`,`loc_z` FROM `houses` ORDER BY `id` ASC",
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
        cache_get_value_name_int  (i, "type",     HouseData[idx][hType]);
        cache_get_value_name_int  (i, "max_pets", HouseData[idx][hMaxPets]);
        cache_get_value_name_int  (i, "pets",     HouseData[idx][hPets]);
        cache_get_value_name_float(i, "loc_x", HouseData[idx][hLocX]);
        cache_get_value_name_float(i, "loc_y", HouseData[idx][hLocY]);
        cache_get_value_name_float(i, "loc_z", HouseData[idx][hLocZ]);
        g_HousePickup[idx] = -1;
        Houses_RecreatePickup(idx);
        g_HouseCount++;
    }
    printf("[Houses] %d case incarcate.", g_HouseCount);

    // Animalele depind de case (Houses_FindByID), deci le incarcam dupa ce casele sunt gata
    Animals_Load();
    return 1;
}

// ============================================================
//  INCARCARE ANIMALE
// ============================================================
stock Animals_Load()
{
    mysql_tquery(g_SQL,
        "SELECT `aID`,`aType`,`aPlayerID`,`aHouseID`,`aName` FROM `animals` ORDER BY `aID` ASC",
        "OnAnimalsLoaded");
}

public OnAnimalsLoaded()
{
    Animals_DestroyAll(); // curata actorii existenti (relevant la respawn-ul de payday)

    new rows = cache_num_rows();
    for(new i = 0; i < rows && g_AnimalCount < MAX_ANIMALS; i++)
    {
        new idx = g_AnimalCount;
        cache_get_value_name_int(i, "aID",       AnimalData[idx][aID]);
        cache_get_value_name_int(i, "aType",     AnimalData[idx][aType]);
        cache_get_value_name_int(i, "aPlayerID", AnimalData[idx][aPlayerID]);
        cache_get_value_name_int(i, "aHouseID",  AnimalData[idx][aHouseID]);
        cache_get_value_name    (i, "aName",     AnimalData[idx][aName], 32);
        g_AnimalObject[idx] = STREAMER_TAG_OBJECT:INVALID_STREAMER_ID;
        Animals_Spawn(idx);
        g_AnimalCount++;
    }
    printf("[Animals] %d animale incarcate.", g_AnimalCount);
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

stock Locations_Load()
{
    mysql_tquery(g_SQL,
        "SELECT `locID`,`locName`,`locX`,`locY`,`locZ` FROM `locations_admin` ORDER BY `locID` ASC",
        "OnLocationsLoaded");
}

public OnLocationsLoaded()
{
    new rows = cache_num_rows();
    g_LocationCount = 0;
    for(new i = 0; i < rows && g_LocationCount < MAX_LOCATIONS; i++)
    {
        new idx = g_LocationCount;
        cache_get_value_name_int  (i, "locID",   LocationData[idx][locID]);
        cache_get_value_name      (i, "locName", LocationData[idx][locName], 32);
        cache_get_value_name_float(i, "locX", LocationData[idx][locX]);
        cache_get_value_name_float(i, "locY", LocationData[idx][locY]);
        cache_get_value_name_float(i, "locZ", LocationData[idx][locZ]);
        g_LocationCount++;
    }
    printf("[Locations] %d locatii incarcate.", g_LocationCount);
    return 1;
}

stock GPS_Load()
{
    mysql_tquery(g_SQL,
        "SELECT `glID`,`glCategory`,`glName`,`glLocX`,`glLocY`,`glLocZ` FROM `locations_gps` ORDER BY `glID` ASC",
        "OnGPSLoaded");
}

public OnGPSLoaded()
{
    new rows = cache_num_rows();
    g_GPSCount = 0;
    for(new i = 0; i < rows && g_GPSCount < MAX_GPS_LOCATIONS; i++)
    {
        new idx = g_GPSCount;
        cache_get_value_name_int  (i, "glID",       GPSData[idx][glID]);
        cache_get_value_name      (i, "glCategory", GPSData[idx][glCategory], 32);
        cache_get_value_name      (i, "glName",     GPSData[idx][glName], 32);
        cache_get_value_name_float(i, "glLocX", GPSData[idx][glLocX]);
        cache_get_value_name_float(i, "glLocY", GPSData[idx][glLocY]);
        cache_get_value_name_float(i, "glLocZ", GPSData[idx][glLocZ]);
        g_GPSCount++;
    }
    printf("[GPS] %d locatii incarcate.", g_GPSCount);
    BBall_FindLobby();
    return 1;
}

public OnBusinessCreated(playerid, idx)
{
    if(!IsPlayerConnected(playerid)) return 0;
    BusinessData[idx][bID] = cache_insert_id();
    Businesses_RecreatePickup(idx);
    Businesses_UpdatePlayersIcons();
    new msg[128];
    format(msg, sizeof(msg), C_SUCCESS"Success: "C_WHITE"Business created (ID: "C_INFO"%d"C_WHITE", Price: "C_INFO"$%s"C_WHITE").",
        BusinessData[idx][bID], MoneyStr(BusinessData[idx][bPrice]));
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
         `insurance_exp`,`medkit_exp`,`extinguisher_exp`,`itp_exp`,`locked` FROM `vehicles_personal` ORDER BY `id` ASC",
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
        new lockedInt;
        cache_get_value_name_int(i, "locked", lockedInt);
        PVehicleData[idx][pvLocked] = bool:lockedInt;
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
        C_SUCCESS"Success: "C_WHITE"The "C_INFO"%s"C_WHITE" has been created and put up for sale for "C_INFO"$%s"C_WHITE".",
        vname, MoneyStr(PVehicleData[idx][pvPrice]));
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
        && VehicleDoc_IsValid(PVehicleData[pvidx][pvInsuranceExp])
        && VehicleDoc_IsValid(PVehicleData[pvidx][pvMedkitExp])
        && VehicleDoc_IsValid(PVehicleData[pvidx][pvExtinguisherExp]);

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
        "SELECT `min_salary`,`tax`,`cass`,`bank_interest`,`insurance_price`,`medkit_price`,`extinguisher_price`,`itp_price`,`plate_price`,`rent_bike_price`,`rent_car_desert_price`,`exam_a_price`,`exam_b_price`,`exam_c_price`,`exam_d_price`,`pizza_price`,`burger_price` \
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
        cache_get_value_name_int  (0, "exam_c_price",       g_ExamCPrice);
        cache_get_value_name_int  (0, "exam_d_price",       g_ExamDPrice);
        cache_get_value_name_int  (0, "pizza_price",        g_PizzaPrice);
        cache_get_value_name_int  (0, "burger_price",       g_BurgerPrice);
    }
    printf("[PayDay] Setari: Salar minim $%d | Impozit %d%% | CASS %d%% | Dobanda %.2f%%",
        g_PDMinSalary, g_PDTax, g_PDCASS, g_PDInterest);
    printf("[VehiculePersonale] Asigurare $%d | Kit medical $%d | Extinctor $%d | ITP $%d | Numar inmatriculare $%d | Bicicleta $%d | RentCarDMVDesert $%d | Examen A $%d | Examen B $%d | Examen C $%d | Examen D $%d | Pizza $%d | Burger $%d",
        g_InsurancePrice, g_MedkitPrice, g_ExtinguisherPrice, g_ITPPrice, g_PlatePrice, g_RentBikePrice, g_RentCarDesertPrice, g_ExamAPrice, g_ExamBPrice, g_ExamCPrice, g_ExamDPrice, g_PizzaPrice, g_BurgerPrice);
    return 1;
}

// ============================================================
//  BOLI (Diseases)
// ============================================================
forward Disease_FinishCure(playerid);

// Imbolnaveste un player: marcheaza starea, o salveaza in DB, aplica efectul vizual (drunk level) si il anunta
stock Disease_Infect(playerid)
{
    PlayerData[playerid][pDiseased]       = true;
    PlayerData[playerid][pDiseasePaydays] = 0;
    UpdatePlayer(playerid, pDiseased);
    UpdatePlayer(playerid, pDiseasePaydays);

    SetPlayerDrunkLevel(playerid, DISEASE_DRUNK_LEVEL);

    SendClientMessage(playerid, COLOR_ERROR,
        C_ERROR"Error: "C_WHITE"You got sick! You need to go to the SMURD hospital and use "C_INFO"/curedisease"C_WHITE" to recover.");
}

// Vindeca un player: reseteaza starea, o salveaza in DB si scoate efectul vizual
stock Disease_Cure(playerid)
{
    PlayerData[playerid][pDiseased]       = false;
    PlayerData[playerid][pDiseasePaydays] = 0;
    UpdatePlayer(playerid, pDiseased);
    UpdatePlayer(playerid, pDiseasePaydays);

    SetPlayerDrunkLevel(playerid, 0);
}

// Apelata de timer-ul pornit de /curedisease, dupa cele 10 secunde de freeze
public Disease_FinishCure(playerid)
{
    if(!IsPlayerConnected(playerid)) return 0;

    TogglePlayerControllable(playerid, 1);
    Disease_Cure(playerid);

    SendClientMessage(playerid, COLOR_SUCCESS,
        C_SUCCESS"Success: "C_WHITE"You have been treated and are now healthy again.");
    return 1;
}

stock PayDay_Apply()
{
    new hour, minute, second;
    gettime(hour, minute, second);
    printf("[PayDay] Distribuit la %02d:00.", hour);

    Caravan_CheckCampingExpiry();
    Caravans_RebuildAll();

    // La fiecare payday: sterge toti actorii-animale si recreeaza-i din DB (re-randomizeaza pozitiile)
    Animals_Load();

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
            C_WHITE"  Gross: "C_SUCCESS"$%s"C_WHITE"  Tax: "C_ERROR"-$%s"C_WHITE"  CASS: "C_ERROR"-$%s"C_WHITE"  Net: "C_SUCCESS"$%s",
            MoneyStr(salary), MoneyStr(tax), MoneyStr(cass), MoneyStr(net));
        SendClientMessage(i, COLOR_WHITE, msg);
        format(msg, sizeof(msg),
            C_WHITE"  Bank interest: "C_SUCCESS"+$%s"C_WHITE"  RP: "C_SUCCESS"+1",
            MoneyStr(interest));
        SendClientMessage(i, COLOR_WHITE, msg);
        SendClientMessage(i, COLOR_INFO, C_INFO"================================");

        if(PlayerData[i][pDiseased])
        {
            PlayerData[i][pDiseasePaydays]++;
            if(PlayerData[i][pDiseasePaydays] >= DISEASE_CURE_PAYDAYS)
            {
                Disease_Cure(i);
                SendClientMessage(i, COLOR_SUCCESS,
                    C_SUCCESS"Success: "C_WHITE"Your illness has run its course. You have recovered.");
            }
            else
            {
                UpdatePlayer(i, pDiseasePaydays);
            }
        }

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
//  PRESEDINTE (alegeri saptamanale prin vot)
// ============================================================
// getdate() nu returneaza ziua saptamanii, deci o calculam din y/m/d (congruenta lui Zeller).
// Returneaza 0 = Duminica, 1 = Luni, ... 6 = Sambata.
stock DayOfWeek(year, month, day)
{
    if(month < 3) { month += 12; year -= 1; }
    new k = year % 100;
    new j = year / 100;
    // h: 0 = Sambata, 1 = Duminica, ...  (-2*j mod 7 == +5*j mod 7, evitam negativele)
    new h = (day + (13 * (month + 1)) / 5 + k + k / 4 + j / 4 + 5 * j) % 7;
    return (h + 6) % 7; // remapeaza la 0 = Duminica
}

// Returneaza true daca acum suntem in fereastra de vot (Duminica, 08:00 - 19:30)
stock bool:President_IsVoteWindowOpen()
{
    new year, month, day;
    getdate(year, month, day);
    if(DayOfWeek(year, month, day) != 0) return false; // doar Duminica

    new hour, minute, second;
    gettime(hour, minute, second);
    if(hour < VOTE_WINDOW_START_HOUR) return false;
    if(hour > VOTE_WINDOW_END_HOUR) return false;
    if(hour == VOTE_WINDOW_END_HOUR && minute >= VOTE_WINDOW_END_MINUTE) return false;
    return true;
}

// Cauta un player online & logat dupa nume exact (case-insensitive). Returneaza playerid sau -1.
stock Player_FindByName(const name[])
{
    for(new i = 0; i < MAX_PLAYERS; i++)
    {
        if(!IsPlayerConnected(i) || !PlayerData[i][pLogged]) continue;
        if(strcmp(PlayerData[i][pName], name, true) == 0) return i;
    }
    return -1;
}

// Gaseste presedintele curent online (sau -1)
stock President_FindCurrentOnline()
{
    for(new i = 0; i < MAX_PLAYERS; i++)
        if(IsPlayerConnected(i) && PlayerData[i][pLogged] && PlayerData[i][pIsPresident]) return i;
    return -1;
}

// Trimite un mesaj tuturor jucatorilor logati
stock President_BroadcastAll(color, const text[])
{
    for(new i = 0; i < MAX_PLAYERS; i++)
        if(IsPlayerConnected(i) && PlayerData[i][pLogged])
            SendClientMessage(i, color, text);
}

// Duminica 06:00 - goleste tabela de voturi si reseteaza flag-ul `voted` pentru toti (DB + online)
stock President_ClearVotes()
{
    mysql_tquery(g_SQL, "DELETE FROM `president_votes`", "", "", 0);
    mysql_tquery(g_SQL, "UPDATE `players` SET `voted`=0", "", "", 0);

    for(new i = 0; i < MAX_PLAYERS; i++)
        if(IsPlayerConnected(i) && PlayerData[i][pLogged])
            PlayerData[i][pVoted] = false;

    President_BroadcastAll(COLOR_INFO,
        C_INFO"[President] "C_WHITE"Voting is now open! Use "C_INFO"/vote [player name]"C_WHITE" until "C_INFO"19:30"C_WHITE" to elect this week's President.");
}

// Duminica 20:00 - declanseaza calculul castigatorului (interogare async)
stock President_ComputeWinner()
{
    // Numara voturile per candidat, excluzand candidatii care au fost presedinti runda trecuta (was_president=1).
    // Presedintele care tocmai isi incheie mandatul e marcat was_president=1 inainte sa rulam asta (vezi mai jos).
    mysql_tquery(g_SQL,
        "UPDATE `players` SET `was_president` = `is_president`",
        "", "", 0);

    mysql_tquery(g_SQL,
        "SELECT v.`vVotatPeId` AS pid, COUNT(*) AS cnt \
         FROM `president_votes` v \
         JOIN `players` p ON p.`id` = v.`vVotatPeId` \
         WHERE p.`was_president` = 0 \
         GROUP BY v.`vVotatPeId` \
         ORDER BY cnt DESC LIMIT 1",
        "OnPresidentWinnerComputed");
}

forward OnPresidentWinnerComputed();
public OnPresidentWinnerComputed()
{
    if(cache_num_rows() == 0)
    {
        // Niciun vot valid: nu se schimba presedintele, dar mandatul vechi s-a incheiat (deja marcat was_president).
        // Pastram presedintele actual? Spec spune ca se calculeaza un nou presedinte; fara voturi, ramane vacant.
        mysql_tquery(g_SQL, "UPDATE `players` SET `is_president`=0", "", "", 0);
        for(new i = 0; i < MAX_PLAYERS; i++)
            if(IsPlayerConnected(i) && PlayerData[i][pLogged])
            {
                PlayerData[i][pWasPresident] = PlayerData[i][pIsPresident];
                PlayerData[i][pIsPresident]  = false;
            }
        President_BroadcastAll(COLOR_INFO,
            C_INFO"[President] "C_WHITE"No valid votes this week - the presidency remains vacant.");
        return 1;
    }

    new winnerId, voteCount;
    cache_get_value_name_int(0, "pid", winnerId);
    cache_get_value_name_int(0, "cnt", voteCount);

    // DB: vechiul presedinte deja marcat was_president=1 (in President_ComputeWinner); acum setam noul presedinte.
    new q[160];
    mysql_tquery(g_SQL, "UPDATE `players` SET `is_president`=0", "", "", 0);
    mysql_format(g_SQL, q, sizeof(q),
        "UPDATE `players` SET `is_president`=1, `was_president`=0 WHERE `id`=%d", winnerId);
    mysql_tquery(g_SQL, q, "", "", 0);

    // Sincronizeaza starea in memorie pentru jucatorii online
    new winnerName[24]; winnerName[0] = EOS;
    for(new i = 0; i < MAX_PLAYERS; i++)
    {
        if(!IsPlayerConnected(i) || !PlayerData[i][pLogged]) continue;
        PlayerData[i][pWasPresident] = PlayerData[i][pIsPresident]; // cine era presedinte devine "fost presedinte"
        PlayerData[i][pIsPresident]  = (PlayerData[i][pID] == winnerId);
        if(PlayerData[i][pID] == winnerId)
        {
            PlayerData[i][pWasPresident] = false;
            format(winnerName, sizeof(winnerName), "%s", PlayerData[i][pName]);
        }
    }

    new msg[160];
    if(strlen(winnerName))
        format(msg, sizeof(msg),
            C_SUCCESS"[President] "C_WHITE"%s"C_WHITE" has been elected President for this week with "C_INFO"%d"C_WHITE" vote(s)!",
            winnerName, voteCount);
    else
        format(msg, sizeof(msg),
            C_SUCCESS"[President] "C_WHITE"A new President has been elected with "C_INFO"%d"C_WHITE" vote(s)! (currently offline)",
            voteCount);
    President_BroadcastAll(COLOR_SUCCESS, msg);
    return 1;
}

// Raspuns la /president - afiseaza presedintele curent + impozitul/CASS la zi
forward OnPresidentInfo(playerid);
public OnPresidentInfo(playerid)
{
    if(!IsPlayerConnected(playerid)) return 0;

    new presName[24];
    if(cache_num_rows() > 0)
        cache_get_value_name(0, "username", presName, sizeof(presName));

    new msg[160];
    if(strlen(presName))
        format(msg, sizeof(msg), C_INFO"[President] "C_WHITE"Current President: "C_INFO"%s"C_WHITE".", presName);
    else
        format(msg, sizeof(msg), C_INFO"[President] "C_WHITE"There is no President elected at the moment.");
    SendClientMessage(playerid, COLOR_INFO, msg);

    format(msg, sizeof(msg), C_INFO"[President] "C_WHITE"Income tax: "C_INFO"%d%%"C_WHITE" | CASS: "C_INFO"%d%%"C_WHITE".", g_PDTax, g_PDCASS);
    SendClientMessage(playerid, COLOR_INFO, msg);
    return 1;
}

// Tick la fiecare minut (acelasi cadou ca PayDay_Check) - declanseaza momentele cheie de Duminica
forward President_Check();
public President_Check()
{
    new year, month, day;
    getdate(year, month, day);
    if(DayOfWeek(year, month, day) != 0) return; // doar Duminica

    new hour, minute, second;
    gettime(hour, minute, second);

    if(hour == 6 && minute == 0 && g_LastVoteClearDay != day)
    {
        g_LastVoteClearDay = day;
        President_ClearVotes();
    }

    if(hour == 20 && minute == 0 && g_LastVoteWinnerDay != day)
    {
        g_LastVoteWinnerDay = day;
        President_ComputeWinner();
    }
}

// ============================================================
//  SCADERE VIATA (1 HP / minut)
// ============================================================
#define HEALTH_DECAY_TICK   60000 // 1 minut, in ms
#define HEALTH_DECAY_AMOUNT 1.0

forward HealthDecay_Tick();
public HealthDecay_Tick()
{
    for(new i = 0; i < MAX_PLAYERS; i++)
    {
        if(!IsPlayerConnected(i) || !PlayerData[i][pLogged]) continue;

        new Float:health;
        GetPlayerHealth(i, health);
        if(health <= 0.0) continue; // deja mort/in curs de respawn

        health -= (PlayerData[i][pDiseased] ? DISEASE_DECAY_AMOUNT : HEALTH_DECAY_AMOUNT);
        if(health < 0.0) health = 0.0;

        SetPlayerHealth(i, health); // la 0.0, SA-MP omoara playerul automat -> OnPlayerRequestClass il respawneaza
    }
    return 1;
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

        SendClientMessage(playerid, COLOR_SUCCESS, "Welcome back! From here, leave your worries aside and enjoy some quality time.");
        SendClientMessage(playerid, COLOR_INFO,
            C_INFO"Info: "C_WHITE"Account found. Use "C_INFO"/login [password]"C_WHITE" to log in.");
    }
    else
    {
        PlayerData[playerid][pRegistered] = false;
        SendClientMessage(playerid, COLOR_SUCCESS, "Welcome! From here, leave your worries aside and enjoy some quality time.");
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
    PlayerData[playerid][pDiseased]       = false;
    PlayerData[playerid][pDiseasePaydays] = 0;
    PlayerData[playerid][pCaravanKey]      = 0;
    Player_RecalcSpawn(playerid);

    SetPlayerVirtualWorld(playerid, 0);
    SetPlayerMapIcon(playerid, 0, 1385.0, 750.0, 10.8203, 35, 0, MAPICON_LOCAL);
    SetPlayerColor(playerid, FactionColors[FACTION_NONE]);
    Factions_SetPlayerIcons(playerid);
    Businesses_SetPlayerIcons(playerid);
    MedShops_SetPlayerIcons(playerid);
    Pizza_SetPlayerIcons(playerid);
    Burger_SetPlayerIcons(playerid);
    BBall_SetPlayerIcon(playerid);

    LoginBG_Destroy(playerid);

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

    new query[650];
    mysql_format(g_SQL, query, sizeof(query),
        "SELECT `id`,`password`,`email`,`level`,`money`,`bank`,`rp`,`admin_level`,`faction`,`faction_rank`,`faction_join`,`house`,`business`,`spawn_type`,`key1`,`key2`,`key3`,\
         `driving_lic_a_exp`,`driving_lic_b_exp`,`driving_lic_c_exp`,`driving_lic_d_exp`,`diseased`,`disease_paydays`,\
         `caravan_key`,`is_president`,`voted`,`was_president` \
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

    new diseasedInt;
    cache_get_value_name_int(0, "diseased",        diseasedInt);
    cache_get_value_name_int(0, "disease_paydays", PlayerData[playerid][pDiseasePaydays]);
    PlayerData[playerid][pDiseased] = bool:diseasedInt;

    cache_get_value_name_int(0, "caravan_key", PlayerData[playerid][pCaravanKey]);
    Caravan_ShowParked(playerid);

    new presInt, votedInt, wasPresInt;
    cache_get_value_name_int(0, "is_president",  presInt);
    cache_get_value_name_int(0, "voted",         votedInt);
    cache_get_value_name_int(0, "was_president", wasPresInt);
    PlayerData[playerid][pIsPresident]  = bool:presInt;
    PlayerData[playerid][pVoted]        = bool:votedInt;
    PlayerData[playerid][pWasPresident] = bool:wasPresInt;

    PlayerData[playerid][pLogged]  = true;
    PlayerData[playerid][pOnDuty]  = false;
    Player_RecalcSpawn(playerid);

    SetPlayerVirtualWorld(playerid, 0);
    SetPlayerColor(playerid, FactionColors[PlayerData[playerid][pFaction]]);
    Factions_SetPlayerIcons(playerid);
    Businesses_SetPlayerIcons(playerid);
    MedShops_SetPlayerIcons(playerid);
    Pizza_SetPlayerIcons(playerid);
    Burger_SetPlayerIcons(playerid);
    BBall_SetPlayerIcon(playerid);

    GivePlayerMoney(playerid, PlayerData[playerid][pMoney]);
    SetPlayerScore(playerid, PlayerData[playerid][pLevel]);

    if(PlayerData[playerid][pDiseased])
    {
        SetPlayerDrunkLevel(playerid, DISEASE_DRUNK_LEVEL);
        SendClientMessage(playerid, COLOR_ERROR,
            C_ERROR"Error: "C_WHITE"You are still sick. Go to the SMURD hospital and use "C_INFO"/curedisease"C_WHITE" to recover.");
    }

    LoginBG_Destroy(playerid);

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

        case pDiseased:
            mysql_format(g_SQL, query, sizeof(query),
                "UPDATE `players` SET `diseased`=%d WHERE `id`=%d",
                PlayerData[playerid][pDiseased], PlayerData[playerid][pID]);

        case pDiseasePaydays:
            mysql_format(g_SQL, query, sizeof(query),
                "UPDATE `players` SET `disease_paydays`=%d WHERE `id`=%d",
                PlayerData[playerid][pDiseasePaydays], PlayerData[playerid][pID]);

        case pCaravanKey:
            mysql_format(g_SQL, query, sizeof(query),
                "UPDATE `players` SET `caravan_key`=%d WHERE `id`=%d",
                PlayerData[playerid][pCaravanKey], PlayerData[playerid][pID]);

        case pIsPresident:
            mysql_format(g_SQL, query, sizeof(query),
                "UPDATE `players` SET `is_president`=%d WHERE `id`=%d",
                PlayerData[playerid][pIsPresident], PlayerData[playerid][pID]);

        case pVoted:
            mysql_format(g_SQL, query, sizeof(query),
                "UPDATE `players` SET `voted`=%d WHERE `id`=%d",
                PlayerData[playerid][pVoted], PlayerData[playerid][pID]);

        case pWasPresident:
            mysql_format(g_SQL, query, sizeof(query),
                "UPDATE `players` SET `was_president`=%d WHERE `id`=%d",
                PlayerData[playerid][pWasPresident], PlayerData[playerid][pID]);

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
    DisableInteriorEnterExits();

    AddPlayerClass(7,1362.4468,788.8919,10.8203,288.7621,0,0,0,0,0,0); // spawn1
    AddPlayerClass(7,1370.1937,791.0197,10.8203,168.5368,0,0,0,0,0,0); // spawn2
    AddPlayerClass(7,1389.8796,790.6416,10.8203,111.1963,0,0,0,0,0,0); // spawn3
    AddPlayerClass(7,1389.8354,781.3478,10.8203,90.8294,0,0,0,0,0,0); // spawn4
    AddPlayerClass(7,1392.5699,746.9161,10.8203,190.8562,0,0,0,0,0,0); // spawn5
    AddPlayerClass(7,1388.7506,731.7965,10.8203,44.4323,0,0,0,0,0,0); // spawn6
    AddPlayerClass(7,1364.1913,728.9312,10.8203,11.2420,0,0,0,0,0,0); // spawn7
    AddPlayerClass(7,1366.0541,750.7808,10.8203,263.0685,0,0,0,0,0,0); // spawn8

    AddStaticVehicle(559, 2794.7180, 1295.5698, 10.3750, 180.9595, 3, 8);
    AddStaticVehicle(565, 2791.6089, 1295.4680, 10.3748, 179.1351, 6, 8);
    AddStaticVehicle(541, 2785.1243, 1295.4415, 10.3750, 178.1488, 8, 13);

    g_TrainID = AddStaticVehicle(538, 2864.7500, 1329.6376, 12.1256, 0.0009,0, 0); // tren

    // Biciclete de inchiriat
    g_RentBikeVehicle[0] = AddStaticVehicle(510,1358.3551,762.0198,10.4325,336.0049,6,6); // bike1
    g_RentBikeVehicle[1] = AddStaticVehicle(510,1359.5782,784.4636,10.4287,166.2988,6,6); // bike2
    g_RentBikeVehicle[2] = AddStaticVehicle(510,1385.8171,796.8197,10.4368,115.3072,6,6); // bike3
    g_RentBikeVehicle[3] = AddStaticVehicle(510,1395.8231,758.8390,10.4292,79.9039,6,6); // bike4
    g_RentBikeVehicle[4] = AddStaticVehicle(510,1395.8622,756.7565,10.4291,66.2207,6,6); // bike5
    g_RentBikeVehicle[5] = AddStaticVehicle(510,1368.0385,727.4263,10.4290,322.6002,6,6); // bike6
    g_RentBikeVehicle[6] = AddStaticVehicle(510,1383.4104,729.2195,10.4292,77.7136,6,6); // bike7
    g_RentBikeVehicle[7] = AddStaticVehicle(510,1386.5029,740.6320,10.4292,73.3423,6,6); // bike8
    g_RentBikeVehicle[8] = AddStaticVehicle(510,1358.5907,732.5933,10.4291,319.0235,6,6); // bike9

    // Masini de inchiriat piramida
    g_RentCarVehicle[0] = AddStaticVehicle(545, 2200.0, 1278.0, 10.6, 90.0, 6, 6);
    g_RentCarVehicle[1] = AddStaticVehicle(565, 2200.0, 1283.0, 10.6, 90.0, 6, 6);
    g_RentCarVehicle[2] = AddStaticVehicle(477, 2200.0, 1288.0, 10.6, 90.0, 6, 6);
    g_RentCarVehicle[3] = AddStaticVehicle(559, 2200.0, 1293.0, 10.6, 90.0, 6, 6);

    // Masini de inchiriat RentCarDMVDesert
    g_RentCarDesertVehicle[0] = AddStaticVehicle(471, -17.0106, 2325.4922, 23.6235, 0.5196, 6, 6);
    g_RentCarDesertVehicle[1] = AddStaticVehicle(471, -19.7723, 2325.7161, 23.6209, 359.8743, 6, 6);
    g_RentCarDesertVehicle[2] = AddStaticVehicle(468, -26.1589, 2324.3223, 23.8033, 2.3033, 6, 6);
    g_RentCarDesertVehicle[3] = AddStaticVehicle(468, -28.8546, 2324.5056, 23.8053, 2.8901, 6, 6);

    // Masini de inchiriat, zona noua (langa spawn-urile civile)
    g_RentCarVehicle2[0] = AddStaticVehicle(562,1412.9662,768.6681,10.4794,268.9738,6,6); // rent car spawn 1
    g_RentCarVehicle2[1] = AddStaticVehicle(561,1413.1460,759.1260,10.6338,269.5908,6,6); // rent car spawn 2
    g_RentCarVehicle2[2] = AddStaticVehicle(565,1412.9193,752.6339,10.4452,270.2829,6,6); // rent car spawn 3
    g_RentCarVehicle2[3] = AddStaticVehicle(402,1413.1685,746.3370,10.6520,270.2584,6,6); // rent car spawn 4
    g_RentCarVehicle2[4] = AddStaticVehicle(603,1413.1903,771.8915,10.6585,269.6379,6,6); // rent car spawn 5
    g_RentCarVehicle2[5] = AddStaticVehicle(579,1413.4404,778.2606,10.7516,269.4717,6,6); // rent car spawn 6
    g_RentCarVehicle2[6] = AddStaticVehicle(489,1413.0236,784.7442,10.9637,270.7792,6,6); // rent car spawn 7

    // Decor pe apa, langa spawn
    CreateDynamicObject(10230, 1355.31726, 547.89276, 0.00000,   10.00000, -6.00000, 180.00000);
    CreateDynamicObject(10231, 1356.17529, 549.27856, -0.66410,   10.00000, -6.00000, 180.00000);
    CreateDynamicObject(17299, 1285.12878, 554.87238, -15.00000,   0.00000, 0.00000, 180.00000);
    CreateDynamicObject(19913, 1390.33057, 536.59735, 1.00000,   0.00000, 0.00000, 90.00000);
    CreateDynamicObject(19913, 1365.49426, 561.35529, 1.00000,   0.00000, 0.00000, 0.00000);
    CreateDynamicObject(19913, 1315.76086, 561.43927, -1.00000,   0.00000, 0.00000, 0.00000);
    CreateDynamicObject(19913, 1315.76086, 561.43927, 1.00000,   0.00000, 0.00000, 0.00000);
    CreateDynamicObject(5126, 1363.92078, 613.57062, 14.66000,   0.00000, 0.00000, -100.00000);

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

    // Autobuze scoala (examen categoria D)
    g_ExamDCar[0] = AddStaticVehicle(437, 1903.8201, 2578.3354, 10.9537, 359.2425, 226, 226);
    g_ExamDCar[1] = AddStaticVehicle(437, 1910.2091, 2576.8301, 10.9536, 1.3625, 226, 226);

    // 3D Text:
    Create3DTextLabel("[ Vehicle Inspection Service ]\n[ Use /vitp ]\n[ Price: 750$ ]", COLOR_WHITE,
        ITP_LOC_X, ITP_LOC_Y, ITP_LOC_Z - 1.0, 27.0, 0, 0);

    Create3DTextLabel("[ Vehicle Inspection Service ]\n[ Use /vplate ]\n[ Price: 250$ ]", COLOR_WHITE,
        PLATE_LOC_X, PLATE_LOC_Y, PLATE_LOC_Z - 1.0, 27.0, 0, 0);

    new examLabel[64];

    CreatePickup(1210, 1, EXAMA_LOC_X, EXAMA_LOC_Y, EXAMA_LOC_Z, -1);
    format(examLabel, sizeof(examLabel), "[ Category A Exam ]\n[ /examA ]\n[ Price: $%s ]", MoneyStr(g_ExamAPrice));
    Create3DTextLabel(examLabel, COLOR_WHITE,
        EXAMA_LOC_X, EXAMA_LOC_Y, EXAMA_LOC_Z - 0.5, 20.0, 0, 0);

    CreatePickup(1210, 1, EXAMB_LOC_X, EXAMB_LOC_Y, EXAMB_LOC_Z, -1);
    format(examLabel, sizeof(examLabel), "[ Category B Exam ]\n[ /examB ]\n[ Price: $%s ]", MoneyStr(g_ExamBPrice));
    Create3DTextLabel(examLabel, COLOR_WHITE,
        EXAMB_LOC_X, EXAMB_LOC_Y, EXAMB_LOC_Z - 0.5, 20.0, 0, 0);

    CreatePickup(1210, 1, EXAMC_LOC_X, EXAMC_LOC_Y, EXAMC_LOC_Z, -1);
    format(examLabel, sizeof(examLabel), "[ Category C Exam ]\n[ /examC ]\n[ Price: $%s ]", MoneyStr(g_ExamCPrice));
    Create3DTextLabel(examLabel, COLOR_WHITE,
        EXAMC_LOC_X, EXAMC_LOC_Y, EXAMC_LOC_Z - 0.5, 20.0, 0, 0);

    CreatePickup(1210, 1, EXAMD_LOC_X, EXAMD_LOC_Y, EXAMD_LOC_Z, -1);
    format(examLabel, sizeof(examLabel), "[ Category D Exam ]\n[ /examD ]\n[ Price: $%s ]", MoneyStr(g_ExamDPrice));
    Create3DTextLabel(examLabel, COLOR_WHITE,
        EXAMD_LOC_X, EXAMD_LOC_Y, EXAMD_LOC_Z - 0.5, 20.0, 0, 0);

    Create3DTextLabel("[ Police ]\n[ Type /garage ]\n [ Or press ENTER (F) ]", COLOR_WHITE,
        POLICE_GARAGE_X, POLICE_GARAGE_Y, POLICE_GARAGE_Z - 0.5, 10.0, 0, 0);
    Create3DTextLabel("[ Police ]\n[ Type /entrace ]\n[ Or press ENTER (F) ]", COLOR_WHITE,
        POLICE_ENTRANCE_X, POLICE_ENTRANCE_Y, POLICE_ENTRANCE_Z - 0.5, 10.0, 0, 0);

    CreatePickup(1241, 1, HOSPITAL_LOC_X, HOSPITAL_LOC_Y, HOSPITAL_LOC_Z, -1);
    Create3DTextLabel("[ Hospitalization ]\n[ Use /curedisease ]", COLOR_WHITE,
        HOSPITAL_LOC_X, HOSPITAL_LOC_Y, HOSPITAL_LOC_Z - 0.5, 10.0, 0, 0);

    MedShops_CreateWorld();
    Pizza_CreateWorld();
    Burger_CreateWorld();

    // Party - eticheta de join e vizibila in toate lumile virtuale (-1); cele de muzica/bautura
    // doar in VW_PARTY, ca sa nu le vada decat cei care au dat deja /joinparty
    Create3DTextLabel("[ /joinparty ]\n[ /leaveparty ]", COLOR_WHITE,
        PartyJoinLoc[0], PartyJoinLoc[1], PartyJoinLoc[2] + 0.5, 20.0, -1, 0);
    Create3DTextLabel("[ /changemusic ]\n[ Price: 25$ ]", COLOR_WHITE,
        PartyMusicLoc[0], PartyMusicLoc[1], PartyMusicLoc[2] + 0.5, 20.0, VW_PARTY, 0);
    Create3DTextLabel("[ /buydrink ]\n[ Price: 10$ ]", COLOR_WHITE,
        PartyDrinkLoc[0], PartyDrinkLoc[1], PartyDrinkLoc[2] + 0.5, 20.0, VW_PARTY, 0);
    Create3DTextLabel("[ /buygrill ]\n[ Price: 10$ ]", COLOR_WHITE,
        PartyGrillLoc[0], PartyGrillLoc[1], PartyGrillLoc[2] + 0.5, 20.0, VW_PARTY, 0);

    // Decor party - vizibil doar in VW_PARTY (.worldid), nu se vede pe harta normala
    CreateDynamicObject(669, -697.82471, 919.30432, 11.53906,   356.85840, 0.00000, 3.14159);
    CreateDynamicObject(669, -710.14233, 907.04150, 11.53906,   356.85840, 0.00000, 3.14159);
    CreateDynamicObject(669, -694.93127, 897.79358, 11.43910,   0.00000, 0.00000, 3.14160);
    CreateDynamicObject(669, -681.81653, 897.28412, 10.90000,   0.00000, 0.00000, 3.14160);
    CreateDynamicObject(669, -666.29932, 901.91235, 10.00000,   0.00000, 0.00000, 0.00000);
    CreateDynamicObject(700, -667.02325, 931.74896, 11.25000,   356.85840, 0.00000, 3.14159);
    CreateDynamicObject(700, -675.36865, 926.49701, 11.25000,   356.85840, 0.00000, 3.14159);
    CreateDynamicObject(700, -658.59790, 944.37335, 11.25000,   356.85840, 0.00000, 3.14159);
    CreateDynamicObject(700, -662.18799, 951.68652, 11.17000,   0.00000, 0.00000, 3.14160);
    CreateDynamicObject(700, -661.13959, 957.93469, 11.17000,   0.00000, 0.00000, 3.14160);
    CreateDynamicObject(700, -662.48218, 964.67023, 11.09000,   0.00000, 0.00000, 3.14160);
    CreateDynamicObject(700, -663.60480, 971.57697, 11.09000,   0.00000, 0.00000, 3.14160);
    CreateDynamicObject(705, -752.52667, 783.40259, 16.00000,   3.14160, 0.00000, 1.04720);
    CreateDynamicObject(705, -749.01703, 818.98468, 13.00000,   3.14160, 0.00000, 1.04720);
    CreateDynamicObject(700, -742.21515, 719.21057, 16.28125,   356.85840, 0.00000, 3.14159);
    CreateDynamicObject(700, -749.48773, 723.33759, 16.28125,   356.85840, 0.00000, 3.14159);
    CreateDynamicObject(700, -764.00842, 735.01819, 16.50000,   356.85840, 0.00000, 3.14160);
    CreateDynamicObject(700, -770.76611, 741.18671, 17.00000,   356.85840, 0.00000, 3.14160);
    CreateDynamicObject(669, -704.81152, 884.03088, 11.57910,   0.00000, 0.00000, 3.14160);
    CreateDynamicObject(18691, -688.06659, 931.67896, 12.62701,   0.00000, 0.00000, 0.00000);
    CreateDynamicObject(19632, -688.11292, 931.62531, 12.59670,   0.00000, 0.00000, 0.00000);
    CreateDynamicObject(19831, -689.13800, 920.72089, 11.10020,   0.00000, 0.00000, 90.00000);
    CreateDynamicObject(1481, -689.10449, 919.61829, 11.77790,   0.00000, 0.00000, 90.00000);
    CreateDynamicObject(1432, -692.81409, 923.10620, 11.23950,   0.00000, 0.00000, 0.00000);
    CreateDynamicObject(1432, -692.59967, 916.79077, 11.23950,   0.00000, 0.00000, 90.00000);
    CreateDynamicObject(1432, -679.56982, 925.78668, 11.13950,   0.00000, 0.00000, 20.00000);
    CreateDynamicObject(1281, -687.26160, 913.02972, 11.87090,   0.00000, 0.00000, 0.00000);
    CreateDynamicObject(1281, -681.11902, 912.40302, 11.85090,   0.00000, 0.00000, 0.00000);
    CreateDynamicObject(1281, -673.65692, 912.79742, 11.75090,   0.00000, 0.00000, 0.00000);
    CreateDynamicObject(2531, -692.29999, 934.31720, 12.59880,   0.00000, 0.00000, 90.00000);
    CreateDynamicObject(2531, -692.29999, 933.32758, 12.59880,   0.00000, 0.00000, 90.00000);
    CreateDynamicObject(1280, -665.99512, 924.37323, 11.53590,   0.00000, 0.00000, 90.00000);
    CreateDynamicObject(1280, -656.99335, 923.46490, 11.47590,   0.00000, 0.00000, 60.00000);
    CreateDynamicObject(19143, -692.64539, 934.50000, 15.82000,   0.00000, 0.00000, -80.00000);
    CreateDynamicObject(19143, -692.59119, 935.00000, 15.82000,   0.00000, 0.00000, -80.00000);
    CreateDynamicObject(19143, -684.82532, 941.90002, 15.66000,   0.00000, 0.00000, 160.00000);
    CreateDynamicObject(19143, -691.81769, 941.90002, 15.66000,   0.00000, 0.00000, 200.00000);
    CreateDynamicObject(19145, -683.68372, 934.50000, 15.82000,   0.00000, 0.00000, 90.00000);
    CreateDynamicObject(19145, -683.68372, 935.00000, 15.82000,   0.00000, 0.00000, 90.00000);
    CreateDynamicObject(12957, -674.72119, 946.11768, 11.72000,   0.00000, 0.00000, -90.00000);
    CreateDynamicObject(1331, -669.25140, 943.71295, 11.84560,   0.00000, 0.00000, 0.00000);
    CreateDynamicObject(3434, -695.07397, 965.68945, 12.10630,   0.00000, 0.00000, -90.00000);

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

	// Camping
	CreateDynamicObject(5418, 1376.68188, 694.27466, 16.57000,   0.00000, 0.00000, 0.00000);
	CreateDynamicObject(736, 1358.00000, 725.00000, 19.98000,   0.00000, 0.00000, 0.00000);
	CreateDynamicObject(736, 1363.00000, 725.00000, 19.98000,   0.00000, 0.00000, 0.00000);
	CreateDynamicObject(736, 1368.00000, 725.00000, 19.98000,   0.00000, 0.00000, 0.00000);
	CreateDynamicObject(736, 1373.00000, 725.00000, 19.98000,   0.00000, 0.00000, 0.00000);
	CreateDynamicObject(736, 1378.00000, 725.00000, 19.98000,   0.00000, 0.00000, 0.00000);
	CreateDynamicObject(736, 1383.00000, 724.97998, 19.98000,   0.00000, 0.00000, 0.00000);
	CreateDynamicObject(736, 1388.00000, 725.00000, 19.98000,   0.00000, 0.00000, 0.00000);
	CreateDynamicObject(736, 1392.98022, 724.99744, 19.98000,   0.00000, 0.00000, 0.00000);
	CreateDynamicObject(736, 1358.00000, 797.00000, 19.98000,   0.00000, 0.00000, 0.00000);
	CreateDynamicObject(736, 1363.00000, 797.00000, 19.98000,   0.00000, 0.00000, 0.00000);
	CreateDynamicObject(736, 1368.00000, 797.00000, 19.98000,   0.00000, 0.00000, 0.00000);
	CreateDynamicObject(736, 1373.00000, 797.00000, 19.98000,   0.00000, 0.00000, 0.00000);
	CreateDynamicObject(736, 1378.00000, 797.00000, 19.98000,   0.00000, 0.00000, 0.00000);
	CreateDynamicObject(736, 1383.00000, 797.00000, 19.98000,   0.00000, 0.00000, 0.00000);
	CreateDynamicObject(736, 1388.00000, 797.00000, 19.98000,   0.00000, 0.00000, 0.00000);
	CreateDynamicObject(736, 1393.00000, 797.00000, 19.98000,   0.00000, 0.00000, 0.00000);
	CreateDynamicObject(736, 1396.00000, 730.00000, 19.98000,   0.00000, 0.00000, 0.00000);
	CreateDynamicObject(736, 1396.00000, 735.00000, 19.98000,   0.00000, 0.00000, 0.00000);
	CreateDynamicObject(736, 1396.00000, 740.00000, 19.98000,   0.00000, 0.00000, 0.00000);
	CreateDynamicObject(736, 1396.00000, 745.00000, 19.98000,   0.00000, 0.00000, 0.00000);
	CreateDynamicObject(736, 1396.00000, 750.00000, 19.98000,   0.00000, 0.00000, 0.00000);
	CreateDynamicObject(736, 1396.00000, 755.00000, 19.98000,   0.00000, 0.00000, 0.00000);
	CreateDynamicObject(736, 1396.00000, 760.00000, 19.98000,   0.00000, 0.00000, 0.00000);
	CreateDynamicObject(736, 1396.00000, 770.00000, 19.98000,   0.00000, 0.00000, 0.00000);
	CreateDynamicObject(736, 1396.00000, 775.00000, 19.98000,   0.00000, 0.00000, 0.00000);
	CreateDynamicObject(736, 1396.00000, 780.00000, 19.98000,   0.00000, 0.00000, 0.00000);
	CreateDynamicObject(736, 1396.00000, 785.00000, 19.98000,   0.00000, 0.00000, 0.00000);
	CreateDynamicObject(736, 1396.00000, 790.00000, 19.98000,   0.00000, 0.00000, 0.00000);
	CreateDynamicObject(736, 1396.00000, 765.00000, 19.98000,   0.00000, 0.00000, 0.00000);
	CreateDynamicObject(736, 1358.00000, 730.00000, 19.98000,   0.00000, 0.00000, 0.00000);
	CreateDynamicObject(736, 1358.00000, 735.00000, 19.98000,   0.00000, 0.00000, 0.00000);
	CreateDynamicObject(736, 1358.00000, 740.00000, 19.98000,   0.00000, 0.00000, 0.00000);
	CreateDynamicObject(736, 1358.00000, 745.00000, 19.98000,   0.00000, 0.00000, 0.00000);
	CreateDynamicObject(736, 1358.00000, 750.00000, 19.98000,   0.00000, 0.00000, 0.00000);
	CreateDynamicObject(736, 1358.00000, 755.00000, 19.98000,   0.00000, 0.00000, 0.00000);
	CreateDynamicObject(736, 1358.00000, 760.00000, 19.98000,   0.00000, 0.00000, 0.00000);
	CreateDynamicObject(736, 1358.00000, 790.00000, 19.98000,   0.00000, 0.00000, 0.00000);
	CreateDynamicObject(736, 1358.00000, 785.00000, 19.98000,   0.00000, 0.00000, 0.00000);
	CreateDynamicObject(3171, 1364.28918, 788.17737, 9.75710,   0.00000, 0.00000, -40.00000);
	CreateDynamicObject(3171, 1372.04102, 791.66473, 9.75710,   0.00000, 0.00000, 10.00000);
	CreateDynamicObject(3171, 1392.03943, 791.12848, 9.75710,   0.00000, 0.00000, 0.00000);
	CreateDynamicObject(3171, 1390.16125, 779.50610, 9.75710,   0.00000, 0.00000, -90.00000);
	CreateDynamicObject(3168, 1365.56824, 753.05426, 9.81050,   0.00000, 0.00000, 90.00000);
	CreateDynamicObject(3168, 1388.35291, 729.54822, 9.81050,   0.00000, 0.00000, -110.00000);
	CreateDynamicObject(3174, 1365.79578, 730.29089, 9.80984,   0.00000, 0.00000, 0.00000);
	CreateDynamicObject(3172, 1390.02930, 746.44336, 9.81350,   0.00000, 0.00000, 160.00000);

    // Basketgame
	CreateDynamicObject(3065, 2480.21948, 1265.64417, 9.94500,   0.00000, 0.00000, 0.00000);
	CreateDynamicObject(3065, 2478.79590, 1267.20386, 9.94500,   0.00000, 0.00000, 0.00000);
	CreateDynamicObject(3065, 2476.80542, 1272.44104, 9.94500,   0.00000, 0.00000, 0.00000);
	CreateDynamicObject(3065, 2479.16333, 1282.01196, 9.94500,   0.00000, 0.00000, 0.00000);
	CreateDynamicObject(3065, 2516.44580, 1282.23962, 9.94500,   0.00000, 0.00000, 0.00000);
	CreateDynamicObject(3065, 2477.91504, 1291.65869, 9.94500,   0.00000, 0.00000, 0.00000);
	CreateDynamicObject(3065, 2484.81592, 1288.32703, 9.94500,   0.00000, 0.00000, 0.00000);
	CreateDynamicObject(3065, 2496.25562, 1301.42542, 9.94500,   0.00000, 0.00000, 0.00000);
	CreateDynamicObject(3065, 2496.94482, 1301.64001, 9.94500,   0.00000, 0.00000, 0.00000);
	CreateDynamicObject(3065, 2497.68848, 1302.26746, 9.94500,   0.00000, 0.00000, 0.00000);
	CreateDynamicObject(3065, 2516.83813, 1297.27136, 9.94500,   0.00000, 0.00000, 0.00000);
	CreateDynamicObject(3065, 2513.90967, 1283.74927, 9.94500,   0.00000, 0.00000, 0.00000);
	CreateDynamicObject(3065, 2511.30054, 1282.73584, 9.94500,   0.00000, 0.00000, 0.00000);
	CreateDynamicObject(3065, 2512.85425, 1283.00391, 9.94500,   0.00000, 0.00000, 0.00000);
	CreateDynamicObject(3065, 2513.21802, 1282.79993, 9.94500,   0.00000, 0.00000, 0.00000);
	CreateDynamicObject(1598, 2479.18921, 1274.31494, 10.06000,   0.00000, 0.00000, 0.00000);
	CreateDynamicObject(1598, 2504.04272, 1284.12024, 10.06000,   0.00000, 0.00000, 0.00000);
	CreateDynamicObject(1598, 2492.30103, 1283.92395, 10.06000,   0.00000, 0.00000, 0.00000);
	CreateDynamicObject(1598, 2499.14063, 1282.54138, 10.06000,   0.00000, 0.00000, 0.00000);
	CreateDynamicObject(1237, 2486.25000, 1303.40002, 9.70000,   0.00000, 0.00000, 0.00000);
	CreateDynamicObject(1237, 2488.75000, 1303.42004, 9.70000,   0.00000, 0.00000, 0.00000);
	CreateDynamicObject(1237, 2506.48096, 1303.40002, 9.70000,   0.00000, 0.00000, 0.00000);
	CreateDynamicObject(1237, 2509.00000, 1303.40002, 9.70000,   0.00000, 0.00000, 0.00000);
	CreateDynamicObject(1237, 2486.25000, 1263.00000, 9.70000,   0.00000, 0.00000, 0.00000);
	CreateDynamicObject(1237, 2488.75000, 1263.00000, 9.70000,   0.00000, 0.00000, 0.00000);
	CreateDynamicObject(1237, 2488.75000, 1303.40002, 9.70000,   0.00000, 0.00000, 0.00000);
	CreateDynamicObject(1237, 2506.50000, 1263.00000, 9.70000,   0.00000, 0.00000, 0.00000);
	CreateDynamicObject(1237, 2509.00000, 1263.00000, 9.70000,   0.00000, 0.00000, 0.00000);



    for(new i = 0; i <= MAX_FACTIONS; i++) g_FactionLabel[i] = Text3D:INVALID_3DTEXT_ID;
    for(new i = 0; i <= MAX_FACTIONS; i++) g_FactionInteriorLabel[i] = Text3D:INVALID_3DTEXT_ID;

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
    for(new i = 0; i < MAX_FIRES; i++) { FireData[i][fireActive] = false; FireData[i][fireObject] = 0; }
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
    Locations_Load();
    GPS_Load();
    BBallHoops_Load();
    BBallSpawns_Load();
    VehiclesFaction_Load();
    PVehicles_Load();
    Caravans_Load();
    PayDay_Load();

    SetTimer("PayDay_Check", 60000, true);
    SetTimer("President_Check", 60000, true);
    SetTimer("HealthDecay_Tick", HEALTH_DECAY_TICK, true);
    SetTimer("Fires_Tick", 1000, true);
    SetTimer("Radar_Tick", RADAR_TICK, true);
    SetTimer("Speedometer_Tick", SPEEDOMETER_TICK, true);
    SetTimer("ServerClock_Tick", SERVER_CLOCK_TICK, true);
    SetTimer("ExamC_TrailerTick", 2000, true);

    ServerClock_Create();

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

    g_GPSActive[playerid] = false;

    Speedometer_Create(playerid);
    LoginBG_Show(playerid);

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
    PlayerData[playerid][pDiseased]       = false;
    PlayerData[playerid][pDiseasePaydays] = 0;
    PlayerData[playerid][pCaravanKey]      = 0;
    PlayerData[playerid][pIsPresident]  = false;
    PlayerData[playerid][pVoted]        = false;
    PlayerData[playerid][pWasPresident] = false;
    PlayerData[playerid][pPass][0]    = EOS;
    PlayerData[playerid][pEmail][0]   = EOS;

    GetPlayerName(playerid, PlayerData[playerid][pName], 24);
    SetPlayerVirtualWorld(playerid, -1);

    GameTextForPlayer(playerid, "~g~Welcome to\n~y~Old is Gold", 5000, 5);

    Turfs_ShowToPlayer(playerid);
    ServerClock_ShowToPlayer(playerid);

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

        format(line, sizeof(line), "[Finance] Cash: $%s | Bank: $%s | House: %d | Keys: %d | %d | %d",
            MoneyStr(PlayerData[playerid][pMoney]),
            MoneyStr(PlayerData[playerid][pBank]),
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

    // ---- /fixcar ----
    if(strcmp(cmd, "/fixcar", true) == 0)
    {
        if(PlayerData[playerid][pAdminLevel] < 1)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have access. Requires admin level 1."), 1;

        new vehid = GetPlayerVehicleID(playerid);
        if(vehid == 0)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be in a vehicle."), 1;

        RepairVehicle(vehid);

        SendClientMessage(playerid, COLOR_SUCCESS, C_SUCCESS"[ADM] Success: "C_WHITE"Vehicle repaired.");
        return 1;
    }

    // ---- /flipcar ----
    if(strcmp(cmd, "/flipcar", true) == 0)
    {
        if(PlayerData[playerid][pAdminLevel] < 1)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have access. Requires admin level 1."), 1;

        new vehid = GetPlayerVehicleID(playerid);
        if(vehid == 0)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be in a vehicle."), 1;

        new Float:fx, Float:fy, Float:fz, Float:fangle;
        GetVehiclePos(vehid, fx, fy, fz);
        GetVehicleZAngle(vehid, fangle);

        SetVehiclePos(vehid, fx, fy, fz + 0.5);
        SetVehicleZAngle(vehid, fangle);

        SendClientMessage(playerid, COLOR_SUCCESS, C_SUCCESS"[ADM] Success: "C_WHITE"Vehicle flipped upright.");
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
        for(new i = 0; i < MAX_PLAYERS; i++) g_FireInRange[fidx][i] = false;

        CreateExplosion(fx, fy, fz-1, 1, 0.0);
        FireData[fidx][fireObject] = CreateObject(FIRE_OBJECT_MODEL, fx, fy, fz - 1.0, 0.0, 0.0, 0.0);

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

    // ---- /opengolftournament ----
    if(strcmp(cmd, "/opengolftournament", true) == 0)
    {
        if(PlayerData[playerid][pAdminLevel] < GOLF_ADMIN_LEVEL)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have access. Requires admin level 2."), 1;

        if(g_GolfStatus != GOLF_STATUS_CLOSED)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"A golf tournament is already open or in progress."), 1;

        g_GolfStatus = GOLF_STATUS_OPEN;
        g_GolfRound = 0;
        for(new i = 0; i < MAX_PLAYERS; i++)
        {
            g_GolfJoined[i] = false;
            g_GolfActive[i] = false;
            g_GolfStrokes[i] = 0;
            g_GolfFinishedHole[i] = false;
        }

        SendClientMessageToAll(COLOR_INFO, C_INFO"[Golf Tournament] "C_WHITE"Registration is now "C_INFO"OPEN"C_WHITE"! Type "C_INFO"/joingolf"C_WHITE" to participate.");
        SendClientMessage(playerid, COLOR_SUCCESS, C_SUCCESS"[ADM] Success: "C_WHITE"Golf tournament registration opened.");
        return 1;
    }

    // ---- /startgolf ----
    if(strcmp(cmd, "/startgolf", true) == 0)
    {
        if(PlayerData[playerid][pAdminLevel] < GOLF_ADMIN_LEVEL)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have access. Requires admin level 2."), 1;

        if(g_GolfStatus != GOLF_STATUS_OPEN)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"The tournament must be opened first with "C_INFO"/opengolftournament"C_WHITE"."), 1;

        new joined = 0;
        for(new i = 0; i < MAX_PLAYERS; i++)
            if(g_GolfJoined[i]) joined++;

        if(joined < 1)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"At least 1 player must join before starting."), 1;

        g_GolfStatus = GOLF_STATUS_PROGRESS;
        for(new i = 0; i < MAX_PLAYERS; i++)
        {
            g_GolfActive[i] = g_GolfJoined[i];
            if(!g_GolfActive[i]) continue;

            SetPlayerHealth(i, 100.0);
            GivePlayerWeapon(i, GOLF_CLUB_WEAPON_ID, 1);
        }

        Golf_ShuffleHoleOrder();

        SendClientMessageToAll(COLOR_SUCCESS, C_SUCCESS"[Golf Tournament] "C_WHITE"Registrations closed. The tournament has started!");
        Golf_StartRound(1);

        SendClientMessage(playerid, COLOR_SUCCESS, C_SUCCESS"[ADM] Success: "C_WHITE"Golf tournament started.");
        return 1;
    }

    // ---- /createdisease ----
    if(strcmp(cmd, "/createdisease", true) == 0)
    {
        if(PlayerData[playerid][pAdminLevel] < 3)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have access. Requires admin level 3."), 1;

        new Float:ax, Float:ay, Float:az;
        GetPlayerPos(playerid, ax, ay, az);

        new infected = 0;
        for(new i = 0; i < MAX_PLAYERS; i++)
        {
            if(!IsPlayerConnected(i) || !PlayerData[i][pLogged]) continue;
            if(PlayerData[i][pDiseased]) continue;
            if(!IsPlayerInRangeOfPoint(i, DISEASE_RADIUS, ax, ay, az)) continue;

            Disease_Infect(i);
            infected++;
        }

        new dmsg[128];
        format(dmsg, sizeof(dmsg), C_SUCCESS"[ADM] Success: "C_WHITE"Infected "C_INFO"%d"C_WHITE" player(s) within "C_INFO"%d m"C_WHITE".",
            infected, floatround(DISEASE_RADIUS));
        SendClientMessage(playerid, COLOR_SUCCESS, dmsg);
        return 1;
    }

    // ---- /curedisease ----
    if(strcmp(cmd, "/curedisease", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        if(!PlayerData[playerid][pDiseased])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You are not sick."), 1;

        if(!IsPlayerInRangeOfPoint(playerid, HOSPITAL_RANGE, HOSPITAL_LOC_X, HOSPITAL_LOC_Y, HOSPITAL_LOC_Z))
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be at the SMURD hospital."), 1;

        if(PlayerData[playerid][pMoney] < DISEASE_CURE_PRICE)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have enough money."), 1;

        PlayerData[playerid][pMoney] -= DISEASE_CURE_PRICE;
        GivePlayerMoney(playerid, -DISEASE_CURE_PRICE);
        UpdatePlayer(playerid, pMoney);

        Faction_AddBank(FACTION_SMURD, DISEASE_CURE_PRICE);

        TogglePlayerControllable(playerid, 0);
        SetTimerEx("Disease_FinishCure", DISEASE_FREEZE_TIME, false, "i", playerid);

        SendClientMessage(playerid, COLOR_INFO,
            C_INFO"Info: "C_WHITE"Treatment in progress, please wait "C_INFO"10 seconds"C_WHITE"...");
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

    // ---- /equip (mafii, in interiorul HQ-ului propriu) ----
    if(strcmp(cmd, "/equip", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        if(!IsMafiaFaction(PlayerData[playerid][pFaction]))
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Only mafia factions can use this."), 1;

        if(!Factions_IsInOwnInterior(playerid))
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be inside your faction HQ interior."), 1;

        SetPlayerHealth(playerid, 100.0);
        GivePlayerWeapon(playerid, WEAPON_GRENADE, 1);
        GivePlayerWeapon(playerid, WEAPON_TEARGAS, 1);
        GivePlayerWeapon(playerid, WEAPON_DEAGLE, 350);
        GivePlayerWeapon(playerid, WEAPON_AK47,  300);
        if(PlayerData[playerid][pFactionRank] >= 4)
            GivePlayerWeapon(playerid, WEAPON_SNIPER, 20);

        SendClientMessage(playerid, COLOR_SUCCESS, C_SUCCESS"Success: "C_WHITE"You have been equipped.");
        return 1;
    }

    // ---- /war (declara razboi pe turful in care te afli) ----
    if(strcmp(cmd, "/war", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        new warAtkFid = PlayerData[playerid][pFaction];
        if(!IsMafiaFaction(warAtkFid))
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Only mafia factions can declare turf wars."), 1;

        new warTidx = War_FindTurfPlayerStandsIn(playerid);
        if(warTidx == -1)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be standing inside a territory to declare war on it."), 1;

        new warDefFid = TurfData[warTidx][tFactionID];
        if(warDefFid == warAtkFid)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You can't declare war on your own territory."), 1;

        if(!IsMafiaFaction(warDefFid))
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"This territory doesn't belong to a mafia faction."), 1;

        if(!TurfData[warTidx][tAttackable])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"This territory cannot be attacked."), 1;

        if(TurfData[warTidx][tWarState] != WAR_STATE_NONE)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"This territory is already at war."), 1;

        if(War_FactionHasActiveWar(warAtkFid))
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Your faction is already involved in another war."), 1;

        if(War_FactionHasActiveWar(warDefFid))
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"That faction is already involved in another war."), 1;

        if(War_CountOnline(warAtkFid) < WAR_MIN_FACTION_ONLINE || War_CountOnline(warDefFid) < WAR_MIN_FACTION_ONLINE)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Both factions need at least 2 members online to start a war."), 1;

        War_Declare(warTidx, warAtkFid, warDefFid);
        return 1;
    }

    // ---- /forcewar [turf_id] [attacker_faction_id] [defender_faction_id] (admin lvl 4+) ----
    if(strcmp(cmd, "/forcewar", true) == 0)
    {
        if(PlayerData[playerid][pAdminLevel] < 4)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have access. Requires admin level 4."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new fwP1[8], fwP2[8], fwP3[8];
        strmid(fwP1, cmdtext, idx, strlen(cmdtext), 8);
        while(cmdtext[idx] > ' ') idx++;
        while(cmdtext[idx] == ' ') idx++;
        strmid(fwP2, cmdtext, idx, strlen(cmdtext), 8);
        while(cmdtext[idx] > ' ') idx++;
        while(cmdtext[idx] == ' ') idx++;
        strmid(fwP3, cmdtext, idx, strlen(cmdtext), 8);

        if(!strlen(fwP1) || !strlen(fwP2) || !strlen(fwP3))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/forcewar [turf_id] [attacker_faction_id] [defender_faction_id]"C_WHITE"."), 1;

        new fwTid = strval(fwP1);
        new fwAtkFid = strval(fwP2);
        new fwDefFid = strval(fwP3);

        new fwTidx = Turfs_FindByID(fwTid);
        if(fwTidx == -1)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Invalid territory ID."), 1;

        if(!IsMafiaFaction(fwAtkFid) || !IsMafiaFaction(fwDefFid))
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Both factions must be mafia factions (4-7)."), 1;

        if(fwAtkFid == fwDefFid)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Attacker and defender must be different factions."), 1;

        if(TurfData[fwTidx][tWarState] != WAR_STATE_NONE)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"This territory is already at war."), 1;

        War_Declare(fwTidx, fwAtkFid, fwDefFid);

        new fwmsg[160];
        format(fwmsg, sizeof(fwmsg), C_SUCCESS"[ADM] Success: "C_WHITE"Forced a war on territory "C_INFO"#%d"C_WHITE": "C_INFO"%s"C_WHITE" vs "C_INFO"%s"C_WHITE".",
            fwTid, FactionData[fwAtkFid][fName], FactionData[fwDefFid][fName]);
        SendClientMessage(playerid, COLOR_SUCCESS, fwmsg);
        return 1;
    }

    // ---- /warsurrender ----
    if(strcmp(cmd, "/warsurrender", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        new wsFid = PlayerData[playerid][pFaction];
        if(!IsMafiaFaction(wsFid))
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Only mafia factions take part in turf wars."), 1;

        if(PlayerData[playerid][pFactionRank] < 4)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You need rank 4 or 5 in the faction to surrender a war."), 1;

        new wsTidx = -1;
        for(new i = 0; i < g_TurfCount; i++)
        {
            if((TurfData[i][tWarState] == WAR_STATE_ACTIVE || TurfData[i][tWarState] == WAR_STATE_OVERTIME) &&
               (TurfData[i][tWarAttackerFaction] == wsFid || TurfData[i][tWarDefenderFaction] == wsFid))
            {
                wsTidx = i;
                break;
            }
        }

        if(wsTidx == -1)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Your faction is not currently in an active war."), 1;

        if(gettime() - TurfData[wsTidx][tWarActiveStartTime] < WAR_SURRENDER_MIN_TIME)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You can only surrender after the first 5 minutes of the war."), 1;

        new wsWinnerFid = (TurfData[wsTidx][tWarAttackerFaction] == wsFid) ? TurfData[wsTidx][tWarDefenderFaction] : TurfData[wsTidx][tWarAttackerFaction];
        War_EndWar(wsTidx, wsWinnerFid, true);
        return 1;
    }

    // ---- /warscore ----
    if(strcmp(cmd, "/warscore", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        new wcFid = PlayerData[playerid][pFaction];
        if(!IsMafiaFaction(wcFid))
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Only mafia factions take part in turf wars."), 1;

        new wcFound = 0;
        for(new i = 0; i < g_TurfCount; i++)
        {
            if(TurfData[i][tWarState] == WAR_STATE_NONE) continue;
            if(TurfData[i][tWarAttackerFaction] != wcFid && TurfData[i][tWarDefenderFaction] != wcFid) continue;

            wcFound++;
            new wcAtkFid = TurfData[i][tWarAttackerFaction];
            new wcDefFid = TurfData[i][tWarDefenderFaction];
            new wcLeft;
            new wcMsg[230];

            if(TurfData[i][tWarState] == WAR_STATE_PENDING)
            {
                wcLeft = TurfData[i][tWarPhaseEndTime] - gettime();
                if(wcLeft < 0) wcLeft = 0;
                format(wcMsg, sizeof(wcMsg), C_INFO"[War] "C_WHITE"Territory "C_INFO"#%d"C_WHITE" (%s): "C_WHITE"%s"C_WHITE" vs "C_WHITE"%s"C_WHITE" - starts in "C_INFO"%d:%02d"C_WHITE".",
                    TurfData[i][tID], TurfData[i][tName], FactionData[wcAtkFid][fName], FactionData[wcDefFid][fName], wcLeft / 60, wcLeft % 60);
            }
            else if(TurfData[i][tWarState] == WAR_STATE_ACTIVE)
            {
                wcLeft = TurfData[i][tWarPhaseEndTime] - gettime();
                if(wcLeft < 0) wcLeft = 0;
                format(wcMsg, sizeof(wcMsg), C_INFO"[War] "C_WHITE"Territory "C_INFO"#%d"C_WHITE" (%s): "C_INFO"%s %d"C_WHITE" - "C_INFO"%d %s"C_WHITE" | Time left: "C_INFO"%d:%02d"C_WHITE".",
                    TurfData[i][tID], TurfData[i][tName], FactionData[wcAtkFid][fName], TurfData[i][tWarAttackerScore],
                    TurfData[i][tWarDefenderScore], FactionData[wcDefFid][fName], wcLeft / 60, wcLeft % 60);
            }
            else
            {
                format(wcMsg, sizeof(wcMsg), C_INFO"[War] "C_WHITE"Territory "C_INFO"#%d"C_WHITE" (%s): "C_INFO"SUDDEN DEATH"C_WHITE" - "C_WHITE"%s "C_INFO"%d"C_WHITE" kills, "C_WHITE"%s "C_INFO"%d"C_WHITE" kills (first to "C_INFO"%d"C_WHITE" wins).",
                    TurfData[i][tID], TurfData[i][tName], FactionData[wcAtkFid][fName], TurfData[i][tWarOvertimeAttackerKills],
                    FactionData[wcDefFid][fName], TurfData[i][tWarOvertimeDefenderKills], WAR_OVERTIME_KILLS_TO_WIN);
            }

            SendClientMessage(playerid, COLOR_INFO, wcMsg);
        }

        if(!wcFound)
            SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Your faction is not currently involved in any turf war.");
        return 1;
    }

    // ---- /vote [player name] (alegeri presedinte, Duminica 08:00-19:30) ----
    if(strcmp(cmd, "/vote", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        if(!President_IsVoteWindowOpen())
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Voting is only open on Sunday between 08:00 and 19:30."), 1;

        if(PlayerData[playerid][pVoted])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You have already voted this week."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new voteName[24];
        strmid(voteName, cmdtext, idx, strlen(cmdtext), 24);
        if(!strlen(voteName))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/vote [player name]"C_WHITE"."), 1;

        new targetid = Player_FindByName(voteName);
        if(targetid == -1)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"That player is not online."), 1;

        new vq[256];
        mysql_format(g_SQL, vq, sizeof(vq),
            "INSERT INTO `president_votes` (`vVotant`,`vVotantId`,`vVotatPe`,`vVotatPeId`) VALUES ('%e',%d,'%e',%d)",
            PlayerData[playerid][pName], PlayerData[playerid][pID],
            PlayerData[targetid][pName], PlayerData[targetid][pID]);
        mysql_tquery(g_SQL, vq, "", "", 0);

        PlayerData[playerid][pVoted] = true;
        UpdatePlayer(playerid, pVoted);

        new vmsg[128];
        format(vmsg, sizeof(vmsg),
            C_SUCCESS"Success: "C_WHITE"You voted for "C_INFO"%s"C_WHITE" as President. Results are announced Sunday at 20:00.",
            PlayerData[targetid][pName]);
        SendClientMessage(playerid, COLOR_SUCCESS, vmsg);
        return 1;
    }

    // ---- /settax [0-100] (doar presedinte) ----
    if(strcmp(cmd, "/settax", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        if(!PlayerData[playerid][pIsPresident])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Only the President can change the tax rate."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new taxStr[8];
        strmid(taxStr, cmdtext, idx, strlen(cmdtext), 8);
        if(!strlen(taxStr))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/settax [0-100]"C_WHITE"."), 1;

        new newTax = strval(taxStr);
        if(newTax < 0 || newTax > 100)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Tax must be between 0 and 100."), 1;

        g_PDTax = newTax;
        new tq[96];
        mysql_format(g_SQL, tq, sizeof(tq), "UPDATE `payday_setup` SET `tax`=%d WHERE `id`=1", newTax);
        mysql_tquery(g_SQL, tq, "", "", 0);

        new tmsg[128];
        format(tmsg, sizeof(tmsg),
            C_INFO"[President] "C_WHITE"The President set the income tax to "C_INFO"%d%%"C_WHITE".", newTax);
        President_BroadcastAll(COLOR_INFO, tmsg);
        return 1;
    }

    // ---- /setcass [0-100] (doar presedinte) ----
    if(strcmp(cmd, "/setcass", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        if(!PlayerData[playerid][pIsPresident])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Only the President can change the CASS rate."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new cassStr[8];
        strmid(cassStr, cmdtext, idx, strlen(cmdtext), 8);
        if(!strlen(cassStr))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/setcass [0-100]"C_WHITE"."), 1;

        new newCass = strval(cassStr);
        if(newCass < 0 || newCass > 100)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"CASS must be between 0 and 100."), 1;

        g_PDCASS = newCass;
        new cq[96];
        mysql_format(g_SQL, cq, sizeof(cq), "UPDATE `payday_setup` SET `cass`=%d WHERE `id`=1", newCass);
        mysql_tquery(g_SQL, cq, "", "", 0);

        new cmsg[128];
        format(cmsg, sizeof(cmsg),
            C_INFO"[President] "C_WHITE"The President set the CASS to "C_INFO"%d%%"C_WHITE".", newCass);
        President_BroadcastAll(COLOR_INFO, cmsg);
        return 1;
    }

    // ---- /president (info: presedintele curent + impozit/CASS) ----
    if(strcmp(cmd, "/president", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        mysql_tquery(g_SQL,
            "SELECT `username` FROM `players` WHERE `is_president`=1 LIMIT 1",
            "OnPresidentInfo", "i", playerid);
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
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be within 15m of the officer who fined you."), 1;

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
            format(amsg2, sizeof(amsg2), C_SUCCESS"Success: "C_WHITE"You paid the "C_INFO"$%s"C_WHITE" fine for: "C_INFO"%s"C_WHITE".", MoneyStr(amount), reason);
            SendClientMessage(playerid, COLOR_SUCCESS, amsg2);

            format(amsg2, sizeof(amsg2), C_SUCCESS"Success: "C_WHITE"%s"C_WHITE" paid the "C_INFO"$%s"C_WHITE" fine you issued.", PlayerData[playerid][pName], MoneyStr(amount));
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
        format(bmsg, sizeof(bmsg), C_INFO"Info: "C_WHITE"The faction "C_INFO"%s"C_WHITE" account has "C_INFO"$%s"C_WHITE".",
            FactionData[fid][fName], MoneyStr(FactionData[fid][fBank]));
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
        format(wmsg, sizeof(wmsg), C_SUCCESS"Success: "C_WHITE"You withdrew "C_INFO"$%s"C_WHITE" from the faction account.", MoneyStr(amount));
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
        SendClientMessage(playerid, COLOR_WHITE, C_INFO"[Rank 1+] "C_WHITE"/f, /fmembers /fhelp");

        if(fid >= 1 && fid <= 3)
            SendClientMessage(playerid, COLOR_WHITE, C_INFO"[Rank 1+] "C_WHITE"/duty");

        if(rank >= 4)
            SendClientMessage(playerid, COLOR_WHITE, C_INFO"[Rank 4+] "C_WHITE"/finvite /fbank");

        if(rank >= 5)
            SendClientMessage(playerid, COLOR_WHITE, C_INFO"[Rank 5] "C_WHITE"/fbankwithdraw /fsetrank");

        if(fid == FACTION_RAR || fid == FACTION_POLICE)
            SendClientMessage(playerid, COLOR_WHITE, C_INFO"[RAR/Police, On-Duty] "C_WHITE"/fine /m /inspectcar");

        if(fid == FACTION_RAR && rank >= 3)
            SendClientMessage(playerid, COLOR_WHITE, C_INFO"[RAR, Rank 3+, On-Duty] "C_WHITE"/confiscate");

        if(fid == FACTION_POLICE && rank >= 2)
            SendClientMessage(playerid, COLOR_WHITE, C_INFO"[Police, Rank 2+, On-Duty] "C_WHITE"/confiscate insurance /confiscate licence");

        if(fid == FACTION_POLICE)
            SendClientMessage(playerid, COLOR_WHITE, C_INFO"[Police, On-Duty] "C_WHITE"/checkLicenses /suspendLic");

        if(fid == FACTION_POLICE)
            SendClientMessage(playerid, COLOR_WHITE, C_INFO"[Police] "C_WHITE"/garage /entrace");

        if(fid == FACTION_POLICE && rank >= 2)
            SendClientMessage(playerid, COLOR_WHITE, C_INFO"[Police, Rank 2+] "C_WHITE"/radar");

        if(fid == FACTION_POLICE && rank >= 4)
            SendClientMessage(playerid, COLOR_WHITE, C_INFO"[Police, Rank 4+] "C_WHITE"/showradars /removeradar");

        if(fid == FACTION_SMURD)
            SendClientMessage(playerid, COLOR_WHITE, C_INFO"[SMURD, On-Duty] "C_WHITE"/heal");

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

        if(!Factions_IsInOwnInterior(playerid))
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be inside your faction HQ interior to change your duty status."), 1;

        PlayerData[playerid][pOnDuty] = !PlayerData[playerid][pOnDuty];

        if(PlayerData[playerid][pOnDuty])
            SendClientMessage(playerid, COLOR_SUCCESS, C_INFO"Info: "C_WHITE"You are now "C_SUCCESS"ON-DUTY"C_WHITE".");
        else
            SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"You are now "C_ERROR"OFF-DUTY"C_WHITE".");
        return 1;
    }

    // ---- /heal [playerid] ----
    if(strcmp(cmd, "/heal", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        if(PlayerData[playerid][pFaction] != FACTION_SMURD)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You are not part of SMURD."), 1;

        if(!PlayerData[playerid][pOnDuty])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be on-duty to use this command."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new p1[8];
        strmid(p1, cmdtext, idx, strlen(cmdtext), 8);

        if(!strlen(p1))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/heal [playerid]"C_WHITE"."), 1;

        new targetid = strval(p1);
        if(!IsPlayerConnected(targetid) || !PlayerData[targetid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"The player is not connected."), 1;

        if(GetPlayerState(targetid) != PLAYER_STATE_PASSENGER || GetVehicleModel(GetPlayerVehicleID(targetid)) != AMBULANCE_MODEL)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"The player must be a passenger in an ambulance."), 1;

        if(PlayerData[targetid][pMoney] < HEAL_PRICE)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"The player doesn't have enough money."), 1;

        SetPlayerHealth(targetid, 100.0);

        PlayerData[targetid][pMoney] -= HEAL_PRICE;
        GivePlayerMoney(targetid, -HEAL_PRICE);
        UpdatePlayer(targetid, pMoney);

        Faction_AddBank(FACTION_SMURD, HEAL_PRICE);

        new healMsg[32];
        format(healMsg, sizeof(healMsg), "Healed. -$%s", MoneyStr(HEAL_PRICE));
        GameTextForPlayer(targetid, healMsg, 3000, 1);

        new hmsg[128];
        format(hmsg, sizeof(hmsg), C_SUCCESS"Success: "C_WHITE"You healed "C_INFO"%s"C_WHITE" for "C_INFO"$%s"C_WHITE".",
            PlayerData[targetid][pName], MoneyStr(HEAL_PRICE));
        SendClientMessage(playerid, COLOR_SUCCESS, hmsg);
        return 1;
    }

    // ---- /inspectcar [playerid] ----
    if(strcmp(cmd, "/inspectcar", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        if(PlayerData[playerid][pFaction] != FACTION_RAR && PlayerData[playerid][pFaction] != FACTION_POLICE)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You are not part of the Registrul Auto Roman or Politia Romana."), 1;

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
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"The player must be within 15m."), 1;

        new vehid = GetPlayerVehicleID(targetid);
        if(vehid == 0)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"The player is not in a vehicle."), 1;

        new engine, lights, alarm, doors, bonnet, boot, objective;
        GetVehicleParamsEx(vehid, engine, lights, alarm, doors, bonnet, boot, objective);
        if(engine)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"The vehicle's engine must be off to inspect it."), 1;

        new pvidx = g_VehicleToPVIndex[vehid];
        if(pvidx == -1)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"This vehicle is not a registered personal vehicle."), 1;

        new vname[24];
        GetVehicleModelName(PVehicleData[pvidx][pvModelID], vname, sizeof(vname));

        new medStatus[16], extStatus[16];
        VehicleDoc_Status(PVehicleData[pvidx][pvMedkitExp], medStatus, sizeof(medStatus));
        VehicleDoc_Status(PVehicleData[pvidx][pvExtinguisherExp], extStatus, sizeof(extStatus));

        new line[160];
        SendClientMessage(playerid, COLOR_INFO, C_INFO"_____ Vehicle Inspection ____________________________");
        format(line, sizeof(line), C_WHITE"Driver: "C_INFO"%s"C_WHITE" | Vehicle: "C_INFO"%s"C_WHITE" | Plate: "C_INFO"%s",
            PlayerData[targetid][pName], vname, PVehicleData[pvidx][pvPlate]);
        SendClientMessage(playerid, COLOR_WHITE, line);

        if(PlayerData[playerid][pFaction] == FACTION_POLICE)
        {
            new insStatus[16];
            VehicleDoc_Status(PVehicleData[pvidx][pvInsuranceExp], insStatus, sizeof(insStatus));
            format(line, sizeof(line), C_WHITE"Insurance: "C_INFO"%s"C_WHITE" | Medical Kit: "C_INFO"%s"C_WHITE" | Extinguisher: "C_INFO"%s",
                insStatus, medStatus, extStatus);
            SendClientMessage(playerid, COLOR_WHITE, line);
        }
        else // FACTION_RAR
        {
            new itpStatus[16];
            VehicleDoc_Status(PVehicleData[pvidx][pvITPExp], itpStatus, sizeof(itpStatus));
            format(line, sizeof(line), C_WHITE"Medical Kit: "C_INFO"%s"C_WHITE" | Extinguisher: "C_INFO"%s"C_WHITE" | ITP: "C_INFO"%s",
                medStatus, extStatus, itpStatus);
            SendClientMessage(playerid, COLOR_WHITE, line);

            new Float:health;
            GetVehicleHealth(vehid, health);
            format(line, sizeof(line), C_WHITE"Vehicle Health: "C_INFO"%d", floatround(health));
            SendClientMessage(playerid, COLOR_WHITE, line);
        }

        SendClientMessage(playerid, COLOR_INFO, C_INFO"_______________________________________________________");
        return 1;
    }

    // ---- /confiscate [extinctor/medkit/itp] [playerid] (RAR) | [insurance] [playerid] / [licence] [A/B/C/D/all] [playerid] (Police) ----
    if(strcmp(cmd, "/confiscate", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        if(PlayerData[playerid][pFaction] != FACTION_RAR && PlayerData[playerid][pFaction] != FACTION_POLICE)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You are not part of the Registrul Auto Roman or Politia Romana."), 1;

        new bool:isPolice = (PlayerData[playerid][pFaction] == FACTION_POLICE);

        if(isPolice && PlayerData[playerid][pFactionRank] < 2)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Requires rank 2 or higher."), 1;
        if(!isPolice && PlayerData[playerid][pFactionRank] < 3)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Requires rank 3 or higher."), 1;

        if(!PlayerData[playerid][pOnDuty])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be on-duty to use this command."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new subStart = idx;
        while(cmdtext[idx] > ' ') idx++;
        new sub[10];
        strmid(sub, cmdtext, subStart, idx, 10);
        while(cmdtext[idx] == ' ') idx++;

        // ---- Police: /confiscate licence [A/B/C/D/all] [playerid] ----
        if(isPolice && strcmp(sub, "licence", true) == 0)
        {
            new lp1[8], lp2[8];
            strmid(lp1, cmdtext, idx, strlen(cmdtext), 8);
            while(cmdtext[idx] > ' ') idx++;
            while(cmdtext[idx] == ' ') idx++;
            strmid(lp2, cmdtext, idx, strlen(cmdtext), 8);

            if(!strlen(lp1) || !strlen(lp2))
                return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/confiscate licence [A/B/C/D/all] [playerid]"C_WHITE"."), 1;

            new targetid = strval(lp2);
            if(!IsPlayerConnected(targetid) || !PlayerData[targetid][pLogged])
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"The player is not connected."), 1;

            new Float:lx, Float:ly, Float:lz;
            GetPlayerPos(playerid, lx, ly, lz);
            if(!IsPlayerInRangeOfPoint(targetid, FINE_RANGE, lx, ly, lz))
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"The player must be within 15m."), 1;

            new lq[256], catLabel[8];

            if(strcmp(lp1, "all", true) == 0)
            {
                PlayerData[targetid][pDrivingLicA_exp][0] = EOS;
                PlayerData[targetid][pDrivingLicB_exp][0] = EOS;
                PlayerData[targetid][pDrivingLicC_exp][0] = EOS;
                PlayerData[targetid][pDrivingLicD_exp][0] = EOS;

                mysql_format(g_SQL, lq, sizeof(lq),
                    "UPDATE `players` SET `driving_lic_a_exp`=NULL, `driving_lic_b_exp`=NULL, `driving_lic_c_exp`=NULL, `driving_lic_d_exp`=NULL WHERE `id`=%d",
                    PlayerData[targetid][pID]);
                format(catLabel, sizeof(catLabel), "ALL");
            }
            else if(strcmp(lp1, "A", true) == 0)
            {
                PlayerData[targetid][pDrivingLicA_exp][0] = EOS;
                mysql_format(g_SQL, lq, sizeof(lq), "UPDATE `players` SET `driving_lic_a_exp`=NULL WHERE `id`=%d", PlayerData[targetid][pID]);
                format(catLabel, sizeof(catLabel), "A");
            }
            else if(strcmp(lp1, "B", true) == 0)
            {
                PlayerData[targetid][pDrivingLicB_exp][0] = EOS;
                mysql_format(g_SQL, lq, sizeof(lq), "UPDATE `players` SET `driving_lic_b_exp`=NULL WHERE `id`=%d", PlayerData[targetid][pID]);
                format(catLabel, sizeof(catLabel), "B");
            }
            else if(strcmp(lp1, "C", true) == 0)
            {
                PlayerData[targetid][pDrivingLicC_exp][0] = EOS;
                mysql_format(g_SQL, lq, sizeof(lq), "UPDATE `players` SET `driving_lic_c_exp`=NULL WHERE `id`=%d", PlayerData[targetid][pID]);
                format(catLabel, sizeof(catLabel), "C");
            }
            else if(strcmp(lp1, "D", true) == 0)
            {
                PlayerData[targetid][pDrivingLicD_exp][0] = EOS;
                mysql_format(g_SQL, lq, sizeof(lq), "UPDATE `players` SET `driving_lic_d_exp`=NULL WHERE `id`=%d", PlayerData[targetid][pID]);
                format(catLabel, sizeof(catLabel), "D");
            }
            else
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Invalid category. Use A, B, C, D or all."), 1;

            mysql_tquery(g_SQL, lq, "", "", 0);

            new lcmsg[160];
            format(lcmsg, sizeof(lcmsg), C_SUCCESS"Success: "C_WHITE"You confiscated "C_INFO"%s"C_WHITE"'s category "C_INFO"%s"C_WHITE" driving license.",
                PlayerData[targetid][pName], catLabel);
            SendClientMessage(playerid, COLOR_SUCCESS, lcmsg);

            format(lcmsg, sizeof(lcmsg), C_ERROR"Error: "C_WHITE"Your category "C_INFO"%s"C_WHITE" driving license was confiscated by "C_INFO"%s"C_WHITE".",
                catLabel, PlayerData[playerid][pName]);
            SendClientMessage(targetid, COLOR_ERROR, lcmsg);
            return 1;
        }

        new p1[8];
        strmid(p1, cmdtext, idx, strlen(cmdtext), 8);

        new bool:validSub = isPolice
            ? (strcmp(sub, "insurance", true) == 0)
            : (strcmp(sub, "extinctor", true) == 0 || strcmp(sub, "medkit", true) == 0 || strcmp(sub, "itp", true) == 0);

        if(!validSub || !strlen(p1))
        {
            new umsg[96];
            format(umsg, sizeof(umsg), C_INFO"Info: "C_WHITE"Use "C_INFO"%s"C_WHITE".",
                isPolice ? "/confiscate [insurance [playerid] / licence [A/B/C/D/all] [playerid]]" : "/confiscate [extinctor/medkit/itp] [playerid]");
            return SendClientMessage(playerid, COLOR_INFO, umsg), 1;
        }

        new targetid = strval(p1);
        if(!IsPlayerConnected(targetid) || !PlayerData[targetid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"The player is not connected."), 1;

        new Float:px, Float:py, Float:pz;
        GetPlayerPos(playerid, px, py, pz);
        if(!IsPlayerInRangeOfPoint(targetid, FINE_RANGE, px, py, pz))
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"The player must be within 15m."), 1;

        new vehid = GetPlayerVehicleID(targetid);
        if(vehid == 0)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"The player is not in a vehicle."), 1;

        new engine, lights, alarm, doors, bonnet, boot, objective;
        GetVehicleParamsEx(vehid, engine, lights, alarm, doors, bonnet, boot, objective);
        if(engine)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"The vehicle's engine must be off to do this."), 1;

        new pvidx = g_VehicleToPVIndex[vehid];
        if(pvidx == -1)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"This vehicle is not a registered personal vehicle."), 1;

        new docName[24], docColumn[24], expTs;
        if(strcmp(sub, "extinctor", true) == 0)
        {
            PVehicleData[pvidx][pvExtinguisherExp] = gettime();
            expTs = PVehicleData[pvidx][pvExtinguisherExp];
            format(docName, sizeof(docName), "fire extinguisher");
            format(docColumn, sizeof(docColumn), "extinguisher_exp");
        }
        else if(strcmp(sub, "medkit", true) == 0)
        {
            PVehicleData[pvidx][pvMedkitExp] = gettime();
            expTs = PVehicleData[pvidx][pvMedkitExp];
            format(docName, sizeof(docName), "medical kit");
            format(docColumn, sizeof(docColumn), "medkit_exp");
        }
        else if(strcmp(sub, "insurance", true) == 0)
        {
            PVehicleData[pvidx][pvInsuranceExp] = gettime();
            expTs = PVehicleData[pvidx][pvInsuranceExp];
            format(docName, sizeof(docName), "insurance");
            format(docColumn, sizeof(docColumn), "insurance_exp");
        }
        else
        {
            PVehicleData[pvidx][pvITPExp] = gettime();
            expTs = PVehicleData[pvidx][pvITPExp];
            format(docName, sizeof(docName), "ITP");
            format(docColumn, sizeof(docColumn), "itp_exp");
        }

        new dateStr[11];
        UnixToDateStr(expTs, dateStr, sizeof(dateStr));

        new q[128];
        mysql_format(g_SQL, q, sizeof(q), "UPDATE `vehicles_personal` SET `%s`='%s' WHERE `id`=%d",
            docColumn, dateStr, PVehicleData[pvidx][pvID]);
        mysql_tquery(g_SQL, q, "", "", 0);

        new cmsg[160];
        format(cmsg, sizeof(cmsg), C_SUCCESS"Success: "C_WHITE"You confiscated "C_INFO"%s"C_WHITE"'s %s document.",
            PlayerData[targetid][pName], docName);
        SendClientMessage(playerid, COLOR_SUCCESS, cmsg);

        format(cmsg, sizeof(cmsg), C_ERROR"Error: "C_WHITE"Your %s document was confiscated by "C_INFO"%s"C_WHITE".",
            docName, PlayerData[playerid][pName]);
        SendClientMessage(targetid, COLOR_ERROR, cmsg);
        return 1;
    }

    // ---- /fine [playerid] [amount] [reason] ----
    if(strcmp(cmd, "/fine", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        if(PlayerData[playerid][pFaction] != FACTION_RAR && PlayerData[playerid][pFaction] != FACTION_POLICE)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You are not part of the Registrul Auto Roman or Politia Romana."), 1;

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
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"The player must be within 15m."), 1;

        g_PendingFineAmount[targetid]  = amount;
        g_PendingFineOfficer[targetid] = playerid;
        format(g_PendingFineReason[targetid], 128, "%s", reason);

        new fmsg[300];
        format(fmsg, sizeof(fmsg), C_SUCCESS"Success: "C_WHITE"You issued a "C_INFO"$%s"C_WHITE" fine to "C_INFO"%s"C_WHITE" for: "C_INFO"%s"C_WHITE". Waiting for them to accept.",
            MoneyStr(amount), PlayerData[targetid][pName], reason);
        SendClientMessage(playerid, COLOR_SUCCESS, fmsg);

        new fTag[16];
        if(PlayerData[playerid][pFaction] == FACTION_RAR)
            format(fTag, sizeof(fTag), "[RAR] ");
        else
            format(fTag, sizeof(fTag), "[Police] ");

        format(fmsg, sizeof(fmsg),
            C_ERROR"%s"C_WHITE"Officer "C_INFO"%s"C_WHITE" fined you "C_INFO"$%s"C_WHITE" for: "C_INFO"%s"C_WHITE". Type "C_INFO"/accept fine %d"C_WHITE" to accept it.",
            fTag, PlayerData[playerid][pName], MoneyStr(amount), reason, playerid);
        printf("[DEBUG /fine] targetid=%d connected=%d logged=%d len=%d msg=%s",
            targetid, IsPlayerConnected(targetid), PlayerData[targetid][pLogged], strlen(fmsg), fmsg);
        SendClientMessage(targetid, COLOR_ERROR, fmsg);
        return 1;
    }

    // ---- /m [playerid] ----
    if(strcmp(cmd, "/m", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        if(PlayerData[playerid][pFaction] != FACTION_RAR && PlayerData[playerid][pFaction] != FACTION_POLICE)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You are not part of the Registrul Auto Roman or Politia Romana."), 1;

        if(!PlayerData[playerid][pOnDuty])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be on-duty to use this command."), 1;

        new myVehid = GetPlayerVehicleID(playerid);
        if(myVehid == 0 || g_VehicleFactionOwner[myVehid] != PlayerData[playerid][pFaction])
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

        new fTag[16];
        if(PlayerData[playerid][pFaction] == FACTION_RAR)
            format(fTag, sizeof(fTag), "[RAR] ");
        else
            format(fTag, sizeof(fTag), "[Police] ");

        new mmsg[160];
        format(mmsg, sizeof(mmsg),
            C_ERROR"%s"C_WHITE"Officer "C_INFO"%s"C_WHITE" orders you to pull over: stop the car and remain inside the vehicle.",
            fTag, PlayerData[playerid][pName]);
        SendClientMessage(targetid, COLOR_ERROR, mmsg);

        format(mmsg, sizeof(mmsg), C_SUCCESS"Success: "C_INFO"%s"C_WHITE" has received your order to pull over.", PlayerData[targetid][pName]);
        SendClientMessage(playerid, COLOR_SUCCESS, mmsg);
        return 1;
    }

    // ---- /radar [install/remove] [speedLimit - doar pentru install] ----
    if(strcmp(cmd, "/radar", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        if(PlayerData[playerid][pFaction] != FACTION_POLICE)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You are not part of the Politia Romana."), 1;

        if(PlayerData[playerid][pFactionRank] < 2)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Requires rank 2 or higher."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new subStart = idx;
        while(cmdtext[idx] > ' ') idx++;
        new sub[8];
        strmid(sub, cmdtext, subStart, idx, 8);
        while(cmdtext[idx] == ' ') idx++;
        new p1[8];
        strmid(p1, cmdtext, idx, strlen(cmdtext), 8);

        if(strcmp(sub, "install", true) == 0)
        {
            if(g_RadarActive[playerid])
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You already have a radar installed. Use "C_INFO"/radar remove"C_WHITE" first."), 1;

            if(!strlen(p1))
                return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/radar install [speedLimit]"C_WHITE"."), 1;

            new speedLimit = strval(p1);
            if(speedLimit <= 0)
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Invalid speed limit."), 1;

            GetPlayerPos(playerid, g_RadarX[playerid], g_RadarY[playerid], g_RadarZ[playerid]);
            g_RadarSpeedLimit[playerid] = speedLimit;
            g_RadarActive[playerid]     = true;

            new Float:radarAngle;
            GetPlayerFacingAngle(playerid, radarAngle);

            Radar_DestroyProps(playerid);
            g_RadarObject[playerid] = CreateObject(RADAR_OBJECT_MODEL,
                g_RadarX[playerid] + 1.0, g_RadarY[playerid], g_RadarZ[playerid] - 1.0, 0.0, 0.0, radarAngle);

            new label[64];
            format(label, sizeof(label), "[ Radar %s ]\n[ Speed max: %d km/h ]", PlayerData[playerid][pName], speedLimit);
            g_RadarLabel[playerid] = Create3DTextLabel(label, COLOR_WHITE,
                g_RadarX[playerid], g_RadarY[playerid], g_RadarZ[playerid] - 1.0, 10.0, 0, 0);

            new imsg[128];
            format(imsg, sizeof(imsg), C_SUCCESS"Success: "C_WHITE"Radar camera installed with a "C_INFO"%d km/h"C_WHITE" speed limit.", speedLimit);
            SendClientMessage(playerid, COLOR_SUCCESS, imsg);

            new fmsg[160];
            format(fmsg, sizeof(fmsg), C_INFO"[Police] "C_WHITE"Officer "C_INFO"%s"C_WHITE" has activated the radar. Speed limit set: "C_INFO"%d km/h"C_WHITE".",
                PlayerData[playerid][pName], speedLimit);
            for(new i = 0; i < MAX_PLAYERS; i++)
            {
                if(IsPlayerConnected(i) && PlayerData[i][pLogged] && PlayerData[i][pFaction] == FACTION_POLICE)
                    SendClientMessage(i, COLOR_WHITE, fmsg);
            }
            return 1;
        }

        if(strcmp(sub, "remove", true) == 0)
        {
            if(!g_RadarActive[playerid])
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have an installed radar."), 1;

            g_RadarActive[playerid] = false;
            Radar_DestroyProps(playerid);

            SendClientMessage(playerid, COLOR_SUCCESS, C_SUCCESS"Success: "C_WHITE"Radar camera removed.");
            return 1;
        }

        return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/radar [install/remove] [speedLimit]"C_WHITE"."), 1;
    }

    // ---- /showradars ----
    if(strcmp(cmd, "/showradars", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        new bool:isPoliceRank4 = (PlayerData[playerid][pFaction] == FACTION_POLICE && PlayerData[playerid][pFactionRank] >= 4);
        if(PlayerData[playerid][pAdminLevel] < 1 && !isPoliceRank4)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have access. Requires Police rank 4+ or admin level 1."), 1;

        new list[1024], any = 0;
        strcat(list, "RadarID\tOfficer\tSpeed Limit\tDistance\n");
        for(new i = 0; i < MAX_PLAYERS; i++)
        {
            if(!g_RadarActive[i]) continue;

            new line[112];
            format(line, sizeof(line), "%d\t%s\t%d km/h\t%dm\n",
                i, PlayerData[i][pName], g_RadarSpeedLimit[i],
                floatround(GetPlayerDistanceFromPoint(playerid, g_RadarX[i], g_RadarY[i], g_RadarZ[i])));
            strcat(list, line);
            any++;
        }

        if(!any)
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"There are no active radars right now."), 1;

        ShowPlayerDialog(playerid, DIALOG_RADAR_LIST, DIALOG_STYLE_TABLIST_HEADERS, "Active Radars", list, "Close", "");
        return 1;
    }

    // ---- /removeradar [radarid] ----
    if(strcmp(cmd, "/removeradar", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        new bool:isPoliceRank4 = (PlayerData[playerid][pFaction] == FACTION_POLICE && PlayerData[playerid][pFactionRank] >= 4);
        if(PlayerData[playerid][pAdminLevel] < 1 && !isPoliceRank4)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have access. Requires Police rank 4+ or admin level 1."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new p1[8];
        strmid(p1, cmdtext, idx, strlen(cmdtext), 8);

        if(!strlen(p1))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/removeradar [radarid]"C_WHITE". See "C_INFO"/showradars"C_WHITE" for IDs."), 1;

        new radarid = strval(p1);
        if(radarid < 0 || radarid >= MAX_PLAYERS || !g_RadarActive[radarid])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"There is no active radar with that ID."), 1;

        new ownerName[24];
        format(ownerName, sizeof(ownerName), "%s", PlayerData[radarid][pName]);

        g_RadarActive[radarid]     = false;
        g_RadarSpeedLimit[radarid] = 0;
        g_RadarX[radarid]          = 0.0;
        g_RadarY[radarid]          = 0.0;
        g_RadarZ[radarid]          = 0.0;
        Radar_DestroyProps(radarid);

        new rmsg[128];
        format(rmsg, sizeof(rmsg), C_SUCCESS"[ADM]Success: "C_WHITE"Removed "C_INFO"%s"C_WHITE"'s radar (ID "C_INFO"%d"C_WHITE").", ownerName, radarid);
        SendClientMessage(playerid, COLOR_SUCCESS, rmsg);

        if(IsPlayerConnected(radarid) && radarid != playerid)
        {
            new omsg[128];
            format(omsg, sizeof(omsg), C_ERROR"Error: "C_WHITE"Your radar was removed by "C_INFO"%s"C_WHITE".", PlayerData[playerid][pName]);
            SendClientMessage(radarid, COLOR_ERROR, omsg);
        }
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

    // ---- /businesslist ----
    if(strcmp(cmd, "/businesslist", true) == 0)
    {
        if(PlayerData[playerid][pAdminLevel] < 1)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have access. Requires admin level 1."), 1;

        new list[4096];
        strcat(list, "ID\tName\tOwner\tPrice\n");
        for(new i = 0; i < g_BusinessCount; i++)
        {
            new owner[24];
            if(BusinessData[i][bOwned]) format(owner, sizeof(owner), "%s", BusinessData[i][bOwner]);
            else format(owner, sizeof(owner), "-");

            new line[160];
            format(line, sizeof(line), "%d\t%s\t%s\t$%s\n",
                BusinessData[i][bID], BusinessData[i][bName], owner,
                MoneyStr(BusinessData[i][bPrice]));
            strcat(list, line);
        }

        ShowPlayerDialog(playerid, DIALOG_BUSINESS_LIST, DIALOG_STYLE_TABLIST_HEADERS, "Business List", list, "Close", "");
        return 1;
    }

    // ---- /bizzlist (lista business-uri cu teleport, admin 2+) ----
    if(strcmp(cmd, "/bizzlist", true) == 0)
    {
        if(PlayerData[playerid][pAdminLevel] < 2)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have access. Requires admin level 2."), 1;

        if(g_BusinessCount == 0)
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"There are no businesses on the server."), 1;

        new list[4096];
        for(new i = 0; i < g_BusinessCount; i++)
        {
            new bizState[24];
            if(BusinessData[i][bOwned]) format(bizState, sizeof(bizState), "%s", BusinessData[i][bOwner]);
            else format(bizState, sizeof(bizState), "For Sale");

            new line[160];
            format(line, sizeof(line), "#%d. %s - %s - $%s\n",
                BusinessData[i][bID], BusinessData[i][bName], bizState, MoneyStr(BusinessData[i][bPrice]));
            strcat(list, line);
        }

        ShowPlayerDialog(playerid, DIALOG_BIZZLIST, DIALOG_STYLE_LIST, "Business List", list, "Teleport", "Close");
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

    // ---- /gotoloc [locatie] ----
    if(strcmp(cmd, "/gotoloc", true) == 0)
    {
        if(PlayerData[playerid][pAdminLevel] < 2)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have access. Requires admin level 2."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new locname[32];
        strmid(locname, cmdtext, idx, strlen(cmdtext), 32);

        if(!strlen(locname))
        {
            SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/gotoloc [location]"C_WHITE". Available locations:");

            new locList[512];
            for(new i = 0; i < g_LocationCount; i++)
            {
                if(i > 0) strcat(locList, ", ");
                strcat(locList, LocationData[i][locName]);
            }

            if(!g_LocationCount)
                SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"No locations are available.");
            else
                SendClientMessage(playerid, COLOR_WHITE, locList);
            return 1;
        }

        new lidx = Locations_FindByName(locname);
        if(lidx == -1)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Unknown location."), 1;

        if(GetPlayerVehicleID(playerid) != 0)
            SetVehiclePos(GetPlayerVehicleID(playerid), LocationData[lidx][locX], LocationData[lidx][locY], LocationData[lidx][locZ] + 0.1);
        else
            SetPlayerPos(playerid, LocationData[lidx][locX], LocationData[lidx][locY], LocationData[lidx][locZ] + 0.1);

        new lmsg[96];
        format(lmsg, sizeof(lmsg), C_SUCCESS"[ADM]Success: "C_WHITE"Teleported to "C_INFO"%s"C_WHITE".", LocationData[lidx][locName]);
        SendClientMessage(playerid, COLOR_SUCCESS, lmsg);
        return 1;
    }

    // ---- /gotoxyz [x] [y] [z] ----
    if(strcmp(cmd, "/gotoxyz", true) == 0)
    {
        if(PlayerData[playerid][pAdminLevel] < 3)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have access. Requires admin level 3."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new gxp1[16], gxp2[16], gxp3[16];
        strmid(gxp1, cmdtext, idx, strlen(cmdtext), 16);
        while(cmdtext[idx] > ' ') idx++;
        while(cmdtext[idx] == ' ') idx++;
        strmid(gxp2, cmdtext, idx, strlen(cmdtext), 16);
        while(cmdtext[idx] > ' ') idx++;
        while(cmdtext[idx] == ' ') idx++;
        strmid(gxp3, cmdtext, idx, strlen(cmdtext), 16);

        if(!strlen(gxp1) || !strlen(gxp2) || !strlen(gxp3))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/gotoxyz [x] [y] [z]"C_WHITE"."), 1;

        new Float:gx = floatstr(gxp1);
        new Float:gy = floatstr(gxp2);
        new Float:gz = floatstr(gxp3);

        if(GetPlayerVehicleID(playerid) != 0)
            SetVehiclePos(GetPlayerVehicleID(playerid), gx, gy, gz);
        else
            SetPlayerPos(playerid, gx, gy, gz);

        new gxmsg[96];
        format(gxmsg, sizeof(gxmsg), C_SUCCESS"[ADM]Success: "C_WHITE"Teleported to "C_INFO"%.4f, %.4f, %.4f"C_WHITE".", gx, gy, gz);
        SendClientMessage(playerid, COLOR_SUCCESS, gxmsg);
        return 1;
    }

    // ---- /gotobiz [biz_id] ----
    if(strcmp(cmd, "/gotobiz", true) == 0)
    {
        if(PlayerData[playerid][pAdminLevel] < 2)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have access. Requires admin level 2."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new p1[8];
        strmid(p1, cmdtext, idx, strlen(cmdtext), 8);

        if(!strlen(p1))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/gotobiz [biz_id]"C_WHITE"."), 1;

        new bidx = Businesses_FindByID(strval(p1));
        if(bidx == -1)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Unknown business ID."), 1;

        if(GetPlayerVehicleID(playerid) != 0)
            SetVehiclePos(GetPlayerVehicleID(playerid), BusinessData[bidx][bLocX], BusinessData[bidx][bLocY], BusinessData[bidx][bLocZ] + 0.1);
        else
            SetPlayerPos(playerid, BusinessData[bidx][bLocX], BusinessData[bidx][bLocY], BusinessData[bidx][bLocZ] + 0.1);

        new bmsg[96];
        format(bmsg, sizeof(bmsg), C_SUCCESS"[ADM]Success: "C_WHITE"Teleported to business "C_INFO"%s"C_WHITE".", BusinessData[bidx][bName]);
        SendClientMessage(playerid, COLOR_SUCCESS, bmsg);
        return 1;
    }

    // ---- /gotohouse [house_id] ----
    if(strcmp(cmd, "/gotohouse", true) == 0)
    {
        if(PlayerData[playerid][pAdminLevel] < 2)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have access. Requires admin level 2."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new p1[8];
        strmid(p1, cmdtext, idx, strlen(cmdtext), 8);

        if(!strlen(p1))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/gotohouse [house_id]"C_WHITE"."), 1;

        new hidx = Houses_FindByID(strval(p1));
        if(hidx == -1)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Unknown house ID."), 1;

        if(GetPlayerVehicleID(playerid) != 0)
            SetVehiclePos(GetPlayerVehicleID(playerid), HouseData[hidx][hLocX], HouseData[hidx][hLocY], HouseData[hidx][hLocZ] + 0.1);
        else
            SetPlayerPos(playerid, HouseData[hidx][hLocX], HouseData[hidx][hLocY], HouseData[hidx][hLocZ] + 0.1);

        new hmsg[96];
        format(hmsg, sizeof(hmsg), C_SUCCESS"[ADM]Success: "C_WHITE"Teleported to house "C_INFO"%s"C_WHITE".", HouseData[hidx][hName]);
        SendClientMessage(playerid, COLOR_SUCCESS, hmsg);
        return 1;
    }

    // ---- /gotofaction [faction_id] ----
    if(strcmp(cmd, "/gotofaction", true) == 0)
    {
        if(PlayerData[playerid][pAdminLevel] < 2)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have access. Requires admin level 2."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new p1[8];
        strmid(p1, cmdtext, idx, strlen(cmdtext), 8);

        if(!strlen(p1))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/gotofaction [faction_id]"C_WHITE"."), 1;

        new fid = strval(p1);
        if(fid < 1 || fid > MAX_FACTIONS)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Invalid faction ID (1-7)."), 1;

        if(FactionData[fid][fHQX] == 0.0 && FactionData[fid][fHQY] == 0.0)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"This faction doesn't have a HQ set."), 1;

        if(GetPlayerVehicleID(playerid) != 0)
            SetVehiclePos(GetPlayerVehicleID(playerid), FactionData[fid][fHQX], FactionData[fid][fHQY], FactionData[fid][fHQZ] + 0.1);
        else
            SetPlayerPos(playerid, FactionData[fid][fHQX], FactionData[fid][fHQY], FactionData[fid][fHQZ] + 0.1);

        new fmsg[96];
        format(fmsg, sizeof(fmsg), C_SUCCESS"[ADM]Success: "C_WHITE"Teleported to "C_INFO"%s"C_WHITE" HQ.", FactionData[fid][fName]);
        SendClientMessage(playerid, COLOR_SUCCESS, fmsg);
        return 1;
    }

    // ---- /goto [playerid] ----
    if(strcmp(cmd, "/goto", true) == 0)
    {
        if(PlayerData[playerid][pAdminLevel] < 2)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have access. Requires admin level 2."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new p1[8];
        strmid(p1, cmdtext, idx, strlen(cmdtext), 8);

        if(!strlen(p1))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/goto [playerid]"C_WHITE"."), 1;

        new targetid = strval(p1);
        if(!IsPlayerConnected(targetid) || !PlayerData[targetid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"The player is not connected."), 1;

        if(targetid == playerid)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You can't teleport to yourself."), 1;

        new Float:tx, Float:ty, Float:tz;
        GetPlayerPos(targetid, tx, ty, tz);

        if(GetPlayerVehicleID(playerid) != 0)
            SetVehiclePos(GetPlayerVehicleID(playerid), tx, ty, tz + 0.1);
        else
            SetPlayerPos(playerid, tx, ty, tz + 0.1);

        SetPlayerVirtualWorld(playerid, GetPlayerVirtualWorld(targetid));
        SetPlayerInterior(playerid, GetPlayerInterior(targetid));

        new gmsg[96];
        format(gmsg, sizeof(gmsg), C_SUCCESS"[ADM]Success: "C_WHITE"Teleported to "C_INFO"%s"C_WHITE".", PlayerData[targetid][pName]);
        SendClientMessage(playerid, COLOR_SUCCESS, gmsg);
        return 1;
    }

    // ---- /setinterior [playerid] [interiorid] ----
    if(strcmp(cmd, "/setinterior", true) == 0)
    {
        if(PlayerData[playerid][pAdminLevel] < 1)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have access. Requires admin level 1."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new si1[8], si2[8];
        strmid(si1, cmdtext, idx, strlen(cmdtext), 8);
        while(cmdtext[idx] > ' ') idx++;
        while(cmdtext[idx] == ' ') idx++;
        strmid(si2, cmdtext, idx, strlen(cmdtext), 8);

        if(!strlen(si1) || !strlen(si2))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/setinterior [playerid] [interiorid]"C_WHITE"."), 1;

        new targetid = strval(si1);
        if(!IsPlayerConnected(targetid) || !PlayerData[targetid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"The player is not connected."), 1;

        new interiorid = strval(si2);
        SetPlayerInterior(targetid, interiorid);

        new smsg[96];
        format(smsg, sizeof(smsg), C_SUCCESS"[ADM]Success: "C_WHITE"Set "C_INFO"%s"C_WHITE"'s interior to "C_INFO"%d"C_WHITE".",
            PlayerData[targetid][pName], interiorid);
        SendClientMessage(playerid, COLOR_SUCCESS, smsg);

        if(targetid != playerid)
        {
            new tmsg[96];
            format(tmsg, sizeof(tmsg), C_INFO"Info: "C_WHITE"An admin set your interior to "C_INFO"%d"C_WHITE".", interiorid);
            SendClientMessage(targetid, COLOR_INFO, tmsg);
        }
        return 1;
    }

    // ---- /setvirtualworld | /setvw [playerid] [vw_id] ----
    if(strcmp(cmd, "/setvirtualworld", true) == 0 || strcmp(cmd, "/setvw", true) == 0)
    {
        if(PlayerData[playerid][pAdminLevel] < 1)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have access. Requires admin level 1."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new sv1[8], sv2[8];
        strmid(sv1, cmdtext, idx, strlen(cmdtext), 8);
        while(cmdtext[idx] > ' ') idx++;
        while(cmdtext[idx] == ' ') idx++;
        strmid(sv2, cmdtext, idx, strlen(cmdtext), 8);

        if(!strlen(sv1) || !strlen(sv2))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/setvw [playerid] [vw_id]"C_WHITE"."), 1;

        new targetid = strval(sv1);
        if(!IsPlayerConnected(targetid) || !PlayerData[targetid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"The player is not connected."), 1;

        new vwid = strval(sv2);
        SetPlayerVirtualWorld(targetid, vwid);

        new smsg[96];
        format(smsg, sizeof(smsg), C_SUCCESS"[ADM]Success: "C_WHITE"Set "C_INFO"%s"C_WHITE"'s virtual world to "C_INFO"%d"C_WHITE".",
            PlayerData[targetid][pName], vwid);
        SendClientMessage(playerid, COLOR_SUCCESS, smsg);

        if(targetid != playerid)
        {
            new tmsg[96];
            format(tmsg, sizeof(tmsg), C_INFO"Info: "C_WHITE"An admin set your virtual world to "C_INFO"%d"C_WHITE".", vwid);
            SendClientMessage(targetid, COLOR_INFO, tmsg);
        }
        return 1;
    }

    // ---- /help ----
    if(strcmp(cmd, "/help", true) == 0)
    {
        SendClientMessage(playerid, COLOR_INFO, C_INFO"===== Player Commands =================");

        SendClientMessage(playerid, COLOR_WHITE, C_INFO"[Account] "C_WHITE"/register /login /stats /help");
        SendClientMessage(playerid, COLOR_WHITE, C_INFO"[Other] "C_WHITE"/cspawn /accept /fhelp /rentcat /rentbike /curedisease");
        SendClientMessage(playerid, COLOR_WHITE, C_INFO"[Houses] "C_WHITE"/buyhouse /sellhouse");
        SendClientMessage(playerid, COLOR_WHITE,
            C_INFO"[Vehicles] "C_WHITE"[Vehicles] /vstats /vbuy /vsell /vpark /vsellto /vcolor /vplate");
        SendClientMessage(playerid, COLOR_WHITE,
            C_INFO"[Vehicles] "C_WHITE"[Vehicles] /vInsurance /vMedicalKit /vExtinctor /vITP /vstats");
        SendClientMessage(playerid, COLOR_WHITE, C_INFO"[Licenses] "C_WHITE"/licenses /examA /examB /examC /examD");
        SendClientMessage(playerid, COLOR_WHITE, C_INFO"[Business] "C_WHITE"/buyBiz /sellBiz /bBank /bWithdraw");
        SendClientMessage(playerid, COLOR_WHITE, C_INFO"[Caravan] "C_WHITE"/attach /detach /camp /findmycaravan");

        SendClientMessage(playerid, COLOR_INFO, C_INFO"========================================");
        return 1;
    }

    // ---- /ahelp ----
    if(strcmp(cmd, "/ahelp", true) == 0)
    {
        new alv = PlayerData[playerid][pAdminLevel];
        if(alv < 1)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have access to admin commands."), 1;

        SendClientMessage(playerid, COLOR_INFO, C_INFO"===== Admin Commands ==========================================");

        if(alv >= 1)
            SendClientMessage(playerid, COLOR_WHITE, C_INFO"[1] "C_WHITE"/ahelp /respawn /aheal /businesslist /showradars /removeradar /fixcar /flipcar /setInterior /setVw");
        if(alv >= 2)
            SendClientMessage(playerid, COLOR_WHITE, C_INFO"[2] "C_WHITE"/createFire /healall /gotoLoc /gotoBiz /gotoHouse /gotoFaction /goto /bizzlist /openGolfTournament /startGolf");
        if(alv >= 3)
        {
            SendClientMessage(playerid, COLOR_WHITE, C_INFO"[3] "C_WHITE"/veh /rac /createDisease");
            SendClientMessage(playerid, COLOR_WHITE,
                C_INFO"[3] [DrivingLic] "C_WHITE"/setDrivingLicAexp /setDrivingLicBexp /setDrivingLicCexp /setDrivingLicDexp");
        }
        if(alv >= 4)
            SendClientMessage(playerid, COLOR_WHITE, C_INFO"[4] [Turfs] "C_WHITE"/forcewar [turf_id] [attacker_faction_id] [defender_faction_id]");
        if(alv >= 5)
        {
            SendClientMessage(playerid, COLOR_WHITE, C_INFO"[5] "C_WHITE"/payday");
            SendClientMessage(playerid, COLOR_WHITE,
                C_INFO"[5] [PVehicles] "C_WHITE"/vchangeINSURANCEexp /vchangeMEDKITexp /vchangeEXTINCTORexp /vchangeITPexp");
        }
        if(alv >= 6)
        {
            SendClientMessage(playerid, COLOR_WHITE, C_INFO"[6] [Factions] "C_WHITE"/changeFaction[HQ/hqIcon/Pickup/Lead/Veh/InteriorLoc/interior/vw] /removeFactionLead");
            SendClientMessage(playerid, COLOR_WHITE, C_INFO"[6] [Houses] "C_WHITE"/createHouse /changeHousePrice /changeHouseOwner /changeHouseLoc");
            SendClientMessage(playerid, COLOR_WHITE, C_INFO"[6] [PVehicles] "C_WHITE"/vCreate /vSetPrice");
            SendClientMessage(playerid, COLOR_WHITE, C_INFO"[6] [Caravans] "C_WHITE"/createCaravan");
            SendClientMessage(playerid, COLOR_WHITE, C_INFO"[6] [Business] "C_WHITE"/createBiz /changeBizName /changeBizPrice /changeBizLoc");
            SendClientMessage(playerid, COLOR_WHITE, C_INFO"[6] [Basket] "C_WHITE"/setbballspawn [hoop_id] [spawn_id]");
        }

        SendClientMessage(playerid, COLOR_INFO, C_INFO"=============================================================");
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
        HouseData[newIdx][hType]     = 1;
        HouseData[newIdx][hMaxPets]  = 0;
        HouseData[newIdx][hPets]     = 0;
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

    // ---- /changehouseloc [id] (muta casa la pozitia ta) ----
    if(strcmp(cmd, "/changehouseloc", true) == 0)
    {
        if(PlayerData[playerid][pAdminLevel] < 6)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have access. Requires admin level 6."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new chlStr[8];
        strmid(chlStr, cmdtext, idx, strlen(cmdtext), 8);
        if(!strlen(chlStr))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/changehouseloc [id]"C_WHITE"."), 1;

        new chlIdx = Houses_FindByID(strval(chlStr));
        if(chlIdx == -1)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Invalid house ID."), 1;

        new Float:chx, Float:chy, Float:chz;
        GetPlayerPos(playerid, chx, chy, chz);

        HouseData[chlIdx][hLocX] = chx;
        HouseData[chlIdx][hLocY] = chy;
        HouseData[chlIdx][hLocZ] = chz;
        Houses_RecreatePickup(chlIdx);

        new chq[160];
        mysql_format(g_SQL, chq, sizeof(chq),
            "UPDATE `houses` SET `loc_x`=%.4f, `loc_y`=%.4f, `loc_z`=%.4f WHERE `id`=%d",
            chx, chy, chz, HouseData[chlIdx][hID]);
        mysql_tquery(g_SQL, chq, "", "", 0);

        new chmsg[128];
        format(chmsg, sizeof(chmsg),
            C_SUCCESS"Success: "C_WHITE"House "C_INFO"#%d"C_WHITE" (%s) moved to your location.",
            HouseData[chlIdx][hID], HouseData[chlIdx][hName]);
        SendClientMessage(playerid, COLOR_SUCCESS, chmsg);
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
        format(lmsg, sizeof(lmsg), C_SUCCESS"Success: "C_WHITE"You bought the house "C_INFO"%s"C_WHITE" for "C_INFO"$%s"C_WHITE".",
            HouseData[hidx][hName], MoneyStr(HouseData[hidx][hPrice]));
        SendClientMessage(playerid, COLOR_SUCCESS, lmsg);
        return 1;
    }

    // ---- /buyanimal [type] (doar pentru casa proprie de tip 1) ----
    if(strcmp(cmd, "/buyanimal", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        if(PlayerData[playerid][pHouse] == 999)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't own a house."), 1;

        new ahidx = Houses_FindByID(PlayerData[playerid][pHouse]);
        if(ahidx == -1)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Your house could not be found."), 1;

        if(HouseData[ahidx][hType] != 1)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You can only buy animals for a type 1 house."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new typeStr[8];
        strmid(typeStr, cmdtext, idx, strlen(cmdtext), 8);
        if(!strlen(typeStr))
        {
            SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/buyanimal [nr]"C_WHITE". Available animals:");
            for(new c = 0; c < sizeof(g_AnimalCatalog); c++)
            {
                new linfo[96];
                format(linfo, sizeof(linfo), C_INFO"  %d"C_WHITE" - %s ("C_INFO"$%s"C_WHITE")",
                    c + 1, g_AnimalCatalog[c][acName], MoneyStr(ANIMAL_PRICE));
                SendClientMessage(playerid, COLOR_WHITE, linfo);
            }
            return 1;
        }

        new anr = strval(typeStr);
        if(anr < 1 || anr > sizeof(g_AnimalCatalog))
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Invalid animal number. Use "C_INFO"/buyanimal"C_WHITE" to see the list."), 1;

        new acIdx = anr - 1;

        if(g_AnimalCount >= MAX_ANIMALS)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"The animal limit on the server has been reached."), 1;

        if(PlayerData[playerid][pMoney] < ANIMAL_PRICE)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have enough money."), 1;

        PlayerData[playerid][pMoney] -= ANIMAL_PRICE;
        GivePlayerMoney(playerid, -ANIMAL_PRICE);
        UpdatePlayer(playerid, pMoney);

        new aq[256];
        mysql_format(g_SQL, aq, sizeof(aq),
            "INSERT INTO `animals` (`aType`,`aPlayerID`,`aHouseID`,`aName`) VALUES (%d,%d,%d,'%e')",
            g_AnimalCatalog[acIdx][acModel], PlayerData[playerid][pID], HouseData[ahidx][hID], g_AnimalCatalog[acIdx][acName]);
        mysql_tquery(g_SQL, aq, "", "", 0);

        // Reincarca toate animalele din DB (recreeaza si obiectele) - include si noul animal
        Animals_Load();

        new amsg[128];
        format(amsg, sizeof(amsg),
            C_SUCCESS"Success: "C_WHITE"You bought a "C_INFO"%s"C_WHITE" for "C_INFO"$%s"C_WHITE". It will appear at your house.",
            g_AnimalCatalog[acIdx][acName], MoneyStr(ANIMAL_PRICE));
        SendClientMessage(playerid, COLOR_SUCCESS, amsg);
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
        format(lmsg, sizeof(lmsg), C_SUCCESS"Success: "C_WHITE"You sold the house "C_INFO"%s"C_WHITE" for "C_INFO"$%s"C_WHITE".",
            HouseData[hidx][hName], MoneyStr(price));
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
        format(lmsg, sizeof(lmsg), C_SUCCESS"Success: "C_WHITE"You bought the business (ID: "C_INFO"%d"C_WHITE") for "C_INFO"$%s"C_WHITE".",
            BusinessData[bidx][bID], MoneyStr(BusinessData[bidx][bPrice]));
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
        format(lmsg, sizeof(lmsg), C_SUCCESS"Success: "C_WHITE"You sold the business (ID: "C_INFO"%d"C_WHITE") for "C_INFO"$%s"C_WHITE".",
            BusinessData[bidx][bID], MoneyStr(refund));
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
        format(bmsg, sizeof(bmsg), C_INFO"Info: "C_WHITE"The business account (ID: "C_INFO"%d"C_WHITE") has "C_INFO"$%s"C_WHITE".",
            BusinessData[bidx][bID], MoneyStr(BusinessData[bidx][bBank]));
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
        format(wmsg, sizeof(wmsg), C_SUCCESS"Success: "C_WHITE"You withdrew "C_INFO"$%s"C_WHITE" from the business account.", MoneyStr(amount));
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
        format(lmsg, sizeof(lmsg), C_SUCCESS"[ADM]Success: "C_WHITE"The price of business (ID: "C_INFO"%d"C_WHITE") was changed to "C_INFO"$%s"C_WHITE".",
            BusinessData[bidx][bID], MoneyStr(newPrice));
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
        format(lmsg, sizeof(lmsg), C_SUCCESS"Success: "C_WHITE"You rented the bike for "C_INFO"$%s"C_WHITE".", MoneyStr(g_RentBikePrice));
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
        else if(vehid != 0 && IsRentCarVehicle2(vehid))
        {
            price = RENT_CAR2_PRICE;
            bizid = RENT_CAR2_BIZ_ID;
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
        format(lmsg, sizeof(lmsg), C_SUCCESS"Success: "C_WHITE"You rented the car for "C_INFO"$%s"C_WHITE".", MoneyStr(price));
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
            C_INFO"Info: "C_WHITE"Get into a "C_INFO"Sanchez"C_WHITE" within "C_INFO"45 seconds"C_WHITE" to start the exam.");
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
            C_INFO"Info: "C_WHITE"Get into a "C_INFO"Comet"C_WHITE" within "C_INFO"45 seconds"C_WHITE" to start the exam.");
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

        if(PlayerData[playerid][pMoney] < g_ExamCPrice)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have enough money."), 1;

        PlayerData[playerid][pMoney] -= g_ExamCPrice;
        GivePlayerMoney(playerid, -g_ExamCPrice);
        UpdatePlayer(playerid, pMoney);

        new bidx = Businesses_FindByID(EXAMC_BIZ_ID);
        if(bidx != -1)
        {
            BusinessData[bidx][bBank] += g_ExamCPrice;

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
            C_INFO"Info: "C_WHITE"Get into a "C_INFO"truck"C_WHITE" within "C_INFO"45 seconds"C_WHITE" to start the exam.");
        return 1;
    }

    // ---- /examD ----
    if(strcmp(cmd, "/examD", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        if(!IsPlayerInRangeOfPoint(playerid, EXAMD_RANGE, EXAMD_LOC_X, EXAMD_LOC_Y, EXAMD_LOC_Z))
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be at the exam location."), 1;

        if(g_ExamDState[playerid] != EXAMD_STATE_NONE)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You already have an exam in progress."), 1;

        if(PlayerData[playerid][pMoney] < g_ExamDPrice)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have enough money."), 1;

        PlayerData[playerid][pMoney] -= g_ExamDPrice;
        GivePlayerMoney(playerid, -g_ExamDPrice);
        UpdatePlayer(playerid, pMoney);

        new bidx = Businesses_FindByID(EXAMD_BIZ_ID);
        if(bidx != -1)
        {
            BusinessData[bidx][bBank] += g_ExamDPrice;

            new q[128];
            mysql_format(g_SQL, q, sizeof(q), "UPDATE `businesses` SET `bank`=%d WHERE `id`=%d",
                BusinessData[bidx][bBank], BusinessData[bidx][bID]);
            mysql_tquery(g_SQL, q, "", "", 0);
        }

        g_ExamDState[playerid]      = EXAMD_STATE_WAITING_CAR;
        g_ExamDCheckpoint[playerid] = 0;
        g_ExamDVehicle[playerid]    = -1;
        ExamD_KillTimer(playerid);
        g_ExamDTimer[playerid] = SetTimerEx("ExamD_Timeout", EXAMD_STEP_TIME, false, "i", playerid);

        SendClientMessage(playerid, COLOR_INFO,
            C_INFO"Info: "C_WHITE"Get into a "C_INFO"Bus"C_WHITE" within "C_INFO"45 seconds"C_WHITE" to start the exam.");
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
        format(lmsg, sizeof(lmsg), C_SUCCESS"[ADM]Success: "C_WHITE"The price of house "C_INFO"%s"C_WHITE" was changed to "C_INFO"$%s"C_WHITE".",
            HouseData[hidx][hName], MoneyStr(newPrice));
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

        new vbidx = Businesses_FindByID(8);
        if(vbidx != -1)
        {
            new vbCut = floatround(PVehicleData[pvidx][pvPrice] * 0.001 / 100.0);
            BusinessData[vbidx][bBank] += vbCut;

            new vbq[128];
            mysql_format(g_SQL, vbq, sizeof(vbq), "UPDATE `businesses` SET `bank`=%d WHERE `id`=%d",
                BusinessData[vbidx][bBank], BusinessData[vbidx][bID]);
            mysql_tquery(g_SQL, vbq, "", "", 0);
        }

        new lmsg[160];
        format(lmsg, sizeof(lmsg),
            C_SUCCESS"Success: "C_WHITE"You bought the vehicle (ID: "C_INFO"%d"C_WHITE") for "C_INFO"$%s"C_WHITE". \
The insurance, medkit, extinguisher and ITP are valid for "C_INFO"7 days"C_WHITE".",
            PVehicleData[pvidx][pvID], MoneyStr(PVehicleData[pvidx][pvPrice]));
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
        format(lmsg, sizeof(lmsg), C_SUCCESS"Success: "C_WHITE"You sold the vehicle (ID: "C_INFO"%d"C_WHITE") for "C_INFO"$%s"C_WHITE".",
            PVehicleData[pvidx][pvID], MoneyStr(refund));
        SendClientMessage(playerid, COLOR_SUCCESS, lmsg);
        return 1;
    }

    // ---- /lock ----
    if(strcmp(cmd, "/lock", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        new vehid = GetPlayerVehicleID(playerid);
        new pvidx;

        if(vehid != 0)
        {
            pvidx = g_VehicleToPVIndex[vehid];
            if(pvidx == -1)
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"This is not a personal vehicle."), 1;
        }
        else
        {
            new keys[MAX_PLAYER_VEHICLES];
            keys[0] = PlayerData[playerid][pKey1];
            keys[1] = PlayerData[playerid][pKey2];
            keys[2] = PlayerData[playerid][pKey3];

            pvidx = -1;
            for(new k = 0; k < MAX_PLAYER_VEHICLES; k++)
            {
                if(keys[k] == 0) continue;
                new kidx = PVehicles_FindByVID(keys[k]);
                if(kidx == -1) continue;

                new cvehid = g_PVehicleVehicle[kidx];
                if(cvehid == -1) continue;

                new Float:vx, Float:vy, Float:vz;
                GetVehiclePos(cvehid, vx, vy, vz);
                if(IsPlayerInRangeOfPoint(playerid, LOCK_RANGE, vx, vy, vz))
                {
                    vehid = cvehid;
                    pvidx = kidx;
                    break;
                }
            }

            if(vehid == 0)
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be in, or within 5m of, your personal vehicle."), 1;
        }

        if(PVehicleData[pvidx][pvOwnerId] != PlayerData[playerid][pID])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't own this vehicle."), 1;

        new engine, lights, alarm, doors, bonnet, boot, objective;
        GetVehicleParamsEx(vehid, engine, lights, alarm, doors, bonnet, boot, objective);
        doors = doors ? 0 : 1;
        SetVehicleParamsEx(vehid, engine, lights, alarm, doors, bonnet, boot, objective);

        PVehicleData[pvidx][pvLocked] = bool:doors;
        new lq[128];
        mysql_format(g_SQL, lq, sizeof(lq), "UPDATE `vehicles_personal` SET `locked`=%d WHERE `id`=%d",
            doors, PVehicleData[pvidx][pvID]);
        mysql_tquery(g_SQL, lq, "", "", 0);

        if(doors)
            SendClientMessage(playerid, COLOR_SUCCESS, C_SUCCESS"Success: "C_WHITE"Vehicle "C_INFO"locked"C_WHITE".");
        else
            SendClientMessage(playerid, COLOR_SUCCESS, C_SUCCESS"Success: "C_WHITE"Vehicle "C_INFO"unlocked"C_WHITE".");
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

        new vpEngine, vpLights, vpAlarm, vpDoors, vpBonnet, vpBoot, vpObjective;
        GetVehicleParamsEx(vehid, vpEngine, vpLights, vpAlarm, vpDoors, vpBonnet, vpBoot, vpObjective);
        if(vpEngine)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"The vehicle's engine must be off to do this."), 1;

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

        if(VehicleDoc_IsValid(PVehicleData[pvidx][pvInsuranceExp]))
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"The insurance is still valid."), 1;

        if(PlayerData[playerid][pMoney] < g_InsurancePrice)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have enough money."), 1;

        PlayerData[playerid][pMoney] -= g_InsurancePrice;
        GivePlayerMoney(playerid, -g_InsurancePrice);
        UpdatePlayer(playerid, pMoney);

        new inbidx = Businesses_FindByID(11);
        if(inbidx != -1)
        {
            BusinessData[inbidx][bBank] += g_InsurancePrice;

            new inbq[128];
            mysql_format(g_SQL, inbq, sizeof(inbq), "UPDATE `businesses` SET `bank`=%d WHERE `id`=%d",
                BusinessData[inbidx][bBank], BusinessData[inbidx][bID]);
            mysql_tquery(g_SQL, inbq, "", "", 0);
        }

        PVehicleData[pvidx][pvInsuranceExp] = gettime() + VEHICLE_INSURANCE_DURATION;

        new dateStr[11];
        UnixToDateStr(PVehicleData[pvidx][pvInsuranceExp], dateStr, sizeof(dateStr));

        new q[128];
        mysql_format(g_SQL, q, sizeof(q), "UPDATE `vehicles_personal` SET `insurance_exp`='%s' WHERE `id`=%d",
            dateStr, PVehicleData[pvidx][pvID]);
        mysql_tquery(g_SQL, q, "", "", 0);

        new lmsg[128];
        format(lmsg, sizeof(lmsg), C_SUCCESS"Success: "C_WHITE"You bought insurance ("C_INFO"5 days"C_WHITE") for "C_INFO"$%s"C_WHITE".", MoneyStr(g_InsurancePrice));
        SendClientMessage(playerid, COLOR_SUCCESS, lmsg);
        return 1;
    }

    // ---- /vmedicalkit ----
    if(strcmp(cmd, "/vmedicalkit", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        if(!MedShops_PlayerInRange(playerid))
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be at a "C_INFO"Shop"C_WHITE" to do this."), 1;

        new vehid = GetPlayerVehicleID(playerid);
        if(vehid == 0)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be in a vehicle."), 1;

        new pvidx = g_VehicleToPVIndex[vehid];
        if(pvidx == -1)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"This is not a personal vehicle."), 1;

        if(PVehicleData[pvidx][pvOwnerId] != PlayerData[playerid][pID])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't own this vehicle."), 1;

        if(VehicleDoc_IsValid(PVehicleData[pvidx][pvMedkitExp]))
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"The medical kit is still valid."), 1;

        if(PlayerData[playerid][pMoney] < g_MedkitPrice)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have enough money."), 1;

        PlayerData[playerid][pMoney] -= g_MedkitPrice;
        GivePlayerMoney(playerid, -g_MedkitPrice);
        UpdatePlayer(playerid, pMoney);

        new mkbidx = Businesses_FindByID(9);
        if(mkbidx != -1)
        {
            BusinessData[mkbidx][bBank] += g_MedkitPrice;

            new mkbq[128];
            mysql_format(g_SQL, mkbq, sizeof(mkbq), "UPDATE `businesses` SET `bank`=%d WHERE `id`=%d",
                BusinessData[mkbidx][bBank], BusinessData[mkbidx][bID]);
            mysql_tquery(g_SQL, mkbq, "", "", 0);
        }

        PVehicleData[pvidx][pvMedkitExp] = gettime() + VEHICLE_MEDKIT_DURATION;

        new dateStr[11];
        UnixToDateStr(PVehicleData[pvidx][pvMedkitExp], dateStr, sizeof(dateStr));

        new q[128];
        mysql_format(g_SQL, q, sizeof(q), "UPDATE `vehicles_personal` SET `medkit_exp`='%s' WHERE `id`=%d",
            dateStr, PVehicleData[pvidx][pvID]);
        mysql_tquery(g_SQL, q, "", "", 0);

        new lmsg[128];
        format(lmsg, sizeof(lmsg), C_SUCCESS"Success: "C_WHITE"You bought a medical kit ("C_INFO"7 days"C_WHITE") for "C_INFO"$%s"C_WHITE".", MoneyStr(g_MedkitPrice));
        SendClientMessage(playerid, COLOR_SUCCESS, lmsg);
        return 1;
    }

    // ---- /vextinctor ----
    if(strcmp(cmd, "/vextinctor", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        if(!MedShops_PlayerInRange(playerid))
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be at a "C_INFO"Shop"C_WHITE" to do this."), 1;

        new vehid = GetPlayerVehicleID(playerid);
        if(vehid == 0)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be in a vehicle."), 1;

        new pvidx = g_VehicleToPVIndex[vehid];
        if(pvidx == -1)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"This is not a personal vehicle."), 1;

        if(PVehicleData[pvidx][pvOwnerId] != PlayerData[playerid][pID])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't own this vehicle."), 1;

        if(VehicleDoc_IsValid(PVehicleData[pvidx][pvExtinguisherExp]))
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"The extinguisher is still valid."), 1;

        if(PlayerData[playerid][pMoney] < g_ExtinguisherPrice)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have enough money."), 1;

        PlayerData[playerid][pMoney] -= g_ExtinguisherPrice;
        GivePlayerMoney(playerid, -g_ExtinguisherPrice);
        UpdatePlayer(playerid, pMoney);

        new exbidx = Businesses_FindByID(10);
        if(exbidx != -1)
        {
            BusinessData[exbidx][bBank] += g_ExtinguisherPrice;

            new exbq[128];
            mysql_format(g_SQL, exbq, sizeof(exbq), "UPDATE `businesses` SET `bank`=%d WHERE `id`=%d",
                BusinessData[exbidx][bBank], BusinessData[exbidx][bID]);
            mysql_tquery(g_SQL, exbq, "", "", 0);
        }

        PVehicleData[pvidx][pvExtinguisherExp] = gettime() + VEHICLE_EXTINGUISHER_DURATION;

        new dateStr[11];
        UnixToDateStr(PVehicleData[pvidx][pvExtinguisherExp], dateStr, sizeof(dateStr));

        new q[128];
        mysql_format(g_SQL, q, sizeof(q), "UPDATE `vehicles_personal` SET `extinguisher_exp`='%s' WHERE `id`=%d",
            dateStr, PVehicleData[pvidx][pvID]);
        mysql_tquery(g_SQL, q, "", "", 0);

        new lmsg[128];
        format(lmsg, sizeof(lmsg), C_SUCCESS"Success: "C_WHITE"You bought an extinguisher ("C_INFO"10 days"C_WHITE") for "C_INFO"$%s"C_WHITE".", MoneyStr(g_ExtinguisherPrice));
        SendClientMessage(playerid, COLOR_SUCCESS, lmsg);
        return 1;
    }

    // ---- /pizza ----
    if(strcmp(cmd, "/pizza", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        if(!Pizza_PlayerInRange(playerid))
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be at a "C_INFO"Pizza"C_WHITE" location to do this."), 1;

        if(PlayerData[playerid][pMoney] < g_PizzaPrice)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have enough money."), 1;

        PlayerData[playerid][pMoney] -= g_PizzaPrice;
        GivePlayerMoney(playerid, -g_PizzaPrice);
        UpdatePlayer(playerid, pMoney);

        new pzbidx = Businesses_FindByID(PIZZA_BIZ_ID);
        if(pzbidx != -1)
        {
            BusinessData[pzbidx][bBank] += g_PizzaPrice;

            new pzbq[128];
            mysql_format(g_SQL, pzbq, sizeof(pzbq), "UPDATE `businesses` SET `bank`=%d WHERE `id`=%d",
                BusinessData[pzbidx][bBank], BusinessData[pzbidx][bID]);
            mysql_tquery(g_SQL, pzbq, "", "", 0);
        }

        new Float:health;
        GetPlayerHealth(playerid, health);
        health += PIZZA_HEAL_AMOUNT;
        if(health > 100.0) health = 100.0;
        SetPlayerHealth(playerid, health);

        new lmsg[128];
        format(lmsg, sizeof(lmsg), C_SUCCESS"Success: "C_WHITE"You bought a "C_INFO"pizza"C_WHITE" for "C_INFO"$%s"C_WHITE" (+%d HP).",
            MoneyStr(g_PizzaPrice), floatround(PIZZA_HEAL_AMOUNT));
        SendClientMessage(playerid, COLOR_SUCCESS, lmsg);
        return 1;
    }

    // ---- /burger ----
    if(strcmp(cmd, "/burger", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        if(!Burger_PlayerInRange(playerid))
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be at a "C_INFO"Burger"C_WHITE" location to do this."), 1;

        if(PlayerData[playerid][pMoney] < g_BurgerPrice)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have enough money."), 1;

        PlayerData[playerid][pMoney] -= g_BurgerPrice;
        GivePlayerMoney(playerid, -g_BurgerPrice);
        UpdatePlayer(playerid, pMoney);

        new bgbidx = Businesses_FindByID(BURGER_BIZ_ID);
        if(bgbidx != -1)
        {
            BusinessData[bgbidx][bBank] += g_BurgerPrice;

            new bgbq[128];
            mysql_format(g_SQL, bgbq, sizeof(bgbq), "UPDATE `businesses` SET `bank`=%d WHERE `id`=%d",
                BusinessData[bgbidx][bBank], BusinessData[bgbidx][bID]);
            mysql_tquery(g_SQL, bgbq, "", "", 0);
        }

        new Float:health;
        GetPlayerHealth(playerid, health);
        health += BURGER_HEAL_AMOUNT;
        if(health > 100.0) health = 100.0;
        SetPlayerHealth(playerid, health);

        new lmsg[128];
        format(lmsg, sizeof(lmsg), C_SUCCESS"Success: "C_WHITE"You bought a "C_INFO"burger"C_WHITE" for "C_INFO"$%s"C_WHITE" (+%d HP).",
            MoneyStr(g_BurgerPrice), floatround(BURGER_HEAL_AMOUNT));
        SendClientMessage(playerid, COLOR_SUCCESS, lmsg);
        return 1;
    }

    // ---- /joinparty ----
    if(strcmp(cmd, "/joinparty", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        if(GetPlayerVirtualWorld(playerid) == VW_PARTY)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You are already at the party."), 1;

        if(!IsPlayerInRangeOfPoint(playerid, PARTY_RANGE, PartyJoinLoc[0], PartyJoinLoc[1], PartyJoinLoc[2]))
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be at the party entrance to join."), 1;

        if(PlayerData[playerid][pMoney] < PARTY_TICKET_PRICE)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have enough money."), 1;

        PlayerData[playerid][pMoney] -= PARTY_TICKET_PRICE;
        GivePlayerMoney(playerid, -PARTY_TICKET_PRICE);
        UpdatePlayer(playerid, pMoney);

        Party_AddBizIncome(PARTY_TICKET_PRICE);

        SetPlayerVirtualWorld(playerid, VW_PARTY);

        if(strlen(g_PartyMusicURL))
            PlayAudioStreamForPlayer(playerid, g_PartyMusicURL);

        new pjmsg[128];
        format(pjmsg, sizeof(pjmsg), C_SUCCESS"Success: "C_WHITE"You joined the party for "C_INFO"$%s"C_WHITE". Use /changemusic and /buydrink here.",
            MoneyStr(PARTY_TICKET_PRICE));
        SendClientMessage(playerid, COLOR_SUCCESS, pjmsg);
        return 1;
    }

    // ---- /leaveparty ----
    if(strcmp(cmd, "/leaveparty", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        if(GetPlayerVirtualWorld(playerid) != VW_PARTY)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You are not at the party."), 1;

        SetPlayerVirtualWorld(playerid, 0);
        StopAudioStreamForPlayer(playerid);

        if(g_PartyHoldingDrink[playerid])
        {
            RemovePlayerAttachedObject(playerid, PARTY_ATTACH_INDEX);
            g_PartyHoldingDrink[playerid] = false;
        }

        SendClientMessage(playerid, COLOR_SUCCESS, C_SUCCESS"Success: "C_WHITE"You left the party.");
        return 1;
    }

    // ---- /changemusic [url] ----
    if(strcmp(cmd, "/changemusic", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        if(GetPlayerVirtualWorld(playerid) != VW_PARTY)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must join the party first. Use "C_INFO"/joinparty"C_WHITE"."), 1;

        if(!IsPlayerInRangeOfPoint(playerid, PARTY_RANGE, PartyMusicLoc[0], PartyMusicLoc[1], PartyMusicLoc[2]))
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be at the music stand to do this."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new musUrl[128];
        strmid(musUrl, cmdtext, idx, strlen(cmdtext), 128);

        if(!strlen(musUrl))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/changemusic [url]"C_WHITE"."), 1;

        if(PlayerData[playerid][pMoney] < PARTY_MUSIC_PRICE)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have enough money."), 1;

        PlayerData[playerid][pMoney] -= PARTY_MUSIC_PRICE;
        GivePlayerMoney(playerid, -PARTY_MUSIC_PRICE);
        UpdatePlayer(playerid, pMoney);

        Party_AddBizIncome(PARTY_MUSIC_PRICE);

        format(g_PartyMusicURL, sizeof(g_PartyMusicURL), "%s", musUrl);

        new musCount = 0;
        for(new i = 0; i < MAX_PLAYERS; i++)
        {
            if(!IsPlayerConnected(i) || !PlayerData[i][pLogged]) continue;
            if(GetPlayerVirtualWorld(i) != VW_PARTY) continue;
            PlayAudioStreamForPlayer(i, g_PartyMusicURL);
            musCount++;
        }

        new musmsg[160];
        format(musmsg, sizeof(musmsg), C_SUCCESS"Success: "C_WHITE"You changed the music for "C_INFO"%d"C_WHITE" player(s) at the party.", musCount);
        SendClientMessage(playerid, COLOR_SUCCESS, musmsg);
        return 1;
    }

    // ---- /buydrink ----
    if(strcmp(cmd, "/buydrink", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        if(GetPlayerVirtualWorld(playerid) != VW_PARTY)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must join the party first. Use "C_INFO"/joinparty"C_WHITE"."), 1;

        if(!IsPlayerInRangeOfPoint(playerid, PARTY_RANGE, PartyDrinkLoc[0], PartyDrinkLoc[1], PartyDrinkLoc[2]))
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be at the bar to do this."), 1;

        if(g_PartyHoldingDrink[playerid])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You're already holding a drink."), 1;

        if(PlayerData[playerid][pMoney] < PARTY_DRINK_PRICE)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have enough money."), 1;

        PlayerData[playerid][pMoney] -= PARTY_DRINK_PRICE;
        GivePlayerMoney(playerid, -PARTY_DRINK_PRICE);
        UpdatePlayer(playerid, pMoney);

        Party_AddBizIncome(PARTY_DRINK_PRICE);

        SetPlayerAttachedObject(playerid, PARTY_ATTACH_INDEX, PARTY_DRINK_MODEL, PARTY_ATTACH_BONE,
            0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.4, 0.4, 0.4);
        g_PartyHoldingDrink[playerid] = true;

        SendClientMessage(playerid, COLOR_SUCCESS, C_SUCCESS"Success: "C_WHITE"You bought a drink. Click to drink it.");
        return 1;
    }

    // ---- /buygrill ----
    if(strcmp(cmd, "/buygrill", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        if(GetPlayerVirtualWorld(playerid) != VW_PARTY)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must join the party first. Use "C_INFO"/joinparty"C_WHITE"."), 1;

        if(!IsPlayerInRangeOfPoint(playerid, PARTY_RANGE, PartyGrillLoc[0], PartyGrillLoc[1], PartyGrillLoc[2]))
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be at the grill to do this."), 1;

        if(PlayerData[playerid][pMoney] < PARTY_GRILL_PRICE)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have enough money."), 1;

        PlayerData[playerid][pMoney] -= PARTY_GRILL_PRICE;
        GivePlayerMoney(playerid, -PARTY_GRILL_PRICE);
        UpdatePlayer(playerid, pMoney);

        Party_AddBizIncome(PARTY_GRILL_PRICE);

        new Float:grillHealth;
        GetPlayerHealth(playerid, grillHealth);
        grillHealth += PARTY_GRILL_HEAL;
        if(grillHealth > 100.0) grillHealth = 100.0;
        SetPlayerHealth(playerid, grillHealth);

        new grillmsg[128];
        format(grillmsg, sizeof(grillmsg), C_SUCCESS"Success: "C_WHITE"You bought food from the grill for "C_INFO"$%s"C_WHITE" (+%d HP).",
            MoneyStr(PARTY_GRILL_PRICE), floatround(PARTY_GRILL_HEAL));
        SendClientMessage(playerid, COLOR_SUCCESS, grillmsg);
        return 1;
    }

    // ---- /joingolf ----
    if(strcmp(cmd, "/joingolf", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        if(g_GolfStatus != GOLF_STATUS_OPEN)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"There is no open golf tournament right now."), 1;

        if(g_GolfJoined[playerid])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You already joined the tournament."), 1;

        g_GolfJoined[playerid] = true;
        SendClientMessage(playerid, COLOR_SUCCESS, C_SUCCESS"Success: "C_WHITE"You joined the golf tournament. Wait for an admin to start it.");
        return 1;
    }

    // ---- /leavegolf ----
    if(strcmp(cmd, "/leavegolf", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        if(!g_GolfJoined[playerid] && !g_GolfActive[playerid])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You are not part of the golf tournament."), 1;

        new bool:wasActive = (g_GolfStatus == GOLF_STATUS_PROGRESS && g_GolfActive[playerid]);

        Golf_PlayerLeftMidRound(playerid);

        if(wasActive)
        {
            new lmsg[128];
            format(lmsg, sizeof(lmsg), C_ERROR"[Golf] "C_WHITE"%s"C_WHITE" left the tournament and was eliminated.", PlayerData[playerid][pName]);
            SendClientMessageToAll(COLOR_ERROR, lmsg);
        }

        SendClientMessage(playerid, COLOR_SUCCESS, C_SUCCESS"Success: "C_WHITE"You left the golf tournament.");
        return 1;
    }

    // ---- /hitball [numar] ----
    if(strcmp(cmd, "/hitball", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        if(g_GolfStatus != GOLF_STATUS_PROGRESS || !g_GolfActive[playerid])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You are not currently in an active golf round."), 1;

        if(g_GolfFinishedHole[playerid])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You already finished this hole."), 1;

        if(g_GolfBallMoving[playerid])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Your ball is still moving."), 1;

        if(!IsValidDynamicObject(g_GolfBallObject[playerid]))
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have a ball."), 1;

        new Float:curX, Float:curY, Float:curZ;
        GetDynamicObjectPos(g_GolfBallObject[playerid], curX, curY, curZ);

        if(!IsPlayerInRangeOfPoint(playerid, GOLF_BALL_RANGE, curX, curY, curZ))
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be near your ball to hit it."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new p1[4];
        strmid(p1, cmdtext, idx, strlen(cmdtext), 4);

        if(!strlen(p1))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/hitball [numar]"C_WHITE" (0-"C_INFO#GOLF_HIT_MAX_POWER C_WHITE")."), 1;

        new inputPower = strval(p1);
        if(inputPower < 0 || inputPower > GOLF_HIT_MAX_POWER)
        {
            new umsg[96];
            format(umsg, sizeof(umsg), C_ERROR"Error: "C_WHITE"Power must be between 0 and %d.", GOLF_HIT_MAX_POWER);
            return SendClientMessage(playerid, COLOR_ERROR, umsg), 1;
        }

        new power = inputPower + random(10); // [numar] + random(10)
        new Float:dist = float(power) * GOLF_POWER_TO_DISTANCE;

        new Float:angle;
        GetPlayerFacingAngle(playerid, angle);

        new Float:dx = dist * floatsin(-angle, degrees);
        new Float:dy = dist * floatcos(angle, degrees);

        g_GolfBallTarget[playerid][0] = curX + dx;
        g_GolfBallTarget[playerid][1] = curY + dy;
        g_GolfBallTarget[playerid][2] = curZ;

        g_GolfLastPower[playerid] = power;
        Golf_StartBallMove(playerid);

        g_GolfStrokes[playerid]++;
        return 1;
    }

    // ---- /joinbasket ----
    if(strcmp(cmd, "/joinbasket", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        if(!g_BBallLobbyFound)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"The basketball location is not configured yet."), 1;

        if(!IsPlayerInRangeOfPoint(playerid, BBALL_LOBBY_RANGE, g_BBallLobbyX, g_BBallLobbyY, g_BBallLobbyZ))
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be at the basketball court to use this command."), 1;

        if(g_BBallStatus == BBALL_STATUS_PROGRESS)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"The round has already started. Wait for the next round."), 1;

        if(g_BBallJoined[playerid])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You already joined the basketball game."), 1;

        g_BBallJoined[playerid] = true;
        BBall_CreateHoopLabels(playerid);
        SendClientMessage(playerid, COLOR_SUCCESS, C_SUCCESS"Success: "C_WHITE"You joined the basketball game. Waiting for more players.");

        if(BBall_CountJoined() >= BBALL_MIN_PLAYERS && !g_BBallCountdownActive)
            BBall_StartCountdown();

        return 1;
    }

    // ---- /leavebasket ----
    if(strcmp(cmd, "/leavebasket", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        if(!g_BBallJoined[playerid] && !g_BBallActive[playerid])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You are not part of the basketball game."), 1;

        new bool:bWasActive = (g_BBallStatus == BBALL_STATUS_PROGRESS && g_BBallActive[playerid]);

        BBall_PlayerLeftMidRound(playerid);

        if(bWasActive)
        {
            new blmsg[128];
            format(blmsg, sizeof(blmsg), C_ERROR"[Basket] "C_WHITE"%s"C_WHITE" left the game and was eliminated.", PlayerData[playerid][pName]);
            SendClientMessageToAll(COLOR_ERROR, blmsg);
        }

        SendClientMessage(playerid, COLOR_SUCCESS, C_SUCCESS"Success: "C_WHITE"You left the basketball game.");
        return 1;
    }

    // ---- /throwball [putere] ----
    if(strcmp(cmd, "/throwball", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        if(g_BBallStatus != BBALL_STATUS_PROGRESS || !g_BBallActive[playerid])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You are not currently in an active basketball round."), 1;

        if(!g_BBallSpawnedHere[playerid])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You are not at the current hoop yet."), 1;

        if(g_BBallBallMoving[playerid])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Your shot is already in the air."), 1;

        new bslot = g_BBallHoopSlot[playerid];
        if(bslot >= BBALL_MAX_HOOPS)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You already finished all hoops."), 1;

        new bhoopIdx = g_BBallHoopOrder[bslot];

        if(!IsPlayerInRangeOfPoint(playerid, BBALL_BALL_RANGE, BBallHoopData[bhoopIdx][0], BBallHoopData[bhoopIdx][1], BBallHoopData[bhoopIdx][2]))
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be near the current hoop to shoot."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new bp1[6];
        strmid(bp1, cmdtext, idx, strlen(cmdtext), 6);

        if(!strlen(bp1))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/throwball [power]"C_WHITE" (0-"C_INFO#BBALL_THROW_MAX_POWER C_WHITE")."), 1;

        new bpower = strval(bp1);
        if(bpower < 0 || bpower > BBALL_THROW_MAX_POWER)
        {
            new bumsg[96];
            format(bumsg, sizeof(bumsg), C_ERROR"Error: "C_WHITE"Power must be between 0 and %d.", BBALL_THROW_MAX_POWER);
            return SendClientMessage(playerid, COLOR_ERROR, bumsg), 1;
        }

        g_BBallBallMoving[playerid] = true;

        // capturate ACUM (la comanda), nu mai tarziu in lant, ca sa nu se schimbe directia
        // daca playerul se mai roteste cat timp asteapta animatia/delay-urile
        GetPlayerPos(playerid, g_BBallThrowX[playerid], g_BBallThrowY[playerid], g_BBallThrowZ[playerid]);
        GetPlayerFacingAngle(playerid, g_BBallThrowAngle[playerid]);

        TogglePlayerControllable(playerid, 1); // unfreeze, era inghetat de la teleportarea la cos

        SetPlayerAttachedObject(playerid, BBALL_ATTACH_INDEX, BBALL_BALL_MODEL, BBALL_ATTACH_BONE,
            0.05, 0.05, 0.05, 0.0, 0.0, 0.0, 0.4, 0.4, 0.4);
        SetTimerEx("BBall_PlayThrowAnim", 500, false, "ii", playerid, bpower);
        return 1;
    }

    // ---- /setbballspawn [hoop_id] [spawn_id] ----
    if(strcmp(cmd, "/setbballspawn", true) == 0)
    {
        if(PlayerData[playerid][pAdminLevel] < BBALL_ADMIN_LEVEL)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have access. Requires admin level 6."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new sp1[4], sp2[4];
        strmid(sp1, cmdtext, idx, strlen(cmdtext), 4);
        while(cmdtext[idx] > ' ') idx++;
        while(cmdtext[idx] == ' ') idx++;
        strmid(sp2, cmdtext, idx, strlen(cmdtext), 4);

        if(!strlen(sp1) || !strlen(sp2))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/setbballspawn [hoop_id 1-8] [spawn_id 1-4]"C_WHITE"."), 1;

        new hoopId = strval(sp1);
        new spawnId = strval(sp2);

        if(hoopId < 1 || hoopId > BBALL_MAX_HOOPS || spawnId < 1 || spawnId > BBALL_SPAWNS_PER_HOOP)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Invalid hoop_id (1-8) or spawn_id (1-4)."), 1;

        new Float:sx, Float:sy, Float:sz;
        GetPlayerPos(playerid, sx, sy, sz);

        new Float:srz;
        GetPlayerFacingAngle(playerid, srz);

        BBallSpawnData[hoopId-1][spawnId-1][0] = sx;
        BBallSpawnData[hoopId-1][spawnId-1][1] = sy;
        BBallSpawnData[hoopId-1][spawnId-1][2] = sz;
        BBallSpawnRot[hoopId-1][spawnId-1][0] = 0.0;
        BBallSpawnRot[hoopId-1][spawnId-1][1] = 0.0;
        BBallSpawnRot[hoopId-1][spawnId-1][2] = srz;
        BBallSpawnSet[hoopId-1][spawnId-1] = true;

        new sq[260];
        mysql_format(g_SQL, sq, sizeof(sq),
            "INSERT INTO `basket_spawns` (`hoop_id`,`spawn_id`,`x`,`y`,`z`,`rx`,`ry`,`rz`) VALUES (%d,%d,%.4f,%.4f,%.4f,0,0,%.4f) \
             ON DUPLICATE KEY UPDATE `x`=%.4f,`y`=%.4f,`z`=%.4f,`rx`=0,`ry`=0,`rz`=%.4f",
            hoopId, spawnId, sx, sy, sz, srz, sx, sy, sz, srz);
        mysql_tquery(g_SQL, sq, "", "", 0);

        new smsg[128];
        format(smsg, sizeof(smsg), C_SUCCESS"[ADM] Success: "C_WHITE"Spawn point "C_INFO"%d"C_WHITE" for hoop "C_INFO"%d"C_WHITE" set to your current position.",
            spawnId, hoopId);
        SendClientMessage(playerid, COLOR_SUCCESS, smsg);
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

    // ---- /attach ----
    if(strcmp(cmd, "/attach", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        if(PlayerData[playerid][pCaravanKey] == 0)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't own a caravan."), 1;

        if(g_CaravanAttachedVeh[playerid] != 0)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Your caravan is already attached."), 1;

        new vehid = GetPlayerVehicleID(playerid);
        if(vehid == 0 || GetPlayerVehicleSeat(playerid) != 0)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be driving a vehicle."), 1;

        new pvidx = g_VehicleToPVIndex[vehid];
        if(pvidx == -1)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be in your personal vehicle."), 1;

        if(PVehicleData[pvidx][pvOwnerId] != PlayerData[playerid][pID])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't own this vehicle."), 1;

        if(IsValidDynamicObject(g_CaravanObject[playerid]))
        {
            new Float:cox, Float:coy, Float:coz;
            GetDynamicObjectPos(g_CaravanObject[playerid], cox, coy, coz);
            if(!IsPlayerInRangeOfPoint(playerid, CARAVAN_ATTACH_RANGE, cox, coy, coz))
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be near your caravan to attach it."), 1;
        }
        else
        {
            new Float:px, Float:py, Float:pz;
            GetPlayerPos(playerid, px, py, pz);
            g_CaravanObject[playerid] = CreateDynamicObject(Caravan_GetModel(PlayerData[playerid][pCaravanKey]), px, py, pz, 0.0, 0.0, 0.0);
        }

        AttachDynamicObjectToVehicle(g_CaravanObject[playerid], vehid, 0.0, CARAVAN_ATTACH_OFFSET_Y, CARAVAN_ATTACH_OFFSET_Z, 0.0, 0.0, 0.0);
        g_CaravanAttachedVeh[playerid] = vehid;

        SendClientMessage(playerid, COLOR_SUCCESS, C_SUCCESS"Success: "C_WHITE"Caravan attached.");
        return 1;
    }

    // ---- /detach ----
    if(strcmp(cmd, "/detach", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        if(PlayerData[playerid][pCaravanKey] == 0)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't own a caravan."), 1;

        if(g_CaravanAttachedVeh[playerid] == 0)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Your caravan is not attached."), 1;

        new vehid = g_CaravanAttachedVeh[playerid];

        new Float:vx, Float:vy, Float:vz;
        GetVehiclePos(vehid, vx, vy, vz);

        new Float:rx, Float:ry, Float:rz;
        GetVehicleRotation(vehid, rx, ry, rz);
        rz = -rz;

        // permite /detach doar daca masina e (aproape) drepata - rx/ry aproape de un multiplu de 90 grade,
        // adica fara panta/inclinare semnificativa
        new Float:rxMod90 = rx - float(floatround(rx / 90.0, floatround_floor)) * 90.0;
        new Float:ryMod90 = ry - float(floatround(ry / 90.0, floatround_floor)) * 90.0;
        if((rxMod90 > 5.0 && rxMod90 < 85.0) || (ryMod90 > 5.0 && ryMod90 < 85.0))
        {
            new flatMsg[160];
            format(flatMsg, sizeof(flatMsg), C_ERROR"Error: "C_WHITE"The vehicle must be on flat ground to detach the caravan. (rx=%.2f, ry=%.2f)", rx, ry);
            return SendClientMessage(playerid, COLOR_ERROR, flatMsg), 1;
        }

        new Float:parkZ = vz + CARAVAN_PARK_OFFSET_Z;

        // In loc de SetDynamicObjectPos/Rot (care nu scoate intotdeauna corect atasarea de pe vehicul),
        // distrugem obiectul atasat si cream unul nou direct cu pozitia si rotatia (completa, inclusiv panta) a masinii
        if(IsValidDynamicObject(g_CaravanObject[playerid]))
            DestroyDynamicObject(g_CaravanObject[playerid]);
        g_CaravanObject[playerid] = CreateDynamicObject(Caravan_GetModel(PlayerData[playerid][pCaravanKey]),
            vx, vy, parkZ, rx, ry, rz);

        new cidx = Caravan_FindByOwner(PlayerData[playerid][pID]);
        if(cidx != -1)
        {
            CaravanData[cidx][rParkLocX] = vx;
            CaravanData[cidx][rParkLocY] = vy;
            CaravanData[cidx][rParkLocZ] = parkZ;
            CaravanData[cidx][rParkRX]   = rx;
            CaravanData[cidx][rParkRY]   = ry;
            CaravanData[cidx][rParkRZ]   = rz;

            new cq[260];
            mysql_format(g_SQL, cq, sizeof(cq),
                "UPDATE `rulote_personale` SET `rParkLocX`=%.4f, `rParkLocY`=%.4f, `rParkLocZ`=%.4f, `parkRX`=%.4f, `parkRY`=%.4f, `parkRZ`=%.4f WHERE `rID`=%d",
                vx, vy, parkZ, rx, ry, rz, CaravanData[cidx][rID]);
            mysql_tquery(g_SQL, cq, "", "", 0);
        }

        g_CaravanAttachedVeh[playerid] = 0;

        SetVehiclePos(vehid, vx, vy, vz + 5.0);

        SendClientMessage(playerid, COLOR_SUCCESS, C_SUCCESS"Success: "C_WHITE"Caravan detached and parked.");
        return 1;
    }

    // ---- /camp ----
    if(strcmp(cmd, "/camp", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        if(PlayerData[playerid][pCaravanKey] == 0)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't own a caravan."), 1;

        if(g_CaravanAttachedVeh[playerid] == 0)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Your caravan must be attached to your vehicle."), 1;

        new campVehid = GetPlayerVehicleID(playerid);
        if(campVehid == 0 || campVehid != g_CaravanAttachedVeh[playerid])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be in the vehicle your caravan is attached to."), 1;

        new Float:cvx, Float:cvy, Float:cvz;
        GetVehiclePos(campVehid, cvx, cvy, cvz);

        new Float:crx, Float:cry, Float:crz;
        GetVehicleRotation(campVehid, crx, cry, crz);
        crz = -crz;

        // permite /camp doar daca masina e (aproape) dreapta - la fel ca la /detach
        new Float:crxMod90 = crx - float(floatround(crx / 90.0, floatround_floor)) * 90.0;
        new Float:cryMod90 = cry - float(floatround(cry / 90.0, floatround_floor)) * 90.0;
        if((crxMod90 > 5.0 && crxMod90 < 85.0) || (cryMod90 > 5.0 && cryMod90 < 85.0))
        {
            new campFlatMsg[160];
            format(campFlatMsg, sizeof(campFlatMsg), C_ERROR"Error: "C_WHITE"The vehicle must be on flat ground to set up camp. (rx=%.2f, ry=%.2f)", crx, cry);
            return SendClientMessage(playerid, COLOR_ERROR, campFlatMsg), 1;
        }

        new campIdx = Caravan_FindByOwner(PlayerData[playerid][pID]);
        if(campIdx == -1)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Caravan data not found."), 1;

        new campNow = gettime();
        CaravanData[campIdx][rCamping]          = true;
        CaravanData[campIdx][rCampingStartDate] = campNow;
        CaravanData[campIdx][rCampLocX]         = cvx;
        CaravanData[campIdx][rCampLocY]         = cvy;
        CaravanData[campIdx][rCampLocZ]         = cvz;
        CaravanData[campIdx][rCampRX]           = crx;
        CaravanData[campIdx][rCampRY]           = cry;
        CaravanData[campIdx][rCampRZ]           = crz;

        new campDtVal[24];
        BuildDateTimeSqlValueFromUnix(campNow, campDtVal, sizeof(campDtVal));

        new campQ[300];
        mysql_format(g_SQL, campQ, sizeof(campQ),
            "UPDATE `rulote_personale` SET `rCamping`=1, `rCampingStartDate`=%s, `rCampLocX`=%.4f, `rCampLocY`=%.4f, `rCampLocZ`=%.4f, `campRX`=%.4f, `campRY`=%.4f, `campRZ`=%.4f WHERE `rID`=%d",
            campDtVal, cvx, cvy, cvz, crx, cry, crz, CaravanData[campIdx][rID]);
        mysql_tquery(g_SQL, campQ, "", "", 0);

        PlayerData[playerid][pSpawn] = CARAVAN_CAMP_SPAWN_TYPE;
        Player_RecalcSpawn(playerid);
        UpdatePlayer(playerid, pSpawn);

        SendClientMessage(playerid, COLOR_SUCCESS,
            C_SUCCESS"Success: "C_WHITE"You set up camp here. You will spawn at your caravan for the next 3 paydays.");
        return 1;
    }

    // ---- /findmycaravan ----
    if(strcmp(cmd, "/findmycaravan", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        if(PlayerData[playerid][pCaravanKey] == 0)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't own a caravan."), 1;

        new fmcIdx = Caravan_FindByOwner(PlayerData[playerid][pID]);
        if(fmcIdx == -1)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Caravan data not found."), 1;

        new bool:fmcUseCamp = (CaravanData[fmcIdx][rCampLocX] != 0.0 || CaravanData[fmcIdx][rCampLocY] != 0.0 || CaravanData[fmcIdx][rCampLocZ] != 0.0);

        new Float:fmcX, Float:fmcY, Float:fmcZ;
        if(fmcUseCamp)
        {
            fmcX = CaravanData[fmcIdx][rCampLocX];
            fmcY = CaravanData[fmcIdx][rCampLocY];
            fmcZ = CaravanData[fmcIdx][rCampLocZ];
        }
        else
        {
            if(CaravanData[fmcIdx][rParkLocX] == 0.0 && CaravanData[fmcIdx][rParkLocY] == 0.0 && CaravanData[fmcIdx][rParkLocZ] == 0.0)
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Your caravan hasn't been parked anywhere yet."), 1;

            fmcX = CaravanData[fmcIdx][rParkLocX];
            fmcY = CaravanData[fmcIdx][rParkLocY];
            fmcZ = CaravanData[fmcIdx][rParkLocZ];
        }

        SetPlayerCheckpoint(playerid, fmcX, fmcY, fmcZ, GPS_CP_SIZE);
        g_GPSActive[playerid] = true;

        SendClientMessage(playerid, COLOR_SUCCESS, C_SUCCESS"Success: "C_WHITE"Checkpoint set to your caravan.");
        return 1;
    }

    // ---- /engine ----
    if(strcmp(cmd, "/engine", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        Vehicle_ToggleEngine(playerid);
        return 1;
    }

    // ---- /gps [name] ----
    if(strcmp(cmd, "/gps", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new gname[32];
        strmid(gname, cmdtext, idx, strlen(cmdtext), 32);

        if(!strlen(gname))
        {
            ShowPlayerDialog(playerid, DIALOG_GPS_CATEGORY, DIALOG_STYLE_LIST,
                "Select Location Category", "DMV Locations\nFactions\nBusiness\nOthers\nShops", "Select", "Cancel");
            return 1;
        }

        if(g_ExamAState[playerid] != EXAMA_STATE_NONE || g_ExamState[playerid] != EXAM_STATE_NONE ||
           g_ExamCState[playerid] != EXAMC_STATE_NONE || g_ExamDState[playerid] != EXAMD_STATE_NONE)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You can't use GPS during an exam."), 1;

        new gidx = GPS_FindByName(gname);
        if(gidx == -1)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Unknown location. Use "C_INFO"/gps"C_WHITE" to see available locations."), 1;

        SetPlayerCheckpoint(playerid, GPSData[gidx][glLocX], GPSData[gidx][glLocY], GPSData[gidx][glLocZ], GPS_CP_SIZE);
        g_GPSActive[playerid] = true;

        new gmsg[128];
        format(gmsg, sizeof(gmsg), C_SUCCESS"Success: "C_WHITE"GPS checkpoint set to "C_INFO"%s"C_WHITE".", GPSData[gidx][glName]);
        SendClientMessage(playerid, COLOR_SUCCESS, gmsg);
        return 1;
    }

    // ---- /killcp ----
    if(strcmp(cmd, "/killcp", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        if(!g_GPSActive[playerid])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have an active checkpoint."), 1;

        DisablePlayerCheckpoint(playerid);
        g_GPSActive[playerid] = false;

        SendClientMessage(playerid, COLOR_SUCCESS, C_SUCCESS"Success: "C_WHITE"Checkpoint removed.");
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

    // ---- /checklicenses [playerid] ----
    if(strcmp(cmd, "/checklicenses", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        if(PlayerData[playerid][pFaction] != FACTION_POLICE)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You are not part of the Politia Romana."), 1;

        if(!PlayerData[playerid][pOnDuty])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be on-duty to use this command."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new p1[8];
        strmid(p1, cmdtext, idx, strlen(cmdtext), 8);

        if(!strlen(p1))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/checklicenses [playerid]"C_WHITE"."), 1;

        new targetid = strval(p1);
        if(!IsPlayerConnected(targetid) || !PlayerData[targetid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"The player is not connected."), 1;

        new statusA[24], statusB[24], statusC[24], statusD[24];
        License_FormatStatus(PlayerData[targetid][pDrivingLicA_exp], statusA, sizeof(statusA));
        License_FormatStatus(PlayerData[targetid][pDrivingLicB_exp], statusB, sizeof(statusB));
        License_FormatStatus(PlayerData[targetid][pDrivingLicC_exp], statusC, sizeof(statusC));
        License_FormatStatus(PlayerData[targetid][pDrivingLicD_exp], statusD, sizeof(statusD));

        new line[128];
        format(line, sizeof(line), C_INFO"_____ %s's Licenses ____________________", PlayerData[targetid][pName]);
        SendClientMessage(playerid, COLOR_INFO, line);

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

    // ---- /suspendlic [playerid] [A/B/C/D/all] ----
    if(strcmp(cmd, "/suspendlic", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        if(PlayerData[playerid][pFaction] != FACTION_POLICE)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You are not part of the Politia Romana."), 1;

        if(!PlayerData[playerid][pOnDuty])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be on-duty to use this command."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new p1[8], p2[8];
        strmid(p1, cmdtext, idx, strlen(cmdtext), 8);
        while(cmdtext[idx] > ' ') idx++;
        while(cmdtext[idx] == ' ') idx++;
        strmid(p2, cmdtext, idx, strlen(cmdtext), 8);

        if(!strlen(p1) || !strlen(p2))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/suspendlic [playerid] [A/B/C/D/all]"C_WHITE"."), 1;

        new targetid = strval(p1);
        if(!IsPlayerConnected(targetid) || !PlayerData[targetid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"The player is not connected."), 1;

        new q[256], catLabel[8];

        if(strcmp(p2, "all", true) == 0)
        {
            PlayerData[targetid][pDrivingLicA_exp][0] = EOS;
            PlayerData[targetid][pDrivingLicB_exp][0] = EOS;
            PlayerData[targetid][pDrivingLicC_exp][0] = EOS;
            PlayerData[targetid][pDrivingLicD_exp][0] = EOS;

            mysql_format(g_SQL, q, sizeof(q),
                "UPDATE `players` SET `driving_lic_a_exp`=NULL, `driving_lic_b_exp`=NULL, `driving_lic_c_exp`=NULL, `driving_lic_d_exp`=NULL WHERE `id`=%d",
                PlayerData[targetid][pID]);
            format(catLabel, sizeof(catLabel), "ALL");
        }
        else if(strcmp(p2, "A", true) == 0)
        {
            PlayerData[targetid][pDrivingLicA_exp][0] = EOS;
            mysql_format(g_SQL, q, sizeof(q), "UPDATE `players` SET `driving_lic_a_exp`=NULL WHERE `id`=%d", PlayerData[targetid][pID]);
            format(catLabel, sizeof(catLabel), "A");
        }
        else if(strcmp(p2, "B", true) == 0)
        {
            PlayerData[targetid][pDrivingLicB_exp][0] = EOS;
            mysql_format(g_SQL, q, sizeof(q), "UPDATE `players` SET `driving_lic_b_exp`=NULL WHERE `id`=%d", PlayerData[targetid][pID]);
            format(catLabel, sizeof(catLabel), "B");
        }
        else if(strcmp(p2, "C", true) == 0)
        {
            PlayerData[targetid][pDrivingLicC_exp][0] = EOS;
            mysql_format(g_SQL, q, sizeof(q), "UPDATE `players` SET `driving_lic_c_exp`=NULL WHERE `id`=%d", PlayerData[targetid][pID]);
            format(catLabel, sizeof(catLabel), "C");
        }
        else if(strcmp(p2, "D", true) == 0)
        {
            PlayerData[targetid][pDrivingLicD_exp][0] = EOS;
            mysql_format(g_SQL, q, sizeof(q), "UPDATE `players` SET `driving_lic_d_exp`=NULL WHERE `id`=%d", PlayerData[targetid][pID]);
            format(catLabel, sizeof(catLabel), "D");
        }
        else
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Invalid category. Use A, B, C, D or all."), 1;

        mysql_tquery(g_SQL, q, "", "", 0);

        new smsg[160];
        format(smsg, sizeof(smsg), C_SUCCESS"Success: "C_WHITE"You suspended "C_INFO"%s"C_WHITE"'s category "C_INFO"%s"C_WHITE" license(s).",
            PlayerData[targetid][pName], catLabel);
        SendClientMessage(playerid, COLOR_SUCCESS, smsg);

        format(smsg, sizeof(smsg), C_ERROR"Error: "C_WHITE"Your category "C_INFO"%s"C_WHITE" license(s) have been suspended by "C_INFO"%s"C_WHITE".",
            catLabel, PlayerData[playerid][pName]);
        SendClientMessage(targetid, COLOR_ERROR, smsg);
        return 1;
    }

    // ---- /garage ----
    if(strcmp(cmd, "/garage", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        if(PlayerData[playerid][pFaction] != FACTION_POLICE)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You are not part of the Politia Romana."), 1;

        if(!IsPlayerInRangeOfPoint(playerid, POLICE_TP_RANGE, POLICE_GARAGE_X, POLICE_GARAGE_Y, POLICE_GARAGE_Z))
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be at the garage."), 1;

        Police_TeleportTo(playerid, POLICE_ENTRANCE_X, POLICE_ENTRANCE_Y, POLICE_ENTRANCE_Z);
        return 1;
    }

    // ---- /entrace ----
    if(strcmp(cmd, "/entrace", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        if(PlayerData[playerid][pFaction] != FACTION_POLICE)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You are not part of the Politia Romana."), 1;

        if(!IsPlayerInRangeOfPoint(playerid, POLICE_TP_RANGE, POLICE_ENTRANCE_X, POLICE_ENTRANCE_Y, POLICE_ENTRANCE_Z))
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be at the entrance."), 1;

        Police_TeleportTo(playerid, POLICE_GARAGE_X, POLICE_GARAGE_Y, POLICE_GARAGE_Z);
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

        new itpEngine, itpLights, itpAlarm, itpDoors, itpBonnet, itpBoot, itpObjective;
        GetVehicleParamsEx(vehid, itpEngine, itpLights, itpAlarm, itpDoors, itpBonnet, itpBoot, itpObjective);
        if(itpEngine)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"The vehicle's engine must be off to do this."), 1;

        if(VehicleDoc_IsValid(PVehicleData[pvidx][pvITPExp]))
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

    // ---- /createcaravan [playerid] [type 1-3] ----
    if(strcmp(cmd, "/createcaravan", true) == 0)
    {
        if(PlayerData[playerid][pAdminLevel] < 6)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have access. Requires admin level 6."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new p1[8], p2[8];
        strmid(p1, cmdtext, idx, strlen(cmdtext), 8);
        while(cmdtext[idx] > ' ') idx++;
        while(cmdtext[idx] == ' ') idx++;
        strmid(p2, cmdtext, idx, strlen(cmdtext), 8);

        if(!strlen(p1) || !strlen(p2))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/createcaravan [playerid] [type 1-3]"C_WHITE"."), 1;

        new targetid = strval(p1);
        if(!IsPlayerConnected(targetid) || !PlayerData[targetid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"The player is not connected."), 1;

        new type = strval(p2);
        if(type < 1 || type > 3)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Invalid type (1-3)."), 1;

        if(PlayerData[targetid][pCaravanKey] != 0)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"This player already owns a caravan."), 1;

        if(g_CaravanCount >= MAX_PERSONAL_CARAVANS)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Caravan limit reached."), 1;

        PlayerData[targetid][pCaravanKey] = type;
        UpdatePlayer(targetid, pCaravanKey);

        new newIdx = g_CaravanCount;
        CaravanData[newIdx][rOwned]            = 1;
        CaravanData[newIdx][rOwner]            = PlayerData[targetid][pID];
        CaravanData[newIdx][rPrice]            = 0;
        CaravanData[newIdx][rCamping]          = false;
        CaravanData[newIdx][rCampingStartDate] = 0;
        CaravanData[newIdx][rParkLocX]         = 0.0;
        CaravanData[newIdx][rParkLocY]         = 0.0;
        CaravanData[newIdx][rParkLocZ]         = 0.0;
        CaravanData[newIdx][rCampLocX]         = 0.0;
        CaravanData[newIdx][rCampLocY]         = 0.0;
        CaravanData[newIdx][rCampLocZ]         = 0.0;
        CaravanData[newIdx][rParkRX]           = 0.0;
        CaravanData[newIdx][rParkRY]           = 0.0;
        CaravanData[newIdx][rParkRZ]           = 0.0;
        CaravanData[newIdx][rCampRX]           = 0.0;
        CaravanData[newIdx][rCampRY]           = 0.0;
        CaravanData[newIdx][rCampRZ]           = 0.0;
        CaravanData[newIdx][rType]             = type;
        g_CaravanCount++;

        new cq[160];
        mysql_format(g_SQL, cq, sizeof(cq), "INSERT INTO `rulote_personale` (`rOwned`,`rOwner`,`rType`) VALUES (1,%d,%d)", PlayerData[targetid][pID], type);
        mysql_tquery(g_SQL, cq, "OnCaravanCreated", "ii", targetid, newIdx);

        new cmsg[128];
        format(cmsg, sizeof(cmsg), C_SUCCESS"[ADM]Success: "C_WHITE"Gave "C_INFO"%s"C_WHITE" a type "C_INFO"%d"C_WHITE" caravan.",
            PlayerData[targetid][pName], type);
        SendClientMessage(playerid, COLOR_SUCCESS, cmsg);

        format(cmsg, sizeof(cmsg), C_SUCCESS"Success: "C_WHITE"You received a caravan! Use "C_INFO"/attach"C_WHITE" in your personal vehicle to tow it.");
        SendClientMessage(targetid, COLOR_SUCCESS, cmsg);
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
        format(lmsg, sizeof(lmsg), C_SUCCESS"[ADM]Success: "C_WHITE"The price of vehicle (ID: "C_INFO"%d"C_WHITE") was changed to "C_INFO"$%s"C_WHITE".",
            PVehicleData[pvidx][pvID], MoneyStr(newPrice));
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

    // ---- /changefactionInteriorLoc [faction_id] (seteaza coordonatele interiorului la pozitia ta) ----
    if(strcmp(cmd, "/changefactionInteriorLoc", true) == 0)
    {
        if(PlayerData[playerid][pAdminLevel] < 6)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have access. Requires admin level 6."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new param[8];
        strmid(param, cmdtext, idx, strlen(cmdtext), 8);
        if(!strlen(param))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/changefactionInteriorLoc [faction_id]"C_WHITE"."), 1;

        new fid = strval(param);
        if(fid < 1 || fid > MAX_FACTIONS)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Invalid faction ID (1-"#MAX_FACTIONS")."), 1;

        new Float:ix, Float:iy, Float:iz;
        GetPlayerPos(playerid, ix, iy, iz);

        FactionData[fid][fInteriorX] = ix;
        FactionData[fid][fInteriorY] = iy;
        FactionData[fid][fInteriorZ] = iz;

        new q[256];
        mysql_format(g_SQL, q, sizeof(q),
            "UPDATE `factions` SET `interior_x`=%.4f, `interior_y`=%.4f, `interior_z`=%.4f WHERE `id`=%d",
            ix, iy, iz, fid);
        mysql_tquery(g_SQL, q, "", "", 0);

        Factions_RecreateInteriorPickup(fid);
        Factions_RecreateLabel(fid); // eticheta exterioara include acum "[ Press ENTER to enter ]"

        new lmsg[128];
        format(lmsg, sizeof(lmsg), C_SUCCESS"Success: "C_WHITE"Interior location for "C_INFO"%s"C_WHITE" set to your position.", FactionData[fid][fName]);
        SendClientMessage(playerid, COLOR_SUCCESS, lmsg);
        return 1;
    }

    // ---- /changefactioninterior [faction_id] [new interior id] ----
    if(strcmp(cmd, "/changefactioninterior", true) == 0)
    {
        if(PlayerData[playerid][pAdminLevel] < 6)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have access. Requires admin level 6."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new p1[8], p2[8];
        strmid(p1, cmdtext, idx, strlen(cmdtext), 8);
        while(cmdtext[idx] > ' ') idx++;
        while(cmdtext[idx] == ' ') idx++;
        strmid(p2, cmdtext, idx, strlen(cmdtext), 8);

        if(!strlen(p1) || !strlen(p2))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/changefactioninterior [faction_id] [interior_id]"C_WHITE"."), 1;

        new fid = strval(p1);
        if(fid < 1 || fid > MAX_FACTIONS)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Invalid faction ID (1-"#MAX_FACTIONS")."), 1;

        new interiorid = strval(p2);
        FactionData[fid][fInterior] = interiorid;

        new q[160];
        mysql_format(g_SQL, q, sizeof(q),
            "UPDATE `factions` SET `interior`=%d WHERE `id`=%d", interiorid, fid);
        mysql_tquery(g_SQL, q, "", "", 0);

        new lmsg[128];
        format(lmsg, sizeof(lmsg), C_SUCCESS"Success: "C_WHITE"Interior for "C_INFO"%s"C_WHITE" set to "C_INFO"%d"C_WHITE".", FactionData[fid][fName], interiorid);
        SendClientMessage(playerid, COLOR_SUCCESS, lmsg);
        return 1;
    }

    // ---- /changefactionvw [faction_id] [new virtual world] ----
    if(strcmp(cmd, "/changefactionvw", true) == 0)
    {
        if(PlayerData[playerid][pAdminLevel] < 6)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have access. Requires admin level 6."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new p1[8], p2[8];
        strmid(p1, cmdtext, idx, strlen(cmdtext), 8);
        while(cmdtext[idx] > ' ') idx++;
        while(cmdtext[idx] == ' ') idx++;
        strmid(p2, cmdtext, idx, strlen(cmdtext), 8);

        if(!strlen(p1) || !strlen(p2))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/changefactionvw [faction_id] [vw_id]"C_WHITE"."), 1;

        new fid = strval(p1);
        if(fid < 1 || fid > MAX_FACTIONS)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Invalid faction ID (1-"#MAX_FACTIONS")."), 1;

        new vwid = strval(p2);
        FactionData[fid][fvw] = vwid;

        new q[160];
        mysql_format(g_SQL, q, sizeof(q),
            "UPDATE `factions` SET `vw`=%d WHERE `id`=%d", vwid, fid);
        mysql_tquery(g_SQL, q, "", "", 0);

        Factions_RecreateInteriorPickup(fid); // pickup-ul/eticheta interiorului depind de vw

        new lmsg[128];
        format(lmsg, sizeof(lmsg), C_SUCCESS"Success: "C_WHITE"Virtual world for "C_INFO"%s"C_WHITE" set to "C_INFO"%d"C_WHITE".", FactionData[fid][fName], vwid);
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

        // Noul lider primeste spawn-ul setat la HQ-ul factiunii si e respawnat pe loc
        PlayerData[targetid][pSpawn] = 2;
        UpdatePlayer(targetid, pSpawn);
        Player_RecalcSpawn(targetid);
        SpawnPlayer(targetid);

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

        // La spawn-ul de factiune (tip 2), aplica vw-ul si interiorul factiunii din DB
        if(PlayerData[playerid][pSpawn] == 2)
        {
            new fid = PlayerData[playerid][pFaction];
            if(fid >= 1 && fid <= MAX_FACTIONS)
            {
                SetPlayerVirtualWorld(playerid, FactionData[fid][fvw]);
                SetPlayerInterior(playerid, FactionData[fid][fInterior]);
            }
        }
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
    War_HandleDeath(playerid, killerid);
    return 1;
}

public OnPlayerUpdate(playerid)
{
    if(!PlayerData[playerid][pLogged]) return 1;

    // Dezactiveaza heal-ul de la automate (vending machines): anuleaza animatia inainte sa se aplice viata
    new anim = GetPlayerAnimationIndex(playerid);
    if(anim >= 1142 && anim <= 1145) // animatiile "VENDING" (VEND_Drink/Drink2/Eat1)
        ClearAnimations(playerid, 1);

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

    ExamD_KillTimer(playerid);
    g_ExamDState[playerid] = EXAMD_STATE_NONE;

    g_RadarActive[playerid] = false;
    Radar_DestroyProps(playerid);

    Golf_PlayerLeftMidRound(playerid);
    BBall_PlayerLeftMidRound(playerid);

    // daca avea o rulota parcata/campata (nu atasata), transfera obiectul ei catre slotul "offline"
    // (Caravans_RebuildAll), ca sa nu ramana orfan in g_CaravanObject[playerid] dupa deconectare
    if(PlayerData[playerid][pCaravanKey] != 0 && g_CaravanAttachedVeh[playerid] == 0)
    {
        new dcCidx = Caravan_FindByOwner(PlayerData[playerid][pID]);
        if(dcCidx != -1 && IsValidDynamicObject(g_CaravanObject[playerid]))
        {
            g_CaravanOfflineObject[dcCidx] = g_CaravanObject[playerid];
            g_CaravanObject[playerid] = STREAMER_TAG_OBJECT:INVALID_STREAMER_ID;
        }
    }

    if(g_PartyHoldingDrink[playerid])
    {
        RemovePlayerAttachedObject(playerid, PARTY_ATTACH_INDEX);
        g_PartyHoldingDrink[playerid] = false;
    }

    Speedometer_Destroy(playerid);
    LoginBG_Destroy(playerid);

    FullUpdatePlayer(playerid);
    return 1;
}

public OnPlayerKeyStateChange(playerid, newkeys, oldkeys)
{
    if((newkeys & KEY_SUBMISSION) && !(oldkeys & KEY_SUBMISSION))
    {
        if(PlayerData[playerid][pLogged] && GetPlayerVehicleID(playerid) != 0 && GetPlayerVehicleSeat(playerid) == 0)
            Vehicle_ToggleEngine(playerid);
    }

    if((newkeys & KEY_SECONDARY_ATTACK) && !(oldkeys & KEY_SECONDARY_ATTACK))
    {
        if(PlayerData[playerid][pLogged] && PlayerData[playerid][pFaction] == FACTION_POLICE)
            Police_GarageEntranceToggle(playerid);

        if(PlayerData[playerid][pLogged] &&
           PlayerData[playerid][pFaction] >= 1 && PlayerData[playerid][pFaction] <= MAX_FACTIONS)
            Factions_InteriorToggle(playerid);
    }

    if((newkeys & KEY_HANDBRAKE) && !(oldkeys & KEY_HANDBRAKE))
    {
        if(PlayerData[playerid][pLogged] && GetPlayerVehicleID(playerid) != 0 && GetPlayerVehicleSeat(playerid) == 0)
            Vehicle_ToggleLights(playerid);
    }

    if((newkeys & KEY_FIRE) && !(oldkeys & KEY_FIRE))
    {
        if(PlayerData[playerid][pLogged] && g_PartyHoldingDrink[playerid])
            Party_DrinkBeer(playerid);
    }
    return 1;
}

public OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
    if(dialogid == DIALOG_BIZZLIST)
    {
        if(!response) return 1; // Close

        if(listitem < 0 || listitem >= g_BusinessCount) return 1;

        if(GetPlayerVehicleID(playerid) != 0)
            SetVehiclePos(GetPlayerVehicleID(playerid), BusinessData[listitem][bLocX], BusinessData[listitem][bLocY], BusinessData[listitem][bLocZ] + 0.1);
        else
            SetPlayerPos(playerid, BusinessData[listitem][bLocX], BusinessData[listitem][bLocY], BusinessData[listitem][bLocZ] + 0.1);

        new bmsg[96];
        format(bmsg, sizeof(bmsg), C_SUCCESS"[ADM]Success: "C_WHITE"Teleported to business "C_INFO"%s"C_WHITE".", BusinessData[listitem][bName]);
        SendClientMessage(playerid, COLOR_SUCCESS, bmsg);
        return 1;
    }

    if(dialogid == DIALOG_GPS_CATEGORY)
    {
        if(!response) return 1; // Cancel

        if(listitem < 0 || listitem > 4) return 1;

        g_GPSDialogCategory[playerid] = listitem;

        // Factiuni: lista e populata direct din FactionData (HQ-ul fiecarei factiuni cu HQ setat), nu din locations_gps
        if(listitem == 1)
        {
            new list[320], any = 0, line[48];
            for(new i = 1; i <= MAX_FACTIONS; i++)
            {
                if(FactionData[i][fHQX] == 0.0 && FactionData[i][fHQY] == 0.0) continue;
                format(line, sizeof(line), "%s (%dm)\n", FactionData[i][fName],
                    floatround(GetPlayerDistanceFromPoint(playerid, FactionData[i][fHQX], FactionData[i][fHQY], FactionData[i][fHQZ])));
                strcat(list, line);
                any++;
            }

            if(!any)
            {
                SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"No locations are available in this category.");
                return 1;
            }

            ShowPlayerDialog(playerid, DIALOG_GPS_LOCATION, DIALOG_STYLE_LIST, "GPS - Factions", list, "Select", "Cancel");
            return 1;
        }

        // Business: lista e populata direct din BusinessData, nu din locations_gps
        if(listitem == 2)
        {
            if(g_BusinessCount == 0)
            {
                SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"No locations are available in this category.");
                return 1;
            }

            new list[2560], line[48];
            for(new i = 0; i < g_BusinessCount; i++)
            {
                format(line, sizeof(line), "%s (%dm)\n", BusinessData[i][bName],
                    floatround(GetPlayerDistanceFromPoint(playerid, BusinessData[i][bLocX], BusinessData[i][bLocY], BusinessData[i][bLocZ])));
                strcat(list, line);
            }

            ShowPlayerDialog(playerid, DIALOG_GPS_LOCATION, DIALOG_STYLE_LIST, "GPS - Business", list, "Select", "Cancel");
            return 1;
        }

        if(GPS_CountInCategory(listitem) == 0)
        {
            SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"No locations are available in this category.");
            return 1;
        }

        new list[768], line[48];
        for(new i = 0; i < g_GPSCount; i++)
        {
            if(GPS_CategoryMatches(GPSData[i][glCategory], listitem))
            {
                format(line, sizeof(line), "%s (%dm)\n", GPSData[i][glName],
                    floatround(GetPlayerDistanceFromPoint(playerid, GPSData[i][glLocX], GPSData[i][glLocY], GPSData[i][glLocZ])));
                strcat(list, line);
            }
        }

        new title[32];
        format(title, sizeof(title), "GPS - %s", GPS_CATEGORY_NAMES[listitem]);
        ShowPlayerDialog(playerid, DIALOG_GPS_LOCATION, DIALOG_STYLE_LIST, title, list, "Select", "Cancel");
        return 1;
    }

    if(dialogid == DIALOG_GPS_LOCATION)
    {
        if(!response) return 1; // Cancel

        if(g_ExamAState[playerid] != EXAMA_STATE_NONE || g_ExamState[playerid] != EXAM_STATE_NONE ||
           g_ExamCState[playerid] != EXAMC_STATE_NONE || g_ExamDState[playerid] != EXAMD_STATE_NONE)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You can't use GPS during an exam."), 1;

        // Factiuni: listitem indexeaza direct lista de factiuni-cu-HQ construita mai sus, in aceeasi ordine
        if(g_GPSDialogCategory[playerid] == 1)
        {
            new fid = 0, count = 0;
            for(new i = 1; i <= MAX_FACTIONS; i++)
            {
                if(FactionData[i][fHQX] == 0.0 && FactionData[i][fHQY] == 0.0) continue;
                if(count == listitem) { fid = i; break; }
                count++;
            }

            if(fid == 0)
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Unknown location."), 1;

            SetPlayerCheckpoint(playerid, FactionData[fid][fHQX], FactionData[fid][fHQY], FactionData[fid][fHQZ], GPS_CP_SIZE);
            g_GPSActive[playerid] = true;

            new gmsg[128];
            format(gmsg, sizeof(gmsg), C_SUCCESS"Success: "C_WHITE"GPS checkpoint set to "C_INFO"%s"C_WHITE".", FactionData[fid][fName]);
            SendClientMessage(playerid, COLOR_SUCCESS, gmsg);
            return 1;
        }

        // Business: listitem indexeaza direct BusinessData
        if(g_GPSDialogCategory[playerid] == 2)
        {
            if(listitem < 0 || listitem >= g_BusinessCount)
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Unknown location."), 1;

            SetPlayerCheckpoint(playerid, BusinessData[listitem][bLocX], BusinessData[listitem][bLocY], BusinessData[listitem][bLocZ], GPS_CP_SIZE);
            g_GPSActive[playerid] = true;

            new gmsg[128];
            format(gmsg, sizeof(gmsg), C_SUCCESS"Success: "C_WHITE"GPS checkpoint set to "C_INFO"%s"C_WHITE".", BusinessData[listitem][bName]);
            SendClientMessage(playerid, COLOR_SUCCESS, gmsg);
            return 1;
        }

        new gidx = GPS_GetNthInCategory(g_GPSDialogCategory[playerid], listitem);
        if(gidx == -1)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Unknown location."), 1;

        SetPlayerCheckpoint(playerid, GPSData[gidx][glLocX], GPSData[gidx][glLocY], GPSData[gidx][glLocZ], GPS_CP_SIZE);
        g_GPSActive[playerid] = true;

        new gmsg[128];
        format(gmsg, sizeof(gmsg), C_SUCCESS"Success: "C_WHITE"GPS checkpoint set to "C_INFO"%s"C_WHITE".", GPSData[gidx][glName]);
        SendClientMessage(playerid, COLOR_SUCCESS, gmsg);
        return 1;
    }

    return 0;
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

    // A iesit din autobuz in timpul examenului D (inainte de ultimul checkpoint) -> pica si autobuzul respawneaza
    if(oldstate == PLAYER_STATE_DRIVER && newstate != PLAYER_STATE_DRIVER && g_ExamDState[playerid] == EXAMD_STATE_DRIVING)
        ExamD_Fail(playerid, "You got out of the bus.");

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
        if(vehid >= 0 && vehid < MAX_VEHICLES && IsExamDCarVehicle(vehid))
        {
            new examUser = ExamD_GetCarUser(vehid);
            if(examUser != -1 && examUser != playerid)
            {
                RemovePlayerFromVehicle(playerid);
                SendClientMessage(playerid, COLOR_ERROR,
                    C_ERROR"Error: "C_WHITE"This bus is being used for an exam.");
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

            if(!IsExamACarVehicle(vehid) && !IsExamBCarVehicle(vehid) && !IsExamCTruckVehicle(vehid) && !IsExamDCarVehicle(vehid) && !IsRentCarVehicle(vehid) && !IsRentCarDesertVehicle(vehid) && !IsRentCarVehicle2(vehid))
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

            if(IsRentCarVehicle(vehid) || IsRentCarDesertVehicle(vehid) || IsRentCarVehicle2(vehid))
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
                    Vehicle_SetLocked(vehid, true); g_GPSActive[playerid] = false;

                    SendClientMessage(playerid, COLOR_INFO,
                        C_INFO"Info: "C_WHITE"The exam has started! You have "C_INFO"45 seconds"C_WHITE" to reach the next checkpoint.");
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
                    Vehicle_SetLocked(vehid, true); g_GPSActive[playerid] = false;

                    SendClientMessage(playerid, COLOR_INFO,
                        C_INFO"Info: "C_WHITE"The exam has started! You have "C_INFO"45 seconds"C_WHITE" to reach the next checkpoint.");
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
                    Vehicle_SetLocked(vehid, true); g_GPSActive[playerid] = false;

                    SendClientMessage(playerid, COLOR_INFO,
                        C_INFO"Info: "C_WHITE"Now attach a "C_INFO"trailer"C_WHITE" within "C_INFO"45 seconds"C_WHITE" to continue the exam.");
                }
            }

            if(IsExamDCarVehicle(vehid))
            {
                new examUser = ExamD_GetCarUser(vehid);
                if(examUser != -1 && examUser != playerid)
                {
                    RemovePlayerFromVehicle(playerid);
                    SendClientMessage(playerid, COLOR_ERROR,
                        C_ERROR"Error: "C_WHITE"This bus is being used for an exam.");
                }
                else if(g_ExamDState[playerid] != EXAMD_STATE_WAITING_CAR)
                {
                    RemovePlayerFromVehicle(playerid);
                    SendClientMessage(playerid, COLOR_ERROR,
                        C_ERROR"Error: "C_WHITE"You must use "C_INFO"/examD"C_WHITE" to use this bus.");
                }
                else
                {
                    ExamD_KillTimer(playerid);
                    g_ExamDState[playerid]      = EXAMD_STATE_DRIVING;
                    g_ExamDVehicle[playerid]    = vehid;
                    g_ExamDCheckpoint[playerid] = 0;
                    ExamD_GotoCheckpoint(playerid, 0);
                    Vehicle_SetLocked(vehid, true); g_GPSActive[playerid] = false;

                    SendClientMessage(playerid, COLOR_INFO,
                        C_INFO"Info: "C_WHITE"The exam has started! You have "C_INFO"45 seconds"C_WHITE" to reach the next checkpoint.");
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
    // Params nesetate (vehicul nou-creat) sunt -1, nu 0 - fortam engine OFF explicit, ca sa nu fie citit ca "ON"
    new engine, lights, alarm, doors, bonnet, boot, objective;
    GetVehicleParamsEx(vehicleid, engine, lights, alarm, doors, bonnet, boot, objective);
    SetVehicleParamsEx(vehicleid, 0, lights, alarm, doors, bonnet, boot, objective);

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
