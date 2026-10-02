"""A bounded external X11 focus owner for native focus-loss acceptance."""
import ctypes as C
import time

x = C.CDLL('libX11.so.6')
x.XOpenDisplay.argtypes = [C.c_char_p]
x.XOpenDisplay.restype = C.c_void_p
x.XDefaultRootWindow.argtypes = [C.c_void_p]
x.XDefaultRootWindow.restype = C.c_ulong
x.XCreateSimpleWindow.argtypes = [C.c_void_p, C.c_ulong, C.c_int, C.c_int,
                                  C.c_uint, C.c_uint, C.c_uint, C.c_ulong, C.c_ulong]
x.XCreateSimpleWindow.restype = C.c_ulong
x.XMapWindow.argtypes = [C.c_void_p, C.c_ulong]
x.XSetInputFocus.argtypes = [C.c_void_p, C.c_ulong, C.c_int, C.c_ulong]
x.XSync.argtypes = [C.c_void_p, C.c_int]
x.XDestroyWindow.argtypes = [C.c_void_p, C.c_ulong]
x.XCloseDisplay.argtypes = [C.c_void_p]
display = x.XOpenDisplay(None)
if not display:
    raise SystemExit('No X11 display for real focus boundary')
window = x.XCreateSimpleWindow(display, x.XDefaultRootWindow(display), 10, 10,
                              280, 180, 0, 0, 0x18202A)
try:
    x.XMapWindow(display, window)
    x.XSync(display, 0)
    x.XSetInputFocus(display, window, 1, 0)
    x.XSync(display, 0)
    time.sleep(3)
finally:
    x.XDestroyWindow(display, window)
    x.XCloseDisplay(display)
