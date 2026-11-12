// Window chrome for the document page: table of contents, remembered scroll
// position and the resize/TOC scroll anchor. Swift installs it once the page
// has finished loading (MarkdownWebView.Coordinator.webView(_:didFinish:)), so
// the TOC is built only after the latest document text is rendered.
window._mvInstallHost = function(options) {
    if (!window._mvBuildTOC) {
        window._mvBuildTOC = function() {
            var headings = document.querySelectorAll('h1,h2,h3');
            var toc = document.getElementById('toc');
            var isNew = !toc;
            if (isNew) {
                toc = document.createElement('nav');
                toc.id = 'toc';
                toc.style.cssText = 'position:fixed;top:0;left:0;width:220px;height:100vh;' +
                    'background:var(--color-bg);' +
                    'border-right:1px solid var(--color-border);' +
                    'padding:20px 14px;overflow-y:auto;z-index:100;box-sizing:border-box;' +
                    'overscroll-behavior:contain;transition:transform 0.3s ease;';
            }
            toc.innerHTML = '';
            headings.forEach(function(h) {
                var level = parseInt(h.tagName[1]);
                var fontSize = level === 1 ? '13.5px' : level === 2 ? '12px' : '11px';
                var fontWeight = level === 1 ? '600' : '400';
                var opacity = level === 3 ? '0.7' : '1';
                var a = document.createElement('a');
                a.href = '#' + h.id;
                a.textContent = h.textContent;
                a.style.cssText = 'display:block;padding-left:' + (level-1)*12 + 'px;' +
                    'margin:4px 0;color:var(--color-text);text-decoration:none;' +
                    'font-size:' + fontSize + ';font-weight:' + fontWeight + ';opacity:' + opacity + ';' +
                    'white-space:nowrap;overflow:hidden;text-overflow:ellipsis;line-height:1.5;';
                a.onmouseenter = function() { this.style.opacity = String(parseFloat(opacity) * 0.6); };
                a.onmouseleave = function() { this.style.opacity = opacity; };
                a.onclick = function(e) { e.preventDefault(); h.scrollIntoView({behavior:'smooth'}); };
                toc.appendChild(a);
            });
            if (isNew) {
                document.body.appendChild(toc);
                document.body.style.paddingLeft = '220px';
                document.body.style.transition = 'padding-left 0.3s ease';
            }
        };
    }
    window._mvBuildTOC();

    if (!options.showTOC) {
        // Instant hide on load (no animation).
        var t = document.getElementById('toc');
        if (t) {
            t.style.transition = 'none';
            t.style.transform = 'translateX(-220px)';
            t.style.pointerEvents = 'none';
            document.body.style.transition = 'none';
            document.body.style.paddingLeft = '';
        }
    }

    // Restore the saved scroll position.
    if (options.savedScrollY > 0) {
        setTimeout(function() { window.scrollTo({ top: options.savedScrollY, behavior: 'smooth' }); }, 100);
    }

    // Save the scroll position, debounced.
    var scrollTimer;
    window.addEventListener('scroll', function() {
        clearTimeout(scrollTimer);
        scrollTimer = setTimeout(function() {
            window.webkit.messageHandlers.scrollPosition.postMessage(window.scrollY);
        }, 200);
    }, { passive: true });

    // Resize scroll anchor: keeps the first visible block element at the same
    // viewport position while the window edge is dragged. _mvFindAnchor is also
    // used by the TOC toggle below.
    var _anchor = null, _anchorTop = 0, _tid = null, _raf = null;
    window._mvFindAnchor = _findAnchor;
    function _findAnchor() {
        var x = Math.floor(window.innerWidth * 0.5);
        for (var y = 2; y < window.innerHeight * 0.4; y += 4) {
            var el = document.elementFromPoint(x, y);
            while (el && el !== document.body && el !== document.documentElement) {
                var d = window.getComputedStyle(el).display;
                if (d === 'block' || d === 'list-item' || d === 'table' || d === 'flex') {
                    return el;
                }
                el = el.parentElement;
            }
        }
        return null;
    }
    window.addEventListener('resize', function() {
        if (!_anchor) {
            _anchor = _findAnchor();
            if (_anchor) _anchorTop = _anchor.getBoundingClientRect().top;
        } else {
            // Batch corrections to one per animation frame so rapid resize events
            // don't queue multiple scroll calls. Each correction is instant so
            // the content appears locked to the viewport edge while dragging.
            cancelAnimationFrame(_raf);
            _raf = requestAnimationFrame(function() {
                var delta = _anchor.getBoundingClientRect().top - _anchorTop;
                if (Math.abs(delta) > 0.5) window.scrollBy(0, delta);
            });
        }
        clearTimeout(_tid);
        _tid = setTimeout(function() {
            // Once the drag stops, apply a final smooth correction for any
            // residual drift that accumulated during the live resize.
            if (_anchor) {
                var delta = _anchor.getBoundingClientRect().top - _anchorTop;
                if (Math.abs(delta) > 0.5) window.scrollBy({ top: delta, behavior: 'smooth' });
            }
            _anchor = null;
        }, 150);
    }, { passive: true });
};

// Shows or hides the TOC with an animation, keeping the first visible block in
// place while the body padding changes.
window._mvSetTOC = function(show) {
    var t = document.getElementById('toc');
    if (!t) return;
    var transform = show ? 'translateX(0)' : 'translateX(-220px)';
    var padding = show ? '220px' : '';
    // First block-level element at the top of the viewport.
    var anchor = window._mvFindAnchor ? window._mvFindAnchor() : null;
    // Predict the scroll delta by peeking at the final layout state.
    var delta = 0;
    if (anchor) {
        var anchorTop = anchor.getBoundingClientRect().top;
        var prevTransform = t.style.transform;
        var prevPadding = document.body.style.paddingLeft;
        t.style.transition = 'none';
        document.body.style.transition = 'none';
        t.style.transform = transform;
        document.body.style.paddingLeft = padding;
        delta = anchor.getBoundingClientRect().top - anchorTop; // forced reflow
        t.style.transform = prevTransform;
        document.body.style.paddingLeft = prevPadding;
        void document.body.getBoundingClientRect(); // force restore reflow
    }
    // Start the TOC animation and scroll correction simultaneously.
    t.style.transition = 'transform 0.3s ease';
    t.style.transform = transform;
    t.style.pointerEvents = show ? 'auto' : 'none';
    document.body.style.transition = 'padding-left 0.3s ease';
    document.body.style.paddingLeft = padding;
    if (Math.abs(delta) > 0.5) { window.scrollBy({ top: delta, behavior: 'smooth' }); }
};
