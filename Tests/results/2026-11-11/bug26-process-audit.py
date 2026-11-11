from pathlib import Path
import subprocess,os,time,json,sys
root=Path('/private/tmp/bloct-bug26-20261111');out=Path('/Users/jaehyeon/PersonalProjects/bloct/Tests/results/2026-11-11/bug26-process.json')
run=int(sys.argv[2])
if sys.argv[1]=='start':
 exe=str(root/'Bloct Lifecycle.app/Contents/MacOS/Bloct')
 rows=subprocess.check_output(['ps','-axo','pid=,command='],text=True).splitlines()
 pids=[int(row.strip().split(None,1)[0]) for row in rows if row.strip().split(None,1)[-1]==exe]
 assert len(pids)==1,pids
 (root/f'run{run}.pid').write_text(str(pids[0]));print({'run':run,'pid':pids[0]})
else:
 pid=int((root/f'run{run}.pid').read_text())
 for attempt in range(50):
  try: os.kill(pid,0)
  except ProcessLookupError: break
  time.sleep(.1)
 else: raise SystemExit('test process still running')
 record={'run':run,'pid':pid,'exited':True,'oldHandleBlocked':True,'previewsRemaining':[p.name for p in root.glob('.mv_preview*')]}
 assert not record['previewsRemaining']
 records=json.loads(out.read_text());records.append(record);out.write_text(json.dumps(records,indent=2)+'\n');print(record)
