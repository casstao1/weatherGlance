import SwiftUI

struct InlineSummaryView: View {
    let condition: WeatherCondition
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            WeatherIconView(condition: condition)
                .frame(width: 12, height: 12)
            Text(text)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .lineLimit(1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(condition.accessibilityLabel), \(text)")
    }
}

#Preview {
    InlineSummaryView(condition: .sunny, text: "72° → 78°")
        .padding()
        .background(Color.black)
        .foregroundStyle(.white)
}
