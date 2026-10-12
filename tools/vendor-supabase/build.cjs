// npm ci --prefix tools/vendor-supabase --ignore-scripts; node this file.
const path=require('node:path');
require('esbuild').buildSync({entryPoints:[path.join(__dirname,'entry.js')],bundle:true,format:'esm',platform:'browser',target:'es2020',minify:true,legalComments:'eof',outfile:path.resolve(__dirname,'../../js/vendor/supabase-2.117.3.js')});
