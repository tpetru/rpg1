import compress from '@fastify/compress';
import cookie from '@fastify/cookie';
import websocket from '@fastify/websocket';
import Fastify from 'fastify';
import { ZodError } from 'zod';
import { requireAuth } from './auth';
import { config } from './config';
import { loadActiveWorlds, type AppContext, type WorldRuntime } from './context';
import { pool } from './db';
import { Engine } from './engine/engine';
import { GameError } from './errors';
import { Realtime } from './realtime';
import { registerAuthRoutes } from './routes/auth';
import { registerMapRoutes } from './routes/map';
import { registerSettlementRoutes } from './routes/settlements';
import { registerWorldRoutes } from './routes/worlds';

const app = Fastify({ logger: { level: 'info' } });
await app.register(cookie);
await app.register(compress);
await app.register(websocket);

app.setErrorHandler((err, req, reply) => {
  if (err instanceof GameError) return reply.status(err.status).send({ error: err.message });
  if (err instanceof ZodError) return reply.status(400).send({ error: err.issues[0]?.message ?? 'Invalid request' });
  req.log.error(err);
  return reply.status(500).send({ error: 'Internal server error' });
});

const realtime = new Realtime();
// One strictly ordered engine per world. They run in the API process for now and move
// to their own processes once workloads grow.
const worlds = new Map<number, WorldRuntime>();
for (const info of await loadActiveWorlds()) worlds.set(info.id, { info, engine: new Engine(info, realtime) });
const ctx: AppContext = { worlds, realtime };

registerAuthRoutes(app);
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
