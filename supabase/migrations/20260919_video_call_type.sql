alter table public.call_sessions drop constraint if exists call_sessions_call_type_check;
alter table public.call_sessions add constraint call_sessions_call_type_check check (call_type in ('voice','video'));
