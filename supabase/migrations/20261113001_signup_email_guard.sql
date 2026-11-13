-- Refuse fake emails at sign-up: throwaway inboxes and misspelled domains.
--
-- check_signup_email() answers the sign-up form before it creates anything,
-- so the person sees why. The trigger on auth.users runs the same check on
-- the server, so calling the Supabase sign-up API directly cannot skip it.
-- (Whether a domain can receive mail at all needs a DNS lookup, which the
-- database cannot do: the send-email function checks that for the form.)

create table if not exists public.email_domain_rules (
  domain     text primary key check (domain = lower(btrim(domain))),
  kind       text not null check (kind in ('disposable', 'typo')),
  -- For a typo: the domain the person most likely meant.
  suggestion text,
  created_at timestamptz not null default now()
);

comment on table public.email_domain_rules is
  'Email domains refused at sign-up: disposable inboxes, and common misspellings (with the intended domain).';

alter table public.email_domain_rules enable row level security;
-- No policies: read only through the functions below. Admins can add rows
-- from the dashboard.

insert into public.email_domain_rules (domain, kind, suggestion) values
  -- throwaway inbox services
  ('mailinator.com', 'disposable', null),
  ('mailinator.net', 'disposable', null),
  ('guerrillamail.com', 'disposable', null),
  ('guerrillamail.net', 'disposable', null),
  ('guerrillamail.org', 'disposable', null),
  ('guerrillamailblock.com', 'disposable', null),
  ('sharklasers.com', 'disposable', null),
  ('grr.la', 'disposable', null),
  ('10minutemail.com', 'disposable', null),
  ('10minutemail.net', 'disposable', null),
  ('10minemail.com', 'disposable', null),
  ('temp-mail.org', 'disposable', null),
  ('temp-mail.io', 'disposable', null),
  ('tempmail.com', 'disposable', null),
  ('tempmail.net', 'disposable', null),
  ('tempmailo.com', 'disposable', null),
  ('tempail.com', 'disposable', null),
  ('tempr.email', 'disposable', null),
  ('temporary-mail.net', 'disposable', null),
  ('throwawaymail.com', 'disposable', null),
  ('trashmail.com', 'disposable', null),
  ('trashmail.de', 'disposable', null),
  ('yopmail.com', 'disposable', null),
  ('yopmail.net', 'disposable', null),
  ('yopmail.fr', 'disposable', null),
  ('getnada.com', 'disposable', null),
  ('nada.email', 'disposable', null),
  ('dispostable.com', 'disposable', null),
  ('maildrop.cc', 'disposable', null),
  ('mailnesia.com', 'disposable', null),
  ('mintemail.com', 'disposable', null),
  ('mohmal.com', 'disposable', null),
  ('mytemp.email', 'disposable', null),
  ('emailondeck.com', 'disposable', null),
  ('fakeinbox.com', 'disposable', null),
  ('fakemail.net', 'disposable', null),
  ('spamgourmet.com', 'disposable', null),
  ('mailcatch.com', 'disposable', null),
  ('mail.tm', 'disposable', null),
  ('mail.gw', 'disposable', null),
  ('burnermail.io', 'disposable', null),
  ('emailfake.com', 'disposable', null),
  ('fakemailgenerator.com', 'disposable', null),
  ('inboxkitten.com', 'disposable', null),
  ('moakt.com', 'disposable', null),
  ('tmail.ws', 'disposable', null),
  ('tmpmail.org', 'disposable', null),
  ('tmpmail.net', 'disposable', null),
  ('spam4.me', 'disposable', null),
  ('mailpoof.com', 'disposable', null),
  ('anonbox.net', 'disposable', null),
  ('discard.email', 'disposable', null),
  ('emltmp.com', 'disposable', null),
  ('linshiyouxiang.net', 'disposable', null),
  ('mailto.plus', 'disposable', null),
  ('fexpost.com', 'disposable', null),
  ('fexbox.org', 'disposable', null),
  ('mailbox.in.ua', 'disposable', null),
  ('rover.info', 'disposable', null),
  ('chacuo.net', 'disposable', null),
  ('wegwerfmail.de', 'disposable', null),
  ('example.com', 'disposable', null),
  ('example.org', 'disposable', null),
  ('test.com', 'disposable', null),
  -- common misspellings, with the intended domain
  ('gmial.com', 'typo', 'gmail.com'),
  ('gmaill.com', 'typo', 'gmail.com'),
  ('gamil.com', 'typo', 'gmail.com'),
  ('gmal.com', 'typo', 'gmail.com'),
  ('gmai.com', 'typo', 'gmail.com'),
  ('gnail.com', 'typo', 'gmail.com'),
  ('gmail.co', 'typo', 'gmail.com'),
  ('gmail.con', 'typo', 'gmail.com'),
  ('gmail.cm', 'typo', 'gmail.com'),
  ('gmail.om', 'typo', 'gmail.com'),
  ('gmail.comm', 'typo', 'gmail.com'),
  ('gmail.vom', 'typo', 'gmail.com'),
  ('gmail.xom', 'typo', 'gmail.com'),
  ('gmail.net', 'typo', 'gmail.com'),
  ('gmail.com.eg', 'typo', 'gmail.com'),
  ('hotmial.com', 'typo', 'hotmail.com'),
  ('hotmal.com', 'typo', 'hotmail.com'),
  ('hotmil.com', 'typo', 'hotmail.com'),
  ('hotmai.com', 'typo', 'hotmail.com'),
  ('hotmail.co', 'typo', 'hotmail.com'),
  ('hotmail.con', 'typo', 'hotmail.com'),
  ('homail.com', 'typo', 'hotmail.com'),
  ('outlok.com', 'typo', 'outlook.com'),
  ('outlook.co', 'typo', 'outlook.com'),
  ('outlook.con', 'typo', 'outlook.com'),
  ('yaho.com', 'typo', 'yahoo.com'),
  ('yahooo.com', 'typo', 'yahoo.com'),
  ('yahoo.co', 'typo', 'yahoo.com'),
  ('yahoo.con', 'typo', 'yahoo.com'),
  ('icloud.co', 'typo', 'icloud.com'),
  ('icoud.com', 'typo', 'icloud.com')
