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

        VStack(alignment: .leading, spacing: 16) {
            // 凡例（体重専用）
            HStack(spacing: 16) {
                legendItem(label: "実測値", color: .teal, isLine: false)
                legendItem(label: "推測値", color: .orange, isLine: true)
            }

            if trendData.isEmpty {
                Text("この期間のデータがありません").foregroundColor(.secondary).frame(height: 250)
            } else {
                Chart {
                    ForEach(trendData) { item in
                        if let predicted = item.predictedWeight {
                            LineMark(x: .value("日付", item.date, unit: .day), y: .value("予測", predicted), series: .value("系列", "予測"))
                                .foregroundStyle(.orange).lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                        }
                        if let actual = item.actualWeight {
                            LineMark(x: .value("日付", item.date, unit: .day), y: .value("実測", actual),series: .value("系列", "実測"))
                                .foregroundStyle(.teal)
                            PointMark(x: .value("日付", item.date, unit: .day), y: .value("実測", actual))
                                .foregroundStyle(.teal).symbolSize(30)
                        }
                    }
                    if let selectedDate {
                        RuleMark(x: .value("Selected", selectedDate, unit: .day))
                            .foregroundStyle(.separator).zIndex(-1)
                    }
                }
                .chartXSelection(value: $selectedDate)
                .chartYScale(domain: .automatic(includesZero: false))
                .chartXScale(domain: graphStartDate...Date())
                .chartXAxis {
                    // 自身で計算した axisValues を直接渡す
                    AxisMarks(values: axisValues) { value in
                        if let date = value.as(Date.self) {
                            let day = Calendar.current.component(.day, from: date)
                            
                            AxisGridLine()
                            
                            // 1日は非表示にする、あるいは月名を表示するなどの制御が可能
                            if day != 1 {
                                AxisValueLabel(format: .dateTime.day())
                            } else {
                                // 1日の代わりに月を表示すると、より親切です（不要なら空文字）
                                AxisValueLabel(format: .dateTime.month(.narrow))
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        if let kgValue = value.as(Double.self) {
                            AxisValueLabel {
                                Text("\(Int(kgValue)) kg")
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
        }
    }

    // --- 以下、専用のヘルパー関数群 ---
    private func popoverView(data: WeightChartData) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(data.date, format: .dateTime.month().day().weekday()).font(.system(size: 15, weight: .bold))
            HStack(spacing: 12) {
                if let actual = data.actualWeight { popoverValueStack(title: "実測", value: actual, color: .teal) }
                if let predicted = data.predictedWeight { popoverValueStack(title: "理論", value: predicted, color: .orange) }
            }
        }
        .padding(8).background(.ultraThinMaterial).cornerRadius(8).shadow(radius: 2)
    }

    private func popoverValueStack(title: String, value: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title).font(.system(size: 12)).foregroundColor(color)
            Text("\(String(format: "%.2f", value))kg").font(.system(size: 15, weight: .bold, design: .monospaced))
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
        var currentDate = calendar.startOfDay(for: graphStartDate)
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
            
            // 1日は無条件に追加
            if day == 1 {
                dates.append(currentDate)
            }
            // 指定の間隔（5, 10...）の場合
            else if day % dynamicStride == 0 {
                // 前後の日付を確認し、1日と近すぎる（例：2日前後、あるいは月末付近）場合は追加しない
                // これにより「30」と「次月1日」の衝突を防ぐ
                let isNearMonthEnd = day > 27 // 月末付近の数字は1日と被りやすいので捨てる
                let isNearMonthStart = day < 3 // 月初付近も同様
                
                if !isNearMonthEnd && !isNearMonthStart {
                    dates.append(currentDate)
                }
            }
            
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }
        return dates
    }
}
