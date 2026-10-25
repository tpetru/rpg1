# GeoWars

A browser strategy game in the spirit of Tribal Wars, played on the real world map. Every land hex
(Uber H3 grid) is a settlement named after a real city, belongs to a real country and produces
resources based on that country's real-world profile. Start with one settlement, grow it, train an
army, conquer your neighbours and organise into alliances.

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
npm run db:seed -- --speed 1      # use e.g. --speed 50 for fast local testing
npm run dev                       # API on :3000, web on http://localhost:5173
```

Other scripts: `npm test` (rules unit tests), `npm run typecheck`.

## Architecture notes

- **Lazy resources.** Settlements store a stock snapshot plus `resources_at`. Current stock is
  `snapshot + rate × elapsed`, capped by the warehouse, so nothing ticks in the database.
- **One ordered event engine per world.** Every delayed action (build completion now; attacks,
  support and returns later) is a row in `game_events`. The engine runs them one at a time in
  `(execute_at, id)` order, which keeps arrival races deterministic. Scale by adding worlds.
- **Shared rules.** `checkBuild`, production and cost formulas live in `@geowars/rules`. The server
  enforces them; the client uses the same code to show live resources, costs and disabled reasons.
- **World settings** (speed, queue slots, starting resources) are JSON on the world row.

## Roadmap

1. ~~Map, accounts, spawning in a country, buildings, resources~~
2. Units, attack/support commands, combat, reports, independent towns
3. Governors, loyalty and conquest, rankings
4. Alliances, diplomacy, chat, incoming-attack feed
5. Research: Technology, Medicine, Education, Weapons, Politics; alliance projects
6. Country control bonuses, strategic resources, market, overseas travel, win condition
