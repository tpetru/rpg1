// ============================================================
//  lang.inc - suport multi-language pentru gamemode
// ------------------------------------------------------------
//  Ideea: textul ENGLEZ din sursa E cheia. Nu se inventeaza ID-uri.
//  Fiecare mesaj trimis catre un player trece prin SCM()/SPD()/T(),
//  care cauta textul original intr-un hash table incarcat din
//  scriptfiles/lang/<cod>.txt si il inlocuieste cu traducerea.
//
//  Daca nu exista traducere -> se afiseaza textul original (engleza).
//  Deci scriptul functioneaza corect si cu fisierul de limba gol.
//
//  Fisier de limba (scriptfiles/lang/ro.txt), 2 linii per intrare:
//      en:{EF6F6C}Error: {E3E3E3}You must be logged in.
//      ro:{EF6F6C}Eroare: {E3E3E3}Trebuie sa fii logat.
//  - "\n" (backslash + n) in fisier = linie noua reala in joc
//  - "\\" = backslash literal
//  - liniile goale si cele care incep cu '#' sunt ignorate
//  - "ro:" gol = fara traducere (ramane engleza)
// ============================================================

#if defined _lang_included
    #endinput
#endif
#define _lang_included

// ---- Limbile suportate. Index 0 = limba sursa (engleza, fara lookup) ----
#define LANG_TOTAL          2
#define LANG_TR_COUNT       (LANG_TOTAL - 1)

// ---- Dimensiuni interne ----
#define LANG_HASH_SIZE      16384   // sloturi hash / limba (putere a lui 2, load factor mic)
#define LANG_POOL_SIZE      240000  // celule pentru textele traduse (packed: 4 caractere/celula)
#define LANG_MAX_LINE       6144    // lungime maxima a unei linii din fisierul de limba (paginile /howto sunt lungi)
#define LANG_TBUF_SIZE      2048    // buffer returnat de T()
#define LANG_DIALOG_SIZE    6144    // buffer pentru corpul unui dialog tradus (vezi SPD)
#define LANG_TBUF_COUNT     4       // cate buffere rotative are T()

// Pune 1 ca sa scrie in scriptfiles/lang/missing_<cod>.txt fiecare text
// fara traducere (util cand completezi fisierul; incetineste serverul)
#define LANG_LOG_MISSING    0

new const g_LangCode[LANG_TOTAL][4] = { "en", "ro" };

static g_LangH1  [LANG_TR_COUNT][LANG_HASH_SIZE];
static g_LangH2  [LANG_TR_COUNT][LANG_HASH_SIZE];
static g_LangOff [LANG_TR_COUNT][LANG_HASH_SIZE];
static g_LangPool[LANG_POOL_SIZE];
static g_LangPoolUsed = 0;
static g_LangEntries[LANG_TR_COUNT];
static bool:g_LangReady = false;

static g_TBuf[LANG_TBUF_COUNT][LANG_TBUF_SIZE];
static g_TBufIdx = 0;

new g_PlayerLang[MAX_PLAYERS];

// ============================================================
//  HASH
// ============================================================
static Lang_Hash(const src[], seed)
{
    new h = seed;
    for(new i = 0; src[i] != EOS; i++)
        h = (h * 33) ^ src[i];
    return h;
}

// ============================================================
//  POOL DE STRINGURI (packed, 4 caractere per celula)
// ============================================================
static Lang_PoolStore(const src[])
{
    new cells = (strlen(src) + 4) / 4;
    if(g_LangPoolUsed + cells > LANG_POOL_SIZE) return -1;

    new off = g_LangPoolUsed;
    strpack(g_LangPool[off], src, cells);
    g_LangPoolUsed += cells;
    return off;
}

