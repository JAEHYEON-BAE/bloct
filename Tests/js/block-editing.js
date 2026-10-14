// Block editing, rendering and page features, run by Tests/HostedRegression.swift inside
// a page loaded by the production MarkdownWebView (including the didFinish scripts).
//
// The test WebView has no key window, so focus()/blur() do nothing; the suite dispatches
// the blur event the editor listens for instead. Checks that need the KaTeX CDN are
// skipped when it is unreachable.
//
// Result protocol (shared by every file in Tests/js):
//   return JSON.stringify({ results: [{ name, pass, detail, skip }] })

const b64 = s => btoa(unescape(encodeURIComponent(s)));
const unb64 = s => decodeURIComponent(escape(atob(s)));
const tick = ms => new Promise(r => setTimeout(r, ms || 0));
const results = [];
const check = (name, cond, detail) => results.push({ name, pass: !!cond, detail: cond ? '' : String(detail) });
const skip = (name, reason) => results.push({ name, pass: true, skip: true, detail: reason });

// Record messages sent to Swift while still forwarding them to the native bridge.
window.__msgs = [];
const native = window.webkit.messageHandlers;
window.webkit = { messageHandlers: new Proxy({}, { get: (_, n) => ({
  postMessage: m => { window.__msgs.push([n, m]); try { native[n].postMessage(m); } catch (e) {} }
}) }) };
const commits = () => window.__msgs.filter(m => m[0] === 'commitEdit').map(m => unb64(m[1]));
const dirtyMsgs = () => window.__msgs.filter(m => m[0] === 'editorDirty').map(m => m[1]);

// Clean slate: drop any open editor and force a re-render even if the text matches.
const reset = doc => {
  if (window._mvActiveEl) window._mvCloseEditor(false);
  window.__msgs = [];
  window._mvStale = true;
  window._mvRender(b64(doc));
  window._mvSetEditMode(true);
};
const ed = () => document.getElementById('mv-block-editor');
const block = start => document.querySelector('#content .mv-block[data-start="' + start + '"]');
const blurEd = () => {
  const t = ed();
  if (!t) { check('blur needs an open editor', false, 'no editor was open'); return; }
  t.dispatchEvent(new FocusEvent('blur'));
};
const typeIn = v => {
  const t = ed();
  if (!t) { check('typeIn needs an open editor', false, 'no editor was open'); return; }
  t.value = v; t.dispatchEvent(new Event('input', { bubbles: true }));
};
const keyEd = opts => {
  const t = ed();
  if (!t) { check('keypress needs an open editor', false, 'no editor was open'); return; }
  t.dispatchEvent(new KeyboardEvent('keydown', Object.assign({ bubbles: true, cancelable: true }, opts)));
};
const clickEl = el => el.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true }));
const DOC = '# A\n\npara a\n\npara b\n\npara c';

// ---- 1. Click another block right after an edit that added a line
reset(DOC);
{
  const bB = block(4);                 // captured before the edit: stale line range
  clickEl(block(2));
  check('1a editor opens on clicked block', ed() && ed().value === 'para a', ed() && ed().value);
  typeIn('para a\nextra line');
  blurEd();                            // real browsers blur on mousedown elsewhere
  clickEl(bB);
  await tick();                        // let the deferred blur handler run
  check('1b next editor shows "para b"', ed() && ed().value === 'para b', ed() ? ed().value : '<no editor>');
  check('1c commit keeps blank lines', commits()[0] === '# A\n\npara a\nextra line\n\npara b\n\npara c', JSON.stringify(commits()[0]));
  typeIn('para B!');
  blurEd(); await tick();
  check('1d second commit correct', commits().at(-1) === '# A\n\npara a\nextra line\n\npara B!\n\npara c', JSON.stringify(commits().at(-1)));
  check('1e no stray editor left', !ed() && !window._mvActiveEl);
}

// ---- 2. Swift pushes _mvRender while an editor is open
reset(DOC);
{
  clickEl(block(2)); typeIn('dirty text');
  const t = ed();
  window._mvRender(b64(commits().length ? commits()[0] : DOC));
  check('2a dirty editor survives echo', ed() === t && t.isConnected);
  window._mvRender(b64('# A\n\nsomething external'));
  check('2b dirty editor survives external render', ed() === t);
  check('2c raw lines not clobbered', window._mvRawLines.join('\n').includes('dirty text'), window._mvRawLines.join('|'));
  blurEd(); await tick();
  check('2d content re-rendered after close', document.getElementById('content').textContent.includes('dirty text'));
}
reset(DOC);
{
  clickEl(block(2));                   // clean editor, no typing
  window._mvRender(b64('# A\n\nundone'));
  check('2e clean editor dropped for undo', !ed() && !window._mvActiveEl);
  check('2f undo content rendered', document.getElementById('content').textContent.includes('undone'));
}

