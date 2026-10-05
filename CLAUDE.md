# Launching the app

When launching Hammertime for testing, build it with `./scripts/build-app.sh` and always launch it in the background with `open -g -j build/Hammertime.app` so it never takes focus from other windows. Never launch it through Xcode's Run, which always brings the app to the foreground.
