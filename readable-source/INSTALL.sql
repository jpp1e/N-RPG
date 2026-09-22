-- 누알피지 — Supabase clean-install SQL
-- 대상: 앱 객체가 없는 새 전용 Supabase 프로젝트
-- 실행 위치: Supabase Dashboard > SQL Editor
-- 주의: 이 파일은 기존 누알피지 DB 업그레이드용이 아닙니다.
-- 기준: 공개 배포용 clean-install 경로.

begin;

-- -----------------------------------------------------------------------------
-- 0. Clean-install guard
-- -----------------------------------------------------------------------------
do $$
begin
  if to_regclass('public.jpp1e_rooms') is not null
     or to_regclass('public.jpp1e_room_invites') is not null
     or to_regclass('public.jpp1e_push_subscriptions') is not null
     or to_regclass('public.jpp1e_realtime_memberships') is not null
     or to_regnamespace('jpp1e_private') is not null
     or exists (select 1 from storage.buckets where id = 'jpp1e-assets')
     or exists (
       select 1
       from pg_proc p
       join pg_namespace n on n.oid = p.pronamespace
       where n.nspname = 'public' and p.proname like 'jpp1e_%'
     )
  then
    raise exception '누알피지 설치 항목이 이미 존재합니다. 이 SQL은 처음 설치할 때 한 번만 실행하세요.';
  end if;
end;
$$;

-- Supabase normally provides pgcrypto in extensions already.
create extension if not exists pgcrypto with schema extensions;


do $preflight$
begin
  if to_regclass('realtime.messages') is null or to_regprocedure('realtime.send(jsonb,text,text,boolean)') is null then
    raise exception 'Supabase Realtime 준비가 완료되지 않았습니다. setup-helper의 Realtime 준비 확인 SQL을 실행하세요. 누락 시 Dashboard → Realtime → Inspector에서 임시 채널에 Listen하여 Listening 상태를 확인한 뒤 다시 진단하세요. 계속 누락되면 설치를 중단하세요. 관리 객체를 직접 만들거나 권한을 완화하지 마세요.';
  end if;
end;
$preflight$;

create schema jpp1e_private authorization postgres;
revoke all on schema jpp1e_private from public, anon, authenticated, service_role;

-- New postgres-owned functions should not become PUBLIC-executable by default.
alter default privileges for role postgres revoke execute on functions from public;
alter default privileges for role postgres in schema public revoke execute on functions from public;

-- -----------------------------------------------------------------------------
-- 0A. Private image bucket
-- Storage 화면에서 사용자가 따로 만들 필요가 없도록 설치 SQL에서 함께 생성합니다.
-- -----------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('jpp1e-assets', 'jpp1e-assets', false, 10485760, array['image/*']::text[]);

-- -----------------------------------------------------------------------------
-- 1. Core tables
-- -----------------------------------------------------------------------------
create table public.jpp1e_rooms (
  id uuid primary key default extensions.gen_random_uuid(),
  room_code text not null unique,
  name text not null,
  rule text not null default '자유 룰',
  owner_secret_hash text not null,
  state jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  realtime_secret text not null default encode(extensions.gen_random_bytes(24), 'hex')
);

create table public.jpp1e_room_invites (
  id uuid primary key default extensions.gen_random_uuid(),
  room_id uuid not null references public.jpp1e_rooms(id) on delete cascade,
  code_id text not null unique,
  secret_hash text not null,
  character_id text not null,
  character_name text not null,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  kind text not null default 'invite',
  secret_plain text,
  used_at timestamptz,
  updated_at timestamptz not null default now(),
  revoked_at timestamptz
);

create unique index jpp1e_room_invites_reconnect_room_character_key
  on public.jpp1e_room_invites(room_id, character_id)
  where kind = 'reconnect' and active = true;

create table public.jpp1e_push_subscriptions (
  id uuid primary key default extensions.gen_random_uuid(),
  room_id uuid not null references public.jpp1e_rooms(id) on delete cascade,
  invite_id uuid references public.jpp1e_room_invites(id) on delete cascade,
  role text not null check (role = any(array['gm'::text,'player'::text])),
  character_id text,
  character_name text,
  endpoint text not null,
  p256dh text not null,
  auth text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  show_preview boolean not null default false,
  notification_types text[] not null default array['chat'::text],
  constraint jpp1e_push_subscriptions_notification_types_check
    check (
      notification_types <@ array['chat'::text,'desc'::text,'system'::text]
      and cardinality(notification_types) >= 1
    )
);

create index jpp1e_push_subscriptions_room_id_idx
  on public.jpp1e_push_subscriptions(room_id);
create index jpp1e_push_subscriptions_invite_id_idx
  on public.jpp1e_push_subscriptions(invite_id);
create unique index jpp1e_push_subscriptions_room_endpoint_uidx
  on public.jpp1e_push_subscriptions(room_id, endpoint);

