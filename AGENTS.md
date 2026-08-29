# Offer-logic maintenance rule

Before changing offer capture, parser routing or rules, OCR, cross-app behavior,
verdict scoring, overlay verdict delivery, deduplication, or outcome inference,
read `docs/OFFER_DETECTION.md` and verify the proposed behavior against it.

If the implementation changes, update that document in the same change. Do not
prepare a release while the implementation and document disagree.
