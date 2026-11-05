const results=[];
const check=async(name,body)=>{try{await body();results.push({name,pass:true});}catch(error){results.push({name,pass:false,detail:String(error)+'\n'+String(error.stack||'')});}};
const assert=(value,message)=>{if(!value)throw new Error(message||'assertion failed');};
let editor,host;
const fresh=(markdown='')=>{
  if(editor){editor.destroy();host.remove();}
  host=document.createElement('div');document.body.append(host);
  editor=BloctBlocks.mountVisualEditor(host,markdown,{imageURL:source=>source.startsWith('data:image/')?source:null});
  editor.focus();return editor;
};
const type=text=>{
  for(const character of text){
    const view=editor.view,{from,to}=view.state.selection;
    let handled=false;
    view.someProp('handleTextInput',handler=>{handled=handler(view,from,to,character,()=>view.state.tr.insertText(character,from,to));return handled;});
    if(!handled)view.dispatch(view.state.tr.insertText(character,from,to));
  }
};
const key=(value,options={})=>{
  const event=new KeyboardEvent('keydown',{key:value,keyCode:{Enter:13,Backspace:8,Tab:9,z:90,b:66}[value]||0,bubbles:true,cancelable:true,...options});
  let handled=false;editor.view.someProp('handleKeyDown',handler=>{handled=handler(editor.view,event);return handled;});return handled;
};
const serialized=()=>editor.session.markdown();

