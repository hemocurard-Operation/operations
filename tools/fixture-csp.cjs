// Exercise the production CSP in local fixture pages. A nonce permits only their trusted test bootstrap.
const fs=require('node:fs'),path=require('node:path');
const html=fs.readFileSync(path.resolve(__dirname,'../index.html'),'utf8');
const match=html.match(/http-equiv="Content-Security-Policy" content="([^"]+)"/);
if(!match)throw Error('Missing application CSP');
const fixturePolicy=match[1].replace("script-src 'self'","script-src 'self' 'nonce-hc-fixture'");
exports.protectResponse=res=>{const end=res.end.bind(res);res.end=(body,...args)=>{
 if(body&&String(res.getHeader('Content-Type')||'').includes('text/html')){
  res.setHeader('Content-Security-Policy',fixturePolicy);
  body=String(body).replace(/<script\b/g,'<script nonce="hc-fixture"');
 }
 return end(body,...args);
}};