// ---- 3. Cmd+Enter / Shift+Cmd+Enter navigation
reset(DOC);
{
  clickEl(block(2)); typeIn('one\ntwo\nthree');
  keyEd({ key: 'Enter', metaKey: true });
  await tick();
  check('3a cmd+enter after multi-line edit opens para b', ed() && ed().value === 'para b', ed() ? ed().value : '<none>');
  keyEd({ key: 'Enter', metaKey: true, shiftKey: true });
  await tick();
  check('3b shift+cmd+enter returns to edited block', ed() && ed().value === 'one\ntwo\nthree', ed() ? ed().value : '<none>');
}
reset(DOC);
{
  clickEl(block(6));                   // last block
  typeIn('para c edited');
  keyEd({ key: 'Enter', metaKey: true });
  await tick();
  check('3c cmd+enter on last block opens append zone', window._mvActiveEl && window._mvActiveEl.id === 'mv-append-zone', window._mvActiveEl && window._mvActiveEl.id);
  typeIn('brand new para');
  blurEd(); await tick();
  check('3d append zone gets a blank separator', commits().at(-1) === '# A\n\npara a\n\npara b\n\npara c edited\n\nbrand new para', JSON.stringify(commits().at(-1)));
  check('3e exactly one append zone', document.querySelectorAll('#mv-append-zone').length === 1, document.querySelectorAll('#mv-append-zone').length);
}

// ---- 4. editorDirty only fires for real typing
reset(DOC);
{
  clickEl(block(2));
  check('4a click alone is not dirty', dirtyMsgs().length === 0, JSON.stringify(dirtyMsgs()));
  typeIn('x'); typeIn('xy'); typeIn('xyz');
  check('4b one true per edit session', JSON.stringify(dirtyMsgs()) === '[true]', JSON.stringify(dirtyMsgs()));
  blurEd(); await tick();
  check('4c false after commit', JSON.stringify(dirtyMsgs()) === '[true,false]', JSON.stringify(dirtyMsgs()));
}

// ---- 5. Escape commits without leaving an editor open
reset(DOC);
{
  clickEl(block(2)); typeIn('escaped edit');
  keyEd({ key: 'Escape' });
  await tick();
  check('5a escape closes editor', !ed() && !window._mvActiveEl);
  check('5b escape commits text', commits().at(-1) === '# A\n\nescaped edit\n\npara b\n\npara c', JSON.stringify(commits().at(-1)));
}

// ---- 6. Math, offline KaTeX fallback, malformed anchors, fences
{
  const hadKatex = typeof katex !== 'undefined';
  reset('Cost $x+1$ here\n\n$$\na = b\n$$');
  if (hadKatex) {
    check('6a inline math rendered by KaTeX', !!document.querySelector('#content .katex'));
    check('6b display math rendered by KaTeX', !!document.querySelector('#content .katex-display'));
  } else {
    skip('6a inline math rendered by KaTeX', 'KaTeX CDN unreachable');
    skip('6b display math rendered by KaTeX', 'KaTeX CDN unreachable');
  }
  const saved = window.katex; delete window.katex;      // simulate the CDN being offline
  let threw = '';
  try { reset('Cost $x+1$ here\n\n$$\na = b\n$$\n\nplain tail'); } catch (e) { threw = e.message; }
  check('6c offline: render does not throw', !threw, threw);
  const txt = document.getElementById('content').textContent;
  check('6d offline: document still renders', txt.includes('plain tail'), txt.slice(0, 120));
  check('6e offline: inline math falls back to text', txt.includes('$x+1$'), txt.slice(0, 120));
  check('6f offline: block math falls back to text', txt.includes('a = b'), txt.slice(0, 160));
  if (saved) window.katex = saved;
  try { reset(DOC); } catch (e) {}
  let threw2 = '';
  try { reset('[bad](#100%) link\n\n```\ncode\n\nwith blank\n```\n\n$$\nm\n\nn\n$$'); } catch (e) { threw2 = e.name + ': ' + e.message; }
  check('6g malformed anchor does not throw', !threw2, threw2);
  const txt2 = document.getElementById('content').textContent;
  check('6h malformed anchor still renders', txt2.includes('link') && !!document.querySelector('a[href="#100%"]'), txt2.slice(0, 120));
  check('6i fence and math blocks stay whole', document.querySelectorAll('#content .mv-block').length === 3, document.querySelectorAll('#content .mv-block').length);
  const code = (document.querySelector('#content pre code') || {}).textContent;
  check('6j fenced code keeps its blank line', code === 'code\n\nwith blank\n', JSON.stringify(code));
}

