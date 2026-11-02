-- Add payment_method column to event_payments
alter table public.event_payments
  add column if not exists payment_method text not null default 'cash'
    check (payment_method in ('cash', 'tayo'));
