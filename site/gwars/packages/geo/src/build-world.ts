// Builds the playable world: every H3 cell whose center lies on land becomes a settlement hex,
// tagged with its real country, landmass, nearest real city name and a resource profile.
//
//   npm run geo:build -- --res 3
//
// Downloads are cached in packages/geo/cache. Outputs:
//   packages/geo/out/world-r{res}.json       -> loaded into the DB by `npm run db:seed`
//   apps/web/public/geo/countries.geojson    -> country shapes drawn under the hexes
import { existsSync } from 'node:fs';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { strFromU8, unzipSync } from 'fflate';
import { cellToChildren, cellToLatLng, getRes0Cells, gridDisk, latLngToCell } from 'h3-js';
import type { WorldFile, WorldHex } from './world-file';

const GEO_ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const REPO_ROOT = path.resolve(GEO_ROOT, '../..');
const CACHE_DIR = path.join(GEO_ROOT, 'cache');

const NE = 'https://raw.githubusercontent.com/nvkelso/natural-earth-vector/v5.1.2/geojson';
const SOURCES = {
  countries: `${NE}/ne_50m_admin_0_countries.geojson`,
  land: `${NE}/ne_50m_land.geojson`,
  cities: 'https://download.geonames.org/export/dump/cities15000.zip',
};

/** Countries without any hex center inside them still get one hex if at least this populous. */
const MICROSTATE_MIN_POP = 100_000;
/** A microstate may take a hex from a neighbor only if the neighbor keeps more than this many. */
const MICROSTATE_DONOR_MIN = 3;

type Position = [number, number];
type PolygonCoords = Position[][];
interface Geometry {
  type: 'Polygon' | 'MultiPolygon';
  coordinates: PolygonCoords | PolygonCoords[];
}
interface Feature {
  properties: Record<string, unknown>;
  geometry: Geometry | null;
}
interface IndexedPolygon {
  bbox: [number, number, number, number];
  rings: PolygonCoords;
}
interface Country {
  code: string;
  name: string;
  continent: string;
  pop: number;
  label: Position;
  polys: IndexedPolygon[];
}
interface Cell {
  h: string;
  lat: number;
  lng: number;
  country: Country;
  landmass: number;
  name: string;
}
interface City {
  name: string;
  pop: number;
  lat: number;
  lng: number;
}
interface ResourceEntry {
  food: number;
  steel: number;
  oil: number;
  rare: number;
  uranium: number;
}

function arg(name: string): string | undefined {
  const i = process.argv.indexOf(name);
  return i >= 0 ? process.argv[i + 1] : undefined;
}

async function download(url: string): Promise<Buffer> {
  const file = path.join(CACHE_DIR, path.basename(new URL(url).pathname));
  if (existsSync(file)) return readFile(file);
  console.log(`Downloading ${url}`);
  const resp = await fetch(url);
  if (!resp.ok) throw new Error(`${url}: HTTP ${resp.status}`);
  const buf = Buffer.from(await resp.arrayBuffer());
  await writeFile(file, buf);
  return buf;
}

function polygonsOf(g: Geometry | null): PolygonCoords[] {
  if (!g) return [];
  return g.type === 'Polygon' ? [g.coordinates as PolygonCoords] : (g.coordinates as PolygonCoords[]);
}

function indexPolygon(rings: PolygonCoords): IndexedPolygon {
  let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
  for (const [x, y] of rings[0]) {
    if (x < minX) minX = x;
    if (x > maxX) maxX = x;
    if (y < minY) minY = y;
    if (y > maxY) maxY = y;
  }
  return { bbox: [minX, minY, maxX, maxY], rings };
}

function inRing(x: number, y: number, ring: Position[]): boolean {
  let inside = false;
  for (let i = 0, j = ring.length - 1; i < ring.length; j = i++) {
    const [xi, yi] = ring[i];
    const [xj, yj] = ring[j];
    if (yi > y !== yj > y && x < ((xj - xi) * (y - yi)) / (yj - yi) + xi) inside = !inside;
  }
  return inside;
}

