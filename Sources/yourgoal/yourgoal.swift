import Foundation
import ArgumentParser
import AsyncHTTPClient
import OpenAIKit

var openAIClient: OpenAIKit.Client?

@main
struct YourGoal: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
    	commandName: "yourgoal",
        abstract: "Doing. Stuff."
    )

    @Argument(help: "Your goal, in quotes")
    var yourgoal: String

    var apiKey: String {
        ProcessInfo.processInfo.environment["OPENAI_API_KEY"]!
    }

    var organization: String {
        ProcessInfo.processInfo.environment["OPENAI_ORGANIZATION"]!
    }

    var saving: Bool = false
    var savefilename: String = ""
    var runfilename: String = ""
    var messages: [OpenAIKit.Chat.Message] = [
        .system(content: "You are a coding assistant that only knows three commands: SAVE THIS, RUN THIS and DONE. You will be given a goal. Use your three commands to accomplish the goal. The command SAVE THIS should be followed by the name of a file to save and the codeblock to save into the file. The name of the file to save should always be 'output.swift' with no quotes. The command RUN THIS should be followed by the name of the file to run. I will tell you the output of the file when you tell me to run a file. You are not to tell me the output of running the file, wait for me to respond with the output of the file. The output of running the file will determine if you reached your goal. When you reach that goal, respond with the command DONE. Only respond with the command DONE if you have validated the running of the file accomplished the goal, by having me respond with the correct output. Limit commentary, only include the commands you know, SAVE THIS, RUN THIS or DONE. No other commentary, help, congratulations or any other form of commentary.")
    ]

    mutating func runfile() async {
        print("DEBUG: Running \(runfilename)")
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
        task.arguments = [runfilename]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                print("DEBUG: LOCAL OUTPUT\n\n\"\(output.trimmingCharacters(in: .whitespacesAndNewlines))\"\n")
                if output.trimmingCharacters(in: .whitespacesAndNewlines) == "" {
                    messages.append(.user(content: "There was no output from running the file."))
                } else {
                    messages.append(.user(content: output.trimmingCharacters(in: .whitespacesAndNewlines)))
                }
                await callCompletion()
            } else {
                print("DEBUG: NO LOCAL OUTPUT")
            }
        } catch {
            print("DEBUG: Error running \(runfilename)")
        }
    }

    func save(line: String) {        
        print("DEBUG: Saving \(line.trimmingCharacters(in: .whitespacesAndNewlines))")
        let fileManager = FileManager.default
        let currentDirectory = fileManager.currentDirectoryPath
        let path = "\(currentDirectory)/\(savefilename)"
        // Check if the file exists
        if FileManager.default.fileExists(atPath: path) {
            // If the file exists, open it in append mode
            if let fileHandle = FileHandle(forWritingAtPath: path) {
                // Move file cursor to the end of the file
                fileHandle.seekToEndOfFile()

                // Convert the text to data
                let data = line.data(using: .utf8)!
                
                // Write the data to the file
                fileHandle.write(data)
                
                // Close the file handle
                fileHandle.closeFile()            
            } else {
                print("Error opening file")
            }
        } else {
            // If the file doesn't exist yet, create it and
            // write the text to it
            do {
                try line.write(toFile: path, atomically: true, encoding: .utf8)
            } catch {
                print("Error writing to file: ", error)
            }
        }
    }

    mutating func parse(line: String) async {
        if line.starts(with: "SAVE THIS") {
            savefilename = "output.swift" //String(line.dropFirst(10)).replacingOccurrences(of: "\"", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            print("DEBUG: Saving to '\(savefilename)'")
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: savefilename) {
                print("DEBUG: File exists, removing...")
                do {
                    try fileManager.removeItem(at: URL(fileURLWithPath: savefilename))
                    print("DEBUG: File removed successfully")
                } catch {
                    print("DEBUG: Error removing file: \(error)")
                }
            }            
        } else if (line == "```") || (line == "```swift") || (line == "```Swift") {
            if saving {
                saving = false
                print("DEBUG: Done saving to \(savefilename)")
            } else {
                saving = true
            }
        } else if line.starts(with: "RUN THIS") {
            runfilename = savefilename
            // runfilename = String(line.dropFirst(9)).replacingOccurrences(of: "\"", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            print("DEBUG: Running \(runfilename)")
            await runfile()
        } else if line == "DONE" {
            print("DEBUG: Done")
        } else if saving {
            save(line: "\(line)\n")
        } else {
            print("ERROR: UNKNOWN LINE - \(line)")
        }
    }

    mutating func callCompletion() async {
        print("DEBUG: Calling completion")
        do {
            let completion = try await openAIClient?.chats.create(
                model: Model.GPT3.gpt3_5Turbo,
                messages: messages
            )
            print("DEBUG: Got completion")
            switch completion?.choices.first?.message {
            case .assistant(let content):
                messages.append(.assistant(content: content))
                for line in content.split(separator: "\n") {
                    await parse(line: String(line))
                }
            case .user(let content):
                print("User: \(content)")
            case .system(let content):
                print("System: \(content)")
            case .none:
                print("No response")
            }
        } catch let error {
            print(error)
        }
    }

	mutating func run() async throws {
        let httpClient = HTTPClient(eventLoopGroupProvider: .createNew)
        defer {
            // it's important to shutdown the httpClient after all requests are done, even if one failed. See: https://github.com/swift-server/async-http-client
            try? httpClient.syncShutdown()
        }
        let configuration = Configuration(apiKey: apiKey, organization: organization)

        openAIClient = OpenAIKit.Client(httpClient: httpClient, configuration: configuration)
        messages.append(.user(content: "Your goal is to run a command line application to \(yourgoal) using the language Swift."))

        await callCompletion()
    }
}
