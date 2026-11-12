// Remembered scroll position and the resize scroll anchor. Installed with the
// TOC once the page has finished loading (see toc.js).
window._mvInstallScroll = function(savedScrollY) {
    // Restore the saved scroll position.
    if (savedScrollY > 0) {
        setTimeout(function() { window.scrollTo({ top: savedScrollY, behavior: 'smooth' }); }, 100);
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
