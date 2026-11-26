import contextlib
import io
import json
import pathlib
import tempfile
import unittest

from analyze_telemetry import fnum, main


class TelemetryNumbersTests(unittest.TestCase):
    def test_nonfinite_values_use_the_default(self):
        for value in ['NaN', 'Infinity', '-Infinity', float('nan'), float('inf')]:
            with self.subTest(value=value):
                self.assertEqual(fnum({'value': value}, 'value', 7), 7)
        self.assertEqual(fnum({'value': '12.5'}, 'value'), 12.5)

    def test_partial_numeric_records_do_not_stop_the_summary(self):
        events = [
            {'event': 'session_start'},
            {'event': 'shot', 'shot_angle': 'NaN', 'wave': 'Infinity'},
            {'event': 'hit', 'wave': '-Infinity'},
            {'event': 'session_end', 'score': 'NaN', 'shots': 'Infinity'},
        ]
        with tempfile.TemporaryDirectory() as directory:
            path = pathlib.Path(directory) / 'telemetry.jsonl'
            path.write_text('\n'.join(map(json.dumps, events)), encoding='utf-8')
            output = io.StringIO()
            with contextlib.redirect_stdout(output):
                self.assertEqual(main(['analyze_telemetry.py', str(path)]), 0)
            self.assertIn('total shots         : 1', output.getvalue())
            self.assertIn('per-session results:', output.getvalue())


if __name__ == '__main__':
    unittest.main()