on conflict (domain) do nothing;

-- {ok, reason, suggestion}: reason is 'invalid', 'disposable' or 'typo'.
create or replace function public.check_signup_email(p_email text)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_email  text := lower(btrim(coalesce(p_email, '')));
  v_domain text;
  v_rule   public.email_domain_rules;
begin
  -- local@domain.tld, no spaces, a dot in the domain, a 2+ letter ending.
  if v_email !~ '^[^@\s]+@[^@\s]+\.[a-z]{2,}$' then
    return jsonb_build_object('ok', false, 'reason', 'invalid');
  end if;
  v_domain := split_part(v_email, '@', 2);

  select * into v_rule from public.email_domain_rules where domain = v_domain;
  if found then
    return jsonb_build_object(
      'ok', false,
      'reason', v_rule.kind,
      'suggestion', case when v_rule.suggestion is null then null
                         else split_part(v_email, '@', 1) || '@' || v_rule.suggestion end
    );
  end if;
  return jsonb_build_object('ok', true);
end;
$$;

revoke all on function public.check_signup_email(text) from public;
grant execute on function public.check_signup_email(text) to anon, authenticated;

-- The server-side guard: a new account with a refused email is not created.
create or replace function public.guard_signup_email()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_check jsonb;
begin
  if new.email is null then
    return new;
  end if;
  v_check := public.check_signup_email(new.email);
  if not (v_check ->> 'ok')::boolean then
    raise exception 'signup_email_rejected:%', v_check ->> 'reason'
      using errcode = 'P0001';
  end if;
  return new;
end;
$$;

drop trigger if exists before_auth_user_created_email on auth.users;
create trigger before_auth_user_created_email
  before insert on auth.users
  for each row execute function public.guard_signup_email();
