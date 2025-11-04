//
//  PongEngine.swift
//  DisplayLinkPerfHarness
//
//  Created by Jesus Rojas on Oct 31, 2025.
//

import SwiftUI
import Foundation
import QuartzCore
import CoreGraphics
import UIKit

final class PongEngine: ObservableObject {
  @Published var ballPosition: CGPoint = .zero
  @Published var ballSize: CGFloat = 16

  private var velocity = CGPoint(x: 180, y: 180) // points per second
  private var bounds: CGSize = .zero
  private var link: CADisplayLink?
  private var lastTimestamp: CFTimeInterval = 0

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

  func setBounds(_ size: CGSize) {
    bounds = size
    if ballPosition == .zero {
      ballPosition = CGPoint(x: size.width / 2, y: size.height / 2)
    }
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
  }

  @objc private func applicationDidEnterBackground() {
    link?.isPaused = true
  }

  @objc private func applicationWillEnterForeground() {
    link?.isPaused = false
  }

  @objc private func step(_ dl: CADisplayLink) {
    guard bounds.width > 0 && bounds.height > 0 else { return }
    if lastTimestamp == 0 { lastTimestamp = dl.timestamp; return }
    let dt = CGFloat(dl.timestamp - lastTimestamp)
    lastTimestamp = dl.timestamp

    var pos = ballPosition
    pos.x += velocity.x * dt
    pos.y += velocity.y * dt

    let r = ballSize / 2
    if pos.x - r < 0 { pos.x = r; velocity.x = abs(velocity.x) }
    if pos.x + r > bounds.width { pos.x = bounds.width - r; velocity.x = -abs(velocity.x) }
    if pos.y - r < 0 { pos.y = r; velocity.y = abs(velocity.y) }
    if pos.y + r > bounds.height { pos.y = bounds.height - r; velocity.y = -abs(velocity.y) }

    ballPosition = pos
  }
}
