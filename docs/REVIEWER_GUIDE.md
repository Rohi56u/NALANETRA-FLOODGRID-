# Five-minute reviewer path

[Start the service](SETUP.md) and open `http://127.0.0.1:8000` in three tabs or isolated profiles. Each console tab has its own in-memory session; automation uses separate contexts. Use the fixture accounts in the README.

| Step | Action | Evidence to inspect |
|---|---|---|
| Citizen intake | Upload a photo, depth tag and coordinates | Canonical receipt, protected capture and labelled score sources |
| Officer review | Inspect the photo; confirm depth/context | Verification gate, explained contributions, actor/time |
| Dispatch | Select the issued free crew | Same shared mission; duplicate active assignment is blocked |
| Crew proof | Use labelled local GPS fixture; upload distinct before/after plus note | Mission/capture checks and `AWAITING_REVIEW` |
| Officer closure | Compare both images and approve with note | Shared closed state, proof digests and role-scoped updates |

The fixture capture mode is local-only. Physical Flutter exercises require actual camera/GPS and a visitable test site; label the exercise appropriately.

Inspect [priority arithmetic](../backend/priority_engine.py), [workflow gates](../backend/main.py), [database](../backend/database.py), [drainage experiment](../intelligence/forecast.py), [OSRM screening](../routing/osrm_engine.py) and [failure-path tests](../tests/test_workflow.py).

The [console screenshot](assets/review_console.png) is from an actual service run. The [experiment chart](assets/risk_experiment.png) and [CSV](../data/demo/model_results.csv) are calculated synthetic results. [Validation](VALIDATION.md) and [primary references](../research/CITATIONS.md) distinguish implementation from field validation.

The [submitted PDF](slides/PS26085_FLOOD_BUSTERS.pdf) is unchanged. `python -m scripts.verify_presentation` checks the PDF, six slides and presentation architecture image.
