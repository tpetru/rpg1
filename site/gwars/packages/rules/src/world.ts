import type { ResourceBag } from './resources';

/** Per-world tuning, stored as JSON on the world row. Same idea as Tribal Wars world settings. */
export interface WorldSettings {
  /** Multiplies resource production. */
  speed: number;
  /** Divides building construction times. */
  constructionSpeed: number;
  /** Divides troop training times. */
  recruitSpeed: number;
  /** Multiplies how fast troops travel (attack and return). */
  warSpeed: number;
  buildQueueSlots: number;
  startingResources: ResourceBag;
  /** Share of the cost returned when a queued building is cancelled. */
  cancelRefund: number;
}

export const DEFAULT_WORLD_SETTINGS: WorldSettings = {
  speed: 1,
  constructionSpeed: 1,
  recruitSpeed: 1,
  warSpeed: 1,
  buildQueueSlots: 2,
  startingResources: { food: 500, steel: 500, oil: 500 },
  cancelRefund: 0.9,
};

export function resolveWorldSettings(stored: Partial<WorldSettings>): WorldSettings {
  return { ...DEFAULT_WORLD_SETTINGS, ...stored };
}

export const SPEED_KEYS = ['speed', 'constructionSpeed', 'recruitSpeed', 'warSpeed'] as const;
export type SpeedKey = (typeof SPEED_KEYS)[number];
export const SPEED_MIN = 0.1;
export const SPEED_MAX = 100000;
