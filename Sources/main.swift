// The Swift Programming Language
// https://docs.swift.org/swift-book

import ArgumentParser
import Foundation
import Logging
import CSV

struct Run: ParsableCommand {
  static let configuration = CommandConfiguration(abstract: "Job simulator")

  @Option(name: [.short, .customLong("input")], help: "The CSV file to load, or '-' for stdin.")
  var inFile: String

  @Option(name: [.short, .customLong("workers")], help: "Workers per pod. Default: 3")
  var workersPerPod: Int = 3

  @Option(name: [.customLong("min-pods")], help: "Min Pods. Default: 1")
  var minPods: Int = 1

  @Option(name: [.customLong("max-pods")], help: "Max Pods. Default: 3")
  var maxPods: Int = 3

  mutating func run() throws {
    if inFile == "-" {
      inFile = "/dev/stdin"
    }

    // Read from a file
    let currentPath = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let url = URL(fileURLWithPath: inFile, relativeTo: currentPath)
    let stream = InputStream(url: url)!

    let simulation = Simulation()
    simulation.loadCSV(stream)
    simulation.maxPods = maxPods
    simulation.minPods = minPods
    simulation.workersPerPod = workersPerPod
    simulation.algorithm = PercentileAlgorithm()
    simulation.run()
  }
}

LoggingSystem.bootstrap { label in
    var handler = StreamLogHandler.standardOutput(label: label)
    handler.logLevel = .trace
    return handler
}
Run.main()
