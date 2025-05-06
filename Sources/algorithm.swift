//
//  algorithm.swift
//  simulate
//
//  Created by Bing-Chang Lai on 4/27/25.
//

import Foundation
import SigmaSwiftStatistics

protocol Algorithm : CustomStringConvertible {
  func estimate(_ history: EventLog, length: Int, at: Date) -> Double
}

class PercentileAlgorithm : Algorithm {
  var percentile: Double = 0.90
  var lookback: TimeInterval = 600

  func estimate(_ history: EventLog, length: Int, at: Date) -> Double {
    var estimatedQueueLength : Double = 0
    let latencies = history.latencies(since: at - lookback)
    if let k = Sigma.percentile(latencies, percentile: self.percentile) {
      estimatedQueueLength = Double(length) * k
    }
    return estimatedQueueLength
  }

  var description: String {
    return "percentile: \(percentile) with lookup"
  }
}

class AverageAlgorithm : Algorithm {
  var lookback: TimeInterval = 600

  func estimate(_ history: EventLog, length: Int, at: Date) -> Double {
    var estimatedQueueLength : Double = 0
    let latencies = history.latencies(since: at - 600)
    if let k = Sigma.average(latencies) {
      estimatedQueueLength = Double(length) * k
    }
    return estimatedQueueLength
  }

  var description: String {
    return "average with lookback: \(lookback)"
  }
}
