'use strict';

const express  = require('express');
const axios    = require('axios');
const { getValidToken } = require('../auth');

const router = express.Router();
const API_BASE    = process.env.UBER_API_BASE || 'https://api.uber.com/v1';
const CUSTOMER_ID = process.env.UBER_CUSTOMER_ID;

/**
 * POST /api/delivery-quote
 */
router.post('/', async (req, res) => {
  const {
    pickup_address,
    pickup_lat,
    pickup_lng,
    dropoff_address,
    dropoff_lat,
    dropoff_lng,
  } = req.body;

  if (!pickup_address || !dropoff_address) {
    return res.status(400).json({
      error: 'pickup_address and dropoff_address are required',
    });
  }

  try {
    const token = await getValidToken();

    const payload = {
      pickup_address:  pickup_address,
      dropoff_address: dropoff_address,
    };

    console.log('[Quote] Requesting delivery quote from Uber…');

    const response = await axios.post(
      `${API_BASE}/customers/${CUSTOMER_ID}/delivery_quotes`,
      payload,
      {
        headers: {
          Authorization:  `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
        timeout: 15_000,
      }
    );

    const data = response.data;
    console.log('[Quote] Received quote_id:', data.id);

    const createdTime = data.created ? new Date(data.created) : new Date();
    const etaTime = data.dropoff_eta ? new Date(data.dropoff_eta) : null;
    const etaSeconds = etaTime ? Math.round((etaTime - createdTime) / 1000) : (data.duration ? data.duration * 60 : null);

    return res.json({
      quote_id:    data.id,
      fee:         data.fee,
      currency:    data.currency,
      expires_at:  data.expires,
      eta_seconds: etaSeconds,
      raw:         data,
    });

  } catch (err) {
    const detail = err.response?.data || err.message;
    console.error('[Quote] Error:', detail);
    return res.status(err.response?.status || 500).json({
      error:  'Failed to fetch delivery quote',
      detail: detail,
    });
  }
});

module.exports = router;
