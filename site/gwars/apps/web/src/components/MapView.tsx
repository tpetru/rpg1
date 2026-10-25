import { useEffect, useRef, useState } from 'react';
import { Map as MlMap, NavigationControl } from 'maplibre-gl';
import type { FeatureCollection } from 'geojson';
import { cellToBoundary, cellToLatLng } from 'h3-js';
import type { HexRow } from '@geowars/rules';

export interface HexOwner {
  settlementId: number;
  ownerId: number;
  points: number;
}

/** Feature-state "kind" per hex. */
const KIND = { free: 0, mine: 1, player: 2, independent: 3 } as const;

interface Props {
  hexes: HexRow[];
  countries: Record<string, string>;
  owners: Map<number, HexOwner>;
  myId: number;
  selected: number | null;
  focus: { idx: number; seq: number } | null;
  onSelect: (idx: number) => void;
}

function hexFeatures(hexes: HexRow[]): FeatureCollection {
  return {
    type: 'FeatureCollection',
    features: hexes.map(([h3], i) => {
      const ring = cellToBoundary(h3, true);
      // Hexes crossing the antimeridian: shift western points east so the polygon does not wrap the globe.
      const lngs = ring.map((p) => p[0]);
      if (Math.max(...lngs) - Math.min(...lngs) > 180) for (const p of ring) if (p[0] < 0) p[0] += 360;
      return { type: 'Feature', id: i, properties: {}, geometry: { type: 'Polygon', coordinates: [ring] } };
    }),
  };
}

function kindOf(owner: HexOwner | undefined, myId: number): number {
  if (!owner) return KIND.free;
  if (owner.ownerId === myId) return KIND.mine;
  return owner.ownerId ? KIND.player : KIND.independent;
}

export function MapView({ hexes, countries, owners, myId, selected, focus, onSelect }: Props) {
  const container = useRef<HTMLDivElement>(null);
  const mapRef = useRef<MlMap | null>(null);
  const kinds = useRef(new Map<number, number>());
  const selectedRef = useRef<number | null>(null);
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
        layers: [{ id: 'ocean', type: 'background', paint: { 'background-color': '#0a1724' } }],
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

      map.addLayer({ id: 'country-fill', type: 'fill', source: 'countries', paint: { 'fill-color': '#1a2b3b' } });
      map.addLayer({
        id: 'hex-fill',
        type: 'fill',
        source: 'hexes',
        paint: {
          'fill-color': [
            'match',
            ['coalesce', ['feature-state', 'kind'], 0],
            KIND.mine, '#3ddc84',
            KIND.player, '#e8644f',
            KIND.independent, '#9aa5b1',
            '#2a4157',
          ],
          'fill-opacity': [
            'case',
            ['boolean', ['feature-state', 'hover'], false], 0.95,
            ['==', ['coalesce', ['feature-state', 'kind'], 0], 0], 0.35,
            0.8,
          ],
        },
      });
      map.addLayer({
        id: 'hex-line',
        type: 'line',
        source: 'hexes',
        paint: { 'line-color': '#4d6b86', 'line-width': 0.5, 'line-opacity': ['interpolate', ['linear'], ['zoom'], 1.5, 0, 3, 0.6] },
      });
      map.addLayer({ id: 'country-line', type: 'line', source: 'countries', paint: { 'line-color': '#8fb3d1', 'line-width': 0.8, 'line-opacity': 0.55 } });
      map.addLayer({
        id: 'hex-selected',
        type: 'line',
        source: 'hexes',
        paint: {
          'line-color': '#ffd54a',
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
      map.remove();
      mapRef.current = null;
      kinds.current.clear();
    };
  }, [hexes]);

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
      {hover && hoverHex && (
        <div className="map-tooltip" style={{ left: hover.x + 14, top: hover.y + 14 }}>
          <strong>{hoverHex[2]}</strong>
          <span>{countries[hoverHex[1]] ?? hoverHex[1]}</span>
          <span className="muted">{hoverOwner ? `${hoverOwner.points} points` : 'Unclaimed'}</span>
        </div>
      )}
    </div>
  );
}
