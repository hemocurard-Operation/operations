import {withLocalOCR} from './image-ocr.js';
import {PHOTO_GROUPS,PHOTO_FIELDS} from './daily-photo-domain.js';
import {quadProjector,prepareInkCell,agreedDigits,blueInk} from './inventory-ocr-domain.js';
export function rectifyInventoryGrid(source,points,columnSplit=.5){
 if(!Number.isFinite(columnSplit)||columnSplit<.25||columnSplit>.75)throw Error('La separación entre columnas debe estar entre 25% y 75%.');
 const project=quadProjector(points),width=640,height=1024,ctx=source.getContext('2d',{willReadFrequently:true}),original=ctx.getImageData(0,0,source.width,source.height),canvas=document.createElement('canvas');canvas.width=width;canvas.height=height;const target=canvas.getContext('2d'),out=target.createImageData(width,height);
 for(let y=0;y<height;y++)for(let x=0;x<width;x++){const t=x/(width-1),u=t<=.5?t*2*columnSplit:columnSplit+(t-.5)*2*(1-columnSplit),p=project(u,y/(height-1));const sx=Math.max(0,Math.min(source.width-1,Math.round(p.x*(source.width-1)))),sy=Math.max(0,Math.min(source.height-1,Math.round(p.y*(source.height-1)))),i=(sy*source.width+sx)*4,j=(y*width+x)*4;out.data[j]=original.data[i];out.data[j+1]=original.data[i+1];out.data[j+2]=original.data[i+2];out.data[j+3]=255;}
 target.putImageData(out,0,0);return canvas;
}
function digitCanvas(cell,width,height){
 const canvas=document.createElement('canvas');canvas.width=240;canvas.height=140;const ctx=canvas.getContext('2d');ctx.fillStyle='white';ctx.fillRect(0,0,240,140);if(cell.blank)return canvas;
 const {minX,minY,maxX,maxY}=cell.bounds,w=maxX-minX+1,h=maxY-minY+1,small=document.createElement('canvas');small.width=w;small.height=h;const sc=small.getContext('2d'),img=sc.createImageData(w,h);for(let y=0;y<h;y++)for(let x=0;x<w;x++){const j=(y*w+x)*4,v=cell.mask[(y+minY)*width+x+minX]?0:255;img.data[j]=img.data[j+1]=img.data[j+2]=v;img.data[j+3]=255;}sc.putImageData(img,0,0);const scale=Math.min(190/w,100/h);ctx.imageSmoothingEnabled=false;ctx.drawImage(small,0,0,w,h,(240-w*scale)/2,(140-h*scale)/2,w*scale,h*scale);small.width=small.height=0;return canvas;
}
export async function readInventoryGrid(source,points,{signal,onProgress=()=>{},inkMode='auto',columnSplit=.5}={}){
 const grid=rectifyInventoryGrid(source,points,columnSplit),ctx=grid.getContext('2d',{willReadFrequently:true}),all=ctx.getImageData(0,0,640,1024).data;let blue=0;for(let i=0;i<all.length;i+=4)if(blueInk(all[i],all[i+1],all[i+2]))blue++;
 const mode=inkMode==='auto'?(blue>300?'blue':'dark'):inkMode;const cells={},inventory={},prepared=[];for(let r=0;r<8;r++)for(let c=0;c<2;c++)prepared.push(prepareInkCell(ctx.getImageData(c*320,r*128,320,128).data,320,128,mode));
 const readCells=async(worker,aborted)=>{
  let processed=0;for(let row=0;row<8;row++)for(let col=0;col<2;col++){
   aborted();const group=PHOTO_GROUPS[row],field=PHOTO_FIELDS[col][0],ink=prepared[row*2+col],canvas=digitCanvas(ink,320,128);let value=null,reason='Sin tinta legible',confidence=null;
   if(!ink.blank){const readings=[];for(const psm of ['8','13']){aborted();await worker.setParameters({tessedit_char_whitelist:'0123456789',tessedit_pageseg_mode:psm,preserve_interword_spaces:'1'});const r=await worker.recognize(canvas);aborted();readings.push({text:r.data.text,confidence:r.data.confidence});}
    value=agreedDigits(readings);confidence=Math.min(...readings.map(r=>r.confidence));reason=value===null?'Lectura dudosa; completar manualmente':'Dos lecturas coinciden; revisar';
   }
   (cells[group]??={})[field]={value,reason,confidence,preview:canvas.toDataURL('image/png')};if(value!==null)(inventory[group]??={})[field]=value;canvas.width=canvas.height=0;processed++;onProgress(`Leyendo celda ${processed}/16 · ${group} · ${PHOTO_FIELDS[col][1]}`);
  }
  return {inventory,cells,text:'Lectura del cuadro seleccionado por celdas. Modo: '+(mode==='blue'?'tinta azul':'contraste oscuro')+'. Las celdas vacías o dudosas no se importan.',date:null};
 };try{return prepared.every(c=>c.blank)?await readCells(null,()=>{if(signal?.aborted)throw new DOMException('Lectura cancelada','AbortError')}):await withLocalOCR(readCells,{signal,onProgress})}finally{grid.width=grid.height=0}
}
