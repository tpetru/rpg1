/** Output of build-world.ts, consumed by the server seed script. */
export interface WorldFile {
  res: number;
  generatedAt: string;
  sources: Record<string, string>;
  countries: { code: string; name: string; continent: string }[];
  hexes: WorldHex[];
}

export interface WorldHex {
  /** H3 index */
  h: string;
  lat: number;
  lng: number;
  /** Country code (Natural Earth ADM0_A3) */
  c: string;
  /** Landmass id, 0 = largest */
  lm: number;
  /** Display name */
  n: string;
  /** Multipliers: food, steel, oil, rare, uranium */
  p: [number, number, number, number, number];
}
