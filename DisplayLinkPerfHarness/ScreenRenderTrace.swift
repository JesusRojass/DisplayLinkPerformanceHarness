//
//  ScreenRenderTrace.swift
//  DisplayLinkPerfHarness
//
//  Created by Jesus Rojas on Nov 3, 2025.
//

import Foundation
import QuartzCore
import UIKit
import FirebasePerformance

final class ScreenRenderTrace: ObservableObject {
  private var displayLink: CADisplayLink?
  private var lastTimestamp: CFTimeInterval = 0
  private var targetFPS: Int = 60
  private var strict: Bool = true
  private var trace: Trace?

  func start(name: String, targetFPS: Int, strict: Bool) {
    stop()
    self.targetFPS = targetFPS
    self.strict = strict
    self.trace = Performance.startTrace(name: name)
    let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
    if #available(iOS 15.0, *) {
      link.preferredFrameRateRange = CAFrameRateRange(
        minimum: Float(strict ? targetFPS : 0),
        maximum: Float(targetFPS),
        preferred: Float(exactly: targetFPS)
      )
    } else {
      link.preferredFramesPerSecond = targetFPS
    }
    link.add(to: .main, forMode: .common)

    self.lastTimestamp = 0
    self.displayLink = link
  }

  @objc private func tick(_ link: CADisplayLink) {
    if lastTimestamp == 0 {
      lastTimestamp = link.timestamp
      return
    }
    let _ = link.timestamp - lastTimestamp
    lastTimestamp = link.timestamp
  }

  func stop() {
    displayLink?.invalidate()
    displayLink = nil
    lastTimestamp = 0
    trace?.stop()
    trace = nil
  }

  deinit {
    stop()
  }
}
