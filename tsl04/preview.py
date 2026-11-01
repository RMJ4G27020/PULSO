import bpy, numpy as np, os, sys
OUT=os.path.dirname(os.path.abspath(__file__))
D=os.path.join(OUT,"hojas_cian")
ANIMS=["reposo","correr","giro","salto","caida","aterrizaje","impulso","adherencia","muerte","aparicion","carga_baja","victoria"]
Z=3  # escala de vista
def cargar(p):
    im=bpy.data.images.load(p); im.colorspace_settings.name='Non-Color'
    w,h=im.size; b=np.empty(w*h*4,dtype=np.float32); im.pixels.foreach_get(b)
    a=b.reshape(h,w,4)[::-1].copy(); bpy.data.images.remove(im); return a
def amp(a,z): return np.repeat(np.repeat(a,z,axis=0),z,axis=1)
filas=[]; W=0
hojas=[]
for n in ANIMS:
    a=amp(cargar(os.path.join(D,"tsl04_%s.png"%n)),Z); hojas.append((n,a)); W=max(W,a.shape[1])
FONDO=np.array([0.07,0.09,0.055],dtype=np.float32)
for n,a in hojas:
    h,w,_=a.shape
    fila=np.zeros((h,W,4),dtype=np.float32); fila[:,:w]=a
    filas.append(fila); filas.append(np.zeros((6,W,4),dtype=np.float32))
big=np.concatenate(filas,axis=0)
al=big[...,3:4]; rgb=big[...,:3]*al + FONDO*(1-al)
out=np.concatenate([rgb,np.ones_like(al)],axis=2)
im=bpy.data.images.new("prev",out.shape[1],out.shape[0],alpha=True)
im.colorspace_settings.name='Non-Color'
im.pixels.foreach_set(out[::-1].reshape(-1).astype(np.float32))
im.filepath_raw=os.path.join(OUT,"preview.png"); im.file_format='PNG'; im.save()
print("PREVIEW %dx%d"%(out.shape[1],out.shape[0]))
