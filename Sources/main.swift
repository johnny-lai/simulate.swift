// The Swift Programming Language
// https://docs.swift.org/swift-book

import ArgumentParser
import Foundation
import Logging
import CSV

struct Run: ParsableCommand {
  static let configuration = CommandConfiguration(abstract: "Job simulator")

  @Option(name: [.short, .customLong("verbose")], help: "Verbose mode. Defaults to false")
  var verbose: Bool = false

  @Option(name: [.short, .customLong("input")], help: "The CSV file to load, or '-' for stdin.")
  var inFile: String

  @Option(name: [.short, .customLong("multiplier")], help: "Multiplier. Default: 1.0")
  var multipler: Double = 1.0

  @Option(name: [.short, .customLong("target")], help: "Target Pickup Seconds. Default: 300")
  var targetPickup: TimeInterval = 300

  @Option(name: [.short, .customLong("workers")], help: "Workers per pod. Default: 3")
  var workersPerPod: Int = 3

  @Option(name: [.customLong("min-pods")], help: "Min Pods. Default: 1")
  var minPods: Int = 1

  @Option(name: [.customLong("max-pods")], help: "Max Pods. Default: 3")
  var maxPods: Int = 30

  @Option(name: [.customLong("startup")], help: "Pod Startup Seconds. Default: 180")
  var podStartupTime: TimeInterval = 180

  @Option(name: [.customLong("shutdown")], help: "Pod Shutdown Seconds. Default: 0")
  var podShutdownTime: TimeInterval = 0

  mutating func run() throws {
    let verbose = self.verbose
    
    LoggingSystem.bootstrap { label in
        var handler = StreamLogHandler.standardOutput(label: label)
        if verbose {
          handler.logLevel = .trace
        } else {
          handler.logLevel = .info
        }
        return handler
    }

    if inFile == "-" {
      inFile = "/dev/stdin"
    }

    // Read from a file
    let currentPath = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let url = URL(fileURLWithPath: inFile, relativeTo: currentPath)
    let stream = InputStream(url: url)!

    let simulation = Simulation()
    simulation.loadCSV(stream)
    simulation.multipler = multipler
    simulation.targetPickup = targetPickup
    simulation.workersPerPod = workersPerPod
    simulation.minPods = minPods
    simulation.maxPods = maxPods
    simulation.podStartupTime = podStartupTime
    simulation.podShutdownTime = podShutdownTime
    simulation.algorithm = PercentileAlgorithm()
    simulation.run()
  }
}

Run.main()
