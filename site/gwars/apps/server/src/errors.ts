/** An expected failure whose message is safe to show to the player. */
export class GameError extends Error {
  constructor(
    message: string,
    public status = 400,
  ) {
    super(message);
  }
}
