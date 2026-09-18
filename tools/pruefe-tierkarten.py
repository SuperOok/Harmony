# -*- coding: utf-8 -*-
"""Prüft docs/tierkarten.md auf innere Widersprüche."""
import io, re, sys
from collections import Counter, defaultdict

STEINE = {"Wasser":1,"Feld":1,"Baum1":1,"Baum2":2,"Baum3":3,
          "Berg1":1,"Berg2":2,"Berg3":3,"Gebäude":2}

txt = io.open("docs/tierkarten.md", encoding="utf-8").read()
blocks = re.findall(r"Karte:\s+(.+?)\n\s*Muster:\s+(.+?)\n\s*Würfel:\s+auf (\d+)\n\s*Punkte:\s+(.+?)\n", txt)
karten = []
for name, muster, wuerfel, punkte in blocks:
    zellen = {}
    for z, s in re.findall(r"(\d+)=(\S+)", muster):
        zellen[int(z)] = s
    pts = [int(p) for p in punkte.replace("/", " ").split()]
    karten.append((name.strip(), zellen, int(wuerfel), pts))

fehler = []
def pruef(bed, msg):
    if not bed: fehler.append(msg)

pruef(len(karten) == 32, f"32 Karten erwartet, {len(karten)} gefunden")
namen = Counter(n for n,_,_,_ in karten)
for n,c in namen.items():
    pruef(c == 1, f"Name doppelt vergeben: {n}")

# Nachbarschaft der Schablone: Spalten 1-3 / 4-6 / 7-9 / 10-12,
# ungerade Spaltenindizes sitzen eine halbe Zelle tiefer.
def cr(n): return (n-1)//3, (n-1)%3
def nachbarn(n):
    c, r = cr(n)
    aus = [(c, r-1), (c, r+1)]
    versatz = (0,-1) if c % 2 == 0 else (0,1)
    for dc in (-1, 1):
        aus += [(c+dc, r+versatz[0]), (c+dc, r+versatz[1])]
    return {c2*3+r2+1 for c2,r2 in aus if 0 <= c2 <= 3 and 0 <= r2 <= 2}

def cube(n):
    c, r = cr(n)
    z = r - (c - (c & 1)) // 2
    return (c, -c-z, z)
def dreh(p): return (-p[2], -p[0], -p[1])
def kanonisch(zellen):
    formen = []
    pts = [cube(n) for n in zellen]
    for _ in range(6):
        mx, mz = min(p[0] for p in pts), min(p[2] for p in pts)
        formen.append(tuple(sorted((p[0]-mx, p[2]-mz) for p in pts)))
        pts = [dreh(p) for p in pts]
    return min(formen)

for name, zellen, w, pts in karten:
    for z, s in zellen.items():
        pruef(1 <= z <= 12, f"{name}: Zelle {z} außerhalb der Schablone")
        pruef(s in STEINE, f"{name}: unbekannter Stein {s!r}")
    pruef(w in zellen, f"{name}: Würfelzelle {w} kommt im Muster nicht vor")
    pruef(pts == sorted(set(pts)), f"{name}: Punkte nicht streng steigend: {pts}")
    pruef(2 <= len(pts) <= 5, f"{name}: {len(pts)} Tierwürfel")
    # Zusammenhang
    rest, erreicht = set(zellen) - {min(zellen)}, {min(zellen)}
    rand = [min(zellen)]
    while rand:
        z = rand.pop()
        for nb in nachbarn(z) & rest:
            rest.discard(nb); erreicht.add(nb); rand.append(nb)
    pruef(not rest, f"{name}: Muster nicht zusammenhängend, {sorted(rest)} abgetrennt")

# identische Karten
sig = defaultdict(list)
for name, zellen, w, pts in karten:
    sig[(tuple(sorted(zellen.items())), w, tuple(pts))].append(name)
for k, v in sig.items():
    pruef(len(v) == 1, f"identische Karten: {', '.join(v)}")

print("FEHLER" if fehler else "Keine Widersprüche gefunden.")
for f in fehler: print("  -", f)

print(f"\n{'Karte':14}{'Form':22}{'Zellen':>7}{'Steine':>7}{'Würfel':>7}{'Max':>5}")
formen = defaultdict(list)
for name, zellen, w, pts in karten:
    formen[kanonisch(zellen)].append((name, zellen, w, pts))
for form in sorted(formen, key=lambda f: (len(f), f)):
    for name, zellen, w, pts in sorted(formen[form], key=lambda k: sum(STEINE[s] for s in k[1].values())):
        s = sum(STEINE[x] for x in zellen.values())
        print(f"{name:14}{str(sorted(zellen)):22}{len(zellen):>7}{s:>7}{len(pts):>7}{pts[-1]:>5}")
    print()

print("Punktleisten, die mehrfach vorkommen:")
leisten = defaultdict(list)
for name, zellen, w, pts in karten:
    leisten[tuple(pts)].append(name)
for k, v in sorted(leisten.items(), key=lambda kv: -len(kv[1])):
    if len(v) > 1:
        print(f"  {' / '.join(map(str,k)):24} {', '.join(v)}")
print(f"\n{len(leisten)} verschiedene Punktleisten auf 32 Karten")
