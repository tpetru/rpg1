export const RESOURCES = ['food', 'steel', 'oil'] as const;
export type Resource = (typeof RESOURCES)[number];
export type ResourceBag = Record<Resource, number>;

/** Strategic resources only exist in some hexes. Extraction arrives in a later milestone. */
export const STRATEGIC = ['rare', 'uranium'] as const;
export type StrategicResource = (typeof STRATEGIC)[number];

/** Per-hex production multipliers derived from real-world data. 0 = not present. */
export type ResourceProfile = Record<Resource | StrategicResource, number>;

export const RESOURCE_LABELS: Record<Resource | StrategicResource, string> = {
  food: 'Food',
  steel: 'Steel',
  oil: 'Oil',
  rare: 'Rare earths',
  uranium: 'Uranium',
};

export function mapBag(fn: (r: Resource) => number): ResourceBag {
  return { food: fn('food'), steel: fn('steel'), oil: fn('oil') };
}

export function canAfford(stock: ResourceBag, cost: ResourceBag): boolean {
  return RESOURCES.every((r) => stock[r] >= cost[r]);
}
