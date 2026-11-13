import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import nodemailer from 'npm:nodemailer@6.9.14';

const GMAIL_USER = Deno.env.get('GMAIL_USER') ?? '';
const GMAIL_PASS = Deno.env.get('GMAIL_PASS') ?? '';
const FROM = `سبتاوية <${GMAIL_USER}>`;

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
};

interface Payload {
  type: 'invite' | 'accepted' | 'rejected' | 'check_email' | 'check_domain';
  to?: string;
  name?: string;
  email?: string;
}

// Names go into the email's HTML: never let one carry markup or links.
function escapeHtml(v: string): string {
  return v
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, 'Content-Type': 'application/json' },
  });
}

// Sending mail is for an active admin only (invites, accept / reject). The
// caller's own sign-in token is checked here: the public key alone, or a
// servant's token, is refused, so nobody can send mail from this account.
async function callerIsAdmin(req: Request): Promise<boolean> {
  const token = (req.headers.get('Authorization') ?? '').replace(/^Bearer\s+/i, '');
  if (!token) return false;
  const admin = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
  );
  const { data: userData, error } = await admin.auth.getUser(token);
  const userId = userData?.user?.id;
  if (error || !userId) return false;
  const { data: profile } = await admin
    .from('profiles')
    .select('role, is_active')
    .eq('id', userId)
    .maybeSingle();
  return profile?.role === 'admin' && profile?.is_active === true;
}

