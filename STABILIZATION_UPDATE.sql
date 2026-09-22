-- Only baseline 9046b212 or this patch. Back up first; never run clean-install on existing data.
begin;

do $preflight$
begin
  if to_regclass('realtime.messages') is null or to_regprocedure('realtime.send(jsonb,text,text,boolean)') is null then
    raise exception 'Supabase Realtime 준비가 완료되지 않았습니다. setup-helper의 Realtime 준비 확인 SQL을 실행하세요. 누락 시 Dashboard → Realtime → Inspector에서 임시 채널에 Listen하여 Listening 상태를 확인한 뒤 다시 진단하세요. 계속 누락되면 설치를 중단하세요. 관리 객체를 직접 만들거나 권한을 완화하지 마세요.';
  end if;
end;
$preflight$;

lock table public.jpp1e_rooms in share row exclusive mode;
do $guard$
declare v_body text;
begin
  select prosrc into v_body from pg_proc where oid=to_regprocedure('jpp1e_private.ensure_reconnect_code(uuid,text,text)');
  if v_body is null or md5(replace(v_body,chr(13),'')) not in ('b0d785f89ecad98b4473c39efdc94bd9','b0d785f89ecad98b4473c39efdc94bd9') then raise exception 'Unsupported function: jpp1e_private.ensure_reconnect_code(uuid,text,text)'; end if;
  select prosrc into v_body from pg_proc where oid=to_regprocedure('jpp1e_private.lock_credential(text,boolean)');
  if v_body is null or md5(replace(v_body,chr(13),'')) not in ('75e0602de2ac8868fe361bfd93673ba9','75e0602de2ac8868fe361bfd93673ba9') then raise exception 'Unsupported function: jpp1e_private.lock_credential(text,boolean)'; end if;
  select prosrc into v_body from pg_proc where oid=to_regprocedure('public.jpp1e_create_room(text,text,text,jsonb)');
  if v_body is null or md5(replace(v_body,chr(13),'')) not in ('41f94044b5a5a425eac9a4a2ff969016','41f94044b5a5a425eac9a4a2ff969016') then raise exception 'Unsupported function: public.jpp1e_create_room(text,text,text,jsonb)'; end if;
  select prosrc into v_body from pg_proc where oid=to_regprocedure('public.jpp1e_load_room(text,text)');
  if v_body is null or md5(replace(v_body,chr(13),'')) not in ('6783b49d18c2bb4eb239ca44b32f9669','6783b49d18c2bb4eb239ca44b32f9669') then raise exception 'Unsupported function: public.jpp1e_load_room(text,text)'; end if;
  select prosrc into v_body from pg_proc where oid=to_regprocedure('public.jpp1e_save_room(text,text,text,text,jsonb)');
  if v_body is null or md5(replace(v_body,chr(13),'')) not in ('4e1ce0c772e19b3d7b8beab9a3fe911a','4e1ce0c772e19b3d7b8beab9a3fe911a') then raise exception 'Unsupported function: public.jpp1e_save_room(text,text,text,text,jsonb)'; end if;
  select prosrc into v_body from pg_proc where oid=to_regprocedure('public.jpp1e_save_room(text,text,text,text,jsonb,jsonb)');
  if v_body is null or md5(replace(v_body,chr(13),'')) not in ('4b4e080906b08b3a6c10270defa8da71','1a955b1529866be7d04e0a43df10785d') then raise exception 'Unsupported function: public.jpp1e_save_room(text,text,text,text,jsonb,jsonb)'; end if;
  select prosrc into v_body from pg_proc where oid=to_regprocedure('public.jpp1e_delete_room(text,text)');
  if v_body is null or md5(replace(v_body,chr(13),'')) not in ('f46cef6b38ebc238adf62666222ed850','f46cef6b38ebc238adf62666222ed850') then raise exception 'Unsupported function: public.jpp1e_delete_room(text,text)'; end if;
  select prosrc into v_body from pg_proc where oid=to_regprocedure('public.jpp1e_filter_player_state(jsonb,text)');
  if v_body is null or md5(replace(v_body,chr(13),'')) not in ('3285f807952d87023b30e23f04a73994','1d3630c8b28cf4ca31a2c30582f1f805','d7aaf6c2a564b651881ed6ef72b43428') then raise exception 'Unsupported function: public.jpp1e_filter_player_state(jsonb,text)'; end if;
  select prosrc into v_body from pg_proc where oid=to_regprocedure('public.jpp1e_create_player_invite(text,text,text,text)');
  if v_body is null or md5(replace(v_body,chr(13),'')) not in ('08408f031e24700ddeed27e9ebb4d8cd','08408f031e24700ddeed27e9ebb4d8cd') then raise exception 'Unsupported function: public.jpp1e_create_player_invite(text,text,text,text)'; end if;
  select prosrc into v_body from pg_proc where oid=to_regprocedure('public.jpp1e_join_player(text)');
  if v_body is null or md5(replace(v_body,chr(13),'')) not in ('63ac62da586e53649842f035def2a4c2','63ac62da586e53649842f035def2a4c2') then raise exception 'Unsupported function: public.jpp1e_join_player(text)'; end if;
  select prosrc into v_body from pg_proc where oid=to_regprocedure('public.jpp1e_join_player_v3(text)');
  if v_body is null or md5(replace(v_body,chr(13),'')) not in ('2602b1a3f56d44c473baf601248341d6','2602b1a3f56d44c473baf601248341d6') then raise exception 'Unsupported function: public.jpp1e_join_player_v3(text)'; end if;
  select prosrc into v_body from pg_proc where oid=to_regprocedure('public.jpp1e_list_player_invites(text,text)');
  if v_body is null or md5(replace(v_body,chr(13),'')) not in ('c941b2c9840a82e727a2bc477b71ee15','c941b2c9840a82e727a2bc477b71ee15') then raise exception 'Unsupported function: public.jpp1e_list_player_invites(text,text)'; end if;
  select prosrc into v_body from pg_proc where oid=to_regprocedure('public.jpp1e_list_player_invites_v3(text,text)');
  if v_body is null or md5(replace(v_body,chr(13),'')) not in ('04ac2d7d94bab4ff8e0e7135a35525f5','04ac2d7d94bab4ff8e0e7135a35525f5') then raise exception 'Unsupported function: public.jpp1e_list_player_invites_v3(text,text)'; end if;
  select prosrc into v_body from pg_proc where oid=to_regprocedure('public.jpp1e_list_player_invites_v4(text,text)');
  if v_body is null or md5(replace(v_body,chr(13),'')) not in ('a91bc403ee5b3c87f92a58bc7b4e4b82','a91bc403ee5b3c87f92a58bc7b4e4b82') then raise exception 'Unsupported function: public.jpp1e_list_player_invites_v4(text,text)'; end if;
  select prosrc into v_body from pg_proc where oid=to_regprocedure('public.jpp1e_list_player_reconnects(text,text)');
  if v_body is null or md5(replace(v_body,chr(13),'')) not in ('3c251f8360345b7864dcbc7488eab97e','3c251f8360345b7864dcbc7488eab97e') then raise exception 'Unsupported function: public.jpp1e_list_player_reconnects(text,text)'; end if;
  select prosrc into v_body from pg_proc where oid=to_regprocedure('public.jpp1e_get_reconnect_code_by_credential(text)');
  if v_body is null or md5(replace(v_body,chr(13),'')) not in ('195a437b1f341b3854cf626876bc4df7','195a437b1f341b3854cf626876bc4df7') then raise exception 'Unsupported function: public.jpp1e_get_reconnect_code_by_credential(text)'; end if;
  select prosrc into v_body from pg_proc where oid=to_regprocedure('public.jpp1e_reissue_player_reconnect(text,text,text)');
  if v_body is null or md5(replace(v_body,chr(13),'')) not in ('1edbbe8be4abb3d481f01ca5b9900a1f','1edbbe8be4abb3d481f01ca5b9900a1f') then raise exception 'Unsupported function: public.jpp1e_reissue_player_reconnect(text,text,text)'; end if;
  select prosrc into v_body from pg_proc where oid=to_regprocedure('public.jpp1e_revoke_player_invite(text,text,text)');
  if v_body is null or md5(replace(v_body,chr(13),'')) not in ('c021b56b2b1ebd96f3db4c16d62e7e5d','c021b56b2b1ebd96f3db4c16d62e7e5d') then raise exception 'Unsupported function: public.jpp1e_revoke_player_invite(text,text,text)'; end if;
  select prosrc into v_body from pg_proc where oid=to_regprocedure('public.jpp1e_revoke_player_access(text,text,text)');
  if v_body is null or md5(replace(v_body,chr(13),'')) not in ('f7fbbd5daef2dddf93701fdcf02bd9c5','f7fbbd5daef2dddf93701fdcf02bd9c5') then raise exception 'Unsupported function: public.jpp1e_revoke_player_access(text,text,text)'; end if;
  select prosrc into v_body from pg_proc where oid=to_regprocedure('public.jpp1e_player_send_message(text,text,text,timestamptz)');
  if v_body is null or md5(replace(v_body,chr(13),'')) not in ('be4cb9082c12ce76fd19e801eb10e4d1','be4cb9082c12ce76fd19e801eb10e4d1') then raise exception 'Unsupported function: public.jpp1e_player_send_message(text,text,text,timestamptz)'; end if;
  select prosrc into v_body from pg_proc where oid=to_regprocedure('public.jpp1e_player_edit_message(text,text,text)');
  if v_body is null or md5(replace(v_body,chr(13),'')) not in ('5a494e5bdc4d609282c0111717dd9bc6','5a494e5bdc4d609282c0111717dd9bc6') then raise exception 'Unsupported function: public.jpp1e_player_edit_message(text,text,text)'; end if;
  select prosrc into v_body from pg_proc where oid=to_regprocedure('public.jpp1e_player_move_token(text,text,numeric,numeric)');
  if v_body is null or md5(replace(v_body,chr(13),'')) not in ('e50aeeec69b8635674a18a947ea0674d','e50aeeec69b8635674a18a947ea0674d') then raise exception 'Unsupported function: public.jpp1e_player_move_token(text,text,numeric,numeric)'; end if;
  select prosrc into v_body from pg_proc where oid=to_regprocedure('public.jpp1e_player_update_annotations(text,jsonb)');
  if v_body is null or md5(replace(v_body,chr(13),'')) not in ('5feb7b4e3bf84f8d769e5c254f78289e','5feb7b4e3bf84f8d769e5c254f78289e') then raise exception 'Unsupported function: public.jpp1e_player_update_annotations(text,jsonb)'; end if;
  select prosrc into v_body from pg_proc where oid=to_regprocedure('public.jpp1e_player_update_character(text,jsonb,jsonb)');
  if v_body is null or md5(replace(v_body,chr(13),'')) not in ('523915e3921c543987d67156a402589f','5e3680e9e611b05124783da400218fd0') then raise exception 'Unsupported function: public.jpp1e_player_update_character(text,jsonb,jsonb)'; end if;
  select prosrc into v_body from pg_proc where oid=to_regprocedure('public.jpp1e_player_ack_handout(text,text)');
  if v_body is null or md5(replace(v_body,chr(13),'')) not in ('89509edce21564aaa7086ea463f72796','89509edce21564aaa7086ea463f72796') then raise exception 'Unsupported function: public.jpp1e_player_ack_handout(text,text)'; end if;
  select prosrc into v_body from pg_proc where oid=to_regprocedure('public.jpp1e_realtime_topic(text,text)');
  if v_body is null or md5(replace(v_body,chr(13),'')) not in ('6627b62397b84290f70a720bf53caaef','6627b62397b84290f70a720bf53caaef') then raise exception 'Unsupported function: public.jpp1e_realtime_topic(text,text)'; end if;
  select prosrc into v_body from pg_proc where oid=to_regprocedure('public.jpp1e_realtime_bind_gm(text,text)');
  if v_body is null or md5(replace(v_body,chr(13),'')) not in ('c9188167681859d802934fbedd12a328','c9188167681859d802934fbedd12a328') then raise exception 'Unsupported function: public.jpp1e_realtime_bind_gm(text,text)'; end if;
  select prosrc into v_body from pg_proc where oid=to_regprocedure('public.jpp1e_realtime_bind_player(text)');
  if v_body is null or md5(replace(v_body,chr(13),'')) not in ('3c77d3755f61ad7464d697d49a4c7fbf','3c77d3755f61ad7464d697d49a4c7fbf') then raise exception 'Unsupported function: public.jpp1e_realtime_bind_player(text)'; end if;
  select prosrc into v_body from pg_proc where oid=to_regprocedure('public.jpp1e_realtime_authorized()');
  if v_body is null or md5(replace(v_body,chr(13),'')) not in ('188273371927c03cbce333af1f26a428','2945f1e7f7d3f20c5b666d371c963d8c') then raise exception 'Unsupported function: public.jpp1e_realtime_authorized()'; end if;
  select prosrc into v_body from pg_proc where oid=to_regprocedure('public.jpp1e_push_manage_subscription(text,text,text,text,jsonb,boolean,text[])');
  if v_body is null or md5(replace(v_body,chr(13),'')) not in ('27df4142b2608bafbdd4b3a902b86edd','27df4142b2608bafbdd4b3a902b86edd') then raise exception 'Unsupported function: public.jpp1e_push_manage_subscription(text,text,text,text,jsonb,boolean,text[])'; end if;
  select prosrc into v_body from pg_proc where oid=to_regprocedure('jpp1e_private.redact_maps(jsonb,text[])');
  if v_body is not null and md5(replace(v_body,chr(13),'')) not in ('c0286694e78e7cdfc23aac6425814f28','e41545ecfb65a0fc0c81fc5a8f9461ed') then raise exception 'Unsupported helper: jpp1e_private.redact_maps(jsonb,text[])'; end if;
  select prosrc into v_body from pg_proc where oid=to_regprocedure('jpp1e_private.signal_room_state()');
  if v_body is not null and md5(replace(v_body,chr(13),'')) <> 'd3eac2078b65ff51e4508dcb2fa6fa90' then raise exception 'Unsupported helper: jpp1e_private.signal_room_state()'; end if;
  if exists(select 1 from pg_trigger where tgrelid='public.jpp1e_rooms'::regclass and tgname='jpp1e_state_changed' and (tgfoid is distinct from to_regprocedure('jpp1e_private.signal_room_state()') or tgtype<>17)) then raise exception 'Unsupported state trigger'; end if;
