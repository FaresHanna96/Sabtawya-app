import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

// Sends an FCM push to every admin device when a servant sign-up arrives.
// Called by a database trigger (no JWT), so it only acts on a real pending
// sign-up that has not been announced yet.

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

async function sendPush(
  tokens: { token: string }[],
  title: string,
  body: string,
  badge?: number,
): Promise<number> {
  const bearer = await accessToken();
  const url =
    `https://fcm.googleapis.com/v1/projects/${SERVICE_ACCOUNT.project_id}/messages:send`;
  let sent = 0;
  for (const { token } of tokens) {
    const res = await fetch(url, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${bearer}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        message: {
          token,
          notification: { title, body },
          // The unread count, which the service worker shows on the app icon.
          ...(badge === undefined ? {} : { data: { badge: String(badge) } }),
          webpush: { fcm_options: { link: '/' } },
        },
      }),
    });
    if (res.ok) {
      sent++;
    } else if (res.status === 404 || res.status === 400) {
      // The device is gone; forget its token.
      await supabase.from('device_tokens').delete().eq('token', token);
    }
  }
  return sent;
}

// The admin decided on a sign-up: tell the servant who asked.
async function announceDecision(profileId: string): Promise<Response> {
  const { data: p } = await supabase
    .from('profiles')
    .select('full_name, is_active, rejected_at, push_decided_at')
    .eq('id', profileId)
    .maybeSingle();
  if (!p || p.push_decided_at || (!p.is_active && !p.rejected_at)) {
    return new Response('nothing to announce', { status: 200 });
  }
  const { data: claimed } = await supabase
    .from('profiles')
    .update({ push_decided_at: new Date().toISOString() })
    .eq('id', profileId)
    .is('push_decided_at', null)
    .select('id')
    .maybeSingle();
  if (!claimed) return new Response('nothing to announce', { status: 200 });

  const { data: tokens } = await supabase
    .from('device_tokens')
    .select('token')
    .eq('user_id', profileId);
  if (!tokens || tokens.length === 0) {
    return new Response('no devices', { status: 200 });
  }
  const accepted = p.is_active && !p.rejected_at;
  const sent = await sendPush(
    tokens,
    accepted ? 'تم قبول طلبك' : 'بخصوص طلب الانضمام',
    accepted
      ? 'تمت الموافقة على طلب انضمامك، يمكنك الآن تسجيل الدخول'
      : 'لم يتم قبول طلب انضمامك، تواصل مع أمين الخدمة',
  );
  return new Response(JSON.stringify({ sent }), { status: 200 });
}

// Pushes one stored notification to its user's devices, once.
async function pushNotification(id: string): Promise<Response> {
  const { data: n } = await supabase
    .from('notifications')
    .update({ pushed_at: new Date().toISOString() })
    .eq('id', id)
    .is('pushed_at', null)
    .select('user_id, title, body')
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
  const sent = await sendPush(tokens, n.title, n.body ?? '', count ?? undefined);
  return new Response(JSON.stringify({ sent }), { status: 200 });
}

serve(async (req) => {
  try {
    const { profile_id, kind, notification_id } = await req.json();
    if (kind === 'notification' && notification_id) {
      return await pushNotification(notification_id);
    }
    if (!profile_id) return new Response('missing profile_id', { status: 400 });
    if (kind === 'decision') return await announceDecision(profile_id);

    // Claim the announcement: only a still-pending, not-yet-announced sign-up.
    const { data: claimed } = await supabase
      .from('profiles')
      .update({ push_notified_at: new Date().toISOString() })
      .eq('id', profile_id)
      .eq('role', 'servant')
      .eq('is_active', false)
      .is('rejected_at', null)
      .is('push_notified_at', null)
      .select('full_name')
      .maybeSingle();
    if (!claimed) return new Response('nothing to announce', { status: 200 });

    const { data: admins } = await supabase
      .from('profiles')
      .select('id')
      .eq('role', 'admin')
      .eq('is_active', true);
    const ids = (admins ?? []).map((a) => a.id);
    if (ids.length === 0) return new Response('no admins', { status: 200 });

    const { data: tokens } = await supabase
      .from('device_tokens')
      .select('token')
      .in('user_id', ids);
    if (!tokens || tokens.length === 0) {
      return new Response('no devices', { status: 200 });
    }

    const sent = await sendPush(
      tokens,
      'طلب انضمام جديد',
      `${claimed.full_name} يطلب الانضمام للخدمة`,
    );
    return new Response(JSON.stringify({ sent }), { status: 200 });
  } catch (e) {
    return new Response(String(e), { status: 500 });
  }
});
