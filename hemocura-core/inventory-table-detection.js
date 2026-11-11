import {withLocalOCR} from './image-ocr.js';
import {blueInk,validateQuad} from './inventory-ocr-domain.js';
const median=values=>{const v=[...values].sort((a,b)=>a-b);return v[Math.floor(v.length/2)]};
const norm=s=>String(s||'').normalize('NFD').replace(/[\u0300-\u036f]/g,'').toUpperCase();
export function inventoryHeadings(blocks){
 const words=[];for(const block of blocks||[])for(const paragraph of block.paragraphs||[])for(const line of paragraph.lines||[])for(const word of line.words||[])if(word.bbox)words.push(word);
 const groups=words.map(w=>({group:norm(w.text).replace(/[\s.]/g,''),...w.bbox})).filter(g=>/^(AB|A|B|O)[+-]$/.test(g.group));
 const result=[];for(const a of words){if(!/^UNIDADES$/.test(norm(a.text).trim()))continue;const ah=a.bbox.y1-a.bbox.y0,b=words.find(w=>/^DISPONIBLES[.:]?$/.test(norm(w.text).trim())&&w.bbox.x0>=a.bbox.x1-2&&w.bbox.x0-a.bbox.x1<ah*4&&Math.abs((w.bbox.y0+w.bbox.y1-a.bbox.y0-a.bbox.y1)/2)<ah*.8);if(b)result.push({x0:a.bbox.x0,y0:Math.min(a.bbox.y0,b.bbox.y0),x1:b.bbox.x1,y1:Math.max(a.bbox.y1,b.bbox.y1),groups})}
 return result.filter((a,i)=>!result.slice(0,i).some(b=>Math.abs(a.y0-b.y0)<8&&Math.abs(a.x0-b.x0)<20));
}
function clusters(items,distance,coordinate,score){const out=[];let current=[];for(const item of [...items].sort((a,b)=>coordinate(a)-coordinate(b))){if(current.length&&coordinate(item)-coordinate(current[current.length-1])>distance){out.push(current.sort((a,b)=>score(b)-score(a))[0]);current=[]}current.push(item)}if(current.length)out.push(current.sort((a,b)=>score(b)-score(a))[0]);return out}
function intersect(h,v,cx,cy){const x=(v.x+v.slope*(h.y-cy-h.slope*cx))/(1-v.slope*h.slope);return {x,y:h.y+h.slope*(x-cx)}}
// Header-anchored geometry only: this never reads or returns quantities.
export function tableCandidatesFromPixels(image,headings,{checkAbort=()=>{}}={}){
 const {width,height,data}=image,result=[];
 for(const heading of headings){checkAbort();const hw=heading.x1-heading.x0;if(hw<35)continue;const cx=(heading.x0+heading.x1)/2,x0=Math.max(1,Math.floor(cx-hw*.9)),x1=Math.min(width-2,Math.ceil(cx+hw*.9)),y0=Math.max(1,Math.floor(heading.y1+2)),y1=Math.min(height-2,Math.ceil(heading.y1+hw*2.5));
  const histogram=new Uint32Array(256);let count=0;for(let y=y0;y<y1;y+=4)for(let x=x0;x<x1;x+=4){const j=(y*width+x)*4;histogram[Math.round(.299*data[j]+.587*data[j+1]+.114*data[j+2])]++;count++}let sum=0,paper=220;for(let i=0;i<256;i++){sum+=histogram[i];if(sum>=count*.8){paper=i;break}}const threshold=Math.max(35,Math.min(180,paper-40));
  const dark=(x,y)=>{if(x<0||x>=width||y<0||y>=height)return false;const i=(y*width+x)*4;return !blueInk(data[i],data[i+1],data[i+2])&&.299*data[i]+.587*data[i+1]+.114*data[i+2]<threshold};
  const horizontal=[];for(let y=y0;y<=y1;y++){if(y%30===0)checkAbort();let best=null;for(let s=-12;s<=12;s++){const slope=s/100;let start=x0,last=x0-1,gap=0;for(let x=x0;x<=x1+1;x++){const yy=Math.round(y+slope*(x-cx)),hit=x<=x1&&(dark(x,yy)||dark(x,yy-1)||dark(x,yy+1));if(hit){last=x;gap=0}else if(++gap>3||x===x1+1){const length=last-start;if(length>=hw*.7&&(!best||length>best.length))best={y,slope,x0:start,x1:last,length};start=x+1;gap=0;}}}if(best)horizontal.push(best)}
  const lines=clusters(horizontal,3,a=>a.y,a=>a.length);let found=null;
  // Take the last nine equally spaced body boundaries, excluding title/column headers.
  for(let end=lines.length-1;end>=8;end--){const rows=lines.slice(end-8,end+1),gaps=rows.slice(1).map((h,i)=>h.y-rows[i].y),step=median(gaps),top=rows[0],bottom=rows[8];if(step<7||step>hw*.4||Math.max(...gaps)-Math.min(...gaps)>step*.25||top.y-heading.y1>hw*.65)continue;
   const left=median(rows.map(r=>r.x0)),right=median(rows.map(r=>r.x1)),w=right-left,cy=(top.y+bottom.y)/2;if(w<hw*.7||w>hw*2||rows.filter(r=>r.length>=w*.8).length<7)continue;
   const vertical=[];for(let x=Math.floor(left-4);x<=right+4;x++){let best=null;for(let s=-12;s<=12;s++){const slope=s/100;let hits=0,total=0;for(let y=top.y+4;y<bottom.y-3;y++){const xx=Math.round(x+slope*(y-cy));if(dark(xx,y)||dark(xx-1,y)||dark(xx+1,y))hits++;total++;}const coverage=hits/total;if(coverage>=.78&&(!best||coverage>best.coverage))best={x,slope,coverage};}if(best)vertical.push(best)}
   const sides=clusters(vertical,3,a=>a.x,a=>a.coverage);const a=sides.find(v=>Math.abs(v.x-left)<w*.08),d=[...sides].reverse().find(v=>Math.abs(v.x-right)<w*.08);if(!a||!d)continue;const inside=sides.filter(v=>v.x>a.x+w*.1&&v.x<d.x-w*.1);if(inside.length!==2)continue;const [b,c]=inside;const labels=heading.groups||[];const labelAt=(name,row)=>labels.some(g=>g.group===name&&(g.x0+g.x1)/2>left&&(g.x0+g.x1)/2<b.x&&(g.y0+g.y1)/2>rows[row].y&&(g.y0+g.y1)/2<rows[row+1].y);if(!labelAt('A+',0)||!(labelAt('AB+',6)||labelAt('AB-',7)))continue;const split=(c.x-b.x)/(d.x-b.x);if((b.x-a.x)/w<.1||(b.x-a.x)/w>.4||split<.25||split>.75)continue;
   const pixelPoints=[intersect(top,b,cx,cy),intersect(top,d,cx,cy),intersect(bottom,d,cx,cy),intersect(bottom,b,cx,cy)],points=pixelPoints.map(p=>({x:p.x/width,y:p.y/height}));try{validateQuad(points)}catch{continue}found={points,columnSplit:split,heading:{x0:heading.x0/width,y0:heading.y0/height,x1:heading.x1/width,y1:heading.y1/height},rowHeight:step/height};break;
  }
  if(found&&!result.some(r=>Math.abs(r.points[0].x-found.points[0].x)<.04&&Math.abs(r.points[0].y-found.points[0].y)<.04))result.push(found);
 }
 return result.sort((a,b)=>a.points[0].y-b.points[0].y||a.points[0].x-b.points[0].x).slice(0,6);
}
export async function detectInventoryTables(source,{signal,onProgress=()=>{}}={}){
 const canvas=document.createElement('canvas'),scale=Math.min(1,1200/Math.max(source.width,source.height));canvas.width=Math.round(source.width*scale);canvas.height=Math.round(source.height*scale);const ctx=canvas.getContext('2d',{willReadFrequently:true});ctx.drawImage(source,0,0,canvas.width,canvas.height);
 try{return await withLocalOCR(async(worker,aborted)=>{await worker.setParameters({tessedit_pageseg_mode:'11'});const {data}=await worker.recognize(canvas,{}, {blocks:true});aborted();const headings=inventoryHeadings(data.blocks);onProgress(`Revisando ${headings.length} encabezado(s) de inventario…`);await new Promise(r=>setTimeout(r,0));aborted();return tableCandidatesFromPixels(ctx.getImageData(0,0,canvas.width,canvas.height),headings,{checkAbort:aborted});},{signal,onProgress})}finally{canvas.width=canvas.height=0}
}
