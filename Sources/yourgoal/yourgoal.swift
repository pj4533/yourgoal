import Foundation
import ArgumentParser

@main
struct YourGoal: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
    	commandName: "yourgoal",
        abstract: "Doing. Stuff."
    )

    @Argument(help: "Your goal, in quotes")
    var yourgoal: String

    @Flag(help: "Debug Mode")
    var debug: Bool = false

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
    var namespaceUUID: String = UUID().uuidString
            
    func getContext(withQuery query: String, includeResults: Bool = true) async -> String {
        let queryEmbedding = await OpenAIClient.shared.getEmbedding(withText: query)
        let vectorDB = PineconeVectorDatabase(apiKey: self.pineconeAPIKey, baseURL: self.pineconeBaseURL, namespace: self.namespaceUUID)
        return await vectorDB.query(embedding: queryEmbedding, includeResults: includeResults)
    }

    func prioritizeTasks() async -> [Task] {
        DebugLog.shared.log("\n****PRIORITIZE TASKS COMPLETION*****\n")
        let completion = await OpenAIClient.shared.getCompletion(withSystemMessage:  "You are an task prioritization AI tasked with cleaning the formatting and reprioritizing tasks. Consider the ultimate objective of your team: \(yourgoal). Do not remove any tasks. Return the result as an ordered bulleted list using a '* ' at the beginning of each line.", userMessage: "Clean, format and reprioritize these tasks: \(taskList.map({$0.name}).joined(separator: ", ")).")
        var prioritizedTasks: [Task] = []
        DebugLog.shared.log("\n****PRIORITIZE TASKS RESULT****\n")
        DebugLog.shared.log(completion)
        let lines = completion.split(separator: "\n")
        for line in lines {
            let taskComponents = line.components(separatedBy: "* ")
            if let taskName = taskComponents.last {
                let newTask = Task(id: UUID().uuidString, name: String(taskName))
                prioritizedTasks.append(newTask)
            }
        }
        return prioritizedTasks
    }
    
    mutating func createNewTasks(withPreviousTask previousTask: Task, previousResult: String) async -> [Task] {
        DebugLog.shared.log("\n****CREATE NEW TASKS COMPLETION****\n")
        let completion = await OpenAIClient.shared.getCompletion(withSystemMessage: "You are an task creation AI that uses the result of an execution agent to create new tasks with the following objective: \(yourgoal), The last completed task has the result: \(previousResult). This result was based on this task description: \(previousTask.name). These are incomplete tasks: \(taskList.map({$0.name}).joined(separator: ", ")).", userMessage: "Based on the previous result, create new tasks to be completed by the AI system that do not overlap with incomplete tasks. Each line containing a task should start with '-- '")
        var newTasks: [Task] = []
        DebugLog.shared.log("\n****CREATE NEW TASKS RESULT****\n")
        DebugLog.shared.log(completion)
        let newTaskStrings = completion.split(separator: "\n")
        for taskString in newTaskStrings {
            if taskString.hasPrefix("-- ") {
                if let newTaskString = taskString.components(separatedBy: "-- ").last {
                    let newTask = Task(id: UUID().uuidString, name: String(newTaskString))
                    newTasks.append(newTask)
                }
            }
        }
        return newTasks
    }

    // This is based on the AI-Functions concept, check it out here: https://github.com/Torantulino/AI-Functions  (also the core of AutoGPT)
    func callAIFunction(functionDesc: String, functionDef: String, parametersString: String) async -> String {
        DebugLog.shared.log("\n****CALL AI FUNCTION COMPLETION****\n")
        let completion = await OpenAIClient.shared.getCompletion(withSystemMessage: "You are now the following Swift function: ```// \(functionDesc)\n\(functionDef)```\n\nOnly respond with your `return` value.", userMessage: parametersString, temperature: 0.0, maxTokens: 100)
        DebugLog.shared.log("\n****CALL AI FUNCITON STRING RESULT****\n")
        DebugLog.shared.log(completion)
        return completion
    }
    
    func isGoalCompleted() async -> Bool {
        let context = await getContext(withQuery: yourgoal, includeResults: false)
        let aiFunctionStringResult = await callAIFunction(functionDesc: "Determines if the goal is completed by analyzing the context", functionDef: "func isGoalCompleted(goal: String, context: String) -> Bool", parametersString: "goal parameter: ```\(yourgoal)```, context parameter: ```\(context)```")
        if let boolResult = Bool(aiFunctionStringResult) {
            return boolResult
        }
        print("Error converting type for AI function: \(aiFunctionStringResult)".red)
        return false
    }
    
    func execute(task: Task, withContext context: String) async -> String {
        let context = await getContext(withQuery: yourgoal)
        DebugLog.shared.log("\n****TASK EXECUTE COMPLETION****\n")
        let completion = await OpenAIClient.shared.getCompletion(withSystemMessage: "You are an AI who performs one task based on the following objective: \(yourgoal).\nTake into account these previously completed tasks and results: \(context)", userMessage: "Your task: \(task.name)", temperature: 0.7, maxTokens: 2000)
        return completion
    }
    
	mutating func run() async throws {
        DebugLog.shared.debug = self.debug
        OpenAIClient.initialize(apiKey: self.apiKey, organization: self.organization)
        
        print("\n*****OBJECTIVE*****\n".lightBlue)
        print("\(yourgoal)")

        let firstTask = Task(id: UUID().uuidString, name: "Develop a task list")
        taskList.append(firstTask)
        
        while taskList.count > 0 {
            // Print the task list
            print("\n*****TASK LIST*****\n".magenta)
            for task in taskList {
                print("* \(task.name)")
            }
            
            // Step 1: Pull the first task
            if let task = taskList.first {
                taskList.removeFirst()
                print("\n*****NEXT TASK*****\n".green)
                print("* \(task.name)")

                let result = await execute(task: task, withContext: "")
                print("\n*****TASK RESULT*****\n".yellow)
                print(result)
                
                // Step 2: Enrich result and store in Pinecone
                let enrichedResult = result // not even sure what "enriched" is...need to look that up -- prob something in the original project?
                let embedding = await OpenAIClient.shared.getEmbedding(withText: enrichedResult)
                let vector = Vector(id: "\(task.id)", values: embedding, metadata: VectorMetadata(taskName: task.name, result: result))
                let vectorDB = PineconeVectorDatabase(apiKey: self.pineconeAPIKey, baseURL: self.pineconeBaseURL, namespace: self.namespaceUUID)
                await vectorDB.upsert(vector: vector)
                
                // Based on context, have we completed the objective
                if await isGoalCompleted() {
                    taskList = []
                    print("\n*****GOAL ACHIEVED*****\n".green)
                } else {
                    // Step 3: Create new tasks and reprioritize task list
                    let newTasks = await createNewTasks(withPreviousTask: task, previousResult: result)
                    taskList.append(contentsOf: newTasks)
                    taskList = await prioritizeTasks()
                }
            }
        }
    }
}
