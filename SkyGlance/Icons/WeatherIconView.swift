import SwiftUI

struct WeatherIconView: View {
    let condition: WeatherCondition

    var body: some View {
        GeometryReader { geo in
            Image(systemName: condition.sfSymbol)
                .resizable()
                .scaledToFit()
                .frame(width: geo.size.width, height: geo.size.height)
                .accessibilityLabel(condition.accessibilityLabel)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

// MARK: – Preview

#Preview {
    HStack(spacing: 12) {
        ForEach(WeatherCondition.allCases, id: \.self) { cond in
            WeatherIconView(condition: cond)
                .frame(width: 32, height: 32)
                .foregroundStyle(.primary)
        }
    }
    .padding()
}
