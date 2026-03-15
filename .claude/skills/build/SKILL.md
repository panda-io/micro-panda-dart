---
name: build
description: Full build pipeline for micro-panda-dart. Runs Dart unit tests, rebuilds the mpd binary via install.sh, then runs all mpd integration tests.
disable-model-invocation: true
---

Run the full micro-panda build pipeline in three steps. Use the repo root `/Users/sang/Dev/panda-io/micro-panda-dart` as the working directory.

## Step 1 — Dart unit tests

```bash
cd /Users/sang/Dev/panda-io/micro-panda-dart && dart test
```

Report how many tests passed/failed. If any fail, show the failures and stop — do not proceed to step 2.

## Step 2 — Rebuild mpd binary

```bash
cd /Users/sang/Dev/panda-io/micro-panda-dart && ./install.sh
```

Report success or failure. If it fails, show the error and stop.

## Step 3 — mpd integration tests

```bash
cd /Users/sang/Dev/panda-io/micro-panda-dart/micro-panda/std && mpd test
```

Report how many tests passed/failed. Show any failures.

## Summary

After all three steps, print a one-line summary:
`✓ dart test (N) | ✓ install.sh | ✓ mpd test (N)` — substituting actual counts and ✓/✗ per step.
