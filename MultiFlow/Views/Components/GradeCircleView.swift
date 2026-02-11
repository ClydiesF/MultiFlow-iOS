import SwiftUI
import UIKit

struct GradeCircleView: View {
    let grade: Grade

    @State private var didAppear = false
    @State private var currentStep: CGFloat = 0
    @State private var isSpinning = false
    @State private var hasRevealedOnce = false

    private let size: CGFloat = 60
    private let gold = Color(red: 1.0, green: 215.0 / 255.0, blue: 0.0)
    private let grades = ["F", "E", "D", "C", "B", "A"]

    var body: some View {
        ZStack {
            Circle()
                .fill(.thinMaterial)
                .overlay(
                    Circle()
                        .fill(Color.black.opacity(0.85))
                )

            Circle()
                .stroke(
                    AngularGradient(
                        colors: [
                            Color.white.opacity(0.10),
                            Color.white.opacity(0.40),
                            Color.black.opacity(0.10)
                        ],
                        center: .center
                    ),
                    lineWidth: 1.5
                )

            GradeDialView(
                sequence: dialSequence,
                step: currentStep,
                isSpinning: isSpinning,
                gold: gold,
                dialSize: size
            )
        }
        .frame(width: size, height: size)
        .scaleEffect(didAppear ? 1 : 0.82)
        .shadow(
            color: grade == .a ? Color.yellow.opacity(0.15) : .clear,
            radius: grade == .a ? 10 : 0,
            x: 0,
            y: grade == .a ? 5 : 0
        )
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) {
                didAppear = true
            }
            if !hasRevealedOnce {
                hasRevealedOnce = true
                currentStep = CGFloat(gradeIndex(for: displayGrade))
                revealGrade(finalGrade: displayGrade)
            }
        }
        .onChange(of: displayGrade) { _, newValue in
            revealGrade(finalGrade: newValue)
        }
    }

    private func revealGrade(finalGrade: String) {
        guard let targetIndex = grades.firstIndex(of: finalGrade) else { return }
        if !isSpinning && Int(currentStep.rounded()) % grades.count == targetIndex {
            currentStep = CGFloat(targetIndex)
            return
        }

        let normalizedCurrent = Int(currentStep.rounded()) % grades.count
        let cycles = 2
        let finalStep = cycles * grades.count + targetIndex
        let totalSteps = max(finalStep - normalizedCurrent, 1)

        let selectionGenerator = UISelectionFeedbackGenerator()
        selectionGenerator.prepare()

        let heavyGenerator = UIImpactFeedbackGenerator(style: .heavy)
        heavyGenerator.prepare()

        isSpinning = true

        for step in 0..<totalSteps {
            let progress = Double(step) / Double(max(totalSteps, 1))
            let delay = progress * 0.48
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                selectionGenerator.selectionChanged()
            }
        }

        withAnimation(.spring(response: 0.6, dampingFraction: 0.7, blendDuration: 0)) {
            currentStep = CGFloat(finalStep)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.58) {
            isSpinning = false
            heavyGenerator.impactOccurred(intensity: 0.95)
            withTransaction(Transaction(animation: .none)) {
                currentStep = CGFloat(targetIndex)
            }
        }
    }

    private func gradeIndex(for letter: String) -> Int {
        grades.firstIndex(of: letter) ?? 0
    }

    private var dialSequence: [String] {
        Array(repeating: grades, count: 3).flatMap { $0 }
    }

    private var displayGrade: String {
        switch grade {
        case .a: return "A"
        case .b: return "B"
        case .c: return "C"
        case .dOrF: return "F"
        }
    }
}

private struct GradeDialView: View {
    let sequence: [String]
    let step: CGFloat
    let isSpinning: Bool
    let gold: Color
    let dialSize: CGFloat

    var body: some View {
        let snappedStep = isSpinning ? step : step.rounded()
        let restingIndex = min(max(Int(snappedStep), 0), max(sequence.count - 1, 0))
        let restingLetter = sequence.isEmpty ? "F" : sequence[restingIndex]

        ZStack {
            VStack(spacing: 0) {
                ForEach(Array(sequence.enumerated()), id: \.offset) { _, letter in
                    Text(letter)
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .foregroundStyle(gold)
                        .lineLimit(1)
                        .frame(width: dialSize, height: dialSize, alignment: .center)
                }
            }
            .offset(y: -(snappedStep * dialSize))
            .blur(radius: isSpinning ? 2.5 : 0)
            .opacity(isSpinning ? 1 : 0)
            .frame(width: dialSize, height: dialSize, alignment: .center)
            .clipped()

            Text(restingLetter)
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundStyle(gold)
                .lineLimit(1)
                .frame(width: dialSize, height: dialSize, alignment: .center)
                .opacity(isSpinning ? 0 : 1)
        }
        .frame(width: dialSize, height: dialSize, alignment: .center)
    }
}

#Preview {
    VStack(spacing: 16) {
        GradeCircleView(grade: .a)
        GradeCircleView(grade: .b)
        GradeCircleView(grade: .c)
        GradeCircleView(grade: .dOrF)
    }
    .padding(24)
    .background(Color.black)
}
