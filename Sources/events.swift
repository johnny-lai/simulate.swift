//
//  event.swift
//  simulate
//
//  Created by Bing-Chang Lai on 4/27/25.
//

import Foundation

class EventQueue {
  var events: [Event] = []

  func enqueue(_ event: Event) {
    if let i = events.firstIndex(where: { $0.at > event.at }) {
      events.insert(event, at: i)
    } else {
      events.append(event)
    }
  }

  func dequeue() -> Event? {
    if events.isEmpty {
      return nil
    }
    return events.removeFirst()
  }
}

class Event {
  var at: Date

  init(at: Date = Date()) {
    self.at = at
  }

  func perform(_ simulation: Simulation) {}
}

class JobEnqueuedEvent: Event {
  var job: Job
  var to: JobQueue

  init(job: Job, to: JobQueue, at: Date = Date()) {
    self.job = job
    self.to = to
    super.init(at: at)
  }

  override func perform(_ simulation: Simulation) {
    print("Enqueueing job \(self.job) at \(at)")
    to.enqueue(self.job)
  }
}

class JobCompletedEvent: Event {
  var job: Job
  var worker_id: Int

  init(job: Job, worker_id: Int, at: Date = Date()) {
    self.job = job
    self.worker_id = worker_id
    super.init(at: at)
  }

  override func perform(_ simulation: Simulation) {
    simulation.recordJobCompletion(job, worker_id: worker_id, at: at)
    print("Worker finished a job at \(at)")
    if let w = simulation.workerWithId(self.worker_id) {
      w.idle = true
    }
  }
}

class AutoScaleEvent: Event {
  override func perform(_ simulation: Simulation) {
    let podStartUp : TimeInterval = 180
    let currentPodCount = simulation.currentPodCount()
    var desiredPodCount = simulation.desiredPodCount(at: at)

    // Ensure desired is with min to max range
    desiredPodCount = min(desiredPodCount, simulation.maxPods)
    desiredPodCount = max(desiredPodCount, simulation.minPods)

    if currentPodCount < desiredPodCount {
      print("\(at): AutoScale: Scale up \(currentPodCount) to \(desiredPodCount) pods")
      simulation.eventQueue.enqueue(AddPodEvent(desiredPodCount - currentPodCount, at: at.addingTimeInterval(podStartUp)))
    } else if currentPodCount > desiredPodCount {
      print("\(at): AutoScale: Scale down \(currentPodCount) to \(desiredPodCount) pods")
      simulation.eventQueue.enqueue(RemovePodEvent(desiredPodCount - currentPodCount, at: at.addingTimeInterval(1)))
    } else if !simulation.isDone() {
      // Schedule next auto-scale in 15 seconds
      simulation.eventQueue.enqueue(AutoScaleEvent(at: at.addingTimeInterval(15)))
    }
  }
}

class AddPodEvent: Event {
  var count: Int
  
  init(_ count: Int, at: Date = Date()) {
    self.count = count
    super.init(at: at)
  }
  
  override func perform(_ simulation: Simulation) {
    print("\(at): AddPodEvent: added \(count) new pods")
    simulation.addPod(count)

    if !simulation.isDone() {
      // Schedule next auto-scale in 15 seconds
      simulation.eventQueue.enqueue(AutoScaleEvent(at: at.addingTimeInterval(15)))
    }
  }
}

class RemovePodEvent: Event {
  var count: Int
  
  init(_ count: Int, at: Date = Date()) {
    self.count = count
    super.init(at: at)
  }
  
  override func perform(_ simulation: Simulation) {
    print("\(at): RemovePodEvent: removed \(count) pods")
    simulation.removePod(count)

    if !simulation.isDone() {
      // Schedule next auto-scale in 15 seconds
      simulation.eventQueue.enqueue(AutoScaleEvent(at: at.addingTimeInterval(15)))
    }
  }
}

