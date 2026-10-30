'use strict';
'require crossbox-view as view';
'require uci';
'require rpc';
'require ui';
'require crossbox as cb';
const reboot=rpc.declare({object:'system',method:'reboot'});
return view.extend({
 load(){return Promise.all([cb.api.board(),uci.load('system'),cb.api.telemetry()]);},
 render(data){const board=data[0],sys=uci.sections('system','system')[0],hostname=E('input',{'value':sys?.hostname||board.hostname,'maxlength':'63'}),links=[['Administration','admin/system/admin'],['Software','admin/system/package-manager'],['Backup and upgrade','admin/system/flash'],['System log','admin/status/logs/syslog'],['Diagnostics','admin/crossbox/tools']];const values=E('dl',{'class':'cb-kv'});for(const [key,value]of [['Device model',board.model],['Firmware',data[2].firmware||board.release?.description],['Base system',board.release?.description],['Kernel',board.kernel],['Processor',board.system]])values.append(E('dt',{},cb.t(key)),E('dd',{},value||'—'));
 return E('div',{'class':'cb-form'},[cb.heading('System'),cb.card('System information',E('div',{'class':'cb-card-body'},[values,E('hr'),cb.field('Hostname',hostname),E('div',{'class':'cb-actions'},[cb.button('Apply changes',async()=>{if(!/^[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$/.test(hostname.value))throw new Error('Invalid hostname');uci.set('system',sys['.name'],'hostname',hostname.value);await uci.save();await ui.changes.apply(true);},true),cb.button('Restart router',()=>ui.showModal(cb.t('Restart router'),[E('p',{},cb.t('Restart router')+'?'),E('div',{'class':'cb-actions'},[E('button',{'class':'btn','click':ui.hideModal},_('Cancel')),cb.button('Restart router',async()=>{await reboot();ui.hideModal();ui.awaitReconnect(board.hostname+'.lan');},true)])]))])])),E('div',{'style':'height:16px'}),cb.card('Advanced settings',E('div',{'class':'cb-card-body cb-actions'},links.filter(([title,path])=>cb.hasPage(path)).map(([title,path])=>cb.link(title,path))))]);
 },handleSaveApply:null,handleSave:null,handleReset:null
});
