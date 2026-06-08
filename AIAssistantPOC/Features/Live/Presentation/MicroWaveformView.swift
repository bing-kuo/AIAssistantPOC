//
//  MicroWaveformView.swift
//  AIAssistantPOC
//

import SwiftUI

struct MicroWaveformView: View {

    enum Mode: Equatable {
        case idle
        case reactive
        case synthetic
    }

    let rms: Float
    let mode: Mode

    private let weights: [CGFloat] = [0.5, 0.8, 1.0, 0.8, 0.5]
    private let minHeight: CGFloat = 4
    private let maxHeight: CGFloat = 24
    private let attack = 0.06
    private let release = 0.22
    private let noiseFloor: Float = -50

    @State private var envelope: CGFloat = 0

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: maxHeight)
            .onChange(of: rms) { _, newValue in
                let target = mode == .reactive ? conditioned(newValue) : 0
                withAnimation(.easeOut(duration: target >= envelope ? attack : release)) {
                    envelope = target
                }
            }
            .onChange(of: mode) { _, newValue in
                if newValue != .reactive {
                    withAnimation(.easeOut(duration: release)) { envelope = 0 }
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch mode {
        case .reactive: reactiveBars
        case .synthetic: syntheticBars
        case .idle: idleBars
        }
    }

    private var reactiveBars: some View {
        HStack(spacing: 3) {
            ForEach(weights.indices, id: \.self) { index in
                bar(height: minHeight + (maxHeight - minHeight) * weights[index] * envelope)
            }
        }
    }

    private var syntheticBars: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            HStack(spacing: 3) {
                ForEach(weights.indices, id: \.self) { index in
                    let pulse = sin(time * 3 + Double(index) * 0.6) * 0.5 + 0.5
                    bar(height: minHeight + (maxHeight - minHeight) * (0.25 + 0.35 * pulse) * weights[index])
                }
            }
        }
    }

    private var idleBars: some View {
        HStack(spacing: 3) {
            ForEach(weights.indices, id: \.self) { _ in
                bar(height: minHeight).opacity(0.3)
            }
        }
    }

    private func bar(height: CGFloat) -> some View {
        Capsule()
            .fill(.tint)
            .frame(height: height)
    }

    private func conditioned(_ rms: Float) -> CGFloat {
        guard rms > 0 else { return 0 }
        let decibels = 20 * log10(rms)
        guard decibels > noiseFloor else { return 0 }
        let normalized = (decibels - noiseFloor) / -noiseFloor
        return CGFloat(min(max(normalized, 0), 1))
    }
}

#Preview {
    HStack(spacing: 24) {
        MicroWaveformView(rms: 0, mode: .idle)
        MicroWaveformView(rms: 0, mode: .synthetic)
        MicroWaveformView(rms: 0.05, mode: .reactive)
    }
    .frame(height: 24)
    .tint(.blue)
    .padding()
}
