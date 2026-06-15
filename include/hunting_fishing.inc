// ============================================================
//  HUNTING_FISHING.INC - Vanatoare si Pescuit (ilegal)
// ============================================================
#if defined _hunting_fishing_included
    #endinput
#endif
#define _hunting_fishing_included

enum E_HUNT_ANIMAL
{
    haID, haModel,
    Float:haX, Float:haY, Float:haZ,
    bool:haAlive, haZone,
    haActorID
}

enum E_FISH
{
    fhID, fhZone,
    Float:fhX, Float:fhY, Float:fhZ,
    bool:fhAlive, fhPickupID
}

new HuntAnimals[MAX_HUNT_ANIMALS][E_HUNT_ANIMAL];
new HuntAnimalCount = 0;
new FishData[MAX_FISH][E_FISH];
new FishCount = 0;

// Inventar vanatoare/pescuit per player
new PlayerHuntBag[MAX_PLAYERS]    = {0, ...}; // animale vanate
new PlayerFishBag[MAX_PLAYERS]    = {0, ...}; // pesti prinsi

// Zone dynamice streamer
new HuntZoneIDs[sizeof(HuntZones)];
new FishZoneIDs[sizeof(FishZones)];

// ============================================================
//  INIT
// ============================================================

stock HuntingFishing_Init()
{
    // Creeaza zone dinamice
    for(new i = 0; i < sizeof(HuntZones); i++)
    {
        HuntZoneIDs[i] = CreateDynamicCircle(
            HuntZones[i][0], HuntZones[i][1],
            HuntZones[i][3], -1, -1
        );
    }
    for(new i = 0; i < sizeof(FishZones); i++)
    {
        FishZoneIDs[i] = CreateDynamicCircle(
            FishZones[i][0], FishZones[i][1],
            FishZones[i][3], -1, -1
        );
    }
    HuntingFishing_SpawnAll();
    print("[HuntingFishing] Sistem vanatoare/pescuit incarcat.");
}

stock HuntingFishing_SpawnAll()
{
    HuntingFishing_SpawnAnimals();
    HuntingFishing_SpawnFish();
}

stock HuntingFishing_SpawnAnimals()
{
    // Curata vechi
    for(new i = 0; i < HuntAnimalCount; i++)
    {
        if(HuntAnimals[i][haActorID] > 0)
            DestroyActor(HuntAnimals[i][haActorID]);
    }
    HuntAnimalCount = 0;

    // Modele animale de vanat: cerb=51, mistret=52
    new models[] = {51, 52, 53, 54};

    for(new z = 0; z < sizeof(HuntZones); z++)
    {
        new perZone = 5; // 5 animale per zona
        for(new n = 0; n < perZone && HuntAnimalCount < MAX_HUNT_ANIMALS; n++)
        {
            new i = HuntAnimalCount;
            HuntAnimals[i][haZone] = z;
            HuntAnimals[i][haAlive] = true;
            // Pozitie random in zona
            HuntAnimals[i][haX] = HuntZones[z][0] + random(floatround(HuntZones[z][3]*2)) - HuntZones[z][3];
            HuntAnimals[i][haY] = HuntZones[z][1] + random(floatround(HuntZones[z][3]*2)) - HuntZones[z][3];
            HuntAnimals[i][haZ] = HuntZones[z][2];
            HuntAnimals[i][haModel] = models[random(sizeof(models))];
            HuntAnimals[i][haActorID] = CreateActor(
                HuntAnimals[i][haModel],
                HuntAnimals[i][haX], HuntAnimals[i][haY], HuntAnimals[i][haZ],
                float(random(360))
            );
            HuntAnimalCount++;
        }
    }
    new msg[64];
    format(msg, sizeof(msg), "[HuntFish] %d animale de vanat spawnate.", HuntAnimalCount);
    print(msg);
}

