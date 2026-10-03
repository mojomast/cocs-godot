"""Full v2 built receipt: real PNG channels with normals enabled AND disabled."""
import json
from pathlib import Path
import struct
import tempfile
import unittest
from unittest.mock import patch
import receipt
import material_pack
from test_material_pack import png
from test_receipt import glb_doc

def encode(doc,blob):
    text=json.dumps(doc).encode();text+=b' '*(-len(text)%4);blob+=b'\0'*(-len(blob)%4)
    return b'glTF'+struct.pack('<II',2,28+len(text)+len(blob))+struct.pack('<I4s',len(text),b'JSON')+text+struct.pack('<I4s',len(blob),b'BIN\0')+blob

class OptionalNormals(unittest.TestCase):
    def test_built_enabled_disabled_and_false_lineage(self):
        for enabled in (True,False):
            with self.subTest(enabled=enabled),tempfile.TemporaryDirectory(dir='/tmp/opencode') as tmp:
                root=Path(tmp)
                def put(name,raw):
                    (root/name).write_bytes(raw);return receipt.digest(raw)
                linear=png(bytes([64,128,192,255]));color=material_pack.srgb_png(linear)
                normal=png(bytes([128,128,255,255]));rough=png(bytes([128,128,128,255]))
                resources={'stone':{'channels':{role:{'path':root/(role+'.png'),'sha256':put(role+'.png',raw)} for role,raw in [('albedo',linear),('normal',normal),('roughness',rough)]},'tileMeters':2}}
                overlay=put('manifest.json',b'checked overlay');hashes={'overlaySha256':overlay,'baseSha256':'base'}
                doc,_=receipt.glb_parts(glb_doc(normal=enabled));blob=bytes(256)
                doc['images']=[];doc['textures']=[];doc['bufferViews']=doc['bufferViews'][:1]
                for raw in (color,normal,rough):
                    doc['bufferViews'].append({'buffer':0,'byteOffset':len(blob),'byteLength':len(raw)})
                    doc['images'].append({'bufferView':len(doc['bufferViews'])-1,'mimeType':'image/png'})
                    doc['textures'].append({'source':len(doc['images'])-1});blob+=raw
                doc['buffers']=[{'byteLength':len(blob)}]
                doc['materials'][0]['pbrMetallicRoughness']['metallicRoughnessTexture']={'index':2}
                gh=put('art.glb',encode(doc,blob));bh=put('master.blend',b'BLENDER-v450'+b'fixture'*20)
                ah=put('authority.json',json.dumps({'id':'fixture','geometryHash':'g'}).encode())
                evidence={'sourceAlbedoSha256':receipt.digest(linear),'embeddedSrgbAlbedoSha256':receipt.digest(color),
                    'normalSourceAndEmbeddedSha256':receipt.digest(normal) if enabled else None,
                    'sourceRoughnessSha256':receipt.digest(rough),'embeddedPackedRoughnessSha256':receipt.digest(rough)}
                lineage={'glbSha256':gh,'geometryHash':'g','pack':hashes,'materialLineage':{'stone':evidence}}
                lh=put('lineage.json',json.dumps(lineage).encode())
                c={'schemaVersion':2,'moth':{'manifest':'manifest.json','sha256':overlay},'maps':[{'id':'fixture',
                    'authority':{'path':'authority.json','sha256':ah,'geometryHash':'g'},
                    'materials':{'stone':{'role':'surface','normal':enabled,'resource':'stone','tileMeters':2}},
                    'art':{'blend':'master.blend','blendSha256':bh,'glb':'art.glb','glbSha256':gh,'lineage':'lineage.json','lineageSha256':lh,'maxPrimitives':4}}]}
                with patch.object(receipt,'ROOT',root),patch.object(material_pack,'load_pack',return_value=(resources,hashes)):
                    self.assertTrue(receipt.verify(c,True)['maps'][0]['built'])
                    if enabled:
                        resources['stone']['channels']['normal']['sha256']='0'*64
                        with self.assertRaisesRegex(ValueError,'color/normal GLB bytes mismatch'):receipt.verify(c,True)
                        resources['stone']['channels']['normal']['sha256']=receipt.digest(normal)
                    evidence['normalSourceAndEmbeddedSha256']='forged'
                    c['maps'][0]['art']['lineageSha256']=put('lineage.json',json.dumps(lineage).encode())
                    with self.assertRaisesRegex(ValueError,'report differs'):receipt.verify(c,True)
                    evidence['normalSourceAndEmbeddedSha256']=receipt.digest(normal) if enabled else None
                    c['maps'][0]['art']['lineageSha256']=put('lineage.json',json.dumps(lineage).encode())
                    c['maps'][0]['materials']['stone']['normal']=not enabled
                    with self.assertRaises(ValueError):receipt.verify(c,True)

if __name__=='__main__':unittest.main()
