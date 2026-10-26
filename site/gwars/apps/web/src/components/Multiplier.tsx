import type { Resource } from '@geowars/rules';
import { useI18n } from '../i18n';
import type { TextKey } from '../i18n/en';

/** A resource multiplier (0.4–2.0) shown as a small bar. */
export function Multiplier({ resource, value }: { resource: Resource; value: number }) {
  const { t } = useI18n();
  const label = t(`res.${resource}` as TextKey);
  return (
    <div className="mult" title={`${label} ×${value.toFixed(2)}`}>
      <span className="mult-label">{label}</span>
      <span className="mult-track">
        <span className={`mult-fill ${resource}`} style={{ width: `${Math.min(100, (value / 2) * 100)}%` }} />
      </span>
      <span className="mult-value">×{value.toFixed(2)}</span>
    </div>
  );
}
