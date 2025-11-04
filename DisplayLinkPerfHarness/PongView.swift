//
//  PongView.swift
//  DisplayLinkPerfHarness
//
//  Created by Jesus Rojas on Oct 31, 2025.
//

import SwiftUI

struct PongView: View {
  @ObservedObject var engine: PongEngine
  var body: some View {
    GeometryReader { geo in
      ZStack {
        Rectangle().fill(Color.black.opacity(0.05))
        Circle()
          .fill(Color.accentColor)
          .frame(width: engine.ballSize, height: engine.ballSize)
          .position(engine.ballPosition)
      }
      .background(
        GeometryReader { innerGeo in
          Color.clear
            .preference(key: PongSizeKey.self, value: innerGeo.size)
        }
      )
      .onPreferenceChange(PongSizeKey.self) { newSize in
        engine.setBounds(newSize)
      }
      .onAppear {
        // Fallback initial set
        engine.setBounds(geo.size)
      }
    }
  }
}

private struct PongSizeKey: PreferenceKey {
  static var defaultValue: CGSize = .zero
  static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
    value = nextValue()
  }
}
