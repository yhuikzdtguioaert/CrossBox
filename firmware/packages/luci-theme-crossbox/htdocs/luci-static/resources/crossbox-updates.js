'use strict';
'require baseclass';
'require ui';
'require poll';
'require crossbox as cb';

// This module is loaded only by the authenticated outer shell, never the login page or iframe.
return baseclass.extend({
 __init__(){
  let announced=null,reconnecting=false;
  const refresh=async()=>{
   if(document.hidden)return;
   const state=await cb.api.updateStatus();
   if(state.supported&&state.phase==='installing'&&!reconnecting){reconnecting=true;ui.showModal(cb.t('Installing firmware'),[E('p',{'class':'spinning'},cb.t('The router will reboot. Do not disconnect its power during installation. Your settings will be preserved.'))]);ui.awaitReconnect();return;}
   const available=state.supported&&state.available;
   for(const a of document.querySelectorAll('#topmenu a[href$="/crossbox/updates"]')){
    a.querySelector('.cb-update-dot')?.remove();
    if(available)a.appendChild(E('span',{'class':'cb-update-dot','aria-label':cb.t('Update available')},'•'));
   }
   if(!available||state.phase!=='available'||announced===state.available.tag||document.body.classList.contains('modal-overlay-active'))return;
   announced=state.available.tag;
   ui.showModal(cb.t('Update available'),[
    E('p',{},cb.t('A new CrossBox version is available.')+' '+state.current+' → '+state.available.version),
    state.automatic?E('p',{'class':'cb-warning'},cb.t('A newer stable release will install automatically. Settings are preserved; Internet access will pause during reboot.')):null,
    E('div',{'class':'right'},[
     E('button',{'class':'btn','click':()=>ui.hideModal()},cb.t('Later')),
     E('button',{'class':'btn primary','click':()=>{ui.hideModal();window.crossboxNavigate?.(L.url('admin/crossbox/updates'));}},cb.t('View update'))
    ])
   ]);
  };
  // One document-wide callback survives route transitions; it never performs network downloads.
  poll.add(()=>refresh().catch(()=>{}),30);
 }
});