// ============================================================
//  INSERARE / CAUTARE
// ============================================================
static Lang_Insert(t, const key[], const value[])
{
    new h1 = Lang_Hash(key, 5381);
    new h2 = Lang_Hash(key, 0x811C9DC5);
    new idx = (h1 & 0x7FFFFFFF) % LANG_HASH_SIZE;

    for(new probe = 0; probe < LANG_HASH_SIZE; probe++)
    {
        if(g_LangOff[t][idx] == -1)
        {
            new off = Lang_PoolStore(value);
            if(off == -1) return 0;

            g_LangH1 [t][idx] = h1;
            g_LangH2 [t][idx] = h2;
            g_LangOff[t][idx] = off;
            g_LangEntries[t]++;
            return 1;
        }
        // duplicat -> pastreaza prima intrare
        if(g_LangH1[t][idx] == h1 && g_LangH2[t][idx] == h2) return 0;

        idx = (idx + 1) % LANG_HASH_SIZE;
    }
    return 0;
}

// Cauta traducerea textului `src` in limba `lang` (1..LANG_TOTAL-1).
// Returneaza 1 si completeaza `dest` daca a gasit, altfel 0.
stock Lang_Find(lang, const src[], dest[], destSize = sizeof(dest))
{
    if(!g_LangReady || lang <= 0 || lang >= LANG_TOTAL) return 0;

    new t = lang - 1;
    if(g_LangEntries[t] == 0) return 0;

    new h1 = Lang_Hash(src, 5381);
    new h2 = Lang_Hash(src, 0x811C9DC5);
    new idx = (h1 & 0x7FFFFFFF) % LANG_HASH_SIZE;

    for(new probe = 0; probe < LANG_HASH_SIZE; probe++)
    {
        if(g_LangOff[t][idx] == -1) return 0;
        if(g_LangH1[t][idx] == h1 && g_LangH2[t][idx] == h2)
        {
            strunpack(dest, g_LangPool[ g_LangOff[t][idx] ], destSize);
            return 1;
        }
        idx = (idx + 1) % LANG_HASH_SIZE;
    }
    return 0;
}

// ============================================================
//  NIVEL 2: POTRIVIRE PE TIPAR
// ------------------------------------------------------------
//  Unele mesaje sunt compuse cu format() intr-un loc si trimise in altul
//  (anunturi difuzate prin functii ajutatoare), deci nu pot trece prin T().
//  Pentru ele pastram sablonul ("...%s a cucerit teritoriul %d...") si, cand
//  cautarea exacta esueaza, incercam sa potrivim mesajul gata formatat cu un
//  sablon cunoscut, extragem valorile si le punem in sablonul tradus.
// ============================================================
#define LANG_PAT_SIZE       4096
#define LANG_PAT_MAXARGS    8
#define LANG_PAT_ARGLEN     160
#define LANG_PAT_KEYLEN     10      // cate caractere de la inceput formeaza cheia
#define LANG_PAT_WILD       64      // sabloane care incep cu un %... (cautare liniara)

static g_PatSrc [LANG_TR_COUNT][LANG_PAT_SIZE];
static g_PatDst [LANG_TR_COUNT][LANG_PAT_SIZE];
static g_PatWild[LANG_TR_COUNT][LANG_PAT_WILD];
static g_PatWildN[LANG_TR_COUNT];

// Lungimea unui specificator de format care incepe la src[i], sau 0 daca nu e unul.
static Lang_SpecLen(const src[], i)
{
    if(src[i] != '%') return 0;
    new j = i + 1;
    if(src[j] == '%') return 0;                     // "%%" = procent literal
    // fara spatiu si fara '#': format() din SA-MP nu le suporta, iar daca le-am accepta,
    // un text ca "75% back" ar fi confundat cu un specificator
    while(src[j] != EOS && (src[j] == '-' || src[j] == '+' || src[j] == '.' ||
          (src[j] >= '0' && src[j] <= '9'))) j++;
    if(src[j] == EOS) return 0;
    if((src[j] >= 'a' && src[j] <= 'z') || (src[j] >= 'A' && src[j] <= 'Z')) return (j - i) + 1;
    return 0;
}

static Lang_PatArgCount(const src[])
{
    new n = 0;
    for(new i = 0; src[i] != EOS; i++)
    {
        if(src[i] != '%') continue;
        new sl = Lang_SpecLen(src, i);
        if(sl) { n++; i += sl - 1; }
        else if(src[i + 1] == '%') i++;
    }
    return n;
}