end;
$guard$;

-- Remove hidden references recursively, including duplicated token/message references.
create or replace function jpp1e_private.redact_maps(p_value jsonb, p_refs text[])
returns jsonb language plpgsql immutable set search_path = pg_catalog
as $function$
declare v_result jsonb; v_key text; v_item jsonb; v_text text; v_ref text;
begin
  if jsonb_typeof(p_value)='object' then
    v_result:='{}'::jsonb;
    for v_key,v_item in select key,value from jsonb_each(p_value) loop
      v_result:=v_result||jsonb_build_object(v_key,jpp1e_private.redact_maps(v_item,p_refs));
    end loop;
    return v_result;
  elsif jsonb_typeof(p_value)='array' then
    v_result:='[]'::jsonb;
    for v_item in select value from jsonb_array_elements(p_value) loop
      v_result:=v_result||jsonb_build_array(jpp1e_private.redact_maps(v_item,p_refs));
    end loop;
    return v_result;
  elsif jsonb_typeof(p_value)='string' then
    v_text:=p_value#>>'{}';
    foreach v_ref in array p_refs loop
      if coalesce(v_ref,'')<>'' and position(v_ref in v_text)>0 then return 'null'::jsonb; end if;
    end loop;
    -- Old map paths duplicated outside layout must not leak either.
    if v_text ~ 'rooms/[^/]+/maps/' then return 'null'::jsonb; end if;
  end if;
  return p_value;
