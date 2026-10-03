"""Linear Moth bytes -> glTF sRGB bytes -> shader-linear round-trip proof."""
import importlib.util
from pathlib import Path
import struct
import unittest
import zlib

SPEC=importlib.util.spec_from_file_location('material_pack',Path(__file__).with_name('material_pack.py'))
pack=importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(pack)


def png(pixels):
    def chunk(kind,body):return struct.pack('>I',len(body))+kind+body+struct.pack('>I',zlib.crc32(kind+body))
    header=struct.pack('>IIBBBBB',len(pixels)//4,1,8,6,0,0,0)
    return b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',header)+chunk(b'IDAT',zlib.compress(b'\0'+pixels))+chunk(b'IEND',b'')


class PackTests(unittest.TestCase):
    def test_true_linear_to_srgb_to_native_linear(self):
        source=bytes([0,64,128,255,64,128,192,123,128,192,255,0])
        width,height,output=pack.linear_rgba(pack.srgb_png(png(source)))
        self.assertEqual((width,height),(3,1))
        self.assertNotEqual(output[:3],source[:3])
        for index,value in enumerate(source):
            if index%4==3:
                self.assertEqual(output[index],value)
            else:
                srgb=output[index]/255
                linear=srgb/12.92 if srgb<=.04045 else ((srgb+.055)/1.055)**2.4
                self.assertLessEqual(abs(linear-value/255),.004)


if __name__=='__main__':unittest.main()
