import bpy, numpy as np, os, sys
OUT=os.path.dirname(os.path.abspath(__file__))
ARGS=sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else ["adherencia"]
NOM=ARGS[0]; Z=6
def cargar(p):
    im=bpy.data.images.load(p); im.colorspace_settings.name='Non-Color'
    w,h=im.size; b=np.empty(w*h*4,dtype=np.float32); im.pixels.foreach_get(b)
    a=b.reshape(h,w,4)[::-1].copy(); bpy.data.images.remove(im); return a
a=cargar(os.path.join(OUT,"hojas_cian","tsl04_%s.png"%NOM))
a=np.repeat(np.repeat(a,Z,axis=0),Z,axis=1)
# rejilla tenue en los limites de cada cuadro, para ver el encuadre de 96 px
for x in range(0,a.shape[1],96*Z):
    a[:,x:x+1,:3]=np.array([0.35,0.42,0.28]); a[:,x:x+1,3]=1.0
FON=np.array([0.07,0.09,0.055],dtype=np.float32)
al=a[...,3:4]; rgb=a[...,:3]*al+FON*(1-al)
out=np.concatenate([rgb,np.ones_like(al)],axis=2)
im=bpy.data.images.new("z",out.shape[1],out.shape[0],alpha=True)
im.colorspace_settings.name='Non-Color'
im.pixels.foreach_set(out[::-1].reshape(-1).astype(np.float32))
im.filepath_raw=os.path.join(OUT,"zoom_%s.png"%NOM); im.file_format='PNG'; im.save()
print("ZOOM %s %dx%d"%(NOM,out.shape[1],out.shape[0]))
