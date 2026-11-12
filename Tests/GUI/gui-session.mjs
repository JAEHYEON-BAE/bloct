// Paste this factory (without `export`) into cua_repl when running GUI checks.
// Keep the raw CUA App private: observing it after Quit can reactivate a dying PID.
export async function createGUIAppSession(cua, appPath) {
    if (!appPath.startsWith('/') || !appPath.endsWith('.app')) {
        throw new Error('Use an explicit absolute test .app path');
    }
    const target = await cua.getApp(appPath);
    let retired = false;
    const methods = [
        'getAXState', 'getScreenshot', 'getAXStateAndScreenshot',
        'click', 'drag', 'scroll', 'selectText', 'setValue',
        'performSecondaryAction', 'paste', 'pressKey', 'typeText',
    ];
    function requireLive() {
        if (retired) throw new Error('GUI app session retired; check process exit before binding a fresh session');
    }
    const app = Object.freeze(Object.fromEntries(methods.map(method => [method, (...args) => {
        requireLive();
        return target[method](...args);
    }])));
    return Object.freeze({
        app,
        // Retire BEFORE sending Quit, including while its response is in flight.
        // On error, never retry with the old handle: the process may have exited.
        finish(method, ...args) {
            requireLive();
            if (!['click', 'pressKey', 'performSecondaryAction'].includes(method)) {
                throw new Error('finish requires a terminal UI action');
            }
            retired = true;
            return target[method](...args);
        },
    });
}
