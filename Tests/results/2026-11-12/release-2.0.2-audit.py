import hashlib,json,plistlib,re,subprocess,zipfile
from pathlib import Path

result=Path('Tests/results/2026-11-12')
archive=Path('/private/tmp/bloct-public-2.0.2/Bloct.zip')
read=lambda name:json.loads((result/name).read_text())
release=read('release-2.0.2-release.json')
run=read('release-2.0.2-actions.json')
tap=read('release-2.0.2-tap-actions.json')
commit=read('release-2.0.2-tap-commit.json')
assert release['tagName']=='v2.0.2' and not release['isDraft'] and not release['isPrerelease']
assert run['status']=='completed' and run['conclusion']=='success'
assert tap['status']=='completed' and tap['conclusion']=='success'
asset=next(a for a in release['assets'] if a['name']=='Bloct.zip')
digest=hashlib.sha256(archive.read_bytes()).hexdigest()
assert asset['digest']=='sha256:'+digest
cask=(result/'release-2.0.2-cask.rb').read_text()
assert re.search(r'version "2\.0\.2"',cask)
assert f'sha256 "{digest}"' in cask
expected={f:Path('Sources/Bloct')/f for f in ['editor-switch.js','task-lists.js','marked.min.js','purify.min.js','style.css','DOMPurify-LICENSE.txt']}
expected.update({f:Path('Editor/dist')/f for f in ['blocks.js','math.js','math.css','visual.css','editor-licenses.txt']})
resources={}
with zipfile.ZipFile(archive) as z:
 info=plistlib.loads(z.read('Bloct.app/Contents/Info.plist'))
 assert info['CFBundleShortVersionString']==info['CFBundleVersion']=='2.0.2'
 for name,path in expected.items():
  source=path.read_bytes()
  if str(path).startswith('Sources/'):
   assert source==subprocess.check_output(['git','show',f'v2.0.2:{path}'])
  assert z.read('Bloct.app/Contents/Resources/'+name)==source,name
  resources[name]=hashlib.sha256(source).hexdigest()
refs=dict(line.split('\t')[::-1] for line in (result/'release-2.0.2-remote-refs.txt').read_text().splitlines())
assert refs['refs/tags/v2.0.2^{}']==run['headSha']==subprocess.check_output(['git','rev-parse','v2.0.2^{}'],text=True).strip()
report={'date':'2026-11-12','releaseURL':release['url'],'tag':'v2.0.2','tagCommit':run['headSha'],'releaseWorkflow':{'id':run['databaseId'],'url':run['url'],'conclusion':run['conclusion']},'download':'anonymous curl -q without authentication','version':info['CFBundleShortVersionString'],'sha256':digest,'digestMatchesGitHub':True,'resourcesMatched':len(resources),'resourceSHA256':resources,'binaryVerification':read('release-2.0.2-public-binary.json'),'homebrew':{'workflow':tap,'caskVersion':'2.0.2','caskSHA256':digest,'caskCommit':commit,'anonymousRawCaskVerified':True},'remoteRefs':refs,'GUIAndRegressionEvidence':'../2026-11-11/review-gui.json','limits':['Real IME and macOS 14 hardware acceptance gates remain.','No installed app replacement or public ZIP GUI run in this release task.','Existing menu polling runner 3 missing-resource failures remain outside the passed scope.']}
(result/'release-2.0.2-published.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({k:report[k] for k in ['releaseURL','tagCommit','sha256','resourcesMatched']},indent=2))