// Are sablonul doua specificatoare lipite (imposibil de despartit la potrivire)?
static bool:Lang_PatAmbiguous(const src[])
{
    new i = 0;
    while(src[i] != EOS)
    {
        new sl = Lang_SpecLen(src, i);
        if(sl)
        {
            i += sl;
            if(Lang_SpecLen(src, i)) return true;   // %s%d - fara text intre ele
            continue;
        }
        i++;
    }
    return false;
}

// Pozitia primului specificator (sau strlen daca nu exista)
static Lang_PatPrefixLen(const src[])
{
    for(new i = 0; src[i] != EOS; i++)
        if(Lang_SpecLen(src, i)) return i;
    return strlen(src);
}

static Lang_PatKeyHash(const src[])
{
    new h = 5381;
    for(new i = 0; i < LANG_PAT_KEYLEN && src[i] != EOS; i++) h = (h * 33) ^ src[i];
    return h;
}

static Lang_PatInsert(t, const pat[], const tr[])
{
    if(Lang_PatArgCount(pat) == 0) return 0;
    if(Lang_PatArgCount(pat) != Lang_PatArgCount(tr)) return 0;
    if(Lang_PatArgCount(pat) > LANG_PAT_MAXARGS) return 0;
    if(Lang_PatAmbiguous(pat) || Lang_PatAmbiguous(tr)) return 0;

    new so = Lang_PoolStore(pat); if(so == -1) return 0;
    new dof = Lang_PoolStore(tr); if(dof == -1) return 0;

    if(Lang_PatPrefixLen(pat) < LANG_PAT_KEYLEN)
    {
        // incepe (aproape) cu un specificator -> lista liniara
        if(g_PatWildN[t] >= LANG_PAT_WILD) return 0;
        g_PatWild[t][ g_PatWildN[t] ] = so;
        g_PatDst [t][ g_PatWildN[t] + LANG_PAT_SIZE - LANG_PAT_WILD ] = dof;
        g_PatWildN[t]++;
        return 1;
    }

    new idx = (Lang_PatKeyHash(pat) & 0x7FFFFFFF) % (LANG_PAT_SIZE - LANG_PAT_WILD);
    for(new probe = 0; probe < LANG_PAT_SIZE - LANG_PAT_WILD; probe++)
    {
        if(g_PatSrc[t][idx] == -1)
        {
            g_PatSrc[t][idx] = so;
            g_PatDst[t][idx] = dof;
            return 1;
        }
        idx = (idx + 1) % (LANG_PAT_SIZE - LANG_PAT_WILD);
    }
    return 0;
}

// Potriveste `src` cu sablonul `pat`; pune valorile capturate in caps[].
static bool:Lang_PatMatch(const pat[], const src[], caps[][], &capCount)
{
    capCount = 0;
    new pi = 0, si = 0;

    while(pat[pi] != EOS)
    {
        new sl = Lang_SpecLen(pat, pi);
        if(sl)
        {
            pi += sl;
            // textul literal care urmeaza dupa specificator, pana la urmatorul specificator
            new lit[128], ll = 0;
            while(pat[pi] != EOS && !Lang_SpecLen(pat, pi) && ll < 127)
            {
                if(pat[pi] == '%' && pat[pi + 1] == '%') pi++;
                lit[ll++] = pat[pi++];
            }
            lit[ll] = EOS;

            if(capCount >= LANG_PAT_MAXARGS) return false;

            new stop;
            if(ll == 0) stop = strlen(src);          // specificator la final
            else
            {
                stop = -1;
                for(new k = si; src[k] != EOS; k++)
                {
                    new m = 0;
                    while(m < ll && src[k + m] == lit[m]) m++;
                    if(m == ll) { stop = k; break; }
                }
                if(stop == -1) return false;
            }

            new cl = stop - si;
            if(cl < 0 || cl >= LANG_PAT_ARGLEN) return false;
            for(new k = 0; k < cl; k++) caps[capCount][k] = src[si + k];
            caps[capCount][cl] = EOS;
            capCount++;

            si = stop + ll;
            continue;
        }

        if(pat[pi] == '%' && pat[pi + 1] == '%') pi++;
        if(src[si] != pat[pi]) return false;
        pi++; si++;
    }
    return (src[si] == EOS);
}

