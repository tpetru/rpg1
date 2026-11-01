import { Fragment, useEffect, useRef, useState, type ReactNode } from 'react';
import { Map as MlMap, NavigationControl, setWorkerUrl, type ExpressionSpecification, type GeoJSONSource } from 'maplibre-gl';
// MapLibre looks for its worker file next to the script that imported it, which does not exist once the
// app is bundled. Vite bundles the worker (with its imports) into one file and gives us its URL.
import workerUrl from 'maplibre-gl/dist/maplibre-gl-worker.mjs?worker&url';
import type { FeatureCollection } from 'geojson';
import { cellToBoundary, cellToLatLng } from 'h3-js';
import type { CommandDto, CountryRef, HexRow, IncomingCommandDto } from '@geowars/rules';
import { drawArrowImages, drawMarkerImages, markerShare, markerTier } from '../art/mapMarkers';
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
const KIND = { free: 0, mine: 1, player: 2, independent: 3, current: 4 } as const;

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

export interface MapAction {
  id: string;
  label: string;
  icon: ReactNode;
  disabled?: boolean;
  /** Danger handles wear the enemy red; neutral ones the plain overlay ink. */
  tone?: 'danger' | 'neutral';
  onClick: () => void;
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
  /** What can be done with the settlement on a clicked hex; none means no menu opens. */
  actions?: (idx: number) => MapAction[];
  /** My armies in flight: attack routes out, return routes home. */
  commands?: CommandDto[];
  /** Enemy armies in flight towards my settlements. */
  incoming?: IncomingCommandDto[];
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

function kindOf(owner: HexOwner | undefined, myId: number, isCurrent = false): number {
  if (!owner) return KIND.free;
  if (owner.ownerId === myId) return isCurrent ? KIND.current : KIND.mine;
  return owner.ownerId ? KIND.player : KIND.independent;
}

const STATE_KIND: ExpressionSpecification = ['coalesce', ['feature-state', 'kind'], 0];
const HOVER: ExpressionSpecification = ['boolean', ['feature-state', 'hover'], false];

/** Colour of a hex by who holds it. */
function kindColor(p: MapPalette): ExpressionSpecification {
  return ['match', STATE_KIND, KIND.mine, p.mine, KIND.current, p.current, KIND.player, p.player, KIND.independent, p.independent, p.free];
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

/** The map is dark in both themes, so one bright red reads as the enemy everywhere. */
const FOE_RED = '#ff6b5e';

/** The marker silhouettes and route chevrons for the current theme; repainted on theme switch. */
function registerGlyphImages(map: MlMap, theme: 'light' | 'dark') {
  const fill = theme === 'dark' ? '#e3edf6' : '#faf9f5';
  const ink = theme === 'dark' ? '#08131e' : '#141413';
  const pal = MAP_PALETTES[theme];
  const images = [
    ...drawMarkerImages(fill, ink),
    // The chevrons wear the same colours as the lines they ride.
    ...drawArrowImages({ mine: pal.mine, foe: FOE_RED, ret: pal.independent }),
  ];
  for (const { id, image } of images) {
    if (map.hasImage(id)) map.removeImage(id);
    map.addImage(id, image);
  }
}

/** A march between two hexes, as a line feature between their centres. */
function routeFeatures(hexes: HexRow[], commands: CommandDto[], incoming: IncomingCommandDto[]) {
  const point = (idx: number): [number, number] => {
    const [lat, lng] = cellToLatLng(hexes[idx][0]);
    return [lng, lat];
  };
  const line = (cmd: CommandDto, side: 'mine' | 'foe') => {
    // A return keeps the attack's endpoints: origin is home, target is the field the army
    // left — so the troops physically fly target → origin, and the chevrons must too.
    const [from, to] = cmd.type === 'return' ? [cmd.targetIdx, cmd.originIdx] : [cmd.originIdx, cmd.targetIdx];
    return {
      type: 'Feature' as const,
      properties: { side, kind: cmd.type },
      geometry: { type: 'LineString' as const, coordinates: [point(from), point(to)] },
    };
  };
  return {
    type: 'FeatureCollection' as const,
    features: [...commands.map((c) => line(c, 'mine' as const)), ...incoming.map((c) => line(c, 'foe' as const))],
  };
}

export function MapView({ hexes, countries, owners, players, mode, myId, selected, focus, onSelect, actions, commands = [], incoming = [], children }: Props) {
  const { t, hexName, countryName } = useI18n();
  const { theme } = useTheme();
  const palette = MAP_PALETTES[theme];
  const paletteRef = useRef(palette);
  paletteRef.current = palette;
  const themeRef = useRef(theme);
  themeRef.current = theme;
  const container = useRef<HTMLDivElement>(null);
  const mapRef = useRef<MlMap | null>(null);
  const kinds = useRef(new Map<number, number>());
  const selectedRef = useRef<number | null>(null);
  const modeRef = useRef(mode);
  modeRef.current = mode;
  const onSelectRef = useRef(onSelect);
  onSelectRef.current = onSelect;
  const hexesRef = useRef(hexes);
  hexesRef.current = hexes;
  const actionsRef = useRef(actions);
  actionsRef.current = actions;
  const [ready, setReady] = useState(false);
  const [hover, setHover] = useState<{ idx: number; x: number; y: number } | null>(null);
  const [menu, setMenu] = useState<{ idx: number; x: number; y: number } | null>(null);

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
          'line-color': ['match', STATE_KIND, KIND.mine, pal.mine, KIND.current, pal.current, KIND.player, pal.player, pal.independent],
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

      // Settlement markers: one silhouette per size tier, in the owner's colour. Registered as
      // raster images (not SDF) so each glyph keeps its outline; repainted on theme switch.
      registerGlyphImages(map, themeRef.current);
      map.addSource('markers', { type: 'geojson', data: { type: 'FeatureCollection', features: [] } });
      map.addLayer({
        id: 'hex-markers',
        type: 'symbol',
        source: 'markers',
        layout: {
          'icon-image': ['concat', 'settlement-', ['get', 'tier']],
          'icon-size': ['interpolate', ['linear'], ['zoom'], 1.5, 0.18, 3, 0.3, 5, 0.46, 7, 0.6],
          'icon-anchor': 'center',
          // The glyph's mass sits above its ground line; a small downward nudge centres it in the hex.
          'icon-offset': ['literal', [0, 0.22]],
          'icon-allow-overlap': true,
          'icon-ignore-placement': true,
        },
      });

      // March routes: hairlines, not ribbons. Everything is a thin solid stroke; only the
      // enemy line breaks into dashes, and returns recede by opacity instead of pattern.
      map.addSource('routes', { type: 'geojson', data: { type: 'FeatureCollection', features: [] } });
      map.addLayer(
        {
          id: 'route-lines',
          type: 'line',
          source: 'routes',
          paint: {
            'line-color': ['case', ['==', ['get', 'side'], 'foe'], FOE_RED, ['==', ['get', 'kind'], 'return'], pal.independent, pal.mine],
            'line-width': ['interpolate', ['linear'], ['zoom'], 2, 1, 4, 1.4, 7, 1.8],
            'line-dasharray': ['case', ['==', ['get', 'side'], 'foe'], ['literal', [1.6, 1.8]], ['literal', [1, 0]]],
            'line-opacity': ['case', ['==', ['get', 'side'], 'foe'], 0.7, ['==', ['get', 'kind'], 'return'], 0.35, 0.55],
          },
        },
        'hex-markers',
      );
      // Direction chevrons riding each route in the direction of travel (for a return, home).
      // Placed along the line, they rotate with its heading.
      map.addLayer(
        {
          id: 'route-arrows',
          type: 'symbol',
          source: 'routes',
          layout: {
            'symbol-placement': 'line',
            'symbol-spacing': 64,
            'icon-image': [
              'case',
              ['==', ['get', 'side'], 'foe'],
              'route-arrow-foe',
              ['==', ['get', 'kind'], 'return'],
              'route-arrow-return',
              'route-arrow-mine',
            ],
            'icon-size': ['interpolate', ['linear'], ['zoom'], 2, 0.4, 4, 0.55, 7, 0.75],
            'icon-rotation-alignment': 'map',
            'icon-pitch-alignment': 'map',
            'icon-allow-overlap': true,
            'icon-ignore-placement': true,
          },
          paint: {
            'icon-opacity': ['case', ['==', ['get', 'side'], 'foe'], 0.9, ['==', ['get', 'kind'], 'return'], 0.45, 0.75],
          },
        },
        'hex-markers',
      );

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
        if (id === undefined) return;
        onSelectRef.current(id);
        if (!actionsRef.current?.(id).length) return setMenu(null);
        // The menu sits on the settlement itself, not on the cursor.
        const [lat, lng] = cellToLatLng(hexesRef.current[id][0]);
        const p = map.project([lng, lat]);
        setMenu({ idx: id, x: p.x, y: p.y });
      });
      map.on('movestart', () => setMenu(null));

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
    map.setPaintProperty('hex-owned', 'line-color', ['match', STATE_KIND, KIND.mine, palette.mine, KIND.current, palette.current, KIND.player, palette.player, palette.independent]);
    map.setPaintProperty('hex-selected', 'line-color', palette.selected);
    map.setPaintProperty('route-lines', 'line-color', ['case', ['==', ['get', 'side'], 'foe'], FOE_RED, ['==', ['get', 'kind'], 'return'], palette.independent, palette.mine]);
    registerGlyphImages(map, theme);
  }, [mode, palette, theme, ready]);

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
    for (const [idx, owner] of owners) next.set(idx, kindOf(owner, myId, idx === selected));
    for (const [idx, kind] of next) {
      if (kinds.current.get(idx) !== kind) map.setFeatureState({ source: 'hexes', id: idx }, { kind });
    }
    for (const idx of kinds.current.keys()) {
      if (!next.has(idx)) map.setFeatureState({ source: 'hexes', id: idx }, { kind: KIND.free });
    }
    kinds.current = next;

    // Every owned hex carries its size silhouette at the hex's centre.
    (map.getSource('markers') as GeoJSONSource | undefined)?.setData({
      type: 'FeatureCollection',
      features: [...owners.entries()].map(([idx, owner]) => {
        const [lat, lng] = cellToLatLng(hexes[idx][0]);
        return {
          type: 'Feature' as const,
          properties: { kind: kindOf(owner, myId, idx === selected), tier: markerTier(owner.points) },
          geometry: { type: 'Point' as const, coordinates: [lng, lat] },
        };
      }),
    });
  }, [owners, myId, selected, hexes, ready]);

  // Armies in flight: redraw the route lines whenever a command starts or lands.
  useEffect(() => {
    const map = mapRef.current;
    if (!ready || !map) return;
    (map.getSource('routes') as GeoJSONSource | undefined)?.setData(routeFeatures(hexes, commands, incoming));
  }, [commands, incoming, hexes, ready]);

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

  useEffect(() => {
    if (!menu) return;
    const onKey = (e: KeyboardEvent) => e.key === 'Escape' && setMenu(null);
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [menu]);

  const menuActions = menu ? (actions?.(menu.idx) ?? []) : [];
  const hoverHex = hover ? hexes[hover.idx] : null;
  const hoverOwner = hover ? owners.get(hover.idx) : undefined;

  return (
    <div className="map-wrap">
      <div ref={container} className="map" />
      {children}
      {hover && hoverHex && hoverOwner && !menu && (
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
          {hoverOwner && <span className="muted">{t('map.tipSize', { n: markerShare(hoverOwner.points) })}</span>}
        </div>
      )}
      {menu && menuActions.length > 0 && (
        <div className="map-menu" role="menu" style={{ left: menu.x, top: menu.y }} onMouseDown={(e) => e.stopPropagation()}>
          {menuActions.map((a, i) => (
            <Fragment key={a.id}>
              {i > 0 && <span className="map-menu-sep" aria-hidden="true" />}
              <button
                role="menuitem"
                className={`map-act ${a.tone === 'danger' ? 'danger' : 'neutral'}`}
                disabled={a.disabled}
                aria-label={a.label}
                title={a.label}
                onClick={() => {
                  setMenu(null);
                  a.onClick();
                }}
              >
                {a.icon}
              </button>
            </Fragment>
          ))}
        </div>
      )}
    </div>
  );
}
