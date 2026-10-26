import { LANGS, useI18n, type Lang } from '../i18n';

export function LanguageSwitch() {
  const { lang, setLang, t } = useI18n();
  return (
    <select className="lang-switch" value={lang} onChange={(e) => setLang(e.target.value as Lang)} aria-label={t('lang.label')} title={t('lang.label')}>
      {LANGS.map((l) => (
        <option key={l.code} value={l.code}>
          {l.label}
        </option>
      ))}
    </select>
  );
}
