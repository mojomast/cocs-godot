import unittest
from pathlib import Path
from run import native_command


class CommandTests(unittest.TestCase):
    def test_non_audio_contract_selects_dummy_without_changing_rendering_scope(self):
        for rendered in [False, True]:
            command = native_command({'resource': 'gpu-exclusive', 'rendered': rendered,
                                      'script': 'res://fixture.gd'}, Path('/binary'), Path('/candidate'))
            self.assertEqual('--headless' in command, not rendered)
            self.assertEqual(command[command.index('--audio-driver') + 1], 'Dummy')
            self.assertEqual(command[-4:], ['--path', '/candidate/godot', '--script', 'res://fixture.gd'])

    def test_real_audio_contract_cannot_be_relabelled_dummy(self):
        command = native_command({'resource': 'gpu-audio-exclusive', 'rendered': True,
                                  'script': 'res://audio.gd'}, Path('/binary'), Path('/candidate'))
        self.assertNotIn('Dummy', command)
        self.assertNotIn('--headless', command)


if __name__ == '__main__': unittest.main()
