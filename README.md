# yourgoal

Testing to see if LLMs can create executable code, and how much human intervention is actually needed.

### Notes

* Quick and simple, didn't spend a ton of time on architecture
* Don't be stupid, if you tell it to do destructive/dangerous stuff it will

### Developer Commands

`export $(grep -v '^#' .env | xargs)` Parse environment variables

`swift build` Builds app to the `.build` folder

`swift build -c release` Build a release version

`./.build/debug/yourgoal` Runs app after building

`swift run yourgoal` Runs app directly
