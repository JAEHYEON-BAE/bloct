import select, subprocess, os, json
from pathlib import Path
pid=int(subprocess.check_output(['pgrep','-f','^/private/tmp/bloct-review-20261111/Bloct Review.app/Contents/MacOS/Bloct$'],text=True))
k=select.kqueue()
event=select.kevent(pid,filter=select.KQ_FILTER_PROC,flags=select.KQ_EV_ADD|select.KQ_EV_ONESHOT,fflags=0x80000000|0x04000000)
k.control([event],0,0)
print('Watching PID',pid,flush=True)
events=k.control(None,1,60)
report={'pid':pid,'exitObserved':bool(events),'rawWaitStatus':events[0].data if events else None}
if events:
 status=events[0].data
 report.update({'normalExit':os.WIFEXITED(status),'exitCode':os.WEXITSTATUS(status) if os.WIFEXITED(status) else None})
report['previewFilesRemaining']=[str(p) for p in Path('/private/tmp/bloct-review-20261111').glob('.mv_preview*')]
report['newBloctCrashReports']=[str(p) for p in Path('/Users/jaehyeon/Library/Logs/DiagnosticReports').glob('Bloct*.ips') if p.stat().st_mtime>1794403200]
Path('Tests/results/2026-11-11/review-gui-exit.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2),flush=True)
assert report.get('exitCode')==0 and not report['previewFilesRemaining'] and not report['newBloctCrashReports']
