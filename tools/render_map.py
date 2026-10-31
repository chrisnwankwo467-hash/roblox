"""Render a geometry-only isometric preview of the actual exported hub.

This CPU preview uses generated part transforms/colors. It is not a Studio
screenshot: Roblox lighting, particles, text and real-time effects may differ.
Requires numpy and Pillow, both optional development-only dependencies.
"""
import json
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
scene = json.loads((ROOT / 'dist/world.json').read_text())
WIDTH, HEIGHT = 1600, 1080
pixels = np.zeros((HEIGHT, WIDTH, 3), dtype=np.uint8)
for y in range(HEIGHT):
    t = y / HEIGHT
    pixels[y, :, :] = np.array((143, 207, 238)) * (1-t) + np.array((230, 244, 247)) * t
zbuffer = np.full((HEIGHT, WIDTH), -np.inf, dtype=np.float32)
eye = np.array((260., 260., 360.))
target = np.array((0., 3., 24.))
forward = (eye-target) / np.linalg.norm(eye-target)
right = np.cross(np.array((0., 1., 0.)), forward); right /= np.linalg.norm(right)
up = np.cross(forward, right)
basis = np.stack((right, up, forward), axis=0)
sun = np.array((-0.4, 0.85, 0.35)); sun /= np.linalg.norm(sun)
SCALE = 3.05
OFFSET = np.array((WIDTH * .5, HEIGHT * .51))


def cube():
    v = np.array([(x,y,z) for x in (-.5,.5) for y in (-.5,.5) for z in (-.5,.5)])
    faces = [(0,1,3),(0,3,2),(4,6,7),(4,7,5),(0,4,5),(0,5,1),(2,3,7),(2,7,6),(0,2,6),(0,6,4),(1,5,7),(1,7,3)]
    return v, faces


def cylinder():
    n=12
    v=np.array([(x,.5*np.cos(a),.5*np.sin(a)) for x in (-.5,.5) for a in np.arange(n)*2*np.pi/n]+[(-.5,0,0),(.5,0,0)])
    f=[]
    for i in range(n):
        j=(i+1)%n
        f += [(i,j,n+j),(i,n+j,n+i),(2*n,j,i),(2*n+1,n+i,n+j)]
    return v,f


def ball():
    rings, slices=6,10
    v=[]
    for j in range(rings+1):
        lat=-np.pi/2+j*np.pi/rings
        for i in range(slices):
            a=i*2*np.pi/slices
            v.append((.5*np.cos(lat)*np.cos(a),.5*np.sin(lat),.5*np.cos(lat)*np.sin(a)))
    f=[]
    for j in range(rings):
        for i in range(slices):
            a=j*slices+i;b=j*slices+(i+1)%slices;c=a+slices;d=b+slices
            f.extend([(a,c,d),(a,d,b)])
    return np.array(v),f


meshes={'Block':cube(),'Cylinder':cylinder(),'Ball':ball()}


def triangle(points, depth, color):
    low=np.maximum(np.floor(points.min(axis=0)).astype(int),0)
    high=np.minimum(np.ceil(points.max(axis=0)).astype(int),(WIDTH-1,HEIGHT-1))
    if np.any(high<low): return
    a,b,c=points
    denom=(b[1]-c[1])*(a[0]-c[0])+(c[0]-b[0])*(a[1]-c[1])
    if abs(denom)<1e-7:return
    yy,xx=np.mgrid[low[1]:high[1]+1,low[0]:high[0]+1]
    u=((b[1]-c[1])*(xx-c[0])+(c[0]-b[0])*(yy-c[1]))/denom
    v=((c[1]-a[1])*(xx-c[0])+(a[0]-c[0])*(yy-c[1]))/denom
    w=1-u-v
    z=u*depth[0]+v*depth[1]+w*depth[2]
    sub=zbuffer[low[1]:high[1]+1,low[0]:high[0]+1]
    mask=(u>=-1e-6)&(v>=-1e-6)&(w>=-1e-6)&(z>sub)
    sub[mask]=z[mask]
    pixels[low[1]:high[1]+1,low[0]:high[0]+1][mask]=color


count=0
for record in scene['records']:
    if record['className'] not in ('Part','SpawnLocation','WedgePart'): continue
    p=record['properties']
    if p.get('Transparency',0)>=.65:continue
    comp=p['CFrame']['components']; pos=np.array(comp[:3]); rotation=np.array(comp[3:]).reshape(3,3)
    if abs(pos[0])>245 or pos[2]<-115 or pos[2]>185 or pos[1]<-8:continue
    size=np.array([p['Size'][k] for k in 'XYZ'])
    color=np.array([p.get('Color',{'R':.5,'G':.5,'B':.5})[k] for k in 'RGB'])*255
    shape=p.get('Shape',{}).get('name','Block')
    verts,faces=meshes.get(shape,meshes['Block'])
    world=(verts*size)@rotation.T+pos
    view=(world-target)@basis.T
    screen=view[:,:2]*np.array((SCALE,-SCALE))+OFFSET
    neon=p.get('Material',{}).get('name')=='Neon'
    for face in faces:
        ids=np.array(face)
        normal=np.cross(world[ids[1]]-world[ids[0]],world[ids[2]]-world[ids[0]])
        length=np.linalg.norm(normal)
        if length<1e-8:continue
        normal/=length
        light=1.07 if neon else .66+.34*max(0,np.dot(normal,sun))
        shaded=np.clip(color*light,0,255).astype(np.uint8)
        triangle(screen[ids],view[ids,2],shaded)
    count+=1
image=Image.fromarray(pixels)
draw=ImageDraw.Draw(image)
font_path='/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'
try:
    title=ImageFont.truetype(font_path,36);small=ImageFont.truetype(font_path,18)
except OSError:title=small=ImageFont.load_default()
draw.rounded_rectangle((28,26,750,124),radius=16,fill=(24,38,65))
draw.text((48,38),'BLADEBOUND / SPIRIT TRIALS',font=title,fill=(250,233,178))
draw.text((50,88),'Built map geometry · Studio rendering and effects may differ',font=small,fill=(197,229,244))
OUT=ROOT/'dist/Bladebound-Hub.png'
image.save(OUT)
print(f'Rendered {count} actual hub parts: {OUT}')
