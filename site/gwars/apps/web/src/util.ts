import { useEffect, useRef, useState } from 'react';
import type { ServerMessage } from '@geowars/rules';

const intFormat = new Intl.NumberFormat('en-US');

export function fmtInt(n: number): string {
  return intFormat.format(Math.floor(n));
}

export function fmtDuration(totalSec: number): string {
  const s = Math.max(0, Math.ceil(totalSec));
  const h = Math.floor(s / 3600);
  const m = Math.floor((s % 3600) / 60);
  const sec = s % 60;
  const pad = (x: number) => String(x).padStart(2, '0');
  return h > 0 ? `${h}:${pad(m)}:${pad(sec)}` : `${m}:${pad(sec)}`;
}

/** Re-renders every `intervalMs` and returns the current time. */
export function useNow(intervalMs = 1000): number {
  const [now, setNow] = useState(Date.now);
  useEffect(() => {
    const t = setInterval(() => setNow(Date.now()), intervalMs);
    return () => clearInterval(t);
  }, [intervalMs]);
  return now;
}

/** Remembers small per-browser preferences; storage can be unavailable (private mode), so failures are ignored. */
export const prefs = {
  get(key: string): string | null {
    try {
      return localStorage.getItem(key);
    } catch {
      return null;
    }
  },
  set(key: string, value: string | null): void {
    try {
      if (value === null) localStorage.removeItem(key);
      else localStorage.setItem(key, value);
    } catch {
      // ignore
    }
  },
};

/** Keeps a WebSocket to the world's event stream open, reconnecting with backoff. */
export function useServerEvents(worldId: number, onMessage: (msg: ServerMessage) => void): void {
  const handler = useRef(onMessage);
  handler.current = onMessage;

  useEffect(() => {
    let socket: WebSocket | null = null;
    let retry: ReturnType<typeof setTimeout> | undefined;
    let delay = 1000;
    let closed = false;

    const connect = () => {
      const proto = location.protocol === 'https:' ? 'wss' : 'ws';
      socket = new WebSocket(`${proto}://${location.host}/api/w/${worldId}/ws`);
      socket.onopen = () => (delay = 1000);
      socket.onmessage = (e) => handler.current(JSON.parse(e.data) as ServerMessage);
      socket.onclose = () => {
        if (closed) return;
        retry = setTimeout(connect, delay);
        delay = Math.min(delay * 2, 30_000);
      };
    };
    connect();

    return () => {
      closed = true;
      clearTimeout(retry);
      socket?.close();
    };
  }, [worldId]);
}
