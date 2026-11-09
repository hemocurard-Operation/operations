// Geometry and pixel rules. No number is inferred from an empty or ambiguous cell.
export function validateQuad(points){
 if(!Array.isArray(points)||points.length!==4||points.some(p=>!Number.isFinite(p.x)||!Number.isFinite(p.y)||p.x<0||p.x>1||p.y<0||p.y>1))throw Error('Marque cuatro esquinas dentro de la foto.');
 const [tl,tr,br,bl]=points;if(tl.x>=tr.x||bl.x>=br.x||tl.y>=bl.y||tr.y>=br.y)throw Error('Oriente la foto y comience por la esquina superior izquierda del cuadro.');
 let area=0;for(let i=0;i<4;i++){const a=points[i],b=points[(i+1)%4],c=points[(i+2)%4];if((b.x-a.x)*(c.y-b.y)-(b.y-a.y)*(c.x-b.x)<=0.00001)throw Error('Marque las esquinas en orden: superior izquierda, superior derecha, inferior derecha e inferior izquierda.');area+=a.x*b.y-b.x*a.y;}
 if(area/2<0.001)throw Error('El cuadro seleccionado es demasiado pequeño. Amplíe la foto.');return points;
}
export function quadProjector(points){
 validateQuad(points);const [p0,p1,p2,p3]=points;const dx1=p1.x-p2.x,dx2=p3.x-p2.x,dy1=p1.y-p2.y,dy2=p3.y-p2.y,sx=p0.x-p1.x+p2.x-p3.x,sy=p0.y-p1.y+p2.y-p3.y,den=dx1*dy2-dx2*dy1;
 if(Math.abs(den)<1e-9)throw Error('La selección no forma un cuadro válido.');
 const g=(sx*dy2-dx2*sy)/den,h=(dx1*sy-sx*dy1)/den,a=p1.x-p0.x+g*p1.x,b=p3.x-p0.x+h*p3.x,d=p1.y-p0.y+g*p1.y,e=p3.y-p0.y+h*p3.y;
 return (u,v)=>({x:(a*u+b*v+p0.x)/(g*u+h*v+1),y:(d*u+e*v+p0.y)/(g*u+h*v+1)});
}
export function blueInk(r,g,b){return b-r>18&&b-g>6&&r<210;}
export function prepareInkCell(rgba,width,height,mode='dark'){
 const mask=new Uint8Array(width*height),gray=new Uint8Array(mask.length);let sum=0;
 for(let i=0;i<mask.length;i++){const j=i*4;gray[i]=Math.round(.299*rgba[j]+.587*rgba[j+1]+.114*rgba[j+2]);sum+=gray[i];}
 const threshold=Math.max(25,Math.min(190,sum/mask.length-32));
 for(let y=0;y<height;y++)for(let x=0;x<width;x++){const i=y*width+x,j=i*4;if(x<width*.1||x>=width*.9||y<height*.06||y>=height*.94)continue;mask[i]=(mode==='blue'?blueInk(rgba[j],rgba[j+1],rgba[j+2]):gray[i]<threshold)?1:0;}
 // Remove long ruling lines before looking for connected ink. Border fragments cannot become a "1".
 for(let y=0;y<height;y++){let n=0;for(let x=0;x<width;x++)n+=mask[y*width+x];if(n>width*.6)for(let x=0;x<width;x++)mask[y*width+x]=0;}
 for(let x=0;x<width;x++){let n=0;for(let y=0;y<height;y++)n+=mask[y*width+x];if(n>height*.85)for(let y=0;y<height;y++)mask[y*width+x]=0;}
 const seen=new Uint8Array(mask.length),kept=new Uint8Array(mask.length);let ink=0,minX=width,minY=height,maxX=-1,maxY=-1;
 for(let i=0;i<mask.length;i++)if(mask[i]&&!seen[i]){const queue=[i];seen[i]=1;let loX=width,hiX=0,loY=height,hiY=0;for(let k=0;k<queue.length;k++){const j=queue[k],x=j%width,y=Math.floor(j/width);loX=Math.min(loX,x);hiX=Math.max(hiX,x);loY=Math.min(loY,y);hiY=Math.max(hiY,y);for(const [nx,ny] of [[x-1,y],[x+1,y],[x,y-1],[x,y+1]])if(nx>=0&&nx<width&&ny>=0&&ny<height){const n=ny*width+nx;if(mask[n]&&!seen[n]){seen[n]=1;queue.push(n)}}}
  if(queue.length<8||hiY-loY<7||hiX-loX<1)continue;
  for(const j of queue)kept[j]=1;ink+=queue.length;minX=Math.min(minX,loX);maxX=Math.max(maxX,hiX);minY=Math.min(minY,loY);maxY=Math.max(maxY,hiY);
 }
 return {mask:kept,blank:ink<12,ink,bounds:{minX,minY,maxX,maxY}};
}
export function agreedDigits(readings,minConfidence=55){
 if(readings.length<2)return null;const values=readings.map(r=>String(r.text||'').trim());
 if(readings.some(r=>!Number.isFinite(r.confidence)||r.confidence<minConfidence)||values.some(v=>!/^\d{1,5}$/.test(v))||values.some(v=>v!==values[0]))return null;
 return Number(values[0]);
}
