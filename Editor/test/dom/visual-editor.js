const results=[];
const check=async(name,body)=>{try{await body();results.push({name,pass:true});}catch(error){results.push({name,pass:false,detail:String(error)+'\n'+String(error.stack||'')});}};
const assert=(value,message)=>{if(!value)throw new Error(message||'assertion failed');};
let editor,host;
const fresh=(markdown='',options={})=>{
  if(editor){editor.destroy();host.remove();}
  host=document.createElement('div');document.body.append(host);
  editor=BloctBlocks.mountVisualEditor(host,markdown,{imageURL:source=>source.startsWith('data:image/')?source:null,...options});
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
  const event=new KeyboardEvent('keydown',{key:value,keyCode:{Enter:13,Backspace:8,Delete:46,Tab:9,z:90,b:66}[value]||0,bubbles:true,cancelable:true,...options});
  let handled=false;editor.view.someProp('handleKeyDown',handler=>{handled=handler(editor.view,event);return handled;});return handled;
};
const serialized=()=>editor.session.markdown();
const blankClick=(target=editor.view.dom,options={})=>{
  const rect=editor.view.dom.getBoundingClientRect(),last=editor.view.dom.lastElementChild.getBoundingClientRect();
  const event=new MouseEvent('mousedown',{button:0,detail:1,bubbles:true,cancelable:true,
    clientX:rect.left+rect.width/2,clientY:last.bottom+12,...options});
  target.dispatchEvent(event);return event.defaultPrevented;
};
const selectTableCell=(row,column,offset=0,tableIndex=0)=>{
  const tables=[];editor.session.doc.descendants(n=>{if(n.type.name==='table')tables.push(n);});
  const cell=tables[tableIndex].child(row).child(column);
  assert(editor.session.setSelection(editor.session.reference(cell.attrs.id),offset));
  editor.view.updateState(editor.session.state);editor.focus();return cell;
};

await check('empty document blank click reuses the first line without dirtying or adding a leading blank',async()=>{
  fresh();const revision=editor.session.revision,id=editor.session.doc.firstChild.attrs.id;
  assert(blankClick());assert(blankClick(document.body));
  assert(editor.session.doc.childCount===1 && editor.session.doc.firstChild.attrs.id===id);
  assert(editor.session.revision===revision && !editor.session.changed && editor.view.hasFocus());
  type('First 한글😀');const snap=await editor.snapshot();
  assert(snap.text==='First 한글😀');assert(editor.acknowledge(snap.token));
  assert(editor.history(false));assert(serialized()==='');
});
for(const source of ['Last **bold**','# Heading','- last item','> quote','```js\ncode\n```','$$x^2$$','---',
  '| A | B |\n| --- | --- |\n| C | D |','<section>protected</section>','한글😀\r\n\r\n끝']) {
  await check(`blank click after final ${JSON.stringify(source)} opens plain text and supports save/reimport/Undo`,async()=>{
    fresh(source);const count=editor.session.doc.childCount;
    assert(blankClick(document.body));assert(editor.session.doc.childCount===count+1);
    assert(editor.session.state.selection.$from.parent.type.name==='paragraph');
    assert(blankClick());assert(editor.session.doc.childCount===count+1);
    type('Next');assert(editor.session.doc.lastChild.textContent==='Next');
    assert(editor.session.doc.lastChild.firstChild.marks.length===0);
    const snapshot=await editor.snapshot(),reopened=BloctBlocks.importMarkdown(snapshot.text).doc;
    assert(snapshot.text.startsWith(source));assert(reopened.lastChild.type.name==='paragraph' && reopened.lastChild.textContent==='Next');
    assert(editor.history(false));
    if(editor.session.doc.childCount!==count)assert(editor.history(false));
    assert(serialized()===source);assert(editor.history(true));
  });
}
await check('blank click ignores read-only, frozen, composition, controls, modified and content clicks',()=>{
  fresh('text');const before=editor.session.doc;
  editor.setEditable(false);assert(!blankClick());editor.setEditable(true);
  assert(!editor.freezeIfClean());assert(!blankClick());editor.unfreeze();
  editor.view.input.composing=true;assert(!blankClick());editor.view.input.composing=false;
  assert(!blankClick(document.createElement('button')));assert(!blankClick(host.querySelector('p')));
  for(const options of [{button:2},{detail:2},{shiftKey:true},{metaKey:true},{ctrlKey:true},{altKey:true},{clientY:0},{clientX:-10}])assert(!blankClick(editor.view.dom,options));
  assert(editor.session.doc.eq(before) && !editor.session.changed);
});
await check('blank click listener is removed on destroy and does not affect a second editor',()=>{
  fresh('first');const otherHost=document.createElement('div');document.body.append(otherHost);
  const other=BloctBlocks.mountVisualEditor(otherHost,'second');
  assert(blankClick(editor.view.dom));assert(other.session.doc.childCount===1);
  other.destroy();otherHost.remove();
  const dom=editor.view.dom;editor.destroy();
  const event=new MouseEvent('mousedown',{button:0,bubbles:true,cancelable:true,clientY:500,clientX:100});
  document.body.dispatchEvent(event);assert(!event.defaultPrevented);
  host.remove();editor=null;
});

