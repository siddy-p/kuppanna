'use strict';

const sqlite3 = require('sqlite3').verbose();
const path    = require('path');

const DB_PATH = process.env.DATABASE_PATH || path.join(__dirname, '..', 'kuppanna.sqlite');

// Singleton connection
let _db = null;

/**
 * Returns a Promise that resolves to the open database connection.
 * Creates tables on first call.
 */
function getDb() {
  if (_db) return Promise.resolve(_db);

  return new Promise((resolve, reject) => {
    const db = new sqlite3.Database(DB_PATH, (err) => {
      if (err) return reject(err);

      // Enable WAL mode
      db.serialize(() => {
        db.run('PRAGMA journal_mode = WAL');
        db.run('PRAGMA foreign_keys = ON');
        db.run(`
          CREATE TABLE IF NOT EXISTS oauth_tokens (
            id            INTEGER PRIMARY KEY CHECK (id = 1),
            access_token  TEXT    NOT NULL,
            expires_at    INTEGER NOT NULL,
            client_id     TEXT    NOT NULL,
            client_secret TEXT    NOT NULL,
            created_at    INTEGER NOT NULL DEFAULT (strftime('%s','now'))
          )
        `);
        db.run(`
          CREATE TABLE IF NOT EXISTS orders (
            id               INTEGER PRIMARY KEY AUTOINCREMENT,
            order_id         TEXT    NOT NULL UNIQUE,
            uber_delivery_id TEXT,
            quote_id         TEXT,
            status           TEXT    NOT NULL DEFAULT 'pending',
            tracking_url     TEXT,
            customer_name    TEXT,
            customer_phone   TEXT,
            customer_email   TEXT,
            pickup_address   TEXT,
            dropoff_address  TEXT,
            fee_amount       INTEGER,
            fee_currency     TEXT,
            created_at       INTEGER NOT NULL DEFAULT (strftime('%s','now')),
            updated_at       INTEGER NOT NULL DEFAULT (strftime('%s','now'))
          )
        `, (err2) => {
          if (err2) return reject(err2);
          console.log(`[DB] SQLite connected → ${DB_PATH}`);
          console.log('[DB] Tables: oauth_tokens, orders — OK');
          _db = db;
          resolve(db);
        });
      });
    });
  });
}

// ── Promise helpers ───────────────────────────────────────────────────────

/** db.get() → Promise<row|undefined> */
function dbGet(db, sql, params = {}) {
  return new Promise((resolve, reject) => {
    db.get(sql, params, (err, row) => (err ? reject(err) : resolve(row)));
  });
}

/** db.run() → Promise<{lastID, changes}> */
function dbRun(db, sql, params = {}) {
  return new Promise((resolve, reject) => {
    db.run(sql, params, function (err) {
      if (err) return reject(err);
      resolve({ lastID: this.lastID, changes: this.changes });
    });
  });
}

/** db.all() → Promise<rows[]> */
function dbAll(db, sql, params = {}) {
  return new Promise((resolve, reject) => {
    db.all(sql, params, (err, rows) => (err ? reject(err) : resolve(rows)));
  });
}

module.exports = { getDb, dbGet, dbRun, dbAll };
