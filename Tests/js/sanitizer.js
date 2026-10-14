// HTML sanitizing and CSP, run by Tests/HostedRegression.swift inside a page loaded by the
// production MarkdownWebView. Complements Tests/WebKitRegression.swift with further attack
// patterns and with legitimate Markdown/HTML that sanitizing must not remove.
//
// Result protocol: return JSON.stringify({ results: [{ name, pass, detail, skip }] })

const b64 = s => btoa(unescape(encodeURIComponent(s)));
const results = [];
const check = (name, cond, detail) => results.push({ name, pass: !!cond, detail: cond ? '' : String(detail) });
const skip = (name, reason) => results.push({ name, pass: true, skip: true, detail: reason });
const sleep = ms => new Promise(r => setTimeout(r, ms));
const C = () => document.getElementById('content');
const render = md => {
  if (window._mvActiveEl) window._mvCloseEditor(false);
  window._mvStale = true;
  window._mvRender(b64(md));
};
const hasKatex = typeof katex !== 'undefined';

// ---- 1. Attack patterns: nothing executable or editor-impersonating may survive
window.__pwn = 0;
const attacks = {
  'mixed-case javascript: href': '<a href="JaVaScRiPt:window.__pwn=1">x</a>',
  'entity-encoded javascript: href': '<a href="&#106;avascript:window.__pwn=2">x</a>',
  'whitespace-prefixed javascript: href': '<a href="  javascript:window.__pwn=3">x</a>',
  'markdown link to javascript:': '[x](javascript:window.__pwn=4)',
  'svg xlink:href javascript:': '<svg><a xlink:href="javascript:window.__pwn=5"><text>x</text></a></svg>',
  'mXSS math/mglyph/style': '<math><mtext><table><mglyph><style><img src=x onerror="window.__pwn=6">',
  'mXSS noscript attribute': '<noscript><p title="</noscript><img src=x onerror=window.__pwn=7>">',
  'details ontoggle': '<details open ontoggle="window.__pwn=8"><summary>s</summary>t</details>',
  'input autofocus onfocus': '<input autofocus onfocus="window.__pwn=9">',
  'object and embed': '<object data="javascript:window.__pwn=10"></object><embed src="javascript:window.__pwn=11">',
  'data:text/html link': '<a href="data:text/html,<script>alert(1)</script>">d</a>',
  'svg animate href': '<svg><animate attributeName="href" values="javascript:window.__pwn=12"/><a><text>t</text></a></svg>',
  'style element': '<style>body{background:url(https://example.invalid/leak)}</style>',
  'img srcset': '<img srcset="https://example.invalid/a.png 1x" src="x">',
  'button formaction': '<button formaction="javascript:window.__pwn=13">b</button>',
  'spoofed #content and #mv-append-zone': '<div id="content">a</div><div id="mv-append-zone" data-start="0">b</div>',
  'spoofed search highlight class': '<mark class="mv-hl">m</mark>',
};
for (const [name, md] of Object.entries(attacks)) {
  render(md);
  await sleep(60);
  const h = C().innerHTML;
  // <input> itself is allowed (task lists); only its dangerous attributes must go.
  const leaked = /\son[a-z]+=|javascript:|\bautofocus\b|<style|<object|<embed|<iframe|srcset|formaction|data:text\/html|<button/i.exec(h);
  const structure = document.querySelectorAll('#content #content').length === 0
                 && document.querySelectorAll('#mv-append-zone').length === 1
                 && C().querySelector('mark.mv-hl') === null;
  check('blocks ' + name, !leaked && structure && window.__pwn === 0,
        (leaked ? 'leaked ' + leaked[0] + ' in ' : '') + h.slice(0, 160) + ' pwn=' + window.__pwn);
}

// ---- 2. Legitimate content must survive sanitizing
const violations = [];
document.addEventListener('securitypolicyviolation', e => violations.push(e.violatedDirective + ' ' + e.blockedURI));