create table public.jpp1e_realtime_memberships (
  auth_user_id uuid not null references auth.users(id) on delete cascade,
  room_id uuid not null references public.jpp1e_rooms(id) on delete cascade,
  role text not null check (role = any(array['gm'::text,'player'::text])),
  invite_id uuid references public.jpp1e_room_invites(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (auth_user_id, room_id),
  constraint jpp1e_realtime_memberships_role_invite_check check (
    (role = 'gm' and invite_id is null)
    or (role = 'player' and invite_id is not null)
  )
);

alter table public.jpp1e_rooms enable row level security;
alter table public.jpp1e_room_invites enable row level security;
alter table public.jpp1e_push_subscriptions enable row level security;
alter table public.jpp1e_realtime_memberships enable row level security;

-- Browser roles must never CRUD app tables directly.
revoke all on table public.jpp1e_rooms from anon, authenticated;
revoke all on table public.jpp1e_room_invites from anon, authenticated;
revoke all on table public.jpp1e_push_subscriptions from anon, authenticated;
revoke all on table public.jpp1e_realtime_memberships from anon, authenticated;

grant all on table public.jpp1e_rooms to service_role;
grant all on table public.jpp1e_room_invites to service_role;
grant all on table public.jpp1e_push_subscriptions to service_role;
grant all on table public.jpp1e_realtime_memberships to service_role;

-- -----------------------------------------------------------------------------
-- 2. Private credential helpers
-- -----------------------------------------------------------------------------
create or replace function jpp1e_private.ensure_reconnect_code(
  p_room_id uuid,
  p_character_id text,
  p_character_name text
)
returns text
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_row public.jpp1e_room_invites%rowtype;
  v_code_id text;
  v_secret text;
begin
  -- Serialize all reconnect creation with enrollment/reissue/revoke in this room.
  perform 1 from public.jpp1e_rooms r where r.id=p_room_id for update;
  if not found then raise exception 'room not found'; end if;
  if not exists(select 1 from public.jpp1e_rooms r cross join lateral jsonb_array_elements(coalesce(r.state->'characters','[]'::jsonb)) c where r.id=p_room_id and c->>'id'=p_character_id) then raise exception 'character not found'; end if;
  -- A contradictory active+revoked row must never be returned or resurrected.
  if exists(select 1 from public.jpp1e_room_invites i where i.room_id=p_room_id and i.character_id=p_character_id and i.kind='reconnect' and i.active=true and i.revoked_at is not null) then raise exception 'invalid reconnect state'; end if;
  select * into v_row
  from public.jpp1e_room_invites i
  where i.room_id=p_room_id
    and i.character_id=p_character_id
    and i.kind='reconnect'
    and i.active=true and i.revoked_at is null
  order by i.created_at desc
  limit 1 for update;

  if v_row.id is not null then
    if coalesce(v_row.secret_plain,'')<>'' then
      return v_row.code_id||'.'||v_row.secret_plain;
    end if;
  end if;

  loop
    v_code_id:=upper(substr(replace(gen_random_uuid()::text,'-',''),1,8));
    exit when not exists(select 1 from public.jpp1e_room_invites i where i.code_id=v_code_id);
  end loop;
  v_secret:=encode(extensions.gen_random_bytes(18),'hex');

  if v_row.id is not null then
    -- Filling a legacy missing plaintext changes the bearer secret too.
    delete from public.jpp1e_realtime_memberships where room_id=p_room_id and role='player' and invite_id=v_row.id;
    delete from public.jpp1e_push_subscriptions where room_id=p_room_id and role='player' and invite_id=v_row.id;
    update public.jpp1e_room_invites
    set code_id=v_code_id,
        secret_hash=extensions.crypt(v_secret,extensions.gen_salt('bf')),
        secret_plain=v_secret,
        character_name=coalesce(nullif(trim(p_character_name),''),character_name),
        active=true,
        updated_at=now()
    where id=v_row.id;
  else
    insert into public.jpp1e_room_invites(
      room_id,code_id,secret_hash,secret_plain,character_id,character_name,active,kind,created_at,updated_at
    ) values(
      p_room_id,v_code_id,extensions.crypt(v_secret,extensions.gen_salt('bf')),v_secret,
      p_character_id,coalesce(nullif(trim(p_character_name),''),'플레이어'),true,'reconnect',now(),now()
    );
  end if;

  return v_code_id||'.'||v_secret;
end;
$function$;

create or replace function jpp1e_private.lock_credential(
  p_credential text,
  p_allow_invite boolean default false
)
returns public.jpp1e_room_invites
language plpgsql
security definer
set search_path to 'public', 'extensions', 'pg_temp'
as $function$
declare
  v_room_id uuid;
  v_room public.jpp1e_rooms%rowtype;
  v_i public.jpp1e_room_invites%rowtype;
  v_code text:=upper(split_part(trim(p_credential),'.',1));
  v_secret text:=split_part(trim(p_credential),'.',2);
begin
  if coalesce(v_code,'')='' or coalesce(v_secret,'')='' or array_length(string_to_array(trim(p_credential),'.'),1)<>2 then
    raise exception 'invalid credential' using errcode='42501';
  end if;
  select i.room_id into v_room_id from public.jpp1e_room_invites i where i.code_id=v_code;
  select r.* into v_room from public.jpp1e_rooms r where r.id=v_room_id for update;
  if v_room.id is null then raise exception 'invalid credential' using errcode='42501'; end if;
  select i.* into v_i from public.jpp1e_room_invites i where i.room_id=v_room.id and i.code_id=v_code for update;
  if v_i.id is null or v_i.active is distinct from true or v_i.revoked_at is not null
     or extensions.crypt(v_secret,v_i.secret_hash) is distinct from v_i.secret_hash
     or not (v_i.kind='reconnect' or (coalesce(p_allow_invite,false) and v_i.kind='invite' and v_i.used_at is null))
     or not exists (select 1 from jsonb_array_elements(coalesce(v_room.state->'characters','[]'::jsonb)) c where c->>'id'=v_i.character_id)
  then raise exception 'invalid credential' using errcode='42501'; end if;
  return v_i;
end;
$function$;

revoke all on function jpp1e_private.ensure_reconnect_code(uuid,text,text) from public, anon, authenticated, service_role;
revoke all on function jpp1e_private.lock_credential(text,boolean) from public, anon, authenticated, service_role;

-- -----------------------------------------------------------------------------
-- 3. Room RPCs
-- -----------------------------------------------------------------------------
create or replace function public.jpp1e_create_room(
  p_name text,
  p_rule text,
  p_owner_secret text,
  p_state jsonb
)
returns table(room_id uuid, room_code text)
language plpgsql
security definer
set search_path to 'public', 'extensions'
as $function$
declare
  v_id uuid;
  v_code text;
begin
  if length(coalesce(p_owner_secret, '')) < 20 then
    raise exception 'owner secret too short';
  end if;

  loop
    v_code := upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 10));
    exit when not exists (
      select 1 from public.jpp1e_rooms where jpp1e_rooms.room_code = v_code
    );
  end loop;

  insert into public.jpp1e_rooms(
    name, rule, room_code, owner_secret_hash, state, realtime_secret
  )
  values (
    coalesce(nullif(trim(p_name), ''), '새 세션 방'),
    coalesce(nullif(trim(p_rule), ''), '자유 룰'),
    v_code,
    crypt(p_owner_secret, gen_salt('bf')),
    coalesce(p_state, '{}'::jsonb),
    encode(gen_random_bytes(24), 'hex')
  )
  returning id into v_id;

  return query select v_id, v_code;
