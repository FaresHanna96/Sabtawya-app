import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

// Sends one stored notification (a row of `notifications`) to its user's
// devices over FCM. Called by a database trigger (no JWT), so it only acts on
// a real row that has not been pushed yet.

const SERVICE_ACCOUNT = JSON.parse(
  Deno.env.get('FIREBASE_SERVICE_ACCOUNT') ?? '{}',
);

const supabase = createClient(
  Deno.env.get('SUPABASE_URL') ?? '',
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
);

function b64url(data: ArrayBuffer | string): string {
  const bytes = typeof data === 'string'
    ? new TextEncoder().encode(data)
    : new Uint8Array(data);
  let s = '';
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

async function accessToken(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = b64url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const claims = b64url(JSON.stringify({
    iss: SERVICE_ACCOUNT.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  }));
  const pem = (SERVICE_ACCOUNT.private_key as string)
    .replace(/-----[^-]+-----/g, '')
    .replace(/\s+/g, '');
  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey(
    'pkcs8',
    der,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const sig = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(`${header}.${claims}`),
  );
  const jwt = `${header}.${claims}.${b64url(sig)}`;

  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  });
  const json = await res.json();
  if (!json.access_token) throw new Error(JSON.stringify(json));
  return json.access_token as string;
}

// An installation ID is 22 characters of base64url; a registration token is
// far longer. FCM takes them in different fields.
const isInstallationId = (t: string) => /^[A-Za-z0-9_-]{22}$/.test(t);

async function sendOne(
  url: string,
  bearer: string,
  target: Record<string, string>,
  title: string,
  body: string,
  data: Record<string, string> = {},
): Promise<Response> {
  return await fetch(url, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${bearer}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      message: {
        ...target,
        notification: { title, body },
        // What a tap opens, and the unread count the service worker shows on
        // the app icon.
        data,
        webpush: {
          fcm_options: {
            link: data.notification_id ? `/?n=${data.notification_id}` : '/',
          },
        },
      },
    }),
  });
}

async function sendPush(
  tokens: { token: string }[],
  title: string,
  body: string,
  data: Record<string, string> = {},
): Promise<number> {
  const bearer = await accessToken();
  const url =
    `https://fcm.googleapis.com/v1/projects/${SERVICE_ACCOUNT.project_id}/messages:send`;
  let sent = 0;
  for (const { token } of tokens) {
    let res: Response;
    if (isInstallationId(token)) {
      res = await sendOne(url, bearer, { fid: token }, title, body, data);
      // Should the `fid` field be refused, the transition still accepts an
      // installation ID in `token`.
      if (res.status === 400) {
        res = await sendOne(url, bearer, { token }, title, body, data);
      }
      // A 400 here may be the message, not the device: only a 404 (not
      // registered any more) removes an installation ID.
      if (res.ok) {
        sent++;
      } else if (res.status === 404) {
        await supabase.from('device_tokens').delete().eq('token', token);
      }
      continue;
    }
    res = await sendOne(url, bearer, { token }, title, body, data);
    if (res.ok) {
      sent++;
    } else if (res.status === 404 || res.status === 400) {
      // The device is gone; forget its token.
      await supabase.from('device_tokens').delete().eq('token', token);
    }
  }
  return sent;
}

// Pushes one stored notification to its user's devices, once.
async function pushNotification(id: string): Promise<Response> {
  const { data: n } = await supabase
    .from('notifications')
    .update({ pushed_at: new Date().toISOString() })
    .eq('id', id)
    .is('pushed_at', null)
    .select('id, user_id, title, body')
    .maybeSingle();
  if (!n) return new Response('nothing to announce', { status: 200 });

  const { data: tokens } = await supabase
    .from('device_tokens')
    .select('token')
    .eq('user_id', n.user_id);
  if (!tokens || tokens.length === 0) {
    return new Response('no devices', { status: 200 });
  }
  const { count } = await supabase
    .from('notifications')
    .select('id', { count: 'exact', head: true })
    .eq('user_id', n.user_id)
    .is('read_at', null);
  const sent = await sendPush(tokens, n.title, n.body ?? '', {
    notification_id: n.id as string,
    ...(count === null ? {} : { badge: String(count) }),
  });
  return new Response(JSON.stringify({ sent }), { status: 200 });
}

serve(async (req) => {
  try {
    const { kind, notification_id } = await req.json();
    if (kind !== 'notification' || !notification_id) {
      return new Response('missing notification_id', { status: 400 });
    }
    return await pushNotification(notification_id);
  } catch (e) {
    return new Response(String(e), { status: 500 });
  }
});
