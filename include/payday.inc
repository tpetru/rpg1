// ============================================================
//  PAYDAY.INC - Sistem Payday la 30 minute
//  Salariu, impozit presedinte, CASS, taxe casa, decay pets
//  La ora 00:00: payday mafia (teritorii)
// ============================================================
#if defined _payday_included
    #endinput
#endif
#define _payday_included

new PaydayTimer;
new PaydayCount = 0; // cate payday-uri au trecut (pentru debug/midnight check)

// ============================================================
//  INIT
// ============================================================

stock Payday_Init()
{
    PaydayTimer = SetTimer("Payday_Execute", PAYDAY_INTERVAL, true);
    print("[Payday] Timer payday setat (30 minute).");
}

// ============================================================
//  EXECUTE PAYDAY
// ============================================================

forward Payday_Execute();
public Payday_Execute()
{
    PaydayCount++;
    new h = GetServerHour();

    SendMsgAll(COLOR_GOLD,
        "[{FFD700}PAYDAY{FFFFFF}] A venit payday-ul! Toti jucatorii logati primesc salariul.");

    for(new i = 0; i < MAX_PLAYERS; i++)
    {
        if(!IsPlayerConnected(i) || !PlayerData[i][pLogged]) continue;
        Payday_GivePlayer(i);
    }

    // La ora 00:00 -> payday mafia teritorii
    if(h == 0)
    {
        Mafia_TerritoryPayday();
        SendMsgAll(COLOR_ORANGE,
            "[MAFIA] Mafiile au primit veniturile din teritorii!");
    }

    // Respawn animale si pesti la fiecare payday
    HuntingFishing_SpawnAll();
}

// ============================================================
//  PAYDAY PER PLAYER
// ============================================================

stock Payday_GivePlayer(playerid)
{
    // 1. Calcul salariu brut
    new salary_base = SALARY_BASE + (PlayerData[playerid][pLevel] * SALARY_PER_LEVEL);

    // 2. Bonus job (daca e on duty)
    new job_bonus = 0;
    if(PlayerData[playerid][pOnDuty] && PlayerData[playerid][pJob] != JOB_NONE)
        job_bonus = JobSalaries[PlayerData[playerid][pJob]] / 2;

    new salary_gross = salary_base + job_bonus;

    // 3. Impozit si CASS (setate de presedinte)
    new tax  = (salary_gross * President_GetIncomeTax()) / 100;
    new cass = (salary_gross * President_GetCASS())      / 100;
    new salary_net = salary_gross - tax - cass;
    if(salary_net < 0) salary_net = 0;

    // 4. Venit din afaceri
    new business_income = 0;
    for(new b = 0; b < BusinessCount; b++)
    {
        if(!BusinessData[b][bID]) continue;
        if(BusinessData[b][bOwnerID] == PlayerData[playerid][pID])
            business_income += BusinessData[b][bIncome];
    }

    // 5. Taxe casa
    new house_tax = 0;
    new houseid = GetPlayerOwnedHouse(playerid);
    if(houseid != -1) house_tax = HouseData[houseid][hTaxes];

    // 6. Aplica totul
    new total_in  = salary_net + business_income;
    new total_out = house_tax;

    GivePlayerMoney(playerid, total_in - total_out);
    PlayerData[playerid][pMoney] += (total_in - total_out);
    PlayerData[playerid][pRP]    += RP_PER_PAYDAY;
    Player_AddXP(playerid, 50);

    // 7. Decay animale companie
    Pets_PaydayDecay(playerid);

    // 8. Mesaj detaliat
    new msg[256];
    format(msg, sizeof(msg),
        "[{FFD700}PAYDAY{FFFFFF}] "
        "Salariu brut: {00FF00}$%d{FFFFFF} | "
        "Impozit: {FF4444}-%d%%%FFFFFF} ($%d) | "
        "CASS: {FF4444}-%d%%%FFFFFF} ($%d) | "
        "Net: {00FF00}$%d{FFFFFF}",
        salary_gross,
        President_GetIncomeTax(), tax,
        President_GetCASS(), cass,
        salary_net);
    SendClientMessage(playerid, COLOR_GOLD, msg);

    if(business_income > 0)
        SendMsgFmt(playerid, COLOR_GREEN,
            "[Afaceri] Venit din afaceri: {FFD700}+$%d", business_income);

    if(house_tax > 0)
        SendMsgFmt(playerid, COLOR_ORANGE,
            "[Casa] Taxa de proprietate: {FF4444}-$%d", house_tax);

    SendMsgFmt(playerid, COLOR_YELLOW,
        "[PAYDAY] Total primit: {00FF00}$%d{FFFFFF} | +{00FF00}%d RP{FFFFFF} | +{00FF00}50 XP",
        total_in - total_out, RP_PER_PAYDAY);

    // 9. Salveaza
    Player_SaveData(playerid);
}
