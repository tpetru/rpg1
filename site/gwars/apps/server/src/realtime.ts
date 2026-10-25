import type { ServerMessage } from '@geowars/rules';
import type { WebSocket } from 'ws';

/**
 * In-process fan-out of server events to connected players.
 * When the API and engine run as separate processes this becomes a Redis pub/sub bridge.
 */
export class Realtime {
  private sockets = new Map<number, Set<WebSocket>>();

  add(accountId: number, socket: WebSocket): void {
    let set = this.sockets.get(accountId);
    if (!set) this.sockets.set(accountId, (set = new Set()));
    set.add(socket);
    socket.on('close', () => {
      set.delete(socket);
      if (set.size === 0) this.sockets.delete(accountId);
    });
  }

  sendTo(accountId: number, msg: ServerMessage): void {
    const data = JSON.stringify(msg);
    for (const socket of this.sockets.get(accountId) ?? []) socket.send(data);
  }

  broadcast(msg: ServerMessage): void {
    const data = JSON.stringify(msg);
    for (const set of this.sockets.values()) for (const socket of set) socket.send(data);
  }
}
