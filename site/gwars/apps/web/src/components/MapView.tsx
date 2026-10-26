import { useEffect, useRef, useState, type ReactNode } from 'react';
import { Map as MlMap, NavigationControl, setWorkerUrl, type ExpressionSpecification } from 'maplibre-gl';
// MapLibre looks for its worker file next to the script that imported it, which does not exist once the
// app is bundled. Vite bundles the worker (with its imports) into one file and gives us its URL.
import workerUrl from 'maplibre-gl/dist/maplibre-gl-worker.mjs?worker&url';
import type { FeatureCollection } from 'geojson';
import { cellToBoundary, cellToLatLng } from 'h3-js';
import type { CountryRef, HexRow } from '@geowars/rules';
import { fmtInt, useI18n } from '../i18n';
import { MAP_PALETTES, useTheme, type MapPalette } from '../theme';
import type { TextKey } from '../i18n/en';

export interface HexOwner {
  settlementId: number;
  ownerId: number;
  points: number;
}

setWorkerUrl(workerUrl);

/** What the hexes are coloured by. */
export type MapMode = 'owners' | 'countries' | 'food' | 'steel' | 'oil' | 'rare' | 'uranium';

/** Feature-state "kind" per hex. */
const KIND = { free: 0, mine: 1, player: 2, independent: 3 } as const;

const RESOURCE_TONES = {
  food: ['#5d7f4d', '#b4e36f'],
  steel: ['#5f7686', '#c1d2dd'],
  oil: ['#8a6a3c', '#ffb74d'],
  rare: ['#7d4a8f', '#e08cf5'],
  uranium: ['#7f8a35', '#e2f04f'],
} as const;

/** Colour ramp of a resource layer: [poor, average, rich]. Poor matches the theme's empty hexes. */
export function resourceRamp(mode: keyof typeof RESOURCE_TONES, palette: MapPalette): [string, string, string] {
  return [palette.free, ...RESOURCE_TONES[mode]];
}

interface Props {
  hexes: HexRow[];
  countries: Record<string, CountryRef>;
  owners: Map<number, HexOwner>;
  /** ownerId -> nation name */
  players: Record<number, string>;
  mode: MapMode;
  myId: number;
  selected: number | null;
  focus: { idx: number; seq: number } | null;
  onSelect: (idx: number) => void;
  /** Overlays drawn on top of the map (controls, legend). */
  children?: ReactNode;
}

/** Spreads hues by the golden angle so countries with neighbouring positions in the list look different. */
function countryColors(hexes: HexRow[]): Map<string, string> {
  const codes = [...new Set(hexes.map((h) => h[1]))].sort();
  return new Map(codes.map((code, i) => [code, `hsl(${Math.round((i * 137.508) % 360)} ${i % 2 ? 50 : 38}% ${i % 3 === 0 ? 34 : i % 3 === 1 ? 42 : 50}%)`]));
}

function hexFeatures(hexes: HexRow[]): FeatureCollection {
  const colors = countryColors(hexes);
  return {
    type: 'FeatureCollection',
    features: hexes.map(([h3, country, , food, steel, oil, rare, uranium], i) => {
      const ring = cellToBoundary(h3, true);
      // Hexes crossing the antimeridian: shift western points east so the polygon does not wrap the globe.
      const lngs = ring.map((p) => p[0]);
      if (Math.max(...lngs) - Math.min(...lngs) > 180) for (const p of ring) if (p[0] < 0) p[0] += 360;
      return {
        type: 'Feature',
        id: i,
        // Baked into the geometry so switching layers only swaps a paint expression.
        properties: { food, steel, oil, rare, uranium, cc: colors.get(country) },
        geometry: { type: 'Polygon', coordinates: [ring] },
      };
    }),
  };
}

function kindOf(owner: HexOwner | undefined, myId: number): number {
  if (!owner) return KIND.free;
  if (owner.ownerId === myId) return KIND.mine;
  return owner.ownerId ? KIND.player : KIND.independent;
}

const STATE_KIND: ExpressionSpecification = ['coalesce', ['feature-state', 'kind'], 0];
const HOVER: ExpressionSpecification = ['boolean', ['feature-state', 'hover'], false];

/** Colour of a hex by who holds it. */
function kindColor(p: MapPalette): ExpressionSpecification {
  return ['match', STATE_KIND, KIND.mine, p.mine, KIND.player, p.player, KIND.independent, p.independent, p.free];
}

