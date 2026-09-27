"""Plain studded test field; invisible markers preserve the gameplay loop."""
import json
import math
from pathlib import Path

out = Path(__file__).resolve().parent.parent
items = []

def part(name, position, size, class_name='Part', visible=False):
    obj = {'Name': name, 'ClassName': class_name, 'Properties': {
        'Anchored': True,
        'CFrame': {'CFrame': {'position': position, 'orientation': [[1,0,0],[0,1,0],[0,0,1]]}},
        'Size': size, 'Color': [112/255,221/255,53/255], 'Material': 'Plastic',
        'TopSurface': 'Studs' if visible else 'Smooth', 'BottomSurface': 'Smooth',
        'Transparency': 0 if visible else 1, 'CanCollide': visible,
    }}
    items.append(obj)
    return obj

part('Field', [0,-1,0], [600,2,600], visible=True)
ocean = part('Ocean', [0,-3.5,0], [2048,1,2048], visible=True)
ocean['Properties'].update({'Color':[0,210/255,225/255], 'Material':'Neon', 'TopSurface':'Smooth', 'CanCollide':False, 'CastShadow':False})
# Four distant cyan backdrop faces give the reference's cloud-free horizon,
# including on Studio graphics settings that do not render Atmosphere.
for name, pos, size in [('North',[0,1020,-1024],[2048,2048,1]),('South',[0,1020,1024],[2048,2048,1]),('West',[-1024,1020,0],[1,2048,2048]),('East',[1024,1020,0],[1,2048,2048])]:
    backdrop = part('Horizon'+name,pos,size,visible=True)
    backdrop['Properties'].update({'Color':[170/255,1,1],'Material':'Neon','TopSurface':'Smooth','CanCollide':False,'CastShadow':False})
    backdrop['Children'] = []
    for face in ['Front','Back','Left','Right']:
        backdrop['Children'].append({'Name':'SkyGradient'+face,'ClassName':'SurfaceGui','Properties':{'Face':face,'LightInfluence':0,'MaxDistance':0,'SizingMode':'FixedSize','CanvasSize':[256,256]},'Children':[
            {'Name':'Gradient','ClassName':'Frame','Properties':{'Size':{'UDim2':[[1,0],[1,0]]},'BorderSizePixel':0,'BackgroundColor3':[1,1,1]},'Children':[
                {'Name':'Color','ClassName':'UIGradient','Properties':{'Rotation':90,'Color':{'ColorSequence':{'keypoints':[{'time':0,'color':[225/255,1,1]},{'time':1,'color':[150/255,250/255,1]}]}}}}
            ]}
        ]})
lid = part('SkyTop', [0,2044,0], [2048,1,2048], visible=True)
lid['Properties'].update({'Color':[225/255,1,1],'Material':'Neon','TopSurface':'Smooth','CanCollide':False,'CastShadow':False})
spawn = part('Spawn', [0,0.15,12], [8,0.3,8], 'SpawnLocation')
spawn['Properties'].update({'Neutral': True, 'Duration': 0, 'CanCollide': True})
for name, x in [('CashIn',-17), ('Upgrade',0), ('Recruit',17)]:
    obj = part(name, [x,1,-15], [1,1,1])
    obj['Children'] = [{'Name':'Prompt', 'ClassName':'ProximityPrompt', 'Properties': {
        'ActionText':name, 'ObjectText':'Barracks', 'Enabled':False,
        'HoldDuration':0.25, 'MaxActivationDistance':12, 'RequiresLineOfSight':False,
    }}]
for ring, (radius, count) in enumerate([(67,6),(136,8),(227,10)],1):
    for i in range(count):
        angle = i/count*math.tau
        part(f'Camp_{ring}_{i+1}', [math.sin(angle)*radius,0.22,math.cos(angle)*radius], [1,0.3,1])
(out/'map.model.json').write_text(json.dumps({'ClassName':'Folder','Children':items},indent=2))
print('Generated plain studded field with invisible gameplay markers')
