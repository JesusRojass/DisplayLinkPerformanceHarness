//
//  DisplayLinkTracker.swift
//  DisplayLinkPerfHarness
//
//  Created by Jesus Rojas on Oct 31, 2025.
//

import SwiftUI
import QuartzCore
import FirebasePerformance
import UIKit

final class DisplayLinkTracker: ObservableObject {
  @Published private(set) var total: Int64 = 0
  @Published private(set) var slow: Int64 = 0
  @Published private(set) var frozen: Int64 = 0

  private var trace: Trace?
  func setTrace(_ t: Trace?) { trace = t }

  private var previousTimestamp: CFTimeInterval = -1
  private var link: CADisplayLink?
  private var tickWorkMicros: useconds_t = 0

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

  func setWorkMicros(_ us: Int) { tickWorkMicros = useconds_t(max(0, us)) }

  func startDedicated(frameRate: Int, strict: Bool) {
    stop()
    let l = CADisplayLink(target: self, selector: #selector(step(_:)))
    if #available(iOS 15.0, *) {
      let fr = Float(frameRate)
      let minVal: Float = strict ? fr : 60
      l.preferredFrameRateRange = CAFrameRateRange(minimum: minVal, maximum: fr, preferred: fr)
    } else {
      l.preferredFramesPerSecond = frameRate
    }
    l.add(to: .main, forMode: .common)
    link = l
  }

  func stop() { link?.invalidate(); link = nil; previousTimestamp = -1 }

  @objc private func applicationDidEnterBackground() {
    link?.isPaused = true
  }

  @objc private func applicationWillEnterForeground() {
    link?.isPaused = false
  }

  func stopTrace() {
    trace?.stop()
    trace = nil
  }

  @objc func step(_ dl: CADisplayLink) {
    if tickWorkMicros > 0 { usleep(tickWorkMicros) }

    let current = dl.timestamp
    let frameBudget = dl.targetTimestamp - current
    if frameBudget <= 0 {
      previousTimestamp = current
      return
    }

    if previousTimestamp != -1 {
      let frameDuration = current - previousTimestamp
      if frameDuration > frameBudget { slow += 1; trace?.incrementMetric("slow", by: 1) }
      if frameDuration > 42.0 * frameBudget { frozen += 1; trace?.incrementMetric("frozen", by: 1) }
      total += 1
      trace?.incrementMetric("total", by: 1)
    }
    previousTimestamp = current
  }
}

