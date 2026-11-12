// Keeps the author's spelling when a changed block is written again.
//
// The serializer writes a changed block in one canonical spelling. The same
// writer applied to the block as it was read gives that block's canonical
// text, so the difference between it and the file is the author's spelling
// (`_em_`, `$$ x $$`, a setext heading, a `~~~` fence, table padding…) and
// the difference between it and the new text is the edit. merge() applies
// both. Where they touch the same characters the edit wins for that span.
// serialize() accepts the result only when it reads back as the edited block.

interface Hunk {from: number; to: number; text: string}

// Myers' O((N+M)D) difference with a bound on D, so a block rewritten
// wholesale costs little. Returns the replaced spans of `a`, in order.
function diff(a: string, b: string, limit: number): Hunk[] | null {
  let start = 0;
  while (start < a.length && start < b.length && a[start] === b[start]) start++;
  let end = 0;
  while (end < a.length - start && end < b.length - start
      && a[a.length - 1 - end] === b[b.length - 1 - end]) end++;
  const A = a.slice(start, a.length - end), B = b.slice(start, b.length - end);
  const n = A.length, m = B.length;
  if (!n && !m) return [];
  if (!n || !m) return [{from: start, to: start + n, text: B}];
  const max = Math.min(n + m, limit), offset = max + 1;
  const v = new Int32Array(2 * max + 3);
  const trace: Int32Array[] = [];
  let found = -1;
  for (let d = 0; d <= max && found < 0; d++) {
    trace.push(v.slice(offset - d, offset + d + 1));
    for (let k = -d; k <= d; k += 2) {
      let x = k === -d || (k !== d && v[offset + k - 1] < v[offset + k + 1]) ? v[offset + k + 1] : v[offset + k - 1] + 1;
      let y = x - k;
      while (x < n && y < m && A[x] === B[y]) {x++; y++;}
      v[offset + k] = x;
      if (x >= n && y >= m) {found = d; break;}
    }
  }
  if (found < 0) return null;
  // Walk back through the snapshots, collecting the matched runs.
  const equal: [number, number, number][] = [];
  let x = n, y = m;
  for (let d = found; d > 0; d--) {
    const previous = trace[d], at = (k: number) => previous[k + d];
    const k = x - y;
    const down = k === -d || (k !== d && at(k - 1) < at(k + 1));
    const previousK = down ? k + 1 : k - 1;
    const previousX = at(previousK), previousY = previousX - previousK;
    const middleX = down ? previousX : previousX + 1;
    if (x > middleX) equal.push([middleX, middleX - k, x - middleX]);
    x = previousX; y = previousY;
  }
  if (x > 0) equal.push([0, 0, x]);
  equal.reverse();
  const hunks: Hunk[] = [];
  let ai = 0, bi = 0;
  for (const [ea, eb, length] of [...equal, [n, m, 0] as [number, number, number]]) {
    if (ea > ai || eb > bi) hunks.push({from: start + ai, to: start + ea, text: B.slice(bi, eb)});
    ai = ea + length; bi = eb + length;
  }
  return hunks;
}

// Three-way merge of `ours` (the file's spelling) and `theirs` (the edit), both
// derived from `base`. Some edits have no single position: typing ` x` after
// `a` in `| a |` may be read as ` x` after `a` or `x ` after `a `, and both
// sides inserting at one point have no single order (`Title|` + `Z` and
// `|\n=====`). Each reading is a candidate, the edit's first; serialize()
// keeps the first that reads back. No candidate when a difference is too large.
export function merge(base: string, ours: string, theirs: string, limit = 2000): string[] {
  if (ours === base) return [theirs];
  if (theirs === base) return [ours];
  const mine = diff(base, ours, limit), edit = diff(base, theirs, limit);
  if (!mine || !edit) return [];
  const candidates = new Set<string>();
  for (const placed of [edit, slide(base, edit, -1), slide(base, edit, 1)])
    for (const editFirst of [true, false]) candidates.add(combine(base, mine, placed, editFirst));
  return [...candidates];
}

// Moves each pure insertion or deletion as far as it goes in one direction
// without changing what it does or crossing a neighbouring span.
function slide(base: string, hunks: Hunk[], direction: -1 | 1): Hunk[] {
  const result = hunks.map(h => ({...h}));
  const order = direction < 0 ? result : [...result].reverse();
  order.forEach((hunk, index) => {
    const limit = direction < 0 ? (order[index - 1]?.to ?? 0) : (order[index - 1]?.from ?? base.length);
    if (hunk.from === hunk.to) {
      while (direction < 0 && hunk.from > limit && base[hunk.from - 1] === hunk.text[hunk.text.length - 1]) {
        hunk.text = base[hunk.from - 1] + hunk.text.slice(0, -1); hunk.from--; hunk.to--;
      }
      while (direction > 0 && hunk.to < limit && base[hunk.from] === hunk.text[0]) {
        hunk.text = hunk.text.slice(1) + base[hunk.from]; hunk.from++; hunk.to++;
      }
    } else if (!hunk.text) {
      while (direction < 0 && hunk.from > limit && base[hunk.from - 1] === base[hunk.to - 1]) {hunk.from--; hunk.to--;}
      while (direction > 0 && hunk.to < limit && base[hunk.from] === base[hunk.to]) {hunk.from++; hunk.to++;}
    }
  });
  return result;
}

function combine(base: string, mine: Hunk[], edit: Hunk[], editFirst: boolean): string {
  const all = [...mine.map(h => ({...h, edit: false})), ...edit.map(h => ({...h, edit: true}))]
    .sort((p, q) => p.from - q.from || p.to - q.to || (p.edit === editFirst ? -1 : 1));
  let output = '', cursor = 0;
  for (let i = 0; i < all.length;) {
    // A cluster is a run of overlapping spans.
    const cluster = [all[i]];
    let to = all[i].to;
    for (i++; i < all.length; i++) {
      const next = all[i];
      if (next.from < to) {cluster.push(next); to = Math.max(to, next.to);} else break;
    }
    const from = cluster[0].from;
    output += base.slice(cursor, from);
    const sides = new Set(cluster.map(h => h.edit));
    // Conflicting spans take the edit's text over the whole span.
    const chosen = sides.size === 1 ? cluster : cluster.filter(h => h.edit);
    let at = from;
    for (const hunk of chosen) {output += base.slice(at, hunk.from) + hunk.text; at = hunk.to;}
    output += base.slice(at, to);
    cursor = to;
  }
  return output + base.slice(cursor);
}
