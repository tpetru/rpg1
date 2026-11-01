import { useI18n } from '../i18n';

interface Props {
  /** The settlement to return to, named on the pill. */
  name: string;
  onBack: () => void;
}

/**
 * The hall pages' back control: a hairline pill with a drawn chevron, not a floating text link.
 * It reads as a control before it reads as a sentence, and the chevron slides on hover so the
 * way back is obvious even to someone skimming.
 */
export function BackButton({ name, onBack }: Props) {
  const { t } = useI18n();
  return (
    <button type="button" className="back-pill" onClick={onBack}>
      <svg viewBox="0 0 16 16" width="11" height="11" aria-hidden="true" focusable="false">
        <path fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round" d="M10 2.5 4.5 8 10 13.5" />
      </svg>
      {t('hall.back', { name })}
    </button>
  );
}
