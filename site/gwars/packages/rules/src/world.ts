import type { ResourceBag } from './resources';

/** Per-world tuning, stored as JSON on the world row. Same idea as Tribal Wars world settings. */
export interface WorldSettings {
  /** Multiplies production and divides build times. */
  speed: number;
  buildQueueSlots: number;
  startingResources: ResourceBag;
  /** Share of the cost returned when a queued building is cancelled. */
  cancelRefund: number;
}

export const DEFAULT_WORLD_SETTINGS: WorldSettings = {
  speed: 1,
  buildQueueSlots: 2,
  startingResources: { food: 500, steel: 500, oil: 500 },
  cancelRefund: 0.9,
};

export function resolveWorldSettings(stored: Partial<WorldSettings>): WorldSettings {
  return { ...DEFAULT_WORLD_SETTINGS, ...stored };
}
