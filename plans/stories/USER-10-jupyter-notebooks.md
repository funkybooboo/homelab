# USER-10: jupyter

As the operator, I want my jupyter notebook server back -- the
notebooks from the old fleet extracted and served -- so that the
analysis work continues where it stopped.

**Status**: planned (operator-confirmed keep, 2026-11-23)
**Arc**: v3

## Acceptance criteria

- [ ] Notebooks extracted: locate `*.ipynb` under the Nov-21
      vzdump of old CT 118 (the old paths were "to locate" --
      `/root/` or a `/home/*/` notebooks dir; prove them at
      extract time, not from the table)
- [ ] Manifest + role: jupyter (lab) pinned, notebooks dir
      restored only-while-absent
- [ ] Operator opens the notebook list; an old notebook runs its
      cells; serve front live

## Notes

This is the one old-fleet service whose DATA PATH was never
proven ("to locate" in the archive notes) -- the extraction
step is exploratory: walk the dump's home dirs for *.ipynb before
writing the role. Notebooks are small; the CT is tiny.
