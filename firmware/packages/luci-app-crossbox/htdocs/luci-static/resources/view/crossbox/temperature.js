'use strict';
'require crossbox-view as view';
'require crossbox as cb';

return view.extend({
 load(){return cb.api.telemetry();},
 render(initial){
  const grid=E('div',{'class':'cb-temperature-grid'}),note=E('p',{'class':'cb-hardware-note'}),history=new Map();
  const update=data=>{
   grid.replaceChildren();
   for(const sensor of data.sensors||[]){
    const samples=history.get(sensor.id)||[];samples.push(sensor.celsius);if(samples.length>120)samples.shift();history.set(sensor.id,samples);
    const ns='http://www.w3.org/2000/svg',chart=document.createElementNS(ns,'svg');chart.setAttribute('viewBox','0 0 400 100');chart.setAttribute('class','cb-sensor-chart');chart.setAttribute('role','img');chart.setAttribute('aria-label',cb.t('Temperature history'));
    if(samples.length>1){const min=Math.min(...samples)-2,max=Math.max(...samples)+2,line=document.createElementNS(ns,'path');line.setAttribute('d','M'+samples.map((v,i)=>(400*i/(samples.length-1)).toFixed(1)+','+(90-(v-min)/(max-min)*80).toFixed(1)).join(' L'));line.setAttribute('fill','none');line.setAttribute('stroke','currentColor');line.setAttribute('stroke-width','2');chart.appendChild(line);}
    grid.appendChild(cb.card(sensor.name,E('div',{'class':'cb-card-body'},[E('div',{'class':'cb-sensor-value'},sensor.celsius.toFixed(1)+' °C'),E('p',{'class':'cb-muted'},sensor.driver),chart])));
   }
   note.textContent=cb.t(data.sensors?.length?'Readings come directly from the hardware sensors. History stays in this browser tab.':'No temperature sensor is exposed by this hardware. Virtual machines usually do not provide thermal sensors.');
   if(!data.sensors?.length)grid.appendChild(E('div',{'class':'cb-empty'},[cb.icon('temperature'),E('h2',{},cb.t('Temperature unavailable')),E('p',{},cb.t('No hardware sensor detected'))]));
  };
  update(initial);cb.poll(async()=>{if(!document.hidden)update(await cb.api.telemetry());},5);
  return E('div',{},[cb.heading('Temperature','Updated every 5 seconds'),grid,note]);
 },handleSaveApply:null,handleSave:null,handleReset:null
});
