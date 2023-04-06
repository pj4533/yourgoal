import Foundation
import ArgumentParser
import AsyncHTTPClient
import OpenAIKit

var openAIClient: OpenAIKit.Client?

struct Task: Codable {
    var id: Int
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

    var maxTaskId: Int = 0
    var taskList: [Task] = []
    
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
    
    func prioritizeTasks(withStartingTaskId startingTaskId: Int) async -> [Task] {
        let messages: [OpenAIKit.Chat.Message] = [
            .system(content: "You are an task prioritization AI tasked with cleaning the formatting of and reprioritizing tasks. Consider the ultimate objective of your team: \(yourgoal). Do not remove any tasks. Return the result as a numbered list, like:\n#. First task\n#. Second task\nStart the task list with number \(startingTaskId)."),
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
                    let taskComponents = line.components(separatedBy: ". ")
                    if let taskIdString = taskComponents.first, let taskId = Int(taskIdString), let taskName = taskComponents.last {
                        let newTask = Task(id: taskId, name: String(taskName))
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
                        maxTaskId += 1
                        if let newTaskString = taskString.components(separatedBy: "-- ").last {
                            let newTask = Task(id: maxTaskId, name: String(newTaskString))
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
        let messages: [OpenAIKit.Chat.Message] = [
            .system(content: "You are an AI who performs one task based on the following objective: {objective}.\nTake into account these previously completed tasks: \(context)"),
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
        let httpClient = HTTPClient(eventLoopGroupProvider: .createNew)
        defer {
            // it's important to shutdown the httpClient after all requests are done, even if one failed. See: https://github.com/swift-server/async-http-client
            try? httpClient.syncShutdown()
        }
        let configuration = Configuration(apiKey: apiKey, organization: organization)

        openAIClient = OpenAIKit.Client(httpClient: httpClient, configuration: configuration)
        maxTaskId += 1 // prob a way to make this more swifty so i can just ask for it
        let firstTask = Task(id: maxTaskId, name: "Develop a task list")
        taskList.append(firstTask)
        
        while taskList.count > 0 {
            // Print the task list
            print("\n****** TASK LIST ******\n")
            for task in taskList {
                print("\(task.id): \(task.name)")
            }
            
            // Step 1: Pull the first task
            if let task = taskList.first {
                taskList.removeFirst()
                print("\n****** NEXT TASK ******\n")
                print("\(task.id): \(task.name)")

                let result = await execute(task: task, withContext: "")
                print("\n****** TASK RESULT ******\n")
                print(result)
                
                // Step 2: Enrich result and store in Pinecone
                let enrichedResult = result // not even sure what "enriched" is...need to look that up -- prob something in the original project?
                let adaEmbedding = await getADAEmbedding(withText: enrichedResult)
                /*
                 enriched_result = {'data': result}  # This is where you should enrich the result if needed
                 result_id = f"result_{task['task_id']}"
                 vector = enriched_result['data']  # extract the actual result from the dictionary
                 index.upsert([(result_id, get_ada_embedding(vector),{"task":task['task_name'],"result":result})])
                 */
                
                // Step 3: Create new tasks and reprioritize task list
                let newTasks = await createNewTasks(withPreviousTask: task, previousResult: result)
                taskList.append(contentsOf: newTasks)
                taskList = await prioritizeTasks(withStartingTaskId: task.id)
            }
        }
    }
}
