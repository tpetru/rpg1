/** A resource multiplier (0.4–2.0) shown as a small bar. */
export function Multiplier({ label, value, kind }: { label: string; value: number; kind: string }) {
  return (
    <div className="mult" title={`${label} ×${value.toFixed(2)}`}>
      <span className="mult-label">{label}</span>
      <span className="mult-track">
        <span className={`mult-fill ${kind}`} style={{ width: `${Math.min(100, (value / 2) * 100)}%` }} />
      </span>
      <span className="mult-value">×{value.toFixed(2)}</span>
    </div>
  );
}
