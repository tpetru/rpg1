import type { BuildingId } from '@geowars/rules';
import type { TextKey } from './i18n/en';

/** How the building catalogue is grouped in the settlement panel. Every building appears exactly once. */
export const CATALOGUE: { title: TextKey; ids: BuildingId[] }[] = [
  { title: 'panel.cat.government', ids: ['cityhall', 'commandcenter', 'parliament'] },
  { title: 'panel.cat.production', ids: ['farm', 'steelmill', 'oilfield'] },
  { title: 'panel.cat.services', ids: ['warehouse', 'housing', 'market', 'hospital', 'researchcenter', 'radar'] },
  { title: 'panel.cat.military', ids: ['bunker', 'barracks', 'fortifications', 'factory', 'airbase', 'port'] },
];
