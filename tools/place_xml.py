"""Serialize the generated primitive scene into Roblox's XML place format.

Typed scene data comes from executing the actual Luau builders. Property types
are checked against a small API-metadata snapshot, never guessed from strings.
"""
from __future__ import annotations
import base64
import struct
import xml.etree.ElementTree as ET


def element(parent, tag, name, text=None):
    node = ET.SubElement(parent, tag, {"name": name})
    if text is not None:
        node.text = str(text)
    return node


def scalar(parent, tag, value):
    ET.SubElement(parent, tag).text = str(value)


def f32(*values):
    return struct.pack('<' + 'f' * len(values), *values)


def string(value):
    raw = value.encode('utf-8')
    return struct.pack('<I', len(raw)) + raw


def encode_attributes(attributes):
    """Roblox AttributesSerialize; same layout as rbx-dom attributes writer."""
    result = bytearray(struct.pack('<I', len(attributes)))
    for name, value in sorted(attributes.items()):
        result += string(name)
        if isinstance(value, bool):
            result += bytes((0x03, int(value)))
        elif isinstance(value, str):
            result += b'\x02' + string(value)
        elif isinstance(value, (int, float)):
            result += b'\x06' + struct.pack('<d', value)
        elif value.get('__type') == 'Vector3':
            result += b'\x11' + f32(*(value[k] for k in ('X', 'Y', 'Z')))
        elif value.get('__type') == 'Color3':
            result += b'\x0f' + f32(*(value[k] for k in ('R', 'G', 'B')))
        elif value.get('__type') == 'CFrame':
            components = value['components']
            result += b'\x14' + f32(*components[:3]) + b'\x00' + f32(*components[3:])
        else:
            raise ValueError(f'Unsupported attribute {name}: {value}')
    return base64.b64encode(result).decode('ascii')


def property_xml(parent, name, value, definition, enums):
    kind = definition['type']
    if name == 'Size' and definition.get('basePart'):
        name = 'size'  # Historical Roblox XML property alias.
    if name == 'Shape':
        name = 'shape'
    if isinstance(value, dict):
        tag = value.get('__type')
        if tag == 'EnumItem':
            element(parent, 'token', name, enums[value['enum']][value['name']])
        elif tag == 'Ref':
            element(parent, 'Ref', name, value['id'])
        elif tag in ('Vector3', 'Vector2', 'Color3'):
            if tag == 'Color3' and name == 'Color' and definition.get('basePart'):
                # Parts serialize their Color through the packed Color3uint8 alias.
                channels = [max(0, min(255, round(value[k] * 255))) for k in ('R', 'G', 'B')]
                element(parent, 'Color3uint8', 'Color3uint8', (255 << 24) | (channels[0] << 16) | (channels[1] << 8) | channels[2])
            else:
                node = element(parent, tag, name)
                for axis in ('R', 'G', 'B') if tag == 'Color3' else (('X','Y','Z') if tag == 'Vector3' else ('X','Y')):
                    scalar(node, axis, value[axis])
        elif tag == 'CFrame':
            node = element(parent, 'CoordinateFrame', name)
            keys = ['X', 'Y', 'Z'] + [f'R{r}{c}' for r in range(3) for c in range(3)]
            for key, number in zip(keys, value['components']):
                scalar(node, key, number)
        elif tag == 'UDim':
            node = element(parent, 'UDim', name)
            scalar(node, 'S', value['Scale'])
            scalar(node, 'O', int(value['Offset']))
        elif tag == 'UDim2':
            node = element(parent, 'UDim2', name)
            for axis in ('X', 'Y'):
                scalar(node, axis + 'S', value[axis]['Scale'])
                scalar(node, axis + 'O', int(value[axis]['Offset']))
        elif tag == 'NumberRange':
            element(parent, 'NumberRange', name, f"{value['Min']} {value['Max']}")
        elif tag in ('NumberSequence', 'ColorSequence'):
            points = []
            for point in value['Keypoints']:
                vals = [point['Time']]
                if tag == 'ColorSequence':
                    vals += [point['Value'][k] for k in ('R', 'G', 'B')] + [0]
                else:
                    vals += [point['Value'], point.get('Envelope', 0)]
                points.extend(str(n) for n in vals)
            element(parent, tag, name, ' '.join(points) + ' ')
        else:
            raise ValueError(f'Unrecognized typed property {name}: {value}')
    elif isinstance(value, bool):
        element(parent, 'bool', name, str(value).lower())
    elif isinstance(value, (int, float)):
        xml_type = {'int': 'int', 'int64': 'int64', 'float': 'float', 'double': 'double'}.get(kind, 'float')
        element(parent, xml_type, name, value)
    elif isinstance(value, str):
        if kind in ('Content', 'ContentId'):
            node = element(parent, 'Content', name)
            scalar(node, 'url', value)
        else:
            element(parent, 'string', name, value)
    elif value is None:
        if definition.get('category') == 'Class':
            element(parent, 'Ref', name, 'null')
    else:
        raise ValueError((name, value))


def import_scene(root, scene, schema):
    """Returns existing top-level service Item nodes for script insertion."""
    items = {}
    services = {}
    children = {}
    for record in scene['records']:
        children.setdefault(record.get('parent'), []).append(record)
    count = 0
    def visit(record, parent):
        nonlocal count
        class_name = record['className']
        node = ET.SubElement(parent, 'Item', {'class': class_name, 'referent': record['id']})
        items[record['id']] = node
        props = ET.SubElement(node, 'Properties')
        definitions = schema['classes'][class_name]
        element(props, 'string', 'Name', record['name'])
        for name, value in sorted(record['properties'].items()):
            if name not in definitions:
                raise ValueError(f'Unknown Roblox property: {class_name}.{name}')
            property_xml(props, name, value, definitions[name], schema['enums'])
        attributes = record.get('attributes', {})
        if attributes:
            element(props, 'BinaryString', 'AttributesSerialize', encode_attributes(attributes))
        if record.get('parent') is None:
            services[class_name] = node
        count += 1
        for child in children.get(record['id'], []):
            visit(child, node)
    for record in children.get(None, []):
        visit(record, root)
    if count != len(scene['records']):
        raise ValueError('Scene contains unreachable or cyclic hierarchy records')
    return services


def make_schema(scene, api):
    classes = {item['Name']: item for item in api['Classes']}
    cache = {}
    def properties(class_name):
        if class_name in cache:
            return cache[class_name]
        cls = classes[class_name]
        inherited = properties(cls['Superclass']).copy() if cls.get('Superclass') in classes else {}
        for member in cls['Members']:
            if member['MemberType'] == 'Property':
                inherited[member['Name']] = {
                    'type': member['ValueType']['Name'],
                    'category': member['ValueType']['Category'],
                    'basePart': class_name == 'BasePart' or inherited.get('Size', {}).get('basePart', False),
                }
        cache[class_name] = inherited
        return inherited
    result = {'classes': {}, 'enums': {}}
    enum_data = {item['Name']: {entry['Name']: entry['Value'] for entry in item['Items']} for item in api['Enums']}
    for record in scene['records']:
        cls = record['className']
        definitions = properties(cls)
        target = result['classes'].setdefault(cls, {})
        for name, value in record['properties'].items():
            if name not in definitions:
                raise ValueError(f'Builder assigned unsupported property {cls}.{name}')
            target[name] = definitions[name]
            if isinstance(value, dict) and value.get('__type') == 'EnumItem':
                result['enums'][value['enum']] = enum_data[value['enum']]
    return result
