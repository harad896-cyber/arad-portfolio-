-- One-time welcome diamonds for every GapResan account.
-- Grants are written to a server-owned ledger and cannot be requested by clients.
create table if not exists public.gap_diamond_transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  transaction_type text not null check (transaction_type in ('signup_bonus')),
  amount bigint not null check (amount > 0),
  description text not null,
  created_at timestamptz not null default now()
);

create unique index if not exists gap_diamond_signup_bonus_once_idx
  on public.gap_diamond_transactions(user_id)
  where transaction_type = 'signup_bonus';

alter table public.gap_diamond_transactions enable row level security;
revoke all on public.gap_diamond_transactions from anon, authenticated;
grant select on public.gap_diamond_transactions to authenticated;
drop policy if exists gap_diamond_transactions_read_own on public.gap_diamond_transactions;
create policy gap_diamond_transactions_read_own
  on public.gap_diamond_transactions for select to authenticated
  using (user_id = (select auth.uid()));

create or replace function fun_internal.grant_ludo_welcome_diamonds(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_granted uuid;
begin
  if p_user_id is null then return; end if;

  insert into public.gap_diamond_wallets(user_id)
    values (p_user_id)
    on conflict (user_id) do nothing;

  insert into public.gap_diamond_transactions(
    user_id, transaction_type, amount, description
  ) values (
    p_user_id, 'signup_bonus', 10, '۱۰ الماس هدیه خوش‌آمدگویی گپ‌رسان'
  )
  on conflict (user_id) where transaction_type = 'signup_bonus'
  do nothing
  returning id into v_granted;

  if v_granted is not null then
    update public.gap_diamond_wallets
      set balance = balance + 10, updated_at = now()
      where user_id = p_user_id;
  end if;
end;
$function$;

revoke all on function fun_internal.grant_ludo_welcome_diamonds(uuid)
  from public, anon, authenticated;
grant execute on function fun_internal.grant_ludo_welcome_diamonds(uuid)
  to service_role;

create or replace function fun_internal.on_gapresan_diamond_signup()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
begin
  perform fun_internal.grant_ludo_welcome_diamonds(new.id);
  return new;
end;
$function$;

revoke all on function fun_internal.on_gapresan_diamond_signup()
  from public, anon, authenticated;

drop trigger if exists gapresan_welcome_diamonds_after_signup on auth.users;
create trigger gapresan_welcome_diamonds_after_signup
  after insert on auth.users
  for each row execute function fun_internal.on_gapresan_diamond_signup();

-- Backfill existing accounts once. The unique ledger index prevents duplicates.
select fun_internal.grant_ludo_welcome_diamonds(id) from auth.users;

create or replace function public.get_my_diamond_balance()
returns bigint
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_uid uuid := (select auth.uid());
  v_balance bigint;
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode = '28000';
  end if;

  perform fun_internal.grant_ludo_welcome_diamonds(v_uid);

  select coalesce(w.balance, 0::bigint)
    into v_balance
    from public.gap_diamond_wallets w
    where w.user_id = v_uid;

  return coalesce(v_balance, 0::bigint);
end;
$function$;

revoke all on function public.get_my_diamond_balance() from public, anon;
grant execute on function public.get_my_diamond_balance() to authenticated;
