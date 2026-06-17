// ============================================================
//  FS_PAYDAY - Sistem Payday
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
#include "../include/jobs.inc"
#include "../include/mafia.inc"
#include "../include/payday.inc"

public OnFilterScriptInit()
{
    Payday_Init();
    print("[FS] Payday incarcat.");
    return 1;
}

public OnFilterScriptExit()
{
    print("[FS] Payday descarcat.");
    return 1;
}
