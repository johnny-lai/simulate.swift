//
//  algorithm.swift
//  simulate
//
//  Created by Bing-Chang Lai on 4/27/25.
//

import Foundation

protocol Algorithm {
  func estimate(_ history: EventLog, queue: JobQueue, at: Date) -> Double
}

class PercentileAlgorithm : Algorithm {
  var percentile: Double = 90

  func estimate(_ history: EventLog, queue: JobQueue, at: Date) -> Double {
    var estimatedQueueLength : Double = 0
    if let k = history.percentileLatency(self.percentile, since: at - 600) {
      estimatedQueueLength = Double(queue.jobs.count) * k
    }
    return estimatedQueueLength
  }
}