for(const source of ['', 'End', 'End\n\n\n', '# Heading', '- item', '> Quote', '```js\ncode\n```', '$$x$$', '| A | B |\n| --- | --- |\n| C | D |', '<section>raw</section>']) {
  await check(`opening trailing Text ${JSON.stringify(source)} stays clean and accepts input without duplicate blanks`,async()=>{
    fresh(source,{trailingParagraph:true});
    const initial=editor.session.doc,count=initial.childCount;
    const last=initial.lastChild;assert(last.type.name==='paragraph' && !last.content.size);
    assert(!editor.session.changed && serialized()===source);
    assert(blankClick());assert(blankClick());assert(editor.session.doc.childCount===count);
    type('Next');assert(editor.session.doc.lastChild.textContent==='Next');
    const snapshot=await editor.snapshot();assert(snapshot.text.includes('Next'));
    assert(editor.history(false));assert(serialized()===source && !editor.session.changed);
    editor.reload(source);assert(editor.session.doc.childCount===count && !editor.session.changed);
    const handoff=await editor.handoff();assert(handoff.text===source);
    editor.restoreDraft(source,source);assert(editor.session.doc.childCount===count && !editor.session.changed);
  });
}
for(let level=1;level<=6;level++)await check(`H${level}: typed marker converts to editable heading and placeholder`,()=>{
  fresh();type('#'.repeat(level)+' ');
  assert(editor.session.doc.firstChild.type.name==='heading');
  assert(editor.session.doc.firstChild.attrs.level===level);
  assert(!host.previousElementSibling?.classList.contains('visual-toolbar'));
  assert(host.querySelector(`h${level}[data-placeholder="Header ${level}"]`));
  assert(!document.querySelector('textarea'),'no raw Markdown textarea in normal editing');
  type('Title');assert(host.querySelector(`h${level}`).textContent==='Title');
  assert(serialized()==='#'.repeat(level)+' Title');
});
for(const [prefix,kind,selector] of [
  ['> ','blockquote','blockquote p'],
  ['- ','bullet_list','ul p'],
  ['+ ','bullet_list','ul p'],
  ['3. ','ordered_list','ol p'],
  ['[] ','bullet_list','li.task-item p'],
  ['[x] ','bullet_list','li.task-item p'],
  ['```js ','code_block','pre[data-placeholder="Code"]'],
  ['~~~ ','code_block','pre[data-placeholder="Code"]'],
])await check(`${JSON.stringify(prefix)}: block conversion, placeholder and round-trip`,()=>{
  fresh();type(prefix);assert(editor.session.doc.firstChild.type.name===kind,serialized());
  assert(host.querySelector(selector),host.innerHTML);
  if(kind!=='code_block')assert(!host.querySelector('[data-placeholder]'),'ordinary blocks must have no guide text');
  type('content');serialized();
});
await check('heading Enter creates paragraph; Shift-Enter stays within text block',()=>{
  fresh();type('## Title');assert(key('Enter'));type('Body');
  assert(editor.session.doc.child(1).type.name==='paragraph');
  key('Enter',{shiftKey:true});type('continued');
  assert(serialized()==='## Title\nBody\\\ncontinued',serialized());
  key('Enter');type('Next');assert(serialized()==='## Title\nBody\\\ncontinued\n\nNext',serialized());
  key('Enter');type('- item');assert(serialized().endsWith('\n\nNext\n- item'),serialized());
});
await check('quote Enter and empty quote exit preserve block structure',()=>{
  fresh();type('> Quote');key('Enter');type('second');serialized();
  key('Enter');key('Enter');type('outside');serialized();
  assert(editor.session.doc.lastChild.type.name==='paragraph');
});
for(const [marker,kind] of [['>','blockquote'],['-','bullet_list'],['+','bullet_list'],['*','bullet_list'],
  ['1.','ordered_list'],['3)','ordered_list'],['#','heading'],['######','heading'],
  ['[]','bullet_list'],['[ ]','bullet_list'],['[\u00a0]','bullet_list'],['[x]','bullet_list'],
  ['```js','code_block'],['~~~','code_block'],['---','horizontal_rule'],['***','horizontal_rule']]) {
  await check(`WebKit NBSP after ${marker} converts and Undo keeps the caret before Following`,()=>{
    fresh('replace\n\nFollowing');editor.view.dispatch(editor.view.state.tr.delete(1,8));
    type(marker+'\u00a0');assert(editor.session.doc.firstChild.type.name===kind,JSON.stringify(editor.session.doc.toJSON()));
    assert(key('Backspace'));assert(editor.session.doc.firstChild.textContent===marker+'\u00a0');
    type('X');assert(editor.session.doc.firstChild.textContent===marker+'\u00a0X');
    assert(editor.session.doc.lastChild.textContent==='Following');serialized();
  });
}
await check('Space markers convert after exiting an empty quote and after splitting or clearing text',()=>{
  for(const space of [' ','\u00a0'])for(const marker of ['>','-'])for(const origin of ['quote','split','clear']) {
    fresh('Before');blankClick();
    if(origin==='quote'){assert(editor.format('blockquote'));assert(key('Backspace'));}
    if(origin==='split'){type('content');key('Enter');}
    if(origin==='clear'){type('content');const {$from}=editor.view.state.selection;editor.view.dispatch(editor.view.state.tr.delete($from.start(),$from.end()));}
    type(marker+space);assert(editor.session.doc.lastChild.type.name===(marker==='>'?'blockquote':'bullet_list'));
    type('Next');assert(editor.session.doc.lastChild.textContent==='Next');serialized();
  }
});
await check('NBSP bullet separator and checkbox spaces support sequential task conversion',()=>{
  fresh();type('-\u00a0[\u00a0]\u00a0');
  assert(editor.session.doc.firstChild.firstChild.attrs.checked===false);
  type('Task');assert(serialized()==='- [ ] Task');
  fresh();type('*\u00a0[x]\u00a0');
  assert(editor.session.doc.firstChild.firstChild.attrs.checked===true);
  type('Done');assert(serialized()==='* [x] Done');
});
await check('NBSP in pasted, non-marker, code and composing text does not trigger block rules',()=>{
  fresh();type('body >\u00a0');assert(editor.session.doc.firstChild.type.name==='paragraph');
  fresh('```\ncode\n```');type('>\u00a0');assert(editor.session.doc.firstChild.type.name==='code_block');
  fresh();editor.view.input.composing=true;type('>\u00a0');editor.view.input.composing=false;
  assert(editor.session.doc.firstChild.type.name==='paragraph');
  fresh();editor.view.dispatch(editor.view.state.tr.insertText('>\u00a0').setMeta('uiEvent','paste'));
  assert(editor.session.doc.firstChild.type.name==='paragraph');
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
await check('empty table cells and ordinary text stay blank without guide text',()=>{
  fresh('| A |  |\n| --- | --- |\n|  | B |');
  assert(host.querySelectorAll('td').length===4);
  assert(!host.querySelector('td[data-placeholder],td.is-empty'));
  assert([...host.querySelectorAll('td')].filter(cell=>!cell.textContent).length===2);
  assert(!serialized().includes('Cell'));
  fresh();assert(editor.format('table'));
  assert(!host.querySelector('td[data-placeholder],td.is-empty'));
  assert(host.querySelector('p') && !host.querySelector('p[data-placeholder]'),'ordinary paragraph remains unlabelled');
  type('typed');assert(host.querySelector('td').textContent==='typed');serialized();
});
await check('table vertical arrows keep the column and leave the source and dirty state unchanged',()=>{
  const source='Before\n\n| A | B | C |\n| --- | --- | --- |\n| D | E | F |\n| G | H | I |\n\n| X | Y |\n| --- | --- |\n| Z | W |';
  fresh(source);selectTableCell(1,1);
  assert(key('ArrowUp'));assert(editor.view.state.selection.$from.parent.textContent==='B');
  assert(key('ArrowDown'));assert(editor.view.state.selection.$from.parent.textContent==='E');
  assert(key('ArrowDown'));assert(editor.view.state.selection.$from.parent.textContent==='H');
  assert(key('ArrowDown'));assert(editor.view.state.selection.$from.parent.textContent==='X','bottom edge moves into the following area');
  selectTableCell(0,1);assert(key('ArrowUp'));assert(editor.view.state.selection.$from.parent.textContent==='Before');
  assert(serialized()===source && !editor.session.changed);
});
await check('Up from every first-row column exits to the preceding text block without editing',()=>{
  for(const prefix of ['Before','## Before','> Before','- Before'])for(const column of [0,1,2]) {
    const source=prefix+'\n\n| A | B | C |\n| --- | --- | --- |\n| D | E | F |';
    fresh(source);selectTableCell(0,column);assert(key('ArrowUp'));
    assert(editor.view.state.selection.$from.parent.textContent==='Before');
    assert(editor.view.state.selection.$from.parentOffset===6);
    assert(serialized()===source && !editor.session.changed);
    type(' up');assert(editor.session.doc.firstChild.textContent==='Before up');
    assert(editor.history(false));assert(serialized()===source && !editor.session.changed);
  }
});
await check('Up before a document-start table creates an editable paragraph and Undo restores the exact table',()=>{
  for(const prefix of ['', '> ']) {
    const source=prefix+'| A | B |\n'+prefix+'| --- | --- |\n'+prefix+'| C | D |';
    fresh(source);const original=editor.session.doc;selectTableCell(0,1);assert(key('ArrowUp'));
    assert(editor.session.doc.firstChild.type.name==='paragraph');
    assert(editor.view.state.selection.$from.parent===editor.session.doc.firstChild);
    assert(editor.session.doc.child(1).type===original.firstChild.type
      && editor.session.doc.child(1).content.eq(original.firstChild.content),'table contents preserved after its blank-line prefix changes');serialized();
    assert(editor.history(false));assert(editor.session.doc.eq(original) && serialized()===source);
    assert(editor.history(true));type('Above table');
    const reopened=BloctBlocks.importMarkdown(serialized()).doc;
    assert(reopened.firstChild.textContent==='Above table');
    assert(reopened.child(1).type.name===(prefix?'blockquote':'table'));
  }
});
await check('Up selects an immediately preceding atomic block without deleting or skipping it',()=>{
  const source='$$x$$\n\n| A | B |\n| --- | --- |\n| C | D |';
  fresh(source);selectTableCell(0,1);assert(key('ArrowUp'));
  assert(editor.view.state.selection.node?.type.name==='equation');
  assert(serialized()===source && !editor.session.changed);
});
await check('Up inside a wrapped first-row cell exits only from its first visual line',()=>{
  fresh('Before\n\n| A | '+('wrapped words '.repeat(40)).trim()+' |\n| --- | --- |\n| C | D |');
  host.style.width='240px';selectTableCell(0,1,100);
  assert(!editor.view.endOfTextblock('up'));assert(!key('ArrowUp'));
  selectTableCell(0,1);assert(key('ArrowUp'));
  assert(editor.view.state.selection.$from.parent.textContent==='Before' && !editor.session.changed);
});
await check('Down from every last-row column exits to the following text block without editing',()=>{
  for(const suffix of ['After','## After','> After','- After'])for(const column of [0,1,2]) {
    const source='| A | B | C |\n| --- | --- | --- |\n| D | E | F |\n\n'+suffix;
    fresh(source);selectTableCell(1,column,1);assert(key('ArrowDown'));
    assert(editor.view.state.selection.$from.parent.textContent==='After');
    assert(editor.view.state.selection.$from.parentOffset===0);
    assert(serialized()===source && !editor.session.changed);
    type('below ');assert(editor.session.doc.lastChild.textContent==='below After');
    assert(editor.history(false));assert(serialized()===source && !editor.session.changed);
  }
});
await check('Down after a document-end table creates an editable paragraph and Undo restores source',()=>{
  for(const prefix of ['', '> ']) {
    const source=prefix+'| A | B |\n'+prefix+'| --- | --- |\n'+prefix+'| C | D |';
    fresh(source);const original=editor.session.doc;selectTableCell(1,1);assert(key('ArrowDown'));
    assert(editor.session.doc.lastChild.type.name==='paragraph');
    assert(editor.view.state.selection.$from.parent===editor.session.doc.lastChild);
    assert(editor.session.doc.firstChild.eq(original.firstChild));serialized();
    assert(editor.history(false));assert(editor.session.doc.eq(original) && serialized()===source);
    assert(editor.history(true));type('Below table');
    const reopened=BloctBlocks.importMarkdown(serialized()).doc;
    assert(reopened.lastChild.textContent==='Below table');
    assert(reopened.firstChild.type.name===(prefix?'blockquote':'table'));
  }
});
await check('Down selects an immediately following atomic block without changing it',()=>{
  const source='| A | B |\n| --- | --- |\n| C | D |\n\n$$x$$';
  fresh(source);selectTableCell(1,1);assert(key('ArrowDown'));
  assert(editor.view.state.selection.node?.type.name==='equation');
  assert(serialized()===source && !editor.session.changed);
});
await check('Down inside a wrapped last-row cell exits only from its last visual line',()=>{
  fresh('| A | B |\n| --- | --- |\n| short | '+('wrapped words '.repeat(40)).trim()+' |\n\nAfter');
  host.style.width='240px';const cell=selectTableCell(1,1,100);
  assert(!editor.view.endOfTextblock('down'));assert(!key('ArrowDown'));
  selectTableCell(1,1,cell.content.size);assert(key('ArrowDown'));
  assert(editor.view.state.selection.$from.parent.textContent==='After' && !editor.session.changed);
});
await check('Down from an empty last-row cell uses the following empty paragraph without inserting another',()=>{
  fresh();assert(editor.format('table'));const before=editor.session.doc;
  selectTableCell(1,1);assert(key('ArrowDown'));
  assert(editor.view.state.selection.$from.parent===editor.session.doc.lastChild);
  assert(editor.session.doc.eq(before));serialized();
});
await check('horizontal cell arrows cross only at text edges and never wrap to another row',()=>{
  fresh('| AA | BB |\n| --- | --- |\n| CC | DD |');
  selectTableCell(1,1,1);assert(!key('ArrowLeft'));assert(!key('ArrowRight'));
  selectTableCell(1,1);assert(key('ArrowLeft'));assert(editor.view.state.selection.$from.parent.textContent==='CC');
  assert(editor.view.state.selection.$from.parentOffset===2);
  assert(key('ArrowRight'));assert(editor.view.state.selection.$from.parent.textContent==='DD');
  assert(editor.view.state.selection.$from.parentOffset===0);
  selectTableCell(1,0);assert(key('ArrowLeft'));assert(editor.view.state.selection.$from.parent.textContent==='CC');
  selectTableCell(0,1,2);assert(key('ArrowRight'));assert(editor.view.state.selection.$from.parent.textContent==='BB');
  assert(!key('ArrowUp',{shiftKey:true}) && !key('ArrowLeft',{altKey:true}));
  assert(!editor.session.changed);
});
await check('vertical cell navigation handles empty, short and Unicode target text',()=>{
  fresh('| A | 😀 |\n| --- | --- |\n|  | Long |');
  selectTableCell(1,1,1);assert(key('ArrowUp'));assert(editor.view.state.selection.$from.parent.textContent==='😀');
  assert(editor.view.state.selection.$from.parentOffset===0,'no surrogate split');
  selectTableCell(0,0,1);assert(key('ArrowDown'));assert(editor.view.state.selection.$from.parent.content.size===0);
  assert(editor.view.state.selection.$from.parentOffset===0);serialized();
});
await check('wrapped table cells keep native vertical movement until the first or last visual line',()=>{
  fresh('| A | B |\n| --- | --- |\n| short | '+('wrapped words '.repeat(40)).trim()+' |');
  host.style.width='240px';
  const cell=selectTableCell(1,1,100);
  assert(!editor.view.endOfTextblock('up') && !editor.view.endOfTextblock('down'));
  assert(!key('ArrowUp') && !key('ArrowDown'));
  assert(editor.view.state.selection.$from.parent===cell && !editor.session.changed);
});
await check('Enter at the last cell inserts a paragraph immediately below this table, not in the next table',()=>{
  const source='| A | B |\n| --- | --- |\n| C | D |\n\n| Next | Table |\n| --- | --- |\n| Keep | Safe |';
  fresh(source);const next=editor.session.doc.child(1);selectTableCell(1,1,1);
  assert(key('Enter'));assert(editor.session.doc.childCount===3);
  assert(editor.session.doc.child(1).type.name==='paragraph');
  assert(editor.view.state.selection.$from.parent===editor.session.doc.child(1));
  assert(editor.session.doc.child(2).eq(next));serialized();
  assert(editor.history(false));assert(serialized()===source && !editor.session.changed);
  assert(editor.history(true));type('Below first');
  assert(serialized().includes('\n\nBelow first\n\n| Next | Table |'));
  const reopened=BloctBlocks.importMarkdown(serialized()).doc;
  assert(reopened.child(1).type.name==='paragraph' && reopened.child(1).textContent==='Below first');
  assert(reopened.child(2).textContent==='NextTableKeepSafe');
});
await check('Enter in other cells stays in the current table; at document end it creates editable text',()=>{
  fresh('| A | B |\n| --- | --- |\n| C | D |');
  selectTableCell(0,1);assert(key('Enter'));assert(editor.view.state.selection.$from.parent.textContent==='C');
  assert(!editor.session.changed);
  selectTableCell(1,1);assert(key('Enter'));type('After table');
  assert(editor.session.doc.lastChild.type.name==='paragraph');
  assert(serialized().endsWith('\n\nAfter table'));
  fresh('| A | B |\n| --- | --- |\n| C | D |\n\nExisting paragraph');
  selectTableCell(1,1);key('Enter');type('New paragraph');
  assert(editor.session.doc.child(1).textContent==='New paragraph');
  assert(editor.session.doc.lastChild.textContent==='Existing paragraph');serialized();
});
await check('Enter from every table column moves to the next row first cell; Tab keeps cell order',()=>{
  const source='| A | B | C |\n| --- | --- | --- |\n| D | E | F |\n| G | H | I |\n\n| Next | Table |\n| --- | --- |\n| Keep | Safe |';
  for(const row of [0,1])for(const column of [0,1,2]) {
    fresh(source);selectTableCell(row,column,1);assert(key('Enter'));
    assert(editor.view.state.selection.$from.parent===editor.session.doc.firstChild.child(row+1).firstChild);
    assert(editor.view.state.selection.$from.parentOffset===0);
    assert(serialized()===source && !editor.session.changed);
    type('row-start');assert(editor.session.doc.firstChild.child(row+1).firstChild.textContent.startsWith('row-start'));
    assert(editor.history(false));assert(serialized()===source && !editor.session.changed);
  }
  for(const column of [0,1,2]) {
    fresh(source);selectTableCell(2,column);assert(key('Enter'));
    assert(editor.view.state.selection.$from.parent.type.name==='paragraph');
    assert(editor.session.doc.child(1).type.name==='paragraph');
    assert(editor.session.doc.lastChild.textContent==='NextTableKeepSafe');serialized();
  }
  fresh(source);selectTableCell(1,1);assert(key('Tab'));
  assert(editor.view.state.selection.$from.parent.textContent==='F');
});
await check('Enter targets an empty next row first cell and preserves existing cell text',()=>{
  const source='| A | B |\n| --- | --- |\n|  |  |\n| C | D |';
  fresh(source);selectTableCell(0,0);assert(key('Enter'));
  assert(editor.view.state.selection.$from.parent===editor.session.doc.firstChild.child(1).firstChild);
  type('first');assert(editor.session.doc.firstChild.child(1).firstChild.textContent==='first');
  assert(editor.session.doc.firstChild.firstChild.textContent==='AB');serialized();
});
await check('Shift-Enter from every column inserts an empty row and selects its first cell, preserving existing data',()=>{
  const source='| A | B | C |\n| :--- | :---: | ---: |\n| D | E | F |\n| G | H | I |\n\nFollowing';
  for(const row of [0,1,2])for(const column of [0,1,2]) {
    fresh(source);const before=editor.session.doc.firstChild;selectTableCell(row,column);
    assert(key('Enter',{shiftKey:true}));const table=editor.session.doc.firstChild;
    assert(table.childCount===4 && table.child(row+1).childCount===3);
    assert(table.child(row+1).textContent==='');
    assert(editor.view.state.selection.$from.parent===table.child(row+1).firstChild);
    assert(editor.view.state.selection.$from.parentOffset===0);
    for(let i=0;i<3;i++)assert(table.child(i>row?i+1:i).eq(before.child(i)));
    assert(JSON.stringify(table.attrs.align)===JSON.stringify(['left','center','right']));
    assert(editor.session.doc.lastChild.textContent==='Following');
    const reopened=BloctBlocks.importMarkdown(serialized()).doc.firstChild;
    assert(reopened.childCount===4 && !reopened.child(row+1).textContent);
    assert(editor.history(false));assert(serialized()===source && !editor.session.changed);
    assert(editor.history(true));assert(editor.session.doc.firstChild.childCount===4);
  }
});
await check('inserted row accepts text, repeated insertion and snapshots preserve row order and second table',async()=>{
  const source='| A | B |\n| --- | --- |\n| C | D |\n\n| Next | Table |\n| --- | --- |\n| Keep | Safe |';
  fresh(source);selectTableCell(0,1);key('Enter',{shiftKey:true});type('middle');
  key('Enter',{shiftKey:true});type('another');
  const table=editor.session.doc.firstChild;
  assert(table.childCount===4 && table.child(1).firstChild.textContent==='middle');
  assert(table.child(2).firstChild.textContent==='another' && table.lastChild.textContent==='CD');
  const snapshot=await editor.snapshot();assert(editor.acknowledge(snapshot.token));
  const reopened=BloctBlocks.importMarkdown(snapshot.text).doc;
  assert(reopened.firstChild.childCount===4 && reopened.child(1).textContent==='NextTableKeepSafe');
});
await check('table exit and row insertion work inside quotes and preserve CRLF',()=>{
  const source='> | A | B |\r\n> | --- | --- |\r\n> | C | D |\r\n\r\nOutside';
  fresh(source);selectTableCell(0,1);key('Enter',{shiftKey:true});type('inside');
  const table=editor.session.doc.firstChild.firstChild;
  assert(table.childCount===3 && table.child(1).firstChild.textContent==='inside');
  selectTableCell(2,1);key('Enter');type('Below quoted table');
  assert(editor.session.doc.firstChild.child(1).type.name==='paragraph');
  assert(editor.session.doc.lastChild.textContent==='Outside');
  const output=serialized();assert(output.includes('> Below quoted table'));
  assert(!/(^|[^\r])\n/.test(output),'CRLF preserved');
});
await check('new row first-cell focus supports arrows, next-row Enter and unmarked text after a formatted source cell',()=>{
  fresh('| A | **B** |\n| --- | --- |\n| C | D |');
  selectTableCell(0,1,1);key('Enter',{shiftKey:true});type('new');
  const row=editor.session.doc.firstChild.child(1);
  assert(row.firstChild.textContent==='new' && !row.firstChild.firstChild.marks.length);
  assert(key('ArrowRight'));assert(editor.view.state.selection.$from.parent===row.child(1));
  assert(key('Enter'));assert(editor.view.state.selection.$from.parent.textContent==='C');
  assert(editor.view.state.selection.$from.parentOffset===0);serialized();
});
await check('Tab shares local cell order and cannot jump into a later table',()=>{
  fresh('| A | B |\n| --- | --- |\n| C | D |\n\n| Next | Table |\n| --- | --- |\n| Keep | Safe |');
  selectTableCell(1,0);assert(key('Tab'));assert(editor.view.state.selection.$from.parent.textContent==='D');
  assert(key('Tab',{shiftKey:true}));assert(editor.view.state.selection.$from.parent.textContent==='C');
  selectTableCell(1,1);assert(key('Tab'));assert(editor.view.state.selection.$from.parent.type.name==='paragraph');
  assert(editor.session.doc.lastChild.textContent==='NextTableKeepSafe');serialized();
});
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
await check('formatted inline code mounts, retains marks through typing, snapshot and Undo',async()=>{
  for(const source of ['**`address`**','*`address`*','[`address`](https://example.invalid)',
    '**[*`address`*](https://example.invalid)**','| Bits |\n| --- |\n| `000001`**`00`** |']) {
    fresh(source);let at=0,marks;
    editor.session.doc.descendants((node,pos)=>{
      if(!marks && node.isText && node.marks.some(m=>m.type.name==='code') && node.marks.length>1) {at=pos;marks=node.marks;}
    });
    assert(marks,source);assert(host.querySelector('strong code,em code,[data-link-source] code,code [data-link-source]'),host.innerHTML);
    const $pos=editor.session.doc.resolve(at);
    assert(editor.session.setSelection(editor.session.reference($pos.parent.attrs.id),$pos.parentOffset+1),source);
    editor.view.updateState(editor.session.state);
    type('X');const snapshot=await editor.snapshot();
    assert(editor.session.doc.nodeAt(at).marks.map(m=>m.type.name).join(',')===marks.map(m=>m.type.name).join(','));
    assert(BloctBlocks.importMarkdown(snapshot.text).doc.textContent.includes('X'));
    assert(editor.history(false));assert(serialized()===source);
  }
});
await check('Markdown typing stays literal inside an existing inline code mark',()=>{
  for(const literal of ['**bold**','*italic*','`code`','$x$','[link](https://example.invalid)','![image](a.png)','> ','- ','# ']) {
    fresh('`seed`');const p=editor.session.doc.firstChild;
    editor.session.setSelection(editor.session.reference(p.attrs.id),2);editor.view.updateState(editor.session.state);
    type(literal);assert(editor.session.doc.childCount===1 && editor.session.doc.firstChild.type.name==='paragraph');
    assert(editor.session.doc.firstChild.textContent==='se'+literal+'ed');
    assert(editor.session.doc.firstChild.childCount===1 && editor.session.doc.firstChild.firstChild.marks.map(m=>m.type.name).join(',')==='code');
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
for(const prefix of ['> Previous','- Previous','1. Previous','## Previous','Previous','```\nPrevious\n```']) {
  await check(`empty text Backspace after ${JSON.stringify(prefix)} selects the preceding block end without rewrapping`,()=>{
    fresh(prefix);blankClick();
    assert(editor.format('blockquote'));assert(key('Backspace'));
    assert(editor.session.doc.lastChild.type.name==='paragraph' && !editor.session.doc.lastChild.content.size);
    const previous=editor.session.doc.firstChild;
    assert(key('Backspace'));assert(editor.session.doc.childCount===1);
    assert(editor.session.doc.firstChild.eq(previous));
    assert(editor.view.state.selection.$from.parent.textContent==='Previous');
    assert(editor.view.state.selection.$from.parentOffset===8);
    type('X');assert(editor.session.doc.firstChild.textContent==='PreviousX');serialized();
    assert(editor.history(false));assert(editor.history(false));
    assert(editor.session.doc.childCount===2 && !editor.session.doc.lastChild.content.size);
  });
}
await check('empty first text Backspace is a no-op and protected previous nodes are selected without deletion',()=>{
  fresh();const original=editor.session.doc;assert(key('Backspace'));assert(editor.session.doc.eq(original));
  for(const source of ['---','<section>protected</section>']) {
    fresh(source);blankClick();const previous=editor.session.doc.firstChild;
    assert(key('Backspace'));assert(editor.session.doc.childCount===1 && editor.session.doc.firstChild.eq(previous));
    assert(editor.view.state.selection.node===editor.session.doc.firstChild);serialized();
  }
});
for(const prefix of ['Previous','## Previous','> Previous','> First\n>\n> Previous',
  '- First\n- Previous','3. First\n4. Previous','- [x] Previous',
  '- Parent\n  1. First\n  2. Previous','> 3. First\n> 4. Previous']) {
  for(const backwards of [true,false])await check(`${backwards?'Backspace':'Delete'} joins Text into the last sentence of ${JSON.stringify(prefix)}`,async()=>{
    const source=prefix+'\n\n**Next** tail\n\nFollowing';fresh(source);
    const previous=editor.session.doc.firstChild,right=editor.session.doc.child(1);
    let lastText;
    previous.descendants(node=>{if(['paragraph','heading'].includes(node.type.name))lastText=node;});
    if(previous.isTextblock)lastText=previous;
    const target=backwards?right:lastText,offset=backwards?0:target.content.size;
    assert(editor.session.setSelection(editor.session.reference(target.attrs.id),offset));editor.view.updateState(editor.session.state);
    const position=editor.view.state.selection.from;
    assert(key(backwards?'Backspace':'Delete'));assert(editor.session.doc.childCount===2,JSON.stringify(editor.session.doc.toJSON()));
    assert(editor.session.doc.firstChild.type===previous.type);
    const cursor=editor.view.state.selection.$from;
    assert(cursor.parent.textContent==='PreviousNext tail',cursor.parent.textContent);
    assert(cursor.parentOffset===8);assert(cursor.parent.attrs.id===lastText.attrs.id);
    assert(cursor.parent.child(1).marks.some(m=>m.type.name==='strong'));
    assert(editor.session.doc.lastChild.textContent==='Following');
    if(previous.type.name.endsWith('_list'))assert(editor.session.doc.firstChild.childCount===previous.childCount,'no extra item/number');
    const snapshot=await editor.snapshot();assert(editor.acknowledge(snapshot.token));
    assert(BloctBlocks.importMarkdown(snapshot.text).doc.textContent===editor.session.doc.textContent);
    assert(editor.history(false));assert(serialized()===source);assert(editor.view.state.selection.from===position);
    assert(editor.history(true));type('X');assert(editor.view.state.selection.$from.parent.textContent==='PreviousXNext tail');serialized();
  });
}
await check('boundary merge preserves CRLF, Unicode and an empty right Text without adding a list item',()=>{
  for(const backwards of [true,false]) {
    fresh('2. 첫째\r\n3. 한글😀');blankClick();
    const root=editor.session.doc.firstChild,last=root.lastChild.firstChild,p=editor.session.doc.lastChild;
    const target=backwards?p:last;
    assert(editor.session.setSelection(editor.session.reference(target.attrs.id),backwards?0:target.content.size));editor.view.updateState(editor.session.state);
    assert(key(backwards?'Backspace':'Delete'));
    assert(editor.session.doc.childCount===1 && editor.session.doc.firstChild.childCount===2);
    assert(editor.view.state.selection.$from.parentOffset===4);type('X');
    assert(serialized()==='2. 첫째\r\n3. 한글😀X');
  }
});
await check('forward merge does not skip another list item or consume an isolating table',()=>{
  fresh('1. First\n2. Previous\n\nNext');
  const first=editor.session.doc.firstChild.firstChild.firstChild;
  editor.session.setSelection(editor.session.reference(first.attrs.id),first.content.size);editor.view.updateState(editor.session.state);
  key('Delete');assert(editor.session.doc.lastChild.textContent==='Next');
  fresh('Before\n\n| A | B |\n| --- | --- |\n| C | D |');
  const p=editor.session.doc.firstChild;
  editor.session.setSelection(editor.session.reference(p.attrs.id),p.content.size);editor.view.updateState(editor.session.state);
  key('Delete');assert(editor.session.doc.lastChild.type.name==='table');
  assert(editor.session.doc.lastChild.textContent==='ABCD');
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
  assert(editor.session.doc.firstChild.attrs.value===' x^2 ');
  assert(host.querySelector('.katex-display'));
  assert(!editor.session.doc.firstChild.isInline);
  assert(editor.view.state.selection.$from.parent.type.name==='paragraph');
  type('After');assert(editor.session.doc.lastChild.textContent==='After');
  assert(serialized().startsWith('$$ x^2 $$\n'),'typed spelling: '+serialized());
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
  assert(editor.session.doc.firstChild.attrs.value===' x ');serialized();
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
await check('line breaks typed inside math stay line breaks of the TeX, never object characters',()=>{
  fresh();type('See $$a = 1');key('Enter',{shiftKey:true});type('b = 2$$ done');
  let math=editor.session.doc.firstChild.child(1);
  assert(math.type.name==='inline_math' && math.attrs.display===true,JSON.stringify(editor.session.doc.toJSON()));
  assert(math.attrs.value==='a = 1\nb = 2','TeX: '+JSON.stringify(math.attrs.value));
  assert(!host.querySelector('.katex-error') && !serialized().includes('\uFFFC'));
  assert(serialized()==='See $$a = 1\nb = 2$$ done','saved: '+JSON.stringify(serialized()));
  fresh();type('Inline $a');key('Enter',{shiftKey:true});type('b$');
  math=editor.session.doc.firstChild.child(1);
  assert(math.type.name==='inline_math' && math.attrs.value==='a\nb','inline TeX: '+JSON.stringify(math.attrs.value));
  assert(serialized()==='Inline $a\nb$');
});
await check('display math typed with TeX on the delimiter lines is saved the same way',()=>{
  fresh();type('$$a = b');key('Enter');type('  c = d$$');
  const eq=editor.session.doc.firstChild;
  assert(eq.type.name==='equation' && eq.attrs.value==='a = b\n  c = d','TeX: '+JSON.stringify(eq.attrs.value));
  assert(serialized().startsWith('$$a = b\n  c = d$$\n'),'saved: '+JSON.stringify(serialized()));
  fresh();type('$$');key('Enter');type('a = b');key('Enter');type('$$');
  assert(serialized().startsWith('$$\na = b\n$$\n'),'own lines: '+JSON.stringify(serialized()));
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
// Dispatch through EditorView's DOM handler so ProseMirror's native arrow
// capture (not only our keymap) participates in selecting atomic formulas.
const mathArrow=(direction)=>editor.view.dom.dispatchEvent(new KeyboardEvent('keydown',{
  key:direction,keyCode:{ArrowLeft:37,ArrowUp:38,ArrowRight:39,ArrowDown:40}[direction],bubbles:true,cancelable:true,
}));
for(const [source,fromEnd,direction,leave] of [
  ['Before\n\n$$x^2$$\n\nAfter',false,'ArrowDown','ArrowRight'],
  ['Before\n\n$$x^2$$\n\nAfter',true,'ArrowUp','ArrowUp'],
  ['Before\n\n$$x^2$$\n\nAfter',false,'ArrowRight','ArrowLeft'],
  ['Before\n\n$$x^2$$\n\nAfter',true,'ArrowLeft','ArrowRight'],
  ['Before $x^2$ After',false,'ArrowRight','ArrowLeft'],
  ['Before $x^2$ After',true,'ArrowLeft','ArrowRight'],
])await check(`formula arrow selection ${direction} from ${fromEnd?'after':'before'} ${source.includes('\n')?'block':'inline'} highlights, opens and cancels without editing`,async()=>{
  fresh(source);
  const block=fromEnd?editor.session.doc.lastChild:editor.session.doc.firstChild;
  const inline=source.startsWith('Before $');
  const offset=inline?(fromEnd?8:7):(fromEnd?0:block.content.size);
  assert(editor.session.setSelection(editor.session.reference(block.attrs.id),offset));
  editor.view.updateState(editor.session.state);editor.focus();
  mathArrow(direction);
  const selection=editor.view.state.selection;
  assert(selection.node?.type.name===(inline?'inline_math':'equation'),'arrow must select formula');
  const math=host.querySelector('.visual-math');
  assert(math.classList.contains('ProseMirror-selectednode'),'selection CSS class');
  const css=getComputedStyle(math);
  assert(css.backgroundColor!=='rgba(0, 0, 0, 0)' && css.backgroundColor!=='transparent','selected formula must have hover background');
  assert(css.outlineStyle==='none','selected formula uses the hover appearance');
  assert(getComputedStyle(math,'::selection').backgroundColor==='rgba(0, 0, 0, 0)','native selection must not cover the hover background');
  assert(key('Enter'));const dialog=document.querySelector('dialog[open]');assert(dialog,'Enter must open formula editor');
  assert(dialog.querySelector('textarea').value==='x^2');
  assert(!key('Enter',{repeat:true}) || document.querySelectorAll('dialog').length===1);
  dialog.close('cancel');await new Promise(resolve=>setTimeout(resolve,0));
  assert(!document.querySelector('dialog') && editor.view.hasFocus(),'cancel removes dialog and restores editor focus');
  assert(serialized()===source && !editor.session.changed,'cancel must preserve source');
  mathArrow(leave);assert(!math.classList.contains('ProseMirror-selectednode'),'leaving math must clear selection '+JSON.stringify(editor.view.state.selection.toJSON()));
});
await check('arrow-selected formula Apply preserves surrounding text, supports Save/reimport and Undo',async()=>{
  const source='Before\n\n$$x^2$$\n\nAfter';fresh(source);
  const first=editor.session.doc.firstChild;
  editor.session.setSelection(editor.session.reference(first.attrs.id),first.content.size);
  editor.view.updateState(editor.session.state);editor.focus();mathArrow('ArrowDown');
  assert(key('Enter'));const dialog=document.querySelector('dialog[open]');assert(dialog);
  dialog.querySelector('textarea').value='x^3';dialog.close('apply');
  await new Promise(resolve=>setTimeout(resolve,0));
  const snapshot=await editor.snapshot();assert(BloctBlocks.importMarkdown(snapshot.text).doc.child(1).attrs.value==='x^3');
  assert(snapshot.text.startsWith('Before\n\n') && snapshot.text.endsWith('\n\nAfter'));
  assert(editor.acknowledge(snapshot.token));assert(editor.history(false));assert(serialized()===source);
  assert(editor.history(true));assert(editor.session.doc.child(1).attrs.value==='x^3');
});
await check('engine-selected formula ignores activation while read-only, frozen, composing or modified',()=>{
  fresh('Before\n\n$$x$$\n\nAfter');
  const first=editor.session.doc.firstChild;
  editor.session.setSelection(editor.session.reference(first.attrs.id),first.content.size);
  editor.view.updateState(editor.session.state);editor.focus();mathArrow('ArrowDown');
  assert(editor.view.state.selection.node?.type.name==='equation');
  const original=serialized();
  editor.setEditable(false);key('Enter');assert(!document.querySelector('dialog'));
  editor.setEditable(true);assert(!editor.freezeIfClean());key('Enter');assert(!document.querySelector('dialog'));editor.unfreeze();
  editor.view.input.composing=true;
  assert(!editor.view.props.handleKeyDown(editor.view,new KeyboardEvent('keydown',{key:'Enter',isComposing:true})));
  editor.view.input.composing=false;assert(!document.querySelector('dialog'));
  for(const modifier of ['shiftKey','metaKey','ctrlKey','altKey']) {
    const event=new KeyboardEvent('keydown',{key:'Enter',[modifier]:true});
    assert(!editor.view.props.handleKeyDown(editor.view,event));assert(!document.querySelector('dialog'));
  }
  assert(serialized()===original && !editor.session.changed,'guards preserve source');
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
await check('typed URL, address and entity text saves as written and reopens with the same text',async()=>{
  const text='visit https://example.com or user@example.com, R&D &amp; v1.0 (beta) - a+b!';
  fresh();type(text);
  const snapshot=await editor.snapshot();
  assert(snapshot.text==='visit https://example.com or user@example.com, R&D \\&amp; v1.0 (beta) - a+b!',snapshot.text);
  assert(BloctBlocks.importMarkdown(snapshot.text).doc.firstChild.textContent===text);
});
await check('Mod-b bold that ends with a space saves as plain Markdown without character references',()=>{
  fresh();type('a ');assert(key('b',{metaKey:true}));type('word ');assert(key('b',{metaKey:true}));type('b');
  assert(serialized()==='a **word** b',serialized());
});
await check('editing a formatted paragraph keeps its punctuation, spacing, nesting and link form',()=>{
  const source='e.g. v1.0 (beta) **bold *both* `code`** and [docs](https://example.com/a_b) - see <https://example.com>';
  fresh(source);const p=editor.session.doc.firstChild;
  editor.session.setSelection(editor.session.reference(p.attrs.id),p.content.size);editor.view.updateState(editor.session.state);
  type('!');assert(serialized()===source+'!',serialized());
});
await check('the equation dialog has a fixed-size field without a focus ring',async()=>{
  fresh('$$x^2$$\n\nTail');
  host.querySelector('.visual-math').click();
  const dialog=document.querySelector('dialog'),input=dialog?.querySelector('textarea');
  assert(input && document.activeElement===input,'dialog field focused');
  const field=getComputedStyle(input),frame=getComputedStyle(dialog);
  assert(field.resize==='none','resize: '+field.resize);
  assert(field.height==='140px' && field.minHeight!=='140px','height: '+field.height+' / '+field.minHeight);
  assert(field.outlineStyle==='none' && frame.outlineStyle==='none','outline: '+field.outlineStyle+' / '+frame.outlineStyle);
  const before=input.getBoundingClientRect().height;
  input.value=Array.from({length:40},(_,i)=>'line '+i).join('\n');
  assert(input.getBoundingClientRect().height===before && input.scrollHeight>input.clientHeight,'long TeX scrolls inside the fixed field');
  dialog.close('cancel');await new Promise(resolve=>setTimeout(resolve,50));
  assert(!document.querySelector('dialog') && editor.session.doc.firstChild.attrs.value==='x^2','dialog closed without changing TeX');
});
if(editor){editor.destroy();host.remove();}
return JSON.stringify({results});
