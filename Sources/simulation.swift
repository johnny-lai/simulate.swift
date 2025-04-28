//
//  simulation.swift
//  simulate
//
//  Created by Bing-Chang Lai on 4/27/25.
//

import Foundation
import CSV

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

  func desiredPodCount(at: Date) -> Int {
    let e = estimatedQueueLength(at: at)
    print("Actual = \(self.queue.latency()) Estimated = \(e)")

    let desiredWorkers = max(e / targetPickup, e)
    return max(Int(ceil(desiredWorkers/Double(workersPerPod))), 1)
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

  func autoScale(at: Date) {
    let currentPodCount = self.currentPodCount()
    var desiredPodCount = self.desiredPodCount(at: at)

    // Ensure desired is with min to max range
    desiredPodCount = min(desiredPodCount, maxPods)
    desiredPodCount = max(desiredPodCount, minPods)

    // TODO: Simulate delay in adding workers
    // TODO: Simulate pods
    if currentPodCount < desiredPodCount {
      print("\(at): AutoScale: Scale up \(currentPodCount) to \(desiredPodCount) pods")
      addPod(desiredPodCount - currentPodCount)
    } else if currentPodCount > desiredPodCount {
      print("\(at): AutoScale: Scale down \(currentPodCount) to \(desiredPodCount) pods")
      removePod(currentPodCount - desiredPodCount)
    } else {
      print("\(at): AutoScale: \(currentPodCount) is stable")
    }
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
    print("Starting simulation")
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
        print("\(at): \(state())")
        event.perform(self)

        aliveWorkers().forEach( { $0.perform(eventQueue, at: at) } )
      }

      print("\(at): \(state())")
      print("Simulation ended at \(at)")

      let pickupAverage = history.pickupAverage(since: first.at)
      print("Pickup average = \(pickupAverage)")
    } else {
      print("Simulation ended without events")
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

  func state() -> State {
    var s = State()
    s.jobsPending = queue.jobs.count
    s.workersBusy = busyWorkers().count
    s.workersIdle = aliveWorkers().count - s.workersBusy
    return s
  }

  func isDone() -> Bool {
    return expectedJobCount <= 0 && self.busyWorkers().count == 0
  }
}
