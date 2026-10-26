import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from 'react';

export type Theme = 'light' | 'dark';
const STORAGE_KEY = 'gw.theme';
const DEFAULT_THEME: Theme = 'light';

function readSavedTheme(): Theme {
  try {
    const saved = localStorage.getItem(STORAGE_KEY);
    if (saved === 'light' || saved === 'dark') return saved;
  } catch {
    // storage unavailable (private mode): use the default
  }
  return DEFAULT_THEME;
}

interface ThemeValue {
  theme: Theme;
  setTheme: (theme: Theme) => void;
  toggle: () => void;
}

const Context = createContext<ThemeValue | null>(null);

/** Colours the map draws itself (it paints with WebGL, so CSS variables do not reach it). */
export interface MapPalette {
  ocean: string;
  land: string;
  hexLine: string;
  countryLine: string;
  /** Hexes nobody holds */
  free: string;
  mine: string;
  player: string;
  independent: string;
  selected: string;
}

export const MAP_PALETTES: Record<Theme, MapPalette> = {
  light: {
    ocean: '#181715',
    land: '#252320',
    hexLine: '#5b5346',
    countryLine: '#a89c85',
    free: '#2d2924',
    mine: '#cc785c',
    player: '#5f9a8f',
    independent: '#a09d96',
    selected: '#faf9f5',
  },
  dark: {
    ocean: '#0a1724',
    land: '#1a2b3b',
    hexLine: '#4d6b86',
    countryLine: '#8fb3d1',
    free: '#2a4157',
    mine: '#3ddc84',
    player: '#e8644f',
    independent: '#9aa5b1',
    selected: '#ffd54a',
  },
};

export function ThemeProvider({ children }: { children: ReactNode }) {
  const [theme, setThemeState] = useState<Theme>(readSavedTheme);

  const setTheme = useCallback((next: Theme) => {
    try {
      localStorage.setItem(STORAGE_KEY, next);
    } catch {
      // ignore
    }
    setThemeState(next);
  }, []);

  // Applied before paint so the page never flashes the wrong theme.
  useEffect(() => {
    document.documentElement.dataset.theme = theme;
  }, [theme]);

  const value = useMemo<ThemeValue>(
    () => ({ theme, setTheme, toggle: () => setTheme(theme === 'light' ? 'dark' : 'light') }),
    [theme, setTheme],
  );
  return <Context.Provider value={value}>{children}</Context.Provider>;
}

export function useTheme(): ThemeValue {
  const value = useContext(Context);
  if (!value) throw new Error('useTheme must be used inside <ThemeProvider>');
  return value;
}
