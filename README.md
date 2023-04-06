# yourgoal

Swift implementation of [BabyAGI](https://github.com/yoheinakajima/babyagi)

- [x] Hooked to OpenAI
- [x] Basic task creation
- [x] Creating embeddings
- [ ] Saving to Pinecone

### Notes

* Don't be stupid

### Developer Commands

`export $(grep -v '^#' .env | xargs)` Parse environment variables

`swift build` Builds app to the `.build` folder

`swift build -c release` Build a release version

`./.build/debug/yourgoal` Runs app after building

`swift run yourgoal` Runs app directly
