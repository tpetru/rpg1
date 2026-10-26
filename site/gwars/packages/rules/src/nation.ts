/** Nation names are chosen by the player per world: letters and digits only, starting with a letter. */
export const NATION_NAME_MIN = 3;
export const NATION_NAME_MAX = 20;

/** Returns why a nation name is invalid, or null when it is valid. */
export function nationNameError(name: string): string | null {
  if (name.length < NATION_NAME_MIN || name.length > NATION_NAME_MAX) {
    return `Nation name must be ${NATION_NAME_MIN}-${NATION_NAME_MAX} characters`;
  }
  if (!/^[A-Za-z]/.test(name)) return 'Nation name must start with a letter';
  if (!/^[A-Za-z0-9]+$/.test(name)) return 'Only letters and digits are allowed (no spaces or symbols)';
  return null;
}
