//
//  SleepTrendChart.swift
//  CalorieBalance
//
//  Created by Soichiro Yuhara on 2026/03/20.
//

import SwiftUI
import Charts

struct SleepTrendChart: View {
    @ObservedObject var viewModel: CalorieBalanceViewModel
    let graphStartDate: Date
    @Binding var selectedDate: Date?

    var body: some View {
        let trendData = viewModel.calculateSleepData(from: graphStartDate)
        let axisValues = calculateAxisValues(startDate: graphStartDate)
        let dailyAbsMax = trendData.map { abs($0.dailyNet) }.max() ?? 0.0
        let calorieRange = max(dailyAbsMax * 1.5, 100.0) // 最低でも100を確保
        let sleepMax = 13.0
        let sleepScaleFactor = (calorieRange * 2.0) / sleepMax
        // 相関係数 r の計算
        let correlationValue: Double? = {
            let validData = trendData.filter { $0.sleep > 0 }
            guard validData.count > 2 else { return nil }
            
            let n = Double(validData.count)
            let sumX = validData.map { $0.sleep }.reduce(0, +)
            let sumY = validData.map { $0.dailyNet }.reduce(0, +)
            let sumXY = validData.map { $0.sleep * $0.dailyNet }.reduce(0, +)
            let sumX2 = validData.map { $0.sleep * $0.sleep }.reduce(0, +)
            let sumY2 = validData.map { $0.dailyNet * $0.dailyNet }.reduce(0, +)
            
            let numerator = (n * sumXY) - (sumX * sumY)
            let denominator = sqrt((n * sumX2 - pow(sumX, 2)) * (n * sumY2 - pow(sumY, 2)))
            
            return denominator == 0 ? 0 : numerator / denominator
        }()
        VStack(alignment: .leading, spacing: 16) {
            // 凡例（体重専用）
            HStack(spacing: 16) {
                legendItem(label: "消費超過", color: .green, isLine: false)
                legendItem(label: "摂取超過", color: .red, isLine: false)
                legendItem(label: "睡眠(上下反転)", color: .indigo, isLine: true)
            }

            if trendData.isEmpty {
                Text("この期間のデータがありません").foregroundColor(.secondary).frame(height: 250)
            } else {
                Chart {
                    ForEach(trendData) { item in
                        BarMark(x: .value("日付", item.date, unit: .day), y: .value("日次", item.dailyNet))
                            .foregroundStyle(item.dailyNet <= 0 ? .green : .red)
                    }
                    ForEach(trendData) { item in
                        let mappedSleep = calorieRange - (item.sleep * sleepScaleFactor)
                        LineMark(x: .value("日付", item.date, unit: .day), y: .value("睡眠", mappedSleep), series: .value("系列", "睡眠"))
                            .foregroundStyle(.indigo)
                            .interpolationMethod(.catmullRom)
                        PointMark(x: .value("日付", item.date, unit: .day), y: .value("合計", mappedSleep))
                            .foregroundStyle(.indigo).symbolSize(40)

                    }
                    if let selectedDate {
                        RuleMark(x: .value("Selected", selectedDate, unit: .day))
                            .foregroundStyle(.separator).zIndex(2)
                            .shadow(color: .white, radius: 0, x: 1, y: 1)
                            .shadow(color: .white, radius: 0, x: -1, y: -1)
                    }
                }
                .chartXSelection(value: $selectedDate)
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
                .chartYScale(domain: -calorieRange...calorieRange) // これで中央が0になる
                .chartYAxis {
                    // 左軸：カロリー
                    AxisMarks(position: .leading)

                    // 右軸：睡眠（ラベルも反転して配置）
                    let sleepLabels: [Double] = [0, 4, 8, 12]
                    AxisMarks(position: .trailing, values: sleepLabels.map { calorieRange - ($0 * sleepScaleFactor) }) { value in
                        if let yVal = value.as(Double.self) {
                            AxisValueLabel {
                                // 1. yVal から sleep を逆算
                                let h = (calorieRange - yVal) / sleepScaleFactor
                                
                                // 2. 数値が有限（Finite）であることを確認し、文字列補完内でフォーマット
                                if h.isFinite {
                                    Text("\(h, format: .number.precision(.fractionLength(0)))h")
                                        .foregroundColor(.indigo)
                                } else {
                                    Text("--h")
                                        .foregroundColor(.indigo)
                                }
                            }
                        }
                    }
                }                .frame(height: 250)
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
            if let r = correlationValue {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "bed.double.fill")
                            .foregroundColor(.indigo)
                        Text("睡眠と収支の相関分析")
                            .font(.headline)
                    }

                    // 相関の解釈
                    // 一般的に |r| > 0.4 で相関あり、r < 0 は負の相関（睡眠増 → 収支減 = 良い傾向）
                    let interpretation: String = {
                        if abs(r) < 0.2 { return "明確な相関は見られません" }
                        if r <= -0.2 { return "睡眠が長いほど、摂取が抑えられる傾向にあります" }
                        if r >= 0.2 { return "睡眠が長いほど、摂取が増える傾向にあります（要分析）" }
                        return "分析中"
                    }()

                    Text(interpretation)
                        .font(.subheadline)
                        .bold()
                        .foregroundColor(r <= -0.2 ? .green : (r >= 0.2 ? .orange : .primary))

                    Text("相関係数 \(Text(String(format: "r = %.2f", r)).bold())")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("※ 一般に睡眠不足は食欲増進ホルモンを増やし、ダイエットを妨げます。")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.top, 2)
                }
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(12)
            }
        }
    }
    // --- 以下、専用のヘルパー関数群 ---
    private func popoverView(data: SleepChartData) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(data.date, format: .dateTime.month().day().weekday()).font(.system(size: 15, weight: .bold))
            HStack(spacing: 12) {
                popoverValueStack(title: "睡眠", value: data.sleep, color: .indigo)
                let dailyColor: Color = data.dailyNet <= 0 ? .green : .red
                popoverValueStack(title: "日次収支", value: data.dailyNet, color: dailyColor)

            }
        }
        .padding(8).background(.ultraThinMaterial).cornerRadius(8).shadow(radius: 2)
    }

    private func popoverValueStack(title: String, value: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // 項目名（合計収支 or 睡眠）
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(color)
            // 数値と単位の出し分け
            Text(title == "睡眠" ? String(format: "%.1f h", value) : String(format: "%.0f kcal", value))
                .font(.system(size: 15, weight: .bold, design: .monospaced))
        }
    }
    private func calculatePopoverX(dateX: CGFloat, geometry: GeometryProxy) -> CGFloat {
        let minX: CGFloat = 50
        let maxX: CGFloat = geometry.size.width - 50
        return min(max(dateX, minX), maxX)
    }

    private func legendItem(label: String, color: Color, isLine: Bool) -> some View {
        HStack(spacing: 6) {
            if isLine {
                // 折れ線を模した横長のデザイン
                RoundedRectangle(cornerRadius: 1)
                    .fill(color)
                    .frame(width: 18, height: 3)
            } else {
                // 棒グラフやプロット点を模したデザイン
                RoundedRectangle(cornerRadius: 2)
                    .fill(color.opacity(0.8))
                    .frame(width: 12, height: 12)
            }
            
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
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
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
            currentDate = nextDate
        }
        return dates
    }
}


#Preview {
    // プレビュー用に一時的な状態を保持する場所がないため、
    // シンプルに表示を確認するだけなら .constant を使います。
    SleepTrendChart(
        viewModel: CalorieBalanceViewModel(previewData: DailyMetrics.mockData),
        graphStartDate: Calendar.current.date(byAdding: .day, value: -30, to: Date())!,
        selectedDate: .constant(nil) // Bindingへの暫定対応
    )
    .padding()
    .background(Color.black.opacity(0.1)) // グラフを見やすくするための背景
}

