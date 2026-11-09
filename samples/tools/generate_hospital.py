from pathlib import Path
import sys, math, json, hashlib
import numpy as np, ezdxf, ifcopenshell, ifcopenshell.validate, ifcopenshell.geom
import ifcopenshell.api as api
out=Path(__file__).resolve().parents[1]/'files'
out.mkdir(parents=True,exist_ok=True)
model=ifcopenshell.file(schema='IFC4')
def entity(cls,name): return api.run('root.create_entity',model,ifc_class=cls,name=name)
project=entity('IfcProject','Hospital demonstrativo - EngenhariaArquitetura')
api.run('unit.assign_unit',model,length={'is_metric':True,'raw':'METERS'},area={'is_metric':True,'raw':'SQUARE_METERS'},volume={'is_metric':True,'raw':'CUBIC_METERS'})
ctx=api.run('context.add_context',model,context_type='Model')
body=api.run('context.add_context',model,context_type='Model',context_identifier='Body',target_view='MODEL_VIEW',parent=ctx)
site=entity('IfcSite','Terreno demonstrativo'); building=entity('IfcBuilding','Hospital didatico'); floor=entity('IfcBuildingStorey','Terreo');floor.Elevation=0.
for parent,child in [(project,site),(site,building),(building,floor)]:api.run('aggregate.assign_object',model,products=[child],relating_object=parent)
for e in [site,building,floor]:api.run('geometry.edit_object_placement',model,product=e,matrix=np.eye(4))
doc=ezdxf.new('R2000');doc.units=4; ms=doc.modelspace()
for name,color in [('ARQ_PAREDES',7),('ARQ_PORTAS',1),('ARQ_JANELAS',4),('ARQ_TEXTOS',3),('ARQ_COTAS',2),('ARQ_MOBILIARIO',5),('ARQ_AREAS',8)]:doc.layers.new(name,dxfattribs={'color':color})
native=['EACAD4','50'];group=0;counts={};plan=[]
def point(p):return (round(p[0]*20+80),round((24-p[1])*20+80))
def native_line(a,b,kind=0,width=0,content='',rgb=0,g=None):
 global group
 if g is None:group+=1;g=group
 native.append(';'.join(map(str,[*point(a),*point(b),0,kind,width,g,rgb,0,content.encode('utf-8').hex()])))
def line(a,b,layer='ARQ_MOBILIARIO',g=None):
 ms.add_line((a[0]*1000,a[1]*1000),(b[0]*1000,b[1]*1000),dxfattribs={'layer':layer});native_line(a,b,g=g)
def product(cls,name,a,b,width,height,z=0):
 dx,dy=b[0]-a[0],b[1]-a[1];length=math.hypot(dx,dy)
 obj=entity(cls,name);counts[cls]=counts.get(cls,0)+1
 rep=api.run('geometry.add_wall_representation',model,context=body,length=length,height=height,thickness=width)
 api.run('geometry.assign_representation',model,product=obj,representation=rep)
 m=np.eye(4);m[:3,0]=[dx/length,dy/length,0];m[:3,1]=[-dy/length,dx/length,0];m[:3,3]=[a[0],a[1],z]
 api.run('geometry.edit_object_placement',model,product=obj,matrix=m)
 if cls=='IfcSpace':api.run('aggregate.assign_object',model,products=[obj],relating_object=floor)
 else:api.run('spatial.assign_container',model,products=[obj],relating_structure=floor)
 if cls=='IfcDoor':obj.OverallHeight=height;obj.OverallWidth=length
 if cls=='IfcWindow':obj.OverallHeight=height;obj.OverallWidth=length
 return obj
def wall(a,b):
 if a==b:return
 product('IfcWall','Parede %03d'%(counts.get('IfcWall',0)+1),a,b,.2,3.2)
 ms.add_line((a[0]*1000,a[1]*1000),(b[0]*1000,b[1]*1000),dxfattribs={'layer':'ARQ_PAREDES','lineweight':50})
 native_line(a,b,2,200)
 plan.append({'type':'wall','a':a,'b':b,'width_m':.2})
def opening(a,b,isdoor):
 cls='IfcDoor' if isdoor else 'IfcWindow'; layer='ARQ_PORTAS' if isdoor else 'ARQ_JANELAS'
 product(cls,('Porta' if isdoor else 'Janela')+' %03d'%counts.get(cls,0),a,b,.08,2.1 if isdoor else 1.2,0 if isdoor else 1.)
 native_line(a,b,3 if isdoor else 4,round(math.dist(a,b)*1000))
 ax,ay=a;dx,dy=b[0]-ax,b[1]-ay;length=math.hypot(dx,dy)
 if isdoor:
  # Same clockwise-on-screen opening as CAD 2D, with Y up in CAD exchange.
  end=(ax+dy,ay-dx)
  ms.add_line((ax*1000,ay*1000),(end[0]*1000,end[1]*1000),dxfattribs={'layer':layer})
  angle=math.degrees(math.atan2(dy,dx));ms.add_arc((ax*1000,ay*1000),length*1000,angle-90,angle,dxfattribs={'layer':layer})
 else:
  for d in [-.1,0,.1]:ms.add_line(((ax-dy/length*d)*1000,(ay+dx/length*d)*1000),((b[0]-dy/length*d)*1000,(b[1]+dx/length*d)*1000),dxfattribs={'layer':layer})
 plan.append({'type':'door' if isdoor else 'window','a':a,'b':b})
def hwall(y,x0,x1,gaps=[]):
 cursor=x0
 for lo,hi,door in sorted(gaps):wall((cursor,y),(lo,y));opening((lo,y),(hi,y),door);cursor=hi
 wall((cursor,y),(x1,y))
