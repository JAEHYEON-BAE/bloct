// Real WKWebView, production parser/sanitizer/events/bridge. Persistence and
// native Undo are covered separately by TaskListRegression.swift.
const results = [];
const check = (name, pass, detail = '') => results.push({ name, pass: !!pass, detail: pass ? '' : String(detail) });
const b64 = s => btoa(unescape(encodeURIComponent(s)));
const text = () => window._mvRawLines.join('\n');
const boxes = () => [...document.querySelectorAll('#content .mv-task-checkbox')];
const input = () => document.getElementById('mv-block-editor');
let commits = [];
const native = window.webkit.messageHandlers;
window.webkit = { messageHandlers: new Proxy({}, { get: (_, name) => ({ postMessage: message => {
    if (name === 'commitEdit') commits.push(new TextDecoder().decode(Uint8Array.from(atob(message.text), c => c.charCodeAt(0))));
    try { native[name].postMessage(message); } catch (_) {}
} }) }) };
const reset = raw => {
    if (window._mvActiveEl) window._mvCloseEditor(false);
    window._mvCheckBeforeEdit = false;
    window._mvDiskChecking = false;
    window._mvPendingTask = null;
    window._mvPendingEdit = null;
    window._mvStale = true;
    window._mvRender(b64(raw));
    window._mvSetEditMode(false);
    commits = [];
};
const click = node => node.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true }));
const key = (node, repeat = false) => node.dispatchEvent(new KeyboardEvent('keydown', { key: ' ', repeat, bubbles: true, cancelable: true }));
const edit = value => { input().value = value; input().dispatchEvent(new Event('input', { bubbles: true })); };
const tick = () => new Promise(resolve => setTimeout(resolve, 5));

for (const [name, raw, count] of [
    ['duplicates/nesting', '- [ ] 동일\n  - [X] 동일\n- [x] 동일', 3],
    ['ordered/quotes', '> 1. [ ] 한글 😀\n>    - [X] 중첩\n> 2. [x] 두번째', 3],
    ['blank boundaries', '- [ ] 동일\n\n- [X] 동일\n\n  - [x] 독립', 3],
    ['CRLF/trailing spaces', '1. [ ] 한글 😀  \r\n2. [X] 끝\t\r\n', 2],
    ['continuation/nesting', '- [ ] same\n  continued\n  - [ ] same\n- [ ] same', 3],
    ['math/image/code preprocessing', '- [ ] $x$ ![a](a.png){width=10} `code`\n- [X] $z$', 2],
    ['math before task', '$$x$$\n- [ ] same\n- [X] same', 2],
    ['tabs', '- [ ] same\t \n- [X] end', 2],
    ['content/indent tabs nested in quote', '> - [ ] parent\tlabel\n>   - [X] child\n>     - [ ] deep', 3],
    ['empty tasks', '- [ ] \n- [X] ', 2]
]) {
    reset(raw);
    check(name + ': trusted count', boxes().length === count, boxes().length);
    // Every target, including indistinguishable labels, changes exactly one code unit.
    for (let i = 0; i < count && boxes().length === count; i++) {
        const before = text(), expectedState = boxes()[i].checked;
        click(boxes()[i]);
        const after = text();
        const diffs = [...Array(Math.max(before.length, after.length)).keys()].filter(j => before[j] !== after[j]);
        check(name + ': exact marker ' + i, before.length === after.length && diffs.length === 1
            && before[diffs[0] - 1] === '[' && before[diffs[0] + 1] === ']'
            && after[diffs[0]] === (expectedState ? ' ' : 'x') && boxes()[i].checked !== expectedState, JSON.stringify(after));
    }
    check(name + ': one commit per toggle', commits.length === count, commits.length);
    check(name + ': no inline editor', !input());
}