/** Paint for the fill layer in each mode. */
function fillPaint(mode: MapMode, palette: MapPalette): { color: ExpressionSpecification; opacity: ExpressionSpecification } {
  if (mode === 'owners') {
    return {
      color: kindColor(palette),
      opacity: ['case', HOVER, 0.95, ['==', STATE_KIND, 0], 0.35, 0.8],
    };
  }
  const opacity: ExpressionSpecification = ['case', HOVER, 0.97, 0.85];
  if (mode === 'countries') return { color: ['get', 'cc'], opacity };
  const [poor, avg, rich] = resourceRamp(mode, palette);
  if (mode === 'rare' || mode === 'uranium') {
    // Strategic resources exist only in some hexes; the rest stay dark.
    return {
      color: ['case', ['>', ['get', mode], 0], ['interpolate', ['linear'], ['get', mode], 0.3, avg, 1.5, rich], poor],
      opacity,
    };
  }
  return { color: ['interpolate', ['linear'], ['get', mode], 0.4, poor, 1, avg, 2, rich], opacity };
}

export function MapView({ hexes, countries, owners, players, mode, myId, selected, focus, onSelect, children }: Props) {
  const { t, hexName, countryName } = useI18n();
  const { theme } = useTheme();
  const palette = MAP_PALETTES[theme];
  const paletteRef = useRef(palette);
  paletteRef.current = palette;
  const container = useRef<HTMLDivElement>(null);
  const mapRef = useRef<MlMap | null>(null);
  const kinds = useRef(new Map<number, number>());
  const selectedRef = useRef<number | null>(null);
  const modeRef = useRef(mode);
  modeRef.current = mode;
  const onSelectRef = useRef(onSelect);
  onSelectRef.current = onSelect;
  const [ready, setReady] = useState(false);
  const [hover, setHover] = useState<{ idx: number; x: number; y: number } | null>(null);

  useEffect(() => {
    const map = new MlMap({
      container: container.current!,
      style: {
        version: 8,
        projection: { type: 'globe' },
        sources: {},
        layers: [{ id: 'ocean', type: 'background', paint: { 'background-color': paletteRef.current.ocean } }],
      },
      center: [15, 30],
      zoom: 1.6,
      attributionControl: { compact: true, customAttribution: 'Natural Earth · GeoNames · H3' },
    });
    map.addControl(new NavigationControl({ showCompass: false }), 'bottom-right');
    mapRef.current = map;

    map.on('load', () => {
      map.addSource('countries', { type: 'geojson', data: '/geo/countries.geojson' });
      map.addSource('hexes', { type: 'geojson', data: hexFeatures(hexes) });

      const pal = paletteRef.current;
      const initial = fillPaint(modeRef.current, pal);
      map.addLayer({ id: 'country-fill', type: 'fill', source: 'countries', paint: { 'fill-color': pal.land } });
      map.addLayer({ id: 'hex-fill', type: 'fill', source: 'hexes', paint: { 'fill-color': initial.color, 'fill-opacity': initial.opacity } });
      map.addLayer({
        id: 'hex-line',
        type: 'line',
        source: 'hexes',
        paint: { 'line-color': pal.hexLine, 'line-width': 0.5, 'line-opacity': ['interpolate', ['linear'], ['zoom'], 1.5, 0, 3, 0.6] },
      });
      map.addLayer({ id: 'country-line', type: 'line', source: 'countries', paint: { 'line-color': pal.countryLine, 'line-width': 0.8, 'line-opacity': 0.55 } });
      // Settled hexes keep an outline in their owner's colour in every layer.
      map.addLayer({
        id: 'hex-owned',
        type: 'line',
        source: 'hexes',
        paint: {
          'line-color': ['match', STATE_KIND, KIND.mine, pal.mine, KIND.player, pal.player, pal.independent],
          // "zoom" may only feed a top-level interpolate, so the ownership test sits inside each stop.
          'line-width': ['interpolate', ['linear'], ['zoom'], 1.5, ['case', ['>', STATE_KIND, 0], 1.2, 0], 5, ['case', ['>', STATE_KIND, 0], 2.2, 0]],
          'line-opacity': 0.95,
        },
      });
      map.addLayer({
        id: 'hex-selected',
        type: 'line',
        source: 'hexes',
        paint: {
          'line-color': pal.selected,
          'line-width': ['case', ['boolean', ['feature-state', 'selected'], false], 2.5, 0],
        },
      });

      let hovered: number | null = null;
      map.on('mousemove', 'hex-fill', (e) => {
        const id = e.features?.[0]?.id as number | undefined;
        if (id === undefined) return;
        if (hovered !== null && hovered !== id) map.setFeatureState({ source: 'hexes', id: hovered }, { hover: false });
        hovered = id;
        map.setFeatureState({ source: 'hexes', id }, { hover: true });
        map.getCanvas().style.cursor = 'pointer';
        setHover({ idx: id, x: e.point.x, y: e.point.y });
      });
      map.on('mouseleave', 'hex-fill', () => {
        if (hovered !== null) map.setFeatureState({ source: 'hexes', id: hovered }, { hover: false });
        hovered = null;
        map.getCanvas().style.cursor = '';
        setHover(null);
      });
      map.on('click', 'hex-fill', (e) => {
        const id = e.features?.[0]?.id as number | undefined;
        if (id !== undefined) onSelectRef.current(id);
      });

      setReady(true);
    });

    return () => {
      // A rebuilt map starts with no style: effects that paint must wait for its own "load".
      setReady(false);
      map.remove();
      mapRef.current = null;
      kinds.current.clear();
    };
  }, [hexes]);

  // Layer or theme switch: only paint properties change.
  useEffect(() => {
    const map = mapRef.current;
    if (!ready || !map) return;
    const paint = fillPaint(mode, palette);
    map.setPaintProperty('hex-fill', 'fill-color', paint.color);
    map.setPaintProperty('hex-fill', 'fill-opacity', paint.opacity);
    map.setPaintProperty('ocean', 'background-color', palette.ocean);
    map.setPaintProperty('country-fill', 'fill-color', palette.land);
    map.setPaintProperty('hex-line', 'line-color', palette.hexLine);
    map.setPaintProperty('country-line', 'line-color', palette.countryLine);
    map.setPaintProperty('hex-owned', 'line-color', ['match', STATE_KIND, KIND.mine, palette.mine, KIND.player, palette.player, palette.independent]);
    map.setPaintProperty('hex-selected', 'line-color', palette.selected);
  }, [mode, palette, ready]);

  // The panel opens and closes next to the map; WebGL needs to be told its canvas changed size.
  useEffect(() => {
    const el = container.current;
    if (!el || typeof ResizeObserver === 'undefined') return;
    const observer = new ResizeObserver(() => mapRef.current?.resize());
    observer.observe(el);
    return () => observer.disconnect();
  }, []);

  // Ownership colors: only hexes whose kind changed are touched.
  useEffect(() => {
    const map = mapRef.current;
    if (!ready || !map) return;
    const next = new Map<number, number>();
    for (const [idx, owner] of owners) next.set(idx, kindOf(owner, myId));
    for (const [idx, kind] of next) {
      if (kinds.current.get(idx) !== kind) map.setFeatureState({ source: 'hexes', id: idx }, { kind });
    }
    for (const idx of kinds.current.keys()) {
      if (!next.has(idx)) map.setFeatureState({ source: 'hexes', id: idx }, { kind: KIND.free });
    }
    kinds.current = next;
  }, [owners, myId, ready]);

  useEffect(() => {
    const map = mapRef.current;
    if (!ready || !map) return;
    if (selectedRef.current !== null) map.setFeatureState({ source: 'hexes', id: selectedRef.current }, { selected: false });
    if (selected !== null) map.setFeatureState({ source: 'hexes', id: selected }, { selected: true });
    selectedRef.current = selected;
  }, [selected, ready]);

  useEffect(() => {
    const map = mapRef.current;
    if (!ready || !map || !focus) return;
    const [lat, lng] = cellToLatLng(hexes[focus.idx][0]);
    map.flyTo({ center: [lng, lat], zoom: Math.max(map.getZoom(), 4), duration: 1800 });
  }, [focus, ready, hexes]);

  const hoverHex = hover ? hexes[hover.idx] : null;
  const hoverOwner = hover ? owners.get(hover.idx) : undefined;

  return (
    <div className="map-wrap">
      <div ref={container} className="map" />
      {children}
      {hover && hoverHex && (
        <div className="map-tooltip" style={{ left: hover.x + 14, top: hover.y + 14 }}>
          <strong>{hexName(hoverHex, countries)}</strong>
          <span>{countryName(hoverHex[1], countries)}</span>
          {mode !== 'owners' && mode !== 'countries' && (
            <span>
              {t(`res.${mode}` as TextKey)} ×{(hoverHex[{ food: 3, steel: 4, oil: 5, rare: 6, uranium: 7 }[mode]] as number).toFixed(2)}
            </span>
          )}
          <span className="muted">
            {hoverOwner
              ? `${hoverOwner.ownerId ? (players[hoverOwner.ownerId] ?? t('map.unknownNation')) : t('map.independent')} · ${t('points', { n: fmtInt(hoverOwner.points) })}`
              : t('map.unclaimed')}
          </span>
        </div>
      )}
    </div>
  );
}
