"""Render real App Store preview captures. Run with:
uv run --with imageio-ffmpeg python3 render-previews.py --source-dir /path/to/captures
The directory must contain ios-raw.mov and macos-raw.mov. Requires macOS fonts.
"""
from pathlib import Path
import subprocess,json,hashlib,argparse,shutil
import imageio_ffmpeg
f=imageio_ffmpeg.get_ffmpeg_exe()
parser=argparse.ArgumentParser()
parser.add_argument('--source-dir',type=Path,required=True)
parser.add_argument('--out',type=Path,default=Path(__file__).resolve().parent)
args=parser.parse_args()
out=args.out
out.mkdir(parents=True,exist_ok=True)
source=args.source_dir
font='/System/Library/Fonts/Supplemental/Arial.ttf'
bold='/System/Library/Fonts/Supplemental/Arial Bold.ttf'
def run(args):subprocess.run([f,'-hide_banner','-loglevel','error','-y',*args],check=True)
common=['-c:v','libx264','-profile:v','high','-level:v','4.0','-pix_fmt','yuv420p','-b:v','11M','-minrate','10M','-maxrate','12M','-bufsize','12M','-r','30','-c:a','aac','-b:a','256k','-ar','48000','-ac','2','-movflags','+faststart','-t','24']
mobile=("[0:v]fps=30,split=2[s0][s1];[s0]trim=start=1:end=8,setpts=PTS-STARTPTS[a];"
 "[s1]trim=start=22:end=39,setpts=PTS-STARTPTS[b];"
 "[a][b]concat=n=2:v=1:a=0,tpad=stop_mode=clone:stop_duration=1,scale=886:1920:force_original_aspect_ratio=increase,crop=886:1920,setsar=1,"
 "drawbox=x=0:y=1700:w=iw:h=220:color=0xf7faf9:t=fill,"
 "drawbox=x=48:y=1730:w=70:h=6:color=0x007d73:t=fill,"
 f"drawtext=fontfile='{bold}':text='Create with JSX-style':x=48:y=1770:fontsize=48:fontcolor=0x163b38:enable='lt(t,7)',"
 f"drawtext=fontfile='{bold}':text='JavaScript':x=48:y=1825:fontsize=48:fontcolor=0x163b38:enable='lt(t,7)',"
 f"drawtext=fontfile='{bold}':text='Preview your widget':x=48:y=1770:fontsize=48:fontcolor=0x163b38:enable='gte(t,7)',"
 f"drawtext=fontfile='{font}':text='Make it yours.':x=48:y=1830:fontsize=34:fontcolor=0x59736f:enable='gte(t,7)'[v]")
run(['-i',str(source/'ios-raw.mov'),'-f','lavfi','-i','anullsrc=r=48000:cl=stereo','-filter_complex',mobile,'-map','[v]','-map','1:a',*common,str(out/'ios-preview-en.mp4')])
mac=("fps=30,trim=start=2:end=26,setpts=PTS-STARTPTS,tpad=stop_mode=clone:stop_duration=1,crop=2360:1328:112:76,scale=1920:1080,setsar=1,fps=30:start_time=0,"
 "drawbox=x=0:y=960:w=iw:h=120:color=0xf7faf9:t=fill,"
 "drawbox=x=56:y=987:w=68:h=5:color=0x007d73:t=fill,"
 f"drawtext=fontfile='{bold}':text='Create with JSX-style JavaScript':x=56:y=1014:fontsize=40:fontcolor=0x163b38:enable='lt(t,12)',"
 f"drawtext=fontfile='{bold}':text='Preview layouts in different sizes':x=56:y=1014:fontsize=40:fontcolor=0x163b38:enable='gte(t,12)'")
run(['-i',str(source/'macos-raw.mov'),'-f','lavfi','-i','anullsrc=r=48000:cl=stereo','-vf',mac,'-map','0:v','-map','1:a',*common,str(out/'macos-preview-en.mp4')])
p=out/'asset-plan.json'
if not p.exists(): shutil.copyfile(Path(__file__).resolve().parent/'asset-plan.json',p)
d=json.loads(p.read_text());d['status']='encoded; visual and technical validation pending';d['assets'][0]['story']=['Create with JSX-style JavaScript','Preview your widget'];d['assets'][1]['story']=['Create with JSX-style JavaScript','Preview layouts in different sizes'];d['sources']={n:{'path':str(source/f'{n}-raw.mov'),'sha256':hashlib.sha256(Path(str(source/f'{n}-raw.mov')).read_bytes()).hexdigest()} for n in ['ios','macos']};p.write_text(json.dumps(d,indent=2)+'\n')
print('Encoded both 24-second app previews')
