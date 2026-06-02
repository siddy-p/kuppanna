'use strict';

const express = require('express');
const { getDb, dbRun } = require('../db');

const router = express.Router();

const STATUS_MAP = {
  pending:             'pending',
  pickup:              'accepted',
  pickup_complete:     'picked_up',
  dropoff:             'en_route',
  delivered:           'delivered',
  returned:            'returned',
  cancelled:           'cancelled',
  en_route_to_pickup:  'accepted',
  en_route_to_dropoff: 'en_route',
};

/**
 * POST /api/uber-webhook
 */
router.post('/', async (req, res) => {
  const body = req.body;
  console.log('[Webhook] Event received:', JSON.stringify(body, null, 2));

  try {
    const uberDeliveryId = body?.data?.id || body?.id;
    const rawStatus      = body?.data?.status || body?.status;

    if (!uberDeliveryId || !rawStatus) {
      console.warn('[Webhook] Missing delivery ID or status — ignoring');
      return res.status(200).json({ received: true, warning: 'missing fields' });
    }

    const mappedStatus = STATUS_MAP[rawStatus] || rawStatus;
    const db = await getDb();

    const result = await dbRun(db, `
      UPDATE orders
      SET status     = $status,
          updated_at = strftime('%s','now')
      WHERE uber_delivery_id = $uber_delivery_id
    `, {
      $status:           mappedStatus,
      $uber_delivery_id: uberDeliveryId,
    });

    if (result.changes === 0) {
      console.warn(`[Webhook] No order found for delivery_id: ${uberDeliveryId}`);
    } else {
      console.log(`[Webhook] Order ${uberDeliveryId} → status: "${mappedStatus}"`);
    }

    return res.status(200).json({ received: true, delivery_id: uberDeliveryId, status: mappedStatus });

  } catch (err) {
    console.error('[Webhook] Error:', err.message);
    return res.status(200).json({ received: true, error: err.message });
  }
});

module.exports = router;
