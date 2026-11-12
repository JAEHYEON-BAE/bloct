// Aa is the sole editor. Reading cannot reopen the retired textarea path.
const results=[];
const check=(name,pass)=>results.push({name,pass:!!pass});
const encode=s=>btoa(unescape(encodeURIComponent(s)));
for(const source of ['', 'Plain 한글😀', '# Heading', '- item\n- next', '- [ ] task', '> quote',
  '```js\ncode\n```','---','| A | B |\n| --- | --- |\n| C | D |','<div>protected</div>']) {
  window._mvRender(encode(source));
  const page=document.documentElement;
  document.querySelector('#content').click();document.body.click();
  document.body.dispatchEvent(new KeyboardEvent('keydown',{key:'x',bubbles:true}));
  check(`${JSON.stringify(source)}: reading has no old mode or textarea`,!window._mvSetEditMode&&!window._mvStartBlockEdit&&!document.querySelector('textarea,[contenteditable=true]'));
  check(`${JSON.stringify(source)}: reading clicks preserve exact source`,window._mvRawLines.join('\n')===source);
  await window._mvSwitchEditor(true,source);
  const editor=window._bloctVisual,view=editor.view;
  check(`${JSON.stringify(source)}: Aa enables one editor in the same page`,editor.view.editable&&document.querySelectorAll('[contenteditable=true]').length===1&&document.documentElement===page);
  view.dispatch(view.state.tr.insert(view.state.doc.content.size,BloctBlocks.schema.nodes.paragraph.create(null,BloctBlocks.schema.text('Added'))));
  const draft=(await editor.snapshot()).text;
  const closed=await window._mvSwitchEditor(false,source);
  check(`${JSON.stringify(source)}: Aa off preserves the unsaved draft and removes editing`,closed.text===draft&&!document.querySelector('[contenteditable=true],textarea,.visual-toolbar')&&!window._bloctVisual);
  document.body.click();document.querySelector('#content').click();
  check(`${JSON.stringify(source)}: clicking after Aa off cannot resume editing`,window._mvRawLines.join('\n')===draft&&!document.querySelector('textarea,[contenteditable=true]'));
  await window._mvSwitchEditor(true,source);
  check(`${JSON.stringify(source)}: reentry keeps dirty draft and baseline`,window._bloctVisual.session.markdown()===draft&&window._bloctVisual.session.changed);
  await window._mvSwitchEditor(false,source);
}
window._mvRender(encode('$$x^2$$'));await window._mvSwitchEditor(true,'$$x^2$$');
document.querySelector('.visual-math').click();
const field=document.querySelector('dialog textarea');field.value='unfinished property draft';
const blocked=await window._mvSwitchEditor(false,'$$x^2$$');
check('open property editor prevents mode exit without losing unapplied text',blocked.blocked===true&&!!window._bloctVisual&&field.value==='unfinished property draft');
document.querySelector('dialog').close('cancel');await new Promise(resolve=>setTimeout(resolve,0));
await window._mvSwitchEditor(false,'$$x^2$$');
check('finishing property editing allows a fully read-only exit',!document.querySelector('dialog,textarea,[contenteditable=true]')&&!window._bloctVisual);
return JSON.stringify({results});
