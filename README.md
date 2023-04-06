# yourgoal

Swift implementation of [BabyAGI](https://github.com/yoheinakajima/babyagi)

### Notes

* Don't be stupid
* Look in the .env.example for how to input keys
* No color output yet

### Backstory

I had written some previous code prior to BabyAGI that just iterated on writing and executing code in a loop. Was kinda boring though, and I realized I had most of the pieces in place to port BabyAGI to Swift, so I decided to give it a shot. Also gave me a chance to learn about [Pinecone.io](https://www.pinecone.io). All the credit due is to [yoheinakajima](https://github.com/yoheinakajima), I just ported and iterated a bit. Might keep going with it though, who knows.

### Developer Commands

`export $(grep -v '^#' .env | xargs)` Parse environment variables

`swift build` Builds app to the `.build` folder

`swift build -c release` Build a release version

`./.build/debug/yourgoal` Runs app after building

`swift run yourgoal` Runs app directly
