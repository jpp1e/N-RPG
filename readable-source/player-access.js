/* 누알피지 플레이어 접속 모듈.
 * 원격 공개 페이지에서는 별도 로컬 테스트 설정을 활성화하지 않습니다.
 */
(function(root){
  'use strict';
  const KEY='jpp1e_player_sessions_v2';
  const loopback=host=>['localhost','127.0.0.1','[::1]'].includes(host);
  class AccessError extends Error{
    constructor(code,status=0){super({DISABLED:'플레이어 접속 기능을 사용할 수 없습니다.',UNAVAILABLE:'플레이어 접속 서버 기능을 확인해주세요.',DENIED:'플레이어 접근 권한을 확인할 수 없습니다.',IDENTITY:'승인된 기기의 로그인 정보를 확인해주세요.',STALE:'방 또는 로그인 상태가 변경되었습니다.',PUSH_PENDING:'푸시 알림 기능을 사용할 수 없습니다.'}[code]||'플레이어 요청을 완료하지 못했습니다.');this.code=code;this.status=status;}
  }
  function previewConfig(location,raw){
    if(!raw?.enabled)return null;
    // 원격 공개 페이지에서는 이 로컬 테스트 설정을 활성화하지 않습니다.
    if(!loopback(location.hostname))return null;
    let url;try{url=new URL(raw.url);}catch{throw new AccessError('UNAVAILABLE');}
    if(!loopback(url.hostname)||!['http:','https:'].includes(url.protocol)||url.username||url.password||url.pathname!=='/'||url.search||url.hash||typeof raw.key!=='string'||!raw.key)throw new AccessError('UNAVAILABLE');
    return Object.freeze({url:url.origin,key:raw.key,vapidPublicKey:typeof raw.vapidPublicKey==='string'?raw.vapidPublicKey:'',enabled:true});
  }
  function stored(storage){
    const raw=storage.getItem(KEY);if(!raw)return {};
    try{const value=JSON.parse(raw);if(!value||typeof value!=='object'||Array.isArray(value))throw 0;return value;}
    catch{throw new AccessError('DENIED');}
  }
  const writes=Object.freeze({
    jpp1e_player_send_message:['p_message_id','p_text','p_time'],
    jpp1e_player_edit_message:['p_message_id','p_text'],
    jpp1e_player_update_character:['p_sheet','p_skills'],
    jpp1e_player_move_token:['p_character_id','p_x','p_y'],
    jpp1e_player_ack_handout:['p_handout_id']
  });
  function create({config,storage,createClient,fetchImpl=root.fetch.bind(root),legacySession,removeLegacy,onBoundary=()=>{}}){
    let selected=null,generation=0,clientPromise=null,sessionFlight=null,observedUid=null;
    const ready=new Map(),preparing=new Map(),failedEnrollment=new Map();
    function invalidate(reason='STALE'){
      generation++;ready.clear();preparing.clear();onBoundary(reason,selected);
    }
    function selectRoom(id){if(selected!==id){selected=id;invalidate();}}
    function mark(id){const all=stored(storage);return Object.prototype.hasOwnProperty.call(all,id)?all[id]||{version:2}:null;}
    function view(id){
      const meta=mark(id);if(!meta)return null;
      const verified=ready.get(id);
      return {version:2,roomCode:meta.roomCode,accessId:meta.accessId,authUserId:meta.authUserId,characterId:verified?.meta.characterId||null,characterName:verified?.meta.characterName||'',pending:!verified};
    }
    function ticket(){return {id:selected,generation};}
    function check(t){if(t.id!==selected||t.generation!==generation)throw new AccessError('STALE');}
    async function client(){
      if(!config)throw new AccessError('DISABLED');
      if(!clientPromise)clientPromise=(async()=>{
        const c=await createClient(config.url,config.key);
        c.auth.onAuthStateChange((event,session)=>{
          const uid=session?.user?.id||null;
          // Keep this callback synchronous; no SDK calls under its auth lock.
          if(event==='SIGNED_OUT'||(observedUid&&uid!==observedUid)){observedUid=uid;invalidate('IDENTITY');}
          else if(uid)observedUid=uid;
        });
        return c;
      })().catch(e=>{clientPromise=null;throw new AccessError('IDENTITY');});
      return clientPromise;
    }
    async function session(allowCreate=false){
      const c=await client();
      if(sessionFlight)return sessionFlight;
      sessionFlight=(async()=>{
        let result=await c.auth.getSession();
        if(result.error)throw new AccessError('IDENTITY');
        if(!result.data?.session&&allowCreate)result=await c.auth.signInAnonymously();
        const s=result.data?.session;
        if(result.error||!s?.access_token||!s.user?.id)throw new AccessError('IDENTITY');
        if(allowCreate&&s.user.is_anonymous!==true)throw new AccessError('IDENTITY');
        if(observedUid&&observedUid!==s.user.id){observedUid=s.user.id;invalidate('IDENTITY');throw new AccessError('IDENTITY');}
        observedUid=s.user.id;return s;
      })();
      try{return await sessionFlight;}finally{sessionFlight=null;}
    }
    async function send(path,body,t,uid,{multipart=false,allowCreate=false}={}){
      check(t);
      let s=await session(allowCreate);check(t);
      if(uid&&s.user.id!==uid)throw new AccessError('IDENTITY');
      const expected=s.user.id;
      for(let attempt=0;attempt<2;attempt++){
        check(t);
        let res;
        try{res=await fetchImpl(config.url+path,{method:'POST',headers:{apikey:config.key,Authorization:'Bearer '+s.access_token,...(multipart?{}:{'Content-Type':'application/json'})},body:multipart?body:JSON.stringify(body),signal:AbortSignal.timeout(15000)});}
        catch{check(t);throw new AccessError('NETWORK');}
        check(t);
        if(res.status===401&&attempt===0){
          const refreshed=await (await client()).auth.refreshSession();check(t);
          s=refreshed.data?.session;
          if(refreshed.error||!s?.access_token||s.user?.id!==expected)throw new AccessError('IDENTITY');
          continue;
        }
        if(!res.ok)throw new AccessError(res.status===404?'UNAVAILABLE':res.status===401||res.status===403?'DENIED':'REQUEST',res.status);
        let value;try{value=await res.json();}catch{throw new AccessError('DENIED');}
        const latest=await session(false);check(t);
        if(latest.user.id!==expected)throw new AccessError('IDENTITY');
        return {value,uid:expected};
      }
      throw new AccessError('IDENTITY');
    }
    const rpc=(name,body,t,uid,options)=>send('/rest/v1/rpc/'+name,body,t,uid,options);
    function rowOf(value,expected){
      if(!Array.isArray(value)||value.length!==1)throw new AccessError('DENIED');
      const row=value[0];
      if(!row?.access_id||!row.room_id||typeof row.room_code!=='string'||!row.character_id||!row.state||Array.isArray(row.state)||!Array.isArray(row.state.characters)||!row.state.characters.some(c=>c.id===row.character_id))throw new AccessError('DENIED');
      if(expected&&(row.room_code!==expected.roomCode||row.access_id!==expected.accessId))throw new AccessError('DENIED');
      return row;
    }
    function remember(id,row,uid){
      const meta={version:2,authUserId:uid,roomCode:row.room_code,accessId:row.access_id,characterId:row.character_id,characterName:row.character_name||''};
      const all=stored(storage);all[id]=meta;storage.setItem(KEY,JSON.stringify(all));
      ready.set(id,{meta,row});removeLegacy(id);return {meta,row};
    }
    async function join(invite){
      const t=ticket();
      const result=await rpc('jpp1e_player_approve_v2',{p_invite_code:invite},t,null,{allowCreate:true});
      const row=rowOf(result.value);return {row,uid:result.uid,t};
    }
    function commitJoin(id,enrollment){check(enrollment.t);remember(id,enrollment.row,enrollment.uid);}
    async function ensure(id){
      if(!config)throw new AccessError('DISABLED');
      if(selected!==id)throw new AccessError('STALE');
      if(ready.has(id))return ready.get(id);
      if(preparing.has(id))return preparing.get(id);
      const t=ticket();
      const work=(async()=>{
        const meta=mark(id);
        if(meta){
          if(meta.version!==2||!meta.authUserId||!meta.accessId||!meta.roomCode)throw new AccessError('DENIED');
          const result=await rpc('jpp1e_player_read_v2',{p_room_code:meta.roomCode},t,meta.authUserId);
          return remember(id,rowOf(result.value,meta),result.uid);
        }
        if(failedEnrollment.has(id))throw failedEnrollment.get(id);
        const legacy=legacySession(id);
        if(!legacy?.inviteCode||!legacy.roomCode)throw new AccessError('DENIED');
        try{
          const enrollment=await join(legacy.inviteCode);check(t);
          if(enrollment.row.room_code!==legacy.roomCode)throw new AccessError('DENIED');
          return remember(id,enrollment.row,enrollment.uid);
        }catch(e){if(e.code!=='STALE')failedEnrollment.set(id,e);throw e;}
      })();
      preparing.set(id,work);
      try{return await work;}finally{if(preparing.get(id)===work)preparing.delete(id);}
    }
    async function protect(fn){try{return await fn();}catch(e){if(!['STALE','PUSH_PENDING'].includes(e.code))invalidate(e.code||'DENIED');throw e;}}
    async function read(id){return protect(async()=>{
      const wasReady=ready.has(id),t=ticket(),state=await ensure(id);check(t);
      if(!wasReady)return state.row;
      const result=await rpc('jpp1e_player_read_v2',{p_room_code:state.meta.roomCode},t,state.meta.authUserId);
      return remember(id,rowOf(result.value,state.meta),result.uid).row;
    });}
    async function write(id,name,args){return protect(async()=>{
      const fields=writes[name];if(!fields)throw new AccessError('DENIED');
      const t=ticket(),{meta}=await ensure(id);check(t);
      const body={p_room_code:meta.roomCode};
      for(const field of fields)if(args[field]!==undefined)body[field]=args[field];
      if(name==='jpp1e_player_move_token'){
        if(args.p_character_id!==meta.characterId)throw new AccessError('DENIED');
        body.p_character_id=meta.characterId;
      }
      return (await rpc(name+'_v2',body,t,meta.authUserId)).value;
    });}
    async function asset(id,action,extra){return protect(async()=>{
      const t=ticket(),{meta}=await ensure(id);check(t);
      let body;
      if(action==='upload'){
        if(!['character','token'].includes(extra.assetType)||(extra.characterId&&extra.characterId!==meta.characterId))throw new AccessError('DENIED');
        body=new FormData();Object.entries({action,roomCode:meta.roomCode,assetType:extra.assetType,characterId:meta.characterId}).forEach(([k,v])=>body.append(k,v));body.append('file',extra.file);
      }else{
        if(!['sign','delete'].includes(action))throw new AccessError('DENIED');
        body={action,roomCode:meta.roomCode,path:extra.path};
      }
      const {value}=await send('/functions/v1/jpp1e-player-assets-v2',body,t,meta.authUserId,{multipart:action==='upload'});
      if(value?.ok!==true)throw new AccessError('DENIED');return value;
    });}
    async function push(id,action,extra){return protect(async()=>{
      if(!['register','unregister'].includes(action))throw new AccessError('PUSH_PENDING');
      const t=ticket(),{meta}=await ensure(id);check(t);
      const body=action==='register'?{action,roomCode:meta.roomCode,subscription:extra.subscription,showPreview:extra.showPreview===true,notificationTypes:extra.notificationTypes}:{action,roomCode:meta.roomCode,endpoint:extra.endpoint};
      const {value}=await send('/functions/v1/jpp1e-player-push-v2',body,t,meta.authUserId);
      if(value?.ok!==true)throw new AccessError('DENIED');return value;
    });}
    async function topic(id){return protect(async()=>{
      const t=ticket(),{meta}=await ensure(id);check(t);
      const {value}=await rpc('jpp1e_player_topic_v2',{p_room_code:meta.roomCode},t,meta.authUserId);
      if(typeof value!=='string'||!value.startsWith('jpp1e-v2:'+meta.roomCode+':'))throw new AccessError('DENIED');
      return {topic:value,userId:meta.authUserId};
    });}
    return {enabled:!!config,view,mark,join,commitJoin,read,write,asset,push,topic,client,session,selectRoom,invalidate,
      isReady:id=>ready.has(id),stamp:()=>generation,
      async gmTopic(roomCode,secret){const t=ticket(),s=await session(true);check(t);return (await rpc('jpp1e_gm_topic_v2',{p_room_code:roomCode,p_owner_secret:secret},t,s.user.id)).value;}
    };
  }
  root.Jpp1ePlayerAccess=Object.freeze({KEY,AccessError,previewConfig,create});
})(typeof window==='undefined'?globalThis:window);