static Lang_PatBuild(const tr[], const caps[][], capCount, dest[], destSize)
{
    new p = 0, ci = 0;
    for(new i = 0; tr[i] != EOS && p < destSize - 1; )
    {
        new sl = Lang_SpecLen(tr, i);
        if(sl)
        {
            if(ci >= capCount) return 0;
            for(new k = 0; caps[ci][k] != EOS && p < destSize - 1; k++) dest[p++] = caps[ci][k];
            ci++;
            i += sl;
            continue;
        }
        if(tr[i] == '%' && tr[i + 1] == '%') i++;
        dest[p++] = tr[i++];
    }
    dest[p] = EOS;
    return 1;
}

// Incearca sa traduca un mesaj deja formatat. 1 = a reusit.
stock Lang_FindPattern(lang, const src[], dest[], destSize = sizeof(dest))
{
    if(!g_LangReady || lang <= 0 || lang >= LANG_TOTAL) return 0;
    new t = lang - 1;

    static pat[LANG_TBUF_SIZE], tr[LANG_TBUF_SIZE];
    static caps[LANG_PAT_MAXARGS][LANG_PAT_ARGLEN];
    new capCount;

    new idx = (Lang_PatKeyHash(src) & 0x7FFFFFFF) % (LANG_PAT_SIZE - LANG_PAT_WILD);
    for(new probe = 0; probe < LANG_PAT_SIZE - LANG_PAT_WILD; probe++)
    {
        if(g_PatSrc[t][idx] == -1) break;
        strunpack(pat, g_LangPool[ g_PatSrc[t][idx] ], sizeof(pat));
        if(Lang_PatMatch(pat, src, caps, capCount))
        {
            strunpack(tr, g_LangPool[ g_PatDst[t][idx] ], sizeof(tr));
            if(Lang_PatBuild(tr, caps, capCount, dest, destSize)) return 1;
        }
        idx = (idx + 1) % (LANG_PAT_SIZE - LANG_PAT_WILD);
    }

    for(new w = 0; w < g_PatWildN[t]; w++)
    {
        strunpack(pat, g_LangPool[ g_PatWild[t][w] ], sizeof(pat));
        if(!Lang_PatMatch(pat, src, caps, capCount)) continue;
        strunpack(tr, g_LangPool[ g_PatDst[t][w + LANG_PAT_SIZE - LANG_PAT_WILD] ], sizeof(tr));
        if(Lang_PatBuild(tr, caps, capCount, dest, destSize)) return 1;
    }
    return 0;
}

#if LANG_LOG_MISSING == 1
static Lang_LogMissing(lang, const src[])
{
    new path[48];
    format(path, sizeof(path), "lang/missing_%s.txt", g_LangCode[lang]);

    new File:f = fopen(path, io_append);
    if(!f) return;

    new line[LANG_MAX_LINE];
    new p = 0;
    for(new i = 0; src[i] != EOS && p < LANG_MAX_LINE - 4; i++)
    {
        if(src[i] == '\\')      { line[p++] = '\\'; line[p++] = '\\'; }
        else if(src[i] == '\n') { line[p++] = '\\'; line[p++] = 'n';  }
        else                      line[p++] = src[i];
    }
    line[p] = EOS;

    fwrite(f, "en:");
    fwrite(f, line);
    fwrite(f, "\r\nro:\r\n");
    fclose(f);
}
#endif

