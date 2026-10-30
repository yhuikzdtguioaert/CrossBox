'use strict';
'require crossbox-view as view';
'require crossbox as cb';

function baseName(name){return name.replace(/\s+\(\d+\)$/,'').trim();}
return view.extend({
 load(){return Promise.all([cb.api.vpnGet(),cb.api.vpnStatus()]);},
 render(data){
  let config=data[0].config,status=data[1],busy=false,testToken=0,previousSelected=null,root;const expanded=new Set();
  const url=E('input',{'type':'password','autocomplete':'off','spellcheck':'false','placeholder':'https://…','value':config.subscription||''}),profile=E('textarea',{'spellcheck':'false','autocomplete':'off','rows':'7'},config.profile||''),agent=E('input',{'value':config.user_agent||'Happ/3.0.0'}),mode=E('select',{},['domains','all','proxy'].map((v,i)=>E('option',{'value':v},cb.t(['Only selected domains','All Internet traffic','Local proxy only'][i])))),domains=E('textarea',{'rows':'4'},(config.domains||[]).join('\n'));mode.value=config.mode||'proxy';
  const state=E('div'),selected=E('div',{'class':'cb-selected-server'}),result=E('div',{'role':'status','class':'cb-subtitle'}),list=E('div',{'class':'cb-server-groups'}),count=E('span',{'class':'cb-subtitle'}),search=E('input',{'type':'search','class':'cb-server-search','placeholder':cb.t('Search country, server or address'),'aria-label':cb.t('Search servers')}),protocol=E('select',{'aria-label':cb.t('Protocol')},E('option',{'value':''},cb.t('All protocols'))),sort=E('select',{'aria-label':cb.t('Sort servers')},[E('option',{'value':'name'},cb.t('By name')),E('option',{'value':'delay'},cb.t('By latency'))]);
  const collect=enabled=>Object.assign({},config,{enabled,subscription:url.value.trim(),profile:profile.value,user_agent:agent.value.trim(),mode:mode.value,domains:cb.domains(domains.value)});
  const save=async(enabled,keepSaved)=>{if(busy)throw new Error(cb.t('Working…'));busy=true;const owner=cb.currentGeneration(),revision=cb.revision();root.inert=true;try{const next=keepSaved?Object.assign({},config,{enabled}):collect(enabled);cb.check(await cb.api.vpnSave(JSON.stringify(next)));config=next;if(!keepSaved&&owner===cb.currentGeneration()&&revision===cb.revision())cb.dirty=false;update(await cb.api.vpnStatus());cb.notify('Configuration saved');}finally{busy=false;root.inert=false;}};
  const toggle=cb.button(config.enabled?'Stop':'Start',()=>save(!config.enabled,config.enabled),true);toggle.classList.add('cb-service-toggle');
  const choose=async name=>{if(busy)throw new Error(cb.t('Working…'));busy=true;try{cb.check(await cb.api.vpnSelect(name));update(await cb.api.vpnStatus());}finally{busy=false;}};
  const visible=()=>{const q=search.value.toLocaleLowerCase();let nodes=(status.nodes||[]).filter(n=>(!protocol.value||n.type===protocol.value)&&(!q||[n.name,n.type,n.endpoint,n.transport].join(' ').toLocaleLowerCase().includes(q)));if(sort.value==='delay')nodes=[...nodes].sort((a,b)=>(a.delay>0?a.delay:Infinity)-(b.delay>0?b.delay:Infinity));else nodes=[...nodes].sort((a,b)=>a.name.localeCompare(b.name,document.documentElement.lang,{numeric:true})||(a.endpoint||'').localeCompare(b.endpoint||''));return nodes;};
  const draw=()=>{
   const nodes=visible(),groups=new Map();for(const n of nodes){const key=baseName(n.name)+'\0'+n.type;if(!groups.has(key))groups.set(key,[]);groups.get(key).push(n);}
   list.replaceChildren();count.textContent=nodes.length+' / '+(status.nodes||[]).length+' '+cb.t('servers');
   for(const[key,items]of groups){
    const chosen=items.some(n=>n.name===status.selected),details=E('details',{'class':'cb-server-group'});details.open=expanded.has(key)||(!!search.value&&nodes.length<=12);
    const summary=E('summary',{},[E('span',{'class':'cb-server-orb'},cb.icon('globe')),E('span',{'class':'cb-server-title'},baseName(items[0].name)),E('span',{'class':'cb-chip'},items[0].type),E('span',{'class':'cb-server-count'},String(items.length)),chosen?E('span',{'class':'cb-state'},cb.t('Selected')):null,cb.icon('chevron')]);
    const body=E('div',{'class':'cb-server-options'});
    const populate=()=>{body.replaceChildren();if(!details.open)return;for(const[nIndex,n]of items.entries()){
     const active=n.name===status.selected,latency=n.delay>0?n.delay+' ms':cb.t(n.alive===false?'Unreachable':'Not tested');
     body.appendChild(E('div',{'class':'cb-server-option'+(active?' is-selected':'')},[E('div',{'class':'cb-server-endpoint'},[E('strong',{},n.endpoint||cb.t('Variant')+' '+(nIndex+1)),E('small',{},n.transport||n.type)]),E('span',{'class':'cb-server-latency'+(n.delay>0?' is-good':'')},latency),cb.button('Check',async()=>{const r=await cb.api.vpnProbe(n.name);update(await cb.api.vpnStatus());cb.check(r);}),active?E('span',{'class':'cb-selected-mark'},'✓'):cb.button('Connect',()=>choose(n.name),true)]));
    }};
    details.addEventListener('toggle',()=>{if(details.open)expanded.add(key);else expanded.delete(key);populate();});details.append(summary,body);populate();list.appendChild(details);
   }
   if(!nodes.length)list.appendChild(E('div',{'class':'cb-empty'},cb.t(status.nodes?.length?'No matching servers':'Import a subscription and start VPN to load servers.')));
  };
  const update=s=>{
   if(s.selected&&s.selected!==previousSelected){const n=s.nodes?.find(n=>n.name===s.selected);if(n)expanded.add(baseName(n.name)+'\0'+n.type);}previousSelected=s.selected;status=s;state.replaceChildren(E('span',{'class':'cb-state'+(s.running?'':' off')},cb.t(s.running?'Engine running':'Engine stopped')));if(s.error)state.appendChild(E('p',{'class':'cb-error'},s.error));
   const n=s.nodes?.find(n=>n.name===s.selected);selected.replaceChildren(E('span',{'class':'cb-subtitle'},cb.t('Selected server')),E('strong',{},n?baseName(n.name):cb.t('No server selected')),E('span',{'class':'cb-subtitle'},n?[n.type,n.endpoint,n.delay>0?n.delay+' ms':''].filter(Boolean).join(' / '):cb.t('Add your subscription below')));
   const old=protocol.value;protocol.replaceChildren(E('option',{'value':''},cb.t('All protocols')),...[...new Set((s.nodes||[]).map(n=>n.type))].sort().map(p=>E('option',{'value':p},p)));protocol.value=old;toggle.textContent=cb.t(config.enabled?'Stop':'Start');draw();
  };
  const testVisible=cb.button('Check visible servers',async()=>{
   if(busy)return;busy=true;const token=++testToken,owner=cb.currentGeneration(),nodes=visible().slice(0,12);cancel.hidden=false;
   try{for(let i=0;i<nodes.length&&token===testToken&&owner===cb.currentGeneration();i++){result.textContent=cb.t('Checking servers')+' '+(i+1)+' / '+nodes.length;await cb.api.vpnProbe(nodes[i].name);}update(await cb.api.vpnStatus());result.textContent=cb.t(token===testToken?'Server checks complete':'Server checks cancelled');}finally{busy=false;cancel.hidden=true;}
  });
  const cancel=cb.button('Cancel',()=>{testToken++;});cancel.hidden=true;
  const fastest=cb.button('Use fastest checked',()=>{const best=(status.nodes||[]).filter(n=>n.alive!==false&&n.delay>0).sort((a,b)=>a.delay-b.delay)[0];if(!best)throw new Error(cb.t((status.nodes||[]).some(n=>n.alive===false||n.delay===0)?'No servers passed the HTTPS check':'Check servers first'));return choose(best.name);});
  for(const el of [search,protocol,sort])el.addEventListener(el===search?'input':'change',draw);
  const domainField=cb.field('Domains',domains,'One hostname per line, without https:// or paths. Subdomains are included.');const modeChanged=()=>{domainField.hidden=mode.value!=='domains';};mode.addEventListener('change',modeChanged);modeChanged();
  update(status);cb.poll(async()=>{if(!document.hidden&&!busy)update(await cb.api.vpnStatus());},10);
  const settings=E('details',{'class':'cb-settings-panel'},[E('summary',{},[cb.icon('network'),cb.t('Subscription and routing'),cb.icon('chevron')]),E('div',{'class':'cb-card-body'},[cb.field('Subscription URL',url),cb.field('Routing',mode),domainField,E('details',{},[E('summary',{},cb.t('Import profile')),cb.field('Import profile',profile,'Paste share links, Base64 subscription, Clash YAML / JSON, or Xray JSON.'),cb.field('User-Agent',agent)]),E('div',{'class':'cb-actions'},[cb.button('Save and apply',()=>save(config.enabled),true),cb.button('Update subscription',async()=>{busy=true;try{cb.check(await cb.api.vpnRefresh());update(await cb.api.vpnStatus());}finally{busy=false;}})]),E('p',{'class':'cb-subtitle'},cb.t('Subscriptions and keys are stored on the router with restricted permissions.'))])]);
  if(!config.subscription&&!config.profile)settings.open=true;
  return root=E('div',{'class':'cb-form cb-vpn-page'},[cb.heading('VPN client','Choose where your connection goes'),E('section',{'class':'cb-connection-panel'},[E('div',{'class':'cb-connection-state'},[cb.icon('globe'),state]),selected,E('div',{'class':'cb-actions'},[toggle,cb.button('Test connection',async()=>{result.textContent=cb.t('Working…');const r=await cb.api.vpnTest();result.textContent=r.ok?cb.t('Connection successful')+' / '+r.result:cb.t('Operation failed')+': '+r.error;}),result])]),settings,cb.card('Servers',E('div',{},[E('div',{'class':'cb-server-toolbar','data-view-filter':'1'},[search,protocol,sort,count]),E('div',{'class':'cb-card-body cb-actions'},[testVisible,fastest,cancel,E('small',{'class':'cb-subtitle'},cb.t('Checks up to 12 filtered servers at a time.'))]),list])),E('p',{'class':'cb-subtitle'},cb.t('Encryption consumes CPU. Selective routing reduces load; direct traffic bypasses the VPN.'))]);
 },handleSaveApply:null,handleSave:null,handleReset:null
});
