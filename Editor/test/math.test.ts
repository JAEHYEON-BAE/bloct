import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import katex from 'katex';
import {importMarkdown} from '../src/importer.ts';
import {BlockSession} from '../src/session.ts';
import type {Node as PMNode} from '@tiptap/pm/model';

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
    ['$$\nx\n$$','x'],['$$x\r\ny$$','x\r\ny'],['$$x\\$y$$','x\\$y'],
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