end;
$function$;

create or replace function public.jpp1e_load_room(
  p_room_code text,
  p_owner_secret text
)
returns table(
  room_id uuid,
  room_code text,
  name text,
  rule text,
  state jsonb,
  created_at timestamptz,
  updated_at timestamptz
)
language sql
security definer
set search_path to 'public', 'extensions'
as $function$
  select
    r.id,
    r.room_code,
    r.name,
    r.rule,
    r.state,
    r.created_at,
    r.updated_at
  from public.jpp1e_rooms r
  where r.room_code = upper(trim(p_room_code))
    and crypt(p_owner_secret, r.owner_secret_hash) = r.owner_secret_hash
  limit 1;
$function$;

-- Legacy 5-argument save is deliberately blocked. 4C3 uses optimistic-CAS save below.
create or replace function public.jpp1e_save_room(
  p_room_code text,
  p_owner_secret text,
  p_name text,
  p_rule text,
  p_state jsonb
)
returns boolean
language plpgsql
security definer
set search_path to 'public', 'extensions', 'realtime'
as $function$
begin
  raise exception using errcode = '22023', message = 'Client update required: expected room snapshot missing';
end;
$function$;

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

create or replace function public.jpp1e_delete_room(
  p_room_code text,
  p_owner_secret text
)
returns boolean
language plpgsql
security definer
set search_path to 'public', 'extensions'
as $function$
declare
  v_count integer;
begin
  delete from public.jpp1e_rooms r
  where r.room_code = upper(trim(p_room_code))
    and crypt(p_owner_secret, r.owner_secret_hash) = r.owner_secret_hash;

  get diagnostics v_count = row_count;
  return v_count = 1;
end;
$function$;

-- -----------------------------------------------------------------------------
-- 4. Filtered player state
-- -----------------------------------------------------------------------------

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

-- -----------------------------------------------------------------------------
-- 5. Invite / reconnect RPCs
-- -----------------------------------------------------------------------------
create or replace function public.jpp1e_create_player_invite(
  p_room_code text,
  p_owner_secret text,
  p_character_id text,
  p_character_name text
)
returns table(invite_code text, character_name text)
language plpgsql
security definer
set search_path to 'public', 'extensions'
as $function$
declare v_room_id uuid; v_code_id text; v_secret text;
begin
  select r.id into v_room_id from public.jpp1e_rooms r
  where r.room_code = upper(trim(p_room_code))
    and crypt(p_owner_secret, r.owner_secret_hash) = r.owner_secret_hash
  limit 1 for update;
  if v_room_id is null then raise exception 'invalid owner credentials'; end if;
  if coalesce(trim(p_character_id),'')='' or coalesce(trim(p_character_name),'')='' then raise exception 'character is required'; end if;
  if not exists(select 1 from public.jpp1e_rooms r cross join lateral jsonb_array_elements(coalesce(r.state->'characters','[]'::jsonb)) c where r.id=v_room_id and c->>'id'=p_character_id) then raise exception 'character not found'; end if;

  loop
    v_code_id := upper(substr(replace(gen_random_uuid()::text,'-',''),1,8));
    exit when not exists(select 1 from public.jpp1e_room_invites i where i.code_id=v_code_id);
  end loop;
  v_secret := encode(gen_random_bytes(18),'hex');

  insert into public.jpp1e_room_invites(
    room_id,code_id,secret_hash,secret_plain,character_id,character_name,active,kind,created_at,updated_at
  ) values(
    v_room_id,v_code_id,crypt(v_secret,gen_salt('bf')),v_secret,p_character_id,p_character_name,true,'invite',now(),now()
  );
  return query select v_code_id||'.'||v_secret,p_character_name;
end;
$function$;

