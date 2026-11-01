import bpy, numpy as np, os
OUT=os.path.dirname(os.path.abspath(__file__)); D=os.path.join(OUT,"comic")
def cargar(p):
    im=bpy.data.images.load(p); im.colorspace_settings.name='Non-Color'
    w,h=im.size; b=np.empty(w*h*4,dtype=np.float32); im.pixels.foreach_get(b)
    a=b.reshape(h,w,4)[::-1].copy(); bpy.data.images.remove(im); return a
def red(a,f):
    h,w,_=a.shape; nh,nw=h//f,w//f
    return a[:nh*f,:nw*f].reshape(nh,f,nw,f,4).mean(axis=(1,3))
ps=[red(cargar(os.path.join(D,"v%d.png"%i)),2) for i in range(1,9)]
W=ps[0].shape[1]; H=ps[0].shape[0]; G=6
filas=[]
for r in range(2):
    fila=[ps[r*4+c] for c in range(4)]
    sep=np.ones((H,G,4),dtype=np.float32); sep[...,:3]=0.07
    row=[]
    for k,f in enumerate(fila):
        row.append(f)
        if k<3: row.append(sep)
    filas.append(np.concatenate(row,axis=1))
    filas.append(np.ones((G,filas[-1].shape[1],4),dtype=np.float32)*np.array([0.07,0.07,0.07,1.0],dtype=np.float32))
ancha=red(cargar(os.path.join(D,"v9.png")),2)
w_tot=filas[0].shape[1]
f=np.zeros((int(ancha.shape[0]*w_tot/ancha.shape[1]),w_tot,4),dtype=np.float32)
import math
z=w_tot/ancha.shape[1]
idx=(np.arange(f.shape[0])/z).astype(int).clip(0,ancha.shape[0]-1)
jdx=(np.arange(w_tot)/z).astype(int).clip(0,ancha.shape[1]-1)
f[:]=ancha[np.ix_(idx,jdx)]
filas.append(f)
big=np.concatenate(filas,axis=0); big[...,3]=1.0
o=bpy.data.images.new("c",big.shape[1],big.shape[0],alpha=True); o.colorspace_settings.name='Non-Color'
o.pixels.foreach_set(big[::-1].reshape(-1).astype(np.float32))
o.filepath_raw=os.path.join(OUT,"contacto.png"); o.file_format='PNG'; o.save()
print("CONTACTO %dx%d"%(big.shape[1],big.shape[0]))
