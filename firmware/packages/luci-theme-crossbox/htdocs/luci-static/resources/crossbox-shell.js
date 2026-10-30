'use strict';
'require baseclass';

return baseclass.extend({
 __init__(){
  if(!document.body.classList.contains('cb-embedded')){
   L.require('crossbox-updates');
   // Native deep links enter the same app shell used by sidebar navigation.
   if(!location.pathname.includes('/admin/crossbox/')&&document.getElementById('view'))
    location.replace(L.url('admin/crossbox/dashboard')+'?open='+encodeURIComponent(location.pathname+location.search));
   else L.require('menu-crossbox');
   return;
  }
  const dirty=value=>window.parent.crossboxNativeDirty?.(window,value);
  for(const type of ['input','change'])document.addEventListener(type,e=>{
   if(e.target.closest('.cbi-map')&&e.target.type!=='search')dirty(true);
  });
  for(const type of ['uci-applied','uci-reverted'])document.addEventListener(type,()=>dirty(false));
  document.addEventListener('click',e=>{
   if(e.defaultPrevented||e.button||e.ctrlKey||e.metaKey||e.shiftKey||e.altKey)return;
   const a=e.target.closest('a[href]');
   if(!a||a.target||a.hasAttribute('download')||a.getAttribute('href').startsWith('#'))return;
   if(a.origin===location.origin&&a.pathname.startsWith(L.url('admin')+'/')&&!a.pathname.endsWith('/logout')){
    e.preventDefault();window.parent.crossboxNavigate?.(a.href);
   }
  });
 }
});