rooms=[]
top=['EXAMES','DIAGNOSTICO','ENFERMARIA 1','ENFERMARIA 2','ISOLAMENTO']
for i,n in enumerate(top):rooms.append((n,i*8,14,8,10))
x=0
for name,width in [('RECEPCAO',8),('TRIAGEM',6),('CONSULTORIO 1',6),('CONSULTORIO 2',6),('FARMACIA',6),('APOIO / SERVICOS',8)]:rooms.append((name,x,0,width,10));x+=width
def label(text,x,y,size=.3):
 ms.add_text(text,dxfattribs={'layer':'ARQ_TEXTOS','height':size*1000,'insert':(x*1000,y*1000)})
 native_line((x,y),(x+len(text)*size*.6,y),5,round(size*1000),text,0x34d399)
def furniture(x,y,w,h,name='Leito'):
 global group
 group+=1;g=group
 for a,b in [((x,y),(x+w,y)),((x+w,y),(x+w,y+h)),((x+w,y+h),(x,y+h)),((x,y+h),(x,y)),((x,y+h-.5),(x+w,y+h-.5))]:line(a,b,g=g)
 product('IfcFurnishingElement',name,(x,y),(x+w,y),h,.65)
for name,x,y,w,h in rooms:
 sp=product('IfcSpace',name,(x+.2,y+.2),(x+w-.2,y+.2),h-.4,2.8)
 sp.CompositionType='ELEMENT';sp.PredefinedType='INTERNAL'
 label(name,x+.6,y+h/2,.3);label(f'{(w-.2)*(h-.2):.1f} m2',x+.6,y+h/2-.7,.23)
 if 'ENFERMARIA' in name or name=='ISOLAMENTO':
  furniture(x+1,y+1,1,2.2);furniture(x+4,y+1,1,2.2)
 elif 'CONSULTORIO' in name or name in ['TRIAGEM','EXAMES']:
  furniture(x+1,y+1,1,2.1,'Maca');furniture(x+w-2.5,y+1,1.5,.7,'Mesa')
 elif name=='RECEPCAO':furniture(x+1,y+1,4,.8,'Balcao')
product('IfcSpace','CIRCULACAO',(0,10),(40,10),4,2.8)
label('CIRCULACAO PRINCIPAL - 4,00 m',12,11.8,.38)
label('HOSPITAL DEMONSTRATIVO - TERREO',9,26,.5)
label('MODELO SINTETICO PARA TESTES - SEM PROJETO EXECUTIVO',7,-3,.3)
# Outer shell with windows, and corridor entries at both ends.
hwall(0,0,40,[(2,4,False),(10,12,False),(16,18,False),(22,24,False),(28,30,False),(34,36,False)])
hwall(24,0,40,[(i*8+3,i*8+5,False) for i in range(5)])
for x in [0,40]:wall((x,0),(x,10.8));opening((x,10.8),(x,13.2),True);wall((x,13.2),(x,24))
for y in [10,14]:
 relevant=[room for room in rooms if (room[2]==0)==(y==10)]
 hwall(y,0,40,[(x+w/2-.6,x+w/2+.6,True) for _,x,_,w,_ in relevant])
for x in [8,16,24,32]:wall((x,14),(x,24))
for x in [8,14,20,26,32]:wall((x,0),(x,10))
product('IfcSlab','Laje do terreo',(0,0),(40,0),24,.2,-.2)
# Dimension entities in native file; DXF dimension rendered to standard primitives.
for a,b,off in [((0,0),(40,0),1500),((40,0),(40,24),1500)]:
 native_line(a,b,6,off,rgb=0xfbbf24)
 dx,dy=b[0]-a[0],b[1]-a[1];length=math.hypot(dx,dy);ox,oy=dy/length*off,-dx/length*off
 c=(a[0]*1000+ox,a[1]*1000+oy);d=(b[0]*1000+ox,b[1]*1000+oy)
 for p,q in [((a[0]*1000,a[1]*1000),c),((b[0]*1000,b[1]*1000),d),(c,d)]:ms.add_line(p,q,dxfattribs={'layer':'ARQ_COTAS'})
 ms.add_text(f'{length:.2f} m',dxfattribs={'layer':'ARQ_COTAS','height':250,'insert':((c[0]+d[0])/2,(c[1]+d[1])/2+200)})
(out/'hospital_terreo.eacad').write_text('\n'.join(native)+'\n',encoding='utf-8')
doc.saveas(out/'hospital_terreo.dxf')
model.write(str(out/'hospital_terreo.ifc'))
log=ifcopenshell.validate.json_logger();ifcopenshell.validate.validate(model,log,express_rules=True)
errors=[v for v in log.statements if v.get('level')=='error']
(out.parent/'validacao-ifc.json').write_text(json.dumps(log.statements,ensure_ascii=False,indent=2,default=str),encoding='utf-8')
if errors:raise RuntimeError(f'IFC validation errors: {len(errors)}; see log')
settings=ifcopenshell.geom.settings();tested=0
for cls in ['IfcWall','IfcDoor','IfcWindow','IfcSlab','IfcSpace','IfcFurnishingElement']:
 for obj in model.by_type(cls):
  shape=ifcopenshell.geom.create_shape(settings,obj)
  assert len(shape.geometry.verts)>0;tested+=1
audit=ezdxf.readfile(out/'hospital_terreo.dxf').audit();assert not audit.has_errors
(out.parent/'modelo-hospital.json').write_text(json.dumps({'title':'Hospital demonstrativo','synthetic':True,'dimensions_m':[40,24],'rooms':rooms,'ifc_counts':counts,'validated_shapes':tested,'plan':plan},ensure_ascii=False,indent=2),encoding='utf-8')
print('IFC schema + geometry OK:',counts,'shapes:',tested)
print('DXF audit OK; native entities:',len(native)-2)
