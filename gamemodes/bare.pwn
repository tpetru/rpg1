#include <a_samp>
#include <core>
#include <float>
#include <a_mysql>
#include <streamer>

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
forward OnVehiclesFactionLoaded();
forward OnVehicleFactionCreated(playerid, idx);
forward Fires_Tick();
forward OnVehiclesPersonalLoaded();
forward OnVehiclePersonalCreated(playerid, idx);

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

// ============================================================
//  DATE JUCATOR
// ============================================================
enum E_PLAYER_DATA
{
    pID, pName[24], pPass[64], pEmail[64],
    pLevel, pMoney, pBank, pRP, pAdminLevel, pFaction, pFactionRank, pHouse,
    pSpawn, Float:pSpawnX, Float:pSpawnY, Float:pSpawnZ,
    pKey1, pKey2, pKey3,
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

// Returneaza {RRGGBB} pentru culoarea factiunii
stock GetFactionColorCode(fid, out[], len)
{
    if(fid < 0 || fid > MAX_FACTIONS) { out[0] = EOS; return; }
    format(out, len, "{%06x}", (FactionColors[fid] >> 8) & 0xFFFFFF);
}

new g_TrainID = -1;
new g_FactionPickup[MAX_FACTIONS + 1] = {-1, -1, -1, -1, -1, -1, -1, -1};
new Text3D:g_FactionLabel[MAX_FACTIONS + 1];

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
        HouseData[idx][hLocX], HouseData[idx][hLocY], HouseData[idx][hLocZ]-1, -1);

    if(g_HouseLabel[idx] != Text3D:INVALID_3DTEXT_ID)
    {
        Delete3DTextLabel(g_HouseLabel[idx]);
        g_HouseLabel[idx] = Text3D:INVALID_3DTEXT_ID;
    }

    new label[256];
    if(HouseData[idx][hOwned])
    {
        format(label, sizeof(label),
            "[ House #%d ]\nName: %s\nOwner: Da\nOwner: %s\nPrice: $%d",
            HouseData[idx][hID], HouseData[idx][hName], HouseData[idx][hOwner], HouseData[idx][hPrice]);
    }
    else
    {
        format(label, sizeof(label),
            "[ House #%d ]\nName: %s\nOwner: Nu\nOwner: -\nPrice: $%d\n\n/buyhouse to buy this house",
            HouseData[idx][hID], HouseData[idx][hName], HouseData[idx][hPrice]);
    }
    g_HouseLabel[idx] = Create3DTextLabel(label, COLOR_WHITE,
        HouseData[idx][hLocX], HouseData[idx][hLocY], HouseData[idx][hLocZ]+0.5, 15.0, 0, 0);
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

stock VehiclesFaction_Create(idx)
{
    if(g_VFactionVehicle[idx] != -1)
    {
        DestroyVehicle(g_VFactionVehicle[idx]);
        g_VFactionVehicle[idx] = -1;
    }

    new vehid = CreateVehicle(VFactionData[idx][vfModelID],
        VFactionData[idx][vfLocX], VFactionData[idx][vfLocY], VFactionData[idx][vfLocZ],
        VFactionData[idx][vfRotation], VFactionData[idx][vfColor1], VFactionData[idx][vfColor2], -1, false);

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
#define FIRE_ICON_SLOT_BASE     50
#define FIRE_EXTINGUISH_RANGE   25.0
#define DUTY_HQ_RANGE           15.0
#define FACTION_SMURD           3

#define FIRE_VISUAL_REFRESH      3 // recreeaza explozia (vizual) o data la 3 secunde, nu in fiecare tick, ca sa nu se suprapuna si sa para mai mare

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
    format(msg, sizeof(msg), "[SMURD] "C_WHITE"Pompierul %s%s "C_WHITE"a stins incendiul.",
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
                GameTextForPlayer(i, "Stinge focul", 3000, 3);
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
//  VEHICULE PERSONALE
// ============================================================
#define MAX_PERSONAL_VEHICLES   200
#define MAX_PLAYER_VEHICLES     3
#define VEHICLE_DOC_DURATION    604800 // 7 zile, in secunde

enum E_PVEHICLE_DATA
{
    pvID, pvOwnerId, pvModelID,
    pvColor1, pvColor2, pvPlate[8], pvPrice,
    Float:pvLocX, Float:pvLocY, Float:pvLocZ, Float:pvRotation,
    pvInsuranceExp, pvMedkitExp, pvExtinguisherExp
}
new PVehicleData[MAX_PERSONAL_VEHICLES][E_PVEHICLE_DATA];
new g_PVehicleVehicle[MAX_PERSONAL_VEHICLES];
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
}

// Returneaza indexul (in PVehicleData) al vehiculului cu pvID == vid, sau -1
stock PVehicles_FindByVID(vid)
{
    for(new i = 0; i < g_PVehicleCount; i++)
        if(PVehicleData[i][pvID] == vid) return i;
    return -1;
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
        `house`       INT DEFAULT 999,\
        `spawn_type`  INT DEFAULT 1,\
        `key1`        INT DEFAULT 0,\
        `key2`        INT DEFAULT 0,\
        `key3`        INT DEFAULT 0\
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
        "ALTER TABLE `players` ADD COLUMN `house` INT DEFAULT 999",
        "", "", 0);
    mysql_tquery(g_SQL,
        "ALTER TABLE `players` ADD COLUMN `spawn_type` INT DEFAULT 1",
        "", "", 0);
    mysql_tquery(g_SQL, "ALTER TABLE `players` ADD COLUMN `key1` INT DEFAULT 0", "", "", 0);
    mysql_tquery(g_SQL, "ALTER TABLE `players` ADD COLUMN `key2` INT DEFAULT 0", "", "", 0);
    mysql_tquery(g_SQL, "ALTER TABLE `players` ADD COLUMN `key3` INT DEFAULT 0", "", "", 0);

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
        `extinguisher_price` INT  DEFAULT 500\
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;",
        "", "", 0);

    mysql_tquery(g_SQL, "ALTER TABLE `payday_setup` ADD COLUMN `insurance_price`    INT DEFAULT 500", "", "", 0);
    mysql_tquery(g_SQL, "ALTER TABLE `payday_setup` ADD COLUMN `medkit_price`       INT DEFAULT 500", "", "", 0);
    mysql_tquery(g_SQL, "ALTER TABLE `payday_setup` ADD COLUMN `extinguisher_price` INT DEFAULT 500", "", "", 0);

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
        `plate`            VARCHAR(8) DEFAULT 'NoRP',\
        `price`            INT DEFAULT 0,\
        `loc_x`            FLOAT DEFAULT 0.0,\
        `loc_y`            FLOAT DEFAULT 0.0,\
        `loc_z`            FLOAT DEFAULT 0.0,\
        `rotation`         FLOAT DEFAULT 0.0,\
        `insurance_exp`    INT DEFAULT 0,\
        `medkit_exp`       INT DEFAULT 0,\
        `extinguisher_exp` INT DEFAULT 0\
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;",
        "", "", 0);

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
    format(msg, sizeof(msg), C_SUCCESS"Succes: "C_WHITE"Casa \""C_INFO"%s"C_WHITE"\" creata (ID: "C_INFO"%d"C_WHITE").",
        HouseData[idx][hName], HouseData[idx][hID]);
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
        C_SUCCESS"Succes: "C_WHITE"Vehicul de factiune creat (ID: "C_INFO"%d"C_WHITE", Factiune: "C_INFO"%d"C_WHITE").",
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
         `insurance_exp`,`medkit_exp`,`extinguisher_exp` FROM `vehicles_personal` ORDER BY `id` ASC",
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
        cache_get_value_name      (i, "plate",             PVehicleData[idx][pvPlate], 8);
        cache_get_value_name_int  (i, "price",             PVehicleData[idx][pvPrice]);
        cache_get_value_name_float(i, "loc_x",             PVehicleData[idx][pvLocX]);
        cache_get_value_name_float(i, "loc_y",              PVehicleData[idx][pvLocY]);
        cache_get_value_name_float(i, "loc_z",              PVehicleData[idx][pvLocZ]);
        cache_get_value_name_float(i, "rotation",           PVehicleData[idx][pvRotation]);
        cache_get_value_name_int  (i, "insurance_exp",      PVehicleData[idx][pvInsuranceExp]);
        cache_get_value_name_int  (i, "medkit_exp",         PVehicleData[idx][pvMedkitExp]);
        cache_get_value_name_int  (i, "extinguisher_exp",   PVehicleData[idx][pvExtinguisherExp]);
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
    PVehicles_Create(idx);
    new msg[128];
    format(msg, sizeof(msg),
        C_SUCCESS"Succes: "C_WHITE"Vehicul personal creat (ID: "C_INFO"%d"C_WHITE", Pret: "C_INFO"$%d"C_WHITE").",
        PVehicleData[idx][pvID], PVehicleData[idx][pvPrice]);
    SendClientMessage(playerid, COLOR_SUCCESS, msg);
    return 1;
}

