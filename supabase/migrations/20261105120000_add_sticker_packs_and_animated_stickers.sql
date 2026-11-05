-- Animated sticker catalog and public asset delivery for GapResan.
create table if not exists public.sticker_packs (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name text not null,
  description text,
  cover_path text,
  is_active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint sticker_packs_slug_length check (char_length(slug) between 2 and 64),
  constraint sticker_packs_name_length check (char_length(name) between 1 and 100)
);

create table if not exists public.stickers (
  id uuid primary key default gen_random_uuid(),
  pack_id uuid not null references public.sticker_packs(id) on delete cascade,
  slug text not null,
  name text not null,
  asset_path text not null,
  preview_path text,
  format text not null default 'lottie'
    check (format in ('lottie', 'gif', 'webp', 'png')),
  tags text[] not null default '{}',
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  constraint stickers_pack_slug_unique unique (pack_id, slug),
  constraint stickers_slug_length check (char_length(slug) between 1 and 80),
  constraint stickers_asset_path_length check (char_length(asset_path) between 1 and 500)
);

create index if not exists stickers_active_pack_sort_idx
  on public.stickers (pack_id, sort_order) where is_active = true;
create index if not exists sticker_packs_active_sort_idx
  on public.sticker_packs (sort_order) where is_active = true;

alter table public.sticker_packs enable row level security;
alter table public.stickers enable row level security;

drop policy if exists sticker_packs_read_active on public.sticker_packs;
create policy sticker_packs_read_active
  on public.sticker_packs for select to anon, authenticated
  using (is_active = true);

drop policy if exists stickers_read_active on public.stickers;
create policy stickers_read_active
  on public.stickers for select to anon, authenticated
  using (
    is_active = true
    and exists (
      select 1 from public.sticker_packs p
      where p.id = stickers.pack_id and p.is_active = true
    )
  );

grant select on public.sticker_packs, public.stickers to anon, authenticated;
revoke insert, update, delete, truncate, references, trigger
  on public.sticker_packs, public.stickers from anon, authenticated;

alter table public.messages drop constraint if exists messages_message_type_check;
alter table public.messages
  add constraint messages_message_type_check
  check (message_type = any (array[
    'text','image','video','file','audio','poll','sticker','gif'
  ]));

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('stickers', 'stickers', true, 10485760,
  array['application/json','image/gif','image/webp','image/png'])
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;
