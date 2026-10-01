"""Offline geometric connectivity for the two wall-mounted source-safe jibs."""
from collections import defaultdict

from authored_detail import jib_frame


def check(x,z):
    edges=defaultdict(set)
    labels=defaultdict(set)
    for label,a,b,r,material in jib_frame(x,z):
        assert a!=b and r>0 and material
        edges[a].add(b);edges[b].add(a)
        labels[a].add(label);labels[b].add(label)
    anchor=(x,7.7,z)
    hook=(x,8.4,z+24)
    seen={anchor};pending=[anchor]
    while pending:
        for other in edges[pending.pop()]:
            if other not in seen:seen.add(other);pending.append(other)
    assert len(seen)==len(edges),f'{x,z}: disconnected boom endpoints {set(edges)-seen}'
    assert edges[hook]=={(x,16.2,z+24)},'hoist must end at connected tip'
    # A free-ended structural web was the rejected visual defect. Only the
    # mast foot and hook may terminate at a single joint (supported by their
    # separate source-solid wall/turntable and hoist block, respectively).
    dangling=[p for p,links in edges.items() if len(links)<2 and p not in (anchor,hook)]
    assert not dangling,f'{x,z}: unconnected beam ends {dangling}'
    for side in (-.55,.55):
        for i in range(7):
            top=(x+side,18.8-2.6*i/6,z+4*i)
            bottom=(x+side,16.65-1.9*i/6,z+4*i)
            assert bottom in edges[top],f'{x,z}: missing triangular truss post {i}'
        assert (x+side,12.9,z-9) in edges[(x+side,14,z-9)]
    print('JIB_CONNECTED',x,z,'joints',len(edges),'members',sum(map(len,edges.values()))//2)


for base in ((-47,-7),(47,27)):check(*base)
