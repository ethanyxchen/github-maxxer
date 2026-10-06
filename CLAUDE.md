# Launching the app

When launching Hammertime for testing, build it with `./scripts/build-app.sh` and always launch it in the background with `open -g -j build/Hammertime.app --args --no-activate` so it never takes focus from other windows. `--no-activate` stops the app from bringing itself to the foreground at launch. Never run the executable inside the bundle directly, and never launch it through Xcode's Run; both bring the app to the foreground.

The one exception is `./scripts/replay-slam.sh`, which replays the merge celebration for someone to watch. It brings Hammertime to the foreground so the slam plays in the window; a merge that lands while Hammertime is in the background slams a floating card instead. Run it only when the user asks to see the celebration.

# Compiler warnings

The build must stay free of compiler warnings. The pre-commit hook in `.githooks/pre-commit` compiles with warnings treated as errors and blocks the commit when any appear; enable it once per clone with `git config core.hooksPath .githooks`. Whenever a build, `./scripts/build-app.sh`, or the hook reports a warning, fix its cause in the code right away, even when the warning is in code you did not touch. Never silence a warning, suppress a diagnostic, or bypass the hook with `--no-verify`.
