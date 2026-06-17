// ============================================================
//  UTILS.INC - Functii ajutatoare globale
// ============================================================
#if defined _utils_included
    #endinput
#endif
#define _utils_included

#include <a_samp>
#include <md5>

// ---- Hash parola ----
stock HashPassword(const pass[], output[], size = sizeof(output))
{
    new hash[33];
    MD5_Hash(pass, hash, sizeof(hash));
    format(output, size, "%s", hash);
}

// ---- Mesaje colorate ----
stock SendMsg(playerid, color, const msg[])
{
    SendClientMessage(playerid, color, msg);
}

stock SendMsgAll(color, const msg[])
{
    SendClientMessageToAll(color, msg);
}

stock SendMsgFmt(playerid, color, const fmt[], {Float,_}:...)
{
    new msg[256];
    //va_format(msg, sizeof(msg), fmt);
    //vformat(msg, sizeof(str), "%d", value);
    format(msg, sizeof(msg), fmt);
    SendClientMessage(playerid, color, msg);
}

stock SendMsgAllFmt(color, const fmt[], {Float,_}:...)
{
    new msg[256];
    va_format(msg, sizeof(msg), fmt);
    SendClientMessageToAll(color, msg);
}

// ---- Distanta ----
stock Float:GetDistanceBetweenPlayers(p1, p2)
{
    new Float:x1, Float:y1, Float:z1, Float:x2, Float:y2, Float:z2;
    GetPlayerPos(p1, x1, y1, z1);
    GetPlayerPos(p2, x2, y2, z2);
    return VectorSize(x2-x1, y2-y1, z2-z1);
}

stock Float:GetDistanceToPoint(playerid, Float:tx, Float:ty, Float:tz)
{
    new Float:x, Float:y, Float:z;
    GetPlayerPos(playerid, x, y, z);
    return VectorSize(tx-x, ty-y, tz-z);
}

// ---- Formatare bani ----
stock MoneyFormat(amount, output[], size = sizeof(output))
{
    if(amount >= 1000000)
        format(output, size, "%d.%03dkk", amount/1000000, (amount%1000000)/1000);
    else if(amount >= 1000)
        format(output, size, "%d.%03dk", amount/1000, amount%1000);
    else
        format(output, size, "%d", amount);
}

// ---- Formatare timp ----
stock TimeFormat(seconds, output[], size = sizeof(output))
{
    new h = seconds/3600, m = (seconds%3600)/60, s = seconds%60;
    format(output, size, "%02d:%02d:%02d", h, m, s);
}

// ---- Verificare nume valid ----
stock bool:IsValidName(const name[])
{
    new len = strlen(name);
    if(len < 3 || len > 20) return false;
    for(new i = 0; i < len; i++)
    {
        if(!IsCharAlphaNumeric(name[i]) && name[i] != '_') return false;
    }
    return true;
}



// ---- Gametext cu stil ----
stock ShowGameText(playerid, const msg[], time, style)
{
    GameTextForPlayer(playerid, msg, time, style);
}

// ---- Ora actuala server ----
stock GetServerHour()
{
    new h, m, s;
    gettime(h, m, s);
    return h;
}

stock GetServerMinute()
{
    new h, m, s;
    gettime(h, m, s);
    return m;
}

// ---- Zi saptamana (0=Duminica) ----
stock GetWeekDay()
{
    new y, mo, d, h, m, s;
    getdate(y, mo, d);
    gettime(h, m, s);
    // Calcul Zeller simplificat
    if(mo < 3) { mo += 12; y--; }
    new k = y % 100, j = y / 100;
    new f = d + (13*(mo+1)/5) + k + (k/4) + (j/4) - 2*j;
    return ((f % 7) + 7) % 7; // 0=Sambata, 1=Duminica...
}

// ---- Dialog shorthand ----
stock ShowDialog(playerid, dialogid, style, title[], button1[], button2[], info[])
{
    ShowPlayerDialog(playerid, dialogid, style, title, info, button1, button2);
}

// ---- 3D Text Label ----
// Wrapper pentru a crea un label 3D simplu
stock Text3D:Create3DLabel(const text[], color, Float:x, Float:y, Float:z, Float:drawdist, vw, interior)
{
    return Create3DTextLabel(text, color, x, y, z, drawdist, vw, 0);
}

// ---- Pickup helper ----
stock CreateRPGPickup(model, type, Float:x, Float:y, Float:z)
{
    return CreatePickup(model, type, x, y, z, -1);
}

// ---- Anunta toti in raza ----
stock AnnounceInRange(Float:x, Float:y, Float:z, Float:range, color, const msg[])
{
    for(new i = 0; i < MAX_PLAYERS; i++)
    {
        if(!IsPlayerConnected(i)) continue;
        new Float:px, Float:py, Float:pz;
        GetPlayerPos(i, px, py, pz);
        if(VectorSize(px-x, py-y, pz-z) <= range)
            SendClientMessage(i, color, msg);
    }
}


