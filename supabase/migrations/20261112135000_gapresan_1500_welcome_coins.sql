-- Grant every GapResan account 1,500 welcome coins exactly once.
-- The welcome credit is server-owned, immutable in the ledger, and idempotent.
alter table public.gap_coin_transactions
  drop constraint if exists gap_coin_transactions_transaction_type_check;

alter table public.gap_coin_transactions
  add constraint gap_coin_transactions_transaction_type_check
  check (transaction_type in ('purchase','transfer','refund','game_spend','signup_bonus'));

alter table public.gap_coin_transactions
  drop constraint if exists gap_coin_tx_participants;

alter table public.gap_coin_transactions
  add constraint gap_coin_tx_participants check (
    (transaction_type = 'purchase'
      and from_user_id is null and to_user_id is not null
      and payment_provider is not null and payment_reference is not null
      and payment_product_id is not null and price_minor is not null
      and currency_code is not null)
    or
    (transaction_type = 'transfer'
      and from_user_id is not null and to_user_id is not null
      and from_user_id <> to_user_id and request_key is not null)
    or
    (transaction_type = 'refund'
      and from_user_id is null and to_user_id is not null
      and payment_provider is not null and payment_reference is not null)
    or
    (transaction_type = 'game_spend'
      and from_user_id is not null and to_user_id is null)
    or
    (transaction_type = 'signup_bonus'
      and from_user_id is null and to_user_id is not null
      and request_key is null)
  );

create unique index if not exists gap_coin_signup_bonus_once_idx
  on public.gap_coin_transactions(to_user_id)
  where transaction_type = 'signup_bonus';

create or replace function fun_internal.grant_welcome_coins(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_granted uuid;
begin
  if p_user_id is null then return; end if;

  insert into public.gap_coin_wallets(user_id)
    values (p_user_id)
    on conflict (user_id) do nothing;

  insert into public.gap_coin_transactions(
    transaction_type, from_user_id, to_user_id, amount, request_key, description
  ) values (
    'signup_bonus', null, p_user_id, 1500, null, '۱۵۰۰ سکه هدیه خوش‌آمدگویی گپ‌رسان'
  )
  on conflict (to_user_id) where transaction_type = 'signup_bonus'
  do nothing
  returning to_user_id into v_granted;

  if v_granted is not null then
    update public.gap_coin_wallets
      set balance = balance + 1500, updated_at = now()
      where user_id = p_user_id;
  end if;
end;
$function$;

revoke all on function fun_internal.grant_welcome_coins(uuid) from public, anon, authenticated;
grant execute on function fun_internal.grant_welcome_coins(uuid) to service_role;

create or replace function fun_internal.on_gapresan_user_created()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
begin
  perform fun_internal.grant_welcome_coins(new.id);
  return new;
end;
$function$;

revoke all on function fun_internal.on_gapresan_user_created() from public, anon, authenticated;

drop trigger if exists gapresan_welcome_coins_after_signup on auth.users;
create trigger gapresan_welcome_coins_after_signup
  after insert on auth.users
  for each row execute function fun_internal.on_gapresan_user_created();

-- Backfill accounts that existed before this migration. The unique ledger index
-- prevents duplicate credits if this migration or backfill is retried.
select fun_internal.grant_welcome_coins(id) from auth.users;

create or replace function fun_internal.get_my_coin_wallet()
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

  perform fun_internal.grant_welcome_coins(v_uid);

  return query
    select w.balance, w.updated_at
    from public.gap_coin_wallets w
    where w.user_id = v_uid;
end;
$function$;

revoke all on function fun_internal.get_my_coin_wallet() from public, anon, authenticated;
grant execute on function fun_internal.get_my_coin_wallet() to authenticated;
