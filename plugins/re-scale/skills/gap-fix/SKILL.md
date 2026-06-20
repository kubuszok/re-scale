---
description: Fix enforcement failures in a ported Scala file — resolve shortcuts, port missing methods, then stamp a covenant
---

Fix all enforcement failures in `$ARGUMENTS`, then stamp a covenant.

## Procedure

1. Run `re-scale enforce shortcuts --file <path>` — note all hits
2. Run `re-scale enforce compare --port <path> --source <ref> --strict` — note gaps
3. Read both files (Scala port + original source) with the Read tool
4. For each shortcut hit, apply the triage action:
   - `todo`/`fixme`: port the missing logic from source
   - `for-now-comment`/`simplified-comment`: remove or reword if the work is done
   - `null-cast`: replace with `Nullable[A]` pattern
   - `scala-unimpl`/`not-implemented`: implement from source
   - `flag-break-var`: rewrite with `boundary`/`break`
5. For each missing method: port from source reference
6. For each short body: fill in from source reference
7. Verify:
   ```
   re-scale enforce shortcuts --file <path>           # must be 0 hits
   re-scale enforce compare --port <path> --source <ref> --strict  # no missing, no short-body
   ```
8. Compile: `re-scale build compile --module <mod> --all`
9. Test: `re-scale test unit --module <mod>`
10. Stamp: `re-scale enforce covenant-apply --file <path> --source <ref>`
11. Commit with: `<module>: gap-fix <file> — N shortcuts resolved, M methods ported`

## Original invention exemption

If the file is OUR ORIGINAL INVENTION (not a port of any upstream source), it
has no gaps to fix and no covenant to stamp. Add `Covenant-type: original-invention`
to its header block comment instead — that marker makes `enforce verify`,
`shortcuts`, and `stale-stubs` all PASS the file unconditionally, with no
baseline methods or `covenant-apply` step required. Only do this for genuinely
original code, never to silence enforcement on a real port.

## Important

**Do NOT access .rescale/data/ files directly.** Use `re-scale db` commands.
**Do NOT use shell commands for search/read.** Use Grep, Glob, Read, Edit tools.
