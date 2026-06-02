'use strict';

const express  = require('express');
const axios    = require('axios');
const crypto   = require('crypto');
const { getValidToken } = require('../auth');
const { getDb, dbRun } = require('../db');

const router = express.Router();
const API_BASE    = process.env.UBER_API_BASE || 'https://api.uber.com/v1';
const CUSTOMER_ID = process.env.UBER_CUSTOMER_ID;

/**
 * POST /api/create-delivery
 *
 * Body:
 * {
 *   "quote_id":        "string",
 *   "customer_name":   "string",
 *   "customer_phone":  "string",   -- E.164 e.g. "+447700900000"
 *   "customer_email":  "string",   -- optional
 *   "pickup_address":  "string",   -- full address string
 *   "dropoff_address": "string",   -- full address string
 *   "fee_amount":      number,     -- in minor units
 *   "fee_currency":    "string"
 * }
 */
router.post('/', async (req, res) => {
  const {
    quote_id,
    customer_name,
    customer_phone,
    customer_email,
    pickup_address,
    dropoff_address,
    fee_amount,
    fee_currency,
  } = req.body;

  if (!quote_id || !customer_name || !customer_phone) {
    return res.status(400).json({
      error: 'quote_id, customer_name, and customer_phone are required',
    });
  }

  try {
    const token   = await getValidToken();
    const orderId = crypto.randomUUID();

    // Uber Direct deliveries API expects flat address strings inside
    // pickup/dropoff objects (different from delivery_quotes which takes
    // top-level pickup_address / dropoff_address strings)
    const payload = {
      quote_id,
      pickup_name:         'Kuppanna Restaurant',
      pickup_address:      pickup_address || '15 Drummond Street, London, NW1 2QB, GB',
      pickup_phone_number: '+447700900001',
      pickup_notes:        'Bag near counter. Ring bell on arrival.',
      dropoff_name:        customer_name,
      dropoff_address:     dropoff_address || 'London, GB',
      dropoff_phone_number: customer_phone,
      dropoff_notes:       'Leave at door if no answer.',
      manifest_items: [
        {
          name:     'Food Order',
          quantity:  1,
          size:     'small',
          price:    fee_amount || 1000,
          currency: (fee_currency || 'GBP').toUpperCase(),
        },
      ],
      external_id: orderId,
      test_specifications: {
        robo_courier_specification: {
          mode: 'auto'
        }
      }
    };

    if (customer_email) {
      payload.dropoff_email = customer_email;
    }

    console.log(`[Delivery] Creating delivery for order ${orderId}…`);
    console.log('[Delivery] Payload:', JSON.stringify(payload, null, 2));

    const response = await axios.post(
      `${API_BASE}/customers/${CUSTOMER_ID}/deliveries`,
      payload,
      {
        headers: {
          Authorization:  `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
        timeout: 15_000,
      }
    );

    const data          = response.data;
    const deliveryId    = data.id;
    const trackingUrl   = data.tracking_url;
    const initialStatus = data.status || 'pending';

    console.log(`[Delivery] Created — delivery_id: ${deliveryId}, status: ${initialStatus}`);

    // ── Log to SQLite ────────────────────────────────────────────────────────
    const db = await getDb();
    await dbRun(db, `
      INSERT INTO orders
        (order_id, uber_delivery_id, quote_id, status, tracking_url,
         customer_name, customer_phone, customer_email,
         pickup_address, dropoff_address, fee_amount, fee_currency)
      VALUES
        ($order_id, $uber_delivery_id, $quote_id, $status, $tracking_url,
         $customer_name, $customer_phone, $customer_email,
         $pickup_address, $dropoff_address, $fee_amount, $fee_currency)
    `, {
      $order_id:         orderId,
      $uber_delivery_id: deliveryId,
      $quote_id:         quote_id,
      $status:           initialStatus,
      $tracking_url:     trackingUrl || null,
      $customer_name:    customer_name,
      $customer_phone:   customer_phone,
      $customer_email:   customer_email || null,
      $pickup_address:   pickup_address || null,
      $dropoff_address:  dropoff_address || null,
      $fee_amount:       fee_amount || null,
      $fee_currency:     fee_currency || null,
    });

    console.log(`[Delivery] Order logged to SQLite — order_id: ${orderId}`);

    return res.status(201).json({
      order_id:     orderId,
      delivery_id:  deliveryId,
      tracking_url: trackingUrl,
      status:       initialStatus,
    });

  } catch (err) {
    const detail = err.response?.data || err.message;
    console.error('[Delivery] Error:', JSON.stringify(detail, null, 2));
    return res.status(err.response?.status || 500).json({
      error:  'Failed to create delivery',
      detail: detail,
    });
  }
});

module.exports = router;
