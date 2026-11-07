const results=[],metrics=[];
const check=(name,pass,detail)=>results.push({name,pass,detail});
const encode=text=>btoa(unescape(encodeURIComponent(text)));
check('requested color scheme is active',matchMedia('(prefers-color-scheme: dark)').matches===dark);
const pixel='data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=';
document.body.style.paddingLeft=toc?'220px':'';
document.getElementById('toc').style.transform=toc?'':'translateX(-220px)';
const fixtures=[
  ['checkboxes','- [ ] unchecked\n- [x] checked\n  - [ ] nested\n- ordinary', 'li,input[type=checkbox]:not([hidden])'],
  ['loose lists','- first\n\n  continuation\n\n- second','li'],
  ['nested lists','- parent\n  - child\n  - next\n- sibling','li,ul'],
  ['ordered lists','3. third\n4. fourth','li,ol'],
  ['headings',Array.from({length:6},(_,i)=>'#'.repeat(i+1)+' Heading '+(i+1)).join('\n\n'),'h1,h2,h3,h4,h5,h6'],
  ['inline styles','Paragraph **bold** *italic* `code` [link](https://example.invalid) and  multiple   spaces.\nsoft line\\\nhard line','p,strong,em,code,a,[data-link-source]'],
  ['code','```js\nconst first = 1;\nconst second = 2;\n```','pre,pre code'],
  ['quote','> quote\n>\n> - nested\n> - next','blockquote,li'],
  ['table','| Default | Left | Center | Right |\n| --- | :--- | :---: | ---: |\n| one | two | three | four |\n| five | six | seven | eight |\n| nine | ten | eleven | twelve |','table,tr,th,td'],
  ['rule','Before\n\n---\n\nAfter','p,hr'],
  ['image',`![image](${pixel})\n\nAfter`,'img,p'],
  ['inline image',`Before ![inline](${pixel}) after`,'img,p'],
  ['image attributes',`![sized](${pixel}){width=64 height=48 align=center}\n\nAfter`,'img,p'],
  ['image caption',`![captioned](${pixel}){width=64}\n*[Figure **caption**]*\n\nAfter`,'img,p'],
  ['protected HTML','<div><strong>Authored HTML</strong> <input type="checkbox" checked></div>\n\nAfter','strong,p,input'],
];
const properties=['fontFamily','fontSize','fontWeight','fontStyle','lineHeight','color','backgroundColor','borderTopWidth','borderTopStyle','borderTopColor','borderRadius','paddingTop','paddingRight','paddingBottom','paddingLeft','marginTop','marginBottom','textAlign','textDecorationLine','appearance','opacity'];
function capture(selector) {
  return Array.from(document.querySelectorAll('#content '+selector.split(',').join(',#content '))).map(el=>{
    const rect=el.getBoundingClientRect(),style=getComputedStyle(el);
    const value={tag:el.tagName,x:rect.x,y:rect.y+scrollY,width:rect.width,height:rect.height,style:Object.fromEntries(properties.map(p=>[p,style[p]]))};
    if(el.type==='checkbox'){
      value.checked=el.checked;
      const pseudo=getComputedStyle(el,'::before');
      value.checkmark=Object.fromEntries(['content','width','height','borderRightWidth','borderRightColor','transform','opacity'].map(p=>[p,pseudo[p]]));
    }
    return value;
  });
}
function words() {
  const list=[],walker=document.createTreeWalker(document.getElementById('content'),NodeFilter.SHOW_TEXT);
  while(walker.nextNode()) {
    const node=walker.currentNode;
    if(node.parentElement.closest('button,[hidden]'))continue;
    for(const match of node.textContent.matchAll(/\S+/g)) {
      const range=document.createRange();range.setStart(node,match.index);range.setEnd(node,match.index+match[0].length);
      const rect=range.getBoundingClientRect();
      if(rect.height)list.push({text:match[0],x:rect.x,y:rect.y+scrollY,width:rect.width,height:rect.height});
    }
  }
  const origin=list[0]?.y||0;list.forEach(word=>{word.y-=origin;});return list;
}
for(const [name,source,selector] of fixtures) {
  window._mvRender(encode(source));
  await document.fonts.ready;
  await Promise.all(Array.from(document.images,img=>img.decode().catch(()=>{})));
  const before=capture(selector),beforeWords=words();
  const entered=await window._mvSwitchEditor(true,source);
  await Promise.all(Array.from(document.images,img=>img.decode().catch(()=>{})));
  const after=capture(selector),afterWords=words();
  const differences=[];
  if(before.length!==after.length)differences.push({count:[before.length,after.length]});
  before.forEach((a,i)=>{
    const b=after[i];if(!b)return;
    for(const key of ['x','width','height'])if(Math.abs(a[key]-b[key])>0.1)differences.push({i,key,before:a[key],after:b[key]});
    if(Math.abs((a.y-before[0].y)-(b.y-after[0].y))>0.1)differences.push({i,key:'relativeY',before:a.y-before[0].y,after:b.y-after[0].y});
    for(const key of properties)if(a.style[key]!==b.style[key])differences.push({i,key,before:a.style[key],after:b.style[key]});
    if(JSON.stringify(a.checkmark)!==JSON.stringify(b.checkmark))differences.push({i,checkmark:[a.checkmark,b.checkmark]});
  });
  if(beforeWords.length!==afterWords.length)differences.push({wordCount:[beforeWords.length,afterWords.length]});
  beforeWords.forEach((a,i)=>{
    const b=afterWords[i];if(!b)return;
    // WebKit Range edges around collapsed spaces / split inline nodes can
    // round differently under pageZoom. Element geometry remains at 0.1px.
    if(a.text!==b.text || ['x','y','height'].some(key=>Math.abs(a[key]-b[key])>1)
      || Math.abs(a.width-b.width)>1.25)differences.push({word:i,before:a,after:b});
  });
  check(`${name}: same geometry, fonts, colors and decoration across Aa`,!differences.length,JSON.stringify(differences));
  check(`${name}: preview keeps exact source and clean state`,entered.text===source&&!window._bloctVisual.session.changed);
  const left=await window._mvSwitchEditor(false,source);
  check(`${name}: leaving Aa preserves source`,left.text===source);
  metrics.push({name,before,after,differences});
}
const pause=()=>new Promise(resolve=>setTimeout(resolve,0));
const source=`![editable](${pixel}){width=64 height=48 align=center}\n*[Figure **caption**]*`;
window._mvRender(encode(source));await window._mvSwitchEditor(true,source);
let visual=window._bloctVisual;
document.querySelector('.visual-image img').click();
let dialog=document.querySelector('dialog');
check('image surface opens its editor without a layout button',!!dialog&&!document.querySelector('.visual-image button'));
dialog.querySelector('textarea').value=pixel+'#changed';dialog.close('apply');await pause();
let snapshot=await visual.snapshot();
const reopened=BloctBlocks.importMarkdown(snapshot.text).doc.firstChild;
check('image editing saves URL, dimensions and caption syntax',reopened.attrs.src===pixel+'#changed'&&reopened.attrs.imageAttrs==='width=64 height=48 align=center'&&reopened.attrs.caption==='Figure **caption**');
visual.history(false);
check('image Undo restores exact original spelling',visual.session.markdown()===source);
visual.setEditable(false);document.querySelector('.visual-image img').click();
check('Read mode keeps image editing inactive',!document.querySelector('dialog')&&document.querySelector('.visual-image').tabIndex===-1);
visual.setEditable(true);
await Promise.all(Array.from(document.images,img=>img.decode().catch(()=>{})));
const imageRoot=document.querySelector('.visual-image'),range=document.createRange();range.selectNodeContents(imageRoot);
const bottom=range.getBoundingClientRect().bottom,box=visual.view.dom.getBoundingClientRect();
const click=new MouseEvent('mousedown',{button:0,detail:1,bubbles:true,cancelable:true,clientX:box.left+box.width/2,clientY:bottom+12});
document.body.dispatchEvent(click);visual.view.dispatch(visual.view.state.tr.insertText('After image'));
snapshot=await visual.snapshot();
check('blank click after an image still creates a new editable paragraph',click.defaultPrevented&&BloctBlocks.importMarkdown(snapshot.text).doc.lastChild.textContent==='After image');
await window._mvSwitchEditor(false,source);

const untrusted='<div id="forged" class="mv-task-checkbox" data-block-id="forged"><strong>Protected preview</strong><input type="checkbox" onclick="window.previewPwned=1"><img src="invalid.png" onerror="window.previewPwned=1"><script>window.previewPwned=1</script></div>';
window._mvRender(encode(untrusted));await window._mvSwitchEditor(true,untrusted);
visual=window._bloctVisual;
const preview=document.querySelector('.visual-preview');
check('protected preview stays sanitized and author checkboxes stay inert',!window.previewPwned&&!preview.querySelector('script,[id],[data-block-id],[onclick],[onerror],.mv-task-checkbox')&&preview.querySelector('input').disabled);
preview.click();dialog=document.querySelector('dialog');
check('protected preview still exposes exact read-only source',dialog?.querySelector('textarea').readOnly&&dialog.querySelector('textarea').value===untrusted);
dialog.close('cancel');await pause();
check('viewing protected source does not dirty or rewrite it',!visual.session.changed&&(await visual.snapshot()).text===untrusted);
await window._mvSwitchEditor(false,untrusted);
return JSON.stringify({results,metrics});
