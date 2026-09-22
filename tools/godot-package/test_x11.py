"""Real X-server regression for a window destroyed between enumeration and lookup."""
import ctypes as C
import os
import unittest
from verify import X11


class WindowDiscovery(unittest.TestCase):
    def test_destroyed_window_is_ignored_only_during_discovery(self):
        x11 = X11(os.environ['DISPLAY'])
        try:
            x11.lib.XCreateSimpleWindow.argtypes = [C.c_void_p, C.c_ulong, C.c_int, C.c_int, C.c_uint, C.c_uint, C.c_uint, C.c_ulong, C.c_ulong]
            x11.lib.XCreateSimpleWindow.restype = C.c_ulong
            x11.lib.XDestroyWindow.argtypes = [C.c_void_p, C.c_ulong]
            dead = x11.lib.XCreateSimpleWindow(x11.display, x11.root, 0, 0, 100, 100, 0, 0, 0)
            self.assertNotEqual(dead, 0)
            x11.lib.XDestroyWindow(x11.display, dead)
            x11.lib.XSync(x11.display, 0)
            # Simulate the stale result from the earlier XQueryTree call. All
            # subsequent metadata requests are real Xlib calls against the server.
            x11.windows = lambda: iter([dead])
            self.assertIsNone(x11.window(12345))
            self.assertEqual(x11.errors, [])
            x11.pid(dead)
            x11.lib.XSync(x11.display, 0)
            with self.assertRaisesRegex(RuntimeError, 'Unexpected X11'):
                x11.check_errors()
            self.assertEqual(x11.errors[0][0], 3)
        finally:
            x11.close()


if __name__ == '__main__':
    unittest.main()
