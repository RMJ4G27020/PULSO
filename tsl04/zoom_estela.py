import bpy, numpy as np, os
OUT=os.path.dirname(os.path.abspath(__file__)); D=os.path.join(OUT,"hojas_estela_cian")
ORD=["encendido","activa","aviso","apagado"]; Z=10
def cargar(p):
    im=bpy.data.images.load(p); im.colorspace_settings.name='Non-Color'
    w,h=im.size; b=np.empty(w*h*4,dtype=np.float32); im.pixels.foreach_get(b)
    a=b.reshape(h,w,4)[::-1].copy(); bpy.data.images.remove(im); return a
hs=[np.repeat(np.repeat(cargar(os.path.join(D,"estela_%s.png"%n)),Z,axis=0),Z,axis=1) for n in ORD]
W=max(h.shape[1] for h in hs); filas=[]
for h in hs:
    f=np.zeros((h.shape[0],W,4),dtype=np.float32); f[:,:h.shape[1]]=h
    for x in range(0,h.shape[1],32*Z): f[:,x:x+1,:3]=np.array([0.30,0.36,0.24]); f[:,x:x+1,3]=1.0
    filas.append(f); filas.append(np.zeros((8,W,4),dtype=np.float32))
big=np.concatenate(filas,axis=0)
FON=np.array([0.05,0.06,0.04],dtype=np.float32)
al=big[...,3:4]; out=np.concatenate([big[...,:3]*al+FON*(1-al),np.ones_like(al)],axis=2)
im=bpy.data.images.new("z",out.shape[1],out.shape[0],alpha=True)
im.colorspace_settings.name='Non-Color'
im.pixels.foreach_set(out[::-1].reshape(-1).astype(np.float32))
im.filepath_raw=os.path.join(OUT,"zoom_estela.png"); im.file_format='PNG'; im.save()
print("ZOOM %dx%d"%(out.shape[1],out.shape[0]))
