// Extends the current R2 panel in place. All requests stay on the staging origin.
(() => {
  'use strict';
  let principal=null,group='direct',distributorId=null,pageOffset=0,lastUsers=[],lastTotal=0;
  const selected=new Set();
  const authKey='vini_admin_scoped_token';
  const shell=document.createElement('section');shell.id='page-admin-v2';shell.className='page';shell.style.display='none';document.querySelector('main.main').append(shell);
  const status=document.createElement('p');status.setAttribute('role','status');
  const nav=document.createElement('div');nav.className='nav-section vini-admin-nav';document.querySelector('.sidebar .logo').after(nav);
  const style=document.createElement('style');style.textContent='.vini-admin-nav button{background:transparent;border:0;width:100%;text-align:left;font:inherit}.vini-admin-nav button:hover{background:#1a1a25}.vini-admin-nav button.active{background:#8b5cf6;color:white}#page-admin-v2{overflow-x:auto}#page-admin-v2 h1{margin-bottom:20px}#page-admin-v2 .form-group{min-width:150px;flex:1}.vini-operation-card{display:flex;flex-wrap:wrap;align-items:center;gap:12px;padding:14px;margin:12px 0;border:1px solid #252532;border-radius:8px;background:#12121a}';document.head.append(style);
  nav.addEventListener('click',event=>{const item=event.target.closest('button');if(item){document.querySelectorAll('.sidebar .nav-item').forEach(n=>n.classList.remove('active'));item.classList.add('active')}});
  function element(tag,value,cls){const e=document.createElement(tag);if(tag==='form')e.addEventListener('submit',event=>event.preventDefault());if(value!==undefined)e.textContent=String(value??'');if(cls)e.className=cls;return e}
  function button(label,fn){const e=element('button',label,'btn btn-secondary');e.type='button';const permission=label.startsWith('Pausar')?'pause':label.startsWith('Reactivar')?'reactivate':label.startsWith('Archivar')||label==='Eliminar (archivar)'?'archive':label==='Resetear HWID'?'hwid_reset':label==='Renovar'?'renew':label==='Asignar BASIC / PRO'||label==='Crear usuario/licencia'?'create':label.startsWith('Revocar')?'revoke':null;if(permission&&principal?.role!=='SUPER_ADMIN'&&!principal?.actions.includes(permission))e.disabled=true;e.addEventListener('click',()=>Promise.resolve().then(fn).catch(report));return e}
  function report(error){status.textContent=error.message||'Error';if(!shell.contains(status))shell.prepend(status)}
  async function request(path,method='GET',data){
    const response=await fetch('/api/admin-v2'+path,{method,credentials:'omit',headers:{'Content-Type':'application/json','Authorization':'Bearer '+token},...(data?{body:JSON.stringify(data)}:{})});
    const result=await response.json();if(!response.ok)throw Error(result.error||'Error administrativo');return result;
  }
  function show(){document.querySelectorAll('.page').forEach(p=>p.style.display='none');shell.style.display='block';shell.replaceChildren(status);status.textContent=''}
  function field(parent,label,type='text',value=''){const wrap=element('div',undefined,'form-group'),caption=element('label',label),input=document.createElement('input');input.id='admin-field-'+crypto.randomUUID();caption.htmlFor=input.id;input.type=type;input.value=value;wrap.append(caption,input);parent.append(wrap);return input}
  function choice(parent,label,values){const wrap=element('div',undefined,'form-group'),caption=element('label',label),select=document.createElement('select');select.id='admin-field-'+crypto.randomUUID();caption.htmlFor=select.id;for(const [value,title] of values){const o=element('option',title);o.value=value;select.append(o)}wrap.append(caption,select);parent.append(wrap);return select}
  function summary(){return {group,...(distributorId?{distributorId}:{})}}
  async function authenticate(){
    principal=await request('/me');nav.replaceChildren(element('div','Administración','nav-section-title'));
    if(principal.role==='SUPER_ADMIN'||principal.scopes.includes('direct'))nav.append(button('Clientes directos',()=>{group='direct';distributorId=null;pageOffset=0;selected.clear();return users()}));
    if(principal.role==='DISTRIBUTOR')nav.append(button('Mis clientes',()=>{group='distributor';distributorId=principal.distributorId;pageOffset=0;selected.clear();return users()}));
    nav.append(button('Distribuidores',distributors),button('Operaciones e informes',operations));
    if(principal.role==='SUPER_ADMIN')nav.append(button('Todos los usuarios',()=>{group='all';distributorId=null;pageOffset=0;selected.clear();return users()}),button('Origen desconocido',()=>{group='unknown';distributorId=null;pageOffset=0;selected.clear();return users()}),button('Administradores',administrators),button('Retención',retention),button('Permisos de patches',patchPolicy));
    nav.querySelectorAll('button').forEach(n=>{n.className='nav-item'});
    const scoped=principal.role!=='SUPER_ADMIN';document.querySelectorAll('.sidebar .nav-item[data-page]').forEach(n=>{n.hidden=scoped;n.style.display=scoped?'none':''});
    document.querySelectorAll('.sidebar .nav-section:not(.vini-admin-nav)').forEach(n=>{if(n.querySelector('[data-page]')&&!n.querySelector('#logoutBtn'))n.style.display=scoped?'none':''});
    document.getElementById('loginScreen').style.display='none';document.getElementById('app').style.display='flex';
    if(principal.role==='DISTRIBUTOR'){group='distributor';distributorId=principal.distributorId}
    else if(principal.role==='ADMIN'&&!principal.scopes.includes('direct')){const first=principal.scopes.find(s=>s.startsWith('distributor:'));if(first){group='distributor';distributorId=first.slice('distributor:'.length)}}
    document.querySelectorAll('.sidebar .nav-item').forEach(n=>n.classList.remove('active'));nav.querySelector('button')?.classList.add('active');
    await users();
  }
  // Capture prevents the original login handler from sending a second request.
  document.getElementById('loginForm').addEventListener('submit',async event=>{
    event.preventDefault();event.stopImmediatePropagation();
    try{
      const credentials={username:document.getElementById('loginUsername').value,password:document.getElementById('loginPassword').value};
      let response=await fetch('/api/admin-v2/login',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(credentials)});
      if(response.status===401)response=await fetch('/api/admin/login',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(credentials)});
      const result=await response.json();if(!response.ok||!result.token)throw Error(result.error||'Credenciales inválidas');
      token=result.token;sessionStorage.setItem(authKey,token);document.getElementById('loginPassword').value='';await authenticate();
    }catch(error){alert(error.message)}
  },true);
  document.getElementById('logoutBtn').addEventListener('click',()=>{sessionStorage.removeItem(authKey);principal=null});
  async function users(){
    show();shell.append(element('h1',group==='direct'?'Clientes directos':group==='unknown'?'Origen histórico desconocido':group==='distributor'?'Clientes del distribuidor':'Todos los usuarios'));
    const filters=element('form');filters.style.display='flex';filters.style.flexWrap='wrap';filters.style.gap='12px';
    const search=field(filters,'Buscar usuario'),plan=choice(filters,'Plan',[['','Todos'],['basic','BASIC'],['pro','PRO']]),state=choice(filters,'Estado',[['','Todos'],['active','Activos'],['expired','Expirados'],['paused','Pausados'],['blocked','Bloqueados'],['revoked','Revocados'],['archived','Archivados']]);
    const creator=field(filters,'ID del creador'),before=field(filters,'Expira antes de (UTC)','date'),expiresAfter=field(filters,'Expira desde (UTC)','date'),after=field(filters,'Creado desde (UTC)','date'),createdBefore=field(filters,'Creado antes de (UTC)','date');
    const owner=group==='all'?choice(filters,'Distribuidor',[['','Todos'],...(await request('/distributors')).distributors.map(d=>[d.id,d.name])]):null;
    function currentSelection(){const params={...summary()};for(const [key,value] of [['search',search.value],['plan',plan.value],['status',state.value],['creator',creator.value],['expiresBefore',before.value],['expiresAfter',expiresAfter.value],['createdAfter',after.value],['createdBefore',createdBefore.value],['distributorId',owner?.value]])if(value)params[key]=value;return params}
    filters.append(button('Buscar',()=>load(0)));shell.append(filters);
    const table=document.createElement('table');const head=element('tr');for(const title of ['Seleccionar','Usuario','Plan','Estado','Vencimiento','Saldo en pausa','HWID protegido','Distribuidor','Creador original','Acciones'])head.append(element('th',title));table.append(head);const rows=document.createElement('tbody');table.append(rows);shell.append(table);
    if(['direct','distributor'].includes(group)||group==='all'&&principal.role==='SUPER_ADMIN')shell.append(button(group==='all'?'Pausar todas las licencias':'Pausar todas',()=>bulk('pause',summary())),button(group==='all'?'Reactivar todas las licencias':'Reactivar todas',()=>bulk('resume_scope',summary())));
    shell.append(button('Crear usuario/licencia',createUser),button('Pausar seleccionados',()=>bulk('pause',{group:'selected',ids:[...selected]})),button('Pausar este ámbito filtrado',()=>bulk('pause',currentSelection())),button('Archivar expirados del ámbito',()=>bulk('archive',{...currentSelection(),status:'expired'})),button('Revocar seleccionados',()=>bulk('revoke',{group:'selected',ids:[...selected]})),button('Página anterior',()=>load(Math.max(0,pageOffset-50))),button('Página siguiente',()=>load(pageOffset+50)));
    if(principal.role==='SUPER_ADMIN')shell.append(button('Purgar seleccionados archivados',()=>bulk('purge',{group:'selected',ids:[...selected]})));
    async function load(offset){
      const params={...currentSelection(),limit:50,offset};
      const result=await request('/users?'+new URLSearchParams(params));pageOffset=offset;lastUsers=result.users;lastTotal=result.total;rows.replaceChildren();
      for(const user of lastUsers){
        const tr=element('tr'),check=document.createElement('input');check.type='checkbox';check.checked=selected.has(user.id);check.setAttribute('aria-label','Seleccionar '+user.username);check.addEventListener('change',()=>check.checked?selected.add(user.id):selected.delete(user.id));const td=element('td');td.append(check);tr.append(td);
        const remaining=!user.is_paused?'—':!user.pause_remaining_known?'No verificado':user.pause_remaining_ms===null?'Sin caducidad':Math.floor(user.pause_remaining_ms/86400000)+' d '+Math.floor(user.pause_remaining_ms%86400000/3600000)+' h '+Math.floor(user.pause_remaining_ms%3600000/60000)+' min';
        const labels={active:'Activa',paused:'Pausada',expired:'Expirada',revoked:'Revocada',archived:'Archivada',blocked:'Bloqueada',inactive:'Inactiva',unverified:'No verificada'};
        const values=[user.username,user.plan_id||'No verificado',user.licenseStatus,user.license_expires_at||'Sin caducidad',remaining,user.hwidMasked||'Sin vínculo',user.distributor_id|| (user.origin_status==='unknown'?'Desconocido':'Directo'),user.created_by_admin_id||'Desconocido'];
        values.forEach((value,index)=>{const cell=element('td');if(index===2){const tone=user.licenseStatus==='active'?'badge-active':['paused','expired'].includes(user.licenseStatus)?'badge-paused':['revoked','blocked'].includes(user.licenseStatus)?'badge-blocked':'';cell.append(element('span',labels[user.licenseStatus]||value,'badge '+tone))}else cell.textContent=value;tr.append(cell)});
        const actions=element('td');actions.append(button('Renovar',async()=>{const date=prompt('Nueva expiración ISO 8601. Vacío = sin caducidad.',user.license_expires_at||'');if(date===null)return;if(user.archived_at&&!confirm('¿Renovar y desarchivar explícitamente, conservando bloqueos y pausas?'))return;await request('/users/'+encodeURIComponent(user.id)+'/renew','POST',{licenseExpiresAt:date||null,restoreArchived:!!user.archived_at});return load(pageOffset)}),button('Pausar individual',()=>bulk('pause_individual',{group:'selected',ids:[user.id]})),button('Reactivar individual',()=>bulk('resume_individual',{group:'selected',ids:[user.id]})),button('Historial',async()=>{show();const history=await request('/audit?userId='+encodeURIComponent(user.id));shell.append(element('pre',JSON.stringify(history,null,2)))}));
        actions.append(button('Eliminar (archivar)',()=>bulk('archive_individual',{group:'selected',ids:[user.id]})),button('Resetear HWID',()=>bulk('hwid_reset',{group:'selected',ids:[user.id]})),button('Asignar BASIC / PRO',async()=>{const plan=prompt('Plan: basic o pro',user.plan_id||'basic');if(plan===null)return;await request('/users/'+encodeURIComponent(user.id),'PATCH',{plan});await load(pageOffset)}));
        if(principal.role==='SUPER_ADMIN')actions.append(button('Transferir',async()=>{const id=prompt('ID distribuidor destino; vacío = cliente directo.');if(id===null)return;await request('/users/'+encodeURIComponent(user.id)+'/transfer','POST',{distributorId:id||null});return load(pageOffset)}));
        tr.append(actions);rows.append(tr);
      }
      status.textContent='Total sin duplicados: '+lastTotal+'. Mostrando '+lastUsers.length+' desde '+pageOffset+'. Seleccionados: '+selected.size;
    }
    filters.addEventListener('submit',e=>{e.preventDefault();load(0).catch(report)});await load(pageOffset);
  }
  async function createUser(){
    show();shell.append(element('h1','Crear usuario y licencia'));const form=element('form');const name=field(form,'Nombre'),plan=choice(form,'Plan',[['basic','BASIC'],['pro','PRO']]),expires=field(form,'Expira (vacío = sin caducidad)','datetime-local');
    form.append(button('Emitir',async()=>{const result=await request('/users','POST',{username:name.value,plan:plan.value,licenseExpiresAt:expires.value?new Date(expires.value).toISOString():null,distributorId:distributorId||null});show();shell.append(element('p','Guarda esta licencia de forma segura. No aparece en los informes.'),element('pre',result.licenseKey),button('Volver',users))}));shell.append(form);
  }
  async function distributors(){
    show();shell.append(element('h1','Distribuidores'));const result=await request('/distributors');
    for(const d of result.distributors){const row=element('div',d.name+' — '+d.status+' — '+d.total+' clientes; '+d.active+' activos; '+d.expired+' expirados; '+d.paused+' pausados. ID: '+d.id);row.append(button('Administrar',()=>{group='distributor';distributorId=d.id;pageOffset=0;selected.clear();return users()}));if(principal.role==='SUPER_ADMIN')row.append(button(d.status==='active'?'Suspender acceso administrativo':'Reactivar acceso administrativo',async()=>{await request('/distributors/'+d.id,'PATCH',{status:d.status==='active'?'suspended':'active'});await distributors()}));shell.append(row)}
    if(principal.role==='SUPER_ADMIN')shell.append(button('Crear distribuidor',async()=>{const name=prompt('Nombre del distribuidor');if(name){await request('/distributors','POST',{name});await distributors()}}));
  }
  async function bulk(action,selection,revertOf=null){
    if(selection.group==='selected'&&!selection.ids.length)throw Error('Selecciona usuarios primero');
    const op=await request('/operations/preview','POST',{action,selection,revertOf,reason:action==='archive'||action==='purge'?'expired_cleanup':'manual',idempotencyKey:crypto.randomUUID()});
    const detail=await request('/operations/'+op.id+'/members');
    const warning=action==='hwid_reset'?'\nRevocará sesiones online y activaciones de ESTA licencia. Los leases offline ya emitidos conservan su caducidad firmada. La clave de licencia sigue siendo válida para autenticarse de nuevo.':action==='archive_individual'?'\nBaja lógica: conserva historial y saldo. No es eliminación definitiva.':'';
    if(!confirm('Operación: '+action+'\nÁmbito: '+JSON.stringify(op.scope)+'\nCantidad exacta: '+op.total+'\nDistribuidores: '+op.summary.distributors+'\nYa pausadas: '+(op.summary.alreadyPaused||0)+'\nCambios de pausa previstos: '+(op.summary.effectiveChanges||0)+'\nPrimeros registros: '+detail.members.map(m=>m.username).join(', ')+warning+'\nConfirmar ejecución por lotes.'))return;
    sessionStorage.setItem('vini_operation_'+op.id,op.confirmationToken);await run(op.id,op.confirmationToken);
  }
  async function run(id,confirmationToken){
    for(let batch=0;batch<501;batch++){
      const result=await request('/operations/'+id+'/execute','POST',{confirmationToken});status.textContent='Operación '+id+': '+JSON.stringify(result.results);
      if(result.status==='completed'){sessionStorage.removeItem('vini_operation_'+id);alert('Operación terminada. '+JSON.stringify(result.results));return operations()}
      await new Promise(resolve=>setTimeout(resolve,50));
    }
    throw Error('Límite de lotes alcanzado; reanuda desde Operaciones.');
  }
  async function operations(){
    show();shell.append(element('h1','Operaciones e informes'));const result=await request('/operations');
    const actions={pause:'Pausa masiva',pause_individual:'Pausa individual',resume_individual:'Reactivación individual',resume_scope:'Reactivación del ámbito',reverse_pause:'Reversión de pausa',archive:'Archivado',archive_individual:'Baja lógica individual',hwid_reset:'Reset HWID individual',revoke:'Revocación',purge:'Purga'},states={preview:'Previsualización',running:'En ejecución',completed:'Finalizada',cancelled:'Cancelada'};
    for(const op of result.operations){const row=element('div',op.id+' — '+(actions[op.action]||op.action)+' — '+(states[op.status]||op.status),'vini-operation-card');row.append(button('Ver informe',async()=>{const r=await request('/operations/'+op.id);status.textContent=JSON.stringify(r)}));
      if(op.action==='pause'&&['completed','cancelled'].includes(op.status))row.append(button('Revertir esta pausa',async()=>{const r=await request('/operations/'+op.id);return bulk('reverse_pause',r.scope,op.id)}));
      if(op.actor_id===principal.id&&['preview','running'].includes(op.status))row.append(button('Reanudar con confirmación',async()=>{const confirmation=await request('/operations/'+op.id+'/reconfirm','POST',{});if(confirm('Reanudar operación '+op.id+'\nCantidad: '+confirmation.total+'\nÁmbito: '+JSON.stringify(confirmation.scope)))return run(op.id,confirmation.confirmationToken)}));
      if(['preview','running'].includes(op.status))row.append(button('Cancelar pendientes',async()=>{if(confirm('¿Cancelar los lotes pendientes? Los ya aplicados se conservan y pueden revertirse por operación.')){await request('/operations/'+op.id+'/cancel','POST',{});await operations()}}));shell.append(row);
    }
  }
  async function administrators(){
    show();shell.append(element('h1','Administradores y ámbitos'));const list=await request('/administrators');
    for(const a of list.administrators){const row=element('div',a.username+' — '+a.role+' — '+(a.distributor_id||'sin distribuidor')+' — '+a.status);if(a.id!==principal.id&&a.id!=='legacy-super')row.append(button('Deshabilitar',async()=>{if(confirm('¿Deshabilitar esta cuenta administrativa?')){await request('/administrators/'+a.id+'/disable','POST',{});await administrators()}}));shell.append(row)}
    const form=element('form'),name=field(form,'Usuario'),password=field(form,'Contraseña (mínimo 14 caracteres)','password'),role=choice(form,'Rol',[['ADMIN','ADMIN'],['DISTRIBUTOR','DISTRIBUTOR'],['SUPER_ADMIN','SUPER_ADMIN']]),dist=field(form,'ID distribuidor (obligatorio para DISTRIBUTOR)'),actions=field(form,'Acciones separadas por coma: read,create,renew,pause,reactivate,revoke,archive'),scopes=field(form,'Ámbitos ADMIN: direct,distributor:UUID (separados por coma)');
    form.append(button('Crear administrador',async()=>{await request('/administrators','POST',{username:name.value,password:password.value,role:role.value,distributorId:dist.value||null,actions:actions.value.split(',').map(s=>s.trim()).filter(Boolean),scopes:scopes.value.split(',').map(s=>s.trim()).filter(Boolean)});password.value='';await administrators()}));shell.append(form);
  }
  async function retention(){
    show();const current=await request('/retention');shell.append(element('h1','Retención y purga'),element('p','No hay borrado automático. La purga requiere archivo previo, expiración vigente, retención y confirmación de SUPER_ADMIN. Conserva una fila mínima anonimizada para auditoría.'));
    const form=element('form'),days=field(form,'Días (mínimo 90)','number',current.days),enabled=choice(form,'Permitir purga manual',[['0','Deshabilitada'],['1','Habilitada']]);enabled.value=String(current.enabled);
    form.append(button('Guardar política',async()=>{if(confirm('¿Cambiar la política de retención?')){await request('/retention','PUT',{days:Number(days.value),enabled:enabled.value==='1'});await retention()}}));shell.append(form);
  }
  async function patchPolicy(){
    show();shell.append(element('h1','Permisos de patches'),element('p','PRO no concede asignaciones individuales. Combat/Visuals/Offsets no determinan el plan. Solo patches incorporados explícitamente usan esta política; los anteriores conservan sus derechos.'));
    const form=element('form'),patch=field(form,'ID remoto patch'),target=field(form,'ID estable target'),cap=choice(form,'Capacidad',[['patch.basic','BASIC + PRO'],['patch.pro','Solo PRO']]),dist=field(form,'ID distribuidor opcional'),compatible=choice(form,'Compatibilidad declarada',[['0','No verificada'],['1','Compatible']]),description=field(form,'Descripción de compatibilidad'),enabled=choice(form,'Disponibilidad',[['1','Habilitado'],['0','Deshabilitado']]),revoked=choice(form,'Revocación',[['0','No'],['1','Sí']]);
    form.append(button('Guardar política',async()=>{await request('/patch-policies','PUT',{patchId:patch.value,targetId:target.value,capabilityId:cap.value,distributorId:dist.value||null,enabled:enabled.value==='1',revoked:revoked.value==='1',compatible:compatible.value==='1',compatibilityDescription:description.value});status.textContent='Política guardada'}));shell.append(form);
  }
  const saved=sessionStorage.getItem(authKey);if(saved){token=saved;authenticate().catch(error=>{sessionStorage.removeItem(authKey);report(error)})}
  else if(token)authenticate().catch(report);
})();
