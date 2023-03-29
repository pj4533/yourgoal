# yourgoal

Command line app to accomplish simple tasks using AI

### Notes

* Mac only
* Command line only

### Developer Commands

`export $(grep -v '^#' .env | xargs)` Parse environment variables

`swift build` Builds app to the `.build` folder

`swift build -c release` Build a release version

`./.build/debug/yourgoal` Runs app after building

`swift run yourgoal` Runs app directly
