import json,sys
d=json.load(open(sys.argv[1])); n=int(sys.argv[2]) if len(sys.argv)>2 else 40
key=sys.argv[3] if len(sys.argv)>3 else 'self_ms'
print('frames',d['frames'], {k:v for k,v in d['other_messages'].items() if 'sample' not in k})
fs=sorted(d['functions'],key=lambda f:-f[key])
tot=sum(f['self_ms'] for f in fs)
print('total self ms %.0f'%tot)
for f in fs[:n]: print('%9.0f %9.0f %10d  %s'%(f['self_ms'],f['total_ms'],f['calls'],f['name'].replace('res://scripts/','').replace('res://','')))