// ============================================================
//  INCARCARE FISIERE DE LIMBA
// ============================================================
static Lang_Unescape(dest[], const src[], destSize)
{
    new p = 0;
    for(new i = 0; src[i] != EOS && p < destSize - 1; i++)
    {
        if(src[i] == '\\' && src[i + 1] != EOS)
        {
            i++;
            switch(src[i])
            {
                case 'n': dest[p++] = '\n';
                case 't': dest[p++] = '\t';
                case 'r': dest[p++] = '\r';
                case '\\': dest[p++] = '\\';
                default:  { dest[p++] = '\\'; if(p < destSize - 1) dest[p++] = src[i]; }
            }
        }
        else dest[p++] = src[i];
    }
    dest[p] = EOS;
}

static Lang_TrimEol(str[])
{
    new len = strlen(str);
    while(len > 0 && (str[len - 1] == '\n' || str[len - 1] == '\r')) str[--len] = EOS;
}

static Lang_LoadFile(lang)
{
    new t = lang - 1;
    new path[32];
    format(path, sizeof(path), "lang/%s.txt", g_LangCode[lang]);

    new File:f = fopen(path, io_read);
    if(!f)
    {
        printf("[lang] Fisierul scriptfiles/%s nu exista - limba '%s' ramane netradusa.", path, g_LangCode[lang]);
        return;
    }

    // static: 3 x LANG_MAX_LINE ar depasi stiva daca ar fi locale
    static line[LANG_MAX_LINE], key[LANG_MAX_LINE], val[LANG_MAX_LINE];
    new bool:haveKey = false;
    new skipped = 0, patterns = 0;

    key[0] = EOS;

    while(fread(f, line, sizeof(line)))
    {
        Lang_TrimEol(line);

        if(line[0] == EOS || line[0] == '#') continue;

        // orice linie valida are forma "xx:text" (xx = cod de limba)
        if(strlen(line) < 3 || line[2] != ':') { skipped++; continue; }

        if(line[0] == 'e' && line[1] == 'n')
        {
            Lang_Unescape(key, line[3], sizeof(key));
            haveKey = (key[0] != EOS);
            continue;
        }

        // linie de traducere
        if(!haveKey) { skipped++; continue; }

        Lang_Unescape(val, line[3], sizeof(val));
        if(val[0] != EOS)
        {
            if(!Lang_Insert(t, key, val)) skipped++;
            if(Lang_PatInsert(t, key, val)) patterns++;
        }
        haveKey = false;
    }
    fclose(f);

    printf("[lang] '%s': %d traduceri (%d sabloane, %d ignorate), pool %d/%d celule.",
        g_LangCode[lang], g_LangEntries[t], patterns, skipped, g_LangPoolUsed, LANG_POOL_SIZE);
}

// Apelat o singura data din OnGameModeInit()
stock Lang_Load()
{
    for(new t = 0; t < LANG_TR_COUNT; t++)
    {
        g_LangEntries[t] = 0;
        for(new i = 0; i < LANG_HASH_SIZE; i++) g_LangOff[t][i] = -1;
        for(new i = 0; i < LANG_PAT_SIZE; i++) { g_PatSrc[t][i] = -1; g_PatDst[t][i] = -1; }
        g_PatWildN[t] = 0;
    }
    g_LangPoolUsed = 0;
    g_LangReady = true;

    for(new l = 1; l < LANG_TOTAL; l++) Lang_LoadFile(l);

    for(new i = 0; i < MAX_PLAYERS; i++) g_PlayerLang[i] = 0;
    return 1;
}

// ============================================================
//  LIMBA JUCATORULUI
// ============================================================
stock Lang_SetPlayer(playerid, const code[])
{
    if(playerid < 0 || playerid >= MAX_PLAYERS) return 0;

    for(new l = 0; l < LANG_TOTAL; l++)
    {
        if(!strcmp(code, g_LangCode[l], true))
        {
            g_PlayerLang[playerid] = l;
            return 1;
        }
    }
    g_PlayerLang[playerid] = 0;
    return 0;
}

stock Lang_Of(playerid)
{
    if(playerid < 0 || playerid >= MAX_PLAYERS) return 0;
    return g_PlayerLang[playerid];
}

