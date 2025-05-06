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
  var percentile: Double
  var lookback: TimeInterval

  init(percentile: Double = 0.90, lookback: TimeInterval = 600) {
    self.percentile = percentile
    self.lookback = lookback
  }

  func estimate(_ history: EventLog, length: Int, at: Date) -> Double {
    var estimatedQueueLength : Double = 0
    let latencies = history.latencies(since: at - lookback)
    if let k = Sigma.percentile(latencies, percentile: self.percentile) {
      estimatedQueueLength = Double(length) * k
    }
    return estimatedQueueLength
  }

  var description: String {
    return "percentile(\(percentile), lookback: \(lookback))"
  }
}

class AverageAlgorithm : Algorithm {
  var lookback: TimeInterval

  init(lookback: TimeInterval = 600) {
    self.lookback = lookback
  }

  func estimate(_ history: EventLog, length: Int, at: Date) -> Double {
    var estimatedQueueLength : Double = 0
    let latencies = history.latencies(since: at - 600)
    if let k = Sigma.average(latencies) {
      estimatedQueueLength = Double(length) * k
    }
    return estimatedQueueLength
  }

  var description: String {
    return "average(lookback: \(lookback))"
  }
}
