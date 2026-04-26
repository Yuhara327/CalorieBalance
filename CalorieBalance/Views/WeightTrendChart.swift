//
//  WeightTrendChart.swift
//  CalorieBalance
//
//  Created by Soichiro Yuhara on 2026/03/19.
//

import SwiftUI
import Charts

struct WeightTrendChart: View {
    @ObservedObject var viewModel: CalorieBalanceViewModel
    let graphStartDate: Date
    @Binding var selectedDate: Date?

    var body: some View {
        let trendData = viewModel.calculateWeightTrend(from: graphStartDate)
        let axisValues = calculateAxisValues(startDate: graphStartDate)
        let latestCompleteData = trendData.last { $0.actualWeight != nil && $0.predictedWeight != nil }

        VStack(alignment: .leading, spacing: 16) {
            // 凡例の多言語化
            HStack(spacing: 16) {
                legendItem(label: String(localized: "実測値"), color: .teal, isLine: false)
                legendItem(label: String(localized: "推測値"), color: .orange, isLine: true)
            }

            if trendData.isEmpty {
                Text(String(localized: "この期間のデータがありません"))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center) // 中央揃えを追加
                    .frame(height: 250)
            } else {
                Chart {
                    ForEach(trendData) { item in
                        if let predicted = item.predictedWeight {
                            LineMark(x: .value("日付", item.date, unit: .day), y: .value("予測", predicted), series: .value("系列", "予測"))
                                .foregroundStyle(.orange)
                                .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                        }
                        if let actual = item.actualWeight {
                            LineMark(x: .value("日付", item.date, unit: .day), y: .value("実測", actual), series: .value("系列", "実測"))
                                .foregroundStyle(.teal)
                                .interpolationMethod(.catmullRom)
                            PointMark(x: .value("日付", item.date, unit: .day), y: .value("実測", actual))
                                .foregroundStyle(.teal).symbolSize(30)
                        }
                    }
                    if let selectedDate {
                        RuleMark(x: .value("Selected", selectedDate, unit: .day))
                            .foregroundStyle(.separator).zIndex(-1)
                    }
                }
                .chartXSelection(value: Binding<Date?>(
                    get: { selectedDate },
                    set: { newValue in
                        guard let date = newValue else {
                            selectedDate = nil
                            return
                        }
                        // trendData の最後の日付を超えないように制限
                        if let lastDate = trendData.last?.date {
                            selectedDate = min(date, lastDate)
                        } else {
                            selectedDate = date
                        }
                    }
                ))
                .chartYScale(domain: .automatic(includesZero: false))
                .chartXAxis {
                    // values に axisValues を渡すことで、目盛りの範囲を厳密に制御
                    AxisMarks(values: axisValues) { value in
                        if let date = value.as(Date.self) {
                            let day = Calendar.current.component(.day, from: date)
                            AxisGridLine()
                            if day != 1 {
                                AxisValueLabel(format: .dateTime.day())
                            } else {
                                AxisValueLabel(format: .dateTime.month(.narrow))
                            }
                        }
                    }
                }
                // グラフのプロット領域に適切な内側の余白（インセット）を持たせる
                .chartXAxis(.visible)
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        if let kgValue = value.as(Double.self) {
                            AxisValueLabel {
                                // 重要修正：Measurement API で軸の単位も自動化
                                let measurement = Measurement(value: kgValue, unit: UnitMass.kilograms)
                                Text(measurement.formatted(.measurement(width: .abbreviated, usage: .personWeight)))
                            }
                        }
                    }
                }
                .frame(height: 250)
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        if let selectedDate, let data = trendData.first(where: { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }) {
                            let dateX = proxy.position(forX: data.date) ?? 0
                            popoverView(data: data)
                                .position(x: calculatePopoverX(dateX: dateX, geometry: geometry), y: 20)
                        }
                    }
                }
            }
            
            if let data = latestCompleteData,
               let actual = data.actualWeight,
               let predicted = data.predictedWeight {
                let gap = actual - predicted
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .foregroundColor(.teal)
                        Text(String(localized: "現在のトレンド感"))
                            .font(.headline)
                    }
                    
                    Text(gap > 0.5 ? String(localized: "予測を上回る推移（停滞傾向）") : (gap < -0.5 ? String(localized: "予測を下回る推移（加速傾向）") : String(localized: "予測通りの安定した推移")))
                        .font(.subheadline)
                        .bold()
                        .foregroundColor(gap > 0.5 ? .orange : (gap < -0.5 ? .teal : .primary))

                    // 重要修正：一文として構成し、Catalogに文脈を伝える
                    let gapMeasurement = Measurement(value: abs(gap), unit: UnitMass.kilograms)
                    let formattedGap = gapMeasurement.formatted(.measurement(width: .abbreviated, usage: .personWeight))
                    let sign = gap >= 0 ? "+" : "-"
                    
                    Text("理論上の予測体重に対し、現在は実測値が \(sign)\(formattedGap) 乖離しています。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                // 【修正2】カードを画面幅いっぱいまで広げる
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(12)
            }
        }
    }

    private func popoverView(data: WeightChartData) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(data.date, format: .dateTime.month().day().weekday()).font(.system(size: 15, weight: .bold))
            HStack(spacing: 12) {
                if let actual = data.actualWeight { popoverValueStack(title: String(localized: "実測"), value: actual, color: .teal) }
                if let predicted = data.predictedWeight { popoverValueStack(title: String(localized: "理論"), value: predicted, color: .orange) }
            }
        }
        .padding(8).background(.ultraThinMaterial).cornerRadius(8).shadow(radius: 2)
    }

    private func popoverValueStack(title: String, value: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title).font(.system(size: 12)).foregroundColor(color)
            // 重要修正：ポップオーバーも Measurement で一文に
            let m = Measurement(value: value, unit: UnitMass.kilograms)
            Text(m.formatted(.measurement(width: .abbreviated, usage: .personWeight)))
                .font(.system(size: 15, weight: .bold, design: .monospaced))
        }
    }

    private func calculatePopoverX(dateX: CGFloat, geometry: GeometryProxy) -> CGFloat {
        let minX: CGFloat = 50
        let maxX: CGFloat = geometry.size.width - 50
        return min(max(dateX, minX), maxX)
    }

    private func legendItem(label: String, color: Color, isLine: Bool) -> some View {
        HStack(spacing: 4) {
            if isLine { Rectangle().fill(color).frame(width: 16, height: 2) }
            else { Circle().fill(color).frame(width: 8, height: 8) }
            Text(label).font(.caption).foregroundColor(.secondary)
        }
    }

    private func calculateAxisValues(startDate: Date) -> [Date] {
        let calendar = Calendar.current
        var dates: [Date] = []
        var currentDate = calendar.startOfDay(for: startDate)
        let endDate = calendar.startOfDay(for: Date())
        let daysCount = calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 30
        let dynamicStride: Int = {
            if daysCount <= 14 { return 2 }
            if daysCount <= 45 { return 5 }
            if daysCount <= 100 { return 15 }
            return 31
        }()

        while currentDate <= endDate {
            let day = calendar.component(.day, from: currentDate)
            if day == 1 {
                dates.append(currentDate)
            } else if day % dynamicStride == 0 {
                let isNearMonthEnd = day > 27
                let isNearMonthStart = day < 3
                if !isNearMonthEnd && !isNearMonthStart {
                    dates.append(currentDate)
                }
            }
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
            currentDate = nextDate
        }
        return dates
    }
}

#Preview {
    WeightTrendChart(
        viewModel: CalorieBalanceViewModel(previewData: DailyMetrics.mockData),
        graphStartDate: Calendar.current.date(byAdding: .day, value: -30, to: Date())!,
        selectedDate: .constant(nil)
    )
    .padding()
    .background(Color.black.opacity(0.1))
}
