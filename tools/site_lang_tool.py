#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Unelte pentru sistemul multi-language al site-ului (site/includes/lang.php).

  python tools/site_lang_tool.py scan   - lista toate apelurile t('...') din site/*.php
  python tools/site_lang_tool.py check  - compara cu site/includes/lang/ro.php: ce lipseste, ce e in plus
  python tools/site_lang_tool.py apply <fisier>  - aplica traduceri in loturi (linii "cheie<TAB>traducere")

Spre deosebire de tools/lang_tool.py (gamemode), aici NU exista wrap automat:
HTML amestecat cu PHP nu are un tipar de apel uniform de "imbracat" - fiecare
t('...') se scrie manual, o data, direct in fisierul .php.
"""
import os, re, sys, json, subprocess

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SITE = os.path.join(ROOT, "site")
DICT_PHP = os.path.join(SITE, "includes", "lang", "ro.php")
PHP_EXE = r"C:\xampp\php\php.exe"

SKIP_DIRS = {"admin", "games", "pictures", "assets", "vendor"}  # panoul de admin si content generat de forum raman netraduse
SKIP_FILES = {"lang.php", "set_language.php"}  # infrastructura, nu au continut de tradus (comentariile lor mentioneaza t() ca exemplu)

# t() cu literal simplu, fara ghilimele/backslash-uri escapate in interior (asa scriem noi apelurile)
CALL_RE_S = re.compile(r"\bte?\(\s*'([^']*)'\s*\)")
CALL_RE_D = re.compile(r'\bte?\(\s*"([^"]*)"\s*\)')


def iter_php_files():
    for dirpath, dirnames, filenames in os.walk(SITE):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS and d != "lang"]
        for fn in filenames:
            if fn.endswith(".php") and fn not in SKIP_FILES:
                yield os.path.join(dirpath, fn)


def unescape_php_single(s):
    return s.replace("\\'", "'").replace("\\\\", "\\")


def unescape_php_double(s):
    out = s.replace('\\"', '"')
    out = out.replace("\\n", "\n").replace("\\t", "\t").replace("\\r", "\r")
    return out.replace("\\\\", "\\")


def scan_calls():
    found = {}  # text -> list of (file, lineno)
    for path in iter_php_files():
        with open(path, encoding="utf-8") as f:
            for lineno, line in enumerate(f, 1):
                for m in CALL_RE_S.finditer(line):
                    text = unescape_php_single(m.group(1))
                    found.setdefault(text, []).append((os.path.relpath(path, ROOT), lineno))
                for m in CALL_RE_D.finditer(line):
                    text = unescape_php_double(m.group(1))
                    found.setdefault(text, []).append((os.path.relpath(path, ROOT), lineno))
    return found


def load_dict():
    out = subprocess.run(
        [PHP_EXE, "-r", "echo json_encode(require '%s');" % DICT_PHP.replace("\\", "/")],
        capture_output=True, text=True,
    )
    if out.returncode != 0:
        print(out.stderr)
        raise SystemExit(1)
    data = json.loads(out.stdout)
    return data if isinstance(data, dict) else {}


def cmd_scan():
    calls = scan_calls()
    print("apeluri t()/te() gasite:", len(calls), "texte distincte")
    for text, sites in sorted(calls.items()):
        loc = sites[0]
        extra = " (+%d)" % (len(sites) - 1) if len(sites) > 1 else ""
        print("  %-90s  %s:%d%s" % (text[:90], loc[0], loc[1], extra))


def cmd_check():
    calls = scan_calls()
    d = load_dict()
    missing = sorted(set(calls) - set(d))
    unused = sorted(set(d) - set(calls))
    print("chei folosite in cod:", len(calls))
    print("chei in dictionar:   ", len(d))
    print("traduse:             ", sum(1 for k in calls if k in d and d[k]))
    print()
    print("LIPSESC din dictionar (%d):" % len(missing))
    for k in missing:
        loc = calls[k][0]
        print("  %-90s  %s:%d" % (k[:90], loc[0], loc[1]))
    print()
    print("NEFOLOSITE in cod (%d):" % len(unused))
    for k in unused:
        print("  ", k[:90])


def php_single_quote(s):
    return "'" + s.replace("\\", "\\\\").replace("'", "\\'") + "'"


def cmd_apply(batch_path):
    d = load_dict()
    n = 0
    with open(batch_path, encoding="utf-8") as f:
        for raw in f:
            line = raw.rstrip("\n")
            if not line or "\t" not in line:
                continue
            key, val = line.split("\t", 1)
            if not val.strip():
                continue
            d[key] = val
            n += 1

    lines = [
        "<?php",
        "// ============================================================",
        "//  Dictionar RO pentru site (includes/lang.php / t())",
        "// ------------------------------------------------------------",
        "//  Cheia = textul englez EXACT din sursa (site/*.php). Regenerat/completat",
        "//  manual pe masura ce se adauga t('...') in pagini.",
        "// ============================================================",
        "return [",
    ]
    for k in sorted(d):
        if not d[k]:
            continue
        lines.append("    %s => %s," % (php_single_quote(k), php_single_quote(d[k])))
    lines.append("];")
    with open(DICT_PHP, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines) + "\n")
    print("aplicate: %d | total in dictionar: %d" % (n, sum(1 for v in d.values() if v)))


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "help"
    if cmd == "scan":
        cmd_scan()
    elif cmd == "check":
        cmd_check()
    elif cmd == "apply":
        cmd_apply(sys.argv[2])
    else:
        print(__doc__)
