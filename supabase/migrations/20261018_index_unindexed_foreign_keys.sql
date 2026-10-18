-- Add leading-column indexes for foreign keys that currently lack one.
-- This reduces lookup and parent-row delete/update costs across chat, calls, groups, and stories.
do $$
declare
  fk record;
  cols text[];
  index_name text;
  column_sql text;
begin
  for fk in
    select c.conname, n.nspname as schema_name, t.relname as table_name,
           t.oid as table_oid, c.conkey
    from pg_constraint c
    join pg_class t on t.oid = c.conrelid
    join pg_namespace n on n.oid = t.relnamespace
    where c.contype = 'f'
      and n.nspname = 'public'
      and not exists (
        select 1
        from pg_index i
        where i.indrelid = c.conrelid
          and i.indisvalid
          and i.indisready
          and i.indpred is null
          and (
            select array_agg(x.attnum::smallint order by x.ordinality)
            from unnest(i.indkey::smallint[]) with ordinality x(attnum, ordinality)
            where x.ordinality <= cardinality(c.conkey)
          ) = c.conkey
      )
  loop
    select array_agg(a.attname order by k.ordinality)
      into cols
    from unnest(fk.conkey) with ordinality k(attnum, ordinality)
    join pg_attribute a on a.attrelid = fk.table_oid and a.attnum = k.attnum;

    if cols is null then
      continue;
    end if;

    index_name := 'idx_' || left(fk.table_name, 24) || '_' ||
      left(array_to_string(cols, '_'), 20) || '_' || substr(md5(fk.conname), 1, 6);

    select string_agg(format('%I', col), ', ')
      into column_sql
    from unnest(cols) as col;

    execute format(
      'create index if not exists %I on %I.%I (%s)',
      index_name, fk.schema_name, fk.table_name, column_sql
    );
  end loop;
end
$$;
