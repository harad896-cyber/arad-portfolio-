create index if not exists messages_conversation_created_idx on public.messages(conversation_id,created_at desc);

create or replace function public.get_home_conversations()
returns table(
 conversation_id uuid,type text,title text,avatar_url text,description text,username text,is_public boolean,created_at timestamptz,
 peer jsonb,last_message jsonb,preview text,unread_count bigint)
language sql stable security definer set search_path=public
as $$
select c.id,c.type,c.title,c.avatar_url,c.description,c.username,c.is_public,c.created_at,
 case when c.type='direct' then (select to_jsonb(p) from profiles p where p.id=(select cm2.user_id from conversation_members cm2 where cm2.conversation_id=c.id and cm2.user_id<>auth.uid() limit 1)) else null end,
 case when lm.id is null then null else jsonb_build_object('id',lm.id,'sender_id',lm.sender_id,'body',lm.body,'message_type',lm.message_type,'created_at',lm.created_at,'read_at',lm.read_at) end,
 case when lm.id is null then 'هنوز پیامی ارسال نشده' when nullif(trim(coalesce(lm.body,'')),'') is not null then lm.body when lm.message_type='image' then '📷 تصویر' when lm.message_type='video' then '🎬 ویدیو' when lm.message_type='audio' then '🎙️ پیام صوتی' when lm.message_type='file' then '📎 فایل' else 'پیام' end,
 (select count(*) from messages um where um.conversation_id=c.id and um.sender_id<>auth.uid() and um.read_at is null)
from conversation_members me join conversations c on c.id=me.conversation_id
left join lateral (select m.id,m.sender_id,m.body,m.message_type,m.created_at,m.read_at from messages m where m.conversation_id=c.id order by m.created_at desc limit 1) lm on true
where me.user_id=auth.uid()
order by coalesce(lm.created_at,c.created_at) desc;
$$;
revoke all on function public.get_home_conversations() from public;
grant execute on function public.get_home_conversations() to authenticated;