#!/usr/bin/env python3
"""Rebuild DEADFALL's original synthesized sound bank; stdlib + ffmpeg only."""
from array import array
from pathlib import Path
import math, random, subprocess, wave

OUT = Path(__file__).resolve().parents[2] / 'assets/audio'
RATE = 22050
TAU = math.tau

def write(name, seconds, sample, stereo=False, ogg=False):
    rng = random.Random(7152026)
    values = array('h')
    for i in range(round(seconds * RATE)):
        t = i / RATE
        v = max(-0.92, min(0.92, sample(t, rng)))
        values.append(round(v * 32767))
        if stereo:
            values.append(round(max(-0.92, min(0.92, v * (0.93 + 0.07 * math.sin(t * .7)))) * 32767))
    path = OUT / (name + '.wav')
    with wave.open(str(path), 'wb') as f:
        f.setnchannels(2 if stereo else 1); f.setsampwidth(2); f.setframerate(RATE); f.writeframes(values.tobytes())
    if ogg:
        subprocess.run(['ffmpeg', '-y', '-hide_banner', '-loglevel', 'error', '-i', str(path), '-c:a', 'libvorbis', '-q:a', '4', str(path.with_suffix('.ogg'))], check=True)
        path.unlink()

def tone(t, hz): return math.sin(TAU * hz * t)
def tick(t, r, decay=55): return r.uniform(-1, 1) * math.exp(-t * decay)

def music(t, r):
    beat = .625
    roots = [73.4162, 58.2705, 87.3071, 65.4064]
    chord = int(t / 5) % 4
    base = roots[chord]
    rel = t % 5
    padenv = min(1, rel / .3, (5 - rel) / .45)
    minor = chord == 0
    pad = sum(tone(t, base * ratio * 2) + .25 * tone(t, base * ratio * 2.003) for ratio in [1, 2**((3 if minor else 4)/12), 1.4983]) * .048 * padenv
    b = t % beat
    index = int(t / beat)
    kick = math.sin(TAU * (43 * b + 7 * (1-math.exp(-b*35)))) * math.exp(-b*15) * .28
    bass = (tone(b, base) + .18*tone(b, base*2)) * math.exp(-b*6) * .11
    snare = tick(b, r, 24) * .105 if index % 4 in [1, 3] else 0
    hat = tick(t % (beat*.5), r, 150) * .035
    notes = [0,7,12,15,14,7,3,10]
    n = int(t / (beat*.5))
    p = t % (beat*.5)
    hz = 293.665 * 2**(notes[n%8]/12)
    lead = (tone(p,hz)+.2*tone(p,hz*2))*min(1,p*180)*math.exp(-p*9)*.036
    # Deliberate zero crossings at phrase boundary; no runtime synthesis.
    edge = min(1,t/.05,(20-t)/.10)
    return (pad + kick + bass + snare + hat + lead) * edge

OUT.mkdir(parents=True,exist_ok=True)
write('last_signal',20,music,True,True)
write('quarantine_wind',12,lambda t,r:(r.uniform(-1,1)*.035+tone(t,55)*.015+tone(t,110)*.009)*(0.8+.2*tone(t,1/12))*min(1,t/.2,(12-t)/.2),True,True)
write('rifle',.55,lambda t,r: tick(t,r,21)*.65+tone(t,73)*math.exp(-t*17)*.27+tick(max(0,t-.035),r,80)*(.1 if t>.035 else 0))
write('pistol',.38,lambda t,r:tick(t,r,30)*.66+tone(t,128)*math.exp(-t*23)*.24)
write('reload',.85,lambda t,r:sum(tick(t-d,r,75)*a if t>=d else 0 for d,a in [(0,.25),(.23,.20),(.57,.32),(.69,.24)]))
write('dry',.09,lambda t,r:tick(t,r,100)*.20+tone(t,1350)*math.exp(-t*100)*.10)
write('melee',.30,lambda t,r:r.uniform(-1,1)*math.sin(math.pi*t/.3)**2*.28)
write('impact',.24,lambda t,r:tick(t,r,30)*.32+tone(t,96)*math.exp(-t*24)*.22)
write('footstep',.17,lambda t,r:tick(t,r,42)*.20+tone(t,75)*math.exp(-t*35)*.12)
write('zombie_growl',1.3,lambda t,r:((tone(t,67+5*math.sin(t*5))+.33*tone(t,134)+r.uniform(-1,1)*.2)*.17)*min(1,t*8,(1.3-t)*4))
write('zombie_attack',.55,lambda t,r:(tone(t,86)+.3*tone(t,172)+r.uniform(-1,1)*.3)*math.sin(math.pi*t/.55)*.24)
write('zombie_death',.8,lambda t,r:(tone(t,88-20*t)+r.uniform(-1,1)*.2)*math.exp(-t*3)*min(1,t*40)*.25)
for name,hz in [('ui_click',880),('ui_confirm',1174.66),('ui_error',220)]:
    write(name,.16,lambda t,r,hz=hz:(tone(t,hz)+.2*tone(t,hz*1.5))*math.exp(-t*25)*min(1,t*1000)*.13)
print('Original audio bank generated: 15 cues/loops')
