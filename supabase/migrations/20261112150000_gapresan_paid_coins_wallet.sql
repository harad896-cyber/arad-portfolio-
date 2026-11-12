-- GapResan paid-only virtual coins: server-owned wallet ledger and transfers.
-- Purchases are credited only by a trusted server after the payment provider verifies them.
create schema if not exists fun_internal;
grant usage on schema fun_internal to service_role;

create table if not exists public.gap_coin_wallets (
  user_id uuid primary key references auth.users(id) on delete cascade,
  balance bigint not null default 0 check (balance >= 0),
  updated_at timestamptz not null default now()
);

create table if not exists public.gap_coin_transactions (
  id uuid primary key default gen_random_uuid(),
  transaction_type text not null check (transaction_type in ('purchase','transfer','refund','game_spend')),
  from_user_id uuid references auth.users(id) on delete set null,
  to_user_id uuid references auth.users(id) on delete set null,
  amount bigint not null check (amount > 0 and amount <= 100000000),
  request_key text,
  payment_provider text,
  payment_reference text,
  description text,
  created_at timestamptz not null default now(),
  constraint gap_coin_tx_participants check (
    (transaction_type = 'purchase' and from_user_id is null and to_user_id is not null
      and payment_provider is not null and payment_reference is not null)
    or
    (transaction_type = 'transfer' and from_user_id is not null and to_user_id is not null
      and from_user_id <> to_user_id and request_key is not null)
    or
    (transaction_type in ('refund','game_spend'))
  )
);

create unique index if not exists gap_coin_transfer_idempotency_idx
  on public.gap_coin_transactions(from_user_id, request_key)
  where transaction_type = 'transfer';
create unique index if not exists gap_coin_payment_reference_idx
  on public.gap_coin_transactions(payment_provider, payment_reference)
  where transaction_type = 'purchase';
create index if not exists gap_coin_tx_sender_created_idx
  on public.gap_coin_transactions(from_user_id, created_at desc);
create index if not exists gap_coin_tx_receiver_created_idx
  on public.gap_coin_transactions(to_user_id, created_at desc);

alter table public.gap_coin_wallets enable row level security;
alter table public.gap_coin_transactions enable row level security;
revoke all on public.gap_coin_wallets, public.gap_coin_transactions from anon, authenticated;
grant select on public.gap_coin_wallets, public.gap_coin_transactions to authenticated;
grant select, insert, update on public.gap_coin_wallets to service_role;
grant select, insert on public.gap_coin_transactions to service_role;

drop policy if exists gap_coin_wallet_read_own on public.gap_coin_wallets;
create policy gap_coin_wallet_read_own on public.gap_coin_wallets
  for select to authenticated using ((select auth.uid()) = user_id);

drop policy if exists gap_coin_transaction_read_participant on public.gap_coin_transactions;
create policy gap_coin_transaction_read_participant on public.gap_coin_transactions
  for select to authenticated
  using ((select auth.uid()) = from_user_id or (select auth.uid()) = to_user_id);

-- A new account wallet is created on first wallet open. The client cannot set a balance.
create or replace function public.get_my_coin_wallet()
returns table(balance bigint, updated_at timestamptz)
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_uid uuid := (select auth.uid());
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode = '28000';
  end if;
  insert into public.gap_coin_wallets(user_id)
    values (v_uid) on conflict (user_id) do nothing;
  return query
    select w.balance, w.updated_at
    from public.gap_coin_wallets w
    where w.user_id = v_uid;
end;
$function$;
revoke all on function public.get_my_coin_wallet() from public, anon;
grant execute on function public.get_my_coin_wallet() to authenticated;

