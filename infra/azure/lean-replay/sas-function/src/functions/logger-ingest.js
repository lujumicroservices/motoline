const { app } = require('@azure/functions');
const { DefaultAzureCredential } = require('@azure/identity');
const { BlobServiceClient } = require('@azure/storage-blob');

function json(status, body) {
  return {
    status,
    headers: { 'Content-Type': 'application/json' },
    jsonBody: body,
  };
}

function safeId(value, fallback) {
  const s = typeof value === 'string' ? value.trim() : '';
  if (!s || s.length > 80) return fallback;
  if (!/^[A-Za-z0-9._-]+$/.test(s)) return fallback;
  return s;
}

app.http('logger-ingest', {
  methods: ['GET', 'POST'],
  authLevel: 'anonymous',
  handler: async (request, context) => {
    const expected = process.env.LOGGER_INGEST_KEY || '';
    const got =
      request.headers.get('x-logger-key') ||
      request.headers.get('x-device-secret') ||
      '';
    if (!expected || got !== expected) {
      return json(401, { ok: false, error: 'unauthorized' });
    }
    if (request.method === 'GET') {
      return json(200, { ok: true, ping: true });
    }

    let body = {};
    try {
      body = (await request.json()) ?? {};
    } catch (_) {
      return json(400, { ok: false, error: 'invalid_json' });
    }

    const deviceId = safeId(body.device_id, 'unpaired');
    const sessionId = safeId(body.session_id, '');
    if (!sessionId) return json(400, { ok: false, error: 'missing_session_id' });

    const account = process.env.BLOB_ACCOUNT;
    const container = process.env.BLOB_LOGGER_CONTAINER || 'logger-sessions';
    if (!account) {
      context.error('BLOB_ACCOUNT is not set');
      return json(500, { ok: false, error: 'misconfigured' });
    }

    const prefix = `${deviceId}/${sessionId}`;
    const files = {
      'manifest.json':
        typeof body.manifest === 'object'
          ? JSON.stringify(body.manifest)
          : typeof body.manifest === 'string'
            ? body.manifest
            : '',
      'gnss.ndjson': typeof body.gnss_ndjson === 'string' ? body.gnss_ndjson : '',
      'imu.ndjson': typeof body.imu_ndjson === 'string' ? body.imu_ndjson : '',
      'baro.ndjson': typeof body.baro_ndjson === 'string' ? body.baro_ndjson : '',
    };
    if (!files['gnss.ndjson']) {
      return json(400, { ok: false, error: 'missing_gnss' });
    }

    const credential = new DefaultAzureCredential();
    const service = new BlobServiceClient(
      `https://${account}.blob.core.windows.net`,
      credential,
    );
    const c = service.getContainerClient(container);
    const written = [];
    for (const [name, text] of Object.entries(files)) {
      if (!text) continue;
      const blob = c.getBlockBlobClient(`${prefix}/${name}`);
      await blob.upload(text, Buffer.byteLength(text), {
        blobHTTPHeaders: {
          blobContentType: name.endsWith('.json')
            ? 'application/json'
            : 'application/x-ndjson',
        },
      });
      written.push(`${container}/${prefix}/${name}`);
    }

    return json(200, { ok: true, session_id: sessionId, blobs: written });
  },
});