render('- [x] done\n- [ ] todo');
check('keeps task-list checkboxes', C().querySelectorAll('input[type=checkbox]').length === 2, C().innerHTML.slice(0, 200));
render('<details><summary>More</summary>\n\nhidden **text**\n\n</details>');
check('keeps details/summary', !!C().querySelector('details summary'), C().innerHTML.slice(0, 200));
render('H<sub>2</sub>O x<sup>2</sup> <kbd>K</kbd> <u>u</u> line<br>break');
check('keeps sub/sup/kbd/u/br', ['sub', 'sup', 'kbd', 'u', 'br'].every(t => C().querySelector(t)), C().innerHTML.slice(0, 200));
render('<div align="center"><img src="https://example.com/a.png" width="200"></div>');
check('keeps README-style align and width', C().querySelector('div[align=center] img[width="200"]') !== null, C().innerHTML.slice(0, 200));
render('<span style="color:red">red</span>');
check('keeps inline style attribute', C().querySelector('span[style*="color"]') !== null, C().innerHTML);
render('| a | b |\n|:-:|--:|\n| 1 | 2 |');
const th = C().querySelector('th');
check('keeps table column alignment', th && (th.getAttribute('align') === 'center' || /center/.test(th.getAttribute('style') || '')), th && th.outerHTML);
render('```python\nprint(1)\n```');
check('keeps code language class (used by copy as Markdown)', !!C().querySelector('code.language-python'), C().innerHTML.slice(0, 200));
render('*[Figure 1. caption]*');
check('keeps figure-caption class', !!C().querySelector('.figure-caption'), C().innerHTML);
render('# 제목 하나\n\n[이동](#제목-하나) [메일](mailto:a@b.c) [상대](other.md) [웹](https://example.com)');
const hrefs = Array.from(C().querySelectorAll('a')).map(a => a.getAttribute('href'));
check('assigns heading id after sanitizing', C().querySelector('h1').id === '제목-하나', C().querySelector('h1').id);
check('keeps anchor, mailto, relative and https links', JSON.stringify(hrefs) === JSON.stringify(['#제목-하나', 'mailto:a@b.c', 'other.md', 'https://example.com']), JSON.stringify(hrefs));

render('Inline $\\frac{a}{b}$ and\n\n$$\n\\sum_{i=1}^n i\n$$');
await sleep(50);
if (hasKatex) {
  check('keeps KaTeX MathML annotation and HTML', C().querySelectorAll('.katex annotation').length === 2 && C().querySelectorAll('.katex-html').length === 2, C().innerHTML.slice(0, 200));
} else {
  skip('keeps KaTeX MathML annotation and HTML', 'KaTeX CDN unreachable');
}
{
  const sel = window.getSelection(); const r = document.createRange();
  r.selectNodeContents(C()); sel.removeAllRanges(); sel.addRange(r);
  let copied = '';
  const ev = new Event('copy', { bubbles: true, cancelable: true });
  ev.clipboardData = { setData: (t, v) => { copied = v; } };
  document.dispatchEvent(ev);
  check('copy as Markdown restores TeX source', copied.includes('\\frac{a}{b}') && copied.includes('\\sum_{i=1}^n i'), copied);
  sel.removeAllRanges();
}

// ---- 3. CSP permits what the renderer needs
if (hasKatex) {
  render('Fonts $\\mathbb{R}\\mathcal{L}\\mathfrak{g}$');
  await document.fonts.ready; await sleep(1500);
  const katexFonts = Array.from(document.fonts).filter(f => /KaTeX/.test(f.family));
  check('KaTeX web fonts load under CSP', katexFonts.some(f => f.status === 'loaded'), katexFonts.map(f => f.family + ':' + f.status).join(', '));
} else {
  skip('KaTeX web fonts load under CSP', 'KaTeX CDN unreachable');
}
check('no CSP violations while rendering legitimate content', violations.length === 0, violations.join(' | '));

return JSON.stringify({ results });
