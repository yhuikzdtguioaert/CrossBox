'use strict';
'require crossbox-view as view';
'require rpc';
'require crossbox as cb';
const diagnostic=rpc.declare({object:'crossbox',method:'diagnostic',params:['action','host']});
return view.extend({
 render(){const host=E('input',{'type':'text','placeholder':'example.com / 1.1.1.1','autocomplete':'off','spellcheck':'false','aria-label':cb.t('Hostname or IP address')}),output=E('pre',{'class':'cb-diagnostic-output','role':'status'},cb.t('Run a diagnostic to see the result.'));let busy=false;
  const run=async(action)=>{if(busy)return;busy=true;output.textContent=cb.t('Working…');try{const r=cb.check(await diagnostic(action,host.value.trim()));output.textContent=r.output||cb.t('No output');output.classList.toggle('cb-error',!!r.code);}finally{busy=false;}};
  return E('div',{'class':'cb-form'},[cb.heading('Tools','Diagnostics'),cb.card('Diagnostics',E('div',{'class':'cb-card-body'},[cb.field('Hostname or IP address',host),E('div',{'class':'cb-actions'},[cb.button('Ping',()=>run('ping'),true),cb.button('DNS lookup',()=>run('lookup')),cb.button('Trace route',()=>run('trace'))]),E('p',{'class':'cb-subtitle'},cb.t('Commands run on the router and stop after 12 seconds.')),output,cb.link('Advanced settings','admin/network/diagnostics')]))]);
 },handleSaveApply:null,handleSave:null,handleReset:null
});
