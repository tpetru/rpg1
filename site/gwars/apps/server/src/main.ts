import compress from '@fastify/compress';
import cookie from '@fastify/cookie';
import websocket from '@fastify/websocket';
import type { ApiErrorBody } from '@geowars/rules';
import Fastify from 'fastify';
import { ZodError } from 'zod';
import { requireAuth } from './auth';
import { config } from './config';
import { loadActiveWorlds, type AppContext, type WorldRuntime } from './context';
import { pool } from './db';
import { Engine } from './engine/engine';
import { GameError, VALIDATION_MESSAGES } from './errors';
import { Realtime } from './realtime';
import { registerAdminRoutes } from './routes/admin';
import { registerAuthRoutes } from './routes/auth';
import { registerMapRoutes } from './routes/map';
import { registerSettlementRoutes } from './routes/settlements';
import { registerWorldRoutes } from './routes/worlds';

// The server only listens on 127.0.0.1 behind Apache, so the forwarded client address can be trusted.
const app = Fastify({ logger: { level: 'info' }, trustProxy: true });
await app.register(cookie);
await app.register(compress);
await app.register(websocket);

app.setErrorHandler((err, req, reply) => {
  let body: ApiErrorBody;
  if (err instanceof GameError) {
    body = { error: err.message, code: err.code, params: err.params };
    return reply.status(err.status).send(body);
  }
  if (err instanceof ZodError) {
    const message = err.issues[0]?.message ?? '';
    const known = message in VALIDATION_MESSAGES;
    body = { error: known ? VALIDATION_MESSAGES[message] : 'Invalid request', code: known ? message : 'invalid_request' };
    return reply.status(400).send(body);
  }
  req.log.error(err);
  body = { error: 'Internal server error', code: 'internal' };
  return reply.status(500).send(body);
});

const realtime = new Realtime();
// One strictly ordered engine per world. They run in the API process for now and move
// to their own processes once workloads grow.
const worlds = new Map<number, WorldRuntime>();
for (const info of await loadActiveWorlds()) worlds.set(info.id, { info, engine: new Engine(info, realtime) });
const ctx: AppContext = { worlds, realtime };

registerAuthRoutes(app);
registerAdminRoutes(app, ctx);
registerWorldRoutes(app, ctx);
registerMapRoutes(app, ctx);
registerSettlementRoutes(app, ctx);

app.get('/api/w/:worldId/ws', { websocket: true, preHandler: requireAuth }, (socket, req) => {
  const world = ctx.worlds.get(Number((req.params as { worldId: string }).worldId));
  if (!world) return socket.close(4404, 'World not found');
  realtime.add(world.info.id, req.account!.id, socket);
});

const shutdown = async () => {
  for (const w of worlds.values()) w.engine.stop();
  await app.close();
  await pool.end();
  process.exit(0);
};
process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);

await app.listen({ port: config.port, host: '127.0.0.1' });
for (const w of worlds.values()) {
  w.engine.start();
  app.log.info(`${w.info.name} (id ${w.info.id}) running at speed ${w.info.settings.speed}`);
}
if (worlds.size === 0) app.log.warn('No active worlds. Create one with: npm run db:seed -- --number 0');
