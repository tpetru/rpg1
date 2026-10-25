import mysql, { type Pool, type PoolConnection, type ResultSetHeader, type RowDataPacket } from 'mysql2/promise';
import { config } from './config';

export const pool: Pool = mysql.createPool({
  ...config.db,
  connectionLimit: 10,
  charset: 'utf8mb4',
  supportBigNumbers: true,
  decimalNumbers: true,
});

export type Db = Pool | PoolConnection;

export async function rows<T>(db: Db, sql: string, params: unknown[] = []): Promise<T[]> {
  const [result] = await db.query<RowDataPacket[]>(sql, params);
  return result as T[];
}

export async function one<T>(db: Db, sql: string, params: unknown[] = []): Promise<T | undefined> {
  return (await rows<T>(db, sql, params))[0];
}

export async function exec(db: Db, sql: string, params: unknown[] = []): Promise<ResultSetHeader> {
  const [result] = await db.query<ResultSetHeader>(sql, params);
  return result;
}

export async function tx<T>(fn: (conn: PoolConnection) => Promise<T>): Promise<T> {
  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();
    const out = await fn(conn);
    await conn.commit();
    return out;
  } catch (err) {
    await conn.rollback();
    throw err;
  } finally {
    conn.release();
  }
}

export function isDuplicateKey(err: unknown): boolean {
  return (err as { code?: string })?.code === 'ER_DUP_ENTRY';
}
