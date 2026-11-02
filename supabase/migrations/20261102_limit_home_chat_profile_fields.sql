-- Avoid returning the entire profiles row from the SECURITY DEFINER home-chat RPC.
-- Keep the fields consumed by the app, but never serialize phone, country, or owner flags.
CREATE OR REPLACE FUNCTION public.get_home_conversations()
RETURNS TABLE(
  conversation_id uuid,
  type text,
  title text,
  avatar_url text,
  description text,
  username text,
  is_public boolean,
  created_at timestamp with time zone,
  peer jsonb,
  last_message jsonb,
  preview text,
  unread_count bigint
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
  select
    c.id,c.type,c.title,c.avatar_url,c.description,c.username,c.is_public,c.created_at,
    case when c.type='direct' then (
      select jsonb_build_object(
        'id', p.id,
        'username', p.username,
        'display_name', p.display_name,
        'avatar_url', p.avatar_url,
        'bio', p.bio,
        'is_online', p.is_online,
        'last_seen', p.last_seen,
        'is_verified', p.is_verified,
        'created_at', p.created_at,
        'joined_at', p.joined_at
      )
      from public.profiles p
      where p.id=(
        select cm2.user_id
        from public.conversation_members cm2
        where cm2.conversation_id=c.id
          and cm2.user_id <> auth.uid()
        limit 1
      )
    ) else null end as peer,
    case when lm.id is null then null else jsonb_build_object(
      'id',lm.id,'sender_id',lm.sender_id,'body',lm.body,
      'message_type',lm.message_type,'created_at',lm.created_at,'read_at',lm.read_at
    ) end as last_message,
    case
      when lm.id is null then 'هنوز پیامی ارسال نشده'
      when nullif(trim(coalesce(lm.body,'')),'') is not null then lm.body
      when lm.message_type='image' then '📷 تصویر'
      when lm.message_type='video' then '🎬 ویدیو'
      when lm.message_type='audio' then '🎙️ پیام صوتی'
      when lm.message_type='file' then '📎 فایل'
      else 'پیام'
    end as preview,
    (select count(*) from public.messages um
      where um.conversation_id=c.id
        and um.sender_id<>auth.uid()
        and um.read_at is null) as unread_count
  from public.conversation_members me
  join public.conversations c on c.id=me.conversation_id
  left join lateral (
    select m.id,m.sender_id,m.body,m.message_type,m.created_at,m.read_at
    from public.messages m
    where m.conversation_id=c.id
    order by m.created_at desc
    limit 1
  ) lm on true
  where me.user_id=auth.uid()
  order by coalesce(lm.created_at,c.created_at) desc;
$function$;
