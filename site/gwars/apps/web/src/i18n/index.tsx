import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from 'react';
import type { ApiErrorBody, BuildingId, CountryRef, HexRow } from '@geowars/rules';
import { en, type Dictionary, type TextKey } from './en';
import { ro } from './ro';

export type Lang = 'ro' | 'en';
export const LANGS: { code: Lang; label: string }[] = [
  { code: 'ro', label: 'Română' },
  { code: 'en', label: 'English' },
];

const DICTIONARIES: Record<Lang, Dictionary> = { en, ro };
const LOCALES: Record<Lang, string> = { ro: 'ro-RO', en: 'en-US' };
const STORAGE_KEY = 'gw.lang';
const DEFAULT_LANG: Lang = 'ro';

type Params = Record<string, string | number | undefined>;

function readSavedLang(): Lang {
  try {
    const saved = localStorage.getItem(STORAGE_KEY);
    if (saved === 'ro' || saved === 'en') return saved;
  } catch {
    // storage unavailable (private mode): use the default
  }
  return DEFAULT_LANG;
}

function interpolate(text: string, params?: Params): string {
  return params ? text.replace(/\{(\w+)\}/g, (match, name: string) => String(params[name] ?? match)) : text;
}

// Number formatting lives outside React so plain helpers can use it; the provider keeps it in sync.
let currentLang: Lang = readSavedLang();
let numberFormat = new Intl.NumberFormat(LOCALES[currentLang]);

/** Whole number in the current language, e.g. 12.345 (ro) or 12,345 (en). */
export function fmtInt(n: number): string {
  return numberFormat.format(Math.floor(n));
}

const regionNames = new Map<Lang, Intl.DisplayNames | null>();
function regionNamesFor(lang: Lang): Intl.DisplayNames | null {
  if (!regionNames.has(lang)) {
    try {
      regionNames.set(lang, new Intl.DisplayNames([LOCALES[lang]], { type: 'region' }));
    } catch {
      regionNames.set(lang, null);
    }
  }
  return regionNames.get(lang) ?? null;
}

interface I18n {
  lang: Lang;
  setLang: (lang: Lang) => void;
  t: (key: TextKey, params?: Params) => string;
  /** Message for an API error: translated by its code when known, otherwise the server's English text. */
  errorText: (err: unknown) => string;
  /** Message for a code that has no server response (client-side validation), e.g. a build blocker. */
  codeText: (code: string, params?: Params, fallback?: string) => string;
  buildingName: (id: BuildingId) => string;
  countryName: (code: string, countries: Record<string, CountryRef>) => string;
  hexName: (hex: HexRow, countries: Record<string, CountryRef>) => string;
}

const Context = createContext<I18n | null>(null);

export function I18nProvider({ children }: { children: ReactNode }) {
  const [lang, setLangState] = useState<Lang>(currentLang);

  const setLang = useCallback((next: Lang) => {
    currentLang = next;
    numberFormat = new Intl.NumberFormat(LOCALES[next]);
    try {
      localStorage.setItem(STORAGE_KEY, next);
    } catch {
      // ignore
    }
    setLangState(next);
  }, []);

  useEffect(() => {
    document.documentElement.lang = lang;
  }, [lang]);

  const value = useMemo<I18n>(() => {
    const dict = DICTIONARIES[lang];
    const t: I18n['t'] = (key, params) => interpolate(dict[key], params);
    const has = (key: string): key is TextKey => key in dict;

    const codeText: I18n['codeText'] = (code, params, fallback) => {
      const key = `err.${code}`;
      if (!has(key)) return fallback ?? code;
      // Parameters naming a building are shown by the building's translated name.
      const resolved: Params = { ...params };
      if (typeof resolved.building === 'string') resolved.building = t(`building.${resolved.building}.name` as TextKey);
      return t(key, resolved);
    };

    const countryName: I18n['countryName'] = (code, countries) => {
      const ref = countries[code];
      if (!ref) return code;
      if (ref.a2) {
        const localized = regionNamesFor(lang)?.of(ref.a2);
        if (localized && localized !== ref.a2) return localized;
      }
      return ref.name;
    };

    const hexName: I18n['hexName'] = (hex, countries) => {
      const [, country, name, , , , , , key] = hex;
      if (!key) return name;
      const [kind, ...rest] = key.split(':');
      if (kind === 'frontier') return t('hex.frontier', { n: rest[0], country: countryName(country, countries) });
      if (kind === 'dir') {
        const [dir, ...city] = rest;
        return t('hex.dir', { dir: t(`dir.${dir}` as TextKey), city: city.join(':') });
      }
      return name;
    };

    return {
      lang,
      setLang,
      t,
      codeText,
      errorText: (err) => {
        const body = (err as { body?: ApiErrorBody }).body;
        if (body?.code) return codeText(body.code, body.params, body.error);
        return err instanceof Error ? err.message : String(err);
      },
      buildingName: (id) => t(`building.${id}.name` as TextKey),
      countryName,
      hexName,
    };
  }, [lang, setLang]);

  return <Context.Provider value={value}>{children}</Context.Provider>;
}

export function useI18n(): I18n {
  const value = useContext(Context);
  if (!value) throw new Error('useI18n must be used inside <I18nProvider>');
  return value;
}
