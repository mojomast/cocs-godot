"""Explicit archived negative regressions and complete U mode-anchor coverage.

Requires COCS_BOTANICAL_U_FIXTURE_ROOT; reads pinned bytes only, writes nothing.
"""
from archived_fixture import PINS,archive_bytes
from test_correction import CorrectionTests
from test_greenhouse import GreenhouseTests

def main():
    # Preflight every required input before invoking any GLB/JSON parser.
    for path in PINS:archive_bytes(path)
    CorrectionTests.setUpClass()
    CorrectionTests().verify_frozen_actual_U_counterexamples()
    greenhouse=GreenhouseTests()
    greenhouse.verify_U_actual_outer_end_is_floating()
    count=greenhouse.check_dense_frame(include_archive=True)
    print('Pinned 243223d3 archive: all three actual-U failures reproduced; '
          f'{count} successor-frame capsule samples passed, including all 32763 '
          'frozen U route/nav/mode spawn/team objective/camera fixture points')

if __name__=='__main__':main()
