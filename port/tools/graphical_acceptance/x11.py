"""Minimal Xlib/XTest private-display driver. No packages or shared desktop access."""
import ctypes as C
import struct
import zlib
from pathlib import Path

P = C.c_void_p
U = C.c_ulong
I = C.c_int


class Image(C.Structure):
    _fields_ = [('width', I), ('height', I), ('xoffset', I), ('format', I),
                ('data', P), ('byte_order', I), ('bitmap_unit', I), ('bitmap_bit_order', I),
                ('bitmap_pad', I), ('depth', I), ('bytes_per_line', I), ('bits_per_pixel', I),
                ('red_mask', U), ('green_mask', U), ('blue_mask', U)]


class X11:
    def __init__(self, display):
        # Caller supplies the freshly allocated Xvfb display explicitly.
        self.x = C.CDLL('libX11.so.6')
        self.t = C.CDLL('libXtst.so.6')
        signatures = {
            'XOpenDisplay': (P, [C.c_char_p]), 'XDefaultRootWindow': (U, [P]),
            'XCreateSimpleWindow': (U, [P,U,I,I,C.c_uint,C.c_uint,C.c_uint,U,U]),
            'XStoreName': (I,[P,U,C.c_char_p]), 'XMapWindow':(I,[P,U]),
            'XRaiseWindow':(I,[P,U]), 'XSetInputFocus':(I,[P,U,I,U]),
            'XGetInputFocus':(I,[P,C.POINTER(U),C.POINTER(I)]),
            'XQueryTree':(I,[P,U,C.POINTER(U),C.POINTER(U),C.POINTER(C.POINTER(U)),C.POINTER(C.c_uint)]),
            'XFetchName':(I,[P,U,C.POINTER(C.c_char_p)]), 'XFree':(I,[P]),
            'XSync':(I,[P,I]), 'XKeysymToKeycode':(C.c_ubyte,[P,U]),
            'XStringToKeysym':(U,[C.c_char_p]), 'XQueryKeymap':(I,[P,P]),
            'XQueryPointer':(I,[P,U,C.POINTER(U),C.POINTER(U),C.POINTER(I),C.POINTER(I),C.POINTER(I),C.POINTER(I),C.POINTER(C.c_uint)]),
            'XGrabPointer':(I,[P,U,I,C.c_uint,I,I,U,U,U]),
            'XUngrabPointer':(I,[P,U]),
            'XGetImage':(C.POINTER(Image),[P,U,I,I,C.c_uint,C.c_uint,U,I]),
            'XDestroyImage':(I,[C.POINTER(Image)]),
            'XDestroyWindow':(I,[P,U]), 'XCloseDisplay':(I,[P]),
            'XCreateGC':(P,[P,U,U,P]), 'XSetForeground':(I,[P,P,U]),
            'XDrawString':(I,[P,U,P,I,I,C.c_char_p,I]), 'XFreeGC':(I,[P,P]),
        }
        for name,(result,args) in signatures.items():
            fn = getattr(self.x,name); fn.restype=result; fn.argtypes=args
        for name,args in {
            'XTestFakeKeyEvent':[P,C.c_uint,I,U],
            'XTestFakeButtonEvent':[P,C.c_uint,I,U],
            'XTestFakeMotionEvent':[P,I,I,I,U],
            'XTestFakeRelativeMotionEvent':[P,I,I,U],
        }.items():
            fn=getattr(self.t,name); fn.restype=I; fn.argtypes=args
        self.d = self.x.XOpenDisplay(display.encode())
        if not self.d: raise RuntimeError(f'Cannot open owned display {display}')
        self.root = self.x.XDefaultRootWindow(self.d)
        self.sink = self.x.XCreateSimpleWindow(self.d,self.root,1160,50,400,230,2,0xffffff,0x234467)
        self.x.XStoreName(self.d,self.sink,b'PRIVATE acceptance focus sink')
        self.x.XMapWindow(self.d,self.sink)
        self.sync()

    def sync(self): self.x.XSync(self.d,0)

    def draw_sink(self):
        gc=self.x.XCreateGC(self.d,self.sink,0,None)
        self.x.XSetForeground(self.d,gc,0xffffff)
        for y,text in [(30,b'PRIVATE XVFB FOCUS SINK'),(60,b'Actual XSetInputFocus + XTest input'),(90,b'No owner desktop connection')]:
            self.x.XDrawString(self.d,self.sink,gc,15,y,text,len(text))
        self.x.XFreeGC(self.d,gc); self.sync()

    def windows(self):
        root=U(); parent=U(); children=C.POINTER(U)(); n=C.c_uint()
        self.x.XQueryTree(self.d,self.root,C.byref(root),C.byref(parent),C.byref(children),C.byref(n))
        found=[]
        for w in list(children[:n.value]):
            name=C.c_char_p()
            self.x.XFetchName(self.d,w,C.byref(name))
            found.append((w,name.value.decode(errors='replace') if name.value else ''))
            if name: self.x.XFree(name)
        if children: self.x.XFree(children)
        return found

    def focus(self,w):
        self.x.XRaiseWindow(self.d,w)
        self.x.XSetInputFocus(self.d,w,2,0); self.sync()

    def keycode(self,key): return self.x.XKeysymToKeycode(self.d,self.x.XStringToKeysym(key.encode()))
    def key(self,key,down):
        self.t.XTestFakeKeyEvent(self.d,self.keycode(key),int(down),0); self.sync()
    def button(self,down):
        self.t.XTestFakeButtonEvent(self.d,1,int(down),0); self.sync()
    def motion(self,x,y,relative=False):
        if relative: self.t.XTestFakeRelativeMotionEvent(self.d,x,y,0)
        else: self.t.XTestFakeMotionEvent(self.d,-1,x,y,0)
        self.sync()

    def state(self,probe=True):
        focus=U(); revert=I(); root=U(); child=U(); rx=I(); ry=I(); wx=I(); wy=I(); mask=C.c_uint()
        self.x.XGetInputFocus(self.d,C.byref(focus),C.byref(revert))
        self.x.XQueryPointer(self.d,self.root,C.byref(root),C.byref(child),C.byref(rx),C.byref(ry),C.byref(wx),C.byref(wy),C.byref(mask))
        keys=C.create_string_buffer(32); self.x.XQueryKeymap(self.d,keys)
        result={'focus':focus.value,'pointer_root':[rx.value,ry.value], 'pointer_child':child.value,
                'button1_down':bool(mask.value & 256),
                'keys_down':[k for k in ['w','a','s','d'] if keys.raw[self.keycode(k)//8] & (1 << (self.keycode(k)%8))]}
        if probe:
            # A competing client can acquire only when no other client owns the grab.
            # Success is immediately ungrabbed; this never releases Godot's grab.
            status=self.x.XGrabPointer(self.d,self.sink,False,0,1,1,0,0,0)
            if status == 0: self.x.XUngrabPointer(self.d,0)
            self.sync()
            result['competing_grab_status']=status
        return result

    def screenshot(self,path):
        self.draw_sink()
        image=self.x.XGetImage(self.d,self.root,0,0,1600,1000,0xffffffff,2)
        if not image: raise RuntimeError('XGetImage failed')
        try:
            im=image.contents
            if (im.bits_per_pixel, im.byte_order, im.red_mask, im.green_mask, im.blue_mask)!=(32,0,0xff0000,0xff00,0xff):
                raise RuntimeError('Unexpected Xvfb pixel layout')
            raw=C.string_at(im.data,im.bytes_per_line*im.height)
            rows=[]
            for y in range(im.height):
                row=raw[y*im.bytes_per_line:y*im.bytes_per_line+im.width*4]
                rgb=bytearray(im.width*3)
                rgb[0::3]=row[2::4]; rgb[1::3]=row[1::4]; rgb[2::3]=row[0::4]
                rows.append(b'\0'+rgb)
            def chunk(kind,data):
                return struct.pack('!I',len(data))+kind+data+struct.pack('!I',zlib.crc32(kind+data))
            Path(path).write_bytes(b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('!2I5B',im.width,im.height,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(b''.join(rows)))+chunk(b'IEND',b''))
        finally: self.x.XDestroyImage(image)

    def close(self):
        self.x.XDestroyWindow(self.d,self.sink); self.x.XCloseDisplay(self.d)
