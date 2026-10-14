"""Regress the unused-cell and stationary-jump defects using real encoded art."""
import importlib.util
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('pet_quality',ROOT/'scripts/qa/validate_pet_quality.py')
quality=importlib.util.module_from_spec(spec)
spec.loader.exec_module(quality)

class QualityRegression(unittest.TestCase):
    def setUp(self):
        self.image=Image.open(ROOT/'spritesheet.webp').convert('RGBA')

    def test_current_jump_leaves_ground_and_lands(self):
        errors=[]
        result=quality.inspect_jump(self.image,8,12,errors)
        self.assertEqual(errors,[])
        self.assertGreaterEqual(result['airborne_lift_pixels'],8)
        self.assertEqual(result['landing_delta_pixels'],0)

    def test_stationary_jump_is_rejected(self):
        image=self.image.copy()
        neutral=image.crop((0,0,192,208))
        for column in range(5):
            image.paste(neutral,(column*192,4*208))
        errors=[]
        result=quality.inspect_jump(image,8,12,errors)
        self.assertEqual(result['airborne_lift_pixels'],0)
        self.assertTrue(any('never visibly leaves the ground' in e for e in errors))

    def test_artwork_in_unused_idle_cell_is_rejected(self):
        image=self.image.copy()
        image.paste(image.crop((0,0,192,208)),(6*192,0))
        with tempfile.TemporaryDirectory(prefix='milk-dragon-quality-regression-') as scratch:
            atlas=Path(scratch)/'invalid.png'
            image.save(atlas)
            result=subprocess.run([sys.executable,str(ROOT/'scripts/qa/validate_atlas.py'),str(atlas),'--require-v2'],capture_output=True,text=True)
        self.assertNotEqual(result.returncode,0)
        self.assertIn('unused column 6 is not transparent',result.stdout)

if __name__=='__main__':
    unittest.main()
