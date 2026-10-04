import unittest
from grant_policy_v3 import validate_phase,PHASE
class PhaseAdmission(unittest.TestCase):
    def receipt(self):return {'phase':PHASE,'allowedGroups':['controls','reference-accepted-civic-r035']}
    def test_only_explicit_controls_reference_subset_is_admitted(self):
        for group in self.receipt()['allowedGroups']:self.assertTrue(validate_phase(self.receipt(),group))
        self.assertTrue(validate_phase({'phase':PHASE,'allowedGroups':['controls']},'controls'))
    def test_candidate_cannot_be_authorized_by_receipt_or_cli_in_this_phase(self):
        g=self.receipt();g['allowedGroups'].append('step-v1-accepted-civic-r035')
        for group in g['allowedGroups']:
            with self.assertRaises(ValueError):validate_phase(g,group)
        with self.assertRaises(ValueError):validate_phase(self.receipt(),'controls',True)
        g=self.receipt();g['continueAfterKnownBaselineFailure']=True
        with self.assertRaises(ValueError):validate_phase(g,'controls')
    def test_unknown_duplicate_legacy_and_empty_permissions_reject(self):
        for update in [{'allowedGroups':[]},{'allowedGroups':['controls','controls']},{'allowedGroups':['unknown']},
                       {'allowedGroups':'controls'},{'allowedGroups':[None]},{'groups':['controls']},{'phase':'future'}]:
            g=self.receipt();g.update(update)
            with self.assertRaises(ValueError):validate_phase(g,'controls')
if __name__=='__main__':unittest.main()
