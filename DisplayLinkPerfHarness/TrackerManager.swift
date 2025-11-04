//
//  TrackerManager.swift
//  DisplayLinkPerfHarness
//
//  Created by Jesus Rojas on Oct 31, 2025.
//

import Foundation
import QuartzCore
import UIKit
#if canImport(FirebasePerformance)
import FirebasePerformance
public typealias PerfTrace = Trace
#else
public class PerfTrace {
  public init() {}
  public func stop() {}
  public func incrementMetric(_ name: String, by: Int64) {}
}
#endif

final class TrackerManager: ObservableObject {
  @Published var trackers: [DisplayLinkTracker] = []
  private var sharedLink: CADisplayLink?

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

  func configure(count: Int, sharedLinkMode: Bool, frameRate: Int, workMicros: Int, strict: Bool) {
    stopAll()
    trackers = (0..<count).enumerated().map { idx, _ in
      let t = DisplayLinkTracker()
      t.setWorkMicros(workMicros)
      let traceName = "DLTracker_\(idx + 1)"
      #if canImport(FirebasePerformance)
      let tr = Performance.startTrace(name: traceName)
      t.setTrace(tr)
      #else
      t.setTrace(nil)
      #endif
      if !sharedLinkMode { t.startDedicated(frameRate: frameRate, strict: strict) }
      return t
    }
    if sharedLinkMode {
      let l = CADisplayLink(target: self, selector: #selector(sharedStep(_:)))
      if #available(iOS 15.0, *) {
        let fr = Float(frameRate)
        let minVal: Float = strict ? fr : 60
        l.preferredFrameRateRange = CAFrameRateRange(minimum: minVal, maximum: fr, preferred: fr)
      } else {
        l.preferredFramesPerSecond = frameRate
      }
      l.add(to: .main, forMode: .common)
      sharedLink = l
    }
  }

  func stopAll() {
    sharedLink?.invalidate(); sharedLink = nil
    trackers.forEach { t in
      t.stop()
      t.stopTrace()
    }
    trackers.removeAll()
  }

  @objc private func sharedStep(_ l: CADisplayLink) {
    trackers.forEach { tracker in
      tracker.step(l)
    }
  }

  @objc private func applicationDidEnterBackground() {
    sharedLink?.isPaused = true
  }

  @objc private func applicationWillEnterForeground() {
    sharedLink?.isPaused = false
  }
}
