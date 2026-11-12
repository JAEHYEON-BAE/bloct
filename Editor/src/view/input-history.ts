interface InputState {
  value: string;
  start: number;
  end: number;
  direction: 'forward' | 'backward' | 'none';
}

// A dialog owns its draft history. Never use WebKit's shared native Undo stack:
// it can include edits from another field or a previously closed dialog.
export function inputHistory(input: HTMLTextAreaElement) {
  const capture = (): InputState => ({value: input.value, start: input.selectionStart,
    end: input.selectionEnd, direction: input.selectionDirection});
  const past: InputState[] = [], future: InputState[] = [];
  let current = capture(), before: InputState | undefined;
  let composing = false, lastType = '', lastTime = 0;
  const record = (type: string) => {
    const next = capture(), previous = before ?? current;
    before = undefined;
    if (next.value === previous.value) { current = next; return; }
    const now = Date.now();
    const continuous = /^(insertText|deleteContentBackward|deleteContentForward)$/.test(type)
      && type === lastType && now - lastTime < 500 && !future.length
      && previous.start === previous.end && current.value === previous.value
      && current.start === previous.start && current.end === previous.end;
    if (!continuous) past.push(previous);
    future.length = 0; current = next; lastType = type; lastTime = now;
  };
  const replay = (forward: boolean) => {
    // Consume exhausted history and composition-time commands too: the host
    // must never fall through to document checkpoints while the dialog is open.
    if (composing || input.readOnly) return;
    const from = forward ? future : past, to = forward ? past : future;
    const next = from.pop();
    if (!next) return;
    to.push(capture()); input.value = next.value;
    input.focus(); input.setSelectionRange(next.start, next.end, next.direction);
    current = next; before = undefined; lastType = '';
  };
  input.addEventListener('beforeinput', event => {
    if (event.inputType === 'historyUndo' || event.inputType === 'historyRedo') {
      event.preventDefault(); replay(event.inputType === 'historyRedo');
    } else if (!composing) before = capture();
  });
  input.addEventListener('input', event => {
    if (!composing && !(event as InputEvent).isComposing) record((event as InputEvent).inputType);
  });
  input.addEventListener('compositionstart', () => { before = capture(); composing = true; lastType = ''; });
  input.addEventListener('compositionend', () => { composing = false; record('composition'); });
  return replay;
}
