// ============================================================
//  CONFIG.INC - Setari globale Romania RPG
// ============================================================
#if defined _config_included
    #endinput
#endif
#define _config_included

// ---- MySQL ----
#define MYSQL_HOST      "127.0.0.1"
#define MYSQL_USER      "root"
#define MYSQL_PASS      "parola_ta"
#define MYSQL_DB        "romania_rpg"
#define MYSQL_PORT      3306

// ---- Limite ----
#define MAX_PLAYERS_RPG     200
#define MAX_HOUSES          500
#define MAX_BUSINESSES      200
#define MAX_VEHICLES        1000
#define MAX_PETS            500
#define MAX_NEWSPAPERS      100
#define MAX_TRADES          50
#define MAX_FACTIONS        9
#define MAX_MAFIA_MEMBERS   50
#define MAX_TERRITORIES     30
#define MAX_TOURS           10
#define MAX_DISEASES        20
#define MAX_HUNT_ANIMALS    100
#define MAX_FISH            100

// ---- Payday ----
#define PAYDAY_INTERVAL     (30 * 60 * 1000)   // 30 minute
#define PAYDAY_MIDNIGHT     0                    // ora 00:00 pt mafia

// ---- Nivel / XP ----
#define MAX_LEVEL           100
#define XP_PER_LEVEL        1000
#define SALARY_BASE         500
#define SALARY_PER_LEVEL    100
#define RP_PER_PAYDAY       10

// ---- President ----
#define PRESIDENT_VOTE_START    7    // ora 07:00
#define PRESIDENT_VOTE_END      20   // ora 20:00
#define PRESIDENT_ANNOUNCE      (20 * 60 + 5) // 20:05
#define MIN_LEVEL_VOTE          5
#define MIN_LEVEL_CANDIDATE     10
#define TAX_MIN                 0
#define TAX_MAX                 30   // maxim 30% impozit
#define CASS_MIN                0
#define CASS_MAX                15

// ---- Boala ----
#define DISEASE_HP_DECAY        3    // hp/minut bolnav
#define NORMAL_HP_DECAY         1    // hp/minut normal (fara boala)
#define DISEASE_RANGE           15.0 // raza de infectare

// ---- Hunting / Fishing ----
#define HUNT_ANIMAL_RESPAWN_PAYDAY   1
#define FISH_RESPAWN_PAYDAY          1

// ---- Colors ----
#define COLOR_WHITE         0xFFFFFFFF
#define COLOR_RED           0xFF0000FF
#define COLOR_GREEN         0x00FF00FF
#define COLOR_BLUE          0x0000FFFF
#define COLOR_YELLOW        0xFFFF00FF
#define COLOR_ORANGE        0xFF8C00FF
#define COLOR_GREY          0xAFAFAFFF
#define COLOR_PURPLE        0x8B00FFFF
#define COLOR_PINK          0xFF69B4FF
#define COLOR_DARK_BLUE     0x00008BFF
#define COLOR_GOLD          0xFFD700FF
#define COLOR_SYSTEM        0x00E5FFFF
#define COLOR_ERROR         0xFF4444FF
#define COLOR_SUCCESS       0x44FF44FF
#define COLOR_UBER          0x000000FF

