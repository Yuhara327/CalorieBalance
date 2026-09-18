import Charts
import SwiftUI

struct EnergyBalanceChart: View {
    let projection: EnergyBalanceProjection
    private let chartAxisLabel = ""

    private var chartMaximum: Double {
        let dietaryCalories: Double = projection.dietaryCalories ?? 0.0
        let targetIntakeCalories: Double = projection.targetIntakeCalories ?? 0.0
        let values: [Double] = [
            projection.burnedCalories,
            dietaryCalories,
            targetIntakeCalories
        ]
        let maximumValue: Double = values.max() ?? 1.0
        return max(maximumValue * 1.12, 1.0)
    }

    private var burnedTitle: String {
        projection.isForecast ? String(localized: "予想消費") : String(localized: "消費")
    }

    private var netTitle: String {
        projection.isForecast ? String(localized: "予想収支") : String(localized: "収支")
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                metricLabel(
                    title: burnedTitle,
                    value: projection.burnedCalories,
                    color: .green
                )

                Spacer(minLength: 4)

                metricLabel(
                    title: String(localized: "摂取"),
                    value: projection.dietaryCalories,
                    color: .red,
                    alignment: .trailing
                )
            }

            Chart {
                BarMark(
                    xStart: .value(chartAxisLabel, 0.0),
                    xEnd: .value(burnedTitle, projection.burnedCalories),
                    y: .value(chartAxisLabel, 0),
                    height: .fixed(40)
                )
                .foregroundStyle(Color.green.opacity(0.8))
                .cornerRadius(8)

                if let dietaryCalories = projection.dietaryCalories {
                    BarMark(
                        xStart: .value(chartAxisLabel, 0.0),
                        xEnd: .value(String(localized: "摂取"), dietaryCalories),
                        y: .value(chartAxisLabel, 0),
                        height: .fixed(25)
                    )
                    .foregroundStyle(Color.red.opacity(0.9))
                    .cornerRadius(7)
                }

                if let targetIntakeCalories = projection.targetIntakeCalories {
                    RuleMark(x: .value(String(localized: "目標"), targetIntakeCalories))
                        .foregroundStyle(Color.orange)
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 4]))
                }
            }
            .chartXScale(domain: 0...chartMaximum)
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .frame(height: 48)
            .accessibilityLabel(String(localized: "エネルギーバランス"))
            .accessibilityValue(accessibilitySummary)

            if let targetIntakeCalories = projection.targetIntakeCalories {
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(.orange)
                        .frame(width: 18, height: 3)
                    Text(String(localized: "目標"))
                    Text(verbatim: "\(Int(targetIntakeCalories)) kcal")
                        .bold()
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()

            HStack(alignment: .firstTextBaseline) {
                Text(netTitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()

                if let netCalories = projection.netCalories {
                    Text(verbatim: "\(signedCalories(netCalories)) kcal")
                        .font(.system(.title2, design: .rounded))
                        .bold()
                        .foregroundColor(netCalories <= 0 ? .green : .red)
                } else {
                    Text(verbatim: "-- kcal")
                        .font(.system(.title2, design: .rounded))
                        .bold()
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(16)
    }

    private var accessibilitySummary: String {
        let burned = "\(burnedTitle) \(Int(projection.burnedCalories)) kcal"
        let intake = projection.dietaryCalories.map { "摂取 \(Int($0)) kcal" } ?? "摂取データなし"
        let net = projection.netCalories.map { "\(netTitle) \(Int($0)) kcal" } ?? "収支データなし"
        return "\(burned)、\(intake)、\(net)"
    }

    private func signedCalories(_ value: Double) -> String {
        guard abs(value) >= 0.5 else { return "0" }
        return value.formatted(
            .number
                .precision(.fractionLength(0))
                .sign(strategy: .always())
        )
    }

    private func metricLabel(
        title: String,
        value: Double?,
        color: Color,
        alignment: HorizontalAlignment = .leading
    ) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            HStack(spacing: 5) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(color.opacity(0.8))
                    .frame(width: 10, height: 10)
                Text(title)
            }
            .font(.caption)
            .foregroundColor(.secondary)

            Text(verbatim: value.map { "\(Int($0)) kcal" } ?? "-- kcal")
                .font(.subheadline)
                .bold()
                .foregroundColor(color)
        }
    }
}

private struct EnergyBalanceChartPreview: View {
    private let projection = EnergyBalanceProjection(
            burnedCalories: 2350,
            dietaryCalories: 1200,
            netCalories: -1150,
            targetIntakeCalories: 1850,
            isForecast: true
        )

    var body: some View {
        ZStack {
            AdvancedBackgroundView()

            EnergyBalanceChart(projection: projection)
                .glassEffect(in: .rect(cornerRadius: 30.0))
                .padding()
        }
    }
}

#Preview("今日・目標あり") {
    EnergyBalanceChartPreview()
}
