# USER-23: Paperless-ngx -- the document archive

As a household member, I want scanned documents archived,
OCR'd, and searchable, so that any paper document I keep is one
search away.

**Status**: planned (hardware-gated: the operator is buying a
scanner)
**Arc**: v3 (after the scanner arrives; personal-content family)

## Workflow

Paper arrives; scan it; paperless-ngx OCRs, tags, and files it;
find anything by content search. Receipts, mail, manuals, tax
documents.

## Acceptance criteria

- [ ] Scanner produces into the consume directory (watched
      folder or email-in per scanner capability)
- [ ] Manifest + role; documents on truenas; consumption flow
      proven with real scans
- [ ] Search finds a scanned document by its content

## Lenses

- Security: documents are private data -- tailnet-only front;
  dataset rides B2 snapshots.
- Reliability: the archive is tier-0-adjacent (documents are not
  re-fetchable) -- B2 coverage confirmed in the story's Phase 0.
