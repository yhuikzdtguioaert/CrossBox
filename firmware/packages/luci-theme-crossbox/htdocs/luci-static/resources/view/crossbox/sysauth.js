'use strict';
'require view';
return view.extend({
 render(){
  const source=document.querySelector('section[hidden]'),form=source.querySelector('form'),button=source.querySelector('button');
  document.body.classList.add('cb-login-page');button.type='button';button.classList.add('cb-btn-primary');
  const brand=E('div',{'class':'cb-login-brand'},[E('img',{'src':L.env.media+'/logo.svg?v='+encodeURIComponent(window.crossboxAssetVersion||L.env.resource_version||'0'),'alt':''}),E('span',{},['Cross',E('b',{},'Box')])]);
  const panel=E('section',{'class':'cb-login-card'},[brand,E('p',{'class':'cb-login-caption'},document.documentElement.lang.startsWith('ru')?'Вход в панель управления':'Sign in to your router'),...Array.from(source.children)]);
  const submit=()=>{if(button.disabled||!form.reportValidity())return;button.disabled=true;button.textContent=_('Logging in…');form.submit();};
  form.addEventListener('keydown',e=>{if(e.key==='Enter'){e.preventDefault();submit();}});button.addEventListener('click',submit);
  requestAnimationFrame(()=>panel.querySelector('input[type=password]')?.focus());
  return E('div',{'class':'cb-login-shell'},panel);
 },addFooter(){}
});
