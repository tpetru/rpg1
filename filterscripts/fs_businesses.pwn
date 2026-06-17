// ============================================================
//  FS_BUSINESSES - Sistem Afaceri
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
#include "../include/businesses.inc"

public OnFilterScriptInit()
{
    Businesses_Init();
    print("[FS] Businesses incarcat.");
    return 1;
}

public OnFilterScriptExit()
{
    print("[FS] Businesses descarcat.");
    return 1;
}

public OnPlayerPickUpPickup(playerid, pickupid)
{
    if(!PlayerData[playerid][pLogged]) return 0;
    for(new i = 0; i < BusinessCount; i++)
    {
        if(BusinessData[i][bPickup] != pickupid) continue;
        if(BusinessData[i][bOwnerID] == PlayerData[playerid][pID])
        {
            new info[128];
            format(info, sizeof(info),
                "{FFD700}%s{FFFFFF}\nProfit per payday: {00FF00}$%d{FFFFFF}\nTaxa: $%d",
                BusinessData[i][bName], BusinessData[i][bIncome], BusinessData[i][bTaxes]);
            ShowPlayerDialog(playerid, 9994, DIALOG_STYLE_MSGBOX, "Afacerea Ta", info, "Inchide", "");
        }
        else if(BusinessData[i][bForSale])
        {
            new info[128];
            format(info, sizeof(info),
                "Cumperi {FFD700}%s{FFFFFF} pentru {00FF00}$%d{FFFFFF}?\nProfit/payday: +$%d",
                BusinessData[i][bName], BusinessData[i][bPrice], BusinessData[i][bIncome]);
            SetPVarInt(playerid, "BuyBizID", i);
            ShowPlayerDialog(playerid, DIALOG_BUSINESS_BUY, DIALOG_STYLE_MSGBOX,
                "Cumpara Afacere", info, "Cumpara", "Anuleaza");
        }
        else
            SendMsg(playerid, COLOR_GREY, "[Afacere] Aceasta afacere nu este de vanzare.");
        return 1;
    }
    return 0;
}

public OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
    return Business_OnDialog(playerid, dialogid, response, listitem, inputtext);
}
