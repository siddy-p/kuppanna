'use strict';

const express = require('express');
const { getDb, dbGet, dbAll } = require('../db');

const router = express.Router();

/**
 * GET /api/order/:id
 * Lookup by uber_delivery_id OR internal order_id
 */
router.get('/:id', async (req, res) => {
  const { id } = req.params;

  try {
    const db = await getDb();
    const row = await dbGet(db, `
      SELECT
        order_id,
        uber_delivery_id  AS delivery_id,
        status,
        tracking_url,
        customer_name,
        pickup_address,
        dropoff_address,
        fee_amount,
        fee_currency,
        created_at,
        updated_at
      FROM orders
      WHERE uber_delivery_id = $id OR order_id = $id
      LIMIT 1
    `, { $id: id });

    if (!row) {
      return res.status(404).json({ error: `Order not found: ${id}` });
    }

    return res.json(row);

  } catch (err) {
    console.error('[Order] Lookup error:', err.message);
    return res.status(500).json({ error: 'Failed to retrieve order', detail: err.message });
  }
});

/**
 * GET /api/order
 * List all orders (most recent first)
 */
router.get('/', async (req, res) => {
  try {
    const db = await getDb();
    const rows = await dbAll(db, `
      SELECT order_id, uber_delivery_id AS delivery_id, status, tracking_url, created_at, updated_at
      FROM orders
      ORDER BY created_at DESC
      LIMIT 50
    `);

    return res.json({ orders: rows, count: rows.length });

  } catch (err) {
    console.error('[Order] List error:', err.message);
    return res.status(500).json({ error: 'Failed to list orders', detail: err.message });
  }
});

module.exports = router;