end;
$function$;
revoke all on function jpp1e_private.redact_maps(jsonb,text[]) from public,anon,authenticated,service_role;

create or replace function jpp1e_private.signal_room_state()
returns trigger language plpgsql security definer set search_path = pg_catalog
as $function$
begin
  perform realtime.send(jsonb_build_object('kind','signal','refresh',true),
    'state_changed','jpp1e:'||new.room_code||':'||new.realtime_secret,true);
  return new;
end;
$function$;
revoke all on function jpp1e_private.signal_room_state() from public,anon,authenticated,service_role;
drop trigger if exists jpp1e_state_changed on public.jpp1e_rooms;
create trigger jpp1e_state_changed after update of state,name,rule on public.jpp1e_rooms
for each row when (old.state is distinct from new.state or old.name is distinct from new.name or old.rule is distinct from new.rule)
execute function jpp1e_private.signal_room_state();

create or replace function public.jpp1e_save_room(
  p_room_code text,
  p_owner_secret text,
  p_name text,
  p_rule text,
  p_state jsonb,
  p_expected jsonb
)
returns boolean
language plpgsql
security definer
set search_path to 'public', 'extensions', 'realtime'
as $function$
declare
  v_topic text;
begin
  if p_expected is null
     or jsonb_typeof(p_expected) is distinct from 'object'
     or not (p_expected ?& array['name','rule','state'])
     or jsonb_typeof(p_expected->'state') is distinct from 'object'
     or jsonb_typeof(p_state) is distinct from 'object' then
    raise exception using errcode = '22023', message = 'Invalid expected room snapshot';
  end if;

  -- PostgreSQL rechecks these predicates after waiting for a concurrent writer.
  -- The comparison and replacement must remain in this one UPDATE.
  update public.jpp1e_rooms r
     set name = coalesce(nullif(trim(p_name), ''), r.name),
         rule = coalesce(nullif(trim(p_rule), ''), r.rule),
         state = p_state,
         updated_at = now()
   where r.room_code = upper(trim(p_room_code))
     and crypt(p_owner_secret, r.owner_secret_hash) = r.owner_secret_hash
     and r.state = p_expected->'state'
     and to_jsonb(r.name) = p_expected->'name'
     and to_jsonb(r.rule) = p_expected->'rule'
  returning 'jpp1e:' || r.room_code || ':' || r.realtime_secret into v_topic;

  if v_topic is null then
    -- Never return GM state on the conflict/error path.
    if exists (
      select 1 from public.jpp1e_rooms r
       where r.room_code = upper(trim(p_room_code))
         and crypt(p_owner_secret, r.owner_secret_hash) = r.owner_secret_hash
    ) then
      raise exception using errcode = 'PT409', message = 'Room save conflict';
    end if;
    return false;
  end if;

  -- State-change trigger emits the signal for GM and PL writes.
  return true;
