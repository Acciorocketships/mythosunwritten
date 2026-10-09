import json,sys
from pathlib import Path
source=Path(sys.argv[1] if len(sys.argv)>1 else "/tmp/oct9-local-kernel2")

def prominence(h,n,sign):
    vals=[v*sign for v in h]; order=sorted(range(len(h)),key=lambda i:vals[i],reverse=True)
    parent=list(range(len(h)));active=bytearray(len(h));peak=list(range(len(h)));edge=bytearray(len(h));found=[]
    def root(i):
        while parent[i]!=i:
            parent[i]=parent[parent[i]];i=parent[i]
        return i
    for i in order:
        active[i]=1;x=i%n;z=i//n;edge[i]=int(x==0 or z==0 or x==n-1 or z==n-1)
        for dx,dz in [(-1,0),(1,0),(0,-1),(0,1)]:
            xx=x+dx;zz=z+dz
            if xx<0 or zz<0 or xx>=n or zz>=n:continue
            j=zz*n+xx
            if not active[j]:continue
            a,b=root(i),root(j)
            if a==b:continue
            if vals[peak[a]]<vals[peak[b]]:a,b=b,a
            depth=vals[peak[b]]-vals[i]
            if depth>=8 and not edge[b]:found.append((peak[b]%n,peak[b]//n,depth))
            parent[b]=a;edge[a]|=edge[b]
    return found
for v in [0,1]:
    j=json.load(open(source/f'{v}_heights.json'));n=j['n'];h=j['heights']
    print(v,'peaks>=8m',len(prominence(h,n,1)),'basins>=8m',len(prominence(h,n,-1)))
