// Reading and Aa editing share one page and article. Detached roots cannot
// receive clicks or contribute duplicate headings, search results or IDs.
window._mvInstallEditorSwitch = function(config) {
    const readerHost = document.getElementById('content');
    const readerRender = window._mvRender, readerSearch = window._mvSearch;
    const visualHost = document.createElement('div');
    const decode = value => new TextDecoder().decode(Uint8Array.from(atob(value), c => c.charCodeAt(0)));
    const encode = value => btoa(unescape(encodeURIComponent(value)));
    window._mvGeneration = config.generation;
    let editor = null, visual = false, generation = window._mvGeneration;
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
        const list=blocks(),el=list.find(el=>{const r=el.getBoundingClientRect();return r.height>0 && r.bottom>toolbarHeight() && r.top<innerHeight;});
        return {x:scrollX,y:scrollY,key:el&&key(el),ordinal:el?list.filter(n=>key(n)===key(el)).indexOf(el):0,top:el?.getBoundingClientRect().top};
    }
    function toolbarHeight() {return visual ? editor.toolbar.getBoundingClientRect().height : 0;}
    function restore(saved,delta) {
        const el=blocks().filter(el=>key(el)===saved.key)[saved.ordinal];
        const y=el ? scrollY+el.getBoundingClientRect().top-saved.top-delta : saved.y;
        window.scrollTo({left:saved.x,top:y,behavior:'instant'});
    }
    function mount(raw,baseline) {
        generation=window._mvGeneration;
        readerHost.replaceWith(visualHost);visualHost.id='content';readerHost.removeAttribute('id');
        editor=BloctBlocks.mountVisualEditor(visualHost,raw,{
            savedMarkdown:baseline,trailingParagraph:true,imageURL,renderPreview:source=>_mvRenderOneBlock(source,0),
            onChange:dirty=>{if(visual)window.webkit?.messageHandlers.editorDirty?.postMessage({dirty,generation:window._mvGeneration});}
        });
        visual=true;window._bloctVisual=editor;editor.setEditable(true);editor.unfreeze();
        document.body.classList.add('visual-active');
        window._mvDiskChecking=true;
        window.webkit?.messageHandlers.editorDirty?.postMessage({dirty:editor.session.changed,generation:window._mvGeneration});
    }
    window._mvSwitchEditor = async function(on,baseline) {
        if(on===visual)return {text:visual?editor.session.markdown():window._mvRawLines.join('\n')};
        if(!on && editor.hasOpenDialog) {
            editor.status.textContent='Apply or cancel the open editor before finishing editing.';
            return {blocked:true};
        }
        if(on && typeof BloctBlocks==='undefined')throw new Error('Visual editor resources unavailable');
        const deadline=Date.now()+1500;
        while((visual && editor.view.composing) && Date.now()<deadline)await new Promise(r=>setTimeout(r,20));
        if(visual && editor.view.composing)throw new Error('Finish text composition before switching editors.');
        const saved=anchor(),oldToolbar=toolbarHeight();
        if(on) {
            const raw=window._mvRawLines.join('\n');
            mount(raw,baseline);
            restore(saved,toolbarHeight()-oldToolbar);
            editor.focus();
        } else {
            const snapshot=await editor.handoff();
            editor.destroy();editor=null;window._bloctVisual=null;visual=false;
            visualHost.replaceWith(readerHost);readerHost.id='content';visualHost.removeAttribute('id');visualHost.replaceChildren();
            document.body.classList.remove('visual-active');
            window._mvDiskChecking=false;
            window._mvStale=true;readerRender(encode(snapshot.text));
            ensureReadingEndLine();
            restore(saved,-oldToolbar);
        }
        window._mvBuildTOC?.();
        return {text:visual?editor.session.markdown():window._mvRawLines.join('\n')};
    };
    window._mvRender = value => {
        if(!visual){readerRender(value);ensureReadingEndLine();return;}
        const text=decode(value);window._mvStale=false;
        if(generation!==window._mvGeneration){generation=window._mvGeneration;editor.reload(text);}
        else if(!editor.session.changed && text!==editor.session.markdown())editor.reload(text);
        visualHost.querySelectorAll('img[data-source],img[data-mv-image-source]').forEach(img=>{const url=imageURL(img.dataset.source||img.dataset.mvImageSource);if(url && img.src!==url)img.src=url;});
    };
    window._mvSearch = {
        highlight:term=>visual?editor.search(term):readerSearch.highlight(term),
        clear:()=>visual?editor.search(''):readerSearch.clear(),
        navigate:forward=>visual?editor.navigate(forward):readerSearch.navigate(forward),
        refresh:()=>{if(!visual)readerSearch.refresh();}
    };
    if(config.visual)mount(window._mvRawLines.join('\n'),config.baseline);
    else ensureReadingEndLine();
};
