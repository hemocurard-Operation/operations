// Canonical component codes already used by the production workflow.
// Supplies and commercial products belong to their own catalogs.
export const BLOOD_COMPONENTS=Object.freeze([
 {code:'SANGRE_TOTAL',label:'Sangre total'},
 {code:'CONCENTRADO_HEMATIES',label:'Concentrado de hematíes (paquete globular)'},
 {code:'PLASMA_FRESCO_CONGELADO',label:'Plasma fresco congelado'},
 {code:'PLAQUETAS',label:'Plaquetas'},
 {code:'CRIOPRECIPITADO',label:'Crioprecipitado'}
].map(Object.freeze));
export const isBloodComponent=code=>BLOOD_COMPONENTS.some(c=>c.code===code);
export const bloodComponentLabel=code=>BLOOD_COMPONENTS.find(c=>c.code===code)?.label||code;
