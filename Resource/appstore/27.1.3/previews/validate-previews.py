"""Check both encoded previews: uv run --with av python3 validate-previews.py."""
from pathlib import Path
import av,json,hashlib
out=Path(__file__).resolve().parent
report={'sourceAppVersion':'27.1.3 (27013)','durationRange':[15,30],'configuredVideoTargetBitRate':11000000,'files':[],'visualInspection':'pending'}
for name,dimensions in [('ios-preview-en.mp4',(886,1920)),('macos-preview-en.mp4',(1920,1080))]:
    p=out/name
    with av.open(str(p)) as c:
        v=c.streams.video[0];a=c.streams.audio[0];ctx=v.codec_context
        times=[];interlaced=False
        for frame in c.decode(v):
            times.append(float(frame.time));interlaced |= bool(getattr(frame,'interlaced_frame',False))
        row={'file':name,'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'durationSeconds':c.duration/av.time_base,'videoDurationSeconds':float(v.duration*v.time_base),'video':{'codec':ctx.name,'profile':ctx.profile,'avcLevel':ctx.extradata[3]/10,'width':ctx.width,'height':ctx.height,'fps':str(v.average_rate),'pixelFormat':ctx.format.name,'averageBitRate':v.bit_rate,'interlaced':interlaced},'audio':{'codec':a.codec_context.name,'sampleRate':a.codec_context.sample_rate,'channels':a.codec_context.channels},'decodedVideoFrames':len(times)}
        row['technicalPass']=all([15<=row['videoDurationSeconds']<=30,p.stat().st_size<500*1024*1024,(ctx.width,ctx.height)==dimensions,float(v.average_rate)==30,ctx.name=='h264',ctx.profile=='High',ctx.extradata[3]<=40,not interlaced,row['audio']['codec']=='aac',row['audio']['channels']==2,row['audio']['sampleRate'] in [44100,48000],450<=len(times)<=900,all(abs((b-a)-1/30)<0.0001 for a,b in zip(times,times[1:]))])
        report['files'].append(row)
(out/'validation-report.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
assert all(r['technicalPass'] for r in report['files'])
