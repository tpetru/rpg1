#!/usr/bin/env python3
"""Genereaza site/flights/data.json pentru flights.php: fontul de linii si aeroportul principal al fiecarei tari.

Surse (descarcate manual intr-un folder, dat ca argument):
  airports.csv    - OurAirports (github.com/davidmegginson/ourairports-data), domeniu public
  countries.json  - github.com/mledoze/countries (numele capitalei pe tara)
  places.geojson  - Natural Earth ne_10m_populated_places_simple (coordonatele capitalelor)
  runways.csv     - OurAirports, pistele (lungimea si directia)
  futural.jhf     - fontul Hershey "Roman Simplex" (din pachetul Hershey-Fonts de pe PyPI)

Rulare: python3 build_data.py <folder-surse>   -> scrie data.json langa script.

Pentru fiecare tara, aeroportul principal: dintre aeroporturile cu zboruri regulate aflate la cel mult
100 km de capitala, cel din categoria cea mai mare (mare > mediu) si cu pista cea mai lunga, cu o penalizare de 30 ft/km de distanta
(asa iese Otopeni in loc de Baneasa, Fiumicino in loc de Ciampino, Abu Dhabi in loc de Al Maktoum). Daca nu e niciunul aproape, cel mai apropiat
de capitala din categoria cea mai buna. Dupa el urmeaza toate celelalte aeroporturi mari/medii cu zboruri
regulate din tara, in ordinea alfabetica a orasului.
Pentru fiecare aeroport se salveaza si directia pistei celei mai lungi (avionul decoleaza pe ea).
"""
import csv, json, math, os, sys, unicodedata

src = sys.argv[1]
here = os.path.dirname(os.path.abspath(__file__))


def norm(s):
    return unicodedata.normalize('NFKD', s or '').encode('ascii', 'ignore').decode().lower().strip()


def dist(a, b):
    la1, lo1, la2, lo2 = map(math.radians, (a[0], a[1], b[0], b[1]))
    h = math.sin((la2 - la1) / 2) ** 2 + math.cos(la1) * math.cos(la2) * math.sin((lo2 - lo1) / 2) ** 2
    return 6371 * 2 * math.asin(math.sqrt(h))


# --- fontul Hershey: o linie pe glifa, ASCII 32..126 in ordine ---
font = {}
lines = [l.rstrip('\n') for l in open(os.path.join(src, 'futural.jhf')) if not l.startswith('#')]
for i, l in enumerate(lines[:95]):
    body = l[8:]
    left, right = ord(body[0]) - 82, ord(body[1]) - 82
    strokes, cur = [], []
    k = 2
    while k + 1 < len(body) + 1 and k < len(body):
        pair = body[k:k + 2]
        k += 2
        if pair == ' R':
            if cur: strokes.append(cur)
            cur = []
            continue
        cur.append([ord(pair[0]) - 82 - left, ord(pair[1]) - 82])
    if cur: strokes.append(cur)
    font[chr(32 + i)] = {'w': right - left, 's': strokes}

# --- capitale ---
countries = json.load(open(os.path.join(src, 'countries.json')))
places = [f['properties'] for f in json.load(open(os.path.join(src, 'places.geojson')))['features']]
capitals = {}
for p in places:
    if p.get('adm0cap') == 1 and p.get('iso_a2') and len(p['iso_a2']) == 2:
        old = capitals.get(p['iso_a2'])
        if not old or p['pop_max'] > old['pop_max']:
            capitals[p['iso_a2']] = p
by_name = {}
for p in places:
    by_name.setdefault(norm(p['name']), []).append(p)

cap_info = {}
for c in countries:
    cc = c['cca2']
    name = (c.get('capital') or [''])[0]
    p = capitals.get(cc)
    if not p and name:
        cand = [q for q in by_name.get(norm(name), []) if q.get('iso_a2') == cc] or by_name.get(norm(name), [])
        p = max(cand, key=lambda q: q['pop_max']) if cand else None
    if p:
        cap_info[cc] = (p['name'], (p['latitude'], p['longitude']))
    elif c.get('latlng'):
        cap_info[cc] = (name or c['name']['common'], tuple(c['latlng']))

# --- aeroporturi ---
rank = {'large_airport': 0, 'medium_airport': 1, 'small_airport': 2}
per = {}
for r in csv.DictReader(open(os.path.join(src, 'airports.csv'), encoding='utf-8')):
    if r['type'] not in rank:
        continue
    per.setdefault(r['iso_country'], []).append(r)

runway = {}
for r in csv.DictReader(open(os.path.join(src, 'runways.csv'), encoding='utf-8')):
    if r['closed'] == '1':
        continue
    try:
        ln = float(r['length_ft'] or 0)
    except ValueError:
        continue
    hd = r['le_heading_degT']
    if not hd:
        # fara directie explicita: din numele pistei (ex. "08R" -> 80 grade)
        num = ''.join(ch for ch in r['le_ident'][:2] if ch.isdigit())
        hd = int(num) * 10 if num else None
    try:
        hd = float(hd) if hd is not None else None
    except ValueError:
        hd = None
    old = runway.get(r['airport_ident'])
    if not old or ln > old[0]:
        runway[r['airport_ident']] = (ln, hd)

out = {}
for cc, rows in per.items():
    if cc not in cap_info:
        continue
    cap_name, cap = cap_info[cc]

    def tier(r):
        sched = r['scheduled_service'] == 'yes'
        t = r['type']
        if t == 'large_airport' and sched: return 0
        if t == 'medium_airport' and sched: return 1
        if t in ('large_airport', 'medium_airport'): return 2
        if sched and r['iata_code']: return 3
        return 9

    rows = [r for r in rows if tier(r) < 9]
    if not rows:
        continue
    for r in rows:
        r['_d'] = dist(cap, (float(r['latitude_deg']), float(r['longitude_deg'])))
    rlen = lambda r: runway.get(r['ident'], (0, None))[0]
    near = [r for r in rows if r['_d'] <= 100 and tier(r) <= 1]
    if near:
        main = min(near, key=lambda r: (tier(r), -(rlen(r) - 30 * r['_d'])))
    else:
        best = min(tier(r) for r in rows)
        main = min((r for r in rows if tier(r) == best), key=lambda r: r['_d'])
    others = sorted((r for r in rows if r is not main and tier(r) <= max(tier(main), 1)),
                    key=lambda r: norm(r['municipality'] or r['name']))
    out[cc] = {
        'cap': cap_name,
        'a': [[r['iata_code'] or r['ident'], r['name'], r['municipality'],
               round(float(r['latitude_deg']), 4), round(float(r['longitude_deg']), 4),
               None if runway.get(r['ident'], (0, None))[1] is None else round(runway[r['ident']][1])]
              for r in [main] + others],
    }

json.dump({'font': font, 'airports': dict(sorted(out.items()))},
          open(os.path.join(here, 'data.json'), 'w', encoding='utf-8'), ensure_ascii=False, separators=(',', ':'))
print(len(out), 'tari;', len(font), 'glife')
for cc in ('RO', 'MD', 'US', 'DE', 'GB', 'JP', 'AU', 'BR', 'TR', 'IT', 'CH', 'CA', 'AE'):
    if cc in out:
        print(cc, out[cc]['cap'], '->', out[cc]['a'][0][:3], out[cc]['a'][0][5], [a[0] for a in out[cc]['a'][1:]])
