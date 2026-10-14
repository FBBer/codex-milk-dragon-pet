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
LOOK_LABELS = ('000', '022.5', '045', '067.5', '090', '112.5', '135', '157.5',
               '180', '202.5', '225', '247.5', '270', '292.5', '315', '337.5')
CARDINALS = {'000', '090', '180', '270'}


def validate_direction_evidence(semantics, blind, atlas_hash):
    """Fail closed on incomplete or contradictory recorded visual evidence."""
    def require(condition, message):
        if not condition:
            raise ValueError(message)

    require(isinstance(semantics, dict) and semantics.get('atlas_sha256') == atlas_hash,
            'visual direction evidence belongs to different encoded artwork')
    directions = semantics.get('directions')
    require(isinstance(directions, list) and len(directions) == 16,
            'all 16 labeled semantic reviews are required')
    require(all(isinstance(item, dict) for item in directions), 'invalid semantic review')
    require({item.get('label') for item in directions} == set(LOOK_LABELS),
            'semantic reviews must contain each look direction exactly once')
    for item in directions:
        label = item['label']
        index = LOOK_LABELS.index(label)
        expected = ('up' if index == 0 else 'up-right' if index < 4 else
                    'right' if index == 4 else 'down-right' if index < 8 else
                    'down' if index == 8 else 'down-left' if index < 12 else
                    'left' if index == 12 else 'up-left')
        require(item.get('expected') == expected, f'incorrect expected direction: {label}')
        require(item.get('verdict') in ('pass', 'warning'), f'non-passing semantic review: {label}')
        require(label not in CARDINALS or item['verdict'] == 'pass',
                f'cardinal direction must pass: {label}')
        require(all(isinstance(item.get(field), str) and item[field].strip()
                    for field in ('observed', 'evidence')), f'missing visual evidence: {label}')

    require(isinstance(blind, dict) and blind.get('atlas_sha256') == atlas_hash,
            'blind direction evidence belongs to different encoded artwork')
    require(blind.get('ok') is True and blind.get('errors') == [] and blind.get('unconfirmed') == [],
            'independent direction evidence is missing or non-passing')
    pairs = blind.get('pairs')
    require(isinstance(pairs, list) and len(pairs) == 14, 'all 14 blind comparison pairs are required')
    require(all(isinstance(pair, dict) for pair in pairs), 'invalid blind pair')
    names = {f'{axis}-{number}' for axis in ('horizontal', 'vertical') for number in range(1, 8)}
    require({pair.get('pair') for pair in pairs} == names, 'blind pairs are missing or duplicated')
    seen = {'horizontal': set(), 'vertical': set()}
    warnings = []
    for pair in pairs:
        name = pair['pair']
        axis = name.split('-')[0]
        require(pair.get('axis') == axis, f'incorrect blind pair axis: {name}')
        hard = name in ('horizontal-4', 'vertical-1')
        require(pair.get('gate') == ('hard' if hard else 'review'), f'incorrect blind gate: {name}')
        for side in ('A', 'B'):
            item = pair.get(side)
            require(isinstance(item, dict), f'missing blind observation: {name} {side}')
            label = item.get('source_direction')
            require(label in LOOK_LABELS and label not in seen[axis],
                    f'missing or duplicated blind direction: {name} {side}')
            index = LOOK_LABELS.index(label)
            if axis == 'horizontal':
                require(index not in (0, 8), f'invalid horizontal comparison: {label}')
                expected = 'screen-right' if index < 8 else 'screen-left'
            else:
                require(index not in (4, 12), f'invalid vertical comparison: {label}')
                expected = 'up' if index < 4 or index > 12 else 'down'
            require(item.get('expected') == expected, f'incorrect blind expected direction: {label}')
            require((label in CARDINALS) == hard, f'cardinal evidence must use a hard gate: {label}')
            observed = item.get('observed')
            require(observed in (expected, 'ambiguous'), f'wrong blind observation: {label}')
            require(item.get('pass') is (observed == expected), f'contradictory blind verdict: {label}')
            require(not hard or item['pass'] is True, f'non-passing cardinal blind evidence: {label}')
            if observed == 'ambiguous':
                warnings.append(f'{name} {side} {axis} axis is ambiguous')
            seen[axis].add(label)
    require(seen['horizontal'] == set(LOOK_LABELS) - {'000', '180'} and
            seen['vertical'] == set(LOOK_LABELS) - {'090', '270'}, 'blind axis coverage is incomplete')
    require(isinstance(blind.get('warnings'), list) and sorted(blind['warnings']) == sorted(warnings),
            'blind warnings do not match the recorded observations')
    require(blind.get('reviewRequired') is bool(warnings), 'blind review status is inconsistent')

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
    blind=json.loads((repo/'qa'/'blind-direction-validation.json').read_text(encoding='utf8'))
    try:
        validate_direction_evidence(semantics, blind, hashlib.sha256(atlas.read_bytes()).hexdigest())
    except ValueError as error:
        raise SystemExit(f'FAIL: {error}') from error
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
