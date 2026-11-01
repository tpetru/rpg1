import { useEffect, useRef, useState } from 'react';
import type { ServerMessage } from '@geowars/rules';

export { fmtInt } from './i18n';

export function fmtDuration(totalSec: number): string {
  const s = Math.max(0, Math.ceil(totalSec));
  const h = Math.floor(s / 3600);
  const m = Math.floor((s % 3600) / 60);
  const sec = s % 60;
  const pad = (x: number) => String(x).padStart(2, '0');
  return h > 0 ? `${h}h ${pad(m)}m ${pad(sec)}s` : m > 0 ? `${m}m ${pad(sec)}s` : `${sec}s`;
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

/** Duration as the Build hub shows it: "5m 02s", "1h 40m", "45s". */
export function fmtBuildTime(totalSec: number): string {
  const s = Math.max(0, Math.round(totalSec));
  const h = Math.floor(s / 3600);
  const m = Math.floor((s % 3600) / 60);
  const sec = s % 60;
  if (h > 0) return `${h}h ${String(m).padStart(2, '0')}m`;
  if (m > 0) return `${m}m ${String(sec).padStart(2, '0')}s`;
  return `${sec}s`;
}

/** A time left as hh:mm:ss. */
export function fmtHms(totalSec: number): string {
  const s = Math.max(0, Math.ceil(totalSec));
  const pad = (x: number) => String(x).padStart(2, '0');
  return `${pad(Math.floor(s / 3600))}:${pad(Math.floor((s % 3600) / 60))}:${pad(s % 60)}`;
}

/** Date and exact local time to the millisecond, always with the date. */
export function fmtDateTimeMs(ms: number): string {
  const d = new Date(ms);
  const pad = (x: number, n = 2) => String(x).padStart(n, '0');
  return `${pad(d.getDate())}.${pad(d.getMonth() + 1)}.${d.getFullYear()} ${pad(d.getHours())}:${pad(d.getMinutes())}:${pad(d.getSeconds())}.${pad(d.getMilliseconds(), 3)}`;
}

/** The exact local time of a moment, to the millisecond; the date is added when it is not today. */
export function fmtClock(ms: number): string {
  const d = new Date(ms);
  const pad = (x: number, n = 2) => String(x).padStart(n, '0');
  const time = `${pad(d.getHours())}:${pad(d.getMinutes())}:${pad(d.getSeconds())}.${pad(d.getMilliseconds(), 3)}`;
  const today = new Date();
  const sameDay = d.getFullYear() === today.getFullYear() && d.getMonth() === today.getMonth() && d.getDate() === today.getDate();
  return sameDay ? time : `${pad(d.getDate())}.${pad(d.getMonth() + 1)} ${time}`;
}
