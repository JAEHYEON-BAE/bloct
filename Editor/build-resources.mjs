import {readFile,writeFile,readdir} from 'node:fs/promises';
import {resolve} from 'node:path';
let css=await readFile('node_modules/katex/dist/katex.min.css','utf8');
css=css.replace(/src:([^;]+);/g,(whole,source)=>{
  const woff2=/url\(([^)]+\.woff2)\)\s*format\([^)]+\)/.exec(source);
  return woff2 ? `src:url(${woff2[1]}) format("woff2");` : whole;
});
for(const match of [...css.matchAll(/url\((fonts\/[^)]+)\)/g)]) {
  const bytes=await readFile('node_modules/katex/dist/'+match[1]);
  css=css.replace(match[0],`url(data:font/woff2;base64,${bytes.toString('base64')})`);
}
css+='\n'+await readFile('src/visual.css','utf8');
await writeFile('dist/visual.css',css);
const lock=JSON.parse(await readFile('package-lock.json','utf8'));
let notices='Bloct visual editor — dependency license notices\n';
for(const [path,entry] of Object.entries(lock.packages)) {
  if(!path||entry.dev)continue;
  const files=await readdir(path);
  const license=files.find(name=>/^licen[sc]e(?:\.|$)/i.test(name));
  if(license) notices+=`\n--- ${path} ${entry.version} ---\n`+await readFile(resolve(path,license),'utf8')+'\n';
}
await writeFile('dist/editor-licenses.txt',notices);
