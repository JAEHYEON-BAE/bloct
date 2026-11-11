import test from 'node:test';
import assert from 'node:assert/strict';
import {createGUIAppSession} from './gui-session.mjs';

test('a pending Quit blocks concurrent and later observations before they reach CUA', async () => {
    let finishQuit;
    const calls = [];
    const session = await createGUIAppSession({getApp: async path => {
        calls.push(['bind', path]);
        return {
            getAXState: async () => { calls.push(['observe']); return 'document'; },
            click: index => { calls.push(['quit', index]); return new Promise(resolve => { finishQuit = resolve; }); },
        };
    }}, '/private/tmp/Bloct Lifecycle.app');
    const savedHandle = session.app;
    assert.equal(await savedHandle.getAXState(), 'document');
    const pending = session.finish('click', 18);
    assert.throws(() => savedHandle.getAXState(), /retired/);
    assert.throws(() => savedHandle.pressKey('super+q'), /retired/);
    finishQuit();
    await pending;
    assert.throws(() => session.finish('click', 18), /retired/);
    assert.deepEqual(calls, [['bind', '/private/tmp/Bloct Lifecycle.app'], ['observe'], ['quit', 18]]);
});

test('a lost Quit response never retries or reactivates the possibly exited process', async () => {
    let calls = 0;
    const session = await createGUIAppSession({getApp: async () => ({
        pressKey: async () => { calls++; throw new Error('procNotFound'); },
    })}, '/private/tmp/Bloct Lifecycle.app');
    await assert.rejects(session.finish('pressKey', 'super+q'), /procNotFound/);
    assert.throws(() => session.app.getAXState(), /retired/);
    assert.throws(() => session.finish('pressKey', 'super+q'), /retired/);
    assert.equal(calls, 1);
});

test('a fresh binding has independent lifetime and does not revive saved handles', async () => {
    let bindings = 0;
    const cua = {getApp: async () => {
        const generation = ++bindings;
        return {pressKey: async () => {}, getAXState: async () => `process ${generation}`};
    }};
    const old = await createGUIAppSession(cua, '/private/tmp/Bloct Lifecycle.app');
    await old.finish('pressKey', 'super+q');
    // The caller confirms actual process exit outside CUA before this rebind.
    const fresh = await createGUIAppSession(cua, '/private/tmp/Bloct Lifecycle.app');
    assert.equal(await fresh.app.getAXState(), 'process 2');
    assert.throws(() => old.app.getAXState(), /retired/);
});

test('ambiguous app names are rejected before launch', async () => {
    let launched = false;
    await assert.rejects(createGUIAppSession({getApp: async () => { launched = true; }}, 'Bloct'), /absolute/);
    assert.equal(launched, false);
});
