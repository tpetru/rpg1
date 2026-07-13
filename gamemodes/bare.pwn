#include <a_samp>
#include <core>
#include <float>
#include <a_mysql>
#include <streamer>
#include <string>
#include <mysql_config>

#pragma tabsize 0
#pragma warning disable 239
#pragma dynamic 32768   // stack/heap marit (default 4096 celule era depasit -> coliziune stack/heap la runtime)

// ============================================================
//  CULORI - GENERAL
// ============================================================
#define COLOR_ERROR     0xFF3333FF
#define COLOR_SUCCESS   0x1A8C1AFF
#define COLOR_INFO      0xBB99FFFF
#define COLOR_WHITE     0xFFFFFFFF
#define COLOR_YELLOW    0xFFFF00FF

#define C_ERROR     "{FF3333}"
#define C_SUCCESS   "{1A8C1A}"
#define C_INFO      "{BB99FF}"
#define C_WHITE     "{FFFFFF}"

// ============================================================
//  CULORI - FACTIUNI
// ============================================================
#define MAX_FACTIONS    8
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
    0xFFCC00FF,  // 7 = Mafia Asiatica      (galben)
    0x85648CFF   // 8 = News Reporters      (mov deschis)
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
forward Job_ReturnTimeout(playerid);
forward Job_StartSource(playerid);
forward Job_StartDest(playerid);
forward Job_PayDelivery(playerid);
forward Job_AddBizIncome(bizId, amount);
forward Float:Job_Dist2D(Float:x1, Float:y1, Float:x2, Float:y2);
forward OnPlayerBanCheck(playerid);
forward Admin_DoKick(playerid);
forward Job_Unfreeze(playerid);
forward Uber_Charge(passenger);
forward OnHouseCreated(playerid, idx);
forward OnBusinessesLoaded();
forward OnBusinessCreated(playerid, idx);
forward OnTurfsLoaded();
forward OnATMsLoaded();
forward OnATMCreated(playerid, idx);
forward OnShopsLoaded();
forward OnShopCreated(playerid, idx);
forward OnFastFoodLoaded();
forward DrugTransport_Loaded(playerid);
forward DrugTransport_Unloaded(playerid);
forward DrugCraft_Finish(playerid);
forward Drug_Unfreeze(playerid);
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
forward OnPhoneSimChecked(playerid, candidate);
forward Phone_RingTimeout(playerid);
forward Phone_CallCharge(playerid);

// ============================================================
//  PAYDAY - SETARI
// ============================================================
new g_PDMinSalary  = 5000;
new g_PDTax        = 10;
new g_PDCASS       = 10;
new Float:g_PDInterest = 0.10;   // 0.1% (10.000.000 -> 10.000 dobanda)
#define BANK_INTEREST_CAP 25000  // dobanda maxima per payday
new g_LastPayDayHour   = -1;
new g_InsurancePrice   = 500;
new g_MedkitPrice      = 500;
new g_ExtinguisherPrice = 500;
new g_ITPPrice         = 750;
new g_PlatePrice       = 250;
new g_RentBikePrice    = 15;
new g_ExamAPrice       = 200;
new g_ExamBPrice       = 300;
new g_ExamCPrice       = 500;
new g_ExamDPrice       = 400;
new g_ExamPPrice       = 1000;  // examen avion (Airplane A)
new g_ExamHPrice       = 1000;  // examen elicopter (Airplane H)
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
    pAirLicA_exp[11], pAirLicH_exp[11], // permis avion: A = avioane, H = elicoptere
    bool:pLogged, bool:pRegistered, bool:pOnDuty,
    bool:pDiseased, pDiseasePaydays,
    pCaravanKey,
    pFarmKey, // id-ul fermei detinute (0 = niciuna)
    bool:pIsPresident, bool:pVoted, bool:pWasPresident,
    pJob,
    pPhoneModel, pPhoneNumber, // telefon: index marca (0-4, -1 = fara telefon), numar (7 cifre, 0 = fara SIM)
    pMedkits, pExtinguishers,  // inventar: medical kit-uri / extinctoare cumparate din /shop, neaplicate inca
    pMuteExpire,               // timestamp unix pana cand jucatorul e mutat (0 = nu e mutat)
    pWanted,                   // nivel wanted (0-6), setat de politie; persistat in DB
    pJailSeconds               // secunde ramase de stat in inchisoare; persistat in DB
}
new PlayerData[MAX_PLAYERS][E_PLAYER_DATA];

#define MAX_JOBS 10 // numarul maxim de joburi (/getjob 1-10)

// ============================================================
//  FACTIUNI
// ============================================================
enum E_FACTION_DATA
{
    fID, fName[32], fMembers, fLead[24], fBank,
    fPickupID, fMapIconID,
    Float:fHQX, Float:fHQY, Float:fHQZ,
    Float:fInteriorX, Float:fInteriorY, Float:fInteriorZ,
    fInterior, fvw,
    fSeifHerbs, fSeifDrugs // seif mafie: iarba (g) si drugs (g)
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

// ============================================================
//  PERMISE AVION (A = avioane, H = elicoptere)
// ============================================================
#define AIR_LIC_NONE 0
#define AIR_LIC_A    1  // avioane
#define AIR_LIC_H    2  // elicoptere

// Returneaza categoria de permis avion necesara pentru un model (AIR_LIC_NONE/A/H)
stock GetAircraftLicenseCategory(model)
{
    static const planeModels[11] = {592, 577, 511, 512, 593, 520, 553, 476, 519, 460, 513};
    static const heliModels[9]   = {548, 425, 417, 487, 488, 497, 563, 447, 469};

    for(new i = 0; i < sizeof(planeModels); i++) if(planeModels[i] == model) return AIR_LIC_A;
    for(new i = 0; i < sizeof(heliModels);  i++) if(heliModels[i]  == model) return AIR_LIC_H;
    return AIR_LIC_NONE;
}

// Verifica daca playerul are permisul de avion valid (existent si neexpirat) pentru categoria data
stock bool:Player_HasValidAirLicense(playerid, category)
{
    new expTs;
    switch(category)
    {
        case AIR_LIC_A:
        {
            if(!strlen(PlayerData[playerid][pAirLicA_exp])) return false;
            expTs = DateStrToUnix(PlayerData[playerid][pAirLicA_exp]);
        }
        case AIR_LIC_H:
        {
            if(!strlen(PlayerData[playerid][pAirLicH_exp])) return false;
            expTs = DateStrToUnix(PlayerData[playerid][pAirLicH_exp]);
        }
        default: return true;
    }
    return expTs > gettime();
}

// Returneaza litera categoriei de avion ("A" / "H")
stock GetAirLicenseCategoryName(category, out[], len)
{
    switch(category)
    {
        case AIR_LIC_A: format(out, len, "A (Airplanes)");
        case AIR_LIC_H: format(out, len, "H (Helicopters)");
        default: format(out, len, "-");
    }
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

// Salveaza in DB continutul seifului unei factiuni (iarba + drugs)
stock Faction_SaveSeif(fid)
{
    if(fid < 1 || fid > MAX_FACTIONS) return;

    new q[128];
    mysql_format(g_SQL, q, sizeof(q), "UPDATE `factions` SET `seif_herbs`=%d, `seif_drugs`=%d WHERE `id`=%d",
        FactionData[fid][fSeifHerbs], FactionData[fid][fSeifDrugs], fid);
    mysql_tquery(g_SQL, q, "", "", 0);
}

new g_TrainID = -1;
new g_FactionPickup[MAX_FACTIONS + 1] = {-1, -1, -1, -1, -1, -1, -1, -1, -1};
new Text3D:g_FactionLabel[MAX_FACTIONS + 1];
new g_FactionInteriorPickup[MAX_FACTIONS + 1] = {-1, -1, -1, -1, -1, -1, -1, -1, -1};
new Text3D:g_FactionInteriorLabel[MAX_FACTIONS + 1];
#define FACTION_INTERIOR_PICKUP_MODEL 19197

// ============================================================
//  NEWS REPORTERS (factiune 8) - stiri live si ziare
// ============================================================
#define NEWS_FACTION_ID     8
#define NEWS_MAX_ITEMS      5
#define NEWS_ITEM_LEN       128

// Ziarul in lucru al reporterului (rank 2+)
new g_NewspaperItem[MAX_PLAYERS][NEWS_MAX_ITEMS][NEWS_ITEM_LEN];
new bool:g_NewspaperCreated[MAX_PLAYERS];

// Copia de ziar detinuta de un player (cumparata cu /accept newspaper)
new g_OwnedNewsItem[MAX_PLAYERS][NEWS_MAX_ITEMS][NEWS_ITEM_LEN];
new bool:g_HasNewspaper[MAX_PLAYERS];
new g_OwnedNewsAuthor[MAX_PLAYERS][24];

// Oferta de vanzare in asteptare (indexata dupa cumparator)
new g_NewsOfferSeller[MAX_PLAYERS];
new g_NewsOfferAmount[MAX_PLAYERS];

// Reseteaza toate ziarele (la payday-ul de la 00:00)
Newspaper_ResetAll()
{
    for(new i = 0; i < MAX_PLAYERS; i++)
    {
        g_NewspaperCreated[i] = false;
        g_HasNewspaper[i]     = false;
        g_NewsOfferSeller[i]  = INVALID_PLAYER_ID;
        g_NewsOfferAmount[i]  = 0;
        g_OwnedNewsAuthor[i][0] = EOS;
        for(new n = 0; n < NEWS_MAX_ITEMS; n++)
        {
            g_NewspaperItem[i][n][0] = EOS;
            g_OwnedNewsItem[i][n][0] = EOS;
        }
    }
}

// ---- Q&A live (reporter rank 3) - o singura sesiune activa pe server ----
#define QA_MAX_QUESTIONS    30
#define QA_Q_LEN            144
new bool:g_QAActive          = false;
new g_QAReporter             = INVALID_PLAYER_ID; // host-ul sesiunii active
new g_QAGuest                = INVALID_PLAYER_ID; // invitatul sesiunii active
new g_QAPendingReporter      = INVALID_PLAYER_ID; // reporter care a trimis invitatia (asteapta accept)
new g_QAPendingGuest         = INVALID_PLAYER_ID; // invitatul care trebuie sa accepte
new g_QAQuestion[QA_MAX_QUESTIONS][QA_Q_LEN];
new g_QAAskerName[QA_MAX_QUESTIONS][24];
new g_QACount                = 0;

// Trimite un mesaj tuturor jucatorilor logati
QA_Broadcast(const text[])
{
    for(new i = 0; i < MAX_PLAYERS; i++)
        if(IsPlayerConnected(i) && PlayerData[i][pLogged])
            SendClientMessage(i, COLOR_WHITE, text);
}

// Sterge intrebarea de pe pozitia qi (0-based) si strange coada
QA_RemoveQuestion(qi)
{
    if(qi < 0 || qi >= g_QACount) return;
    for(new i = qi; i < g_QACount - 1; i++)
    {
        format(g_QAQuestion[i], QA_Q_LEN, "%s", g_QAQuestion[i + 1]);
        format(g_QAAskerName[i], 24, "%s", g_QAAskerName[i + 1]);
    }
    g_QACount--;
    g_QAQuestion[g_QACount][0] = EOS;
    g_QAAskerName[g_QACount][0] = EOS;
}

// Inchide sesiunea Q&A si goleste coada
QA_Reset()
{
    g_QAActive          = false;
    g_QAReporter        = INVALID_PLAYER_ID;
    g_QAGuest           = INVALID_PLAYER_ID;
    g_QAPendingReporter = INVALID_PLAYER_ID;
    g_QAPendingGuest    = INVALID_PLAYER_ID;
    g_QACount           = 0;
    for(new i = 0; i < QA_MAX_QUESTIONS; i++)
    {
        g_QAQuestion[i][0]  = EOS;
        g_QAAskerName[i][0] = EOS;
    }
}

// ============================================================
//  BICICLETE DE INCHIRIAT
// ============================================================
#define MAX_RENT_BIKES  8
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
#define MAX_RENT_CARS    12
#define RENT_CAR_PRICE   30
#define RENT_CAR_BIZ_ID  3

new g_RentCarVehicle[MAX_RENT_CARS] = {-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1};

// Returneaza true daca vehiculul dat e una dintre masinile de inchiriat
stock bool:IsRentCarVehicle(vehid)
{
    for(new i = 0; i < MAX_RENT_CARS; i++)
        if(g_RentCarVehicle[i] == vehid) return true;
    return false;
}


// ============================================================
//  EXAMEN AUTO CATEGORIA A
// ============================================================
#define MAX_EXAMA_CARS        3
#define EXAMA_CAR_MODEL       468 // Sanchez
#define EXAMA_BIZ_ID          5
new Float:EXAMA_LOC_X = 0.0;   // suprascris din locations_admin ("examA")
new Float:EXAMA_LOC_Y = 0.0;
new Float:EXAMA_LOC_Z = 0.0;
#define EXAMA_RANGE           5.0
#define EXAMA_CP_SIZE         5.0
#define EXAMA_STEP_TIME       45000 // 45 secunde, in ms
#define EXAMA_PASS_HEALTH     800.0
#define EXAMA_PASS_DURATION   604800  // 7 zile, in secunde
#define EXAMA_FAIL_DURATION   172800  // 2 zile, in secunde
#define MAX_EXAMA_CHECKPOINTS 15

#define EXAMA_STATE_NONE        0
#define EXAMA_STATE_WAITING_CAR 1
#define EXAMA_STATE_DRIVING     2

new Float:ExamACheckpoints[MAX_EXAMA_CHECKPOINTS][3] = {
    {2479.5181, -1519.3479, 23.6631},
    {2446.2490, -1502.1802, 23.4938},
    {2427.3413, -1440.7948, 23.4960},
    {2392.9199, -1393.8077, 23.5205},
    {2373.7632, -1272.0996, 23.5053},
    {2505.6135, -1258.8060, 34.5433},
    {2642.5374, -1259.2731, 49.5187},
    {2720.2637, -1269.0895, 59.1017},
    {2721.1731, -1493.8816, 29.9495},
    {2676.2427, -1409.4928, 29.9819},
    {2640.5549, -1406.3492, 29.9493},
    {2590.6865, -1441.5521, 33.8178},
    {2445.8987, -1442.8083, 23.4978},
    {2428.0662, -1533.9043, 23.5060},
    {2461.9412, -1553.1794, 23.6719}
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
new Float:EXAMB_LOC_X = 0.0;   // suprascris din locations_admin ("examB")
new Float:EXAMB_LOC_Y = 0.0;
new Float:EXAMB_LOC_Z = 0.0;
#define EXAMB_RANGE           5.0
#define EXAMB_CP_SIZE         5.0
#define EXAMB_STEP_TIME       45000 // 45 secunde, in ms
#define EXAMB_PASS_HEALTH     800.0
#define EXAMB_PASS_DURATION   864000  // 10 zile, in secunde
#define EXAMB_FAIL_DURATION   259200  // 3 zile, in secunde
#define MAX_EXAMB_CHECKPOINTS 14

#define EXAM_STATE_NONE        0
#define EXAM_STATE_WAITING_CAR 1
#define EXAM_STATE_DRIVING     2

new Float:ExamBCheckpoints[MAX_EXAMB_CHECKPOINTS][3] = {
    {504.5715,  -1452.6357, 15.5083},
    {439.5282,  -1451.9370, 29.6128},
    {306.0009,  -1476.2756, 33.0049},
    {259.3398,  -1478.1753, 27.1188},
    {197.4094,  -1520.5747, 13.0941},
    {157.0935,  -1547.3715, 10.6117},
    {111.3023,  -1652.5562, 9.7398},
    {151.3344,  -1740.4871, 4.8910},
    {334.7835,  -1743.9547, 4.2363},
    {344.0608,  -1772.6437, 4.8150},
    {447.4669,  -1773.4774, 5.1757},
    {596.1281,  -1737.6882, 13.0781},
    {636.0414,  -1613.6667, 15.3746},
    {486.8066,  -1528.3212, 19.4628}
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
new Float:EXAMC_LOC_X = 0.0;   // suprascris din locations_admin ("examC")
new Float:EXAMC_LOC_Y = 0.0;
new Float:EXAMC_LOC_Z = 0.0;
#define EXAMC_RANGE              5.0
#define EXAMC_CP_SIZE            5.0
#define EXAMC_STEP_TIME          45000 // 45 secunde, in ms
#define EXAMC_PASS_HEALTH        800.0
#define EXAMC_PASS_DURATION      1036800 // 12 zile, in secunde
#define EXAMC_FAIL_DURATION      259200  // 3 zile, in secunde
#define MAX_EXAMC_CHECKPOINTS    11

#define EXAMC_STATE_NONE            0
#define EXAMC_STATE_WAITING_TRUCK   1
#define EXAMC_STATE_WAITING_TRAILER 2
#define EXAMC_STATE_DRIVING         3

new Float:ExamCCheckpoints[MAX_EXAMC_CHECKPOINTS][3] = {
    {2422.3242, -2093.3274, 14.0774},
    {2479.7256, -2117.2493, 14.1326},
    {2446.4546, -2087.4189, 14.1444},
    {2416.3779, -1985.5095, 13.9575},
    {2231.2905, -1970.1224, 13.9605},
    {2270.8047, -2071.3318, 13.9721},
    {2432.8650, -2051.6885, 23.3405},
    {2693.0410, -2051.4683, 13.9480},
    {2716.3013, -1950.2334, 13.9274},
    {2472.5869, -1930.5250, 13.9493},
    {2411.3777, -2061.6150, 13.9391}
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
new Float:EXAMD_LOC_X = 0.0;   // suprascris din locations_admin ("examD")
new Float:EXAMD_LOC_Y = 0.0;
new Float:EXAMD_LOC_Z = 0.0;
#define EXAMD_RANGE           5.0
#define EXAMD_CP_SIZE         5.0
#define EXAMD_STEP_TIME       45000 // 45 secunde, in ms
#define EXAMD_PASS_HEALTH     800.0
#define EXAMD_PASS_DURATION   1123200 // 13 zile, in secunde
#define EXAMD_FAIL_DURATION   259200  // 3 zile, in secunde
#define MAX_EXAMD_CHECKPOINTS 9

#define EXAMD_STATE_NONE        0
#define EXAMD_STATE_WAITING_CAR 1
#define EXAMD_STATE_DRIVING     2

new Float:ExamDCheckpoints[MAX_EXAMD_CHECKPOINTS][3] = {
    {1801.9431, -1889.8314, 13.5340},
    {1818.8110, -1926.6517, 13.5095},
    {1944.9701, -1935.4471, 13.5161},
    {1963.8546, -1768.4059, 13.5162},
    {2083.2180, -1739.8503, 13.5166},
    {2062.2559, -1610.1251, 13.5177},
    {1999.3108, -1734.3137, 13.5164},
    {1837.5396, -1749.4659, 13.5162},
    {1813.0925, -1886.7690, 13.5815}
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

// ============================================================
//  JOB 1 - GLOVO (livrari) - stare runtime
// ============================================================
#define JOB_GLOVO            1
#define JOB_GLOVO_BIZ_ID     16    // business-ul care primeste cota din fiecare livrare
#define JOB_GLOVO_BIZ_CUT    5     // $ catre biz dupa fiecare livrare
#define JOB_GLOVO_BASE_PAY   100   // plata de baza per livrare
#define JOB_GLOVO_PAY_PER_M  2     // $ per unitate de distanta 2D (pickup -> casa)
#define JOB_CP_SIZE          6.0
#define JOB_RETURN_GRACE     30    // secunde sa revii in masina de lucru
#define MAX_GLOVO_VEHICLES   8

// Job 2 - Cement Truck Driver
#define JOB_CEMENT           2
#define JOB_CEMENT_BASE_PAY  2000  // plata de baza per cursa de ciment
#define JOB_CEMENT_PAY_PER_M 1     // $ per unitate de distanta 2D (load -> unload)
#define MAX_CEMENT_VEHICLES  4

// Job 3 - Gun Delivery
#define JOB_GUN              3
#define JOB_GUN_BASE_PAY     500   // plata de baza per livrare de arme
#define JOB_GUN_PAY_PER_M    1     // $ per unitate de distanta 2D (load -> HQ mafie)
#define MAX_GUN_VEHICLES     3
// Puncte de incarcare arme (aleatoriu)
new Float:g_GunLoad[4][3] = {
    {2796.7163, -2499.9944, 13.7082},
    {2779.1350, -2487.9683, 13.7250},
    {2787.2561, -2449.5754, 13.7051},
    {2796.2278, -2415.9189, 13.6993}
};
// Puncte fixe de descarcare arme (pe langa HQ-urile mafiilor 4-7)
new Float:g_GunUnload[4][3] = {
    {1366.3796, -1280.0173, 13.2739},
    {1791.4491, -1164.2979, 23.8281},
    {1606.1707, -1709.8176, 13.2740},
    {2399.0107, -1979.8297, 13.2740}
};

// Job 4 - Car Transportator
#define JOB_TRANSPORT        4
#define JOB_TRANSPORT_BASE_PAY  1500   // plata de baza per transport
#define JOB_TRANSPORT_PAY_PER_M 1      // $ per unitate de distanta 2D (load -> unload)
#define MAX_TRANSPORT_VEHICLES  3

// Job 6 - Emergency Logistics Driver (livrare provizii medicale catre shop-urile [ Shop ])
#define JOB_EMERGENCY            6
#define JOB_EMERGENCY_BASE_PAY   700   // plata de baza per livrare
#define JOB_EMERGENCY_PAY_PER_M  1     // $ per unitate de distanta 2D (load -> shop)
#define MAX_EMERGENCY_VEHICLES   4     // 2 Bobcat + 2 Burrito la depou
#define MAX_EMERGENCY_LOADPOINTS 4

// Job 7 - Bus Driver (rute fixe cu checkpoint-uri; /bus [1-3])
#define JOB_BUS                  7
#define JOB_BUS_CP_PAY           300    // plata la fiecare checkpoint atins
#define JOB_BUS_PAY_PER_M        1      // $ per unitate de distanta 2D (cp anterior -> cp curent)
#define JOB_BUS_FINISH_BONUS     1000   // bonus la finalul rutei
#define BUS_MODEL                431
#define MAX_BUS_VEHICLES         4
#define MAX_BUS_LINES            3
#define MAX_BUS_CHECKPOINTS      27     // maxim checkpoint-uri per linie
#define BUS_CP_SIZE              5.0
#define BUS_FARE                 100    // taxa pe care o plateste automat un pasager cand se urca

#define JOB_STAGE_NONE       0
#define JOB_STAGE_PICKUP     1     // mergi la sursa (restaurant / fabrica de ciment)
#define JOB_STAGE_DELIVER    2     // mergi la destinatie (casa / santier)
#define JOB_UNLOADS_PER_LOAD 2     // cate descarcari se fac dupa o incarcare, inainte de a reveni la load

new g_GlovoVehicle[MAX_GLOVO_VEHICLES];
new g_CementVehicle[MAX_CEMENT_VEHICLES];
new g_GunVehicle[MAX_GUN_VEHICLES];
new g_TransportVehicle[MAX_TRANSPORT_VEHICLES];
new g_EmergencyVehicle[MAX_EMERGENCY_VEHICLES];
new g_BusVehicle[MAX_BUS_VEHICLES];

// Rutele de autobuz (checkpoint-uri). Linia 1 are 18 statii, linia 2 are 27; linia 3 neconfigurata.
new const Float:g_BusRoute[MAX_BUS_LINES][MAX_BUS_CHECKPOINTS][3] = {
    { // linia 1 (18 statii)
        {1431.9585, -2301.6685, 13.4755},
        {1357.9236, -2273.1279, 13.4822},
        {1572.0150, -2120.4258, 16.2865},
        {1633.4972, -1820.8115, 26.5235},
        {1635.1697, -1604.2130, 28.6164},
        {1874.1375, -1519.3989,  3.3653},
        {2162.4192, -1558.0868,  2.3554},
        {2458.8350, -1622.4037, 15.3976},
        {2709.8962, -1627.2876, 13.2461},
        {2838.9270, -1659.8217, 10.7964},
        {2819.8853, -1907.2726, 11.0366},
        {2730.4597, -2151.8865, 11.0331},
        {2306.9209, -2242.5627, 13.4756},
        {2157.3621, -2527.2581, 13.4756},
        {1988.2135, -2667.9309,  9.2859},
        {1453.8038, -2667.3308, 13.0074},
        {1348.2158, -2410.4878, 13.4759},
        {1416.0830, -2289.0371, 13.4832},
        {0.0,0.0,0.0},{0.0,0.0,0.0},{0.0,0.0,0.0},{0.0,0.0,0.0},{0.0,0.0,0.0},
        {0.0,0.0,0.0},{0.0,0.0,0.0},{0.0,0.0,0.0},{0.0,0.0,0.0}
    },
    { // linia 2 (27 statii)
        {1425.5400, -2283.4775, 13.4818},
        {1470.7073, -2335.9094, 13.4804},
        {1422.7953, -2375.6055, 16.4484},
        {1326.5377, -2329.4338, 13.4869},
        {1318.3137, -2433.1787,  8.7736},
        {1136.3953, -2378.7195, 11.5033},
        {1050.4734, -2076.8840, 13.0429},
        {1060.6907, -1901.7083, 13.0942},
        { 834.0831, -1766.8604, 13.4944},
        { 635.0814, -1712.8989, 14.3294},
        { 615.7697, -1582.7186, 15.9944},
        { 542.8235, -1567.3887, 16.0027},
        { 600.1449, -1408.6462, 13.4914},
        {1048.5167, -1407.5127, 13.4364},
        {1202.9115, -1386.5382, 13.3007},
        {1324.4363, -1282.9692, 13.4846},
        {1302.9524, -1543.5864, 13.4835},
        {1299.1555, -1840.2660, 13.4834},
        {1498.4246, -1874.2264, 13.4835},
        {1551.2250, -2096.1519, 34.0557},
        {1882.0103, -2168.3818, 13.4834},
        {2131.2534, -2214.3882, 13.4847},
        {2158.7129, -2532.3252, 13.4777},
        {1578.4894, -2667.2209,  6.0712},
        {1360.1135, -2476.4082,  8.2271},
        {1350.4290, -2346.9434, 13.4894},
        {1424.7383, -2296.1458, 13.5228}
    },
    { // linia 3 (neconfigurata)
        {0.0,0.0,0.0},{0.0,0.0,0.0},{0.0,0.0,0.0},{0.0,0.0,0.0},{0.0,0.0,0.0},{0.0,0.0,0.0},{0.0,0.0,0.0},
        {0.0,0.0,0.0},{0.0,0.0,0.0},{0.0,0.0,0.0},{0.0,0.0,0.0},{0.0,0.0,0.0},{0.0,0.0,0.0},{0.0,0.0,0.0},
        {0.0,0.0,0.0},{0.0,0.0,0.0},{0.0,0.0,0.0},{0.0,0.0,0.0},{0.0,0.0,0.0},{0.0,0.0,0.0},{0.0,0.0,0.0},
        {0.0,0.0,0.0},{0.0,0.0,0.0},{0.0,0.0,0.0},{0.0,0.0,0.0},{0.0,0.0,0.0},{0.0,0.0,0.0}
    }
};
new const g_BusRouteCount[MAX_BUS_LINES] = { 18, 27, 0 };

new g_BusLine[MAX_PLAYERS];       // 0 = nu conduce nicio ruta; 1-3 = linia activa
new g_BusCP[MAX_PLAYERS];         // indexul checkpoint-ului curent (0-based)
new Float:g_BusLastX[MAX_PLAYERS], Float:g_BusLastY[MAX_PLAYERS]; // pozitia checkpoint-ului anterior (pt distanta)

// ============================================================
//  RACE EVENTS (BestLap) - /event race / join / start / stop
// ============================================================
#define MAX_RACE_LAPS       3
#define MAX_RACE_CP         20
#define RACE_CP_SIZE        6.0
#define RACE_COUNTDOWN_SEC  5
#define RACE_TIMEOUT_MS     300000   // 5 minute -> oprire fortata
#define RACE_VW_BASE        100      // vw = RACE_VW_BASE + playerid (fiecare in lumea lui)

#define RACE_STATE_NONE     0
#define RACE_STATE_SIGNUP   1        // admin a deschis, jucatorii se inscriu
#define RACE_STATE_RUNNING  2        // cursa in desfasurare

#define RACE_VEH_COUNT      6
new const g_RaceVehModels[RACE_VEH_COUNT]    = { 541, 411, 562, 560, 522, 475 };
new const g_RaceVehKey[RACE_VEH_COUNT][12]   = { "bullet", "infernus", "elegy", "stratum", "nrg", "sabre" };
new const g_RaceVehNames[RACE_VEH_COUNT][12] = { "Bullet", "Infernus", "Elegy", "Stratum", "NRG-500", "Sabre" };

new const g_RaceLapName[MAX_RACE_LAPS][8]    = { "Lap1", "Lap2", "Lap3" };
new const g_RaceCPCount[MAX_RACE_LAPS]       = { 8, 20, 20 };
new const Float:g_RaceStartA[MAX_RACE_LAPS]  = { 178.6069, 0.1279, 273.6426 };

new const Float:g_RaceRoute[MAX_RACE_LAPS][MAX_RACE_CP][3] = {
    { // Lap1 (8 CP)
        {2605.1707, -1472.6241, 16.4534},
        {2582.9429, -1633.6659,  2.4361},
        {2465.8970, -1850.3326,  1.3494},
        {1893.1073, -1827.3865,  3.7046},
        {1635.5002, -1766.8109,  3.6727},
        {1370.1033, -1709.4420,  8.5767},
        {1388.4249, -1503.6621,  8.3937},
        {1410.4387, -1313.8179,  9.0590},
        {0.0,0.0,0.0},{0.0,0.0,0.0},{0.0,0.0,0.0},{0.0,0.0,0.0},{0.0,0.0,0.0},{0.0,0.0,0.0},
        {0.0,0.0,0.0},{0.0,0.0,0.0},{0.0,0.0,0.0},{0.0,0.0,0.0},{0.0,0.0,0.0},{0.0,0.0,0.0}
    },
    { // Lap2 (20 CP)
        {1580.3252, -1153.0703, 23.6239},
        {1565.6978, -1077.9589, 23.2448},
        {1409.1250, -1032.8496, 23.6068},
        {1374.2716,  -976.2896, 32.0049},
        {1207.8025,  -937.6534, 42.4536},
        { 893.7263,  -982.5880, 36.8706},
        { 750.1914, -1060.4253, 23.2962},
        { 595.7969, -1219.6530, 17.6354},
        { 189.4673, -1493.1193, 12.3045},
        { 111.3744, -1630.4452,  9.8706},
        { 175.5263, -1737.9240,  3.8864},
        { 340.1557, -1750.1292,  4.1582},
        { 372.7091, -1774.9583,  5.0976},
        { 461.4944, -1734.1646,  9.6554},
        { 749.8878, -1779.2998, 12.5341},
        {1108.5374, -1853.1766, 13.1047},
        {1315.1792, -1838.5227, 13.1031},
        {1362.0209, -1734.1315, 13.1047},
        {1531.6903, -1674.5566, 13.1002},
        {1542.6736, -1628.1552, 13.0888}
    },
    { // Lap3 (20 CP)
        {1744.0759, -1455.7893, 13.1542},
        {1938.2386, -1465.3813, 13.0069},
        {2130.7861, -1439.6023, 23.4530},
        {2070.4951, -1286.5313, 23.4444},
        {2128.9172, -1113.6912, 24.8166},
        {2339.2415, -1120.4597, 28.7157},
        {2566.3489, -1054.3274, 69.1073},
        {2640.8584, -1073.5317, 69.0780},
        {2640.9114, -1275.2339, 48.8905},
        {2676.6843, -1489.9058, 30.0385},
        {2721.3120, -1629.7285, 12.4689},
        {2831.6689, -1658.4220, 10.3197},
        {2823.1726, -1905.4618, 10.5622},
        {2654.3896, -2047.0558, 19.4851},
        {2348.5737, -2047.7664, 12.9975},
        {2214.7117, -1995.7489, 12.9881},
        {2172.3630, -1892.3920, 12.9754},
        {2099.8931, -1735.8873, 13.0232},
        {2114.2922, -1502.9583, 23.4131},
        {1743.7234, -1456.2620, 13.1507}
    }
};

// Recorduri incarcate din tabela `races` (indexate [lap][veh])
new Float:g_RaceRecordTime[MAX_RACE_LAPS][RACE_VEH_COUNT];
new g_RaceRecordHolder[MAX_RACE_LAPS][RACE_VEH_COUNT][24];
new g_RaceRecordID[MAX_RACE_LAPS][RACE_VEH_COUNT];

// Starea evenimentului (un singur eveniment activ global)
new g_RaceState       = RACE_STATE_NONE;
new g_RaceLap         = 0;    // 0-based
new g_RaceVehModel    = -1;   // -1 = random per jucator
new g_RaceCountdown   = 0;
new g_RaceFinishOrder = 0;    // cati au terminat pana acum
new g_RaceTotal       = 0;    // participanti la start
new g_RaceTimeoutTimer   = -1;
new g_RaceCountdownTimer = -1;

new bool:g_RaceIn[MAX_PLAYERS];    // e participant
new g_RaceVehicle[MAX_PLAYERS];    // vehiculul creat pentru cursa (0 = niciunul)
new g_RaceCP[MAX_PLAYERS];         // index checkpoint tinta curent
new g_RaceStartTick[MAX_PLAYERS];  // tick la GOGOGO
new bool:g_RaceDone[MAX_PLAYERS];  // a terminat cursa
new g_RaceVehUsed[MAX_PLAYERS];    // modelul folosit efectiv (pt record)

forward OnRacesLoaded();
forward Race_CountdownTick();
forward Race_Timeout();

// ============================================================
//  ANTICHEAT (interior / vw / arme / teleport) - server-authoritative
//  Orice actiune legitima a scriptului trece prin wrapperele AC_* (inlocuite global),
//  care "anunta" AC-ul; un timer (AC_Tick) reconciliaza starea reala cu cea autorizata.
// ============================================================
#define AC_TICK               1000    // ms
#define AC_TP_THRESHOLD_2D    60.0    // metri pe jos intr-un tick -> teleport (imposibil legitim)
#define AC_GRACE_MS           5000    // ignora verificarile atat dupa spawn/teleport legitim
#define AC_MAX_WEAPON_ID      47

new Float:g_ACLastX[MAX_PLAYERS], Float:g_ACLastY[MAX_PLAYERS], Float:g_ACLastZ[MAX_PLAYERS];
new bool:g_ACExpectTP[MAX_PLAYERS];
new g_ACInt[MAX_PLAYERS];
new g_ACVW[MAX_PLAYERS];
new g_ACGrace[MAX_PLAYERS];
new bool:g_ACWeaponAllowed[MAX_PLAYERS][AC_MAX_WEAPON_ID];
new g_ACWeaponAmmo[MAX_PLAYERS][AC_MAX_WEAPON_ID];

// --- Wrappere peste native: marcheaza actiunea ca legitima, apoi cheama native-ul ---
stock AC_SetInterior(playerid, interiorid)
{
    g_ACInt[playerid] = interiorid;
    return SetPlayerInterior(playerid, interiorid);
}
stock AC_SetVW(playerid, vw)
{
    g_ACVW[playerid] = vw;
    return SetPlayerVirtualWorld(playerid, vw);
}
stock AC_SetPos(playerid, Float:x, Float:y, Float:z)
{
    g_ACExpectTP[playerid] = true;
    g_ACLastX[playerid] = x;
    g_ACLastY[playerid] = y;
    g_ACLastZ[playerid] = z;
    g_ACGrace[playerid] = GetTickCount() + AC_GRACE_MS;
    return SetPlayerPos(playerid, x, y, z);
}
stock AC_GiveWeapon(playerid, weaponid, ammo)
{
    if(weaponid > 0 && weaponid < AC_MAX_WEAPON_ID)
    {
        g_ACWeaponAllowed[playerid][weaponid] = true;
        g_ACWeaponAmmo[playerid][weaponid] += ammo;
    }
    return GivePlayerWeapon(playerid, weaponid, ammo);
}

// Sterge evidenta de arme (la spawn/connect jucatorul nu are nicio arma legitima)
stock AC_ResetWeapons(playerid)
{
    for(new w = 0; w < AC_MAX_WEAPON_ID; w++)
    {
        g_ACWeaponAllowed[playerid][w] = false;
        g_ACWeaponAmmo[playerid][w] = 0;
    }
}

// Initializeaza starea AC (la connect)
stock AC_InitPlayer(playerid)
{
    g_ACInt[playerid] = 0;
    g_ACVW[playerid]  = 0;
    g_ACExpectTP[playerid] = true;
    g_ACGrace[playerid] = GetTickCount() + AC_GRACE_MS;
    AC_ResetWeapons(playerid);
    GetPlayerPos(playerid, g_ACLastX[playerid], g_ACLastY[playerid], g_ACLastZ[playerid]);
}

// Restaureaza doar armele permise (dupa ce s-a detectat una ilegala)
stock AC_RestoreWeapons(playerid)
{
    ResetPlayerWeapons(playerid);
    for(new w = 1; w < AC_MAX_WEAPON_ID; w++)
        if(g_ACWeaponAllowed[playerid][w] && g_ACWeaponAmmo[playerid][w] > 0)
            GivePlayerWeapon(playerid, w, g_ACWeaponAmmo[playerid][w]);
}

// Alerteaza adminii online + log in consola
stock AC_Flag(playerid, const reason[])
{
    new msg[144];
    format(msg, sizeof(msg), C_ERROR"[AC] "C_WHITE"%s (ID %d): "C_INFO"%s"C_WHITE" - detected & corrected.",
        PlayerData[playerid][pName], playerid, reason);
    for(new i = 0; i < MAX_PLAYERS; i++)
        if(IsPlayerConnected(i) && PlayerData[i][pLogged] && PlayerData[i][pAdminLevel] >= 1)
            SendClientMessage(i, COLOR_ERROR, msg);
    printf("[AC] %s (ID %d): %s", PlayerData[playerid][pName], playerid, reason);
}

forward AC_Tick();
public AC_Tick()
{
    new tick = GetTickCount();
    for(new i = 0; i < MAX_PLAYERS; i++)
    {
        if(!IsPlayerConnected(i) || !PlayerData[i][pLogged]) continue;

        new pstate = GetPlayerState(i);
        if(pstate == PLAYER_STATE_WASTED || pstate == PLAYER_STATE_SPECTATING || pstate == PLAYER_STATE_NONE) continue;

        // Perioada de gratie (dupa spawn/teleport legitim): doar actualizeaza referintele
        if(tick < g_ACGrace[i])
        {
            GetPlayerPos(i, g_ACLastX[i], g_ACLastY[i], g_ACLastZ[i]);
            g_ACExpectTP[i] = false;
            continue;
        }

        // 1) Interior neautorizat
        if(GetPlayerInterior(i) != g_ACInt[i])
        {
            AC_Flag(i, "interior change");
            SetPlayerInterior(i, g_ACInt[i]);
        }
        // 2) Virtual World neautorizat
        if(GetPlayerVirtualWorld(i) != g_ACVW[i])
        {
            AC_Flag(i, "virtual world change");
            SetPlayerVirtualWorld(i, g_ACVW[i]);
        }
        // 3) Arma neautorizata (nu a fost data de script)
        for(new slot = 0; slot < 13; slot++)
        {
            new wid, wammo;
            GetPlayerWeaponData(i, slot, wid, wammo);
            if(wid > 0 && (wid >= AC_MAX_WEAPON_ID || !g_ACWeaponAllowed[i][wid]))
            {
                AC_Flag(i, "illegal weapon");
                AC_RestoreWeapons(i);
                break;
            }
        }
        // 4) Teleport pe jos (viteza imposibila 2D)
        new Float:x, Float:y, Float:z;
        GetPlayerPos(i, x, y, z);
        if(pstate == PLAYER_STATE_ONFOOT && !g_ACExpectTP[i])
        {
            new Float:dx = x - g_ACLastX[i], Float:dy = y - g_ACLastY[i];
            if(floatsqroot(dx*dx + dy*dy) > AC_TP_THRESHOLD_2D)
            {
                AC_Flag(i, "teleport");
                SetPlayerPos(i, g_ACLastX[i], g_ACLastY[i], g_ACLastZ[i]);
                g_ACGrace[i] = tick + AC_GRACE_MS;
                continue; // nu actualiza referinta cu pozitia ilegala
            }
        }
        g_ACExpectTP[i] = false;
        g_ACLastX[i] = x; g_ACLastY[i] = y; g_ACLastZ[i] = z;
    }
    return 1;
}

// ============================================================
//  HUNTING (Vanatoare) - Padure 1, caprioare (obiect 19315), sniper
// ============================================================
#define HUNT_DEER_MODEL      19315
#define HUNT_SPAWN_COUNT     31
#define HUNT_DEER_Z_OFFSET   0.0     // ajusteaza daca obiectul pluteste/intra in pamant
#define HUNT_FLEE_RANGE      30.0    // te apropii sub asta -> caprioara fuge
#define HUNT_RESPAWN_MS      8000    // reapare dupa ce a fost vanata / a fugit
#define HUNT_MAX_MEAT        3       // maxim caprioare purtate
#define HUNT_PAYOUT          2500    // $ per caprioara la shop
#define HUNT_SNIPER          34      // Sniper Rifle
#define HUNT_SNIPER_AMMO     20
#define HUNT_SELL_RANGE      4.0     // raza fata de un shop pentru vanzare
#define HUNT_HIT_RADIUS      2.5     // glontul trece la <= atat de caprioara -> lovitura
#define HUNT_NEARMISS_RADIUS 8.0     // <= atat dar peste HIT -> ratare aproape (fuge)
#define HUNT_START_RANGE     6.0     // trebuie sa fii la spotul /hunt
#define HUNT_PICKUP_MODEL    358     // model sniper (marker vizual la spotul /hunt)
#define HUNT_MAPICON_ID      23      // map icon pentru spotul de vanatoare
// Coordonatele spotului /hunt - suprascrise din locations_admin (locID 24)
new Float:g_HuntStartX = -418.3721;
new Float:g_HuntStartY = -1759.6816;
new Float:g_HuntStartZ = 6.2188;

new const Float:g_HuntSpawn[HUNT_SPAWN_COUNT][3] = {
    {-537.2568, -1854.7827, 17.6421},
    {-740.3446, -1834.9449, 20.4195},
    {-745.6627, -1879.6664,  7.3637},
    {-631.4255, -1880.2915, 10.2420},
    {-556.9229, -1844.8096, 23.6721},
    {-463.1077, -1858.9150,  8.7767},
    {-501.6665, -1883.4086,  6.9162},
    {-540.7300, -1901.6730,  6.6735},
    {-475.8235, -1933.3390, 16.7617},
    {-578.3080, -1946.9349, 37.4607},
    {-634.6374, -1942.1870, 24.2231},
    {-595.0672, -1985.1296, 42.5277},
    {-580.5845, -2000.1544, 46.2056},
    {-582.4641, -2057.2344, 48.2717},
    {-541.9572, -2070.2976, 57.5569},
    {-617.5294, -2089.0710, 33.7676},
    {-666.4946, -2123.5256, 26.8630},
    {-674.7985, -2159.2278, 23.6123},
    {-709.5779, -2157.0793, 23.2453},
    {-730.9156, -2148.1003, 25.2554},
    {-776.0397, -2102.1418, 23.7720},
    {-761.4037, -2083.6672,  9.1514},
    {-826.7884, -2026.1710, 23.0104},
    {-818.8213, -1952.7219,  6.5954},
    {-907.0889, -1989.7632, 49.2356},
    {-941.2412, -1946.5924, 44.9338},
    {-772.4939, -1849.8960, 25.4336},
    {-626.8541, -1825.9879, 26.8658},
    {-562.2267, -1898.9149,  6.0865},
    {-594.8085, -1939.2736, 31.8823},
    {-579.3868, -1978.6750, 43.6208}
};

new STREAMER_TAG_OBJECT:g_HuntDeer[HUNT_SPAWN_COUNT]; // obiectul caprioarei (INVALID = despawnata)
new g_HuntDeerRespawn[HUNT_SPAWN_COUNT];               // tick cand reapare (0 = activa acum)
new g_HuntMeat[MAX_PLAYERS];                           // caprioare purtate
new bool:g_HasSniper[MAX_PLAYERS];                     // a luat sniper prin /hunt

stock Hunt_CreateDeer(idx)
{
    if(IsValidDynamicObject(g_HuntDeer[idx])) return;
    g_HuntDeer[idx] = CreateDynamicObject(HUNT_DEER_MODEL,
        g_HuntSpawn[idx][0], g_HuntSpawn[idx][1], g_HuntSpawn[idx][2] + HUNT_DEER_Z_OFFSET,
        0.0, 0.0, float(random(360)));
    g_HuntDeerRespawn[idx] = 0;
}

stock Hunt_RemoveDeer(idx)
{
    if(IsValidDynamicObject(g_HuntDeer[idx]))
        DestroyDynamicObject(g_HuntDeer[idx]);
    g_HuntDeer[idx] = STREAMER_TAG_OBJECT:INVALID_STREAMER_ID;
}

stock Hunt_Init()
{
    for(new i = 0; i < HUNT_SPAWN_COUNT; i++)
    {
        g_HuntDeer[i] = STREAMER_TAG_OBJECT:INVALID_STREAMER_ID;
        g_HuntDeerRespawn[i] = 0;
        Hunt_CreateDeer(i);
    }
    // pickup + map icon + eticheta se creeaza in Locations_ApplyToCommands (dupa ce coord vin din DB)
}

// Returneaza indexul unei caprioare aflate la o distanta < HUNT_FLEE_RANGE de player, sau -1
stock Hunt_PlayerNearSpawn(playerid, idx)
{
    return IsPlayerInRangeOfPoint(playerid, HUNT_FLEE_RANGE, g_HuntSpawn[idx][0], g_HuntSpawn[idx][1], g_HuntSpawn[idx][2]);
}

forward Hunt_Tick();
public Hunt_Tick()
{
    new tick = GetTickCount();
    for(new i = 0; i < HUNT_SPAWN_COUNT; i++)
    {
        if(IsValidDynamicObject(g_HuntDeer[i]))
        {
            // fuge daca un jucator se apropie prea mult
            for(new p = 0; p < MAX_PLAYERS; p++)
            {
                if(!IsPlayerConnected(p) || !PlayerData[p][pLogged]) continue;
                if(Hunt_PlayerNearSpawn(p, i))
                {
                    Hunt_RemoveDeer(i);
                    g_HuntDeerRespawn[i] = tick + HUNT_RESPAWN_MS;
                    if(g_HasSniper[p])
                        SendClientMessage(p, COLOR_INFO, C_INFO"[Hunt] "C_WHITE"A deer sensed you and bolted! Snipe them from a distance.");
                    break;
                }
            }
        }
        else if(g_HuntDeerRespawn[i] != 0 && tick >= g_HuntDeerRespawn[i])
        {
            // nu reaparea daca inca e un jucator langa (ar fugi instant)
            new bool:someoneNear = false;
            for(new p = 0; p < MAX_PLAYERS; p++)
                if(IsPlayerConnected(p) && PlayerData[p][pLogged] && Hunt_PlayerNearSpawn(p, i)) { someoneNear = true; break; }
            if(someoneNear)
                g_HuntDeerRespawn[i] = tick + 3000; // reincearca mai tarziu
            else
                Hunt_CreateDeer(i);
        }
    }
    return 1;
}

// Distanta de la un punct la segmentul AB (3D) - pt traiectoria glontului (jucator -> impact)
stock Float:Hunt_DistPointSeg(Float:px, Float:py, Float:pz, Float:ax, Float:ay, Float:az, Float:bx, Float:by, Float:bz)
{
    new Float:abx = bx - ax, Float:aby = by - ay, Float:abz = bz - az;
    new Float:ab2 = abx*abx + aby*aby + abz*abz;
    new Float:t = 0.0;
    if(ab2 > 0.0) t = ((px-ax)*abx + (py-ay)*aby + (pz-az)*abz) / ab2;
    if(t < 0.0) t = 0.0; else if(t > 1.0) t = 1.0;
    return VectorSize(px - (ax + abx*t), py - (ay + aby*t), pz - (az + abz*t));
}

// Caprioara fuge (dispare + programeaza reaparitia)
stock Hunt_Flee(idx)
{
    Hunt_RemoveDeer(idx);
    g_HuntDeerRespawn[idx] = GetTickCount() + HUNT_RESPAWN_MS;
}

public OnPlayerWeaponShot(playerid, weaponid, hittype, hitid, Float:fX, Float:fY, Float:fZ)
{
    if(weaponid == HUNT_SNIPER)
    {
        new Float:px, Float:py, Float:pz;
        GetPlayerPos(playerid, px, py, pz);
        pz += 0.6; // aprox inaltimea tevii

        // gaseste caprioara cea mai apropiata de traiectoria glontului (jucator -> punct de impact)
        new best = -1;
        new Float:bestDist = 999999.0;
        for(new i = 0; i < HUNT_SPAWN_COUNT; i++)
        {
            if(!IsValidDynamicObject(g_HuntDeer[i])) continue;
            new Float:d = Hunt_DistPointSeg(
                g_HuntSpawn[i][0], g_HuntSpawn[i][1], g_HuntSpawn[i][2] + 0.8,
                px, py, pz, fX, fY, fZ);
            if(d < bestDist) { bestDist = d; best = i; }
        }

        if(best != -1)
        {
            if(bestDist <= HUNT_HIT_RADIUS)
            {
                // lovitura curata -> doborata
                Hunt_Flee(best);
                if(g_HuntMeat[playerid] >= HUNT_MAX_MEAT)
                    SendClientMessage(playerid, COLOR_ERROR, C_ERROR"[Hunt] "C_WHITE"You hit a deer but you're at the max ("C_INFO#HUNT_MAX_MEAT C_WHITE"). Sell some first ("C_INFO"/sellmeat"C_WHITE").");
                else
                {
                    g_HuntMeat[playerid]++;
                    new hm[144];
                    format(hm, sizeof(hm), C_SUCCESS"[Hunt] "C_WHITE"Clean shot! You bagged a deer. Carrying "C_INFO"%d/%d"C_WHITE". Sell at any shop ("C_INFO"/sellmeat"C_WHITE").",
                        g_HuntMeat[playerid], HUNT_MAX_MEAT);
                    SendClientMessage(playerid, COLOR_SUCCESS, hm);
                }
            }
            else if(bestDist <= HUNT_NEARMISS_RADIUS)
            {
                // ratare aproape -> caprioara se sperie si fuge
                Hunt_Flee(best);
                SendClientMessage(playerid, COLOR_ERROR, C_ERROR"[Hunt] "C_WHITE"You missed - the deer bolted! Steady your aim next time.");
            }
            // ratare departe -> nimic (caprioara nu observa)
        }
    }
    return 1;
}

// ============================================================
//  FARMING (Agricultura) - terenuri, /farm
// ============================================================
#define MAX_FARMS            20
#define FARM_STEPS           5
#define FARM_TRACTOR         531
#define FARM_COMBINE         532
#define FARM_DOZER           486
#define FARM_TRUCK           403     // camion (pt livrarea recoltei)
#define FARM_TRAILER         450     // remorca
#define FARM_TRUCK_PRICE     12500
#define FARM_TRAILER_PRICE   10000

new const g_FarmStepName[FARM_STEPS][12]    = { "Plow", "Level", "Seed", "Fertilize", "Harvest" };
new const g_FarmStepAction[FARM_STEPS][12]  = { "plow", "level", "seed", "fertilize", "harvest" };
new const g_FarmStepVeh[FARM_STEPS]         = { FARM_TRACTOR, FARM_DOZER, FARM_TRACTOR, FARM_TRACTOR, FARM_COMBINE };
new const g_FarmStepVehName[FARM_STEPS][12] = { "Tractor", "Dozer", "Tractor", "Tractor", "Combine" };
new const g_FarmStepMin[FARM_STEPS]         = { 1, 2, 3, 1, 4 };

enum E_FARM_DATA
{
    fmID,
    Float:fmX, Float:fmY, Float:fmZ, Float:fmRange,
    fmTractors, fmCombines, fmDozers, fmTrucks, fmTrailers,
    fmNextStep,   // index 0-4
    fmLastWork,   // unix (aliniat la zi) sau 0 = niciodata
    fmPlowed, fmLeveled, fmSeeded, fmFertilized, fmReady,
    fmOwner[24], fmOwned, fmPrice,
    fmBank, fmRecolta
}
new FarmData[MAX_FARMS][E_FARM_DATA];
new g_FarmCount = 0;

// stare de lucru per player
new g_FarmWorking[MAX_PLAYERS];   // farm index+1 (0 = nu lucreaza)
new g_FarmWorkStep[MAX_PLAYERS];  // pasul lucrat
new g_FarmWorkVeh[MAX_PLAYERS];   // vehiculul folosit (0 = niciunul)
new g_FarmWorkTimer[MAX_PLAYERS]; // timer id (-1 = niciunul)

// Preturi utilaje (suprascrise din payday_setup)
new g_FarmTractorPrice = 10000, g_FarmDozerPrice = 15000, g_FarmCombinePrice = 20000;

new g_FarmPickup[MAX_FARMS];           // pickup-ul terenului (-1 = niciunul)
new Text3D:g_FarmLabel[MAX_FARMS];     // eticheta 3D a terenului

new bool:g_FarmWorkSpawned[MAX_PLAYERS]; // true daca utilajul de lucru a fost spawnat de work (temp -> se distruge)
new g_FarmRentVeh[MAX_PLAYERS];        // utilaj inchiriat (0 = niciunul)
new g_FarmDelivTruck[MAX_PLAYERS];     // camionul de livrare (0 = nu livreaza)
new g_FarmDelivTrailer[MAX_PLAYERS];   // remorca de livrare
new g_FarmDelivFarm[MAX_PLAYERS];      // ferma pt care se livreaza (index)

stock Farm_StepIndex(const name[])
{
    for(new i = 0; i < FARM_STEPS; i++)
        if(strcmp(name, g_FarmStepName[i], true) == 0) return i;
    return 0;
}
stock Farm_ActionIndex(const action[])
{
    for(new i = 0; i < FARM_STEPS; i++)
        if(strcmp(action, g_FarmStepAction[i], true) == 0) return i;
    return -1;
}
stock Farm_PlayerIn(playerid)
{
    for(new i = 0; i < g_FarmCount; i++)
        if(FarmData[i][fmRange] > 0.0 &&
           IsPlayerInRangeOfPoint(playerid, FarmData[i][fmRange], FarmData[i][fmX], FarmData[i][fmY], FarmData[i][fmZ]))
            return i;
    return -1;
}
// Numarul de utilaje de un model detinute de ferma (din coloanele farms)
stock Farm_OwnedCount(fidx, model)
{
    if(model == FARM_TRACTOR) return FarmData[fidx][fmTractors];
    if(model == FARM_COMBINE) return FarmData[fidx][fmCombines];
    if(model == FARM_DOZER)   return FarmData[fidx][fmDozers];
    if(model == FARM_TRUCK)   return FarmData[fidx][fmTrucks];
    if(model == FARM_TRAILER) return FarmData[fidx][fmTrailers];
    return 0;
}
stock Farm_OwnedAdd(fidx, model, delta)
{
    if(model == FARM_TRACTOR)      { FarmData[fidx][fmTractors] += delta; if(FarmData[fidx][fmTractors] < 0) FarmData[fidx][fmTractors] = 0; }
    else if(model == FARM_COMBINE) { FarmData[fidx][fmCombines] += delta; if(FarmData[fidx][fmCombines] < 0) FarmData[fidx][fmCombines] = 0; }
    else if(model == FARM_DOZER)   { FarmData[fidx][fmDozers]   += delta; if(FarmData[fidx][fmDozers]   < 0) FarmData[fidx][fmDozers]   = 0; }
    else if(model == FARM_TRUCK)   { FarmData[fidx][fmTrucks]   += delta; if(FarmData[fidx][fmTrucks]   < 0) FarmData[fidx][fmTrucks]   = 0; }
    else if(model == FARM_TRAILER) { FarmData[fidx][fmTrailers] += delta; if(FarmData[fidx][fmTrailers] < 0) FarmData[fidx][fmTrailers] = 0; }
}
stock Farm_Save(fidx)
{
    new dstr[11];
    UnixToDateStr(FarmData[fidx][fmLastWork], dstr, sizeof(dstr));
    new q[400];
    mysql_format(g_SQL, q, sizeof(q),
        "UPDATE `farms` SET `nextStep`='%e', `lastWorkingDate`='%s', `isPlowed`=%d, `isLeveled`=%d, `isSeeded`=%d, `isFertilized`=%d, `isReadyToHarvest`=%d, `tractors`=%d, `combines`=%d, `dozers`=%d, `trucks`=%d, `trailers`=%d, `farmBank`=%d, `farmRecolta`=%d WHERE `id`=%d",
        g_FarmStepName[FarmData[fidx][fmNextStep]], dstr,
        FarmData[fidx][fmPlowed], FarmData[fidx][fmLeveled], FarmData[fidx][fmSeeded], FarmData[fidx][fmFertilized], FarmData[fidx][fmReady],
        FarmData[fidx][fmTractors], FarmData[fidx][fmCombines], FarmData[fidx][fmDozers], FarmData[fidx][fmTrucks], FarmData[fidx][fmTrailers],
        FarmData[fidx][fmBank], FarmData[fidx][fmRecolta],
        FarmData[fidx][fmID]);
    mysql_tquery(g_SQL, q, "", "", 0);
}
stock Farm_Cancel(playerid, bool:notify)
{
    if(g_FarmWorking[playerid] == 0) return;
    if(g_FarmWorkTimer[playerid] != -1) { KillTimer(g_FarmWorkTimer[playerid]); g_FarmWorkTimer[playerid] = -1; }
    new wv = g_FarmWorkVeh[playerid];
    new bool:wspawn = g_FarmWorkSpawned[playerid];
    g_FarmWorkVeh[playerid] = 0;
    g_FarmWorking[playerid] = 0;
    g_FarmWorkSpawned[playerid] = false;
    if(wv != 0 && wspawn)
        DestroyVehicle(wv); // utilaj temporar spawnat de work -> distrus (rentalul se ocupa singur la coborare)
    if(notify && IsPlayerConnected(playerid))
        SendClientMessage(playerid, COLOR_ERROR, C_ERROR"[Farm] "C_WHITE"Work cancelled - you lost today's progress on this field.");
}

stock Farm_RecreatePickup(fidx)
{
    if(g_FarmPickup[fidx] != -1) { DestroyPickup(g_FarmPickup[fidx]); g_FarmPickup[fidx] = -1; }
    if(g_FarmLabel[fidx] != Text3D:INVALID_3DTEXT_ID) { Delete3DTextLabel(g_FarmLabel[fidx]); g_FarmLabel[fidx] = Text3D:INVALID_3DTEXT_ID; }

    if(FarmData[fidx][fmX] == 0.0 && FarmData[fidx][fmY] == 0.0) return; // teren neconfigurat

    g_FarmPickup[fidx] = CreatePickup(19602, 1, FarmData[fidx][fmX], FarmData[fidx][fmY], FarmData[fidx][fmZ], -1);

    new ownerTxt[24];
    if(FarmData[fidx][fmOwned]) format(ownerTxt, sizeof(ownerTxt), "%s", FarmData[fidx][fmOwner]);
    else                        format(ownerTxt, sizeof(ownerTxt), "ForSale");

    new label[144];
    format(label, sizeof(label), "[ Farm #%d ]\n[ Owner: %s ]\n[ Price: %s$ ]\n[ /buyfarm ]",
        FarmData[fidx][fmID], ownerTxt, MoneyStr(FarmData[fidx][fmPrice]));
    g_FarmLabel[fidx] = Create3DTextLabel(label, COLOR_WHITE,
        FarmData[fidx][fmX], FarmData[fidx][fmY], FarmData[fidx][fmZ] + 0.5, 30.0, 0, 0);
}

stock Farms_Load()
{
    mysql_tquery(g_SQL, "SELECT * FROM `farms` ORDER BY `id` ASC", "OnFarmsLoaded");
}
forward OnFarmsLoaded();
public OnFarmsLoaded()
{
    new rows = cache_num_rows();
    g_FarmCount = 0;
    for(new i = 0; i < rows && g_FarmCount < MAX_FARMS; i++)
    {
        new idx = g_FarmCount;
        cache_get_value_name_int  (i, "id", FarmData[idx][fmID]);
        cache_get_value_name_float(i, "x",     FarmData[idx][fmX]);
        cache_get_value_name_float(i, "y",     FarmData[idx][fmY]);
        cache_get_value_name_float(i, "z",     FarmData[idx][fmZ]);
        cache_get_value_name_float(i, "range", FarmData[idx][fmRange]);
        new stepName[16];
        cache_get_value_name(i, "nextStep", stepName, sizeof(stepName));
        FarmData[idx][fmNextStep] = Farm_StepIndex(stepName);
        new dbuf[11];
        cache_get_value_name(i, "lastWorkingDate", dbuf, sizeof(dbuf));
        FarmData[idx][fmLastWork] = DateStrToUnix(dbuf);
        cache_get_value_name_int(i, "isPlowed",         FarmData[idx][fmPlowed]);
        cache_get_value_name_int(i, "isLeveled",        FarmData[idx][fmLeveled]);
        cache_get_value_name_int(i, "isSeeded",         FarmData[idx][fmSeeded]);
        cache_get_value_name_int(i, "isFertilized",     FarmData[idx][fmFertilized]);
        cache_get_value_name_int(i, "isReadyToHarvest", FarmData[idx][fmReady]);
        cache_get_value_name    (i, "owner", FarmData[idx][fmOwner], 24);
        cache_get_value_name_int(i, "isOwned", FarmData[idx][fmOwned]);
        cache_get_value_name_int(i, "price",   FarmData[idx][fmPrice]);
        cache_get_value_name_int(i, "farmBank",    FarmData[idx][fmBank]);
        cache_get_value_name_int(i, "farmRecolta", FarmData[idx][fmRecolta]);
        cache_get_value_name_int(i, "tractors", FarmData[idx][fmTractors]);
        cache_get_value_name_int(i, "combines", FarmData[idx][fmCombines]);
        cache_get_value_name_int(i, "dozers",   FarmData[idx][fmDozers]);
        cache_get_value_name_int(i, "trucks",   FarmData[idx][fmTrucks]);
        cache_get_value_name_int(i, "trailers", FarmData[idx][fmTrailers]);
        g_FarmPickup[idx] = -1;
        g_FarmLabel[idx]  = Text3D:INVALID_3DTEXT_ID;
        Farm_RecreatePickup(idx);
        g_FarmCount++;
    }
    printf("[Farms] %d fields loaded.", g_FarmCount);
    return 1;
}

forward Farm_Complete(playerid);
public Farm_Complete(playerid)
{
    if(g_FarmWorking[playerid] == 0) return 1;
    g_FarmWorkTimer[playerid] = -1;
    new fidx = g_FarmWorking[playerid] - 1;
    new step = g_FarmWorkStep[playerid];

    // trebuie sa fie inca la volanul vehiculului de lucru
    if(GetPlayerState(playerid) != PLAYER_STATE_DRIVER || GetPlayerVehicleID(playerid) != g_FarmWorkVeh[playerid])
    {
        Farm_Cancel(playerid, true);
        return 1;
    }

    switch(step)
    {
        case 0: FarmData[fidx][fmPlowed] = 1;
        case 1: FarmData[fidx][fmLeveled] = 1;
        case 2: FarmData[fidx][fmSeeded] = 1;
        case 3: FarmData[fidx][fmFertilized] = 1;
        case 4: FarmData[fidx][fmReady] = 1;
    }

    new msg[160];
    if(step == 4)
    {
        // recolta -> aduna in stocul fermei (se vinde cu /farm deliver)
        new gain = 10000 + random(2500);
        FarmData[fidx][fmRecolta] += gain;
        FarmData[fidx][fmPlowed] = 0; FarmData[fidx][fmLeveled] = 0; FarmData[fidx][fmSeeded] = 0;
        FarmData[fidx][fmFertilized] = 0; FarmData[fidx][fmReady] = 0;
        FarmData[fidx][fmNextStep] = 0;
        format(msg, sizeof(msg), C_SUCCESS"[Farm] "C_WHITE"Cycle complete! Harvest "C_SUCCESS"+$%s"C_WHITE" (stock $%s). Sell it with "C_INFO"/farm deliver"C_WHITE".",
            MoneyStr(gain), MoneyStr(FarmData[fidx][fmRecolta]));
    }
    else
    {
        FarmData[fidx][fmNextStep] = step + 1;
        format(msg, sizeof(msg), C_SUCCESS"[Farm] "C_WHITE"'%s' done! Next step: "C_INFO"%s"C_WHITE" (come back tomorrow).", g_FarmStepName[step], g_FarmStepName[step + 1]);
    }
    Farm_Save(fidx);
    SendClientMessage(playerid, COLOR_SUCCESS, msg);

    // curata utilajul (clear g_FarmWorking inainte de eject, ca sa nu se declanseze cancel)
    new wv = g_FarmWorkVeh[playerid];
    new bool:wspawn = g_FarmWorkSpawned[playerid];
    g_FarmWorking[playerid] = 0;
    g_FarmWorkVeh[playerid] = 0;
    g_FarmWorkSpawned[playerid] = false;
    if(wv != 0)
    {
        RemovePlayerFromVehicle(playerid);
        if(wspawn) DestroyVehicle(wv); // utilaj temporar spawnat de work -> distrus (rentalul se ocupa singur la coborare)
    }
    return 1;
}

stock Farm_IndexByID(id)
{
    for(new i = 0; i < g_FarmCount; i++)
        if(FarmData[i][fmID] == id) return i;
    return -1;
}
stock Farm_VehPrice(model)
{
    if(model == FARM_TRACTOR) return g_FarmTractorPrice;
    if(model == FARM_DOZER)   return g_FarmDozerPrice;
    if(model == FARM_COMBINE) return g_FarmCombinePrice;
    if(model == FARM_TRUCK)   return FARM_TRUCK_PRICE;
    if(model == FARM_TRAILER) return FARM_TRAILER_PRICE;
    return 0;
}
stock Farm_ModelFromType(const type[])
{
    if(!strlen(type)) return -1; // fara argument -> invalid (strcmp cu string gol da match)
    if(strcmp(type, "tractor", true) == 0) return FARM_TRACTOR;
    if(strcmp(type, "dozer", true) == 0)   return FARM_DOZER;
    if(strcmp(type, "combina", true) == 0 || strcmp(type, "combine", true) == 0) return FARM_COMBINE;
    if(strcmp(type, "truck", true) == 0)   return FARM_TRUCK;
    if(strcmp(type, "trailer", true) == 0) return FARM_TRAILER;
    return -1;
}
stock Farm_VehTypeName(model, dest[], size = sizeof(dest))
{
    if(model == FARM_TRACTOR)      format(dest, size, "Tractor");
    else if(model == FARM_DOZER)   format(dest, size, "Dozer");
    else if(model == FARM_COMBINE) format(dest, size, "Combine");
    else if(model == FARM_TRUCK)   format(dest, size, "Truck");
    else if(model == FARM_TRAILER) format(dest, size, "Trailer");
    else                           format(dest, size, "Vehicle");
}
stock bool:Farm_IsOwner(playerid, fidx)
{
    return (FarmData[fidx][fmOwned] != 0 && strcmp(FarmData[fidx][fmOwner], PlayerData[playerid][pName], true) == 0);
}
// Seteaza pFarmKey al playerului dupa terenul al carui owner e numele lui (0 = niciunul)
stock Farm_SyncPlayerKey(playerid)
{
    PlayerData[playerid][pFarmKey] = 0;
    for(new i = 0; i < g_FarmCount; i++)
        if(FarmData[i][fmOwned] != 0 && strlen(FarmData[i][fmOwner]) &&
           strcmp(FarmData[i][fmOwner], PlayerData[playerid][pName], true) == 0)
        {
            PlayerData[playerid][pFarmKey] = FarmData[i][fmID];
            break;
        }
}
// La 1 secunda dupa spawn: ataseaza remorca la camion
forward Farm_DeliverAttach(playerid);
public Farm_DeliverAttach(playerid)
{
    if(g_FarmDelivTruck[playerid] != 0 && g_FarmDelivTrailer[playerid] != 0 &&
       GetPlayerVehicleID(playerid) == g_FarmDelivTruck[playerid])
        AttachTrailerToVehicle(g_FarmDelivTrailer[playerid], g_FarmDelivTruck[playerid]);
    return 1;
}
// Curata livrarea (camion + remorca + checkpoint)
stock Farm_DeliverCleanup(playerid)
{
    if(g_FarmDelivTruck[playerid] != 0)   { DestroyVehicle(g_FarmDelivTruck[playerid]);   g_FarmDelivTruck[playerid] = 0; }
    if(g_FarmDelivTrailer[playerid] != 0) { DestroyVehicle(g_FarmDelivTrailer[playerid]); g_FarmDelivTrailer[playerid] = 0; }
    g_FarmDelivFarm[playerid] = 0;
    DisablePlayerCheckpoint(playerid);
}
// Curata utilajul inchiriat
stock Farm_RentCleanup(playerid)
{
    if(g_FarmRentVeh[playerid] != 0) { DestroyVehicle(g_FarmRentVeh[playerid]); g_FarmRentVeh[playerid] = 0; }
}

// Transfer intre cash-ul playerului si un cont de proprietate (referinta). Returneaza true daca a reusit.
stock bool:Prop_BankTransfer(playerid, &balance, bool:deposit, amount)
{
    if(deposit)
    {
        if(PlayerData[playerid][pMoney] < amount)
        {
            SendClientMessage(playerid, COLOR_ERROR, C_ERROR"[Bank] "C_WHITE"You don't have that much cash.");
            return false;
        }
        PlayerData[playerid][pMoney] -= amount;
        GivePlayerMoney(playerid, -amount);
        balance += amount;
    }
    else
    {
        if(balance < amount)
        {
            SendClientMessage(playerid, COLOR_ERROR, C_ERROR"[Bank] "C_WHITE"That account doesn't have that much.");
            return false;
        }
        balance -= amount;
        PlayerData[playerid][pMoney] += amount;
        GivePlayerMoney(playerid, amount);
    }
    UpdatePlayer(playerid, pMoney);
    return true;
}

// Puncte de incarcare pentru Car Transportator (sursa)
new const Float:g_TransportLoad[3][3] = {
    {2186.0884, -2315.1008, 14.1808},
    {2215.6162, -2214.7976, 14.1800},
    {2199.8181, -2228.4229, 14.1791}
};
// Business-urile la care se descarca (destinatie)
new const g_TransportUnloadBiz[4] = { 3, 8, 17, 18 };

// Puncte de incarcare ciment (sursa)
new const Float:g_CementLoad[3][3] = {
    {541.3927, 843.8402, -40.7562},
    {584.7085, 914.6931, -42.2006},
    {543.2087, 906.5889, -42.0325}
};
// Puncte de descarcare ciment (santiere - destinatie)
new const Float:g_CementUnload[8][3] = {
    {603.7239, 1244.5341, 11.4458},
    {106.7742, 2587.2163, 16.3024},
    {126.0796, 2414.8916, 16.2104},
    {-317.1321, 1747.8442, 42.5297},
    {1347.3595, 645.5427, 10.5258},
    {2622.3687, 825.5492, 5.0429},
    {1763.7852, 640.8087, 19.3381},
    {431.1435, 611.6857, 19.0608}
};
// Puncte de incarcare provizii (sursa) pentru Emergency Logistics Driver.
// Descarcarea se face la shop-urile [ Shop ] (ShopData, din tabela `shops`).
new const Float:g_EmergencyLoad[MAX_EMERGENCY_LOADPOINTS][3] = {
    {1142.3639, -1328.0309, 13.7563},
    {1746.1986, -1456.8336, 13.6527},
    {2001.8474, -1404.6630, 17.5796},
    {2042.2239, -1447.1166, 17.8504}
};
new bool:g_IsWorking[MAX_PLAYERS];
new g_JobStage[MAX_PLAYERS];
new g_JobUnloadsDone[MAX_PLAYERS]; // cate descarcari s-au facut de la ultima incarcare
new Float:g_JobPickupX[MAX_PLAYERS], Float:g_JobPickupY[MAX_PLAYERS];
new g_JobPay[MAX_PLAYERS];          // plata calculata pentru livrarea curenta
new g_JobVehicle[MAX_PLAYERS];      // vehiculul cu care a inceput munca
new g_JobReturnTimer[MAX_PLAYERS];  // timer grace 30s (-1 = inactiv)

// Job 5 - Uber (serviciu de transport intre playeri)
#define JOB_UBER             5
#define UBER_CHARGE_INTERVAL 20   // secunde intre taxari
#define UBER_CP_SIZE         3.0

new bool:g_UberOnDuty[MAX_PLAYERS];     // sofer: e la serviciu ca uber
new g_UberFare[MAX_PLAYERS];            // sofer: pretul cerut per 20s
new g_UberVehicle[MAX_PLAYERS];         // sofer: vehiculul personal cu care e uber
new g_UberPassenger[MAX_PLAYERS];       // sofer: pasagerul curent (INVALID_PLAYER_ID = niciunul)
new bool:g_UberWantsRide[MAX_PLAYERS];  // pasager: a cerut /service uber
new g_UberDriver[MAX_PLAYERS];          // pasager: soferul asignat (INVALID_PLAYER_ID = niciunul)
new bool:g_UberRideActive[MAX_PLAYERS]; // pasager: cursa e in desfasurare (e in masina, se taxeaza)
new g_UberChargeTimer[MAX_PLAYERS];     // pasager: timer-ul de taxare (-1 = inactiv)

// ============================================================
//  DRUGS (mafii) - craft/transport iarba & drugs in seif
// ============================================================
#define SEIF_MAX_HERBS       10000   // capacitate iarba (g)
#define SEIF_MAX_DRUGS       1000    // capacitate drugs (g)
#define DRUG_HUNTLEY_MODEL   579     // Huntley - vehiculul de transport
#define DRUG_TRANSPORT_HOUR_MIN 19   // /drugs transport doar intre 19:00 ...
#define DRUG_TRANSPORT_HOUR_MAX 23   // ... si 23:59
#define DRUG_CP_SIZE         3.0
#define DRUG_LOAD_FREEZE     5        // secunde freeze la incarcare/descarcare
#define DRUG_CRAFT_FREEZE    30       // secunde freeze la craft
#define DRUG_USE_FREEZE      1        // secunde freeze dupa /drugs use
#define DRUG_USE_HEAL        30.0     // hp la /drugs use
#define DRUG_GET_AMOUNT      2        // g de drugs luate din seif la /drugs get (si consumate la /drugs use)
#define DRUG_CRAFT_RANGE     3.0
// Masinaria de craftat si seiful (interior)
#define DRUG_CRAFT_X         2543.0
#define DRUG_CRAFT_Y         -1293.8
#define DRUG_CRAFT_Z         1045.5
#define DRUG_SEIF_X          2532.1270
#define DRUG_SEIF_Y          -1282.2848
#define DRUG_SEIF_Z          1048.2891

// Etape transport: 0=niciuna, 1=spre punctul de preluare, 2=incarcare(freeze), 3=spre HQ, 4=descarcare(freeze)
#define DRUG_STAGE_NONE      0
#define DRUG_STAGE_TOPICKUP  1
#define DRUG_STAGE_LOADING   2
#define DRUG_STAGE_TOHQ      3
#define DRUG_STAGE_UNLOADING 4

new g_PlayerDrugs[MAX_PLAYERS];     // drugs (g) pe care le are playerul la el (se pierd la moarte/deconectare)
new g_DrugStage[MAX_PLAYERS];       // etapa transportului
new g_DrugPartner[MAX_PLAYERS];     // al doilea membru din vehicul (pt mesaj), INVALID_PLAYER_ID daca none

// Marker seif per factiune mafie (pickup + eticheta), in interiorul/vw-ul factiunii
new STREAMER_TAG_PICKUP:g_SeifPickup[MAX_FACTIONS + 1];
new STREAMER_TAG_3D_TEXT_LABEL:g_SeifLabel[MAX_FACTIONS + 1];
new STREAMER_TAG_3D_TEXT_LABEL:g_CraftLabel[MAX_FACTIONS + 1]; // eticheta masinariei de craft

// Punctele de preluare a iarbii, per factiune mafie (4-7).
new const Float:g_DrugPickup[MAX_FACTIONS + 1][3] = {
    {0.0, 0.0, 0.0},                  // 0 - nefolosit
    {0.0, 0.0, 0.0},                  // 1
    {0.0, 0.0, 0.0},                  // 2
    {0.0, 0.0, 0.0},                  // 3
    {-758.0449, -2060.4685, 6.5507},  // 4 - Mafia Europeana
    {-819.8571, -1954.8936, 6.5274},  // 5 - Mafia Americana
    {-810.5676, -1942.0809, 5.8185},  // 6 - Mafia Africana
    {-740.3304, -2062.4729, 6.2076},  // 7 - Mafia Asiatica
    {0.0, 0.0, 0.0}                   // 8 - News Reporters (fara drog)
};

// Catalog joburi pentru /joblist (nume + locatie de teleport admin). Index 0 = job 1.
new const g_JobNames[MAX_JOBS][32] = {
    "Glovo Delivery", "Cement Truck Driver", "Gun Delivery", "Car Transportator", "Uber",
    "Emergency Logistics Driver", "Bus Driver", "Job 8", "Job 9", "Job 10"
};
new const Float:g_JobTeleport[MAX_JOBS][3] = {
    {2390.0, 1667.0, 11.0},            // 1 - Glovo
    {334.6250, 871.5236, 20.4063},     // 2 - Cement Truck Driver
    {2501.6855, -2618.8445, 13.7147},  // 3 - Gun Delivery (depou vehicule)
    {1984.0514, -2065.8538, 14.0127},  // 4 - Car Transportator (depou vehicule)
    {0.0, 0.0, 0.0},        // 5 - Uber (fara locatie fixa)
    {1110.2723, -1225.3549, 15.8070},  // 6 - Emergency Logistics Driver (depou)
    {1411.4031, -2310.6638, 13.6462},  // 7 - Bus Driver (depou)
    {0.0, 0.0, 0.0},        // 8
    {0.0, 0.0, 0.0},        // 9
    {0.0, 0.0, 0.0}         // 10
};

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
#define DIALOG_JOBLIST       9006
#define DIALOG_FARMLIST      9018
#define DIALOG_PHONE_BUY     9007
#define DIALOG_SHOP          9008
#define DIALOG_NEWSPAPER     9009
#define DIALOG_QA_LIST       9010
#define DIALOG_REGISTER      9011
#define DIALOG_LOGIN         9012
#define DIALOG_FASTFOOD_LIST 9013
#define DIALOG_REPORTS_LIST  9014
#define DIALOG_REPORTS_VIEW  9015
#define DIALOG_HOWTO         9016

// ============================================================
//  TELEFONIE
// ============================================================
#define PHONE_MODEL_COUNT          5
#define PHONE_NUMBER_MIN           10000     // 5 cifre (primul numar posibil)
#define PHONE_NUMBER_MAX           99999     // 5 cifre (ultimul numar posibil)
#define PHONE_SHOP_BIZ_ID          21        // business care primeste 5% din vanzarea telefoanelor
#define PHONE_SHOP_BIZ_CUT_PCT     5
#define PHONE_CARRIER_BIZ_ID       22        // business care primeste 50% din SMS-uri, apeluri si SIM-uri
#define PHONE_CARRIER_CUT_PCT      50
#define PHONE_SIM_PRICE            250       // $ per SIM (50% -> PHONE_CARRIER_BIZ_ID)
#define PHONE_SMS_PRICE            5         // $ per SMS
#define PHONE_CALL_PRICE           3         // $ per interval de taxare
#define PHONE_CALL_CHARGE_INTERVAL 10        // secunde intre taxari pe durata apelului
#define PHONE_CALL_RING_TIMEOUT    30        // secunde pana cand un apel neraspuns se incheie automat

new const g_PhoneModels[PHONE_MODEL_COUNT][24] = {
    "Samsung A70", "Samsung S27", "iPhone 16", "iPhone 17", "Motorola 67"
};
new const g_PhonePrices[PHONE_MODEL_COUNT] = {
    1000, 2000, 1600, 2200, 500
};

// Stare apel (doar in memorie). Un apel are un initiator (caller) si un destinatar (callee).
new g_PhoneCallPartner[MAX_PLAYERS];      // celalalt participant; INVALID_PLAYER_ID = niciun apel
new bool:g_PhoneCallActive[MAX_PLAYERS];  // true = apel conectat (s-a dat /pickup); false = doar suna
new bool:g_PhoneCallCaller[MAX_PLAYERS];  // true = el a initiat apelul (deci el plateste taxarea)
new g_PhoneRingTimer[MAX_PLAYERS];        // timer de timeout pentru ring (setat pe initiator)
new g_PhoneCallTimer[MAX_PLAYERS];        // timer de taxare (setat pe initiator)
// SIM-ul aleatoriu in curs de verificare a unicitatii (intre /buysim si callback)
new g_PhonePendingSim[MAX_PLAYERS];

new g_GPSDialogCategory[MAX_PLAYERS];       // 0=Factions,1=Businesses,2=Banks&ATMs,3=Shops,4=FastFoods,5=dinamica (locations_admin)
new g_GPSDynCat[MAX_PLAYERS][32];           // pentru categoriile dinamice: numele locCategory selectat
#define GPS_MAX_DYNCATS 16

// Lista GPS construita per-player la deschiderea unei categorii, sortata crescator dupa distanta.
// Stocam doar (tip, index) ca referinta in sursa, ca sa nu copiem nume/coordonate.
#define MAX_GPS_LISTITEMS 200
#define GPSITEM_GPS      0
#define GPSITEM_FACTION  1
#define GPSITEM_BIZ      2
#define GPSITEM_ATM      3
#define GPSITEM_JOB      4
#define GPSITEM_SHOP     5
#define GPSITEM_FASTFOOD 6
#define GPSITEM_LOC      7
new g_GPSItemType[MAX_PLAYERS][MAX_GPS_LISTITEMS];
new g_GPSItemRef[MAX_PLAYERS][MAX_GPS_LISTITEMS];
new Float:g_GPSItemDist[MAX_PLAYERS][MAX_GPS_LISTITEMS];
new g_GPSListCount[MAX_PLAYERS];

// ============================================================
//  EXAMENE DE ZBOR (P = avion -> Airplane A; H = elicopter -> Airplane H)
// ============================================================
#define FLIGHT_EXAM_BIZ_ID     6
#define FLIGHT_EXAM_BIZ_CUT    30      // % din pret catre business
#define FLIGHT_PASS_DURATION_P 1296000 // 15 zile (avion), in secunde
#define FLIGHT_PASS_DURATION_H 1382400 // 16 zile (elicopter), in secunde
#define FLIGHT_FAIL_DURATION   172800  // 2 zile, in secunde (permis scurt daca aeronava e avariata)
#define FLIGHT_PASS_HEALTH     800.0
#define FLIGHT_CP_SIZE         8.0
#define FLIGHT_STEP_TIME       60000   // 60 secunde per checkpoint

#define FLIGHT_STATE_NONE      0
#define FLIGHT_STATE_WAITING   1
#define FLIGHT_STATE_FLYING    2
#define FLIGHT_CAT_P           0       // avion  -> pAirLicA_exp
#define FLIGHT_CAT_H           1       // elicopter -> pAirLicH_exp

// examP (avion) - vehicul + checkpoint-uri se completeaza mai tarziu (momentan 0.0)
#define EXAMP_RANGE            5.0
new Float:EXAMP_LOC_X = 0.0;   // suprascris din locations_admin (id 5, "examP")
new Float:EXAMP_LOC_Y = 0.0;
new Float:EXAMP_LOC_Z = 0.0;
#define MAX_EXAMP_CARS         1
#define MAX_EXAMP_CHECKPOINTS  8
new g_ExamPCar[MAX_EXAMP_CARS] = {-1};
new Float:ExamPCheckpoints[MAX_EXAMP_CHECKPOINTS][3] = {
    {1444.3706, -2494.1445, 14.2678}, // cp1
    {1741.9435, -2496.1680, 32.6662}, // cp2
    {2003.4653, -2494.2500, 14.2505}, // cp3
    {2109.0967, -2543.3591, 14.2476}, // cp4
    {2050.7490, -2593.1965, 14.2580}, // cp5
    {1853.6288, -2590.7241, 30.0579}, // cp6
    {1486.2864, -2593.2788, 14.2542}, // cp7
    {1496.8160, -2412.1025, 14.2594}  // cp8 (aterizare, langa vehicul)
};

// examH (elicopter)
#define EXAMH_RANGE            5.0
new Float:EXAMH_LOC_X = 0.0;   // suprascris din locations_admin (id 6, "examH")
new Float:EXAMH_LOC_Y = 0.0;
new Float:EXAMH_LOC_Z = 0.0;
#define MAX_EXAMH_CARS         1
#define MAX_EXAMH_CHECKPOINTS  4
new g_ExamHCar[MAX_EXAMH_CARS] = {-1};
new Float:ExamHCheckpoints[MAX_EXAMH_CHECKPOINTS][3] = {
    {1606.0615, -2411.1555, 24.7277},
    {1769.8705, -2413.2139, 24.7256},
    {1766.5414, -2378.8860, 22.7122},
    {1635.0007, -2417.2942, 13.5662}
};

// Stare per-player (un singur examen de zbor odata)
new g_FlightState[MAX_PLAYERS];
new g_FlightCat[MAX_PLAYERS];
new g_FlightCheckpoint[MAX_PLAYERS];
new g_FlightVehicle[MAX_PLAYERS];
new g_FlightTimer[MAX_PLAYERS] = {-1, ...};

forward FlightExam_Timeout(playerid);

stock bool:IsExamPCarVehicle(vehid)
{
    for(new i = 0; i < MAX_EXAMP_CARS; i++)
        if(g_ExamPCar[i] == vehid) return true;
    return false;
}
stock bool:IsExamHCarVehicle(vehid)
{
    for(new i = 0; i < MAX_EXAMH_CARS; i++)
        if(g_ExamHCar[i] == vehid) return true;
    return false;
}

stock FlightExam_CPCount(playerid)
    return (g_FlightCat[playerid] == FLIGHT_CAT_H) ? MAX_EXAMH_CHECKPOINTS : MAX_EXAMP_CHECKPOINTS;

stock FlightExam_GetCarUser(vehid)
{
    for(new i = 0; i < MAX_PLAYERS; i++)
        if(g_FlightState[i] == FLIGHT_STATE_FLYING && g_FlightVehicle[i] == vehid) return i;
    return -1;
}

stock FlightExam_KillTimer(playerid)
{
    if(g_FlightTimer[playerid] != -1)
    {
        KillTimer(g_FlightTimer[playerid]);
        g_FlightTimer[playerid] = -1;
    }
}

stock FlightExam_GotoCheckpoint(playerid, cpIdx)
{
    new Float:cx, Float:cy, Float:cz;
    if(g_FlightCat[playerid] == FLIGHT_CAT_H) { cx = ExamHCheckpoints[cpIdx][0]; cy = ExamHCheckpoints[cpIdx][1]; cz = ExamHCheckpoints[cpIdx][2]; }
    else                                      { cx = ExamPCheckpoints[cpIdx][0]; cy = ExamPCheckpoints[cpIdx][1]; cz = ExamPCheckpoints[cpIdx][2]; }
    SetPlayerCheckpoint(playerid, cx, cy, cz, FLIGHT_CP_SIZE);
    FlightExam_KillTimer(playerid);
    g_FlightTimer[playerid] = SetTimerEx("FlightExam_Timeout", FLIGHT_STEP_TIME, false, "i", playerid);
}

stock FlightExam_Fail(playerid, const reason[])
{
    new vehid = g_FlightVehicle[playerid];
    new bool:isH = (g_FlightCat[playerid] == FLIGHT_CAT_H);

    g_FlightState[playerid]      = FLIGHT_STATE_NONE;
    g_FlightVehicle[playerid]    = -1;
    g_FlightCheckpoint[playerid] = 0;
    DisablePlayerCheckpoint(playerid);
    FlightExam_KillTimer(playerid);

    if(vehid != -1) { Vehicle_SetLocked(vehid, false); SetVehicleToRespawn(vehid); }

    new msg[160];
    format(msg, sizeof(msg), C_ERROR"Error: "C_WHITE"You failed the Airplane %s exam. %s Try again.", isH ? ("H") : ("A"), reason);
    SendClientMessage(playerid, COLOR_ERROR, msg);
}

stock FlightExam_Finish(playerid)
{
    new vehid = g_FlightVehicle[playerid];
    new bool:isH = (g_FlightCat[playerid] == FLIGHT_CAT_H);

    DisablePlayerCheckpoint(playerid);
    FlightExam_KillTimer(playerid);
    g_FlightState[playerid]      = FLIGHT_STATE_NONE;
    g_FlightVehicle[playerid]    = -1;
    g_FlightCheckpoint[playerid] = 0;

    new Float:health = 0.0;
    if(vehid != -1) GetVehicleHealth(vehid, health);
    new bool:fullPass = (health >= FLIGHT_PASS_HEALTH);
    new passDur = isH ? FLIGHT_PASS_DURATION_H : FLIGHT_PASS_DURATION_P;
    new expTs = gettime() + (fullPass ? passDur : FLIGHT_FAIL_DURATION);

    new dateStr[11];
    UnixToDateStr(expTs, dateStr, sizeof(dateStr));
    if(isH) { format(PlayerData[playerid][pAirLicH_exp], 11, "%s", dateStr); UpdatePlayer(playerid, pAirLicH_exp); }
    else    { format(PlayerData[playerid][pAirLicA_exp], 11, "%s", dateStr); UpdatePlayer(playerid, pAirLicA_exp); }

    if(vehid != -1) { Vehicle_SetLocked(vehid, false); SetVehicleToRespawn(vehid); }

    new msg[176];
    format(msg, sizeof(msg),
        C_SUCCESS"Congratulations, "C_WHITE"your Airplane %s license is valid until "C_INFO"%s"C_WHITE" (Aircraft HP: "C_INFO"%d"C_WHITE").",
        isH ? ("H") : ("A"), dateStr, floatround(health));
    SendClientMessage(playerid, COLOR_SUCCESS, msg);
}

public FlightExam_Timeout(playerid)
{
    if(!IsPlayerConnected(playerid)) return 0;
    if(g_FlightState[playerid] == FLIGHT_STATE_NONE) return 0;
    g_FlightTimer[playerid] = -1;
    FlightExam_Fail(playerid, "Time's up.");
    return 1;
}

public OnPlayerEnterRaceCheckpoint(playerid)
{
    // Race event: a atins un race checkpoint de cursa
    if(g_RaceState == RACE_STATE_RUNNING && g_RaceIn[playerid] && !g_RaceDone[playerid])
    {
        new lap     = g_RaceLap;
        new count   = g_RaceCPCount[lap];
        new reached = g_RaceCP[playerid]; // indexul CP-ului tocmai atins

        if(reached < count - 1)
        {
            // mai sunt checkpoint-uri -> arata urmatorul (cu sageata)
            g_RaceCP[playerid] = reached + 1;
            Race_SetCP(playerid, lap, reached + 1);
            return 1;
        }

        // ---- FINISH ----
        g_RaceDone[playerid] = true;
        DisablePlayerRaceCheckpoint(playerid);

        new Float:secs = float(GetTickCount() - g_RaceStartTick[playerid]) / 1000.0;
        if(secs < 0.0) secs = 0.0;

        g_RaceFinishOrder++;
        new pos = g_RaceFinishOrder;
        new totalSec = floatround(secs);
        new mm = totalSec / 60, ss = totalSec % 60;

        // Anunt global pentru primele 3 locuri
        if(pos <= 3)
        {
            new bm[144];
            format(bm, sizeof(bm), C_INFO"[Race Event] "C_WHITE"%s finished the race in position "C_SUCCESS"%d"C_WHITE", time "C_INFO"%d:%02d"C_WHITE".",
                PlayerData[playerid][pName], pos, mm, ss);
            SendClientMessageToAll(COLOR_INFO, bm);
        }

        // Mesaj privat cu locul obtinut
        new pm[128];
        format(pm, sizeof(pm), C_INFO"[Race Event] "C_WHITE"You finished in position "C_SUCCESS"%d/%d"C_WHITE" (time "C_INFO"%d:%02d"C_WHITE").",
            pos, g_RaceTotal, mm, ss);
        SendClientMessage(playerid, COLOR_INFO, pm);

        // Verificare record (dupa lap + modelul folosit efectiv)
        new vi = Race_VehIndex(g_RaceVehUsed[playerid]);
        if(vi != -1 && secs < g_RaceRecordTime[lap][vi])
        {
            new oldHolder[24];
            format(oldHolder, sizeof(oldHolder), "%s", g_RaceRecordHolder[lap][vi]);
            new bool:hadHolder = (strlen(oldHolder) > 0);

            g_RaceRecordTime[lap][vi] = secs;
            format(g_RaceRecordHolder[lap][vi], 24, "%s", PlayerData[playerid][pName]);

            if(g_RaceRecordID[lap][vi] != -1)
            {
                new rq[160];
                mysql_format(g_SQL, rq, sizeof(rq),
                    "UPDATE `races` SET `rTimeRecord`=%.2f, `rPlayerName`='%e' WHERE `rID`=%d",
                    secs, PlayerData[playerid][pName], g_RaceRecordID[lap][vi]);
                mysql_tquery(g_SQL, rq, "", "", 0);
            }

            new rm[160];
            if(hadHolder)
                format(rm, sizeof(rm), C_SUCCESS"[Race Event] "C_WHITE"%s beat %s's record on %s (%s): %.2fs!",
                    PlayerData[playerid][pName], oldHolder, g_RaceLapName[lap], g_RaceVehNames[vi], secs);
            else
                format(rm, sizeof(rm), C_SUCCESS"[Race Event] "C_WHITE"%s set a new record on %s (%s): %.2fs!",
                    PlayerData[playerid][pName], g_RaceLapName[lap], g_RaceVehNames[vi], secs);
            SendClientMessageToAll(COLOR_SUCCESS, rm);
        }

        // Toti participantii au terminat? -> incheie evenimentul
        if(g_RaceFinishOrder >= g_RaceTotal)
            Race_End(false);

        return 1;
    }
    return 1;
}

public OnPlayerEnterCheckpoint(playerid)
{
    if(g_FlightState[playerid] == FLIGHT_STATE_FLYING)
    {
        g_FlightCheckpoint[playerid]++;
        if(g_FlightCheckpoint[playerid] >= FlightExam_CPCount(playerid))
            FlightExam_Finish(playerid);
        else
            FlightExam_GotoCheckpoint(playerid, g_FlightCheckpoint[playerid]);
        return 1;
    }

    // Farm: livrare recolta ajunsa la shop
    if(g_FarmDelivTruck[playerid] != 0 && GetPlayerVehicleID(playerid) == g_FarmDelivTruck[playerid])
    {
        new fdx = g_FarmDelivFarm[playerid];
        new pay = FarmData[fdx][fmRecolta] + 5000 + random(2500);
        FarmData[fdx][fmBank] += pay; // banii merg in contul fermei
        FarmData[fdx][fmRecolta] = 0;
        Farm_Save(fdx);
        Farm_DeliverCleanup(playerid);
        new dm[144];
        format(dm, sizeof(dm), C_SUCCESS"[Farm] "C_WHITE"Harvest delivered! "C_SUCCESS"+$%s"C_WHITE" to the farm bank (now "C_INFO"$%s"C_WHITE").", MoneyStr(pay), MoneyStr(FarmData[fdx][fmBank]));
        SendClientMessage(playerid, COLOR_SUCCESS, dm);
        return 1;
    }

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

    // Transport drugs (mafii): atingerea checkpoint-ului de preluare / HQ
    if(g_DrugStage[playerid] == DRUG_STAGE_TOPICKUP)
    {
        DisablePlayerCheckpoint(playerid);
        g_DrugStage[playerid] = DRUG_STAGE_LOADING;
        TogglePlayerControllable(playerid, 0);
        GameTextForPlayer(playerid, "~w~Loading weed...", DRUG_LOAD_FREEZE * 1000, 3);
        SetTimerEx("DrugTransport_Loaded", DRUG_LOAD_FREEZE * 1000, false, "i", playerid);
        return 1;
    }
    if(g_DrugStage[playerid] == DRUG_STAGE_TOHQ)
    {
        DisablePlayerCheckpoint(playerid);
        g_DrugStage[playerid] = DRUG_STAGE_UNLOADING;
        TogglePlayerControllable(playerid, 0);
        GameTextForPlayer(playerid, "~w~Unloading weed...", DRUG_LOAD_FREEZE * 1000, 3);
        SetTimerEx("DrugTransport_Unloaded", DRUG_LOAD_FREEZE * 1000, false, "i", playerid);
        return 1;
    }

    if(g_IsWorking[playerid] && g_JobStage[playerid] != JOB_STAGE_NONE)
    {
        // 2 secunde de freeze la atingerea checkpoint-ului, apoi unfreeze
        TogglePlayerControllable(playerid, 0);
        SetTimerEx("Job_Unfreeze", 2000, false, "i", playerid);

        if(g_JobStage[playerid] == JOB_STAGE_PICKUP)
        {
            Job_StartDest(playerid);
        }
        else if(g_JobStage[playerid] == JOB_STAGE_DELIVER)
        {
            Job_PayDelivery(playerid);
            g_JobUnloadsDone[playerid]++;
            if(g_JobUnloadsDone[playerid] < JOB_UNLOADS_PER_LOAD)
                Job_StartDest(playerid);   // mai are o descarcare (fara sa treaca pe la load)
            else
                Job_StartSource(playerid); // ambele descarcari facute -> inapoi la load
        }
        return 1;
    }

    // Uber: soferul a ajuns la pasagerul asignat (inainte ca acesta sa se urce)
    if(g_UberOnDuty[playerid] && g_UberPassenger[playerid] != INVALID_PLAYER_ID &&
       !g_UberRideActive[g_UberPassenger[playerid]])
    {
        DisablePlayerCheckpoint(playerid);
        SendClientMessage(playerid, COLOR_INFO, C_INFO"[Uber] "C_WHITE"You reached your passenger. Wait for them to get in.");
        return 1;
    }

    // Bus Driver: a atins o statie de pe ruta activa
    if(g_BusLine[playerid] > 0)
    {
        new line  = g_BusLine[playerid] - 1;
        new cp    = g_BusCP[playerid];             // index 0-based al statiei tocmai atinse
        new total = g_BusRouteCount[line];

        new Float:cx = g_BusRoute[line][cp][0];
        new Float:cy = g_BusRoute[line][cp][1];
        new Float:dist = Job_Dist2D(g_BusLastX[playerid], g_BusLastY[playerid], cx, cy);
        new pay = JOB_BUS_CP_PAY + floatround(JOB_BUS_PAY_PER_M * dist);

        g_BusLastX[playerid] = cx;
        g_BusLastY[playerid] = cy;

        new bool:lastCp = (cp + 1 >= total);       // tocmai a atins ultima statie
        if(lastCp) pay += JOB_BUS_FINISH_BONUS;

        PlayerData[playerid][pMoney] += pay;
        GivePlayerMoney(playerid, pay);
        UpdatePlayer(playerid, pMoney);

        // GameText mic, jos: statia curenta / total
        new gt[16];
        format(gt, sizeof(gt), "~w~%d/%d", cp + 1, total);
        GameTextForPlayer(playerid, gt, 3000, 3);

        // Avanseaza; dupa ultima statie ruta reincepe de la statia 1
        g_BusCP[playerid] = lastCp ? 0 : (cp + 1);
        Bus_SetCheckpoint(playerid);

        new bm[144];
        if(lastCp)
            format(bm, sizeof(bm), C_SUCCESS"[Bus] "C_WHITE"Route complete! "C_SUCCESS"+$%s"C_WHITE" (incl. "C_INFO"$%s"C_WHITE" bonus). Starting again from stop 1.",
                MoneyStr(pay), MoneyStr(JOB_BUS_FINISH_BONUS));
        else
            format(bm, sizeof(bm), C_SUCCESS"[Bus] "C_WHITE"Stop "C_INFO"%d/%d"C_WHITE" reached. "C_SUCCESS"+$%s"C_WHITE".",
                cp + 1, total, MoneyStr(pay));
        SendClientMessage(playerid, COLOR_SUCCESS, bm);
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
        FactionData[fid][fHQX], FactionData[fid][fHQY], FactionData[fid][fHQZ]-0.5,
        20.0, 0, 0);
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
        FactionData[fid][fInteriorX], FactionData[fid][fInteriorY], FactionData[fid][fInteriorZ]-0.5,
        10.0, FactionData[fid][fvw], 0);
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
       IsPlayerInRangeOfPoint(playerid, 1.5, FactionData[fid][fHQX], FactionData[fid][fHQY], FactionData[fid][fHQZ]))
    {
        AC_SetPos(playerid, FactionData[fid][fInteriorX], FactionData[fid][fInteriorY], FactionData[fid][fInteriorZ]);
        AC_SetVW(playerid, FactionData[fid][fvw]);
        AC_SetInterior(playerid, FactionData[fid][fInterior]);
        return;
    }

    // Langa pickup-ul din interior (vw-ul factiunii) -> iesi afara
    if(GetPlayerVirtualWorld(playerid) == FactionData[fid][fvw] &&
       IsPlayerInRangeOfPoint(playerid, 1.5, FactionData[fid][fInteriorX], FactionData[fid][fInteriorY], FactionData[fid][fInteriorZ]))
    {
        AC_SetPos(playerid, FactionData[fid][fHQX], FactionData[fid][fHQY], FactionData[fid][fHQZ]);
        AC_SetVW(playerid, 0);
        AC_SetInterior(playerid, 0);
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

// ============================================================
//  CITYHALL (intrare/iesire)
// ============================================================
new Float:CITYHALL_EXT_X = 0.0;   // suprascris din locations_admin ("Cityhall")
new Float:CITYHALL_EXT_Y = 0.0;
new Float:CITYHALL_EXT_Z = 0.0;
new Float:CITYHALL_INT_X = 0.0;   // suprascris din locations_admin ("cityhall_int")
new Float:CITYHALL_INT_Y = 0.0;
new Float:CITYHALL_INT_Z = 0.0;
#define CITYHALL_INTERIOR     3
#define CITYHALL_PICKUP_MODEL 1276
#define CITYHALL_MAPICON      35
#define CITYHALL_RANGE        2.5

// Creeaza pickup-urile, map icon-ul si etichetele 3D pentru Cityhall (exterior + interior)
stock Cityhall_Create()
{
    CreateDynamicPickup(CITYHALL_PICKUP_MODEL, 1, CITYHALL_EXT_X, CITYHALL_EXT_Y, CITYHALL_EXT_Z, 0, 0);
    CreateDynamicPickup(CITYHALL_PICKUP_MODEL, 1, CITYHALL_INT_X, CITYHALL_INT_Y, CITYHALL_INT_Z, 0, CITYHALL_INTERIOR);

    CreateDynamicMapIcon(CITYHALL_EXT_X, CITYHALL_EXT_Y, CITYHALL_EXT_Z, CITYHALL_MAPICON, 0, 0, 0, -1, 99999.0, MAPICON_GLOBAL);

    CreateDynamic3DTextLabel("[ Cityhall ]\n[ Press enter to enter ]", COLOR_WHITE,
        CITYHALL_EXT_X, CITYHALL_EXT_Y, CITYHALL_EXT_Z-0.5, 20.0,
        INVALID_PLAYER_ID, INVALID_VEHICLE_ID, 0, 0, 0);
    CreateDynamic3DTextLabel("[ Cityhall ]\n[ Press enter to exit ]", COLOR_WHITE,
        CITYHALL_INT_X, CITYHALL_INT_Y, CITYHALL_INT_Z-0.5, 20.0,
        INVALID_PLAYER_ID, INVALID_VEHICLE_ID, 0, 0, CITYHALL_INTERIOR);
}

// Intrare/iesire Cityhall (apasand KEY_SECONDARY_ATTACK langa pickup)
stock Cityhall_Toggle(playerid)
{
    // Exterior -> interior
    if(GetPlayerInterior(playerid) == 0 &&
       IsPlayerInRangeOfPoint(playerid, CITYHALL_RANGE, CITYHALL_EXT_X, CITYHALL_EXT_Y, CITYHALL_EXT_Z))
    {
        AC_SetPos(playerid, CITYHALL_INT_X, CITYHALL_INT_Y, CITYHALL_INT_Z);
        AC_SetInterior(playerid, CITYHALL_INTERIOR);
        return;
    }
    // Interior -> exterior
    if(GetPlayerInterior(playerid) == CITYHALL_INTERIOR &&
       IsPlayerInRangeOfPoint(playerid, CITYHALL_RANGE, CITYHALL_INT_X, CITYHALL_INT_Y, CITYHALL_INT_Z))
    {
        AC_SetPos(playerid, CITYHALL_EXT_X, CITYHALL_EXT_Y, CITYHALL_EXT_Z);
        AC_SetInterior(playerid, 0);
    }
}

// Seteaza map icon-urile factiunilor (MAPICON_GLOBAL) pentru un player
stock Factions_SetPlayerIcons(playerid)
{
    for(new i = 1; i <= MAX_FACTIONS; i++)
    {
        if(FactionData[i][fMapIconID] == -1) continue;
        if(FactionData[i][fHQX] == 0.0 && FactionData[i][fHQY] == 0.0) continue;
        SetPlayerMapIcon(playerid, i, FactionData[i][fHQX], FactionData[i][fHQY], FactionData[i][fHQZ],
            FactionData[i][fMapIconID], FactionColors[i], MAPICON_GLOBAL);
    }
    SetPlayerMapIcon(playerid, 0, 846.4172, -2059.0867, 12.8672, 35, 0, MAPICON_GLOBAL); // SPAWN POINT
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
    Float:hLocX, Float:hLocY, Float:hLocZ,
    hHasFridge, hFridge[5], // frigider: 0=lapte, 1=banane, 2=apa, 3=suc, 4=bere
    hBank // contul casei
}
new HouseData[MAX_HOUSES][E_HOUSE_DATA];

// ---- Frigider casa ----
#define FRIDGE_PRICE        10000
#define FRIDGE_ITEMS        5
// indici: 0=Milk(L), 1=Banana(pcs), 2=Water(L), 3=Juice(L), 4=Beer(L)
new const g_FridgeName[FRIDGE_ITEMS][16] = { "Milk", "Banana", "Water", "Juice", "Beer" };
new const g_FridgeUnit[FRIDGE_ITEMS][8]  = { "L", "pcs", "L", "L", "L" };
new const g_FridgeMax[FRIDGE_ITEMS]      = { 20, 30, 25, 20, 50 };
new const g_FridgePrice[FRIDGE_ITEMS]    = { 100, 50, 150, 200, 250 };
new const g_FridgeHeal[FRIDGE_ITEMS]     = { 20, 10, 25, 15, 10 };
#define FRIDGE_OPEN_START   15 // ora de deschidere pentru /frigde buy
#define FRIDGE_OPEN_END     20 // ora de inchidere (exclusiv)
#define FRIDGE_RANGE        20.0
#define FRIDGE_BIZ_ID       14 // business-ul care primeste o cota din cumparaturile de la frigider
#define FRIDGE_BIZ_CUT_PCT  10 // % din valoarea cumparata care intra in banca business-ului
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
        HouseData[idx][hLocX], HouseData[idx][hLocY], HouseData[idx][hLocZ]-0.3, 20.0, 0, 0);
}

// Returneaza indexul (in HouseData) al casei cu hID == hid, sau -1
stock Houses_FindByID(hid)
{
    for(new i = 0; i < g_HouseCount; i++)
        if(HouseData[i][hID] == hid) return i;
    return -1;
}

// Returneaza indexul unui item de frigider dupa nume (EN sau RO), sau -1
stock Fridge_FindItem(const name[])
{
    if(strcmp(name, "milk", true) == 0   || strcmp(name, "lapte", true) == 0)  return 0;
    if(strcmp(name, "banana", true) == 0 || strcmp(name, "banane", true) == 0) return 1;
    if(strcmp(name, "water", true) == 0  || strcmp(name, "apa", true) == 0)    return 2;
    if(strcmp(name, "juice", true) == 0  || strcmp(name, "suc", true) == 0)    return 3;
    if(strcmp(name, "beer", true) == 0   || strcmp(name, "bere", true) == 0)   return 4;
    return -1;
}

// Returneaza indexul casei detinute de player daca e in raza ei, altfel -1
stock Player_FridgeHouse(playerid)
{
    if(PlayerData[playerid][pHouse] == 0) return -1;
    new hidx = Houses_FindByID(PlayerData[playerid][pHouse]);
    if(hidx == -1) return -1;
    if(!IsPlayerInRangeOfPoint(playerid, FRIDGE_RANGE, HouseData[hidx][hLocX], HouseData[hidx][hLocY], HouseData[hidx][hLocZ]))
        return -1;
    return hidx;
}

// Salveaza in DB frigiderul unei case
stock Houses_SaveFridge(hidx)
{
    new q[256];
    mysql_format(g_SQL, q, sizeof(q),
        "UPDATE `houses` SET `has_fridge`=%d, `fridge_milk`=%d, `fridge_banana`=%d, `fridge_water`=%d, `fridge_juice`=%d, `fridge_beer`=%d WHERE `id`=%d",
        HouseData[hidx][hHasFridge], HouseData[hidx][hFridge][0], HouseData[hidx][hFridge][1],
        HouseData[hidx][hFridge][2], HouseData[hidx][hFridge][3], HouseData[hidx][hFridge][4], HouseData[hidx][hID]);
    mysql_tquery(g_SQL, q, "", "", 0);
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

// Tipuri de casa (hType): 1=Vila, 2=Casa la oras, 3=Apartament, 4=Casa la tara.
// Doar "Casa la tara" (tip 4) poate cumpara animale.
#define HOUSE_TYPE_COUNTRYSIDE 4

// Scrie "Yes"/"No" in dest (evita ternarul cu literale de lungimi diferite)
stock YesNoText(cond, dest[], size = sizeof(dest))
{
    if(cond) format(dest, size, "Yes");
    else     format(dest, size, "No");
}

// Numele in engleza al tipului de casa (hType)
stock HouseTypeName(type, dest[], size = sizeof(dest))
{
    switch(type)
    {
        case 1: format(dest, size, "Villa");
        case 2: format(dest, size, "City House");
        case 3: format(dest, size, "Apartment");
        case 4: format(dest, size, "Countryside House");
        default: format(dest, size, "Unknown");
    }
}

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
    new Float:z = HouseData[hidx][hLocZ] - 0.2;
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
//  ATM-URI (bancomate)
// ============================================================
#define MAX_ATMS            100
#define ATM_RANGE           5.0
#define ATM_PICKUP_MODEL    1212
#define ATM_MAX_TRANSACTION 100000  // maxim per /deposit sau /withdraw
#define ATM_MIN_TRANSACTION 100     // minim per /deposit sau /withdraw
#define ATM_DEPOSIT_BASE    40      // taxa fixa la depunere
#define ATM_WITHDRAW_BASE   60      // taxa fixa la retragere
#define ATM_BANK_BIZ_A      19      // banca 1 (business)
#define ATM_BANK_BIZ_B      20      // banca 2 (business)

enum E_ATM_DATA
{
    atmID, atmType,
    Float:atmX, Float:atmY, Float:atmZ,
    atmBankOwner // id-ul business-ului-banca cel mai apropiat
}
new ATMData[MAX_ATMS][E_ATM_DATA];
new g_AtmPickup[MAX_ATMS];
new Text3D:g_AtmLabel[MAX_ATMS];
new g_AtmCount = 0;

// Creeaza pickup-ul + eticheta 3D pentru un ATM
stock ATM_Create(idx)
{
    new Float:z = ATMData[idx][atmZ] - 0.3;

    if(g_AtmPickup[idx] != -1) { DestroyPickup(g_AtmPickup[idx]); g_AtmPickup[idx] = -1; }
    g_AtmPickup[idx] = CreatePickup(ATM_PICKUP_MODEL, 1, ATMData[idx][atmX], ATMData[idx][atmY], z, -1);

    if(g_AtmLabel[idx] != Text3D:INVALID_3DTEXT_ID)
    {
        Delete3DTextLabel(g_AtmLabel[idx]);
        g_AtmLabel[idx] = Text3D:INVALID_3DTEXT_ID;
    }
    new label[160];
    format(label, sizeof(label), "[ ATM #%d ]\n[ /deposit <suma> ]\n[ /withdraw <suma> ]", ATMData[idx][atmID]);
    g_AtmLabel[idx] = Create3DTextLabel(label, COLOR_WHITE, ATMData[idx][atmX], ATMData[idx][atmY], z-0.5, 25.0, 0, 0);
}

// Returneaza indexul celui mai apropiat ATM in raza ATM_RANGE (sau -1)
stock ATM_FindNearbyIndex(playerid)
{
    for(new i = 0; i < g_AtmCount; i++)
        if(IsPlayerInRangeOfPoint(playerid, ATM_RANGE, ATMData[i][atmX], ATMData[i][atmY], ATMData[i][atmZ]))
            return i;
    return -1;
}

// Returneaza indexul ATM-ului cu atmID dat (sau -1)
stock ATM_FindByID(id)
{
    for(new i = 0; i < g_AtmCount; i++)
        if(ATMData[i][atmID] == id) return i;
    return -1;
}
// ATM_NearestBank() e definit mai jos, dupa structurile de business (depinde de BusinessData)

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
        BusinessData[idx][bLocX], BusinessData[idx][bLocY], BusinessData[idx][bLocZ]-0.5, 20.0, 0, 0);
}

// Seteaza map icon-urile business-urilor (36 = detinut, 52 = de vanzare) pentru un player
stock Businesses_SetPlayerIcons(playerid)
{
    for(new i = 0; i < g_BusinessCount; i++)
    {
        SetPlayerMapIcon(playerid, BUSINESS_ICON_SLOT_BASE + i,
            BusinessData[i][bLocX], BusinessData[i][bLocY], BusinessData[i][bLocZ],
            56, 0, MAPICON_GLOBAL);
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
#define WAR_MIN_FACTION_ONLINE    0  // TEMPORAR: de readus la 2 (minim membri online per factiune pt /war)
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

    new warMsg[200];
    format(warMsg, sizeof(warMsg), C_ERROR"[War] "C_WHITE"%s"C_WHITE" is attacking territory "C_INFO"#%d"C_WHITE" (%s) of "C_WHITE"%s"C_WHITE"!",
        FactionData[atkFid][fName], TurfData[tidx][tID], TurfData[tidx][tName], FactionData[defFid][fName]);
    War_NotifyFaction(atkFid, COLOR_ERROR, warMsg);
    War_NotifyFaction(defFid, COLOR_ERROR, warMsg);

    format(warMsg, sizeof(warMsg), C_ERROR"[War] "C_WHITE"The war starts in "C_INFO"2 minutes"C_WHITE".");
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

    new wmsg[350];
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
//  DRUGS (mafii) - functii
// ============================================================
// Trimite un mesaj tuturor membrilor online ai unei factiuni (reutilizeaza War_NotifyFaction)
// Reseteaza starea de transport a unui player
stock Drug_ResetTransport(playerid)
{
    g_DrugStage[playerid]   = DRUG_STAGE_NONE;
    g_DrugPartner[playerid] = INVALID_PLAYER_ID;
    DisablePlayerCheckpoint(playerid);
}

// La descarcare/craft: anunta factiunea + salveaza seiful
stock Drug_AnnounceSeif(fid, const text[])
{
    War_NotifyFaction(fid, COLOR_INFO, text);
}

// Timer: dupa 5s de incarcare iarba -> trimite playerul la HQ
public DrugTransport_Loaded(playerid)
{
    if(!IsPlayerConnected(playerid) || g_DrugStage[playerid] != DRUG_STAGE_LOADING) return 1;

    TogglePlayerControllable(playerid, 1);

    new fid = PlayerData[playerid][pFaction];
    if(fid < 1 || fid > MAX_FACTIONS) { Drug_ResetTransport(playerid); return 1; }

    g_DrugStage[playerid] = DRUG_STAGE_TOHQ;
    SetPlayerCheckpoint(playerid, FactionData[fid][fHQX], FactionData[fid][fHQY], FactionData[fid][fHQZ], DRUG_CP_SIZE);
    SendClientMessage(playerid, COLOR_INFO, C_INFO"[Drugs] "C_WHITE"Transport the weed to your faction HQ. Watch out for the police and don't lose the goods.");
    return 1;
}

// Timer: dupa 5s de descarcare la HQ -> aduna iarba in seif si anunta factiunea
public DrugTransport_Unloaded(playerid)
{
    if(!IsPlayerConnected(playerid) || g_DrugStage[playerid] != DRUG_STAGE_UNLOADING) return 1;

    TogglePlayerControllable(playerid, 1);

    new fid = PlayerData[playerid][pFaction];
    if(fid < 1 || fid > MAX_FACTIONS) { Drug_ResetTransport(playerid); return 1; }

    new amount = 900 + random(100);
    new space  = SEIF_MAX_HERBS - FactionData[fid][fSeifHerbs];
    if(space < 0) space = 0;
    if(amount > space) amount = space; // nu depasi capacitatea

    FactionData[fid][fSeifHerbs] += amount;
    Faction_SaveSeif(fid);

    new partner = g_DrugPartner[playerid];
    new partnerName[24] = "?";
    if(partner != INVALID_PLAYER_ID && IsPlayerConnected(partner))
        format(partnerName, sizeof(partnerName), "%s", PlayerData[partner][pName]);

    new dmsg[160];
    format(dmsg, sizeof(dmsg),
        C_SUCCESS"[Faction] "C_WHITE"%s and %s successfully transported "C_INFO"%d"C_WHITE" grams of weed. The vault now holds "C_INFO"%d/%d"C_WHITE" grams of weed.",
        PlayerData[playerid][pName], partnerName, amount, FactionData[fid][fSeifHerbs], SEIF_MAX_HERBS);
    Drug_AnnounceSeif(fid, dmsg);

    // Mesaj personal catre toti ocupantii masinii de transport
    new pmsg[128];
    format(pmsg, sizeof(pmsg), C_SUCCESS"[Drugs] "C_WHITE"You deposited "C_INFO"%d"C_WHITE" grams of weed in the faction vault.", amount);
    new tveh = GetPlayerVehicleID(playerid);
    if(tveh != 0)
    {
        for(new i = 0; i < MAX_PLAYERS; i++)
            if(IsPlayerConnected(i) && PlayerData[i][pLogged] && GetPlayerVehicleID(i) == tveh)
                SendClientMessage(i, COLOR_SUCCESS, pmsg);
    }
    else SendClientMessage(playerid, COLOR_SUCCESS, pmsg); // fallback: soferul nu mai e in vehicul

    Drug_ResetTransport(playerid);
    return 1;
}

// Timer: dupa 30s de craft -> produce drugs in seif si anunta factiunea
public DrugCraft_Finish(playerid)
{
    if(!IsPlayerConnected(playerid)) return 1;

    TogglePlayerControllable(playerid, 1);

    new fid = PlayerData[playerid][pFaction];
    if(fid < 1 || fid > MAX_FACTIONS) return 1;

    new produced = 5 + random(3);
    new space    = SEIF_MAX_DRUGS - FactionData[fid][fSeifDrugs];
    if(space < 0) space = 0;
    if(produced > space) produced = space;

    FactionData[fid][fSeifDrugs] += produced;
    Faction_SaveSeif(fid);

    new dmsg[160];
    format(dmsg, sizeof(dmsg),
        C_SUCCESS"[Faction] "C_WHITE"%s produced "C_INFO"%d"C_WHITE" grams of drugs. The vault now holds "C_INFO"%d/%d"C_WHITE" grams of drugs.",
        PlayerData[playerid][pName], produced, FactionData[fid][fSeifDrugs], SEIF_MAX_DRUGS);
    Drug_AnnounceSeif(fid, dmsg);
    return 1;
}

// Timer: scoate freeze-ul de 1s dupa /drugs use
public Drug_Unfreeze(playerid)
{
    if(IsPlayerConnected(playerid)) TogglePlayerControllable(playerid, 1);
    return 1;
}

// (Re)creeaza pickup-ul + eticheta seifului pentru o mafie, in interiorul si vw-ul ei (din DB)
stock Drugs_RecreateSeifMarker(fid)
{
    if(fid < MAFIA_FID_MIN || fid > MAFIA_FID_MAX) return;

    if(IsValidDynamicPickup(g_SeifPickup[fid]))       DestroyDynamicPickup(g_SeifPickup[fid]);
    if(IsValidDynamic3DTextLabel(g_SeifLabel[fid]))   DestroyDynamic3DTextLabel(g_SeifLabel[fid]);

    g_SeifPickup[fid] = CreateDynamicPickup(1279, 1, DRUG_SEIF_X, DRUG_SEIF_Y, DRUG_SEIF_Z,
        FactionData[fid][fvw], FactionData[fid][fInterior]);

    g_SeifLabel[fid] = CreateDynamic3DTextLabel("[ Seif ]\n[ /seif ]\n[ /drugs get ]", COLOR_WHITE,
        DRUG_SEIF_X, DRUG_SEIF_Y, DRUG_SEIF_Z, 25.0,
        INVALID_PLAYER_ID, INVALID_VEHICLE_ID, 0,
        FactionData[fid][fvw], FactionData[fid][fInterior]);

    if(IsValidDynamic3DTextLabel(g_CraftLabel[fid])) DestroyDynamic3DTextLabel(g_CraftLabel[fid]);
    g_CraftLabel[fid] = CreateDynamic3DTextLabel("[ Crafting machine ]\n[ /drugs craft ]", COLOR_WHITE,
        DRUG_CRAFT_X, DRUG_CRAFT_Y, DRUG_CRAFT_Z - 1.0, 25.0,
        INVALID_PLAYER_ID, INVALID_VEHICLE_ID, 0,
        FactionData[fid][fvw], FactionData[fid][fInterior]);
}

// ============================================================
//  LOCATII IMPORTANTE
// ============================================================
#define MAX_LOCATIONS 100

enum E_LOCATION_DATA
{
    locID, locName[32], Float:locX, Float:locY, Float:locZ, locInterior, locVW, bool:locForGPS, locCategory[32], locDescr[64]
}
new LocationData[MAX_LOCATIONS][E_LOCATION_DATA];
new g_LocationCount = 0;

stock Locations_FindByName(const name[])
{
    for(new i = 0; i < g_LocationCount; i++)
        if(strcmp(LocationData[i][locName], name, true) == 0) return i;
    return -1;
}

// Cauta o locatie dupa locID (din locations_admin), returneaza indexul in LocationData sau -1
stock Locations_FindByID(id)
{
    for(new i = 0; i < g_LocationCount; i++)
        if(LocationData[i][locID] == id) return i;
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
    vfColor1, vfColor2,
    Float:vfFuel
}
new VFactionData[MAX_VFACTION_VEHICLES][E_VFACTION_DATA];
new g_VFactionVehicle[MAX_VFACTION_VEHICLES];
new g_VFactionCount = 0;

// vehicleid (real, din CreateVehicle) -> ID factiune proprietara (0 = niciuna)
new g_VehicleFactionOwner[MAX_VEHICLES];

// Motorina live pentru ORICE vehicul (indexat dupa vehicleid, 0.0 - 100.0)
new Float:g_VehicleFuel[MAX_VEHICLES];

// Girofar atasat pe vehicul (obiect dinamic; 0 = niciunul). Indexat dupa vehicleid.
// Se pune automat la incarcare pe vehiculele de factiune cu vfID 94-97 (Infernus).
new STREAMER_TAG_OBJECT:g_VehicleGirofar[MAX_VEHICLES];
#define GIROFAR_OBJECT_MODEL  19419  // police_lights01 (bara de lumini)
#define GIROFAR_OFFSET_X      0.0
#define GIROFAR_OFFSET_Y      0.0
#define GIROFAR_OFFSET_Z      0.71   // inaltimea plafonului la Infernus (411)

// Coordonate salvate temporar (per player) pentru /save si /gotosave
new Float:g_SavedPos[MAX_PLAYERS][4]; // x, y, z, angle
new g_SavedInt[MAX_PLAYERS], g_SavedVW[MAX_PLAYERS];
new bool:g_HasSavedPos[MAX_PLAYERS];

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
        new oldveh = g_VFactionVehicle[idx];
        if(oldveh >= 0 && oldveh < MAX_VEHICLES && IsValidDynamicObject(g_VehicleGirofar[oldveh]))
        {
            DestroyDynamicObject(g_VehicleGirofar[oldveh]);
            g_VehicleGirofar[oldveh] = STREAMER_TAG_OBJECT:INVALID_STREAMER_ID;
        }
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
    {
        g_VehicleFactionOwner[vehid] = VFactionData[idx][vfFactionID];
        g_VehicleFuel[vehid] = VFactionData[idx][vfFuel];

        // Girofar pe vehiculele de factiune cu vfID 94-97 (Infernus)
        if(VFactionData[idx][vfID] >= 94 && VFactionData[idx][vfID] <= 97)
        {
            new Float:gx, Float:gy, Float:gz;
            GetVehiclePos(vehid, gx, gy, gz);
            g_VehicleGirofar[vehid] = CreateDynamicObject(GIROFAR_OBJECT_MODEL, gx, gy, gz + 1.0, 0.0, 0.0, 0.0);
            AttachDynamicObjectToVehicle(g_VehicleGirofar[vehid], vehid,
                GIROFAR_OFFSET_X, GIROFAR_OFFSET_Y, GIROFAR_OFFSET_Z, 0.0, 0.0, 0.0);
        }
    }
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
#define MAX_HOSPITALS        4
// Locatiile spitalelor (/curedisease) - incarcate din locations_admin (id 22, 23)
new Float:g_HospitalLoc[MAX_HOSPITALS][3];
new g_HospitalCount = 0;

// True daca playerul e in raza vreunui spital
stock bool:Player_NearHospital(playerid)
{
    for(new i = 0; i < g_HospitalCount; i++)
        if(IsPlayerInRangeOfPoint(playerid, HOSPITAL_RANGE, g_HospitalLoc[i][0], g_HospitalLoc[i][1], g_HospitalLoc[i][2]))
            return true;
    return false;
}
#define DISEASE_CURE_PRICE   200
#define DISEASE_FREEZE_TIME  10000 // 10 secunde, in ms

#define MAX_SHOPS             20
#define SHOP_ICON_SLOT_BASE   70 // sloturile 70-89 (0=spawn, 1-8=factiuni, 9=baschet, 10-59=business, 60-69=incendii, 90-94=pizza, 95-99=burger)
#define SHOP_MAPICON_ID       17
#define SHOP_PICKUP_MODEL     954
#define SHOP_RANGE            10.0

enum E_SHOP_DATA
{
    shopID,
    Float:shopX, Float:shopY, Float:shopZ
}
new ShopData[MAX_SHOPS][E_SHOP_DATA];
new g_ShopPickup[MAX_SHOPS];
new Text3D:g_ShopLabel[MAX_SHOPS];
new g_ShopCount = 0;

// Creeaza (sau recreeaza) pickup-ul + eticheta 3D pentru un shop
stock Shop_Create(idx)
{
    if(g_ShopPickup[idx] != -1) { DestroyPickup(g_ShopPickup[idx]); g_ShopPickup[idx] = -1; }
    g_ShopPickup[idx] = CreatePickup(SHOP_PICKUP_MODEL, 1, ShopData[idx][shopX], ShopData[idx][shopY], ShopData[idx][shopZ], -1);

    if(g_ShopLabel[idx] != Text3D:INVALID_3DTEXT_ID)
    {
        Delete3DTextLabel(g_ShopLabel[idx]);
        g_ShopLabel[idx] = Text3D:INVALID_3DTEXT_ID;
    }
    new label[64];
    format(label, sizeof(label), "[ Shop #%d ]\n[ Use /shop ]", ShopData[idx][shopID]);
    g_ShopLabel[idx] = Create3DTextLabel(label, COLOR_WHITE, ShopData[idx][shopX], ShopData[idx][shopY], ShopData[idx][shopZ] - 0.5, 40.0, 0, 0);
}

// Returneaza indexul shop-ului cu shopID dat (sau -1)
stock Shop_FindByID(id)
{
    for(new i = 0; i < g_ShopCount; i++)
        if(ShopData[i][shopID] == id) return i;
    return -1;
}

// Seteaza map icon-urile shop-urilor pentru un player (si curata sloturile shop-urilor sterse)
stock Shop_SetPlayerIcons(playerid)
{
    for(new i = 0; i < MAX_SHOPS; i++)
    {
        if(i < g_ShopCount)
            SetPlayerMapIcon(playerid, SHOP_ICON_SLOT_BASE + i,
                ShopData[i][shopX], ShopData[i][shopY], ShopData[i][shopZ],
                SHOP_MAPICON_ID, 0, MAPICON_GLOBAL);
        else
            RemovePlayerMapIcon(playerid, SHOP_ICON_SLOT_BASE + i);
    }
}

// Reimprospateaza icoanele de shop pentru toti playerii conectati (dupa create/move/delete)
stock Shop_RefreshAllIcons()
{
    for(new i = 0; i < MAX_PLAYERS; i++)
        if(IsPlayerConnected(i) && PlayerData[i][pLogged])
            Shop_SetPlayerIcons(i);
}

// Verifica daca playerid e in raza unuia dintre shop-uri
stock bool:Shop_PlayerInRange(playerid)
{
    for(new i = 0; i < g_ShopCount; i++)
        if(IsPlayerInRangeOfPoint(playerid, SHOP_RANGE, ShopData[i][shopX], ShopData[i][shopY], ShopData[i][shopZ]))
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
#define PIZZA_ICON_SLOT_BASE  90 // sloturile 90-94 (mutat din 76-80 ca sa nu se loveasca de shop-uri 70-89)
#define PIZZA_MAPICON_ID      29
#define PIZZA_PICKUP_MODEL    1582

#define BURGER_HEAL_AMOUNT    25.0
#define BURGER_BIZ_ID         13
#define BURGER_ICON_SLOT_BASE 95 // sloturile 95-99 (mutat din 81-85 ca sa nu se loveasca de shop-uri 70-89)
#define BURGER_MAPICON_ID     10
#define BURGER_PICKUP_MODEL   19320

// Locatiile de /pizza si /burger se incarca din tabelul `fastfood` (ffType 1=pizza, 2=burger).
new Float:PizzaLocations[MAX_FOOD_LOCATIONS][3];
new Float:BurgerLocations[MAX_FOOD_LOCATIONS][3];
new g_PizzaName[MAX_FOOD_LOCATIONS][32];   // ffName pt afisare in GPS
new g_BurgerName[MAX_FOOD_LOCATIONS][32];
// ffID-ul din DB pentru fiecare slot (0 = slot gol) + handle-uri pickup/eticheta pt recreere curata
new g_PizzaFFID[MAX_FOOD_LOCATIONS];
new g_BurgerFFID[MAX_FOOD_LOCATIONS];
new g_PizzaPickup[MAX_FOOD_LOCATIONS];
new g_BurgerPickup[MAX_FOOD_LOCATIONS];
new Text3D:g_PizzaLabel[MAX_FOOD_LOCATIONS];
new Text3D:g_BurgerLabel[MAX_FOOD_LOCATIONS];
new bool:g_FastFoodInit = false;

// Initializeaza handle-urile pickup/eticheta la valori invalide (o singura data, inainte de prima incarcare)
stock FastFood_InitHandles()
{
    if(g_FastFoodInit) return;
    for(new i = 0; i < MAX_FOOD_LOCATIONS; i++)
    {
        g_PizzaPickup[i]  = -1;
        g_BurgerPickup[i] = -1;
        g_PizzaLabel[i]   = Text3D:INVALID_3DTEXT_ID;
        g_BurgerLabel[i]  = Text3D:INVALID_3DTEXT_ID;
    }
    g_FastFoodInit = true;
}

// Verifica daca playerid e in raza uneia dintre cele 5 locatii de /pizza
stock bool:Pizza_PlayerInRange(playerid)
{
    for(new i = 0; i < MAX_FOOD_LOCATIONS; i++)
    {
        if(PizzaLocations[i][0] == 0.0 && PizzaLocations[i][1] == 0.0) continue;
        if(IsPlayerInRangeOfPoint(playerid, FOOD_RANGE, PizzaLocations[i][0], PizzaLocations[i][1], PizzaLocations[i][2]))
            return true;
    }
    return false;
}

// Verifica daca playerid e in raza uneia dintre cele 5 locatii de /burger
stock bool:Burger_PlayerInRange(playerid)
{
    for(new i = 0; i < MAX_FOOD_LOCATIONS; i++)
    {
        if(BurgerLocations[i][0] == 0.0 && BurgerLocations[i][1] == 0.0) continue;
        if(IsPlayerInRangeOfPoint(playerid, FOOD_RANGE, BurgerLocations[i][0], BurgerLocations[i][1], BurgerLocations[i][2]))
            return true;
    }
    return false;
}

// Recreeaza pickup-urile si etichetele 3D pentru locatiile de /pizza (idempotent: distruge intai handle-urile vechi)
stock Pizza_CreateWorld()
{
    FastFood_InitHandles();

    new label[96];
    format(label, sizeof(label), "[ Buy Food ]\n[ /pizza ]\n[ +%d hp = %s$ ]", floatround(PIZZA_HEAL_AMOUNT), MoneyStr(g_PizzaPrice));

    for(new i = 0; i < MAX_FOOD_LOCATIONS; i++)
    {
        if(g_PizzaPickup[i] != -1) { DestroyPickup(g_PizzaPickup[i]); g_PizzaPickup[i] = -1; }
        if(g_PizzaLabel[i] != Text3D:INVALID_3DTEXT_ID) { Delete3DTextLabel(g_PizzaLabel[i]); g_PizzaLabel[i] = Text3D:INVALID_3DTEXT_ID; }

        if(PizzaLocations[i][0] == 0.0 && PizzaLocations[i][1] == 0.0) continue;
        g_PizzaPickup[i] = CreatePickup(PIZZA_PICKUP_MODEL, 1, PizzaLocations[i][0], PizzaLocations[i][1], PizzaLocations[i][2], -1);
        g_PizzaLabel[i]  = Create3DTextLabel(label, COLOR_WHITE, PizzaLocations[i][0], PizzaLocations[i][1], PizzaLocations[i][2], 25.0, 0, 0);
    }
}

// Seteaza map icon-urile locatiilor de /pizza pentru un player
stock Pizza_SetPlayerIcons(playerid)
{
    for(new i = 0; i < MAX_FOOD_LOCATIONS; i++)
    {
        if(PizzaLocations[i][0] == 0.0 && PizzaLocations[i][1] == 0.0) { RemovePlayerMapIcon(playerid, PIZZA_ICON_SLOT_BASE + i); continue; }
        SetPlayerMapIcon(playerid, PIZZA_ICON_SLOT_BASE + i,
            PizzaLocations[i][0], PizzaLocations[i][1], PizzaLocations[i][2],
            PIZZA_MAPICON_ID, 0, MAPICON_GLOBAL);
    }
}

// Recreeaza pickup-urile si etichetele 3D pentru locatiile de /burger (idempotent: distruge intai handle-urile vechi)
stock Burger_CreateWorld()
{
    FastFood_InitHandles();

    new label[96];
    format(label, sizeof(label), "[ Buy Food ]\n[ /burger ]\n[ +%d hp = %s$ ]", floatround(BURGER_HEAL_AMOUNT), MoneyStr(g_BurgerPrice));

    for(new i = 0; i < MAX_FOOD_LOCATIONS; i++)
    {
        if(g_BurgerPickup[i] != -1) { DestroyPickup(g_BurgerPickup[i]); g_BurgerPickup[i] = -1; }
        if(g_BurgerLabel[i] != Text3D:INVALID_3DTEXT_ID) { Delete3DTextLabel(g_BurgerLabel[i]); g_BurgerLabel[i] = Text3D:INVALID_3DTEXT_ID; }

        if(BurgerLocations[i][0] == 0.0 && BurgerLocations[i][1] == 0.0) continue;
        g_BurgerPickup[i] = CreatePickup(BURGER_PICKUP_MODEL, 1, BurgerLocations[i][0], BurgerLocations[i][1], BurgerLocations[i][2], -1);
        g_BurgerLabel[i]  = Create3DTextLabel(label, COLOR_WHITE, BurgerLocations[i][0], BurgerLocations[i][1], BurgerLocations[i][2], 25.0, 0, 0);
    }
}

// Seteaza map icon-urile locatiilor de /burger pentru un player
stock Burger_SetPlayerIcons(playerid)
{
    for(new i = 0; i < MAX_FOOD_LOCATIONS; i++)
    {
        if(BurgerLocations[i][0] == 0.0 && BurgerLocations[i][1] == 0.0) { RemovePlayerMapIcon(playerid, BURGER_ICON_SLOT_BASE + i); continue; }
        SetPlayerMapIcon(playerid, BURGER_ICON_SLOT_BASE + i,
            BurgerLocations[i][0], BurgerLocations[i][1], BurgerLocations[i][2],
            BURGER_MAPICON_ID, 0, MAPICON_GLOBAL);
    }
}

// Incarca locatiile de /pizza si /burger din tabelul `fastfood` (ffType 1=pizza, 2=burger)
stock FastFood_Load()
{
    FastFood_InitHandles();
    mysql_tquery(g_SQL, "SELECT `ffID`,`ffName`,`ffType`,`ffLocX`,`ffLocY`,`ffLocZ` FROM `fastfood` ORDER BY `ffID` ASC", "OnFastFoodLoaded");
}

public OnFastFoodLoaded()
{
    // reseteaza array-urile de coordonate si de ID-uri
    for(new i = 0; i < MAX_FOOD_LOCATIONS; i++)
    {
        PizzaLocations[i][0] = 0.0;  PizzaLocations[i][1] = 0.0;  PizzaLocations[i][2] = 0.0;
        BurgerLocations[i][0] = 0.0; BurgerLocations[i][1] = 0.0; BurgerLocations[i][2] = 0.0;
        g_PizzaFFID[i] = 0; g_BurgerFFID[i] = 0;
        g_PizzaName[i][0] = EOS; g_BurgerName[i][0] = EOS;
    }

    new rows = cache_num_rows(), pc = 0, bc = 0;
    for(new i = 0; i < rows; i++)
    {
        new ffid, type, ffname[32];
        cache_get_value_name_int(i, "ffID",   ffid);
        cache_get_value_name_int(i, "ffType", type);
        cache_get_value_name(i, "ffName", ffname, sizeof(ffname));
        new Float:x, Float:y, Float:z;
        cache_get_value_name_float(i, "ffLocX", x);
        cache_get_value_name_float(i, "ffLocY", y);
        cache_get_value_name_float(i, "ffLocZ", z);

        if(type == 2)
        {
            if(bc < MAX_FOOD_LOCATIONS) { BurgerLocations[bc][0] = x; BurgerLocations[bc][1] = y; BurgerLocations[bc][2] = z; g_BurgerFFID[bc] = ffid; format(g_BurgerName[bc], 32, "%s", ffname); bc++; }
        }
        else
        {
            if(pc < MAX_FOOD_LOCATIONS) { PizzaLocations[pc][0] = x; PizzaLocations[pc][1] = y; PizzaLocations[pc][2] = z; g_PizzaFFID[pc] = ffid; format(g_PizzaName[pc], 32, "%s", ffname); pc++; }
        }
    }

    // creeaza pickup-urile si etichetele 3D dupa ce coordonatele sunt incarcate
    Pizza_CreateWorld();
    Burger_CreateWorld();

    // reaplica map icon-urile pentru jucatorii deja conectati (relevant la /ffcreate, /ffc)
    for(new i = 0; i < MAX_PLAYERS; i++)
        if(IsPlayerConnected(i) && PlayerData[i][pLogged]) { Pizza_SetPlayerIcons(i); Burger_SetPlayerIcons(i); }

    printf("[FastFood] Incarcate %d locatii (%d pizza, %d burger).", rows, pc, bc);
    return 1;
}

// Returneaza tipul (1=pizza, 2=burger) al unui ffID incarcat, sau 0 daca nu exista
stock FastFood_FindType(ffid)
{
    if(ffid <= 0) return 0;
    for(new i = 0; i < MAX_FOOD_LOCATIONS; i++)
    {
        if(g_PizzaFFID[i]  == ffid) return 1;
        if(g_BurgerFFID[i] == ffid) return 2;
    }
    return 0;
}

// Numara cate locatii incarcate are un tip (1=pizza, 2=burger)
stock FastFood_CountType(type)
{
    new n = 0;
    for(new i = 0; i < MAX_FOOD_LOCATIONS; i++)
    {
        if(type == 2) { if(BurgerLocations[i][0] != 0.0 || BurgerLocations[i][1] != 0.0) n++; }
        else          { if(PizzaLocations[i][0]  != 0.0 || PizzaLocations[i][1]  != 0.0) n++; }
    }
    return n;
}

// Scrie numele tipului ("pizza"/"burger") in dest (evita ternarul cu literale de lungimi diferite)
stock FastFood_TypeName(type, dest[], destSize = sizeof(dest))
{
    if(type == 2) format(dest, destSize, "burger");
    else          format(dest, destSize, "pizza");
}

// A n-a locatie fast-food (0-based): intai pizza, apoi burger. Returneaza 1 daca exista, 0 altfel.
stock FastFood_GetNth(n, &ffid, &ffType, &Float:fx, &Float:fy, &Float:fz, ffname[], ffnamelen)
{
    new count = 0;
    for(new i = 0; i < MAX_FOOD_LOCATIONS; i++)
    {
        if(PizzaLocations[i][0] == 0.0 && PizzaLocations[i][1] == 0.0) continue;
        if(count == n) { ffid = g_PizzaFFID[i]; ffType = 1; fx = PizzaLocations[i][0]; fy = PizzaLocations[i][1]; fz = PizzaLocations[i][2]; format(ffname, ffnamelen, "%s", g_PizzaName[i]); return 1; }
        count++;
    }
    for(new i = 0; i < MAX_FOOD_LOCATIONS; i++)
    {
        if(BurgerLocations[i][0] == 0.0 && BurgerLocations[i][1] == 0.0) continue;
        if(count == n) { ffid = g_BurgerFFID[i]; ffType = 2; fx = BurgerLocations[i][0]; fy = BurgerLocations[i][1]; fz = BurgerLocations[i][2]; format(ffname, ffnamelen, "%s", g_BurgerName[i]); return 1; }
        count++;
    }
    return 0;
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
//  JOBURI (livrari pe checkpoint-uri) - functii comune
// ============================================================
// Creeaza cele 8 vehicule de Glovo (doar cu ele poti livra ca Glovo)
stock Job_CreateGlovoVehicles()
{
    g_GlovoVehicle[0] = CreateVehicle(586, 997.8586, -1381.1765, 12.7536, 150, 18, 18, 600); // glovo bike
    g_GlovoVehicle[1] = CreateVehicle(586, 997.9205, -1376.6702, 12.7767, 150, 18, 18, 600); // glovo bike2
    g_GlovoVehicle[2] = CreateVehicle(586, 997.7095, -1372.8729, 12.7963, 150, 18, 18, 600); // glovo bike3
    g_GlovoVehicle[3] = CreateVehicle(586, 1002.4597, -1370.5007, 12.7668, 0, 18, 18, 600);  // glovo bike4
    g_GlovoVehicle[4] = CreateVehicle(439, 1007.5924, -1368.9583, 13.2219, 0, 18, 18, 600);  // glovo car1
    g_GlovoVehicle[5] = CreateVehicle(439, 1016.6483, -1362.4163, 13.2734, 90, 18, 18, 600); // glovo car2
    g_GlovoVehicle[6] = CreateVehicle(439, 1016.5866, -1347.1003, 13.2731, 90, 18, 18, 600); // glovo car3
    g_GlovoVehicle[7] = CreateVehicle(439, 1016.7150, -1354.5189, 13.2739, 90, 18, 18, 600); // glovo car4

    new gPlate[16];
    for(new i = 0; i < MAX_GLOVO_VEHICLES; i++)
    {
        if(g_GlovoVehicle[i] == -1) continue;
        format(gPlate, sizeof(gPlate), "GLOVO %d", i + 1);
        SetVehicleNumberPlate(g_GlovoVehicle[i], gPlate);
        SetVehicleToRespawn(g_GlovoVehicle[i]);
    }
}

// Creeaza cele 4 camioane de ciment de lucru + decorul (puncte de incarcare/descarcare)
stock Job_CreateCementVehicles()
{
    g_CementVehicle[0] = CreateVehicle(524, 324.3096, 895.7263, 21.4, 222.3172, 18, 18, 600);
    g_CementVehicle[1] = CreateVehicle(524, 342.9575, 838.4533, 20.9, 332.1989, 18, 18, 600);
    g_CementVehicle[2] = CreateVehicle(524, 376.6194, 869.7731, 21.4,  29.2446, 18, 18, 600);
    g_CementVehicle[3] = CreateVehicle(524, 338.3516, 894.8132, 21.4, 318.4369, 18, 18, 600);
}

stock bool:Job_IsGlovoVehicle(vehicleid)
{
    if(vehicleid <= 0) return false;
    for(new i = 0; i < MAX_GLOVO_VEHICLES; i++)
        if(g_GlovoVehicle[i] == vehicleid) return true;
    return false;
}

stock bool:Job_IsCementVehicle(vehicleid)
{
    if(vehicleid <= 0) return false;
    for(new i = 0; i < MAX_CEMENT_VEHICLES; i++)
        if(g_CementVehicle[i] == vehicleid) return true;
    return false;
}

// Creeaza cele 3 vehicule pentru jobul de livrare arme
stock Job_CreateGunVehicles()
{
    g_GunVehicle[0] = CreateVehicle(609, 2501.6855, -2618.8445, 13.7147, 181.6162, 18, 18, 600);
    g_GunVehicle[1] = CreateVehicle(609, 2515.8430, -2628.9255, 13.7110,  88.5833, 18, 18, 600);
    g_GunVehicle[2] = CreateVehicle(609, 2500.5139, -2640.9800, 13.7184, 359.3251, 18, 18, 600);

    new gunPlate[16];
    for(new i = 0; i < MAX_GUN_VEHICLES; i++)
    {
        if(g_GunVehicle[i] == -1) continue;
        format(gunPlate, sizeof(gunPlate), "GUN %d", i + 1);
        SetVehicleNumberPlate(g_GunVehicle[i], gunPlate);
        SetVehicleToRespawn(g_GunVehicle[i]);
    }
}

stock bool:Job_IsGunVehicle(vehicleid)
{
    if(vehicleid <= 0) return false;
    for(new i = 0; i < MAX_GUN_VEHICLES; i++)
        if(g_GunVehicle[i] == vehicleid) return true;
    return false;
}

// Creeaza cele 3 Packer pentru jobul de transport auto (culoare ca celelalte job-uri: 18,18)
stock Job_CreateTransportVehicles()
{
    g_TransportVehicle[0] = CreateVehicle(443, 1984.0514, -2065.8538, 14.0127, 88.9700, 18, 18, 600);
    g_TransportVehicle[1] = CreateVehicle(443, 1984.0754, -2058.6465, 14.0066, 90.4182, 18, 18, 600);
    g_TransportVehicle[2] = -1; // doar 2 vehicule pentru acest job

    new trPlate[16];
    for(new i = 0; i < MAX_TRANSPORT_VEHICLES; i++)
    {
        if(g_TransportVehicle[i] == -1) continue;
        format(trPlate, sizeof(trPlate), "TRUCK %d", i + 1);
        SetVehicleNumberPlate(g_TransportVehicle[i], trPlate);
        SetVehicleToRespawn(g_TransportVehicle[i]);
    }
}

stock bool:Job_IsTransportVehicle(vehicleid)
{
    if(vehicleid <= 0) return false;
    for(new i = 0; i < MAX_TRANSPORT_VEHICLES; i++)
        if(g_TransportVehicle[i] == vehicleid) return true;
    return false;
}

// Creeaza vehiculele de lucru (2 Bobcat + 2 Burrito) la depou + decorul de la punctele de incarcare
stock Job_CreateEmergencyVehicles()
{
    g_EmergencyVehicle[0] = CreateVehicle(422, 1110.2723, -1225.3549, 15.8070, 180.6582, 18, 18, 600);
    g_EmergencyVehicle[1] = CreateVehicle(422, 1105.8149, -1225.3574, 15.8124, 180.8036, 18, 18, 600);
    g_EmergencyVehicle[2] = CreateVehicle(482, 1101.0980, -1225.5131, 15.9370, 180.2646, 18, 18, 600);
    g_EmergencyVehicle[3] = CreateVehicle(482, 1095.9619, -1225.5238, 15.9374, 181.5029, 18, 18, 600);

    new sosPlate[16];
    for(new i = 0; i < MAX_EMERGENCY_VEHICLES; i++)
    {
        if(g_EmergencyVehicle[i] == -1) continue;
        format(sosPlate, sizeof(sosPlate), "SOS %d", i + 1);
        SetVehicleNumberPlate(g_EmergencyVehicle[i], sosPlate);
        SetVehicleToRespawn(g_EmergencyVehicle[i]);
    }
}

stock bool:Job_IsEmergencyVehicle(vehicleid)
{
    if(vehicleid <= 0) return false;
    for(new i = 0; i < MAX_EMERGENCY_VEHICLES; i++)
        if(g_EmergencyVehicle[i] == vehicleid) return true;
    return false;
}

// Creeaza cele 4 autobuze de job la depou
stock Job_CreateBusVehicles()
{
    g_BusVehicle[0] = CreateVehicle(BUS_MODEL, 1411.4031, -2310.6638, 13.6462, 180.6553, 1, 1, 600);
    g_BusVehicle[1] = CreateVehicle(BUS_MODEL, 1404.6364, -2311.1135, 13.6465, 180.3654, 1, 1, 600);
    g_BusVehicle[2] = CreateVehicle(BUS_MODEL, 1441.4481, -2350.9551, 13.6543, 359.9575, 1, 1, 600);
    g_BusVehicle[3] = CreateVehicle(BUS_MODEL, 1451.2782, -2350.9165, 13.6521,   0.0014, 1, 1, 600);

    new busPlate[16];
    for(new i = 0; i < MAX_BUS_VEHICLES; i++)
    {
        if(g_BusVehicle[i] == -1) continue;
        format(busPlate, sizeof(busPlate), "BUS %d", i + 1);
        SetVehicleNumberPlate(g_BusVehicle[i], busPlate);
        SetVehicleToRespawn(g_BusVehicle[i]);
    }
}

stock bool:Bus_IsBusVehicle(vehicleid)
{
    if(vehicleid <= 0) return false;
    for(new i = 0; i < MAX_BUS_VEHICLES; i++)
        if(g_BusVehicle[i] == vehicleid) return true;
    return false;
}

// Pune checkpoint-ul curent (g_BusCP) al rutei active a playerului
stock Bus_SetCheckpoint(playerid)
{
    new line = g_BusLine[playerid] - 1;
    new cp   = g_BusCP[playerid];
    SetPlayerCheckpoint(playerid, g_BusRoute[line][cp][0], g_BusRoute[line][cp][1], g_BusRoute[line][cp][2], BUS_CP_SIZE);
}

// Incheie ruta de autobuz a playerului (curata starea + checkpoint-ul)
stock Bus_End(playerid)
{
    if(g_BusLine[playerid] == 0) return;
    g_BusLine[playerid] = 0;
    g_BusCP[playerid]   = 0;
    DisablePlayerCheckpoint(playerid);
}

// Apelat cand un pasager se urca intr-un autobuz de job: ii ia automat biletul (-100$ pasager, +100$ sofer)
stock Bus_PayFare(playerid)
{
    new veh = GetPlayerVehicleID(playerid);
    if(veh == 0 || !Bus_IsBusVehicle(veh)) return 0;

    new driver = INVALID_PLAYER_ID;
    for(new i = 0; i < MAX_PLAYERS; i++)
        if(IsPlayerConnected(i) && GetPlayerState(i) == PLAYER_STATE_DRIVER && GetPlayerVehicleID(i) == veh)
        {
            driver = i;
            break;
        }

    // fara sofer cu jobul de autobuz -> nu se taxeaza nimic (urcare libera)
    if(driver == INVALID_PLAYER_ID || driver == playerid || PlayerData[driver][pJob] != JOB_BUS) return 0;

    if(PlayerData[playerid][pMoney] < BUS_FARE)
        return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"[Bus] "C_WHITE"You don't have enough money for the ticket ("C_INFO"$100"C_WHITE")."), 0;

    PlayerData[playerid][pMoney] -= BUS_FARE;
    GivePlayerMoney(playerid, -BUS_FARE);
    UpdatePlayer(playerid, pMoney);

    PlayerData[driver][pMoney] += BUS_FARE;
    GivePlayerMoney(driver, BUS_FARE);
    UpdatePlayer(driver, pMoney);

    SendClientMessage(playerid, COLOR_SUCCESS, C_SUCCESS"[Bus] "C_WHITE"You paid a "C_INFO"$100"C_WHITE" bus ticket.");
    SendClientMessage(driver,   COLOR_SUCCESS, C_SUCCESS"[Bus] "C_WHITE"A passenger paid a "C_INFO"$100"C_WHITE" ticket.");
    return 1;
}

// ============================================================
//  RACE EVENTS - functii
// ============================================================
stock Race_VehIndex(model)
{
    for(new i = 0; i < RACE_VEH_COUNT; i++)
        if(g_RaceVehModels[i] == model) return i;
    return -1;
}

stock Races_Load()
{
    for(new l = 0; l < MAX_RACE_LAPS; l++)
        for(new v = 0; v < RACE_VEH_COUNT; v++)
        {
            g_RaceRecordTime[l][v]      = 999.0;
            g_RaceRecordHolder[l][v][0] = EOS;
            g_RaceRecordID[l][v]        = -1;
        }
    mysql_tquery(g_SQL, "SELECT `rID`,`rName`,`rVehModelID`,`rTimeRecord`,`rPlayerName` FROM `races`", "OnRacesLoaded");
}

public OnRacesLoaded()
{
    new rows = cache_num_rows();
    for(new i = 0; i < rows; i++)
    {
        new rname[16], model;
        cache_get_value_name(i, "rName", rname, sizeof(rname));
        cache_get_value_name_int(i, "rVehModelID", model);

        new l = -1;
        for(new k = 0; k < MAX_RACE_LAPS; k++)
            if(strcmp(rname, g_RaceLapName[k], true) == 0) { l = k; break; }
        new v = Race_VehIndex(model);
        if(l == -1 || v == -1) continue;

        cache_get_value_name_int  (i, "rID",         g_RaceRecordID[l][v]);
        cache_get_value_name_float(i, "rTimeRecord", g_RaceRecordTime[l][v]);
        cache_get_value_name      (i, "rPlayerName", g_RaceRecordHolder[l][v], 24);
    }
    printf("[Race] Recorduri incarcate (%d randuri).", rows);
    return 1;
}

// Pune race checkpoint-ul (cu sageata spre urmatorul) pentru statia cp de pe traseul lap
stock Race_SetCP(playerid, lap, cp)
{
    new count = g_RaceCPCount[lap];
    new type;
    new Float:nx, Float:ny, Float:nz;
    if(cp >= count - 1)
    {
        // ultima statie -> checkpoint de FINISH (steag)
        type = 1;
        nx = g_RaceRoute[lap][cp][0]; ny = g_RaceRoute[lap][cp][1]; nz = g_RaceRoute[lap][cp][2];
    }
    else
    {
        // statie normala -> sageata spre urmatoarea
        type = 0;
        nx = g_RaceRoute[lap][cp + 1][0]; ny = g_RaceRoute[lap][cp + 1][1]; nz = g_RaceRoute[lap][cp + 1][2];
    }
    SetPlayerRaceCheckpoint(playerid, type,
        g_RaceRoute[lap][cp][0], g_RaceRoute[lap][cp][1], g_RaceRoute[lap][cp][2],
        nx, ny, nz, RACE_CP_SIZE);
}

// Curata starea de cursa a unui jucator (vehicul + checkpoint), fara respawn
stock Race_ClearPlayer(playerid)
{
    if(g_RaceVehicle[playerid] != 0)
    {
        DestroyVehicle(g_RaceVehicle[playerid]);
        g_RaceVehicle[playerid] = 0;
    }
    DisablePlayerRaceCheckpoint(playerid);
    g_RaceIn[playerid]   = false;
    g_RaceDone[playerid] = false;
    g_RaceCP[playerid]   = 0;
}

// Incheie evenimentul: respawneaza participantii (daca era pornit) si reseteaza starea
stock Race_End(bool:forced)
{
    if(g_RaceState == RACE_STATE_NONE) return;
    new bool:wasRunning = (g_RaceState == RACE_STATE_RUNNING);

    if(g_RaceTimeoutTimer != -1)   { KillTimer(g_RaceTimeoutTimer);   g_RaceTimeoutTimer = -1; }
    if(g_RaceCountdownTimer != -1) { KillTimer(g_RaceCountdownTimer); g_RaceCountdownTimer = -1; }

    for(new i = 0; i < MAX_PLAYERS; i++)
    {
        if(!g_RaceIn[i]) continue;
        Race_ClearPlayer(i);
        if(wasRunning && IsPlayerConnected(i))
        {
            TogglePlayerControllable(i, 1);
            AC_SetVW(i, 0);
            AC_SetInterior(i, 0);
            SpawnPlayer(i);
        }
    }

    g_RaceState       = RACE_STATE_NONE;
    g_RaceLap         = 0;
    g_RaceVehModel    = -1;
    g_RaceFinishOrder = 0;
    g_RaceTotal       = 0;

    if(forced)
        SendClientMessageToAll(COLOR_INFO, C_INFO"[Race Event] "C_WHITE"The race event was stopped. Racers have been respawned.");
    else
        SendClientMessageToAll(COLOR_INFO, C_INFO"[Race Event] "C_WHITE"The race event has ended.");
}

public Race_Timeout()
{
    g_RaceTimeoutTimer = -1;
    if(g_RaceState == RACE_STATE_RUNNING)
        Race_End(true);
    return 1;
}

public Race_CountdownTick()
{
    g_RaceCountdownTimer = -1;
    if(g_RaceState != RACE_STATE_RUNNING) return 1;

    if(g_RaceCountdown > 0)
    {
        new txt[8];
        format(txt, sizeof(txt), "~r~%d", g_RaceCountdown);
        for(new i = 0; i < MAX_PLAYERS; i++)
            if(g_RaceIn[i] && IsPlayerConnected(i))
                GameTextForPlayer(i, txt, 1100, 4);
        g_RaceCountdown--;
        g_RaceCountdownTimer = SetTimer("Race_CountdownTick", 1000, false);
    }
    else
    {
        new tick = GetTickCount();
        for(new i = 0; i < MAX_PLAYERS; i++)
        {
            if(!g_RaceIn[i] || !IsPlayerConnected(i)) continue;
            GameTextForPlayer(i, "~g~GO~y~GO~g~GO!", 2000, 4);
            TogglePlayerControllable(i, 1);
            g_RaceStartTick[i] = tick;
        }
    }
    return 1;
}

// Returneaza job id-ul caruia ii apartine vehiculul de lucru (sau 0 daca nu e vehicul de job)
stock Job_VehicleRequiredJob(vehicleid)
{
    if(Job_IsGlovoVehicle(vehicleid))     return JOB_GLOVO;
    if(Job_IsCementVehicle(vehicleid))    return JOB_CEMENT;
    if(Job_IsGunVehicle(vehicleid))       return JOB_GUN;
    if(Job_IsTransportVehicle(vehicleid)) return JOB_TRANSPORT;
    if(Job_IsEmergencyVehicle(vehicleid)) return JOB_EMERGENCY;
    return 0;
}

// Alege un business random din lista (8/17/18) care exista. Returneaza false daca niciunul.
stock bool:Job_PickRandomTransportBiz(&Float:bx, &Float:by, &Float:bz)
{
    new valid[sizeof(g_TransportUnloadBiz)], count = 0;
    for(new i = 0; i < sizeof(g_TransportUnloadBiz); i++)
        if(Businesses_FindByID(g_TransportUnloadBiz[i]) != -1)
            valid[count++] = g_TransportUnloadBiz[i];
    if(count == 0) return false;
    new bidx = Businesses_FindByID(valid[random(count)]);
    bx = BusinessData[bidx][bLocX]; by = BusinessData[bidx][bLocY]; bz = BusinessData[bidx][bLocZ];
    return true;
}

// Alege HQ-ul exterior al unei mafii random (factiuni 4-7, cu HQ setat). Returneaza false daca niciuna.
stock bool:Job_PickRandomMafiaHQ(&Float:hx, &Float:hy, &Float:hz)
{
    new valid[MAFIA_FID_MAX - MAFIA_FID_MIN + 1], count = 0;
    for(new fid = MAFIA_FID_MIN; fid <= MAFIA_FID_MAX; fid++)
        if(FactionData[fid][fHQX] != 0.0 || FactionData[fid][fHQY] != 0.0)
            valid[count++] = fid;
    if(count == 0) return false;
    new pick = valid[random(count)];
    hx = FactionData[pick][fHQX]; hy = FactionData[pick][fHQY]; hz = FactionData[pick][fHQZ];
    return true;
}

// Alege aleatoriu o destinatie de descarcare arme: punctele fixe (g_GunUnload) + HQ-urile mafiilor 4-7
stock bool:Job_PickGunUnload(&Float:ux, &Float:uy, &Float:uz)
{
    new Float:list[sizeof(g_GunUnload) + (MAFIA_FID_MAX - MAFIA_FID_MIN + 1)][3], count = 0;

    for(new i = 0; i < sizeof(g_GunUnload); i++)
    {
        if(g_GunUnload[i][0] == 0.0 && g_GunUnload[i][1] == 0.0) continue;
        list[count][0] = g_GunUnload[i][0]; list[count][1] = g_GunUnload[i][1]; list[count][2] = g_GunUnload[i][2];
        count++;
    }
    for(new fid = MAFIA_FID_MIN; fid <= MAFIA_FID_MAX; fid++)
        if(FactionData[fid][fHQX] != 0.0 || FactionData[fid][fHQY] != 0.0)
        {
            list[count][0] = FactionData[fid][fHQX]; list[count][1] = FactionData[fid][fHQY]; list[count][2] = FactionData[fid][fHQZ];
            count++;
        }

    if(count == 0) return false;
    new r = random(count);
    ux = list[r][0]; uy = list[r][1]; uz = list[r][2];
    return true;
}

// Job Center - puncte separate pentru /getjob si /quitjob, in interiorul Cityhall (interior 3)
new Float:GETJOB_X  = 0.0;   // suprascris din locations_admin ("getjob")
new Float:GETJOB_Y  = 0.0;
new Float:GETJOB_Z  = 0.0;
new Float:QUITJOB_X = 0.0;   // suprascris din locations_admin ("quitjob")
new Float:QUITJOB_Y = 0.0;
new Float:QUITJOB_Z = 0.0;

stock JobCenter_Create()
{
    CreateDynamicPickup(1239, 1, GETJOB_X, GETJOB_Y, GETJOB_Z, 0, CITYHALL_INTERIOR);
    CreateDynamic3DTextLabel("[ Job Center ]\n[ /getjob ]", COLOR_WHITE,
        GETJOB_X, GETJOB_Y, GETJOB_Z - 0.5, 20.0,
        INVALID_PLAYER_ID, INVALID_VEHICLE_ID, 0, 0, CITYHALL_INTERIOR);

    CreateDynamicPickup(1239, 1, QUITJOB_X, QUITJOB_Y, QUITJOB_Z, 0, CITYHALL_INTERIOR);
    CreateDynamic3DTextLabel("[ Job Center ]\n[ /quitjob ]", COLOR_WHITE,
        QUITJOB_X, QUITJOB_Y, QUITJOB_Z - 0.5, 20.0,
        INVALID_PLAYER_ID, INVALID_VEHICLE_ID, 0, 0, CITYHALL_INTERIOR);
}

// Returneaza true daca playerul e la punctul de /getjob (interior 3, langa punct)
stock bool:Job_AtGetJob(playerid)
{
    if(GetPlayerInterior(playerid) != CITYHALL_INTERIOR) return false;
    return (IsPlayerInRangeOfPoint(playerid, 3.0, GETJOB_X, GETJOB_Y, GETJOB_Z) != 0);
}

// Returneaza true daca playerul e la punctul de /quitjob (interior 3, langa punct)
stock bool:Job_AtQuitJob(playerid)
{
    if(GetPlayerInterior(playerid) != CITYHALL_INTERIOR) return false;
    return (IsPlayerInRangeOfPoint(playerid, 3.0, QUITJOB_X, QUITJOB_Y, QUITJOB_Z) != 0);
}

// Cauta un job dupa nume (case-insensitive). Returneaza job id (1-based) sau -1.
stock Job_FindByName(const name[])
{
    for(new i = 0; i < MAX_JOBS; i++)
        if(strcmp(g_JobNames[i], name, true) == 0) return i + 1;
    return -1;
}

stock Float:Job_Dist2D(Float:x1, Float:y1, Float:x2, Float:y2)
{
    return floatsqroot((x2 - x1) * (x2 - x1) + (y2 - y1) * (y2 - y1));
}

// Alege o locatie valida de restaurant (pizza sau burger), sarind peste sloturile goale {0,0,0}
stock Job_PickRandomFood(&Float:fx, &Float:fy, &Float:fz)
{
    new Float:list[MAX_FOOD_LOCATIONS * 2][3], count = 0;
    for(new i = 0; i < MAX_FOOD_LOCATIONS; i++)
    {
        if(PizzaLocations[i][0] == 0.0 && PizzaLocations[i][1] == 0.0) continue;
        list[count][0] = PizzaLocations[i][0]; list[count][1] = PizzaLocations[i][1]; list[count][2] = PizzaLocations[i][2];
        count++;
    }
    for(new i = 0; i < MAX_FOOD_LOCATIONS; i++)
    {
        if(BurgerLocations[i][0] == 0.0 && BurgerLocations[i][1] == 0.0) continue;
        list[count][0] = BurgerLocations[i][0]; list[count][1] = BurgerLocations[i][1]; list[count][2] = BurgerLocations[i][2];
        count++;
    }
    if(count == 0) { fx = 0.0; fy = 0.0; fz = 0.0; return; }
    new r = random(count);
    fx = list[r][0]; fy = list[r][1]; fz = list[r][2];
}

// Etapa 1: checkpoint la sursa (restaurant pt Glovo / fabrica pt Ciment)
public Job_StartSource(playerid)
{
    new Float:x, Float:y, Float:z;
    switch(PlayerData[playerid][pJob])
    {
        case JOB_GLOVO:
        {
            Job_PickRandomFood(x, y, z);
            SendClientMessage(playerid, COLOR_INFO, C_INFO"[Glovo] "C_WHITE"Drive to the marked restaurant to pick up an order.");
        }
        case JOB_CEMENT:
        {
            new r = random(sizeof(g_CementLoad));
            x = g_CementLoad[r][0]; y = g_CementLoad[r][1]; z = g_CementLoad[r][2];
            SendClientMessage(playerid, COLOR_INFO, C_INFO"[Cement] "C_WHITE"Drive to the marked plant to load cement.");
        }
        case JOB_GUN:
        {
            new r = random(sizeof(g_GunLoad));
            x = g_GunLoad[r][0]; y = g_GunLoad[r][1]; z = g_GunLoad[r][2];
            SendClientMessage(playerid, COLOR_INFO, C_INFO"[Guns] "C_WHITE"Drive to the marked spot to load the weapons.");
        }
        case JOB_TRANSPORT:
        {
            new r = random(sizeof(g_TransportLoad));
            x = g_TransportLoad[r][0]; y = g_TransportLoad[r][1]; z = g_TransportLoad[r][2];
            SendClientMessage(playerid, COLOR_INFO, C_INFO"[Transport] "C_WHITE"Drive to the marked spot to load the vehicle.");
        }
        case JOB_EMERGENCY:
        {
            new r = random(sizeof(g_EmergencyLoad));
            x = g_EmergencyLoad[r][0]; y = g_EmergencyLoad[r][1]; z = g_EmergencyLoad[r][2];
            SendClientMessage(playerid, COLOR_INFO, C_INFO"[Logistics] "C_WHITE"Drive to the marked depot to load the medical supplies.");
        }
        default: return;
    }
    g_JobPickupX[playerid]    = x;
    g_JobPickupY[playerid]    = y;
    g_JobStage[playerid]      = JOB_STAGE_PICKUP;
    g_JobUnloadsDone[playerid] = 0; // ciclu nou: 0 descarcari facute
    SetPlayerCheckpoint(playerid, x, y, z, JOB_CP_SIZE);
}

// Etapa 2: checkpoint la destinatie (casa pt Glovo / santier pt Ciment) + calcul plata (sursa -> destinatie)
public Job_StartDest(playerid)
{
    new Float:x, Float:y, Float:z;
    switch(PlayerData[playerid][pJob])
    {
        case JOB_GLOVO:
        {
            if(g_HouseCount <= 0)
            {
                SendClientMessage(playerid, COLOR_ERROR, C_ERROR"[Glovo] "C_WHITE"No delivery address available right now.");
                Job_StartSource(playerid);
                return;
            }
            new hidx = random(g_HouseCount);
            x = HouseData[hidx][hLocX]; y = HouseData[hidx][hLocY]; z = HouseData[hidx][hLocZ];
            SendClientMessage(playerid, COLOR_INFO, C_INFO"[Glovo] "C_WHITE"Order picked up. Deliver it to the marked house.");
        }
        case JOB_CEMENT:
        {
            new r = random(sizeof(g_CementUnload));
            x = g_CementUnload[r][0]; y = g_CementUnload[r][1]; z = g_CementUnload[r][2];
            SendClientMessage(playerid, COLOR_INFO, C_INFO"[Cement] "C_WHITE"Cement loaded. Drive to the marked site to unload.");
        }
        case JOB_GUN:
        {
            new Float:mx, Float:my, Float:mz;
            if(!Job_PickGunUnload(mx, my, mz))
            {
                SendClientMessage(playerid, COLOR_ERROR, C_ERROR"[Guns] "C_WHITE"No drop-off is available to deliver to right now.");
                Job_StartSource(playerid);
                return;
            }
            x = mx; y = my; z = mz;
            SendClientMessage(playerid, COLOR_INFO, C_INFO"[Guns] "C_WHITE"Weapons loaded. Deliver them to the marked drop-off.");
        }
        case JOB_TRANSPORT:
        {
            new Float:bx, Float:by, Float:bz;
            if(!Job_PickRandomTransportBiz(bx, by, bz))
            {
                SendClientMessage(playerid, COLOR_ERROR, C_ERROR"[Transport] "C_WHITE"No drop-off business is available right now.");
                Job_StartSource(playerid);
                return;
            }
            x = bx; y = by; z = bz;
            SendClientMessage(playerid, COLOR_INFO, C_INFO"[Transport] "C_WHITE"Vehicle loaded. Drive to the marked business to unload.");
        }
        case JOB_EMERGENCY:
        {
            if(g_ShopCount == 0)
            {
                SendClientMessage(playerid, COLOR_ERROR, C_ERROR"[Logistics] "C_WHITE"No shop is available right now.");
                Job_StartSource(playerid);
                return;
            }
            new r = random(g_ShopCount);
            x = ShopData[r][shopX]; y = ShopData[r][shopY]; z = ShopData[r][shopZ];
            SendClientMessage(playerid, COLOR_INFO, C_INFO"[Logistics] "C_WHITE"Supplies loaded. Deliver them to the marked shop.");
        }
        default: return;
    }
    new Float:dist = Job_Dist2D(g_JobPickupX[playerid], g_JobPickupY[playerid], x, y);
    switch(PlayerData[playerid][pJob])
    {
        case JOB_GLOVO:     g_JobPay[playerid] = JOB_GLOVO_BASE_PAY     + floatround(JOB_GLOVO_PAY_PER_M     * dist);
        case JOB_CEMENT:    g_JobPay[playerid] = JOB_CEMENT_BASE_PAY    + floatround(JOB_CEMENT_PAY_PER_M    * dist);
        case JOB_GUN:       g_JobPay[playerid] = JOB_GUN_BASE_PAY       + floatround(JOB_GUN_PAY_PER_M       * dist);
        case JOB_TRANSPORT: g_JobPay[playerid] = JOB_TRANSPORT_BASE_PAY + floatround(JOB_TRANSPORT_PAY_PER_M * dist);
        case JOB_EMERGENCY: g_JobPay[playerid] = JOB_EMERGENCY_BASE_PAY + floatround(JOB_EMERGENCY_PAY_PER_M * dist);
    }
    g_JobStage[playerid] = JOB_STAGE_DELIVER;
    SetPlayerCheckpoint(playerid, x, y, z, JOB_CP_SIZE);
}

// Plateste livrarea curenta + cota de business (daca jobul are una)
public Job_PayDelivery(playerid)
{
    new pay = g_JobPay[playerid];
    PlayerData[playerid][pMoney] += pay;
    GivePlayerMoney(playerid, pay);
    UpdatePlayer(playerid, pMoney);

    if(PlayerData[playerid][pJob] == JOB_GLOVO)
        Job_AddBizIncome(JOB_GLOVO_BIZ_ID, JOB_GLOVO_BIZ_CUT);

    new dmsg[128];
    format(dmsg, sizeof(dmsg), C_SUCCESS"[Job] "C_WHITE"Delivery complete! You earned "C_INFO"$%s"C_WHITE".", MoneyStr(pay));
    SendClientMessage(playerid, COLOR_SUCCESS, dmsg);
}

// Trimite o cota catre un business si o persista
public Job_AddBizIncome(bizId, amount)
{
    new bidx = Businesses_FindByID(bizId);
    if(bidx == -1) return;

    BusinessData[bidx][bBank] += amount;

    new q[128];
    mysql_format(g_SQL, q, sizeof(q), "UPDATE `businesses` SET `bank`=%d WHERE `id`=%d",
        BusinessData[bidx][bBank], BusinessData[bidx][bID]);
    mysql_tquery(g_SQL, q, "", "", 0);
}

// Porneste munca pentru jobul curent (trebuie sa fii la volanul vehiculului corect de job)
stock Job_StartWork(playerid)
{
    if(g_IsWorking[playerid])
    {
        SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You are already working. Use "C_INFO"/stopwork"C_WHITE" to stop.");
        return;
    }

    new veh = GetPlayerVehicleID(playerid);
    if(GetPlayerState(playerid) != PLAYER_STATE_DRIVER || Job_VehicleRequiredJob(veh) != PlayerData[playerid][pJob])
    {
        SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be driving a work vehicle for your job (see "C_INFO"/joblist"C_WHITE").");
        return;
    }

    g_IsWorking[playerid]      = true;
    g_JobVehicle[playerid]     = veh;
    g_JobReturnTimer[playerid] = -1;

    SendClientMessage(playerid, COLOR_SUCCESS, C_SUCCESS"[Job] "C_WHITE"You started working! Follow the checkpoints. Use "C_INFO"/stopwork"C_WHITE" to stop.");
    Job_StartSource(playerid);
}

// Opreste munca: reseteaza starea, checkpoint-ul si timer-ul (fara mesaj - apelantul anunta)
stock Job_StopWork(playerid)
{
    if(!g_IsWorking[playerid]) return;
    g_IsWorking[playerid]   = false;
    g_JobStage[playerid]    = JOB_STAGE_NONE;
    g_JobVehicle[playerid]  = INVALID_VEHICLE_ID;
    DisablePlayerCheckpoint(playerid);
    if(g_JobReturnTimer[playerid] != -1)
    {
        KillTimer(g_JobReturnTimer[playerid]);
        g_JobReturnTimer[playerid] = -1;
    }
}

// Timer: scoate freeze-ul de 2s aplicat la atingerea unui checkpoint de livrare
public Job_Unfreeze(playerid)
{
    if(IsPlayerConnected(playerid))
        TogglePlayerControllable(playerid, 1);
    return 1;
}

// Timer: a expirat ragazul de 30s de revenire in masina de lucru
public Job_ReturnTimeout(playerid)
{
    g_JobReturnTimer[playerid] = -1;
    if(!g_IsWorking[playerid]) return 1;

    // Daca intre timp a revenit in masina de lucru, nu opri
    if(GetPlayerState(playerid) == PLAYER_STATE_DRIVER && GetPlayerVehicleID(playerid) == g_JobVehicle[playerid])
        return 1;

    Job_StopWork(playerid);
    SendClientMessage(playerid, COLOR_ERROR, C_ERROR"[Job] "C_WHITE"You didn't return to your work vehicle in time. Work stopped.");
    return 1;
}

// Apelat din OnPlayerStateChange cand starea/vehiculul jucatorului care lucreaza se schimba
stock Job_HandleStateChange(playerid)
{
    if(!g_IsWorking[playerid]) return;

    new bool:inWorkVeh = (GetPlayerState(playerid) == PLAYER_STATE_DRIVER &&
                          GetPlayerVehicleID(playerid) == g_JobVehicle[playerid]);

    if(inWorkVeh)
    {
        if(g_JobReturnTimer[playerid] != -1)
        {
            KillTimer(g_JobReturnTimer[playerid]);
            g_JobReturnTimer[playerid] = -1;
            SendClientMessage(playerid, COLOR_SUCCESS, C_SUCCESS"[Job] "C_WHITE"Welcome back. Keep working!");
        }
    }
    else
    {
        if(g_JobReturnTimer[playerid] == -1)
        {
            g_JobReturnTimer[playerid] = SetTimerEx("Job_ReturnTimeout", JOB_RETURN_GRACE * 1000, false, "i", playerid);
            new wmsg[144];
            format(wmsg, sizeof(wmsg), C_ERROR"[Job] "C_WHITE"You left your work vehicle. Return within "C_INFO"%d seconds"C_WHITE" or work stops.", JOB_RETURN_GRACE);
            SendClientMessage(playerid, COLOR_ERROR, wmsg);
        }
    }
}

// ============================================================
//  JOB 5 - UBER - functii
// ============================================================
// Reseteaza legatura pasager<->sofer + opreste taxarea (fara mesaje - apelantul anunta).
// Daca ride-ul nu incepuse inca, scoate si checkpoint-ul soferului.
stock Uber_ClearAssignment(passenger)
{
    new driver = g_UberDriver[passenger];

    if(g_UberChargeTimer[passenger] != -1)
    {
        KillTimer(g_UberChargeTimer[passenger]);
        g_UberChargeTimer[passenger] = -1;
    }
    g_UberRideActive[passenger] = false;
    g_UberDriver[passenger]     = INVALID_PLAYER_ID;

    if(driver != INVALID_PLAYER_ID && IsPlayerConnected(driver) && g_UberPassenger[driver] == passenger)
    {
        g_UberPassenger[driver] = INVALID_PLAYER_ID;
        DisablePlayerCheckpoint(driver);
    }
}

// Scoate un sofer din serviciul de uber (si incheie cursa curenta daca exista)
stock Uber_GoOffDuty(driver)
{
    if(!g_UberOnDuty[driver]) return;

    new passenger = g_UberPassenger[driver];
    if(passenger != INVALID_PLAYER_ID && IsPlayerConnected(passenger))
    {
        Uber_ClearAssignment(passenger);
        SendClientMessage(passenger, COLOR_ERROR, C_ERROR"[Uber] "C_WHITE"Your driver went off duty. Ride cancelled.");
    }

    g_UberOnDuty[driver]    = false;
    g_UberVehicle[driver]   = INVALID_VEHICLE_ID;
    g_UberPassenger[driver] = INVALID_PLAYER_ID;
}

// Timer: taxeaza pasagerul la fiecare UBER_CHARGE_INTERVAL secunde
public Uber_Charge(passenger)
{
    if(!g_UberRideActive[passenger])
    {
        if(g_UberChargeTimer[passenger] != -1) { KillTimer(g_UberChargeTimer[passenger]); g_UberChargeTimer[passenger] = -1; }
        return 1;
    }

    new driver = g_UberDriver[passenger];
    if(driver == INVALID_PLAYER_ID || !IsPlayerConnected(driver))
    {
        Uber_ClearAssignment(passenger);
        SendClientMessage(passenger, COLOR_ERROR, C_ERROR"[Uber] "C_WHITE"Your driver is no longer available. Ride ended.");
        return 1;
    }

    new fare = g_UberFare[driver];
    if(PlayerData[passenger][pMoney] < fare)
    {
        Uber_ClearAssignment(passenger);
        SendClientMessage(passenger, COLOR_ERROR, C_ERROR"[Uber] "C_WHITE"You ran out of money. Ride ended.");
        SendClientMessage(driver,    COLOR_ERROR, C_ERROR"[Uber] "C_WHITE"Your passenger ran out of money. Ride ended.");
        return 1;
    }

    PlayerData[passenger][pMoney] -= fare;
    GivePlayerMoney(passenger, -fare);
    UpdatePlayer(passenger, pMoney);

    PlayerData[driver][pMoney] += fare;
    GivePlayerMoney(driver, fare);
    UpdatePlayer(driver, pMoney);

    new cmsg[128];
    format(cmsg, sizeof(cmsg), C_INFO"[Uber] "C_WHITE"Fare charged: "C_INFO"$%s"C_WHITE".", MoneyStr(fare));
    SendClientMessage(passenger, COLOR_INFO, cmsg);
    format(cmsg, sizeof(cmsg), C_SUCCESS"[Uber] "C_WHITE"Fare received: "C_INFO"$%s"C_WHITE".", MoneyStr(fare));
    SendClientMessage(driver, COLOR_SUCCESS, cmsg);
    return 1;
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

        AC_SetPos(i, GolfTeeLocations[holeIdx][0], GolfTeeLocations[holeIdx][1], GolfTeeLocations[holeIdx][2] + 0.5);
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
#define BBALL_MIN_PLAYERS       1     // TODO: de schimbat limita de playeri la basket
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
#define BBALL_ICON_SLOT         9     // slot liber intre factiuni (1-8) si business-uri (10-59); mutat din 86 (era in zona shop-urilor)
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

new STREAMER_TAG_3D_TEXT_LABEL:g_BBallHoopLabel[BBALL_MAX_HOOPS]; // etichete globale (vizibile tuturor la teren)

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
    BBall_CreateHoopLabels(); // etichete globale la coșuri, dupa ce coordonatele sunt incarcate
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

// Creeaza etichetele 3D "[ #1 ]".."[ #8 ]" la fiecare cos, globale (vizibile tuturor). Apelat dupa incarcarea cosurilor.
stock BBall_CreateHoopLabels()
{
    new text[16];
    for(new h = 0; h < BBALL_MAX_HOOPS; h++)
    {
        if(IsValidDynamic3DTextLabel(g_BBallHoopLabel[h]))
            DestroyDynamic3DTextLabel(g_BBallHoopLabel[h]);
        if(BBallHoopData[h][0] == 0.0 && BBallHoopData[h][1] == 0.0) continue; // cos nesetat
        format(text, sizeof(text), "[ #%d ]", h + 1);
        g_BBallHoopLabel[h] = CreateDynamic3DTextLabel(text, COLOR_WHITE,
            BBallHoopData[h][0], BBallHoopData[h][1], BBallHoopData[h][2] - 0.3, 50.0);
    }
}

// Cauta locatia "Basket" in locations_admin si creeaza pickup-ul + 3D textul + map icon-ul
stock BBall_FindLobby()
{
    new idx = Locations_FindByName("Basket");
    if(idx == -1)
    {
        print("[Basketball] Locatia 'Basket' nu a fost gasita in locations_admin.");
        return;
    }

    g_BBallLobbyX = LocationData[idx][locX];
    g_BBallLobbyY = LocationData[idx][locY];
    g_BBallLobbyZ = LocationData[idx][locZ];
    g_BBallLobbyFound = true;

    BBall_CreateLobby();

    // reaplica map icon-ul pentru jucatorii deja conectati (locatia se stie abia dupa incarcarea DB)
    for(new i = 0; i < MAX_PLAYERS; i++)
        if(IsPlayerConnected(i) && PlayerData[i][pLogged])
            BBall_SetPlayerIcon(i);
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
        g_BBallLobbyLabel = Create3DTextLabel(text, COLOR_WHITE, g_BBallLobbyX, g_BBallLobbyY, g_BBallLobbyZ + 0.5, 25.0, 0, 0);
    else
        Update3DTextLabelText(g_BBallLobbyLabel, COLOR_WHITE, text);
}

// Map icon local (vizibil doar pentru acest player) la locatia /joinbasket
stock BBall_SetPlayerIcon(playerid)
{
    if(!g_BBallLobbyFound) return;
    SetPlayerMapIcon(playerid, BBALL_ICON_SLOT, g_BBallLobbyX, g_BBallLobbyY, g_BBallLobbyZ, BBALL_MAPICON_ID, 0, MAPICON_GLOBAL);
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

    AC_SetPos(playerid, sx, sy, sz);
    AC_SetVW(playerid, 0);

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
            if(PlayerData[ownerPlayerid][pHouse] != 0 && Houses_FindByID(PlayerData[ownerPlayerid][pHouse]) != -1)
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
// Puncte de tranzitie Politie (faction 1), suprascrise din locations_admin dupa nume:
//  point 20 "police_garage_to_int" (garaj -> interior), point 19 "police_int_to_garage" (interior -> garaj),
//  point 18 "police_int_to_ext" (interior -> strada). Destinatia interior->strada = HQ-ul exterior al factiunii 1.
new Float:POLICE_GARAGE_X   = 0.0;  // point 20: garaj (exterior) - suprascris din locations_admin ("police_garage_to_int")
new Float:POLICE_GARAGE_Y   = 0.0;
new Float:POLICE_GARAGE_Z   = 0.0;
new POLICE_GARAGE_INT       = 0;
new Float:POLICE_ENTRANCE_X = 0.0;   // point 19: interior LSPD, duce la garaj - suprascris ("police_int_to_garage")
new Float:POLICE_ENTRANCE_Y = 0.0;
new Float:POLICE_ENTRANCE_Z = 0.0;
new POLICE_ENTRANCE_INT     = 6;
new Float:POLICE_EXIT_X     = 0.0;   // point 18: interior LSPD, duce la strada - suprascris ("police_int_to_ext")
new Float:POLICE_EXIT_Y     = 0.0;
new Float:POLICE_EXIT_Z     = 0.0;
new Float:LSPD_BARRIER_X = 0.0;    // bariera LSPD - suprascris din locations_admin ("lspd_barrier")
new Float:LSPD_BARRIER_Y = 0.0;
new Float:LSPD_BARRIER_Z = 0.0;
#define POLICE_TP_RANGE     2.0

// Teleporteaza playerul (doar pe jos) la coordonatele date, in interiorul dat
stock Police_TeleportTo(playerid, Float:x, Float:y, Float:z, interiorid = 0)
{
    AC_SetPos(playerid, x, y, z);
    AC_SetInterior(playerid, interiorid);
}

// Daca playerul e in raza garajului sau a intrarii, il teleporteaza la celalalt punct.
// Returneaza true daca a fost teleportat, false daca nu era in raza niciunui punct.
stock bool:Police_GarageEntranceToggle(playerid)
{
    if(GetPlayerVehicleID(playerid) != 0) return false; // doar pe jos, nu in vehicul

    // Garaj -> interior (point 20 -> point 19)
    if(IsPlayerInRangeOfPoint(playerid, POLICE_TP_RANGE, POLICE_GARAGE_X, POLICE_GARAGE_Y, POLICE_GARAGE_Z))
    {
        Police_TeleportTo(playerid, POLICE_ENTRANCE_X, POLICE_ENTRANCE_Y, POLICE_ENTRANCE_Z, POLICE_ENTRANCE_INT);
        return true;
    }
    // Interior -> garaj (point 19 -> point 20)
    if(IsPlayerInRangeOfPoint(playerid, POLICE_TP_RANGE, POLICE_ENTRANCE_X, POLICE_ENTRANCE_Y, POLICE_ENTRANCE_Z))
    {
        Police_TeleportTo(playerid, POLICE_GARAGE_X, POLICE_GARAGE_Y, POLICE_GARAGE_Z, POLICE_GARAGE_INT);
        return true;
    }
    // Interior -> strada (point 18 -> HQ-ul exterior al factiunii 1)
    if(IsPlayerInRangeOfPoint(playerid, POLICE_TP_RANGE, POLICE_EXIT_X, POLICE_EXIT_Y, POLICE_EXIT_Z))
    {
        Police_TeleportTo(playerid, FactionData[FACTION_POLICE][fHQX], FactionData[FACTION_POLICE][fHQY], FactionData[FACTION_POLICE][fHQZ], 0);
        return true;
    }
    return false;
}

// ============================================================
//  ARREST & INCHISOARE
// ============================================================
#define ARREST_ZONE_RANGE     6.0   // cat de aproape de zona de arest trebuie sa fie politistul
#define ARREST_SUSPECT_RANGE  4.0    // cat de aproape de politist trebuie sa fie inculpatul
// zona 1 = interior LSPD ("PR/arrest-int"), zona 2 = exterior/garaj ("PR/arrest-ext"). Ambele din locations_admin.
new Float:ARREST_ZONE_X = 0.0;
new Float:ARREST_ZONE_Y = 0.0;
new Float:ARREST_ZONE_Z = 0.0;
new Float:ARREST_ZONE2_X = 0.0;
new Float:ARREST_ZONE2_Y = 0.0;
new Float:ARREST_ZONE2_Z = 0.0;

new Float:JAIL_X = 0.0;              // celula de inchisoare ("jail" din locations_admin)
new Float:JAIL_Y = 0.0;
new Float:JAIL_Z = 0.0;
new JAIL_INTERIOR = 0;
new JAIL_VW = 0;

// punctul unde politistii (factiunea 1) dau /duty ("PR/duty" din locations_admin)
#define DUTY_LOC_RANGE  5.0
new Float:DUTY_LOC_X = 0.0;
new Float:DUTY_LOC_Y = 0.0;
new Float:DUTY_LOC_Z = 0.0;
new DUTY_LOC_INT = 0;
new DUTY_LOC_VW = 0;
// punct de eliberare (dupa ce si-a ispasit pedeapsa)
#define JAIL_RELEASE_X  855.5033
#define JAIL_RELEASE_Y  -2073.2300
#define JAIL_RELEASE_Z  17.3279

// durata (minute) si amenda ($) dupa wanted level; index 1-6 (0 nefolosit)
new const g_JailMinutes[7] = {0, 2, 4, 7, 11, 15, 20};
new const g_JailFine[7]    = {0, 1000, 2000, 3500, 5000, 7500, 10000};

forward Jail_Tick();

// Teleporteaza inculpatul in celula (daca e configurata)
stock Jail_Send(playerid)
{
    if(JAIL_X != 0.0 || JAIL_Y != 0.0)
    {
        AC_SetPos(playerid, JAIL_X, JAIL_Y, JAIL_Z);
        AC_SetInterior(playerid, JAIL_INTERIOR);
        AC_SetVW(playerid, JAIL_VW);
    }
    SetPlayerHealth(playerid, 100.0);
}

// Elibereaza inculpatul: reseteaza timpul, il scoate din celula
stock Jail_Release(playerid)
{
    PlayerData[playerid][pJailSeconds] = 0;
    UpdatePlayer(playerid, pJailSeconds);
    AC_SetInterior(playerid, 0);
    AC_SetVW(playerid, 0);
    AC_SetPos(playerid, JAIL_RELEASE_X, JAIL_RELEASE_Y, JAIL_RELEASE_Z);
    SetPlayerHealth(playerid, 100.0);
    SendClientMessage(playerid, COLOR_SUCCESS, C_SUCCESS"[P.R.] "C_WHITE"You have served your sentence. You are free to go.");
}

// Ruleaza o data pe secunda: scade timpul de inchisoare si elibereaza la 0
public Jail_Tick()
{
    for(new i = 0; i < MAX_PLAYERS; i++)
    {
        if(!IsPlayerConnected(i) || !PlayerData[i][pLogged]) continue;
        if(PlayerData[i][pJailSeconds] <= 0) continue;
        PlayerData[i][pJailSeconds]--;
        if(PlayerData[i][pJailSeconds] <= 0)
        {
            PlayerData[i][pJailSeconds] = 0;
            Jail_Release(i);
        }
    }
    return 1;
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

// Vehicule personale - declarate aici (inainte de Speedometer) ca PVehicleData sa fie
// accesibil in Speedometer_Tick (afisare + consum motorina). Definitiile aferente sunt in sectiunea "VEHICULE PERSONALE".
#define MAX_PERSONAL_VEHICLES   200
enum E_PVEHICLE_DATA
{
    pvID, pvOwnerId, pvModelID,
    pvColor1, pvColor2, pvPlate[16], pvPrice,
    Float:pvLocX, Float:pvLocY, Float:pvLocZ, Float:pvRotation,
    pvInsuranceExp, pvMedkitExp, pvExtinguisherExp, pvITPExp,
    bool:pvLocked,
    pvFirstReg,  // data primei inmatriculari (unix; 0 = neinmatriculata inca)
    pvFromBiz,   // business-ul de la care a fost cumparata
    Float:pvFuel, // nivelul de motorina (0.0 - 100.0)
    bool:pvIsConfiscated // 1 = confiscat/tractat de R.A.R. (motorul nu porneste pana la /redeemcar)
}
new PVehicleData[MAX_PERSONAL_VEHICLES][E_PVEHICLE_DATA];
new g_PVehicleVehicle[MAX_PERSONAL_VEHICLES];
new Text3D:g_PVehicleLabel[MAX_PERSONAL_VEHICLES];
new g_PVehicleCount = 0;

// ============================================================
//  SPEEDOMETER (viteza / HP / lock)
// ============================================================
#define SPEEDOMETER_TICK 200 // 0.2 secunde, in ms

// --- Motorina (fuel), doar la vehiculele personale ---
#define FUEL_MAX             100.0
#define FUEL_IDLE_DRAIN      0.003   // %/tick cat motorul e pornit dar masina e stationata (tick 200ms)
#define FUEL_MOVE_DRAIN      0.00015 // %/tick per km/h cat conduce
#define FUEL_PRICE_PER_PCT   5       // $ pentru fiecare 1% realimentat la /refuel
#define FUEL_STATION_RANGE   6.0     // raza de folosire a unei benzinarii
#define MAX_FUEL_STATIONS    6
#define FUEL_STATION_PICKUP_MODEL 1650 // canistra de benzina

new PlayerText:Speedometer_Text[MAX_PLAYERS][5];
new bool:g_SpeedometerShown[MAX_PLAYERS];
new bool:g_SpeedometerLockShown[MAX_PLAYERS]; // textdraw-ul de lock/unlock apare doar la masinile personale

forward Speedometer_Tick();

// Creeaza cele 3 textdraw-uri (viteza/HP/lock) pentru un player, ascunse initial
stock Speedometer_Create(playerid)
{
    Speedometer_Text[playerid][0] = CreatePlayerTextDraw(playerid, 607.000, 388.000, "999 km/h");
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

    Speedometer_Text[playerid][1] = CreatePlayerTextDraw(playerid, 607.000, 400.000, "Fuel: 100%");
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

    Speedometer_Text[playerid][2] = CreatePlayerTextDraw(playerid, 607.000, 412.000, "9999 hp");
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

    Speedometer_Text[playerid][3] = CreatePlayerTextDraw(playerid, 607.000, 424.000, "Engine ON/OFF");
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

    Speedometer_Text[playerid][4] = CreatePlayerTextDraw(playerid, 607.000, 436.000, "unlocked");
    PlayerTextDrawLetterSize(playerid, Speedometer_Text[playerid][4], 0.160, 0.999);
    PlayerTextDrawTextSize(playerid, Speedometer_Text[playerid][4], 50.000, 58.000);
    PlayerTextDrawAlignment(playerid, Speedometer_Text[playerid][4], 2);
    PlayerTextDrawColor(playerid, Speedometer_Text[playerid][4], 255);
    PlayerTextDrawUseBox(playerid, Speedometer_Text[playerid][4], 1);
    PlayerTextDrawBoxColor(playerid, Speedometer_Text[playerid][4], -757935537);
    PlayerTextDrawSetShadow(playerid, Speedometer_Text[playerid][4], 0);
    PlayerTextDrawSetOutline(playerid, Speedometer_Text[playerid][4], 0);
    PlayerTextDrawBackgroundColor(playerid, Speedometer_Text[playerid][4], 255);
    PlayerTextDrawFont(playerid, Speedometer_Text[playerid][4], 1);
    PlayerTextDrawSetProportional(playerid, Speedometer_Text[playerid][4], 1);

    g_SpeedometerShown[playerid] = false;
    g_SpeedometerLockShown[playerid] = false;
}

stock Speedometer_Destroy(playerid)
{
    for(new i = 0; i < 5; i++)
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
                PlayerTextDrawHide(i, Speedometer_Text[i][4]);
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

        new bool:isPersonal = (g_VehicleToPVIndex[vehid] != -1);

        // --- Vehicul confiscat de R.A.R.: motorul ramane oprit ---
        if(isPersonal && engine && PVehicleData[g_VehicleToPVIndex[vehid]][pvIsConfiscated])
        {
            SetVehicleParamsEx(vehid, 0, lights, alarm, doors, bonnet, boot, objective);
            engine = 0;
        }

        // --- Consum motorina: orice sofer cu motorul pornit ---
        if(engine && GetPlayerState(i) == PLAYER_STATE_DRIVER)
        {
            new Float:drain = FUEL_IDLE_DRAIN + FUEL_MOVE_DRAIN * speed;
            g_VehicleFuel[vehid] -= drain;

            if(g_VehicleFuel[vehid] <= 0.0)
            {
                g_VehicleFuel[vehid] = 0.0;
                // ramas fara motorina -> opreste motorul
                SetVehicleParamsEx(vehid, 0, lights, alarm, doors, bonnet, boot, objective);
                engine = 0;
                Vehicle_SaveFuel(vehid);
                SendClientMessage(i, COLOR_ERROR, C_ERROR"[Fuel] "C_WHITE"You ran out of fuel. Refuel at a gas station ("C_INFO"/refuel"C_WHITE").");
            }
        }

        new text[16];
        format(text, sizeof(text), "%d km/h", floatround(speed));
        PlayerTextDrawSetString(i, Speedometer_Text[i][0], text);

        format(text, sizeof(text), "Fuel: %d%%", floatround(g_VehicleFuel[vehid]));
        PlayerTextDrawSetString(i, Speedometer_Text[i][1], text);

        format(text, sizeof(text), "%d hp", floatround(health));
        PlayerTextDrawSetString(i, Speedometer_Text[i][2], text);

        PlayerTextDrawSetString(i, Speedometer_Text[i][3], engine ? "engine ON" : "engine OFF");

        if(isPersonal)
        {
            PlayerTextDrawSetString(i, Speedometer_Text[i][4], doors ? "locked" : "unlocked");
            if(!g_SpeedometerLockShown[i])
            {
                PlayerTextDrawShow(i, Speedometer_Text[i][4]);
                g_SpeedometerLockShown[i] = true;
            }
        }
        else if(g_SpeedometerLockShown[i])
        {
            PlayerTextDrawHide(i, Speedometer_Text[i][4]);
            g_SpeedometerLockShown[i] = false;
        }

        if(!g_SpeedometerShown[i])
        {
            PlayerTextDrawShow(i, Speedometer_Text[i][0]);
            PlayerTextDrawShow(i, Speedometer_Text[i][1]);
            PlayerTextDrawShow(i, Speedometer_Text[i][2]);
            PlayerTextDrawShow(i, Speedometer_Text[i][3]);
            g_SpeedometerShown[i] = true;
        }
    }
    return 1;
}

// Returneaza indexul (in VFactionData) al vehiculului de factiune cu acest vehicleid, sau -1
stock VFaction_FindByVehicle(vehicleid)
{
    if(vehicleid <= 0) return -1;
    for(new i = 0; i < g_VFactionCount; i++)
        if(g_VFactionVehicle[i] == vehicleid) return i;
    return -1;
}

// Salveaza motorina in DB daca vehiculul e din DB (personal sau factiune); altfel nu face nimic
stock Vehicle_SaveFuel(vehicleid)
{
    if(vehicleid <= 0 || vehicleid >= MAX_VEHICLES) return;

    new pvidx = g_VehicleToPVIndex[vehicleid];
    if(pvidx != -1)
    {
        PVehicleData[pvidx][pvFuel] = g_VehicleFuel[vehicleid];
        new q[96];
        mysql_format(g_SQL, q, sizeof(q), "UPDATE `vehicles_personal` SET `fuel`=%.2f WHERE `id`=%d",
            g_VehicleFuel[vehicleid], PVehicleData[pvidx][pvID]);
        mysql_tquery(g_SQL, q, "", "", 0);
        return;
    }

    new vfidx = VFaction_FindByVehicle(vehicleid);
    if(vfidx != -1)
    {
        VFactionData[vfidx][vfFuel] = g_VehicleFuel[vehicleid];
        new q[96];
        mysql_format(g_SQL, q, sizeof(q), "UPDATE `vehicles_faction` SET `fuel`=%.2f WHERE `id`=%d",
            g_VehicleFuel[vehicleid], VFactionData[vfidx][vfID]);
        mysql_tquery(g_SQL, q, "", "", 0);
    }
}

// Benzinarii (pozitii fixe). Pozitiile 0.0 sunt ignorate.
new const Float:g_FuelStations[MAX_FUEL_STATIONS][3] = {
    {1004.0121, -937.5402,  42.3281}, // peco1
    {1942.3754, -1772.9906, 13.6406}, // peco2
    {0.0, 0.0, 0.0},
    {0.0, 0.0, 0.0},
    {0.0, 0.0, 0.0},
    {0.0, 0.0, 0.0}
};

stock Fuel_CreateStations()
{
    for(new i = 0; i < MAX_FUEL_STATIONS; i++)
    {
        if(g_FuelStations[i][0] == 0.0 && g_FuelStations[i][1] == 0.0) continue;
        CreatePickup(FUEL_STATION_PICKUP_MODEL, 1, g_FuelStations[i][0], g_FuelStations[i][1], g_FuelStations[i][2], -1);
        Create3DTextLabel("[ Gas Station ]\n[ /refuel ]", COLOR_WHITE,
            g_FuelStations[i][0], g_FuelStations[i][1], g_FuelStations[i][2] + 0.4, 20.0, 0, 0);
    }
}

stock bool:Fuel_PlayerAtStation(playerid)
{
    for(new i = 0; i < MAX_FUEL_STATIONS; i++)
    {
        if(g_FuelStations[i][0] == 0.0 && g_FuelStations[i][1] == 0.0) continue;
        if(IsPlayerInRangeOfPoint(playerid, FUEL_STATION_RANGE, g_FuelStations[i][0], g_FuelStations[i][1], g_FuelStations[i][2]))
            return true;
    }
    return false;
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
#define MAX_PLAYER_VEHICLES     3
#define VSELLTO_RANGE           10.0
#define VEHICLE_DOC_DURATION         604800  // 7 zile, in secunde (folosit la /vbuy)
#define VEHICLE_INSURANCE_DURATION   432000  // 5 zile
#define VEHICLE_MEDKIT_DURATION      604800  // 7 zile
#define VEHICLE_EXTINGUISHER_DURATION 864000 // 10 zile
#define VEHICLE_ITP_DURATION         1296000 // 15 zile (la trecerea ITP-ului cu succes)
#define VEHICLE_REDEEM_FEE           5000    // taxa de deblocare a unui vehicul confiscat de R.A.R.

#define ITP_RANGE       3.0
#define ITP_CHECK_TIME  10000 // 10 secunde, in ms
#define ITP_MIN_HEALTH  900.0
new Float:ITP_LOC_X   = 0.0;   // suprascris din locations_admin (id 16, "Vehicle ITP")
new Float:ITP_LOC_Y   = 0.0;
new Float:ITP_LOC_Z   = 0.0;

#define PLATE_RANGE     3.0
new Float:PLATE_LOC_X = 0.0;   // suprascris din locations_admin (id 15, "Vehicle Plate")
new Float:PLATE_LOC_Y = 0.0;
new Float:PLATE_LOC_Z = 0.0;

// E_PVEHICLE_DATA + PVehicleData/g_PVehicle* sunt declarate mai sus (inainte de Speedometer),
// ca sa fie accesibile in Speedometer_Tick pentru afisarea/consumul de motorina.

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
    {
        g_VehicleToPVIndex[vehid] = idx;
        g_VehicleFuel[vehid] = PVehicleData[idx][pvFuel];
    }

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

    if(pvidx != -1 && PVehicleData[pvidx][pvIsConfiscated])
        return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"This vehicle has been impounded by R.A.R. Pay the release fee ("C_INFO"/redeemcar"C_WHITE") to start it."), 0;

    // Vehiculele de job pot fi pornite doar de cei care au jobul corespunzator
    new reqJob = Job_VehicleRequiredJob(vehid);
    if(reqJob != 0 && PlayerData[playerid][pJob] != reqJob)
        return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Only workers of this job can start this vehicle."), 0;

    new engine, lights, alarm, doors, bonnet, boot, objective;
    GetVehicleParamsEx(vehid, engine, lights, alarm, doors, bonnet, boot, objective);
    new bool:turningOn = (engine == 0);

    // Fara motorina nu poti porni motorul
    if(turningOn && g_VehicleFuel[vehid] <= 0.0)
        return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"[Fuel] "C_WHITE"The tank is empty. Refuel at a gas station ("C_INFO"/refuel"C_WHITE")."), 0;

    engine = engine ? 0 : 1;
    SetVehicleParamsEx(vehid, engine, lights, alarm, doors, bonnet, boot, objective);

    // La oprirea motorului, salvam nivelul curent de motorina (daca e vehicul din DB)
    if(!turningOn)
        Vehicle_SaveFuel(vehid);

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
    lights = (lights == 1) ? 0 : 1; // -1 (nesetat) sau 0 -> aprinde
    SetVehicleParamsEx(vehid, engine, lights, alarm, doors, bonnet, boot, objective);

    return 1;
}

stock Vehicle_ToggleBonnet(playerid)
{
    new vehid = GetPlayerVehicleID(playerid);
    if(vehid == 0 || GetPlayerVehicleSeat(playerid) != 0)
        return 0;

    new engine, lights, alarm, doors, bonnet, boot, objective;
    GetVehicleParamsEx(vehid, engine, lights, alarm, doors, bonnet, boot, objective);
    bonnet = (bonnet == 1) ? 0 : 1; // -1 (nesetat) sau 0 -> deschide capota
    SetVehicleParamsEx(vehid, engine, lights, alarm, doors, bonnet, boot, objective);

    return 1;
}

stock Vehicle_ToggleBoot(playerid)
{
    new vehid = GetPlayerVehicleID(playerid);
    if(vehid == 0 || GetPlayerVehicleSeat(playerid) != 0)
        return 0;

    new engine, lights, alarm, doors, bonnet, boot, objective;
    GetVehicleParamsEx(vehid, engine, lights, alarm, doors, bonnet, boot, objective);
    boot = (boot == 1) ? 0 : 1; // -1 (nesetat) sau 0 -> deschide portbagajul
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

// Locatiile intre care se alege random spawn-ul civil (pSpawn==1)
#define CIVIL_SPAWN_COUNT 6
new Float:CivilSpawnLocations[CIVIL_SPAWN_COUNT][4] = {
    {868.2825, -2071.2629, 17.3279, 32.4158}, // spawn civil 1
    {855.5033, -2073.2300, 17.3279, 16.4357}, // spawn civil 2
    {842.9693, -2071.7813, 17.3279, 5.1556},  // spawn civil 3
    {834.1105, -2069.5881, 17.3279, 4.5289},  // spawn civil 4
    {841.6141, -2080.4556, 17.3279, 15.8090}, // spawn civil 5
    {857.5778, -2073.7075, 17.3279, 15.4957}  // spawn civil 6
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
        new hidx = (PlayerData[playerid][pHouse] != 0) ? Houses_FindByID(PlayerData[playerid][pHouse]) : -1;
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
    // DB_CreateTables(); // NU se ruleaza la pornire. Decomenteaza o singura data pentru un DB nou (creeaza toate tabelele).

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
        `house`       INT DEFAULT 0,\
        `business`    INT DEFAULT 0,\
        `spawn_type`  INT DEFAULT 1,\
        `key1`        INT DEFAULT 0,\
        `key2`        INT DEFAULT 0,\
        `key3`        INT DEFAULT 0,\
        `driving_lic_a_exp` DATE DEFAULT NULL,\
        `driving_lic_b_exp` DATE DEFAULT NULL,\
        `driving_lic_c_exp` DATE DEFAULT NULL,\
        `driving_lic_d_exp` DATE DEFAULT NULL,\
        `airplane_lic_a_exp` DATE DEFAULT NULL,\
        `airplane_lic_h_exp` DATE DEFAULT NULL,\
        `diseased`         TINYINT DEFAULT 0,\
        `disease_paydays`  INT     DEFAULT 0,\
        `caravan_key`      INT     DEFAULT 0,\
        `is_president`     TINYINT DEFAULT 0,\
        `voted`            TINYINT DEFAULT 0,\
        `was_president`    TINYINT DEFAULT 0,\
        `job`              INT     DEFAULT 0,\
        `phone_model`      INT     DEFAULT -1,\
        `phone_number`     INT     DEFAULT 0,\
        `medkits`          INT     DEFAULT 0,\
        `extinguishers`    INT     DEFAULT 0,\
        `mute_expire`      INT     DEFAULT 0,\
        `wanted_level`     INT     DEFAULT 0,\
        `jail_seconds`     INT     DEFAULT 0\
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;",
        "", "", 0);
    print("[DB] Tabel `players` verificat/creat.");

    mysql_tquery(g_SQL,
        "CREATE TABLE IF NOT EXISTS `bans` (\
        `banID`     INT AUTO_INCREMENT PRIMARY KEY,\
        `username`  VARCHAR(24)  NOT NULL DEFAULT '',\
        `ip`        VARCHAR(46)  NOT NULL DEFAULT '',\
        `reason`    VARCHAR(128) NOT NULL DEFAULT '',\
        `banned_by` VARCHAR(24)  NOT NULL DEFAULT '',\
        `ban_date`  INT DEFAULT 0\
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;",
        "", "", 0);

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
        `vw`         INT DEFAULT 0,\
        `seif_herbs` INT DEFAULT 0,\
        `seif_drugs` INT DEFAULT 0\
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;",
        "", "", 0);

    mysql_tquery(g_SQL,
        "CREATE TABLE IF NOT EXISTS `payday_setup` (\
        `id`                INT PRIMARY KEY DEFAULT 1,\
        `min_salary`        INT   DEFAULT 5000,\
        `tax`               INT   DEFAULT 10,\
        `cass`              INT   DEFAULT 10,\
        `bank_interest`     FLOAT DEFAULT 0.10,\
        `insurance_price`   INT   DEFAULT 500,\
        `medkit_price`      INT   DEFAULT 500,\
        `extinguisher_price` INT  DEFAULT 500,\
        `itp_price`         INT   DEFAULT 750,\
        `plate_price`       INT   DEFAULT 250,\
        `rent_bike_price`   INT   DEFAULT 15,\
        `exam_a_price`      INT   DEFAULT 200,\
        `exam_b_price`      INT   DEFAULT 300,\
        `exam_c_price`      INT   DEFAULT 500,\
        `exam_d_price`      INT   DEFAULT 400,\
        `exam_p_price`      INT   DEFAULT 1000,\
        `exam_h_price`      INT   DEFAULT 1000,\
        `pizza_price`       INT   DEFAULT 50,\
        `burger_price`      INT   DEFAULT 55,\
        `farm_tractor_price` INT  DEFAULT 10000,\
        `farm_dozer_price`  INT   DEFAULT 15000,\
        `farm_combine_price` INT  DEFAULT 20000\
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;",
        "", "", 0);

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
        `pets`     INT DEFAULT 0,\
        `has_fridge`    INT DEFAULT 0,\
        `fridge_milk`   INT DEFAULT 0,\
        `fridge_banana` INT DEFAULT 0,\
        `fridge_water`  INT DEFAULT 0,\
        `fridge_juice`  INT DEFAULT 0,\
        `fridge_beer`   INT DEFAULT 0,\
        `bank`          INT DEFAULT 0\
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;",
        "", "", 0);

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
        `color2`     INT DEFAULT 1,\
        `fuel`       FLOAT DEFAULT 100.0\
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
        `locked`           TINYINT DEFAULT 0,\
        `first_registration` DATE DEFAULT NULL,\
        `from_biz`         INT DEFAULT 0,\
        `fuel`             FLOAT DEFAULT 100.0,\
        `is_confiscated`   TINYINT DEFAULT 0\
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;",
        "", "", 0);

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
        "CREATE TABLE IF NOT EXISTS `races` (\
        `rID`          INT AUTO_INCREMENT PRIMARY KEY,\
        `rName`        VARCHAR(16) NOT NULL,\
        `rVehModelID`  INT NOT NULL,\
        `rTimeRecord`  FLOAT DEFAULT 999,\
        `rPlayerName`  VARCHAR(24) DEFAULT ''\
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;",
        "", "", 0);

    mysql_tquery(g_SQL,
        "CREATE TABLE IF NOT EXISTS `farms` (\
        `id`               INT AUTO_INCREMENT PRIMARY KEY,\
        `x`                FLOAT DEFAULT 0.0,\
        `y`                FLOAT DEFAULT 0.0,\
        `z`                FLOAT DEFAULT 0.0,\
        `range`            FLOAT DEFAULT 0.0,\
        `tractors`         INT DEFAULT 0,\
        `combines`         INT DEFAULT 0,\
        `dozers`           INT DEFAULT 0,\
        `trucks`           INT DEFAULT 0,\
        `trailers`         INT DEFAULT 0,\
        `nextStep`         VARCHAR(16) NOT NULL DEFAULT 'Plow',\
        `lastWorkingDate`  DATE DEFAULT NULL,\
        `isPlowed`         TINYINT(1) DEFAULT 0,\
        `isLeveled`        TINYINT(1) DEFAULT 0,\
        `isSeeded`         TINYINT(1) DEFAULT 0,\
        `isFertilized`     TINYINT(1) DEFAULT 0,\
        `isReadyToHarvest` TINYINT(1) DEFAULT 0,\
        `owner`            VARCHAR(24) NOT NULL DEFAULT '',\
        `isOwned`          TINYINT(1) DEFAULT 0,\
        `price`            INT DEFAULT 100000,\
        `farmBank`         INT DEFAULT 0,\
        `farmRecolta`      INT DEFAULT 0\
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

    mysql_tquery(g_SQL,
        "CREATE TABLE IF NOT EXISTS `atms` (\
        `atmID`   INT AUTO_INCREMENT PRIMARY KEY,\
        `atmType` INT DEFAULT 0,\
        `atmLocX` FLOAT DEFAULT 0.0,\
        `atmLocY` FLOAT DEFAULT 0.0,\
        `atmLocZ` FLOAT DEFAULT 0.0,\
        `atmBankOwner` INT DEFAULT 0\
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;",
        "", "", 0);

    mysql_tquery(g_SQL,
        "CREATE TABLE IF NOT EXISTS `reports` (\
        `repID`          INT AUTO_INCREMENT PRIMARY KEY,\
        `playerName`     VARCHAR(24) NOT NULL DEFAULT '',\
        `playerDbId`     INT DEFAULT 0,\
        `repText`        VARCHAR(160) NOT NULL DEFAULT '',\
        `repDate`        INT DEFAULT 0,\
        `status`         INT DEFAULT 0,\
        `adminName`      VARCHAR(24) NOT NULL DEFAULT '',\
        `reply`          VARCHAR(160) NOT NULL DEFAULT '',\
        `replyDelivered` INT DEFAULT 0\
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;",
        "", "", 0);

    mysql_tquery(g_SQL,
        "CREATE TABLE IF NOT EXISTS `shops` (\
        `shopID`   INT AUTO_INCREMENT PRIMARY KEY,\
        `shopLocX` FLOAT DEFAULT 0.0,\
        `shopLocY` FLOAT DEFAULT 0.0,\
        `shopLocZ` FLOAT DEFAULT 0.0\
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;",
        "", "", 0);

    mysql_tquery(g_SQL,
        "CREATE TABLE IF NOT EXISTS `fastfood` (\
        `ffID`   INT AUTO_INCREMENT PRIMARY KEY,\
        `ffName` VARCHAR(32) NOT NULL DEFAULT '',\
        `ffType` INT DEFAULT 1,\
        `ffLocX` FLOAT DEFAULT 0.0,\
        `ffLocY` FLOAT DEFAULT 0.0,\
        `ffLocZ` FLOAT DEFAULT 0.0\
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;",
        "", "", 0);

    mysql_tquery(g_SQL,
        "CREATE TABLE IF NOT EXISTS `locations_admin` (\
        `locID`   INT AUTO_INCREMENT PRIMARY KEY,\
        `locName` VARCHAR(32) NOT NULL DEFAULT '',\
        `locX`    FLOAT DEFAULT 0.0,\
        `locY`    FLOAT DEFAULT 0.0,\
        `locZ`    FLOAT DEFAULT 0.0,\
        `interiorID` INT DEFAULT 0,\
        `vwID`       INT DEFAULT 0,\
        `locForGPS`  TINYINT(1) DEFAULT 0,\
        `locCategory` VARCHAR(32) NOT NULL DEFAULT '',\
        `locDescr`   VARCHAR(64) NOT NULL DEFAULT '',\
        UNIQUE KEY `uq_location_name` (`locName`)\
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;",
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

    mysql_tquery(g_SQL,
        "CREATE TABLE IF NOT EXISTS `basket_hoops` (\
        `id` INT PRIMARY KEY,\
        `x`  FLOAT DEFAULT 0.0,\
        `y`  FLOAT DEFAULT 0.0,\
        `z`  FLOAT DEFAULT 0.0\
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;",
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

    print("[DB] Tabele verificate/create.");
}

// ============================================================
//  INCARCARE FACTIUNI
// ============================================================
stock Factions_Load()
{
    print("[Factions] Se incarca factiunile din baza de date...");
    // Reconciliaza contorul `members` cu numarul real de jucatori din tabelul players (repara drift-ul in timp).
    // Ruleaza inaintea SELECT-ului pe aceeasi conexiune (FIFO), deci valorile incarcate sunt deja corecte.
    mysql_tquery(g_SQL,
        "UPDATE `factions` f SET f.`members` = (SELECT COUNT(*) FROM `players` p WHERE p.`faction` = f.`id`)",
        "", "", 0);
    mysql_tquery(g_SQL,
        "SELECT `id`,`name`,`members`,`lead`,`bank`,`pickup_id`,`mapicon_id`,`hq_x`,`hq_y`,`hq_z`,\
         `interior_x`,`interior_y`,`interior_z`,`interior`,`vw`,`seif_herbs`,`seif_drugs` \
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
        cache_get_value_name_int  (i, "seif_herbs", FactionData[fid][fSeifHerbs]);
        cache_get_value_name_int  (i, "seif_drugs", FactionData[fid][fSeifDrugs]);

        Factions_RecreatePickup(fid);
        Factions_RecreateLabel(fid);
        Factions_RecreateInteriorPickup(fid);
    }
    printf("[Factions] %d factiuni incarcate.", rows);

    // Markerele de seif pentru mafii (in interiorul/vw-ul fiecareia)
    for(new mfid = MAFIA_FID_MIN; mfid <= MAFIA_FID_MAX; mfid++)
        Drugs_RecreateSeifMarker(mfid);
    return 1;
}

// ============================================================
//  INCARCARE CASE
// ============================================================
stock Houses_Load()
{
    mysql_tquery(g_SQL,
        "SELECT `id`,`name`,`owner`,`owner_id`,`owned`,`price`,`type`,`max_pets`,`pets`,`loc_x`,`loc_y`,`loc_z`,\
         `has_fridge`,`fridge_milk`,`fridge_banana`,`fridge_water`,`fridge_juice`,`fridge_beer`,`bank` FROM `houses` ORDER BY `id` ASC",
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
        cache_get_value_name_int  (i, "has_fridge",    HouseData[idx][hHasFridge]);
        cache_get_value_name_int  (i, "fridge_milk",   HouseData[idx][hFridge][0]);
        cache_get_value_name_int  (i, "fridge_banana", HouseData[idx][hFridge][1]);
        cache_get_value_name_int  (i, "fridge_water",  HouseData[idx][hFridge][2]);
        cache_get_value_name_int  (i, "fridge_juice",  HouseData[idx][hFridge][3]);
        cache_get_value_name_int  (i, "fridge_beer",   HouseData[idx][hFridge][4]);
        cache_get_value_name_int  (i, "bank",          HouseData[idx][hBank]);
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

// ============================================================
//  INCARCARE ATM-URI
// ============================================================
stock ATMs_Load()
{
    mysql_tquery(g_SQL,
        "SELECT `atmID`,`atmType`,`atmLocX`,`atmLocY`,`atmLocZ`,`atmBankOwner` FROM `atms` ORDER BY `atmID` ASC",
        "OnATMsLoaded");
}

public OnATMsLoaded()
{
    new rows = cache_num_rows();
    g_AtmCount = 0;
    for(new i = 0; i < rows && g_AtmCount < MAX_ATMS; i++)
    {
        new idx = g_AtmCount;
        cache_get_value_name_int  (i, "atmID",   ATMData[idx][atmID]);
        cache_get_value_name_int  (i, "atmType", ATMData[idx][atmType]);
        cache_get_value_name_float(i, "atmLocX", ATMData[idx][atmX]);
        cache_get_value_name_float(i, "atmLocY", ATMData[idx][atmY]);
        cache_get_value_name_float(i, "atmLocZ", ATMData[idx][atmZ]);
        cache_get_value_name_int  (i, "atmBankOwner", ATMData[idx][atmBankOwner]);
        g_AtmPickup[idx] = -1;
        g_AtmLabel[idx]  = Text3D:INVALID_3DTEXT_ID;
        ATM_Create(idx);
        g_AtmCount++;
    }
    printf("[ATMs] %d ATM-uri incarcate.", g_AtmCount);
    return 1;
}

// Returneaza id-ul business-ului-banca cel mai apropiat de player (ATM_BANK_BIZ_A / _B), sau 0
stock ATM_NearestBank(playerid)
{
    new banks[2] = {ATM_BANK_BIZ_A, ATM_BANK_BIZ_B};
    new bestBiz = 0;
    new Float:bestDist = 999999.0;
    for(new i = 0; i < 2; i++)
    {
        new bidx = Businesses_FindByID(banks[i]);
        if(bidx == -1) continue;
        new Float:d = GetPlayerDistanceFromPoint(playerid, BusinessData[bidx][bLocX], BusinessData[bidx][bLocY], BusinessData[bidx][bLocZ]);
        if(d < bestDist) { bestDist = d; bestBiz = banks[i]; }
    }
    return bestBiz;
}

// Anunta un admin ce ATM a creat/mutat si carei banci apartine
stock ATM_AnnounceBank(playerid, idx, bool:moved)
{
    new bankName[32] = "no bank";
    new bidx = Businesses_FindByID(ATMData[idx][atmBankOwner]);
    if(bidx != -1) format(bankName, sizeof(bankName), "%s", BusinessData[bidx][bName]);

    new amsg[160];
    format(amsg, sizeof(amsg), C_SUCCESS"[ADM] Success: "C_WHITE"You %s ATM "C_INFO"#%d"C_WHITE", which belongs to bank "C_INFO"#%d %s"C_WHITE".",
        moved ? "moved" : "created", ATMData[idx][atmID], ATMData[idx][atmBankOwner], bankName);
    SendClientMessage(playerid, COLOR_SUCCESS, amsg);
}

public OnATMCreated(playerid, idx)
{
    if(!IsPlayerConnected(playerid)) return 0;
    ATMData[idx][atmID] = cache_insert_id();
    ATM_Create(idx);
    ATM_AnnounceBank(playerid, idx, false);
    return 1;
}

stock Shops_Load()
{
    mysql_tquery(g_SQL,
        "SELECT `shopID`,`shopLocX`,`shopLocY`,`shopLocZ` FROM `shops` ORDER BY `shopID` ASC",
        "OnShopsLoaded");
}

public OnShopsLoaded()
{
    new rows = cache_num_rows();
    g_ShopCount = 0;
    for(new i = 0; i < rows && g_ShopCount < MAX_SHOPS; i++)
    {
        new idx = g_ShopCount;
        cache_get_value_name_int  (i, "shopID",   ShopData[idx][shopID]);
        cache_get_value_name_float(i, "shopLocX", ShopData[idx][shopX]);
        cache_get_value_name_float(i, "shopLocY", ShopData[idx][shopY]);
        cache_get_value_name_float(i, "shopLocZ", ShopData[idx][shopZ]);
        g_ShopPickup[idx] = -1;
        g_ShopLabel[idx]  = Text3D:INVALID_3DTEXT_ID;
        Shop_Create(idx);
        g_ShopCount++;
    }
    printf("[Shops] %d shop-uri incarcate.", g_ShopCount);
    return 1;
}

public OnShopCreated(playerid, idx)
{
    if(!IsPlayerConnected(playerid)) return 0;
    ShopData[idx][shopID] = cache_insert_id();
    Shop_Create(idx);
    Shop_RefreshAllIcons();

    new m[96];
    format(m, sizeof(m), C_SUCCESS"[ADM] Success: "C_WHITE"Shop "C_INFO"#%d"C_WHITE" created.", ShopData[idx][shopID]);
    SendClientMessage(playerid, COLOR_SUCCESS, m);
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
        "SELECT `locID`,`locName`,`locX`,`locY`,`locZ`,`interiorID`,`vwID`,`locForGPS`,`locCategory`,`locDescr` FROM `locations_admin` ORDER BY `locID` ASC",
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
        cache_get_value_name_int  (i, "interiorID", LocationData[idx][locInterior]);
        cache_get_value_name_int  (i, "vwID",       LocationData[idx][locVW]);
        new gpsFlag; cache_get_value_name_int(i, "locForGPS", gpsFlag);
        LocationData[idx][locForGPS] = (gpsFlag != 0);
        cache_get_value_name      (i, "locCategory", LocationData[idx][locCategory], 32);
        cache_get_value_name      (i, "locDescr", LocationData[idx][locDescr], 64);
        g_LocationCount++;
    }
    printf("[Locations] %d locatii incarcate.", g_LocationCount);
    Locations_ApplyToCommands();
    return 1;
}

// Suprascrie coordonatele comenzilor din DB (locations_admin) daca randul exista.
// Fiecare grup: daca gaseste locatia dupa nume, actualizeaza globalele corespunzatoare.
Locations_ApplyToCommands()
{
    new idx;
    idx = Locations_FindByID(16);                  if(idx != -1) { ITP_LOC_X = LocationData[idx][locX]; ITP_LOC_Y = LocationData[idx][locY]; ITP_LOC_Z = LocationData[idx][locZ]; }     // Vehicle ITP (/vitp)
    idx = Locations_FindByID(15);                  if(idx != -1) { PLATE_LOC_X = LocationData[idx][locX]; PLATE_LOC_Y = LocationData[idx][locY]; PLATE_LOC_Z = LocationData[idx][locZ]; } // Vehicle Plate (/vplate)
    idx = Locations_FindByName("police_garage_to_int"); if(idx != -1) { POLICE_GARAGE_X = LocationData[idx][locX];   POLICE_GARAGE_Y = LocationData[idx][locY];   POLICE_GARAGE_Z = LocationData[idx][locZ];   POLICE_GARAGE_INT = LocationData[idx][locInterior]; }   // point 20
    idx = Locations_FindByName("police_int_to_garage"); if(idx != -1) { POLICE_ENTRANCE_X = LocationData[idx][locX]; POLICE_ENTRANCE_Y = LocationData[idx][locY]; POLICE_ENTRANCE_Z = LocationData[idx][locZ]; POLICE_ENTRANCE_INT = LocationData[idx][locInterior]; } // point 19
    idx = Locations_FindByName("police_int_to_ext");    if(idx != -1) { POLICE_EXIT_X = LocationData[idx][locX];     POLICE_EXIT_Y = LocationData[idx][locY];     POLICE_EXIT_Z = LocationData[idx][locZ]; }     // point 18
    idx = Locations_FindByName("Cityhall");         if(idx != -1) { CITYHALL_EXT_X = LocationData[idx][locX]; CITYHALL_EXT_Y = LocationData[idx][locY]; CITYHALL_EXT_Z = LocationData[idx][locZ]; } // exterior City Hall (rand DB redenumit "Cityhall")
    idx = Locations_FindByName("cityhall_int");    if(idx != -1) { CITYHALL_INT_X = LocationData[idx][locX]; CITYHALL_INT_Y = LocationData[idx][locY]; CITYHALL_INT_Z = LocationData[idx][locZ]; }
    idx = Locations_FindByName("getjob");          if(idx != -1) { GETJOB_X = LocationData[idx][locX]; GETJOB_Y = LocationData[idx][locY]; GETJOB_Z = LocationData[idx][locZ]; }
    idx = Locations_FindByName("quitjob");         if(idx != -1) { QUITJOB_X = LocationData[idx][locX]; QUITJOB_Y = LocationData[idx][locY]; QUITJOB_Z = LocationData[idx][locZ]; }
    // Spitale (/curedisease): id 22 (Hospital) si 23 (Hospital2)
    g_HospitalCount = 0;
    new const hospIDs[] = {22, 23};
    for(new hi = 0; hi < sizeof(hospIDs); hi++)
    {
        new hidx = Locations_FindByID(hospIDs[hi]);
        if(hidx != -1 && g_HospitalCount < MAX_HOSPITALS)
        {
            g_HospitalLoc[g_HospitalCount][0] = LocationData[hidx][locX];
            g_HospitalLoc[g_HospitalCount][1] = LocationData[hidx][locY];
            g_HospitalLoc[g_HospitalCount][2] = LocationData[hidx][locZ];
            g_HospitalCount++;
        }
    }
    idx = Locations_FindByName("examA");           if(idx != -1) { EXAMA_LOC_X = LocationData[idx][locX]; EXAMA_LOC_Y = LocationData[idx][locY]; EXAMA_LOC_Z = LocationData[idx][locZ]; }
    idx = Locations_FindByName("examB");           if(idx != -1) { EXAMB_LOC_X = LocationData[idx][locX]; EXAMB_LOC_Y = LocationData[idx][locY]; EXAMB_LOC_Z = LocationData[idx][locZ]; }
    idx = Locations_FindByName("examC");           if(idx != -1) { EXAMC_LOC_X = LocationData[idx][locX]; EXAMC_LOC_Y = LocationData[idx][locY]; EXAMC_LOC_Z = LocationData[idx][locZ]; }
    idx = Locations_FindByName("examD");           if(idx != -1) { EXAMD_LOC_X = LocationData[idx][locX]; EXAMD_LOC_Y = LocationData[idx][locY]; EXAMD_LOC_Z = LocationData[idx][locZ]; }
    idx = Locations_FindByID(5);                   if(idx != -1) { EXAMP_LOC_X = LocationData[idx][locX]; EXAMP_LOC_Y = LocationData[idx][locY]; EXAMP_LOC_Z = LocationData[idx][locZ]; } // examP (avion)
    idx = Locations_FindByID(6);                   if(idx != -1) { EXAMH_LOC_X = LocationData[idx][locX]; EXAMH_LOC_Y = LocationData[idx][locY]; EXAMH_LOC_Z = LocationData[idx][locZ]; } // examH (elicopter)
    idx = Locations_FindByName("lspd_barrier");    if(idx != -1) { LSPD_BARRIER_X = LocationData[idx][locX]; LSPD_BARRIER_Y = LocationData[idx][locY]; LSPD_BARRIER_Z = LocationData[idx][locZ]; }

    // Hunting (locID 24): coordonate + pickup sniper + map icon
    idx = Locations_FindByID(24);                  if(idx != -1) { g_HuntStartX = LocationData[idx][locX]; g_HuntStartY = LocationData[idx][locY]; g_HuntStartZ = LocationData[idx][locZ]; }
    CreatePickup(HUNT_PICKUP_MODEL, 1, g_HuntStartX, g_HuntStartY, g_HuntStartZ, -1);
    Create3DTextLabel("[ Hunting ]\nUse /hunt", COLOR_WHITE, g_HuntStartX, g_HuntStartY, g_HuntStartZ + 0.4, 20.0, 0, 0);
    CreateDynamicMapIcon(g_HuntStartX, g_HuntStartY, g_HuntStartZ, HUNT_MAPICON_ID, 0, 0, 0, -1, 99999.0, MAPICON_GLOBAL);

    // Politie: /duty, celula de inchisoare si cele 2 zone de /arrest (interior + exterior)
    idx = Locations_FindByName("PR/duty");         if(idx != -1) { DUTY_LOC_X = LocationData[idx][locX]; DUTY_LOC_Y = LocationData[idx][locY]; DUTY_LOC_Z = LocationData[idx][locZ]; DUTY_LOC_INT = LocationData[idx][locInterior]; DUTY_LOC_VW = LocationData[idx][locVW]; }
    idx = Locations_FindByName("jail");            if(idx != -1) { JAIL_X = LocationData[idx][locX]; JAIL_Y = LocationData[idx][locY]; JAIL_Z = LocationData[idx][locZ]; JAIL_INTERIOR = LocationData[idx][locInterior]; JAIL_VW = LocationData[idx][locVW]; }
    idx = Locations_FindByName("PR/arrest-int");   if(idx != -1) { ARREST_ZONE_X = LocationData[idx][locX]; ARREST_ZONE_Y = LocationData[idx][locY]; ARREST_ZONE_Z = LocationData[idx][locZ]; }
    idx = Locations_FindByName("PR/arrest-ext");   if(idx != -1) { ARREST_ZONE2_X = LocationData[idx][locX]; ARREST_ZONE2_Y = LocationData[idx][locY]; ARREST_ZONE2_Z = LocationData[idx][locZ]; }

    Cmd_CreateMarkers(); // creeaza pickup-urile/etichetele DUPA ce coordonatele sunt sincronizate din DB
}

// Creeaza pickup-urile si etichetele 3D pentru locatiile de comanda, folosind coordonatele
// (deja suprascrise din locations_admin). Rulat o singura data, din OnLocationsLoaded.
Cmd_CreateMarkers()
{
    Cityhall_Create();
    JobCenter_Create();

    CreatePickup(1239, 1, ITP_LOC_X, ITP_LOC_Y, ITP_LOC_Z, -1);
    Create3DTextLabel("[ Vehicle Inspection Service ]\n[ Use /vitp ]\n[ Price: 750$ ]", COLOR_WHITE,
        ITP_LOC_X, ITP_LOC_Y, ITP_LOC_Z - 0.5, 30.0, 0, 0);
    CreatePickup(1239, 1, PLATE_LOC_X, PLATE_LOC_Y, PLATE_LOC_Z, -1);
    Create3DTextLabel("[ Vehicle Inspection Service ]\n[ Use /vplate ]\n[ Price: 250$ ]", COLOR_WHITE,
        PLATE_LOC_X, PLATE_LOC_Y, PLATE_LOC_Z - 0.5, 3.0, 0, 0);

    new examLabel[64];
    CreatePickup(1210, 1, EXAMA_LOC_X, EXAMA_LOC_Y, EXAMA_LOC_Z, -1);
    format(examLabel, sizeof(examLabel), "[ Category A Exam ]\n[ /examA ]\n[ Price: $%s ]", MoneyStr(g_ExamAPrice));
    Create3DTextLabel(examLabel, COLOR_WHITE, EXAMA_LOC_X, EXAMA_LOC_Y, EXAMA_LOC_Z - 0.5, 30.0, 0, 0);

    CreatePickup(1210, 1, EXAMB_LOC_X, EXAMB_LOC_Y, EXAMB_LOC_Z, -1);
    format(examLabel, sizeof(examLabel), "[ Category B Exam ]\n[ /examB ]\n[ Price: $%s ]", MoneyStr(g_ExamBPrice));
    Create3DTextLabel(examLabel, COLOR_WHITE, EXAMB_LOC_X, EXAMB_LOC_Y, EXAMB_LOC_Z - 0.5, 30.0, 0, 0);

    CreatePickup(1210, 1, EXAMC_LOC_X, EXAMC_LOC_Y, EXAMC_LOC_Z, -1);
    format(examLabel, sizeof(examLabel), "[ Category C Exam ]\n[ /examC ]\n[ Price: $%s ]", MoneyStr(g_ExamCPrice));
    Create3DTextLabel(examLabel, COLOR_WHITE, EXAMC_LOC_X, EXAMC_LOC_Y, EXAMC_LOC_Z - 0.5, 30.0, 0, 0);

    CreatePickup(1210, 1, EXAMD_LOC_X, EXAMD_LOC_Y, EXAMD_LOC_Z, -1);
    format(examLabel, sizeof(examLabel), "[ Category D Exam ]\n[ /examD ]\n[ Price: $%s ]", MoneyStr(g_ExamDPrice));
    Create3DTextLabel(examLabel, COLOR_WHITE, EXAMD_LOC_X, EXAMD_LOC_Y, EXAMD_LOC_Z - 0.5, 30.0, 0, 0);

    // Examene de zbor (examH elicopter, examP avion)
    CreatePickup(1239, 1, EXAMH_LOC_X, EXAMH_LOC_Y, EXAMH_LOC_Z, -1);
    Create3DTextLabel("[ Helicopter Exam ]\n[ /examH ]\n[ Price: $1.000 ]", COLOR_WHITE,
        EXAMH_LOC_X, EXAMH_LOC_Y, EXAMH_LOC_Z + 0.5, 20.0, 0, 0);
    CreatePickup(1239, 1, EXAMP_LOC_X, EXAMP_LOC_Y, EXAMP_LOC_Z, -1);
    Create3DTextLabel("[ Airplane Exam ]\n[ /examP ]\n[ Price: $1.000 ]", COLOR_WHITE,
        EXAMP_LOC_X, EXAMP_LOC_Y, EXAMP_LOC_Z + 0.5, 20.0, 0, 0);

    // Garaj (point 20) -> interior. Interior/VW din globalele suprascrise din DB.
    CreateDynamic3DTextLabel("[ Police Garage ]\n[ Press ENTER (F) to go inside ]", COLOR_WHITE,
        POLICE_GARAGE_X, POLICE_GARAGE_Y, POLICE_GARAGE_Z - 0.5, 10.0,
        INVALID_PLAYER_ID, INVALID_VEHICLE_ID, 0, 0, POLICE_GARAGE_INT);
    // Interior (point 19) -> garaj
    CreateDynamic3DTextLabel("[ To Garage ]\n[ Press ENTER (F) ]", COLOR_WHITE,
        POLICE_ENTRANCE_X, POLICE_ENTRANCE_Y, POLICE_ENTRANCE_Z - 0.5, 10.0,
        INVALID_PLAYER_ID, INVALID_VEHICLE_ID, 0, 0, POLICE_ENTRANCE_INT);
    // Punctul 18 (interior -> strada) NU are eticheta proprie: exista deja "[ Press ENTER to exit ]" din logica de factiune.

    for(new hi = 0; hi < g_HospitalCount; hi++)
    {
        CreatePickup(1241, 1, g_HospitalLoc[hi][0], g_HospitalLoc[hi][1], g_HospitalLoc[hi][2], -1);
        Create3DTextLabel("[ Hospitalization ]\n[ Use /curedisease ]", COLOR_WHITE,
            g_HospitalLoc[hi][0], g_HospitalLoc[hi][1], g_HospitalLoc[hi][2] - 0.5, 10.0, 0, 0);
    }

    // Locatiile de /arrest (interior LSPD + exterior garaj): pickup + eticheta 3D, in interiorul/VW-ul corect din DB.
    // Cautate dupa nume (nu dupa locID) ca sa ramana corecte indiferent de renumerotarea randurilor.
    new arIdx;
    arIdx = Locations_FindByID(13);
    if(arIdx != -1)
    {
        CreateDynamicPickup(1247, 1, LocationData[arIdx][locX], LocationData[arIdx][locY], LocationData[arIdx][locZ], LocationData[arIdx][locVW], LocationData[arIdx][locInterior]);
        CreateDynamic3DTextLabel("[ Politia Romana ]\n[ /arrest ]", COLOR_WHITE,
            LocationData[arIdx][locX], LocationData[arIdx][locY], LocationData[arIdx][locZ] - 0.3, 10.0,
            INVALID_PLAYER_ID, INVALID_VEHICLE_ID, 0, LocationData[arIdx][locVW], LocationData[arIdx][locInterior]);
    }
    arIdx = Locations_FindByID(14);
    if(arIdx != -1)
    {
        CreateDynamicPickup(1247, 1, LocationData[arIdx][locX], LocationData[arIdx][locY], LocationData[arIdx][locZ], LocationData[arIdx][locVW], LocationData[arIdx][locInterior]);
        CreateDynamic3DTextLabel("[ Politia Romana ]\n[ /arrest ]", COLOR_WHITE,
            LocationData[arIdx][locX], LocationData[arIdx][locY], LocationData[arIdx][locZ] - 0.3, 10.0,
            INVALID_PLAYER_ID, INVALID_VEHICLE_ID, 0, LocationData[arIdx][locVW], LocationData[arIdx][locInterior]);
    }
}

// Porneste un examen de zbor (cat = FLIGHT_CAT_P / FLIGHT_CAT_H). Trimite mesajele si returneaza 1.
// Definita aici (dupa BusinessData) fiindca acceseaza banca business-ului.
stock FlightExam_Begin(playerid, cat)
{
    new Float:lx, Float:ly, Float:lz, Float:rng, price;
    new bool:ready;
    new craft[16];
    if(cat == FLIGHT_CAT_H)
    {
        lx = EXAMH_LOC_X; ly = EXAMH_LOC_Y; lz = EXAMH_LOC_Z; rng = EXAMH_RANGE; price = g_ExamHPrice;
        ready = (g_ExamHCar[0] != -1);
        format(craft, sizeof(craft), "helicopter");
    }
    else
    {
        lx = EXAMP_LOC_X; ly = EXAMP_LOC_Y; lz = EXAMP_LOC_Z; rng = EXAMP_RANGE; price = g_ExamPPrice;
        ready = (g_ExamPCar[0] != -1);
        format(craft, sizeof(craft), "airplane");
    }

    if(!ready)
        return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"This exam is not available yet."), 1;
    if(!IsPlayerInRangeOfPoint(playerid, rng, lx, ly, lz))
        return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be at the exam location."), 1;
    if(g_FlightState[playerid] != FLIGHT_STATE_NONE)
        return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You already have a flight exam in progress."), 1;
    if(PlayerData[playerid][pMoney] < price)
        return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have enough money."), 1;

    PlayerData[playerid][pMoney] -= price;
    GivePlayerMoney(playerid, -price);
    UpdatePlayer(playerid, pMoney);

    new cut = price * FLIGHT_EXAM_BIZ_CUT / 100;
    new bidx = Businesses_FindByID(FLIGHT_EXAM_BIZ_ID);
    if(bidx != -1 && cut > 0)
    {
        BusinessData[bidx][bBank] += cut;
        new q[128];
        mysql_format(g_SQL, q, sizeof(q), "UPDATE `businesses` SET `bank`=%d WHERE `id`=%d", BusinessData[bidx][bBank], BusinessData[bidx][bID]);
        mysql_tquery(g_SQL, q, "", "", 0);
    }

    g_FlightState[playerid]      = FLIGHT_STATE_WAITING;
    g_FlightCat[playerid]        = cat;
    g_FlightCheckpoint[playerid] = 0;
    g_FlightVehicle[playerid]    = -1;
    FlightExam_KillTimer(playerid);
    g_FlightTimer[playerid] = SetTimerEx("FlightExam_Timeout", FLIGHT_STEP_TIME, false, "i", playerid);

    new m[144];
    format(m, sizeof(m), C_INFO"Info: "C_WHITE"Get into the exam "C_INFO"%s"C_WHITE" within "C_INFO"60 seconds"C_WHITE" to start the exam.", craft);
    SendClientMessage(playerid, COLOR_INFO, m);
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
        "SELECT `id`,`faction_id`,`model_id`,`loc_x`,`loc_y`,`loc_z`,`rotation`,`color1`,`color2`,`fuel` \
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
        cache_get_value_name_float(i, "fuel",        VFactionData[idx][vfFuel]);
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
         `insurance_exp`,`medkit_exp`,`extinguisher_exp`,`itp_exp`,`locked`,`first_registration`,`from_biz`,`fuel`,`is_confiscated` FROM `vehicles_personal` ORDER BY `id` ASC",
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
        cache_get_value_name(i, "first_registration", dateBuf, sizeof(dateBuf));
        PVehicleData[idx][pvFirstReg] = DateStrToUnix(dateBuf);
        cache_get_value_name_int(i, "from_biz", PVehicleData[idx][pvFromBiz]);
        cache_get_value_name_float(i, "fuel", PVehicleData[idx][pvFuel]);
        new confInt;
        cache_get_value_name_int(i, "is_confiscated", confInt);
        PVehicleData[idx][pvIsConfiscated] = bool:confInt;
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
        "SELECT `min_salary`,`tax`,`cass`,`bank_interest`,`insurance_price`,`medkit_price`,`extinguisher_price`,`itp_price`,`plate_price`,`rent_bike_price`,`exam_a_price`,`exam_b_price`,`exam_c_price`,`exam_d_price`,`exam_p_price`,`exam_h_price`,`pizza_price`,`burger_price`,`farm_tractor_price`,`farm_dozer_price`,`farm_combine_price` \
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
        cache_get_value_name_int  (0, "exam_a_price",       g_ExamAPrice);
        cache_get_value_name_int  (0, "exam_b_price",       g_ExamBPrice);
        cache_get_value_name_int  (0, "exam_c_price",       g_ExamCPrice);
        cache_get_value_name_int  (0, "exam_d_price",       g_ExamDPrice);
        cache_get_value_name_int  (0, "exam_p_price",       g_ExamPPrice);
        cache_get_value_name_int  (0, "exam_h_price",       g_ExamHPrice);
        cache_get_value_name_int  (0, "pizza_price",        g_PizzaPrice);
        cache_get_value_name_int  (0, "burger_price",       g_BurgerPrice);
        cache_get_value_name_int  (0, "farm_tractor_price", g_FarmTractorPrice);
        cache_get_value_name_int  (0, "farm_dozer_price",   g_FarmDozerPrice);
        cache_get_value_name_int  (0, "farm_combine_price", g_FarmCombinePrice);
    }
    printf("[PayDay] Setari: Salar minim $%d | Impozit %d%% | CASS %d%% | Dobanda %.2f%%",
        g_PDMinSalary, g_PDTax, g_PDCASS, g_PDInterest);
    printf("[VehiculePersonale] Asigurare $%d | Kit medical $%d | Extinctor $%d | ITP $%d | Numar inmatriculare $%d | Bicicleta $%d | Examen A $%d | Examen B $%d | Examen C $%d | Examen D $%d | Pizza $%d | Burger $%d",
        g_InsurancePrice, g_MedkitPrice, g_ExtinguisherPrice, g_ITPPrice, g_PlatePrice, g_RentBikePrice, g_ExamAPrice, g_ExamBPrice, g_ExamCPrice, g_ExamDPrice, g_PizzaPrice, g_BurgerPrice);
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
        new interest = floatround(float(PlayerData[i][pBank]) * g_PDInterest / 100.0);
        if(interest > BANK_INTEREST_CAP) interest = BANK_INTEREST_CAP; // plafon dobanda

        // --- Taxe pe proprietati ---
        new Float:carTaxF = 0.0;
        for(new v = 0; v < g_PVehicleCount; v++)
            if(PVehicleData[v][pvOwnerId] == PlayerData[i][pID])
                carTaxF += PVehicleData[v][pvPrice] * 0.00001; // 10$ la 1.000.000

        new Float:houseTaxF = 0.0;
        if(PlayerData[i][pHouse] != 0)
        {
            new hidx = Houses_FindByID(PlayerData[i][pHouse]);
            if(hidx != -1) houseTaxF = HouseData[hidx][hPrice] * 0.0001; // 100$ la 1.000.000
        }

        new Float:bizTaxF = 0.0;
        for(new b = 0; b < g_BusinessCount; b++)
            if(BusinessData[b][bOwnerId] == PlayerData[i][pID])
                bizTaxF += BusinessData[b][bPrice] * 0.00025; // 250$ la 1.000.000

        new carTax   = floatround(carTaxF);
        new houseTax = floatround(houseTaxF);
        new bizTax   = floatround(bizTaxF);
        new propTax  = carTax + houseTax + bizTax;

        new net      = salary - tax - cass - propTax;

        PlayerData[i][pMoney] += net;
        PlayerData[i][pBank]  += interest;
        PlayerData[i][pRP]    += 1;

        GivePlayerMoney(i, net);
        GameTextForPlayer(i, "~g~Payday", 3000, 1);

        new total = net + interest; // diferenta totala in avere (cash + banca)

        new msg[256];
        SendClientMessage(i, COLOR_INFO, C_INFO"========== PayDay ==========");

        format(msg, sizeof(msg), C_SUCCESS"Income: "C_WHITE"Salary: "C_SUCCESS"$%s"C_WHITE", Interest: "C_SUCCESS"$%s",
            MoneyStr(salary), MoneyStr(interest));
        SendClientMessage(i, COLOR_WHITE, msg);

        // Impartit in 2 linii: linia intreaga depasea limita de afisare a SendClientMessage (~144 car. cu codurile de culoare)
        format(msg, sizeof(msg), C_ERROR"Outcome: "C_WHITE"CASS: "C_ERROR"$%s "C_WHITE"| Tax: "C_ERROR"$%s",
            MoneyStr(cass), MoneyStr(tax));
        SendClientMessage(i, COLOR_WHITE, msg);

        format(msg, sizeof(msg), C_ERROR"Outcome: "C_WHITE"Property tax: Veh: "C_ERROR"$%s"C_WHITE", House: "C_ERROR"$%s"C_WHITE", Business: "C_ERROR"$%s",
            MoneyStr(carTax), MoneyStr(houseTax), MoneyStr(bizTax));
        SendClientMessage(i, COLOR_WHITE, msg);

        if(total >= 0)
            format(msg, sizeof(msg), C_INFO"Total: "C_SUCCESS"+$%s", MoneyStr(total));
        else
            format(msg, sizeof(msg), C_INFO"Total: "C_ERROR"-$%s", MoneyStr(-total));
        SendClientMessage(i, COLOR_WHITE, msg);

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

    // Venit din teritorii pentru mafii (factiunile 4-7): 100$ per teritoriu detinut, in banca factiunii
    for(new fid = MAFIA_FID_MIN; fid <= MAFIA_FID_MAX; fid++)
    {
        new turfCount = 0;
        for(new t = 0; t < g_TurfCount; t++)
            if(TurfData[t][tFactionID] == fid) turfCount++;

        if(turfCount > 0)
        {
            new turfIncome = 100 * turfCount;
            Faction_AddBank(fid, turfIncome);

            new tmsg[144];
            format(tmsg, sizeof(tmsg), C_SUCCESS"[Faction] "C_WHITE"Territory income: "C_SUCCESS"+$%s"C_WHITE" (%d territories) added to the faction bank.",
                MoneyStr(turfIncome), turfCount);
            // doar membrii cu rank 4+ primesc anuntul
            for(new p = 0; p < MAX_PLAYERS; p++)
                if(IsPlayerConnected(p) && PlayerData[p][pLogged] && PlayerData[p][pFaction] == fid && PlayerData[p][pFactionRank] >= 4)
                    SendClientMessage(p, COLOR_SUCCESS, tmsg);
        }
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
        if(hour == 0) Newspaper_ResetAll(); // reset ziare la miezul noptii
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

// Fereastra pentru jobul Car Transportator: Vineri (5), Sambata (6), Duminica (0), intre 16:00 si 23:00
stock bool:Job_TransportWindowOpen()
{
    new year, month, day;
    getdate(year, month, day);
    new dow = DayOfWeek(year, month, day);
    if(dow != 0 && dow != 5 && dow != 6) return false;

    new hour, minute, second;
    gettime(hour, minute, second);
    if(hour < 16 || hour > 23) return false;
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
        SendClientMessage(playerid, COLOR_WHITE,
            C_WHITE"For more information about the activities on the server, you can use "C_SUCCESS"/howto"C_WHITE".");
        SendClientMessage(playerid, COLOR_WHITE,
            C_WHITE"If you have any other questions, the admins are here to help via the "C_SUCCESS"/report"C_WHITE" command.");

        new ldlg[160];
        format(ldlg, sizeof(ldlg), C_WHITE"Welcome back, "C_INFO"%s"C_WHITE"!\nThis account is registered.\n\nEnter your password to log in:", PlayerData[playerid][pName]);
        ShowPlayerDialog(playerid, DIALOG_LOGIN, DIALOG_STYLE_PASSWORD, "Login", ldlg, "Login", "Quit");
    }
    else
    {
        PlayerData[playerid][pRegistered] = false;
        SendClientMessage(playerid, COLOR_SUCCESS, "Welcome! From here, leave your worries aside and enjoy some quality time.");
        SendClientMessage(playerid, COLOR_WHITE,
            C_WHITE"For more information about the activities on the server, you can use "C_SUCCESS"/howto"C_WHITE".");
        SendClientMessage(playerid, COLOR_WHITE,
            C_WHITE"If you have any other questions, the admins are here to help via the "C_SUCCESS"/report"C_WHITE" command.");

        new rdlg[160];
        format(rdlg, sizeof(rdlg), C_WHITE"Welcome, "C_INFO"%s"C_WHITE"!\nThis account is not registered.\n\nEnter a password to create your account:", PlayerData[playerid][pName]);
        ShowPlayerDialog(playerid, DIALOG_REGISTER, DIALOG_STYLE_PASSWORD, "Register", rdlg, "Register", "Quit");
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
    PlayerData[playerid][pHouse]      = 0;
    PlayerData[playerid][pBusiness]   = 0;
    PlayerData[playerid][pSpawn]      = 1;
    PlayerData[playerid][pOnDuty]     = false;
    PlayerData[playerid][pKey1]       = 0;
    PlayerData[playerid][pKey2]       = 0;
    PlayerData[playerid][pKey3]       = 0;
    PlayerData[playerid][pDrivingLicA_exp][0] = EOS;
    PlayerData[playerid][pDrivingLicB_exp][0] = EOS;
    PlayerData[playerid][pDrivingLicC_exp][0] = EOS;
    PlayerData[playerid][pDrivingLicD_exp][0] = EOS;
    PlayerData[playerid][pAirLicA_exp][0] = EOS;
    PlayerData[playerid][pAirLicH_exp][0] = EOS;
    PlayerData[playerid][pDiseased]       = false;
    PlayerData[playerid][pDiseasePaydays] = 0;
    PlayerData[playerid][pCaravanKey]      = 0;
    PlayerData[playerid][pFarmKey]         = 0;
    Player_RecalcSpawn(playerid);

    AC_SetVW(playerid, 0);
    SetPlayerMapIcon(playerid, 0, 846.4172, -2059.0867, 12.8672, 35, 0, MAPICON_GLOBAL);
    SetPlayerColor(playerid, FactionColors[FACTION_NONE]);
    Factions_SetPlayerIcons(playerid);
    Businesses_SetPlayerIcons(playerid);
    Shop_SetPlayerIcons(playerid);
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
         `driving_lic_a_exp`,`driving_lic_b_exp`,`driving_lic_c_exp`,`driving_lic_d_exp`,`airplane_lic_a_exp`,`airplane_lic_h_exp`,`diseased`,`disease_paydays`,\
         `caravan_key`,`is_president`,`voted`,`was_president`,`job`,`phone_model`,`phone_number`,`medkits`,`extinguishers`,`mute_expire`,`wanted_level`,`jail_seconds` \
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
    cache_get_value_name(0, "airplane_lic_a_exp", PlayerData[playerid][pAirLicA_exp], 11);
    cache_get_value_name(0, "airplane_lic_h_exp", PlayerData[playerid][pAirLicH_exp], 11);

    new diseasedInt;
    cache_get_value_name_int(0, "diseased",        diseasedInt);
    cache_get_value_name_int(0, "disease_paydays", PlayerData[playerid][pDiseasePaydays]);
    PlayerData[playerid][pDiseased] = bool:diseasedInt;

    cache_get_value_name_int(0, "caravan_key", PlayerData[playerid][pCaravanKey]);
    Caravan_ShowParked(playerid);

    Farm_SyncPlayerKey(playerid); // seteaza pFarmKey dupa numele proprietarului fermei

    new presInt, votedInt, wasPresInt;
    cache_get_value_name_int(0, "is_president",  presInt);
    cache_get_value_name_int(0, "voted",         votedInt);
    cache_get_value_name_int(0, "was_president", wasPresInt);
    PlayerData[playerid][pIsPresident]  = bool:presInt;
    PlayerData[playerid][pVoted]        = bool:votedInt;
    PlayerData[playerid][pWasPresident] = bool:wasPresInt;

    cache_get_value_name_int(0, "job", PlayerData[playerid][pJob]);
    cache_get_value_name_int(0, "phone_model",  PlayerData[playerid][pPhoneModel]);
    cache_get_value_name_int(0, "phone_number", PlayerData[playerid][pPhoneNumber]);
    // Implicit dupa login jucatorul NU are medical kit / extinctor la el (nu se pastreaza intre sesiuni)
    PlayerData[playerid][pMedkits]       = 0;
    PlayerData[playerid][pExtinguishers] = 0;
    cache_get_value_name_int(0, "mute_expire",   PlayerData[playerid][pMuteExpire]);
    cache_get_value_name_int(0, "wanted_level",  PlayerData[playerid][pWanted]);
    if(PlayerData[playerid][pWanted] < 0) PlayerData[playerid][pWanted] = 0;
    if(PlayerData[playerid][pWanted] > 6) PlayerData[playerid][pWanted] = 6;
    SetPlayerWantedLevel(playerid, PlayerData[playerid][pWanted]);
    cache_get_value_name_int(0, "jail_seconds",  PlayerData[playerid][pJailSeconds]);
    if(PlayerData[playerid][pJailSeconds] < 0) PlayerData[playerid][pJailSeconds] = 0;

    PlayerData[playerid][pLogged]  = true;
    PlayerData[playerid][pOnDuty]  = false;
    Player_RecalcSpawn(playerid);

    AC_SetVW(playerid, 0);
    SetPlayerColor(playerid, FactionColors[PlayerData[playerid][pFaction]]);
    Factions_SetPlayerIcons(playerid);
    Businesses_SetPlayerIcons(playerid);
    Shop_SetPlayerIcons(playerid);
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
    Reports_OnLogin(playerid);
    SpawnPlayer(playerid);
    return 1;
}

// ============================================================
//  SISTEM DE REPORTURI (/report, /reports, /reportreply) - persistat in DB
//  Max 2 reporturi deschise per jucator; adminii le vad in dialog (preview -> text complet);
//  la raspuns/rezolvare reportul e sters din DB (offline: pastrat pana la livrarea la login).
// ============================================================
#define MAX_OPEN_REPORTS_PER_PLAYER 2
#define REPORT_PREVIEW_LEN          40   // caractere din text afisate in lista dialog
#define MAX_REPORT_DIALOG           50   // reporturi maxime afisate in dialog
new g_ReportDialogIds[MAX_PLAYERS][MAX_REPORT_DIALOG]; // maparea listitem -> repID
new g_ReportDialogCount[MAX_PLAYERS];
new g_ReportViewId[MAX_PLAYERS];                       // reportul deschis in dialogul de vizualizare

forward OnReportSubmit(playerid, text[]);
forward OnReportsList(playerid);
forward OnReportView(playerid, repID);
forward OnReportReplyLookup(adminid, repID, text[]);
forward OnReportRepliesDeliver(playerid);
forward OnOpenReportsCount(playerid);

// La login: livreaza raspunsurile (apoi le sterge) + notifica adminii de reporturile deschise
stock Reports_OnLogin(playerid)
{
    new q[160];
    mysql_format(g_SQL, q, sizeof(q),
        "SELECT `adminName`,`reply` FROM `reports` WHERE `playerDbId`=%d AND `status`=1 ORDER BY `repID` ASC",
        PlayerData[playerid][pID]);
    mysql_tquery(g_SQL, q, "OnReportRepliesDeliver", "i", playerid);

    if(PlayerData[playerid][pAdminLevel] >= 1)
        mysql_tquery(g_SQL, "SELECT COUNT(*) AS c FROM `reports` WHERE `status`=0", "OnOpenReportsCount", "i", playerid);
}

// Trimite dialogul cu reporturile deschise (folosit de /reports si de butonul Back)
stock Reports_ShowList(playerid)
{
    mysql_tquery(g_SQL,
        "SELECT `repID`,`playerName`,`repText` FROM `reports` WHERE `status`=0 ORDER BY `repID` ASC",
        "OnReportsList", "i", playerid);
}

stock Report_Delete(repID)
{
    new q[96];
    mysql_format(g_SQL, q, sizeof(q), "DELETE FROM `reports` WHERE `repID`=%d", repID);
    mysql_tquery(g_SQL, q, "", "", 0);
}

// /report -> verifica limita de reporturi deschise, apoi insereaza si difuzeaza
public OnReportSubmit(playerid, text[])
{
    if(!IsPlayerConnected(playerid) || !PlayerData[playerid][pLogged]) return 1;

    new c; cache_get_value_name_int(0, "c", c);
    if(c >= MAX_OPEN_REPORTS_PER_PLAYER)
    {
        new lmsg[160];
        format(lmsg, sizeof(lmsg), C_ERROR"Error: "C_WHITE"You already have "C_INFO"%d"C_WHITE" open reports. Wait for a reply before sending more.", c);
        return SendClientMessage(playerid, COLOR_ERROR, lmsg), 1;
    }

    new q[300];
    mysql_format(g_SQL, q, sizeof(q),
        "INSERT INTO `reports` (`playerName`,`playerDbId`,`repText`,`repDate`,`status`) VALUES ('%e',%d,'%e',%d,0)",
        PlayerData[playerid][pName], PlayerData[playerid][pID], text, gettime());
    mysql_tquery(g_SQL, q, "", "", 0);

    new rmsg[200];
    format(rmsg, sizeof(rmsg), "[REPORT] %s (ID %d): %s", PlayerData[playerid][pName], playerid, text);
    for(new i = 0; i < MAX_PLAYERS; i++)
        if(IsPlayerConnected(i) && PlayerData[i][pLogged] && PlayerData[i][pAdminLevel] >= 1)
            SendClientMessage(i, COLOR_YELLOW, rmsg);

    SendClientMessage(playerid, COLOR_SUCCESS, C_SUCCESS"Success: "C_WHITE"Your report has been sent to the admins.");
    return 1;
}

public OnReportRepliesDeliver(playerid)
{
    if(!IsPlayerConnected(playerid)) return 1;
    new rows = cache_num_rows();
    if(rows == 0) return 1;

    new aname[24], rtext[160], rline[200];
    for(new i = 0; i < rows; i++)
    {
        cache_get_value_name(i, "adminName", aname, sizeof(aname));
        cache_get_value_name(i, "reply", rtext, sizeof(rtext));
        format(rline, sizeof(rline), "[REPLY] %s: %s", aname, rtext);
        SendClientMessage(playerid, COLOR_YELLOW, rline);
    }

    // raspunsurile au fost livrate -> sterge reporturile respective
    new q[96];
    mysql_format(g_SQL, q, sizeof(q), "DELETE FROM `reports` WHERE `playerDbId`=%d AND `status`=1", PlayerData[playerid][pID]);
    mysql_tquery(g_SQL, q, "", "", 0);
    return 1;
}

public OnOpenReportsCount(playerid)
{
    if(!IsPlayerConnected(playerid)) return 1;
    new c; cache_get_value_name_int(0, "c", c);
    if(c > 0)
    {
        new msg[128];
        format(msg, sizeof(msg), C_INFO"Info: "C_WHITE"There are "C_INFO"%d"C_WHITE" open report(s). Use "C_INFO"/reports"C_WHITE".", c);
        SendClientMessage(playerid, COLOR_INFO, msg);
    }
    return 1;
}

// /reports -> dialog cu reporturile deschise (preview), maparea listitem -> repID per admin
public OnReportsList(playerid)
{
    if(!IsPlayerConnected(playerid)) return 1;
    new rows = cache_num_rows();
    if(rows == 0)
        return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"There are no open reports."), 1;

    g_ReportDialogCount[playerid] = 0;
    static list[2048];
    new line[120], rid, rname[24], rtxt[160], preview[REPORT_PREVIEW_LEN + 4];
    list[0] = EOS;
    strcat(list, "ID\tPlayer\tReport\n");
    for(new i = 0; i < rows && g_ReportDialogCount[playerid] < MAX_REPORT_DIALOG; i++)
    {
        cache_get_value_name_int(i, "repID", rid);
        cache_get_value_name(i, "playerName", rname, sizeof(rname));
        cache_get_value_name(i, "repText", rtxt, sizeof(rtxt));

        strmid(preview, rtxt, 0, REPORT_PREVIEW_LEN, sizeof(preview));
        if(strlen(rtxt) > REPORT_PREVIEW_LEN) strcat(preview, "...");

        format(line, sizeof(line), "%d\t%s\t%s\n", rid, rname, preview);
        strcat(list, line);

        g_ReportDialogIds[playerid][g_ReportDialogCount[playerid]] = rid;
        g_ReportDialogCount[playerid]++;
    }

    ShowPlayerDialog(playerid, DIALOG_REPORTS_LIST, DIALOG_STYLE_TABLIST_HEADERS, "Open reports", list, "View", "Close");
    return 1;
}

// afiseaza textul complet al unui report (buton Resolve / Back)
public OnReportView(playerid, repID)
{
    if(!IsPlayerConnected(playerid)) return 1;
    if(cache_num_rows() == 0)
        return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"That report no longer exists."), 1;

    new rname[24], rtxt[160], rline[300];
    cache_get_value_name(0, "playerName", rname, sizeof(rname));
    cache_get_value_name(0, "repText", rtxt, sizeof(rtxt));

    g_ReportViewId[playerid] = repID;
    format(rline, sizeof(rline), "{FFFF00}Report #%d\n{FFFFFF}From: %s\n\n%s\n\n{BB99FF}Reply: /reportreply %d [text]\nPress Resolve to close & delete this report.", repID, rname, rtxt, repID);
    ShowPlayerDialog(playerid, DIALOG_REPORTS_VIEW, DIALOG_STYLE_MSGBOX, "Report", rline, "Resolve", "Back");
    return 1;
}

public OnReportReplyLookup(adminid, repID, text[])
{
    if(!IsPlayerConnected(adminid)) return 1;

    if(cache_num_rows() == 0)
        return SendClientMessage(adminid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Invalid report ID."), 1;

    new status; cache_get_value_name_int(0, "status", status);
    if(status != 0)
        return SendClientMessage(adminid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"That report is already answered."), 1;

    new pdbid; cache_get_value_name_int(0, "playerDbId", pdbid);
    new pname[24]; cache_get_value_name(0, "playerName", pname, sizeof(pname));

    // reporterul e online?
    new target = INVALID_PLAYER_ID;
    for(new i = 0; i < MAX_PLAYERS; i++)
        if(IsPlayerConnected(i) && PlayerData[i][pLogged] && PlayerData[i][pID] == pdbid) { target = i; break; }

    if(target != INVALID_PLAYER_ID)
    {
        // online -> livreaza acum si sterge reportul (rezolvat)
        new rmsg[200];
        format(rmsg, sizeof(rmsg), "[REPLY] %s: %s", PlayerData[adminid][pName], text);
        SendClientMessage(target, COLOR_YELLOW, rmsg);
        Report_Delete(repID);

        new amsg[160];
        format(amsg, sizeof(amsg), C_SUCCESS"Success: "C_WHITE"Reply sent to "C_INFO"%s"C_WHITE" and report #%d resolved.", pname, repID);
        SendClientMessage(adminid, COLOR_SUCCESS, amsg);
    }
    else
    {
        // offline -> pastreaza raspunsul (status=1), se livreaza si se sterge la login-ul jucatorului
        new q[320];
        mysql_format(g_SQL, q, sizeof(q),
            "UPDATE `reports` SET `status`=1, `adminName`='%e', `reply`='%e' WHERE `repID`=%d",
            PlayerData[adminid][pName], text, repID);
        mysql_tquery(g_SQL, q, "", "", 0);

        new amsg[160];
        format(amsg, sizeof(amsg), C_SUCCESS"Success: "C_WHITE"Reply saved for "C_INFO"%s"C_WHITE" (report #%d); delivered on next login.", pname, repID);
        SendClientMessage(adminid, COLOR_SUCCESS, amsg);
    }
    return 1;
}

// ============================================================
//  SALVARE DATE JUCATOR
// ============================================================
stock FullUpdatePlayer(playerid)
{
    if(!PlayerData[playerid][pLogged]) return;

    new licA[14], licB[14], licC[14], licD[14], licAirA[14], licAirH[14], facJoin[14];
    BuildDateSqlValue(PlayerData[playerid][pDrivingLicA_exp], licA, sizeof(licA));
    BuildDateSqlValue(PlayerData[playerid][pDrivingLicB_exp], licB, sizeof(licB));
    BuildDateSqlValue(PlayerData[playerid][pDrivingLicC_exp], licC, sizeof(licC));
    BuildDateSqlValue(PlayerData[playerid][pDrivingLicD_exp], licD, sizeof(licD));
    BuildDateSqlValue(PlayerData[playerid][pAirLicA_exp], licAirA, sizeof(licAirA));
    BuildDateSqlValue(PlayerData[playerid][pAirLicH_exp], licAirH, sizeof(licAirH));
    BuildDateSqlValueFromUnix(PlayerData[playerid][pFactionJoin], facJoin, sizeof(facJoin));

    new query[820];
    mysql_format(g_SQL, query, sizeof(query),
        "UPDATE `players` SET \
        `password`='%e', `level`=%d, `money`=%d, `bank`=%d, \
        `rp`=%d, `admin_level`=%d, `faction`=%d, `faction_rank`=%d, `faction_join`=%s, `house`=%d, `business`=%d, `spawn_type`=%d, \
        `key1`=%d, `key2`=%d, `key3`=%d, \
        `driving_lic_a_exp`=%s, `driving_lic_b_exp`=%s, `driving_lic_c_exp`=%s, `driving_lic_d_exp`=%s, \
        `airplane_lic_a_exp`=%s, `airplane_lic_h_exp`=%s, \
        `phone_model`=%d, `phone_number`=%d, `medkits`=%d, `extinguishers`=%d, `mute_expire`=%d, `wanted_level`=%d, `jail_seconds`=%d \
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
        licAirA, licAirH,
        PlayerData[playerid][pPhoneModel],
        PlayerData[playerid][pPhoneNumber],
        PlayerData[playerid][pMedkits],
        PlayerData[playerid][pExtinguishers],
        PlayerData[playerid][pMuteExpire],
        PlayerData[playerid][pWanted],
        PlayerData[playerid][pJailSeconds],
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

        case pAirLicA_exp:
            mysql_format(g_SQL, query, sizeof(query),
                "UPDATE `players` SET `airplane_lic_a_exp`='%s' WHERE `id`=%d",
                PlayerData[playerid][pAirLicA_exp], PlayerData[playerid][pID]);

        case pAirLicH_exp:
            mysql_format(g_SQL, query, sizeof(query),
                "UPDATE `players` SET `airplane_lic_h_exp`='%s' WHERE `id`=%d",
                PlayerData[playerid][pAirLicH_exp], PlayerData[playerid][pID]);

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

        case pJob:
            mysql_format(g_SQL, query, sizeof(query),
                "UPDATE `players` SET `job`=%d WHERE `id`=%d",
                PlayerData[playerid][pJob], PlayerData[playerid][pID]);

        case pPhoneModel:
            mysql_format(g_SQL, query, sizeof(query),
                "UPDATE `players` SET `phone_model`=%d WHERE `id`=%d",
                PlayerData[playerid][pPhoneModel], PlayerData[playerid][pID]);

        case pPhoneNumber:
            mysql_format(g_SQL, query, sizeof(query),
                "UPDATE `players` SET `phone_number`=%d WHERE `id`=%d",
                PlayerData[playerid][pPhoneNumber], PlayerData[playerid][pID]);

        case pMedkits:
            mysql_format(g_SQL, query, sizeof(query),
                "UPDATE `players` SET `medkits`=%d WHERE `id`=%d",
                PlayerData[playerid][pMedkits], PlayerData[playerid][pID]);

        case pExtinguishers:
            mysql_format(g_SQL, query, sizeof(query),
                "UPDATE `players` SET `extinguishers`=%d WHERE `id`=%d",
                PlayerData[playerid][pExtinguishers], PlayerData[playerid][pID]);

        case pMuteExpire:
            mysql_format(g_SQL, query, sizeof(query),
                "UPDATE `players` SET `mute_expire`=%d WHERE `id`=%d",
                PlayerData[playerid][pMuteExpire], PlayerData[playerid][pID]);

        case pWanted:
            mysql_format(g_SQL, query, sizeof(query),
                "UPDATE `players` SET `wanted_level`=%d WHERE `id`=%d",
                PlayerData[playerid][pWanted], PlayerData[playerid][pID]);

        case pJailSeconds:
            mysql_format(g_SQL, query, sizeof(query),
                "UPDATE `players` SET `jail_seconds`=%d WHERE `id`=%d",
                PlayerData[playerid][pJailSeconds], PlayerData[playerid][pID]);

        default: return;
    }
    mysql_tquery(g_SQL, query, "", "", 0);
}

// ============================================================
//  TELEFONIE - LOGICA
// ============================================================
// Scrie marca telefonului playerului in out[] ("Telefon" daca nu are unul valid)
stock Phone_GetBrand(playerid, out[], len)
{
    new model = PlayerData[playerid][pPhoneModel];
    if(model < 0 || model >= PHONE_MODEL_COUNT) format(out, len, "Phone");
    else format(out, len, "%s", g_PhoneModels[model]);
}

stock bool:Phone_HasPhone(playerid)
    return (PlayerData[playerid][pPhoneModel] >= 0 && PlayerData[playerid][pPhoneModel] < PHONE_MODEL_COUNT);

stock bool:Phone_HasSim(playerid)
    return (PlayerData[playerid][pPhoneNumber] > 0);

// Genereaza un numar aleatoriu de 7 cifre
stock Phone_RandomNumber()
    return PHONE_NUMBER_MIN + random(PHONE_NUMBER_MAX - PHONE_NUMBER_MIN + 1);

// Cota care merge in business-ul operatorului (50% din SMS/apel)
stock Phone_CarrierCut(amount)
    return floatround(amount * PHONE_CARRIER_CUT_PCT / 100.0);

// Gaseste playerul online (logat) care detine acest numar de telefon
stock Phone_FindByNumber(number)
{
    if(number <= 0) return INVALID_PLAYER_ID;
    for(new i = 0; i < MAX_PLAYERS; i++)
    {
        if(!IsPlayerConnected(i) || !PlayerData[i][pLogged]) continue;
        if(PlayerData[i][pPhoneNumber] == number) return i;
    }
    return INVALID_PLAYER_ID;
}

// Deschide dialogul de cumparare telefon: SIM ca prima optiune, apoi cele 5 marci
stock Phone_ShowBuyDialog(playerid)
{
    new dlg[320], line[64];
    format(line, sizeof(line), "SIM (phone number)\t$%s\n", MoneyStr(PHONE_SIM_PRICE));
    strcat(dlg, line);
    for(new i = 0; i < PHONE_MODEL_COUNT; i++)
    {
        format(line, sizeof(line), "%s\t$%s\n", g_PhoneModels[i], MoneyStr(g_PhonePrices[i]));
        strcat(dlg, line);
    }
    ShowPlayerDialog(playerid, DIALOG_PHONE_BUY, DIALOG_STYLE_TABLIST, "Phone Shop", dlg, "Select", "Back");
}

// Cere un numar nou si verifica unicitatea in DB (async). Evita coliziunile cu numerele online cunoscute.
stock Phone_RequestSim(playerid)
{
    new candidate = Phone_RandomNumber();
    new guard = 0;
    while(Phone_FindByNumber(candidate) != INVALID_PLAYER_ID && guard < 20)
    {
        candidate = Phone_RandomNumber();
        guard++;
    }
    g_PhonePendingSim[playerid] = candidate;

    new q[128];
    mysql_format(g_SQL, q, sizeof(q), "SELECT `id` FROM `players` WHERE `phone_number`=%d LIMIT 1", candidate);
    mysql_tquery(g_SQL, q, "OnPhoneSimChecked", "ii", playerid, candidate);
}

public OnPhoneSimChecked(playerid, candidate)
{
    if(!IsPlayerConnected(playerid) || !PlayerData[playerid][pLogged]) return 0;

    // coliziune (numarul exista deja in DB) - reincearca cu altul
    if(cache_num_rows() > 0)
    {
        Phone_RequestSim(playerid);
        return 1;
    }

    // taxa SIM: reverifica banii la momentul atribuirii (pot fi cheltuiti intre /buysim si callback)
    if(PlayerData[playerid][pMoney] < PHONE_SIM_PRICE)
    {
        new emsg[128];
        format(emsg, sizeof(emsg), C_ERROR"Error: "C_WHITE"You no longer have enough money for a SIM ("C_INFO"$%s"C_WHITE").", MoneyStr(PHONE_SIM_PRICE));
        SendClientMessage(playerid, COLOR_ERROR, emsg);
        return 1;
    }

    new bool:wasChange = (PlayerData[playerid][pPhoneNumber] > 0);

    PlayerData[playerid][pMoney] -= PHONE_SIM_PRICE;
    GivePlayerMoney(playerid, -PHONE_SIM_PRICE);
    UpdatePlayer(playerid, pMoney);

    new cut = Phone_CarrierCut(PHONE_SIM_PRICE);
    if(cut > 0) Job_AddBizIncome(PHONE_CARRIER_BIZ_ID, cut);

    PlayerData[playerid][pPhoneNumber] = candidate;
    UpdatePlayer(playerid, pPhoneNumber);

    new brand[24]; Phone_GetBrand(playerid, brand, sizeof(brand));
    new msg[144];
    if(wasChange)
        format(msg, sizeof(msg), C_SUCCESS"[%s]: "C_WHITE"You changed your SIM for "C_INFO"$%s"C_WHITE". Your new phone number is "C_INFO"%05d"C_WHITE".",
            brand, MoneyStr(PHONE_SIM_PRICE), candidate);
    else
        format(msg, sizeof(msg), C_SUCCESS"[%s]: "C_WHITE"You got a new SIM for "C_INFO"$%s"C_WHITE". Your phone number is "C_INFO"%05d"C_WHITE".",
            brand, MoneyStr(PHONE_SIM_PRICE), candidate);
    SendClientMessage(playerid, COLOR_SUCCESS, msg);
    return 1;
}

// Inchide un apel (ring sau activ) pentru player si interlocutorul lui, cu mesaje optionale pentru fiecare
stock Phone_EndCall(playerid, const reasonSelf[], const reasonPartner[])
{
    new partner = g_PhoneCallPartner[playerid];

    if(g_PhoneRingTimer[playerid] != -1) { KillTimer(g_PhoneRingTimer[playerid]); g_PhoneRingTimer[playerid] = -1; }
    if(g_PhoneCallTimer[playerid] != -1) { KillTimer(g_PhoneCallTimer[playerid]); g_PhoneCallTimer[playerid] = -1; }
    g_PhoneCallPartner[playerid] = INVALID_PLAYER_ID;
    g_PhoneCallActive[playerid]  = false;
    g_PhoneCallCaller[playerid]  = false;
    if(reasonSelf[0] && IsPlayerConnected(playerid))
        SendClientMessage(playerid, COLOR_INFO, reasonSelf);

    if(partner != INVALID_PLAYER_ID)
    {
        if(g_PhoneRingTimer[partner] != -1) { KillTimer(g_PhoneRingTimer[partner]); g_PhoneRingTimer[partner] = -1; }
        if(g_PhoneCallTimer[partner] != -1) { KillTimer(g_PhoneCallTimer[partner]); g_PhoneCallTimer[partner] = -1; }
        g_PhoneCallPartner[partner] = INVALID_PLAYER_ID;
        g_PhoneCallActive[partner]  = false;
        g_PhoneCallCaller[partner]  = false;
        if(reasonPartner[0] && IsPlayerConnected(partner))
            SendClientMessage(partner, COLOR_INFO, reasonPartner);
    }
}

// Expira un apel neraspuns dupa PHONE_CALL_RING_TIMEOUT secunde (timer setat pe initiator)
public Phone_RingTimeout(playerid)
{
    g_PhoneRingTimer[playerid] = -1;

    if(g_PhoneCallPartner[playerid] == INVALID_PLAYER_ID) return 1; // apelul nu mai exista
    if(g_PhoneCallActive[playerid]) return 1;                       // s-a raspuns deja

    new partner = g_PhoneCallPartner[playerid];
    new sBrand[24], pBrand[24];
    Phone_GetBrand(playerid, sBrand, sizeof(sBrand));
    if(partner != INVALID_PLAYER_ID) Phone_GetBrand(partner, pBrand, sizeof(pBrand)); else format(pBrand, sizeof(pBrand), "Phone");

    new selfMsg[144], partnerMsg[144];
    format(selfMsg, sizeof(selfMsg), C_INFO"[%s]: "C_WHITE"Nobody answered. The call has ended.", sBrand);
    format(partnerMsg, sizeof(partnerMsg), C_INFO"[%s]: "C_WHITE"Missed call.", pBrand);
    Phone_EndCall(playerid, selfMsg, partnerMsg);
    return 1;
}

// Taxeaza initiatorul la fiecare PHONE_CALL_CHARGE_INTERVAL secunde cat timp apelul e activ
public Phone_CallCharge(playerid)
{
    if(g_PhoneCallPartner[playerid] == INVALID_PLAYER_ID || !g_PhoneCallActive[playerid])
    {
        if(g_PhoneCallTimer[playerid] != -1) { KillTimer(g_PhoneCallTimer[playerid]); g_PhoneCallTimer[playerid] = -1; }
        return 1;
    }

    new partner = g_PhoneCallPartner[playerid];
    new sBrand[24], pBrand[24];
    Phone_GetBrand(playerid, sBrand, sizeof(sBrand));
    if(partner != INVALID_PLAYER_ID) Phone_GetBrand(partner, pBrand, sizeof(pBrand)); else format(pBrand, sizeof(pBrand), "Phone");

    if(PlayerData[playerid][pMoney] < PHONE_CALL_PRICE)
    {
        new selfMsg[144], partnerMsg[144];
        format(selfMsg, sizeof(selfMsg), C_INFO"[%s]: "C_WHITE"You ran out of money for the call. The call has ended.", sBrand);
        format(partnerMsg, sizeof(partnerMsg), C_INFO"[%s]: "C_WHITE"The call has ended.", pBrand);
        Phone_EndCall(playerid, selfMsg, partnerMsg);
        return 1;
    }

    PlayerData[playerid][pMoney] -= PHONE_CALL_PRICE;
    GivePlayerMoney(playerid, -PHONE_CALL_PRICE);
    UpdatePlayer(playerid, pMoney);

    new cut = Phone_CarrierCut(PHONE_CALL_PRICE);
    if(cut > 0) Job_AddBizIncome(PHONE_CARRIER_BIZ_ID, cut);
    return 1;
}

// ============================================================
//  MODERARE (mute / kick / ban)
// ============================================================
// Returneaza true daca jucatorul e mutat in acest moment (si curata mute-ul expirat)
stock bool:Player_IsMuted(playerid)
{
    if(PlayerData[playerid][pMuteExpire] <= 0) return false;
    if(gettime() >= PlayerData[playerid][pMuteExpire])
    {
        // mute expirat -> curata
        PlayerData[playerid][pMuteExpire] = 0;
        UpdatePlayer(playerid, pMuteExpire);
        return false;
    }
    return true;
}

public Admin_DoKick(playerid)
{
    Kick(playerid);
    return 1;
}

// Da kick cu o mica intarziere, ca mesajul de motiv sa apuce sa ajunga la jucator
stock Admin_KickDelayed(playerid)
{
    SetTimerEx("Admin_DoKick", 500, false, "i", playerid);
}

// Verifica la conectare daca jucatorul (username sau IP) e banat
stock Ban_Check(playerid)
{
    new ip[46], name[24];
    GetPlayerIp(playerid, ip, sizeof(ip));
    GetPlayerName(playerid, name, sizeof(name));

    new q[160];
    mysql_format(g_SQL, q, sizeof(q),
        "SELECT `reason` FROM `bans` WHERE `username`='%e' OR `ip`='%e' LIMIT 1",
        name, ip);
    mysql_tquery(g_SQL, q, "OnPlayerBanCheck", "i", playerid);
}

public OnPlayerBanCheck(playerid)
{
    if(!IsPlayerConnected(playerid)) return 0;
    if(cache_num_rows() == 0) return 1; // nu e banat

    new reason[128];
    cache_get_value_name(0, "reason", reason, sizeof(reason));

    new msg[160];
    format(msg, sizeof(msg), C_ERROR"You are banned from this server."C_WHITE" Reason: "C_INFO"%s", reason[0] ? reason : "No reason");
    SendClientMessage(playerid, COLOR_ERROR, msg);
    Admin_KickDelayed(playerid);
    return 1;
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

// ---- Bariera LSPD (facțiunea 1 o deschide cu tasta H / horn) ----
new STREAMER_TAG_OBJECT:g_LSPDBarrier;
new bool:g_LSPDBarrierOpen = false;
new g_LSPDBarrierTimer = -1;
// LSPD_BARRIER_X/Y/Z declarate mai sus (langa coordonatele Politiei), ca sa fie vizibile in Locations_ApplyToCommands
#define LSPD_BARRIER_RANGE   10.0
#define LSPD_BARRIER_SPEED   0.5
forward LSPDBarrier_Close();

public LSPDBarrier_Close()
{
    MoveDynamicObject(g_LSPDBarrier, LSPD_BARRIER_X, LSPD_BARRIER_Y, LSPD_BARRIER_Z, LSPD_BARRIER_SPEED, 0.0, 90.0, 90.0);
    g_LSPDBarrierOpen = false;
    g_LSPDBarrierTimer = -1;
    return 1;
}

forward Veh_SpawnAll();

// Spawneaza toate vehiculele statice/de job/de examen. Apelat de un timer la 1 secunda dupa OnGameModeInit,
// nu direct, ca serverul sa fie deja pornit complet cand apar vehiculele.
public Veh_SpawnAll()
{
    // Biciclete de inchiriat
    g_RentBikeVehicle[0] = AddStaticVehicle(510,850.5624,-2054.5640,12.4752,66.0922,46,46); // mtb
    g_RentBikeVehicle[1] = AddStaticVehicle(510,851.7432,-2050.4297,12.4752,67.0849,46,46); // mtb2
    g_RentBikeVehicle[2] = AddStaticVehicle(510,851.1944,-2046.5259,12.4747,42.9260,46,46); // mtb3
    g_RentBikeVehicle[3] = AddStaticVehicle(510,851.6276,-2040.2594,12.4760,57.2991,46,46); // mtb4
    g_RentBikeVehicle[4] = AddStaticVehicle(510,821.3160,-2039.9390,12.4725,287.5561,46,46); // mtb5
    g_RentBikeVehicle[5] = AddStaticVehicle(510,821.5632,-2044.7482,12.4743,314.1075,46,46); // mtb6
    g_RentBikeVehicle[6] = AddStaticVehicle(510,821.2587,-2047.7460,12.4740,310.0911,46,46); // mtb7
    g_RentBikeVehicle[7] = AddStaticVehicle(510,821.1445,-2052.4043,12.4736,309.7540,46,46); // mtb8

    new rbPlate[18];
    for(new i = 0; i < MAX_RENT_BIKES; i++)
    {
        if(g_RentBikeVehicle[i] == -1) continue;
        format(rbPlate, sizeof(rbPlate), "Rent B %d", i + 1);
        SetVehicleNumberPlate(g_RentBikeVehicle[i], rbPlate);
        SetVehicleToRespawn(g_RentBikeVehicle[i]);
    }

    // Masini de inchiriat LS
    g_RentCarVehicle[0]  = AddStaticVehicle(562,1099.6075,-1757.9934,13.0087,89.0613,6,6);  // 562
    g_RentCarVehicle[1]  = AddStaticVehicle(561,1098.9120,-1766.6272,13.1621,90.3318,6,6);  // 561
    g_RentCarVehicle[2]  = AddStaticVehicle(565,1099.6223,-1775.7684,12.9673,89.9628,6,6);  // 565
    g_RentCarVehicle[3]  = AddStaticVehicle(603,1083.7201,-1772.6057,13.1893,269.6560,6,6); // 603
    g_RentCarVehicle[4]  = AddStaticVehicle(579,1077.6416,-1766.8062,13.2942,90.3040,6,6);  // 579
    g_RentCarVehicle[5]  = AddStaticVehicle(489,1077.3267,-1760.8992,13.5229,90.9905,6,6);  // 489
    g_RentCarVehicle[6]  = AddStaticVehicle(567,1083.9471,-1754.8574,13.2592,270.2663,6,6); // 567
    g_RentCarVehicle[7]  = AddStaticVehicle(477,1061.5952,-1769.9111,13.1252,269.2493,6,6); // zr
    g_RentCarVehicle[8]  = AddStaticVehicle(480,1061.4655,-1763.8555,13.1660,270.3265,6,6); // comet
    g_RentCarVehicle[9]  = AddStaticVehicle(415,1061.4050,-1757.9336,13.1913,269.1944,6,6); // cheetah
    g_RentCarVehicle[10] = AddStaticVehicle(467,1061.8734,-1749.1780,13.1910,270.7324,6,6); // oceanic
    g_RentCarVehicle[11] = AddStaticVehicle(580,1062.2733,-1740.2670,13.2663,269.1573,6,6); // staff

    new rcPlate[18];
    for(new i = 0; i < MAX_RENT_CARS; i++)
    {
        if(g_RentCarVehicle[i] == -1) continue;
        format(rcPlate, sizeof(rcPlate), "Rent C %d", i + 1);
        SetVehicleNumberPlate(g_RentCarVehicle[i], rcPlate);
        SetVehicleToRespawn(g_RentCarVehicle[i]);
    }

    // Vehicule de Glovo (doar cu ele se poate livra)
    Job_CreateGlovoVehicles();
    // Vehicule + decor pentru jobul de ciment
    Job_CreateCementVehicles();
    // Vehicule pentru jobul de livrare arme
    Job_CreateGunVehicles();
    // Vehicule pentru jobul de transport auto
    Job_CreateTransportVehicles();
    // Vehicule + decor pentru jobul Emergency Logistics Driver
    Job_CreateEmergencyVehicles();
    // Autobuze pentru jobul Bus Driver
    Job_CreateBusVehicles();

    // Motociclete scoala (examen categoria A)
    g_ExamACar[0] = AddStaticVehicle(468, 2468.4807, -1545.0331, 23.6673, 225.5256, 1, 1);
    g_ExamACar[1] = AddStaticVehicle(468, 2473.8789, -1545.3284, 23.6708, 213.4875, 1, 1);
    g_ExamACar[2] = AddStaticVehicle(468, 2480.3633, -1544.9382, 23.6699, 219.3432, 1, 1);

    // Masini scoala (examen categoria B)
    g_ExamBCar[0] = AddStaticVehicle(480, 491.0, -1486.5, 19.7, 348, 1, 1);
    g_ExamBCar[1] = AddStaticVehicle(480, 490.0, -1496.0, 20.1, 355, 1, 1);
    g_ExamBCar[2] = AddStaticVehicle(480, 489.5, -1506.0, 20.2, 7,   1, 1);

    // Capete tractor + remorci scoala (examen categoria C)
    g_ExamCTruck[0]   = AddStaticVehicle(403, 2394.0, -2066.0, 14.1192, 270, 1, 1);
    g_ExamCTruck[1]   = AddStaticVehicle(403, 2394.0, -2078.0, 14.1255, 270, 1, 1);
    g_ExamCTrailer[0] = AddStaticVehicle(450, 2394.0, -2094.0, 14.1463, 270, 1, 1);
    g_ExamCTrailer[1] = AddStaticVehicle(450, 2394.0, -2105.0, 14.1400, 270, 1, 1);

    // Autobuze scoala (examen categoria D)
    g_ExamDCar[0] = AddStaticVehicle(437, 1768.2, -1894.2072, 13.6907, 270, 1, 1);
    g_ExamDCar[1] = AddStaticVehicle(437, 1768.2, -1886.6780, 13.6888, 270, 1, 1);

    // Elicopter examen H
    g_ExamHCar[0] = AddStaticVehicle(469, 1635.0007, -2417.2942, 13.5662, 182.3682, 1, 3); // heli examH
    // Avion examen P
    g_ExamPCar[0] = AddStaticVehicle(476, 1496.8160, -2412.1025, 14.2594, 140.4002, 1, 1); // veh examP
    return 1;
}

public OnGameModeInit()
{
    SetGameModeText("N-RP");
    ShowPlayerMarkers(0);
    ShowNameTags(1);
    AllowAdminTeleport(1);
    DisableInteriorEnterExits();

    AddPlayerClass(7,868.2825,-2071.2629,17.3279,32.4158,0,0,0,0,0,0); // spawn civil 1
    AddPlayerClass(7,855.5033,-2073.2300,17.3279,16.4357,0,0,0,0,0,0); // spawn civil 2
    AddPlayerClass(7,842.9693,-2071.7813,17.3279,5.1556,0,0,0,0,0,0);  // spawn civil 3
    AddPlayerClass(7,834.1105,-2069.5881,17.3279,4.5289,0,0,0,0,0,0);  // spawn civil 4
    AddPlayerClass(7,841.6141,-2080.4556,17.3279,15.8090,0,0,0,0,0,0); // spawn civil 5
    AddPlayerClass(7,857.5778,-2073.7075,17.3279,15.4957,0,0,0,0,0,0); // spawn civil 6

    // Vehiculele (statice, job, examene) se spawneaza la 1 secunda dupa pornire, prin Veh_SpawnAll.
    SetTimer("Veh_SpawnAll", 2000, false);

    // ATM-uri:
    CreateDynamicObject(19324, 1102.34668, -1428.19055, 15.60,   0.00000, 0.00000, 90.00000);
    CreateDynamicObject(19324, 925.27521, -1206.83533, 16.70,   0.00000, 0.00000, 90.00000);
    CreateDynamicObject(19324, 812.37860, -1805.46765, 12.70,   0.00000, 0.00000, 90.00000);
    CreateDynamicObject(19324, 1506.89355, -1659.46252, 13.60,   0.00000, 0.00000, 80.00000);
    CreateDynamicObject(19324, 1921.77490, -1765.87976, 13.20,   0.00000, 0.00000, 180.00000);
    CreateDynamicObject(19324, 1955.02405, -2179.68848, 13.20,   0.00000, 0.00000, 180.00000);
    CreateDynamicObject(19324, 2404.08447, -1983.23743, 13.20,   0.00000, 0.00000, 90.00000);
    CreateDynamicObject(19324, 2353.31372, -1467.06970, 23.70,   0.00000, 0.00000, -90.00000);
    CreateDynamicObject(19324, 1089.52332, -922.59290, 43.10,   0.00000, 0.00000, 0.00000);
    CreateDynamicObject(19324, 1085.26147, -1803.68738, 13.24,   0.00000, 0.00000, 180.00000);

    // Obiecte decor / hartă LS
    CreateDynamicObject(10794, 823.76910, -2085.44141, 7.00000,   0.00000, 0.00000, 0.00000);
    CreateDynamicObject(10795, 821.52875, -2085.42847, 17.04660,   0.00000, 0.00000, 0.00000);
    CreateDynamicObject(10793, 748.59967, -2085.44019, 35.58000,   0.00000, 0.00000, 0.00000);
    CreateDynamicObject(6296, 836.00000, -2048.00000, 14.00000,   0.00000, 0.00000, 0.00000);
    CreateDynamicObject(3850, 851.20093, -2025.00000, 12.40000,   0.00000, 0.00000, 90.00000);
    CreateDynamicObject(3850, 851.19958, 12.40000, 12.40000,   0.00000, 0.00000, 90.00000);
    CreateDynamicObject(3850, 846.59998, -2025.00000, 12.40000,   0.00000, 0.00000, 90.00000);
    CreateDynamicObject(3850, 841.20001, -2025.00000, 12.40000,   0.00000, 0.00000, 90.00000);
    CreateDynamicObject(3850, 836.20093, -2025.00000, 12.40000,   0.00000, 0.00000, 90.00000);
    CreateDynamicObject(3850, 831.20093, -2025.00000, 12.40000,   0.00000, 0.00000, 90.00000);
    CreateDynamicObject(3850, 826.20001, -2025.00000, 12.40000,   0.00000, 0.00000, 90.00000);
    CreateDynamicObject(3850, 821.71997, -2025.00000, 12.40000,   0.00000, 0.00000, 90.00000);
    CreateDynamicObject(1653, 1062.19995, -1780.00000, 13.32000,   0.00000, 0.00000, 0.00000);
    CreateDynamicObject(1653, 1055.80005, -1760.78540, 13.32000,   0.00000, 0.00000, 90.00000);
    CreateDynamicObject(1653, 1055.80005, -1747.95398, 13.32000,   0.00000, 0.00000, 90.00000);
    CreateDynamicObject(1653, 1055.80005, -1739.96497, 13.32000,   0.00000, 0.00000, 90.00000);
    CreateDynamicObject(1653, 1062.19995, -1733.50000, 13.32000,   0.00000, 0.00000, 0.00000);
    CreateDynamicObject(1653, 1087.80005, -1780.00000, 13.32000,   0.00000, 0.00000, 0.00000);
    CreateDynamicObject(1653, 1075.00000, -1733.50000, 13.32000,   0.00000, 0.00000, 0.00000);
    CreateDynamicObject(1653, 1097.39001, -1733.50000, 13.32000,   0.00000, 0.00000, 0.00000);
    CreateDynamicObject(1653, 1055.80005, -1773.59424, 13.32000,   0.00000, 0.00000, 90.00000);
    CreateDynamicObject(1653, 1075.00000, -1780.00000, 13.32000,   0.00000, 0.00000, 0.00000);
    CreateDynamicObject(1653, 1087.80005, -1733.50000, 13.32000,   0.00000, 0.00000, 0.00000);
    CreateDynamicObject(1653, 1097.42004, -1780.00000, 13.32000,   0.00000, 0.00000, 0.00000);
    CreateDynamicObject(1653, 1103.80005, -1773.59998, 13.32000,   0.00000, 0.00000, 90.00000);
    CreateDynamicObject(1653, 1103.80005, -1754.40002, 13.32000,   0.00000, 0.00000, 90.00000);
    CreateDynamicObject(1653, 1103.80005, -1760.80005, 13.32000,   0.00000, 0.00000, 90.00000);
    CreateDynamicObject(19641, 1544.69995, -1636.80640, 11.50000,   0.00000, 0.00000, 90.00000);
    CreateDynamicObject(19641, 1544.69995, -1619.81995, 11.50000,   0.00000, 0.00000, 90.00000);
    g_LSPDBarrier = CreateDynamicObject(968, 1544.70020, -1630.9, 13.24000,   0.00000, 90.00000, 90.00000);
    CreateDynamicObject(19875, 732.03381, -1349.67273, 12.46800,   0.00000, 0.00000, 90.00000);
    CreateDynamicObject(8886, 1543.13196, -1612.72058, 15.56000,   0.00000, 0.00000, 90.00000);
    CreateDynamicObject(19419, 1543.44299, -1631.95276, 12.31600,   0.00000, 0.00000, 90.00000);
    CreateDynamicObject(18755, 1552.00977, -1670.72156, 100.00000,   0.00000, 0.00000, 90.00000);
    CreateDynamicObject(19817, 831.01996, -1206.70068, 15.50000,   0.00000, 0.00000, 0.00000);
    CreateDynamicObject(19817, 867.25000, -1206.69995, 15.50000,   0.00000, 0.00000, 0.00000);
    CreateDynamicObject(19872, 843.81152, -1200.86340, 15.66250,   0.00000, 0.00000, 0.00000);
    CreateDynamicObject(3406, 861.50909, -1231.30005, 14.19850,   0.00000, 0.00000, 0.00000);
    CreateDynamicObject(3406, 870.23822, -1231.30005, 14.19850,   0.00000, 0.00000, 0.00000);
    CreateDynamicObject(19903, 828.61462, -1203.63989, 15.96740,   0.00000, 0.00000, -70.00000);
    CreateDynamicObject(19899, 834.14355, -1202.83716, 15.96690,   0.00000, 0.00000, -90.00000);
    CreateDynamicObject(19898, 830.89221, -1205.07703, 16.00760,   0.00000, 0.00000, 90.00000);
    CreateDynamicObject(19815, 827.83850, -1201.63171, 17.84000,   0.00000, 0.00000, -1.00000);
    CreateDynamicObject(0, 866.00897, -1201.67981, 18.53650,   0.00000, 0.00000, 0.00000);
    CreateDynamicObject(19167, 867.22388, -1201.71387, 18.00000,   90.00000, 90.00000, -90.00000);
    CreateDynamicObject(18655, 864.34094, -1202.07532, 15.97080,   0.00000, 0.00000, 140.00000);
    CreateDynamicObject(14834, 870.03662, -1202.86670, 16.19170,   0.00000, 0.00000, 0.00000);
    CreateDynamicObject(1364, 875.27753, -1203.59424, 16.72520,   0.00000, 0.00000, 0.00000);
    CreateDynamicObject(1597, 914.21338, -1240.16968, 18.50000,   0.00000, 0.00000, 90.00000);
    CreateDynamicObject(12957, 928.15411, -1236.19092, 17.58330,   0.00000, 0.00000, 130.00000);
    CreateDynamicObject(1231, 930.95081, -1231.81555, 18.46190,   0.00000, 0.00000, -40.00000);

    // Acces blocat catre LS - obiectele de blocaj
    CreateDynamicObject(17030, 1768.06226, 629.15228, 8.64000,   0.00000, 0.00000, 40.00000);
    CreateDynamicObject(17030, 1696.87964, 413.50015, 17.00000,   0.00000, 0.00000, 40.00000);
    CreateDynamicObject(16357, 478.48645, 535.81256, 3.92000,   10.00000, -10.00000, -55.00000);
    CreateDynamicObject(4505, 413.26392, 624.34644, 20.13000,   0.00000, 0.00000, 120.00000);
    CreateDynamicObject(4515, 604.52344, 352.53906, 19.73438,   356.85840, 0.00000, -0.61087);
    CreateDynamicObject(3172, -161.87057, 391.90576, 12.68000,   0.00000, 90.00000, 100.00000);
    CreateDynamicObject(12957, -154.82791, 395.20377, 11.80000,   0.00000, 6.00000, 170.00000);

    // Vehiculele de examen (A/B/C/D + heli H) se creeaza in Veh_SpawnAll, la 1 secunda dupa pornire.

    // Etichetele/pickup-urile pentru examenele de zbor (examH/examP) se creeaza in Cmd_CreateMarkers,
    // dupa ce coordonatele sunt incarcate din locations_admin (altfel ar aparea la 0,0,0).

    // Punct /duty Politia Romana (interiorul HQ-ului factiunii 1: interior 6, vw 0)
    CreateDynamic3DTextLabel("[ Politia Romana ]\n[ /duty ]", COLOR_WHITE,
        256.1231, 65.5168, 1003.6406, 10.0,
        INVALID_PLAYER_ID, INVALID_VEHICLE_ID, 0, 0, 6);

    // Pickup-urile/etichetele pentru locatiile de comanda (ITP, plate, examene, politie, spital,
    // City Hall, Job Center) se creeaza in Cmd_CreateMarkers(), dupa incarcarea coordonatelor din DB.

    Fuel_CreateStations();

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

    for(new i = 0; i <= MAX_FACTIONS; i++) g_FactionLabel[i] = Text3D:INVALID_3DTEXT_ID;
    for(new i = 0; i <= MAX_FACTIONS; i++) g_FactionInteriorLabel[i] = Text3D:INVALID_3DTEXT_ID;

    // Cityhall_Create() si JobCenter_Create() se apeleaza acum din Cmd_CreateMarkers() (dupa load DB)

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
    for(new i = 0; i < MAX_VEHICLES; i++) g_VehicleFuel[i] = 50.0; // implicit 50% (vehiculele DB isi suprascriu la creare)

    DB_Init();
    Factions_Load();
    Houses_Load();
    Businesses_Load();
    Turfs_Load();
    ATMs_Load();
    Shops_Load();
    FastFood_Load(); // incarca locatiile /pizza /burger din DB (dupa DB_Init, altfel g_SQL nu e gata)
    Locations_Load();
    GPS_Load();
    BBallHoops_Load();
    BBallSpawns_Load();
    VehiclesFaction_Load();
    PVehicles_Load();
    Caravans_Load();
    PayDay_Load();
    Races_Load();
    Farms_Load();

    SetTimer("PayDay_Check", 60000, true);
    SetTimer("AC_Tick", AC_TICK, true); // anticheat

    Hunt_Init();
    SetTimer("Hunt_Tick", 1000, true); // vanatoare: fuga/respawn caprioare
    SetTimer("President_Check", 60000, true);
    SetTimer("HealthDecay_Tick", HEALTH_DECAY_TICK, true);
    SetTimer("Fires_Tick", 1000, true);
    SetTimer("Jail_Tick", 1000, true);
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
    AC_InitPlayer(playerid); // anticheat: initializeaza starea
    g_HuntMeat[playerid] = 0;
    g_HasSniper[playerid] = false;
    g_FarmWorking[playerid] = 0;
    g_FarmWorkVeh[playerid] = 0;
    g_FarmWorkTimer[playerid] = -1;
    g_FarmWorkSpawned[playerid] = false;
    g_FarmRentVeh[playerid] = 0;
    g_FarmDelivTruck[playerid] = 0;
    g_FarmDelivTrailer[playerid] = 0;

    // Acces blocat catre LS - sterge cladirile inlocuite de blocaj
    RemoveBuildingForPlayer(playerid, 8028, 1735.8594, 519.1563, 25.1563, 0.25);
    RemoveBuildingForPlayer(playerid, 8056, 1735.8594, 519.1563, 25.1563, 0.25);
    RemoveBuildingForPlayer(playerid, 8128, 1735.8750, 519.0078, 4.3594, 0.25);
    RemoveBuildingForPlayer(playerid, 8129, 1735.8750, 519.0078, 4.3594, 0.25);
    RemoveBuildingForPlayer(playerid, 1290, 1716.7813, 460.8906, 35.9688, 0.25);
    RemoveBuildingForPlayer(playerid, 1290, 1750.1094, 556.5469, 31.0391, 0.25);
    RemoveBuildingForPlayer(playerid, 3332, 445.4219, 565.4688, 24.5547, 0.25);
    RemoveBuildingForPlayer(playerid, 3333, 475.2344, 537.3203, 3.3203, 0.25);
    RemoveBuildingForPlayer(playerid, 3332, 491.3125, 499.9375, 24.5547, 0.25);
    RemoveBuildingForPlayer(playerid, 16431, 475.1250, 537.4375, 17.5859, 0.25);
    RemoveBuildingForPlayer(playerid, 3331, 445.4219, 565.4688, 24.5547, 0.25);
    RemoveBuildingForPlayer(playerid, 16357, 475.1250, 537.4375, 17.5859, 0.25);
    RemoveBuildingForPlayer(playerid, 3330, 475.2344, 537.3203, 3.3203, 0.25);
    RemoveBuildingForPlayer(playerid, 3331, 491.3125, 499.9375, 24.5547, 0.25);
    RemoveBuildingForPlayer(playerid, 792, 851.7969, -2066.3594, 12.1719, 0.25);
    RemoveBuildingForPlayer(playerid, 6005, 895.2578, -1256.9297, 31.2344, 0.25);
    RemoveBuildingForPlayer(playerid, 5838, 895.2578, -1256.9297, 31.2344, 0.25);
    RemoveBuildingForPlayer(playerid, 1312, 547.5703, -1251.2813, 19.8906, 0.25);
    RemoveBuildingForPlayer(playerid, 1211, 555.1563, -1251.9297, 16.6406, 0.25);

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
    PlayerData[playerid][pHouse]      = 0;
    PlayerData[playerid][pBusiness]   = 0;
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
    PlayerData[playerid][pAirLicA_exp][0] = EOS;
    PlayerData[playerid][pAirLicH_exp][0] = EOS;
    PlayerData[playerid][pLogged]     = false;
    PlayerData[playerid][pRegistered] = false;
    PlayerData[playerid][pOnDuty]     = false;
    PlayerData[playerid][pDiseased]       = false;
    PlayerData[playerid][pDiseasePaydays] = 0;
    PlayerData[playerid][pCaravanKey]      = 0;
    PlayerData[playerid][pIsPresident]  = false;
    PlayerData[playerid][pVoted]        = false;
    PlayerData[playerid][pWasPresident] = false;
    PlayerData[playerid][pJob]          = 0;
    g_IsWorking[playerid]      = false;
    g_JobStage[playerid]       = JOB_STAGE_NONE;
    g_JobVehicle[playerid]     = INVALID_VEHICLE_ID;
    g_JobReturnTimer[playerid] = -1;
    g_UberOnDuty[playerid]     = false;
    g_UberFare[playerid]       = 0;
    g_UberVehicle[playerid]    = INVALID_VEHICLE_ID;
    g_UberPassenger[playerid]  = INVALID_PLAYER_ID;
    g_UberWantsRide[playerid]  = false;
    g_UberDriver[playerid]     = INVALID_PLAYER_ID;
    g_UberRideActive[playerid] = false;
    g_UberChargeTimer[playerid] = -1;
    g_PlayerDrugs[playerid]    = 0;
    g_DrugStage[playerid]      = DRUG_STAGE_NONE;
    g_DrugPartner[playerid]    = INVALID_PLAYER_ID;
    g_BusLine[playerid]        = 0;
    g_BusCP[playerid]          = 0;
    PlayerData[playerid][pPhoneModel]  = -1;
    PlayerData[playerid][pPhoneNumber] = 0;
    PlayerData[playerid][pMedkits]       = 0;
    PlayerData[playerid][pExtinguishers] = 0;
    PlayerData[playerid][pMuteExpire]    = 0;
    PlayerData[playerid][pWanted]        = 0;
    PlayerData[playerid][pJailSeconds]   = 0;
    g_HasSavedPos[playerid]      = false;
    g_NewspaperCreated[playerid] = false;
    g_HasNewspaper[playerid]     = false;
    g_NewsOfferSeller[playerid]  = INVALID_PLAYER_ID;
    g_NewsOfferAmount[playerid]  = 0;
    g_PhoneCallPartner[playerid] = INVALID_PLAYER_ID;
    g_PhoneCallActive[playerid]  = false;
    g_PhoneCallCaller[playerid]  = false;
    g_PhoneRingTimer[playerid]   = -1;
    g_PhoneCallTimer[playerid]   = -1;
    g_PhonePendingSim[playerid]  = 0;
    PlayerData[playerid][pPass][0]    = EOS;
    PlayerData[playerid][pEmail][0]   = EOS;

    GetPlayerName(playerid, PlayerData[playerid][pName], 24);
    AC_SetVW(playerid, -1);

    GameTextForPlayer(playerid, "~g~Welcome to\n~y~Old is Gold", 5000, 5);

    Turfs_ShowToPlayer(playerid);
    ServerClock_ShowToPlayer(playerid);

    Player_CheckExists(playerid);
    Ban_Check(playerid);
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
        new colorcode[9], fname[45];
        if(fid > 0 && fid <= MAX_FACTIONS)
        {
            GetFactionColorCode(fid, colorcode, sizeof(colorcode));
            format(fname, sizeof(fname), "%s%s (%d)"C_WHITE, colorcode, FactionData[fid][fName], PlayerData[playerid][pFactionRank]);
        }
        else fname = "No faction";

        new jobName[32];
        if(PlayerData[playerid][pJob] >= 1 && PlayerData[playerid][pJob] <= MAX_JOBS)
            format(jobName, sizeof(jobName), "%s", g_JobNames[PlayerData[playerid][pJob] - 1]);
        else
            jobName = "Unemployed";

        SendClientMessage(playerid, COLOR_INFO, "\n\n__ Stats _____________________________________________________");
        format(line, sizeof(line), "[Account] Name: %s | Email: %s | Level: %d | RP: %d | Faction: %s | Job: %s",
            PlayerData[playerid][pName],
            email,
            PlayerData[playerid][pLevel],
            PlayerData[playerid][pRP],
            fname,
            jobName
        );
        SendClientMessage(playerid, COLOR_WHITE, line);

        new houseText[12], bizText[12], caravanText[12], farmText[12];
        if(PlayerData[playerid][pBusiness] != 0) format(bizText, sizeof(bizText), "%d", PlayerData[playerid][pBusiness]);
        else format(bizText, sizeof(bizText), "None");

        if(PlayerData[playerid][pHouse] != 0) format(houseText, sizeof(houseText), "%d", PlayerData[playerid][pHouse]);
        else format(houseText, sizeof(houseText), "None");

        if(PlayerData[playerid][pCaravanKey] != 0) format(caravanText, sizeof(caravanText), "%d", PlayerData[playerid][pCaravanKey]);
        else format(caravanText, sizeof(caravanText), "None");

        if(PlayerData[playerid][pFarmKey] != 0) format(farmText, sizeof(farmText), "%d", PlayerData[playerid][pFarmKey]);
        else format(farmText, sizeof(farmText), "None");

        format(line, sizeof(line), "[Finance] Cash: $%s | Bank: $%s | Vehicles: %d, %d, %d | House: %d | Business: %d | Caravan: %d | Farm: %d",
            MoneyStr(PlayerData[playerid][pMoney]),
            MoneyStr(PlayerData[playerid][pBank]),
            PlayerData[playerid][pKey1],
            PlayerData[playerid][pKey2],
            PlayerData[playerid][pKey3],
            houseText,
            bizText,
            caravanText,
            farmText
            );
        SendClientMessage(playerid, COLOR_WHITE, line);

        // Telefon: marca + numar (sau "None" daca nu are telefon / SIM)
        new phoneInfo[48];
        if(Phone_HasPhone(playerid))
        {
            new pbr[24];
            Phone_GetBrand(playerid, pbr, sizeof(pbr));
            if(PlayerData[playerid][pPhoneNumber] > 0)
                format(phoneInfo, sizeof(phoneInfo), "%s (%d)", pbr, PlayerData[playerid][pPhoneNumber]);
            else
                format(phoneInfo, sizeof(phoneInfo), "%s (no SIM)", pbr);
        }
        else phoneInfo = "None";

        // Business, boala, inchisoare, rulota, ferma, mut
        new disTxt[24], jailTxt[16], muteTxt[24], mkTxt[4], exTxt[4];

        if(PlayerData[playerid][pDiseased]) format(disTxt, sizeof(disTxt), "Yes (%d paydays)", PlayerData[playerid][pDiseasePaydays]);
        else format(disTxt, sizeof(disTxt), "No");

        if(PlayerData[playerid][pJailSeconds] > 0) format(jailTxt, sizeof(jailTxt), "%ds", PlayerData[playerid][pJailSeconds]);
        else format(jailTxt, sizeof(jailTxt), "No");

        new muteRemain = PlayerData[playerid][pMuteExpire] - gettime();
        if(muteRemain > 0) format(muteTxt, sizeof(muteTxt), "Yes (%d min)", (muteRemain + 59) / 60);
        else format(muteTxt, sizeof(muteTxt), "No");

        YesNoText(PlayerData[playerid][pMedkits] > 0, mkTxt);
        YesNoText(PlayerData[playerid][pExtinguishers] > 0, exTxt);

        format(line, sizeof(line), "[Other] Phone: %s | Disease: %s | Wanted: %d | Jail: %s | Muted: %s | Medical kit: %s | Extinguisher: %s",
            phoneInfo, disTxt, PlayerData[playerid][pWanted], jailTxt, muteTxt, mkTxt, exTxt);
        SendClientMessage(playerid, COLOR_WHITE, line);


        if(PlayerData[playerid][pAdminLevel] > 0)
        {
            format(line, sizeof(line), "Admin level: %d",
                PlayerData[playerid][pAdminLevel]);
            SendClientMessage(playerid, COLOR_WHITE, line);
        }

        return 1;
    }

    // ---- /report [text] (max 2 reporturi deschise; persistat in DB) ----
    if(strcmp(cmd, "/report", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new rtext[128];
        strmid(rtext, cmdtext, idx, strlen(cmdtext), 128);
        if(!strlen(rtext))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/report [text]"C_WHITE"."), 1;

        // verifica limita de reporturi deschise (async), apoi insereaza in OnReportSubmit
        new q[128];
        mysql_format(g_SQL, q, sizeof(q), "SELECT COUNT(*) AS c FROM `reports` WHERE `playerDbId`=%d AND `status`=0", PlayerData[playerid][pID]);
        mysql_tquery(g_SQL, q, "OnReportSubmit", "is", playerid, rtext);
        return 1;
    }

    // ---- /reports (admin 1+: dialog cu reporturile deschise) ----
    if(strcmp(cmd, "/reports", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;
        if(PlayerData[playerid][pAdminLevel] < 1)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have access. Requires admin level 1."), 1;

        Reports_ShowList(playerid);
        return 1;
    }

    // ---- /reportreply [repID] [text] (admin 1+ raspunde; reportul e sters dupa livrare) ----
    if(strcmp(cmd, "/reportreply", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;
        if(PlayerData[playerid][pAdminLevel] < 1)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have access. Requires admin level 1."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new rrp1[8];
        strmid(rrp1, cmdtext, idx, strlen(cmdtext), 8);
        if(!strlen(rrp1))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/reportreply [repID] [text]"C_WHITE"."), 1;

        new rrid = strval(rrp1);
        while(cmdtext[idx] > ' ') idx++;   // sari peste repID
        while(cmdtext[idx] == ' ') idx++;  // sari peste spatii
        new rrtext[128];
        strmid(rrtext, cmdtext, idx, strlen(cmdtext), 128);
        if(!strlen(rrtext))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/reportreply [repID] [text]"C_WHITE"."), 1;

        new q[160];
        mysql_format(g_SQL, q, sizeof(q), "SELECT `status`,`playerDbId`,`playerName` FROM `reports` WHERE `repID`=%d", rrid);
        mysql_tquery(g_SQL, q, "OnReportReplyLookup", "iis", playerid, rrid, rrtext);
        return 1;
    }

    // ---- /deposit <suma> (cash -> bank, la ATM) ----
    if(strcmp(cmd, "/deposit", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        new atmIdx = ATM_FindNearbyIndex(playerid);
        if(atmIdx == -1)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be near an ATM."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new dStr[12];
        strmid(dStr, cmdtext, idx, strlen(cmdtext), 12);
        if(!strlen(dStr))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/deposit <amount>"C_WHITE" (max $100,000)."), 1;

        new amount = strval(dStr);
        if(amount < ATM_MIN_TRANSACTION)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Minimum "C_INFO"$100"C_WHITE" per transaction."), 1;
        if(amount > ATM_MAX_TRANSACTION)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Maximum "C_INFO"$100,000"C_WHITE" per transaction."), 1;
        if(PlayerData[playerid][pMoney] < amount)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have that much cash."), 1;

        new fee = ATM_DEPOSIT_BASE + amount / 1000; // 90$ + 0.001 * suma
        if(amount <= fee)
        {
            new fmsg[128];
            format(fmsg, sizeof(fmsg), C_ERROR"Error: "C_WHITE"Amount too small to cover the fee ("C_INFO"$%s"C_WHITE").", MoneyStr(fee));
            return SendClientMessage(playerid, COLOR_ERROR, fmsg), 1;
        }

        new credited = amount - fee;
        PlayerData[playerid][pMoney] -= amount;
        GivePlayerMoney(playerid, -amount);
        PlayerData[playerid][pBank]  += credited;
        UpdatePlayer(playerid, pMoney);
        UpdatePlayer(playerid, pBank);

        // 10% din taxa merge in banca business-ului care detine ATM-ul
        new bankCut = floatround(fee * 10.0 / 100.0);
        if(bankCut > 0) Job_AddBizIncome(ATMData[atmIdx][atmBankOwner], bankCut);

        new dmsg[144];
        format(dmsg, sizeof(dmsg), C_SUCCESS"[Bank] "C_WHITE"Deposited "C_SUCCESS"$%s"C_WHITE" (fee "C_ERROR"$%s"C_WHITE"). New balance: "C_SUCCESS"$%s",
            MoneyStr(credited), MoneyStr(fee), MoneyStr(PlayerData[playerid][pBank]));
        SendClientMessage(playerid, COLOR_SUCCESS, dmsg);
        return 1;
    }

    // ---- /withdraw <suma> (bank -> cash, la ATM) ----
    if(strcmp(cmd, "/withdraw", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        new atmIdx = ATM_FindNearbyIndex(playerid);
        if(atmIdx == -1)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be near an ATM."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new wStr[12];
        strmid(wStr, cmdtext, idx, strlen(cmdtext), 12);
        if(!strlen(wStr))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/withdraw <amount>"C_WHITE" (max $100,000)."), 1;

        new amount = strval(wStr);
        if(amount < ATM_MIN_TRANSACTION)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Minimum "C_INFO"$100"C_WHITE" per transaction."), 1;
        if(amount > ATM_MAX_TRANSACTION)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Maximum "C_INFO"$100,000"C_WHITE" per transaction."), 1;
        if(PlayerData[playerid][pBank] < amount)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have that much in the bank."), 1;

        new fee = ATM_WITHDRAW_BASE + amount / 1000; // 110$ + 0.001 * suma
        if(amount <= fee)
        {
            new fmsg[128];
            format(fmsg, sizeof(fmsg), C_ERROR"Error: "C_WHITE"Amount too small to cover the fee ("C_INFO"$%s"C_WHITE").", MoneyStr(fee));
            return SendClientMessage(playerid, COLOR_ERROR, fmsg), 1;
        }

        new given = amount - fee;
        PlayerData[playerid][pBank]  -= amount;
        PlayerData[playerid][pMoney] += given;
        GivePlayerMoney(playerid, given);
        UpdatePlayer(playerid, pMoney);
        UpdatePlayer(playerid, pBank);

        // 10% din taxa merge in banca business-ului care detine ATM-ul
        new bankCut = floatround(fee * 10.0 / 100.0);
        if(bankCut > 0) Job_AddBizIncome(ATMData[atmIdx][atmBankOwner], bankCut);

        new wmsg[144];
        format(wmsg, sizeof(wmsg), C_SUCCESS"[Bank] "C_WHITE"Withdrew "C_SUCCESS"$%s"C_WHITE" (fee "C_ERROR"$%s"C_WHITE"). New balance: "C_SUCCESS"$%s",
            MoneyStr(given), MoneyStr(fee), MoneyStr(PlayerData[playerid][pBank]));
        SendClientMessage(playerid, COLOR_SUCCESS, wmsg);
        return 1;
    }

    // ---- /mybank [farm/house/biz] [deposit/withdraw] [amount] (conturile proprietatilor, la banca/ATM) ----
    if(strcmp(cmd, "/mybank", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;
        if(ATM_FindNearbyIndex(playerid) == -1)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"[Bank] "C_WHITE"You must be near a bank or ATM."), 1;

        new mbl[128];
        while(cmdtext[idx] == ' ') idx++;
        new mbtype[10], mbt = 0;
        while(cmdtext[idx] > ' ' && mbt < 9) { mbtype[mbt++] = cmdtext[idx]; idx++; }
        mbtype[mbt] = EOS;

        // fara argument -> arata soldurile
        if(!strlen(mbtype))
        {
            SendClientMessage(playerid, COLOR_INFO, C_INFO"_____ Property Accounts ____________________");
            if(PlayerData[playerid][pFarmKey] != 0)
            {
                new fi = Farm_IndexByID(PlayerData[playerid][pFarmKey]);
                if(fi != -1) { format(mbl, sizeof(mbl), C_WHITE"Farm #%d: "C_INFO"$%s", FarmData[fi][fmID], MoneyStr(FarmData[fi][fmBank])); SendClientMessage(playerid, COLOR_WHITE, mbl); }
            }
            if(PlayerData[playerid][pHouse] != 0)
            {
                new hi = Houses_FindByID(PlayerData[playerid][pHouse]);
                if(hi != -1) { format(mbl, sizeof(mbl), C_WHITE"House (%s): "C_INFO"$%s", HouseData[hi][hName], MoneyStr(HouseData[hi][hBank])); SendClientMessage(playerid, COLOR_WHITE, mbl); }
            }
            if(PlayerData[playerid][pBusiness] != 0)
            {
                new bi = Businesses_FindByID(PlayerData[playerid][pBusiness]);
                if(bi != -1) { format(mbl, sizeof(mbl), C_WHITE"Business (%s): "C_INFO"$%s", BusinessData[bi][bName], MoneyStr(BusinessData[bi][bBank])); SendClientMessage(playerid, COLOR_WHITE, mbl); }
            }
            SendClientMessage(playerid, COLOR_INFO, C_INFO"Use "C_WHITE"/mybank [farm/house/biz] [deposit/withdraw] [amount]");
            return 1;
        }

        // parseaza actiunea + suma
        while(cmdtext[idx] == ' ') idx++;
        new mbact[12], mba = 0;
        while(cmdtext[idx] > ' ' && mba < 11) { mbact[mba++] = cmdtext[idx]; idx++; }
        mbact[mba] = EOS;
        while(cmdtext[idx] == ' ') idx++;
        new mbamtS[16];
        strmid(mbamtS, cmdtext, idx, strlen(cmdtext), 16);
        new mbamt = strval(mbamtS);

        new bool:dep = (strcmp(mbact, "deposit", true) == 0);
        if(!dep && strcmp(mbact, "withdraw", true) != 0)
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/mybank [farm/house/biz] [deposit/withdraw] [amount]"C_WHITE"."), 1;
        if(mbamt <= 0)
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/mybank [farm/house/biz] [deposit/withdraw] [amount]"C_WHITE"."), 1;

        if(strcmp(mbtype, "farm", true) == 0)
        {
            if(PlayerData[playerid][pFarmKey] == 0)
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"[Bank] "C_WHITE"You don't own a farm."), 1;
            new fi = Farm_IndexByID(PlayerData[playerid][pFarmKey]);
            if(fi == -1) return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"[Bank] "C_WHITE"Farm not found."), 1;
            if(!Prop_BankTransfer(playerid, FarmData[fi][fmBank], dep, mbamt)) return 1;
            Farm_Save(fi);
            format(mbl, sizeof(mbl), C_SUCCESS"[Bank] "C_WHITE"Farm bank now: "C_INFO"$%s"C_WHITE".", MoneyStr(FarmData[fi][fmBank]));
            SendClientMessage(playerid, COLOR_SUCCESS, mbl);
            return 1;
        }
        else if(strcmp(mbtype, "house", true) == 0)
        {
            if(PlayerData[playerid][pHouse] == 0)
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"[Bank] "C_WHITE"You don't own a house."), 1;
            new hi = Houses_FindByID(PlayerData[playerid][pHouse]);
            if(hi == -1) return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"[Bank] "C_WHITE"House not found."), 1;
            if(!Prop_BankTransfer(playerid, HouseData[hi][hBank], dep, mbamt)) return 1;
            new q[96];
            mysql_format(g_SQL, q, sizeof(q), "UPDATE `houses` SET `bank`=%d WHERE `id`=%d", HouseData[hi][hBank], HouseData[hi][hID]);
            mysql_tquery(g_SQL, q, "", "", 0);
            format(mbl, sizeof(mbl), C_SUCCESS"[Bank] "C_WHITE"House bank now: "C_INFO"$%s"C_WHITE".", MoneyStr(HouseData[hi][hBank]));
            SendClientMessage(playerid, COLOR_SUCCESS, mbl);
            return 1;
        }
        else if(strcmp(mbtype, "biz", true) == 0 || strcmp(mbtype, "business", true) == 0)
        {
            if(PlayerData[playerid][pBusiness] == 0)
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"[Bank] "C_WHITE"You don't own a business."), 1;
            new bi = Businesses_FindByID(PlayerData[playerid][pBusiness]);
            if(bi == -1) return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"[Bank] "C_WHITE"Business not found."), 1;
            if(!Prop_BankTransfer(playerid, BusinessData[bi][bBank], dep, mbamt)) return 1;
            new q[96];
            mysql_format(g_SQL, q, sizeof(q), "UPDATE `businesses` SET `bank`=%d WHERE `id`=%d", BusinessData[bi][bBank], BusinessData[bi][bID]);
            mysql_tquery(g_SQL, q, "", "", 0);
            format(mbl, sizeof(mbl), C_SUCCESS"[Bank] "C_WHITE"Business bank now: "C_INFO"$%s"C_WHITE".", MoneyStr(BusinessData[bi][bBank]));
            SendClientMessage(playerid, COLOR_SUCCESS, mbl);
            return 1;
        }
        return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/mybank [farm/house/biz] [deposit/withdraw] [amount]"C_WHITE"."), 1;
    }

    // ---- /shop (Medical Kit / Extinctor / Phone) ----
    if(strcmp(cmd, "/shop", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;
        if(!Shop_PlayerInRange(playerid))
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be at a "C_INFO"Shop"C_WHITE" to do this."), 1;

        new dlg[220];
        format(dlg, sizeof(dlg), ""C_INFO"Item\t"C_INFO"Price\n"C_WHITE"Medical Kit\t"C_SUCCESS"$%s\n"C_WHITE"Extinctor\t"C_SUCCESS"$%s\n"C_WHITE"Phone\t"C_INFO"Next",
            MoneyStr(g_MedkitPrice), MoneyStr(g_ExtinguisherPrice));
        ShowPlayerDialog(playerid, DIALOG_SHOP, DIALOG_STYLE_TABLIST_HEADERS, "Shop", dlg, "Select", "Close");
        return 1;
    }

    // ---- /v install [medicalkit/extinctor] (aplica un act din inventar pe vehiculul curent) ----
    if(strcmp(cmd, "/v", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        new sub[256];
        sub = strtok(cmdtext, idx);
        if(strcmp(sub, "install", true) != 0)
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/v install [medicalkit/extinctor]"C_WHITE"."), 1;

        new what[256];
        what = strtok(cmdtext, idx);
        new bool:isMed = (strcmp(what, "medicalkit", true) == 0);
        new bool:isExt = (strcmp(what, "extinctor", true) == 0);
        if(!isMed && !isExt)
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/v install [medicalkit/extinctor]"C_WHITE"."), 1;

        new vehid = GetPlayerVehicleID(playerid);
        if(vehid == 0)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be in a vehicle."), 1;
        new pvidx = g_VehicleToPVIndex[vehid];
        if(pvidx == -1)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"This is not a personal vehicle."), 1;
        if(PVehicleData[pvidx][pvOwnerId] != PlayerData[playerid][pID])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't own this vehicle."), 1;

        if(isMed)
        {
            if(PlayerData[playerid][pMedkits] <= 0)
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have any medical kit. Buy one with "C_INFO"/shop"C_WHITE"."), 1;
            if(VehicleDoc_IsValid(PVehicleData[pvidx][pvMedkitExp]))
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"The medical kit is still valid."), 1;

            PlayerData[playerid][pMedkits]--;
            UpdatePlayer(playerid, pMedkits);

            PVehicleData[pvidx][pvMedkitExp] = gettime() + VEHICLE_MEDKIT_DURATION;
            new dateStr[11];
            UnixToDateStr(PVehicleData[pvidx][pvMedkitExp], dateStr, sizeof(dateStr));
            new q[128];
            mysql_format(g_SQL, q, sizeof(q), "UPDATE `vehicles_personal` SET `medkit_exp`='%s' WHERE `id`=%d", dateStr, PVehicleData[pvidx][pvID]);
            mysql_tquery(g_SQL, q, "", "", 0);

            new m[144];
            format(m, sizeof(m), C_SUCCESS"Success: "C_WHITE"You installed a medical kit ("C_INFO"7 days"C_WHITE"). You have "C_INFO"%d"C_WHITE" left.", PlayerData[playerid][pMedkits]);
            SendClientMessage(playerid, COLOR_SUCCESS, m);
        }
        else // isExt
        {
            if(PlayerData[playerid][pExtinguishers] <= 0)
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have any extinguisher. Buy one with "C_INFO"/shop"C_WHITE"."), 1;
            if(VehicleDoc_IsValid(PVehicleData[pvidx][pvExtinguisherExp]))
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"The extinguisher is still valid."), 1;

            PlayerData[playerid][pExtinguishers]--;
            UpdatePlayer(playerid, pExtinguishers);

            PVehicleData[pvidx][pvExtinguisherExp] = gettime() + VEHICLE_EXTINGUISHER_DURATION;
            new dateStr[11];
            UnixToDateStr(PVehicleData[pvidx][pvExtinguisherExp], dateStr, sizeof(dateStr));
            new q[128];
            mysql_format(g_SQL, q, sizeof(q), "UPDATE `vehicles_personal` SET `extinguisher_exp`='%s' WHERE `id`=%d", dateStr, PVehicleData[pvidx][pvID]);
            mysql_tquery(g_SQL, q, "", "", 0);

            new m[144];
            format(m, sizeof(m), C_SUCCESS"Success: "C_WHITE"You installed an extinguisher ("C_INFO"10 days"C_WHITE"). You have "C_INFO"%d"C_WHITE" left.", PlayerData[playerid][pExtinguishers]);
            SendClientMessage(playerid, COLOR_SUCCESS, m);
        }
        return 1;
    }

    // ---- /buysim (primeste un numar de telefon aleatoriu, unic) ----
    if(strcmp(cmd, "/buysim", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;
        if(!Phone_HasPhone(playerid))
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You need a phone. Use "C_INFO"/shop"C_WHITE" (Phone)."), 1;
        if(PlayerData[playerid][pMoney] < PHONE_SIM_PRICE)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have enough money for a SIM ("C_INFO"$250"C_WHITE")."), 1;

        Phone_RequestSim(playerid);
        SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Searching for an available phone number...");
        return 1;
    }

    // ---- /call [numar] (suna un jucator online dupa numarul lui de telefon) ----
    if(strcmp(cmd, "/call", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;
        if(!Phone_HasPhone(playerid))
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You need a phone. Use "C_INFO"/shop"C_WHITE" (Phone)."), 1;
        if(!Phone_HasSim(playerid))
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You need a SIM. Use "C_INFO"/buysim"C_WHITE"."), 1;
        if(g_PhoneCallPartner[playerid] != INVALID_PLAYER_ID)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You are already in a call. Use "C_INFO"/hangup"C_WHITE"."), 1;

        new ns[256];
        ns = strtok(cmdtext, idx);
        if(!strlen(ns))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/call [number]"C_WHITE"."), 1;

        new number = strval(ns);
        new target = Phone_FindByNumber(number);
        if(target == INVALID_PLAYER_ID)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"That number is unavailable or the player isn't online."), 1;
        // [TEMP-SELF] permite auto-apelul pentru testare (de scos)
        // if(target == playerid)
        //     return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You can't call yourself."), 1;
        if(g_PhoneCallPartner[target] != INVALID_PLAYER_ID)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"The number is currently busy."), 1;

        g_PhoneCallPartner[playerid] = target;
        g_PhoneCallCaller[playerid]  = true;
        g_PhoneCallActive[playerid]  = false;
        g_PhoneCallPartner[target]   = playerid;
        g_PhoneCallCaller[target]    = false;
        g_PhoneCallActive[target]    = false;
        g_PhoneRingTimer[playerid]   = SetTimerEx("Phone_RingTimeout", PHONE_CALL_RING_TIMEOUT * 1000, false, "i", playerid);

        new sBrand[24], tBrand[24];
        Phone_GetBrand(playerid, sBrand, sizeof(sBrand));
        Phone_GetBrand(target,   tBrand, sizeof(tBrand));

        new m[260];
        format(m, sizeof(m), C_INFO"[%s]: "C_WHITE"You called "C_INFO"%s"C_WHITE"("C_INFO"%05d"C_WHITE"), wait for an answer.",
            sBrand, PlayerData[target][pName], PlayerData[target][pPhoneNumber]);
        SendClientMessage(playerid, COLOR_WHITE, m);

        format(m, sizeof(m), C_INFO"[%s]: "C_INFO"%s"C_WHITE"("C_INFO"%05d"C_WHITE") "C_WHITE"is calling you. To answer, use "C_INFO"/pickup"C_WHITE".",
            tBrand, PlayerData[playerid][pName], PlayerData[playerid][pPhoneNumber]);
        SendClientMessage(target, COLOR_WHITE, m);
        return 1;
    }

    // ---- /pickup (raspunde la un apel primit) ----
    if(strcmp(cmd, "/pickup", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;
        if(g_PhoneCallPartner[playerid] == INVALID_PLAYER_ID)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You have no incoming call."), 1;
        if(g_PhoneCallActive[playerid])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You are already in a call."), 1;
        if(g_PhoneCallCaller[playerid])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You started the call; wait for the other person to answer."), 1;

        new caller = g_PhoneCallPartner[playerid];
        g_PhoneCallActive[playerid] = true;
        g_PhoneCallActive[caller]   = true;
        if(g_PhoneRingTimer[caller] != -1) { KillTimer(g_PhoneRingTimer[caller]); g_PhoneRingTimer[caller] = -1; }
        // initiatorul (caller) plateste taxarea pe durata apelului
        g_PhoneCallTimer[caller] = SetTimerEx("Phone_CallCharge", PHONE_CALL_CHARGE_INTERVAL * 1000, true, "i", caller);

        new sBrand[24], cBrand[24];
        Phone_GetBrand(playerid, sBrand, sizeof(sBrand));
        Phone_GetBrand(caller,   cBrand, sizeof(cBrand));

        new m[160];
        format(m, sizeof(m), C_INFO"[%s]: "C_WHITE"Call started with "C_INFO"%s"C_WHITE"("C_INFO"%05d"C_WHITE"). Use "C_INFO"/hangup"C_WHITE" to end it.",
            sBrand, PlayerData[caller][pName], PlayerData[caller][pPhoneNumber]);
        SendClientMessage(playerid, COLOR_WHITE, m);

        format(m, sizeof(m), C_INFO"[%s]: "C_WHITE"Call started with "C_INFO"%s"C_WHITE"("C_INFO"%05d"C_WHITE"). Use "C_INFO"/hangup"C_WHITE" to end it.",
            cBrand, PlayerData[playerid][pName], PlayerData[playerid][pPhoneNumber]);
        SendClientMessage(caller, COLOR_WHITE, m);
        return 1;
    }

    // ---- /hangup (inchide apelul curent, fie ca suna sau e activ) ----
    if(strcmp(cmd, "/hangup", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;
        if(g_PhoneCallPartner[playerid] == INVALID_PLAYER_ID)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You are not in a call."), 1;

        new partner = g_PhoneCallPartner[playerid];
        new sBrand[24], pBrand[24];
        Phone_GetBrand(playerid, sBrand, sizeof(sBrand));
        if(partner != INVALID_PLAYER_ID) Phone_GetBrand(partner, pBrand, sizeof(pBrand)); else format(pBrand, sizeof(pBrand), "Phone");

        new selfMsg[144], partnerMsg[144];
        format(selfMsg,    sizeof(selfMsg),    C_INFO"[%s]: "C_WHITE"You ended the call.", sBrand);
        format(partnerMsg, sizeof(partnerMsg), C_INFO"[%s]: "C_WHITE"The other party ended the call.", pBrand);
        Phone_EndCall(playerid, selfMsg, partnerMsg);
        return 1;
    }

    // ---- /sms [numar] [mesaj] ----
    if(strcmp(cmd, "/sms", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;
        if(!Phone_HasPhone(playerid))
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You need a phone. Use "C_INFO"/shop"C_WHITE" (Phone)."), 1;
        if(!Phone_HasSim(playerid))
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You need a SIM. Use "C_INFO"/buysim"C_WHITE"."), 1;

        new ns[256];
        ns = strtok(cmdtext, idx);
        while(cmdtext[idx] == ' ') idx++;
        new text[128];
        strmid(text, cmdtext, idx, strlen(cmdtext), 128);

        if(!strlen(ns) || !strlen(text))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/sms [number] [message]"C_WHITE"."), 1;

        new number = strval(ns);
        new target = Phone_FindByNumber(number);
        if(target == INVALID_PLAYER_ID)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"That number is unavailable or the player isn't online."), 1;
        // [TEMP-SELF] permite auto-SMS pentru testare (de scos)
        // if(target == playerid)
        //     return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You can't text yourself."), 1;
        if(PlayerData[playerid][pMoney] < PHONE_SMS_PRICE)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have enough money ("C_INFO"$5"C_WHITE")."), 1;

        PlayerData[playerid][pMoney] -= PHONE_SMS_PRICE;
        GivePlayerMoney(playerid, -PHONE_SMS_PRICE);
        UpdatePlayer(playerid, pMoney);

        new cut = Phone_CarrierCut(PHONE_SMS_PRICE);
        if(cut > 0) Job_AddBizIncome(PHONE_CARRIER_BIZ_ID, cut);

        new sBrand[24], tBrand[24];
        Phone_GetBrand(playerid, sBrand, sizeof(sBrand));
        Phone_GetBrand(target,   tBrand, sizeof(tBrand));

        new m[356];
        format(m, sizeof(m), C_INFO"[%s]: "C_WHITE"SMS to "C_INFO"%s"C_WHITE"("C_INFO"%05d"C_WHITE"): %s",
            sBrand, PlayerData[target][pName], PlayerData[target][pPhoneNumber], text);
        SendClientMessage(playerid, COLOR_WHITE, m);

        format(m, sizeof(m), C_INFO"[%s]: ""{FFFF00}""SMS from "C_WHITE"%s("C_INFO"%05d"C_WHITE"): "C_WHITE"%s",
            tBrand, PlayerData[playerid][pName], PlayerData[playerid][pPhoneNumber], text);
        SendClientMessage(target, COLOR_WHITE, m);
        return 1;
    }

    // ---- /jobs (lista joburilor disponibile) ----
    if(strcmp(cmd, "/jobs", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        SendClientMessage(playerid, COLOR_INFO, C_INFO"===== Available Jobs =====");
        for(new i = 0; i < MAX_JOBS; i++)
        {
            new line[96];
            format(line, sizeof(line), C_INFO"#%d"C_WHITE". %s", i + 1, g_JobNames[i]);
            if(i + 1 == JOB_TRANSPORT) strcat(line, C_INFO" (WE: 16:00-23:00)");
            SendClientMessage(playerid, COLOR_WHITE, line);
        }
        SendClientMessage(playerid, COLOR_INFO, C_WHITE"Use "C_INFO"/getjob [id or name]"C_WHITE" to take one.");
        return 1;
    }

    // ---- /getjob [id or name] ----
    if(strcmp(cmd, "/getjob", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        if(!Job_AtGetJob(playerid))
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be at the Job Center inside the City Hall to do this."), 1;

        if(PlayerData[playerid][pJob] != 0)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You already have a job. Use "C_INFO"/quitjob"C_WHITE" first."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new jobStr[32];
        strmid(jobStr, cmdtext, idx, strlen(cmdtext), 32);
        if(!strlen(jobStr))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/getjob [id or name]"C_WHITE". See "C_INFO"/jobs"C_WHITE" for the list."), 1;

        new jobId;
        if(jobStr[0] >= '0' && jobStr[0] <= '9')
        {
            jobId = strval(jobStr);
        }
        else
        {
            jobId = Job_FindByName(jobStr);
            if(jobId == -1)
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Unknown job. See "C_INFO"/jobs"C_WHITE" for the list."), 1;
        }

        if(jobId < 1 || jobId > MAX_JOBS)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Invalid job. Choose between 1 and "#MAX_JOBS"."), 1;

        PlayerData[playerid][pJob] = jobId;
        UpdatePlayer(playerid, pJob);

        new jmsg[96];
        format(jmsg, sizeof(jmsg), C_SUCCESS"Success: "C_WHITE"You took job "C_INFO"#%d"C_WHITE".", jobId);
        SendClientMessage(playerid, COLOR_SUCCESS, jmsg);
        return 1;
    }

    // ---- /quitjob ----
    if(strcmp(cmd, "/quitjob", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        if(!Job_AtQuitJob(playerid))
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be at the Job Center inside the City Hall to do this."), 1;

        if(PlayerData[playerid][pJob] == 0)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have a job."), 1;

        if(g_IsWorking[playerid]) Job_StopWork(playerid);  // daca lucra, opreste si munca
        if(g_UberOnDuty[playerid]) Uber_GoOffDuty(playerid); // daca era uber, scoate-l din serviciu

        PlayerData[playerid][pJob] = 0;
        UpdatePlayer(playerid, pJob);

        SendClientMessage(playerid, COLOR_SUCCESS, C_SUCCESS"Success: "C_WHITE"You quit your job.");
        return 1;
    }

    // ---- /setjob [playerid] [jobid] (admin: seteaza jobul unui player, 0 = niciun job) ----
    if(strcmp(cmd, "/setjob", true) == 0)
    {
        if(PlayerData[playerid][pAdminLevel] < 1)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have access. Requires admin level 1."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new sjp[8], sja = 0;
        while(cmdtext[idx] > ' ' && sja < 7) { sjp[sja++] = cmdtext[idx]; idx++; }
        sjp[sja] = EOS;
        while(cmdtext[idx] == ' ') idx++;
        new sjj[8];
        strmid(sjj, cmdtext, idx, strlen(cmdtext), 8);
        if(!strlen(sjp) || !strlen(sjj))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/setjob [playerid] [jobid]"C_WHITE" (0-"#MAX_JOBS")."), 1;

        new targetid = strval(sjp), jobid = strval(sjj);
        if(!IsPlayerConnected(targetid) || !PlayerData[targetid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"The player is not connected."), 1;
        if(jobid < 0 || jobid > MAX_JOBS)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Invalid job. Choose between 0 and "#MAX_JOBS"."), 1;

        if(g_IsWorking[targetid])  Job_StopWork(targetid);   // opreste munca in curs
        if(g_UberOnDuty[targetid]) Uber_GoOffDuty(targetid); // scoate-l din serviciul uber

        PlayerData[targetid][pJob] = jobid;
        UpdatePlayer(targetid, pJob);

        new sjJobName[32];
        if(jobid >= 1 && jobid <= MAX_JOBS) format(sjJobName, sizeof(sjJobName), "%s", g_JobNames[jobid - 1]);
        else format(sjJobName, sizeof(sjJobName), "none");

        new sjmsg[144];
        format(sjmsg, sizeof(sjmsg), C_SUCCESS"[ADM] Success: "C_WHITE"Set "C_INFO"%s"C_WHITE"'s job to "C_INFO"#%d - %s"C_WHITE".",
            PlayerData[targetid][pName], jobid, sjJobName);
        SendClientMessage(playerid, COLOR_SUCCESS, sjmsg);

        if(targetid != playerid)
        {
            format(sjmsg, sizeof(sjmsg), C_INFO"[Job] "C_WHITE"An admin set your job to "C_INFO"#%d - %s"C_WHITE".", jobid, sjJobName);
            SendClientMessage(targetid, COLOR_WHITE, sjmsg);
        }
        return 1;
    }

    // ---- /stopwork (opreste munca curenta) ----
    if(strcmp(cmd, "/stopwork", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        if(g_UberOnDuty[playerid])
        {
            Uber_GoOffDuty(playerid);
            SendClientMessage(playerid, COLOR_SUCCESS, C_SUCCESS"[Uber] "C_WHITE"You went off duty.");
            return 1;
        }

        if(g_BusLine[playerid] > 0)
        {
            Bus_End(playerid);
            SendClientMessage(playerid, COLOR_SUCCESS, C_SUCCESS"[Bus] "C_WHITE"You cancelled your bus route.");
            return 1;
        }

        if(!g_IsWorking[playerid])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You are not working."), 1;

        Job_StopWork(playerid);
        SendClientMessage(playerid, COLOR_SUCCESS, C_SUCCESS"Success: "C_WHITE"You stopped working.");
        return 1;
    }

    // ---- /bus [nr-linie] (Bus Driver: porneste o ruta cu checkpoint-uri) ----
    if(strcmp(cmd, "/bus", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        if(PlayerData[playerid][pJob] != JOB_BUS)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You need the Bus Driver job. Get it with "C_INFO"/getjob bus driver"C_WHITE"."), 1;

        new busVeh = GetPlayerVehicleID(playerid);
        if(busVeh == 0 || GetPlayerState(playerid) != PLAYER_STATE_DRIVER || !Bus_IsBusVehicle(busVeh))
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be driving a bus from the depot."), 1;

        if(g_BusLine[playerid] > 0)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You are already on a route. Use "C_INFO"/stopwork"C_WHITE" to cancel it."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new bl[8];
        strmid(bl, cmdtext, idx, strlen(cmdtext), 8);
        if(!strlen(bl))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/bus [1-"#MAX_BUS_LINES"]"C_WHITE"."), 1;

        new line = strval(bl);
        if(line < 1 || line > MAX_BUS_LINES)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Invalid line. Use "C_INFO"/bus [1-"#MAX_BUS_LINES"]"C_WHITE"."), 1;
        if(g_BusRouteCount[line - 1] == 0)
        {
            new nm[96];
            format(nm, sizeof(nm), C_ERROR"Error: "C_WHITE"Bus line "C_INFO"%d"C_WHITE" is not set up yet.", line);
            return SendClientMessage(playerid, COLOR_ERROR, nm), 1;
        }

        g_BusLine[playerid] = line;
        g_BusCP[playerid]   = 0;

        new Float:px, Float:py, Float:pz;
        GetPlayerPos(playerid, px, py, pz);
        g_BusLastX[playerid] = px;
        g_BusLastY[playerid] = py;

        Bus_SetCheckpoint(playerid);

        new sm[144];
        format(sm, sizeof(sm), C_SUCCESS"[Bus] "C_WHITE"Line "C_INFO"%d"C_WHITE" started ("C_INFO"%d"C_WHITE" stops). Follow the checkpoints; the route loops back to stop 1 at the end.",
            line, g_BusRouteCount[line - 1]);
        SendClientMessage(playerid, COLOR_SUCCESS, sm);
        return 1;
    }

    // ---- /fare [amount] (Uber: intri in serviciu cu masina personala) ----
    if(strcmp(cmd, "/fare", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        if(PlayerData[playerid][pJob] != JOB_UBER)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You need the Uber job. Get it with "C_INFO"/getjob uber"C_WHITE"."), 1;

        new fareVeh = GetPlayerVehicleID(playerid);
        if(fareVeh == 0 || GetPlayerState(playerid) != PLAYER_STATE_DRIVER)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be driving your personal vehicle."), 1;

        new farePv = g_VehicleToPVIndex[fareVeh];
        if(farePv == -1 || PVehicleData[farePv][pvOwnerId] != PlayerData[playerid][pID])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be in your own personal vehicle."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new fareStr[12];
        strmid(fareStr, cmdtext, idx, strlen(cmdtext), 12);
        if(!strlen(fareStr))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/fare [amount]"C_WHITE" (price charged every "#UBER_CHARGE_INTERVAL"s)."), 1;

        new fareAmount = strval(fareStr);
        if(fareAmount <= 0)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Invalid fare amount."), 1;

        g_UberOnDuty[playerid]  = true;
        g_UberFare[playerid]    = fareAmount;
        g_UberVehicle[playerid] = fareVeh;

        new fmsg[160];
        format(fmsg, sizeof(fmsg),
            C_INFO"[Uber] "C_WHITE"%s"C_WHITE" is on duty as an Uber driver, accepting rides for "C_INFO"$%s"C_WHITE"/"#UBER_CHARGE_INTERVAL"s. Use "C_INFO"/service uber"C_WHITE".",
            PlayerData[playerid][pName], MoneyStr(fareAmount));
        SendClientMessageToAll(COLOR_INFO, fmsg);
        return 1;
    }

    // ---- /service [uber] (ceri un serviciu) ----
    if(strcmp(cmd, "/service", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new svc[16];
        strmid(svc, cmdtext, idx, strlen(cmdtext), 16);

        if(strcmp(svc, "uber", true) != 0)
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/service uber"C_WHITE"."), 1;

        if(g_UberDriver[playerid] != INVALID_PLAYER_ID)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You already have an Uber on the way."), 1;

        // numara soferii uber online
        new uberCount = 0;
        for(new i = 0; i < MAX_PLAYERS; i++)
            if(IsPlayerConnected(i) && PlayerData[i][pLogged] && g_UberOnDuty[i] && g_UberPassenger[i] == INVALID_PLAYER_ID)
                uberCount++;

        if(uberCount == 0)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"There are no Uber drivers available right now."), 1;

        g_UberWantsRide[playerid] = true;
        g_UberDriver[playerid]    = INVALID_PLAYER_ID;

        new rmsg[144];
        format(rmsg, sizeof(rmsg), C_INFO"[Uber] "C_WHITE"%s"C_WHITE" needs an Uber! Use "C_INFO"/accept uber"C_WHITE" to take the ride.", PlayerData[playerid][pName]);
        for(new i = 0; i < MAX_PLAYERS; i++)
            if(IsPlayerConnected(i) && PlayerData[i][pLogged] && g_UberOnDuty[i] && g_UberPassenger[i] == INVALID_PLAYER_ID)
                SendClientMessage(i, COLOR_INFO, rmsg);

        SendClientMessage(playerid, COLOR_SUCCESS, C_SUCCESS"[Uber] "C_WHITE"An Uber has been requested. Please wait for a driver.");
        return 1;
    }

    // ---- /job (incepi munca la jobul tau) ----
    if(strcmp(cmd, "/job", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        if(PlayerData[playerid][pJob] == 0)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have a job. Use "C_INFO"/getjob [1-"#MAX_JOBS"]"C_WHITE" first."), 1;

        // TODO: de schimbat distanta de /job (verificare proximitate fata de locatia de munca a fiecarui job)

        switch(PlayerData[playerid][pJob])
        {
            case JOB_GLOVO:     Job_StartWork(playerid);
            case JOB_CEMENT:    Job_StartWork(playerid);
            case JOB_GUN:       Job_StartWork(playerid);
            case JOB_TRANSPORT:
            {
                // [TEMP-TRANSPORTHOURS] jobul se poate face doar Vineri/Sambata/Duminica, 16:00-23:00. Dezactivat temporar (vezi roadmap).
                // if(!Job_TransportWindowOpen())
                //     return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Car transport is only available Fri-Sun, 16:00-23:00."), 1;
                Job_StartWork(playerid);
            }
            case JOB_UBER:      SendClientMessage(playerid, COLOR_INFO, C_INFO"[Uber] "C_WHITE"As an Uber driver, use "C_INFO"/fare [amount]"C_WHITE" in your personal vehicle to go on duty.");
            case JOB_EMERGENCY: Job_StartWork(playerid);
            case JOB_BUS:       SendClientMessage(playerid, COLOR_INFO, C_INFO"[Bus] "C_WHITE"As a Bus Driver, get in a depot bus and use "C_INFO"/bus [1-"#MAX_BUS_LINES"]"C_WHITE" to start a route.");
            case 8:  { /* TODO: implementeaza job 8 */  SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Job 8 is not available yet."); }
            case 9:  { /* TODO: implementeaza job 9 */  SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Job 9 is not available yet."); }
            case 10: { /* TODO: implementeaza job 10 */ SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Job 10 is not available yet."); }
        }
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
                C_INFO"Info: "C_WHITE"Use "C_INFO"/veh [name or model id]"C_WHITE". Ex: "C_INFO"/veh Infernus"C_WHITE" sau "C_INFO"/veh 411"C_WHITE"."), 1;

        new model;
        if(vehname[0] >= '0' && vehname[0] <= '9')
        {
            // argument numeric -> model id direct
            model = strval(vehname);
            if(model < 400 || model > 611)
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Invalid vehicle model (400-611)."), 1;
        }
        else
        {
            model = GetVehicleModelByName(vehname);
            if(model == -1)
            {
                new errmsg[128];
                format(errmsg, sizeof(errmsg), C_ERROR"Error: "C_WHITE"Vehicle \""C_INFO"%s"C_WHITE"\" not found.", vehname);
                return SendClientMessage(playerid, COLOR_ERROR, errmsg), 1;
            }
        }

        new Float:x, Float:y, Float:z, Float:angle;
        GetPlayerPos(playerid, x, y, z);
        GetPlayerFacingAngle(playerid, angle);

        new vehid = CreateVehicle(model, x + 3.0, y, z, angle, -1, -1, -1);
        PutPlayerInVehicle(playerid, vehid, 0);

        new realName[24];
        GetVehicleModelName(model, realName, sizeof(realName));

        new msg[128];
        format(msg, sizeof(msg), C_SUCCESS"[ADM] Success: "C_WHITE"You spawned a "C_INFO"%s"C_WHITE" (model %d).", realName, model);
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
            C_SUCCESS"[ADM] Success: "C_WHITE"All vehicles have been respawned.");
        return 1;
    }

    // ---- /event race/join/start/stop (evenimente race BestLap) ----
    if(strcmp(cmd, "/event", true) == 0)
    {
        new sub[256];
        sub = strtok(cmdtext, idx);
        if(!strlen(sub))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"/event race [lap1/lap2/lap3] [vehicle/random], join, start, stop"), 1;

        // ---- /event race [lap] [vehicle] (admin 2+) ----
        if(strcmp(sub, "race", true) == 0)
        {
            if(PlayerData[playerid][pAdminLevel] < 2)
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have access. Requires admin level 2."), 1;
            if(g_RaceState != RACE_STATE_NONE)
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"A race event is already active. Use "C_INFO"/event stop"C_WHITE" first."), 1;

            new lapStr[256], vehStr[256];
            lapStr = strtok(cmdtext, idx);
            vehStr = strtok(cmdtext, idx);
            if(!strlen(lapStr) || !strlen(vehStr))
                return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/event race [lap1/lap2/lap3] [bullet/infernus/elegy/stratum/nrg/sabre/random]"C_WHITE"."), 1;

            new lap = -1;
            for(new k = 0; k < MAX_RACE_LAPS; k++)
                if(strcmp(lapStr, g_RaceLapName[k], true) == 0) { lap = k; break; }
            if(lap == -1)
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Invalid lap. Use "C_INFO"lap1/lap2/lap3"C_WHITE"."), 1;

            new model = -1;
            if(strcmp(vehStr, "random", true) != 0)
            {
                new vi = -1;
                for(new k = 0; k < RACE_VEH_COUNT; k++)
                    if(strcmp(vehStr, g_RaceVehKey[k], true) == 0) { vi = k; break; }
                if(vi == -1)
                    return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Invalid vehicle. Use "C_INFO"bullet/infernus/elegy/stratum/nrg/sabre/random"C_WHITE"."), 1;
                model = g_RaceVehModels[vi];
            }

            g_RaceState    = RACE_STATE_SIGNUP;
            g_RaceLap      = lap;
            g_RaceVehModel = model;
            g_RaceFinishOrder = 0;
            g_RaceTotal    = 0;
            for(new i = 0; i < MAX_PLAYERS; i++) { g_RaceIn[i] = false; g_RaceDone[i] = false; g_RaceCP[i] = 0; }

            new vlabel[12];
            if(model == -1) format(vlabel, sizeof(vlabel), "Random");
            else            format(vlabel, sizeof(vlabel), "%s", g_RaceVehNames[Race_VehIndex(model)]);

            new bm[160];
            format(bm, sizeof(bm), C_INFO"[Race Event] "C_WHITE"A "C_INFO"%s"C_WHITE" race was opened on "C_INFO"%s"C_WHITE"! Type "C_INFO"/event join"C_WHITE" to enter.",
                vlabel, g_RaceLapName[lap]);
            SendClientMessageToAll(COLOR_INFO, bm);
            return 1;
        }

        // ---- /event join (jucator) ----
        if(strcmp(sub, "join", true) == 0)
        {
            if(!PlayerData[playerid][pLogged])
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;
            if(g_RaceState != RACE_STATE_SIGNUP)
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"There is no race event open to join right now."), 1;
            if(g_RaceIn[playerid])
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You already joined the race event."), 1;

            g_RaceIn[playerid]   = true;
            g_RaceDone[playerid] = false;
            SendClientMessage(playerid, COLOR_SUCCESS, C_SUCCESS"[Race Event] "C_WHITE"You joined the race. Wait for an admin to start it.");
            return 1;
        }

        // ---- /event start (admin 2+) ----
        if(strcmp(sub, "start", true) == 0)
        {
            if(PlayerData[playerid][pAdminLevel] < 2)
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have access. Requires admin level 2."), 1;
            if(g_RaceState != RACE_STATE_SIGNUP)
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"There is no race event waiting to start."), 1;

            new count = 0;
            for(new i = 0; i < MAX_PLAYERS; i++)
                if(g_RaceIn[i] && IsPlayerConnected(i)) count++;
            if(count < 1)
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Nobody joined the event yet."), 1;

            g_RaceState       = RACE_STATE_RUNNING;
            g_RaceFinishOrder = 0;
            g_RaceTotal       = count;

            // Daca a fost "random", se alege UN singur model, comun tuturor participantilor
            new eventModel = (g_RaceVehModel != -1) ? g_RaceVehModel : g_RaceVehModels[random(RACE_VEH_COUNT)];

            new Float:sx = g_RaceRoute[g_RaceLap][0][0];
            new Float:sy = g_RaceRoute[g_RaceLap][0][1];
            new Float:sz = g_RaceRoute[g_RaceLap][0][2];
            new Float:sa = g_RaceStartA[g_RaceLap];

            for(new i = 0; i < MAX_PLAYERS; i++)
            {
                if(!g_RaceIn[i] || !IsPlayerConnected(i)) continue;

                g_RaceVehUsed[i] = eventModel;

                new veh = CreateVehicle(eventModel, sx, sy, sz, sa, random(256), random(256), -1);
                SetVehicleVirtualWorld(veh, RACE_VW_BASE + i);
                LinkVehicleToInterior(veh, 0);
                if(veh >= 0 && veh < MAX_VEHICLES) g_VehicleFuel[veh] = FUEL_MAX;
                g_RaceVehicle[i] = veh;

                // porneste motorul (params -1 nesetati -> engine ON)
                new e, l, al, d, b, bo, o;
                GetVehicleParamsEx(veh, e, l, al, d, b, bo, o);
                SetVehicleParamsEx(veh, 1, l, al, d, b, bo, o);

                AC_SetInterior(i, 0);
                AC_SetVW(i, RACE_VW_BASE + i);
                PutPlayerInVehicle(i, veh, 0);

                g_RaceDone[i] = false;
                g_RaceCP[i]   = 1; // spawn e la CP index 0; prima tinta e index 1
                Race_SetCP(i, g_RaceLap, 1);
                TogglePlayerControllable(i, 0); // freeze pana la GOGOGO
            }

            g_RaceCountdown = RACE_COUNTDOWN_SEC;
            Race_CountdownTick();

            if(g_RaceTimeoutTimer != -1) KillTimer(g_RaceTimeoutTimer);
            g_RaceTimeoutTimer = SetTimer("Race_Timeout", RACE_TIMEOUT_MS, false);

            new startMsg[128];
            format(startMsg, sizeof(startMsg), C_INFO"[Race Event] "C_WHITE"The race is starting on "C_INFO"%s"C_WHITE" with the "C_INFO"%s"C_WHITE"!",
                g_RaceLapName[g_RaceLap], g_RaceVehNames[Race_VehIndex(eventModel)]);
            SendClientMessageToAll(COLOR_INFO, startMsg);
            return 1;
        }

        // ---- /event stop (admin 2+) ----
        if(strcmp(sub, "stop", true) == 0)
        {
            if(PlayerData[playerid][pAdminLevel] < 2)
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have access. Requires admin level 2."), 1;
            if(g_RaceState == RACE_STATE_NONE)
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"There is no active race event."), 1;
            Race_End(true);
            return 1;
        }

        return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"/event race [lap1/lap2/lap3] [vehicle/random], join, start, stop"), 1;
    }

    // ---- /hunt (ia sniperul de vanatoare, la spotul de hunting) ----
    if(strcmp(cmd, "/hunt", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;
        if(!IsPlayerInRangeOfPoint(playerid, HUNT_START_RANGE, g_HuntStartX, g_HuntStartY, g_HuntStartZ))
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"[Hunt] "C_WHITE"You must be at the hunting spot to start (see the map icon in the forest)."), 1;

        AC_GiveWeapon(playerid, HUNT_SNIPER, HUNT_SNIPER_AMMO);
        g_HasSniper[playerid] = true;
        SendClientMessage(playerid, COLOR_SUCCESS, C_SUCCESS"[Hunt] "C_WHITE"You grabbed a hunting rifle. Snipe deer from a distance - get within 30m and they flee.");
        SendClientMessage(playerid, COLOR_INFO, C_INFO"[Hunt] "C_WHITE"Carry max "C_INFO#HUNT_MAX_MEAT C_WHITE" deer, then sell at any shop with "C_INFO"/sellmeat"C_WHITE". Use "C_INFO"/stophunt"C_WHITE" to put the rifle away.");
        return 1;
    }

    // ---- /stophunt (scoate sniperul de vanatoare) ----
    if(strcmp(cmd, "/stophunt", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;
        if(!g_HasSniper[playerid])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"[Hunt] "C_WHITE"You are not hunting."), 1;

        g_ACWeaponAllowed[playerid][HUNT_SNIPER] = false;
        g_ACWeaponAmmo[playerid][HUNT_SNIPER] = 0;
        AC_RestoreWeapons(playerid); // scoate sniperul, pastreaza restul armelor legitime
        g_HasSniper[playerid] = false;
        SendClientMessage(playerid, COLOR_SUCCESS, C_SUCCESS"[Hunt] "C_WHITE"You put the hunting rifle away.");
        return 1;
    }

    // ---- /sellmeat (vinde caprioarele la orice shop) ----
    if(strcmp(cmd, "/sellmeat", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;
        if(g_HuntMeat[playerid] <= 0)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"[Hunt] "C_WHITE"You have no deer to sell."), 1;

        new bool:nearShop = false;
        for(new i = 0; i < g_ShopCount; i++)
            if(IsPlayerInRangeOfPoint(playerid, HUNT_SELL_RANGE, ShopData[i][shopX], ShopData[i][shopY], ShopData[i][shopZ])) { nearShop = true; break; }
        if(!nearShop)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"[Hunt] "C_WHITE"You must be at a shop to sell your deer."), 1;

        new count = g_HuntMeat[playerid];
        new earn = count * HUNT_PAYOUT;
        PlayerData[playerid][pMoney] += earn;
        GivePlayerMoney(playerid, earn);
        UpdatePlayer(playerid, pMoney);
        g_HuntMeat[playerid] = 0;

        new sm[128];
        format(sm, sizeof(sm), C_SUCCESS"[Hunt] "C_WHITE"You sold "C_INFO"%d"C_WHITE" deer for "C_SUCCESS"$%s"C_WHITE".", count, MoneyStr(earn));
        SendClientMessage(playerid, COLOR_SUCCESS, sm);
        return 1;
    }

    // ---- /farm [stats/plow/level/seed/fertilize/harvest/buy/sell] ----
    if(strcmp(cmd, "/farm", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new fAction[16], fap = 0;
        while(cmdtext[idx] > ' ' && fap < 15) { fAction[fap++] = cmdtext[idx]; idx++; }
        fAction[fap] = EOS;
        if(!strlen(fAction))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/farm [stats/plow/level/seed/fertilize/harvest/buy/sell]"C_WHITE"."), 1;

        new fidx = Farm_PlayerIn(playerid);
        if(fidx == -1)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"[Farm] "C_WHITE"You are not on a field."), 1;

        new fTodayDay = gettime() / 86400;
        new fLastDay  = FarmData[fidx][fmLastWork] / 86400;
        new bool:fWorkedToday = (FarmData[fidx][fmLastWork] > 0 && fLastDay >= fTodayDay);

        // ---- /farm stats ----
        if(strcmp(fAction, "stats", true) == 0)
        {
            new sline[144];
            format(sline, sizeof(sline), C_INFO"_____ Field #%d ____________________", FarmData[fidx][fmID]);
            SendClientMessage(playerid, COLOR_INFO, sline);
            if(FarmData[fidx][fmOwned])
                format(sline, sizeof(sline), C_WHITE"Owner: "C_INFO"%s", FarmData[fidx][fmOwner]);
            else
                format(sline, sizeof(sline), C_WHITE"Owner: "C_SUCCESS"unowned"C_WHITE" (price "C_INFO"$%s"C_WHITE")", MoneyStr(FarmData[fidx][fmPrice]));
            SendClientMessage(playerid, COLOR_WHITE, sline);
            format(sline, sizeof(sline), C_WHITE"Next step: "C_INFO"%s"C_WHITE" (%s, %d min)",
                g_FarmStepName[FarmData[fidx][fmNextStep]], g_FarmStepVehName[FarmData[fidx][fmNextStep]], g_FarmStepMin[FarmData[fidx][fmNextStep]]);
            SendClientMessage(playerid, COLOR_WHITE, sline);
            if(fWorkedToday)
                SendClientMessage(playerid, COLOR_WHITE, C_WHITE"Ready to work: "C_ERROR"no"C_WHITE" (already worked today, come back tomorrow)");
            else
                SendClientMessage(playerid, COLOR_WHITE, C_WHITE"Ready to work: "C_SUCCESS"yes");
            format(sline, sizeof(sline), C_WHITE"Vehicles: "C_INFO"%d"C_WHITE" Tractor, "C_INFO"%d"C_WHITE" Dozer, "C_INFO"%d"C_WHITE" Combine, "C_INFO"%d"C_WHITE" Truck, "C_INFO"%d"C_WHITE" Trailer.",
                Farm_OwnedCount(fidx, FARM_TRACTOR), Farm_OwnedCount(fidx, FARM_DOZER), Farm_OwnedCount(fidx, FARM_COMBINE), Farm_OwnedCount(fidx, FARM_TRUCK), Farm_OwnedCount(fidx, FARM_TRAILER));
            SendClientMessage(playerid, COLOR_WHITE, sline);
            return 1;
        }

        // ---- /farm buy [tractor/dozer/combina/truck/trailer] (doar pe terenul personal) ----
        if(strcmp(fAction, "buy", true) == 0)
        {
            if(!Farm_IsOwner(playerid, fidx))
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"[Farm] "C_WHITE"You can only buy vehicles on your own field."), 1;

            while(cmdtext[idx] == ' ') idx++;
            new typeArg[12], tap = 0;
            while(cmdtext[idx] > ' ' && tap < 11) { typeArg[tap++] = cmdtext[idx]; idx++; }
            typeArg[tap] = EOS;
            new model = Farm_ModelFromType(typeArg);
            if(model == -1)
                return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/farm buy [tractor/dozer/combina/truck/trailer]"C_WHITE"."), 1;

            new price = Farm_VehPrice(model);
            new vtn[12]; Farm_VehTypeName(model, vtn);
            if(FarmData[fidx][fmBank] < price)
            {
                new em[128];
                format(em, sizeof(em), C_ERROR"[Farm] "C_WHITE"The farm bank needs "C_INFO"$%s"C_WHITE" for a %s (use "C_INFO"/farm deposit"C_WHITE").", MoneyStr(price), vtn);
                return SendClientMessage(playerid, COLOR_ERROR, em), 1;
            }

            FarmData[fidx][fmBank] -= price; // banii se iau din contul fermei
            Farm_OwnedAdd(fidx, model, 1); // creste numarul de utilaje detinute
            Farm_Save(fidx);

            new bm[144];
            format(bm, sizeof(bm), C_SUCCESS"[Farm] "C_WHITE"Bought a %s for "C_INFO"$%s"C_WHITE". The farm now owns "C_INFO"%d"C_WHITE" (bank: "C_INFO"$%s"C_WHITE").", vtn, MoneyStr(price), Farm_OwnedCount(fidx, model), MoneyStr(FarmData[fidx][fmBank]));
            SendClientMessage(playerid, COLOR_SUCCESS, bm);
            return 1;
        }

        // ---- /farm sell [tractor/dozer/combina/truck/trailer] (doar pe terenul personal) ----
        if(strcmp(fAction, "sell", true) == 0)
        {
            if(!Farm_IsOwner(playerid, fidx))
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"[Farm] "C_WHITE"You can only sell vehicles on your own field."), 1;

            while(cmdtext[idx] == ' ') idx++;
            new typeArg[12], tap = 0;
            while(cmdtext[idx] > ' ' && tap < 11) { typeArg[tap++] = cmdtext[idx]; idx++; }
            typeArg[tap] = EOS;
            new model = Farm_ModelFromType(typeArg);
            if(model == -1)
                return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/farm sell [tractor/dozer/combina/truck/trailer]"C_WHITE"."), 1;

            new vtn[12]; Farm_VehTypeName(model, vtn);
            if(Farm_OwnedCount(fidx, model) <= 0)
            {
                new em[128];
                format(em, sizeof(em), C_ERROR"[Farm] "C_WHITE"This field doesn't own a %s.", vtn);
                return SendClientMessage(playerid, COLOR_ERROR, em), 1;
            }

            new refund = Farm_VehPrice(model) * 75 / 100;
            FarmData[fidx][fmBank] += refund; // 75% inapoi in contul fermei
            Farm_OwnedAdd(fidx, model, -1);
            Farm_Save(fidx);

            new sm2[144];
            format(sm2, sizeof(sm2), C_SUCCESS"[Farm] "C_WHITE"Sold a %s for "C_INFO"$%s"C_WHITE" (75%%) into the farm bank (now "C_INFO"$%s"C_WHITE").", vtn, MoneyStr(refund), MoneyStr(FarmData[fidx][fmBank]));
            SendClientMessage(playerid, COLOR_SUCCESS, sm2);
            return 1;
        }

        // ---- /farm deposit [amount] (owner: bani personali -> contul fermei) ----
        if(strcmp(fAction, "deposit", true) == 0)
        {
            if(!Farm_IsOwner(playerid, fidx))
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"[Farm] "C_WHITE"This is not your field."), 1;
            while(cmdtext[idx] == ' ') idx++;
            new amtStr[16];
            strmid(amtStr, cmdtext, idx, strlen(cmdtext), 16);
            new amt = strval(amtStr);
            if(amt <= 0)
                return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/farm deposit [amount]"C_WHITE"."), 1;
            if(PlayerData[playerid][pMoney] < amt)
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"[Farm] "C_WHITE"You don't have that much money."), 1;
            PlayerData[playerid][pMoney] -= amt;
            GivePlayerMoney(playerid, -amt);
            UpdatePlayer(playerid, pMoney);
            FarmData[fidx][fmBank] += amt;
            Farm_Save(fidx);
            new dm[128];
            format(dm, sizeof(dm), C_SUCCESS"[Farm] "C_WHITE"Deposited "C_INFO"$%s"C_WHITE". Farm bank: "C_INFO"$%s"C_WHITE".", MoneyStr(amt), MoneyStr(FarmData[fidx][fmBank]));
            SendClientMessage(playerid, COLOR_SUCCESS, dm);
            return 1;
        }

        // ---- /farm withdraw [amount] (owner: contul fermei -> bani personali) ----
        if(strcmp(fAction, "withdraw", true) == 0)
        {
            if(!Farm_IsOwner(playerid, fidx))
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"[Farm] "C_WHITE"This is not your field."), 1;
            while(cmdtext[idx] == ' ') idx++;
            new amtStr[16];
            strmid(amtStr, cmdtext, idx, strlen(cmdtext), 16);
            new amt = strval(amtStr);
            if(amt <= 0)
                return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/farm withdraw [amount]"C_WHITE"."), 1;
            if(FarmData[fidx][fmBank] < amt)
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"[Farm] "C_WHITE"The farm bank doesn't have that much."), 1;
            FarmData[fidx][fmBank] -= amt;
            PlayerData[playerid][pMoney] += amt;
            GivePlayerMoney(playerid, amt);
            UpdatePlayer(playerid, pMoney);
            Farm_Save(fidx);
            new wm[128];
            format(wm, sizeof(wm), C_SUCCESS"[Farm] "C_WHITE"Withdrew "C_INFO"$%s"C_WHITE". Farm bank: "C_INFO"$%s"C_WHITE".", MoneyStr(amt), MoneyStr(FarmData[fidx][fmBank]));
            SendClientMessage(playerid, COLOR_SUCCESS, wm);
            return 1;
        }

        // ---- /farm deliver (vinde recolta: cu truck+trailer la shop, sau instant la jumatate) ----
        if(strcmp(fAction, "deliver", true) == 0)
        {
            if(!Farm_IsOwner(playerid, fidx))
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"[Farm] "C_WHITE"This is not your field."), 1;
            if(FarmData[fidx][fmRecolta] <= 0)
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"[Farm] "C_WHITE"No harvest to deliver. Complete a farming cycle first."), 1;
            if(g_FarmDelivTruck[playerid] != 0)
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"[Farm] "C_WHITE"You are already on a delivery."), 1;

            if(Farm_OwnedCount(fidx, FARM_TRUCK) >= 1 && Farm_OwnedCount(fidx, FARM_TRAILER) >= 1)
            {
                // gaseste cel mai apropiat shop
                new Float:px, Float:py, Float:pz, Float:pa;
                GetPlayerPos(playerid, px, py, pz);
                GetPlayerFacingAngle(playerid, pa);
                new shop = -1; new Float:best = 999999.0;
                for(new i = 0; i < g_ShopCount; i++)
                {
                    new Float:d = VectorSize(px - ShopData[i][shopX], py - ShopData[i][shopY], pz - ShopData[i][shopZ]);
                    if(d < best) { best = d; shop = i; }
                }
                if(shop == -1)
                    return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"[Farm] "C_WHITE"No shop available for delivery."), 1;

                g_FarmDelivTruck[playerid]   = CreateVehicle(FARM_TRUCK, px, py, pz, pa, -1, -1, -1);
                g_FarmDelivTrailer[playerid] = CreateVehicle(FARM_TRAILER, px, py - 6.0, pz, pa, -1, -1, -1);
                g_FarmDelivFarm[playerid]    = fidx;
                PutPlayerInVehicle(playerid, g_FarmDelivTruck[playerid], 0);
                SetTimerEx("Farm_DeliverAttach", 1000, false, "i", playerid);
                SetPlayerCheckpoint(playerid, ShopData[shop][shopX], ShopData[shop][shopY], ShopData[shop][shopZ], 6.0);

                SendClientMessage(playerid, COLOR_SUCCESS, C_SUCCESS"[Farm] "C_WHITE"Delivery started! Drive the truck to the shop checkpoint to sell the harvest.");
                return 1;
            }
            else
            {
                // fara truck+trailer -> vanzare instant la jumatate, in contul fermei
                new pay = FarmData[fidx][fmRecolta] / 2;
                FarmData[fidx][fmBank] += pay;
                FarmData[fidx][fmRecolta] = 0;
                Farm_Save(fidx);
                new im[144];
                format(im, sizeof(im), C_SUCCESS"[Farm] "C_WHITE"Sold the harvest for "C_INFO"$%s"C_WHITE" (half, no truck+trailer) to the farm bank.", MoneyStr(pay));
                SendClientMessage(playerid, COLOR_SUCCESS, im);
                return 1;
            }
        }

        // ---- /farm rent [tractor/dozer/combina] (25% din pret, din contul fermei) ----
        if(strcmp(fAction, "rent", true) == 0)
        {
            if(!Farm_IsOwner(playerid, fidx))
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"[Farm] "C_WHITE"This is not your field."), 1;
            while(cmdtext[idx] == ' ') idx++;
            new typeArg[12], tap = 0;
            while(cmdtext[idx] > ' ' && tap < 11) { typeArg[tap++] = cmdtext[idx]; idx++; }
            typeArg[tap] = EOS;
            new model = Farm_ModelFromType(typeArg);
            if(model != FARM_TRACTOR && model != FARM_DOZER && model != FARM_COMBINE)
                return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"You can only rent "C_INFO"tractor / dozer / combina"C_WHITE"."), 1;
            if(g_FarmRentVeh[playerid] != 0)
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"[Farm] "C_WHITE"You already have a rented vehicle."), 1;

            new rentPrice = Farm_VehPrice(model) * 25 / 100;
            if(FarmData[fidx][fmBank] < rentPrice)
            {
                new em[128];
                format(em, sizeof(em), C_ERROR"[Farm] "C_WHITE"The farm bank needs "C_INFO"$%s"C_WHITE" to rent (25%%).", MoneyStr(rentPrice));
                return SendClientMessage(playerid, COLOR_ERROR, em), 1;
            }
            FarmData[fidx][fmBank] -= rentPrice;
            Farm_Save(fidx);

            new Float:px, Float:py, Float:pz, Float:pa;
            GetPlayerPos(playerid, px, py, pz);
            GetPlayerFacingAngle(playerid, pa);
            g_FarmRentVeh[playerid] = CreateVehicle(model, px, py, pz, pa, -1, -1, -1);
            PutPlayerInVehicle(playerid, g_FarmRentVeh[playerid], 0);

            new vtn[12]; Farm_VehTypeName(model, vtn);
            new rm[144];
            format(rm, sizeof(rm), C_SUCCESS"[Farm] "C_WHITE"Rented a %s for "C_INFO"$%s"C_WHITE" (25%%). It disappears when you leave it.", vtn, MoneyStr(rentPrice));
            SendClientMessage(playerid, COLOR_SUCCESS, rm);
            return 1;
        }

        new step = Farm_ActionIndex(fAction);
        if(step == -1)
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/farm [stats / plow / level / seed/fertilize/harvest/buy/sell]"C_WHITE"."), 1;

        if(g_FarmWorking[playerid] != 0)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"[Farm] "C_WHITE"You are already doing farm work."), 1;

        if(step != FarmData[fidx][fmNextStep])
        {
            new emsg[144];
            format(emsg, sizeof(emsg), C_ERROR"[Farm] "C_WHITE"The next step here is "C_INFO"%s"C_WHITE", not %s.", g_FarmStepName[FarmData[fidx][fmNextStep]], g_FarmStepName[step]);
            return SendClientMessage(playerid, COLOR_ERROR, emsg), 1;
        }

        if(fWorkedToday)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"[Farm] "C_WHITE"This field was already worked today. Come back tomorrow."), 1;

        // utilajul necesar: fie cel in care esti deja (rentat/altul), fie unul spawnat temporar (daca ferma detine)
        new stepModel = g_FarmStepVeh[step];
        new curVeh = GetPlayerVehicleID(playerid);
        new veh;
        new bool:spawned = false;
        if(curVeh != 0 && GetVehicleModel(curVeh) == stepModel)
        {
            veh = curVeh; // esti deja in utilajul potrivit (ex. rentat)
        }
        else if(Farm_OwnedCount(fidx, stepModel) >= 1)
        {
            // spawneaza temporar un utilaj detinut de ferma (se distruge la final/coborare)
            new Float:wx, Float:wy, Float:wz, Float:wa;
            GetPlayerPos(playerid, wx, wy, wz);
            GetPlayerFacingAngle(playerid, wa);
            veh = CreateVehicle(stepModel, wx, wy, wz, wa, -1, -1, -1);
            spawned = true;
        }
        else
        {
            new vtn0[12]; Farm_VehTypeName(stepModel, vtn0);
            new emv[144];
            format(emv, sizeof(emv), C_ERROR"[Farm] "C_WHITE"This field has no %s. Buy or rent one ("C_INFO"/farm buy/rent"C_WHITE").", vtn0);
            return SendClientMessage(playerid, COLOR_ERROR, emv), 1;
        }

        // incepe lucrarea: lastWorkingDate = azi (indiferent daca termina)
        FarmData[fidx][fmLastWork] = gettime();
        Farm_Save(fidx);

        // pune playerul in utilaj (grace AC pt teleport in vehicul)
        g_ACGrace[playerid] = GetTickCount() + AC_GRACE_MS;
        g_ACExpectTP[playerid] = true;
        PutPlayerInVehicle(playerid, veh, 0);

        g_FarmWorking[playerid]  = fidx + 1;
        g_FarmWorkStep[playerid] = step;
        g_FarmWorkVeh[playerid]  = veh;
        g_FarmWorkSpawned[playerid] = spawned;

        new mins = g_FarmStepMin[step];
        g_FarmWorkTimer[playerid] = SetTimerEx("Farm_Complete", mins * 60000, false, "i", playerid);

        new smsg[144];
        format(smsg, sizeof(smsg), C_SUCCESS"[Farm] "C_WHITE"Started "C_INFO"%s"C_WHITE". Drive the "C_INFO"%s"C_WHITE" for "C_INFO"%d min"C_WHITE" - don't leave it!",
            g_FarmStepName[step], g_FarmStepVehName[step], mins);
        SendClientMessage(playerid, COLOR_SUCCESS, smsg);
        return 1;
    }

    // ---- /farmstats (informatii despre ferma detinuta) ----
    if(strcmp(cmd, "/farmstats", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;
        if(PlayerData[playerid][pFarmKey] == 0)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"[Farm] "C_WHITE"You don't own a farm."), 1;

        new fs = Farm_IndexByID(PlayerData[playerid][pFarmKey]);
        if(fs == -1)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"[Farm] "C_WHITE"Your farm could not be found."), 1;

        new fl[144];
        format(fl, sizeof(fl), C_INFO"_____ Your Farm (#%d) ____________________", FarmData[fs][fmID]);
        SendClientMessage(playerid, COLOR_INFO, fl);

        format(fl, sizeof(fl), C_WHITE"Next step: "C_INFO"%s"C_WHITE" (%s, %d min)",
            g_FarmStepName[FarmData[fs][fmNextStep]], g_FarmStepVehName[FarmData[fs][fmNextStep]], g_FarmStepMin[FarmData[fs][fmNextStep]]);
        SendClientMessage(playerid, COLOR_WHITE, fl);

        format(fl, sizeof(fl), C_WHITE"Progress: Plow[%s] Level[%s] Seed[%s] Fertilize[%s] Harvest[%s]",
            (FarmData[fs][fmPlowed] ? "X" : "-"), (FarmData[fs][fmLeveled] ? "X" : "-"), (FarmData[fs][fmSeeded] ? "X" : "-"),
            (FarmData[fs][fmFertilized] ? "X" : "-"), (FarmData[fs][fmReady] ? "X" : "-"));
        SendClientMessage(playerid, COLOR_WHITE, fl);

        format(fl, sizeof(fl), C_WHITE"Vehicles: Tractors "C_INFO"%d"C_WHITE", Dozers "C_INFO"%d"C_WHITE", Combines "C_INFO"%d"C_WHITE" (+ truck/trailer if bought)",
            FarmData[fs][fmTractors], FarmData[fs][fmDozers], FarmData[fs][fmCombines]);
        SendClientMessage(playerid, COLOR_WHITE, fl);

        format(fl, sizeof(fl), C_WHITE"Farm bank: "C_INFO"$%s"C_WHITE" | Harvest stock: "C_INFO"$%s"C_WHITE" (sell with /farm deliver)",
            MoneyStr(FarmData[fs][fmBank]), MoneyStr(FarmData[fs][fmRecolta]));
        SendClientMessage(playerid, COLOR_WHITE, fl);

        new fToday = gettime() / 86400, fLast = FarmData[fs][fmLastWork] / 86400;
        if(FarmData[fs][fmLastWork] > 0)
        {
            new ds[11]; UnixToDateStr(FarmData[fs][fmLastWork], ds, sizeof(ds));
            if(fLast >= fToday)
                format(fl, sizeof(fl), C_WHITE"Last worked: "C_INFO"%s"C_WHITE" - "C_ERROR"come back tomorrow", ds);
            else
                format(fl, sizeof(fl), C_WHITE"Last worked: "C_INFO"%s"C_WHITE" - ready: "C_SUCCESS"yes", ds);
        }
        else
            format(fl, sizeof(fl), C_WHITE"Last worked: "C_INFO"never"C_WHITE" - ready: "C_SUCCESS"yes");
        SendClientMessage(playerid, COLOR_WHITE, fl);
        return 1;
    }

    // ---- /buyfarm (cumpara terenul pe care stai, daca e liber) ----
    if(strcmp(cmd, "/buyfarm", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;
        if(PlayerData[playerid][pFarmKey] != 0)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"[Farm] "C_WHITE"You already own a farm. Use "C_INFO"/sellfarm"C_WHITE" first."), 1;

        new fidx = Farm_PlayerIn(playerid);
        if(fidx == -1)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"[Farm] "C_WHITE"You are not on a farm."), 1;
        if(FarmData[fidx][fmOwned])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"[Farm] "C_WHITE"This farm is already owned."), 1;

        new price = FarmData[fidx][fmPrice];
        if(PlayerData[playerid][pMoney] < price)
        {
            new em[128];
            format(em, sizeof(em), C_ERROR"[Farm] "C_WHITE"You need "C_INFO"$%s"C_WHITE" to buy this farm.", MoneyStr(price));
            return SendClientMessage(playerid, COLOR_ERROR, em), 1;
        }

        PlayerData[playerid][pMoney] -= price;
        GivePlayerMoney(playerid, -price);
        UpdatePlayer(playerid, pMoney);

        FarmData[fidx][fmOwned] = 1;
        format(FarmData[fidx][fmOwner], 24, "%s", PlayerData[playerid][pName]);
        PlayerData[playerid][pFarmKey] = FarmData[fidx][fmID];

        new q[160];
        mysql_format(g_SQL, q, sizeof(q), "UPDATE `farms` SET `owner`='%e', `isOwned`=1 WHERE `id`=%d",
            PlayerData[playerid][pName], FarmData[fidx][fmID]);
        mysql_tquery(g_SQL, q, "", "", 0);
        Farm_RecreatePickup(fidx);

        new bm[128];
        format(bm, sizeof(bm), C_SUCCESS"[Farm] "C_WHITE"You bought Farm "C_INFO"#%d"C_WHITE" for "C_INFO"$%s"C_WHITE"! Use "C_INFO"/farmstats"C_WHITE".",
            FarmData[fidx][fmID], MoneyStr(price));
        SendClientMessage(playerid, COLOR_SUCCESS, bm);
        return 1;
    }

    // ---- /sellfarm (vinde ferma detinuta) ----
    if(strcmp(cmd, "/sellfarm", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;
        if(PlayerData[playerid][pFarmKey] == 0)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"[Farm] "C_WHITE"You don't own a farm."), 1;

        new fidx = Farm_IndexByID(PlayerData[playerid][pFarmKey]);
        if(fidx == -1)
        {
            PlayerData[playerid][pFarmKey] = 0;
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"[Farm] "C_WHITE"Your farm could not be found."), 1;
        }

        new refund = FarmData[fidx][fmPrice] * 75 / 100;
        PlayerData[playerid][pMoney] += refund;
        GivePlayerMoney(playerid, refund);
        UpdatePlayer(playerid, pMoney);

        FarmData[fidx][fmOwned] = 0;
        FarmData[fidx][fmOwner][0] = EOS;
        PlayerData[playerid][pFarmKey] = 0;

        new q[160];
        mysql_format(g_SQL, q, sizeof(q), "UPDATE `farms` SET `owner`='', `isOwned`=0 WHERE `id`=%d", FarmData[fidx][fmID]);
        mysql_tquery(g_SQL, q, "", "", 0);
        Farm_RecreatePickup(fidx);

        new sm[128];
        format(sm, sizeof(sm), C_SUCCESS"[Farm] "C_WHITE"You sold Farm "C_INFO"#%d"C_WHITE" for "C_INFO"$%s"C_WHITE".", FarmData[fidx][fmID], MoneyStr(refund));
        SendClientMessage(playerid, COLOR_SUCCESS, sm);
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

    // ---- /changecar [engine/lights/alarm/doors/hood/boot] (comuta o componenta a vehiculului curent) ----
    if(strcmp(cmd, "/changecar", true) == 0)
    {
        if(PlayerData[playerid][pAdminLevel] < 3)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have access. Requires admin level 3."), 1;

        new vehid = GetPlayerVehicleID(playerid);
        if(vehid == 0)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be in a vehicle."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new ccComp[12];
        strmid(ccComp, cmdtext, idx, strlen(cmdtext), 12);
        if(!strlen(ccComp))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/changecar [engine/lights/alarm/doors/hood/boot]"C_WHITE"."), 1;

        new ccEngine, ccLights, ccAlarm, ccDoors, ccBonnet, ccBoot, ccObjective;
        GetVehicleParamsEx(vehid, ccEngine, ccLights, ccAlarm, ccDoors, ccBonnet, ccBoot, ccObjective);

        new ccName[16], ccNew;
        if(strcmp(ccComp, "engine", true) == 0)
        {
            ccEngine = (ccEngine == 1) ? 0 : 1; ccNew = ccEngine; format(ccName, sizeof(ccName), "Engine");
        }
        else if(strcmp(ccComp, "lights", true) == 0)
        {
            ccLights = (ccLights == 1) ? 0 : 1; ccNew = ccLights; format(ccName, sizeof(ccName), "Lights");
        }
        else if(strcmp(ccComp, "alarm", true) == 0)
        {
            ccAlarm = (ccAlarm == 1) ? 0 : 1; ccNew = ccAlarm; format(ccName, sizeof(ccName), "Alarm");
        }
        else if(strcmp(ccComp, "doors", true) == 0 || strcmp(ccComp, "lock", true) == 0)
        {
            ccDoors = (ccDoors == 1) ? 0 : 1; ccNew = ccDoors; format(ccName, sizeof(ccName), "Doors");
        }
        else if(strcmp(ccComp, "hood", true) == 0 || strcmp(ccComp, "bonnet", true) == 0)
        {
            ccBonnet = (ccBonnet == 1) ? 0 : 1; ccNew = ccBonnet; format(ccName, sizeof(ccName), "Hood");
        }
        else if(strcmp(ccComp, "boot", true) == 0 || strcmp(ccComp, "trunk", true) == 0)
        {
            ccBoot = (ccBoot == 1) ? 0 : 1; ccNew = ccBoot; format(ccName, sizeof(ccName), "Boot");
        }
        else
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Unknown component. Use "C_INFO"engine/lights/alarm/doors/hood/boot"C_WHITE"."), 1;

        SetVehicleParamsEx(vehid, ccEngine, ccLights, ccAlarm, ccDoors, ccBonnet, ccBoot, ccObjective);

        new ccMsg[96];
        format(ccMsg, sizeof(ccMsg), C_SUCCESS"[ADM] Success: "C_WHITE"%s "C_INFO"%s"C_WHITE".", ccName, ccNew ? ("ON") : ("OFF"));
        SendClientMessage(playerid, COLOR_SUCCESS, ccMsg);
        return 1;
    }

    // ---- /jetpack (primesti un jetpack) ----
    if(strcmp(cmd, "/jetpack", true) == 0)
    {
        if(PlayerData[playerid][pAdminLevel] < 5)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have access. Requires admin level 5."), 1;

        SetPlayerSpecialAction(playerid, SPECIAL_ACTION_USEJETPACK);
        SendClientMessage(playerid, COLOR_SUCCESS, C_SUCCESS"[ADM] Success: "C_WHITE"You received a jetpack.");
        return 1;
    }

    // ---- /removejetpack (elimina toate jetpack-urile de pe server) ----
    if(strcmp(cmd, "/removejetpack", true) == 0)
    {
        if(PlayerData[playerid][pAdminLevel] < 5)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have access. Requires admin level 5."), 1;

        new removed = 0;
        for(new i = 0; i < MAX_PLAYERS; i++)
        {
            if(!IsPlayerConnected(i)) continue;
            if(GetPlayerSpecialAction(i) == SPECIAL_ACTION_USEJETPACK)
            {
                SetPlayerSpecialAction(i, SPECIAL_ACTION_NONE);
                removed++;
            }
        }

        new rjmsg[96];
        format(rjmsg, sizeof(rjmsg), C_SUCCESS"[ADM] Success: "C_WHITE"Removed all jetpacks ("C_INFO"%d"C_WHITE" player(s)).", removed);
        SendClientMessage(playerid, COLOR_SUCCESS, rjmsg);
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
            SetPlayerMapIcon(i, FIRE_ICON_SLOT_BASE + fidx, fx, fy, fz, FIRE_MAPICON_ID, 0, MAPICON_GLOBAL);
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

        if(joined < 1) // TODO: de schimbat limita de playeri la golf
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"At least 1 player must join before starting."), 1;

        g_GolfStatus = GOLF_STATUS_PROGRESS;
        for(new i = 0; i < MAX_PLAYERS; i++)
        {
            g_GolfActive[i] = g_GolfJoined[i];
            if(!g_GolfActive[i]) continue;

            SetPlayerHealth(i, 100.0);
            AC_GiveWeapon(i, GOLF_CLUB_WEAPON_ID, 1);
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

        if(!Player_NearHospital(playerid))
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

    // ---- /news [text] (News Reporters rank 1+, difuzat tuturor) ----
    if(strcmp(cmd, "/news", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;
        if(PlayerData[playerid][pFaction] != NEWS_FACTION_ID)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Only News Reporters can use this."), 1;
        if(PlayerData[playerid][pFactionRank] < 1)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Requires faction rank 1+."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new ntext[144];
        strmid(ntext, cmdtext, idx, strlen(cmdtext), 144);
        if(!strlen(ntext))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/news [text]"C_WHITE"."), 1;

        new nmsg[256];
        format(nmsg, sizeof(nmsg), C_WHITE"[{FFFF00}NEWS"C_WHITE"] %s: {FFFF00}%s", PlayerData[playerid][pName], ntext);
        for(new i = 0; i < MAX_PLAYERS; i++)
            if(IsPlayerConnected(i) && PlayerData[i][pLogged])
                SendClientMessage(i, COLOR_WHITE, nmsg);
        return 1;
    }

    // ---- /newspaper [create/edit/sell/open] ----
    if(strcmp(cmd, "/newspaper", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new nsub[12], nsp = 0;
        while(cmdtext[idx] > ' ' && nsp < 11) { nsub[nsp++] = cmdtext[idx]; idx++; }
        nsub[nsp] = EOS;
        if(!strlen(nsub))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/newspaper [create/edit/sell/open]"C_WHITE"."), 1;

        new bool:isReporter = (PlayerData[playerid][pFaction] == NEWS_FACTION_ID);

        // ---- /newspaper open (cumparatori sau reporterul care si-a facut ziarul) ----
        if(strcmp(nsub, "open", true) == 0)
        {
            new bool:showOwn = false;
            if(g_HasNewspaper[playerid]) showOwn = false;
            else if(isReporter && g_NewspaperCreated[playerid]) showOwn = true;
            else return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have a newspaper."), 1;

            new authorName[24];
            if(showOwn) format(authorName, sizeof(authorName), "%s", PlayerData[playerid][pName]);
            else        format(authorName, sizeof(authorName), "%s", g_OwnedNewsAuthor[playerid]);

            new dlg[1024], nline[NEWS_ITEM_LEN + 32], any = 0;
            format(dlg, sizeof(dlg), C_INFO"News Reporters"C_WHITE" - published by "C_INFO"%s"C_WHITE"\n\n\n\n", authorName);
            for(new n = 0; n < NEWS_MAX_ITEMS; n++)
            {
                new bool:empty;
                if(showOwn) empty = (g_NewspaperItem[playerid][n][0] == EOS);
                else        empty = (g_OwnedNewsItem[playerid][n][0] == EOS);
                if(empty) continue;

                if(showOwn) format(nline, sizeof(nline), "%d) %s\n\n\n\n", n + 1, g_NewspaperItem[playerid][n]);
                else        format(nline, sizeof(nline), "%d) %s\n\n\n\n", n + 1, g_OwnedNewsItem[playerid][n]);
                strcat(dlg, nline);
                any++;
            }
            if(!any) strcat(dlg, C_WHITE"(This newspaper has no news yet.)");

            ShowPlayerDialog(playerid, DIALOG_NEWSPAPER, DIALOG_STYLE_MSGBOX, "Newspaper", dlg, "Close", "");
            return 1;
        }

        // ---- restul necesita reporter rank 2+ ----
        if(!isReporter)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Only News Reporters can use this."), 1;
        if(PlayerData[playerid][pFactionRank] < 2)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Requires faction rank 2+."), 1;

        // ---- /newspaper create ----
        if(strcmp(nsub, "create", true) == 0)
        {
            g_NewspaperCreated[playerid] = true;
            for(new n = 0; n < NEWS_MAX_ITEMS; n++) g_NewspaperItem[playerid][n][0] = EOS;
            SendClientMessage(playerid, COLOR_SUCCESS, C_SUCCESS"Success: "C_WHITE"New newspaper created. Add news with "C_INFO"/newspaper edit [1-5] [text]"C_WHITE".");
            return 1;
        }

        // ---- /newspaper edit [1-5] [text] ----
        if(strcmp(nsub, "edit", true) == 0)
        {
            if(!g_NewspaperCreated[playerid])
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Create a newspaper first ("C_INFO"/newspaper create"C_WHITE")."), 1;

            while(cmdtext[idx] == ' ') idx++;
            new slotStr[4], ssp = 0;
            while(cmdtext[idx] > ' ' && ssp < 3) { slotStr[ssp++] = cmdtext[idx]; idx++; }
            slotStr[ssp] = EOS;
            new slot = strval(slotStr);
            if(slot < 1 || slot > NEWS_MAX_ITEMS)
                return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/newspaper edit [1-5] [text]"C_WHITE"."), 1;

            while(cmdtext[idx] == ' ') idx++;
            new etext[NEWS_ITEM_LEN];
            strmid(etext, cmdtext, idx, strlen(cmdtext), NEWS_ITEM_LEN);
            if(!strlen(etext))
                return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/newspaper edit [1-5] [text]"C_WHITE"."), 1;

            format(g_NewspaperItem[playerid][slot - 1], NEWS_ITEM_LEN, "%s", etext);

            new emsg[96];
            format(emsg, sizeof(emsg), C_SUCCESS"Success: "C_WHITE"News "C_INFO"#%d"C_WHITE" updated.", slot);
            SendClientMessage(playerid, COLOR_SUCCESS, emsg);
            return 1;
        }

        // ---- /newspaper sell [playerid] [amount] ----
        if(strcmp(nsub, "sell", true) == 0)
        {
            if(!g_NewspaperCreated[playerid])
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Create a newspaper first ("C_INFO"/newspaper create"C_WHITE")."), 1;

            while(cmdtext[idx] == ' ') idx++;
            new tStr[8], tsp = 0;
            while(cmdtext[idx] > ' ' && tsp < 7) { tStr[tsp++] = cmdtext[idx]; idx++; }
            tStr[tsp] = EOS;
            while(cmdtext[idx] == ' ') idx++;
            new aStr[12];
            strmid(aStr, cmdtext, idx, strlen(cmdtext), 12);
            if(!strlen(tStr) || !strlen(aStr))
                return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/newspaper sell [playerid] [amount]"C_WHITE"."), 1;

            new targetid = strval(tStr), amount = strval(aStr);
            if(!IsPlayerConnected(targetid) || !PlayerData[targetid][pLogged])
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Invalid player."), 1;
            if(targetid == playerid)
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You can't sell to yourself."), 1;
            if(amount <= 0)
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Invalid amount."), 1;

            g_NewsOfferSeller[targetid] = playerid;
            g_NewsOfferAmount[targetid] = amount;

            new smsg[160];
            format(smsg, sizeof(smsg), C_SUCCESS"Success: "C_WHITE"You offered your newspaper to "C_INFO"%s"C_WHITE" for "C_INFO"$%s"C_WHITE".",
                PlayerData[targetid][pName], MoneyStr(amount));
            SendClientMessage(playerid, COLOR_SUCCESS, smsg);
            format(smsg, sizeof(smsg), C_INFO"[NEWS] "C_WHITE"%s"C_WHITE" offers you a newspaper for "C_INFO"$%s"C_WHITE". Type "C_INFO"/accept newspaper %d"C_WHITE" to buy.",
                PlayerData[playerid][pName], MoneyStr(amount), playerid);
            SendClientMessage(targetid, COLOR_WHITE, smsg);
            return 1;
        }

        return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/newspaper [create/edit/sell/open]"C_WHITE"."), 1;
    }

    // ---- /qa [playerid] | [list/ask/del/end] (reporter rank 3, live Q&A) ----
    if(strcmp(cmd, "/qa", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;
        if(PlayerData[playerid][pFaction] != NEWS_FACTION_ID)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Only News Reporters can use this."), 1;
        if(PlayerData[playerid][pFactionRank] < 3)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Requires faction rank 3+."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new qsub[10], qsp = 0;
        while(cmdtext[idx] > ' ' && qsp < 9) { qsub[qsp++] = cmdtext[idx]; idx++; }
        qsub[qsp] = EOS;
        if(!strlen(qsub))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/qa [playerid]"C_WHITE" to start, or "C_INFO"/qa [list/ask/del/end]"C_WHITE"."), 1;

        // ---- /qa list ----
        if(strcmp(qsub, "list", true) == 0)
        {
            if(!g_QAActive || g_QAReporter != playerid)
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You are not hosting a Q&A."), 1;

            static qdlg[6144];
            qdlg[0] = EOS;
            if(g_QACount == 0)
            {
                strcat(qdlg, C_WHITE"(No questions submitted yet.)");
            }
            else
            {
                new qline[QA_Q_LEN + 48];
                for(new i = 0; i < g_QACount; i++)
                {
                    format(qline, sizeof(qline), ""C_INFO"%d."C_WHITE" [%s] %s\n", i + 1, g_QAAskerName[i], g_QAQuestion[i]);
                    strcat(qdlg, qline);
                }
            }
            ShowPlayerDialog(playerid, DIALOG_QA_LIST, DIALOG_STYLE_MSGBOX, "Q&A - Questions", qdlg, "Close", "");
            return 1;
        }

        // ---- /qa ask [nr] ----
        if(strcmp(qsub, "ask", true) == 0)
        {
            if(!g_QAActive || g_QAReporter != playerid)
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You are not hosting a Q&A."), 1;

            while(cmdtext[idx] == ' ') idx++;
            new nStr[6];
            strmid(nStr, cmdtext, idx, strlen(cmdtext), 6);
            new nr = strval(nStr);
            if(nr < 1 || nr > g_QACount)
                return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/qa ask [nr]"C_WHITE" (see "C_INFO"/qa list"C_WHITE")."), 1;

            new qi = nr - 1;
            new qmsg[256];
            format(qmsg, sizeof(qmsg), "{85648C}[Q&A] "C_WHITE"Question from "C_INFO"%s"C_WHITE": %s", g_QAAskerName[qi], g_QAQuestion[qi]);
            QA_Broadcast(qmsg);

            if(g_QAGuest != INVALID_PLAYER_ID && IsPlayerConnected(g_QAGuest))
                SendClientMessage(g_QAGuest, COLOR_INFO, C_INFO"[Q&A] "C_WHITE"Answer with "C_INFO"/answer [text]"C_WHITE".");

            QA_RemoveQuestion(qi);
            return 1;
        }

        // ---- /qa del [nr] ----
        if(strcmp(qsub, "del", true) == 0)
        {
            if(!g_QAActive || g_QAReporter != playerid)
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You are not hosting a Q&A."), 1;

            while(cmdtext[idx] == ' ') idx++;
            new nStr[6];
            strmid(nStr, cmdtext, idx, strlen(cmdtext), 6);
            new nr = strval(nStr);
            if(nr < 1 || nr > g_QACount)
                return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/qa del [nr]"C_WHITE" (see "C_INFO"/qa list"C_WHITE")."), 1;

            QA_RemoveQuestion(nr - 1);
            SendClientMessage(playerid, COLOR_SUCCESS, C_SUCCESS"Success: "C_WHITE"Question removed.");
            return 1;
        }

        // ---- /qa end ----
        if(strcmp(qsub, "end", true) == 0)
        {
            if(!g_QAActive || g_QAReporter != playerid)
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You are not hosting a Q&A."), 1;

            new emsg[128];
            format(emsg, sizeof(emsg), "{85648C}[Q&A] "C_WHITE"The live Q&A hosted by "C_INFO"%s"C_WHITE" has ended.", PlayerData[playerid][pName]);
            QA_Broadcast(emsg);
            QA_Reset();
            return 1;
        }

        // ---- altfel: qsub e un playerid -> porneste o sesiune (trimite invitatie) ----
        if(g_QAActive || g_QAPendingReporter != INVALID_PLAYER_ID)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"A Q&A session is already active or pending."), 1;

        new guest = strval(qsub);
        if(!IsPlayerConnected(guest) || !PlayerData[guest][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Invalid player."), 1;
        if(guest == playerid)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You can't interview yourself."), 1;

        g_QAPendingReporter = playerid;
        g_QAPendingGuest    = guest;

        new imsg[176];
        format(imsg, sizeof(imsg), C_SUCCESS"Success: "C_WHITE"Q&A invite sent to "C_INFO"%s"C_WHITE". Waiting for them to accept.", PlayerData[guest][pName]);
        SendClientMessage(playerid, COLOR_SUCCESS, imsg);
        format(imsg, sizeof(imsg), "{85648C}[Q&A] "C_WHITE"%s"C_WHITE" invites you to a live Q&A. Type "C_INFO"/accept qa %d"C_WHITE" to accept.", PlayerData[playerid][pName], playerid);
        SendClientMessage(guest, COLOR_WHITE, imsg);
        return 1;
    }

    // ---- /question [text] (orice jucator, in timpul unui Q&A activ) ----
    if(strcmp(cmd, "/question", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;
        if(!g_QAActive)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"There is no active Q&A right now."), 1;
        if(playerid == g_QAReporter || playerid == g_QAGuest)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You can't submit questions in your own Q&A."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new qtext[QA_Q_LEN];
        strmid(qtext, cmdtext, idx, strlen(cmdtext), QA_Q_LEN);
        if(!strlen(qtext))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/question [text]"C_WHITE"."), 1;

        if(g_QACount >= QA_MAX_QUESTIONS)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"The question queue is full. Try again later."), 1;

        format(g_QAQuestion[g_QACount], QA_Q_LEN, "%s", qtext);
        format(g_QAAskerName[g_QACount], 24, "%s", PlayerData[playerid][pName]);
        g_QACount++;

        SendClientMessage(playerid, COLOR_SUCCESS, C_SUCCESS"Success: "C_WHITE"Your question was submitted to the reporter.");
        return 1;
    }

    // ---- /answer [text] (doar invitatul, in timpul unui Q&A activ) ----
    if(strcmp(cmd, "/answer", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;
        if(!g_QAActive || playerid != g_QAGuest)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You are not the guest of an active Q&A."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new atext[176];
        strmid(atext, cmdtext, idx, strlen(cmdtext), 176);
        if(!strlen(atext))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/answer [text]"C_WHITE"."), 1;

        new amsg[256];
        format(amsg, sizeof(amsg), "{85648C}[Q&A] "C_WHITE"%s "C_INFO"(guest)"C_WHITE": %s", PlayerData[playerid][pName], atext);
        QA_Broadcast(amsg);
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
        AC_GiveWeapon(playerid, WEAPON_GRENADE, 1);
        AC_GiveWeapon(playerid, WEAPON_TEARGAS, 1);
        AC_GiveWeapon(playerid, WEAPON_DEAGLE, 350);
        AC_GiveWeapon(playerid, WEAPON_AK47,  300);
        if(PlayerData[playerid][pFactionRank] >= 4)
            AC_GiveWeapon(playerid, WEAPON_SNIPER, 20);

        SendClientMessage(playerid, COLOR_SUCCESS, C_SUCCESS"Success: "C_WHITE"You have been equipped.");
        return 1;
    }

    // ---- /seif (rank 4+ mafie: vezi continutul seifului) ----
    if(strcmp(cmd, "/seif", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        new fid = PlayerData[playerid][pFaction];
        if(!IsMafiaFaction(fid))
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Only mafia factions have a vault."), 1;

        if(PlayerData[playerid][pFactionRank] < 4)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You need rank 4 or higher to check the vault."), 1;

        new smsg[144];
        format(smsg, sizeof(smsg), C_INFO"[Seif] "C_WHITE"Iarba: "C_INFO"%d/%d"C_WHITE"grame. Drugs: "C_INFO"%d/%d"C_WHITE"gr.",
            FactionData[fid][fSeifHerbs], SEIF_MAX_HERBS, FactionData[fid][fSeifDrugs], SEIF_MAX_DRUGS);
        SendClientMessage(playerid, COLOR_INFO, smsg);
        return 1;
    }

    // ---- /drugs <transport/craft/get/use> ----
    if(strcmp(cmd, "/drugs", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        new dfid = PlayerData[playerid][pFaction];
        if(!IsMafiaFaction(dfid))
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Only mafia factions can use this."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new sub[16];
        strmid(sub, cmdtext, idx, strlen(cmdtext), 16);

        if(strcmp(sub, "transport", true) == 0)
        {
            new trank = PlayerData[playerid][pFactionRank];
            if(trank != 1 && trank != 2 && trank != 5)
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Only rank 1, 2 and 5 can transport."), 1;

            // [TEMP-DRUGHOUR] limitarea orara (19:00-23:59) pentru transportul de droguri e dezactivata temporar pentru testare (de readus)
            // new dhour, dminute, dsecond;
            // gettime(dhour, dminute, dsecond);
            // if(dhour < DRUG_TRANSPORT_HOUR_MIN || dhour > DRUG_TRANSPORT_HOUR_MAX)
            //     return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Transports are only available between "C_INFO"19:00"C_WHITE" and "C_INFO"23:59"C_WHITE"."), 1;

            new dveh = GetPlayerVehicleID(playerid);
            if(dveh == 0 || GetPlayerState(playerid) != PLAYER_STATE_DRIVER ||
               g_VehicleFactionOwner[dveh] != dfid || GetVehicleModel(dveh) != DRUG_HUNTLEY_MODEL)
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be driving your faction's Huntley."), 1;

            if(g_DrugStage[playerid] != DRUG_STAGE_NONE)
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You already have a transport in progress."), 1;

            // al doilea membru al factiunii in vehicul
            new partner = INVALID_PLAYER_ID;
            for(new i = 0; i < MAX_PLAYERS; i++)
            {
                if(i == playerid || !IsPlayerConnected(i) || !PlayerData[i][pLogged]) continue;
                if(GetPlayerVehicleID(i) != dveh) continue;
                if(PlayerData[i][pFaction] != dfid) continue;
                partner = i;
                break;
            }
            // TEMPORAR: transportul se poate face si cu o singura persoana in masina.
            // De readus la minim 2 membri (vezi roadmap).
            // if(partner == INVALID_PLAYER_ID)
            //     return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You need a second faction member in the vehicle."), 1;

            if(g_DrugPickup[dfid][0] == 0.0 && g_DrugPickup[dfid][1] == 0.0)
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Your faction has no pickup location set yet."), 1;

            g_DrugStage[playerid]   = DRUG_STAGE_TOPICKUP;
            g_DrugPartner[playerid] = partner;
            SetPlayerCheckpoint(playerid, g_DrugPickup[dfid][0], g_DrugPickup[dfid][1], g_DrugPickup[dfid][2], DRUG_CP_SIZE);
            SendClientMessage(playerid, COLOR_INFO, C_INFO"[Drugs] "C_WHITE"Your brother from the countryside prepared a proper shipment. Hurry and bring the goods to HQ.");
            return 1;
        }
        else if(strcmp(sub, "craft", true) == 0)
        {
            new drank = PlayerData[playerid][pFactionRank];
            if(drank < 3 || drank > 5)
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Only rank 3, 4 and 5 can craft."), 1;

            if(!IsPlayerInRangeOfPoint(playerid, DRUG_CRAFT_RANGE, DRUG_CRAFT_X, DRUG_CRAFT_Y, DRUG_CRAFT_Z))
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be at the crafting machine."), 1;

            new need = 200 + random(100);
            if(FactionData[dfid][fSeifHerbs] < need)
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Not enough weed in the vault."), 1;

            FactionData[dfid][fSeifHerbs] -= need;
            Faction_SaveSeif(dfid);

            TogglePlayerControllable(playerid, 0);
            GameTextForPlayer(playerid, "~w~Crafting...", DRUG_CRAFT_FREEZE * 1000, 3);
            SetTimerEx("DrugCraft_Finish", DRUG_CRAFT_FREEZE * 1000, false, "i", playerid);
            return 1;
        }
        else if(strcmp(sub, "get", true) == 0)
        {
            if(!IsPlayerInRangeOfPoint(playerid, DRUG_CRAFT_RANGE, DRUG_SEIF_X, DRUG_SEIF_Y, DRUG_SEIF_Z))
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be at the vault."), 1;

            if(!War_FactionHasActiveWar(dfid))
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You can only take drugs during a war involving your faction."), 1;

            if(FactionData[dfid][fSeifDrugs] < DRUG_GET_AMOUNT)
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Not enough drugs in the vault."), 1;

            FactionData[dfid][fSeifDrugs] -= DRUG_GET_AMOUNT;
            Faction_SaveSeif(dfid);
            g_PlayerDrugs[playerid] += DRUG_GET_AMOUNT;

            new gmsg[128];
            format(gmsg, sizeof(gmsg), C_SUCCESS"[Drugs] "C_WHITE"You took "C_INFO"%dg"C_WHITE" of drugs. You now carry "C_INFO"%dg"C_WHITE".",
                DRUG_GET_AMOUNT, g_PlayerDrugs[playerid]);
            SendClientMessage(playerid, COLOR_SUCCESS, gmsg);
            return 1;
        }
        else if(strcmp(sub, "use", true) == 0)
        {
            new Float:ux, Float:uy, Float:uz;
            GetPlayerPos(playerid, ux, uy, uz);
            if(War_FindActiveWarForFactionAt(dfid, ux, uy) == -1)
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You can only use drugs inside the turf of an active war."), 1;

            if(g_PlayerDrugs[playerid] < DRUG_GET_AMOUNT)
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't carry enough drugs."), 1;

            g_PlayerDrugs[playerid] -= DRUG_GET_AMOUNT;

            new Float:uhp;
            GetPlayerHealth(playerid, uhp);
            uhp += DRUG_USE_HEAL;
            if(uhp > 100.0) uhp = 100.0;
            SetPlayerHealth(playerid, uhp);

            ApplyAnimation(playerid, "CRACK", "crckidle2", 4.0, 0, 0, 0, 0, 0, 1);
            TogglePlayerControllable(playerid, 0);
            SetTimerEx("Drug_Unfreeze", DRUG_USE_FREEZE * 1000, false, "i", playerid);

            SendClientMessage(playerid, COLOR_SUCCESS, C_SUCCESS"[Drugs] "C_WHITE"You injected drugs. "C_SUCCESS"+30 HP"C_WHITE".");
            return 1;
        }

        SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/drugs [transport/craft/get/use]"C_WHITE".");
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
            new wcMsg[350];

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

        // ---- /accept uber (un sofer uber preia cel mai apropiat pasager care a cerut cursa) ----
        if(strcmp(sub, "uber", true) == 0)
        {
            if(!g_UberOnDuty[playerid])
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You are not on duty as an Uber driver."), 1;

            if(g_UberPassenger[playerid] != INVALID_PLAYER_ID)
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You already have a passenger."), 1;

            new best = INVALID_PLAYER_ID;
            new Float:bestDist = 99999.0;
            for(new i = 0; i < MAX_PLAYERS; i++)
            {
                if(!IsPlayerConnected(i) || !PlayerData[i][pLogged]) continue;
                if(!g_UberWantsRide[i] || g_UberDriver[i] != INVALID_PLAYER_ID) continue;
                new Float:px, Float:py, Float:pz;
                GetPlayerPos(i, px, py, pz);
                new Float:d = GetPlayerDistanceFromPoint(playerid, px, py, pz);
                if(d < bestDist) { bestDist = d; best = i; }
            }

            if(best == INVALID_PLAYER_ID)
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Nobody is waiting for an Uber right now."), 1;

            g_UberPassenger[playerid] = best;
            g_UberDriver[best]        = playerid;
            g_UberWantsRide[best]     = false;

            new Float:tx, Float:ty, Float:tz;
            GetPlayerPos(best, tx, ty, tz);
            SetPlayerCheckpoint(playerid, tx, ty, tz, UBER_CP_SIZE);

            new umsg[144];
            format(umsg, sizeof(umsg), C_SUCCESS"[Uber] "C_WHITE"You accepted "C_INFO"%s"C_WHITE"'s ride. Drive to the checkpoint.", PlayerData[best][pName]);
            SendClientMessage(playerid, COLOR_SUCCESS, umsg);
            format(umsg, sizeof(umsg), C_SUCCESS"[Uber] "C_WHITE"%s"C_WHITE" is coming to pick you up. Get in when they arrive.", PlayerData[playerid][pName]);
            SendClientMessage(best, COLOR_SUCCESS, umsg);
            return 1;
        }

        // ---- /accept newspaper [sellerid] (cumpara ziarul oferit) ----
        if(strcmp(sub, "newspaper", true) == 0)
        {
            if(!strlen(p1))
                return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/accept newspaper [playerid]"C_WHITE"."), 1;

            new sellerid = strval(p1);
            if(g_NewsOfferSeller[playerid] == INVALID_PLAYER_ID || g_NewsOfferSeller[playerid] != sellerid)
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have a pending newspaper offer from this player."), 1;

            if(!IsPlayerConnected(sellerid) || !PlayerData[sellerid][pLogged])
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"The seller is no longer connected."), 1;

            new amount = g_NewsOfferAmount[playerid];
            if(PlayerData[playerid][pMoney] < amount)
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have enough money."), 1;

            PlayerData[playerid][pMoney] -= amount;
            GivePlayerMoney(playerid, -amount);
            PlayerData[sellerid][pMoney] += amount;
            GivePlayerMoney(sellerid, amount);

            for(new n = 0; n < NEWS_MAX_ITEMS; n++)
                format(g_OwnedNewsItem[playerid][n], NEWS_ITEM_LEN, "%s", g_NewspaperItem[sellerid][n]);
            format(g_OwnedNewsAuthor[playerid], 24, "%s", PlayerData[sellerid][pName]);
            g_HasNewspaper[playerid] = true;

            g_NewsOfferSeller[playerid] = INVALID_PLAYER_ID;
            g_NewsOfferAmount[playerid] = 0;

            new npmsg[160];
            format(npmsg, sizeof(npmsg), C_SUCCESS"Success: "C_WHITE"You bought a newspaper from "C_INFO"%s"C_WHITE" for "C_INFO"$%s"C_WHITE". Read it with "C_INFO"/newspaper open"C_WHITE".",
                PlayerData[sellerid][pName], MoneyStr(amount));
            SendClientMessage(playerid, COLOR_SUCCESS, npmsg);
            format(npmsg, sizeof(npmsg), C_SUCCESS"Success: "C_WHITE"%s"C_WHITE" bought your newspaper for "C_INFO"$%s"C_WHITE".",
                PlayerData[playerid][pName], MoneyStr(amount));
            SendClientMessage(sellerid, COLOR_SUCCESS, npmsg);
            return 1;
        }

        // ---- /accept qa [reporterid] (invitatul accepta live-ul Q&A) ----
        if(strcmp(sub, "qa", true) == 0)
        {
            if(!strlen(p1))
                return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/accept qa [reporterid]"C_WHITE"."), 1;

            new rid = strval(p1);
            if(g_QAPendingReporter == INVALID_PLAYER_ID || g_QAPendingGuest != playerid || g_QAPendingReporter != rid)
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have a pending Q&A invite from this player."), 1;
            if(!IsPlayerConnected(rid) || !PlayerData[rid][pLogged])
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"The reporter is no longer connected."), 1;

            g_QAActive          = true;
            g_QAReporter        = rid;
            g_QAGuest           = playerid;
            g_QAPendingReporter = INVALID_PLAYER_ID;
            g_QAPendingGuest    = INVALID_PLAYER_ID;
            g_QACount           = 0;

            new qamsg[220];
            format(qamsg, sizeof(qamsg), "{85648C}[Q&A] "C_WHITE"Live started! Reporter "C_INFO"%s"C_WHITE" is interviewing "C_INFO"%s"C_WHITE". Submit questions with "C_INFO"/question [text]"C_WHITE".",
                PlayerData[rid][pName], PlayerData[playerid][pName]);
            QA_Broadcast(qamsg);
            return 1;
        }

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

    // ---- /fkick, /funinvite [playerid] (rank 5 Lead: scoate un membru din propria factiune) ----
    if(strcmp(cmd, "/fkick", true) == 0 || strcmp(cmd, "/funinvite", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        new fid = PlayerData[playerid][pFaction];
        if(fid < 1 || fid > MAX_FACTIONS)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You are not part of a faction."), 1;

        if(PlayerData[playerid][pFactionRank] < 5)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Requires rank 5 (Lead)."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new fkp1[8];
        strmid(fkp1, cmdtext, idx, strlen(cmdtext), 8);
        if(!strlen(fkp1))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/fkick [playerid]"C_WHITE"."), 1;

        new targetid = strval(fkp1);
        if(!IsPlayerConnected(targetid) || !PlayerData[targetid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"The player is not connected."), 1;

        if(targetid == playerid)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You can't kick yourself."), 1;

        if(PlayerData[targetid][pFaction] != fid)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"The player is not part of your faction."), 1;

        if(PlayerData[targetid][pFactionRank] >= 5)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You can't kick another Lead."), 1;

        // Reseteaza playerul scos
        PlayerData[targetid][pFaction]     = 0;
        PlayerData[targetid][pFactionRank] = 1;
        PlayerData[targetid][pFactionJoin] = 0;
        SetPlayerColor(targetid, FactionColors[FACTION_NONE]);
        Factions_SetPlayerIcons(targetid);
        Player_RecalcSpawn(targetid);

        new q[160];
        mysql_format(g_SQL, q, sizeof(q),
            "UPDATE `players` SET `faction`=0, `faction_rank`=1, `faction_join`=NULL WHERE `id`=%d",
            PlayerData[targetid][pID]);
        mysql_tquery(g_SQL, q, "", "", 0);

        // Scade fMembers la factiune
        FactionData[fid][fMembers]--;
        if(FactionData[fid][fMembers] < 0) FactionData[fid][fMembers] = 0;
        mysql_format(g_SQL, q, sizeof(q), "UPDATE `factions` SET `members`=%d WHERE `id`=%d",
            FactionData[fid][fMembers], fid);
        mysql_tquery(g_SQL, q, "", "", 0);

        new fkmsg[144];
        format(fkmsg, sizeof(fkmsg), C_SUCCESS"Success: "C_WHITE"You removed "C_INFO"%s"C_WHITE" from the faction.", PlayerData[targetid][pName]);
        SendClientMessage(playerid, COLOR_SUCCESS, fkmsg);
        SendClientMessage(targetid, COLOR_ERROR, C_ERROR"Info: "C_WHITE"You were kicked from your faction by the leader.");

        SetPlayerHealth(targetid, 0.0); // moare la scoaterea din factiune
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
            SendClientMessage(playerid, COLOR_WHITE, C_INFO"[Rank 5] "C_WHITE"/fbankwithdraw /fsetrank /fkick");

        if(fid == FACTION_RAR || fid == FACTION_POLICE)
            SendClientMessage(playerid, COLOR_WHITE, C_INFO"[RAR/Police, On-Duty] "C_WHITE"/fine /m /inspectcar");

        if(fid == FACTION_RAR && rank >= 3)
            SendClientMessage(playerid, COLOR_WHITE, C_INFO"[RAR, Rank 3+, On-Duty] "C_WHITE"/confiscate");

        if(fid == FACTION_POLICE && rank >= 2)
            SendClientMessage(playerid, COLOR_WHITE, C_INFO"[Police, Rank 2+, On-Duty] "C_WHITE"/confiscate insurance /confiscate licence /inspectplayer");

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

        // Politia Romana: /duty se face la punctul dedicat (locations_admin "PR/duty"); restul factiunilor: interiorul HQ
        if(fid == FACTION_POLICE && (DUTY_LOC_X != 0.0 || DUTY_LOC_Y != 0.0))
        {
            if(GetPlayerInterior(playerid) != DUTY_LOC_INT || GetPlayerVirtualWorld(playerid) != DUTY_LOC_VW ||
               !IsPlayerInRangeOfPoint(playerid, DUTY_LOC_RANGE, DUTY_LOC_X, DUTY_LOC_Y, DUTY_LOC_Z))
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be at the police duty point inside the LSPD."), 1;
        }
        else if(!Factions_IsInOwnInterior(playerid))
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

    // ---- /wanted [playerid] [wanted_level 0-6] [reason] (Politia rank 1+) ----
    if(strcmp(cmd, "/wanted", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;
        if(PlayerData[playerid][pFaction] != FACTION_POLICE)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Only Politia Romana can use this."), 1;
        if(PlayerData[playerid][pFactionRank] < 1)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Requires faction rank 1+."), 1;
        if(!PlayerData[playerid][pOnDuty])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be on-duty to use this command."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new wp1[8]; strmid(wp1, cmdtext, idx, strlen(cmdtext), 8);
        while(cmdtext[idx] > ' ') idx++; while(cmdtext[idx] == ' ') idx++;
        new wp2[8]; strmid(wp2, cmdtext, idx, strlen(cmdtext), 8);
        while(cmdtext[idx] > ' ') idx++; while(cmdtext[idx] == ' ') idx++;
        new wreason[128]; strmid(wreason, cmdtext, idx, strlen(cmdtext), 128);

        if(!strlen(wp1) || !strlen(wp2))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/wanted [playerid] [wanted_level 0-6] [reason]"C_WHITE"."), 1;

        new wtarget = strval(wp1);
        new wlevel  = strval(wp2);
        if(!IsPlayerConnected(wtarget) || !PlayerData[wtarget][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"The player is not connected."), 1;
        if(wlevel < 0 || wlevel > 6)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Wanted level must be between 0 and 6."), 1;
        if(!strlen(wreason)) format(wreason, sizeof(wreason), "No reason");

        PlayerData[wtarget][pWanted] = wlevel;
        SetPlayerWantedLevel(wtarget, wlevel);
        UpdatePlayer(wtarget, pWanted);

        new wmsg[220];
        format(wmsg, sizeof(wmsg), C_INFO"[P.R.] "C_WHITE"Officer "C_INFO"%s"C_WHITE" (rank %d) set "C_INFO"%s"C_WHITE"'s wanted level to "C_INFO"%d star(s)"C_WHITE".",
            PlayerData[playerid][pName], PlayerData[playerid][pFactionRank], PlayerData[wtarget][pName], PlayerData[wtarget][pWanted]);
        for(new i = 0; i < MAX_PLAYERS; i++)
            if(IsPlayerConnected(i) && PlayerData[i][pLogged] && PlayerData[i][pFaction] == FACTION_POLICE)
                SendClientMessage(i, COLOR_WHITE, wmsg);

        new wtmsg[200];
        format(wtmsg, sizeof(wtmsg), C_ERROR"[WANTED] "C_WHITE"Officer "C_INFO"%s"C_WHITE" set your wanted level to "C_INFO"%d star(s)"C_WHITE". Reason: "C_INFO"%s",
            PlayerData[playerid][pName], PlayerData[wtarget][pWanted], wreason);
        SendClientMessage(wtarget, COLOR_WHITE, wtmsg);
        return 1;
    }

    // ---- /wantedlist (Politia: lista jucatorilor cu wanted) ----
    if(strcmp(cmd, "/wantedlist", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;
        if(PlayerData[playerid][pFaction] != FACTION_POLICE)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Only Politia Romana can use this."), 1;

        SendClientMessage(playerid, COLOR_INFO, C_INFO"===== Wanted List =====");
        new wlAny = 0;
        for(new i = 0; i < MAX_PLAYERS; i++)
        {
            if(!IsPlayerConnected(i) || !PlayerData[i][pLogged]) continue;
            if(PlayerData[i][pWanted] <= 0) continue;
            new wl[96];
            format(wl, sizeof(wl), C_WHITE"%s "C_ERROR"- Wanted %d", PlayerData[i][pName], PlayerData[i][pWanted]);
            SendClientMessage(playerid, COLOR_WHITE, wl);
            wlAny++;
        }
        if(!wlAny) SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"No wanted players online.");
        return 1;
    }

    // ---- /adminwanted [playerid] [wantedlevel] (admin: seteaza direct nivelul de wanted) ----
    if(strcmp(cmd, "/adminwanted", true) == 0)
    {
        if(PlayerData[playerid][pAdminLevel] < 1)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have access. Requires admin level 1."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new awp1[8], awa = 0;
        while(cmdtext[idx] > ' ' && awa < 7) { awp1[awa++] = cmdtext[idx]; idx++; }
        awp1[awa] = EOS;
        while(cmdtext[idx] == ' ') idx++;
        new awp2[8]; strmid(awp2, cmdtext, idx, strlen(cmdtext), 8);
        if(!strlen(awp1) || !strlen(awp2))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/adminwanted [playerid] [wantedlevel]"C_WHITE" (0-6)."), 1;

        new awtarget = strval(awp1), awlevel = strval(awp2);
        if(!IsPlayerConnected(awtarget) || !PlayerData[awtarget][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"The player is not connected."), 1;
        if(awlevel < 0 || awlevel > 6)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Wanted level must be between 0 and 6."), 1;

        PlayerData[awtarget][pWanted] = awlevel;
        SetPlayerWantedLevel(awtarget, awlevel);
        UpdatePlayer(awtarget, pWanted);

        new awmsg[144];
        format(awmsg, sizeof(awmsg), C_SUCCESS"[ADM] Success: "C_WHITE"Set "C_INFO"%s"C_WHITE"'s wanted level to "C_INFO"%d"C_WHITE".",
            PlayerData[awtarget][pName], awlevel);
        SendClientMessage(playerid, COLOR_SUCCESS, awmsg);
        return 1;
    }

    // ---- /arrest [playerid] (Politia: rank 2 -> wanted 1-4; rank 3+ -> wanted 1-6) ----
    if(strcmp(cmd, "/arrest", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;
        if(PlayerData[playerid][pFaction] != FACTION_POLICE)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Only Politia Romana can use this."), 1;
        if(PlayerData[playerid][pFactionRank] < 2)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Requires faction rank 2+."), 1;

        // In una dintre zonele de arest (interior LSPD sau exterior/garaj), daca sunt configurate
        new bool:zone1Set = (ARREST_ZONE_X != 0.0 || ARREST_ZONE_Y != 0.0);
        new bool:zone2Set = (ARREST_ZONE2_X != 0.0 || ARREST_ZONE2_Y != 0.0);
        if(zone1Set || zone2Set)
        {
            new bool:inZone = false;
            if(zone1Set && IsPlayerInRangeOfPoint(playerid, ARREST_ZONE_RANGE, ARREST_ZONE_X, ARREST_ZONE_Y, ARREST_ZONE_Z))  inZone = true;
            if(zone2Set && IsPlayerInRangeOfPoint(playerid, ARREST_ZONE_RANGE, ARREST_ZONE2_X, ARREST_ZONE2_Y, ARREST_ZONE2_Z)) inZone = true;
            if(!inZone)
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be in an arrest zone (LSPD interior or garage)."), 1;
        }

        while(cmdtext[idx] == ' ') idx++;
        new arp1[8];
        strmid(arp1, cmdtext, idx, strlen(cmdtext), 8);
        if(!strlen(arp1))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/arrest [playerid]"C_WHITE"."), 1;

        new artarget = strval(arp1);
        if(!IsPlayerConnected(artarget) || !PlayerData[artarget][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"The player is not connected."), 1;
        // [TEMP-SELF] permite auto-arestul pentru testare (de scos)
        // if(artarget == playerid)
        //     return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You can't arrest yourself."), 1;

        new arwl = PlayerData[artarget][pWanted];
        if(arwl < 1)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"That player is not wanted."), 1;

        new maxWanted = (PlayerData[playerid][pFactionRank] >= 3) ? 6 : 4;
        if(arwl > maxWanted)
        {
            new mwmsg[128];
            format(mwmsg, sizeof(mwmsg), C_ERROR"Error: "C_WHITE"Your rank can only arrest suspects up to wanted level "C_INFO"%d"C_WHITE".", maxWanted);
            return SendClientMessage(playerid, COLOR_ERROR, mwmsg), 1;
        }

        // Inculpatul trebuie sa fie langa politist
        new Float:arx, Float:ary, Float:arz;
        GetPlayerPos(playerid, arx, ary, arz);
        if(!IsPlayerInRangeOfPoint(artarget, ARREST_SUSPECT_RANGE, arx, ary, arz))
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"The suspect must be next to you (5m)."), 1;

        new minutes = g_JailMinutes[arwl];
        new fine    = g_JailFine[arwl];

        // Ia banii (cat poate plati)
        new paid = fine;
        if(PlayerData[artarget][pMoney] < paid) paid = PlayerData[artarget][pMoney];
        if(paid < 0) paid = 0;

        new vaultCut = paid * 10 / 100;   // 10% in seiful factiunii 1
        new copGets  = paid - vaultCut;

        if(paid > 0)
        {
            PlayerData[artarget][pMoney] -= paid;
            GivePlayerMoney(artarget, -paid);
            UpdatePlayer(artarget, pMoney);
        }
        if(copGets > 0)
        {
            PlayerData[playerid][pMoney] += copGets;
            GivePlayerMoney(playerid, copGets);
            UpdatePlayer(playerid, pMoney);
        }
        if(vaultCut > 0) Faction_AddBank(FACTION_POLICE, vaultCut);

        // Reseteaza wanted-ul
        PlayerData[artarget][pWanted] = 0;
        SetPlayerWantedLevel(artarget, 0);
        UpdatePlayer(artarget, pWanted);

        // Baga in inchisoare
        PlayerData[artarget][pJailSeconds] = minutes * 60;
        UpdatePlayer(artarget, pJailSeconds);
        Jail_Send(artarget);

        // Anunt catre toti politistii
        new armsg[220];
        format(armsg, sizeof(armsg), C_INFO"[P.R.] "C_WHITE"Officer "C_INFO"%s"C_WHITE" (rank %d) arrested suspect "C_INFO"%s"C_WHITE" (wanted level "C_INFO"%d"C_WHITE").",
            PlayerData[playerid][pName], PlayerData[playerid][pFactionRank], PlayerData[artarget][pName], arwl);
        for(new i = 0; i < MAX_PLAYERS; i++)
            if(IsPlayerConnected(i) && PlayerData[i][pLogged] && PlayerData[i][pFaction] == FACTION_POLICE)
                SendClientMessage(i, COLOR_WHITE, armsg);

        // Anunt catre inculpat
        new artmsg[200];
        format(artmsg, sizeof(artmsg), C_INFO"[P.R.] "C_WHITE"You were arrested by officer "C_INFO"%s"C_WHITE". You will serve "C_INFO"%d minute(s)"C_WHITE" in jail. You paid "C_INFO"$%s"C_WHITE".",
            PlayerData[playerid][pName], minutes, MoneyStr(paid));
        SendClientMessage(artarget, COLOR_WHITE, artmsg);
        return 1;
    }

    // ---- /refillfactionveh (rank 5+: alimenteaza TOATE vehiculele factiunii la maxim) ----
    if(strcmp(cmd, "/refillfactionveh", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;
        if(PlayerData[playerid][pFaction] < 1 || PlayerData[playerid][pFaction] > MAX_FACTIONS)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You are not part of a faction."), 1;
        if(PlayerData[playerid][pFactionRank] < 5)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Requires faction rank 5+."), 1;

        new rfFid = PlayerData[playerid][pFaction], rfCount = 0;
        for(new v = 0; v < MAX_VEHICLES; v++)
        {
            if(g_VehicleFactionOwner[v] != rfFid) continue;
            g_VehicleFuel[v] = FUEL_MAX;
            Vehicle_SaveFuel(v);
            rfCount++;
        }

        new rfmsg[128];
        format(rfmsg, sizeof(rfmsg), C_SUCCESS"Success: "C_WHITE"Refueled all faction vehicles ("C_INFO"%d"C_WHITE") to "C_INFO"100%%"C_WHITE".", rfCount);
        SendClientMessage(playerid, COLOR_SUCCESS, rfmsg);
        return 1;
    }

    // ---- /respawnfactionveh (rank 5+: respawn la TOATE vehiculele factiunii) ----
    if(strcmp(cmd, "/respawnfactionveh", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;
        if(PlayerData[playerid][pFaction] < 1 || PlayerData[playerid][pFaction] > MAX_FACTIONS)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You are not part of a faction."), 1;
        if(PlayerData[playerid][pFactionRank] < 5)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Requires faction rank 5+."), 1;

        new rsFid = PlayerData[playerid][pFaction], rsCount = 0;
        for(new v = 0; v < MAX_VEHICLES; v++)
        {
            if(g_VehicleFactionOwner[v] != rsFid) continue;
            SetVehicleToRespawn(v);
            rsCount++;
        }

        new rsmsg[128];
        format(rsmsg, sizeof(rsmsg), C_SUCCESS"Success: "C_WHITE"Respawned all faction vehicles ("C_INFO"%d"C_WHITE").", rsCount);
        SendClientMessage(playerid, COLOR_SUCCESS, rsmsg);
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
                return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/confiscate licence [A/B/C/D/P/H/all] [playerid]"C_WHITE"."), 1;

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
                PlayerData[targetid][pAirLicA_exp][0] = EOS; // P = avion
                PlayerData[targetid][pAirLicH_exp][0] = EOS; // H = elicopter

                mysql_format(g_SQL, lq, sizeof(lq),
                    "UPDATE `players` SET `driving_lic_a_exp`=NULL, `driving_lic_b_exp`=NULL, `driving_lic_c_exp`=NULL, `driving_lic_d_exp`=NULL, `airplane_lic_a_exp`=NULL, `airplane_lic_h_exp`=NULL WHERE `id`=%d",
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
            else if(strcmp(lp1, "P", true) == 0) // P = permis avion
            {
                PlayerData[targetid][pAirLicA_exp][0] = EOS;
                mysql_format(g_SQL, lq, sizeof(lq), "UPDATE `players` SET `airplane_lic_a_exp`=NULL WHERE `id`=%d", PlayerData[targetid][pID]);
                format(catLabel, sizeof(catLabel), "P");
            }
            else if(strcmp(lp1, "H", true) == 0) // H = permis elicopter
            {
                PlayerData[targetid][pAirLicH_exp][0] = EOS;
                mysql_format(g_SQL, lq, sizeof(lq), "UPDATE `players` SET `airplane_lic_h_exp`=NULL WHERE `id`=%d", PlayerData[targetid][pID]);
                format(catLabel, sizeof(catLabel), "H");
            }
            else
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Invalid category. Use A, B, C, D, P, H or all."), 1;

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
        format(rmsg, sizeof(rmsg), C_SUCCESS"[ADM] Success: "C_WHITE"Removed "C_INFO"%s"C_WHITE"'s radar (ID "C_INFO"%d"C_WHITE").", ownerName, radarid);
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

        SetPlayerHealth(targetid, 0.0);

        new adminName[24];
        GetPlayerName(playerid, adminName, 24);

        new msg[128];
        format(msg, sizeof(msg), C_SUCCESS"[ADM] Success: "C_WHITE"You set "C_INFO"%s"C_WHITE"'s HP to 0.",
            PlayerData[targetid][pName]);
        SendClientMessage(playerid, COLOR_SUCCESS, msg);
        return 1;
    }

    // ---- /mute [playerid] [minute] [motiv] ----
    if(strcmp(cmd, "/mute", true) == 0)
    {
        if(PlayerData[playerid][pAdminLevel] < 2)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have access. Requires admin level 2."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new p1[8]; strmid(p1, cmdtext, idx, strlen(cmdtext), 8);
        while(cmdtext[idx] > ' ') idx++; while(cmdtext[idx] == ' ') idx++;
        new p2[8]; strmid(p2, cmdtext, idx, strlen(cmdtext), 8);
        while(cmdtext[idx] > ' ') idx++; while(cmdtext[idx] == ' ') idx++;
        new reason[128]; strmid(reason, cmdtext, idx, strlen(cmdtext), 128);

        if(!strlen(p1) || !strlen(p2))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/mute [playerid] [minutes] [reason]"C_WHITE"."), 1;

        new targetid = strval(p1);
        new minutes  = strval(p2);
        if(!IsPlayerConnected(targetid) || !PlayerData[targetid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"The player is not connected."), 1;
        if(targetid == playerid)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You can't mute yourself."), 1;
        if(PlayerData[targetid][pAdminLevel] >= PlayerData[playerid][pAdminLevel])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You can't moderate an admin of equal or higher level."), 1;
        if(minutes <= 0)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Minutes must be greater than 0."), 1;
        if(!strlen(reason)) format(reason, sizeof(reason), "No reason");

        PlayerData[targetid][pMuteExpire] = gettime() + minutes * 60;
        UpdatePlayer(targetid, pMuteExpire);

        new bmsg[160];
        format(bmsg, sizeof(bmsg), C_ERROR"[ADM] "C_INFO"%s"C_WHITE" was muted by "C_INFO"%s"C_WHITE" for "C_INFO"%d"C_WHITE" min. Reason: "C_INFO"%s",
            PlayerData[targetid][pName], PlayerData[playerid][pName], minutes, reason);
        SendClientMessageToAll(COLOR_INFO, bmsg);
        return 1;
    }

    // ---- /unmute [playerid] ----
    if(strcmp(cmd, "/unmute", true) == 0)
    {
        if(PlayerData[playerid][pAdminLevel] < 2)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have access. Requires admin level 2."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new p1[8]; strmid(p1, cmdtext, idx, strlen(cmdtext), 8);
        if(!strlen(p1))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/unmute [playerid]"C_WHITE"."), 1;

        new targetid = strval(p1);
        if(!IsPlayerConnected(targetid) || !PlayerData[targetid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"The player is not connected."), 1;
        if(PlayerData[targetid][pMuteExpire] == 0)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"That player is not muted."), 1;

        PlayerData[targetid][pMuteExpire] = 0;
        UpdatePlayer(targetid, pMuteExpire);

        new bmsg[144];
        format(bmsg, sizeof(bmsg), C_SUCCESS"[ADM] "C_INFO"%s"C_WHITE" was unmuted by "C_INFO"%s"C_WHITE".",
            PlayerData[targetid][pName], PlayerData[playerid][pName]);
        SendClientMessageToAll(COLOR_INFO, bmsg);
        return 1;
    }

    // ---- /kick [playerid] [motiv] ----
    if(strcmp(cmd, "/kick", true) == 0)
    {
        if(PlayerData[playerid][pAdminLevel] < 2)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have access. Requires admin level 2."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new p1[8]; strmid(p1, cmdtext, idx, strlen(cmdtext), 8);
        while(cmdtext[idx] > ' ') idx++; while(cmdtext[idx] == ' ') idx++;
        new reason[128]; strmid(reason, cmdtext, idx, strlen(cmdtext), 128);

        if(!strlen(p1))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/kick [playerid] [reason]"C_WHITE"."), 1;

        new targetid = strval(p1);
        if(!IsPlayerConnected(targetid) || !PlayerData[targetid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"The player is not connected."), 1;
        if(targetid == playerid)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You can't kick yourself."), 1;
        if(PlayerData[targetid][pAdminLevel] >= PlayerData[playerid][pAdminLevel])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You can't moderate an admin of equal or higher level."), 1;
        if(!strlen(reason)) format(reason, sizeof(reason), "No reason");

        new bmsg[160];
        format(bmsg, sizeof(bmsg), C_ERROR"[ADM] "C_INFO"%s"C_WHITE" was kicked by "C_INFO"%s"C_WHITE". Reason: "C_INFO"%s",
            PlayerData[targetid][pName], PlayerData[playerid][pName], reason);
        SendClientMessageToAll(COLOR_INFO, bmsg);

        new tmsg[160];
        format(tmsg, sizeof(tmsg), C_ERROR"You were kicked."C_WHITE" Reason: "C_INFO"%s", reason);
        SendClientMessage(targetid, COLOR_ERROR, tmsg);

        Admin_KickDelayed(targetid);
        return 1;
    }

    // ---- /ban [playerid] [motiv] ----
    if(strcmp(cmd, "/ban", true) == 0)
    {
        if(PlayerData[playerid][pAdminLevel] < 4)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have access. Requires admin level 4."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new p1[8]; strmid(p1, cmdtext, idx, strlen(cmdtext), 8);
        while(cmdtext[idx] > ' ') idx++; while(cmdtext[idx] == ' ') idx++;
        new reason[128]; strmid(reason, cmdtext, idx, strlen(cmdtext), 128);

        if(!strlen(p1))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/ban [playerid] [reason]"C_WHITE"."), 1;

        new targetid = strval(p1);
        if(!IsPlayerConnected(targetid) || !PlayerData[targetid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"The player is not connected."), 1;
        if(targetid == playerid)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You can't ban yourself."), 1;
        if(PlayerData[targetid][pAdminLevel] >= PlayerData[playerid][pAdminLevel])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You can't moderate an admin of equal or higher level."), 1;
        if(!strlen(reason)) format(reason, sizeof(reason), "No reason");

        new ip[46];
        GetPlayerIp(targetid, ip, sizeof(ip));

        new q[256];
        mysql_format(g_SQL, q, sizeof(q),
            "INSERT INTO `bans` (`username`,`ip`,`reason`,`banned_by`,`ban_date`) VALUES ('%e','%e','%e','%e',%d)",
            PlayerData[targetid][pName], ip, reason, PlayerData[playerid][pName], gettime());
        mysql_tquery(g_SQL, q, "", "", 0);

        new bmsg[176];
        format(bmsg, sizeof(bmsg), C_ERROR"[ADM] "C_INFO"%s"C_WHITE" was banned by "C_INFO"%s"C_WHITE". Reason: "C_INFO"%s",
            PlayerData[targetid][pName], PlayerData[playerid][pName], reason);
        SendClientMessageToAll(COLOR_INFO, bmsg);

        new tmsg[160];
        format(tmsg, sizeof(tmsg), C_ERROR"You have been banned."C_WHITE" Reason: "C_INFO"%s", reason);
        SendClientMessage(targetid, COLOR_ERROR, tmsg);

        Admin_KickDelayed(targetid);
        return 1;
    }

    // ---- /unban [nume] ----
    if(strcmp(cmd, "/unban", true) == 0)
    {
        if(PlayerData[playerid][pAdminLevel] < 4)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have access. Requires admin level 4."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new uname[24]; strmid(uname, cmdtext, idx, strlen(cmdtext), 24);
        if(!strlen(uname))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/unban [username]"C_WHITE"."), 1;

        new q[128];
        mysql_format(g_SQL, q, sizeof(q), "DELETE FROM `bans` WHERE `username`='%e'", uname);
        mysql_tquery(g_SQL, q, "", "", 0);

        new bmsg[144];
        format(bmsg, sizeof(bmsg), C_SUCCESS"[ADM] Success: "C_WHITE"Removed any ban for username "C_INFO"%s"C_WHITE".", uname);
        SendClientMessage(playerid, COLOR_SUCCESS, bmsg);
        return 1;
    }

    // ---- /businesslist ----
    if(strcmp(cmd, "/businesslist", true) == 0)
    {
        if(PlayerData[playerid][pAdminLevel] < 1)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have access. Requires admin level 1."), 1;

        static list[4096];
        list[0] = EOS;
        strcat(list, "ID\tName\tOwner\tPrice\n");
        for(new i = 0; i < g_BusinessCount; i++)
        {
            new owner[24];
            if(BusinessData[i][bOwned]) format(owner, sizeof(owner), "%s", BusinessData[i][bOwner]);
            else format(owner, sizeof(owner), "-");

            new line[200];
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

        static list[10000];
        list[0] = EOS;
        strcat(list, ""C_INFO"ID\t"C_INFO"Name\t"C_INFO"Owner / Status\t"C_INFO"Price\n");
        for(new i = 0; i < g_BusinessCount; i++)
        {
            new bizState[40];
            if(BusinessData[i][bOwned]) format(bizState, sizeof(bizState), ""C_WHITE"%s", BusinessData[i][bOwner]);
            else format(bizState, sizeof(bizState), ""C_ERROR"For Sale");

            new line[220];
            format(line, sizeof(line), ""C_WHITE"#%d\t"C_WHITE"%s\t%s\t"C_SUCCESS"$%s\n",
                BusinessData[i][bID], BusinessData[i][bName], bizState, MoneyStr(BusinessData[i][bPrice]));
            strcat(list, line);
        }

        ShowPlayerDialog(playerid, DIALOG_BIZZLIST, DIALOG_STYLE_TABLIST_HEADERS, "Business List", list, "Teleport", "Close");
        return 1;
    }

    // ---- /farmlist (lista terenurilor cu teleport, admin 2+) ----
    if(strcmp(cmd, "/farmlist", true) == 0)
    {
        if(PlayerData[playerid][pAdminLevel] < 2)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have access. Requires admin level 2."), 1;

        if(g_FarmCount == 0)
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"There are no farms on the server."), 1;

        static list[10000];
        list[0] = EOS;
        strcat(list, ""C_INFO"ID\t"C_INFO"Owner / Status\t"C_INFO"Location\t"C_INFO"Price\n");
        for(new i = 0; i < g_FarmCount; i++)
        {
            new farmState[40];
            if(FarmData[i][fmOwned]) format(farmState, sizeof(farmState), ""C_WHITE"%s", FarmData[i][fmOwner]);
            else format(farmState, sizeof(farmState), ""C_ERROR"For Sale");

            new locState[16];
            if(FarmData[i][fmRange] > 0.0 || FarmData[i][fmX] != 0.0 || FarmData[i][fmY] != 0.0)
                format(locState, sizeof(locState), ""C_SUCCESS"set");
            else format(locState, sizeof(locState), ""C_ERROR"not set");

            new line[220];
            format(line, sizeof(line), ""C_WHITE"#%d\t%s\t%s\t"C_SUCCESS"$%s\n",
                FarmData[i][fmID], farmState, locState, MoneyStr(FarmData[i][fmPrice]));
            strcat(list, line);
        }

        ShowPlayerDialog(playerid, DIALOG_FARMLIST, DIALOG_STYLE_TABLIST_HEADERS, "Farm List", list, "Teleport", "Close");
        return 1;
    }

    // ---- /joblist (lista joburi cu teleport, admin 2+) ----
    if(strcmp(cmd, "/joblist", true) == 0)
    {
        if(PlayerData[playerid][pAdminLevel] < 2)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have access. Requires admin level 2."), 1;

        new list[1024];
        for(new i = 0; i < MAX_JOBS; i++)
        {
            new line[64];
            format(line, sizeof(line), "#%d. %s\n", i + 1, g_JobNames[i]);
            strcat(list, line);
        }

        ShowPlayerDialog(playerid, DIALOG_JOBLIST, DIALOG_STYLE_LIST, "Job List", list, "Teleport", "Close");
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
        format(msg, sizeof(msg), C_SUCCESS"[ADM] Success: "C_WHITE"You successfully healed "C_INFO"%s"C_WHITE".",
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
            C_SUCCESS"[ADM] Success: "C_WHITE"You successfully healed all players.");
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
            AC_SetPos(playerid, LocationData[lidx][locX], LocationData[lidx][locY], LocationData[lidx][locZ] + 0.1);

        AC_SetInterior(playerid, 0);
        AC_SetVW(playerid, 0);

        new lmsg[96];
        format(lmsg, sizeof(lmsg), C_SUCCESS"[ADM] Success: "C_WHITE"Teleported to "C_INFO"%s"C_WHITE".", LocationData[lidx][locName]);
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
            AC_SetPos(playerid, gx, gy, gz);

        new gxmsg[96];
        format(gxmsg, sizeof(gxmsg), C_SUCCESS"[ADM] Success: "C_WHITE"Teleported to "C_INFO"%.4f, %.4f, %.4f"C_WHITE".", gx, gy, gz);
        SendClientMessage(playerid, COLOR_SUCCESS, gxmsg);
        return 1;
    }

    // ---- /getcar [vehicleid] (aduce un vehicul existent la tine) ----
    if(strcmp(cmd, "/getcar", true) == 0)
    {
        if(PlayerData[playerid][pAdminLevel] < 2)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have access. Requires admin level 2."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new gcStr[8];
        strmid(gcStr, cmdtext, idx, strlen(cmdtext), 8);
        if(!strlen(gcStr))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/getcar [vehicleid]"C_WHITE"."), 1;

        new gcVeh = strval(gcStr);
        if(gcVeh < 1 || gcVeh >= MAX_VEHICLES || !GetVehicleModel(gcVeh))
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Invalid vehicle ID."), 1;

        new Float:gcx, Float:gcy, Float:gcz, Float:gca;
        GetPlayerPos(playerid, gcx, gcy, gcz);
        GetPlayerFacingAngle(playerid, gca);

        SetVehiclePos(gcVeh, gcx + (2.5 * floatsin(-gca, degrees)), gcy + (2.5 * floatcos(-gca, degrees)), gcz);
        SetVehicleZAngle(gcVeh, gca);
        LinkVehicleToInterior(gcVeh, GetPlayerInterior(playerid));
        SetVehicleVirtualWorld(gcVeh, GetPlayerVirtualWorld(playerid));

        new gcmsg[96];
        format(gcmsg, sizeof(gcmsg), C_SUCCESS"[ADM] Success: "C_WHITE"Vehicle "C_INFO"%d"C_WHITE" brought to your location.", gcVeh);
        SendClientMessage(playerid, COLOR_SUCCESS, gcmsg);
        return 1;
    }

    // ---- /gotocar [vehicleid] (teleporteaza-te la un vehicul existent) ----
    if(strcmp(cmd, "/gotocar", true) == 0)
    {
        if(PlayerData[playerid][pAdminLevel] < 2)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have access. Requires admin level 2."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new gtStr[8];
        strmid(gtStr, cmdtext, idx, strlen(cmdtext), 8);
        if(!strlen(gtStr))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/gotocar [vehicleid]"C_WHITE"."), 1;

        new gtVeh = strval(gtStr);
        if(gtVeh < 1 || gtVeh >= MAX_VEHICLES || !GetVehicleModel(gtVeh))
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Invalid vehicle ID."), 1;

        new Float:gtx, Float:gty, Float:gtz;
        GetVehiclePos(gtVeh, gtx, gty, gtz);

        new gtVW = GetVehicleVirtualWorld(gtVeh);
        new gtIn = GetPlayerVehicleID(playerid);
        if(gtIn != 0 && GetPlayerVehicleSeat(playerid) == 0)
        {
            SetVehiclePos(gtIn, gtx + 2.5, gty, gtz);
            SetVehicleVirtualWorld(gtIn, gtVW);
        }
        else
        {
            AC_SetPos(playerid, gtx + 2.5, gty, gtz);
        }
        AC_SetInterior(playerid, 0);
        AC_SetVW(playerid, gtVW);

        new gtmsg[96];
        format(gtmsg, sizeof(gtmsg), C_SUCCESS"[ADM] Success: "C_WHITE"Teleported to vehicle "C_INFO"%d"C_WHITE".", gtVeh);
        SendClientMessage(playerid, COLOR_SUCCESS, gtmsg);
        return 1;
    }

    // ---- /saveloc (salveaza temporar pozitia curenta) ----
    if(strcmp(cmd, "/saveloc", true) == 0)
    {
        if(PlayerData[playerid][pAdminLevel] < 2)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have access. Requires admin level 2."), 1;

        GetPlayerPos(playerid, g_SavedPos[playerid][0], g_SavedPos[playerid][1], g_SavedPos[playerid][2]);
        GetPlayerFacingAngle(playerid, g_SavedPos[playerid][3]);
        g_SavedInt[playerid] = GetPlayerInterior(playerid);
        g_SavedVW[playerid]  = GetPlayerVirtualWorld(playerid);
        g_HasSavedPos[playerid] = true;

        new svmsg[128];
        format(svmsg, sizeof(svmsg), C_SUCCESS"[ADM] Success: "C_WHITE"Position saved: "C_INFO"%.4f, %.4f, %.4f"C_WHITE" (a=%.2f, int=%d, vw=%d).",
            g_SavedPos[playerid][0], g_SavedPos[playerid][1], g_SavedPos[playerid][2], g_SavedPos[playerid][3], g_SavedInt[playerid], g_SavedVW[playerid]);
        SendClientMessage(playerid, COLOR_SUCCESS, svmsg);
        return 1;
    }

    // ---- /gotosave (teleporteaza la pozitia salvata) ----
    if(strcmp(cmd, "/gotosave", true) == 0)
    {
        if(PlayerData[playerid][pAdminLevel] < 2)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have access. Requires admin level 2."), 1;

        if(!g_HasSavedPos[playerid])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"No saved position. Use "C_INFO"/saveloc"C_WHITE" first."), 1;

        new Float:sx = g_SavedPos[playerid][0], Float:sy = g_SavedPos[playerid][1], Float:sz = g_SavedPos[playerid][2];
        new gsVeh = GetPlayerVehicleID(playerid);
        if(gsVeh != 0 && GetPlayerVehicleSeat(playerid) == 0)
        {
            SetVehiclePos(gsVeh, sx, sy, sz);
            SetVehicleZAngle(gsVeh, g_SavedPos[playerid][3]);
            LinkVehicleToInterior(gsVeh, g_SavedInt[playerid]);
            SetVehicleVirtualWorld(gsVeh, g_SavedVW[playerid]);
        }
        else
        {
            AC_SetPos(playerid, sx, sy, sz);
            SetPlayerFacingAngle(playerid, g_SavedPos[playerid][3]);
        }
        AC_SetInterior(playerid, g_SavedInt[playerid]);
        AC_SetVW(playerid, g_SavedVW[playerid]);

        new gsmsg[96];
        format(gsmsg, sizeof(gsmsg), C_SUCCESS"[ADM] Success: "C_WHITE"Teleported to saved position "C_INFO"%.4f, %.4f, %.4f"C_WHITE".", sx, sy, sz);
        SendClientMessage(playerid, COLOR_SUCCESS, gsmsg);
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
            AC_SetPos(playerid, BusinessData[bidx][bLocX], BusinessData[bidx][bLocY], BusinessData[bidx][bLocZ] + 0.1);

        new bmsg[144];
        format(bmsg, sizeof(bmsg), C_SUCCESS"[ADM] Success: "C_WHITE"Teleported to business "C_INFO"%s"C_WHITE".", BusinessData[bidx][bName]);
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
            AC_SetPos(playerid, HouseData[hidx][hLocX], HouseData[hidx][hLocY], HouseData[hidx][hLocZ] + 0.1);

        new hmsg[96];
        format(hmsg, sizeof(hmsg), C_SUCCESS"[ADM] Success: "C_WHITE"Teleported to house "C_INFO"%s"C_WHITE".", HouseData[hidx][hName]);
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
            AC_SetPos(playerid, FactionData[fid][fHQX], FactionData[fid][fHQY], FactionData[fid][fHQZ] + 0.1);

        new fmsg[96];
        format(fmsg, sizeof(fmsg), C_SUCCESS"[ADM] Success: "C_WHITE"Teleported to "C_INFO"%s"C_WHITE" HQ.", FactionData[fid][fName]);
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
            AC_SetPos(playerid, tx, ty, tz + 0.1);

        AC_SetVW(playerid, GetPlayerVirtualWorld(targetid));
        AC_SetInterior(playerid, GetPlayerInterior(targetid));

        new gmsg[96];
        format(gmsg, sizeof(gmsg), C_SUCCESS"[ADM] Success: "C_WHITE"Teleported to "C_INFO"%s"C_WHITE".", PlayerData[targetid][pName]);
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
        AC_SetInterior(targetid, interiorid);

        new smsg[96];
        format(smsg, sizeof(smsg), C_SUCCESS"[ADM] Success: "C_WHITE"Set "C_INFO"%s"C_WHITE"'s interior to "C_INFO"%d"C_WHITE".",
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
        new sv1[10], sv2[10];
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
        AC_SetVW(targetid, vwid);

        new smsg[100];
        format(smsg, sizeof(smsg), C_SUCCESS"[ADM] Success: "C_WHITE"Set "C_INFO"%s"C_WHITE"'s virtual world to "C_INFO"%d"C_WHITE".",
            PlayerData[targetid][pName], vwid);
        SendClientMessage(playerid, COLOR_SUCCESS, smsg);

        if(targetid != playerid)
        {
            new tmsg[100];
            format(tmsg, sizeof(tmsg), C_INFO"Info: "C_WHITE"An admin set your virtual world to "C_INFO"%d"C_WHITE".", vwid);
            SendClientMessage(targetid, COLOR_INFO, tmsg);
        }
        return 1;
    }

    // ---- /setjob [playerid] [jobid] ----
    if(strcmp(cmd, "/setjob", true) == 0)
    {
        if(PlayerData[playerid][pAdminLevel] < 1)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have access. Requires admin level 1."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new sj1[8], sj2[8];
        strmid(sj1, cmdtext, idx, strlen(cmdtext), 8);
        while(cmdtext[idx] > ' ') idx++;
        while(cmdtext[idx] == ' ') idx++;
        strmid(sj2, cmdtext, idx, strlen(cmdtext), 8);

        if(!strlen(sj1) || !strlen(sj2))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/setjob [playerid] [jobid]"C_WHITE" (jobid 0-"#MAX_JOBS")."), 1;

        new targetid = strval(sj1);
        if(!IsPlayerConnected(targetid) || !PlayerData[targetid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"The player is not connected."), 1;

        new jobId = strval(sj2);
        if(jobId < 0 || jobId > MAX_JOBS)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Invalid job. Use 0 (none) to "#MAX_JOBS"."), 1;

        // Daca lucra / era uber, opreste-i activitatea curenta
        if(g_IsWorking[targetid]) Job_StopWork(targetid);
        if(g_UberOnDuty[targetid]) Uber_GoOffDuty(targetid);

        PlayerData[targetid][pJob] = jobId;
        UpdatePlayer(targetid, pJob);

        new smsg[100];
        if(jobId == 0)
            format(smsg, sizeof(smsg), C_SUCCESS"[ADM] Success: "C_WHITE"You removed "C_INFO"%s"C_WHITE"'s job.", PlayerData[targetid][pName]);
        else
            format(smsg, sizeof(smsg), C_SUCCESS"[ADM] Success: "C_WHITE"Set "C_INFO"%s"C_WHITE"'s job to "C_INFO"%s"C_WHITE".", PlayerData[targetid][pName], g_JobNames[jobId - 1]);
        SendClientMessage(playerid, COLOR_SUCCESS, smsg);

        if(targetid != playerid)
        {
            new tmsg[100];
            if(jobId == 0)
                format(tmsg, sizeof(tmsg), C_INFO"Info: "C_WHITE"An admin removed your job.");
            else
                format(tmsg, sizeof(tmsg), C_INFO"Info: "C_WHITE"An admin set your job to "C_INFO"%s"C_WHITE".", g_JobNames[jobId - 1]);
            SendClientMessage(targetid, COLOR_INFO, tmsg);
        }
        return 1;
    }

    // ---- /help ----
    if(strcmp(cmd, "/help", true) == 0)
    {
        SendClientMessage(playerid, COLOR_INFO, C_INFO"===== Player Commands =================");

        SendClientMessage(playerid, COLOR_WHITE, C_INFO"[Account] "C_WHITE" /help /howto (login/register se fac prin dialog la conectare)");
        SendClientMessage(playerid, COLOR_WHITE, C_INFO"[Other] "C_WHITE"/cspawn /accept /fhelp /rentcar /rentbike /curedisease");
        SendClientMessage(playerid, COLOR_WHITE, C_INFO"[Houses] "C_WHITE"/buyhouse /sellhouse /houseupgrade /frigde /buyanimal /hstats");
        SendClientMessage(playerid, COLOR_WHITE,
            C_INFO"[Vehicles] "C_WHITE"/vstats /vbuy /vsell /vpark /vsellto /vcolor /vplate /lock /engine");
        SendClientMessage(playerid, COLOR_WHITE,
            C_INFO"[Vehicles] "C_WHITE"/vInsurance /vMedicalKit /vExtinctor /vITP");
        SendClientMessage(playerid, COLOR_WHITE, C_INFO"[Licenses] "C_WHITE"/licenses /examA /examB /examC /examD /examP /examH");
        SendClientMessage(playerid, COLOR_WHITE, C_INFO"[Business] "C_WHITE"/buyBiz /sellBiz /bBank /bWithdraw");
        SendClientMessage(playerid, COLOR_WHITE, C_INFO"[Phone] "C_WHITE"/buyphone /buysim /call /pickup /hangup /sms");
        SendClientMessage(playerid, COLOR_WHITE, C_INFO"[Caravan] "C_WHITE"/attach /detach /camp /findmycaravan");
        SendClientMessage(playerid, COLOR_WHITE, C_INFO"[Jobs] "C_WHITE"/jobs /getjob /quitjob /job /stopwork");
        SendClientMessage(playerid, COLOR_WHITE, C_INFO"[Uber] "C_WHITE"/fare /service /accept )");

        if(PlayerData[playerid][pFaction] == NEWS_FACTION_ID)
            SendClientMessage(playerid, COLOR_WHITE, C_INFO"[News] "C_WHITE"/news /newspaper [create/edit/sell/open] /qa [id or list/ask/del/end]");
        else
            SendClientMessage(playerid, COLOR_WHITE, C_INFO"[News] "C_WHITE"/newspaper open /question /answer /accept newspaper|qa (in timpul unui eveniment)");

        return 1;
    }

    // ---- /howto [job/faction/vehicle/business/house/games] ----
    if(strcmp(cmd, "/howto", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        new topic[256];
        topic = strtok(cmdtext, idx);
        if(!strlen(topic))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/howto [job / faction / vehicle / business / house / games / caravan / licence / farm]"C_WHITE"."), 1;

        new title[64];
        static body[2548]; // static: buffer mare fara cost pe stiva (/howto e sincron)

        if(!strcmp(topic, "job", true) || !strcmp(topic, "jobs", true))
        {
            new numStr[256];
            numStr = strtok(cmdtext, idx);
            if(strlen(numStr))
            {
                new jn = strval(numStr);
                if(jn < 1 || jn > MAX_JOBS)
                    return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Invalid job number (1-"#MAX_JOBS")."), 1;

                format(title, sizeof(title), "How to: %s (job %d)", g_JobNames[jn - 1], jn);
                switch(jn)
                {
                    case 1: body = "{FFFFFF}Glovo Delivery - food courier.\n\nTake it with /getjob 1. Get in your job bike/car (see /joblist), then /job to start.\nDrive to the marked restaurant to load, deliver to 2 houses, then return to load.\n\nCommands: /getjob 1, /job, /stopwork, /joblist.";
                    case 2: body = "{FFFFFF}Cement Truck Driver - haul cement.\n\nTake it with /getjob 2. Get in a cement truck, then /job.\nLoad at the marked plant, unload at 2 sites, then return to load.\n\nCommands: /getjob 2, /job, /stopwork, /joblist.";
                    case 3: body = "{FFFFFF}Gun Delivery - deliver weapons.\n\nTake it with /getjob 3. Get in the job vehicle, then /job.\nLoad weapons at the marked spot, deliver to 2 drop-offs (fixed points or mafia HQs), then return to load.\n\nCommands: /getjob 3, /job, /stopwork, /joblist.";
                    case 4: body = "{FFFFFF}Car Transportator - transport vehicles.\n\nTake it with /getjob 4. Get in the transporter, then /job.\nLoad at the marked spot, unload at 2 businesses, then return to load.\n\nCommands: /getjob 4, /job, /stopwork, /joblist.";
                    case 5: body = "{FFFFFF}Uber - drive players around for money.\n\nTake it with /getjob 5. Use /fare [amount] in your PERSONAL vehicle to go on duty.\nWhen a player uses /service uber, use /accept uber to take the ride. The passenger is charged over time until they get out.\n\nCommands: /getjob 5, /fare, /service, /accept.";
                    case 6: body = "{FFFFFF}Emergency Logistics Driver - deliver medical supplies.\n\nTake it with /getjob 6. Get in a depot vehicle (Bobcat / Burrito), then /job.\nLoad at the marked depot, deliver to 2 shops, then return to load.\n\nCommands: /getjob 6, /job, /stopwork, /joblist.";
                    case 7: body = "{FFFFFF}Bus Driver - drive fixed routes.\n\nTake it with /getjob 7. Get in a depot bus and use /bus [1-3] to start a route.\nYou earn at each checkpoint, plus $100 for every passenger that boards.\n\nCommands: /getjob 7, /bus [1-3], /stopwork.";
                    default: body = "{FFFFFF}This job is not available yet.";
                }
            }
            else
            {
                title = "How to: Jobs";
                body = "{FFFFFF}Jobs let you earn money doing deliveries.\n\n- /jobs - list all jobs\n- /getjob [id or name] - take a job (at the Job Center in City Hall)\n- /job - start working (be in your job vehicle)\n- /stopwork - stop working\n- /joblist - see job vehicle locations (admin teleport)\n\nMost jobs: drive to the LOAD point, make 2 deliveries (UNLOAD), then return to load. Follow the checkpoints.\n\nUse /howto job [1-"#MAX_JOBS"] for a specific job.";
            }
        }
        else if(!strcmp(topic, "faction", true) || !strcmp(topic, "factions", true))
        {
            new fnStr[256];
            fnStr = strtok(cmdtext, idx);
            if(strlen(fnStr))
            {
                new fn = strval(fnStr);
                if(fn < 1 || fn > MAX_FACTIONS)
                    return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Invalid faction number (1-"#MAX_FACTIONS")."), 1;

                format(title, sizeof(title), "How to: %s (faction %d)", FactionData[fn][fName], fn);
                switch(fn)
                {
                    case 1: body = "{FFFFFF}Politia Romana - law enforcement.\n\nGo on/off duty with /duty (inside the HQ). Only on-duty officers have police powers.\n- /wanted [player] [0-6] [reason] - set a suspect's wanted level\n- /arrest [player] - jail a wanted suspect (at an arrest zone)\n- /m [player] - megaphone: order a driver to pull over (in a faction vehicle, within 50m)\n- /radar install [limit] - set up a speed radar and sanction speeders (/radar remove)\n- /garage, /entrace - move around the station; press H near the LSPD barrier to open it\n\n{FFFF00}Vehicle checks:{FFFFFF} police can inspect papers and confiscate:\n- /checklicenses [player], /suspendlic\n- /confiscate insurance [player] (rank 2+)\n- /confiscate licence [A/B/C/D/P/H/all] [player] - driving + airplane (P) & helicopter (H) licenses";
                    case 2: body = "{FFFFFF}Registrul Auto Roman (R.A.R.) - vehicle registry & inspections.\n\nMembers run the R.A.R. HQ, where drivers renew their vehicle documents (/vitp inspection, /vplate, /vInsurance).\n- /fine [player] [amount] [reason] - fine a driver\n\n{FFFF00}Checks & confiscation (rank 3+, on-duty):{FFFFFF}\n- /confiscate medkit / extinctor / itp [player] - take those items/documents\n\n{FFFF00}Impounding:{FFFFFF} if your ITP is expired, R.A.R. can tow your car with a Towtruck and impound it (/towpark) - the engine won't start. Go to the car and use /redeemcar to pay the release fee and get it back with ITP valid until the end of the day.";
                    case 3: body = "{FFFFFF}SMURD - emergency medical & fire service.\n\n{FFFF00}Medical:{FFFFFF}\n- /heal [player] - heal a player who is a passenger in your ambulance (paid)\nSick players come to the hospital to /curedisease.\n\n{FFFF00}Firefighting:{FFFFFF} fires can break out anywhere on the map. On duty, take the Firetruck, drive within 25m of the fire, and hold the FIRE button (spray water) to put it out.";
                    case 4, 5, 6, 7: body = "{FFFFFF}Mafia - organized crime family.\n\nMafias run drugs and fight over territory.\n- /drugs transport - haul weed to the vault\n- /drugs craft - turn weed into drugs\n- /drugs get / use - take & use drugs during a war\n- /seif - the faction vault (rank 4+)\n- /equip - get weapons inside the HQ\n- /war - start a turf war\n- /warsurrender - surrender an ongoing war (rank 4+)\nEach mafia controls its own territories.";
                    case 8: body = "{FFFFFF}News Reporters - the press. They inform the city via live broadcasts, live interviews and the newspaper.\n\n{FFFF00}Live news (rank 1+):{FFFFFF}\n- /news [text] - broadcast a headline to everyone\n\n{FFFF00}Live Q&A / interviews (rank 3+):{FFFFFF}\n- /qa [player] - start a live interview (the guest accepts with /accept qa)\n- /qa list - see submitted questions\n- /qa ask [nr] - ask one live\n- /qa del [nr] - remove one\n- /qa end - stop the Q&A\nAnyone can /question [text] to submit; the guest replies with /answer [text].\n\n{FFFF00}Newspaper:{FFFFFF}\n- /newspaper create - start a new edition\n- /newspaper edit [1-5] [text] - write up to 5 stories\n- /newspaper sell - put it on sale\n- /newspaper open - read the current newspaper";
                }

                // Comenzi comune de conducere (rank 4/5), adaugate la orice facatiune
                strcat(body, "\n\n{FFFF00}Leadership:{FFFFFF}\n- /finvite [player], /fbank (rank 4+)\n- /fsetrank [player] [1-5], /fbankwithdraw (rank 5 Lead)\n- /fkick (or /funinvite) [player] - remove a member (rank 5 Lead)\n- /refillfactionveh, /respawnfactionveh - refuel/respawn all faction vehicles (Lead)");
            }
            else
            {
                title = "How to: Factions";
                body = "{FFFFFF}Factions: Police (1), R.A.R. (2), SMURD (3), Mafias (4-7), News (8).\n\nJoining: a rank 4+ member invites you with /finvite; you accept with /accept [id] (be within 15m).\n\n- /f [text] - faction chat\n- /fmembers - list members\n- /duty - go on/off duty (factions 1-3, inside the HQ)\n\nUse /howto factions [1-8] for a specific faction.";
            }
        }
        else if(!strcmp(topic, "vehicle", true) || !strcmp(topic, "vehicles", true))
        {
            title = "How to: Vehicles";
            body = "{FFFFFF}Buy vehicles from dealerships. You need a matching driving license (see /howto licence).\n\n- /vbuy - buy the vehicle you're in (unbought dealership car)\n- /vstats - your vehicles + documents & fuel\n- /vpark - save the spawn spot\n- /vsell, /vsellto, /vcolor, /lock, /engine\n\n{FFFF00}Documents & items:{FFFFFF}\n- Insurance (/vInsurance, at R.A.R.) - $500, valid 5 days\n- ITP inspection (/vITP, at R.A.R.) - $750, valid 15 days\n- Plate (/vplate, at R.A.R.) - $250, no expiry\n- Medical kit - buy at /shop ($500), install with /v install medicalkit - valid 7 days\n- Extinguisher - buy at /shop ($500), install with /v install extinctor - valid 10 days\n\nKeep them valid: Police & R.A.R. can inspect your car and confiscate documents/items.";
        }
        else if(!strcmp(topic, "business", true) || !strcmp(topic, "businesses", true))
        {
            title = "How to: Businesses";
            body = "{FFFFFF}Businesses generate passive income into their bank from related activities.\n\n- /buyBiz - buy the business you are standing in (if unowned)\n- /sellBiz - sell your business\n- /bBank - see the business bank\n- /bWithdraw [amount] - withdraw earnings\n\nStand on a business pickup to interact with it.";
        }
        else if(!strcmp(topic, "house", true) || !strcmp(topic, "houses", true))
        {
            title = "How to: Houses";
            body = "{FFFFFF}A house is your spawn point and your storage. You can own only ONE house at a time.\n\n{FFFF00}Buying & selling:{FFFFFF}\n- /buyhouse - buy the house whose pickup you're standing on (must be for sale)\n- /sellhouse - sell your house back for its full price\n- /hstats - name, price, type and fridge contents\n\nHouse types: Villa, City House, Apartment, Countryside House.\n\n{FFFF00}Fridge (storage):{FFFFFF}\n- /houseupgrade frigde - install a fridge ($10.000)\n- /frigde - view contents\n- /frigde buy [item] [qty] - stock up (milk/banana/water/juice/beer), only between 15:00-20:00\n- /frigde use [item] - eat/drink an item to restore HP\nItems (price per unit / max capacity / HP restored):\n- Milk: $100 / 20L / +20hp\n- Banana: $50 / 30pcs / +10hp\n- Water: $150 / 25L / +25hp\n- Juice: $200 / 20L / +15hp\n- Beer: $250 / 50L / +10hp\n\n{FFFF00}Countryside House only:{FFFFFF}\n- /buyanimal [nr] - buy an animal ($5.000): Broasca, Vaca or Caprioara. It appears on your property.\n\nBe at your own house to use the fridge/animal commands.";
        }
        else if(!strcmp(topic, "games", true) || !strcmp(topic, "game", true))
        {
            title = "How to: Mini-games & Events";
            body = "{FFFFFF}Mini-games: Golf, Basketball, and admin-hosted Race Events.\n\n{FFFF00}GOLF{FFFFFF} - stroke play at the golf course.\n- /joingolf - enter (an admin opens the tournament)\n- /hitball [power] - swing toward the hole; aim with your camera, power sets distance\n- /leavegolf - quit\nFewest strokes wins.\n\n{FFFF00}BASKETBALL{FFFFFF} - at the /basket court (follow the map icon).\n- /joinbasket - join the lobby\n- /throwball [power] - shoot at your hoop\n- /leavebasket - quit\nMost points wins.\n\n{FFFF00}RACE EVENTS (BestLap){FFFFFF} - an admin opens a race on a track (Lap1/2/3) with a set car (or random).\n- /event join - enter while sign-ups are open\n- on start you spawn at the line; a 5s countdown runs (5..4..3..2..1..GO!), then race the checkpoints\nYour time is measured from GO to the last checkpoint. The top 3 are announced server-wide; beat the best time for that track & car to set a RECORD!";
        }
        else if(!strcmp(topic, "caravan", true) || !strcmp(topic, "caravans", true))
        {
            title = "How to: Caravan";
            body = "{FFFFFF}You must own a caravan (given by an admin).\n\n- /attach - hook your caravan to your PERSONAL vehicle (be driving it, near the caravan)\n- /detach - unhook & park it on flat ground; the spot is saved and it reappears there\n- /findmycaravan - locate your parked caravan\n- /camp - while attached and driving, start camping\n\n{FFFF00}Camping:{FFFFFF} your SPAWN POINT moves to the caravan's spot for 3 hours (3 paydays). You respawn at your camp until it expires, then it resets to normal.";
        }
        else if(!strcmp(topic, "licence", true) || !strcmp(topic, "license", true) || !strcmp(topic, "licences", true) || !strcmp(topic, "licenses", true))
        {
            title = "How to: Licenses";
            body = "{FFFFFF}You need a license to drive/fly. Pass the exam and pay the fee at the exam spot.\n\n{FFFF00}Validity depends on the exam vehicle's health:{FFFFFF} finish with high HP for the FULL duration; a damaged vehicle gives a shorter one (full / damaged):\n\nDriving licenses:\n- A (/examA) - motorcycles - 7 / 2 days\n- B (/examB) - cars - 10 / 3 days\n- C (/examC) - trucks & trailers - 12 / 3 days\n- D (/examD) - buses - 13 / 3 days\n\nAir licenses:\n- P (/examP) - airplanes - 15 / 2 days\n- H (/examH) - helicopters - 16 / 2 days\n\nCheck yours with /licenses. Rentals and exam vehicles don't need a license.";
        }
        else if(!strcmp(topic, "farm", true) || !strcmp(topic, "farming", true) || !strcmp(topic, "farms", true))
        {
            title = "How to: Farming";
            body = "{FFFFFF}Own a field and work the land through a cycle of 5 steps - "C_INFO"one step per real day"C_WHITE".\n\n{FFFF00}Owning a farm:{FFFFFF} stand on a for-sale field (look for the pickup + sign) and use "C_INFO"/buyfarm"C_WHITE". "C_INFO"/sellfarm"C_WHITE" sells it back for 75%. You can own one farm.\n\n{FFFF00}Machines (on your own farm):{FFFFFF}\n- /farm buy [tractor/dozer/combina] - parks a machine at the farm (Tractor $10.000, Dozer $15.000, Combine $20.000)\n- /farm sell - sit in a farm machine to sell that one (75% back)\n\n{FFFF00}Working (one step per day):{FFFFFF} drive the correct machine for the shown time WITHOUT leaving it:\n- /farm plow - Tractor, 1 min\n- /farm level - Dozer, 2 min\n- /farm seed - Tractor, 3 min\n- /farm fertilize - Tractor, 1 min\n- /farm harvest - Combine, 4 min -> paid $15.000, cycle restarts\n\nIf you leave the machine, die or disconnect, the job is cancelled and you lose that day's work (and can't retry until tomorrow).\n\n{FFFF00}Info:{FFFFFF} /farm stats (on a field) and /farmstats (your farm) show the next step, progress and whether you can work today.";
        }
        else
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/howto [job / faction / vehicle / business / house / games / caravan / licence / farm]"C_WHITE"."), 1;

        ShowPlayerDialog(playerid, DIALOG_HOWTO, DIALOG_STYLE_MSGBOX, title, body, "OK", "");
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
            SendClientMessage(playerid, COLOR_WHITE, C_INFO"[1] "C_WHITE"/ahelp /respawn /aheal /businesslist /showradars /removeradar /fixcar /flipcar /setInterior /setVw /setjob");
        if(alv >= 2)
        {
            SendClientMessage(playerid, COLOR_WHITE, C_INFO"[2] "C_WHITE"/createFire /healall /gotoLoc /gotoBiz /gotoHouse /gotoFaction /goto /bizzlist /farmlist /openGolfTournament /startGolf");
            SendClientMessage(playerid, COLOR_WHITE, C_INFO"[2] "C_WHITE"/getcar /gotocar /saveloc /gotosave");
            SendClientMessage(playerid, COLOR_WHITE, C_INFO"[2] "C_WHITE"/event race [lap1/2/3] [vehicle/random], /event start, /event stop  (race events)");
        }
        if(alv >= 3)
        {
            SendClientMessage(playerid, COLOR_WHITE, C_INFO"[3] "C_WHITE"/setlic /veh /rac /createDisease /forceunlock /gotoxyz /changecar");
        }
        if(alv >= 4)
            SendClientMessage(playerid, COLOR_WHITE, C_INFO"[4] "C_WHITE"/forcewar /adminuninvite");
        if(alv >= 5)
        {
            SendClientMessage(playerid, COLOR_WHITE, C_INFO"[5] "C_WHITE"/vc /bc /hc /fc /farmc /payday /jetpack /removejetpack");
        }
        if(alv >= 6)
        {
            SendClientMessage(playerid, COLOR_WHITE, C_INFO"[6] "C_WHITE"/hcreate /bcreate /vcreate");
            SendClientMessage(playerid, COLOR_WHITE, C_INFO"[6] "C_WHITE"/setbballspawn /createCaravan /createatm /deleteatm /moveatm");
        }

        return 1;
    }

    // ---- /hcreate [nume] ----
    if(strcmp(cmd, "/hcreate", true) == 0)
    {
        if(PlayerData[playerid][pAdminLevel] < 6)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have access. Requires admin level 6."), 1;

        if(g_HouseCount >= MAX_HOUSES)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Limit of "C_INFO#MAX_HOUSES C_WHITE" houses reached."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new hname[32];
        strmid(hname, cmdtext, idx, strlen(cmdtext), 32);

        if(!strlen(hname))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/hcreate [name]"C_WHITE"."), 1;

        new Float:hx, Float:hy, Float:hz;
        GetPlayerPos(playerid, hx, hy, hz);

        new newIdx = g_HouseCount;
        format(HouseData[newIdx][hName], 32, "%s", hname);
        HouseData[newIdx][hOwner][0] = EOS;
        HouseData[newIdx][hOwnerId]  = 0;
        HouseData[newIdx][hOwned]    = 0;
        HouseData[newIdx][hPrice]    = 2000000;
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
             VALUES ('%e','',0,0,2000000,%.4f,%.4f,%.4f)",
            hname, hx, hy, hz);
        mysql_tquery(g_SQL, q, "OnHouseCreated", "ii", playerid, newIdx);
        return 1;
    }

    // ---- /hc [option] ... (admin: modifica o casa dupa ID) ----
    // ---- /farmc [loc / range / price / isOwned] [farmid] (admin 5+: configureaza terenurile) ----
    if(strcmp(cmd, "/farmc", true) == 0)
    {
        if(PlayerData[playerid][pAdminLevel] < 5)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have access. Requires admin level 5."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new fcopt[16], fcp = 0;
        while(cmdtext[idx] > ' ' && fcp < 15) { fcopt[fcp++] = cmdtext[idx]; idx++; }
        fcopt[fcp] = EOS;
        if(!strlen(fcopt))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/farmc [loc / range / price / isOwned]"C_WHITE"."), 1;

        // ---- /farmc loc [id] (seteaza punctul terenului la pozitia ta) ----
        if(strcmp(fcopt, "loc", true) == 0)
        {
            while(cmdtext[idx] == ' ') idx++;
            new p1[8];
            strmid(p1, cmdtext, idx, strlen(cmdtext), 8);
            if(!strlen(p1))
                return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/farmc loc [id]"C_WHITE"."), 1;

            new fi = Farm_IndexByID(strval(p1));
            if(fi == -1)
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Invalid farm ID."), 1;

            new Float:fx, Float:fy, Float:fz;
            GetPlayerPos(playerid, fx, fy, fz);
            FarmData[fi][fmX] = fx; FarmData[fi][fmY] = fy; FarmData[fi][fmZ] = fz;

            new q[160];
            mysql_format(g_SQL, q, sizeof(q), "UPDATE `farms` SET `x`=%.4f, `y`=%.4f, `z`=%.4f WHERE `id`=%d", fx, fy, fz, FarmData[fi][fmID]);
            mysql_tquery(g_SQL, q, "", "", 0);
            Farm_RecreatePickup(fi);

            new m[128];
            format(m, sizeof(m), C_SUCCESS"[ADM] Success: "C_WHITE"Farm "C_INFO"#%d"C_WHITE" point set to your position ("C_INFO"%.1f, %.1f, %.1f"C_WHITE").", FarmData[fi][fmID], fx, fy, fz);
            SendClientMessage(playerid, COLOR_SUCCESS, m);
            return 1;
        }

        // ---- /farmc range [id] [range] ----
        if(strcmp(fcopt, "range", true) == 0)
        {
            while(cmdtext[idx] == ' ') idx++;
            new p1[8], p2[16];
            strmid(p1, cmdtext, idx, strlen(cmdtext), 8);
            while(cmdtext[idx] > ' ') idx++;
            while(cmdtext[idx] == ' ') idx++;
            strmid(p2, cmdtext, idx, strlen(cmdtext), 16);
            if(!strlen(p1) || !strlen(p2))
                return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/farmc range [id] [range]"C_WHITE"."), 1;

            new fi = Farm_IndexByID(strval(p1));
            if(fi == -1)
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Invalid farm ID."), 1;

            new Float:frange = floatstr(p2);
            if(frange <= 0.0)
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Invalid range."), 1;

            FarmData[fi][fmRange] = frange;
            new q[128];
            mysql_format(g_SQL, q, sizeof(q), "UPDATE `farms` SET `range`=%.4f WHERE `id`=%d", frange, FarmData[fi][fmID]);
            mysql_tquery(g_SQL, q, "", "", 0);

            new m[128];
            format(m, sizeof(m), C_SUCCESS"[ADM] Success: "C_WHITE"Farm "C_INFO"#%d"C_WHITE" range set to "C_INFO"%.1f"C_WHITE".", FarmData[fi][fmID], frange);
            SendClientMessage(playerid, COLOR_SUCCESS, m);
            return 1;
        }

        // ---- /farmc price [id] [price] ----
        if(strcmp(fcopt, "price", true) == 0)
        {
            while(cmdtext[idx] == ' ') idx++;
            new p1[8], p2[16];
            strmid(p1, cmdtext, idx, strlen(cmdtext), 8);
            while(cmdtext[idx] > ' ') idx++;
            while(cmdtext[idx] == ' ') idx++;
            strmid(p2, cmdtext, idx, strlen(cmdtext), 16);
            if(!strlen(p1) || !strlen(p2))
                return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/farmc price [id] [price]"C_WHITE"."), 1;

            new fi = Farm_IndexByID(strval(p1));
            if(fi == -1)
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Invalid farm ID."), 1;

            new newPrice = strval(p2);
            if(newPrice <= 0)
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Invalid price."), 1;

            FarmData[fi][fmPrice] = newPrice;
            new q[128];
            mysql_format(g_SQL, q, sizeof(q), "UPDATE `farms` SET `price`=%d WHERE `id`=%d", newPrice, FarmData[fi][fmID]);
            mysql_tquery(g_SQL, q, "", "", 0);
            Farm_RecreatePickup(fi);

            new m[128];
            format(m, sizeof(m), C_SUCCESS"[ADM] Success: "C_WHITE"Farm "C_INFO"#%d"C_WHITE" price set to "C_INFO"$%s"C_WHITE".", FarmData[fi][fmID], MoneyStr(newPrice));
            SendClientMessage(playerid, COLOR_SUCCESS, m);
            return 1;
        }

        // ---- /farmc isOwned [id] [0/1] (reseteaza proprietarul: Owner=EOS, FarmKey=0) ----
        if(strcmp(fcopt, "isowned", true) == 0)
        {
            while(cmdtext[idx] == ' ') idx++;
            new p1[8], p2[8];
            strmid(p1, cmdtext, idx, strlen(cmdtext), 8);
            while(cmdtext[idx] > ' ') idx++;
            while(cmdtext[idx] == ' ') idx++;
            strmid(p2, cmdtext, idx, strlen(cmdtext), 8);
            if(!strlen(p1) || !strlen(p2))
                return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/farmc isOwned [id] [0/1]"C_WHITE"."), 1;

            new fi = Farm_IndexByID(strval(p1));
            if(fi == -1)
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Invalid farm ID."), 1;

            new val = strval(p2) ? 1 : 0;

            // reseteaza cheia fostului proprietar (daca e online)
            if(strlen(FarmData[fi][fmOwner]))
                for(new p = 0; p < MAX_PLAYERS; p++)
                    if(IsPlayerConnected(p) && PlayerData[p][pLogged] &&
                       strcmp(PlayerData[p][pName], FarmData[fi][fmOwner], true) == 0)
                    {
                        PlayerData[p][pFarmKey] = 0;
                        break;
                    }

            FarmData[fi][fmOwner][0] = EOS; // Owner -> EOS
            FarmData[fi][fmOwned] = val;

            new q[160];
            mysql_format(g_SQL, q, sizeof(q), "UPDATE `farms` SET `owner`='', `isOwned`=%d WHERE `id`=%d", val, FarmData[fi][fmID]);
            mysql_tquery(g_SQL, q, "", "", 0);
            Farm_RecreatePickup(fi);

            new m2[128];
            format(m2, sizeof(m2), C_SUCCESS"[ADM] Success: "C_WHITE"Farm "C_INFO"#%d"C_WHITE" isOwned set to "C_INFO"%d"C_WHITE" (owner cleared).", FarmData[fi][fmID], val);
            SendClientMessage(playerid, COLOR_SUCCESS, m2);
            return 1;
        }

        return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/farmc [loc / range / price / isOwned]"C_WHITE"."), 1;
    }

    if(strcmp(cmd, "/hc", true) == 0)
    {
        if(PlayerData[playerid][pAdminLevel] < 5)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have access. Requires admin level 5."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new hopt[16], hpos = 0;
        while(cmdtext[idx] > ' ' && hpos < 15) { hopt[hpos++] = cmdtext[idx]; idx++; }
        hopt[hpos] = EOS;
        if(!strlen(hopt))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/hc [loc / price / owner]"C_WHITE"."), 1;

        // ---- /hc loc [id] (muta casa la pozitia ta) ----
        if(strcmp(hopt, "loc", true) == 0)
        {
            while(cmdtext[idx] == ' ') idx++;
            new chlStr[8];
            strmid(chlStr, cmdtext, idx, strlen(cmdtext), 8);
            if(!strlen(chlStr))
                return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/hc loc [id]"C_WHITE"."), 1;

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

        // ---- /hc price [id] [new_price] ----
        if(strcmp(hopt, "price", true) == 0)
        {
            while(cmdtext[idx] == ' ') idx++;
            new p1[8], p2[16];
            strmid(p1, cmdtext, idx, strlen(cmdtext), 8);
            new hid = strval(p1);
            while(cmdtext[idx] > ' ') idx++;
            while(cmdtext[idx] == ' ') idx++;
            strmid(p2, cmdtext, idx, strlen(cmdtext), 16);
            new newPrice = strval(p2);

            if(!strlen(p1) || !strlen(p2))
                return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/hc price [id] [new_price]"C_WHITE"."), 1;

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
            format(lmsg, sizeof(lmsg), C_SUCCESS"[ADM] Success: "C_WHITE"The price of house "C_INFO"%s"C_WHITE" was changed to "C_INFO"$%s"C_WHITE".",
                HouseData[hidx][hName], MoneyStr(newPrice));
            SendClientMessage(playerid, COLOR_SUCCESS, lmsg);
            return 1;
        }

        // ---- /hc owner [id] [playerid] ----
        if(strcmp(hopt, "owner", true) == 0)
        {
            while(cmdtext[idx] == ' ') idx++;
            new p1[8], p2[8];
            strmid(p1, cmdtext, idx, strlen(cmdtext), 8);
            new hid = strval(p1);
            while(cmdtext[idx] > ' ') idx++;
            while(cmdtext[idx] == ' ') idx++;
            strmid(p2, cmdtext, idx, strlen(cmdtext), 8);
            new targetid = strval(p2);

            if(!strlen(p1) || !strlen(p2))
                return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/hc owner [id] [playerid]"C_WHITE"."), 1;

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
                    PlayerData[oldOwnerPlayer][pHouse]      = 0;
                    UpdatePlayer(oldOwnerPlayer, pHouse);
                }
                else
                {
                    new qold[128];
                    mysql_format(g_SQL, qold, sizeof(qold), "UPDATE `players` SET `house`=0 WHERE `id`=%d", oldOwnerPID);
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

        return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Unknown option. Use "C_INFO"/hc [loc/price/owner]"C_WHITE"."), 1;
    }

    // ---- /buyhouse ----
    if(strcmp(cmd, "/buyhouse", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        if(PlayerData[playerid][pHouse] != 0)
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

    // ---- /buyanimal [type] (doar pentru casa proprie de tip 4 = Casa la tara) ----
    if(strcmp(cmd, "/buyanimal", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        if(PlayerData[playerid][pHouse] == 0)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't own a house."), 1;

        new ahidx = Houses_FindByID(PlayerData[playerid][pHouse]);
        if(ahidx == -1)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Your house could not be found."), 1;

        if(HouseData[ahidx][hType] != HOUSE_TYPE_COUNTRYSIDE)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You can only buy animals at a countryside house."), 1;

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

        if(PlayerData[playerid][pHouse] == 0)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't own a house."), 1;

        new hidx = Houses_FindByID(PlayerData[playerid][pHouse]);
        if(hidx == -1)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"House not found."), 1;

        new price = HouseData[hidx][hPrice] * 75 / 100; // vanzare la 75% din valoare
        PlayerData[playerid][pMoney] += price;
        GivePlayerMoney(playerid, price);
        UpdatePlayer(playerid, pMoney);
        PlayerData[playerid][pHouse]      = 0;

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

    // ---- /houseupgrade [frigde] (cumpara upgrade pentru casa proprie) ----
    if(strcmp(cmd, "/houseupgrade", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new hup[16];
        strmid(hup, cmdtext, idx, strlen(cmdtext), 16);
        if(!strlen(hup))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/houseupgrade frigde"C_WHITE" (Price: "C_INFO"$10.000"C_WHITE")."), 1;

        if(strcmp(hup, "frigde", true) != 0 && strcmp(hup, "fridge", true) != 0)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Unknown upgrade. Available: "C_INFO"frigde"C_WHITE"."), 1;

        new hidx = Player_FridgeHouse(playerid);
        if(hidx == -1)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be at your own house."), 1;
        if(HouseData[hidx][hHasFridge])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"This house already has a fridge."), 1;
        if(PlayerData[playerid][pMoney] < FRIDGE_PRICE)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have enough money ("C_INFO"$10.000"C_WHITE")."), 1;

        PlayerData[playerid][pMoney] -= FRIDGE_PRICE;
        GivePlayerMoney(playerid, -FRIDGE_PRICE);
        UpdatePlayer(playerid, pMoney);

        HouseData[hidx][hHasFridge] = 1;
        Houses_SaveFridge(hidx);

        SendClientMessage(playerid, COLOR_SUCCESS, C_SUCCESS"Success: "C_WHITE"You bought a "C_INFO"fridge"C_WHITE" for your house. Use "C_INFO"/frigde"C_WHITE".");
        return 1;
    }

    // ---- /frigde [buy/use] [item] [qty] (frigiderul casei proprii) ----
    if(strcmp(cmd, "/frigde", true) == 0 || strcmp(cmd, "/fridge", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        new hidx = Player_FridgeHouse(playerid);
        if(hidx == -1)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be at your own house."), 1;
        if(!HouseData[hidx][hHasFridge])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"This house doesn't have a fridge. Buy one with "C_INFO"/houseupgrade frigde"C_WHITE"."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new fsub[8], fsp = 0;
        while(cmdtext[idx] > ' ' && fsp < 7) { fsub[fsp++] = cmdtext[idx]; idx++; }
        fsub[fsp] = EOS;

        // fara argument -> arata continutul frigiderului
        if(!strlen(fsub))
        {
            SendClientMessage(playerid, COLOR_INFO, C_INFO"[Fridge] "C_WHITE"Contents:");
            for(new k = 0; k < FRIDGE_ITEMS; k++)
            {
                new fline[96];
                format(fline, sizeof(fline), C_WHITE"- %s: "C_INFO"%d/%d %s "C_WHITE"(+%d hp)",
                    g_FridgeName[k], HouseData[hidx][hFridge][k], g_FridgeMax[k], g_FridgeUnit[k], g_FridgeHeal[k]);
                SendClientMessage(playerid, COLOR_WHITE, fline);
            }
            SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/frigde buy [item] [qty]"C_WHITE" or "C_INFO"/frigde use [item]"C_WHITE".");
            return 1;
        }

        // ---- /frigde buy [item] [qty] ----
        if(strcmp(fsub, "buy", true) == 0)
        {
            new fhour, fminute, fsecond;
            gettime(fhour, fminute, fsecond);
            if(fhour < FRIDGE_OPEN_START || fhour >= FRIDGE_OPEN_END)
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You can only buy between "C_INFO"15:00"C_WHITE" and "C_INFO"20:00"C_WHITE"."), 1;

            while(cmdtext[idx] == ' ') idx++;
            new fitem[16], fip = 0;
            while(cmdtext[idx] > ' ' && fip < 15) { fitem[fip++] = cmdtext[idx]; idx++; }
            fitem[fip] = EOS;
            while(cmdtext[idx] == ' ') idx++;
            new fqtyStr[8];
            strmid(fqtyStr, cmdtext, idx, strlen(cmdtext), 8);
            if(!strlen(fitem) || !strlen(fqtyStr))
                return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/frigde buy [item] [qty]"C_WHITE" (milk/banana/water/juice/beer)."), 1;

            new fk = Fridge_FindItem(fitem);
            if(fk == -1)
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Unknown item. Use: "C_INFO"milk, banana, water, juice, beer"C_WHITE"."), 1;

            new fqty = strval(fqtyStr);
            if(fqty <= 0)
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Invalid quantity."), 1;

            new fspace = g_FridgeMax[fk] - HouseData[hidx][hFridge][fk];
            if(fspace <= 0)
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"The fridge is already full of this item."), 1;
            if(fqty > fspace) fqty = fspace; // limiteaza la capacitatea ramasa

            new fcost = g_FridgePrice[fk] * fqty;
            if(PlayerData[playerid][pMoney] < fcost)
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have enough money."), 1;

            PlayerData[playerid][pMoney] -= fcost;
            GivePlayerMoney(playerid, -fcost);
            UpdatePlayer(playerid, pMoney);

            HouseData[hidx][hFridge][fk] += fqty;
            Houses_SaveFridge(hidx);

            // 10% din valoare intra in banca business-ului FRIDGE_BIZ_ID
            new fcut = fcost * FRIDGE_BIZ_CUT_PCT / 100;
            if(fcut > 0) Job_AddBizIncome(FRIDGE_BIZ_ID, fcut);

            new fbmsg[144];
            format(fbmsg, sizeof(fbmsg), C_SUCCESS"Success: "C_WHITE"Bought "C_INFO"%d %s"C_WHITE" of "C_INFO"%s"C_WHITE" for "C_SUCCESS"$%s"C_WHITE". Now: "C_INFO"%d/%d"C_WHITE".",
                fqty, g_FridgeUnit[fk], g_FridgeName[fk], MoneyStr(fcost), HouseData[hidx][hFridge][fk], g_FridgeMax[fk]);
            SendClientMessage(playerid, COLOR_SUCCESS, fbmsg);
            return 1;
        }

        // ---- /frigde use [item] ----
        if(strcmp(fsub, "use", true) == 0)
        {
            while(cmdtext[idx] == ' ') idx++;
            new fitem[16];
            strmid(fitem, cmdtext, idx, strlen(cmdtext), 16);
            if(!strlen(fitem))
                return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/frigde use [item]"C_WHITE" (milk/banana/water/juice/beer)."), 1;

            new fk = Fridge_FindItem(fitem);
            if(fk == -1)
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Unknown item. Use: "C_INFO"milk, banana, water, juice, beer"C_WHITE"."), 1;

            if(HouseData[hidx][hFridge][fk] <= 0)
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"There is no more of this item in the fridge."), 1;

            HouseData[hidx][hFridge][fk]--;
            Houses_SaveFridge(hidx);

            new Float:fhp;
            GetPlayerHealth(playerid, fhp);
            fhp += float(g_FridgeHeal[fk]);
            if(fhp > 100.0) fhp = 100.0;
            SetPlayerHealth(playerid, fhp);

            new fumsg[128];
            format(fumsg, sizeof(fumsg), C_SUCCESS"Success: "C_WHITE"You consumed "C_INFO"1 %s"C_WHITE" ("C_SUCCESS"+%d hp"C_WHITE"). Left: "C_INFO"%d/%d"C_WHITE".",
                g_FridgeName[fk], g_FridgeHeal[fk], HouseData[hidx][hFridge][fk], g_FridgeMax[fk]);
            SendClientMessage(playerid, COLOR_SUCCESS, fumsg);
            return 1;
        }

        return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/frigde buy [item] [qty]"C_WHITE" or "C_INFO"/frigde use [item]"C_WHITE"."), 1;
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
            PlayerData[playerid][pBusiness]   = 0;
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

    // ---- /bcreate ----
    if(strcmp(cmd, "/bcreate", true) == 0)
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
        BusinessData[newIdx][bPrice]    = 3000000;
        BusinessData[newIdx][bBank]     = 0;
        BusinessData[newIdx][bLocX]     = bx;
        BusinessData[newIdx][bLocY]     = by;
        BusinessData[newIdx][bLocZ]     = bz;
        g_BusinessPickup[newIdx]        = -1;
        g_BusinessCount++;

        new q[256];
        mysql_format(g_SQL, q, sizeof(q),
            "INSERT INTO `businesses` (`name`,`owned`,`owner`,`owner_id`,`price`,`bank`,`loc_x`,`loc_y`,`loc_z`) \
             VALUES ('Business',0,'',0,3000000,0,%.4f,%.4f,%.4f)",
            bx, by, bz);
        mysql_tquery(g_SQL, q, "OnBusinessCreated", "ii", playerid, newIdx);
        return 1;
    }

    // ---- /createatm (creeaza un ATM la pozitia ta; banca = cea mai apropiata din biz 19/20) ----
    if(strcmp(cmd, "/createatm", true) == 0)
    {
        if(PlayerData[playerid][pAdminLevel] < 6)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have access. Requires admin level 6."), 1;

        if(g_AtmCount >= MAX_ATMS)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Limit of "C_INFO#MAX_ATMS C_WHITE" ATMs reached."), 1;

        new Float:ax, Float:ay, Float:az;
        GetPlayerPos(playerid, ax, ay, az);
        new bankId = ATM_NearestBank(playerid);

        new newIdx = g_AtmCount;
        ATMData[newIdx][atmID]        = 0;
        ATMData[newIdx][atmType]      = 0;
        ATMData[newIdx][atmX]         = ax;
        ATMData[newIdx][atmY]         = ay;
        ATMData[newIdx][atmZ]         = az;
        ATMData[newIdx][atmBankOwner] = bankId;
        g_AtmPickup[newIdx]           = -1;
        g_AtmLabel[newIdx]            = Text3D:INVALID_3DTEXT_ID;
        g_AtmCount++;

        new q[200];
        mysql_format(g_SQL, q, sizeof(q),
            "INSERT INTO `atms` (`atmType`,`atmLocX`,`atmLocY`,`atmLocZ`,`atmBankOwner`) VALUES (0,%.4f,%.4f,%.4f,%d)",
            ax, ay, az, bankId);
        mysql_tquery(g_SQL, q, "OnATMCreated", "ii", playerid, newIdx);
        return 1;
    }

    // ---- /moveatm [id] (muta ATM-ul la pozitia ta + recalculeaza banca) ----
    if(strcmp(cmd, "/moveatm", true) == 0)
    {
        if(PlayerData[playerid][pAdminLevel] < 6)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have access. Requires admin level 6."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new mStr[8];
        strmid(mStr, cmdtext, idx, strlen(cmdtext), 8);
        if(!strlen(mStr))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/moveatm [id]"C_WHITE"."), 1;

        new aidx = ATM_FindByID(strval(mStr));
        if(aidx == -1)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Invalid ATM ID."), 1;

        new Float:ax, Float:ay, Float:az;
        GetPlayerPos(playerid, ax, ay, az);

        ATMData[aidx][atmX]         = ax;
        ATMData[aidx][atmY]         = ay;
        ATMData[aidx][atmZ]         = az;
        ATMData[aidx][atmBankOwner] = ATM_NearestBank(playerid);
        ATM_Create(aidx);

        new q[200];
        mysql_format(g_SQL, q, sizeof(q),
            "UPDATE `atms` SET `atmLocX`=%.4f, `atmLocY`=%.4f, `atmLocZ`=%.4f, `atmBankOwner`=%d WHERE `atmID`=%d",
            ax, ay, az, ATMData[aidx][atmBankOwner], ATMData[aidx][atmID]);
        mysql_tquery(g_SQL, q, "", "", 0);

        ATM_AnnounceBank(playerid, aidx, true);
        return 1;
    }

    // ---- /deleteatm [id] ----
    if(strcmp(cmd, "/deleteatm", true) == 0)
    {
        if(PlayerData[playerid][pAdminLevel] < 6)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have access. Requires admin level 6."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new dStr[8];
        strmid(dStr, cmdtext, idx, strlen(cmdtext), 8);
        if(!strlen(dStr))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/deleteatm [id]"C_WHITE"."), 1;

        new delId = strval(dStr);
        new aidx = ATM_FindByID(delId);
        if(aidx == -1)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Invalid ATM ID."), 1;

        if(g_AtmPickup[aidx] != -1) { DestroyPickup(g_AtmPickup[aidx]); g_AtmPickup[aidx] = -1; }
        if(g_AtmLabel[aidx] != Text3D:INVALID_3DTEXT_ID) { Delete3DTextLabel(g_AtmLabel[aidx]); g_AtmLabel[aidx] = Text3D:INVALID_3DTEXT_ID; }

        // compacteaza array-urile (muta si handle-urile odata cu datele)
        for(new i = aidx; i < g_AtmCount - 1; i++)
        {
            ATMData[i]     = ATMData[i + 1];
            g_AtmPickup[i] = g_AtmPickup[i + 1];
            g_AtmLabel[i]  = g_AtmLabel[i + 1];
        }
        g_AtmCount--;

        new q[96];
        mysql_format(g_SQL, q, sizeof(q), "DELETE FROM `atms` WHERE `atmID`=%d", delId);
        mysql_tquery(g_SQL, q, "", "", 0);

        new dmsg[96];
        format(dmsg, sizeof(dmsg), C_SUCCESS"[ADM] Success: "C_WHITE"ATM "C_INFO"#%d"C_WHITE" deleted.", delId);
        SendClientMessage(playerid, COLOR_SUCCESS, dmsg);
        return 1;
    }

    // ---- /shopcreate (creeaza un shop la pozitia ta) ----
    if(strcmp(cmd, "/shopcreate", true) == 0)
    {
        if(PlayerData[playerid][pAdminLevel] < 6)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have access. Requires admin level 6."), 1;

        if(g_ShopCount >= MAX_SHOPS)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Limit of "C_INFO#MAX_SHOPS C_WHITE" shops reached."), 1;

        new Float:sx, Float:sy, Float:sz;
        GetPlayerPos(playerid, sx, sy, sz);

        new newIdx = g_ShopCount;
        ShopData[newIdx][shopID] = 0;
        ShopData[newIdx][shopX]  = sx;
        ShopData[newIdx][shopY]  = sy;
        ShopData[newIdx][shopZ]  = sz;
        g_ShopPickup[newIdx]     = -1;
        g_ShopLabel[newIdx]      = Text3D:INVALID_3DTEXT_ID;
        g_ShopCount++;

        new q[160];
        mysql_format(g_SQL, q, sizeof(q),
            "INSERT INTO `shops` (`shopLocX`,`shopLocY`,`shopLocZ`) VALUES (%.4f,%.4f,%.4f)",
            sx, sy, sz);
        mysql_tquery(g_SQL, q, "OnShopCreated", "ii", playerid, newIdx);
        return 1;
    }

    // ---- /shopChangeLoc [id] (muta shop-ul la pozitia ta) ----
    if(strcmp(cmd, "/shopChangeLoc", true) == 0)
    {
        if(PlayerData[playerid][pAdminLevel] < 6)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have access. Requires admin level 6."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new mStr[8];
        strmid(mStr, cmdtext, idx, strlen(cmdtext), 8);
        if(!strlen(mStr))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/shopChangeLoc [id]"C_WHITE"."), 1;

        new sidx = Shop_FindByID(strval(mStr));
        if(sidx == -1)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Invalid shop ID."), 1;

        new Float:sx, Float:sy, Float:sz;
        GetPlayerPos(playerid, sx, sy, sz);

        ShopData[sidx][shopX] = sx;
        ShopData[sidx][shopY] = sy;
        ShopData[sidx][shopZ] = sz;
        Shop_Create(sidx);
        Shop_RefreshAllIcons();

        new q[160];
        mysql_format(g_SQL, q, sizeof(q),
            "UPDATE `shops` SET `shopLocX`=%.4f, `shopLocY`=%.4f, `shopLocZ`=%.4f WHERE `shopID`=%d",
            sx, sy, sz, ShopData[sidx][shopID]);
        mysql_tquery(g_SQL, q, "", "", 0);

        new mmsg[96];
        format(mmsg, sizeof(mmsg), C_SUCCESS"[ADM] Success: "C_WHITE"Shop "C_INFO"#%d"C_WHITE" moved to your position.", ShopData[sidx][shopID]);
        SendClientMessage(playerid, COLOR_SUCCESS, mmsg);
        return 1;
    }

    // ---- /shopDelete [id] ----
    if(strcmp(cmd, "/shopDelete", true) == 0)
    {
        if(PlayerData[playerid][pAdminLevel] < 6)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have access. Requires admin level 6."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new dStr[8];
        strmid(dStr, cmdtext, idx, strlen(cmdtext), 8);
        if(!strlen(dStr))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/shopDelete [id]"C_WHITE"."), 1;

        new delId = strval(dStr);
        new sidx = Shop_FindByID(delId);
        if(sidx == -1)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Invalid shop ID."), 1;

        if(g_ShopPickup[sidx] != -1) { DestroyPickup(g_ShopPickup[sidx]); g_ShopPickup[sidx] = -1; }
        if(g_ShopLabel[sidx] != Text3D:INVALID_3DTEXT_ID) { Delete3DTextLabel(g_ShopLabel[sidx]); g_ShopLabel[sidx] = Text3D:INVALID_3DTEXT_ID; }

        // compacteaza array-urile (muta si handle-urile odata cu datele)
        for(new i = sidx; i < g_ShopCount - 1; i++)
        {
            ShopData[i]     = ShopData[i + 1];
            g_ShopPickup[i] = g_ShopPickup[i + 1];
            g_ShopLabel[i]  = g_ShopLabel[i + 1];
        }
        g_ShopCount--;

        new q[96];
        mysql_format(g_SQL, q, sizeof(q), "DELETE FROM `shops` WHERE `shopID`=%d", delId);
        mysql_tquery(g_SQL, q, "", "", 0);

        Shop_RefreshAllIcons();

        new dmsg[96];
        format(dmsg, sizeof(dmsg), C_SUCCESS"[ADM] Success: "C_WHITE"Shop "C_INFO"#%d"C_WHITE" deleted.", delId);
        SendClientMessage(playerid, COLOR_SUCCESS, dmsg);
        return 1;
    }

    // ---- /ffcreate [pizza/burger] [name] (creeaza o locatie fast-food la pozitia ta) ----
    if(strcmp(cmd, "/ffcreate", true) == 0)
    {
        if(PlayerData[playerid][pAdminLevel] < 5)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have access. Requires admin level 5."), 1;

        new tok[256];
        tok = strtok(cmdtext, idx);
        new type = 1; // implicit pizza
        if(strlen(tok))
        {
            if(!strcmp(tok, "burger", true) || !strcmp(tok, "2", true))     type = 2;
            else if(!strcmp(tok, "pizza", true) || !strcmp(tok, "1", true)) type = 1;
            else return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/ffcreate [pizza/burger] [name]"C_WHITE"."), 1;
        }

        new tname[8];
        FastFood_TypeName(type, tname);

        if(FastFood_CountType(type) >= MAX_FOOD_LOCATIONS)
        {
            new lmsg[128];
            format(lmsg, sizeof(lmsg), C_ERROR"Error: "C_WHITE"Limit of "C_INFO"%d"C_WHITE" %s locations reached.", MAX_FOOD_LOCATIONS, tname);
            return SendClientMessage(playerid, COLOR_ERROR, lmsg), 1;
        }

        // restul liniei = numele locatiei (optional)
        while(cmdtext[idx] == ' ') idx++;
        new ffname[32];
        strmid(ffname, cmdtext, idx, strlen(cmdtext), 32);
        if(!strlen(ffname)) format(ffname, sizeof(ffname), (type == 2) ? ("Burger Shot") : ("Pizza Stack"));

        new Float:fx, Float:fy, Float:fz;
        GetPlayerPos(playerid, fx, fy, fz);

        new q[256];
        mysql_format(g_SQL, q, sizeof(q),
            "INSERT INTO `fastfood` (`ffName`,`ffType`,`ffLocX`,`ffLocY`,`ffLocZ`) VALUES ('%e',%d,%.4f,%.4f,%.4f)",
            ffname, type, fx, fy, fz);
        mysql_tquery(g_SQL, q, "", "", 0);
        FastFood_Load(); // reincarca (SELECT ruleaza dupa INSERT pe aceeasi conexiune)

        new cmsg[144];
        format(cmsg, sizeof(cmsg), C_SUCCESS"[ADM] Success: "C_WHITE"%s location "C_INFO"'%s'"C_WHITE" created at your position.", tname, ffname);
        SendClientMessage(playerid, COLOR_SUCCESS, cmsg);
        return 1;
    }

    // ---- /ffc <loc|name|type> <ffID> [value] (modifica o locatie fast-food) ----
    if(strcmp(cmd, "/ffc", true) == 0)
    {
        if(PlayerData[playerid][pAdminLevel] < 5)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have access. Requires admin level 5."), 1;

        new field[256];
        field = strtok(cmdtext, idx);
        new idStr[256];
        idStr = strtok(cmdtext, idx);
        if(!strlen(field) || !strlen(idStr))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/ffc <loc|name|type> <ffID> [value]"C_WHITE"."), 1;

        new ffid = strval(idStr);
        new type = FastFood_FindType(ffid);
        if(type == 0)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Invalid ffID (not loaded)."), 1;

        new q[256];

        if(!strcmp(field, "loc", true))
        {
            new Float:fx, Float:fy, Float:fz;
            GetPlayerPos(playerid, fx, fy, fz);
            mysql_format(g_SQL, q, sizeof(q),
                "UPDATE `fastfood` SET `ffLocX`=%.4f, `ffLocY`=%.4f, `ffLocZ`=%.4f WHERE `ffID`=%d",
                fx, fy, fz, ffid);
            mysql_tquery(g_SQL, q, "", "", 0);
            FastFood_Load();

            new lmsg[112];
            format(lmsg, sizeof(lmsg), C_SUCCESS"[ADM] Success: "C_WHITE"Fast-food "C_INFO"#%d"C_WHITE" moved to your position.", ffid);
            SendClientMessage(playerid, COLOR_SUCCESS, lmsg);
            return 1;
        }
        else if(!strcmp(field, "name", true))
        {
            while(cmdtext[idx] == ' ') idx++;
            new ffname[32];
            strmid(ffname, cmdtext, idx, strlen(cmdtext), 32);
            if(!strlen(ffname))
                return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/ffc name <ffID> [new name]"C_WHITE"."), 1;

            mysql_format(g_SQL, q, sizeof(q), "UPDATE `fastfood` SET `ffName`='%e' WHERE `ffID`=%d", ffname, ffid);
            mysql_tquery(g_SQL, q, "", "", 0);
            FastFood_Load();

            new nmsg[128];
            format(nmsg, sizeof(nmsg), C_SUCCESS"[ADM] Success: "C_WHITE"Fast-food "C_INFO"#%d"C_WHITE" renamed to "C_INFO"'%s'"C_WHITE".", ffid, ffname);
            SendClientMessage(playerid, COLOR_SUCCESS, nmsg);
            return 1;
        }
        else if(!strcmp(field, "type", true))
        {
            new tStr[256];
            tStr = strtok(cmdtext, idx);
            new newType = 0;
            if(!strcmp(tStr, "pizza", true) || !strcmp(tStr, "1", true))       newType = 1;
            else if(!strcmp(tStr, "burger", true) || !strcmp(tStr, "2", true)) newType = 2;
            else return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/ffc type <ffID> [pizza/burger]"C_WHITE"."), 1;

            new tnn[8];
            FastFood_TypeName(newType, tnn);

            if(newType != type && FastFood_CountType(newType) >= MAX_FOOD_LOCATIONS)
            {
                new lmsg[128];
                format(lmsg, sizeof(lmsg), C_ERROR"Error: "C_WHITE"Limit of "C_INFO"%d"C_WHITE" %s locations reached.", MAX_FOOD_LOCATIONS, tnn);
                return SendClientMessage(playerid, COLOR_ERROR, lmsg), 1;
            }

            mysql_format(g_SQL, q, sizeof(q), "UPDATE `fastfood` SET `ffType`=%d WHERE `ffID`=%d", newType, ffid);
            mysql_tquery(g_SQL, q, "", "", 0);
            FastFood_Load();

            new tmsg[112];
            format(tmsg, sizeof(tmsg), C_SUCCESS"[ADM] Success: "C_WHITE"Fast-food "C_INFO"#%d"C_WHITE" type set to "C_INFO"%s"C_WHITE".", ffid, tnn);
            SendClientMessage(playerid, COLOR_SUCCESS, tmsg);
            return 1;
        }

        return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/ffc <loc|name|type> <ffID> [value]"C_WHITE"."), 1;
    }

    // ---- /fastfoodlist (dialog cu toate locatiile fast-food; click = teleport) ----
    if(strcmp(cmd, "/fastfoodlist", true) == 0)
    {
        if(PlayerData[playerid][pAdminLevel] < 5)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have access. Requires admin level 5."), 1;

        new Float:fx, Float:fy, Float:fz, fType, ffid, fname[32];
        new list[2048], line[80], tn[8], shown = 0;
        list[0] = EOS;
        strcat(list, "ffID\tName\tType\n");
        for(new n = 0; FastFood_GetNth(n, ffid, fType, fx, fy, fz, fname, sizeof(fname)); n++)
        {
            FastFood_TypeName(fType, tn);
            format(line, sizeof(line), "%d\t%s\t%s\n", ffid, fname, tn);
            strcat(list, line);
            shown++;
        }

        if(!shown)
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"There are no fast-food locations."), 1;

        ShowPlayerDialog(playerid, DIALOG_FASTFOOD_LIST, DIALOG_STYLE_TABLIST_HEADERS, "Fast-food locations", list, "Teleport", "Close");
        return 1;
    }

    // ---- /bc [option] ... (admin: modifica un business dupa ID) ----
    if(strcmp(cmd, "/bc", true) == 0)
    {
        if(PlayerData[playerid][pAdminLevel] < 5)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have access. Requires admin level 5."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new bopt[16], bpos = 0;
        while(cmdtext[idx] > ' ' && bpos < 15) { bopt[bpos++] = cmdtext[idx]; idx++; }
        bopt[bpos] = EOS;
        if(!strlen(bopt))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/bc [loc / name / price]"C_WHITE"."), 1;

        // ---- /bc name [id] [name] ----
        if(strcmp(bopt, "name", true) == 0)
        {
            while(cmdtext[idx] == ' ') idx++;
            new p1[8];
            strmid(p1, cmdtext, idx, strlen(cmdtext), 8);
            new bid = strval(p1);
            while(cmdtext[idx] > ' ') idx++;
            while(cmdtext[idx] == ' ') idx++;
            new bname[32];
            strmid(bname, cmdtext, idx, strlen(cmdtext), 32);

            if(!strlen(p1) || !strlen(bname))
                return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/bc name [id] [name]"C_WHITE"."), 1;

            new bidx = Businesses_FindByID(bid);
            if(bidx == -1)
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Business not found."), 1;

            format(BusinessData[bidx][bName], 32, "%s", bname);
            Businesses_RecreatePickup(bidx);

            new q[160];
            mysql_format(g_SQL, q, sizeof(q), "UPDATE `businesses` SET `name`='%e' WHERE `id`=%d",
                BusinessData[bidx][bName], BusinessData[bidx][bID]);
            mysql_tquery(g_SQL, q, "", "", 0);

            new lmsg[160];
            format(lmsg, sizeof(lmsg), C_SUCCESS"[ADM] Success: "C_WHITE"The name of business (ID: "C_INFO"%d"C_WHITE") was changed to "C_INFO"%s"C_WHITE".",
                BusinessData[bidx][bID], BusinessData[bidx][bName]);
            SendClientMessage(playerid, COLOR_SUCCESS, lmsg);
            return 1;
        }

        // ---- /bc price [id] [new_price] ----
        if(strcmp(bopt, "price", true) == 0)
        {
            while(cmdtext[idx] == ' ') idx++;
            new p1[8], p2[16];
            strmid(p1, cmdtext, idx, strlen(cmdtext), 8);
            new bid = strval(p1);
            while(cmdtext[idx] > ' ') idx++;
            while(cmdtext[idx] == ' ') idx++;
            strmid(p2, cmdtext, idx, strlen(cmdtext), 16);
            new newPrice = strval(p2);

            if(!strlen(p1) || !strlen(p2))
                return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/bc price [id] [new_price]"C_WHITE"."), 1;

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
            format(lmsg, sizeof(lmsg), C_SUCCESS"[ADM] Success: "C_WHITE"The price of business (ID: "C_INFO"%d"C_WHITE") was changed to "C_INFO"$%s"C_WHITE".",
                BusinessData[bidx][bID], MoneyStr(newPrice));
            SendClientMessage(playerid, COLOR_SUCCESS, lmsg);
            return 1;
        }

        // ---- /bc loc [id] ----
        if(strcmp(bopt, "loc", true) == 0)
        {
            while(cmdtext[idx] == ' ') idx++;
            new p1[8];
            strmid(p1, cmdtext, idx, strlen(cmdtext), 8);
            if(!strlen(p1))
                return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/bc loc [id]"C_WHITE"."), 1;

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
            format(lmsg, sizeof(lmsg), C_SUCCESS"[ADM] Success: "C_WHITE"The location of business (ID: "C_INFO"%d"C_WHITE") was updated.",
                BusinessData[bidx][bID]);
            SendClientMessage(playerid, COLOR_SUCCESS, lmsg);
            return 1;
        }

        return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Unknown option. Use "C_INFO"/bc [name/price/loc]"C_WHITE"."), 1;
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

    // ---- /examP (avion -> Airplane A) ----
    if(strcmp(cmd, "/examP", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;
        return FlightExam_Begin(playerid, FLIGHT_CAT_P);
    }

    // ---- /examH (elicopter -> Airplane H) ----
    if(strcmp(cmd, "/examH", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;
        return FlightExam_Begin(playerid, FLIGHT_CAT_H);
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

        // Prima inmatriculare: doar daca masina nu a mai fost inmatriculata vreodata
        if(PVehicleData[pvidx][pvFirstReg] == 0)
            PVehicleData[pvidx][pvFirstReg] = gettime();

        new insDate[11], medDate[11], extDate[11], itpDate[11], firstRegDate[11];
        UnixToDateStr(PVehicleData[pvidx][pvInsuranceExp], insDate, sizeof(insDate));
        UnixToDateStr(PVehicleData[pvidx][pvMedkitExp], medDate, sizeof(medDate));
        UnixToDateStr(PVehicleData[pvidx][pvExtinguisherExp], extDate, sizeof(extDate));
        UnixToDateStr(PVehicleData[pvidx][pvITPExp], itpDate, sizeof(itpDate));
        UnixToDateStr(PVehicleData[pvidx][pvFirstReg], firstRegDate, sizeof(firstRegDate));

        new q[320];
        mysql_format(g_SQL, q, sizeof(q),
            "UPDATE `vehicles_personal` SET `owner_id`=%d, `insurance_exp`='%s', `medkit_exp`='%s', `extinguisher_exp`='%s', `itp_exp`='%s', `first_registration`='%s' WHERE `id`=%d",
            PVehicleData[pvidx][pvOwnerId], insDate, medDate, extDate, itpDate, firstRegDate, PVehicleData[pvidx][pvID]);
        mysql_tquery(g_SQL, q, "", "", 0);

        // 0.001% din pretul masinii merge in banca business-ului din `from_biz` (citit din DB)
        new vbidx = Businesses_FindByID(PVehicleData[pvidx][pvFromBiz]);
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

    // ---- /forceunlock (admin: descuie vehiculul personal cel mai apropiat) ----
    if(strcmp(cmd, "/forceunlock", true) == 0)
    {
        if(PlayerData[playerid][pAdminLevel] < 3)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have access. Requires admin level 3."), 1;

        new fvehid = GetPlayerVehicleID(playerid);
        new fpvidx = -1;

        if(fvehid != 0)
        {
            fpvidx = g_VehicleToPVIndex[fvehid];
            if(fpvidx == -1)
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"This is not a personal vehicle."), 1;
        }
        else
        {
            new Float:fbest = 8.0; // raza de cautare (m)
            for(new i = 0; i < g_PVehicleCount; i++)
            {
                new cv = g_PVehicleVehicle[i];
                if(cv == -1) continue;
                new Float:vx, Float:vy, Float:vz;
                GetVehiclePos(cv, vx, vy, vz);
                new Float:d = GetPlayerDistanceFromPoint(playerid, vx, vy, vz);
                if(d < fbest) { fbest = d; fpvidx = i; fvehid = cv; }
            }
            if(fpvidx == -1)
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"No personal vehicle within 8m."), 1;
        }

        new fe, fl, fa, fd, fb, fbo, fo;
        GetVehicleParamsEx(fvehid, fe, fl, fa, fd, fb, fbo, fo);
        SetVehicleParamsEx(fvehid, fe, fl, fa, 0, fb, fbo, fo);

        PVehicleData[fpvidx][pvLocked] = false;
        new fq[128];
        mysql_format(g_SQL, fq, sizeof(fq), "UPDATE `vehicles_personal` SET `locked`=0 WHERE `id`=%d",
            PVehicleData[fpvidx][pvID]);
        mysql_tquery(g_SQL, fq, "", "", 0);

        new fmsg[128];
        format(fmsg, sizeof(fmsg), C_SUCCESS"[ADM] Success: "C_WHITE"Personal vehicle (ID: "C_INFO"%d"C_WHITE") force-unlocked.",
            PVehicleData[fpvidx][pvID]);
        SendClientMessage(playerid, COLOR_SUCCESS, fmsg);
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

        AC_SetVW(playerid, VW_PARTY);

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

        AC_SetVW(playerid, 0);
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

    // ---- /towpark (R.A.R. rank 3+: parcheaza un vehicul personal cu ITP expirat, tractat cu towtruck) ----
    if(strcmp(cmd, "/towpark", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;
        if(PlayerData[playerid][pFaction] != FACTION_RAR)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Only R.A.R. members can use this."), 1;
        if(PlayerData[playerid][pFactionRank] < 3)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Requires faction rank 3+."), 1;

        new tow = GetPlayerVehicleID(playerid);
        if(tow == 0 || GetPlayerVehicleSeat(playerid) != 0)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be the driver of a tow truck."), 1;
        if(GetVehicleModel(tow) != 525)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be driving a Towtruck."), 1;

        new towed = GetVehicleTrailer(tow);
        if(towed == 0)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You are not towing any vehicle."), 1;

        new pvidx = g_VehicleToPVIndex[towed];
        if(pvidx == -1)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"The towed vehicle is not a personal vehicle."), 1;

        if(VehicleDoc_IsValid(PVehicleData[pvidx][pvITPExp]))
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"The towed vehicle's ITP is still valid; you can't relocate it."), 1;

        // Pozitia de coborare: ~5m in spatele towtruck-ului, cu aceeasi orientare
        new Float:tx, Float:ty, Float:tz, Float:ta;
        GetVehiclePos(tow, tx, ty, tz);
        GetVehicleZAngle(tow, ta);
        new Float:dropX = tx - (5.0 * floatsin(-ta, degrees));
        new Float:dropY = ty - (5.0 * floatcos(-ta, degrees));

        DetachTrailerFromVehicle(tow);
        SetVehiclePos(towed, dropX, dropY, tz);
        SetVehicleZAngle(towed, ta);

        // Opreste motorul vehiculului tractat (ramane blocat pana la /redeemcar)
        new te, tl, taa, td, tb, tbo, to;
        GetVehicleParamsEx(towed, te, tl, taa, td, tb, tbo, to);
        SetVehicleParamsEx(towed, 0, tl, taa, td, tb, tbo, to);

        // Salveaza noua locatie de spawn + marcheaza vehiculul ca fiind confiscat (memorie + DB)
        PVehicleData[pvidx][pvLocX]          = dropX;
        PVehicleData[pvidx][pvLocY]          = dropY;
        PVehicleData[pvidx][pvLocZ]          = tz;
        PVehicleData[pvidx][pvRotation]      = ta;
        PVehicleData[pvidx][pvIsConfiscated] = true;
        PVehicles_RecreateLabel(pvidx);

        new q[256];
        mysql_format(g_SQL, q, sizeof(q),
            "UPDATE `vehicles_personal` SET `loc_x`=%.4f, `loc_y`=%.4f, `loc_z`=%.4f, `rotation`=%.4f, `is_confiscated`=1 WHERE `id`=%d",
            dropX, dropY, tz, ta, PVehicleData[pvidx][pvID]);
        mysql_tquery(g_SQL, q, "", "", 0);

        new tpmsg[144];
        format(tpmsg, sizeof(tpmsg), C_SUCCESS"Success: "C_WHITE"Vehicle impounded (ID: "C_INFO"%d"C_WHITE"). Owner pays a fee ("C_INFO"/redeemcar"C_WHITE") to release it.", PVehicleData[pvidx][pvID]);
        SendClientMessage(playerid, COLOR_SUCCESS, tpmsg);
        return 1;
    }

    // ---- /redeemcar (rascumpara un vehicul personal confiscat/tractat de R.A.R.) ----
    if(strcmp(cmd, "/redeemcar", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        // Gaseste vehiculul confiscat: cel in care sta playerul, sau cel mai apropiat detinut de el
        new pvidx = -1;
        new curVeh = GetPlayerVehicleID(playerid);
        if(curVeh != 0 && g_VehicleToPVIndex[curVeh] != -1)
            pvidx = g_VehicleToPVIndex[curVeh];
        else
        {
            for(new v = 0; v < g_PVehicleCount; v++)
            {
                if(PVehicleData[v][pvOwnerId] != PlayerData[playerid][pID]) continue;
                if(!PVehicleData[v][pvIsConfiscated]) continue;
                if(g_PVehicleVehicle[v] == -1) continue;
                if(IsPlayerInRangeOfPoint(playerid, 8.0, PVehicleData[v][pvLocX], PVehicleData[v][pvLocY], PVehicleData[v][pvLocZ]))
                {
                    pvidx = v;
                    break;
                }
            }
        }

        if(pvidx == -1)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Get in or stand next to your impounded vehicle to redeem it."), 1;

        if(PVehicleData[pvidx][pvOwnerId] != PlayerData[playerid][pID])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't own this vehicle."), 1;

        if(!PVehicleData[pvidx][pvIsConfiscated])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"This vehicle is not impounded."), 1;

        if(PlayerData[playerid][pMoney] < VEHICLE_REDEEM_FEE)
        {
            new emsg[128];
            format(emsg, sizeof(emsg), C_ERROR"Error: "C_WHITE"You need "C_INFO"$%d"C_WHITE" to pay the release fee.", VEHICLE_REDEEM_FEE);
            return SendClientMessage(playerid, COLOR_ERROR, emsg), 1;
        }

        PlayerData[playerid][pMoney] -= VEHICLE_REDEEM_FEE;
        UpdatePlayer(playerid, pMoney);

        PVehicleData[pvidx][pvIsConfiscated] = false;
        PVehicleData[pvidx][pvITPExp] = gettime(); // ITP valabil pana la sfarsitul zilei curente

        new dateStr[11];
        UnixToDateStr(PVehicleData[pvidx][pvITPExp], dateStr, sizeof(dateStr));

        new q[160];
        mysql_format(g_SQL, q, sizeof(q),
            "UPDATE `vehicles_personal` SET `is_confiscated`=0, `itp_exp`='%s' WHERE `id`=%d",
            dateStr, PVehicleData[pvidx][pvID]);
        mysql_tquery(g_SQL, q, "", "", 0);

        new smsg[160];
        format(smsg, sizeof(smsg), C_SUCCESS"Success: "C_WHITE"You paid the "C_INFO"$%d"C_WHITE" release fee. Your vehicle is unlocked; ITP is valid "C_INFO"until end of today"C_WHITE".", VEHICLE_REDEEM_FEE);
        SendClientMessage(playerid, COLOR_SUCCESS, smsg);
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

    // ---- /refuel (realimenteaza vehiculul personal la o benzinarie) ----
    if(strcmp(cmd, "/refuel", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        new vehid = GetPlayerVehicleID(playerid);
        if(vehid == 0 || GetPlayerVehicleSeat(playerid) != 0)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be driving a vehicle."), 1;

        if(!Fuel_PlayerAtStation(playerid))
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be at a "C_INFO"Gas Station"C_WHITE" to refuel."), 1;

        new missing = floatround(FUEL_MAX - g_VehicleFuel[vehid]);
        if(missing <= 0)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"The tank is already full."), 1;

        new cost = missing * FUEL_PRICE_PER_PCT;
        if(PlayerData[playerid][pMoney] < cost)
        {
            new emsg[128];
            format(emsg, sizeof(emsg), C_ERROR"Error: "C_WHITE"You need "C_INFO"$%s"C_WHITE" to fill the tank.", MoneyStr(cost));
            return SendClientMessage(playerid, COLOR_ERROR, emsg), 1;
        }

        PlayerData[playerid][pMoney] -= cost;
        GivePlayerMoney(playerid, -cost);
        UpdatePlayer(playerid, pMoney);

        g_VehicleFuel[vehid] = FUEL_MAX;
        Vehicle_SaveFuel(vehid);

        new rmsg[144];
        format(rmsg, sizeof(rmsg), C_SUCCESS"[Fuel] "C_WHITE"Tank filled to "C_INFO"100%%"C_WHITE" for "C_INFO"$%s"C_WHITE".", MoneyStr(cost));
        SendClientMessage(playerid, COLOR_SUCCESS, rmsg);
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

        if(g_ExamAState[playerid] != EXAMA_STATE_NONE || g_ExamState[playerid] != EXAM_STATE_NONE ||
           g_ExamCState[playerid] != EXAMC_STATE_NONE || g_ExamDState[playerid] != EXAMD_STATE_NONE)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You can't use GPS during an exam."), 1;

        if(!strlen(gname))
        {
            GPS_ShowCategoryDialog(playerid);
            return 1;
        }

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

        new statusA[24], statusB[24], statusC[24], statusD[24], statusAirA[24], statusAirH[24];
        License_FormatStatus(PlayerData[playerid][pDrivingLicA_exp], statusA, sizeof(statusA));
        License_FormatStatus(PlayerData[playerid][pDrivingLicB_exp], statusB, sizeof(statusB));
        License_FormatStatus(PlayerData[playerid][pDrivingLicC_exp], statusC, sizeof(statusC));
        License_FormatStatus(PlayerData[playerid][pDrivingLicD_exp], statusD, sizeof(statusD));
        License_FormatStatus(PlayerData[playerid][pAirLicA_exp], statusAirA, sizeof(statusAirA));
        License_FormatStatus(PlayerData[playerid][pAirLicH_exp], statusAirH, sizeof(statusAirH));

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
        format(line, sizeof(line), "Airplane A (Planes): "C_INFO"%s", statusAirA);
        SendClientMessage(playerid, COLOR_WHITE, line);
        format(line, sizeof(line), "Airplane H (Helicopters): "C_INFO"%s", statusAirH);
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

        new statusA[24], statusB[24], statusC[24], statusD[24], statusAirA[24], statusAirH[24];
        License_FormatStatus(PlayerData[targetid][pDrivingLicA_exp], statusA, sizeof(statusA));
        License_FormatStatus(PlayerData[targetid][pDrivingLicB_exp], statusB, sizeof(statusB));
        License_FormatStatus(PlayerData[targetid][pDrivingLicC_exp], statusC, sizeof(statusC));
        License_FormatStatus(PlayerData[targetid][pDrivingLicD_exp], statusD, sizeof(statusD));
        License_FormatStatus(PlayerData[targetid][pAirLicA_exp], statusAirA, sizeof(statusAirA));
        License_FormatStatus(PlayerData[targetid][pAirLicH_exp], statusAirH, sizeof(statusAirH));

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
        format(line, sizeof(line), "Airplane A (Planes): "C_INFO"%s", statusAirA);
        SendClientMessage(playerid, COLOR_WHITE, line);
        format(line, sizeof(line), "Airplane H (Helicopters): "C_INFO"%s", statusAirH);
        SendClientMessage(playerid, COLOR_WHITE, line);

        SendClientMessage(playerid, COLOR_INFO, C_INFO"___________________________________________");
        return 1;
    }

    // ---- /inspectplayer [playerid] (Politie rank 2+, on-duty: verifica arme si droguri) ----
    if(strcmp(cmd, "/inspectplayer", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;
        if(PlayerData[playerid][pFaction] != FACTION_POLICE)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You are not part of the Politia Romana."), 1;
        if(PlayerData[playerid][pFactionRank] < 2)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Requires faction rank 2 or higher."), 1;
        if(!PlayerData[playerid][pOnDuty])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be on-duty to use this command."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new p1[8];
        strmid(p1, cmdtext, idx, strlen(cmdtext), 8);
        if(!strlen(p1))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/inspectplayer [playerid]"C_WHITE"."), 1;

        new targetid = strval(p1);
        if(!IsPlayerConnected(targetid) || !PlayerData[targetid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"The player is not connected."), 1;
        if(targetid == playerid)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You can't inspect yourself."), 1;

        new Float:ipx, Float:ipy, Float:ipz;
        GetPlayerPos(playerid, ipx, ipy, ipz);
        if(!IsPlayerInRangeOfPoint(targetid, 5.0, ipx, ipy, ipz))
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"The player must be within 5m."), 1;

        new iline[144];
        format(iline, sizeof(iline), C_INFO"_____ Inspecting %s ____________________", PlayerData[targetid][pName]);
        SendClientMessage(playerid, COLOR_INFO, iline);

        // Arme
        SendClientMessage(playerid, COLOR_WHITE, C_WHITE"Weapons:");
        new wCount = 0, iwid, iwammo, iwname[32];
        for(new slot = 0; slot < 13; slot++)
        {
            GetPlayerWeaponData(targetid, slot, iwid, iwammo);
            if(iwid <= 0) continue;
            GetWeaponName(iwid, iwname, sizeof(iwname));
            format(iline, sizeof(iline), C_ERROR"- %s "C_INFO"(%d ammo)", iwname, iwammo);
            SendClientMessage(playerid, COLOR_WHITE, iline);
            wCount++;
        }
        if(wCount == 0)
            SendClientMessage(playerid, COLOR_WHITE, C_SUCCESS"- none");

        // Droguri
        if(g_PlayerDrugs[targetid] > 0)
            format(iline, sizeof(iline), C_WHITE"Drugs: "C_ERROR"%d g", g_PlayerDrugs[targetid]);
        else
            format(iline, sizeof(iline), C_WHITE"Drugs: "C_SUCCESS"none");
        SendClientMessage(playerid, COLOR_WHITE, iline);

        SendClientMessage(playerid, COLOR_INFO, C_INFO"___________________________________________");

        new itmsg[128];
        format(itmsg, sizeof(itmsg), C_INFO"[Police] "C_WHITE"Officer "C_INFO"%s"C_WHITE" searched you for weapons and drugs.", PlayerData[playerid][pName]);
        SendClientMessage(targetid, COLOR_INFO, itmsg);
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

        if(GetPlayerVehicleID(playerid) != 0)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be on foot to do this."), 1;

        if(!IsPlayerInRangeOfPoint(playerid, POLICE_TP_RANGE, POLICE_GARAGE_X, POLICE_GARAGE_Y, POLICE_GARAGE_Z))
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be at the garage."), 1;

        Police_TeleportTo(playerid, POLICE_ENTRANCE_X, POLICE_ENTRANCE_Y, POLICE_ENTRANCE_Z, POLICE_ENTRANCE_INT);
        return 1;
    }

    // ---- /entrace ----
    if(strcmp(cmd, "/entrace", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        if(PlayerData[playerid][pFaction] != FACTION_POLICE)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You are not part of the Politia Romana."), 1;

        if(GetPlayerVehicleID(playerid) != 0)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be on foot to do this."), 1;

        if(!IsPlayerInRangeOfPoint(playerid, POLICE_TP_RANGE, POLICE_ENTRANCE_X, POLICE_ENTRANCE_Y, POLICE_ENTRANCE_Z))
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be at the entrance."), 1;

        Police_TeleportTo(playerid, POLICE_GARAGE_X, POLICE_GARAGE_Y, POLICE_GARAGE_Z, POLICE_GARAGE_INT);
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

            // Fuel (daca vehiculul e spawnat) + stare lacat
            new fuelTxt[9], lockTxt[12], svid = g_PVehicleVehicle[pvidx];
            if(svid != -1) format(fuelTxt, sizeof(fuelTxt), "%d%%", floatround(g_VehicleFuel[svid]));
            else           format(fuelTxt, sizeof(fuelTxt), "-");
            if(PVehicleData[pvidx][pvLocked]) format(lockTxt, sizeof(lockTxt), "Locked");
            else                              format(lockTxt, sizeof(lockTxt), "Unlocked");

            new line[256];
            format(line, sizeof(line),
                "[ID: %d] %s | Plate: %s | Fuel: %s | %s | Insurance: %s | Medkit: %s | Extinguisher: %s | ITP: %s",
                PVehicleData[pvidx][pvID], vname, PVehicleData[pvidx][pvPlate], fuelTxt, lockTxt, insStatus, medStatus, extStatus, itpStatus);
            SendClientMessage(playerid, COLOR_WHITE, line);
        }

        if(!any)
            SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"You don't own any personal vehicles.");

        SendClientMessage(playerid, COLOR_INFO, C_INFO"___________________________________________________");
        return 1;
    }

    // ---- /hstats (statistici casa proprie) ----
    if(strcmp(cmd, "/hstats", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be logged in."), 1;

        if(PlayerData[playerid][pHouse] == 0)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't own a house."), 1;

        new hsidx = Houses_FindByID(PlayerData[playerid][pHouse]);
        if(hsidx == -1)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Your house could not be found."), 1;

        new htName[24];
        HouseTypeName(HouseData[hsidx][hType], htName);

        SendClientMessage(playerid, COLOR_INFO, C_INFO"_____ House Stats _______________________________");

        new hline[200];
        format(hline, sizeof(hline), "Name: %s | ID: %d | Price: $%s | Type: %s",
            HouseData[hsidx][hName], HouseData[hsidx][hID], MoneyStr(HouseData[hsidx][hPrice]), htName);
        SendClientMessage(playerid, COLOR_WHITE, hline);

        if(HouseData[hsidx][hHasFridge])
        {
            format(hline, sizeof(hline), "Fridge: Yes -> %s: %d/%d, %s: %d/%d, %s: %d/%d, %s: %d/%d, %s: %d/%d",
                g_FridgeName[0], HouseData[hsidx][hFridge][0], g_FridgeMax[0],
                g_FridgeName[1], HouseData[hsidx][hFridge][1], g_FridgeMax[1],
                g_FridgeName[2], HouseData[hsidx][hFridge][2], g_FridgeMax[2],
                g_FridgeName[3], HouseData[hsidx][hFridge][3], g_FridgeMax[3],
                g_FridgeName[4], HouseData[hsidx][hFridge][4], g_FridgeMax[4]);
            SendClientMessage(playerid, COLOR_WHITE, hline);
        }
        else SendClientMessage(playerid, COLOR_WHITE, "Fridge: No");

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

        if(itpBonnet != 1)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must open the bonnet (hood) first."), 1;

        if(itpLights != 1)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must turn on the headlights first."), 1;

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
        format(cmsg, sizeof(cmsg), C_SUCCESS"[ADM] Success: "C_WHITE"Gave "C_INFO"%s"C_WHITE" a type "C_INFO"%d"C_WHITE" caravan.",
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
        new p1[16], p2[16];
        strmid(p1, cmdtext, idx, strlen(cmdtext), 16);
        while(cmdtext[idx] > ' ') idx++;
        while(cmdtext[idx] == ' ') idx++;
        strmid(p2, cmdtext, idx, strlen(cmdtext), 16);

        if(!strlen(p1) || !strlen(p2))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/vcreate [price] [from_biz_id]"C_WHITE"."), 1;

        new price = strval(p1);
        if(price <= 0)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Invalid price."), 1;

        new fromBiz = strval(p2);

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
        PVehicleData[newIdx][pvFirstReg]        = 0;
        PVehicleData[newIdx][pvFromBiz]         = fromBiz;
        PVehicleData[newIdx][pvFuel]            = FUEL_MAX;
        g_PVehicleVehicle[newIdx]               = -1;
        g_PVehicleCount++;

        new q[256];
        mysql_format(g_SQL, q, sizeof(q),
            "INSERT INTO `vehicles_personal` (`owner_id`,`model_id`,`color1`,`color2`,`plate`,`price`,`loc_x`,`loc_y`,`loc_z`,`rotation`,`from_biz`) \
             VALUES (0,%d,1,1,NULL,%d,%.4f,%.4f,%.4f,%.4f,%d)",
            model, price, vx, vy, vz, vangle, fromBiz);
        mysql_tquery(g_SQL, q, "OnVehiclePersonalCreated", "ii", playerid, newIdx);
        return 1;
    }

    // ---- /vc [option] ... (admin: modifica vehiculul personal in care esti) ----
    if(strcmp(cmd, "/vc", true) == 0)
    {
        if(PlayerData[playerid][pAdminLevel] < 5)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have access. Requires admin level 5."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new vopt[16], vpos = 0;
        while(cmdtext[idx] > ' ' && vpos < 15) { vopt[vpos++] = cmdtext[idx]; idx++; }
        vopt[vpos] = EOS;
        if(!strlen(vopt))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/vc [loc / price / insurance / medkit / extinctor / itp]"C_WHITE"."), 1;

        new vehid = GetPlayerVehicleID(playerid);
        if(vehid == 0)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be in a vehicle."), 1;
        new pvidx = g_VehicleToPVIndex[vehid];
        if(pvidx == -1)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"This is not a personal vehicle."), 1;

        // ---- /vc loc (seteaza locatia de spawn la pozitia curenta) ----
        if(strcmp(vopt, "loc", true) == 0)
        {
            GetVehiclePos(vehid, PVehicleData[pvidx][pvLocX], PVehicleData[pvidx][pvLocY], PVehicleData[pvidx][pvLocZ]);
            GetVehicleZAngle(vehid, PVehicleData[pvidx][pvRotation]);
            PVehicles_RecreateLabel(pvidx);

            new q[256];
            mysql_format(g_SQL, q, sizeof(q),
                "UPDATE `vehicles_personal` SET `loc_x`=%.4f, `loc_y`=%.4f, `loc_z`=%.4f, `rotation`=%.4f WHERE `id`=%d",
                PVehicleData[pvidx][pvLocX], PVehicleData[pvidx][pvLocY], PVehicleData[pvidx][pvLocZ], PVehicleData[pvidx][pvRotation],
                PVehicleData[pvidx][pvID]);
            mysql_tquery(g_SQL, q, "", "", 0);

            new lmsg[128];
            format(lmsg, sizeof(lmsg), C_SUCCESS"[ADM] Success: "C_WHITE"The spawn location of vehicle (ID: "C_INFO"%d"C_WHITE") was set to your current position.",
                PVehicleData[pvidx][pvID]);
            SendClientMessage(playerid, COLOR_SUCCESS, lmsg);
            return 1;
        }

        // ---- /vc price [new_price] ----
        if(strcmp(vopt, "price", true) == 0)
        {
            if(PlayerData[playerid][pAdminLevel] < 6)
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have access. Requires admin level 6."), 1;

            while(cmdtext[idx] == ' ') idx++;
            new p1[16];
            strmid(p1, cmdtext, idx, strlen(cmdtext), 16);
            if(!strlen(p1))
                return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/vc price [new_price]"C_WHITE"."), 1;

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
            format(lmsg, sizeof(lmsg), C_SUCCESS"[ADM] Success: "C_WHITE"The price of vehicle (ID: "C_INFO"%d"C_WHITE") was changed to "C_INFO"$%s"C_WHITE".",
                PVehicleData[pvidx][pvID], MoneyStr(newPrice));
            SendClientMessage(playerid, COLOR_SUCCESS, lmsg);
            return 1;
        }

        // ---- /vc insurance [YYYY-MM-DD] ----
        if(strcmp(vopt, "insurance", true) == 0)
        {
            while(cmdtext[idx] == ' ') idx++;
            new dateStr[16];
            strmid(dateStr, cmdtext, idx, strlen(cmdtext), 16);
            if(!strlen(dateStr))
                return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/vc insurance [YYYY-MM-DD]"C_WHITE"."), 1;
            if(!IsValidDateStr(dateStr))
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Invalid format. Use "C_INFO"YYYY-MM-DD"C_WHITE"."), 1;

            PVehicleData[pvidx][pvInsuranceExp] = DateStrToUnix(dateStr);

            new q[128];
            mysql_format(g_SQL, q, sizeof(q), "UPDATE `vehicles_personal` SET `insurance_exp`='%s' WHERE `id`=%d",
                dateStr, PVehicleData[pvidx][pvID]);
            mysql_tquery(g_SQL, q, "", "", 0);

            new lmsg[128];
            format(lmsg, sizeof(lmsg),
                C_SUCCESS"[ADM] Success: "C_WHITE"The insurance expiry date (ID: "C_INFO"%d"C_WHITE") was changed to "C_INFO"%s"C_WHITE".",
                PVehicleData[pvidx][pvID], dateStr);
            SendClientMessage(playerid, COLOR_SUCCESS, lmsg);
            return 1;
        }

        // ---- /vc medkit [YYYY-MM-DD] ----
        if(strcmp(vopt, "medkit", true) == 0)
        {
            while(cmdtext[idx] == ' ') idx++;
            new dateStr[16];
            strmid(dateStr, cmdtext, idx, strlen(cmdtext), 16);
            if(!strlen(dateStr))
                return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/vc medkit [YYYY-MM-DD]"C_WHITE"."), 1;
            if(!IsValidDateStr(dateStr))
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Invalid format. Use "C_INFO"YYYY-MM-DD"C_WHITE"."), 1;

            PVehicleData[pvidx][pvMedkitExp] = DateStrToUnix(dateStr);

            new q[128];
            mysql_format(g_SQL, q, sizeof(q), "UPDATE `vehicles_personal` SET `medkit_exp`='%s' WHERE `id`=%d",
                dateStr, PVehicleData[pvidx][pvID]);
            mysql_tquery(g_SQL, q, "", "", 0);

            new lmsg[128];
            format(lmsg, sizeof(lmsg),
                C_SUCCESS"[ADM] Success: "C_WHITE"The medkit expiry date (ID: "C_INFO"%d"C_WHITE") was changed to "C_INFO"%s"C_WHITE".",
                PVehicleData[pvidx][pvID], dateStr);
            SendClientMessage(playerid, COLOR_SUCCESS, lmsg);
            return 1;
        }

        // ---- /vc extinctor [YYYY-MM-DD] ----
        if(strcmp(vopt, "extinctor", true) == 0)
        {
            while(cmdtext[idx] == ' ') idx++;
            new dateStr[16];
            strmid(dateStr, cmdtext, idx, strlen(cmdtext), 16);
            if(!strlen(dateStr))
                return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/vc extinctor [YYYY-MM-DD]"C_WHITE"."), 1;
            if(!IsValidDateStr(dateStr))
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Invalid format. Use "C_INFO"YYYY-MM-DD"C_WHITE"."), 1;

            PVehicleData[pvidx][pvExtinguisherExp] = DateStrToUnix(dateStr);

            new q[128];
            mysql_format(g_SQL, q, sizeof(q), "UPDATE `vehicles_personal` SET `extinguisher_exp`='%s' WHERE `id`=%d",
                dateStr, PVehicleData[pvidx][pvID]);
            mysql_tquery(g_SQL, q, "", "", 0);

            new lmsg[128];
            format(lmsg, sizeof(lmsg),
                C_SUCCESS"[ADM] Success: "C_WHITE"The extinguisher expiry date (ID: "C_INFO"%d"C_WHITE") was changed to "C_INFO"%s"C_WHITE".",
                PVehicleData[pvidx][pvID], dateStr);
            SendClientMessage(playerid, COLOR_SUCCESS, lmsg);
            return 1;
        }

        // ---- /vc itp [YYYY-MM-DD] ----
        if(strcmp(vopt, "itp", true) == 0)
        {
            while(cmdtext[idx] == ' ') idx++;
            new dateStr[16];
            strmid(dateStr, cmdtext, idx, strlen(cmdtext), 16);
            if(!strlen(dateStr))
                return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/vc itp [YYYY-MM-DD]"C_WHITE"."), 1;
            if(!IsValidDateStr(dateStr))
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Invalid format. Use "C_INFO"YYYY-MM-DD"C_WHITE"."), 1;

            PVehicleData[pvidx][pvITPExp] = DateStrToUnix(dateStr);

            new q[128];
            mysql_format(g_SQL, q, sizeof(q), "UPDATE `vehicles_personal` SET `itp_exp`='%s' WHERE `id`=%d",
                dateStr, PVehicleData[pvidx][pvID]);
            mysql_tquery(g_SQL, q, "", "", 0);

            new lmsg[128];
            format(lmsg, sizeof(lmsg),
                C_SUCCESS"[ADM] Success: "C_WHITE"The ITP expiry date (ID: "C_INFO"%d"C_WHITE") was changed to "C_INFO"%s"C_WHITE".",
                PVehicleData[pvidx][pvID], dateStr);
            SendClientMessage(playerid, COLOR_SUCCESS, lmsg);
            return 1;
        }

        return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Unknown option. Use "C_INFO"/vc [price/insurance/medkit/extinctor/itp]"C_WHITE"."), 1;
    }

    // ---- /setlic [playerid] [all/A/B/C/D/H/P] [YYYY-MM-DD] (seteaza expirarea permiselor) ----
    // A/B/C/D = permis auto; P = permis avion (avioane); H = permis avion (elicoptere)
    if(strcmp(cmd, "/setlic", true) == 0)
    {
        if(PlayerData[playerid][pAdminLevel] < 3)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have access. Requires admin level 3."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new slp1[8], sla = 0;
        while(cmdtext[idx] > ' ' && sla < 7) { slp1[sla++] = cmdtext[idx]; idx++; }
        slp1[sla] = EOS;
        while(cmdtext[idx] == ' ') idx++;
        new slcat[6], slb = 0;
        while(cmdtext[idx] > ' ' && slb < 5) { slcat[slb++] = cmdtext[idx]; idx++; }
        slcat[slb] = EOS;
        while(cmdtext[idx] == ' ') idx++;
        new slDate[16];
        strmid(slDate, cmdtext, idx, strlen(cmdtext), 16);

        if(!strlen(slp1) || !strlen(slcat) || !strlen(slDate))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/setlic [playerid] [all/A/B/C/D/H/P] [YYYY-MM-DD]"C_WHITE"."), 1;

        new targetid = strval(slp1);
        if(!IsPlayerConnected(targetid) || !PlayerData[targetid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"The player is not connected."), 1;
        if(!IsValidDateStr(slDate))
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Invalid format. Use "C_INFO"YYYY-MM-DD"C_WHITE"."), 1;

        new bool:slAll = (strcmp(slcat, "all", true) == 0);
        if(!slAll
            && strcmp(slcat, "A", true) != 0 && strcmp(slcat, "B", true) != 0
            && strcmp(slcat, "C", true) != 0 && strcmp(slcat, "D", true) != 0
            && strcmp(slcat, "H", true) != 0 && strcmp(slcat, "P", true) != 0)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Invalid category. Use "C_INFO"all/A/B/C/D/H/P"C_WHITE"."), 1;

        if(slAll || strcmp(slcat, "A", true) == 0) { format(PlayerData[targetid][pDrivingLicA_exp], 11, "%s", slDate); UpdatePlayer(targetid, pDrivingLicA_exp); }
        if(slAll || strcmp(slcat, "B", true) == 0) { format(PlayerData[targetid][pDrivingLicB_exp], 11, "%s", slDate); UpdatePlayer(targetid, pDrivingLicB_exp); }
        if(slAll || strcmp(slcat, "C", true) == 0) { format(PlayerData[targetid][pDrivingLicC_exp], 11, "%s", slDate); UpdatePlayer(targetid, pDrivingLicC_exp); }
        if(slAll || strcmp(slcat, "D", true) == 0) { format(PlayerData[targetid][pDrivingLicD_exp], 11, "%s", slDate); UpdatePlayer(targetid, pDrivingLicD_exp); }
        if(slAll || strcmp(slcat, "P", true) == 0) { format(PlayerData[targetid][pAirLicA_exp],   11, "%s", slDate); UpdatePlayer(targetid, pAirLicA_exp); }
        if(slAll || strcmp(slcat, "H", true) == 0) { format(PlayerData[targetid][pAirLicH_exp],   11, "%s", slDate); UpdatePlayer(targetid, pAirLicH_exp); }

        new slLabel[8];
        if(slAll) format(slLabel, sizeof(slLabel), "all");
        else      format(slLabel, sizeof(slLabel), "%s", slcat);

        new lmsg[160];
        format(lmsg, sizeof(lmsg), C_SUCCESS"[ADM] Success: "C_WHITE"Set "C_INFO"%s"C_WHITE"'s license(s) "C_INFO"%s"C_WHITE" to expire on "C_INFO"%s"C_WHITE".",
            PlayerData[targetid][pName], slLabel, slDate);
        SendClientMessage(playerid, COLOR_SUCCESS, lmsg);
        format(lmsg, sizeof(lmsg), C_INFO"Info: "C_WHITE"Your license(s) "C_INFO"%s"C_WHITE" now expire on "C_INFO"%s"C_WHITE".", slLabel, slDate);
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
                if(PlayerData[playerid][pHouse] == 0 || Houses_FindByID(PlayerData[playerid][pHouse]) == -1)
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
        format(lmsg, sizeof(lmsg), C_SUCCESS"[ADM] Success: "C_WHITE"You have successfully issued "C_INFO"PayDay"C_WHITE".");
        SendClientMessage(playerid, COLOR_SUCCESS, lmsg);
        return 1;
    }

    // ---- /fc [item] ... (admin: modifica proprietatile unei factiuni) ----
    if(strcmp(cmd, "/fc", true) == 0)
    {
        if(PlayerData[playerid][pAdminLevel] < 5)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have access. Requires admin level 5."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new item[16], ipos = 0;
        while(cmdtext[idx] > ' ' && ipos < 15) { item[ipos++] = cmdtext[idx]; idx++; }
        item[ipos] = EOS;
        if(!strlen(item))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/fc [hq / interiorLoc / interior / vw / hqicon / pickup / lead / vehLoc / createVeh / removelead]"C_WHITE"."), 1;

        // ---- /fc hq [faction_id] ----
        if(strcmp(item, "hq", true) == 0)
        {
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

        // ---- /fc interiorloc [faction_id] ----
        if(strcmp(item, "interiorloc", true) == 0)
        {
            while(cmdtext[idx] == ' ') idx++;
            new param[8];
            strmid(param, cmdtext, idx, strlen(cmdtext), 8);
            if(!strlen(param))
                return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/fc interiorloc [faction_id]"C_WHITE"."), 1;

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

        // ---- /fc interior [faction_id] [interior_id] ----
        if(strcmp(item, "interior", true) == 0)
        {
            while(cmdtext[idx] == ' ') idx++;
            new p1[8], p2[8];
            strmid(p1, cmdtext, idx, strlen(cmdtext), 8);
            while(cmdtext[idx] > ' ') idx++;
            while(cmdtext[idx] == ' ') idx++;
            strmid(p2, cmdtext, idx, strlen(cmdtext), 8);

            if(!strlen(p1) || !strlen(p2))
                return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/fc interior [faction_id] [interior_id]"C_WHITE"."), 1;

            new fid = strval(p1);
            if(fid < 1 || fid > MAX_FACTIONS)
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Invalid faction ID (1-"#MAX_FACTIONS")."), 1;

            new interiorid = strval(p2);
            FactionData[fid][fInterior] = interiorid;

            new q[160];
            mysql_format(g_SQL, q, sizeof(q),
                "UPDATE `factions` SET `interior`=%d WHERE `id`=%d", interiorid, fid);
            mysql_tquery(g_SQL, q, "", "", 0);

            Drugs_RecreateSeifMarker(fid); // seiful depinde de interior

            new lmsg[128];
            format(lmsg, sizeof(lmsg), C_SUCCESS"Success: "C_WHITE"Interior for "C_INFO"%s"C_WHITE" set to "C_INFO"%d"C_WHITE".", FactionData[fid][fName], interiorid);
            SendClientMessage(playerid, COLOR_SUCCESS, lmsg);
            return 1;
        }

        // ---- /fc vw [faction_id] [vw_id] ----
        if(strcmp(item, "vw", true) == 0)
        {
            while(cmdtext[idx] == ' ') idx++;
            new p1[8], p2[8];
            strmid(p1, cmdtext, idx, strlen(cmdtext), 8);
            while(cmdtext[idx] > ' ') idx++;
            while(cmdtext[idx] == ' ') idx++;
            strmid(p2, cmdtext, idx, strlen(cmdtext), 8);

            if(!strlen(p1) || !strlen(p2))
                return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/fc vw [faction_id] [vw_id]"C_WHITE"."), 1;

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
            Drugs_RecreateSeifMarker(fid);        // seiful depinde de vw

            new lmsg[128];
            format(lmsg, sizeof(lmsg), C_SUCCESS"Success: "C_WHITE"Virtual world for "C_INFO"%s"C_WHITE" set to "C_INFO"%d"C_WHITE".", FactionData[fid][fName], vwid);
            SendClientMessage(playerid, COLOR_SUCCESS, lmsg);
            return 1;
        }

        // ---- /fc hqicon [faction_id] [icon_id] ----
        if(strcmp(item, "hqicon", true) == 0)
        {
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

        // ---- /fc pickup [faction_id] [pickup_id] ----
        if(strcmp(item, "pickup", true) == 0)
        {
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

        // ---- /fc lead [faction_id] [playerid] ----
        if(strcmp(item, "lead", true) == 0)
        {
            while(cmdtext[idx] == ' ') idx++;
            new p1[8], p2[8];
            strmid(p1, cmdtext, idx, strlen(cmdtext), 8);
            new fid = strval(p1);
            while(cmdtext[idx] > ' ') idx++;
            while(cmdtext[idx] == ' ') idx++;
            strmid(p2, cmdtext, idx, strlen(cmdtext), 8);
            new targetid = strval(p2);

            if(fid < 1 || fid > MAX_FACTIONS)
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Invalid faction ID (1-8)."), 1;

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

            if(oldFaction != fid) FactionData[fid][fMembers]++; // nu incrementa daca era deja in aceasta factiune
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

        // ---- /fc vehloc (muta punctul de spawn al vehiculului de factiune curent la pozitia lui actuala) ----
        if(strcmp(item, "vehloc", true) == 0)
        {
            new veh = GetPlayerVehicleID(playerid);
            if(veh == 0 || GetPlayerVehicleSeat(playerid) != 0)
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be driving a faction vehicle."), 1;

            new vidx = -1;
            for(new i = 0; i < g_VFactionCount; i++)
                if(g_VFactionVehicle[i] == veh) { vidx = i; break; }

            if(vidx == -1)
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"This is not a faction vehicle."), 1;

            new Float:vx, Float:vy, Float:vz, Float:vangle;
            GetVehiclePos(veh, vx, vy, vz);
            GetVehicleZAngle(veh, vangle);

            VFactionData[vidx][vfLocX]     = vx;
            VFactionData[vidx][vfLocY]     = vy;
            VFactionData[vidx][vfLocZ]     = vz;
            VFactionData[vidx][vfRotation] = vangle;

            new q[192];
            mysql_format(g_SQL, q, sizeof(q),
                "UPDATE `vehicles_faction` SET `loc_x`=%.4f, `loc_y`=%.4f, `loc_z`=%.4f, `rotation`=%.4f WHERE `id`=%d",
                vx, vy, vz, vangle, VFactionData[vidx][vfID]);
            mysql_tquery(g_SQL, q, "", "", 0);

            new lmsg[144];
            format(lmsg, sizeof(lmsg), C_SUCCESS"Success: "C_WHITE"Faction vehicle "C_INFO"#%d"C_WHITE" (%s) spawn location set to your current position.",
                VFactionData[vidx][vfID], FactionData[VFactionData[vidx][vfFactionID]][fName]);
            SendClientMessage(playerid, COLOR_SUCCESS, lmsg);
            return 1;
        }

        // ---- /fc createveh [faction_id] (creeaza un vehicul de factiune la pozitia vehiculului curent) ----
        if(strcmp(item, "createveh", true) == 0)
        {
            if(g_VFactionCount >= MAX_VFACTION_VEHICLES)
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Limit of "C_INFO#MAX_VFACTION_VEHICLES C_WHITE" faction vehicles reached."), 1;

            while(cmdtext[idx] == ' ') idx++;
            new cvParam[8];
            strmid(cvParam, cmdtext, idx, strlen(cmdtext), 8);
            if(!strlen(cvParam))
                return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/fc createveh [faction_id]"C_WHITE"."), 1;

            new cvFid = strval(cvParam);
            if(cvFid < 1 || cvFid > MAX_FACTIONS)
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Invalid faction ID (1-"#MAX_FACTIONS")."), 1;

            new cvVeh = GetPlayerVehicleID(playerid);
            if(cvVeh == 0)
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You must be in a vehicle."), 1;

            new Float:cvx, Float:cvy, Float:cvz, Float:cva;
            GetVehiclePos(cvVeh, cvx, cvy, cvz);
            GetVehicleZAngle(cvVeh, cva);
            new cvModel = GetVehicleModel(cvVeh);

            new cvIdx = g_VFactionCount;
            VFactionData[cvIdx][vfFactionID] = cvFid;
            VFactionData[cvIdx][vfModelID]   = cvModel;
            VFactionData[cvIdx][vfLocX]      = cvx;
            VFactionData[cvIdx][vfLocY]      = cvy;
            VFactionData[cvIdx][vfLocZ]      = cvz;
            VFactionData[cvIdx][vfRotation]  = cva;
            VFactionData[cvIdx][vfColor1]    = -1;
            VFactionData[cvIdx][vfColor2]    = -1;
            g_VFactionVehicle[cvIdx]         = -1;
            g_VFactionCount++;

            new cvq[256];
            mysql_format(g_SQL, cvq, sizeof(cvq),
                "INSERT INTO `vehicles_faction` (`faction_id`,`model_id`,`loc_x`,`loc_y`,`loc_z`,`rotation`,`color1`,`color2`) \
                 VALUES (%d,%d,%.4f,%.4f,%.4f,%.4f,-1,-1)",
                cvFid, cvModel, cvx, cvy, cvz, cva);
            mysql_tquery(g_SQL, cvq, "OnVehicleFactionCreated", "ii", playerid, cvIdx);
            return 1;
        }

        // ---- /fc removelead [faction_id] (scoate liderul unei factiuni) ----
        if(strcmp(item, "removelead", true) == 0)
        {
            while(cmdtext[idx] == ' ') idx++;
            new rlParam[8];
            strmid(rlParam, cmdtext, idx, strlen(cmdtext), 8);
            if(!strlen(rlParam))
                return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/fc removelead [faction_id]"C_WHITE"."), 1;

            new rlFid = strval(rlParam);
            if(rlFid < 1 || rlFid > MAX_FACTIONS)
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Invalid faction ID (1-"#MAX_FACTIONS")."), 1;

            if(!strlen(FactionData[rlFid][fLead]))
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"The faction doesn't have a leader."), 1;

            // Cauta leaderul online (rank 5 in aceasta factiune) ca sa-i resetam direct datele in memorie
            new rlLeaderOnline = INVALID_PLAYER_ID;
            for(new i = 0; i < MAX_PLAYERS; i++)
            {
                if(IsPlayerConnected(i) && PlayerData[i][pLogged] && PlayerData[i][pFaction] == rlFid && PlayerData[i][pFactionRank] == 5)
                {
                    rlLeaderOnline = i;
                    break;
                }
            }

            if(rlLeaderOnline != INVALID_PLAYER_ID)
            {
                PlayerData[rlLeaderOnline][pFaction]     = 0;
                PlayerData[rlLeaderOnline][pFactionRank] = 1;
                SetPlayerColor(rlLeaderOnline, FactionColors[FACTION_NONE]);
                Factions_SetPlayerIcons(rlLeaderOnline);

                new ql[128];
                mysql_format(g_SQL, ql, sizeof(ql), "UPDATE `players` SET `faction`=0, `faction_rank`=1 WHERE `id`=%d",
                    PlayerData[rlLeaderOnline][pID]);
                mysql_tquery(g_SQL, ql, "", "", 0);

                SendClientMessage(rlLeaderOnline, COLOR_ERROR,
                    C_ERROR"Info: "C_WHITE"You are no longer the faction leader. You have been removed from the faction.");
            }
            else
            {
                new ql[160];
                mysql_format(g_SQL, ql, sizeof(ql), "UPDATE `players` SET `faction`=0, `faction_rank`=1 WHERE `username`='%e'",
                    FactionData[rlFid][fLead]);
                mysql_tquery(g_SQL, ql, "", "", 0);
            }

            FactionData[rlFid][fMembers]--;
            if(FactionData[rlFid][fMembers] < 0) FactionData[rlFid][fMembers] = 0;
            FactionData[rlFid][fLead][0] = EOS;

            new q[128];
            mysql_format(g_SQL, q, sizeof(q), "UPDATE `factions` SET `lead`='', `members`=%d WHERE `id`=%d",
                FactionData[rlFid][fMembers], rlFid);
            mysql_tquery(g_SQL, q, "", "", 0);

            new rmsg[128];
            format(rmsg, sizeof(rmsg), C_SUCCESS"[ADM] Success: "C_WHITE"The leader of faction "C_INFO"%s"C_WHITE" has been removed.",
                FactionData[rlFid][fName]);
            SendClientMessage(playerid, COLOR_SUCCESS, rmsg);
            return 1;
        }

        return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Unknown item. Use "C_INFO"/fc [hq / interiorloc / interior / vw / hqicon / pickup / lead / vehloc / createveh / removelead]"C_WHITE"."), 1;
    }

    // ---- /adminuninvite [playerid] (admin 4+: scoate un player din facțiune) ----
    if(strcmp(cmd, "/adminuninvite", true) == 0)
    {
        if(PlayerData[playerid][pAdminLevel] < 4)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have access. Requires admin level 4."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new aup1[8];
        strmid(aup1, cmdtext, idx, strlen(cmdtext), 8);
        if(!strlen(aup1))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Use "C_INFO"/adminuninvite [playerid]"C_WHITE"."), 1;

        new targetid = strval(aup1);
        if(!IsPlayerConnected(targetid) || !PlayerData[targetid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"The player is not connected."), 1;

        new oldFac = PlayerData[targetid][pFaction];
        if(oldFac < 1 || oldFac > MAX_FACTIONS)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"That player is not part of a faction."), 1;

        new bool:wasLead = (PlayerData[targetid][pFactionRank] == 5) ||
            (strlen(FactionData[oldFac][fLead]) && strcmp(FactionData[oldFac][fLead], PlayerData[targetid][pName], true) == 0);

        // Reseteaza playerul
        PlayerData[targetid][pFaction]     = 0;
        PlayerData[targetid][pFactionRank] = 1;
        PlayerData[targetid][pFactionJoin] = 0;
        SetPlayerColor(targetid, FactionColors[FACTION_NONE]);
        Factions_SetPlayerIcons(targetid);
        Player_RecalcSpawn(targetid);

        new q[160];
        mysql_format(g_SQL, q, sizeof(q),
            "UPDATE `players` SET `faction`=0, `faction_rank`=1, `faction_join`=NULL WHERE `id`=%d",
            PlayerData[targetid][pID]);
        mysql_tquery(g_SQL, q, "", "", 0);

        // Scade fMembers la vechea factiune si reseteaza leaderul daca era el
        FactionData[oldFac][fMembers]--;
        if(FactionData[oldFac][fMembers] < 0) FactionData[oldFac][fMembers] = 0;

        if(wasLead)
        {
            FactionData[oldFac][fLead][0] = EOS;
            mysql_format(g_SQL, q, sizeof(q), "UPDATE `factions` SET `lead`='', `members`=%d WHERE `id`=%d",
                FactionData[oldFac][fMembers], oldFac);
        }
        else
        {
            mysql_format(g_SQL, q, sizeof(q), "UPDATE `factions` SET `members`=%d WHERE `id`=%d",
                FactionData[oldFac][fMembers], oldFac);
        }
        mysql_tquery(g_SQL, q, "", "", 0);

        new aumsg[144];
        format(aumsg, sizeof(aumsg), C_SUCCESS"[ADM] Success: "C_WHITE"Removed "C_INFO"%s"C_WHITE" from faction "C_INFO"%s"C_WHITE".",
            PlayerData[targetid][pName], FactionData[oldFac][fName]);
        SendClientMessage(playerid, COLOR_SUCCESS, aumsg);
        SendClientMessage(targetid, COLOR_ERROR, C_ERROR"Info: "C_WHITE"An admin removed you from your faction.");

        SetPlayerHealth(targetid, 0.0); // se seteaza si HP=0 (moare la scoaterea din factiune)
        return 1;
    }

    return 0;
}

public OnPlayerSpawn(playerid)
{
    AC_ResetWeapons(playerid); // la respawn armele se pierd -> reseteaza evidenta AC
    g_HasSniper[playerid] = false; // sniperul de vanatoare se pierde la respawn
    AC_SetInterior(playerid, 0);
    TogglePlayerClock(playerid, 0);
    if(PlayerData[playerid][pLogged])
    {
        AC_SetVW(playerid, 0);
        AC_SetPos(playerid,
            PlayerData[playerid][pSpawnX],
            PlayerData[playerid][pSpawnY],
            PlayerData[playerid][pSpawnZ]);

        // La spawn-ul de factiune (tip 2), aplica vw-ul si interiorul factiunii din DB
        if(PlayerData[playerid][pSpawn] == 2)
        {
            new fid = PlayerData[playerid][pFaction];
            if(fid >= 1 && fid <= MAX_FACTIONS)
            {
                AC_SetVW(playerid, FactionData[fid][fvw]);
                AC_SetInterior(playerid, FactionData[fid][fInterior]);
            }
        }

        // Reaplica nivelul de wanted (persistat) dupa respawn
        SetPlayerWantedLevel(playerid, PlayerData[playerid][pWanted]);

        // Daca mai are de stat la inchisoare, il ducem inapoi in celula
        if(PlayerData[playerid][pJailSeconds] > 0)
        {
            Jail_Send(playerid);
            new jmsg[128];
            format(jmsg, sizeof(jmsg), C_ERROR"[P.R.] "C_WHITE"You are still jailed for "C_INFO"%d"C_WHITE" more second(s).", PlayerData[playerid][pJailSeconds]);
            SendClientMessage(playerid, COLOR_ERROR, jmsg);
        }

        // Freeze scurt (500ms) la spawn ca sa apuce sa se incarce lumea/pozitia, apoi unfreeze
        TogglePlayerControllable(playerid, 0);
        SetTimerEx("Spawn_Unfreeze", 500, false, "i", playerid);
    }
    return 1;
}

forward Spawn_Unfreeze(playerid);
public Spawn_Unfreeze(playerid)
{
    if(IsPlayerConnected(playerid))
        TogglePlayerControllable(playerid, 1);
}

#define LOCAL_CHAT_RANGE 37.5

public OnPlayerText(playerid, text[])
{
    if(!PlayerData[playerid][pLogged]) return 0;

    // Jucatorii mutati nu pot vorbi in chat
    if(Player_IsMuted(playerid))
    {
        new mins = (PlayerData[playerid][pMuteExpire] - gettime() + 59) / 60;
        new mmsg[128];
        format(mmsg, sizeof(mmsg), C_ERROR"You are muted "C_WHITE"for another "C_INFO"%d"C_WHITE" minute(s).", mins);
        SendClientMessage(playerid, COLOR_ERROR, mmsg);
        return 0;
    }

    // Daca jucatorul e intr-o convorbire telefonica activa, vorbele lui merg in telefon, nu in chatul local
    if(g_PhoneCallPartner[playerid] != INVALID_PLAYER_ID && g_PhoneCallActive[playerid])
    {
        new partner = g_PhoneCallPartner[playerid];
        new pbrand[24];
        Phone_GetBrand(playerid, pbrand, sizeof(pbrand));

        new pmsg[200];
        format(pmsg, sizeof(pmsg), C_INFO"%s[%s]: "C_WHITE"%s", PlayerData[playerid][pName], pbrand, text);
        SendClientMessage(playerid, COLOR_WHITE, pmsg);
        if(partner != INVALID_PLAYER_ID && IsPlayerConnected(partner))
            SendClientMessage(partner, COLOR_WHITE, pmsg);
        return 1;
    }

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

    // Vanatoare: pierzi caprioarele purtate cand mori
    if(g_HuntMeat[playerid] > 0)
    {
        g_HuntMeat[playerid] = 0;
        SendClientMessage(playerid, COLOR_ERROR, C_ERROR"[Hunt] "C_WHITE"You lost your deer when you died.");
    }
    g_HasSniper[playerid] = false;
    Farm_Cancel(playerid, false); // moartea anuleaza lucrarea agricola in curs
    Farm_RentCleanup(playerid);
    Farm_DeliverCleanup(playerid);

    // Salveaza nivelul de wanted in DB (persista peste moarte)
    if(PlayerData[playerid][pLogged])
        UpdatePlayer(playerid, pWanted);

    if(g_IsWorking[playerid])
    {
        Job_StopWork(playerid);
        SendClientMessage(playerid, COLOR_ERROR, C_ERROR"[Glovo] "C_WHITE"You died, so your work was stopped.");
    }

    // Drugs purtate se pierd la moarte; un transport in curs se anuleaza
    g_PlayerDrugs[playerid] = 0;
    if(g_DrugStage[playerid] != DRUG_STAGE_NONE)
        Drug_ResetTransport(playerid);

    // O ruta de autobuz in curs se anuleaza la moarte
    Bus_End(playerid);

    // Medical kit-urile si extinctoarele neaplicate din inventar se pierd la moarte
    if(PlayerData[playerid][pLogged] && (PlayerData[playerid][pMedkits] > 0 || PlayerData[playerid][pExtinguishers] > 0))
    {
        PlayerData[playerid][pMedkits]       = 0;
        PlayerData[playerid][pExtinguishers] = 0;
        UpdatePlayer(playerid, pMedkits);
        UpdatePlayer(playerid, pExtinguishers);
        SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You died, so you lost the medical kits and extinguishers in your inventory.");
    }
    return 1;
}

new Float:g_VendLastHealth[MAX_PLAYERS]; // viata cache-uita pentru anularea heal-ului de la automate

public OnPlayerUpdate(playerid)
{
    if(!PlayerData[playerid][pLogged]) return 1;

    // Dezactiveaza heal-ul de la automate (vending machines): detecteaza libraria de animatie "VENDING"
    // si readuce viata la valoarea de dinainte (animatia e lasata sa ruleze normal, nu mai e anulata).
    new alib[24], aname[24];
    GetAnimationName(GetPlayerAnimationIndex(playerid), alib, sizeof(alib), aname, sizeof(aname));
    if(strcmp(alib, "VENDING", true) == 0)
        SetPlayerHealth(playerid, g_VendLastHealth[playerid]);
    else
        GetPlayerHealth(playerid, g_VendLastHealth[playerid]);

    return 1;
}

public OnPlayerDisconnect(playerid, reason)
{
    // Daca era intr-un apel (ring sau activ), inchide-l si anunta interlocutorul
    if(g_PhoneCallPartner[playerid] != INVALID_PLAYER_ID)
    {
        new pp = g_PhoneCallPartner[playerid];
        new ppmsg[144];
        if(pp != INVALID_PLAYER_ID && IsPlayerConnected(pp))
        {
            new ppbrand[24];
            Phone_GetBrand(pp, ppbrand, sizeof(ppbrand));
            format(ppmsg, sizeof(ppmsg), C_INFO"[%s]: "C_WHITE"The call has ended (the other party disconnected).", ppbrand);
        }
        Phone_EndCall(playerid, "", ppmsg);
    }

    Bus_End(playerid); // anuleaza o ruta de autobuz in curs
    Farm_Cancel(playerid, false); // anuleaza lucrarea agricola in curs (curata vehiculul)
    Farm_RentCleanup(playerid);
    Farm_DeliverCleanup(playerid);

    // Race event: curata participantul care pleaca si verifica daca cursa se poate incheia
    if(g_RaceIn[playerid])
    {
        new bool:wasDone = g_RaceDone[playerid];
        Race_ClearPlayer(playerid); // seteaza g_RaceIn=false, distruge vehiculul
        if(g_RaceState == RACE_STATE_RUNNING)
        {
            if(!wasDone && g_RaceTotal > 0) g_RaceTotal--;
            if(g_RaceTotal <= 0 || g_RaceFinishOrder >= g_RaceTotal)
                Race_End(false);
        }
    }

    // Q&A: daca pleaca reporterul-host sau invitatul, inchide sesiunea; curata si invitatia in asteptare
    if(g_QAActive && (playerid == g_QAReporter || playerid == g_QAGuest))
    {
        QA_Broadcast("{85648C}[Q&A] "C_WHITE"The live Q&A has ended (a participant disconnected).");
        QA_Reset();
    }
    else if(playerid == g_QAPendingReporter || playerid == g_QAPendingGuest)
    {
        g_QAPendingReporter = INVALID_PLAYER_ID;
        g_QAPendingGuest    = INVALID_PLAYER_ID;
    }

    // Salveaza motorina daca era la volanul unui vehicul din DB (personal/factiune)
    new dcVeh = GetPlayerVehicleID(playerid);
    if(dcVeh != 0 && GetPlayerVehicleSeat(playerid) == 0)
        Vehicle_SaveFuel(dcVeh);

    Job_StopWork(playerid); // opreste munca + ucide timer-ul de revenire daca exista

    // Uber: curata daca era pasager intr-o cursa / asignat la un sofer
    if(g_UberDriver[playerid] != INVALID_PLAYER_ID)
    {
        new udriver = g_UberDriver[playerid];
        Uber_ClearAssignment(playerid);
        if(udriver != INVALID_PLAYER_ID && IsPlayerConnected(udriver))
            SendClientMessage(udriver, COLOR_INFO, C_INFO"[Uber] "C_WHITE"Your passenger disconnected. The ride has ended.");
    }
    g_UberWantsRide[playerid] = false;
    Uber_GoOffDuty(playerid); // daca era sofer la serviciu

    ExamA_KillTimer(playerid);
    g_ExamAState[playerid] = EXAMA_STATE_NONE;

    Exam_KillTimer(playerid);
    g_ExamState[playerid] = EXAM_STATE_NONE;

    ExamC_KillTimer(playerid);
    g_ExamCState[playerid] = EXAMC_STATE_NONE;

    ExamD_KillTimer(playerid);
    g_ExamDState[playerid] = EXAMD_STATE_NONE;

    FlightExam_KillTimer(playerid);
    g_FlightState[playerid]   = FLIGHT_STATE_NONE;
    g_FlightVehicle[playerid] = -1;

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

    // Bariera LSPD: facțiunea 1, aproape de barieră, apasă H (horn = KEY_CROUCH) -> deschide 5s
    if((newkeys & KEY_CROUCH) && !(oldkeys & KEY_CROUCH))
    {
        if(PlayerData[playerid][pLogged] && PlayerData[playerid][pFaction] == FACTION_POLICE && !g_LSPDBarrierOpen &&
           IsPlayerInRangeOfPoint(playerid, LSPD_BARRIER_RANGE, LSPD_BARRIER_X, LSPD_BARRIER_Y, LSPD_BARRIER_Z))
        {
            g_LSPDBarrierOpen = true;
            MoveDynamicObject(g_LSPDBarrier, LSPD_BARRIER_X, LSPD_BARRIER_Y, LSPD_BARRIER_Z, LSPD_BARRIER_SPEED, 0.0, 10.0, 90.0);
            if(g_LSPDBarrierTimer != -1) KillTimer(g_LSPDBarrierTimer);
            g_LSPDBarrierTimer = SetTimer("LSPDBarrier_Close", 5000, false);
        }
    }

    if((newkeys & KEY_SECONDARY_ATTACK) && !(oldkeys & KEY_SECONDARY_ATTACK))
    {
        if(PlayerData[playerid][pLogged] && PlayerData[playerid][pFaction] == FACTION_POLICE)
            Police_GarageEntranceToggle(playerid);

        if(PlayerData[playerid][pLogged] &&
           PlayerData[playerid][pFaction] >= 1 && PlayerData[playerid][pFaction] <= MAX_FACTIONS)
            Factions_InteriorToggle(playerid);

        if(PlayerData[playerid][pLogged])
            Cityhall_Toggle(playerid);
    }

    // Faruri: leagat de controlul KEY_ACTION. SA-MP nu poate citi NUMPAD 0 (VK 96) direct,
    // dar jucatorul poate seta NUMPAD 0 pe controlul corespunzator din setarile GTA SA ca sa-l foloseasca.
    if((newkeys & KEY_ACTION) && !(oldkeys & KEY_ACTION))
    {
        if(PlayerData[playerid][pLogged] && GetPlayerVehicleID(playerid) != 0 && GetPlayerVehicleSeat(playerid) == 0)
            Vehicle_ToggleLights(playerid);
    }

    // Capota pe KEY_ANALOG_UP, portbagajul pe KEY_ANALOG_DOWN (doar soferul)
    if((newkeys & KEY_ANALOG_UP) && !(oldkeys & KEY_ANALOG_UP))
    {
        if(PlayerData[playerid][pLogged] && GetPlayerVehicleID(playerid) != 0 && GetPlayerVehicleSeat(playerid) == 0)
            Vehicle_ToggleBonnet(playerid);
    }

    if((newkeys & KEY_ANALOG_DOWN) && !(oldkeys & KEY_ANALOG_DOWN))
    {
        if(PlayerData[playerid][pLogged] && GetPlayerVehicleID(playerid) != 0 && GetPlayerVehicleSeat(playerid) == 0)
            Vehicle_ToggleBoot(playerid);
    }

    if((newkeys & KEY_FIRE) && !(oldkeys & KEY_FIRE))
    {
        if(PlayerData[playerid][pLogged] && g_PartyHoldingDrink[playerid])
            Party_DrinkBeer(playerid);
    }
    return 1;
}

// Coordonatele unui item GPS (in functie de tip + referinta)
stock GPSItem_GetCoords(type, ref, &Float:x, &Float:y, &Float:z)
{
    switch(type)
    {
        case GPSITEM_FACTION: { x = FactionData[ref][fHQX]; y = FactionData[ref][fHQY]; z = FactionData[ref][fHQZ]; }
        case GPSITEM_BIZ:     { x = BusinessData[ref][bLocX]; y = BusinessData[ref][bLocY]; z = BusinessData[ref][bLocZ]; }
        case GPSITEM_ATM:     { x = ATMData[ref][atmX]; y = ATMData[ref][atmY]; z = ATMData[ref][atmZ]; }
        case GPSITEM_JOB:     { x = g_JobTeleport[ref][0]; y = g_JobTeleport[ref][1]; z = g_JobTeleport[ref][2]; }
        case GPSITEM_SHOP:    { x = ShopData[ref][shopX]; y = ShopData[ref][shopY]; z = ShopData[ref][shopZ]; }
        case GPSITEM_FASTFOOD:
        {
            if(ref >= MAX_FOOD_LOCATIONS) { new bi = ref - MAX_FOOD_LOCATIONS; x = BurgerLocations[bi][0]; y = BurgerLocations[bi][1]; z = BurgerLocations[bi][2]; }
            else                          { x = PizzaLocations[ref][0];  y = PizzaLocations[ref][1];  z = PizzaLocations[ref][2]; }
        }
        case GPSITEM_LOC:     { x = LocationData[ref][locX]; y = LocationData[ref][locY]; z = LocationData[ref][locZ]; }
        default:              { x = GPSData[ref][glLocX]; y = GPSData[ref][glLocY]; z = GPSData[ref][glLocZ]; }
    }
}

// Numele afisat al unui item GPS
stock GPSItem_GetName(type, ref, name[], len)
{
    switch(type)
    {
        case GPSITEM_FACTION: format(name, len, "%s", FactionData[ref][fName]);
        case GPSITEM_BIZ:     format(name, len, "%s", BusinessData[ref][bName]);
        case GPSITEM_ATM:     format(name, len, "ATM #%d", ATMData[ref][atmID]);
        case GPSITEM_JOB:     format(name, len, "%s", g_JobNames[ref]);
        case GPSITEM_SHOP:    format(name, len, "Shop #%d", ShopData[ref][shopID]);
        case GPSITEM_FASTFOOD:
        {
            if(ref >= MAX_FOOD_LOCATIONS) format(name, len, "%s", g_BurgerName[ref - MAX_FOOD_LOCATIONS]);
            else                          format(name, len, "%s", g_PizzaName[ref]);
        }
        case GPSITEM_LOC:     format(name, len, "%s", LocationData[ref][locName]);
        default:              format(name, len, "%s", GPSData[ref][glName]);
    }
}

// Adauga un item in lista GPS a playerului (calculeaza distanta)
stock GPSList_AddItem(playerid, type, ref)
{
    new n = g_GPSListCount[playerid];
    if(n >= MAX_GPS_LISTITEMS) return;

    new Float:x, Float:y, Float:z;
    GPSItem_GetCoords(type, ref, x, y, z);

    g_GPSItemType[playerid][n] = type;
    g_GPSItemRef[playerid][n]  = ref;
    g_GPSItemDist[playerid][n] = GetPlayerDistanceFromPoint(playerid, x, y, z);
    g_GPSListCount[playerid]   = n + 1;
}

// Sorteaza lista GPS crescator dupa distanta (bubble sort pe cele 3 array-uri paralele)
stock GPSList_Sort(playerid)
{
    new n = g_GPSListCount[playerid];
    for(new a = 0; a < n - 1; a++)
        for(new b = 0; b < n - 1 - a; b++)
            if(g_GPSItemDist[playerid][b] > g_GPSItemDist[playerid][b + 1])
            {
                new tt = g_GPSItemType[playerid][b]; g_GPSItemType[playerid][b] = g_GPSItemType[playerid][b + 1]; g_GPSItemType[playerid][b + 1] = tt;
                new tr = g_GPSItemRef[playerid][b];  g_GPSItemRef[playerid][b]  = g_GPSItemRef[playerid][b + 1];  g_GPSItemRef[playerid][b + 1]  = tr;
                new Float:td = g_GPSItemDist[playerid][b]; g_GPSItemDist[playerid][b] = g_GPSItemDist[playerid][b + 1]; g_GPSItemDist[playerid][b + 1] = td;
            }
}

// Construieste lista GPS pentru o categorie si o sorteaza crescator dupa distanta.
// cat: 0=Factions, 1=Businesses, 2=Banks & ATMs, 3=Shops, 4=FastFoods, 5+=dinamica (locations_admin, dupa dynCat)
stock GPSList_Build(playerid, cat, const dynCat[])
{
    g_GPSListCount[playerid] = 0;
    switch(cat)
    {
        case 0: // factiuni cu HQ setat (tabelul factions)
            for(new i = 1; i <= MAX_FACTIONS; i++)
                if(FactionData[i][fHQX] != 0.0 || FactionData[i][fHQY] != 0.0)
                    GPSList_AddItem(playerid, GPSITEM_FACTION, i);
        case 1: // business-uri (fara bancile 19/20)
            for(new i = 0; i < g_BusinessCount; i++)
                if(BusinessData[i][bID] != ATM_BANK_BIZ_A && BusinessData[i][bID] != ATM_BANK_BIZ_B)
                    GPSList_AddItem(playerid, GPSITEM_BIZ, i);
        case 2: // banci (business 19/20) + bancomate (tabelul atms)
        {
            for(new i = 0; i < g_BusinessCount; i++)
                if(BusinessData[i][bID] == ATM_BANK_BIZ_A || BusinessData[i][bID] == ATM_BANK_BIZ_B)
                    GPSList_AddItem(playerid, GPSITEM_BIZ, i);
            for(new i = 0; i < g_AtmCount; i++)
                GPSList_AddItem(playerid, GPSITEM_ATM, i);
        }
        case 3: // shop-uri (tabelul shops)
            for(new i = 0; i < g_ShopCount; i++)
                GPSList_AddItem(playerid, GPSITEM_SHOP, i);
        case 4: // fast-food (tabelul fastfood: pizza + burger)
        {
            for(new i = 0; i < MAX_FOOD_LOCATIONS; i++)
                if(PizzaLocations[i][0] != 0.0 || PizzaLocations[i][1] != 0.0)
                    GPSList_AddItem(playerid, GPSITEM_FASTFOOD, i);
            for(new i = 0; i < MAX_FOOD_LOCATIONS; i++)
                if(BurgerLocations[i][0] != 0.0 || BurgerLocations[i][1] != 0.0)
                    GPSList_AddItem(playerid, GPSITEM_FASTFOOD, MAX_FOOD_LOCATIONS + i);
        }
        default: // categorii dinamice din locations_admin (locForGPS=1, locCategory == dynCat)
            for(new i = 0; i < g_LocationCount; i++)
                if(LocationData[i][locForGPS] && strcmp(LocationData[i][locCategory], dynCat, true) == 0)
                    GPSList_AddItem(playerid, GPSITEM_LOC, i);
    }
    GPSList_Sort(playerid);
}

// Enumera categoriile dinamice distincte din locations_admin (randuri cu locForGPS=1 si locCategory nevida)
stock GPS_GetDynCategories(cats[][32], maxCats)
{
    new count = 0;
    for(new i = 0; i < g_LocationCount && count < maxCats; i++)
    {
        if(!LocationData[i][locForGPS]) continue;
        if(LocationData[i][locCategory][0] == EOS) continue;

        new bool:dup = false;
        for(new j = 0; j < count; j++)
            if(strcmp(cats[j], LocationData[i][locCategory], true) == 0) { dup = true; break; }
        if(dup) continue;

        format(cats[count], 32, "%s", LocationData[i][locCategory]);
        count++;
    }
    return count;
}

// Primul dialog: categoriile GPS cu numarul de locatii din fiecare (TABLIST_HEADERS)
stock GPS_ShowCategoryDialog(playerid)
{
    new dynCats[GPS_MAX_DYNCATS][32];
    new dynCount = GPS_GetDynCategories(dynCats, GPS_MAX_DYNCATS);

    new list[1536], line[80];
    list[0] = EOS;
    strcat(list, "Category\tLocations\n");

    GPSList_Build(playerid, 0, ""); format(line, sizeof(line), "Factions\t%d\n",     g_GPSListCount[playerid]); strcat(list, line);
    GPSList_Build(playerid, 1, ""); format(line, sizeof(line), "Businesses\t%d\n",   g_GPSListCount[playerid]); strcat(list, line);
    GPSList_Build(playerid, 2, ""); format(line, sizeof(line), "Banks & ATMs\t%d\n", g_GPSListCount[playerid]); strcat(list, line);
    GPSList_Build(playerid, 3, ""); format(line, sizeof(line), "Shops\t%d\n",        g_GPSListCount[playerid]); strcat(list, line);
    GPSList_Build(playerid, 4, ""); format(line, sizeof(line), "FastFoods\t%d\n",    g_GPSListCount[playerid]); strcat(list, line);

    for(new i = 0; i < dynCount; i++)
    {
        GPSList_Build(playerid, 5 + i, dynCats[i]);
        format(line, sizeof(line), "%s\t%d\n", dynCats[i], g_GPSListCount[playerid]);
        strcat(list, line);
    }

    ShowPlayerDialog(playerid, DIALOG_GPS_CATEGORY, DIALOG_STYLE_TABLIST_HEADERS, "GPS - Categories", list, "Select", "Cancel");
}

// Al doilea dialog: locatiile din categoria selectata, sortate dupa cea mai apropiata (TABLIST_HEADERS)
stock GPS_ShowLocationDialog(playerid)
{
    GPSList_Build(playerid, g_GPSDialogCategory[playerid], g_GPSDynCat[playerid]);

    new n = g_GPSListCount[playerid];
    if(n == 0)
    {
        SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"No locations are available in this category.");
        GPS_ShowCategoryDialog(playerid);
        return 1;
    }

    static list[8192];
    new line[80], nm[48];
    list[0] = EOS;
    strcat(list, "Location\tDistance\n");
    for(new i = 0; i < n; i++)
    {
        GPSItem_GetName(g_GPSItemType[playerid][i], g_GPSItemRef[playerid][i], nm, sizeof(nm));
        format(line, sizeof(line), "%s\t%dm\n", nm, floatround(g_GPSItemDist[playerid][i]));
        strcat(list, line);
    }

    ShowPlayerDialog(playerid, DIALOG_GPS_LOCATION, DIALOG_STYLE_TABLIST_HEADERS, "GPS - Locations", list, "Select", "Back");
    return 1;
}

public OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
    if(dialogid == DIALOG_REGISTER)
    {
        if(!response) return Kick(playerid), 1; // Quit/ESC -> deconectare
        if(strlen(inputtext) < 3)
        {
            ShowPlayerDialog(playerid, DIALOG_REGISTER, DIALOG_STYLE_PASSWORD, "Register",
                C_ERROR"Password too short (min 3 characters)."C_WHITE"\n\nEnter a password to create your account:", "Register", "Quit");
            return 1;
        }
        Player_Register(playerid, inputtext);
        return 1;
    }

    if(dialogid == DIALOG_LOGIN)
    {
        if(!response) return Kick(playerid), 1; // Quit/ESC -> deconectare
        if(strcmp(inputtext, PlayerData[playerid][pPass], false) != 0)
        {
            ShowPlayerDialog(playerid, DIALOG_LOGIN, DIALOG_STYLE_PASSWORD, "Login",
                C_ERROR"Incorrect password!"C_WHITE"\n\nEnter your password to log in:", "Login", "Quit");
            return 1;
        }
        Player_Login(playerid, inputtext);
        return 1;
    }

    if(dialogid == DIALOG_SHOP)
    {
        if(!response) return 1; // Inchide

        switch(listitem)
        {
            case 0: // Medical Kit -> intra in inventarul jucatorului
            {
                if(PlayerData[playerid][pMoney] < g_MedkitPrice)
                    return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have enough money for a medical kit."), 1;

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

                PlayerData[playerid][pMedkits]++;
                UpdatePlayer(playerid, pMedkits);

                new m[144];
                format(m, sizeof(m), C_SUCCESS"Success: "C_WHITE"You bought a medical kit for "C_INFO"$%s"C_WHITE" (you now have "C_INFO"%d"C_WHITE").",
                    MoneyStr(g_MedkitPrice), PlayerData[playerid][pMedkits]);
                SendClientMessage(playerid, COLOR_SUCCESS, m);
                SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Install it on your car with "C_INFO"/v install medicalkit"C_WHITE".");
            }
            case 1: // Extinctor -> intra in inventarul jucatorului
            {
                if(PlayerData[playerid][pMoney] < g_ExtinguisherPrice)
                    return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have enough money for an extinguisher."), 1;

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

                PlayerData[playerid][pExtinguishers]++;
                UpdatePlayer(playerid, pExtinguishers);

                new m[144];
                format(m, sizeof(m), C_SUCCESS"Success: "C_WHITE"You bought an extinguisher for "C_INFO"$%s"C_WHITE" (you now have "C_INFO"%d"C_WHITE").",
                    MoneyStr(g_ExtinguisherPrice), PlayerData[playerid][pExtinguishers]);
                SendClientMessage(playerid, COLOR_SUCCESS, m);
                SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Install it on your car with "C_INFO"/v install extinctor"C_WHITE".");
            }
            case 2: // Phone -> deschide dialogul cu telefoanele (SIM + marci)
                Phone_ShowBuyDialog(playerid);
        }
        return 1;
    }

    if(dialogid == DIALOG_PHONE_BUY)
    {
        if(!response) return 1; // Inapoi

        // listitem 0 = SIM, 1..PHONE_MODEL_COUNT = marcile de telefon
        if(listitem == 0)
        {
            if(!Phone_HasPhone(playerid))
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You need a phone before buying a SIM."), 1;
            if(PlayerData[playerid][pMoney] < PHONE_SIM_PRICE)
                return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have enough money for a SIM ("C_INFO"$250"C_WHITE")."), 1;

            Phone_RequestSim(playerid);
            SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Searching for an available phone number...");
            return 1;
        }

        new model = listitem - 1;
        if(model < 0 || model >= PHONE_MODEL_COUNT) return 1;

        new price = g_PhonePrices[model];
        if(PlayerData[playerid][pMoney] < price)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You don't have enough money for this phone."), 1;

        PlayerData[playerid][pMoney] -= price;
        GivePlayerMoney(playerid, -price);
        UpdatePlayer(playerid, pMoney);

        PlayerData[playerid][pPhoneModel] = model;
        UpdatePlayer(playerid, pPhoneModel);

        // 5% din pret merge in banca business-ului magazinului de telefoane
        new cut = floatround(price * PHONE_SHOP_BIZ_CUT_PCT / 100.0);
        if(cut > 0) Job_AddBizIncome(PHONE_SHOP_BIZ_ID, cut);

        new m[160];
        format(m, sizeof(m), C_SUCCESS"Success: "C_WHITE"You bought a "C_INFO"%s"C_WHITE" for "C_INFO"$%s"C_WHITE".",
            g_PhoneModels[model], MoneyStr(price));
        SendClientMessage(playerid, COLOR_SUCCESS, m);

        if(!Phone_HasSim(playerid))
            SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Choose the "C_INFO"SIM"C_WHITE" option in "C_INFO"/shop"C_WHITE" (Phone) to get a number.");
        return 1;
    }

    if(dialogid == DIALOG_BIZZLIST)
    {
        if(!response) return 1; // Close

        if(listitem < 0 || listitem >= g_BusinessCount) return 1;

        if(GetPlayerVehicleID(playerid) != 0)
            SetVehiclePos(GetPlayerVehicleID(playerid), BusinessData[listitem][bLocX], BusinessData[listitem][bLocY], BusinessData[listitem][bLocZ] + 0.1);
        else
            AC_SetPos(playerid, BusinessData[listitem][bLocX], BusinessData[listitem][bLocY], BusinessData[listitem][bLocZ] + 0.1);

        new bmsg[96];
        format(bmsg, sizeof(bmsg), C_SUCCESS"[ADM] Success: "C_WHITE"Teleported to business "C_INFO"%s"C_WHITE".", BusinessData[listitem][bName]);
        SendClientMessage(playerid, COLOR_SUCCESS, bmsg);
        return 1;
    }

    if(dialogid == DIALOG_FARMLIST)
    {
        if(!response) return 1; // Close

        if(listitem < 0 || listitem >= g_FarmCount) return 1;

        if(FarmData[listitem][fmRange] <= 0.0 && FarmData[listitem][fmX] == 0.0 && FarmData[listitem][fmY] == 0.0)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"This farm doesn't have a location set yet."), 1;

        if(GetPlayerVehicleID(playerid) != 0)
            SetVehiclePos(GetPlayerVehicleID(playerid), FarmData[listitem][fmX], FarmData[listitem][fmY], FarmData[listitem][fmZ] + 0.5);
        else
            AC_SetPos(playerid, FarmData[listitem][fmX], FarmData[listitem][fmY], FarmData[listitem][fmZ] + 0.5);

        new fmsg[96];
        format(fmsg, sizeof(fmsg), C_SUCCESS"[ADM] Success: "C_WHITE"Teleported to farm "C_INFO"#%d"C_WHITE".", FarmData[listitem][fmID]);
        SendClientMessage(playerid, COLOR_SUCCESS, fmsg);
        return 1;
    }

    if(dialogid == DIALOG_JOBLIST)
    {
        if(!response) return 1; // Close

        if(listitem < 0 || listitem >= MAX_JOBS) return 1;

        if(g_JobTeleport[listitem][0] == 0.0 && g_JobTeleport[listitem][1] == 0.0)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"This job doesn't have a location set yet."), 1;

        if(GetPlayerVehicleID(playerid) != 0)
            SetVehiclePos(GetPlayerVehicleID(playerid), g_JobTeleport[listitem][0], g_JobTeleport[listitem][1], g_JobTeleport[listitem][2] + 1.0);
        else
            AC_SetPos(playerid, g_JobTeleport[listitem][0], g_JobTeleport[listitem][1], g_JobTeleport[listitem][2] + 1.0);

        AC_SetInterior(playerid, 0);
        AC_SetVW(playerid, 0);

        new jmsg[96];
        format(jmsg, sizeof(jmsg), C_SUCCESS"[ADM] Success: "C_WHITE"Teleported to job "C_INFO"%s"C_WHITE".", g_JobNames[listitem]);
        SendClientMessage(playerid, COLOR_SUCCESS, jmsg);
        return 1;
    }

    if(dialogid == DIALOG_GPS_CATEGORY)
    {
        if(!response) return 1; // Cancel

        // Primele 5 randuri = categorii fixe; restul = categorii dinamice din locations_admin
        if(listitem < 5)
        {
            g_GPSDialogCategory[playerid] = listitem;
            g_GPSDynCat[playerid][0] = EOS;
        }
        else
        {
            new dynCats[GPS_MAX_DYNCATS][32];
            new dynCount = GPS_GetDynCategories(dynCats, GPS_MAX_DYNCATS);
            new di = listitem - 5;
            if(di < 0 || di >= dynCount) return 1;

            g_GPSDialogCategory[playerid] = 5;
            format(g_GPSDynCat[playerid], 32, "%s", dynCats[di]);
        }

        GPS_ShowLocationDialog(playerid);
        return 1;
    }

    if(dialogid == DIALOG_GPS_LOCATION)
    {
        if(!response) { GPS_ShowCategoryDialog(playerid); return 1; } // Back -> inapoi la categorii

        if(g_ExamAState[playerid] != EXAMA_STATE_NONE || g_ExamState[playerid] != EXAM_STATE_NONE ||
           g_ExamCState[playerid] != EXAMC_STATE_NONE || g_ExamDState[playerid] != EXAMD_STATE_NONE)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"You can't use GPS during an exam."), 1;

        // Lista a fost construita si sortata la afisare; listitem indexeaza direct lista pastrata
        if(listitem < 0 || listitem >= g_GPSListCount[playerid])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Unknown location."), 1;

        new Float:cx, Float:cy, Float:cz;
        GPSItem_GetCoords(g_GPSItemType[playerid][listitem], g_GPSItemRef[playerid][listitem], cx, cy, cz);
        SetPlayerCheckpoint(playerid, cx, cy, cz, GPS_CP_SIZE);
        g_GPSActive[playerid] = true;

        new nm[48], gmsg[128];
        GPSItem_GetName(g_GPSItemType[playerid][listitem], g_GPSItemRef[playerid][listitem], nm, sizeof(nm));
        format(gmsg, sizeof(gmsg), C_SUCCESS"Success: "C_WHITE"GPS checkpoint set to "C_INFO"%s"C_WHITE".", nm);
        SendClientMessage(playerid, COLOR_SUCCESS, gmsg);
        return 1;
    }

    if(dialogid == DIALOG_REPORTS_LIST)
    {
        if(!response) return 1; // Close
        if(PlayerData[playerid][pAdminLevel] < 1) return 1;
        if(listitem < 0 || listitem >= g_ReportDialogCount[playerid]) return 1;

        new repID = g_ReportDialogIds[playerid][listitem];
        new q[128];
        mysql_format(g_SQL, q, sizeof(q), "SELECT `playerName`,`repText` FROM `reports` WHERE `repID`=%d", repID);
        mysql_tquery(g_SQL, q, "OnReportView", "ii", playerid, repID);
        return 1;
    }

    if(dialogid == DIALOG_REPORTS_VIEW)
    {
        if(PlayerData[playerid][pAdminLevel] < 1) return 1;
        if(response) // Resolve -> sterge din DB
        {
            Report_Delete(g_ReportViewId[playerid]);
            new msg[96];
            format(msg, sizeof(msg), C_SUCCESS"Success: "C_WHITE"Report #%d resolved and deleted.", g_ReportViewId[playerid]);
            SendClientMessage(playerid, COLOR_SUCCESS, msg);
        }
        else Reports_ShowList(playerid); // Back -> inapoi la lista
        return 1;
    }

    if(dialogid == DIALOG_FASTFOOD_LIST)
    {
        if(!response) return 1; // Close

        new Float:fx, Float:fy, Float:fz, fType, ffid, fname[32];
        if(!FastFood_GetNth(listitem, ffid, fType, fx, fy, fz, fname, sizeof(fname)))
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Error: "C_WHITE"Invalid location."), 1;

        AC_SetInterior(playerid, 0);
        AC_SetVW(playerid, 0);
        AC_SetPos(playerid, fx, fy, fz + 0.5);

        new tmsg[128];
        format(tmsg, sizeof(tmsg), C_SUCCESS"[ADM] Success: "C_WHITE"Teleported to "C_INFO"%s"C_WHITE".", fname);
        SendClientMessage(playerid, COLOR_SUCCESS, tmsg);
        return 1;
    }

    return 0;
}

public OnPlayerExitVehicle(playerid, vehicleid)
{
    // Salveaza motorina la coborarea dintr-un vehicul din DB (personal/factiune)
    Vehicle_SaveFuel(vehicleid);
    return 1;
}

public OnPlayerEnterVehicle(playerid, vehicleid, ispassenger)
{
    // Sincronizeaza interiorul/VW-ul jucatorului cu al vehiculului INAINTE sa se aseze (jucatorul e inca
    // pe jos, deci apelurile nu-l mai ejecteaza). Repara cazul in care ramane blocat intr-un interior/VW
    // gresit (ex: spawn in LSPD interior 6, iesire gresita, teleport) si altfel ar aparea "pe" vehicul.
    if(vehicleid > 0)
    {
        new vw = GetVehicleVirtualWorld(vehicleid);
        if(GetPlayerVirtualWorld(playerid) != vw) AC_SetVW(playerid, vw);
        if(GetPlayerInterior(playerid) != 0) AC_SetInterior(playerid, 0);
    }
    return 1;
}

public OnPlayerStateChange(playerid, newstate, oldstate)
{
    if(newstate == PLAYER_STATE_DRIVER && GetPlayerVehicleID(playerid) == g_TrainID)
        RemovePlayerFromVehicle(playerid);

    // Farm: daca ai coborat din utilaj in timpul lucrarii, s-a terminat treaba (pierzi munca de azi)
    if(g_FarmWorking[playerid] != 0 && oldstate == PLAYER_STATE_DRIVER && newstate != PLAYER_STATE_DRIVER)
        Farm_Cancel(playerid, true);

    // Farm: cobori din utilajul inchiriat -> se distruge
    if(g_FarmRentVeh[playerid] != 0 && oldstate == PLAYER_STATE_DRIVER && newstate != PLAYER_STATE_DRIVER)
        Farm_RentCleanup(playerid);

    // Glovo: daca lucratorul nu mai e in masina de lucru, porneste ragazul de revenire (30s)
    Job_HandleStateChange(playerid);

    // Uber: pasagerul s-a urcat ca pasager in masina soferului asignat -> incepe cursa
    if(newstate == PLAYER_STATE_PASSENGER && g_UberDriver[playerid] != INVALID_PLAYER_ID && !g_UberRideActive[playerid])
    {
        new udriver = g_UberDriver[playerid];
        if(IsPlayerConnected(udriver) && GetPlayerVehicleID(playerid) == g_UberVehicle[udriver])
        {
            g_UberRideActive[playerid] = true;
            DisablePlayerCheckpoint(udriver);
            g_UberChargeTimer[playerid] = SetTimerEx("Uber_Charge", UBER_CHARGE_INTERVAL * 1000, true, "i", playerid);

            new sumsg[144];
            format(sumsg, sizeof(sumsg), C_SUCCESS"[Uber] "C_WHITE"Ride started. You'll be charged "C_INFO"$%s"C_WHITE" now and every "#UBER_CHARGE_INTERVAL"s until you get out.", MoneyStr(g_UberFare[udriver]));
            SendClientMessage(playerid, COLOR_SUCCESS, sumsg);
            SendClientMessage(udriver, COLOR_SUCCESS, C_SUCCESS"[Uber] "C_WHITE"Your passenger got in. The meter is running.");

            Uber_Charge(playerid); // prima taxare are loc imediat la urcare
        }
    }

    // Uber: pasagerul a coborat in timpul cursei -> incheie cursa
    if(oldstate == PLAYER_STATE_PASSENGER && newstate != PLAYER_STATE_PASSENGER && g_UberRideActive[playerid])
    {
        new udriver = g_UberDriver[playerid];
        Uber_ClearAssignment(playerid);
        SendClientMessage(playerid, COLOR_INFO, C_INFO"[Uber] "C_WHITE"You got out. The ride has ended.");
        if(udriver != INVALID_PLAYER_ID && IsPlayerConnected(udriver))
            SendClientMessage(udriver, COLOR_INFO, C_INFO"[Uber] "C_WHITE"Your passenger got out. The ride has ended.");
    }

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

    // A iesit din aeronava in timpul examenului de zbor -> pica si aeronava respawneaza
    if(oldstate == PLAYER_STATE_DRIVER && newstate != PLAYER_STATE_DRIVER && g_FlightState[playerid] == FLIGHT_STATE_FLYING)
        FlightExam_Fail(playerid, "You got out of the aircraft.");

    // Bus Driver: a iesit de la volanul autobuzului in timpul rutei -> ruta se anuleaza
    if(oldstate == PLAYER_STATE_DRIVER && newstate != PLAYER_STATE_DRIVER && g_BusLine[playerid] > 0)
    {
        Bus_End(playerid);
        SendClientMessage(playerid, COLOR_ERROR, C_ERROR"[Bus] "C_WHITE"You left the bus, so your route was cancelled.");
    }

    // Bus Driver: un pasager s-a urcat intr-un autobuz de job -> i se ia automat biletul
    if(newstate == PLAYER_STATE_PASSENGER)
        Bus_PayFare(playerid);

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
                new fcCode[9], fvmsg[144];
                GetFactionColorCode(fid, fcCode, sizeof(fcCode));
                format(fvmsg, sizeof(fvmsg), C_ERROR"Error: "C_WHITE"This vehicle belongs to %s%s"C_WHITE". You cannot drive it.",
                    fcCode, FactionData[fid][fName]);
                SendClientMessage(playerid, COLOR_ERROR, fvmsg);
            }

            // Vehiculele de job pot fi conduse doar de cei care au jobul corespunzator
            new reqJobVeh = Job_VehicleRequiredJob(vehid);
            if(reqJobVeh != 0 && PlayerData[playerid][pJob] != reqJobVeh)
            {
                RemovePlayerFromVehicle(playerid);
                SendClientMessage(playerid, COLOR_ERROR,
                    C_ERROR"Error: "C_WHITE"This is a job vehicle. Only workers of that job can drive it.");
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

            new airCat = GetAircraftLicenseCategory(GetVehicleModel(vehid));
            if(airCat != AIR_LIC_NONE && !IsExamPCarVehicle(vehid) && !IsExamHCarVehicle(vehid))
            {
                // Avioane/elicoptere: necesita permisul de avion corespunzator, nu permisul auto
                if(!Player_HasValidAirLicense(playerid, airCat))
                {
                    RemovePlayerFromVehicle(playerid);

                    new acatName[24], amsg[144];
                    GetAirLicenseCategoryName(airCat, acatName, sizeof(acatName));
                    format(amsg, sizeof(amsg),
                        C_ERROR"Error: "C_WHITE"You need a valid Airplane license "C_INFO"%s"C_WHITE" to fly this.",
                        acatName);
                    SendClientMessage(playerid, COLOR_ERROR, amsg);
                }
            }
            else if(!IsExamACarVehicle(vehid) && !IsExamBCarVehicle(vehid) && !IsExamCTruckVehicle(vehid) && !IsExamDCarVehicle(vehid) && !IsRentCarVehicle(vehid))
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

            if(IsRentCarVehicle(vehid))
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

            if(IsExamPCarVehicle(vehid) || IsExamHCarVehicle(vehid))
            {
                new fcat = IsExamHCarVehicle(vehid) ? FLIGHT_CAT_H : FLIGHT_CAT_P;
                new examUser = FlightExam_GetCarUser(vehid);
                if(examUser != -1 && examUser != playerid)
                {
                    RemovePlayerFromVehicle(playerid);
                    SendClientMessage(playerid, COLOR_ERROR,
                        C_ERROR"Error: "C_WHITE"This aircraft is being used for an exam.");
                }
                else if(g_FlightState[playerid] != FLIGHT_STATE_WAITING || g_FlightCat[playerid] != fcat)
                {
                    RemovePlayerFromVehicle(playerid);
                    SendClientMessage(playerid, COLOR_ERROR,
                        C_ERROR"Error: "C_WHITE"You must use "C_INFO"/examP"C_WHITE" or "C_INFO"/examH"C_WHITE" to use this aircraft.");
                }
                else
                {
                    FlightExam_KillTimer(playerid);
                    g_FlightState[playerid]      = FLIGHT_STATE_FLYING;
                    g_FlightVehicle[playerid]    = vehid;
                    g_FlightCheckpoint[playerid] = 0;
                    FlightExam_GotoCheckpoint(playerid, 0);
                    Vehicle_SetLocked(vehid, true); g_GPSActive[playerid] = false;

                    SendClientMessage(playerid, COLOR_INFO,
                        C_INFO"Info: "C_WHITE"The flight exam has started! Fly through the checkpoints. "C_INFO"60 seconds"C_WHITE" per checkpoint.");
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

        // Vehiculele din DB (personal/factiune) isi pastreaza motorina salvata; restul primesc 50% la respawn
        if(pvidx == -1 && VFaction_FindByVehicle(vehicleid) == -1)
            g_VehicleFuel[vehicleid] = 50.0;
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
