//
//  DisplayLinkPerfApp.swift
//  DisplayLinkPerfHarness
//
//  Created by Jesus Rojas on Oct 30, 2025.
//

import SwiftUI
import QuartzCore
import FirebaseCore
import FirebasePerformance
import UIKit

struct ContentView: View {
  @StateObject private var mgr = TrackerManager()
  @State private var trackerCount: Double = 3
  @State private var fpsIndex: Int = 1
  @State private var sharedLink: Bool = true
  @State private var strictFPS: Bool = true
  @State private var workMicros: Double = 0
  @State private var running = false

  @StateObject private var fpsCounter = FPSCounter()
  @StateObject private var pongEngine = PongEngine()
  @StateObject private var screenTrace = ScreenRenderTrace()

  var body: some View {
    VStack(spacing: 16) {
      Text("DisplayLink Stress Tester").font(.title2).bold()

      HStack {
        Picker("Rate", selection: $fpsIndex) {
          Text("60 Hz").tag(0)
          Text("120 Hz").tag(1)
        }.pickerStyle(.segmented)
        Spacer()
        Toggle("Shared", isOn: $sharedLink)
          .toggleStyle(.switch)
          .controlSize(.small)
        Toggle("Strict", isOn: $strictFPS)
          .toggleStyle(.switch)
          .controlSize(.small)
        Spacer()
      }
      HStack(spacing: 12) {
        Text("Max FPS: \(UIScreen.main.maximumFramesPerSecond)")
        Text("Target: \(fpsIndex == 0 ? 60 : 120)\(strictFPS ? " strict" : " flex")")
      }
      .font(.caption)
      .foregroundStyle(.secondary)

      HStack {
        Text("Trackers: \(Int(trackerCount))")
        Slider(value: $trackerCount, in: 1...12, step: 1)
      }

      VStack(alignment: .leading) {
        Text("Work per tick (µs): \(Int(workMicros))")
        Slider(value: $workMicros, in: 0...5000, step: 100)
      }

      VStack(alignment: .leading, spacing: 8) {
        Text("Pong visualization").font(.headline)
        PongView(engine: pongEngine)
          .frame(height: 180)
          .clipShape(RoundedRectangle(cornerRadius: 12))
          .overlay(alignment: .topTrailing) {
            Text("\(fpsCounter.fps) fps")
              .font(.caption)
              .monospacedDigit()
              .padding(.horizontal, 8)
              .padding(.vertical, 4)
              .background(Color.black.opacity(0.5))
              .foregroundStyle(.white)
              .clipShape(Capsule())
              .padding(8)
          }
          .overlay(
            RoundedRectangle(cornerRadius: 12)
              .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
          )
      }

      HStack {
        // Note: We request 60/120 Hz via CADisplayLink.preferredFrameRateRange. Scene/screen-level APIs vary by SDK.
        Button(running ? "Stop" : "Start") {
          if running {
            mgr.stopAll()
            fpsCounter.stop()
            pongEngine.stop()
            screenTrace.stop()
          } else {
            let fps = fpsIndex == 0 ? 60 : 120
            mgr.configure(
              count: Int(trackerCount),
              sharedLinkMode: sharedLink,
              frameRate: fps,
              workMicros: Int(workMicros),
              strict: strictFPS
            )
            fpsCounter.start(frameRate: fps, strict: strictFPS)
            pongEngine.start(frameRate: fps, strict: strictFPS)
            screenTrace.start(name: "Screen_ContentView", targetFPS: fps, strict: strictFPS)
          }
          running.toggle()
        }.buttonStyle(.borderedProminent)

        Button("Reset counters") {
          if running {
            let count = mgr.trackers.count
            let fps = fpsIndex == 0 ? 60 : 120
            mgr.configure(count: count, sharedLinkMode: sharedLink, frameRate: fps, workMicros: Int(workMicros), strict: strictFPS)
            fpsCounter.start(frameRate: fps, strict: strictFPS)
            pongEngine.start(frameRate: fps, strict: strictFPS)
            screenTrace.start(name: "Screen_ContentView", targetFPS: fps, strict: strictFPS)
          }
        }.buttonStyle(.bordered)
      }

      if !mgr.trackers.isEmpty {
        let totals = mgr.trackers.reduce(Int64(0)) { $0 + $1.total }
        let slows = mgr.trackers.reduce(Int64(0)) { $0 + $1.slow }
        let frozens = mgr.trackers.reduce(Int64(0)) { $0 + $1.frozen }
        let agg = (t: totals, s: slows, f: frozens)
        VStack(alignment: .leading, spacing: 8) {
          Text("Aggregate").font(.headline)
          HStack { Stat("Total", agg.t); Stat("Slow", agg.s); Stat("Frozen", agg.f) }
          Divider()
          ScrollView {
            LazyVStack(alignment: .leading, spacing: 6) {
              ForEach(Array(mgr.trackers.enumerated()), id: \.offset) { idx, t in
                HStack {
                  Text("#\(idx + 1)").frame(width: 30, alignment: .leading).monospaced()
                  Stat("T", t.total); Stat("S", t.slow); Stat("F", t.frozen)
                }
              }
            }
          }.frame(maxHeight: 240)
        }
      } else {
        Spacer()
      }

    }
    .padding()
  }
}

@main
struct DisplayLinkStressTesterApp: App {
  init() {
    FirebaseApp.configure()
    Performance.sharedInstance().isDataCollectionEnabled = true
    Performance.sharedInstance().isInstrumentationEnabled = true
  }
  var body: some Scene { WindowGroup { ContentView() } }
}

private struct Stat: View {
  let title: String; let value: Int64
  init(_ t: String, _ v: Int64) { title = t; value = v }
  var body: some View {
    HStack(spacing: 6) {
      Text(title).font(.caption2).bold()
      Text("\(value)").font(.caption).monospaced()
    }
    .padding(.horizontal, 8).padding(.vertical, 6)
    .background(Color.secondary.opacity(0.15))
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }
}
