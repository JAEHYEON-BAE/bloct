"""Verify the published ZIP, source resources, remote tag and Homebrew cask."""
import hashlib
import json
import plistlib
import re
import subprocess
import zipfile
from pathlib import Path

result = Path(__file__).parent
read = lambda name: json.loads((result / name).read_text())
release = read('release-2.0.5-release.json')
run = read('release-2.0.5-actions.json')
tap = read('release-2.0.5-tap-actions.json')
commit = read('release-2.0.5-tap-commit.json')
archive = Path('/private/tmp/bloct-public-2.0.5/Bloct.zip')
assert release['tagName'] == 'v2.0.5' and not release['isDraft'] and not release['isPrerelease']
assert run['status'] == tap['status'] == 'completed'
assert run['conclusion'] == tap['conclusion'] == 'success'
asset = next(a for a in release['assets'] if a['name'] == 'Bloct.zip')
digest = hashlib.sha256(archive.read_bytes()).hexdigest()
assert asset['digest'] == 'sha256:' + digest
cask = (result / 'release-2.0.5-cask.rb').read_text()
assert re.search(r'version "2\.0\.5"', cask)
assert f'sha256 "{digest}"' in cask
expected = {f: Path('Sources/Bloct/Resources/Web') / f for f in ['page.html', 'style.css']}
expected.update({f: Path('Sources/Bloct/Resources/Vendor') / f
                 for f in ['marked.min.js', 'purify.min.js', 'DOMPurify-LICENSE.txt']})
expected.update({f: Path('Editor/dist') / f for f in
                 ['blocks.js', 'host.js', 'math.js', 'math.css', 'visual.css', 'editor-licenses.txt']})
resources = {}
with zipfile.ZipFile(archive) as z:
    info = plistlib.loads(z.read('Bloct.app/Contents/Info.plist'))
    assert info['CFBundleShortVersionString'] == info['CFBundleVersion'] == '2.0.5'
    for name, path in expected.items():
        source = path.read_bytes()
        if str(path).startswith('Sources/'):
            assert source == subprocess.check_output(['git', 'show', f'v2.0.5:{path}'])
        assert z.read('Bloct.app/Contents/Resources/' + name) == source, name
        resources[name] = hashlib.sha256(source).hexdigest()
refs = dict(line.split('\t')[::-1] for line in
            (result / 'release-2.0.5-remote-refs.txt').read_text().splitlines())
assert refs['refs/tags/v2.0.5^{}'] == run['headSha'] == subprocess.check_output(
    ['git', 'rev-parse', 'v2.0.5^{}'], text=True).strip()
binary = read('release-2.0.5-public-binary.json')
assert sorted(s['architecture'] for s in binary['slices']) == ['arm64', 'x86_64']
assert all(s['minimum_macos'] == [14, 0, 0] and s['sdk'] == [27, 0, 0] for s in binary['slices'])
report = {
    'date': '2026-11-13', 'releaseURL': release['url'], 'tag': 'v2.0.5',
    'tagCommit': run['headSha'], 'releaseWorkflow': run,
    'download': 'Anonymous curl -q without authentication', 'version': '2.0.5',
    'sha256': digest, 'digestMatchesGitHub': True,
    'resourcesMatched': len(resources), 'resourceSHA256': resources,
    'binaryVerification': binary,
    'homebrew': {'workflow': tap, 'caskVersion': '2.0.5', 'caskSHA256': digest,
                 'caskCommit': commit, 'anonymousRawCaskVerified': True},
    'remoteRefs': refs,
    'regressions': {'model': 61, 'browser': 18, 'visual': 388, 'native': 8,
                    'webkit': 963, 'hosted': 269, 'visualNative': 49},
    'limits': ['Bug 13: spaces inside single-dollar delimiters remain literal.',
               'Bug 54: live Markdown table typing conversion remains unsupported.',
               'Menu polling regression was not rerun; its previously recorded failure remains outside scope.',
               'Real IME and macOS 14 hardware acceptance gates remain.',
               'No installed app replacement or public ZIP GUI test in this release task.'],
}
(result / 'release-2.0.5-published.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
print(json.dumps({k: report[k] for k in ['releaseURL', 'tagCommit', 'sha256', 'resourcesMatched']}, indent=2))