stock Lang_Reset(playerid)
{
    if(playerid >= 0 && playerid < MAX_PLAYERS) g_PlayerLang[playerid] = 0;
    return 1;
}

// ============================================================
//  T() - traduce un text (de obicei un format-string) pentru un player
//  Folosire: format(msg, sizeof(msg), T(playerid, "You got %d$."), x);
// ============================================================
stock T(playerid, const src[])
{
    g_TBufIdx = (g_TBufIdx + 1) % LANG_TBUF_COUNT;
    new i = g_TBufIdx;
    g_TBuf[i][0] = EOS;

    new lang = (playerid >= 0 && playerid < MAX_PLAYERS) ? g_PlayerLang[playerid] : 0;
    if(lang > 0 && Lang_Find(lang, src, g_TBuf[i], LANG_TBUF_SIZE)) return g_TBuf[i];

    #if LANG_LOG_MISSING == 1
        if(lang > 0) Lang_LogMissing(lang, src);
    #endif

    strcat(g_TBuf[i], src, LANG_TBUF_SIZE);
    return g_TBuf[i];
}

// Acelasi lucru, dar cu index de limba explicit (pentru mesaje globale)
stock TL(lang, const src[])
{
    g_TBufIdx = (g_TBufIdx + 1) % LANG_TBUF_COUNT;
    new i = g_TBufIdx;
    g_TBuf[i][0] = EOS;

    if(lang > 0 && Lang_Find(lang, src, g_TBuf[i], LANG_TBUF_SIZE)) return g_TBuf[i];

    strcat(g_TBuf[i], src, LANG_TBUF_SIZE);
    return g_TBuf[i];
}

// ============================================================
//  WRAPPERE peste nativele de afisare
// ============================================================
// ============================================================
//  Chat_Send - trimite un mesaj de chat, spart automat in mai multe linii daca depaseste limita.
//  SendClientMessage nu afiseaza mesajele peste 144 de caractere (se taie sau dispar), iar traducerile
//  (RO) sunt mai lungi decat engleza si textele cu %s se maresc la runtime. Orice mesaj trecut prin SCM()
//  e deci impartit la ultimul spatiu dintr-o fereastra de CHAT_MAX_LEN caractere; ultima culoare {RRGGBB}
//  folosita se repeta la inceputul liniei urmatoare, iar un cod de culoare nu e taiat la jumatate.
// ============================================================
#define CHAT_MAX_LEN 140

stock Chat_IsHex(c)
{
    return (c >= '0' && c <= '9') || (c >= 'A' && c <= 'F') || (c >= 'a' && c <= 'f');
}

// Daca text[pos..pos+7] este un cod {RRGGBB}, returneaza true
stock bool:Chat_IsColorAt(const text[], pos, len)
{
    if(pos < 0 || pos + 8 > len || text[pos] != '{' || text[pos + 7] != '}') return false;
    for(new k = 1; k <= 6; k++) if(!Chat_IsHex(text[pos + k])) return false;
    return true;
}

