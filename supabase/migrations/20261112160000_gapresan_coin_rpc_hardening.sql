-- Move privileged coin operations out of the exposed public API schema.
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
  insert into public.gap_coin_wallets(user_id)
    values (v_uid) on conflict (user_id) do nothing;
  return query
    select w.balance, w.updated_at
    from public.gap_coin_wallets w
    where w.user_id = v_uid;
end;
$function$;

revoke all on function fun_internal.get_my_coin_wallet() from public, anon, authenticated;
grant execute on function fun_internal.get_my_coin_wallet() to authenticated;

create or replace function public.get_my_coin_wallet()
returns table(balance bigint, updated_at timestamptz)
language sql
security invoker
set search_path = ''
as $function$ select * from fun_internal.get_my_coin_wallet(); $function$;
revoke all on function public.get_my_coin_wallet() from public, anon;
grant execute on function public.get_my_coin_wallet() to authenticated;

create or replace function fun_internal.transfer_gap_coins(
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
  v_sent_today bigint;
  v_transfer_count integer;
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
  select coalesce(sum(t.amount),0), count(*)::integer
    into v_sent_today, v_transfer_count
    from public.gap_coin_transactions t
    where t.transaction_type = 'transfer'
      and t.from_user_id = v_uid
      and t.created_at >= date_trunc('day', now());
  if v_transfer_count >= 20 or v_sent_today + p_amount > 100000 then
    raise exception 'transfer_limit_exceeded' using errcode = '22023';
  end if;
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

revoke all on function fun_internal.transfer_gap_coins(uuid,bigint,text) from public, anon, authenticated;
grant execute on function fun_internal.transfer_gap_coins(uuid,bigint,text) to authenticated;

create or replace function public.transfer_gap_coins(
  p_to_user_id uuid, p_amount bigint, p_request_key text
)
returns table(transaction_id uuid, balance_after bigint)
language sql
security invoker
set search_path = ''
as $function$
  select * from fun_internal.transfer_gap_coins(p_to_user_id, p_amount, p_request_key);
$function$;
revoke all on function public.transfer_gap_coins(uuid,bigint,text) from public, anon;
grant execute on function public.transfer_gap_coins(uuid,bigint,text) to authenticated;
