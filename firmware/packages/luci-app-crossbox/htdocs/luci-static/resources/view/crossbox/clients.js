'use strict';
'require crossbox-view as view';
'require poll';
'require crossbox as cb';
return view.extend({
 load(){return Promise.all([cb.api.hints(),cb.api.leases()]);},
 render(data){const content=E('div',{'class':'cb-scroll'}),search=E('input',{'type':'search','placeholder':cb.t('Name')+' / IP / MAC','aria-label':cb.t('Clients'),'value':new URLSearchParams(location.search).get('q')||''});let current=data;
  const draw=()=>{const hints=current[0]||{},leases=[...(current[1].dhcp_leases||[]),...(current[1].dhcp6_leases||[])],hosts=new Map();for(const [mac,h]of Object.entries(hints))hosts.set(mac.toLowerCase(),{mac,name:h.name,ips:[...(h.ipaddrs||[]),...(h.ip6addrs||[])]});for(const l of leases){const mac=(l.macaddr||l.duid||'').toLowerCase();if(!mac)continue;let h=hosts.get(mac)||{mac,name:l.hostname,ips:[]};if(l.ipaddr&&!h.ips.includes(l.ipaddr))h.ips.push(l.ipaddr);h.lease=l.expires;hosts.set(mac,h);}const q=search.value.toLowerCase();const rows=[E('tr',{},['Name','IP address','MAC address','Lease'].map(s=>E('th',{},cb.t(s))))];for(const h of hosts.values()){if(q&&!(h.name+' '+h.mac+' '+h.ips.join(' ')).toLowerCase().includes(q))continue;rows.push(E('tr',{},[E('td',{},h.name||cb.t('Unknown')),E('td',{},h.ips.join(', ')||'—'),E('td',{},h.mac),E('td',{},h.lease==null?'—':h.lease<0?'∞':cb.uptime(h.lease))]));}content.replaceChildren(E('table',{'class':'cb-table'},rows));if(rows.length===1)content.appendChild(E('div',{'class':'cb-empty'},cb.t('No devices reported')));};search.addEventListener('input',draw);draw();cb.poll(async()=>{if(!document.hidden){current=await this.load();draw();}},10);return E('div',{},[cb.heading('Clients'),cb.card('Network clients',E('div',{},[E('div',{'class':'cb-card-body'},search),content,E('p',{'class':'cb-footer-note'},cb.t('Device discovery combines neighbor records and DHCP leases. Sleeping devices may still appear.'))]))]);
 },handleSaveApply:null,handleSave:null,handleReset:null
});
