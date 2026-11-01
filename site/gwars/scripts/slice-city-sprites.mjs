/*
 * PARKED — the settlement map no longer uses painted art: its ground is drawn in
 * `apps/web/src/art/cityGround.tsx` and its buildings are the app's own illustrations. This script
 * and the masters in `apps/web/assets/city-src/` are kept so the painted/cartoon versions can be
 * brought back by re-running it, but nothing in the app reads its output today.
 *
 * Cuts the painted town out of its sprite atlases, once, at build time.
 *
 * The atlases in `apps/web/assets/city-src/` are four 1024x768 sheets, each holding several
 * buildings with alpha. The browser used to sample one small rectangle out of a whole sheet for
 * every building it drew, which meant downloading 4.6 MB to paint at most eighteen small pictures.
 * This script extracts those same rectangles into individual WebP files, so a settlement requests
 * only the buildings it actually has.
 *
 * The crop rectangles below were measured from each atlas's alpha channel; they are the rectangles
 * the browser sampled, so the sliced art sits on exactly the same pixels as before. Each output is
 * checked against its rectangle, because a one-pixel shift would move a building off its painted bay.
 *
 * Run with: npm run assets:city
 */
import { mkdir, readdir, stat, unlink } from 'node:fs/promises';
import path from 'node:path';
import sharp from 'sharp';

const ROOT = path.resolve(import.meta.dirname, '..');
const SRC = path.join(ROOT, 'apps/web/assets/city-src');
const PUBLIC_CITY = path.join(ROOT, 'apps/web/public/city');
const OUT = path.join(PUBLIC_CITY, 'buildings');

/** Lossy quality for cut-outs; the matte stays exact so the alpha edges do not go fuzzy. */
const CUT_QUALITY = 82;
/**
 * The plate is the largest image on the screen. Measured on this painting: q80 is 159 KB against
 * the source JPEG's 196 KB, at a mean channel error of ~3/255 over the whole painting — the same
 * order as the JPEG's own error against the original art, and not visible at the size it is shown.
 * Above q86 WebP was outright *larger* than the JPEG, so extra quality would cost bytes for nothing.
 */
const PLATE_QUALITY = 80;

/**
 * [sheet, x, y, width, height] per building, read off the atlas alpha bounds.
 * One entry per id in BUILDING_IDS: a building removed from the game is removed here too, and the
 * stale cut-out is pruned from the output folder.
 */
const CROPS = {
  // Civic sheet: 3 columns by 2 rows, last cell empty.
  cityhall: ['civic', 20, 52, 306, 408],
  housing: ['civic', 378, 110, 256, 351],
  hospital: ['civic', 702, 115, 298, 347],
  researchcenter: ['civic', 25, 582, 289, 343],
  market: ['civic', 345, 611, 336, 314],

  // Garrison sheet: 2 x 2.
  fortifications: ['military', 41, 75, 414, 373],
  barracks: ['military', 502, 82, 487, 370],
  bunker: ['military', 34, 629, 478, 300],
  radar: ['military', 606, 522, 321, 427],

  // Works-yard sheet: 2 x 2.
  oilfield: ['industry', 24, 31, 459, 449],
  steelmill: ['industry', 519, 154, 484, 318],
  factory: ['industry', 31, 538, 468, 423],
  warehouse: ['industry', 528, 610, 473, 348],

  // Outskirts sheet: two in the top row, one below.
  farm: ['outer', 24, 69, 462, 408],
  port: ['outer', 536, 78, 463, 411],
  airbase: ['outer', 34, 575, 524, 343],
};

const kb = (bytes) => `${(bytes / 1024).toFixed(1)} KB`;

async function slice() {
  await mkdir(OUT, { recursive: true });

  // One decode per sheet, reused by every building it holds.
  const sheets = new Map();
  const load = async (name) => {
    if (!sheets.has(name)) {
      const file = path.join(SRC, `${name}.png`);
      sheets.set(name, { file, image: sharp(file), meta: await sharp(file).metadata() });
    }
    return sheets.get(name);
  };

  const rows = [];
  for (const [id, [sheet, left, top, width, height]] of Object.entries(CROPS)) {
    const source = await load(sheet);
    if (left + width > source.meta.width || top + height > source.meta.height) {
      throw new Error(`${id}: crop ${width}x${height} at ${left},${top} falls outside ${sheet}.png`);
    }

    const file = path.join(OUT, `${id}.webp`);
    await sharp(source.file)
      .extract({ left, top, width, height })
      .webp({ quality: CUT_QUALITY, alphaQuality: 100, effort: 6 })
      .toFile(file);

    const out = await sharp(file).metadata();
    if (out.width !== width || out.height !== height) {
      throw new Error(`${id}: wrote ${out.width}x${out.height}, expected ${width}x${height}`);
    }
    rows.push({ id, sheet, size: `${width}x${height}`, bytes: (await stat(file)).size });
  }

  // A building removed from the game must not linger as a file nobody requests.
  const expected = new Set(Object.keys(CROPS).map((id) => `${id}.webp`));
  const stale = (await readdir(OUT)).filter((name) => name.endsWith('.webp') && !expected.has(name));
  for (const name of stale) await unlink(path.join(OUT, name));
  if (stale.length > 0) console.log(`  pruned stale cut-outs: ${stale.join(', ')}`);

  const plateSrc = path.join(SRC, 'base.jpg');
  const plateOut = path.join(PUBLIC_CITY, 'base.webp');
  await sharp(plateSrc).webp({ quality: PLATE_QUALITY, effort: 6 }).toFile(plateOut);
  const plateMeta = await sharp(plateOut).metadata();
  const plateBytes = (await stat(plateOut)).size;
  const plateBefore = (await stat(plateSrc)).size;
  // Objective quality check on the one image where a difference would show: mean channel error
  // between the master and the WebP, per 0-255 sample. Under ~1.5 is not perceptible on this art.
  const rawRgb = (file) => sharp(file).toColorspace('srgb').removeAlpha().raw().toBuffer();
  const [beforePx, afterPx] = await Promise.all([rawRgb(plateSrc), rawRgb(plateOut)]);
  if (beforePx.length !== afterPx.length) {
    throw new Error(`plate comparison: ${beforePx.length} vs ${afterPx.length} samples`);
  }
  let diff = 0;
  for (let i = 0; i < beforePx.length; i++) diff += Math.abs(beforePx[i] - afterPx[i]);
  const meanError = diff / beforePx.length;

  // Report, so the pipeline is auditable from the terminal.
  for (const row of rows) console.log(`  ${row.id.padEnd(15)} ${row.sheet.padEnd(9)} ${row.size.padEnd(9)} ${kb(row.bytes)}`);
  const total = rows.reduce((sum, row) => sum + row.bytes, 0);
  console.log(`\n  ${rows.length} cut-outs: ${kb(total)} (largest ${kb(Math.max(...rows.map((r) => r.bytes)))})`);
  console.log(
    `  plate: ${kb(plateBefore)} → ${kb(plateBytes)} (${plateMeta.width}x${plateMeta.height}), mean channel error ${meanError.toFixed(2)}/255`,
  );
  console.log(`  a town with 11 buildings transfers ~${kb(plateBytes + rows.slice(0, 11).reduce((s, r) => s + r.bytes, 0))}`);
}

slice().catch((error) => {
  console.error(error);
  process.exit(1);
});
