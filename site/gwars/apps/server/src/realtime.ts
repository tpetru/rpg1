import type { ServerMessage } from '@geowars/rules';
import type { WebSocket } from 'ws';

/**
 * In-process fan-out of server events to connected players, scoped per world.
 * When the API and engines run as separate processes this becomes a Redis pub/sub bridge.
 */
export class Realtime {
  /** worldId -> accountId -> sockets */
  private worlds = new Map<number, Map<number, Set<WebSocket>>>();

  add(worldId: number, accountId: number, socket: WebSocket): void {
    let accounts = this.worlds.get(worldId);
    if (!accounts) this.worlds.set(worldId, (accounts = new Map()));
    let set = accounts.get(accountId);
    if (!set) accounts.set(accountId, (set = new Set()));
    set.add(socket);
    socket.on('close', () => {
      set.delete(socket);
      if (set.size === 0) accounts.delete(accountId);
    });
  }

  sendTo(worldId: number, accountId: number, msg: ServerMessage): void {
    const data = JSON.stringify(msg);
    for (const socket of this.worlds.get(worldId)?.get(accountId) ?? []) socket.send(data);
  }

  broadcast(worldId: number, msg: ServerMessage): void {
    const data = JSON.stringify(msg);
    for (const set of this.worlds.get(worldId)?.values() ?? []) for (const socket of set) socket.send(data);
  }
}
