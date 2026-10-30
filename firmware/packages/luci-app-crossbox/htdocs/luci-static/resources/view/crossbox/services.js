'use strict';
'require crossbox-view as view';
'require poll';
'require rpc';
'require crossbox as cb';
const list=rpc.declare({object:'rc',method:'list'}),action=rpc.declare({object:'rc',method:'init',params:['name','action']});
const protectedServices=new Set(['boot','done','network','rpcd','uhttpd','system','log','urandom_seed','sysfixtime']);
return view.extend({
 load(){return list();},
 render(data){const content=E('div'),search=E('input',{'type':'search','placeholder':cb.t('Search services'),'aria-label':cb.t('Search services')});let services=data,busy=false;
  const apply=async(name,op)=>{busy=true;try{const r=await action(name,op);if(r)throw new Error(cb.t('Operation failed'));services=await list();draw();}finally{busy=false;}};
  const draw=()=>{content.replaceChildren();for(const [name,s]of Object.entries(services).sort((a,b)=>a[0].localeCompare(b[0]))){if(name==='error'||search.value&&!name.includes(search.value.trim()))continue;const special=name==='crossbox-vpn'||name==='crossbox-zapret',protectedService=protectedServices.has(name);let controls;
    if(special)controls=E('a',{'class':'btn','href':L.url('admin/crossbox/'+(name==='crossbox-vpn'?'vpn':'zapret'))},cb.t('Open')+' ↗');
    else if(protectedService)controls=E('span',{'class':'cb-subtitle'},cb.t('System service'));
    else controls=E('div',{'class':'cb-actions'},[cb.button(s.running?'Stop':'Start',()=>apply(name,s.running?'stop':'start'),!s.running),cb.button('Restart',()=>apply(name,'restart')),cb.button(s.enabled?'Disable autostart':'Enable autostart',()=>apply(name,s.enabled?'disable':'enable'))]);
    content.appendChild(E('div',{'class':'cb-row'},[E('span',{'class':'cb-row-icon'},cb.icon('router')),E('div',{'class':'cb-row-details'},[E('strong',{},name),E('div',{},[E('span',{'class':'cb-chip'},cb.t(s.enabled?'Autostart enabled':'Autostart disabled')),typeof s.running==='boolean'?' · '+cb.t(s.running?'Process running':'No background process'):''])]),controls]));}
  };search.addEventListener('input',draw);draw();cb.poll(async()=>{if(!document.hidden&&!busy){services=await list();draw();}},10);return E('div',{},[cb.heading('Services'),cb.card('Services',E('div',{},[E('div',{'class':'cb-card-body'},search),content,E('div',{'class':'cb-card-body'},cb.link('Advanced settings','admin/system/startup'))]))]);
 },handleSaveApply:null,handleSave:null,handleReset:null
});
