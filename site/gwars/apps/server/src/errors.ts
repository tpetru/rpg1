/** Validation failures reported by zod schemas: the schema message is the code, this is its English text. */
export const VALIDATION_MESSAGES: Record<string, string> = {
  username_invalid: 'Username: 3-24 letters, digits or _',
  password_short: 'Password must have at least 8 characters',
  email_invalid: 'Enter a valid email address',
};

/**
 * An expected failure shown to the player. `code` (with `params`) lets clients show it in the
 * player's language; `message` is the English fallback.
 */
export class GameError extends Error {
  constructor(
    message: string,
    public status = 400,
    public code?: string,
    public params?: Record<string, string | number>,
  ) {
    super(message);
  }
}
