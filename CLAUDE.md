# Launching the app

When launching Hammertime for testing, build it with `./scripts/build-app.sh` and always launch it in the background with `open -g -j build/Hammertime.app --args --no-activate` so it never takes focus from other windows. `--no-activate` stops the app from bringing itself to the foreground at launch. Never run the executable inside the bundle directly, and never launch it through Xcode's Run; both bring the app to the foreground.

The one exception is `./scripts/replay-slam.sh`, which replays the merge celebration for someone to watch. It brings Hammertime to the foreground so the slam plays in the window; a merge that lands while Hammertime is in the background slams a floating card instead. Run it only when the user asks to see the celebration.
