'use strict';

const axios = require('axios');
const { getDb, dbGet, dbRun } = require('./db');

const TOKEN_URL     = process.env.UBER_TOKEN_URL     || 'https://login.uber.com/oauth/v2/token';
const CLIENT_ID     = process.env.UBER_CLIENT_ID;
const CLIENT_SECRET = process.env.UBER_CLIENT_SECRET;

const REFRESH_BUFFER_SECONDS = 5 * 60; // 5 minutes

/**
 * Returns a valid Uber bearer token, fetching a new one when necessary.
 * Token is cached in the oauth_tokens table (single-row, id=1).
 */
async function getValidToken() {
  const db = await getDb();
  const nowSeconds = Math.floor(Date.now() / 1000);

  const cached = await dbGet(db,
    'SELECT access_token, expires_at FROM oauth_tokens WHERE id = 1'
  );

  if (cached) {
    const secondsUntilExpiry = cached.expires_at - nowSeconds;
    if (secondsUntilExpiry > REFRESH_BUFFER_SECONDS) {
      console.log(`[Auth] Reusing cached token (expires in ${Math.round(secondsUntilExpiry / 60)}m)`);
      return cached.access_token;
    }
    console.log(`[Auth] Token expires in ${secondsUntilExpiry}s — refreshing…`);
  } else {
    console.log('[Auth] No cached token — fetching fresh token…');
  }

  // Fetch new token
  const params = new URLSearchParams();
  params.append('client_id', CLIENT_ID);
  params.append('client_secret', CLIENT_SECRET);
  params.append('grant_type', 'client_credentials');
  params.append('scope', 'eats.deliveries');

  let response;
  try {
    response = await axios.post(TOKEN_URL, params, {
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      timeout: 10_000,
    });
  } catch (err) {
    const detail = err.response?.data || err.message;
    console.error('[Auth] Token fetch failed:', detail);
    throw new Error(`Uber OAuth2 failed: ${JSON.stringify(detail)}`);
  }

  const { access_token, expires_in } = response.data;
  const expiresAt = nowSeconds + expires_in;

  await dbRun(db, `
    INSERT INTO oauth_tokens (id, access_token, expires_at, client_id, client_secret)
    VALUES (1, $access_token, $expires_at, $client_id, $client_secret)
    ON CONFLICT(id) DO UPDATE SET
      access_token  = excluded.access_token,
      expires_at    = excluded.expires_at,
      client_id     = excluded.client_id,
      client_secret = excluded.client_secret,
      created_at    = strftime('%s','now')
  `, {
    $access_token:  access_token,
    $expires_at:    expiresAt,
    $client_id:     CLIENT_ID,
    $client_secret: CLIENT_SECRET,
  });

  console.log(`[Auth] New token cached — valid for ${Math.round(expires_in / 60)} minutes`);
  return access_token;
}

module.exports = { getValidToken };
