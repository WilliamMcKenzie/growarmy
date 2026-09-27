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

field = part('Field', [0,-1,0], [600,2,600], visible=True)
field['Properties'].update({'Color':[136/255,210/255,65/255], 'TopSurface':'Smooth'})
for x in range(24):
    for z in range(24):
        color = [136/255,210/255,65/255] if (x+z)%2 == 0 else [131/255,204/255,68/255]
        tile = part(f'Grass_{x}_{z}',[-287.5+x*25,0.01,-287.5+z*25],[25,0.02,25],visible=True)
        tile['Properties'].update({'Color':color,'TopSurface':'Smooth','CanCollide':False,'CastShadow':False})
        tile['Children'] = [{'Name':'Studs','ClassName':'Texture','Properties':{
            'Face':'Top','Texture':'rbxassetid://10455712361','StudsPerTileU':4,'StudsPerTileV':4,'OffsetStudsU':(x*25)%4,'OffsetStudsV':(z*25)%4,
            'Color3':color,'Transparency':0.05}}]
ocean = part('Ocean', [0,-3.5,0], [2048,1,2048], visible=True)
ocean['Properties'].update({'Color':[0,210/255,225/255], 'Material':'Neon', 'TopSurface':'Smooth', 'CanCollide':False, 'CastShadow':False})
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
