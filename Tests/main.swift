import Foundation

// Drives the main run loop so tests that touch the reader engine (which lives on
// the main actor) run where they're supposed to.
Task { @MainActor in
    var suites: [Suite] = [
        pivotSuite(),
        pacingSuite(),
        tokenizeSuite(),
        chunkerSuite(),
        markdownSuite(),
        reflowSuite(),
        loadSuite(),
    ]
    suites.append(engineSuite())
    exit(await run(suites))
}

RunLoop.main.run()