-- Transfers are atomic, idempotent, serialized by wallet row locks, and never trust a client balance.
create or replace function public.transfer_gap_coins(
  p_to_user_id uuid,
  p_amount bigint,
  p_request_key text
)
returns table(transaction_id uuid, balance_after bigint)
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_uid uuid := (select auth.uid());
  v_existing public.gap_coin_transactions%rowtype;
  v_balance bigint;
  v_tx_id uuid;
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode = '28000';
  end if;
  if p_to_user_id is null or p_to_user_id = v_uid then
    raise exception 'invalid_recipient' using errcode = '22023';
  end if;
  if p_amount is null or p_amount < 1 or p_amount > 100000 then
    raise exception 'invalid_amount' using errcode = '22023';
  end if;
  if p_request_key is null or length(p_request_key) < 12 or length(p_request_key) > 80 then
    raise exception 'invalid_request_key' using errcode = '22023';
  end if;
  if not exists (select 1 from auth.users u where u.id = p_to_user_id) then
    raise exception 'recipient_not_found' using errcode = '22023';
  end if;

  insert into public.gap_coin_wallets(user_id)
    values (v_uid), (p_to_user_id)
    on conflict (user_id) do nothing;

  perform w.user_id
    from public.gap_coin_wallets w
    where w.user_id in (v_uid, p_to_user_id)
    order by w.user_id
    for update;

  select t.* into v_existing
    from public.gap_coin_transactions t
    where t.transaction_type = 'transfer'
      and t.from_user_id = v_uid
      and t.request_key = p_request_key;
  if found then
    if v_existing.to_user_id <> p_to_user_id or v_existing.amount <> p_amount then
      raise exception 'idempotency_key_reused' using errcode = '22023';
    end if;
    select w.balance into v_balance from public.gap_coin_wallets w where w.user_id = v_uid;
    return query select v_existing.id, v_balance;
    return;
  end if;

  select w.balance into v_balance
    from public.gap_coin_wallets w where w.user_id = v_uid;
  if v_balance < p_amount then
    raise exception 'insufficient_coins' using errcode = '22023';
  end if;

  insert into public.gap_coin_transactions(
    transaction_type, from_user_id, to_user_id, amount, request_key, description
  ) values (
    'transfer', v_uid, p_to_user_id, p_amount, p_request_key, 'انتقال سکه بین کاربران'
  ) returning id into v_tx_id;

  update public.gap_coin_wallets
    set balance = balance - p_amount, updated_at = now()
    where user_id = v_uid
    returning balance into v_balance;
  update public.gap_coin_wallets
    set balance = balance + p_amount, updated_at = now()
    where user_id = p_to_user_id;

  return query select v_tx_id, v_balance;
end;
$function$;
revoke all on function public.transfer_gap_coins(uuid,bigint,text) from public, anon;
grant execute on function public.transfer_gap_coins(uuid,bigint,text) to authenticated;

-- Trusted backend only: call after verifying the purchase with Google Play/another approved provider.
create or replace function fun_internal.credit_verified_coin_purchase(
  p_user_id uuid,
  p_amount bigint,
  p_payment_provider text,
  p_payment_reference text,
  p_description text default null
)
returns table(transaction_id uuid, balance_after bigint)
language plpgsql
security invoker
set search_path = ''
as $function$
declare
  v_tx_id uuid;
  v_balance bigint;
begin
  if p_user_id is null or p_amount is null or p_amount < 1 or p_amount > 100000000
     or p_payment_provider is null or length(p_payment_provider) > 40
     or p_payment_reference is null or length(p_payment_reference) < 8
     or length(p_payment_reference) > 200 then
    raise exception 'invalid_purchase_payload' using errcode = '22023';
  end if;

  insert into public.gap_coin_wallets(user_id)
    values (p_user_id) on conflict (user_id) do nothing;
  perform 1 from public.gap_coin_wallets where user_id = p_user_id for update;

  select * into v_existing from public.gap_coin_transactions
    where transaction_type = 'purchase'
      and payment_provider = p_payment_provider
      and payment_reference = p_payment_reference;
  if found then
    if v_existing.to_user_id <> p_user_id or v_existing.amount <> p_amount then
      raise exception 'purchase_reference_reused' using errcode = '22023';
    end if;
    select balance into v_balance from public.gap_coin_wallets where user_id = p_user_id;
    return query select v_existing.id, v_balance;
    return;
  end if;

  insert into public.gap_coin_transactions(
    transaction_type, to_user_id, amount, payment_provider, payment_reference, description
  ) values (
    'purchase', p_user_id, p_amount, p_payment_provider, p_payment_reference, p_description
  ) returning id into v_tx_id;

  update public.gap_coin_wallets
    set balance = balance + p_amount, updated_at = now()
    where user_id = p_user_id returning balance into v_balance;

  return query select v_tx_id, v_balance;
end;
$function$;
revoke all on function fun_internal.credit_verified_coin_purchase(uuid,bigint,text,text,text) from public, anon, authenticated;
grant execute on function fun_internal.credit_verified_coin_purchase(uuid,bigint,text,text,text) to service_role;

comment on table public.gap_coin_wallets is 'GapResan paid-only virtual coin wallet; balances are server-managed.';
comment on table public.gap_coin_transactions is 'Immutable audit ledger for paid coin purchases and peer transfers. No client-side balance writes.';