end;
$function$;

create or replace function public.jpp1e_filter_player_state(
  p_state jsonb,
  p_character_id text
)
returns jsonb
language plpgsql
stable security definer
set search_path to 'public', 'extensions'
as $function$
declare
  v_chars jsonb := '[]'::jsonb;
  v_handouts jsonb := '[]'::jsonb;
  v_history jsonb := '[]'::jsonb;
  v_item jsonb;
  v_snapshot jsonb;
  v_public_char jsonb;
  v_has_history boolean;
begin
  if p_state#>'{layout,mapVisible}' = 'false'::jsonb then
    p_state := jpp1e_private.redact_maps(p_state,array[
      p_state#>>'{layout,boardImage}',
      replace(p_state#>>'{layout,boardImage}','storage:','')]);
    p_state:=jsonb_set(p_state,'{layout}',(p_state->'layout') - 'boardImage' - 'boardFileName');
  end if;
  for v_item in select value from jsonb_array_elements(coalesce(p_state->'characters','[]'::jsonb)) loop
    if v_item->>'id' = p_character_id then v_chars := v_chars || jsonb_build_array(v_item);
    else
      v_public_char := jsonb_strip_nulls(jsonb_build_object('id',v_item->'id','name',v_item->'name','image',v_item->'image','shape',v_item->'shape'));
      v_chars := v_chars || jsonb_build_array(v_public_char);
    end if;
  end loop;

  for v_item in select value from jsonb_array_elements(coalesce(p_state->'handoutHistory','[]'::jsonb)) loop
    if coalesce(v_item->'recipients','[]'::jsonb) ? p_character_id then
      v_snapshot := v_item - 'recipients';
      v_history := v_history || jsonb_build_array(v_snapshot);
      -- historyOnly keeps the item out of the player's archive/incoming UI, while
      -- allowing the existing private-asset signer to verify its image path.
      v_handouts := v_handouts || jsonb_build_array(v_snapshot || jsonb_build_object('historyOnly',true));
    end if;
  end loop;

  for v_item in select value from jsonb_array_elements(coalesce(p_state->'handouts','[]'::jsonb)) loop
    if (coalesce(v_item->'activeTo','[]'::jsonb) ? p_character_id)
       or (coalesce((v_item->>'persist')::boolean,false) and (coalesce(v_item->'revealedTo','[]'::jsonb) ? p_character_id)) then
      v_handouts := v_handouts || jsonb_build_array(v_item - 'audience' - 'revealedTo');
    end if;

    if not coalesce((v_item->>'persist')::boolean,false)
       and (coalesce(v_item->'revealedTo','[]'::jsonb) ? p_character_id) then
      select exists(select 1 from jsonb_array_elements(coalesce(p_state->'handoutHistory','[]'::jsonb)) h where h->>'handoutId'=v_item->>'id' and coalesce(h->'recipients','[]'::jsonb) ? p_character_id) into v_has_history;
      if not v_has_history then
        v_snapshot := jsonb_strip_nulls(jsonb_build_object('id','legacy-'||coalesce(v_item->>'id','handout'),'handoutId',v_item->'id','title',v_item->'title','body',v_item->'body','image',v_item->'image','persist',false,'sentAt',v_item->'sentAt','createdAt',v_item->'createdAt'));
        v_history := v_history || jsonb_build_array(v_snapshot);
        v_handouts := v_handouts || jsonb_build_array(v_snapshot || jsonb_build_object('historyOnly',true));
      end if;
    end if;
  end loop;

  return jsonb_build_object('messages',coalesce(p_state->'messages','[]'::jsonb),'tokens',coalesce(p_state->'tokens','[]'::jsonb),'bgm',coalesce(p_state->'bgm','[]'::jsonb),'bgmState',coalesce(p_state->'bgmState','{}'::jsonb),'characters',v_chars,'layout',coalesce(p_state->'layout','{}'::jsonb),'handouts',v_handouts,'handoutHistory',v_history);
end;
$function$;

create or replace function public.jpp1e_player_update_character(
  p_invite_code text,
  p_sheet jsonb,
  p_skills jsonb
)
returns boolean
language plpgsql
security definer
set search_path to 'public', 'extensions'
as $function$
declare
  v_code_id text;
  v_secret text;
  v_invite public.jpp1e_room_invites%rowtype;
  v_room public.jpp1e_rooms%rowtype;
  v_chars jsonb;
  v_new_chars jsonb := '[]'::jsonb;
  v_item jsonb;
  v_clean_sheet jsonb;
  v_skill jsonb;
  v_new_name text;
  v_new_image text;
  v_old_image text;
  v_messages jsonb;
  v_new_messages jsonb := '[]'::jsonb;
  v_message jsonb;
  v_changed boolean := false;
begin
  v_invite := jpp1e_private.lock_credential(p_invite_code,false);

  if jsonb_typeof(p_sheet) is distinct from 'object'
     or jsonb_typeof(p_skills) is distinct from 'array' then
    raise exception using errcode = '22023', message = 'invalid character data structure';
  end if;
  for v_skill in select value from jsonb_array_elements(p_skills)
  loop
    if jsonb_typeof(v_skill) is distinct from 'array' then
      raise exception using errcode = '22023', message = 'invalid skill structure';
    end if;
    if jsonb_array_length(v_skill) <> 3 then
      raise exception using errcode = '22023', message = 'invalid skill structure';
    end if;
    if jsonb_typeof(v_skill->0) is distinct from 'string'
       or jsonb_typeof(v_skill->1) is distinct from 'number'
       or jsonb_typeof(v_skill->2) is distinct from 'boolean' then
      raise exception using errcode = '22023', message = 'invalid skill field type';
    end if;
    if char_length(btrim(v_skill->>0)) = 0 or char_length(v_skill->>0) > 120
       or (v_skill->>1)::numeric < 0 or (v_skill->>1)::numeric > 100 then
      raise exception using errcode = '22023', message = 'invalid skill name or value range';
    end if;
  end loop;
  v_clean_sheet := p_sheet - '__portrait';

  select * into v_room
  from public.jpp1e_rooms r
  where r.id = v_invite.room_id
  for update;

  v_chars := coalesce(v_room.state->'characters', '[]'::jsonb);
  v_new_image := nullif(trim(coalesce(p_sheet->>'__portrait', '')), '');

  for v_item in select value from jsonb_array_elements(v_chars)
  loop
    if v_item->>'id' = v_invite.character_id then
      v_old_image := nullif(v_item->>'image','');
      if p_sheet ? '__portrait' and jsonb_typeof(p_sheet->'__portrait') not in ('string','null') then
        raise exception using errcode='22023',message='Invalid portrait type';
      end if;
      if v_new_image is not null then
        if v_new_image like 'storage:%' then
          if v_new_image !~ '^storage:rooms/[A-Za-z0-9_-]+/characters/[A-Za-z0-9_-]+/[A-Za-z0-9_-]+[.][A-Za-z0-9]+$'
            or split_part(v_new_image,'/',2) <> v_room.room_code
            or split_part(v_new_image,'/',4) <> left(regexp_replace(btrim(v_invite.character_id),'[^a-zA-Z0-9_-]','_','g'),120)
            or not exists(select 1 from storage.objects o where o.bucket_id='jpp1e-assets' and o.name=substr(v_new_image,9)) then
            raise exception using errcode='42501',message='Invalid portrait reference';
          end if;
        elsif v_new_image is distinct from v_old_image or not (
          v_new_image ~ '^https?://[^[:space:]<>"\\]+$'
          or v_new_image ~ '^data:image/(png|jpeg|gif|webp|avif);base64,[A-Za-z0-9+/]+={0,2}$') then
          raise exception using errcode='42501',message='Invalid portrait reference';
        end if;
      end if;
      v_item := jsonb_set(v_item, '{sheet}', v_clean_sheet, true);
      v_item := jsonb_set(v_item, '{skills}', coalesce(p_skills, '[]'::jsonb), true);
      v_new_name := nullif(trim(coalesce(v_clean_sheet->>'name', '')), '');
      if v_new_name is not null then
        v_item := jsonb_set(v_item, '{name}', to_jsonb(v_new_name), true);
      end if;
      if v_new_image is not null then
        v_item := jsonb_set(v_item, '{image}', to_jsonb(v_new_image), true);
      end if;
      v_changed := true;
    end if;
    v_new_chars := v_new_chars || jsonb_build_array(v_item);
  end loop;

  if not v_changed then
    raise exception 'character not found';
  end if;

  v_messages := coalesce(v_room.state->'messages','[]'::jsonb);
  for v_message in select value from jsonb_array_elements(v_messages)
  loop
    if not (v_message ? 'seal')
       and coalesce(v_message->>'kind','chat') = 'chat'
       and coalesce(v_message->>'gmProxy','false') <> 'true'
       and (
         v_message->>'characterId' = v_invite.character_id
         or (v_message->>'characterId' is null and v_message->>'author' = v_invite.character_name)
       ) then
      v_message := jsonb_set(v_message,'{seal}',coalesce(to_jsonb(v_old_image),'null'::jsonb),true);
    end if;
    v_new_messages := v_new_messages || jsonb_build_array(v_message);
  end loop;

  update public.jpp1e_rooms
  set state = jsonb_set(
        jsonb_set(coalesce(v_room.state, '{}'::jsonb), '{characters}', v_new_chars, true),
        '{messages}', v_new_messages, true
      ),
      updated_at = now()
  where id = v_room.id;

  if v_new_name is not null then
    update public.jpp1e_room_invites
    set character_name = v_new_name
    where id = v_invite.id;
  end if;

  return true;
end;
$function$;

create or replace function public.jpp1e_realtime_authorized()
returns boolean
language sql
stable security definer
set search_path to 'public', 'extensions', 'pg_temp'
as $function$
select exists (
  select 1 from public.jpp1e_realtime_memberships m join public.jpp1e_rooms r on r.id=m.room_id
  where m.auth_user_id=auth.uid() and ('jpp1e:'||r.room_code||':'||r.realtime_secret)=nullif(current_setting('realtime.topic', true), '')
    and ( (m.role='gm' and m.invite_id is null) or
      (m.role='player' and exists(select 1 from public.jpp1e_room_invites i
        where i.id=m.invite_id and i.room_id=m.room_id and i.kind='reconnect' and i.active=true and i.revoked_at is null
          and exists(select 1 from jsonb_array_elements(coalesce(r.state->'characters','[]'::jsonb)) c where c->>'id'=i.character_id))) )
);
$function$;
notify pgrst, 'reload schema';
commit;
