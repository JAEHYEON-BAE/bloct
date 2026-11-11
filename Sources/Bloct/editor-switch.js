// Reading and block editing share one page and article. Detached roots cannot
// receive clicks or contribute duplicate headings, search results or IDs.
window._mvInstallEditorSwitch = function(config) {
    const readerHost = document.getElementById('content');
    const readerRender = window._mvRender, readerSearch = window._mvSearch;
    const visualHost = document.createElement('div');
    const decode = value => new TextDecoder().decode(Uint8Array.from(atob(value), c => c.charCodeAt(0)));
    const encode = value => btoa(unescape(encodeURIComponent(value)));
    window._mvGeneration = config.generation;
    const automatic=config.automatic===true;
    let editor = null, visual = false, generation = window._mvGeneration;
    let pendingPoint=null,pointerStart=null;
    window._mvIsEditing=()=>visual;
    const requestMode=editing=>window.webkit?.messageHandlers.editorModeRequest?.postMessage({editing,generation:window._mvGeneration});
    const readingEndLine=document.createElement('p');
    readingEndLine.className='mv-trailing-line';readingEndLine.setAttribute('aria-hidden','true');
    const ensureReadingEndLine=()=>{if(readerHost.lastChild!==readingEndLine)readerHost.append(readingEndLine);};
    const imageURL = source => {
        if (/^data:image\/(?:png|jpeg|gif|webp);base64,/i.test(source)) return source;
        try { const url = new URL(source); if (['http:', 'https:'].includes(url.protocol)) return url.href; if(url.protocol!=='file:')return null; } catch (_) {}
        return source && window._mvImageOrigin ? window._mvImageOrigin+'?src='+encodeURIComponent(source) : null;
    };
    function blocks() {
        return Array.from(document.querySelectorAll('#content h1,#content h2,#content h3,#content h4,#content h5,#content h6,#content p,#content li,#content pre,#content table,#content img,#content .katex-display'))
            .filter(el=>!el.closest('pre') || el.tagName==='PRE')
            .filter(el=>el.tagName!=='P' || !el.closest('li,table'));
    }
    function key(el) {
        if(el.matches('.katex-display'))return 'math:'+el.querySelector('annotation')?.textContent;
        if(el.tagName==='IMG')return 'image:'+(el.dataset.source||el.dataset.mvImageSource||el.getAttribute('src'));
        return el.tagName+':'+el.textContent.replace(/\s+/g,' ').trim();
    }
    function anchor() {
        const list=blocks(),el=list.find(el=>{const r=el.getBoundingClientRect();return r.height>0 && r.bottom>0 && r.top<innerHeight;});
        return {x:scrollX,y:scrollY,key:el&&key(el),ordinal:el?list.filter(n=>key(n)===key(el)).indexOf(el):0,top:el?.getBoundingClientRect().top};
    }
    function restore(saved) {
        const el=blocks().filter(el=>key(el)===saved.key)[saved.ordinal];
        const y=el ? scrollY+el.getBoundingClientRect().top-saved.top : saved.y;
        window.scrollTo({left:saved.x,top:y,behavior:'instant'});
    }
    function mount(raw,baseline,editing=true) {
        generation=window._mvGeneration;
        readerHost.replaceWith(visualHost);visualHost.id='content';readerHost.removeAttribute('id');
        editor=BloctBlocks.mountVisualEditor(visualHost,raw,{
            savedMarkdown:baseline,trailingParagraph:true,imageURL,renderPreview:source=>_mvRenderOneBlock(source,0),
            onChange:dirty=>{if(visual)window.webkit?.messageHandlers.editorDirty?.postMessage({dirty,generation:window._mvGeneration});}
        });
        visual=editing;window._bloctVisual=editor;editor.setEditable(editing);editor.unfreeze();
        document.body.classList.toggle('visual-active',editing);
        window._mvDiskChecking=editing;
        if(editing)window.webkit?.messageHandlers.editorDirty?.postMessage({dirty:editor.session.changed,generation:window._mvGeneration});
    }
    window._mvSwitchEditor = async function(on,baseline) {
        if(on===visual)return {text:editor?editor.session.markdown():window._mvRawLines.join('\n')};
        if(!on && editor.hasOpenDialog) {
            editor.status.textContent='Apply or cancel the open editor before finishing editing.';
            return {blocked:true};
        }
        if(on && typeof BloctBlocks==='undefined')throw new Error('Visual editor resources unavailable');
        const deadline=Date.now()+1500;
        while((visual && editor.view.composing) && Date.now()<deadline)await new Promise(r=>setTimeout(r,20));
        if(visual && editor.view.composing)throw new Error('Finish text composition before switching editors.');
        const saved=anchor();
        if(on) {
            const raw=window._mvRawLines.join('\n');
            if(automatic){
                editor.session.setSavedBaseline(baseline);editor.unfreeze();editor.setEditable(true);visual=true;
                document.body.classList.add('visual-active');window._mvDiskChecking=true;
            }else mount(raw,baseline);
            restore(saved);
            if(automatic && pendingPoint){const point=pendingPoint;pendingPoint=null;editor.focusAtCoords(point.x,point.y);}
            else editor.focus();
        } else {
            const snapshot=await editor.handoff();
            visual=false;document.body.classList.remove('visual-active');window._mvDiskChecking=false;
            if(automatic){
                editor.setEditable(false);editor.unfreeze();
                window._mvRawLines=snapshot.text.split('\n');window._mvStale=false;
                window.getSelection()?.removeAllRanges();editor.view.dom.blur();
            }else{
                editor.destroy();editor=null;window._bloctVisual=null;
                visualHost.replaceWith(readerHost);readerHost.id='content';visualHost.removeAttribute('id');visualHost.replaceChildren();
                window._mvStale=true;readerRender(encode(snapshot.text));ensureReadingEndLine();
            }
            restore(saved);
        }
        window._mvBuildTOC?.();
        return {text:visual?editor.session.markdown():window._mvRawLines.join('\n')};
    };
    window._mvRender = value => {
        if(!visual&&!automatic){readerRender(value);ensureReadingEndLine();return;}
        const text=decode(value);window._mvStale=false;
        if(generation!==window._mvGeneration){generation=window._mvGeneration;editor.reload(text);}
        else if(!editor.session.changed && text!==editor.session.markdown())editor.reload(text);
        if(automatic&&!visual)window._mvRawLines=editor.session.markdown().split('\n');
        visualHost.querySelectorAll('img[data-source],img[data-mv-image-source]').forEach(img=>{const url=imageURL(img.dataset.source||img.dataset.mvImageSource);if(url && img.src!==url)img.src=url;});
    };
    window._mvSearch = {
        highlight:term=>(automatic||visual)?editor.search(term):readerSearch.highlight(term),
        clear:()=>(automatic||visual)?editor.search(''):readerSearch.clear(),
        navigate:forward=>(automatic||visual)?editor.navigate(forward):readerSearch.navigate(forward),
        refresh:()=>{if(!visual&&!automatic)readerSearch.refresh();}
    };
    if(automatic){
        mount(window._mvRawLines.join('\n'),config.baseline,!!config.visual);
        document.addEventListener('mousedown',event=>{pointerStart={x:event.clientX,y:event.clientY};},true);
        document.addEventListener('click',event=>{
            if(visual || event.defaultPrevented || event.button!==0 || event.detail>1
                || event.metaKey || event.ctrlKey || event.altKey || event.shiftKey)return;
            const target=event.target;
            if(!(target instanceof Element) || target.closest('a,button,input,textarea,select,dialog,#toc'))return;
            const article=visualHost.closest('article.markdown-body');
            if(!visualHost.contains(target) && target!==article && target!==document.body)return;
            const rect=visualHost.getBoundingClientRect();
            if(event.clientX<rect.left || event.clientX>rect.right || event.clientY<rect.top)return;
            if(pointerStart && (Math.abs(event.clientX-pointerStart.x)>4 || Math.abs(event.clientY-pointerStart.y)>4))return;
            pendingPoint={x:event.clientX,y:event.clientY};requestMode(true);
        },true);
        document.addEventListener('keydown',event=>{
            if(event.key!=='Escape' || event.isComposing || editor.view.composing
                || event.metaKey || event.ctrlKey || event.altKey || event.shiftKey
                || editor.hasOpenDialog || event.target?.closest?.('dialog,input,textarea,select,#toc'))return;
            // A reading WebView still receives Escape after the editor blurs.
            // Consume it too, or WebKit forwards the unhandled key to AppKit's beep.
            event.preventDefault();event.stopPropagation();
            if(visual)requestMode(false);
        },true);
    }else if(config.visual)mount(window._mvRawLines.join('\n'),config.baseline);
    else ensureReadingEndLine();
};