function inPolygon(x: number, y: number, p: IndexedPolygon): boolean {
  const [minX, minY, maxX, maxY] = p.bbox;
  if (x < minX || x > maxX || y < minY || y > maxY) return false;
  if (!inRing(x, y, p.rings[0])) return false;
  for (let i = 1; i < p.rings.length; i++) if (inRing(x, y, p.rings[i])) return false;
  return true;
}

function ringArea(ring: Position[]): number {
  let a = 0;
  for (let i = 0, j = ring.length - 1; i < ring.length; j = i++) a += (ring[j][0] + ring[i][0]) * (ring[j][1] - ring[i][1]);
  return Math.abs(a / 2);
}

/** Deterministic pseudo-random value in [0, 1) per hex, so rebuilding gives the same world. */
function hash01(s: string, salt: number): number {
  let h = (2166136261 ^ salt) >>> 0;
  for (let i = 0; i < s.length; i++) {
    h ^= s.charCodeAt(i);
    h = Math.imul(h, 16777619) >>> 0;
  }
  return h / 2 ** 32;
}

const round2 = (x: number) => Math.round(x * 100) / 100;
const clamp = (x: number, lo: number, hi: number) => Math.min(hi, Math.max(lo, x));

const COMPASS = ['East', 'Northeast', 'North', 'Northwest', 'West', 'Southwest', 'South', 'Southeast'];

function compass(from: City, to: Cell): string {
  let dLng = to.lng - from.lng;
  if (dLng > 180) dLng -= 360;
  if (dLng < -180) dLng += 360;
  const angle = (Math.atan2(to.lat - from.lat, dLng * Math.cos((from.lat * Math.PI) / 180)) * 180) / Math.PI;
  return COMPASS[Math.round(((angle + 360) % 360) / 45) % 8];
}

function countBy<T, K>(items: Iterable<T>, key: (t: T) => K): Map<K, number> {
  const out = new Map<K, number>();
  for (const it of items) out.set(key(it), (out.get(key(it)) ?? 0) + 1);
  return out;
}

