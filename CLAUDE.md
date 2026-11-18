# re-scale

Scala Native porting toolkit — enforcement gates, migration tracking, and conversion guides.

## Build

sbt 2.1 with sbt-kubuszok. One projectMatrix, `cli/`, with a JVM row (`cli`) and a Scala Native row (`cliNative`).

```bash
sbt --client ci-jvm-3       # clean, compile, test (+ coverage), doc on the JVM
sbt --client ci-native-3    # the same on Scala Native, after staging the executable
sbt --client install        # link the executable to .build/re-scale-bin
sbt --client stage          # link it to target/stage/bin (the memory-bound specs spawn it)
```

The `bin/re-scale` wrapper locates `.build/re-scale-bin` at runtime. The 1G heap cap is compiled into the
executable (`GC_MAXIMUM_HEAP_SIZE` overrides it; Scala Native 0.5 ignores `SCALANATIVE_MAX_HEAP_SIZE`).

The version comes from git tags (`git describe`); there is no version in the build or the sources. In a linked
`git worktree`, sbt-git cannot read the repository and the version becomes a timestamp, which fails `VersionSpec`:
run the tests from a regular clone when that matters.

This repository holds only the CLI. The agent plugins (`re-scale-hooks`, `re-scale-porting`) live in
`kubuszok/agent-skills`; their session-start hook pins the CLI version.

## Release checklist

1. Merge to master and wait for the snapshot publish of that push (`Sonatype Release`) to succeed.
2. Tag the master commit with the bare version and push the tag: `git tag 0.2.0 && git push origin 0.2.0`.
   The tag run links the four executables, attaches them to `re-scale_native0.5_3` and releases to Maven Central.
3. Once the release is on Central (allow ~30 minutes after the tag run), bump `RESCALE_VERSION` in both
   plugins' `hooks/session-start.sh` in `kubuszok/agent-skills`, with the plugins' versions.
