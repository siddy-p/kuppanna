'use strict';

require('dotenv').config();

const express = require('express');
const cors    = require('cors');
const { getDb, dbGet } = require('./db');

// ── Boot database ─────────────────────────────────────────────────────────
getDb().then(() => {
  console.log('[Server] Database ready');
}).catch((err) => {
  console.error('[Server] Fatal: could not open database:', err);
  process.exit(1);
});

// ── Express app ───────────────────────────────────────────────────────────
const app = express();

app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: false }));

// ── Request logger ────────────────────────────────────────────────────────
app.use((req, _res, next) => {
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.path}`);
  next();
});

// ── Routes ────────────────────────────────────────────────────────────────
app.use('/api/delivery-quote',  require('./routes/quote'));
app.use('/api/create-delivery', require('./routes/delivery'));
app.use('/api/uber-webhook',    require('./routes/webhook'));
app.use('/api/order',           require('./routes/order'));

// ── Health check ──────────────────────────────────────────────────────────
app.get('/health', async (_req, res) => {
  try {
    const db = await getDb();
    const tokenRow = await dbGet(db,
      'SELECT expires_at FROM oauth_tokens WHERE id = 1'
    );
    const now = Math.floor(Date.now() / 1000);
    const tokenStatus = tokenRow
      ? (tokenRow.expires_at > now ? 'valid' : 'expired')
      : 'none';

    res.json({
      status:       'ok',
      app:          "Kuppanna's Test App",
      customer_id:  process.env.UBER_CUSTOMER_ID,
      token_status: tokenStatus,
      timestamp:    new Date().toISOString(),
    });
  } catch (err) {
    res.status(500).json({ status: 'error', detail: err.message });
  }
});

// ── 404 ───────────────────────────────────────────────────────────────────
app.use((_req, res) => {
  res.status(404).json({ error: 'Route not found' });
});

// ── Global error handler ──────────────────────────────────────────────────
app.use((err, _req, res, _next) => {
  console.error('[Server] Unhandled error:', err);
  res.status(500).json({ error: 'Internal server error', detail: err.message });
});

// ── Start ─────────────────────────────────────────────────────────────────
const PORT = parseInt(process.env.PORT || '3000', 10);
app.listen(PORT, '0.0.0.0', () => {
  console.log('');
  console.log("╔══════════════════════════════════════════════╗");
  console.log("║       Kuppanna Backend — STARTED             ║");
  console.log(`║  http://localhost:${PORT}                       ║`);
  console.log("╚══════════════════════════════════════════════╝");
  console.log('');
  console.log('  POST /api/delivery-quote');
  console.log('  POST /api/create-delivery');
  console.log('  POST /api/uber-webhook');
  console.log('  GET  /api/order/:id');
  console.log('  GET  /health');
  console.log('');
});
