import {readFile,writeFile,readdir} from 'node:fs/promises';
import {resolve} from 'node:path';
let css=await readFile('node_modules/katex/dist/katex.min.css','utf8');
// KaTeX minifies the final declaration as src:...} without a semicolon.
// Never consume the closing brace or the next @font-face/.katex rule.
css=css.replace(/src:([^;}]+)(?=[;}])/g,(whole,source)=>{
  const woff2=/url\(([^)]+\.woff2)\)\s*format\([^)]+\)/.exec(source);
  return woff2 ? `src:url(${woff2[1]}) format("woff2")` : whole;
});
for(const match of [...css.matchAll(/url\((fonts\/[^)]+)\)/g)]) {
  const bytes=await readFile('node_modules/katex/dist/'+match[1]);
  css=css.replace(match[0],`url(data:font/woff2;base64,${bytes.toString('base64')})`);
}
// Reset editable-root wrapping at the math boundary in both modes. KaTeX's
// own no-wrap/internal positioning rules still take precedence below it.
css+='\n.katex { white-space:normal; overflow-wrap:normal; text-indent:0; }\n';
await writeFile('dist/math.css',css);
await writeFile('dist/visual.css',css+'\n'+await readFile('../Sources/Bloct/Resources/Web/style.css','utf8')+'\n'+await readFile('src/styles/visual.css','utf8'));
// Page scripts run as one classic script, in this order, and share globals
// (reader.js's _mvPage and _mvRenderOneBlock, task-lists.js's _mvTasks).
// They are joined, not bundled, so those top-level names stay global.
const hostScripts=['task-lists','reader','toc','scroll','editor-switch','start'];
await writeFile('dist/host.js',(await Promise.all(hostScripts.map(name=>readFile(`src/host/${name}.js`,'utf8')))).join('\n'));
const lock=JSON.parse(await readFile('package-lock.json','utf8'));
let notices='Bloct visual editor — dependency license notices\n';
for(const [path,entry] of Object.entries(lock.packages)) {
  if(!path||entry.dev)continue;
  const files=await readdir(path);
  const license=files.find(name=>/^licen[sc]e(?:\.|$)/i.test(name));
  if(license) notices+=`\n--- ${path} ${entry.version} ---\n`+await readFile(resolve(path,license),'utf8')+'\n';
}
await writeFile('dist/editor-licenses.txt',notices);
