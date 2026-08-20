const { app } = require('@azure/functions');
const { DefaultAzureCredential } = require('@azure/identity');
const {
  BlobServiceClient,
  BlobSASPermissions,
  generateBlobSASQueryParameters,
  SASProtocol,
} = require('@azure/storage-blob');

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function json(status, body) {
  return {
    status,
    headers: { 'Content-Type': 'application/json' },
    jsonBody: body,
  };
}

function blobPathFor(userId, rideId) {
  return `${userId}/${rideId}.sqlite.gz`;
}

async function supabaseUserId(authHeader) {
  const url = process.env.SUPABASE_URL;
  const anon = process.env.SUPABASE_ANON_KEY;
  if (!url || !anon) {
    throw new Error('Function missing SUPABASE_URL / SUPABASE_ANON_KEY');
  }
  if (!authHeader || !authHeader.toLowerCase().startsWith('bearer ')) {
    return null;
  }
  const res = await fetch(`${url.replace(/\/$/, '')}/auth/v1/user`, {
    headers: {
      Authorization: authHeader,
      apikey: anon,
    },
  });
  if (!res.ok) return null;
  const body = await res.json();
  return typeof body.id === 'string' ? body.id : null;
}

app.http('lean-replay-sas', {
  methods: ['POST'],
  authLevel: 'anonymous',
  handler: async (request, context) => {
    let payload = {};
    try {
      payload = (await request.json()) ?? {};
    } catch (_) {
      return json(400, { error: 'invalid_json' });
    }
    const rideId = typeof payload.ride_id === 'string' ? payload.ride_id.trim() : '';
    if (!UUID_RE.test(rideId)) {
      return json(400, { error: 'invalid_ride_id' });
    }

    const userId = await supabaseUserId(request.headers.get('authorization'));
    if (!userId || !UUID_RE.test(userId)) {
      return json(401, { error: 'unauthorized' });
    }

    const account = process.env.BLOB_ACCOUNT;
    const container = process.env.BLOB_CONTAINER || 'lean-replay';
    if (!account) {
      context.error('BLOB_ACCOUNT is not set');
      return json(500, { error: 'misconfigured' });
    }

    const blobPath = blobPathFor(userId, rideId);
    const startsOn = new Date(Date.now() - 60 * 1000);
    const expiresOn = new Date(Date.now() + 15 * 60 * 1000);

    const credential = new DefaultAzureCredential();
    const service = new BlobServiceClient(
      `https://${account}.blob.core.windows.net`,
      credential,
    );
    const userDelegationKey = await service.getUserDelegationKey(
      startsOn,
      expiresOn,
    );
    const sas = generateBlobSASQueryParameters(
      {
        containerName: container,
        blobName: blobPath,
        permissions: BlobSASPermissions.parse('acw'),
        startsOn,
        expiresOn,
        protocol: SASProtocol.Https,
      },
      userDelegationKey,
      account,
    ).toString();

    const uploadUrl =
      `https://${account}.blob.core.windows.net/${container}/${blobPath}?${sas}`;

    return json(200, {
      uploadUrl,
      blobPath: `${container}/${blobPath}`,
      expiresAt: expiresOn.toISOString(),
    });
  },
});
