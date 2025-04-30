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

class Simulation {
  var targetPickup: TimeInterval = 300
  var workersPerPod: Int = 3
  var maxPods: Int = 5
  var minPods: Int = 1
  var algorithm: Algorithm = PercentileAlgorithm()
  var podStartupTime: TimeInterval = 180
  var podShutdownTime: TimeInterval = 0

  var eventQueue: EventQueue = EventQueue()
  var queue: JobQueue = JobQueue()
  var workers: [Worker] = []
  var nextWorkerId: Int = 1
  var expectedJobCount: Int = 0

  var history: EventLog = EventLog()

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
    return self.algorithm.estimate(history, queue: queue, at: at)
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
    let stream = OutputStream(toFileAtPath: "output.csv", append: false)!
    let csv = try! CSVWriter(stream: stream)
    writeHeader(to: csv)

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
        writeState(at, to: csv)
        event.perform(self)

        aliveWorkers().forEach( { $0.perform(eventQueue, at: at) } )
      }
      writeState(at, to: csv)

      let pickups = history.pickups(since: first.at)
      let pickupAverage = Sigma.average(pickups)!
      let pickupMax = Sigma.max(pickups)!

      eventLog.info("Summary", metadata: [
        "pickup_average_s": "\(String(format: "%.2f", pickupAverage))",
        "pickup_max_s": "\(String(format: "%.2f", pickupMax))"
      ])
    }

    stream.close()
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

  func writeHeader(to: CSVWriter) {
    do {
      try to.write(row: ["timestamp", "queued_jobs", "idle_workers", "running_workers", "pods"])
    } catch {
    }
  }

  func writeState(_ at: Date, to: CSVWriter) {
    let running = busyWorkers().count
    do {
      try to.write(row: [
        "\(at)",
        "\(queue.jobs.count)",
        "\(aliveWorkers().count - running)",
        "\(running)",
        "\(currentPodCount())"
      ])
    } catch {
    }
  }

  func isDone() -> Bool {
    return expectedJobCount <= 0 && self.busyWorkers().count == 0
  }
}

