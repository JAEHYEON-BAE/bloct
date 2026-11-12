const results=[];
const check=(name,pass)=>results.push({name,pass:!!pass});
const encode=s=>btoa(unescape(encodeURIComponent(s)));
const fixtures=[
  ['nested','- [ ] same\n  - [X] same\n- [x] same',3],
  ['quoted ordered','> 1. [ ] 한글 😀\n>    - [X] 중첩\n> 2. [x] 다음',3],
  ['separate groups','- [ ] same\n\n- [X] same\n\n  - [x] independent',3],
  ['CRLF','1. [ ] 한글 😀  \r\n2. [X] 끝\t\r\n',2],
  ['empty','- [ ] \n- [X] ',2],
];
for(const [name,source,count] of fixtures) {
  window._mvRender(encode(source));
  let boxes=Array.from(document.querySelectorAll('#content .mv-task-checkbox'));
  check(`${name}: reading preserves styled disabled checkboxes`,boxes.length===count&&boxes.every(n=>n.disabled));
  boxes.forEach(n=>{n.click();n.dispatchEvent(new KeyboardEvent('keydown',{key:' ',bubbles:true}));});
  check(`${name}: checkbox click and Space in reading cannot edit`,window._mvRawLines.join('\n')===source);
  await window._mvSwitchEditor(true,source);
  const editor=window._bloctVisual;
  boxes=Array.from(document.querySelectorAll('#content .mv-task-checkbox'));
  check(`${name}: Aa owns enabled task controls`,boxes.length===count&&boxes.every(n=>!n.disabled));
  for(let i=0;i<boxes.length;i++) {
    const before=editor.session.markdown();boxes[i].click();
    const after=(await editor.snapshot()).text;
    const diffs=Array.from({length:Math.max(before.length,after.length)},(_,i)=>i).filter(i=>before[i]!==after[i]);
    check(`${name}: task ${i} changes exactly its marker`,before.length===after.length&&diffs.length===1&&before[diffs[0]-1]==='['&&before[diffs[0]+1]===']');
    check(`${name}: task ${i} Undo restores exact source`,editor.history(false)&&editor.session.markdown()===before);
    boxes=Array.from(document.querySelectorAll('#content .mv-task-checkbox'));
  }
  await window._mvSwitchEditor(false,source);
  check(`${name}: Aa off disables controls again`,Array.from(document.querySelectorAll('#content .mv-task-checkbox')).every(n=>n.disabled));
}
const source='<input type="checkbox" class="mv-task-checkbox" data-block-id="forged">';
window._mvRender(encode(source));await window._mvSwitchEditor(true,source);
check('author HTML checkboxes remain inert inside Aa previews',Array.from(document.querySelectorAll('#content input')).every(n=>n.disabled)&&!document.querySelector('#content .mv-task-checkbox'));
await window._mvSwitchEditor(false,source);
return JSON.stringify({results});