reset('- [ ] first\n- [X] second');
window._mvSetEditMode(true);
click(boxes()[0]);
check('edit-mode click does not open textarea', !input() && text() === '- [x] first\n- [X] second');
key(boxes()[1]);
check('Space toggles once and preserves uppercase of untouched markers', text() === '- [x] first\n- [ ] second' && commits.length === 2);
key(boxes()[1], true);
check('Space repeat does not double-toggle', commits.length === 2);
for (let i = 0; i < 10; i++) click(boxes()[0]);
check('rapid clicks use latest source/DOM', text() === '- [x] first\n- [ ] second' && commits.length === 12);
const stale = boxes()[0];
window._mvStale = true; window._mvRender(b64('- [ ] replacement'));
click(stale);
check('detached DOM cannot commit', text() === '- [ ] replacement' && commits.length === 12);
window._mvRender(b64('- [X] undo'));
check('native Undo render restores checked state', boxes()[0].checked);
window._mvRender(b64('- [ ] redo'));
check('native Redo render restores unchecked state', !boxes()[0].checked);

const blocked = [
    '```\n- [ ] code\n````',
    '~~~\n- [ ] ![x](x){width=20}\n~~~~',
    '    - [ ] indented code',
    '`- [ ] inline`',
    '\\- [ ] escaped',
    '- \\[ ] escaped marker',
    '[ ] ordinary brackets',
    '<div>\n- [ ] HTML block\n</div>',
    '> ```\n> - [ ] quoted code\n> ```',
    '- [ ] real\n  ```\n  - [ ] nested code\n  ```',
    '<input type="checkbox" class="mv-task-checkbox" data-start="1" checked>\n\n- [ ] real'
];
for (const raw of blocked) {
    reset(raw);
    const expected = raw.includes('real') ? 1 : 0;
    check('code/escape/HTML exclusion ' + blocked.indexOf(raw), boxes().length === expected, document.getElementById('content').innerHTML);
    check('author HTML stays disabled ' + blocked.indexOf(raw), [...document.querySelectorAll('#content input:not(.mv-task-checkbox)')].every(node => node.disabled));
}
reset('<input type="checkbox" class="mv-task-checkbox" data-start="0" data-end="1">\n\n- [ ] real');
const fake = document.querySelector('input:not(.mv-task-checkbox)');
click(fake);
check('forged attributes grant no commit authority', commits.length === 0 && !fake.className.includes('mv-'));
click(boxes()[0]);
check('real task beside forged input changes correct source', text().endsWith('- [x] real') && commits.length === 1);

for (const [edited, expected] of [['para\nextra\nmore', 'para\nextra\nmore\n\n- [x] same'], ['short', 'short\n\n- [x] same']]) {
    reset('para\noriginal\n\n- [ ] same');
    window._mvSetEditMode(true);
    click(document.querySelector('.mv-block'));
    edit(edited);
    const target = boxes()[0];
    // The real mousedown is intercepted so textarea blur cannot detach target.
    const down = new MouseEvent('mousedown', { bubbles: true, cancelable: true });
    target.dispatchEvent(down);
    check('task mousedown holds editor until transaction', down.defaultPrevented && !!input());
    click(target);
    await tick();
    check('editor line changes rebase task target ' + edited, text() === expected && !input(), text());
    check('paragraph and task have separate commits ' + edited, commits.length === 2 && commits[0].endsWith('- [ ] same') && commits[1] === expected, JSON.stringify(commits));
}
reset('- [ ] same\n\npara');
window._mvSetEditMode(true);
click(document.querySelectorAll('.mv-block')[1]); edit('edited\nlines');
click(boxes()[0]);
check('editor after task preserves task position', text() === '- [x] same\n\nedited\nlines' && commits.length === 2);

reset('para\n\n- [ ] delayed');
window._mvSetEditMode(true);
click(document.querySelector('.mv-block')); edit('para\nnew line');
window._mvCheckBeforeEdit = true;
input().dispatchEvent(new FocusEvent('blur'));
click(boxes()[0]);
await tick();
check('async preflight holds blurred editor and original target', !!input() && commits.length === 0);
window._mvResumeEdit(true);
check('async preflight commits edit and task on first click', text() === 'para\nnew line\n\n- [x] delayed' && commits.length === 2 && !input(), text());