stock Chat_Send(playerid, color, const msg[])
{
    new len = strlen(msg);
    if(len <= CHAT_MAX_LEN) return SendClientMessage(playerid, color, msg);

    new pos = 0, lastColor[9], chunk[CHAT_MAX_LEN + 16], piece[CHAT_MAX_LEN + 1];
    lastColor[0] = EOS;
    new guard = 0;

    while(pos < len && guard++ < 12)
    {
        new prefixLen = lastColor[0] ? 8 : 0;
        new room = CHAT_MAX_LEN - prefixLen;
        new remaining = len - pos;
        new take = (remaining <= room) ? remaining : room;

        if(remaining > room)
        {
            // taie la ultimul spatiu din fereastra (in a doua jumatate a ei), ca sa nu rupa cuvinte
            new cut = -1;
            for(new k = take; k > take / 2; k--)
                if(msg[pos + k] == ' ') { cut = k; break; }
            if(cut != -1) take = cut;

            // nu taia un cod {RRGGBB} la jumatate: daca limita cade in interiorul lui, taie inainte de el
            for(new k = take - 1; k >= 0 && k >= take - 7; k--)
            {
                if(msg[pos + k] == '}') break;
                if(msg[pos + k] == '{' && !Chat_IsColorAt(msg, pos + k, pos + take) && Chat_IsColorAt(msg, pos + k, len)) { take = k; break; }
            }
            if(take <= 0) take = room;
        }

        strmid(piece, msg, pos, pos + take, sizeof(piece));

        // linia = culoarea ramasa de la linia anterioara + textul
        chunk[0] = EOS;
        if(lastColor[0]) strcat(chunk, lastColor, sizeof(chunk));
        strcat(chunk, piece, sizeof(chunk));
        SendClientMessage(playerid, color, chunk);

        // retine ultima culoare folosita pana aici
        new plen = strlen(piece);
        for(new k = 0; k < plen; k++)
            if(Chat_IsColorAt(piece, k, plen)) { strmid(lastColor, piece, k, k + 8, sizeof(lastColor)); }

        pos += take;
        while(pos < len && msg[pos] == ' ') pos++;   // spatiul de la taietura nu se repeta
    }
    return 1;
}

stock SCM(playerid, color, const msg[])
{
    if(playerid < 0 || playerid >= MAX_PLAYERS || g_PlayerLang[playerid] == 0)
        return Chat_Send(playerid, color, msg);

    new out[256];   // SendClientMessage e limitat la 144 caractere oricum
    if(Lang_Find(g_PlayerLang[playerid], msg, out, sizeof(out)))
        return Chat_Send(playerid, color, out);

    // mesaj deja formatat -> incearca potrivirea pe sablon
    if(Lang_FindPattern(g_PlayerLang[playerid], msg, out, sizeof(out)))
        return Chat_Send(playerid, color, out);

    #if LANG_LOG_MISSING == 1
        Lang_LogMissing(g_PlayerLang[playerid], msg);
    #endif

    return Chat_Send(playerid, color, msg);
}

stock SCMToAll(color, const msg[])
{
    for(new i = 0; i < MAX_PLAYERS; i++)
    {
        if(!IsPlayerConnected(i)) continue;
        SCM(i, color, msg);
    }
    return 1;
}

// Nota: parametrii NU sunt `const` pentru ca nativul ShowPlayerDialog din a_samp
// nu ii declara `const` -> altfel apare "argument type mismatch".
stock SPD(playerid, dialogid, style, caption[], info[], button1[], button2[])
{
    if(playerid < 0 || playerid >= MAX_PLAYERS || g_PlayerLang[playerid] == 0)
        return ShowPlayerDialog(playerid, dialogid, style, caption, info, button1, button2);

    new lang = g_PlayerLang[playerid];
    new cap[128], b1[32], b2[32];
    static body[LANG_DIALOG_SIZE];

    if(!Lang_Find(lang, caption, cap, sizeof(cap))) { cap[0] = EOS; strcat(cap, caption, sizeof(cap)); }
    if(!Lang_Find(lang, button1, b1, sizeof(b1)))   { b1[0]  = EOS; strcat(b1,  button1, sizeof(b1));  }
    if(!Lang_Find(lang, button2, b2, sizeof(b2)))   { b2[0]  = EOS; strcat(b2,  button2, sizeof(b2));  }

    if(Lang_Find(lang, info, body, sizeof(body)) || Lang_FindPattern(lang, info, body, sizeof(body)))
        return ShowPlayerDialog(playerid, dialogid, style, cap, body, b1, b2);

    return ShowPlayerDialog(playerid, dialogid, style, cap, info, b1, b2);
}

stock GTP(playerid, const text[], time, style)
{
    if(playerid < 0 || playerid >= MAX_PLAYERS || g_PlayerLang[playerid] == 0)
        return GameTextForPlayer(playerid, text, time, style);

    new out[256];
    if(Lang_Find(g_PlayerLang[playerid], text, out, sizeof(out)))
        return GameTextForPlayer(playerid, out, time, style);

    return GameTextForPlayer(playerid, text, time, style);
}
