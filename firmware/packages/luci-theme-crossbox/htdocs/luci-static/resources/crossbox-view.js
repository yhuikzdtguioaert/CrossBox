'use strict';
'require view';
'require baseclass';
'require crossbox as cb';

// CrossBox routes mount explicitly; importing a cached view must not render it twice.
const lifecycle={
 __init__(){},
 async mount(generation){
  const data=await this.load();
  if(generation!==cb.currentGeneration())return;
  const nodes=await this.render(data);
  if(generation!==cb.currentGeneration())return;
  const target=document.getElementById('view');
  target.replaceChildren(nodes);
  const footer=this.addFooter();if(footer)target.appendChild(footer);
 }
};
return baseclass.extend({extend(properties){return view.extend(Object.assign({},lifecycle,properties));}});
