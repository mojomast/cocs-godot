from pathlib import Path
from importlib.machinery import SourceFileLoader
checks=SourceFileLoader('event_checks',str(Path(__file__).with_name('horde-checks.py'))).load_module()
checks.run('grenade-old',['node','port/reports/horde-event-repair/horde-grenade.mjs','--baseline=3dbcceb91c2e1542c91e7e2e3fda55ff43a94cb2'],1)
checks.run('grenade-new',['node','port/reports/horde-event-repair/horde-grenade.mjs'])
checks.run('meridian-replay-old',['node','port/reports/horde-event-repair/horde-replay.mjs','--old'],1)
checks.run('meridian-replay-new',['node','port/reports/horde-event-repair/horde-replay.mjs'])