stock HuntingFishing_SpawnFish()
{
    // Curata vechi
    for(new i = 0; i < FishCount; i++)
    {
        if(FishData[i][fhPickupID] > 0)
            DestroyPickup(FishData[i][fhPickupID]);
    }
    FishCount = 0;

    for(new z = 0; z < sizeof(FishZones); z++)
    {
        new perZone = 8;
        for(new n = 0; n < perZone && FishCount < MAX_FISH; n++)
        {
            new i = FishCount;
            FishData[i][fhZone] = z;
            FishData[i][fhAlive] = true;
            FishData[i][fhX] = FishZones[z][0] + random(floatround(FishZones[z][3]*2)) - FishZones[z][3];
            FishData[i][fhY] = FishZones[z][1] + random(floatround(FishZones[z][3]*2)) - FishZones[z][3];
            FishData[i][fhZ] = FishZones[z][2];
            FishData[i][fhPickupID] = CreatePickup(1254, 1,
                FishData[i][fhX], FishData[i][fhY], FishData[i][fhZ], -1);
            FishCount++;
        }
    }
    new msg[64];
    format(msg, sizeof(msg), "[HuntFish] %d pesti spawnati.", FishCount);
    print(msg);
}

// ============================================================
//  VANATOARE
// ============================================================

stock HuntingFishing_OnEnterArea(playerid, areaid)
{
    // Verificam daca e zona de vanatoare sau pescuit
    for(new i = 0; i < sizeof(HuntZones); i++)
    {
        if(HuntZoneIDs[i] == areaid)
        {
            SendMsg(playerid, COLOR_YELLOW, "[Vanatoare] Ai intrat intr-o zona de vanatoare! Foloseste /hunt pentru a vana.");
            return;
        }
    }
    for(new i = 0; i < sizeof(FishZones); i++)
    {
        if(FishZoneIDs[i] == areaid)
        {
            SendMsg(playerid, COLOR_YELLOW, "[Pescuit] Ai intrat intr-o zona de pescuit! Foloseste /fish pentru a pescui.");
            return;
        }
    }
}

stock HuntingFishing_IsInHuntZone(playerid)
{
    new Float:px, Float:py, Float:pz;
    GetPlayerPos(playerid, px, py, pz);
    for(new i = 0; i < sizeof(HuntZones); i++)
    {
        if(VectorSize(px-HuntZones[i][0], py-HuntZones[i][1], 0.0) < HuntZones[i][3])
            return 1;
    }
    return 0;
}

stock HuntingFishing_IsInFishZone(playerid)
{
    new Float:px, Float:py, Float:pz;
    GetPlayerPos(playerid, px, py, pz);
    for(new i = 0; i < sizeof(FishZones); i++)
    {
        if(VectorSize(px-FishZones[i][0], py-FishZones[i][1], 0.0) < FishZones[i][3])
            return 1;
    }
    return 0;
}

stock GetNearestAnimal(playerid)
{
    new Float:px, Float:py, Float:pz;
    GetPlayerPos(playerid, px, py, pz);
    new nearest = -1;
    new Float:minDist = 20.0;
    for(new i = 0; i < HuntAnimalCount; i++)
    {
        if(!HuntAnimals[i][haAlive]) continue;
        new Float:d = VectorSize(px-HuntAnimals[i][haX], py-HuntAnimals[i][haY], pz-HuntAnimals[i][haZ]);
        if(d < minDist) { minDist = d; nearest = i; }
    }
    return nearest;
}

// ============================================================
//  COMENZI
// ============================================================

CMD:hunt(playerid, params[])
{
    if(!PlayerData[playerid][pLogged]) return 1;

    if(!HuntingFishing_IsInHuntZone(playerid))
        return SendMsg(playerid, COLOR_ERROR, "[!] Nu esti intr-o zona de vanatoare!");

    // Verifica daca are arma
    if(!GetPlayerWeapon(playerid))
        return SendMsg(playerid, COLOR_ERROR, "[!] Ai nevoie de o arma pentru vanatoare!");

    new animal = GetNearestAnimal(playerid);
    if(animal == -1)
        return SendMsg(playerid, COLOR_ERROR, "[!] Nu sunt animale in apropiere!");

    // Vaneaza
    HuntAnimals[animal][haAlive] = false;
    if(HuntAnimals[animal][haActorID] > 0)
    {
        ApplyActorAnimation(HuntAnimals[animal][haActorID], "PED", "DEAD_JB", 4.1, 0, 1, 1, 1, 0);
    }

    PlayerHuntBag[playerid]++;
    Player_AddXP(playerid, 25);

    SendMsgFmt(playerid, COLOR_SUCCESS,
        "[Vanatoare] Ai vanat un animal! Ai %d animale in geanta. Vinde la /sellhunt.",
        PlayerHuntBag[playerid]);

    // Notifica politia animalelor
    NotifyFaction(FACTION_POLITIE_ANIMALE, COLOR_RED,
        "[Politia Animalelor] ATENTIE: S-a detectat activitate de vanatoare ilegala!");
    return 1;
}

