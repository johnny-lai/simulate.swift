//
//  simulation.swift
//  simulate
//
//  Created by Bing-Chang Lai on 4/27/25.
//

import Foundation
import CSV

struct Stat {
  var jobsPending: Int = 0
  var workersIdle: Int = 0
  var workersActive: Int = 0
}

class Simulation {
  var eventQueue: EventQueue = EventQueue()
  var queue: JobQueue = JobQueue()
  var workers: [Worker] = []
  var nextWorkerId: Int = 1

  func loadCSV(_ filename: String) {
    let dateFormatter = ISO8601DateFormatter()
    dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let stream = InputStream(fileAtPath: filename)!
    do {
      let reader = try CSVReader(stream: stream, hasHeaderRow: true)
      let decoder = CSVRowDecoder()
      while reader.next() != nil {
        let queue = self.queue
        let at = dateFormatter.date(from: reader["enqueued_at"]!)
        let job = try decoder.decode(Job.self, from: reader)
        eventQueue.enqueue(JobEnqueued(job: job, to: queue, at: at!))
      }
    } catch {
        // Invalid row format
    }
  }

  func workerWithId(_ id: Int) -> Worker? {
    self.workers.first(where: { $0.id == id })
  }

  func desiredWorkerCount() -> Int {
    return 2
  }

  func autoScale() {
    let currentWorkerCount = workers.count
    let desiredWorkerCount = self.desiredWorkerCount()

    if currentWorkerCount < desiredWorkerCount {
      let newWorker = Worker(id: nextWorkerId, queue: self.queue)
      nextWorkerId += 1
      workers.append(newWorker)
    } else if currentWorkerCount > desiredWorkerCount {
      workers.removeLast()
    }
  }

  func run() {
    var at: Date?
    print("Starting simulation")
    while let event = eventQueue.dequeue() {
      at = event.at
      print("\(at): \(stats())")
      event.perform(self)
      autoScale()
      workers.forEach( { $0.perform(eventQueue, at: at!) } )
    }
    if let at = at {
      print("\(at): \(stats())")
      print("Simulation ended at \(at)")
    } else {
      print("Simulation ended without events")
    }
  }

  func stats() -> Stat {
    var s = Stat()
    s.jobsPending = queue.jobs.count
    s.workersActive = workers.filter { !$0.idle }.count
    s.workersIdle = workers.count - s.workersActive
    return s
  }
}
