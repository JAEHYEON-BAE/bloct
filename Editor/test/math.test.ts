import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import katex from 'katex';
import {importMarkdown} from '../src/importer.ts';
import {BlockSession} from '../src/session.ts';
import type {Node as PMNode} from '@tiptap/pm/model';
import {schema} from '../src/schema.ts';

function equations(doc: PMNode) {
  const found: PMNode[]=[];
  doc.descendants(n=>{if(n.type.name==='equation')found.push(n);});
  return found;
}
test('same-line display delimiters keep the matrix first line, rows and following document',()=>{
  const raw=readFileSync(new URL('../../Tests/fixtures/f5-state-space-math.md',import.meta.url),'utf8');
  const session=new BlockSession(raw), math=equations(session.doc);
  assert.equal(math.length,2);
  assert.equal(math[0].attrs.value,raw.slice(raw.indexOf('$$')+2,raw.indexOf('$$',raw.indexOf('$$')+2)));
  assert.equal(session.doc.child(3).textContent,'Math appearance');
  for(const n of math)assert.doesNotThrow(()=>katex.renderToString(n.attrs.value,{displayMode:true,trust:false}));
  assert.equal(session.markdown(),raw);
  session.execute(session.reference(session.doc.firstChild!.attrs.id),{type:'replaceText',from:0,to:0,text:'Edited '});
  assert.ok(session.markdown().includes(raw.slice(raw.indexOf('$$'))));
  assert.ok(session.undo());assert.equal(session.markdown(),raw);
});
test('attached/display-only delimiters protect blank lines and exact UTF-16 source positions',()=>{
  for(const [source,value] of [
    ['$$x$$','x'],['$$x=\n\ny$$','x=\n\ny'],['$$\nx=\n\ny$$','x=\n\ny'],
    ['$$\nx\n$$','x'],['$$x\r\ny$$','x\ny'],['$$x\\$y$$','x\\$y'],
  ]){
    const raw='\uFEFF# 😀\r\n\r\n'+source+'\r\n\r\nTail';
    const session=new BlockSession(raw), math=equations(session.doc);
    assert.equal(math.length,1,source);assert.equal(math[0].attrs.value,value);
    assert.equal(raw.slice(math[0].attrs.source.from,math[0].attrs.source.to),source);
    assert.equal(session.doc.lastChild!.textContent,'Tail');assert.equal(session.markdown(),raw);
  }
});
test('quoted/list math uses container-aware tokens while code and escaped delimiters stay literal',()=>{
  for(const source of ['> $$a=\n> b$$','- $$a=\n  b$$']){
    const imported=importMarkdown(source+'\n\nTail');
    assert.equal(equations(imported.doc)[0].attrs.value,'a=\nb');
    assert.equal(imported.doc.lastChild!.textContent,'Tail');
  }
  for(const raw of ['`$$x$$`','```tex\n$$x\n\ny$$\n```','\\$\\$x\\$\\$'])assert.equal(equations(importMarkdown(raw).doc).length,0);
});
test('double-dollar math in a paragraph stays display math through surrounding edits and Undo',()=>{
  const session=new BlockSession('before $$\\sum_{i=0}^{N} x_i$$ after');
  const p=session.doc.firstChild!, math=p.child(1);
  assert.equal(math.type.name,'inline_math');assert.equal(math.attrs.display,true);
  assert.ok(session.execute(session.reference(p.attrs.id),{type:'replaceText',from:0,to:0,text:'new '}));
  assert.ok(session.markdown().includes('$$\\sum_{i=0}^{N} x_i$$'));
  assert.equal(importMarkdown(session.markdown()).doc.firstChild!.child(1).attrs.display,true);
  assert.ok(session.undo());assert.equal(session.dirty,false);
});

test('literal pending or empty math delimiters save without becoming math on reimport',()=>{
  for(const text of ['$$ ','$$$$','$$   $$','price $5 and $10']) {
    const s=new BlockSession('');
    s.dispatch(s.state.tr.insertText(text));
    const saved=s.snapshot().markdown;
    const reopened=importMarkdown(saved).doc;
    assert.equal(equations(reopened).length,0,text);
    assert.equal(reopened.firstChild!.type.name,'paragraph',text);
    assert.equal(reopened.firstChild!.textContent,text);
  }
});

test('edited math keeps its line breaks, delimiter lines and padding as written',()=>{
  // An equation written with TeX on the delimiter lines stays so after Edit.
  const raw='$$ a = b\n\\\\ c $$\n\nTail';
  const s=new BlockSession(raw),eq=s.doc.firstChild!;
  assert.deepEqual([eq.attrs.openLine,eq.attrs.closeLine],[false,false]);
  s.dispatch(s.state.tr.setNodeMarkup(0,undefined,{...eq.attrs,value:eq.attrs.value+'+ d '}));
  assert.equal(s.markdown(),'$$ a = b\n\\\\ c + d $$\n\nTail');
  // Delimiters on their own lines, quoted or not, stay on their own lines.
  for(const source of ['$$\na\n  b\n$$','> $$\n> a\n>   b\n> $$']) {
    const e=equations(importMarkdown(source).doc)[0];
    assert.deepEqual([e.attrs.openLine,e.attrs.closeLine,e.attrs.value],[true,true,'a\n  b'],source);
  }
  // A new equation with attached delimiters and one without.
  const fresh=new BlockSession('');
  fresh.dispatch(fresh.state.tr.replaceWith(0,fresh.doc.content.size,[
    schema.nodes.equation.create({value:'x\n  y',openLine:false,closeLine:false}),
    schema.nodes.equation.create({value:'z'}),
    schema.nodes.equation.create({value:'w\\',openLine:false,closeLine:false})]));
  const saved=fresh.markdown();
  assert.equal(saved,'$$x\n  y$$\n$$\nz\n$$\n$$w\\\n$$');
  assert.deepEqual(equations(importMarkdown(saved).doc).map(n=>n.attrs.value),['x\n  y','z','w\\']);
});
test('inline math keeps line breaks and padding, and CRLF math edits save',()=>{
  const s=new BlockSession('Text $$ x\r\n  y + 1 $$ end\r\n');
  const math=s.doc.firstChild!.child(1);
  assert.equal(math.attrs.value,'x\n  y + 1');assert.equal(math.attrs.pad,true);
  s.dispatch(s.state.tr.insertText('E',1));
  assert.equal(s.markdown(),'EText $$ x\r\n  y + 1 $$ end\r\n');
  // Without a source to merge with, the attributes alone keep the spelling.
  const n=new BlockSession('');
  n.dispatch(n.state.tr.replaceWith(1,1,[schema.text('a '),schema.nodes.inline_math.create({value:'x\ny',display:true,pad:true}),
    schema.text(' b '),schema.nodes.inline_math.create({value:'p\nq'})]));
  assert.equal(n.markdown(),'a $$ x\ny $$ b $p\nq$');
  const reopened=importMarkdown(n.markdown()).doc.firstChild!;
  assert.deepEqual([reopened.child(1).attrs.value,reopened.child(3).attrs.value],['x\ny','p\nq']);
});
