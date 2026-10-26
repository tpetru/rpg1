import { useI18n } from '../i18n';
import { useTheme } from '../theme';

export function ThemeToggle() {
  const { t } = useI18n();
  const { theme, toggle } = useTheme();
  const label = theme === 'light' ? t('theme.toDark') : t('theme.toLight');
  return (
    <button className="icon-button theme-toggle" onClick={toggle} title={label} aria-label={label}>
      {theme === 'light' ? '☾' : '☀'}
    </button>
  );
}
