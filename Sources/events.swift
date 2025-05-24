//
//  event.swift
//  simulate
//
//  Created by Bing-Chang Lai on 4/27/25.
//

import Foundation
import Logging

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
    eventLog.trace(
      "JobEnqueuedEvent",
      metadata: [
        "at": "\(self.at)",
        "job_id": "\(self.job.id)",
      ])
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
    eventLog.trace(
      "JobCompletedEvent",
      metadata: [
        "at": "\(self.at)",
        "job_id": "\(self.job.id)",
        "worker_id": "\(self.worker_id)",
      ])
    simulation.recordJobCompletion(job, worker_id: worker_id, at: at)
    if let w = simulation.workerWithId(self.worker_id) {
      w.idle = true
    }
  }
}

class AutoScaleEvent: Event {
  override func perform(_ simulation: Simulation) {
    let currentPodCount = simulation.currentPodCount()
    let e = simulation.estimatedQueueLength(at: at)
    let uncappedDesiredPods = simulation.desiredPodCount(estimate: e)

    // Ensure desired is with min to max range
    var desiredPodCount = uncappedDesiredPods
    desiredPodCount = min(desiredPodCount, simulation.maxPods)
    desiredPodCount = max(desiredPodCount, simulation.minPods)

    var direction: String

    if desiredPodCount > currentPodCount {
      direction = "up"
      simulation.eventQueue.enqueue(
        AddPodEvent(
          desiredPodCount - currentPodCount, at: at.addingTimeInterval(simulation.podStartupTime)))
    } else if desiredPodCount < currentPodCount {
      direction = "down"
      simulation.eventQueue.enqueue(
        RemovePodEvent(
          desiredPodCount - currentPodCount, at: at.addingTimeInterval(simulation.podShutdownTime)))
    } else {
      direction = "flat"
      if !simulation.isDone() {
        // Schedule next auto-scale in 15 seconds
        simulation.eventQueue.enqueue(AutoScaleEvent(at: at.addingTimeInterval(15)))
      }
    }

    eventLog.trace(
      "AutoScaleEvent",
      metadata: [
        "at": "\(self.at)",
        "scale": "\(direction)",
        "currentPods": "\(currentPodCount)",
        "desiredPods": "\(desiredPodCount)",
        "actual_s": "\(simulation.queue.latency())",
        "estimated_s": "\(e)",
      ])
  }
}

class AddPodEvent: Event {
  var count: Int

  init(_ count: Int, at: Date = Date()) {
    self.count = count
    super.init(at: at)
  }

  override func perform(_ simulation: Simulation) {
    eventLog.trace(
      "AddPodEvent",
      metadata: [
        "at": "\(self.at)",
        "count": "\(count)",
      ])
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
    eventLog.trace(
      "RemovePodEvent",
      metadata: [
        "at": "\(self.at)",
        "count": "\(count)",
      ])
    simulation.removePod(count)

    if !simulation.isDone() {
      // Schedule next auto-scale in 15 seconds
      simulation.eventQueue.enqueue(AutoScaleEvent(at: at.addingTimeInterval(15)))
    }
  }
}

class WriteStateEvent: Event {
  override func perform(_ simulation: Simulation) {
    eventLog.trace(
      "WriteStateEvent",
      metadata: [
        "at": "\(self.at)"
      ])
    simulation.writeState(at)

    if !simulation.isDone() {
      // Schedule next write state event
      simulation.eventQueue.enqueue(
        WriteStateEvent(at: at.addingTimeInterval(simulation.writeStateInterval)))
    }
  }
}
