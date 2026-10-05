"""Verified absence of any engine-invocation path in this package.

A promise in prose is not evidence. This module parses every ``.py`` file in the
package and walks the resulting syntax tree, so the check operates on what the
code actually imports, calls and attributes rather than on text that may merely
*mention* process spawning in a comment or docstring.

The check is intentionally narrow in one direction and broad in the other: it
refuses the whole ``os`` execution surface, the whole process-spawning module set,
and any call whose name looks like launching something -- regardless of whether
the caller would have been allowed to. A future reviewer adding an engine path
has to delete a line from :data:`policy.FORBIDDEN_IMPORTS`, which is the point.
"""
import ast
from pathlib import Path

from . import policy

#: ``os`` attributes that execute another program. Everything else in ``os`` is
#: filesystem or path manipulation and is not restricted.
OS_EXECUTION_ATTRS = frozenset({
    'system', 'popen', 'execl', 'execle', 'execlp', 'execv', 'execve', 'execvp', 'execvpe',
    'fork', 'forkpty', 'posix_spawn', 'posix_spawnp', 'spawnl', 'spawnle', 'spawnlp', 'spawnv',
    'spawnve', 'spawnvp', 'spawnvpe',
})
#: Attribute names that launch a child. Matched only against a known process-spawning
#: owner, so an unrelated ``.run``/``.call`` in this package is not a false positive;
#: ``FORBIDDEN_REFERENCES`` in policy.py is what refuses importing one by name.
LAUNCH_ATTRS = frozenset({'Popen', 'call', 'check_call', 'check_output', 'getoutput',
                          'getstatusoutput'})
LAUNCH_OWNERS = frozenset({'subprocess', 'multiprocessing', 'shutil', 'pty', 'Popen',
                           'commands'})


class InsecureSourceError(ValueError):
    """This package contains a reference that could execute another program."""


def _dotted(node):
    if isinstance(node, ast.Name):
        return node.id
    if isinstance(node, ast.Attribute):
        head = _dotted(node.value)
        return head + '.' + node.attr if head else node.attr
    return ''


def findings(path):
    """Every execution-capable reference in one module, as readable strings."""
    tree = ast.parse(Path(path).read_text(), filename=str(path))
    found = []
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            for alias in node.names:
                if alias.name.split('.')[0] in policy.FORBIDDEN_IMPORTS:
                    found.append('%s imports %s' % (Path(path).name, alias.name))
        elif isinstance(node, ast.ImportFrom):
            if (node.module or '').split('.')[0] in policy.FORBIDDEN_IMPORTS:
                found.append('%s imports from %s' % (Path(path).name, node.module))
            for alias in node.names:
                if alias.name in policy.FORBIDDEN_REFERENCES:
                    found.append('%s imports %s' % (Path(path).name, alias.name))
        elif isinstance(node, ast.Attribute):
            owner = _dotted(node.value)
            if node.attr in OS_EXECUTION_ATTRS and owner in ('os', 'posix'):
                found.append('%s references os.%s' % (Path(path).name, node.attr))
            if node.attr in LAUNCH_ATTRS and owner.split('.')[-1] in LAUNCH_OWNERS:
                found.append('%s references %s.%s' % (Path(path).name, owner or '?', node.attr))
        elif isinstance(node, ast.Call):
            name = _dotted(node.func)
            if name.split('.')[-1] in OS_EXECUTION_ATTRS and name.split('.')[0] in ('os', 'posix'):
                found.append('%s calls %s' % (Path(path).name, name))
            for keyword in node.keywords:
                if keyword.arg == 'shell':
                    found.append('%s passes a shell keyword' % Path(path).name)
    return found


def audit(root=None):
    """Audit every module in this package. Raises with every finding listed."""
    directory = Path(root or Path(__file__).resolve().parent)
    modules = sorted(directory.glob('*.py'))
    if not modules:
        raise InsecureSourceError('no package modules found to audit')
    problems = []
    for path in modules:
        problems.extend(findings(path))
    if problems:
        raise InsecureSourceError('; '.join(sorted(set(problems))))
    return {'modulesAudited': len(modules),
            'forbiddenImports': list(policy.FORBIDDEN_IMPORTS),
            'forbiddenReferences': list(policy.FORBIDDEN_REFERENCES),
            'osExecutionAttributes': sorted(OS_EXECUTION_ATTRS),
            'launchAttributes': sorted(LAUNCH_ATTRS),
            'launchOwners': sorted(LAUNCH_OWNERS),
            'engineInvocationPaths': 0}