// ---- 7. Search highlighting survives a re-render
reset(DOC);
{
  window._mvSearch.highlight('para');
  check('7a highlights 3 matches', document.querySelectorAll('mark.mv-hl').length === 3, document.querySelectorAll('mark.mv-hl').length);
  window._mvRender(b64(DOC + '\n\npara d'));
  check('7b re-applied after re-render', document.querySelectorAll('mark.mv-hl').length === 4, document.querySelectorAll('mark.mv-hl').length);
  window._mvSearch.navigate(true);
  check('7c navigate marks one current match', document.querySelectorAll('mark.mv-hl[style*="255, 140, 0"], mark.mv-hl[style*="FF8C00"]').length === 1);
  window._mvSearch.clear();
  window._mvRender(b64(DOC));
  check('7d cleared search stays cleared', document.querySelectorAll('mark.mv-hl').length === 0, document.querySelectorAll('mark.mv-hl').length);
  let threw = '';
  try { window._mvSearch.highlight("qu'ote \\ and \n newline"); } catch (e) { threw = e.message; }
  check('7e odd query does not throw', !threw, threw);
  window._mvSearch.clear();
}

// ---- 8. Style tokens resolve; cursor follows edit mode
reset('# H\n\n*[a caption]*\n\ntext');
{
  const cs = n => getComputedStyle(n);
  const cap = document.querySelector('#content .figure-caption');
  check('8a caption exists', !!cap);
  const capColor = cap ? cs(cap).color : '';
  const bodyColor = cs(document.body).color;
  check('8b caption uses the muted color token', capColor && capColor !== bodyColor && capColor !== 'rgba(0, 0, 0, 0)', capColor + ' vs body ' + bodyColor);
  window._mvBuildTOC();
  const toc = document.getElementById('toc');
  check('8c TOC built', !!toc);
  const tocBg = toc ? cs(toc).backgroundColor : '';
  check('8d TOC background is opaque', tocBg && tocBg !== 'rgba(0, 0, 0, 0)' && tocBg !== 'transparent', tocBg);
  const tocLink = toc && toc.querySelector('a');
  check('8e TOC link color resolves', tocLink && cs(tocLink).color !== 'rgba(0, 0, 0, 0)', tocLink && cs(tocLink).color);
  window._mvSetEditMode(false);
  check('8f read mode: no text cursor on content', cs(document.getElementById('content')).cursor === 'auto', cs(document.getElementById('content')).cursor);
  window._mvSetEditMode(true);
  check('8g edit mode: text cursor', cs(document.getElementById('content')).cursor === 'text', cs(document.getElementById('content')).cursor);
}

// ---- 9. Read mode ignores clicks
reset(DOC);
{
  window._mvSetEditMode(false);
  clickEl(block(2));
  check('9a no editor opens in read mode', !ed());
  window._mvSetEditMode(true);
}

// ---- 10. Copy as Markdown
reset('# T\n\n**bold** and *em* and `code`\n\n- a\n- b');
{
  const r = document.createRange();
  r.selectNodeContents(document.getElementById('content'));
  const sel = window.getSelection(); sel.removeAllRanges(); sel.addRange(r);
  let copied = null;
  const ev = new Event('copy', { bubbles: true, cancelable: true });
  ev.clipboardData = { setData: (t, v) => { copied = v; } };
  document.dispatchEvent(ev);
  check('10a copy produces inline markdown', copied && copied.includes('**bold**') && copied.includes('*em*') && copied.includes('`code`'), JSON.stringify(copied));
  check('10b copy produces list markdown', copied && copied.includes('- a') && copied.includes('- b'), JSON.stringify(copied));
  sel.removeAllRanges();
}

return JSON.stringify({ results });