function buildEmail(
  type: string,
  name: string,
): { subject: string; html: string } {
  const appUrl = 'https://sabtawya.vercel.app';

  const logoUrl =
    'https://sabtawya.vercel.app/assets/assets/images/logo.png';

  const header = `
    <div style="text-align:center;padding:24px 0 16px">
      <img src="${logoUrl}" alt="سبتاوية" width="80" height="80"
           style="border-radius:16px;object-fit:cover"/>
      <h1 style="color:#1B3A6B;font-size:22px;margin:10px 0 0">سبتاوية</h1>
      <p style="color:#8A9A2B;font-size:12px;margin:2px 0 0">نظام إدارة الحضور والطايو</p>
    </div>`;

  const footer = `
    <hr style="border:none;border-top:1px solid #eee;margin:24px 0"/>
    <p style="color:#888;font-size:12px;margin:0;text-align:center">
      خدمة 3:6 ابتدائي السبت &mdash; كنيسة السيدة العذراء مريم والقديس اثناسيوس الرسولي بمدينة نصر
    </p>`;

  if (type === 'invite') {
    return {
      subject: 'دعوة للانضمام إلى سبتاوية',
      html: `
        <div style="font-family:Arial,sans-serif;max-width:520px;margin:0 auto;background:#f6f7fb;border-radius:12px;overflow:hidden">
          ${header}
          <div dir="rtl" style="padding:24px;background:#fff;border-radius:0 0 12px 12px;color:#1a1a1a">
            <h2 style="color:#1B3A6B;margin:0 0 12px">أهلاً ${name}،</h2>
            <p style="line-height:1.7">
              تمت دعوتك للانضمام إلى تطبيق <strong>سبتاوية</strong> لإدارة الحضور والطايو.
              سجّل بنفس البريد الإلكتروني الذي وصلتك عليه هذه الرسالة.
            </p>
            <div style="text-align:center">
              <a href="${appUrl}"
                 style="display:inline-block;margin:20px 0;padding:12px 28px;background:#1B3A6B;color:#fff;
                        text-decoration:none;border-radius:6px;font-weight:bold">
                سجّل الآن
              </a>
            </div>
            <p style="color:#555;font-size:13px">
              إذا لم تكن تتوقع هذه الدعوة، يمكنك تجاهل هذه الرسالة.
            </p>
            ${footer}
          </div>
        </div>`,
    };
  }

  if (type === 'accepted') {
    return {
      subject: 'تم قبول طلبك — سبتاوية',
      html: `
        <div style="font-family:Arial,sans-serif;max-width:520px;margin:0 auto;background:#f6f7fb;border-radius:12px;overflow:hidden">
          ${header}
          <div dir="rtl" style="padding:24px;background:#fff;border-radius:0 0 12px 12px;color:#1a1a1a">
            <h2 style="color:#8A9A2B;margin:0 0 12px">أهلاً ${name}،</h2>
            <p style="line-height:1.7">
              تمت الموافقة على طلب انضمامك إلى تطبيق <strong>سبتاوية</strong>.
              يمكنك الآن تسجيل الدخول والبدء في استخدام التطبيق.
            </p>
            <div style="text-align:center">
              <a href="${appUrl}"
                 style="display:inline-block;margin:20px 0;padding:12px 28px;background:#8A9A2B;color:#fff;
                        text-decoration:none;border-radius:6px;font-weight:bold">
                تسجيل الدخول
              </a>
            </div>
            ${footer}
          </div>
        </div>`,
    };
  }

  // rejected
  return {
    subject: 'بخصوص طلب الانضمام — سبتاوية',
    html: `
      <div style="font-family:Arial,sans-serif;max-width:520px;margin:0 auto;background:#f6f7fb;border-radius:12px;overflow:hidden">
        ${header}
        <div dir="rtl" style="padding:24px;background:#fff;border-radius:0 0 12px 12px;color:#1a1a1a">
          <h2 style="color:#8C1C2B;margin:0 0 12px">أهلاً ${name}،</h2>
          <p style="line-height:1.7">
            نأسف لإعلامك بأنه لم يتم قبول طلب انضمامك إلى تطبيق <strong>سبتاوية</strong>
            في الوقت الحالي. يمكنك التواصل مع أمين الخدمة لمزيد من المعلومات.
          </p>
          ${footer}
        </div>
      </div>`,
  };
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: CORS });
  }

  const body = (await req.json()) as Payload;

  // Can this email's domain receive mail at all? Looks up its MX records,
  // so a made-up or misspelled domain is caught before the account is made.
  // Fails open: a DNS hiccup must never stop a real person signing up.
  if (body.type === 'check_domain') {
    const email = (body.email ?? '').trim().toLowerCase();
    const domain = email.includes('@') ? email.split('@').pop()! : '';
    let receivesMail = true;
    if (domain) {
      try {
        const mx = await Deno.resolveDns(domain, 'MX');
        receivesMail = mx.length > 0;
      } catch (e) {
        // NotFound: the domain has no mail server (or does not exist).
        receivesMail = !(e instanceof Deno.errors.NotFound);
      }
    }
    return new Response(JSON.stringify({ receivesMail, domain }), {
      status: 200,
      headers: { ...CORS, 'Content-Type': 'application/json' },
    });
  }

  // Email existence check — uses service role to bypass RLS.
  if (body.type === 'check_email') {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    );
    const email = (body.email ?? '').trim().toLowerCase();
    const { data } = await supabase
      .from('profiles')
      .select('id')
      .ilike('email', email)
      .maybeSingle();
    return new Response(JSON.stringify({ exists: data !== null }), {
      status: 200,
      headers: { ...CORS, 'Content-Type': 'application/json' },
    });
  }

  // Everything below sends an email.
  if (!['invite', 'accepted', 'rejected'].includes(body.type)) {
    return json({ error: 'unknown type' }, 400);
  }
  if (!(await callerIsAdmin(req))) {
    return json({ error: 'forbidden' }, 403);
  }
  const to = (body.to ?? '').trim();
  if (!/^[^@\s]+@[^@\s]+\.[a-z]{2,}$/i.test(to)) {
    return json({ error: 'invalid recipient' }, 400);
  }

  if (!GMAIL_USER || !GMAIL_PASS) {
    return new Response(
      JSON.stringify({ error: 'GMAIL_USER or GMAIL_PASS not configured' }),
      { status: 500, headers: { ...CORS, 'Content-Type': 'application/json' } },
    );
  }

  try {
    const { subject, html } = buildEmail(
      body.type,
      escapeHtml((body.name ?? '').slice(0, 120)),
    );

    const transporter = nodemailer.createTransport({
      host: 'smtp.gmail.com',
      port: 587,
      secure: false,
      auth: { user: GMAIL_USER, pass: GMAIL_PASS },
    });

    const info = await transporter.sendMail({ from: FROM, to, subject, html });

    return new Response(JSON.stringify({ id: info.messageId }), {
      status: 200,
      headers: { ...CORS, 'Content-Type': 'application/json' },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { ...CORS, 'Content-Type': 'application/json' },
    });
  }
});
