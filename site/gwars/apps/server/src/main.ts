import compress from '@fastify/compress';
import cookie from '@fastify/cookie';
import websocket from '@fastify/websocket';
import Fastify from 'fastify';
import { ZodError } from 'zod';
import { requireAuth } from './auth';
import { config } from './config';
import { loadWorld, type AppContext } from './context';
import { pool } from './db';
import { Engine } from './engine/engine';
import { GameError } from './errors';
import { Realtime } from './realtime';
import { registerAuthRoutes } from './routes/auth';
import { registerMapRoutes } from './routes/map';
import { registerSettlementRoutes } from './routes/settlements';
import { registerWorldRoutes } from './routes/world';

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

const world = await loadWorld(config.worldId);
const realtime = new Realtime();
// The engine runs in the API process for now; it moves to its own process once workloads grow.
const engine = new Engine(world, realtime);
const ctx: AppContext = { world, realtime, engine };

registerAuthRoutes(app, ctx);
registerWorldRoutes(app, ctx);
registerMapRoutes(app, ctx);
registerSettlementRoutes(app, ctx);

app.get('/api/ws', { websocket: true, preHandler: requireAuth }, (socket, req) => {
  realtime.add(req.account!.id, socket);
});

const shutdown = async () => {
  engine.stop();
  await app.close();
  await pool.end();
  process.exit(0);
};
process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);

await app.listen({ port: config.port, host: '127.0.0.1' });
engine.start();
app.log.info(`World ${world.id} "${world.name}" running at speed ${world.settings.speed}`);
