"""Build an editable Studio place, full source bundle, and standalone map ZIP.

Usage: python3 tools/package.py [--luau /path/to/luau]
Luau executes the actual builders with construction doubles. Studio still needs
live visual/physics testing; no external assets or credentials are required.
"""
from pathlib import Path
import argparse
import json
import shutil
import subprocess
import sys
import xml.etree.ElementTree as ET
import zipfile
from place_xml import import_scene, make_schema

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'dist'
OUT.mkdir(exist_ok=True)
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--luau', default=shutil.which('luau') or '/workspace/tools/luau/luau')
args = parser.parse_args()
scene_path = OUT / 'world.json'
subprocess.run([sys.executable, str(ROOT / 'tools/export_world.py'), args.luau, str(scene_path)], check=True)
scene = json.loads(scene_path.read_text())
api_cache = Path('/workspace/tools/roblox-api.json')
schema_path = ROOT / 'tools/roblox_schema.json'
if api_cache.exists():
    schema = make_schema(scene, json.loads(api_cache.read_text()))
    schema_path.write_text(json.dumps(schema, indent=2) + '\n')
else:
    schema = json.loads(schema_path.read_text())

root = ET.Element('roblox', {
    'version': '4',
    'xmlns:xmime': 'http://www.w3.org/2005/05/xmlmime',
    'xmlns:xsi': 'http://www.w3.org/2001/XMLSchema-instance',
    'xsi:noNamespaceSchemaLocation': 'http://www.roblox.com/roblox.xsd',
})
for value in ('null', 'nil'):
    ET.SubElement(root, 'External').text = value
services = import_scene(root, scene, schema)


def item(parent, class_name, name):
    node = ET.SubElement(parent, 'Item', {'class': class_name, 'referent': 'CODE_' + name})
    props = ET.SubElement(node, 'Properties')
    ET.SubElement(props, 'string', {'name': 'Name'}).text = name
    return node, props


workspace = services['Workspace']
props = workspace.find('Properties')
ET.SubElement(props, 'bool', {'name': 'StreamingEnabled'}).text = 'true'
ET.SubElement(props, 'int', {'name': 'StreamingMinRadius'}).text = '64'
ET.SubElement(props, 'int', {'name': 'StreamingTargetRadius'}).text = '256'
replicated, _ = item(root, 'ReplicatedStorage', 'ReplicatedStorage')
server, _ = item(root, 'ServerScriptService', 'ServerScriptService')
players, _ = item(root, 'StarterPlayer', 'StarterPlayer')
client, _ = item(players, 'StarterPlayerScripts', 'StarterPlayerScripts')
scripts = [
    (replicated, 'ModuleScript', 'SwordData'),
    (server, 'ModuleScript', 'WorldBuilder'),
    (server, 'Script', 'GameServer'),
    (client, 'LocalScript', 'GameClient'),
]
for parent, class_name, name in scripts:
    node, props = item(parent, class_name, name)
    ET.SubElement(props, 'ProtectedString', {'name': 'Source'}).text = (ROOT / (name + '.lua')).read_text()

place = OUT / 'Bladebound.rbxlx'
ET.ElementTree(root).write(place, encoding='utf-8', xml_declaration=True)
# Artifact integrity: exact source text, unique refs, complete baked hierarchy.
restored = ET.parse(place).getroot()
embedded, refs = {}, set()
for node in restored.iter('Item'):
    ref = node.attrib['referent']
    assert ref not in refs, ref
    refs.add(ref)
    props = node.find('Properties')
    source = props.find("ProtectedString[@name='Source']") if props is not None else None
    if source is not None:
        embedded[props.find("string[@name='Name']").text] = source.text
assert len(embedded) == 4
for name, source in embedded.items():
    assert source == (ROOT / (name + '.lua')).read_text(), name
assert len(refs) > 2000, 'Editable map missing from place'
for ref in restored.iter('Ref'):
    assert ref.text == 'null' or ref.text in refs, ref.text

files = [ROOT / (name + '.lua') for _, _, name in scripts]
files += [ROOT / 'README.md', place]
files += sorted(path for path in (ROOT / 'tools').iterdir() if path.suffix in ('.py', '.json'))
files += sorted(path for path in (ROOT / 'tests').iterdir() if path.suffix in ('.py', '.luau'))
preview = OUT / 'Bladebound-Hub.png'
if preview.exists():
    files.append(preview)
bundle = OUT / 'Bladebound-Scripts.zip'
with zipfile.ZipFile(bundle, 'w', compression=zipfile.ZIP_DEFLATED) as archive:
    for path in files:
        archive.write(path, path.relative_to(ROOT))
    assert archive.testzip() is None
# Browser-friendly single-place download; extracting leaves the place at top level.
with zipfile.ZipFile(OUT / 'Bladebound-Studio.zip', 'w', compression=zipfile.ZIP_DEFLATED) as archive:
    archive.write(place, 'Bladebound.rbxlx')
    assert archive.testzip() is None
print(f'Built editable {place.name}: {place.stat().st_size:,} bytes; {len(refs):,} instances, 4 sources verified')
print(f'Built {bundle.name}: {bundle.stat().st_size:,} bytes; {len(files)} files; ZIP integrity passed')
