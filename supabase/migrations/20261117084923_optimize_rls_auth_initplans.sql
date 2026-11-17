-- Cache auth.uid() as an initplan in row-level security policies.
-- This preserves each policy predicate while avoiding per-row auth function evaluation.
do $$
declare
  p record;
  v_using text;
  v_check text;
  v_sql text;
begin
  for p in
    select schemaname, tablename, policyname, qual, with_check
    from pg_policies
    where schemaname = 'public'
      and (
        (qual ~* 'auth[.]uid[(][)]' and qual !~* 'select[[:space:]]+auth[.]uid')
        or
        (with_check ~* 'auth[.]uid[(][)]' and with_check !~* 'select[[:space:]]+auth[.]uid')
      )
  loop
    v_using := case
      when p.qual is null then null
      else regexp_replace(p.qual, 'auth[.]uid[(][)]', '(select auth.uid())', 'g')
    end;
    v_check := case
      when p.with_check is null then null
      else regexp_replace(p.with_check, 'auth[.]uid[(][)]', '(select auth.uid())', 'g')
    end;

    v_sql := format('alter policy %I on %I.%I', p.policyname, p.schemaname, p.tablename);
    if v_using is not null then
      v_sql := v_sql || format(' using (%s)', v_using);
    end if;
    if v_check is not null then
      v_sql := v_sql || format(' with check (%s)', v_check);
    end if;
    execute v_sql;
  end loop;
end
$$;
