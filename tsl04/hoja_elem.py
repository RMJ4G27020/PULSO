import bpy, numpy as np, os, glob
OUT=os.path.dirname(os.path.abspath(__file__)); D=os.path.join(OUT,"hojas_elementos")
ORD=["pinchos_pinchos","bloque_pulsante_encendido","laser_emisor_dispara","laser_haz_haz",
     "dron_purga_patrulla","dron_purga_alerta","dron_zapador_dispara","portal_portal",
     "anclaje_activo","anclaje_activa"]
def cargar(p):
    im=bpy.data.images.load(p); im.colorspace_settings.name='Non-Color'
    w,h=im.size; b=np.empty(w*h*4,dtype=np.float32); im.pixels.foreach_get(b)
    a=b.reshape(h,w,4)[::-1].copy(); bpy.data.images.remove(im); return a
def amp(a,z): return np.repeat(np.repeat(a,z,axis=0),z,axis=1)
hs=[]
for n in ORD:
    p=os.path.join(D,n+".png")
    if not os.path.exists(p): continue
    a=cargar(p)
    z=max(1,int(round(300.0/a.shape[0])))   # normalizar altura de fila
    hs.append((n,amp(a,z)))
W=max(h.shape[1] for _,h in hs)
filas=[]
for n,h in hs:
    f=np.zeros((h.shape[0],W,4),dtype=np.float32); f[:,:h.shape[1]]=h
    filas.append(f); filas.append(np.zeros((10,W,4),dtype=np.float32))
big=np.concatenate(filas,axis=0)
FON=np.array([0.055,0.065,0.045],dtype=np.float32)
al=big[...,3:4]; out=np.concatenate([big[...,:3]*al+FON*(1-al),np.ones_like(al)],axis=2)
im=bpy.data.images.new("z",out.shape[1],out.shape[0],alpha=True)
im.colorspace_settings.name='Non-Color'
im.pixels.foreach_set(out[::-1].reshape(-1).astype(np.float32))
im.filepath_raw=os.path.join(OUT,"elementos.png"); im.file_format='PNG'; im.save()
print("CONTACTO %dx%d"%(out.shape[1],out.shape[0]))
