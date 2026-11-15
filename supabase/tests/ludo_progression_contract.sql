-- Run against a disposable local Supabase database after applying the Ludo progression migration.
-- This test is transactional and rolls back all fixture rows.
begin;

do $$
declare
  v_user uuid := gen_random_uuid();
  v_match_1 uuid := gen_random_uuid();
  v_match_2 uuid := gen_random_uuid();
  v_match_3 uuid := gen_random_uuid();
  v_match_4 uuid := gen_random_uuid();
  v_abandoned uuid := gen_random_uuid();
  v_milestone_user uuid := gen_random_uuid();
  v_milestone_match uuid := gen_random_uuid();
  v_first jsonb;
  v_duplicate jsonb;
  v_abandon_result jsonb;
  v_first_grant boolean;
  v_duplicate_grant boolean;
  v_daily integer;
  v_total bigint;
  v_coins bigint;
  v_ledger_count integer;
  v_reward_count integer;
  v_milestone_level integer;
  v_milestone_coins bigint;
begin
  insert into auth.users (
    id, aud, role, email, encrypted_password, email_confirmed_at,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at
  ) values (
    v_user, 'authenticated', 'authenticated',
    v_user::text || '@example.invalid', '', now(), '{}'::jsonb, '{}'::jsonb, now(), now()
  );

  -- Inventory grant must be idempotent under retries.
  v_first_grant := ludo_private.grant_cosmetic_item(v_user, 'fox_01', 'starter', 'contract-test');
  v_duplicate_grant := ludo_private.grant_cosmetic_item(v_user, 'fox_01', 'starter', 'contract-test');
  if not v_first_grant or v_duplicate_grant then
    raise exception 'inventory_grant_not_idempotent';
  end if;
  if (select count(*) from public.ludo_inventory where user_id=v_user and item_id='fox_01') <> 1 then
    raise exception 'inventory_duplicate_row_detected';
  end if;

  -- Completed match facts are server-side inputs. One first-place result yields 200 XP.
  insert into public.ludo_match_results(match_id,user_id,placement,completed,completed_at)
  values (v_match_1,v_user,1,true,now());
  v_first := ludo_private.grant_ludo_match_xp(v_match_1,v_user);
  v_duplicate := ludo_private.grant_ludo_match_xp(v_match_1,v_user);
  if (v_first->>'awardedXp')::integer <> 200 or v_first <> v_duplicate then
    raise exception 'match_xp_retry_not_idempotent';
  end if;

  -- Further completed matches hit the 500 XP UTC daily cap exactly.
  insert into public.ludo_match_results(match_id,user_id,placement,completed,completed_at)
  values
    (v_match_2,v_user,1,true,now()),
    (v_match_3,v_user,1,true,now()),
    (v_match_4,v_user,1,true,now());
  perform ludo_private.grant_ludo_match_xp(v_match_2,v_user);
  perform ludo_private.grant_ludo_match_xp(v_match_3,v_user);
  perform ludo_private.grant_ludo_match_xp(v_match_4,v_user);

  select daily_xp,total_xp,coins into v_daily,v_total,v_coins
    from public.ludo_player_profiles where user_id=v_user;
  if v_daily <> 500 or v_total <> 500 or v_coins <> 50 then
    raise exception 'daily_xp_or_reward_idempotency_failed: daily %, total %, coins %',v_daily,v_total,v_coins;
  end if;

  select count(*) into v_ledger_count from public.ludo_xp_ledger where user_id=v_user;
  if v_ledger_count <> 4 then
    raise exception 'xp_ledger_retry_created_duplicate_rows';
  end if;

  select count(*) into v_reward_count from public.ludo_player_level_rewards where user_id=v_user;
  if v_reward_count <> 2 then
    raise exception 'level_reward_unlock_count_unexpected: %',v_reward_count;
  end if;

  if not exists (select 1 from public.ludo_players where user_id=v_user) or
     not exists (select 1 from public.ludo_player_loadouts
       where user_id=v_user and preset_slot=1 and character_id='fox_01') then
    raise exception 'starter_player_identity_or_loadout_missing';
  end if;

  -- Abandoned matches must never grant XP.
  insert into public.ludo_match_results(match_id,user_id,placement,completed,abandoned)
  values (v_abandoned,v_user,1,false,true);
  v_abandon_result := ludo_private.grant_ludo_match_xp(v_abandoned,v_user);
  if (v_abandon_result->>'awardedXp')::integer <> 0 then
    raise exception 'abandoned_match_awarded_xp';
  end if;

  -- A tenth-level milestone grants its title and special coin reward exactly once.
  insert into auth.users (
    id, aud, role, email, encrypted_password, email_confirmed_at,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at
  ) values (
    v_milestone_user, 'authenticated', 'authenticated',
    v_milestone_user::text || '@example.invalid', '', now(), '{}'::jsonb, '{}'::jsonb, now(), now()
  );
  insert into public.ludo_players(user_id) values (v_milestone_user);
  insert into public.ludo_player_profiles(user_id,level,xp_into_level)
    values (v_milestone_user,9,ludo_private.ludo_xp_required(9)-200);
  insert into public.ludo_match_results(match_id,user_id,placement,completed,completed_at)
    values (v_milestone_match,v_milestone_user,1,true,now());
  perform ludo_private.grant_ludo_match_xp(v_milestone_match,v_milestone_user);
  select level,coins into v_milestone_level,v_milestone_coins
    from public.ludo_player_profiles where user_id=v_milestone_user;
  if v_milestone_level <> 10 or v_milestone_coins <> 250 or
     not exists (select 1 from public.ludo_player_profiles
       where user_id=v_milestone_user and 'title_level_10'=any(unlocked_titles)) then
    raise exception 'tenth_level_milestone_reward_failed';
  end if;

  if has_function_privilege('authenticated','ludo_private.grant_ludo_match_xp(uuid,uuid)','EXECUTE') then
    raise exception 'authenticated_can_execute_internal_xp_grant';
  end if;
  if has_column_privilege('authenticated','public.ludo_player_profiles','total_xp','UPDATE') then
    raise exception 'client_can_update_total_xp';
  end if;
end;
$$;

rollback;
