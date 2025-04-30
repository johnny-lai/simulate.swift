//
//  algorithm.swift
//  simulate
//
//  Created by Bing-Chang Lai on 4/27/25.
//

import Foundation
import SigmaSwiftStatistics

protocol Algorithm {
  func estimate(_ history: EventLog, queue: JobQueue, at: Date) -> Double
}

class PercentileAlgorithm : Algorithm {
  var percentile: Double = 0.90

  func estimate(_ history: EventLog, queue: JobQueue, at: Date) -> Double {
    var estimatedQueueLength : Double = 0
    let latencies = history.latencies(since: at - 600)
    if let k = Sigma.percentile(latencies, percentile: self.percentile) {
      estimatedQueueLength = Double(queue.jobs.count) * k
    }
    return estimatedQueueLength
  }
}