reset('- [ ] pending');
window._mvCheckBeforeEdit = true;
click(boxes()[0]);
check('disk guard delays task commit', commits.length === 0 && !!window._mvPendingTask);
window._mvResumeEdit(false);
check('disk guard denial preserves source', text() === '- [ ] pending' && commits.length === 0);
click(boxes()[0]);
window._mvResumeEdit(true);
check('disk guard approval commits once', text() === '- [x] pending' && commits.length === 1);
click(boxes()[0]); click(boxes()[0]); click(boxes()[0]);
window._mvResumeEdit(true);
check('rapid clicks queued during disk preflight each commit once', text() === '- [ ] pending' && commits.length === 4, commits.length);
click(boxes()[0]);
window._mvStale = true; window._mvRender(b64('- [ ] externally replaced'));
window._mvResumeEdit(true);
check('disk guard cannot resume old generation/DOM', text() === '- [ ] externally replaced' && commits.length === 4);
window._mvDiskChecking = true;
click(boxes()[0]);
check('frozen disk inspection blocks toggling', commits.length === 4);
window._mvDiskChecking = false;
click(boxes()[0]);
window._mvResumeEdit(true);
check('replacement page starts a fresh disk preflight', text() === '- [x] externally replaced' && commits.length === 5, text());

reset('- [ ] focus');
check('keyboard control has accessible label', boxes()[0].getAttribute('aria-label') === 'focus' && boxes()[0].tabIndex === 0);
reset('- plain parent\n  - [ ] nested task\n  - plain sibling\n- [ ] task parent\n  - plain child\n- plain last');
const markers = [...document.querySelectorAll('#content li')].map(item => getComputedStyle(item).listStyleType);
check('mixed nested lists hide only task markers', markers.length === 6
    && markers.every((style, i) => [1, 3].includes(i) ? style === 'none' : style !== 'none'), JSON.stringify(markers));
const listItems = [...document.querySelectorAll('#content li')];
const ownTextLeft = item => {
    const node = [...item.childNodes].find(node => node.nodeType === Node.TEXT_NODE && /\S/.test(node.textContent));
    const start = node.textContent.search(/\S/);
    const range = document.createRange();
    range.setStart(node, start); range.setEnd(node, start + 1);
    return range.getBoundingClientRect().left;
};
const textPositions = listItems.map(ownTextLeft);
check('task and ordinary text align at each nesting level',
    Math.abs(textPositions[0] - textPositions[3]) < 0.5 && Math.abs(textPositions[0] - textPositions[5]) < 0.5
    && Math.abs(textPositions[1] - textPositions[2]) < 0.5 && Math.abs(textPositions[1] - textPositions[4]) < 0.5,
    JSON.stringify(textPositions));
check('checkboxes occupy the marker gutter outside the text column', boxes().every(box =>
    box.getBoundingClientRect().right < ownTextLeft(box.closest('li'))));
reset('- plain text\n- [ ] ' + 'wrapped text '.repeat(30));
const wrappingItem = document.querySelectorAll('#content li')[1];
const wrappingRange = document.createRange();
wrappingRange.selectNodeContents(wrappingItem.lastChild);
const wrappedLines = [...wrappingRange.getClientRects()].filter(rect => rect.width > 0);
check('wrapped task lines share ordinary text indentation', wrappedLines.length > 1
    && wrappedLines.every(rect => Math.abs(rect.left - ownTextLeft(document.querySelector('#content li'))) < 0.5),
    JSON.stringify(wrappedLines.map(rect => rect.left)));
reset('1. [ ] ordered task\n\n2. plain ordered\n\n> - [ ] quoted task');
const independentMarkers = [...document.querySelectorAll('#content li')].map(item => getComputedStyle(item).listStyleType);
check('independent ordered and quoted task markers stay hidden', independentMarkers.join(',') === 'none,decimal,none', JSON.stringify(independentMarkers));
reset(Array(30).fill('paragraph\n\n').join('') + '- [ ] scrolled\n\n' + Array(30).fill('tail\n\n').join(''));
window.scrollTo(0, document.querySelector('.mv-task-checkbox').getBoundingClientRect().top + window.scrollY - 200);
const previousScroll = window.scrollY;
click(boxes()[0]);
check('toggle preserves nonzero scroll position', previousScroll > 0 && window.scrollY === previousScroll, previousScroll + ' -> ' + window.scrollY);
return JSON.stringify({ results });
