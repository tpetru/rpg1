import json, sys, numpy as np
from openskp import SkpFile
sc = SkpFile.open('/tmp/skpout/passat.skp').build_scene()
S = 0.893; CX = 1.19; ZF_M = -1.055; ZF_G = 1.39; Y0 = 0.04
mats = []
for m in sc.gltf_materials:
    pb = m.get('pbrMetallicRoughness', {}) if isinstance(m, dict) else {}
    mats.append({'c': [round(float(v), 3) for v in pb.get('baseColorFactor', [1, 1, 1, 1])], 'm': round(float(pb.get('metallicFactor', 0.0)), 2), 'r': round(float(pb.get('roughnessFactor', 0.5)), 2), 'a': 1 if m.get('alphaMode') == 'BLEND' else 0})
P = sc.glb_primitives
# twin primitives (aceeași geometrie în materialul 0 + 1): păstrăm doar prima față (mat 1)
drop = set()
for i in range(len(P) - 1):
    a, b = P[i], P[i + 1]
    if a.material_index == 0 and b.material_index == 1 and len(a.positions) == len(b.positions): drop.add(i)
groups = {}   # cheie -> liste de (pos, nrm, idx)
wheelc = {}
def arr(p):
    pos = np.asarray(p.positions, dtype=np.float64).reshape(-1, 3); nrm = np.asarray(p.normals, dtype=np.float64).reshape(-1, 3)
    idx = np.asarray(p.indices, dtype=np.int64)
    return pos, nrm, idx
for i, p in enumerate(P):
    if i in drop: continue
    pos, nrm, idx = arr(p)
    tr = idx.reshape(-1, 3); fn = np.cross(pos[tr[:, 1]] - pos[tr[:, 0]], pos[tr[:, 2]] - pos[tr[:, 0]])
    for c in range(3):
        d = (nrm[tr[:, c]] * fn).sum(1); bad = tr[:, c][d < 0]; nrm[bad] = -nrm[bad] if False else nrm[bad]
    # vârfurile nu sunt indexate partajat: corectăm fiecare vârf după fața lui
    flip = np.zeros(len(pos), bool)
    for c in range(3): flip[tr[:, c]] |= (nrm[tr[:, c]] * fn).sum(1) < 0
    nrm[flip] *= -1
    if 184 <= i <= 243:
        c = pos.mean(0); w = (0 if c[0] < CX else 1, 1 if c[2] > -2.5 else 0)
        groups.setdefault(('w', w, p.material_index), []).append((pos, nrm, idx)); wheelc.setdefault(w, []).append(pos)
    else:
        groups.setdefault(('b', p.material_index), []).append((pos, nrm, idx))
wc = {w: (np.min(np.vstack(v), 0) + np.max(np.vstack(v), 0)) / 2 for w, v in wheelc.items()}
def tobody(pos):
    return np.stack([(pos[:, 0] - CX) * S, (pos[:, 1] - Y0) * S, (pos[:, 2] - ZF_M) * S + ZF_G], 1)
binout = bytearray(); out = {'mats': mats, 'groups': [], 'wheels': {}}
def pad(): 
    while len(binout) % 4: binout.append(0)
for key, lst in groups.items():
    pos = np.vstack([a for a, _, _ in lst]); nrm = np.vstack([b for _, b, _ in lst])
    off = 0; ids = []
    for a, _, idx in lst: ids.append(idx + off); off += len(a)
    idx = np.concatenate(ids)
    if key[0] == 'w':
        w = key[1]; c = wc[w]
        pos = (pos - c) * S
        out['wheels'][f'{w[0]}{w[1]}'] = [round(float((c[0] - CX) * S), 4), round(float((c[1] - Y0) * S), 4), round(float((c[2] - ZF_M) * S + ZF_G), 4)]
    else:
        pos = tobody(pos)
    # normale netede: media fețelor vecine din același punct, doar dacă unghiul dintre ele < 38° (muchiile ascuțite rămân ascuțite)
    tr2 = idx.reshape(-1, 3); fn2 = np.cross(pos[tr2[:, 1]] - pos[tr2[:, 0]], pos[tr2[:, 2]] - pos[tr2[:, 0]])
    fl = np.linalg.norm(fn2, axis=1, keepdims=True); fl[fl == 0] = 1; fnu = fn2 / fl
    corner_v = tr2.reshape(-1); corner_f = np.repeat(np.arange(len(tr2)), 3)
    pk = np.round(pos[corner_v] * 5000).astype(np.int64)
    _, pid = np.unique(pk, axis=0, return_inverse=True); pid = pid.reshape(-1)
    order = np.argsort(pid, kind='stable'); sp = pid[order]; bounds = np.flatnonzero(np.diff(sp)) + 1
    newn = np.zeros((len(corner_v), 3)); cosT = np.cos(np.radians(38))
    for grp in np.split(order, bounds):
        if len(grp) == 1: newn[grp[0]] = fnu[corner_f[grp[0]]]; continue
        F = fn2[corner_f[grp]]; U = fnu[corner_f[grp]]
        M = (U @ U.T) > cosT
        newn[grp] = M @ F
    nrm = np.zeros_like(nrm); nrm[corner_v] = newn
    # sudură
    q = np.round(pos * 2000).astype(np.int64); qn = np.round(nrm * 40).astype(np.int64)
    k = np.concatenate([q, qn], 1)
    _, first, inv = np.unique(k, axis=0, return_index=True, return_inverse=True)
    pos = pos[first]; nrm = nrm[first]; idx = inv.reshape(-1)[idx]
    tri = idx.reshape(-1, 3); ok = (tri[:, 0] != tri[:, 1]) & (tri[:, 1] != tri[:, 2]) & (tri[:, 0] != tri[:, 2]); idx = tri[ok].reshape(-1)
    lo, hi = pos.min(0), pos.max(0); ctr = (lo + hi) / 2; half = np.maximum((hi - lo) / 2, 1e-4)
    qp = np.round((pos - ctr) / half * 32767).astype(np.int16)
    ln = np.linalg.norm(nrm, axis=1, keepdims=True); ln[ln == 0] = 1; nn = np.round(nrm / ln * 127).astype(np.int8)
    g = {'k': key[0], 'mat': key[-1], 'nv': len(pos), 'ni': len(idx), 'c': [round(float(v), 5) for v in ctr], 'h': [round(float(v), 5) for v in half]}
    if key[0] == 'w': g['w'] = f'{key[1][0]}{key[1][1]}'
    pad(); g['po'] = len(binout); binout += qp.tobytes()
    pad(); g['no'] = len(binout); binout += np.concatenate([nn, np.zeros((len(nn), 1), np.int8)], 1).tobytes() if False else nn.tobytes()
    pad(); g['io'] = len(binout); g['it'] = 4 if len(pos) > 65535 else 2
    binout += idx.astype(np.uint32 if len(pos) > 65535 else np.uint16).tobytes()
    out['groups'].append(g)
open('/home/user/rpg1/site/drift/models/passat.bin', 'wb').write(binout)
json.dump(out, open('/home/user/rpg1/site/drift/models/passat.json', 'w'), separators=(',', ':'))
print(len(binout) / 1e6, 'MB', len(out['groups']), 'groups', out['wheels'], sum(g['nv'] for g in out['groups']), 'verts')