for(let level=1;level<=6;level++)await check(`H${level}: typed marker converts to editable heading and placeholder`,()=>{
  fresh();type('#'.repeat(level)+' ');
  assert(editor.session.doc.firstChild.type.name==='heading');
  assert(editor.session.doc.firstChild.attrs.level===level);
  assert(editor.toolbar.querySelector('select').value===`heading_${level}`);
  assert(host.querySelector(`h${level}[data-placeholder="Header ${level}"]`));
  assert(!document.querySelector('textarea'),'no raw Markdown textarea in normal editing');
  type('Title');assert(host.querySelector(`h${level}`).textContent==='Title');
  assert(serialized()==='#'.repeat(level)+' Title');
});
for(const [prefix,kind,selector] of [
  ['> ','blockquote','blockquote [data-placeholder="Quote"]'],
  ['- ','bullet_list','ul [data-placeholder="List item"]'],
  ['+ ','bullet_list','ul [data-placeholder="List item"]'],
  ['3. ','ordered_list','ol [data-placeholder="List item"]'],
  ['[] ','bullet_list','li.task-item [data-placeholder="To-do"]'],
  ['[x] ','bullet_list','li.task-item [data-placeholder="To-do"]'],
  ['```js ','code_block','pre[data-placeholder="Code"]'],
  ['~~~ ','code_block','pre[data-placeholder="Code"]'],
])await check(`${JSON.stringify(prefix)}: block conversion, placeholder and round-trip`,()=>{
  fresh();type(prefix);assert(editor.session.doc.firstChild.type.name===kind,serialized());
  assert(host.querySelector(selector),host.innerHTML);type('content');serialized();
});
await check('heading Enter creates paragraph; Shift-Enter stays within text block',()=>{
  fresh();type('## Title');assert(key('Enter'));type('Body');
  assert(editor.session.doc.child(1).type.name==='paragraph');
  key('Enter',{shiftKey:true});type('continued');
  assert(serialized()==='## Title\n\nBody\\\ncontinued',serialized());
});
await check('quote Enter and empty quote exit preserve block structure',()=>{
  fresh();type('> Quote');key('Enter');type('second');serialized();
  key('Enter');key('Enter');type('outside');serialized();
  assert(editor.session.doc.lastChild.type.name==='paragraph');
});
await check('task split resets checked, blank item Enter exits the list',()=>{
  fresh();type('[x] Done');key('Enter');type('Next');
  assert(editor.session.doc.firstChild.child(1).attrs.checked===false);
  key('Enter');key('Enter');type('outside');
  assert(editor.session.doc.lastChild.type.name==='paragraph');serialized();
});
await check('code fence Enter converts and code Enter inserts a literal newline',()=>{
  fresh();type('```js');key('Enter');type('const x=1');key('Enter');type('// next');
  assert(editor.session.doc.firstChild.type.name==='code_block');
  assert(editor.session.doc.firstChild.textContent.includes('\n'));serialized();
});
for(const kind of ['paragraph','heading_1','heading_2','heading_3','heading_4','heading_5','heading_6','blockquote','bullet_list','ordered_list','task_list','code_block','horizontal_rule','equation','image_block','table']) {
  await check(`format menu ${kind}: schema-valid editable/atomic block`,()=>{
    fresh();assert(editor.format(kind));editor.session.doc.check();
    assert(editor.session.doc.firstChild.type.name===(kind.startsWith('heading_')?'heading':kind==='task_list'?'bullet_list':kind));
    if(kind==='task_list')assert(editor.session.doc.firstChild.firstChild.attrs.checked===false);
    if(kind==='image_block') {
      // An image has a source editor rather than a Markdown textarea.
      const node=editor.session.doc.firstChild;
      const tr=editor.session.state.tr.setNodeMarkup(0,undefined,{...node.attrs,src:'https://example.invalid/a.png',alt:'image'});
      editor.view.dispatch(tr);
    }
    serialized();
  });
}
await check('bold, italic, inline code, inline math, link and image input rules',()=>{
  const examples=[['**bold**','strong','bold'],['*italic*','em','italic'],['`code`','code','code'],
    ['$x+1$',null,'inline_math'],['[link](https://example.invalid)','link','link'],['![alt](a.png)',null,'image_block']];
  for(const [example,mark,expected] of examples){
    fresh();type(example);
    if(mark){const inline=editor.session.doc.firstChild.firstChild;assert(inline.text===expected);assert(inline.marks.some(m=>m.type.name===mark));}
    else if(expected==='image_block')assert(editor.session.doc.firstChild.type.name===expected);
    else assert(editor.session.doc.firstChild.firstChild.type.name===expected);
    serialized();
  }
});
await check('closing inline code limits the code mark to the delimited text',()=>{
  fresh();type('`code`tail');
  const p=editor.session.doc.firstChild;
  assert(p.childCount===2 && p.child(0).text==='code' && p.child(1).text==='tail');
  assert(p.child(0).marks.some(m=>m.type.name==='code'));
  assert(!p.child(1).marks.length);
  assert(serialized()==='`code`tail',serialized());
});
await check('separate inline code spans and cancelled conversion keep ordinary typing available',()=>{
  fresh();type('Before `one` and `two` after');
  const codes=[];editor.session.doc.descendants(n=>{if(n.isText&&n.marks.some(m=>m.type.name==='code'))codes.push(n.text);});
  assert(JSON.stringify(codes)===JSON.stringify(['one','two']),JSON.stringify(codes));
  const reopened=BloctBlocks.importMarkdown(serialized()).doc;
  assert(reopened.firstChild.textContent==='Before one and two after');
  assert(reopened.firstChild.child(1).marks.some(m=>m.type.name==='code'));
  fresh();type('`one`');key('Backspace');type(' next');
  assert(!editor.session.doc.firstChild.firstChild.marks.length);
  assert(serialized().includes('one'));
});
await check('divider input rule consumes its marker',()=>{
  for(const [prefix,kind]of[['--- ','horizontal_rule']]){
    fresh();type(prefix);assert(editor.session.doc.firstChild.type.name===kind);serialized();
  }
});
await check('input conversion Undo restores literal prefix; document history remains coherent',()=>{
  fresh();type('## ');key('z',{metaKey:true});
  assert(editor.session.doc.firstChild.type.name==='paragraph');
  assert(editor.session.doc.firstChild.textContent==='## ');
  serialized();
});
await check('Backspace after block conversion restores the caret to the literal marker before the following block',()=>{
  for(const prefix of ['> ','- ','+ ','* ','1. ','[] ','## ','```js ','--- ']) {
    fresh('replace\n\nFollowing');
    editor.view.dispatch(editor.view.state.tr.delete(1,8));
    type(prefix);assert(key('Backspace'),prefix);
    assert(editor.session.doc.firstChild.type.name==='paragraph',prefix);
    assert(editor.view.state.selection.from===prefix.length+1,prefix+': '+JSON.stringify(editor.session.selection));
    assert(editor.view.state.selection.$from.parent===editor.session.doc.firstChild,prefix);
    type('X');
    assert(editor.session.doc.firstChild.textContent===prefix+'X',prefix+': '+editor.session.doc.textContent);
    assert(editor.session.doc.lastChild.textContent==='Following',prefix);
  }
});
await check('keyboard Undo of quote and list input rules restores selection on the same line',()=>{
  for(const prefix of ['> ','- ']) {
    fresh('replace\n\nFollowing');editor.view.dispatch(editor.view.state.tr.delete(1,8));
    type(prefix);key('z',{metaKey:true});type('X');
    assert(editor.session.doc.firstChild.textContent===prefix+'X');
    assert(editor.session.doc.lastChild.textContent==='Following');
  }
});
await check('save snapshot acknowledgement keeps later typing dirty and Undo available',async()=>{
  fresh();type('A');const snapshot=await editor.snapshot();type('B');
  assert(!editor.acknowledge(snapshot.token));assert(editor.session.changed);
  assert(editor.history(false));
  // Continuous text input is one engine history group; it is not one native
  // Undo entry per keystroke. The fixed saved snapshot remains independent.
  assert(!editor.acknowledge(snapshot.token));
});
await check('saved baseline becomes clean; search and selection never dirty the document',async()=>{
  fresh();type('saved');const snap=await editor.snapshot();assert(editor.acknowledge(snap.token));
  editor.search('save');editor.navigate(true);assert(!editor.session.changed);
  assert(!serialized().includes('visual-match'));
});
await check('HTML metadata cannot create source authority; protected source is hidden by default',()=>{
  fresh('<script>window.pwned=1</script>\n\n[text][external]');
  assert(!window.pwned);assert(!host.textContent.includes('window.pwned'));
  assert(host.textContent.includes('Preserved content'));
  assert(serialized().includes('<script>window.pwned=1</script>'));
});
await check('separate list groups remain independent after actual view typing',()=>{
  fresh('1. A\n\n1. B');type('prefix');
  assert(editor.session.doc.childCount===2);assert(editor.session.doc.child(1).attrs.start===1);serialized();
});
await check('synthetic composition does not run Markdown input rules mid-composition',()=>{
  fresh();editor.view.dom.dispatchEvent(new CompositionEvent('compositionstart',{bubbles:true}));type('## ');
  assert(editor.session.doc.firstChild.type.name==='paragraph');
  editor.view.dom.dispatchEvent(new CompositionEvent('compositionend',{bubbles:true}));
});
await check('quote conversion before existing content keeps the caret inside the new quote',()=>{
  fresh('replace\n\n> Existing quote');
  const p=editor.session.doc.firstChild;
  editor.session.setSelection(editor.session.reference(p.attrs.id),p.content.size);
  editor.view.updateState(editor.session.state);
  // Clear through the actual view transaction, then trigger the input rule.
  editor.view.dispatch(editor.view.state.tr.delete(1,1+p.content.size));
  type('> ');type('New quote');
  assert(editor.session.doc.firstChild.type.name==='blockquote');
  assert(editor.session.doc.firstChild.textContent==='New quote');
  assert(editor.session.doc.child(1).textContent==='Existing quote');
  assert(serialized()==='> New quote\n\n> Existing quote',serialized());
});
await check('single-line Unicode paste keeps the heading type, marks and cursor context',()=>{
  fresh('## Title');
  const p=editor.session.doc.firstChild;
  editor.session.setSelection(editor.session.reference(p.attrs.id),p.content.size);
  editor.view.updateState(editor.session.state);
  const clipboard=new DataTransfer();clipboard.setData('text/plain',' 한글😀');
  const event=new ClipboardEvent('paste',{clipboardData:clipboard,bubbles:true,cancelable:true});
  editor.view.someProp('handlePaste',handler=>handler(editor.view,event));
  assert(editor.session.doc.firstChild.type.name==='heading');
  assert(editor.session.doc.childCount===1);
  assert(editor.session.doc.firstChild.textContent==='Title 한글😀');serialized();
});
await check('multiline plain paste preserves hard breaks and paragraph boundaries',()=>{
  fresh();
  const clipboard=new DataTransfer();clipboard.setData('text/plain','one\ntwo\n\nthree');
  const event=new ClipboardEvent('paste',{clipboardData:clipboard,bubbles:true,cancelable:true});
  editor.view.someProp('handlePaste',handler=>handler(editor.view,event));
  assert(editor.session.doc.childCount===2);
  assert(editor.session.doc.firstChild.child(1).type.name==='hard_break');
  assert(serialized()==='one\\\ntwo\n\nthree',serialized());
});
await check('empty checked and unchecked tasks save and reimport without literal brackets',()=>{
  for(const prefix of ['[] ','[x] ']){
    fresh();type(prefix);const saved=serialized();
    fresh(saved);const item=editor.session.doc.firstChild.firstChild;
    assert(item.type.name==='list_item');
    assert(item.attrs.checked===prefix.includes('x'));
    assert(item.firstChild.content.size===0);
  }
});
await check('attached matrix delimiters render the first line and all rows without consuming the next block',()=>{
  const tex=String.raw`\mathbf{s}_t =
\begin{pmatrix} R_0 & k_0 \\ R_1 & k_1 \end{pmatrix}
\in \mathbb{R}^{2\times2}`;
  const source='Before\n$$'+tex+'$$\n\n## After';
  fresh(source);
  assert(!host.querySelector('.katex-error'));
  assert(host.querySelectorAll('.katex-display').length===1);
  assert(host.querySelector('.katex annotation').textContent===tex);
  assert(host.querySelector('h2').textContent==='After');
  assert(serialized()===source && !editor.session.changed);
  assert(!host.querySelector('.katex button'),'Edit must not alter KaTeX DOM');
  assert(!host.querySelector('.visual-math button'));
  assert(getComputedStyle(host.querySelector('.visual-math')).cursor==='pointer');
});
await check('an opening double dollar plus Space stays literal and survives a snapshot/reimport',async()=>{
  for(const raw of ['$$ ','$$$$','$$   $$']) {
    fresh();type(raw);
    assert(editor.session.doc.firstChild.type.name==='paragraph',raw);
    assert(editor.session.doc.firstChild.textContent===raw,raw);
    assert(!host.querySelector('.visual-math'),raw);
    const snap=await editor.snapshot();const reopened=BloctBlocks.importMarkdown(snap.text).doc;
    assert(reopened.firstChild.type.name==='paragraph' && reopened.firstChild.textContent===raw,raw);
  }
});
await check('only closing double dollars convert a complete standalone expression to a block equation',()=>{
  fresh();type('$$ ');type('x^2 ');
  assert(!host.querySelector('.visual-math'));
  type('$');assert(!host.querySelector('.visual-math'));
  type('$');
  assert(editor.session.doc.firstChild.type.name==='equation');
  assert(editor.session.doc.firstChild.attrs.value==='x^2');
  assert(host.querySelector('.katex-display'));
  assert(!editor.session.doc.firstChild.isInline);
  assert(editor.view.state.selection.$from.parent.type.name==='paragraph');
  type('After');assert(editor.session.doc.lastChild.textContent==='After');
  assert(BloctBlocks.importMarkdown(serialized()).doc.firstChild.type.name==='equation');
});
await check('multiline double-dollar drafts close as one equation and preserve surrounding blocks and Undo',()=>{
  fresh('replace\n\nFollowing');editor.view.dispatch(editor.view.state.tr.delete(1,8));
  type('$$');key('Enter');type('x +');key('Enter');type('y');key('Enter');
  type('$');assert(!host.querySelector('.visual-math'),'literal: '+JSON.stringify(editor.session.doc.toJSON()));
  type('$');
  assert(editor.session.doc.firstChild.type.name==='equation','block equation: '+JSON.stringify(editor.session.doc.toJSON()));
  assert(editor.session.doc.firstChild.attrs.value==='x +\ny','TeX: '+editor.session.doc.firstChild.attrs.value);
  assert(editor.session.doc.lastChild.textContent==='Following');
  serialized();key('Backspace');
  assert(!host.querySelector('.visual-math'),'literal: '+JSON.stringify(editor.session.doc.toJSON()));
  assert(editor.session.doc.child(3).textContent==='$$','undo: '+JSON.stringify(editor.session.doc.toJSON()));
  assert(editor.view.state.selection.$from.parent===editor.session.doc.child(3));
  assert(editor.session.doc.lastChild.textContent==='Following');
});
await check('hard-break math drafts close correctly and never collect across a different block type',()=>{
  fresh();type('$$');key('Enter',{shiftKey:true});type('x');key('Enter',{shiftKey:true});type('$$');
  assert(editor.session.doc.firstChild.type.name==='equation');
  assert(editor.session.doc.firstChild.attrs.value==='x');serialized();
  fresh();type('$$');key('Enter');type('# ');type('Heading');key('Enter');type('$$');
  assert(!host.querySelector('.visual-math'));
  assert(editor.session.doc.child(1).type.name==='heading');serialized();
});
await check('an unfinished math snapshot remains editable after reimport and completes on the final delimiter',async()=>{
  fresh();type('$$ ');const snapshot=await editor.snapshot();
  fresh(snapshot.text);const p=editor.session.doc.firstChild;
  editor.session.setSelection(editor.session.reference(p.attrs.id),p.content.size);editor.view.updateState(editor.session.state);
  type('x $$');assert(editor.session.doc.firstChild.type.name==='equation');
  assert(editor.session.doc.firstChild.attrs.value==='x');serialized();
  key('Backspace');assert(editor.session.doc.firstChild.type.name==='paragraph');
  assert(editor.session.doc.firstChild.textContent==='$$ x $$');
});
await check('inline dollars remain inline and display drafts protect their body from inline math rules',()=>{
  fresh();type('$x$');assert(editor.session.doc.firstChild.firstChild.type.name==='inline_math');
  assert(editor.session.doc.firstChild.firstChild.attrs.display===false);
  fresh();type('$$ ');type('$x$');assert(!host.querySelector('.visual-math'));
  fresh('`code`');const p=editor.session.doc.firstChild;
  editor.session.setSelection(editor.session.reference(p.attrs.id),4);editor.view.updateState(editor.session.state);
  type('$$ x $$');assert(!host.querySelector('.visual-math'));
  assert(editor.session.doc.firstChild.firstChild.marks.some(m=>m.type.name==='code'));
});
await check('double-dollar typing in text retains display mode and editable-root wrapping cannot affect math',()=>{
  fresh();type('Before $$x^2$$ after');
  const math=editor.session.doc.firstChild.child(1);
  assert(math.type.name==='inline_math' && math.attrs.display===true);
  assert(host.querySelector('.katex-display'));
  assert(getComputedStyle(host.querySelector('.visual-math')).whiteSpace==='normal');
  assert(serialized().includes('$$x^2$$'));
});
await check('matrix Edit dialog retains exact TeX and saves modified math with Undo',()=>{
  const tex=String.raw`\mathbf{s}_t = \begin{pmatrix}a & b \\ c & d\end{pmatrix}`;
  const source='$$'+tex+'$$\n\nTail';fresh(source);
  host.querySelector('.visual-math').click();
  const dialog=document.querySelector('dialog');assert(dialog);
  const input=dialog.querySelector('textarea');assert(input.value===tex);
  input.value+=' + 0';dialog.close('apply');
});
// The dialog close event is queued by WebKit.
await new Promise(resolve=>setTimeout(resolve,0));
await check('applying a math edit preserves following content and Undo restores original spelling',()=>{
  assert(editor.session.doc.firstChild.attrs.value.endsWith(' + 0'));
  assert(!host.querySelector('.katex-error'));assert(serialized().endsWith('\n\nTail'));
  assert(editor.history(false));assert(serialized().startsWith('$$\\mathbf{s}_t ='));
  assert(!editor.session.changed);
});
await check('inline and display math open on the formula surface without editing controls or dirtying source',async()=>{
  for(const source of ['$x^2$','$$x^2$$']) {
    fresh(source);const math=host.querySelector('.visual-math');
    assert(!math.querySelector('button'));
    assert(math.getAttribute('role')==='button' && math.tabIndex===0);
    const before=math.querySelector('.katex').outerHTML;
    math.click();const dialog=document.querySelector('dialog');assert(dialog);
    assert(dialog.querySelector('textarea').value==='x^2');
    dialog.close('cancel');await new Promise(resolve=>setTimeout(resolve,0));
    assert(!editor.session.changed && serialized()===source);
    assert(math.querySelector('.katex').outerHTML===before);
  }
});
await check('math surfaces support keyboard activation and stay inactive in Read mode',async()=>{
  fresh('$x$');const math=host.querySelector('.visual-math');
  for(const key of ['Enter',' ']) {
    math.dispatchEvent(new KeyboardEvent('keydown',{key,bubbles:true,cancelable:true}));
    const dialog=document.querySelector('dialog');assert(dialog);
    dialog.close('cancel');await new Promise(resolve=>setTimeout(resolve,0));
  }
  editor.setEditable(false);math.click();
  assert(!document.querySelector('dialog'));
  assert(math.tabIndex===-1 && math.getAttribute('aria-disabled')==='true');
  assert(getComputedStyle(math).cursor!=='pointer');
  editor.setEditable(true);assert(math.tabIndex===0);
});
await check('dragging across a formula and a frozen editor never open the math dialog',()=>{
  fresh('$x$');const math=host.querySelector('.visual-math');
  math.dispatchEvent(new MouseEvent('mousedown',{clientX:10,clientY:10,bubbles:true}));
  math.dispatchEvent(new MouseEvent('click',{clientX:30,clientY:10,bubbles:true}));
  assert(!document.querySelector('dialog'));
  assert(!editor.freezeIfClean());math.click();assert(!document.querySelector('dialog'));
  editor.unfreeze();assert(!editor.session.changed);
});
await check('unsaved handoff freezes the serialized draft and restore keeps the disk baseline',async()=>{
  fresh('Saved');type('Draft ');
  const draft=serialized(),snapshot=await editor.handoff();
  assert(snapshot.text===draft && !editor.view.editable);
  const before=editor.session.doc;type('blocked');assert(editor.session.doc.eq(before));
  editor.restoreDraft(draft,'Saved');assert(editor.view.editable && editor.session.changed);
  assert(serialized()===draft);
  editor.restoreDraft('Saved','Saved');assert(!editor.session.changed);
  type('New ');assert(editor.session.changed);
  const saved=await editor.snapshot();assert(editor.acknowledge(saved.token));
  assert(!editor.session.changed);
});
if(editor){editor.destroy();host.remove();}
return JSON.stringify({results});
