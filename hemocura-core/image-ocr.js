// Local-only OCR. Models and worker are self-hosted; images are never sent to an OCR API.
export async function readDocumentImage(file,{signal,onProgress=()=>{}}={}){
 if(!file||!['image/jpeg','image/png','image/webp'].includes(file.type))throw Error('Use una imagen JPG, PNG o WebP.');
 if(file.size>10*1024*1024)throw Error('La imagen debe pesar menos de 10 MB.');
 const aborted=()=>{if(signal?.aborted)throw new DOMException('Lectura cancelada','AbortError')};aborted();
 const {default:Tesseract}=await import('../js/vendor/ocr/tesseract.esm.min.js');aborted();
 let worker;const stop=()=>{worker?.terminate().catch(()=>{})};signal?.addEventListener('abort',stop,{once:true});
 try{
  worker=await Tesseract.createWorker('spa',1,{workerPath:new URL('../js/vendor/ocr/worker.min.js',import.meta.url).href,corePath:new URL('../js/vendor/ocr/core',import.meta.url).href,langPath:new URL('../js/vendor/ocr/lang',import.meta.url).href,workerBlobURL:false,cacheMethod:'none',logger:m=>onProgress(m.status==='recognizing text'?`Leyendo texto: ${Math.round(m.progress*100)}%`:'Preparando lector local…')});
  aborted();const result=await worker.recognize(file);aborted();return {text:result.data.text,confidence:result.data.confidence};
 }finally{signal?.removeEventListener('abort',stop);if(worker)await worker.terminate().catch(()=>{})}
}
