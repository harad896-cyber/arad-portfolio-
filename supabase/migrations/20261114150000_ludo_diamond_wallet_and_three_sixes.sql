-- Separate premium diamond balance for Ludo. No welcome grants or automatic
-- account seeding: every account starts at zero until an authorized grant is made.
create table if not exists public.gap_diamond_wallets (
  user_id uuid primary key references auth.users(id) on delete cascade,
  balance bigint not null default 0 check (balance >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.gap_diamond_wallets enable row level security;
revoke all on public.gap_diamond_wallets from anon, authenticated;
grant select on public.gap_diamond_wallets to authenticated;

drop policy if exists gap_diamond_wallets_select_own on public.gap_diamond_wallets;
create policy gap_diamond_wallets_select_own
  on public.gap_diamond_wallets
  for select to authenticated
  using (user_id = (select auth.uid()));

create or replace function public.get_my_diamond_balance()
returns bigint
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((
    select w.balance
    from public.gap_diamond_wallets as w
    where w.user_id = (select auth.uid())
  ), 0::bigint);
$$;

create or replace function public.spend_ludo_diamonds(p_amount integer)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_updated integer;
begin
  if v_user_id is null then
    raise exception 'authentication_required';
  end if;
  if p_amount <> 2 then
    raise exception 'invalid_ludo_diamond_cost';
  end if;

  update public.gap_diamond_wallets
     set balance = balance - 2,
         updated_at = now()
   where user_id = v_user_id
     and balance >= 2;

  get diagnostics v_updated = row_count;
  return v_updated = 1;
end;
$$;

revoke all on function public.get_my_diamond_balance() from public, anon;
revoke all on function public.spend_ludo_diamonds(integer) from public, anon;
grant execute on function public.get_my_diamond_balance() to authenticated;
grant execute on function public.spend_ludo_diamonds(integer) to authenticated;