CMD:sellhunt(playerid, params[])
{
    if(!PlayerData[playerid][pLogged]) return 1;
    if(PlayerHuntBag[playerid] == 0)
        return SendMsg(playerid, COLOR_ERROR, "[!] Nu ai animale vanate!");

    // Trebuie sa fie la "piata neagra" (zona speciala)
    // Simplificat: oricand
    new reward = PlayerHuntBag[playerid] * 800;
    GivePlayerMoney(playerid, reward);
    PlayerData[playerid][pMoney] += reward;
    Player_AddXP(playerid, PlayerHuntBag[playerid] * 15);

    SendMsgFmt(playerid, COLOR_SUCCESS,
        "[Vanatoare] Ai vandut %d animale pentru $%d!",
        PlayerHuntBag[playerid], reward);
    PlayerHuntBag[playerid] = 0;
    return 1;
}

CMD:fish(playerid, params[])
{
    if(!PlayerData[playerid][pLogged]) return 1;

    if(!HuntingFishing_IsInFishZone(playerid))
        return SendMsg(playerid, COLOR_ERROR, "[!] Nu esti intr-o zona de pescuit!");

    // Cauta peste aproape
    new Float:px, Float:py, Float:pz;
    GetPlayerPos(playerid, px, py, pz);
    new nearest = -1;
    new Float:minD = 15.0;

    for(new i = 0; i < FishCount; i++)
    {
        if(!FishData[i][fhAlive]) continue;
        new Float:d = VectorSize(px-FishData[i][fhX], py-FishData[i][fhY], pz-FishData[i][fhZ]);
        if(d < minD) { minD = d; nearest = i; }
    }

    if(nearest == -1)
        return SendMsg(playerid, COLOR_ERROR, "[!] Nu sunt pesti in apropiere! Incearca alta zona.");

    FishData[nearest][fhAlive] = false;
    if(FishData[nearest][fhPickupID] > 0)
    {
        DestroyPickup(FishData[nearest][fhPickupID]);
        FishData[nearest][fhPickupID] = 0;
    }

    PlayerFishBag[playerid]++;
    Player_AddXP(playerid, 15);

    SendMsgFmt(playerid, COLOR_SUCCESS,
        "[Pescuit] Ai prins un peste! Ai %d pesti in geanta. Vinde cu /sellfish.",
        PlayerFishBag[playerid]);

    NotifyFaction(FACTION_POLITIE_ANIMALE, COLOR_ORANGE,
        "[Politia Animalelor] Activitate de pescuit ilegal detectata!");
    return 1;
}

CMD:sellfish(playerid, params[])
{
    if(!PlayerData[playerid][pLogged]) return 1;
    if(PlayerFishBag[playerid] == 0)
        return SendMsg(playerid, COLOR_ERROR, "[!] Nu ai pesti prinsi!");

    new reward = PlayerFishBag[playerid] * 400;
    GivePlayerMoney(playerid, reward);
    PlayerData[playerid][pMoney] += reward;
    Player_AddXP(playerid, PlayerFishBag[playerid] * 10);

    SendMsgFmt(playerid, COLOR_SUCCESS,
        "[Pescuit] Ai vandut %d pesti pentru $%d!",
        PlayerFishBag[playerid], reward);
    PlayerFishBag[playerid] = 0;
    return 1;
}

// Verificare politia animalelor - numar animale in zona
CMD:checkhuntzone(playerid, params[])
{
    if(PlayerData[playerid][pFaction] != FACTION_POLITIE_ANIMALE)
        return SendMsg(playerid, COLOR_ERROR, "[!] Nu ai permisiunea!");

    new info[512];
    for(new z = 0; z < sizeof(HuntZones); z++)
    {
        new alive = 0;
        for(new i = 0; i < HuntAnimalCount; i++)
        {
            if(HuntAnimals[i][haZone] == z && HuntAnimals[i][haAlive]) alive++;
        }
        new line[64];
        format(line, sizeof(line), "Zona %d: %d animale vii\n", z+1, alive);
        strcat(info, line);
    }
    ShowPlayerDialog(playerid, 9999, DIALOG_STYLE_MSGBOX,
        "{FFD700}Stare Zone Vanatoare", info, "Inchide", "");
    return 1;
}
