create table if not exists public.stories (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  text text not null check (char_length(text) between 1 and 180),
  background text not null default '0xFF2563EB',
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '24 hours')
);

create index if not exists stories_expires_at_idx on public.stories(expires_at);
create index if not exists stories_user_id_idx on public.stories(user_id);

alter table public.stories enable row level security;

drop policy if exists "stories_select_authenticated" on public.stories;
create policy "stories_select_authenticated"
on public.stories for select
to authenticated
using (expires_at > now());

drop policy if exists "stories_insert_own" on public.stories;
create policy "stories_insert_own"
on public.stories for insert
to authenticated
with check (auth.uid() = user_id);

drop policy if exists "stories_update_own" on public.stories;
create policy "stories_update_own"
on public.stories for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "stories_delete_own" on public.stories;
create policy "stories_delete_own"
on public.stories for delete
to authenticated
using (auth.uid() = user_id);
