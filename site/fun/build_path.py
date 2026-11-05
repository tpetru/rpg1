# Genereaza fun/romania-judete.json pentru fun.php: un singur contur inchis care trece prin
# granitele tuturor judetelor (DFS pe vecinatati, granitele comune se reparcurg), reesantionat
# uniform la 16384 puncte, coordonate intregi 0..1000 ca lista plata [x0,y0,x1,y1,...].
# Sursa: Natural Earth ne_10m_admin_1_states_provinces.geojson filtrat pe adm0_a3 == ROU.
# Rulare: python3 build_path.py ro.geojson romania-judete.json [toleranta_vecini] [judet_start]
# Iasi: comunele din geoBoundaries ROU ADM2 (simplified) aflate in judetul Iasi, toleranta 0.004
import json, sys, math
import numpy as np
sys.setrecursionlimit(10000)
d=json.load(open(sys.argv[1]))
rings=[]; names=[]
for f in d['features']:
    g=f['geometry']; polys=g['coordinates'] if g['type']=='MultiPolygon' else [g['coordinates']]
    rs=[]
    for p in polys:
        for r in p: rs.append(r)
    # one ring per county: the longest (outer); holes (Ilfov) are Bucharest's outline anyway
    r=max(rs,key=len)
    a=np.array(r[:-1],float)
    a[:,0]*=math.cos(math.radians(45.9)); a[:,1]*=-1
    rings.append(a); names.append(f['properties']['name'])
n=len(rings)
# pairwise min distance & closest point indices
D=np.full((n,n),np.inf); I={}
for i in range(n):
    for j in range(n):
        if i==j: continue
        dd=((rings[i][:,None,:]-rings[j][None,:,:])**2).sum(-1)
        k=np.unravel_index(dd.argmin(),dd.shape); D[i,j]=math.sqrt(dd[k]); I[(i,j)]=k
TOL=float(sys.argv[3]) if len(sys.argv)>3 else 1e-3
adj=[[j for j in range(n) if D[i,j]<TOL] for i in range(n)]
for i in range(n):
    if not adj[i]:
        j=int(np.argmin(D[i])); adj[i].append(j); adj[j].append(i)
print('adjacency sizes',[len(a) for a in adj],file=sys.stderr)
visited=[False]*n; out=[]
def walk(i,a,b):
    # forward along ring i from index a to b inclusive
    L=len(rings[i]); k=a
    while True:
        out.append(rings[i][k])
        if k==b: break
        k=(k+1)%L
def dfs(i,e):
    visited[i]=True
    L=len(rings[i])
    # children ordered by position along ring starting at e
    kids=[j for j in adj[i] if not visited[j]]
    kids.sort(key=lambda j:(I[(i,j)][0]-e)%L)
    cur=e
    for j in kids:
        if visited[j]: continue
        p=I[(i,j)][0]
        walk(i,cur,p); cur=p
        # re-find nearest point of j to this point of i
        q=int(((rings[j]-rings[i][p])**2).sum(-1).argmin())
        dfs(j,q)
    if cur==e:
        walk(i,e,(e-1)%L); out.append(rings[i][e])
    else:
        walk(i,cur,e)
START=sys.argv[4] if len(sys.argv)>4 else 'Satu Mare'
start=names.index(START) if START in names else 0
dfs(start,0)
print('unvisited',[names[i] for i in range(n) if not visited[i]],file=sys.stderr)
P=np.array(out)
# arc-length resample to M points
seg=np.sqrt((np.diff(P,axis=0)**2).sum(-1)); s=np.concatenate([[0],np.cumsum(seg)])
print('max jump',seg.max(),'total',s[-1],file=sys.stderr)
M=16384
t=np.linspace(0,s[-1],M,endpoint=False)
x=np.interp(t,s,P[:,0]); y=np.interp(t,s,P[:,1])
x-=x.min(); y-=y.min(); sc=1000/max(x.max(),y.max())
x=np.round(x*sc).astype(int); y=np.round(y*sc).astype(int)
flat=[int(v) for pair in zip(x,y) for v in pair]
json.dump(flat,open(sys.argv[2],'w'),separators=(',',':'))
# error estimate
z=x+1j*y; Z=np.fft.fft(z)
for N in [1,16,256,1024,4096]:
    Zt=np.zeros_like(Z); Zt[0]=Z[0]
    Zt[1:N+1]=Z[1:N+1]; Zt[-N:]=Z[-N:]
    r=np.fft.ifft(Zt); print(N, 100*np.sqrt((abs(r-z)**2).sum()/(abs(z-z.mean())**2).sum()),file=sys.stderr)
