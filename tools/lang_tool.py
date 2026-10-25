#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Unelte pentru sistemul multi-language al gamemode-ului.

  python tools/lang_tool.py wrap     - rescrie bare.pwn: SendClientMessage->SCM etc.
                                       si imbraca format-stringurile in T(playerid, ...)
  python tools/lang_tool.py extract  - genereaza scriptfiles/lang/ro.txt (schelet)

Textul englez din sursa este cheia de traducere; extract() calculeaza exact
stringul care ajunge in joc (expandeaza C_ERROR/C_INFO/... si #DEFINE-uri).
"""
import os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PWN  = os.path.join(ROOT, "gamemodes", "bare.pwn")

# ---------------------------------------------------------------- lexer utils

def split_args(src, open_idx):
    """src[open_idx] == '('. Returneaza (lista de argumente brute, index dupa ')')."""
    depth = 0
    i = open_idx
    args, start = [], open_idx + 1
    n = len(src)
    while i < n:
        c = src[i]
        if c == '"' or c == "'":
            q = c
            i += 1
            while i < n:
                if src[i] == '\\':
                    i += 2
                    continue
                if src[i] == q:
                    break
                i += 1
        elif c in '([{':
            depth += 1
        elif c in ')]}':
            depth -= 1
            if depth == 0:
                args.append(src[start:i])
                return args, i + 1
        elif c == ',' and depth == 1:
            args.append(src[start:i])
            start = i + 1
        elif c == '/' and i + 1 < n and src[i + 1] == '/':
            while i < n and src[i] != '\n':
                i += 1
            continue
        i += 1
    return None, open_idx


def find_calls(src, name):
    """Toate aparitiile `name(` care nu sunt in comentariu/string. Yield (start, open_idx)."""
    pat = re.compile(r'(?<![A-Za-z0-9_])' + re.escape(name) + r'\s*\(')
    for m in pat.finditer(src):
        yield m.start(), m.end() - 1


def strip_comments_mask(src):
    """Returneaza un bytearray-mask: 1 daca pozitia e cod real, 0 daca e comentariu/string."""
    mask = bytearray(b'\x01' * len(src))
    i, n = 0, len(src)
    while i < n:
        c = src[i]
        if c == '/' and i + 1 < n and src[i + 1] == '/':
            while i < n and src[i] != '\n':
                mask[i] = 0
                i += 1
        elif c == '/' and i + 1 < n and src[i + 1] == '*':
            while i < n and not (src[i] == '*' and i + 1 < n and src[i + 1] == '/'):
                mask[i] = 0
                i += 1
            mask[i] = 0
            if i + 1 < n:
                mask[i + 1] = 0
            i += 2
        elif c == '"' or c == "'":
            q = c
            mask[i] = 0
            i += 1
            while i < n:
                if src[i] == '\\':
                    mask[i] = 0
                    if i + 1 < n:
                        mask[i + 1] = 0
                    i += 2
                    continue
                mask[i] = 0
                if src[i] == q:
                    i += 1
                    break
                i += 1
        else:
            i += 1
    return mask


# ------------------------------------------------------- evaluare string Pawn

ESCAPES = {'n': '\n', 't': '\t', 'r': '\r', '\\': '\\', "'": "'", '"': '"',
           'a': '\a', 'b': '\b', 'e': '\x1b', 'f': '\f', 'v': '\v', '0': '\0'}


def load_defines(src):
    """Colecteaza #define simple: NAME -> valoare (string literal sau numar)."""
    out = {}
    for m in re.finditer(r'^[ \t]*#define[ \t]+([A-Za-z_][A-Za-z0-9_]*)[ \t]+(.+)$', src, re.M):
        name, val = m.group(1), m.group(2).strip()
        if val.endswith('\\'):
            continue
        val = re.sub(r'\s*//.*$', '', val).strip()
        out[name] = val
    return out


def eval_pawn_string(expr, defines, depth=0):
    """Transforma expresia-sursa (concatenare de literale + macro-uri) in stringul runtime.
    Returneaza None daca expresia nu e pur textuala."""
    if depth > 6:
        return None
    i, n = 0, len(expr)
    out = []
    saw_literal = False
    while i < n:
        c = expr[i]
        if c in ' \t\r\n':
            i += 1
            continue
        if c == '\\' and i + 1 < n and expr[i + 1] in '\r\n':
            i += 1
            continue
        if c == '"':
            saw_literal = True
            i += 1
            while i < n and expr[i] != '"':
                if expr[i] == '\\':
                    i += 1
                    if i >= n:
                        return None
                    e = expr[i]
                    if e in '\r\n':
                        # continuare de linie in interiorul unui literal Pawn
                        while i < n and expr[i] in '\r\n':
                            i += 1
                    elif e in ESCAPES:
                        out.append(ESCAPES[e])
                        i += 1
                    elif e == 'x' or e == 'X':
                        j = i + 1
                        h = ''
                        while j < n and expr[j] in '0123456789abcdefABCDEF':
                            h += expr[j]; j += 1
                        if j < n and expr[j] == ';':
                            j += 1
                        out.append(chr(int(h, 16)) if h else '')
                        i = j
                    elif e.isdigit():
                        j = i
                        d = ''
                        while j < n and expr[j].isdigit():
                            d += expr[j]; j += 1
                        if j < n and expr[j] == ';':
                            j += 1
                        out.append(chr(int(d)))
                        i = j
                    else:
                        return None
                else:
                    out.append(expr[i])
                    i += 1
            if i >= n:
                return None
            i += 1
            continue
        if c == '#':
            m = re.match(r'#([A-Za-z_][A-Za-z0-9_]*)', expr[i:])
            if not m or m.group(1) not in defines:
                return None
            val = defines[m.group(1)].strip()
            if val.startswith('"'):
                sub = eval_pawn_string(val, defines, depth + 1)
                if sub is None:
                    return None
                out.append(sub)
            else:
                out.append(val)
            saw_literal = True
            i += len(m.group(0))
            continue
        m = re.match(r'[A-Za-z_][A-Za-z0-9_]*', expr[i:])
        if m and m.group(0) in defines:
            val = defines[m.group(0)].strip()
            if val.startswith('"'):
                sub = eval_pawn_string(val, defines, depth + 1)
                if sub is None:
                    return None
                out.append(sub)
                saw_literal = True
                i += len(m.group(0))
                continue
        return None
    return ''.join(out) if saw_literal else None


def is_translatable(text):
    """Merita tradus? (are cuvinte reale, nu doar simboluri/format specifiers)"""
    if text is None:
        return False
    t = re.sub(r'\{[0-9A-Fa-f]{6}\}', '', text)
    t = re.sub(r'%[-+0-9.]*[a-zA-Z]', '', t)
    letters = re.findall(r'[A-Za-z]', t)
    if len(letters) < 3:
        return False
    return len(re.findall(r'[A-Za-z]{2,}', t)) >= 1


# ------------------------------------------------------------------- WRAP pass

RENAMES = [
    ("SendClientMessageToAll", "SCMToAll"),
    ("SendClientMessage",      "SCM"),
    ("ShowPlayerDialog",       "SPD"),
    ("GameTextForPlayer",      "GTP"),
]

# tabele globale de texte care ajung la jucator prin T(playerid, tabel[idx])
STRING_TABLES = ["g_ServerTips", "g_ServerJokes", "g_SinName", "g_GovRoleName"]

# variabile carora li se atribuie direct texte lungi, trimise apoi la SPD()
# (paginile /howto: `title = "..."` / `body = "..."`)
ASSIGN_TEXTS = ["title", "body"]


def find_assignments(src, names):
    """`nume = "..." ...;` -> yield expresia bruta (concatenarea de literale)."""
    for name in names:
        for m in re.finditer(r'(?<![A-Za-z0-9_])' + re.escape(name) + r'\s*=\s*"', src):
            start = m.end() - 1
            i, n = start, len(src)
            while i < n:
                c = src[i]
                if c == '"':
                    i += 1
                    while i < n and src[i] != '"':
                        i += 2 if src[i] == '\\' else 1
                    i += 1
                    continue
                if c == ';':
                    break
                i += 1
            yield src[start:i]

# sink: nume functie -> (index argument destinatar, index argument text)
SINKS = {
    "SCM":              (0, 2),
    "SPD":              (0, 4),
    "GTP":              (0, 1),
    "JobStatus_Update": (0, 1),
}


def do_rename(src):
    for old, new in RENAMES:
        src = re.sub(r'(?<![A-Za-z0-9_])' + old + r'(\s*\()', new + r'\1', src)
    return src


def wrap_formats(src):
    """format(BUF, size, "lit", ...) urmat de un sink care trimite BUF -> T(recip, "lit")."""
    defines = load_defines(src)
    edits = []
    stats = {"wrapped": 0, "no_sink": 0, "not_literal": 0, "skip_short": 0}

    for start, open_idx in find_calls(src, "format"):
        args, end = split_args(src, open_idx)
        if not args or len(args) < 3:
            continue
        buf = args[0].strip()
        fmt = args[2]
        if not re.fullmatch(r'[A-Za-z_][A-Za-z0-9_]*', buf):
            continue
        if 'T(' in fmt:
            continue
        if 'nolang' in src[start:end + 90]:   # marcaj explicit: nu se traduce
            continue
        text = eval_pawn_string(fmt, defines)
        if text is None:
            stats["not_literal"] += 1
            continue
        if not is_translatable(text):
            stats["skip_short"] += 1
            continue

        recip = find_sink_recipient(src, end, buf)
        if recip is None:
            stats["no_sink"] += 1
            continue
        # deja rezolvat manual: mesajul e recompus per-jucator in bucla de difuzare
        if re.search(r'format\s*\(\s*' + re.escape(buf) + r'\s*,[^;]*?T\s*\(', src[end:end + 1500], re.S):
            stats["already"] = stats.get("already", 0) + 1
            continue

        fs = open_idx + 1
        for a in args[:2]:
            fs += len(a) + 1
        fe = fs + len(fmt)
        edits.append((fs, fe, "T(%s, %s)" % (recip, fmt.strip())))
        stats["wrapped"] += 1

    # --- bucati de text adaugate cu strcat() intr-un buffer trimis apoi jucatorului ---
    for start, open_idx in find_calls(src, "strcat"):
        args, end = split_args(src, open_idx)
        if not args or len(args) < 2:
            continue
        buf, piece = args[0].strip(), args[1]
        if not re.fullmatch(r'[A-Za-z_][A-Za-z0-9_]*', buf):
            continue
        if 'T(' in piece:
            continue
        text = eval_pawn_string(piece, defines)
        if text is None or not is_translatable(text):
            continue
        recip = find_sink_recipient(src, end, buf)
        if recip is None:
            stats["strcat_no_sink"] = stats.get("strcat_no_sink", 0) + 1
            continue
        ps = open_idx + 1 + len(args[0]) + 1
        pe = ps + len(piece)
        edits.append((ps, pe, "T(%s, %s)" % (recip, piece.strip())))
        stats["strcat"] = stats.get("strcat", 0) + 1

    for fs, fe, rep in sorted(edits, reverse=True):
        src = src[:fs] + rep + src[fe:]
    return src, stats


def find_sink_recipient(src, from_idx, buf):
    """Cauta in urmatoarele ~1500 caractere un sink care primeste `buf`."""
    window = src[from_idx:from_idx + 1500]
    best = None
    for name, (ri, ti) in SINKS.items():
        for rel_start, rel_open in find_calls(window, name):
            args, _ = split_args(window, rel_open)
            if not args or len(args) <= max(ri, ti):
                continue
            if args[ti].strip() != buf:
                continue
            recip = args[ri].strip()
            if not re.fullmatch(r'[A-Za-z_][A-Za-z0-9_]*(\[[A-Za-z0-9_\]\[]+\])?', recip):
                continue
            if best is None or rel_start < best[0]:
                best = (rel_start, recip)
    return best[1] if best else None


# ---------------------------------------------------------------- EXTRACT pass

def esc_file(s):
    return s.replace('\\', '\\\\').replace('\n', '\\n').replace('\r', '\\r').replace('\t', '\\t')


def extract(src):
    defines = load_defines(src)
    seen, order = set(), []

    def add(text):
        if not is_translatable(text):
            return
        if text in seen:
            return
        seen.add(text)
        order.append(text)

    # 1) argumente-text ale sink-urilor, direct literale
    for name, (ri, ti) in SINKS.items():
        for start, open_idx in find_calls(src, name):
            args, _ = split_args(src, open_idx)
            if not args or len(args) <= ti:
                continue
            add(eval_pawn_string(args[ti], defines))

    # SPD: caption + butoane
    for start, open_idx in find_calls(src, "SPD"):
        args, _ = split_args(src, open_idx)
        if not args or len(args) < 7:
            continue
        for idx in (3, 5, 6):
            add(eval_pawn_string(args[idx], defines))

    # SCMToAll / President_BroadcastAll (arg 1 = text; trimit prin SCM, deci se traduc la runtime)
    for helper in ("SCMToAll", "President_BroadcastAll"):
        for start, open_idx in find_calls(src, helper):
            args, _ = split_args(src, open_idx)
            if args and len(args) >= 2:
                add(eval_pawn_string(args[1], defines))

    # 2) format-stringuri deja imbracate in T(...)
    for start, open_idx in find_calls(src, "T"):
        args, _ = split_args(src, open_idx)
        if not args or len(args) < 2:
            continue
        add(eval_pawn_string(",".join(args[1:]), defines))

    # 2b) tabele de texte globale trimise jucatorului prin T(playerid, tabel[idx])
    for name in STRING_TABLES:
        m = re.search(r'new\s+const\s+' + re.escape(name) + r'\s*\[[^\]]*\]\s*\[[^\]]*\]\s*=\s*\{', src)
        if not m:
            continue
        args, _ = split_args(src, m.end() - 1)
        for a in (args or []):
            add(eval_pawn_string(a, defines))

    # 2c) texte lungi atribuite direct unei variabile si trimise apoi la SPD (paginile /howto)
    for expr in find_assignments(src, ASSIGN_TEXTS):
        add(eval_pawn_string(expr, defines))

    # 3) format-uri care NU au putut fi imbracate in T() dar sunt clar mesaje de chat
    #    (contin coduri de culoare) -> intra ca SABLOANE, potrivite la runtime
    for start, open_idx in find_calls(src, "format"):
        args, _ = split_args(src, open_idx)
        if not args or len(args) < 3 or 'T(' in args[2]:
            continue
        txt = eval_pawn_string(args[2], defines)
        if txt and re.search(r'\{[0-9A-Fa-f]{6}\}', txt):
            add(txt)

    return order


def write_lang_file(path, texts, keep_existing=True):
    existing = {}
    if keep_existing and os.path.exists(path):
        existing = read_lang_file(path)

    lines = [
        "# ============================================================",
        "#  Fisier de limba: ROMANA",
        "# ------------------------------------------------------------",
        "#  Format: 2 linii per intrare.",
        "#    en: = textul original din joc (CHEIA - nu se modifica!)",
        "#    ro: = traducerea (gol = ramane engleza)",
        "#  \\n = linie noua, \\\\ = backslash. Codurile {RRGGBB} se pastreaza.",
        "#  Regenerat cu: python tools/lang_tool.py extract",
        "# ============================================================",
        "",
    ]
    done = 0
    for t in texts:
        tr = existing.get(t, "")
        if tr:
            done += 1
        lines.append("en:" + esc_file(t))
        lines.append("ro:" + esc_file(tr))
        lines.append("")

    with open(path, "w", encoding="utf-8", newline="\r\n") as f:
        f.write("\n".join(lines))
    return done


def read_lang_file(path):
    out, key = {}, None
    with open(path, "r", encoding="utf-8") as f:
        for raw in f:
            line = raw.rstrip("\r\n")
            if not line or line.startswith("#") or len(line) < 3 or line[2] != ":":
                continue
            body = line[3:]
            if line[:2] == "en":
                key = unesc_file(body)
            elif key is not None:
                if body:
                    out[key] = unesc_file(body)
                key = None
    return out


def unesc_file(s):
    out, i = [], 0
    while i < len(s):
        if s[i] == '\\' and i + 1 < len(s):
            c = s[i + 1]
            out.append({'n': '\n', 'r': '\r', 't': '\t', '\\': '\\'}.get(c, '\\' + c))
            i += 2
        else:
            out.append(s[i])
            i += 1
    return ''.join(out)


# ------------------------------------------------------------------------ main

def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "help"
    src = open(PWN, "r", encoding="utf-8", errors="surrogateescape", newline="").read()

    if cmd == "rename":
        src = do_rename(src)
        open(PWN, "w", encoding="utf-8", errors="surrogateescape", newline="").write(src)
        print("rename: gata")

    elif cmd == "wrap":
        src, stats = wrap_formats(src)
        open(PWN, "w", encoding="utf-8", errors="surrogateescape", newline="").write(src)
        print("wrap:", stats)

    elif cmd == "extract":
        texts = extract(src)
        out = os.path.join(ROOT, "scriptfiles", "lang", "ro.txt")
        os.makedirs(os.path.dirname(out), exist_ok=True)
        done = write_lang_file(out, texts)
        print("extract: %d texte, %d deja traduse -> %s" % (len(texts), done, out))
        longest = max(texts, key=len)
        print("cel mai lung text: %d caractere" % len(longest))

    elif cmd == "list":
        cmd_list(int(sys.argv[2]), int(sys.argv[3]))

    elif cmd == "apply":
        cmd_apply(sys.argv[2])

    elif cmd == "progress":
        e = read_entries(LANGFILE)
        d = sum(1 for x in e if x[1])
        print("traduse %d / %d (%.1f%%)" % (d, len(e), 100.0*d/len(e)))

    elif cmd == "stats":
        texts = extract(src)
        print("texte traductibile:", len(texts))
        for t in texts[:15]:
            print("  ", repr(t[:90]))
    else:
        print(__doc__)



def unwrap_lines(src, linenos):
    """Scoate T(recip, ...) de pe liniile date (recipientul nu e in scope acolo)."""
    lines = src.split("\r\n") if "\r\n" in src else src.split("\n")
    nl = "\r\n" if "\r\n" in src else "\n"
    n = 0
    for ln in linenos:
        i = ln - 1
        if i < 0 or i >= len(lines):
            continue
        line = lines[i]
        out, pos = [], 0
        while True:
            k = line.find("T(", pos)
            if k == -1:
                break
            if k > 0 and (line[k-1].isalnum() or line[k-1] == '_'):
                out.append(line[pos:k+2]); pos = k + 2; continue
            args, end = split_args(line, k + 1)
            if not args or len(args) < 2:
                out.append(line[pos:k+2]); pos = k + 2; continue
            out.append(line[pos:k])
            out.append(",".join(args[1:]).strip())
            pos = end
            n += 1
        out.append(line[pos:])
        lines[i] = "".join(out)
    return nl.join(lines), n


# ---------------------------------------------- traducere in loturi (list/apply)

LANGFILE = os.path.join(ROOT, "scriptfiles", "lang", "ro.txt")


def read_entries(path):
    """Returneaza lista [(en, ro)] in ordinea din fisier."""
    out, key = [], None
    with open(path, "r", encoding="utf-8") as f:
        for raw in f:
            line = raw.rstrip("\r\n")
            if not line or line.startswith("#") or len(line) < 3 or line[2] != ":":
                continue
            if line[:2] == "en":
                key = line[3:]
            elif key is not None:
                out.append([key, line[3:]])
                key = None
    return out


def write_entries(path, entries):
    head = []
    with open(path, "r", encoding="utf-8") as f:
        for raw in f:
            if raw.startswith("#") or not raw.strip():
                head.append(raw.rstrip("\r\n"))
            else:
                break
    body = []
    for en, ro in entries:
        body.append("en:" + en)
        body.append("ro:" + ro)
        body.append("")
    with open(path, "w", encoding="utf-8", newline="\r\n") as f:
        f.write("\n".join(head + body))


def cmd_list(start, count, only_missing=True):
    ents = read_entries(LANGFILE)
    shown = 0
    for i, (en, ro) in enumerate(ents):
        if i < start:
            continue
        if only_missing and ro:
            continue
        print("%d|%s" % (i, en))
        shown += 1
        if shown >= count:
            break


def cmd_apply(batchfile):
    ents = read_entries(LANGFILE)
    n = 0
    with open(batchfile, "r", encoding="utf-8") as f:
        for raw in f:
            line = raw.rstrip("\r\n")
            if not line or "|" not in line:
                continue
            idx, tr = line.split("|", 1)
            try:
                i = int(idx)
            except ValueError:
                continue
            if 0 <= i < len(ents) and tr.strip():
                ents[i][1] = tr
                n += 1
    write_entries(LANGFILE, ents)
    done = sum(1 for e in ents if e[1])
    print("apply: %d traduceri aplicate; total %d/%d (%.1f%%)" % (n, done, len(ents), 100.0*done/len(ents)))

if __name__ == "__main__":
    main()