async function main() {
  const res = Number(arg('--res') ?? 3);
  await mkdir(CACHE_DIR, { recursive: true });

  const [countriesRaw, landRaw, citiesZip] = await Promise.all([
    download(SOURCES.countries),
    download(SOURCES.land),
    download(SOURCES.cities),
  ]);
  const countryFeatures = (JSON.parse(countriesRaw.toString('utf8')) as { features: Feature[] }).features;
  const landFeatures = (JSON.parse(landRaw.toString('utf8')) as { features: Feature[] }).features;
  const resourceTable = JSON.parse(await readFile(path.join(GEO_ROOT, 'data', 'country-resources.json'), 'utf8')) as Record<
    string,
    Partial<ResourceEntry>
  >;
  const defaults = resourceTable._default as ResourceEntry;

  const byCode = new Map<string, Country>();
  for (const f of countryFeatures) {
    const code = String(f.properties.ADM0_A3);
    if (code === 'ATA') continue; // Antarctica is scenery only
    const polys = polygonsOf(f.geometry).map(indexPolygon);
    const existing = byCode.get(code);
    if (existing) {
      existing.polys.push(...polys);
      continue;
    }
    byCode.set(code, {
      code,
      name: String(f.properties.NAME),
      continent: String(f.properties.CONTINENT),
      pop: Number(f.properties.POP_EST ?? 0),
      label: [Number(f.properties.LABEL_X), Number(f.properties.LABEL_Y)],
      polys,
    });
  }
  const countries = [...byCode.values()];

  const landPolys = landFeatures
    .flatMap((f) => polygonsOf(f.geometry))
    .map(indexPolygon)
    .sort((a, b) => ringArea(b.rings[0]) - ringArea(a.rings[0]));

  // 1. Every cell whose center is inside a country.
  const cells = new Map<string, Cell>();
  for (const base of getRes0Cells()) {
    for (const h of cellToChildren(base, res)) {
      const [lat, lng] = cellToLatLng(h);
      if (lat < -60) continue;
      const country = countries.find((c) => c.polys.some((p) => inPolygon(lng, lat, p)));
      if (!country) continue;
      const landmass = landPolys.findIndex((p) => inPolygon(lng, lat, p));
      cells.set(h, { h, lat, lng, country, landmass, name: '' });
    }
  }

  // 2. Small but real countries (Singapore, Luxembourg, Malta, island states) get one hex at their label point.
  const perCountry = countBy(cells.values(), (c) => c.country.code);
  const microstates: string[] = [];
  for (const c of countries) {
    if (perCountry.get(c.code) || c.pop < MICROSTATE_MIN_POP) continue;
    const h = latLngToCell(c.label[1], c.label[0], res);
    const existing = cells.get(h);
    if (existing) {
      const donor = existing.country.code;
      if ((perCountry.get(donor) ?? 0) <= MICROSTATE_DONOR_MIN) continue;
      perCountry.set(donor, perCountry.get(donor)! - 1);
      existing.country = c;
    } else {
      const [lat, lng] = cellToLatLng(h);
      cells.set(h, { h, lat, lng, country: c, landmass: -1, name: '' });
    }
    perCountry.set(c.code, 1);
    microstates.push(c.name);
  }

  // 3. Cells whose center missed the land layer inherit a neighbor's landmass, or become their own island.
  let nextLandmass = landPolys.length;
  for (const cell of cells.values()) {
    if (cell.landmass >= 0) continue;
    const neighbor = gridDisk(cell.h, 1)
      .map((n) => cells.get(n))
      .find((n) => n && n.landmass >= 0);
    cell.landmass = neighbor ? neighbor.landmass : nextLandmass++;
  }
  const landmassRank = new Map(
    [...countBy(cells.values(), (c) => c.landmass).entries()].sort((a, b) => b[1] - a[1]).map(([id], rank) => [id, rank]),
  );
  for (const cell of cells.values()) cell.landmass = landmassRank.get(cell.landmass)!;

  // 4. Names from the biggest real city inside each cell, else "<direction> <nearby city>", else "<country> Frontier N".
  const zip = unzipSync(new Uint8Array(citiesZip));
  const tsv = strFromU8(zip['cities15000.txt']);
  const bestCity = new Map<string, City>();
  for (const line of tsv.split('\n')) {
    const cols = line.split('\t');
    if (cols.length < 15) continue;
    const city: City = { name: cols[1], lat: Number(cols[4]), lng: Number(cols[5]), pop: Number(cols[14]) };
    const h = latLngToCell(city.lat, city.lng, res);
    if (!cells.has(h)) continue;
    const prev = bestCity.get(h);
    if (!prev || city.pop > prev.pop) bestCity.set(h, city);
  }
  const frontierCount = new Map<string, number>();
  for (const cell of cells.values()) {
    const city = bestCity.get(cell.h);
    if (city) {
      cell.name = city.name;
      continue;
    }
    const near = gridDisk(cell.h, 1)
      .map((n) => bestCity.get(n))
      .filter((c): c is City => !!c)
      .sort((a, b) => b.pop - a.pop)[0];
    if (near) {
      cell.name = `${compass(near, cell)} ${near.name}`;
    } else {
      const n = (frontierCount.get(cell.country.code) ?? 0) + 1;
      frontierCount.set(cell.country.code, n);
      cell.name = `${cell.country.name} Frontier ${n}`;
    }
  }

  // 5. Resource profiles: country multipliers x climate x per-hex noise.
  const profile = (cell: Cell): WorldHex['p'] => {
    const m = { ...defaults, ...resourceTable[cell.country.code] };
    const noise = (salt: number) => 0.85 + 0.3 * hash01(cell.h, salt);
    const absLat = Math.abs(cell.lat);
    const climate = absLat > 70 ? 0.45 : absLat > 60 ? 0.65 : absLat > 52 ? 0.9 : 1;
    const strategic = (mult: number, salt: number) =>
      mult > 0 && hash01(cell.h, salt) < Math.min(0.9, mult * 0.3) ? round2(mult * (0.7 + 0.6 * hash01(cell.h, salt + 100))) : 0;
    return [
      round2(clamp(m.food * climate * noise(1), 0.4, 2)),
      round2(clamp(m.steel * noise(2), 0.4, 2)),
      round2(clamp(m.oil * noise(3), 0.4, 2)),
      strategic(m.rare, 4),
      strategic(m.uranium, 5),
    ];
  };

  const sorted = [...cells.values()].sort((a, b) => (a.h < b.h ? -1 : 1));
  const usedCodes = new Set(sorted.map((c) => c.country.code));
  const world: WorldFile = {
    res,
    generatedAt: new Date().toISOString(),
    sources: SOURCES,
    countries: countries
      .filter((c) => usedCodes.has(c.code))
      .map(({ code, name, continent }) => ({ code, name, continent }))
      .sort((a, b) => a.name.localeCompare(b.name)),
    hexes: sorted.map((c) => ({
      h: c.h,
      lat: Math.round(c.lat * 1000) / 1000,
      lng: Math.round(c.lng * 1000) / 1000,
      c: c.country.code,
      lm: c.landmass,
      n: c.name,
      p: profile(c),
    })),
  };

  const outDir = path.join(GEO_ROOT, 'out');
  await mkdir(outDir, { recursive: true });
  const worldPath = path.join(outDir, `world-r${res}.json`);
  await writeFile(worldPath, JSON.stringify(world));

  // Country shapes for the client, with properties stripped and coordinates rounded (~100 m).
  const roundRing = (ring: Position[]) =>
    ring
      .map(([x, y]) => [Math.round(x * 1000) / 1000, Math.round(y * 1000) / 1000] as Position)
      .filter((p, i, arr) => i === 0 || p[0] !== arr[i - 1][0] || p[1] !== arr[i - 1][1]);
  const webCountries = {
    type: 'FeatureCollection',
    features: countryFeatures
      .filter((f) => f.geometry)
      .map((f) => ({
        type: 'Feature',
        properties: { code: String(f.properties.ADM0_A3), name: String(f.properties.NAME) },
        geometry: {
          type: 'MultiPolygon',
          coordinates: polygonsOf(f.geometry).map((poly) => poly.map(roundRing).filter((r) => r.length >= 4)),
        },
      })),
  };
  const webDir = path.join(REPO_ROOT, 'apps', 'web', 'public', 'geo');
  await mkdir(webDir, { recursive: true });
  await writeFile(path.join(webDir, 'countries.geojson'), JSON.stringify(webCountries));

  const landmasses = countBy(world.hexes, (h) => h.lm);
  const top = [...countBy(world.hexes, (h) => h.c).entries()].sort((a, b) => b[1] - a[1]).slice(0, 8);
  console.log(`H3 res ${res}: ${world.hexes.length} hexes in ${world.countries.length} countries`);
  console.log(`Landmasses: ${landmasses.size} (largest: ${[...landmasses.values()].sort((a, b) => b - a).slice(0, 5).join(', ')})`);
  console.log(`Largest countries: ${top.map(([c, n]) => `${c} ${n}`).join(', ')}`);
  console.log(`Named after a city: ${bestCity.size}, frontier hexes: ${[...frontierCount.values()].reduce((a, b) => a + b, 0)}`);
  console.log(`Microstates given a hex (${microstates.length}): ${microstates.join(', ')}`);
  console.log(`Wrote ${path.relative(REPO_ROOT, worldPath)} and apps/web/public/geo/countries.geojson`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