// ============================================================
//  PAYDAY
// ============================================================
stock PayDay_Load()
{
    mysql_tquery(g_SQL,
        "SELECT `min_salary`,`tax`,`cass`,`bank_interest`,`insurance_price`,`medkit_price`,`extinguisher_price` \
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
    }
    printf("[PayDay] Setari: Salar minim $%d | Impozit %d%% | CASS %d%% | Dobanda %.2f%%",
        g_PDMinSalary, g_PDTax, g_PDCASS, g_PDInterest);
    printf("[VehiculePersonale] Asigurare $%d | Kit medical $%d | Extinctor $%d",
        g_InsurancePrice, g_MedkitPrice, g_ExtinguisherPrice);
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
            C_WHITE"  Brut: "C_SUCCESS"$%d"C_WHITE"  Impozit: "C_ERROR"-$%d"C_WHITE"  CASS: "C_ERROR"-$%d"C_WHITE"  Net: "C_SUCCESS"$%d",
            salary, tax, cass, net);
        SendClientMessage(i, COLOR_WHITE, msg);
        format(msg, sizeof(msg),
            C_WHITE"  Dobanda banca: "C_SUCCESS"+$%d"C_WHITE"  RP: "C_SUCCESS"+1",
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
            C_INFO"Info: "C_WHITE"Cont gasit. Foloseste "C_INFO"/login [parola]"C_WHITE" pentru a te loga.");
    }
    else
    {
        PlayerData[playerid][pRegistered] = false;
        SendClientMessage(playerid, COLOR_INFO,
            C_INFO"Info: "C_WHITE"Nu esti inregistrat. Foloseste "C_INFO"/register [parola]"C_WHITE".");
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
    PlayerData[playerid][pHouse]      = 999;
    PlayerData[playerid][pSpawn]      = 1;
    PlayerData[playerid][pOnDuty]     = false;
    PlayerData[playerid][pKey1]       = 0;
    PlayerData[playerid][pKey2]       = 0;
    PlayerData[playerid][pKey3]       = 0;
    Player_RecalcSpawn(playerid);

    SetPlayerVirtualWorld(playerid, 0);
    SetPlayerMapIcon(playerid, 0, 2859.2053, 1290.6671, 11.3906, 35, 0, MAPICON_LOCAL);
    SetPlayerColor(playerid, FactionColors[FACTION_NONE]);
    Factions_SetPlayerIcons(playerid);

    SendClientMessage(playerid, COLOR_SUCCESS,
        C_SUCCESS"Succes: "C_WHITE"Inregistrare reusita! Esti acum logat.");
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
            C_ERROR"Eroare: "C_WHITE"Parola incorecta!");
        return;
    }

    new query[256];
    mysql_format(g_SQL, query, sizeof(query),
        "SELECT `id`,`password`,`email`,`level`,`money`,`bank`,`rp`,`admin_level`,`faction`,`faction_rank`,`house`,`spawn_type`,`key1`,`key2`,`key3` \
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
    cache_get_value_name_int(0, "house",       PlayerData[playerid][pHouse]);
    cache_get_value_name_int(0, "spawn_type",  PlayerData[playerid][pSpawn]);
    cache_get_value_name_int(0, "key1",        PlayerData[playerid][pKey1]);
    cache_get_value_name_int(0, "key2",        PlayerData[playerid][pKey2]);
    cache_get_value_name_int(0, "key3",        PlayerData[playerid][pKey3]);

    PlayerData[playerid][pLogged]  = true;
    PlayerData[playerid][pOnDuty]  = false;
    Player_RecalcSpawn(playerid);

    SetPlayerVirtualWorld(playerid, 0);
    SetPlayerColor(playerid, FactionColors[PlayerData[playerid][pFaction]]);
    Factions_SetPlayerIcons(playerid);

    GivePlayerMoney(playerid, PlayerData[playerid][pMoney]);
    SetPlayerScore(playerid, PlayerData[playerid][pLevel]);

    SendClientMessage(playerid, COLOR_SUCCESS,
        C_SUCCESS"Succes: "C_WHITE"Te-ai logat cu succes!");
    SpawnPlayer(playerid);
    return 1;
}

// ============================================================
//  SALVARE DATE JUCATOR
// ============================================================
stock FullUpdatePlayer(playerid)
{
    if(!PlayerData[playerid][pLogged]) return;

    new query[512];
    mysql_format(g_SQL, query, sizeof(query),
        "UPDATE `players` SET \
        `password`='%e', `level`=%d, `money`=%d, `bank`=%d, \
        `rp`=%d, `admin_level`=%d, `faction`=%d, `faction_rank`=%d, `house`=%d, `spawn_type`=%d, \
        `key1`=%d, `key2`=%d, `key3`=%d \
        WHERE `id`=%d",
        PlayerData[playerid][pPass],
        PlayerData[playerid][pLevel],
        PlayerData[playerid][pMoney],
        PlayerData[playerid][pBank],
        PlayerData[playerid][pRP],
        PlayerData[playerid][pAdminLevel],
        PlayerData[playerid][pFaction],
        PlayerData[playerid][pFactionRank],
        PlayerData[playerid][pHouse],
        PlayerData[playerid][pSpawn],
        PlayerData[playerid][pKey1],
        PlayerData[playerid][pKey2],
        PlayerData[playerid][pKey3],
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

        case pHouse:
            mysql_format(g_SQL, query, sizeof(query),
                "UPDATE `players` SET `house`=%d WHERE `id`=%d",
                PlayerData[playerid][pHouse], PlayerData[playerid][pID]);

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

        default: return;
    }
    mysql_tquery(g_SQL, query, "", "", 0);
}

