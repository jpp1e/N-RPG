-- 2026-09-20 안정화판 → 2026-09-22 맵/시트 회귀 수정. 백업 후 실행.
begin;
do $guard$
declare body text;
begin
  select prosrc into body from pg_proc where oid=to_regprocedure('jpp1e_private.redact_maps(jsonb,text[])');
  if body is null or md5(replace(body,chr(13),'')) not in ('c0286694e78e7cdfc23aac6425814f28','e41545ecfb65a0fc0c81fc5a8f9461ed') then raise exception 'Unsupported function: jpp1e_private.redact_maps(jsonb,text[])'; end if;
  select prosrc into body from pg_proc where oid=to_regprocedure('public.jpp1e_filter_player_state(jsonb,text)');
  if body is null or md5(replace(body,chr(13),'')) not in ('1d3630c8b28cf4ca31a2c30582f1f805','d7aaf6c2a564b651881ed6ef72b43428') then raise exception 'Unsupported function: public.jpp1e_filter_player_state(jsonb,text)'; end if;
end;
$guard$;
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

commit;
