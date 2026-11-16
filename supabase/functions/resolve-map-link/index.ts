import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';

// Turns a shortened Google Maps link (maps.app.goo.gl/…) into the long one the
// app can read the coordinates from. Only Google's own map hosts are ever
// contacted or followed, so this cannot be used to reach anything else.

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
};

const MAX_HOPS = 6;

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, 'Content-Type': 'application/json' },
  });
}

function allowed(u: URL): boolean {
  if (u.protocol !== 'https:') return false;
  if (u.username || u.password || u.port) return false;
  const h = u.hostname.toLowerCase();
  if (h === 'maps.app.goo.gl' || h === 'goo.gl' || h === 'g.co') return true;
  if (h === 'maps.google.com') return true;
  if (/^(www\.)?google\.[a-z.]{2,6}$/.test(h)) {
    return h === 'google.com' || h === 'www.google.com' ||
      u.pathname.startsWith('/maps');
  }
  return false;
}

// Google may send a consent page first; the real address is in `continue`.
function unwrapConsent(u: URL): URL {
  if (u.hostname.startsWith('consent.')) {
    const next = u.searchParams.get('continue');
    if (next) {
      try {
        return new URL(next);
      } catch (_) { /* fall through */ }
    }
  }
  return u;
}

const COORDS: RegExp[] = [
  /!3d(-?\d{1,3}\.\d+)!4d(-?\d{1,3}\.\d+)/,
  /@(-?\d{1,3}\.\d+),(-?\d{1,3}\.\d+)/,
  /[?&;](?:q|ll|sll|query|destination|daddr|center)=(?:loc(?::|%3A))?(-?\d{1,3}\.\d+)(?:%2C|,|\+)(-?\d{1,3}\.\d+)/i,
  /\/(?:place|search|dir)\/(-?\d{1,3}\.\d+),\+?(-?\d{1,3}\.\d+)/,
];

function coordsIn(text: string): string | null {
  for (const re of COORDS) {
    const m = re.exec(text);
    if (m) return `${m[1]},${m[2]}`;
  }
  return null;
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });
  if (req.method !== 'POST') return json({ error: 'method' }, 405);

  let input = '';
  try {
    input = String((await req.json()).url ?? '').trim();
  } catch (_) {
    return json({ error: 'bad_request' }, 400);
  }
  // A pasted message may have words around the link.
  const found = input.match(/https?:\/\/[^\s]+/i);
  let url: URL;
  try {
    url = new URL(found ? found[0] : input);
  } catch (_) {
    return json({ error: 'bad_url' }, 400);
  }

  try {
    for (let hop = 0; hop <= MAX_HOPS; hop++) {
      url = unwrapConsent(url);
      if (!allowed(url)) return json({ error: 'not_allowed' }, 400);

      const direct = coordsIn(decodeURIComponent(url.href));
      if (direct) return json({ url: url.href, coords: direct });

      const res = await fetch(url.href, {
        redirect: 'manual',
        headers: {
          'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 ' +
            '(KHTML, like Gecko) Chrome/124.0 Safari/537.36',
          'Accept-Language': 'en',
          Cookie: 'CONSENT=YES+; SOCS=CAI',
        },
        signal: AbortSignal.timeout(8000),
      });

      const location = res.headers.get('location');
      if (res.status >= 300 && res.status < 400 && location) {
        url = new URL(location, url);
        continue;
      }

      // A page, not a redirect, and no coordinates in its address: a place
      // shared by name. The page's own text is never read: to a server Google
      // sends a generic map centred on Zurich whatever the place, and a wrong
      // place is worse than none. The app tells the person what to do.
      await res.body?.cancel();
      return json({ url: url.href, coords: null });
    }
    return json({ error: 'too_many_redirects' }, 422);
  } catch (_) {
    return json({ error: 'unreachable' }, 502);
  }
});