// ============================================================
//  VEHICULE - CAUTARE DUPA NUME
// ============================================================
stock GetVehicleModelByName(const name[])
{
    static const VehNames[212][24] = {
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

    for(new i = 0; i < sizeof(VehNames); i++)
    {
        if(strfind(VehNames[i], name, true) != -1)
            return i + 400;
    }
    return -1;
}

// ============================================================
//  GAMEMODE
// ============================================================
main()
{
    print("\n----------------------------------");
    print("  Bare Script by Nikolas Maduro\n");
    print("----------------------------------\n");
}

public OnGameModeInit()
{
    SetGameModeText("Old is Gold");
    ShowPlayerMarkers(1);
    ShowNameTags(1);
    AllowAdminTeleport(1);

    AddPlayerClass(294, 2859.2053, 1290.6671, 11.3906, 88.9431, 0, 0, 0, 0, 0, 0);

    AddStaticVehicle(559, 2794.7180, 1295.5698, 10.3750, 180.9595, 3, 8);
    AddStaticVehicle(565, 2791.6089, 1295.4680, 10.3748, 179.1351, 6, 8);
    AddStaticVehicle(541, 2785.1243, 1295.4415, 10.3750, 178.1488, 8, 8);

    g_TrainID = AddStaticVehicle(538, 2864.7500, 1329.6376, 12.1256, 0.0009,0, 0); // tren

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

    for(new i = 0; i < MAX_VFACTION_VEHICLES; i++) g_VFactionVehicle[i] = -1;
    for(new i = 0; i < MAX_VEHICLES; i++) g_VehicleFactionOwner[i] = 0;
    for(new i = 0; i < MAX_FIRES; i++) FireData[i][fireActive] = false;
    for(new i = 0; i < MAX_PERSONAL_VEHICLES; i++) g_PVehicleVehicle[i] = -1;
    for(new i = 0; i < MAX_VEHICLES; i++) g_VehicleToPVIndex[i] = -1;

    DB_Init();
    Factions_Load();
    Houses_Load();
    VehiclesFaction_Load();
    PVehicles_Load();
    PayDay_Load();

    SetTimer("PayDay_Check", 60000, true);
    SetTimer("Fires_Tick", 1000, true);

    return 1;
}

public OnGameModeExit()
{
    mysql_close(g_SQL);
    return 1;
}

public OnPlayerConnect(playerid)
{
    PlayerData[playerid][pID]         = 0;
    PlayerData[playerid][pLevel]      = 1;
    PlayerData[playerid][pMoney]      = 0;
    PlayerData[playerid][pBank]       = 0;
    PlayerData[playerid][pRP]         = 0;
    PlayerData[playerid][pAdminLevel] = 0;
    PlayerData[playerid][pFaction]    = 0;
    PlayerData[playerid][pFactionRank]= 1;
    PlayerData[playerid][pHouse]      = 999;
    PlayerData[playerid][pSpawn]      = 1;
    PlayerData[playerid][pSpawnX]     = 2859.2053;
    PlayerData[playerid][pSpawnY]     = 1290.6671;
    PlayerData[playerid][pSpawnZ]     = 11.3906;
    PlayerData[playerid][pKey1]       = 0;
    PlayerData[playerid][pKey2]       = 0;
    PlayerData[playerid][pKey3]       = 0;
    PlayerData[playerid][pLogged]     = false;
    PlayerData[playerid][pRegistered] = false;
    PlayerData[playerid][pOnDuty]     = false;
    PlayerData[playerid][pPass][0]    = EOS;
    PlayerData[playerid][pEmail][0]   = EOS;

    GetPlayerName(playerid, PlayerData[playerid][pName], 24);
    SetPlayerVirtualWorld(playerid, -1);

    GameTextForPlayer(playerid, "~g~Welcome to\n~y~Old is Gold", 5000, 5);

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
                C_ERROR"Eroare: "C_WHITE"Esti deja inregistrat."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new pass[64];
        strmid(pass, cmdtext, idx, strlen(cmdtext), 64);

        if(!strlen(pass))
            return SendClientMessage(playerid, COLOR_INFO,
                C_INFO"Info: "C_WHITE"Foloseste "C_INFO"/register [parola]"C_WHITE"."), 1;

        Player_Register(playerid, pass);
        return 1;
    }

    // ---- /login [parola] ----
    if(strcmp(cmd, "/login", true) == 0)
    {
        if(!PlayerData[playerid][pRegistered])
            return SendClientMessage(playerid, COLOR_ERROR,
                C_ERROR"Eroare: "C_WHITE"Nu esti inregistrat. Foloseste "C_INFO"/register [parola]"C_WHITE"."), 1;

        if(PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR,
                C_ERROR"Eroare: "C_WHITE"Esti deja logat."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new pass[64];
        strmid(pass, cmdtext, idx, strlen(cmdtext), 64);

        if(!strlen(pass))
            return SendClientMessage(playerid, COLOR_INFO,
                C_INFO"Info: "C_WHITE"Foloseste "C_INFO"/login [parola]"C_WHITE"."), 1;

        Player_Login(playerid, pass);
        return 1;
    }

    // ---- /stats ----
    if(strcmp(cmd, "/stats", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR,
                C_ERROR"Eroare: "C_WHITE"Trebuie sa fii logat pentru a vedea statisticile."), 1;

        new line[128];
        new email[64] = "nesetat";
        if(strlen(PlayerData[playerid][pEmail]))
            format(email, sizeof(email), "%s", PlayerData[playerid][pEmail]);

        new fid = PlayerData[playerid][pFaction];
        new colorcode[9], fname[32];
        if(fid > 0 && fid <= MAX_FACTIONS)
        {
            GetFactionColorCode(fid, colorcode, sizeof(colorcode));
            format(fname, sizeof(fname), "%s%s (%d)", colorcode, FactionData[fid][fName], PlayerData[playerid][pFactionRank]);
        }
        else fname = "Nicio factiune";

        SendClientMessage(playerid, COLOR_INFO, "\n\n__ Statistici ________________________________________________");
        format(line, sizeof(line), "[Cont] Nume: %s | Email: %s | Level: %d | RP: %d | Factiune: %s",
            PlayerData[playerid][pName],
            email,
            PlayerData[playerid][pLevel],
            PlayerData[playerid][pRP],
            fname
        );
        SendClientMessage(playerid, COLOR_WHITE, line);

        format(line, sizeof(line), "[Finante] Cash: $%d | Banca: $%d | Casa: %d",
            PlayerData[playerid][pMoney],
            PlayerData[playerid][pBank],
            PlayerData[playerid][pHouse]);
        SendClientMessage(playerid, COLOR_WHITE, line);

        format(line, sizeof(line), "[Vehicule] pKey1: %d | pKey2: %d | pKey3: %d",
            PlayerData[playerid][pKey1],
            PlayerData[playerid][pKey2],
            PlayerData[playerid][pKey3]);
        SendClientMessage(playerid, COLOR_WHITE, line);

        if(PlayerData[playerid][pAdminLevel] > 0)
        {
            format(line, sizeof(line), "Nivel admin: %d",
                PlayerData[playerid][pAdminLevel]);
            SendClientMessage(playerid, COLOR_WHITE, line);
        }

        SendClientMessage(playerid, COLOR_INFO, "___________________________________________________________");
        return 1;
    }

    // ---- /veh [nume] ----
    if(strcmp(cmd, "/veh", true) == 0)
    {
        if(PlayerData[playerid][pAdminLevel] < 3)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Eroare: "C_WHITE"Nu ai acces. Necesita admin nivel 3."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new vehname[64];
        strmid(vehname, cmdtext, idx, strlen(cmdtext), 32);

        if(!strlen(vehname))
            return SendClientMessage(playerid, COLOR_INFO,
                C_INFO"Info: "C_WHITE"Foloseste "C_INFO"/veh [nume vehicul]"C_WHITE". Ex: "C_INFO"/veh Infernus"C_WHITE"."), 1;

        new model = GetVehicleModelByName(vehname);
        if(model == -1)
        {
            new errmsg[128];
            format(errmsg, sizeof(errmsg), C_ERROR"Eroare: "C_WHITE"Vehiculul \""C_INFO"%s"C_WHITE"\" nu a fost gasit.", vehname);
            return SendClientMessage(playerid, COLOR_ERROR, errmsg), 1;
        }

        new Float:x, Float:y, Float:z, Float:angle;
        GetPlayerPos(playerid, x, y, z);
        GetPlayerFacingAngle(playerid, angle);

        new vehid = CreateVehicle(model, x + 3.0, y, z, angle, -1, -1, -1);
        PutPlayerInVehicle(playerid, vehid, 0);

        new msg[128];
        format(msg, sizeof(msg), C_SUCCESS"Succes: "C_WHITE"Ai spawnat un "C_INFO"%s"C_WHITE" (model %d).", vehname, model);
        SendClientMessage(playerid, COLOR_SUCCESS, msg);
        return 1;
    }

    // ---- /rac (respawn all cars) ----
    if(strcmp(cmd, "/rac", true) == 0)
    {
        if(PlayerData[playerid][pAdminLevel] < 3)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Eroare: "C_WHITE"Nu ai acces. Necesita admin nivel 3."), 1;

        for(new i = 1; i < MAX_VEHICLES; i++)
            SetVehicleToRespawn(i);

        SendClientMessage(playerid, COLOR_SUCCESS,
            C_SUCCESS"Succes: "C_WHITE"Toate vehiculele au fost respawnate.");
        return 1;
    }

    // ---- /createfire ----
    if(strcmp(cmd, "/createfire", true) == 0)
    {
        if(PlayerData[playerid][pAdminLevel] < 2)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Eroare: "C_WHITE"Nu ai acces. Necesita admin nivel 2."), 1;

        new fidx = Fires_FindFree();
        if(fidx == -1)
            return SendClientMessage(playerid, COLOR_ERROR,
                C_ERROR"Eroare: "C_WHITE"Limita de "C_INFO#MAX_FIRES C_WHITE" incendii simultane atinsa."), 1;

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
            "[SMURD] "C_WHITE"Un incendiu a izbucnit! Mergeti cu firetruck-ul si stingeti-l cu apa.");

        for(new i = 0; i < MAX_PLAYERS; i++)
        {
            if(!IsPlayerConnected(i) || !PlayerData[i][pLogged] || PlayerData[i][pFaction] != FACTION_SMURD) continue;
            if(!PlayerData[i][pOnDuty]) continue;
            SendClientMessage(i, COLOR_INFO, fmsg);
            SetPlayerMapIcon(i, FIRE_ICON_SLOT_BASE + fidx, fx, fy, fz, FIRE_MAPICON_ID, 0, MAPICON_LOCAL);
        }

        SendClientMessage(playerid, COLOR_SUCCESS, C_SUCCESS"[ADM] Succes: "C_WHITE"Incendiu creat.");
        return 1;
    }

    // ---- /f [mesaj] (chat factiune) ----
    if(strcmp(cmd, "/f", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Eroare: "C_WHITE"Trebuie sa fii logat."), 1;

        new fid = PlayerData[playerid][pFaction];
        if(fid < 1 || fid > MAX_FACTIONS)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Eroare: "C_WHITE"Nu faci parte dintr-o factiune."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new text[128];
        strmid(text, cmdtext, idx, strlen(cmdtext), 128);

        if(!strlen(text))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Foloseste "C_INFO"/f [mesaj]"C_WHITE"."), 1;

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

    // ---- /duty ----
    if(strcmp(cmd, "/duty", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Eroare: "C_WHITE"Trebuie sa fii logat."), 1;

        new fid = PlayerData[playerid][pFaction];
        if(fid < 1 || fid > 3)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Eroare: "C_WHITE"Doar factiunile 1-3 au sistem de duty."), 1;

        if(FactionData[fid][fHQX] == 0.0 && FactionData[fid][fHQY] == 0.0)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Eroare: "C_WHITE"Factiunea ta nu are HQ setat."), 1;

        if(!IsPlayerInRangeOfPoint(playerid, DUTY_HQ_RANGE, FactionData[fid][fHQX], FactionData[fid][fHQY], FactionData[fid][fHQZ]))
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Eroare: "C_WHITE"Trebuie sa fii langa HQ-ul factiunii pentru a schimba duty-ul."), 1;

        PlayerData[playerid][pOnDuty] = !PlayerData[playerid][pOnDuty];

        if(PlayerData[playerid][pOnDuty])
            SendClientMessage(playerid, COLOR_SUCCESS, C_INFO"Info: "C_WHITE"Esti acum "C_SUCCESS"ON-DUTY"C_WHITE".");
        else
            SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Esti acum "C_ERROR"OFF-DUTY"C_WHITE".");
        return 1;
    }

    // ---- /factions ----
    if(strcmp(cmd, "/factions", true) == 0)
    {
        SendClientMessage(playerid, COLOR_INFO, C_INFO"_____ Factiuni ____________________");
        new line[128], colorcode[9], lead[24];
        for(new i = 1; i <= MAX_FACTIONS; i++)
        {
            GetFactionColorCode(i, colorcode, sizeof(colorcode));
            lead[0] = EOS;
            if(strlen(FactionData[i][fLead])) format(lead, sizeof(lead), "%s", FactionData[i][fLead]);
            else lead = "nimeni";
            format(line, sizeof(line), "%s%d. %s | Lead: %s | Membri: %d",
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
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Eroare: "C_WHITE"Nu ai acces. Necesita admin nivel 1."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new p1[8];
        strmid(p1, cmdtext, idx, strlen(cmdtext), 8);

        if(!strlen(p1))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Foloseste "C_INFO"/respawn [target_player]"C_WHITE"."), 1;

        new targetid = strval(p1);

        if(!IsPlayerConnected(targetid) || !PlayerData[targetid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Eroare: "C_WHITE"Playerul nu este conectat."), 1;

        SpawnPlayer(targetid);

        new adminName[24];
        GetPlayerName(playerid, adminName, 24);

        new msg[128];
        format(msg, sizeof(msg), C_SUCCESS"[ADM]Succes: "C_WHITE"I-ai dat respawn cu succes lui "C_INFO"%s"C_WHITE".",
            PlayerData[targetid][pName]);
        SendClientMessage(playerid, COLOR_SUCCESS, msg);

        format(msg, sizeof(msg), C_INFO"Info: "C_WHITE"Ai primit respawn de la admin "C_INFO"%s"C_WHITE".", adminName);
        SendClientMessage(targetid, COLOR_INFO, msg);
        return 1;
    }

    // ---- /aheal [playerid] ----
    if(strcmp(cmd, "/aheal", true) == 0)
    {
        if(PlayerData[playerid][pAdminLevel] < 1)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Eroare: "C_WHITE"Nu ai acces. Necesita admin nivel 1."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new p1[8];
        strmid(p1, cmdtext, idx, strlen(cmdtext), 8);

        if(!strlen(p1))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Foloseste "C_INFO"/aheal [playerid]"C_WHITE"."), 1;

        new targetid = strval(p1);

        if(!IsPlayerConnected(targetid) || !PlayerData[targetid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Eroare: "C_WHITE"Playerul nu este conectat."), 1;

        SetPlayerHealth(targetid, 100.0);

        new adminName[24];
        GetPlayerName(playerid, adminName, 24);

        new msg[128];
        format(msg, sizeof(msg), C_SUCCESS"[ADM]Succes: "C_WHITE"I-ai dat heal cu succes lui "C_INFO"%s"C_WHITE".",
            PlayerData[targetid][pName]);
        SendClientMessage(playerid, COLOR_SUCCESS, msg);

        format(msg, sizeof(msg), C_INFO"Info: "C_WHITE"Ai primit heal de la admin "C_INFO"%s"C_WHITE".", adminName);
        SendClientMessage(targetid, COLOR_INFO, msg);
        return 1;
    }

    // ---- /healall ----
    if(strcmp(cmd, "/healall", true) == 0)
    {
        if(PlayerData[playerid][pAdminLevel] < 2)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Eroare: "C_WHITE"Nu ai acces. Necesita admin nivel 2."), 1;

        new adminName[24];
        GetPlayerName(playerid, adminName, 24);

        new msg[128];
        format(msg, sizeof(msg), C_INFO"Info: "C_WHITE"Ai primit heal de la admin "C_INFO"%s"C_WHITE".", adminName);

        for(new i = 0; i < MAX_PLAYERS; i++)
        {
            if(!IsPlayerConnected(i) || !PlayerData[i][pLogged]) continue;
            SetPlayerHealth(i, 100.0);
            SendClientMessage(i, COLOR_INFO, msg);
        }

        SendClientMessage(playerid, COLOR_SUCCESS,
            C_SUCCESS"[ADM]Succes: "C_WHITE"Ai dat heal cu succes la toti playerii.");
        return 1;
    }

    // ---- /ahelp ----
    if(strcmp(cmd, "/ahelp", true) == 0)
    {
        new alv = PlayerData[playerid][pAdminLevel];
        if(alv < 1)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Eroare: "C_WHITE"Nu ai acces la comenzile de admin."), 1;

        SendClientMessage(playerid, COLOR_INFO, C_INFO"===== Comenzi Admin ======================");

        if(alv >= 1)
            SendClientMessage(playerid, COLOR_WHITE, C_INFO"[1] "C_WHITE"/ahelp /respawn /aheal");
        if(alv >= 2)
            SendClientMessage(playerid, COLOR_WHITE, C_INFO"[2] "C_WHITE"/createfire /healall");
        if(alv >= 3)
            SendClientMessage(playerid, COLOR_WHITE, C_INFO"[3] "C_WHITE"/veh /rac");
        if(alv >= 5)
            SendClientMessage(playerid, COLOR_WHITE, C_INFO"[5] "C_WHITE"/payday");
        if(alv >= 6)
        {
            SendClientMessage(playerid, COLOR_WHITE, C_INFO"[6] "C_WHITE"/changefactionhq /changefactionhqicon /changefactionhqpickup /changefactionlead");
            SendClientMessage(playerid, COLOR_WHITE, C_INFO"[6] "C_WHITE"/createhouse /changehouseprice /changehouseowner ");
            SendClientMessage(playerid, COLOR_WHITE, C_INFO"[6] "C_WHITE"/createfactionveh [faction_id]");
            SendClientMessage(playerid, COLOR_WHITE, C_INFO"[6] "C_WHITE"/vcreate [pret] /vsetprice [new_price]");
        }

        SendClientMessage(playerid, COLOR_INFO, C_INFO"==========================================");
        return 1;
    }

    // ---- /createhouse [nume] ----
    if(strcmp(cmd, "/createhouse", true) == 0)
    {
        if(PlayerData[playerid][pAdminLevel] < 6)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Eroare: "C_WHITE"Nu ai acces. Necesita admin nivel 6."), 1;

        if(g_HouseCount >= MAX_HOUSES)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Eroare: "C_WHITE"Limita de "C_INFO#MAX_HOUSES C_WHITE" case atinsa."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new hname[32];
        strmid(hname, cmdtext, idx, strlen(cmdtext), 32);

        if(!strlen(hname))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Foloseste "C_INFO"/createhouse [nume]"C_WHITE"."), 1;

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
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Eroare: "C_WHITE"Nu ai acces. Necesita admin nivel 6."), 1;

        if(g_VFactionCount >= MAX_VFACTION_VEHICLES)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Eroare: "C_WHITE"Limita de "C_INFO#MAX_VFACTION_VEHICLES C_WHITE" vehicule de factiune atinsa."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new p1[8];
        strmid(p1, cmdtext, idx, strlen(cmdtext), 8);

        if(!strlen(p1))
            return SendClientMessage(playerid, COLOR_INFO,
                C_INFO"Info: "C_WHITE"Foloseste "C_INFO"/createfactionveh [faction_id]"C_WHITE"."), 1;

        new fid = strval(p1);
        if(fid < 1 || fid > MAX_FACTIONS)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Eroare: "C_WHITE"ID factiune invalid (1-"#MAX_FACTIONS")."), 1;

        new vehid = GetPlayerVehicleID(playerid);
        if(vehid == 0)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Eroare: "C_WHITE"Trebuie sa fii intr-un vehicul."), 1;

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
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Eroare: "C_WHITE"Trebuie sa fii logat."), 1;

        if(PlayerData[playerid][pHouse] != 999)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Eroare: "C_WHITE"Detii deja o casa. Foloseste "C_INFO"/sellhouse"C_WHITE" mai intai."), 1;

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
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Eroare: "C_WHITE"Nu esti langa o casa de vanzare."), 1;

        if(PlayerData[playerid][pMoney] < HouseData[hidx][hPrice])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Eroare: "C_WHITE"Nu ai suficienti bani."), 1;

        PlayerData[playerid][pMoney] -= HouseData[hidx][hPrice];
        GivePlayerMoney(playerid, -HouseData[hidx][hPrice]);

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
        format(lmsg, sizeof(lmsg), C_SUCCESS"Succes: "C_WHITE"Ai cumparat casa "C_INFO"%s"C_WHITE" cu "C_INFO"$%d"C_WHITE".",
            HouseData[hidx][hName], HouseData[hidx][hPrice]);
        SendClientMessage(playerid, COLOR_SUCCESS, lmsg);
        return 1;
    }

    // ---- /sellhouse ----
    if(strcmp(cmd, "/sellhouse", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Eroare: "C_WHITE"Trebuie sa fii logat."), 1;

        if(PlayerData[playerid][pHouse] == 999)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Eroare: "C_WHITE"Nu detii nicio casa."), 1;

        new hidx = Houses_FindByID(PlayerData[playerid][pHouse]);
        if(hidx == -1)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Eroare: "C_WHITE"Casa nu a fost gasita."), 1;

        new price = HouseData[hidx][hPrice];
        PlayerData[playerid][pMoney] += price;
        GivePlayerMoney(playerid, price);
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
        format(lmsg, sizeof(lmsg), C_SUCCESS"Succes: "C_WHITE"Ai vandut casa "C_INFO"%s"C_WHITE" pentru "C_INFO"$%d"C_WHITE".",
            HouseData[hidx][hName], price);
        SendClientMessage(playerid, COLOR_SUCCESS, lmsg);
        return 1;
    }

    // ---- /changehouseprice [id] [pret_nou] ----
    if(strcmp(cmd, "/changehouseprice", true) == 0)
    {
        if(PlayerData[playerid][pAdminLevel] < 6)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Eroare: "C_WHITE"Nu ai acces. Necesita admin nivel 6."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new p1[8], p2[16];
        strmid(p1, cmdtext, idx, strlen(cmdtext), 8);
        new hid = strval(p1);
        while(cmdtext[idx] > ' ') idx++;
        while(cmdtext[idx] == ' ') idx++;
        strmid(p2, cmdtext, idx, strlen(cmdtext), 16);
        new newPrice = strval(p2);

        new hidx = Houses_FindByID(hid);
        if(hidx == -1)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Eroare: "C_WHITE"Casa nu a fost gasita."), 1;

        if(newPrice <= 0)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Eroare: "C_WHITE"Pret invalid."), 1;

        HouseData[hidx][hPrice] = newPrice;

        new q[128];
        mysql_format(g_SQL, q, sizeof(q), "UPDATE `houses` SET `price`=%d WHERE `id`=%d", newPrice, hid);
        mysql_tquery(g_SQL, q, "", "", 0);

        new lmsg[128];
        format(lmsg, sizeof(lmsg), C_SUCCESS"[ADM]Succes: "C_WHITE"Pretul casei "C_INFO"%s"C_WHITE" a fost schimbat la "C_INFO"$%d"C_WHITE".",
            HouseData[hidx][hName], newPrice);
        SendClientMessage(playerid, COLOR_SUCCESS, lmsg);
        return 1;
    }

    // ---- /changehouseowner [id] [playerid] ----
    if(strcmp(cmd, "/changehouseowner", true) == 0)
    {
        if(PlayerData[playerid][pAdminLevel] < 6)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Eroare: "C_WHITE"Nu ai acces. Necesita admin nivel 6."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new p1[8], p2[8];
        strmid(p1, cmdtext, idx, strlen(cmdtext), 8);
        new hid = strval(p1);
        while(cmdtext[idx] > ' ') idx++;
        while(cmdtext[idx] == ' ') idx++;
        strmid(p2, cmdtext, idx, strlen(cmdtext), 8);
        new targetid = strval(p2);

        new hidx = Houses_FindByID(hid);
        if(hidx == -1)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Eroare: "C_WHITE"Casa nu a fost gasita."), 1;

        if(!IsPlayerConnected(targetid) || !PlayerData[targetid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Eroare: "C_WHITE"Playerul nu este conectat."), 1;

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
        format(lmsg, sizeof(lmsg), C_SUCCESS"[ADM] Succes: "C_WHITE"Ownerul casei "C_INFO"%s"C_WHITE" a fost schimbat la "C_INFO"%s"C_WHITE".",
            HouseData[hidx][hName], HouseData[hidx][hOwner]);
        SendClientMessage(playerid, COLOR_SUCCESS, lmsg);
        return 1;
    }

    // ---- /vbuy ----
    if(strcmp(cmd, "/vbuy", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Eroare: "C_WHITE"Trebuie sa fii logat."), 1;

        new vehid = GetPlayerVehicleID(playerid);
        if(vehid == 0)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Eroare: "C_WHITE"Trebuie sa fii intr-un vehicul."), 1;

        new pvidx = g_VehicleToPVIndex[vehid];
        if(pvidx == -1)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Eroare: "C_WHITE"Acesta nu este un vehicul personal."), 1;

        if(PVehicleData[pvidx][pvOwnerId] != 0)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Eroare: "C_WHITE"Acest vehicul are deja un proprietar."), 1;

        new E_PLAYER_DATA:slot = PVehicles_FindFreeKeySlot(playerid);
        if(slot == E_PLAYER_DATA:-1)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Eroare: "C_WHITE"Detii deja "C_INFO#MAX_PLAYER_VEHICLES C_WHITE" vehicule personale."), 1;

        if(PlayerData[playerid][pMoney] < PVehicleData[pvidx][pvPrice])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Eroare: "C_WHITE"Nu ai suficienti bani."), 1;

        PlayerData[playerid][pMoney] -= PVehicleData[pvidx][pvPrice];
        GivePlayerMoney(playerid, -PVehicleData[pvidx][pvPrice]);

        PVehicleData[pvidx][pvOwnerId] = PlayerData[playerid][pID];
        PlayerData[playerid][slot] = PVehicleData[pvidx][pvID];
        UpdatePlayer(playerid, slot);

        new q[128];
        mysql_format(g_SQL, q, sizeof(q), "UPDATE `vehicles_personal` SET `owner_id`=%d WHERE `id`=%d",
            PVehicleData[pvidx][pvOwnerId], PVehicleData[pvidx][pvID]);
        mysql_tquery(g_SQL, q, "", "", 0);

        new lmsg[128];
        format(lmsg, sizeof(lmsg), C_SUCCESS"Succes: "C_WHITE"Ai cumparat vehiculul (ID: "C_INFO"%d"C_WHITE") cu "C_INFO"$%d"C_WHITE".",
            PVehicleData[pvidx][pvID], PVehicleData[pvidx][pvPrice]);
        SendClientMessage(playerid, COLOR_SUCCESS, lmsg);
        return 1;
    }

    // ---- /vsell ----
    if(strcmp(cmd, "/vsell", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Eroare: "C_WHITE"Trebuie sa fii logat."), 1;

        new vehid = GetPlayerVehicleID(playerid);
        if(vehid == 0)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Eroare: "C_WHITE"Trebuie sa fii intr-un vehicul."), 1;

        new pvidx = g_VehicleToPVIndex[vehid];
        if(pvidx == -1)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Eroare: "C_WHITE"Acesta nu este un vehicul personal."), 1;

        if(PVehicleData[pvidx][pvOwnerId] != PlayerData[playerid][pID])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Eroare: "C_WHITE"Nu detii acest vehicul."), 1;

        new refund = PVehicleData[pvidx][pvPrice] / 2;
        PlayerData[playerid][pMoney] += refund;
        GivePlayerMoney(playerid, refund);

        PVehicles_ClearKeySlot(playerid, PVehicleData[pvidx][pvID]);
        PVehicleData[pvidx][pvOwnerId] = 0;

        new q[128];
        mysql_format(g_SQL, q, sizeof(q), "UPDATE `vehicles_personal` SET `owner_id`=0 WHERE `id`=%d", PVehicleData[pvidx][pvID]);
        mysql_tquery(g_SQL, q, "", "", 0);

        new lmsg[128];
        format(lmsg, sizeof(lmsg), C_SUCCESS"Succes: "C_WHITE"Ai vandut vehiculul (ID: "C_INFO"%d"C_WHITE") pentru "C_INFO"$%d"C_WHITE".",
            PVehicleData[pvidx][pvID], refund);
        SendClientMessage(playerid, COLOR_SUCCESS, lmsg);
        return 1;
    }

    // ---- /vsellto [playerid] ----
    if(strcmp(cmd, "/vsellto", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Eroare: "C_WHITE"Trebuie sa fii logat."), 1;

        new vehid = GetPlayerVehicleID(playerid);
        if(vehid == 0)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Eroare: "C_WHITE"Trebuie sa fii intr-un vehicul."), 1;

        new pvidx = g_VehicleToPVIndex[vehid];
        if(pvidx == -1)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Eroare: "C_WHITE"Acesta nu este un vehicul personal."), 1;

        if(PVehicleData[pvidx][pvOwnerId] != PlayerData[playerid][pID])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Eroare: "C_WHITE"Nu detii acest vehicul."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new p1[8];
        strmid(p1, cmdtext, idx, strlen(cmdtext), 8);

        if(!strlen(p1))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Foloseste "C_INFO"/vsellto [playerid]"C_WHITE"."), 1;

        new targetid = strval(p1);
        if(!IsPlayerConnected(targetid) || !PlayerData[targetid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Eroare: "C_WHITE"Playerul nu este conectat."), 1;

        if(targetid == playerid)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Eroare: "C_WHITE"Nu poti vinde catre tine insuti."), 1;

        new E_PLAYER_DATA:slot = PVehicles_FindFreeKeySlot(targetid);
        if(slot == E_PLAYER_DATA:-1)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Eroare: "C_WHITE"Playerul detine deja "C_INFO#MAX_PLAYER_VEHICLES C_WHITE" vehicule personale."), 1;

        PVehicles_ClearKeySlot(playerid, PVehicleData[pvidx][pvID]);

        PVehicleData[pvidx][pvOwnerId] = PlayerData[targetid][pID];
        PlayerData[targetid][slot] = PVehicleData[pvidx][pvID];
        UpdatePlayer(targetid, slot);

        new q[128];
        mysql_format(g_SQL, q, sizeof(q), "UPDATE `vehicles_personal` SET `owner_id`=%d WHERE `id`=%d",
            PVehicleData[pvidx][pvOwnerId], PVehicleData[pvidx][pvID]);
        mysql_tquery(g_SQL, q, "", "", 0);

        new lmsg[128];
        format(lmsg, sizeof(lmsg), C_SUCCESS"Succes: "C_WHITE"Ai transferat vehiculul (ID: "C_INFO"%d"C_WHITE") lui "C_INFO"%s"C_WHITE".",
            PVehicleData[pvidx][pvID], PlayerData[targetid][pName]);
        SendClientMessage(playerid, COLOR_SUCCESS, lmsg);

        format(lmsg, sizeof(lmsg), C_INFO"Info: "C_WHITE"Ai primit vehiculul (ID: "C_INFO"%d"C_WHITE") de la "C_INFO"%s"C_WHITE".",
            PVehicleData[pvidx][pvID], PlayerData[playerid][pName]);
        SendClientMessage(targetid, COLOR_INFO, lmsg);
        return 1;
    }

    // ---- /vcolor [1/2] [colorID] ----
    if(strcmp(cmd, "/vcolor", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Eroare: "C_WHITE"Trebuie sa fii logat."), 1;

        new vehid = GetPlayerVehicleID(playerid);
        if(vehid == 0)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Eroare: "C_WHITE"Trebuie sa fii intr-un vehicul."), 1;

        new pvidx = g_VehicleToPVIndex[vehid];
        if(pvidx == -1)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Eroare: "C_WHITE"Acesta nu este un vehicul personal."), 1;

        if(PVehicleData[pvidx][pvOwnerId] != PlayerData[playerid][pID])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Eroare: "C_WHITE"Nu detii acest vehicul."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new p1[4], p2[8];
        strmid(p1, cmdtext, idx, strlen(cmdtext), 4);
        while(cmdtext[idx] > ' ') idx++;
        while(cmdtext[idx] == ' ') idx++;
        strmid(p2, cmdtext, idx, strlen(cmdtext), 8);

        if(!strlen(p1) || !strlen(p2))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Foloseste "C_INFO"/vcolor [1/2] [colorID]"C_WHITE"."), 1;

        new slotNum = strval(p1);
        new colorId = strval(p2);
        if(slotNum != 1 && slotNum != 2)
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Foloseste "C_INFO"/vcolor [1/2] [colorID]"C_WHITE"."), 1;

        if(slotNum == 1) PVehicleData[pvidx][pvColor1] = colorId;
        else PVehicleData[pvidx][pvColor2] = colorId;

        ChangeVehicleColor(vehid, PVehicleData[pvidx][pvColor1], PVehicleData[pvidx][pvColor2]);

        new q[128];
        mysql_format(g_SQL, q, sizeof(q), "UPDATE `vehicles_personal` SET `color1`=%d, `color2`=%d WHERE `id`=%d",
            PVehicleData[pvidx][pvColor1], PVehicleData[pvidx][pvColor2], PVehicleData[pvidx][pvID]);
        mysql_tquery(g_SQL, q, "", "", 0);

        SendClientMessage(playerid, COLOR_SUCCESS, C_SUCCESS"Succes: "C_WHITE"Culoarea vehiculului a fost schimbata.");
        return 1;
    }

    // ---- /vplate [text] ----
    if(strcmp(cmd, "/vplate", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Eroare: "C_WHITE"Trebuie sa fii logat."), 1;

        new vehid = GetPlayerVehicleID(playerid);
        if(vehid == 0)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Eroare: "C_WHITE"Trebuie sa fii intr-un vehicul."), 1;

        new pvidx = g_VehicleToPVIndex[vehid];
        if(pvidx == -1)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Eroare: "C_WHITE"Acesta nu este un vehicul personal."), 1;

        if(PVehicleData[pvidx][pvOwnerId] != PlayerData[playerid][pID])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Eroare: "C_WHITE"Nu detii acest vehicul."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new plate[8];
        strmid(plate, cmdtext, idx, strlen(cmdtext), 8);

        if(!strlen(plate))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Foloseste "C_INFO"/vplate [text]"C_WHITE" (max 8 caractere)."), 1;

        format(PVehicleData[pvidx][pvPlate], 8, "%s", plate);
        SetVehicleNumberPlate(vehid, PVehicleData[pvidx][pvPlate]);

        new q[128];
        mysql_format(g_SQL, q, sizeof(q), "UPDATE `vehicles_personal` SET `plate`='%e' WHERE `id`=%d",
            PVehicleData[pvidx][pvPlate], PVehicleData[pvidx][pvID]);
        mysql_tquery(g_SQL, q, "", "", 0);

        SendClientMessage(playerid, COLOR_SUCCESS, C_SUCCESS"Succes: "C_WHITE"Numarul de inmatriculare a fost schimbat.");
        return 1;
    }

    // ---- /vinsurance ----
    if(strcmp(cmd, "/vinsurance", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Eroare: "C_WHITE"Trebuie sa fii logat."), 1;

        new vehid = GetPlayerVehicleID(playerid);
        if(vehid == 0)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Eroare: "C_WHITE"Trebuie sa fii intr-un vehicul."), 1;

        new pvidx = g_VehicleToPVIndex[vehid];
        if(pvidx == -1)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Eroare: "C_WHITE"Acesta nu este un vehicul personal."), 1;

        if(PVehicleData[pvidx][pvOwnerId] != PlayerData[playerid][pID])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Eroare: "C_WHITE"Nu detii acest vehicul."), 1;

        if(PlayerData[playerid][pMoney] < g_InsurancePrice)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Eroare: "C_WHITE"Nu ai suficienti bani."), 1;

        PlayerData[playerid][pMoney] -= g_InsurancePrice;
        GivePlayerMoney(playerid, -g_InsurancePrice);

        PVehicleData[pvidx][pvInsuranceExp] = gettime() + VEHICLE_DOC_DURATION;

        new q[128];
        mysql_format(g_SQL, q, sizeof(q), "UPDATE `vehicles_personal` SET `insurance_exp`=%d WHERE `id`=%d",
            PVehicleData[pvidx][pvInsuranceExp], PVehicleData[pvidx][pvID]);
        mysql_tquery(g_SQL, q, "", "", 0);

        new lmsg[128];
        format(lmsg, sizeof(lmsg), C_SUCCESS"Succes: "C_WHITE"Ai cumparat asigurare ("C_INFO"7 zile"C_WHITE") pentru "C_INFO"$%d"C_WHITE".", g_InsurancePrice);
        SendClientMessage(playerid, COLOR_SUCCESS, lmsg);
        return 1;
    }

    // ---- /vmedicalkit ----
    if(strcmp(cmd, "/vmedicalkit", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Eroare: "C_WHITE"Trebuie sa fii logat."), 1;

        new vehid = GetPlayerVehicleID(playerid);
        if(vehid == 0)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Eroare: "C_WHITE"Trebuie sa fii intr-un vehicul."), 1;

        new pvidx = g_VehicleToPVIndex[vehid];
        if(pvidx == -1)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Eroare: "C_WHITE"Acesta nu este un vehicul personal."), 1;

        if(PVehicleData[pvidx][pvOwnerId] != PlayerData[playerid][pID])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Eroare: "C_WHITE"Nu detii acest vehicul."), 1;

        if(PlayerData[playerid][pMoney] < g_MedkitPrice)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Eroare: "C_WHITE"Nu ai suficienti bani."), 1;

        PlayerData[playerid][pMoney] -= g_MedkitPrice;
        GivePlayerMoney(playerid, -g_MedkitPrice);

        PVehicleData[pvidx][pvMedkitExp] = gettime() + VEHICLE_DOC_DURATION;

        new q[128];
        mysql_format(g_SQL, q, sizeof(q), "UPDATE `vehicles_personal` SET `medkit_exp`=%d WHERE `id`=%d",
            PVehicleData[pvidx][pvMedkitExp], PVehicleData[pvidx][pvID]);
        mysql_tquery(g_SQL, q, "", "", 0);

        new lmsg[128];
        format(lmsg, sizeof(lmsg), C_SUCCESS"Succes: "C_WHITE"Ai cumparat kit medical ("C_INFO"7 zile"C_WHITE") pentru "C_INFO"$%d"C_WHITE".", g_MedkitPrice);
        SendClientMessage(playerid, COLOR_SUCCESS, lmsg);
        return 1;
    }

    // ---- /vextinctor ----
    if(strcmp(cmd, "/vextinctor", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Eroare: "C_WHITE"Trebuie sa fii logat."), 1;

        new vehid = GetPlayerVehicleID(playerid);
        if(vehid == 0)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Eroare: "C_WHITE"Trebuie sa fii intr-un vehicul."), 1;

        new pvidx = g_VehicleToPVIndex[vehid];
        if(pvidx == -1)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Eroare: "C_WHITE"Acesta nu este un vehicul personal."), 1;

        if(PVehicleData[pvidx][pvOwnerId] != PlayerData[playerid][pID])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Eroare: "C_WHITE"Nu detii acest vehicul."), 1;

        if(PlayerData[playerid][pMoney] < g_ExtinguisherPrice)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Eroare: "C_WHITE"Nu ai suficienti bani."), 1;

        PlayerData[playerid][pMoney] -= g_ExtinguisherPrice;
        GivePlayerMoney(playerid, -g_ExtinguisherPrice);

        PVehicleData[pvidx][pvExtinguisherExp] = gettime() + VEHICLE_DOC_DURATION;

        new q[128];
        mysql_format(g_SQL, q, sizeof(q), "UPDATE `vehicles_personal` SET `extinguisher_exp`=%d WHERE `id`=%d",
            PVehicleData[pvidx][pvExtinguisherExp], PVehicleData[pvidx][pvID]);
        mysql_tquery(g_SQL, q, "", "", 0);

        new lmsg[128];
        format(lmsg, sizeof(lmsg), C_SUCCESS"Succes: "C_WHITE"Ai cumparat extinctor ("C_INFO"7 zile"C_WHITE") pentru "C_INFO"$%d"C_WHITE".", g_ExtinguisherPrice);
        SendClientMessage(playerid, COLOR_SUCCESS, lmsg);
        return 1;
    }

    // ---- /vpark ----
    if(strcmp(cmd, "/vpark", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Eroare: "C_WHITE"Trebuie sa fii logat."), 1;

        new vehid = GetPlayerVehicleID(playerid);
        if(vehid == 0)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Eroare: "C_WHITE"Trebuie sa fii intr-un vehicul."), 1;

        new pvidx = g_VehicleToPVIndex[vehid];
        if(pvidx == -1)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Eroare: "C_WHITE"Acesta nu este un vehicul personal."), 1;

        if(PVehicleData[pvidx][pvOwnerId] != PlayerData[playerid][pID])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Eroare: "C_WHITE"Nu detii acest vehicul."), 1;

        GetVehiclePos(vehid, PVehicleData[pvidx][pvLocX], PVehicleData[pvidx][pvLocY], PVehicleData[pvidx][pvLocZ]);
        GetVehicleZAngle(vehid, PVehicleData[pvidx][pvRotation]);

        new q[256];
        mysql_format(g_SQL, q, sizeof(q),
            "UPDATE `vehicles_personal` SET `loc_x`=%.4f, `loc_y`=%.4f, `loc_z`=%.4f, `rotation`=%.4f WHERE `id`=%d",
            PVehicleData[pvidx][pvLocX], PVehicleData[pvidx][pvLocY], PVehicleData[pvidx][pvLocZ], PVehicleData[pvidx][pvRotation],
            PVehicleData[pvidx][pvID]);
        mysql_tquery(g_SQL, q, "", "", 0);

        SendClientMessage(playerid, COLOR_SUCCESS, C_SUCCESS"Succes: "C_WHITE"Vehiculul a fost parcat (pozitie salvata).");
        return 1;
    }

    // ---- /vcreate [pret] ----
    if(strcmp(cmd, "/vcreate", true) == 0)
    {
        if(PlayerData[playerid][pAdminLevel] < 6)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Eroare: "C_WHITE"Nu ai acces. Necesita admin nivel 6."), 1;

        if(g_PVehicleCount >= MAX_PERSONAL_VEHICLES)
            return SendClientMessage(playerid, COLOR_ERROR,
                C_ERROR"Eroare: "C_WHITE"Limita de "C_INFO#MAX_PERSONAL_VEHICLES C_WHITE" vehicule personale atinsa."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new p1[16];
        strmid(p1, cmdtext, idx, strlen(cmdtext), 16);

        if(!strlen(p1))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Foloseste "C_INFO"/vcreate [pret]"C_WHITE"."), 1;

        new price = strval(p1);
        if(price <= 0)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Eroare: "C_WHITE"Pret invalid."), 1;

        new vehid = GetPlayerVehicleID(playerid);
        if(vehid == 0)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Eroare: "C_WHITE"Trebuie sa fii intr-un vehicul."), 1;

        new Float:vx, Float:vy, Float:vz, Float:vangle;
        GetVehiclePos(vehid, vx, vy, vz);
        GetVehicleZAngle(vehid, vangle);
        new model = GetVehicleModel(vehid);

        new newIdx = g_PVehicleCount;
        PVehicleData[newIdx][pvOwnerId]         = 0;
        PVehicleData[newIdx][pvModelID]         = model;
        PVehicleData[newIdx][pvColor1]          = 1;
        PVehicleData[newIdx][pvColor2]          = 1;
        format(PVehicleData[newIdx][pvPlate], 8, "NoRP");
        PVehicleData[newIdx][pvPrice]           = price;
        PVehicleData[newIdx][pvLocX]            = vx;
        PVehicleData[newIdx][pvLocY]            = vy;
        PVehicleData[newIdx][pvLocZ]            = vz;
        PVehicleData[newIdx][pvRotation]        = vangle;
        PVehicleData[newIdx][pvInsuranceExp]    = 0;
        PVehicleData[newIdx][pvMedkitExp]       = 0;
        PVehicleData[newIdx][pvExtinguisherExp] = 0;
        g_PVehicleVehicle[newIdx]               = -1;
        g_PVehicleCount++;

        new q[256];
        mysql_format(g_SQL, q, sizeof(q),
            "INSERT INTO `vehicles_personal` (`owner_id`,`model_id`,`color1`,`color2`,`plate`,`price`,`loc_x`,`loc_y`,`loc_z`,`rotation`) \
             VALUES (0,%d,1,1,'NoRP',%d,%.4f,%.4f,%.4f,%.4f)",
            model, price, vx, vy, vz, vangle);
        mysql_tquery(g_SQL, q, "OnVehiclePersonalCreated", "ii", playerid, newIdx);
        return 1;
    }

    // ---- /vsetprice [new_price] ----
    if(strcmp(cmd, "/vsetprice", true) == 0)
    {
        if(PlayerData[playerid][pAdminLevel] < 6)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Eroare: "C_WHITE"Nu ai acces. Necesita admin nivel 6."), 1;

        new vehid = GetPlayerVehicleID(playerid);
        if(vehid == 0)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Eroare: "C_WHITE"Trebuie sa fii intr-un vehicul."), 1;

        new pvidx = g_VehicleToPVIndex[vehid];
        if(pvidx == -1)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Eroare: "C_WHITE"Acesta nu este un vehicul personal."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new p1[16];
        strmid(p1, cmdtext, idx, strlen(cmdtext), 16);

        if(!strlen(p1))
            return SendClientMessage(playerid, COLOR_INFO, C_INFO"Info: "C_WHITE"Foloseste "C_INFO"/vsetprice [new_price]"C_WHITE"."), 1;

        new newPrice = strval(p1);
        if(newPrice <= 0)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Eroare: "C_WHITE"Pret invalid."), 1;

        PVehicleData[pvidx][pvPrice] = newPrice;

        new q[128];
        mysql_format(g_SQL, q, sizeof(q), "UPDATE `vehicles_personal` SET `price`=%d WHERE `id`=%d",
            newPrice, PVehicleData[pvidx][pvID]);
        mysql_tquery(g_SQL, q, "", "", 0);

        new lmsg[128];
        format(lmsg, sizeof(lmsg), C_SUCCESS"[ADM]Succes: "C_WHITE"Pretul vehiculului (ID: "C_INFO"%d"C_WHITE") a fost schimbat la "C_INFO"$%d"C_WHITE".",
            PVehicleData[pvidx][pvID], newPrice);
        SendClientMessage(playerid, COLOR_SUCCESS, lmsg);
        return 1;
    }

    // ---- /cspawn ----
    if(strcmp(cmd, "/cspawn", true) == 0)
    {
        if(!PlayerData[playerid][pLogged])
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Eroare: "C_WHITE"Trebuie sa fii logat."), 1;

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
            case 2: format(spawnName, sizeof(spawnName), "Sediul factiunii");
            case 3: format(spawnName, sizeof(spawnName), "Casa personala");
            default: format(spawnName, sizeof(spawnName), "Spawn civil");
        }

        new lmsg[128];
        format(lmsg, sizeof(lmsg), C_SUCCESS"Succes: "C_WHITE"Punctul de spawn a fost setat la: "C_INFO"%s"C_WHITE".", spawnName);
        SendClientMessage(playerid, COLOR_SUCCESS, lmsg);
        return 1;
    }

    // ---- /payday ----
    if(strcmp(cmd, "/payday", true) == 0)
    {
        if(PlayerData[playerid][pAdminLevel] < 5)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Eroare: "C_WHITE"Nu ai acces. Necesita admin nivel 5."), 1;

        PayDay_Apply();
        new lmsg[128];
        format(lmsg, sizeof(lmsg), C_SUCCESS"[ADM]Succes: "C_WHITE"Ai oferit "C_INFO"PayDay"C_WHITE" cu succes.");
        SendClientMessage(playerid, COLOR_SUCCESS, lmsg);
        return 1;
    }

    // ---- /changefactionhq [id] ----
    if(strcmp(cmd, "/changefactionhq", true) == 0)
    {
        if(PlayerData[playerid][pAdminLevel] < 6)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Eroare: "C_WHITE"Nu ai acces. Necesita admin nivel 6."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new param[8];
        strmid(param, cmdtext, idx, strlen(cmdtext), 8);
        new fid = strval(param);

        if(fid < 1 || fid > MAX_FACTIONS)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Eroare: "C_WHITE"ID factiune invalid (1-7)."), 1;

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
        format(lmsg, sizeof(lmsg), C_SUCCESS"Succes: "C_WHITE"HQ pentru "C_INFO"%s"C_WHITE" setat la pozitia ta.", FactionData[fid][fName]);
        SendClientMessage(playerid, COLOR_SUCCESS, lmsg);
        return 1;
    }

    // ---- /changefactionhqicon [id] [icon_id] ----
    if(strcmp(cmd, "/changefactionhqicon", true) == 0)
    {
        if(PlayerData[playerid][pAdminLevel] < 6)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Eroare: "C_WHITE"Nu ai acces. Necesita admin nivel 6."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new p1[8], p2[8];
        strmid(p1, cmdtext, idx, strlen(cmdtext), 8);
        new fid = strval(p1);
        while(cmdtext[idx] > ' ') idx++;
        while(cmdtext[idx] == ' ') idx++;
        strmid(p2, cmdtext, idx, strlen(cmdtext), 8);
        new iconid = strval(p2);

        if(fid < 1 || fid > MAX_FACTIONS)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Eroare: "C_WHITE"ID factiune invalid (1-7)."), 1;

        FactionData[fid][fMapIconID] = iconid;

        new q[128];
        mysql_format(g_SQL, q, sizeof(q), "UPDATE `factions` SET `mapicon_id`=%d WHERE `id`=%d", iconid, fid);
        mysql_tquery(g_SQL, q, "", "", 0);

        Factions_UpdatePlayersIcons();

        new lmsg[128];
        format(lmsg, sizeof(lmsg), C_SUCCESS"Succes: "C_WHITE"Map icon pentru "C_INFO"%s"C_WHITE" schimbat la %d.", FactionData[fid][fName], iconid);
        SendClientMessage(playerid, COLOR_SUCCESS, lmsg);
        return 1;
    }

    // ---- /changefactionhqpickup [id] [pickup_id] ----
    if(strcmp(cmd, "/changefactionhqpickup", true) == 0)
    {
        if(PlayerData[playerid][pAdminLevel] < 6)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Eroare: "C_WHITE"Nu ai acces. Necesita admin nivel 6."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new p1[8], p2[8];
        strmid(p1, cmdtext, idx, strlen(cmdtext), 8);
        new fid = strval(p1);
        while(cmdtext[idx] > ' ') idx++;
        while(cmdtext[idx] == ' ') idx++;
        strmid(p2, cmdtext, idx, strlen(cmdtext), 8);
        new pickupid = strval(p2);

        if(fid < 1 || fid > MAX_FACTIONS)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Eroare: "C_WHITE"ID factiune invalid (1-7)."), 1;

        FactionData[fid][fPickupID] = pickupid;

        new q[128];
        mysql_format(g_SQL, q, sizeof(q), "UPDATE `factions` SET `pickup_id`=%d WHERE `id`=%d", pickupid, fid);
        mysql_tquery(g_SQL, q, "", "", 0);

        Factions_RecreatePickup(fid);

        new lmsg[128];
        format(lmsg, sizeof(lmsg), C_SUCCESS"Succes: "C_WHITE"Pickup pentru "C_INFO"%s"C_WHITE" schimbat la %d.", FactionData[fid][fName], pickupid);
        SendClientMessage(playerid, COLOR_SUCCESS, lmsg);
        return 1;
    }

    // ---- /changefactionlead [id] [playerid] ----
    if(strcmp(cmd, "/changefactionlead", true) == 0)
    {
        if(PlayerData[playerid][pAdminLevel] < 6)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Eroare: "C_WHITE"Nu ai acces. Necesita admin nivel 6."), 1;

        while(cmdtext[idx] == ' ') idx++;
        new p1[8], p2[8];
        strmid(p1, cmdtext, idx, strlen(cmdtext), 8);
        new fid = strval(p1);
        while(cmdtext[idx] > ' ') idx++;
        while(cmdtext[idx] == ' ') idx++;
        strmid(p2, cmdtext, idx, strlen(cmdtext), 8);
        new targetid = strval(p2);

        if(fid < 1 || fid > MAX_FACTIONS)
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Eroare: "C_WHITE"ID factiune invalid (1-7)."), 1;

        if(!IsPlayerConnected(targetid))
            return SendClientMessage(playerid, COLOR_ERROR, C_ERROR"Eroare: "C_WHITE"Playerul nu este conectat."), 1;

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
        PlayerData[targetid][pFaction] = fid;
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
            "UPDATE `players` SET `faction`=%d WHERE `id`=%d",
            fid, PlayerData[targetid][pID]);
        mysql_tquery(g_SQL, q, "", "", 0);

        // Anunt global cu culorile factiunii
        new announce[192], cFaction[9], cPlayer[9];
        GetFactionColorCode(fid, cFaction, sizeof(cFaction));
        GetFactionColorCode(fid, cPlayer, sizeof(cPlayer));
        format(announce, sizeof(announce),
            C_WHITE">>> %s%s"C_WHITE" este noul lider al %s%s"C_WHITE"! <<<",
            cPlayer, FactionData[fid][fLead], cFaction, FactionData[fid][fName]);
        SendClientMessageToAll(FactionColors[fid], announce);

        new lmsg[128];
        format(lmsg, sizeof(lmsg), C_SUCCESS"Succes: "C_WHITE"Lead pentru "C_INFO"%s"C_WHITE" schimbat la "C_INFO"%s"C_WHITE".",
            FactionData[fid][fName], FactionData[fid][fLead]);
        SendClientMessage(playerid, COLOR_SUCCESS, lmsg);
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

public OnPlayerText(playerid, text[])
{
    if(!PlayerData[playerid][pLogged]) return 0;

    new colorcode[9], msg[144];
    GetFactionColorCode(PlayerData[playerid][pFaction], colorcode, sizeof(colorcode));
    format(msg, sizeof(msg), "%s%s"C_WHITE": %s", colorcode, PlayerData[playerid][pName], text);
    SendClientMessageToAll(COLOR_WHITE, msg);
    return 0;
}

public OnPlayerDeath(playerid, killerid, reason)
{
    return 1;
}

public OnPlayerDisconnect(playerid, reason)
{
    FullUpdatePlayer(playerid);
    return 1;
}

public OnPlayerStateChange(playerid, newstate, oldstate)
{
    if(newstate == PLAYER_STATE_DRIVER && GetPlayerVehicleID(playerid) == g_TrainID)
        RemovePlayerFromVehicle(playerid);

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
                    C_ERROR"Eroare: "C_WHITE"Acest vehicul apartine unei factiuni. Nu il poti conduce.");
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
