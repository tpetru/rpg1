// ============================================================
//  FS_HOUSES - Sistem Case
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
#include "../include/houses.inc"

public OnFilterScriptInit()
{
    Houses_Init();
    print("[FS] Houses incarcat.");
    return 1;
}

public OnFilterScriptExit()
{
    print("[FS] Houses descarcat.");
    return 1;
}

public OnPlayerPickUpPickup(playerid, pickupid)
{
    if(!PlayerData[playerid][pLogged]) return 1;
    for(new i = 0; i < HouseCount; i++)
    {
        if(HouseData[i][hPickup] != pickupid) continue;
        if(HouseData[i][hOwnerID] == PlayerData[playerid][pID])
            House_ShowMenu(playerid, i);
        else if(HouseData[i][hForSale])
        {
            SetPVarInt(playerid, "BuyHouseID", i);
            new info[128];
            format(info, sizeof(info),
                "Cumperi casa din {FFD700}%s{FFFFFF} pentru {00FF00}$%d{FFFFFF}?",
                HouseData[i][hAddress], HouseData[i][hPrice]);
            ShowPlayerDialog(playerid, DIALOG_HOUSE_BUY, DIALOG_STYLE_MSGBOX,
                "Cumpara Casa", info, "Cumpara", "Anuleaza");
        }
        else
            SendMsg(playerid, COLOR_GREY, "[Casa] Casa privata. Nu este de vanzare.");
        return 1;
    }
    return 0;
}

public OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
    if(!response) return 1;
    switch(dialogid)
    {
        case DIALOG_HOUSE_BUY:
        {
            new houseid = GetPVarInt(playerid, "BuyHouseID");
            if(houseid >= 0 && houseid < HouseCount)
                House_Buy(playerid, houseid);
            return 1;
        }
        case DIALOG_HOUSE_MENU:
        {
            new houseid = GetPlayerOwnedHouse(playerid);
            if(houseid == -1) return 1;
            switch(listitem)
            {
                case 0: House_Enter(playerid, houseid);
                case 1:
                {
                    HouseData[houseid][hLocked] = !HouseData[houseid][hLocked];
                    SendMsgFmt(playerid, COLOR_SUCCESS,
                        "[Casa] Casa %s.", HouseData[houseid][hLocked] ? "incuiata" : "descuiata");
                }
                case 2: SendMsg(playerid, COLOR_YELLOW, "[Casa] Foloseste /pet pentru animale in casa.");
                case 3:
                {
                    HouseData[houseid][hForSale] = 1;
                    new query[128];
                    mysql_format(g_SQL, query, sizeof(query),
                        "UPDATE `houses` SET for_sale=1 WHERE id=%d", HouseData[houseid][hID]);
                    mysql_tquery(g_SQL, query, "", "", 0);
                    SendMsg(playerid, COLOR_SUCCESS, "[Casa] Casa pusa la vanzare!");
                }
                case 4: CallLocalFunction("OnPlayerCommandText", "is", playerid, "/sellhouse");
            }
            return 1;
        }
    }
    return 0;
}
