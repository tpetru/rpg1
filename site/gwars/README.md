# GeoWars

A browser strategy game in the spirit of Tribal Wars, played on the real world map. Every land hex
(Uber H3 grid) is a settlement named after a real city, lies in a real country and produces
resources based on that country's real-world profile. Start with one settlement, grow it, train an
army, conquer your neighbours and organise into alliances.

Players create one account, then pick a **world** (World 0, World 1, …). Each world is a separate
round with its own map, players and settings. In each world the player founds a nation with a name
of their own (letters, digits, spaces and hyphens, starting with a letter, at most 2 spaces and
2 hyphens) and starts on a random free hex.

## Stack

| Part | Tech |
| --- | --- |
| `packages/rules` | Game data and formulas shared by server (authoritative) and client (previews) |
| `packages/geo` | Builds the world: Natural Earth countries + GeoNames cities → H3 hexes |
| `apps/server` | Node + Fastify API, WebSocket push, MariaDB/MySQL, ordered event engine |
| `apps/web` | React + Vite + MapLibre GL (globe) |

## Setup

Requirements: Node 22+, MariaDB 10.4+ or MySQL 8.

```sh
npm install
cp .env.example .env              # fill in DB credentials
# create the database and a dedicated user: run db/setup.sql as an admin (edit the password first)
npm run geo:build                 # downloads map data, writes the world file (~10.7k hexes at res 3)
npm run db:migrate
npm run db:seed -- --number 0 --speed 50   # creates "World 0" (skips worlds that already exist)
npm run dev                       # API on :3000, web on http://localhost:5173
```

Other scripts: `npm test` (rules unit tests), `npm run typecheck`.

## Architecture notes

- **Lazy resources.** Settlements store a stock snapshot plus `resources_at`. Current stock is
  `snapshot + rate × elapsed`, capped by the warehouse, so nothing ticks in the database.
- **Worlds.** One server process runs every active world; game routes live under `/api/w/:worldId/`
  and WebSocket events are scoped per world. New worlds are created with `db:seed --number N` and
  picked up on the next server restart.
- **One ordered event engine per world.** Every delayed action (build completion now; attacks,
  support and returns later) is a row in `game_events`. The engine runs them one at a time in
  `(execute_at, id)` order, which keeps arrival races deterministic. Scale by adding worlds.
- **Shared rules.** `checkBuild`, production and cost formulas live in `@geowars/rules`. The server
  enforces them; the client uses the same code to show live resources, costs and disabled reasons.
- **World settings** (speed, queue slots, starting resources) are JSON on the world row.

## Roadmap

1. ~~Map, accounts, worlds, nation founding, buildings, resources~~
2. Units, attack/support commands, combat, reports, independent towns
3. Governors, loyalty and conquest, rankings
4. Alliances, diplomacy, chat, incoming-attack feed
5. Research: Technology, Medicine, Education, Weapons, Politics; alliance projects
6. Country control bonuses, strategic resources, market, overseas travel, win condition
