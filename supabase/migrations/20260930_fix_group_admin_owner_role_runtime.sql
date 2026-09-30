-- Keep group ownership/admin checks consistent with the Flutter UI.
-- Owners stored in conversation_members must be accepted by all group admin RPCs.
create or replace function private.is_group_admin(p_conversation_id uuid, p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select exists (
    select 1
    from public.conversations c
    left join public.conversation_admins ca
      on ca.conversation_id = c.id and ca.user_id = p_user_id
    left join public.conversation_members cm
      on cm.conversation_id = c.id and cm.user_id = p_user_id
    where c.id = p_conversation_id
      and c.type in ('group','channel')
      and (
        c.created_by = p_user_id
        or ca.role in ('owner','admin')
        or cm.role in ('owner','admin')
      )
  );
$function$;
