'use strict';
'require baseclass';
'require ui';
'require uci';
'require crossbox as cb';

const pages=new Set(['dashboard','clients','network','wifi','firewall','vpn','zapret','services','system','statistics','tools','temperature','updates']);
return baseclass.extend({
 started:false,
 async start(){
  if(this.started)return;this.started=true;
  if(!L.loaded)await new Promise(resolve=>document.addEventListener('luci-loaded',resolve,{once:true}));
  window.crossboxNavigate=(url,options)=>this.navigate(url,options);
  window.crossboxNativeDirty=(source,value)=>{if(document.querySelector('#view iframe')?.contentWindow===source){cb.dirty=value;if(value)cb.touch();}};
  document.addEventListener('click',e=>{
   const a=e.target.closest('a[href]');
   if(!a||e.defaultPrevented||e.button||e.ctrlKey||e.metaKey||e.shiftKey||e.altKey||a.target||a.hasAttribute('download')||a.getAttribute('href').startsWith('#'))return;
   const url=new URL(a.href,location.href);
   if(!this.accepts(url))return;e.preventDefault();this.navigate(url.href);
  });
  document.addEventListener('crossbox:saved',()=>{cb.dirty=false;});
  document.addEventListener('input',e=>{if(e.target.closest('#view .cb-form')&&e.target.type!=='search'&&!e.target.closest('[data-view-filter]')){cb.dirty=true;cb.touch();}});
  window.addEventListener('beforeunload',e=>{if(cb.dirty){e.preventDefault();e.returnValue='';}});
  window.addEventListener('popstate',()=>this.navigate(location.href,{replace:true,pop:true,force:true}));
  history.replaceState({crossbox:true},'',location.href);
  const requested=new URLSearchParams(location.search).get('open');let initial=new URL(location.href);
  try{const candidate=new URL(requested||location.href,location.origin);if(this.accepts(candidate))initial=candidate;}catch(e){}
  return this.navigate(initial.href,{replace:true,force:true});
 },
 accepts(url){return url.origin===location.origin&&(url.pathname===L.url('admin')||url.pathname.startsWith(L.url('admin')+'/'))&&!url.pathname.endsWith('/logout');},
 async navigate(href,options={}){
  if(cb.languageChanging){if(options.pop&&this.current)history.pushState({crossbox:true},'',this.current);return;}
  const url=new URL(href,location.href);url.searchParams.delete('crossbox_embed');if([L.url('admin'),L.url(),L.url('admin','crossbox')].includes(url.pathname.replace(/\/$/,'')))url.pathname=L.url('admin','crossbox','dashboard');if(!this.accepts(url)&&url.pathname!==L.url('admin')){location.assign(url.href);return;}
  if(!options.force&&url.href===location.href)return;
  if(cb.dirty&&!window.confirm(cb.t('Discard unsaved changes?'))){if(options.pop&&this.current)history.pushState({crossbox:true},'',this.current);return;}
  this.current=url.href;
  cb.dirty=false;const generation=cb.resetView(),target=document.getElementById('view');
  target.setAttribute('aria-busy','true');target.classList.add('cb-route-loading');
  if(!options.pop)history[options.replace?'replaceState':'pushState']({crossbox:true},'',url.href);
  const path=url.pathname.replace(/^.*\/cgi-bin\/luci\//,'').split('/').filter(Boolean);
  L.env.requestpath=path;L.env.dispatchpath=path;document.body.dataset.page=path.join('-');
  document.querySelectorAll('#tabmenu,.cbi-page-actions').forEach(el=>el.replaceChildren());
  try{
   await cb.loadMenu();
   if(generation!==cb.currentGeneration())return;
   const unavailable=url.searchParams.get('unavailable');
   const available=!unavailable&&cb.hasPage(path.join('/'));
   const page=path[0]==='admin'&&path[1]==='crossbox'?path[2]:null;
   if(!available){
    const missing=unavailable||path.join('/'),wireless=missing==='admin/network/wireless';
    // Keep fallback URLs server-registered so refreshing cannot resurrect a 404.
    url.pathname=L.url('admin/crossbox/dashboard');url.search='';url.searchParams.set('unavailable',missing);
    history.replaceState({crossbox:true},'',url.href);this.current=url.href;
    path.splice(0,path.length,'admin','crossbox','dashboard');L.env.requestpath=path;L.env.dispatchpath=path;document.body.dataset.page=path.join('-');
    target.replaceChildren(cb.heading(wireless?'Wi-Fi':'Page unavailable'),cb.card('Page unavailable',E('div',{'class':'cb-card-body'},[E('p',{},cb.t(wireless?'No wireless radio is available on this system.':'This page requires hardware, a package, or permissions that are not available on this system.')),cb.link('Back to dashboard','admin/crossbox/dashboard')])));
   }else if(pages.has(page)){
    // UCI is cached by LuCI. Reload committed values before remounting a form.
    for(const name of ['network','wireless','system','firewall'])uci.unload(name);
    const instance=await L.require('view.crossbox.'+page);
    if(generation!==cb.currentGeneration())return;
    await instance.mount(generation);
   }else{
    const frame=E('iframe',{'class':'cb-legacy-frame','title':cb.t('Advanced settings'),'data-crossbox-frame':'1'});
    url.searchParams.set('crossbox_embed','1');frame.src=url.href;
    target.replaceChildren(frame);
    await new Promise(resolve=>{frame.addEventListener('load',resolve,{once:true});});
   }
   if(generation!==cb.currentGeneration())return;
   document.dispatchEvent(new CustomEvent('crossbox:navigated',{detail:{path}}));
   window.scrollTo({top:0,behavior:'instant'});
  }catch(e){
   if(generation===cb.currentGeneration()){target.replaceChildren(E('div',{'class':'cb-empty cb-error'},[E('h2',{},cb.t('Unable to load this page')),E('p',{},e.message),cb.button('Retry',()=>this.navigate(location.href,{replace:true,force:true}))]));}
  }finally{if(generation===cb.currentGeneration()){target.removeAttribute('aria-busy');target.classList.remove('cb-route-loading');}}
 }
});
