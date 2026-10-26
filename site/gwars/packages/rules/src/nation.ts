/**
 * Nation names are chosen by the player per world: letters, digits, spaces and hyphens,
 * starting with a letter, with at most 2 spaces and at most 2 hyphens.
 */
export const NATION_NAME_MIN = 3;
export const NATION_NAME_MAX = 20;
export const NATION_MAX_SPACES = 2;
export const NATION_MAX_HYPHENS = 2;

export type NationNameIssue =
  | 'nation_length'
  | 'nation_start'
  | 'nation_chars'
  | 'nation_spaces'
  | 'nation_hyphens'
  | 'nation_separators';

const count = (s: string, ch: string) => s.split(ch).length - 1;

/** Returns why a nation name is invalid as a translatable code, or null when it is valid. */
export function nationNameIssue(name: string): NationNameIssue | null {
  if (name.length < NATION_NAME_MIN || name.length > NATION_NAME_MAX) return 'nation_length';
  if (!/^[A-Za-z]/.test(name)) return 'nation_start';
  if (!/^[A-Za-z0-9 -]+$/.test(name)) return 'nation_chars';
  if (count(name, ' ') > NATION_MAX_SPACES) return 'nation_spaces';
  if (count(name, '-') > NATION_MAX_HYPHENS) return 'nation_hyphens';
  // No doubled or trailing separators: "New  Rome", "New - Rome" and "Rome-" are rejected.
  if (/[ -]{2}/.test(name) || /[ -]$/.test(name)) return 'nation_separators';
  return null;
}

const ISSUE_TEXT: Record<NationNameIssue, string> = {
  nation_length: `Nation name must be ${NATION_NAME_MIN}-${NATION_NAME_MAX} characters`,
  nation_start: 'Nation name must start with a letter',
  nation_chars: 'Only letters, digits, spaces and hyphens are allowed',
  nation_spaces: `A nation name can contain at most ${NATION_MAX_SPACES} spaces`,
  nation_hyphens: `A nation name can contain at most ${NATION_MAX_HYPHENS} hyphens`,
  nation_separators: 'Spaces and hyphens cannot be doubled, side by side or at the end',
};

/** English text for an invalid nation name, or null when it is valid. */
export function nationNameError(name: string): string | null {
  const issue = nationNameIssue(name);
  return issue && ISSUE_TEXT[issue];
}

/** Account rules, shared so the client can validate before submitting. */
export const USERNAME_PATTERN = /^[A-Za-z0-9_]{3,24}$/;
export const PASSWORD_MIN = 8;
