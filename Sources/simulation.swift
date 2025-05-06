//
//  simulation.swift
//  simulate
//
//  Created by Bing-Chang Lai on 4/27/25.
//

import Foundation
import CSV
import Logging
import SigmaSwiftStatistics

let eventLog = Logger(label: "events")
let stateLog = Logger(label: "state")

struct State {
  var jobsPending: Int = 0
  var workersIdle: Int = 0
  var workersBusy: Int = 0
}

enum Output {
  case queueLengths
  case kpis
}

class Simulation {
  var targetPickup: TimeInterval = 300
  var workersPerPod: Int = 3
  var maxPods: Int = 5
  var minPods: Int = 1
  var algorithm: Algorithm = PercentileAlgorithm()
  var podStartupTime: TimeInterval = 180
  var podShutdownTime: TimeInterval = 0
  var multipler: Double = 1.0

  var eventQueue: EventQueue = EventQueue()
  var queue: JobQueue = JobQueue()
  var workers: [Worker] = []
  var nextWorkerId: Int = 1
  var expectedJobCount: Int = 0

  var csvs: [Output: CSVWriter] = [:]

  var history: EventLog = EventLog()

  deinit {
    csvs.forEach { $0.value.stream.close() }
  }

  func loadCSV(_ stream: InputStream) {
    let dateFormatter = ISO8601DateFormatter()
    dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    do {
      let reader = try CSVReader(stream: stream, hasHeaderRow: true)
      let decoder = CSVRowDecoder()
      decoder.dateDecodingStrategy = .custom({ value in
        dateFormatter.date(from: value) ?? Date(timeIntervalSince1970: 0)
      })
      while reader.next() != nil {
        let queue = self.queue
        let job = try decoder.decode(Job.self, from: reader)
        eventQueue.enqueue(JobEnqueuedEvent(job: job, to: queue, at: job.enqueuedAt))
        expectedJobCount += 1
      }
    } catch {
        // Invalid row format
    }
  }

  func workerWithId(_ id: Int) -> Worker? {
    self.workers.first(where: { $0.id == id })
  }

  func estimatedQueueLength(at: Date) -> Double {
    let unprocessedLength = queue.jobs.count + busyWorkers().count

    return self.multipler * self.algorithm.estimate(history, length: unprocessedLength, at: at)
  }

  func desiredPodCount(estimate: Double) -> Int {
    var desiredWorkers = Int(ceil(estimate / targetPickup))
    if desiredWorkers > self.queue.count {
      desiredWorkers = self.queue.count
    }
    return Int(ceil(Double(desiredWorkers)/Double(workersPerPod)))
  }

  func aliveWorkers() -> [Worker] {
    return self.workers.filter( { $0.alive == true } )
  }

  func busyWorkers() -> [Worker] {
    return aliveWorkers().filter( { $0.idle == false } )
  }

  func currentPodCount() -> Int {
    return aliveWorkers().count / workersPerPod
  }

  func addPod(_ n: Int = 1) {
    let targetWorkerCount = n * workersPerPod
    for _ in 0..<targetWorkerCount {
      let newWorker = Worker(id: nextWorkerId, queue: self.queue)
      nextWorkerId += 1
      workers.append(newWorker)
    }
  }

  func removePod(_ n: Int = 1) {
    let targetWorkerCount = n * workersPerPod
    var removed = 0;
    for w in workers {
      // Mark worker are inactive
      if w.alive == true {
        w.alive = false
        removed += 1
      }
      if removed >= targetWorkerCount {
        break
      }
    }
  }

  func run() {
    if let first = eventQueue.events.first {
      // Start with 1 pod
      addPod(1)

      // Add Autoscale sometime after first
      let autoscaleAt = first.at + 1
      eventQueue.enqueue(AutoScaleEvent(at: autoscaleAt))

      var at = first.at
      while let event = eventQueue.dequeue() {
        if isDone() { break }
        at = event.at
        writeState(at)
        event.perform(self)

        aliveWorkers().forEach( { $0.perform(eventQueue, at: at) } )
      }
      writeState(at)

      let pickups = history.pickups(since: first.at)
      let pickupAverage = Sigma.average(pickups)!
      let pickupMax = Sigma.max(pickups)!

      eventLog.info("Parameters", metadata: [
        "target_pickup_s": "\(String(format: "%.2f", targetPickup))",
        "workers_per_pod": "\(workersPerPod)",
        "max_pods": "\(maxPods)",
        "min_pods": "\(minPods)",
        "algorithm": "\(algorithm)",
        "pod_startup_time": "\(podStartupTime)",
        "pod_shutdown_time": "\(podShutdownTime)",
        "multipler": "\(multipler)"
      ])

      eventLog.info("Summary", metadata: [
        "%_<_target": "\(String(format: "%.2f", jobsBelowTargetPercent(pickups)))",
        "pickup_average_s": "\(String(format: "%.2f", pickupAverage))",
        "pickup_max_s": "\(String(format: "%.2f", pickupMax))"
      ])
    }
  }

  func recordJobCompletion(_ job: Job, worker_id: Int, at: Date) {
    let startedAt = at - job.latency

    let j = JobLogEntry(
      jobId: job.id,
      workerId: worker_id,
      enqueuedAt: job.enqueuedAt,
      startedAt: startedAt,
      completedAt: at,
    )
    history.append(j)
    expectedJobCount -= 1
  }

  func csv(_ type: Output) -> CSVWriter {
    if csvs[type] != nil {
      return csvs[type]!
    }

    var fileName: String
    switch type {
    case .kpis:
      fileName = "kpis.csv"
    case .queueLengths:
      fileName = "queueLengths.csv"
    }
    let stream = OutputStream(toFileAtPath: fileName, append: false)!
    let csv = try! CSVWriter(stream: stream)

    switch type {
    case .kpis:
      try! csv.write(row: ["timestamp", "running%", "%_<_target", "95%_pickup", "max_pickup", "queued_jobs"])
    case .queueLengths:
      try! csv.write(row: ["timestamp","idle_workers", "running_workers", "pods", "queued_jobs"])
    }

    csvs[type] = csv
    return csv
  }

  func writeState(_ at: Date) {
    let pickups = history.pickups(since: at.addingTimeInterval(-30 * 60))
    let running = busyWorkers().count
    let totalWorkers = aliveWorkers().count

    let kpis = csv(.kpis)
    try! kpis.write(row: [
      "\(at)",
      "\(String(format: "%.2f", Double(running) / Double(totalWorkers) * 100))",
      "\(String(format: "%.2f", jobsBelowTargetPercent(pickups)))",
      "\(String(format: "%.2f", Sigma.percentile(pickups, percentile: 0.95) ?? 0))",
      "\(String(format: "%.2f", Sigma.max(pickups) ?? 0))",
      "\(queue.jobs.count)"
    ])

    let queueLengths = csv(.queueLengths)
    try! queueLengths.write(row: [
      "\(at)",
      "\(aliveWorkers().count - running)",
      "\(running)",
      "\(currentPodCount())",
      "\(queue.jobs.count)"
    ])
  }

  func jobsBelowTargetPercent(_ pickups: [Double]) -> Double {
    let jobsBelowTarget = pickups.filter( { $0 <= targetPickup } ).count
    var percentBelowTarget: Double = 0
    if pickups.count > 0 {
      percentBelowTarget = Double(jobsBelowTarget) / Double(pickups.count) * 100
    }
    return percentBelowTarget
  }

  func isDone() -> Bool {
    return expectedJobCount <= 0 && self.busyWorkers().count == 0
  }
}

