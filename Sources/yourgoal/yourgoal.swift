import Foundation
import ArgumentParser
import AsyncHTTPClient
import OpenAIKit

var openAIClient: OpenAIKit.Client?

struct VectorMetadata: Codable {
    var taskName: String
    var result: String
}

struct Vector: Codable {
    var id: String
    var values: [Float]
    var metadata: VectorMetadata
}

struct Task: Codable {
    var id: String
    var name: String
}

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
    
    var pineconeAPIKey: String {
        ProcessInfo.processInfo.environment["PINECONE_API_KEY"]!
    }
    
    var pineconeBaseURL: String {
        ProcessInfo.processInfo.environment["PINECONE_BASE_URL"]!
    }

    var taskList: [Task] = []
    
    // I know, I know, I'm going to refactor this. Geeze, relax.
    func upsert(vector: Vector) async {
        struct PineconeUpsert: Codable {
            var vectors: [Vector]
        }
        
        struct ResponseData: Codable {
            let result: String
        }
        
        let upsert = PineconeUpsert(vectors: [vector])
        do {
            if let url = URL(string: "https://\(pineconeBaseURL)/vectors/upsert") {
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue("application/json", forHTTPHeaderField: "accept")
                request.setValue(pineconeAPIKey, forHTTPHeaderField: "Api-Key")

                let encoder = JSONEncoder()
                let jsonData = try encoder.encode(upsert)
                request.httpBody = jsonData
                
                let (_, _) = try await URLSession.shared.data(for: request)
            }
        } catch let error {
            print("ERROR: \(error)")
        }
    }

    // this too, i know.
    func getContext(withQuery query: String) async -> [String] {
        let queryEmbedding = await getADAEmbedding(withText: query)
        
        struct PineconeQuery: Codable {
            var vector: [Float]
            var includeMetadata: Bool
            var topK: Int
        }
        
        struct PineconeMatch: Codable {
            var id: String
            var score: Float
            var metadata: VectorMetadata
        }
        
        struct ResponseData: Codable {
            let matches: [PineconeMatch]
        }
        
        let query = PineconeQuery(vector: queryEmbedding, includeMetadata: true, topK: 5)
        do {
            if let url = URL(string: "https://\(pineconeBaseURL)/query") {
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue("application/json", forHTTPHeaderField: "accept")
                request.setValue(pineconeAPIKey, forHTTPHeaderField: "Api-Key")

                let encoder = JSONEncoder()
                let jsonData = try encoder.encode(query)
                request.httpBody = jsonData
                
                let (data, _) = try await URLSession.shared.data(for: request)
                
                let decoder = JSONDecoder()
                let responseData = try decoder.decode(ResponseData.self, from: data)
                let sortedMatches = responseData.matches.sorted { match1, match2 in
                    return match1.score > match2.score
                }
                return sortedMatches.map { $0.metadata.taskName }
            }
        } catch let error {
            print("ERROR: \(error)")
        }
        return []
    }

    func getADAEmbedding(withText text: String) async -> [Float] {
        let singleLineText = text.replacingOccurrences(of: "\n", with: " ")
        do {
            let response = try await openAIClient?.embeddings.create(input: singleLineText)
            return response?.data.first?.embedding ?? []
        } catch let error {
            print(error)
        }
        return []
    }
    
    func prioritizeTasks() async -> [Task] {
        let messages: [OpenAIKit.Chat.Message] = [
            .system(content: "You are an task prioritization AI tasked with cleaning the formatting and reprioritizing tasks. Consider the ultimate objective of your team: \(yourgoal). Do not remove any tasks. Return the result as an ordered bulleted list using a '* ' at the beginning of each line."),
            .user(content: "Clean, format and reprioritize these tasks: \(taskList.map({$0.name}).joined(separator: ", ")).")
        ]
        var prioritizedTasks: [Task] = []
        do {
            let completion = try await openAIClient?.chats.create(
                model: Model.GPT3.gpt3_5Turbo,
                messages: messages,
                temperature: 0.5,
                maxTokens: 100
            )
            switch completion?.choices.first?.message {
            case .assistant(let content):
                let lines = content.split(separator: "\n")
                for line in lines {
                    let taskComponents = line.components(separatedBy: "* ")
                    if let taskName = taskComponents.last {
                        let newTask = Task(id: UUID().uuidString, name: String(taskName))
                        prioritizedTasks.append(newTask)
                    }
                }
            case .user(let content):
                print("ERROR: got user response: \(content)")
            case .system(let content):
                print("ERROR: got system response: \(content)")
            case .none:
                print("ERROR: got no response")
            }
        } catch let error {
            print(error)
        }
        return prioritizedTasks
    }
    
    mutating func createNewTasks(withPreviousTask previousTask: Task, previousResult: String) async -> [Task] {
        // Tweaked these prompts to make it more easily parsable
        let messages: [OpenAIKit.Chat.Message] = [
            .system(content: "You are an task creation AI that uses the result of an execution agent to create new tasks with the following objective: \(yourgoal), The last completed task has the result: \(previousResult). This result was based on this task description: \(previousTask.name). These are incomplete tasks: \(taskList.map({$0.name}).joined(separator: ", "))."),
            .user(content: "Based on the previous result, create new tasks to be completed by the AI system that do not overlap with incomplete tasks. Each line containing a task should start with '-- '")
        ]
        var newTasks: [Task] = []
        do {
            let completion = try await openAIClient?.chats.create(
                model: Model.GPT3.gpt3_5Turbo,
                messages: messages,
                temperature: 0.5,
                maxTokens: 100
            )
            switch completion?.choices.first?.message {
            case .assistant(let content):
                let newTaskStrings = content.split(separator: "\n")
                for taskString in newTaskStrings {
                    if taskString.hasPrefix("-- ") {
                        if let newTaskString = taskString.components(separatedBy: "-- ").last {
                            let newTask = Task(id: UUID().uuidString, name: String(newTaskString))
                            newTasks.append(newTask)
                        }
                    }
                }
            case .user(let content):
                print("ERROR: got user response: \(content)")
            case .system(let content):
                print("ERROR: got system response: \(content)")
            case .none:
                print("ERROR: got no response")
            }
        } catch let error {
            print(error)
        }
        return newTasks
    }
        
    func execute(task: Task, withContext context: String) async -> String {
        let context = await getContext(withQuery: yourgoal).joined(separator: ", ")
        let messages: [OpenAIKit.Chat.Message] = [
            .system(content: "You are an AI who performs one task based on the following objective: \(yourgoal).\nTake into account these previously completed tasks: \(context)"),
            .user(content: "Your task: \(task.name)")
        ]
        var contentResponse = ""
        do {
            let completion = try await openAIClient?.chats.create(
                model: Model.GPT3.gpt3_5Turbo,
                messages: messages,
                temperature: 0.7,
                maxTokens: 2000
            )
            switch completion?.choices.first?.message {
            case .assistant(let content):
                contentResponse = content
            case .user(let content):
                contentResponse = content
            case .system(let content):
                contentResponse = content
            case .none:
                contentResponse = ""
            }
        } catch let error {
            print(error)
        }
        return contentResponse
    }
    
	mutating func run() async throws {
        print("\u{001B}[96m\u{001B}[1m\n*****OBJECTIVE*****\n\u{001B}[0m\u{001B}[0m")
        print("\(yourgoal)")

        let httpClient = HTTPClient(eventLoopGroupProvider: .createNew)
        defer {
            // it's important to shutdown the httpClient after all requests are done, even if one failed. See: https://github.com/swift-server/async-http-client
            try? httpClient.syncShutdown()
        }
        let configuration = Configuration(apiKey: apiKey, organization: organization)

        openAIClient = OpenAIKit.Client(httpClient: httpClient, configuration: configuration)
        let firstTask = Task(id: UUID().uuidString, name: "Develop a task list")
        taskList.append(firstTask)
        
        while taskList.count > 0 {
            // Print the task list
            print("\u{001B}[95m\u{001B}[1m\n*****TASK LIST*****\n\u{001B}[0m\u{001B}[0m")
            for task in taskList {
                print("* \(task.name)")
            }
            
            // Step 1: Pull the first task
            if let task = taskList.first {
                taskList.removeFirst()
                print("\u{001B}[92m\u{001B}[1m\n*****NEXT TASK*****\n\u{001B}[0m\u{001B}[0m")
                print("* \(task.name)")

                let result = await execute(task: task, withContext: "")
                print("\u{001B}[93m\u{001B}[1m\n*****TASK RESULT*****\n\u{001B}[0m\u{001B}[0m")
                print(result)
                
                // Step 2: Enrich result and store in Pinecone
                let enrichedResult = result // not even sure what "enriched" is...need to look that up -- prob something in the original project?
                let adaEmbedding = await getADAEmbedding(withText: enrichedResult)
                let vector = Vector(id: "\(task.id)", values: adaEmbedding, metadata: VectorMetadata(taskName: task.name, result: result))
                await upsert(vector: vector)
                
                // Step 3: Create new tasks and reprioritize task list
                let newTasks = await createNewTasks(withPreviousTask: task, previousResult: result)
                taskList.append(contentsOf: newTasks)
                taskList = await prioritizeTasks()
            }
        }
    }
}
