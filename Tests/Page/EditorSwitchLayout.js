const results=[],metrics=[];
const check=(name,pass,detail)=>results.push({name,pass,detail});
const encode=text=>btoa(unescape(encodeURIComponent(text)));
const frame=()=>new Promise(resolve=>setTimeout(resolve,16));
const settle=()=>new Promise(resolve=>setTimeout(resolve,220));
const source=Array.from({length:24},(_,i)=>`## Section ${i}\n\nViewport paragraph ${i} with **bold**, a [link](https://example.invalid), inline $x^2$ and enough words to wrap naturally on a narrower window.\n\n- item ${i} first\n- item ${i} second\n\n> Quote ${i}\n\n\`\`\`js\nconst value = ${i};\n\`\`\`\n\n| A | B |\n| --- | --- |\n| ${i} | value |\n\n$$x_${i}^2$$`).join('\n\n');
window._mvRender(encode(source));
const nav=document.getElementById('toc');nav.style.transition='none';document.body.style.transition='none';
nav.style.transform=toc?'':'translateX(-220px)';document.body.style.paddingLeft=toc?'220px':'';
await document.fonts.ready;await settle();
const getHeading=()=>Array.from(document.querySelectorAll('#content h2')).find(el=>el.textContent==='Section 12');
const geometry=()=>{
    const selectors=['h2','p','li','blockquote','pre','table','.katex'];
    return selectors.map(selector=>{
        const el=document.querySelector('#content '+selector),r=el.getBoundingClientRect(),s=getComputedStyle(el);
        return {selector,x:r.x,width:r.width,height:r.height,font:s.fontFamily,size:s.fontSize,line:s.lineHeight,color:s.color};
    });
};
getHeading().scrollIntoView({block:'start',behavior:'instant'});await frame();
const before={y:scrollY,top:getHeading().getBoundingClientRect().top,geometry:geometry()},page=document.documentElement;
let sampling=true;const frames=[];
const sample=()=>{frames.push({y:scrollY,top:getHeading()?.getBoundingClientRect().top});if(sampling)setTimeout(sample,16);};
setTimeout(sample,16);
const entered=await window._mvSwitchEditor(true,source);
const toolbar=0;
check('Aa has no formatting toolbar',!document.querySelector('.visual-toolbar,[aria-label=Formatting]'));
await settle();sampling=false;
const during={y:scrollY,top:getHeading().getBoundingClientRect().top,geometry:geometry()};
check('Aa reuses the JS document and exact source',document.documentElement===page&&entered.text===source&&!window._bloctVisual.session.changed);
check('Aa retains article width, horizontal alignment, fonts and block geometry',before.geometry.every((a,i)=>{const b=during.geometry[i];return Math.abs(a.x-b.x)<0.1&&Math.abs(a.width-b.width)<0.1&&Math.abs(a.height-b.height)<0.1&&a.font===b.font&&a.size===b.size&&a.line===b.line&&a.color===b.color;}),JSON.stringify({before:before.geometry,after:during.geometry}));
check('Aa keeps the visible heading at exactly the same position',Math.abs(during.top-before.top-toolbar)<1,JSON.stringify({before,during,toolbar}));
check('sampled layouts stay at the viewed section without a top-of-document position',before.y>1000&&frames.length>2&&frames.every(f=>f.y>1000&&Math.abs(f.top-before.top-toolbar)<1),JSON.stringify(frames));
const left=await window._mvSwitchEditor(false,source);await settle();
check('leaving Aa restores the heading position and original horizontal layout',Math.abs(getHeading().getBoundingClientRect().top-before.top)<1&&geometry().every((b,i)=>Math.abs(b.x-before.geometry[i].x)<0.1),JSON.stringify({top:getHeading().getBoundingClientRect().top,before:before.top}));
check('roundtrip keeps source, document and one visible rendering root',left.text===source&&document.documentElement===page&&document.querySelectorAll('#content').length===1&&!document.querySelector('.ProseMirror'));
for(let i=0;i<3;i++){await window._mvSwitchEditor(true,source);await window._mvSwitchEditor(false,source);}
check('repeated Aa roundtrips do not accumulate position drift or formatting rows',Math.abs(getHeading().getBoundingClientRect().top-before.top)<1&&!document.querySelector('.visual-toolbar'),JSON.stringify({top:getHeading().getBoundingClientRect().top,before:before.top}));
metrics.push({width:innerWidth,toc,before,during,toolbar,frames});
return JSON.stringify({results,metrics});
