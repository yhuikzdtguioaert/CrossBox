'use strict';
'require crossbox-view as view';
'require ui';
'require crossbox as cb';

const phases={checking:'Checking for updates',no_release:'No published releases yet',current:'Your firmware is up to date',available:'Update available',downloading:'Downloading firmware',validating:'Validating firmware',installing:'Installing firmware',error:'Update check failed'};
return view.extend({
 load(){return cb.api.updateStatus();},
 render(initial){
  let state=initial,busy=false;
  const status=E('div'),version=E('dl',{'class':'cb-kv'}),details=E('div'),automatic=E('input',{'type':'checkbox'});
  const check=cb.button('Check for updates',async()=>{cb.check(await cb.api.updateAction('check'));status.textContent=cb.t('Checking for updates');},true);
  const install=cb.button('Install update',()=>ui.showModal(cb.t('Install update'),[
   E('p',{},cb.t('The router will reboot. Do not disconnect its power during installation. Your settings will be preserved.')),
   E('div',{'class':'right'},[E('button',{'class':'btn','click':()=>ui.hideModal()},cb.t('Cancel')),cb.button('Install update',async()=>{cb.check(await cb.api.updateAction('install'));ui.hideModal();},true)])
  ]));
  const draw=()=>{
   status.replaceChildren(E('strong',{'class':state.phase==='error'?'cb-error':''},cb.t(phases[state.phase]||'Not checked yet')));
   version.replaceChildren();
   for(const [label,value]of [['Installed version',state.current],['Latest version',state.available?.version],['Last checked',state.checked_at?new Date(state.checked_at*1000).toLocaleString(document.documentElement.lang):null]])version.append(E('dt',{},cb.t(label)),E('dd',{},value||'—'));
   automatic.checked=!!state.automatic;
   const working=['checking','downloading','validating','installing'].includes(state.phase);
   check.disabled=working;install.disabled=!state.supported||!state.available||working;
   details.replaceChildren();
   if(!state.supported)details.appendChild(E('p',{'class':'cb-warning'},cb.t('Automatic updates require a supported physical router.')));
   if(state.error)details.appendChild(E('p',{'class':'cb-error'},state.error));
   if(state.retry_blocked)details.appendChild(E('p',{'class':'cb-warning'},cb.t('Automatic retry paused after a previous installation attempt. You can retry manually.')));
   if(state.supported&&state.automatic&&state.available&&state.install_at&&!state.retry_blocked)details.appendChild(E('p',{'class':'cb-subtitle'},cb.t('Automatic installation scheduled for')+' '+new Date(state.install_at*1000).toLocaleString(document.documentElement.lang)));
   if(state.available)details.appendChild(E('a',{'href':'https://github.com/yhuikzdtguioaert/CrossBox/releases/tag/'+encodeURIComponent(state.available.tag),'target':'_blank','rel':'noopener noreferrer'},cb.t('Release notes')));
  };
  automatic.addEventListener('change',async()=>{busy=true;automatic.disabled=true;try{cb.check(await cb.api.updateSettings(automatic.checked));state=await cb.api.updateStatus();draw();cb.notify('Update settings saved');}catch(e){automatic.checked=!!state.automatic;ui.addNotification(null,E('p',{},e.message),'error');}finally{busy=false;automatic.disabled=false;}});
  draw();cb.poll(async()=>{if(!document.hidden&&!busy){state=await cb.api.updateStatus();draw();}},3);
  return E('div',{},[
   cb.heading('Updates','Firmware updates'),
   cb.card('Firmware updates',E('div',{'class':'cb-card-body'},[status,E('hr'),version,details,E('div',{'class':'cb-actions'},[check,install])])),
   E('div',{'style':'height:20px'}),
   cb.card('Automatic installation',E('div',{'class':'cb-card-body'},[E('label',{'class':'cb-toggle'},[automatic,cb.t('Automatic installation')]),E('p',{'class':'cb-subtitle'},cb.t('A newer stable release will install automatically. Settings are preserved; Internet access will pause during reboot.')),E('a',{'href':'https://github.com/yhuikzdtguioaert/CrossBox/releases','target':'_blank','rel':'noopener noreferrer'},cb.t('Repository'))]))
  ]);
 },handleSaveApply:null,handleSave:null,handleReset:null
});