// ---- Dialoguri ID-uri ----
#define DIALOG_LOGIN            1
#define DIALOG_REGISTER         2
#define DIALOG_REGISTER_PASS    3
#define DIALOG_SPAWN_SELECT     4
#define DIALOG_HOUSE_MENU       5
#define DIALOG_BUSINESS_MENU    6
#define DIALOG_VEHICLE_MENU     7
#define DIALOG_PET_MENU         8
#define DIALOG_NEWSPAPER_LIST   9
#define DIALOG_NEWSPAPER_READ   10
#define DIALOG_NEWSPAPER_CAT    11
#define DIALOG_TRADE_OFFER      12
#define DIALOG_TRADE_CONFIRM    13
#define DIALOG_PRESIDENT_VOTE   14
#define DIALOG_FACTION_MENU     15
#define DIALOG_MAFIA_MENU       16
#define DIALOG_DISEASE_CONFIRM  17
#define DIALOG_TOUR_JOIN        18
#define DIALOG_JOB_SELECT       19
#define DIALOG_HOUSE_BUY        20
#define DIALOG_BUSINESS_BUY     21
#define DIALOG_VEHICLE_BUY      22
#define DIALOG_ADMIN_DISEASE    23
#define DIALOG_NEWSPAPER_CREATE 24
#define DIALOG_TOUR_CREATE      25
#define DIALOG_MAFIA_SEIF       26
#define DIALOG_HOSPITAL_TREAT   27
#define DIALOG_RAR_CHECK        28
#define DIALOG_POLICE_FINE      29
#define DIALOG_UBER_REQUEST     30
#define DIALOG_UBER_CONFIRM     31
#define DIALOG_MAFIA_TERRITORY  32
#define DIALOG_PRESIDENT_TAX    33
#define DIALOG_FISHING_SELL     34
#define DIALOG_HUNT_SELL        35
#define DIALOG_TOUR_SELECT_TYPE 36

// ---- Factiuni ID ----
#define FACTION_NONE            0
#define FACTION_POLITIE         1
#define FACTION_POLITIE_ANIMALE 2
#define FACTION_RAR             3
#define FACTION_SMURD           4
#define FACTION_REPORTERI       5
#define FACTION_MAFIA_EU        6
#define FACTION_MAFIA_AF        7
#define FACTION_MAFIA_AS        8
#define FACTION_MAFIA_AM        9

// ---- Joburi ID ----
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

// ---- Rank-uri Factiune ----
#define RANK_RECRUIT    1
#define RANK_MEMBER     2
#define RANK_SENIOR     3
#define RANK_OFFICER    4
#define RANK_LEADER     5

// ---- Skins / Modele ----
// Skin-uri pentru skinurile default ale factiunilor
new FactionSkins[MAX_FACTIONS+1][5] = {
    {0,0,0,0,0},           // 0 - none
    {280,281,282,283,284}, // 1 - Politie
    {285,285,285,285,285}, // 2 - Politia Animalelor (reutilizat)
    {270,270,270,270,270}, // 3 - RAR
    {276,277,278,279,279}, // 4 - SMURD
    {154,155,156,157,158}, // 5 - Reporteri
    {130,131,132,133,134}, // 6 - Mafia EU
    {105,106,107,108,109}, // 7 - Mafia Africana
    {110,111,112,113,114}, // 8 - Mafia Asiatica
    {115,116,117,118,119}  // 9 - Mafia Americana
};

// ---- Zone Vanatoare / Pescuit ----
// {x, y, z, raza}
new Float:HuntZones[][4] = {
    {-1400.0, 2300.0, 0.0, 200.0},  // Padure nord
    {-800.0,  1900.0, 0.0, 150.0},  // Padure centru
    {300.0,   1700.0, 0.0, 180.0},  // Munte est
    {-200.0,  500.0,  0.0, 120.0},  // Zona rurala
    {700.0,   -400.0, 0.0, 100.0}   // Desert
};

new Float:FishZones[][4] = {
    {-2200.0, -300.0,  0.0, 100.0},  // Port vest
    {-1500.0, -1000.0, 0.0, 120.0},  // Plaja
    {1500.0,  -1000.0, 0.0, 100.0},  // Est plaja
    {-800.0,  1500.0,  0.0, 80.0},   // Lac nord
    {300.0,   -800.0,  0.0, 90.0}    // Lac centru
};

// ---- Zone patrulare animale ----
new Float:AnimalPatrolZones[][4] = {
    {-1400.0, 2300.0, 0.0, 250.0},
    {-600.0,  1400.0, 0.0, 200.0},
    {800.0,   1200.0, 0.0, 180.0}
};

// ---- Trasee Tur ----
#define TOUR_MOUNTAIN   1
#define TOUR_BEACH      2
#define TOUR_FOREST     3
#define TOUR_VILLAGE    4
