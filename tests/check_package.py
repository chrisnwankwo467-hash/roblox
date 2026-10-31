"""Check the baked Studio artifact's hierarchy, metadata and property encoding."""
from pathlib import Path
import base64
import json
import struct
import xml.etree.ElementTree as ET
import zipfile

ROOT=Path(__file__).resolve().parents[1]
root=ET.parse(ROOT/'dist/Bladebound.rbxlx').getroot()
scene=json.loads((ROOT/'dist/world.json').read_text())
instances={node.attrib['referent']:node for node in root.iter('Item')}
checks=0
for record in scene['records']:
    node=instances[record['id']]
    props=node.find('Properties')
    assert props.find("string[@name='Name']").text==record['name']
    checks+=1
    color=record['properties'].get('Color')
    if color and color.get('__type')=='Color3' and record['className'] not in ('Part','SpawnLocation','WedgePart'):
        assert props.find("Color3[@name='Color']") is not None,record['className']
        checks+=1
    attrs=record.get('attributes',{})
    if attrs:
        encoded=props.find("BinaryString[@name='AttributesSerialize']").text
        raw=base64.b64decode(encoded)
        assert struct.unpack_from('<I',raw)[0]==len(attrs)
        checks+=1
    if record['className']=='Workspace':
        assert props.find("int[@name='StreamingMinRadius']").text=='64'
        assert props.find("int[@name='StreamingTargetRadius']").text=='256'
        checks+=2
for node in root.iter('Ref'):
    assert node.text=='null' or node.text in instances,node.text
    checks+=1
for name in ('Bladebound-Scripts.zip','Bladebound-Studio.zip'):
    with zipfile.ZipFile(ROOT/'dist'/name) as archive:
        assert archive.testzip() is None
        for member in archive.namelist():
            if member.endswith('.rbxlx'):
                assert archive.read(member)==(ROOT/'dist/Bladebound.rbxlx').read_bytes()
                checks+=1
print(f'PASS: {checks} baked-package assertions, instance refs, metadata, lighting colors, ZIP integrity')
