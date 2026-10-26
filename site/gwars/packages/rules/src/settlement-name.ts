/**
 * Players can rename their settlements. Unlike nation names, these may contain any letters
 * (diacritics included), because real city names do: "București", "São Paulo".
 * Digits, spaces and hyphens are allowed too, with at most 2 spaces and 2 hyphens.
 */
export const SETTLEMENT_NAME_MIN = 3;
export const SETTLEMENT_NAME_MAX = 25;
export const SETTLEMENT_MAX_SPACES = 2;
export const SETTLEMENT_MAX_HYPHENS = 2;

export type SettlementNameIssue =
  | 'settlement_length'
  | 'settlement_start'
  | 'settlement_chars'
  | 'settlement_spaces'
  | 'settlement_hyphens'
  | 'settlement_separators';

const count = (s: string, ch: string) => s.split(ch).length - 1;

/** Returns why a settlement name is invalid as a translatable code, or null when it is valid. */
export function settlementNameIssue(name: string): SettlementNameIssue | null {
  const length = [...name].length;
  if (length < SETTLEMENT_NAME_MIN || length > SETTLEMENT_NAME_MAX) return 'settlement_length';
  if (!/^\p{L}/u.test(name)) return 'settlement_start';
  if (!/^[\p{L}\p{N} -]+$/u.test(name)) return 'settlement_chars';
  if (count(name, ' ') > SETTLEMENT_MAX_SPACES) return 'settlement_spaces';
  if (count(name, '-') > SETTLEMENT_MAX_HYPHENS) return 'settlement_hyphens';
  if (/[ -]{2}/.test(name) || /[ -]$/.test(name)) return 'settlement_separators';
  return null;
}

const ISSUE_TEXT: Record<SettlementNameIssue, string> = {
  settlement_length: `Settlement name must be ${SETTLEMENT_NAME_MIN}-${SETTLEMENT_NAME_MAX} characters`,
  settlement_start: 'Settlement name must start with a letter',
  settlement_chars: 'Only letters, digits, spaces and hyphens are allowed',
  settlement_spaces: `A settlement name can contain at most ${SETTLEMENT_MAX_SPACES} spaces`,
  settlement_hyphens: `A settlement name can contain at most ${SETTLEMENT_MAX_HYPHENS} hyphens`,
  settlement_separators: 'Spaces and hyphens cannot be doubled, side by side or at the end',
};

/** English text for an invalid settlement name, or null when it is valid. */
export function settlementNameError(name: string): string | null {
  const issue = settlementNameIssue(name);
  return issue && ISSUE_TEXT[issue];
}
