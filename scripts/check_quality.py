#!/usr/bin/env python3
"""Re-run structural, frame, continuity and geometry gates on existing artwork."""
from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
import sys
from pathlib import Path
from PIL import Image

STATES = [('idle',6),('running-right',8),('running-left',8),('waving',4),('jumping',5),('failed',8),('waiting',6),('running',6),('review',6)]

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output-dir', required=True)
    args = parser.parse_args()
    repo = Path(__file__).resolve().parents[1]
    output = Path(args.output_dir).resolve()
    output.mkdir(parents=True,exist_ok=True)
    atlas = repo / 'spritesheet.webp'
    checks = repo / 'scripts' / 'qa'
    def run(name,*params):
        return subprocess.run([sys.executable,str(checks/name),*map(str,params)],check=False).returncode
    atlas_report = output/'atlas-validation.json'
    if run('validate_atlas.py',atlas,'--require-v2','--json-out',atlas_report):
        raise SystemExit('FAIL: strict atlas validation')
    encoded_report = json.loads(atlas_report.read_text(encoding='utf8'))
    # This inspects already approved artwork. It does not claim that a new
    # creation/despill stage ran, nor repaint the cloud-synchronized pixels.
    chroma_report = {
        'ok': encoded_report['ok'] and not any(c['opaque_chroma_key_pixels'] or c['chroma_fringe_pixels'] for c in encoded_report['cells']),
        'stage':'existing-artwork-chroma-inspection',
        'sha256':encoded_report['sha256'],
        'opaque_chroma_key_pixels':sum(c['opaque_chroma_key_pixels'] for c in encoded_report['cells']),
        'chroma_fringe_pixels':sum(c['chroma_fringe_pixels'] for c in encoded_report['cells']),
        'transparent_rgb_residue_pixels':encoded_report['transparent_rgb_residue_pixels'],
        'artwork_modified':False,
    }
    chroma_path=output/'chroma-inspection.json'
    chroma_path.write_text(json.dumps(chroma_report,indent=2)+'\n',encoding='utf8')
    with Image.open(atlas) as opened:
        image=opened.convert('RGBA')
    frames=output/'frames'
    for row,(state,count) in enumerate(STATES):
        folder=frames/state
        folder.mkdir(parents=True,exist_ok=True)
        for column in range(count):
            image.crop((column*192,row*208,(column+1)*192,(row+1)*208)).save(folder/f'{column:02d}.png')
    frame_review=output/'standard-frame-review.json'
    continuity=output/'look-continuity.json'
    if run('inspect_frames.py','--frames-root',frames,'--json-out',frame_review):
        raise SystemExit('FAIL: standard frame validation')
    if run('measure_direction_continuity.py',atlas,'--json-out',continuity):
        raise SystemExit('FAIL: continuity measurement')
    semantic_path=repo/'qa'/'direction-semantics.json'
    semantics=json.loads(semantic_path.read_text(encoding='utf8'))
    if semantics.get('atlas_sha256')!=hashlib.sha256(atlas.read_bytes()).hexdigest():
        raise SystemExit('FAIL: visual direction evidence belongs to different encoded artwork')
    blind=json.loads((repo/'qa'/'blind-direction-validation.json').read_text(encoding='utf8'))
    if blind.get('atlas_sha256')!=encoded_report['sha256'] or blind.get('ok') is not True or blind.get('errors') or blind.get('unconfirmed'):
        raise SystemExit('FAIL: independent cardinal direction evidence is missing or non-passing')
    cleanup=repo/'qa'/'chroma-despill.json'
    cleanup_report=json.loads(cleanup.read_text(encoding='utf8'))
    if cleanup_report.get('output_sha256')!=encoded_report['sha256']:
        raise SystemExit('FAIL: chroma cleanup evidence belongs to different encoded artwork')
    quality=output/'pet-quality.json'
    if run('validate_pet_quality.py',atlas,'--atlas-validation',atlas_report,'--chroma-report',cleanup,'--frame-review',frame_review,'--direction-semantics',semantic_path,'--continuity',continuity,'--json-out',quality):
        raise SystemExit('FAIL: pet quality gate')
    print('PASS: strict atlas, all 57 standard frames, chroma inspection, look geometry and recorded direction semantics')

if __name__=='__main__':
    main()