create or replace function public.jpp1e_join_player(
  p_invite_code text
)
returns table(
  room_code text,
  name text,
  rule text,
  character_id text,
  character_name text,
  state jsonb,
  realtime_topic text,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path to 'public', 'extensions', 'pg_temp'
as $function$
declare v_i public.jpp1e_room_invites%rowtype;
begin
  v_i:=jpp1e_private.lock_credential(p_invite_code,false);
  return query select r.room_code,r.name,r.rule,v_i.character_id,v_i.character_name,
    public.jpp1e_filter_player_state(r.state,v_i.character_id),
    'jpp1e:'||r.room_code||':'||r.realtime_secret,r.updated_at
    from public.jpp1e_rooms r where r.id=v_i.room_id;
end;
$function$;

create or replace function public.jpp1e_join_player_v3(
  p_invite_code text
)
returns table(
  room_code text,
  name text,
  rule text,
  character_id text,
  character_name text,
  state jsonb,
  realtime_topic text,
  updated_at timestamptz,
  reconnect_code text
)
language plpgsql
security definer
set search_path to 'public', 'extensions', 'pg_temp'
as $function$
declare v_i public.jpp1e_room_invites%rowtype; v_reconnect text;
begin
  v_i:=jpp1e_private.lock_credential(p_invite_code,true);
  if v_i.kind='invite' then
    v_reconnect:=jpp1e_private.ensure_reconnect_code(v_i.room_id,v_i.character_id,v_i.character_name);
    update public.jpp1e_room_invites set active=false,used_at=now(),updated_at=now() where id=v_i.id;
  else
    v_reconnect:=v_i.code_id||'.'||split_part(trim(p_invite_code),'.',2);
  end if;
  return query select r.room_code,r.name,r.rule,v_i.character_id,v_i.character_name,
    public.jpp1e_filter_player_state(r.state,v_i.character_id),
    'jpp1e:'||r.room_code||':'||r.realtime_secret,r.updated_at,v_reconnect
    from public.jpp1e_rooms r where r.id=v_i.room_id;
end;
$function$;

create or replace function public.jpp1e_list_player_invites(
  p_room_code text,
  p_owner_secret text
)
returns table(code_id text, character_id text, character_name text, active boolean, created_at timestamptz)
language sql
security definer
set search_path to 'public', 'extensions'
as $function$
  select i.code_id,i.character_id,i.character_name,i.active,i.created_at
  from public.jpp1e_room_invites i join public.jpp1e_rooms r on r.id=i.room_id
  where r.room_code=upper(trim(p_room_code)) and crypt(p_owner_secret,r.owner_secret_hash)=r.owner_secret_hash
  and i.kind='invite' and i.active=true and i.used_at is null and i.revoked_at is null
  order by i.created_at desc;
$function$;

create or replace function public.jpp1e_list_player_invites_v3(
  p_room_code text,
  p_owner_secret text
)
returns table(invite_code text, character_id text, character_name text, created_at timestamptz)
language sql
security definer
set search_path to 'public', 'extensions'
as $function$
  select case when coalesce(i.secret_plain,'')<>'' then i.code_id||'.'||i.secret_plain else null end,
         i.character_id,i.character_name,i.created_at
  from public.jpp1e_room_invites i
  join public.jpp1e_rooms r on r.id=i.room_id
  where r.room_code=upper(trim(p_room_code))
    and crypt(p_owner_secret,r.owner_secret_hash)=r.owner_secret_hash
    and i.active=true
    and i.kind='invite'
  and i.kind='invite' and i.active=true and i.used_at is null and i.revoked_at is null
  order by i.created_at desc;
$function$;

create or replace function public.jpp1e_list_player_invites_v4(
  p_room_code text,
  p_owner_secret text
)
returns table(code_id text, invite_code text, character_id text, character_name text, created_at timestamptz)
language sql
security definer
set search_path to 'public', 'extensions'
as $function$
  select i.code_id,
         case when coalesce(i.secret_plain,'')<>'' then i.code_id||'.'||i.secret_plain else null end,
         i.character_id,i.character_name,i.created_at
  from public.jpp1e_room_invites i
  join public.jpp1e_rooms r on r.id=i.room_id
  where r.room_code=upper(trim(p_room_code))
    and crypt(p_owner_secret,r.owner_secret_hash)=r.owner_secret_hash
    and i.active=true
    and i.kind='invite'
  and i.kind='invite' and i.active=true and i.used_at is null and i.revoked_at is null
  order by i.created_at desc;
$function$;

create or replace function public.jpp1e_list_player_reconnects(
  p_room_code text,
  p_owner_secret text
)
returns table(reconnect_code text, character_id text, character_name text, updated_at timestamptz)
language sql
security definer
set search_path to 'public', 'extensions'
as $function$
  select i.code_id||'.'||i.secret_plain,
         i.character_id,i.character_name,i.updated_at
  from public.jpp1e_room_invites i
  join public.jpp1e_rooms r on r.id=i.room_id
  where r.room_code=upper(trim(p_room_code))
    and crypt(p_owner_secret,r.owner_secret_hash)=r.owner_secret_hash
    and i.active=true
    and i.kind='reconnect'
    and coalesce(i.secret_plain,'')<>''
  and i.revoked_at is null
  order by i.character_name,i.updated_at desc;
$function$;

create or replace function public.jpp1e_get_reconnect_code_by_credential(
  p_credential text
)
returns text
language plpgsql
security definer
set search_path to 'public', 'extensions', 'pg_temp'
as $function$
declare v_i public.jpp1e_room_invites%rowtype; v_reconnect text;
begin
  v_i:=jpp1e_private.lock_credential(p_credential,true);
  if v_i.kind='reconnect' then return v_i.code_id||'.'||split_part(trim(p_credential),'.',2); end if;
  v_reconnect:=jpp1e_private.ensure_reconnect_code(v_i.room_id,v_i.character_id,v_i.character_name);
  update public.jpp1e_room_invites set active=false,used_at=now(),updated_at=now() where id=v_i.id;
  return v_reconnect;
end;
$function$;

create or replace function public.jpp1e_reissue_player_reconnect(
  p_room_code text,
  p_owner_secret text,
  p_character_id text
)
returns text
language plpgsql
security definer
set search_path to 'public', 'extensions'
as $function$
declare v_room public.jpp1e_rooms%rowtype; v_name text; v_code_id text; v_secret text; v_row_id uuid;
begin
  select * into v_room from public.jpp1e_rooms r
  where r.room_code=upper(trim(p_room_code))
    and crypt(p_owner_secret,r.owner_secret_hash)=r.owner_secret_hash
  for update;
  if v_room.id is null then raise exception 'invalid owner credentials'; end if;

  select c->>'name' into v_name
  from jsonb_array_elements(coalesce(v_room.state->'characters','[]'::jsonb)) c
  where c->>'id'=p_character_id limit 1;
  if v_name is null then raise exception 'character not found'; end if;

  select id into v_row_id from public.jpp1e_room_invites
  where room_id=v_room.id and character_id=p_character_id and kind='reconnect' and active=true
  order by created_at desc limit 1 for update;

  loop
    v_code_id:=upper(substr(replace(gen_random_uuid()::text,'-',''),1,8));
    exit when not exists(select 1 from public.jpp1e_room_invites i where i.code_id=v_code_id);
  end loop;
  v_secret:=encode(gen_random_bytes(18),'hex');

  if v_row_id is null then
    insert into public.jpp1e_room_invites(room_id,code_id,secret_hash,secret_plain,character_id,character_name,active,kind,created_at,updated_at)
    values(v_room.id,v_code_id,crypt(v_secret,gen_salt('bf')),v_secret,p_character_id,v_name,true,'reconnect',now(),now());
  else
    update public.jpp1e_room_invites
    set code_id=v_code_id,secret_hash=crypt(v_secret,gen_salt('bf')),secret_plain=v_secret,
        character_name=v_name,revoked_at=null,updated_at=now()
    where id=v_row_id;
  end if;

  delete from public.jpp1e_realtime_memberships m where m.room_id=v_room.id and m.role='player'
    and m.invite_id in (select i.id from public.jpp1e_room_invites i where i.room_id=v_room.id and i.character_id=p_character_id);
  delete from public.jpp1e_push_subscriptions s where s.room_id=v_room.id and s.role='player'
    and (s.character_id=p_character_id or s.invite_id in (select i.id from public.jpp1e_room_invites i where i.room_id=v_room.id and i.character_id=p_character_id));
  return v_code_id||'.'||v_secret;
end;
$function$;

create or replace function public.jpp1e_revoke_player_invite(
  p_room_code text,
  p_owner_secret text,
  p_code_id text
)
returns boolean
language plpgsql
security definer
set search_path to 'public', 'extensions', 'pg_temp'
as $function$
declare v_room public.jpp1e_rooms%rowtype; v_id uuid;
begin
  select r.* into v_room from public.jpp1e_rooms r where r.room_code=upper(trim(p_room_code))
    and extensions.crypt(p_owner_secret,r.owner_secret_hash)=r.owner_secret_hash for update;
  if v_room.id is null then raise exception 'invalid owner credentials' using errcode='42501'; end if;
  update public.jpp1e_room_invites i set active=false,revoked_at=now(),updated_at=now()
    where i.room_id=v_room.id and i.code_id=upper(trim(p_code_id)) and i.kind='invite'
      and i.active=true and i.used_at is null and i.revoked_at is null returning i.id into v_id;
  if v_id is null then return false; end if;
  delete from public.jpp1e_realtime_memberships where room_id=v_room.id and role='player' and invite_id=v_id;
  delete from public.jpp1e_push_subscriptions where room_id=v_room.id and role='player' and invite_id=v_id;
  return true;
end;
$function$;

create or replace function public.jpp1e_revoke_player_access(
  p_room_code text,
  p_owner_secret text,
  p_character_id text
)
returns boolean
language plpgsql
security definer
set search_path to 'public', 'extensions', 'pg_temp'
as $function$
declare v_room public.jpp1e_rooms%rowtype;
begin
  select r.* into v_room from public.jpp1e_rooms r where r.room_code=upper(trim(p_room_code))
    and extensions.crypt(p_owner_secret,r.owner_secret_hash)=r.owner_secret_hash for update;
  if v_room.id is null then raise exception 'invalid owner credentials' using errcode='42501'; end if;
  if not exists(select 1 from jsonb_array_elements(coalesce(v_room.state->'characters','[]'::jsonb)) c where c->>'id'=p_character_id)
    then raise exception 'character not found'; end if;
  update public.jpp1e_room_invites set active=false,revoked_at=coalesce(revoked_at,now()),updated_at=now()
    where room_id=v_room.id and character_id=p_character_id and kind in ('invite','reconnect');

  delete from public.jpp1e_realtime_memberships m where m.room_id=v_room.id and m.role='player'
    and m.invite_id in (select i.id from public.jpp1e_room_invites i where i.room_id=v_room.id and i.character_id=p_character_id);
  delete from public.jpp1e_push_subscriptions s where s.room_id=v_room.id and s.role='player'
    and (s.character_id=p_character_id or s.invite_id in (select i.id from public.jpp1e_room_invites i where i.room_id=v_room.id and i.character_id=p_character_id));
  return true;
end;
$function$;

-- -----------------------------------------------------------------------------
-- 6. Player write RPCs
-- -----------------------------------------------------------------------------
create or replace function public.jpp1e_player_send_message(
  p_invite_code text,
  p_message_id text,
  p_text text,
  p_time timestamptz default now()
)
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'extensions'
as $function$
declare
  v_code_id text;
  v_secret text;
  v_invite public.jpp1e_room_invites%rowtype;
  v_room public.jpp1e_rooms%rowtype;
  v_message jsonb;
  v_seal text;
begin
  v_invite := jpp1e_private.lock_credential(p_invite_code,false);
  select * into v_room
  from public.jpp1e_rooms r
  where r.id=v_invite.room_id
  for update;

  select item->>'image' into v_seal
  from jsonb_array_elements(coalesce(v_room.state->'characters','[]'::jsonb)) item
  where item->>'id'=v_invite.character_id
  limit 1;

  v_message := jsonb_build_object(
    'id',coalesce(nullif(trim(p_message_id),''),'m_'||replace(gen_random_uuid()::text,'-','')),
    'author',v_invite.character_name,
    'characterId',v_invite.character_id,
    'text',coalesce(p_text,''),
    'edited',false,
    'time',coalesce(p_time,now()),
    'seal',v_seal
  );

  update public.jpp1e_rooms
  set state=jsonb_set(
        coalesce(v_room.state,'{}'::jsonb),
        '{messages}',
        coalesce(v_room.state->'messages','[]'::jsonb)||jsonb_build_array(v_message),
        true
      ),
      updated_at=now()
  where id=v_room.id;

  return v_message;
end;
$function$;

create or replace function public.jpp1e_player_edit_message(
  p_invite_code text,
  p_message_id text,
  p_text text
)
returns boolean
language plpgsql
security definer
set search_path to 'public', 'extensions'
as $function$
declare
  v_code_id text; v_secret text; v_invite public.jpp1e_room_invites%rowtype; v_room public.jpp1e_rooms%rowtype;
  v_messages jsonb; v_new jsonb:='[]'::jsonb; v_item jsonb; v_changed boolean:=false;
begin
  v_invite := jpp1e_private.lock_credential(p_invite_code,false);
  select * into v_room from public.jpp1e_rooms r where r.id=v_invite.room_id for update;
  v_messages:=coalesce(v_room.state->'messages','[]'::jsonb);
  for v_item in select value from jsonb_array_elements(v_messages) loop
    if v_item->>'id'=p_message_id
       and v_item->>'characterId'=v_invite.character_id
       and coalesce(v_item->>'displayName','')=''
       and coalesce(v_item->>'gmProxy','false')<>'true' then
      v_item:=jsonb_set(v_item,'{text}',to_jsonb(coalesce(p_text,'')),true);
      v_item:=jsonb_set(v_item,'{edited}','true'::jsonb,true);
      v_item:=jsonb_set(v_item,'{editedAt}',to_jsonb(now()),true);
      v_changed:=true;
    end if;
    v_new:=v_new||jsonb_build_array(v_item);
  end loop;
  if v_changed then
    update public.jpp1e_rooms set state=jsonb_set(coalesce(v_room.state,'{}'::jsonb),'{messages}',v_new,true),updated_at=now() where id=v_room.id;
  end if;
  return v_changed;
end;
$function$;

create or replace function public.jpp1e_player_move_token(
  p_invite_code text,
  p_character_id text,
  p_x numeric,
  p_y numeric
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
  v_tokens jsonb;
  v_chars jsonb;
  v_new_tokens jsonb := '[]'::jsonb;
  v_item jsonb;
  v_char jsonb;
  v_changed boolean := false;
begin
  v_invite := jpp1e_private.lock_credential(p_invite_code,false);
  if v_invite.character_id is distinct from p_character_id then raise exception 'character not allowed'; end if;
  select * into v_room
  from public.jpp1e_rooms r
  where r.id = v_invite.room_id
  for update;

  v_tokens := coalesce(v_room.state->'tokens', '[]'::jsonb);
  v_chars := coalesce(v_room.state->'characters', '[]'::jsonb);

  for v_item in select value from jsonb_array_elements(v_tokens)
  loop
    if v_item->>'characterId' = p_character_id then
      v_item := jsonb_set(v_item, '{x}', to_jsonb(greatest(-1000, least(1000, p_x))), true);
      v_item := jsonb_set(v_item, '{y}', to_jsonb(greatest(-1000, least(1000, p_y))), true);
      v_changed := true;
    end if;
    v_new_tokens := v_new_tokens || jsonb_build_array(v_item);
  end loop;

  if not v_changed then
    select value into v_char
    from jsonb_array_elements(v_chars)
    where value->>'id' = p_character_id
    limit 1;

    if v_char is null then
      raise exception 'character not found';
    end if;

    v_new_tokens := v_new_tokens || jsonb_build_array(
      jsonb_build_object(
        'id', 't_' || encode(gen_random_bytes(8), 'hex'),
        'characterId', p_character_id,
        'name', coalesce(v_char->>'name','캐릭터'),
        'image', v_char->'image',
        'x', greatest(-1000, least(1000, p_x)),
        'y', greatest(-1000, least(1000, p_y)),
        'size', 44,
        'shape', 'circle'
      )
    );
    v_changed := true;
  end if;

  update public.jpp1e_rooms
  set state = jsonb_set(coalesce(v_room.state, '{}'::jsonb), '{tokens}', v_new_tokens, true),
      updated_at = now()
  where id = v_room.id;

  return true;
end;
$function$;

create or replace function public.jpp1e_player_update_annotations(
  p_invite_code text,
  p_annotations jsonb
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
  v_count integer;
begin
  v_invite := jpp1e_private.lock_credential(p_invite_code,false);
  update public.jpp1e_rooms
  set state = jsonb_set(
        coalesce(state, '{}'::jsonb),
        '{annotations}',
        coalesce(p_annotations, '[]'::jsonb),
        true
      ),
      updated_at = now()
  where id = v_invite.room_id;

  get diagnostics v_count = row_count;
  return v_count = 1;
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

create or replace function public.jpp1e_player_ack_handout(
  p_invite_code text,
  p_handout_id text
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
  v_handouts jsonb;
  v_new_handouts jsonb := '[]'::jsonb;
  v_item jsonb;
  v_new_active jsonb;
  v_changed boolean := false;
begin
  v_invite := jpp1e_private.lock_credential(p_invite_code,false);
  select * into v_room
  from public.jpp1e_rooms r
  where r.id=v_invite.room_id
  for update;

  v_handouts := coalesce(v_room.state->'handouts','[]'::jsonb);

  for v_item in select value from jsonb_array_elements(v_handouts)
  loop
    if v_item->>'id'=p_handout_id
       and (coalesce(v_item->'activeTo','[]'::jsonb) ? v_invite.character_id)
    then
      select coalesce(jsonb_agg(value),'[]'::jsonb)
        into v_new_active
      from jsonb_array_elements(coalesce(v_item->'activeTo','[]'::jsonb))
      where value #>> '{}' <> v_invite.character_id;

      v_item := jsonb_set(v_item,'{activeTo}',v_new_active,true);
      v_changed := true;
    end if;
    v_new_handouts := v_new_handouts || jsonb_build_array(v_item);
  end loop;

  if v_changed then
    update public.jpp1e_rooms
    set state=jsonb_set(coalesce(v_room.state,'{}'::jsonb),'{handouts}',v_new_handouts,true),
        updated_at=now()
    where id=v_room.id;
  end if;

  return v_changed;
end;
$function$;

-- -----------------------------------------------------------------------------
-- 7. Realtime authorization and bindings
-- -----------------------------------------------------------------------------
create or replace function public.jpp1e_realtime_topic(
  p_room_code text,
  p_owner_secret text
)
returns text
language sql
security definer
set search_path to 'public', 'extensions'
as $function$
  select 'jpp1e:'||r.room_code||':'||r.realtime_secret
  from public.jpp1e_rooms r
  where r.room_code=upper(trim(p_room_code))
    and crypt(p_owner_secret,r.owner_secret_hash)=r.owner_secret_hash
  limit 1;
$function$;

create or replace function public.jpp1e_realtime_bind_gm(
  p_room_code text,
  p_owner_secret text
)
returns boolean
language plpgsql
security definer
set search_path to 'public', 'extensions'
as $function$
declare
  v_room_id uuid;
  v_uid uuid;
begin
  v_uid := auth.uid();
  if v_uid is null then
    raise exception 'authentication required';
  end if;

  select r.id
    into v_room_id
  from public.jpp1e_rooms r
  where r.room_code = upper(trim(p_room_code))
    and crypt(p_owner_secret, r.owner_secret_hash) = r.owner_secret_hash
  limit 1;

  if v_room_id is null then
    raise exception 'invalid owner credentials';
  end if;

  insert into public.jpp1e_realtime_memberships (
    auth_user_id, room_id, role, invite_id
  ) values (
    v_uid, v_room_id, 'gm', null
  )
  on conflict (auth_user_id, room_id)
  do update set role = 'gm', invite_id = null;

  return true;
end;
$function$;

create or replace function public.jpp1e_realtime_bind_player(
  p_invite_code text
)
returns boolean
language plpgsql
security definer
set search_path to 'public', 'extensions'
as $function$
declare
  v_uid uuid;
  v_code_id text;
  v_secret text;
  v_invite public.jpp1e_room_invites%rowtype;
begin
  v_uid := auth.uid();
  if v_uid is null then
    raise exception 'authentication required';
  end if;

  v_invite := jpp1e_private.lock_credential(p_invite_code,false);

  insert into public.jpp1e_realtime_memberships (
    auth_user_id, room_id, role, invite_id
  ) values (
    v_uid, v_invite.room_id, 'player', v_invite.id
  )
  on conflict (auth_user_id, room_id)
  do update set role = 'player', invite_id = v_invite.id;

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

-- -----------------------------------------------------------------------------
-- 8. Push subscription authorization helper (Edge service_role only)
-- -----------------------------------------------------------------------------
create or replace function public.jpp1e_push_manage_subscription(
  p_action text,
  p_invite_code text default null,
  p_room_code text default null,
  p_owner_secret text default null,
  p_subscription jsonb default '{}'::jsonb,
  p_show_preview boolean default false,
  p_notification_types text[] default array['chat'::text]
)
returns boolean
language plpgsql
security definer
set search_path to 'public', 'extensions', 'pg_temp'
as $function$
declare
  v_i public.jpp1e_room_invites%rowtype;
  v_room public.jpp1e_rooms%rowtype;
  v_role text;
  v_endpoint text:=p_subscription->>'endpoint';
begin
  if coalesce(p_invite_code,'')<>'' then
    v_i:=jpp1e_private.lock_credential(p_invite_code,false);
    select r.* into v_room from public.jpp1e_rooms r where r.id=v_i.room_id;
    v_role:='player';
  else
    select r.* into v_room from public.jpp1e_rooms r where r.room_code=upper(trim(p_room_code))
      and extensions.crypt(p_owner_secret,r.owner_secret_hash)=r.owner_secret_hash for update;
    if v_room.id is null then raise exception 'invalid owner credentials' using errcode='42501'; end if;
    v_role:='gm';
  end if;
  if coalesce(v_endpoint,'')='' then raise exception 'invalid subscription'; end if;
  if p_action='register' then
    if coalesce(p_subscription#>>'{keys,p256dh}','')='' or coalesce(p_subscription#>>'{keys,auth}','')='' then raise exception 'invalid subscription'; end if;
    insert into public.jpp1e_push_subscriptions(room_id,invite_id,role,character_id,character_name,endpoint,p256dh,auth,show_preview,notification_types)
      values(v_room.id,v_i.id,v_role,v_i.character_id,case when v_role='gm' then 'GM' else v_i.character_name end,v_endpoint,p_subscription#>>'{keys,p256dh}',p_subscription#>>'{keys,auth}',coalesce(p_show_preview,false),p_notification_types)
      on conflict(room_id,endpoint) do update set invite_id=excluded.invite_id,role=excluded.role,character_id=excluded.character_id,
        character_name=excluded.character_name,p256dh=excluded.p256dh,auth=excluded.auth,show_preview=excluded.show_preview,
        notification_types=excluded.notification_types,updated_at=now();
  elsif p_action='unregister' then
    delete from public.jpp1e_push_subscriptions s where s.room_id=v_room.id and s.endpoint=v_endpoint
      and s.role=v_role and (v_role='gm' or s.invite_id=v_i.id);
  else raise exception 'unknown action'; end if;
  return true;
end;
$function$;

-- -----------------------------------------------------------------------------
-- 9. Function privileges
-- -----------------------------------------------------------------------------
-- First close every public function, then reopen only the intended roles.
do $$
declare r record;
begin
  for r in
    select p.oid::regprocedure as sig
    from pg_proc p
    join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname like 'jpp1e_%'
  loop
    execute format('revoke all on function %s from public, anon, authenticated, service_role', r.sig);
  end loop;
end;
$$;

-- Browser-callable credential-checked RPCs.
grant execute on function public.jpp1e_create_room(text,text,text,jsonb) to anon, authenticated, service_role;
grant execute on function public.jpp1e_load_room(text,text) to anon, authenticated, service_role;
grant execute on function public.jpp1e_save_room(text,text,text,text,jsonb) to anon, authenticated, service_role;
grant execute on function public.jpp1e_save_room(text,text,text,text,jsonb,jsonb) to anon, authenticated, service_role;
grant execute on function public.jpp1e_delete_room(text,text) to anon, authenticated, service_role;
grant execute on function public.jpp1e_filter_player_state(jsonb,text) to anon, authenticated, service_role;
grant execute on function public.jpp1e_create_player_invite(text,text,text,text) to anon, authenticated, service_role;
grant execute on function public.jpp1e_join_player(text) to anon, authenticated, service_role;
grant execute on function public.jpp1e_join_player_v3(text) to anon, authenticated, service_role;
grant execute on function public.jpp1e_list_player_invites(text,text) to anon, authenticated, service_role;
grant execute on function public.jpp1e_list_player_invites_v3(text,text) to anon, authenticated, service_role;
grant execute on function public.jpp1e_list_player_invites_v4(text,text) to anon, authenticated, service_role;
grant execute on function public.jpp1e_list_player_reconnects(text,text) to anon, authenticated, service_role;
grant execute on function public.jpp1e_get_reconnect_code_by_credential(text) to anon, authenticated, service_role;
grant execute on function public.jpp1e_reissue_player_reconnect(text,text,text) to anon, authenticated, service_role;
grant execute on function public.jpp1e_revoke_player_invite(text,text,text) to anon, authenticated, service_role;
grant execute on function public.jpp1e_revoke_player_access(text,text,text) to anon, authenticated, service_role;
grant execute on function public.jpp1e_player_send_message(text,text,text,timestamptz) to anon, authenticated, service_role;
grant execute on function public.jpp1e_player_edit_message(text,text,text) to anon, authenticated, service_role;
grant execute on function public.jpp1e_player_move_token(text,text,numeric,numeric) to anon, authenticated, service_role;
grant execute on function public.jpp1e_player_update_annotations(text,jsonb) to anon, authenticated, service_role;
grant execute on function public.jpp1e_player_update_character(text,jsonb,jsonb) to anon, authenticated, service_role;
grant execute on function public.jpp1e_player_ack_handout(text,text) to anon, authenticated, service_role;
grant execute on function public.jpp1e_realtime_topic(text,text) to anon, authenticated, service_role;

-- Realtime membership requires an Auth user (Anonymous sign-in is enough).
grant execute on function public.jpp1e_realtime_bind_gm(text,text) to authenticated, service_role;
grant execute on function public.jpp1e_realtime_bind_player(text) to authenticated, service_role;
grant execute on function public.jpp1e_realtime_authorized() to authenticated, service_role;

-- Edge-only service RPC.
grant execute on function public.jpp1e_push_manage_subscription(text,text,text,text,jsonb,boolean,text[]) to service_role;

-- -----------------------------------------------------------------------------
-- 10. Supabase Realtime private Broadcast policies
-- -----------------------------------------------------------------------------
drop policy if exists "jpp1e members can receive private broadcast" on realtime.messages;
drop policy if exists "jpp1e members can send private broadcast" on realtime.messages;

create policy "jpp1e members can receive private broadcast"
on realtime.messages
for select
to authenticated
using (
  extension = 'broadcast'::text
  and public.jpp1e_realtime_authorized()
);

create policy "jpp1e members can send private broadcast"
on realtime.messages
for insert
to authenticated
with check (
  extension = 'broadcast'::text
  and public.jpp1e_realtime_authorized()
);

commit;

select '누알피지 설치 SQL 실행 완료' as status;
