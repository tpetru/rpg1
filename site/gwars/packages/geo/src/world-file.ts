/** Output of build-world.ts, consumed by the server seed script. */
export interface WorldFile {
  res: number;
  generatedAt: string;
  sources: Record<string, string>;
  /** a2: ISO 3166-1 alpha-2 (null when Natural Earth has none) */
  countries: { code: string; name: string; continent: string; a2: string | null }[];
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
  /** Display name (English) */
  n: string;
  /** Translation key for generated names: "dir:NE:Paris", "frontier:3"; null for real city names */
  k: string | null;
  /** Multipliers: food, steel, oil, rare, uranium */
  p: [number, number, number, number, number];
}
