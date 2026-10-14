# Validator provenance

The following validators were copied without modification from the installed
OpenAI Work Pets plugin, version `0.1.6`, for reproducible quality checks:

- `validate_atlas.py`
- `inspect_frames.py`
- `measure_direction_continuity.py`
- `validate_pet_quality.py`

They are not original FBBer code and are not covered by this repository's
`LICENSE-CODE.md`. The installed plugin copy did not include a standalone
license or notice for these scripts. This file records their origin; it does
not grant additional redistribution or other rights. Applicable upstream
terms remain separate from the license for the original project code.

The original runner, `../check_quality.py`, invokes these validators using
their default quality thresholds. A passing report is bound to the encoded
`spritesheet.webp` SHA-256 and does not assert that all reviewed warnings are
absent.
