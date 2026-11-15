import {fail,text,now,json,digest,permit,scope,superOnly} from './auth.mjs';
import {selection} from './domain.mjs';
const permission=action=>({pause:'pause',pause_individual:'pause',resume_individual:'reactivate',resume_scope:'reactivate',reverse_pause:'reactivate',archive:'archive',archive_individual:'archive',hwid_reset:'hwid_reset',revoke:'revoke',purge:'purge'})[action];
function claimScope(params){if(params.group==='all')return {kind:'global',sql:"pc.scope_kind='global'",args:[]};if(params.group==='direct')return {kind:'direct',sql:"pc.scope_kind='direct'",args:[]};if(params.group==='distributor')return {kind:'distributor',sql:"pc.scope_kind='distributor' AND pc.scope_distributor_id=?",args:[text(params.distributorId)]};return {kind:'selected',sql:"pc.scope_kind='selected'",args:[]}}
async function checkOrigin(env,a,id){const original=await env.DB.prepare("SELECT * FROM admin_operations WHERE id=? AND action='pause'").bind(text(id)).first();if(!original)fail(400,'invalid_pause_operation');const p=JSON.parse(original.selector);if(p.group==='all')superOnly(a);if(a.role!=='SUPER_ADMIN'&&((p.group==='distributor'&&(a.role==='DISTRIBUTOR'?a.distributor_id!==p.distributorId:!a.scopes.includes('distributor:'+p.distributorId)))||(p.group==='direct'&&(a.role==='DISTRIBUTOR'||!a.scopes.includes('direct')))))fail(403,'pause_origin_forbidden');if(['selected','unknown'].includes(p.group)&&a.role!=='SUPER_ADMIN'&&original.actor_id!==a.id)fail(403,'pause_origin_forbidden');return original}
async function confirmation(env,op){
  const raw=env.AUTH_JWT_SECRET??env.JWT_SECRET;if(typeof raw!=='string'||raw.length<32)fail(503,'auth_unavailable');
  const key=await crypto.subtle.importKey('raw',new TextEncoder().encode(raw),{name:'HMAC',hash:'SHA-256'},false,['sign']);
  const bytes=await crypto.subtle.sign('HMAC',key,new TextEncoder().encode('vini-confirm-v1|'+op.id+'|'+op.actor_id+'|'+op.request_hash+'|'+op.expires_at));
  return [...new Uint8Array(bytes)].map(v=>v.toString(16).padStart(2,'0')).join('');
}
export async function operationResult(env,a,id){
  const op=await env.DB.prepare(`SELECT * FROM admin_operations WHERE id=? AND ${a.role==='SUPER_ADMIN'?'1':'actor_id=?'}`).bind(id,...(a.role==='SUPER_ADMIN'?[]:[a.id])).first();if(!op)fail(404,'operation_not_found');
  const counts=(await env.DB.prepare('SELECT state,COUNT(*) AS count FROM operation_members WHERE operation_id=? GROUP BY state').bind(id).all()).results;
  const results=Object.fromEntries(counts.map(r=>[r.state,r.count]));
  const summary=await env.DB.prepare('SELECT COUNT(DISTINCT distributor_at_preview) AS distributors,SUM(was_paused) AS alreadyPaused,SUM(will_change) AS effectiveChanges FROM operation_members WHERE operation_id=?').bind(id).first();
  return {id:op.id,actorId:op.actor_id,action:op.action,status:op.status,scope:JSON.parse(op.selector),reason:op.reason,expiresAt:op.expires_at,total:counts.reduce((n,r)=>n+r.count,0),summary,results};
}
export async function reconfirm(env,a,id){
  const op=await env.DB.prepare('SELECT * FROM admin_operations WHERE id=? AND actor_id=?').bind(id,a.id).first();if(!op)fail(404,'operation_not_found');permit(a,permission(op.action));
  if(op.status==='cancelled'||(op.status==='preview'&&Date.parse(op.expires_at)<=Date.now()))fail(409,'new_preview_required');
  const token=await confirmation(env,op);if(await digest(token)!==op.token_hash)fail(409,'confirmation_key_rotated');
  return json({...await operationResult(env,a,id),confirmationToken:token});
}
export async function cancel(env,a,id){
  await operationResult(env,a,id);const result=await env.DB.prepare("UPDATE admin_operations SET status='cancelled' WHERE id=? AND status IN ('preview','running') RETURNING id").bind(id).all();
  if(result.results.length)await env.DB.prepare('INSERT INTO admin_audit(id,actor_id,operation_id,action,details,created_at) VALUES(?,?,?,?,?,?)').bind(crypto.randomUUID(),a.id,id,'operation_cancelled','{}',now()).run();
  return json(await operationResult(env,a,id));
}
export async function preview(env,a,input){
  const action=input.action,perm=permission(action);if(!perm)fail(400,'invalid_action');permit(a,perm);
  if(action==='purge')superOnly(a);
  const params=input.selection||{},key=text(input.idempotencyKey,128),reason=text(input.reason,500);
  if(['hwid_reset','archive_individual','pause_individual','resume_individual'].includes(action)&&(params.group!=='selected'||!Array.isArray(params.ids)||params.ids.length!==1))fail(400,'individual_operation_requires_one_id');
  if(action==='resume_scope'&&!['all','direct','distributor'].includes(params.group))fail(400,'invalid_resume_scope');
  if(!['manual','maintenance','distributor_pause','expired_cleanup','license_revocation','support'].includes(reason))fail(400,'reason_code_required');
  const canonical=JSON.stringify({action,selection:params,reason,revertOf:input.revertOf||null});
  const hash=await digest(canonical);
  const previous=await env.DB.prepare('SELECT * FROM admin_operations WHERE actor_id=? AND idempotency_key=?').bind(a.id,key).first();
  if(previous){if(previous.request_hash!==hash)fail(409,'idempotency_key_reused');const token=await confirmation(env,previous);if(await digest(token)!==previous.token_hash)fail(409,'confirmation_key_rotated');return json({...await operationResult(env,a,previous.id),confirmationToken:token})}
  const q=selection(a,params,perm);let filter=q.sql,args=q.args;
  if(['hwid_reset','archive_individual','pause_individual','resume_individual'].includes(action)&&params.group==='selected'){
    const owned=await env.DB.prepare(`SELECT COUNT(*) AS count FROM users u WHERE ${filter}`).bind(...args).first();if(owned.count!==new Set(params.ids).size)fail(404,'user_not_found');
  }
  if(action==='reverse_pause'){
    const original=await checkOrigin(env,a,input.revertOf);
    filter+=' AND EXISTS(SELECT 1 FROM pause_claims pc WHERE pc.user_id=u.id AND pc.operation_id=? AND pc.active=1)';args.push(original.id);
  }
  const cs=claimScope(params);
  if(action==='resume_scope'){filter+=' AND EXISTS(SELECT 1 FROM pause_claims pc WHERE pc.user_id=u.id AND pc.active=1 AND '+cs.sql+')';args.push(...cs.args)}
  const op={id:crypto.randomUUID(),actor_id:a.id,request_hash:hash,expires_at:new Date(Date.now()+900000).toISOString()};
  const token=await confirmation(env,op);
  const predicted=action.startsWith('pause')?"CASE WHEN u.is_paused=0 AND u.archived_at IS NULL AND u.revoked_at IS NULL THEN 1 ELSE 0 END":action==='hwid_reset'?'1':action==='archive_individual'?"CASE WHEN u.archived_at IS NULL THEN 1 ELSE 0 END":'CASE WHEN u.is_paused=1 THEN 1 ELSE 0 END';
  const previewBatch=[
    env.DB.prepare("INSERT INTO admin_operations(id,actor_id,idempotency_key,request_hash,action,selector,reason,token_hash,created_at,expires_at,status,revert_of) VALUES(?,?,?,?,?,?,?,?,?,?,'preview',?)").bind(op.id,a.id,key,hash,action,JSON.stringify(params),reason,await digest(token),now(),op.expires_at,input.revertOf||null),
    env.DB.prepare(`INSERT INTO operation_members(operation_id,user_id,expected_revision,was_paused,distributor_at_preview,will_change) SELECT ?,u.id,u.admin_revision,u.is_paused,u.distributor_id,${predicted} FROM users u WHERE ${filter} ORDER BY u.id`).bind(op.id,...args)
  ];
  if(action==='resume_scope')previewBatch.push(env.DB.prepare(`INSERT INTO operation_claim_members SELECT ?,pc.user_id,pc.id FROM pause_claims pc JOIN operation_members m ON m.user_id=pc.user_id AND m.operation_id=? WHERE pc.active=1 AND ${cs.sql}`).bind(op.id,op.id,...cs.args));
  await env.DB.batch(previewBatch);
  if(action==='resume_scope')await env.DB.prepare("UPDATE operation_members SET will_change=CASE WHEN EXISTS(SELECT 1 FROM pause_claims pc WHERE pc.user_id=operation_members.user_id AND pc.active=1 AND NOT EXISTS(SELECT 1 FROM operation_claim_members cm WHERE cm.operation_id=? AND cm.claim_id=pc.id)) THEN 0 ELSE 1 END WHERE operation_id=?").bind(op.id,op.id).run();
  const result=await operationResult(env,a,op.id);
  return json({...result,confirmationToken:token},201);
}
export async function members(env,a,id,url){
  await operationResult(env,a,id);const offset=Number(url.searchParams.get('offset')||0);if(!Number.isSafeInteger(offset)||offset<0)fail(400,'invalid_page');
  const guard=scope(a,'read');const result=await env.DB.prepare(`SELECT m.user_id,m.expected_revision,m.state,u.username FROM operation_members m JOIN users u ON u.id=m.user_id WHERE m.operation_id=? AND ${guard.sql} ORDER BY m.user_id LIMIT 100 OFFSET ?`).bind(id,...guard.args,offset).all();
  return json({members:result.results,offset});
}
export async function execute(env,a,id,input){
  const op=await env.DB.prepare('SELECT * FROM admin_operations WHERE id=? AND actor_id=?').bind(id,a.id).first();if(!op)fail(404,'operation_not_found');
  const perm=permission(op.action);permit(a,perm);if(op.action==='purge'||JSON.parse(op.selector).group==='all')superOnly(a);
  if(op.action==='reverse_pause')await checkOrigin(env,a,op.revert_of);
  if(await digest(text(input.confirmationToken,128))!==op.token_hash)fail(403,'confirmation_required');
  if(op.status==='cancelled')fail(409,'cancelled');
  if(op.status==='completed')return json(await operationResult(env,a,id));
  if(op.status==='preview'&&Date.parse(op.expires_at)<=Date.now())fail(409,'preview_expired');
  await env.DB.prepare("UPDATE admin_operations SET status='running' WHERE id=? AND status='preview' AND expires_at>?").bind(id,now()).run();
  const current=await env.DB.prepare('SELECT status FROM admin_operations WHERE id=?').bind(id).first();
  if(current.status!=='running')fail(409,'operation_not_running');
  const pending=(await env.DB.prepare("SELECT user_id,expected_revision FROM operation_members WHERE operation_id=? AND state='pending' ORDER BY user_id LIMIT 5").bind(id).all()).results;
  const guard=scope(a,perm),stamp=now(),batch=[];
  for(const member of pending){
    const uid=member.user_id,attempt=crypto.randomUUID();
    let eligible="u.purged_at IS NULL";
    if(op.action==='archive')eligible+=" AND u.is_paused=0 AND u.archived_at IS NULL AND u.license_expires_at IS NOT NULL AND julianday(u.license_expires_at)<=julianday('now')";
    if(op.action==='purge')eligible+=" AND u.is_paused=0 AND u.archived_at IS NOT NULL AND julianday(u.license_expires_at)<=julianday('now') AND EXISTS(SELECT 1 FROM admin_retention r WHERE r.id=1 AND r.enabled=1 AND julianday(u.archived_at)<=julianday('now')-r.days)";
    if(['pause','pause_individual','resume_individual'].includes(op.action))eligible+=' AND u.archived_at IS NULL AND u.revoked_at IS NULL';
    if(op.action==='archive_individual')eligible+=' AND u.archived_at IS NULL';
    if(['resume_individual','reverse_pause','resume_scope'].includes(op.action))eligible+=' AND (u.is_paused=0 OR u.pause_remaining_known=1)';
    batch.push(env.DB.prepare(`UPDATE operation_members SET state='applied',attempt_id=? WHERE operation_id=? AND user_id=? AND state='pending' AND EXISTS(SELECT 1 FROM admin_operations o WHERE o.id=operation_members.operation_id AND o.status='running') AND EXISTS(SELECT 1 FROM users u WHERE u.id=? AND u.admin_revision=? AND ${guard.sql} AND ${eligible})`).bind(attempt,id,uid,uid,member.expected_revision,...guard.args));
    // Unique attempt ownership is acquired in the same atomic D1 batch as all
    // changes. Retries/concurrent requests cannot repeat this member's mutation.
    const proof="EXISTS(SELECT 1 FROM operation_members m WHERE m.operation_id=? AND m.user_id=? AND m.attempt_id=? AND m.state='applied')";
    const proofArgs=[id,uid,attempt];
    const update=(sets,values=[])=>batch.push(env.DB.prepare(`UPDATE users SET ${sets} WHERE id=? AND ${proof}`).bind(...values,uid,...proofArgs));
    if(op.action==='pause'||op.action==='pause_individual'){
      const source=op.action==='pause'?'bulk':'individual';
      const cs=source==='individual'?{kind:'individual'}:claimScope(JSON.parse(op.selector));
      const noDuplicate=source==='individual'?" AND NOT EXISTS(SELECT 1 FROM pause_claims WHERE user_id=? AND active=1 AND source IN ('individual','legacy'))":'';
      batch.push(env.DB.prepare(`INSERT INTO pause_claims(id,user_id,operation_id,actor_id,source,created_at,scope_kind,scope_distributor_id) SELECT ?,?,?,?,?,?,?,? WHERE ${proof}${noDuplicate}`).bind('pause:'+id+':'+uid,uid,id,a.id,source,stamp,cs.kind,JSON.parse(op.selector).distributorId||null,...proofArgs,...(source==='individual'?[uid]:[])));
      update("pause_remaining_ms=CASE WHEN is_paused=0 THEN CASE WHEN license_expires_at IS NULL THEN NULL ELSE MAX(0,ROUND((julianday(license_expires_at)-julianday(?))*86400000)) END ELSE pause_remaining_ms END,pause_remaining_known=CASE WHEN is_paused=0 THEN CASE WHEN license_expires_at IS NULL OR julianday(license_expires_at) IS NOT NULL THEN 1 ELSE 0 END ELSE pause_remaining_known END,is_paused=1,paused_at=COALESCE(paused_at,?),updated_at=?",[stamp,stamp,stamp]);
    }else if(['reverse_pause','resume_individual','resume_scope'].includes(op.action)){
      const condition=op.action==='reverse_pause'?'operation_id=?':op.action==='resume_scope'?'id IN (SELECT claim_id FROM operation_claim_members WHERE operation_id=?)':"source IN ('individual','legacy')";
      batch.push(env.DB.prepare(`UPDATE pause_claims SET active=0,released_at=? WHERE user_id=? AND active=1 AND ${condition} AND ${proof}`).bind(stamp,uid,...(op.action==='reverse_pause'?[op.revert_of]:op.action==='resume_scope'?[id]:[]),...proofArgs));
      update("license_expires_at=CASE WHEN is_paused=1 AND pause_remaining_known=1 AND NOT EXISTS(SELECT 1 FROM pause_claims pc WHERE pc.user_id=users.id AND active=1) THEN CASE WHEN pause_remaining_ms IS NULL THEN NULL ELSE strftime('%Y-%m-%dT%H:%M:%fZ',julianday(?)+pause_remaining_ms/86400000.0) END ELSE license_expires_at END,pause_remaining_known=CASE WHEN EXISTS(SELECT 1 FROM pause_claims pc WHERE pc.user_id=users.id AND active=1) THEN pause_remaining_known ELSE 0 END,is_paused=CASE WHEN EXISTS(SELECT 1 FROM pause_claims pc WHERE pc.user_id=users.id AND active=1) THEN 1 ELSE 0 END,paused_at=(SELECT MIN(created_at) FROM pause_claims pc WHERE pc.user_id=users.id AND active=1),updated_at=?",[stamp,stamp]);
    }else if(['archive','archive_individual'].includes(op.action))update('archive_previous_active=is_active,archived_at=?,is_active=0,updated_at=?',[stamp,stamp]);
    else if(op.action==='hwid_reset'){
      update("hwid='',device_epoch=device_epoch+1,updated_at=?",[stamp]);
      batch.push(env.DB.prepare(`DELETE FROM device_challenges WHERE activation_id IN (SELECT id FROM device_activations WHERE user_id=?) AND ${proof}`).bind(uid,...proofArgs));
      batch.push(env.DB.prepare(`UPDATE device_activations SET status='revoked' WHERE user_id=? AND ${proof}`).bind(uid,...proofArgs));
    }
    else if(op.action==='revoke')update('revoked_at=?,is_active=0,updated_at=?',[stamp,stamp]);
    else if(op.action==='purge'){
      update("username='deleted:'||id,hwid='',license_key=?,permissions='{}',platform=NULL,referral_code=NULL,referred_by=NULL,purged_at=?,is_active=0,updated_at=?",['DELETED-'+crypto.randomUUID(),stamp,stamp]);
      batch.push(env.DB.prepare(`DELETE FROM user_patches WHERE user_id=? AND ${proof}`).bind(uid,...proofArgs));
      batch.push(env.DB.prepare(`UPDATE device_activations SET status='revoked',license_key='DELETED:'||user_id,public_key='',kid='deleted:'||id WHERE user_id=? AND ${proof}`).bind(uid,...proofArgs));
    }
    batch.push(env.DB.prepare(`INSERT INTO admin_audit(id,actor_id,user_id,license_id,operation_id,action,details,created_at) SELECT ?,?,?,?,?,?,?,? WHERE ${proof}`).bind(id+':'+uid,a.id,uid,'license:'+uid,id,op.action,JSON.stringify({reason:op.reason,expectedRevision:member.expected_revision}),stamp,...proofArgs));
    batch.push(env.DB.prepare("UPDATE operation_members SET state='conflict' WHERE operation_id=? AND user_id=? AND state='pending'").bind(id,uid));
  }
  if(batch.length)await env.DB.batch(batch);
  await env.DB.prepare("UPDATE admin_operations SET status='completed' WHERE id=? AND status='running' AND NOT EXISTS(SELECT 1 FROM operation_members WHERE operation_id=? AND state='pending')").bind(id,id).run();
  return json(await operationResult(env,a,id));
}
