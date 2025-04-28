// The Swift Programming Language
// https://docs.swift.org/swift-book

import ArgumentParser
import Foundation

struct Run: ParsableCommand {
  static let configuration = CommandConfiguration(abstract: "Job simulator")

  @Option(name: [.short, .customLong("input")], help: "The CSV file to load, or '-' for stdin.")
  var inFile: String

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
    simulation.algorithm = PercentileAlgorithm()
    simulation.run()
  }
}

Run.main()
