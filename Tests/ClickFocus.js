const results=[];
const check=(name,value,detail)=>results.push({name,pass:!!value,detail});
const encode=text=>btoa(unescape(encodeURIComponent(text)));
const pause=()=>new Promise(resolve=>setTimeout(resolve,0));
let baseline='',requests=[],transitions=[];
Object.defineProperty(window,'webkit',{configurable:true,value:{messageHandlers:{editorModeRequest:{postMessage:payload=>{
  requests.push(payload);transitions.push(window._mvSwitchEditor(payload.editing,baseline));
}}}}});
const settle=async()=>{await Promise.all(transitions.splice(0));await pause();};
const fresh=async(source)=>{
  if(document.querySelector('dialog')){document.querySelector('dialog')?.close('cancel');await pause();}
  await window._mvSwitchEditor(false,baseline);baseline=source;
  window._mvGeneration++;window._mvRender(encode(source));requests=[];
  return window._bloctVisual;
};
const click=(node,x,y,options={})=>{
  for(const type of ['mousedown','mouseup','click'])node.dispatchEvent(new MouseEvent(type,{button:0,detail:1,bubbles:true,cancelable:true,clientX:x,clientY:y,...options}));
};
const escape=(target=window._bloctVisual.view.dom,options={})=>target.dispatchEvent(new KeyboardEvent('keydown',{key:'Escape',bubbles:true,cancelable:true,...options}));
for(const [source,selector,text] of [
  ['Alpha middle Omega','p','Alpha middle Omega'],
  ['## Alpha middle Omega','h2','Alpha middle Omega'],
  ['> Alpha middle Omega','blockquote p','Alpha middle Omega'],
  ['- Alpha middle Omega','li p','Alpha middle Omega'],
  ['| Alpha middle Omega | B |\n| --- | --- |\n| C | D |','td','Alpha middle Omega'],
]){
  const editor=await fresh(source),view=editor.view;
  const node=document.querySelector('.ProseMirror '+selector),before=node.getBoundingClientRect(),scroll={x:scrollX,y:scrollY};
  const range=document.createRange(),offset=text.indexOf('middle');range.setStart(node.firstChild,offset);range.setEnd(node.firstChild,offset+1);
  const r=range.getBoundingClientRect();click(node,r.left+r.width*.2,r.top+r.height/2);await settle();
  check(selector+': click enters at the clicked character with one native request',window._mvIsEditing()&&view.state.selection.$from.parentOffset===offset&&requests.length===1,JSON.stringify(view.state.selection.toJSON()));
  check(selector+': mode changes retain the EditorView and exact geometry',window._bloctVisual.view===view&&Math.abs(node.getBoundingClientRect().top-before.top)<.1&&scrollX===scroll.x&&scrollY===scroll.y);
  view.dispatch(view.state.tr.insertText('X'));const draft=editor.session.markdown();
  check(selector+': immediate input lands at the clicked character',view.state.selection.$from.parent.textContent==='Alpha Xmiddle Omega');
  escape();await settle();
  check(selector+': Escape is read-only without dropping the draft or view',!window._mvIsEditing()&&!view.editable&&window._bloctVisual.view===view&&editor.session.markdown()===draft&&window._mvRawLines.join('\n')===draft);
  const read=view.state.doc;view.dispatch(view.state.tr.insertText('blocked'));
  check(selector+': reading rejects mutation',editor.session.doc.eq(read)&&!editor.history(false));
}
{
  const source=Array.from({length:24},(_,i)=>'## Section '+i+'\n\nAlpha middle Omega').join('\n\n');
  const editor=await fresh(source);window.scrollTo(0,1600);await pause();
  const p=Array.from(editor.view.dom.querySelectorAll('p')).find(p=>{const r=p.getBoundingClientRect();return r.top>60&&r.bottom<innerHeight;});
  const r=p.getBoundingClientRect(),y=scrollY,view=editor.view;
  click(p,r.left+10,r.top+5);await settle();
  check('scrolled document click retains viewport and live view',window._mvIsEditing()&&scrollY===y&&editor.view===view);
  escape();await settle();check('scrolled Escape retains viewport and exact source',!window._mvIsEditing()&&scrollY===y&&editor.session.markdown()===source);
  window.scrollTo(0,0);
}
{
  const editor=await fresh(''),view=editor.view,p=view.dom.querySelector('p'),r=p.getBoundingClientRect();
  click(p,r.left+2,r.top+4);await settle();
  check('empty document click focuses the existing single Text line',window._mvIsEditing()&&editor.session.doc.childCount===1&&view.state.selection.from===1&&!editor.session.changed);
  view.dispatch(view.state.tr.insertText('First'));escape();await settle();
  const blank=view.dom.getBoundingClientRect();click(document.body,blank.left+4,blank.bottom+10);await settle();
  check('below-end click reenters without a duplicate blank line',window._mvIsEditing()&&editor.session.markdown()==='First'&&editor.session.doc.childCount===1);
}
{
  const editor=await fresh('Alpha middle Omega'),p=editor.view.dom.querySelector('p'),r=p.getBoundingClientRect();
  for(const options of [{metaKey:true},{shiftKey:true},{button:2}])click(p,r.left+5,r.top+5,options);
  check('modified and secondary clicks do not request editing',requests.length===0&&!window._mvIsEditing());
  click(p,r.left+5,r.top+5);await settle();editor.view.input.composing=true;escape();editor.view.input.composing=false;await settle();
  check('composition Escape does not leave editing',window._mvIsEditing());
}
{
  const editor=await fresh('$$x^2$$'),math=editor.view.dom.querySelector('.visual-math'),r=math.getBoundingClientRect();
  click(math,r.left+r.width/2,r.top+r.height/2);await settle();
  check('one formula click enters editing and opens one equation dialog',window._mvIsEditing()&&document.querySelectorAll('dialog[open]').length===1,JSON.stringify({requests,editing:window._mvIsEditing(),hit:document.elementFromPoint(r.left+r.width/2,r.top+r.height/2)?.outerHTML.slice(0,250),top:r.top}));
  if(document.querySelector('dialog')){
    escape(document.querySelector('dialog textarea'));await settle();
    check('Escape in an equation popup does not exit document editing',window._mvIsEditing());
    document.querySelector('dialog')?.close('cancel');await pause();
  }
  escape();await settle();
  check('Escape after the popup returns to read-only',!window._mvIsEditing()&&!editor.view.editable);
}
{
  const editor=await fresh('- [ ] task'),input=editor.view.dom.querySelector('input.mv-task-checkbox'),r=input.getBoundingClientRect();
  check('read-only task controls are inert',input.disabled);
  const target=document.elementFromPoint(r.left+r.width/2,r.top+r.height/2);
  click(target,r.left+r.width/2,r.top+r.height/2);await settle();
  check('one task click activates and toggles exactly once',window._mvIsEditing()&&editor.session.markdown()==='- [x] task');
  editor.history(false);check('task click remains one Undo step',editor.session.markdown()==='- [ ] task');
}
await window._mvSwitchEditor(false,baseline);
check('no formatting toolbar exists in either mode',!document.querySelector('.visual-toolbar,[aria-label=Formatting]'));
return JSON.stringify({results});
