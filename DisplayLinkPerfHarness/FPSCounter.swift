//
//  FPSCounter.swift
//  DisplayLinkPerfHarness
//
//  Created by Jesus Rojas on Oct 31, 2025.
//

import SwiftUI
import Foundation
import QuartzCore
import UIKit

final class FPSCounter: ObservableObject {
  @Published var fps: Int = 0
  private var link: CADisplayLink?
  private var lastTimestamp: CFTimeInterval = 0
  private var frameCount: Int = 0

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

  func start(frameRate: Int, strict: Bool) {
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

  func stop() {
    link?.invalidate(); link = nil
    lastTimestamp = 0
    frameCount = 0
    fps = 0
  }

  @objc private func applicationDidEnterBackground() {
    link?.isPaused = true
  }

  @objc private func applicationWillEnterForeground() {
    link?.isPaused = false
  }

  @objc private func step(_ dl: CADisplayLink) {
    if lastTimestamp == 0 { lastTimestamp = dl.timestamp; return }
    frameCount += 1
    let dt = dl.timestamp - lastTimestamp
    if dt >= 1.0 {
      fps = Int(round(Double(frameCount) / dt))
      frameCount = 0
      lastTimestamp = dl.timestamp
    }
  }
}

