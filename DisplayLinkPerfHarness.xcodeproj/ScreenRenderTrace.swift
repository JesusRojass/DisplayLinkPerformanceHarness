//
//  ScreenRenderTrace.swift
//  DisplayLinkPerfHarness
//
//  Created by Jesus Rojas on Oct 31, 2025.
//

import Foundation
import QuartzCore
import FirebasePerformance
import UIKit

final class ScreenRenderTrace: ObservableObject {
  private var trace: Trace?
  private var link: CADisplayLink?
  private var lastTimestamp: CFTimeInterval = 0
  private var targetFPS: Int = 60

  init() {
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(applicationDidEnterBackground),
      name: UIApplication.didEnterBackgroundNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(applicationWillEnterForeground),
      name: UIApplication.willEnterForegroundNotification,
      object: nil
    )
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }

  func start(name: String = "Screen", targetFPS: Int, strict: Bool) {
    stop()
    self.targetFPS = targetFPS
    // Create a Firebase Performance trace to log screen rendering metrics
    trace = Performance.startTrace(name: name)

    let l = CADisplayLink(target: self, selector: #selector(step(_:)))
    if #available(iOS 15.0, *) {
      let fr = Float(targetFPS)
      let minVal: Float = strict ? fr : 60
      l.preferredFrameRateRange = CAFrameRateRange(minimum: minVal, maximum: fr, preferred: fr)
    } else {
      l.preferredFramesPerSecond = targetFPS
    }
    l.add(to: .main, forMode: .common)
    link = l
  }

  func stop() {
    link?.invalidate(); link = nil
    lastTimestamp = 0
    trace?.stop(); trace = nil
  }

  @objc private func applicationDidEnterBackground() {
    link?.isPaused = true
  }

  @objc private func applicationWillEnterForeground() {
    link?.isPaused = false
  }

  @objc private func step(_ dl: CADisplayLink) {
    if lastTimestamp == 0 { lastTimestamp = dl.timestamp; return }
    let dt = dl.timestamp - lastTimestamp
    lastTimestamp = dl.timestamp

    // Increment total frames rendered
    trace?.incrementMetric("total", by: 1)

    // Determine if this frame exceeded its budget (slow) or far exceeded (frozen)
    // Frame budget is 1/targetFPS seconds, or use CADisplayLink targetTimestamp when available
    let budget: CFTimeInterval
    if dl.targetTimestamp > dl.timestamp {
      budget = dl.targetTimestamp - dl.timestamp
    } else {
      budget = 1.0 / Double(targetFPS)
    }

    if dt > budget {
      trace?.incrementMetric("slow", by: 1)
    }
    if dt > 42.0 * budget {
      trace?.incrementMetric("frozen", by: 1)
    }
  }
}
