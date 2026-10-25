// Applies db/migrations/*.sql in name order, once each.
import { readdir, readFile } from 'node:fs/promises';
import path from 'node:path';
import mysql from 'mysql2/promise';
import { REPO_ROOT, config } from './config';

const dir = path.join(REPO_ROOT, 'db', 'migrations');
const conn = await mysql.createConnection({ ...config.db, multipleStatements: true });

try {
  await conn.query(`CREATE TABLE IF NOT EXISTS schema_migrations (
    name VARCHAR(190) NOT NULL PRIMARY KEY,
    applied_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4`);
  const [applied] = await conn.query<mysql.RowDataPacket[]>('SELECT name FROM schema_migrations');
  const done = new Set(applied.map((r) => r.name as string));

  const files = (await readdir(dir)).filter((f) => f.endsWith('.sql')).sort();
  let count = 0;
  for (const file of files) {
    if (done.has(file)) continue;
    console.log(`Applying ${file}`);
    await conn.query(await readFile(path.join(dir, file), 'utf8'));
    await conn.query('INSERT INTO schema_migrations (name) VALUES (?)', [file]);
    count++;
  }
  console.log(count ? `Applied ${count} migration(s)` : 'Database is up to date');
} finally {
  await conn.end();
}
