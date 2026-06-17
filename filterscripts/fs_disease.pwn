// ============================================================
//  FS_DISEASE - Sistem Boli
// ============================================================
#define FILTERSCRIPT

#include <a_samp>
#include <a_mysql>
#include <sscanf2>
#include <zcmd>

#include "../include/config.inc"
#include "../include/db.inc"
#include "../include/utils.inc"
#include "../include/player.inc"
#include "../include/disease.inc"

public OnFilterScriptInit()
{
    print("[FS] Disease incarcat.");
    return 1;
}

public OnFilterScriptExit()
{
    print("[FS] Disease descarcat.");
    return 1;
}

public OnPlayerConnect(playerid)
{
    DiseaseDecayTimer[playerid] = 0;
    return 1;
}

public OnPlayerDisconnect(playerid, reason)
{
    Disease_StopDecay(playerid);
    return 1;
}
