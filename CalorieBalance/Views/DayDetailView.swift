//
//  DayDetailView.swift
//  CalorieBalance
//
//  Created by Soichiro Yuhara on 2026/03/16.
//

import SwiftUI

struct DayDetailView: View {
    @ObservedObject var viewModel: CalorieBalanceViewModel
    let metrics: DailyMetrics // これは画面遷移用（初期データ）として保持
    
    // ★大解決策★：ViewModelが更新されるたびに、常に最新の「この日」のデータを拾ってくる
    var currentData: DailyMetrics {
        if let updated = viewModel.allData.first(where: { Calendar.current.isDate($0.date, inSameDayAs: metrics.date) }) {
            return updated
        }
        return metrics // 見つからなければ初期データを返す
    }
    
    // 統一されたデザイン定数
    private let glassCornerRadius: CGFloat = 30.0
    private let panelPadding: CGFloat = 16.0
    
    // --- 入力用のState ---
    @State private var showingEnergyInput = false
    @State private var energyInput = ""
    @State private var showingWeightInput = false
    @State private var weightInput = ""
    @State private var showingSleepInput = false
    @State private var sleepStart = Date()
    @State private var sleepEnd = Date()
    
    var body: some View {
        ZStack {
            AdvancedBackgroundView()
            
            ScrollView {
                VStack(spacing: 28) {
                    // 古い metrics ではなく、全て currentData を参照するように変更！
                    if let net = currentData.netCalories {
                        HStack {
                            Label("脂肪換算で", systemImage: "barometer")
                            Text("\(abs(currentData.fatEquivalentGram), specifier: "%.2f") g")
                            Text(net >= 0 ? "蓄積しました。" : "燃焼しました！")
                        }
                        .font(.title3)
                        .bold()
                    }
                    
                    // --- セクション1：エネルギー ---
                    VStack(alignment: .leading, spacing: 12) {
                        sectionHeader("エネルギー")
                        
                        VStack(spacing: 0) {
                            // 収支
                            energyRow(
                                icon: "chart.bar.fill",
                                title: "収支",
                                value: currentData.netCalories.map { String(format: "%.0f kcal", $0) } ?? "データなし",
                                color: currentData.netColor,
                                isLarge: true
                            )

                            Divider().padding(.horizontal, panelPadding)

                            // 消費
                            energyRow(
                                icon: "flame.fill",
                                title: "消費",
                                value: currentData.totalBurnedCalories.map { String(format: "%.0f kcal", $0) } ?? "データなし",
                                color: .green
                            )

                            Divider().padding(.horizontal, panelPadding)

                            // 摂取
                            Button {
                                energyInput = currentData.dietaryCalories.map { String(format: "%.0f", $0) } ?? ""
                                showingEnergyInput = true
                            } label: {
                                energyRow(
                                    icon: "carrot.fill",
                                    title: "摂取",
                                    value: currentData.dietaryCalories.map { String(format: "%.0f kcal", $0) } ?? "入力する",
                                    color: .red
                                )
                            }
                        }
                        .glassEffect(in: .rect(cornerRadius: glassCornerRadius))
                    }
                    
                    // --- セクション2：ヘルスケアデータ ---
                    VStack(alignment: .leading, spacing: 12) {
                        sectionHeader("この日のヘルスケアデータ")
                        
                        VStack(spacing: 0) {
                            // 睡眠
                            Button {
                                sleepStart = Calendar.current.startOfDay(for: currentData.date)
                                sleepEnd = Date()
                                showingSleepInput = true
                            } label: {
                                healthRow(
                                    icon: "bed.double.fill",
                                    title: "睡眠",
                                    value: currentData.sleepSeconds != nil ? String(format: "%.1f 時間", currentData.sleepSeconds! / 3600) : "入力する",
                                    color: .indigo,
                                    isMulticolor: true
                                )
                            }

                            Divider().padding(.horizontal, panelPadding)
                            
                            // 歩数
                            healthRow(
                                icon: "figure.walk",
                                title: "歩数",
                                value: currentData.steps != nil ? String(format: "%i 歩", currentData.steps!) : "データなし",
                                color: .orange
                            )
                            
                            Divider().padding(.horizontal, panelPadding)

                            // 体重
                            Button {
                                weightInput = currentData.weight.map { String(format: "%.1f", $0) } ?? ""
                                showingWeightInput = true
                            } label: {
                                healthRow(
                                    icon: "scalemass.fill",
                                    title: "体重",
                                    value: currentData.weight != nil ? String(format:"%.1f kg", currentData.weight!) : "入力する",
                                    color: .teal
                                )
                            }
                        }
                        .glassEffect(in: .rect(cornerRadius: glassCornerRadius))
                    }
                                        
                    Color.clear.frame(height: 40)
                }
                .padding()
            }
        }
        .navigationTitle(currentData.date.formatted(date: .numeric, time: .omitted))
        .navigationBarTitleDisplayMode(.inline)
        
        // --- アラート・シート群 ---
                .alert("摂取カロリー入力", isPresented: $showingEnergyInput) {
                    TextField("kcal", text: $energyInput).keyboardType(.numberPad)
                    Button("保存") {
                        if let val = Double(energyInput) {
                            viewModel.addDietaryCalories(val, for: currentData.date)
                        }
                    }
                    // ★追加：削除ボタン（role: .destructive にすると文字が赤くなります）
                    Button("削除", role: .destructive) {
                        viewModel.deleteDietaryCalories(for: currentData.date)
                    }
                    Button("キャンセル", role: .cancel) {}
                }
                .alert("体重入力", isPresented: $showingWeightInput) {
                    TextField("kg", text: $weightInput).keyboardType(.decimalPad)
                    Button("保存") {
                        if let val = Double(weightInput) {
                            viewModel.addWeight(val, for: currentData.date)
                        }
                    }
                    // ★追加：削除ボタン
                    Button("削除", role: .destructive) {
                        viewModel.deleteWeight(for: currentData.date)
                    }
                    Button("キャンセル", role: .cancel) {}
                }
                .sheet(isPresented: $showingSleepInput) {
                    NavigationStack {
                        Form {
                            Section("睡眠時間の記録") {
                                DatePicker("就寝時刻", selection: $sleepStart, displayedComponents: [.date, .hourAndMinute])
                                DatePicker("起床時刻", selection: $sleepEnd, displayedComponents: [.date, .hourAndMinute])
                            }
                            
                            // ★追加：削除用のセクション
                            Section {
                                Button(role: .destructive) {
                                    viewModel.deleteSleep(for: currentData.date)
                                    showingSleepInput = false
                                } label: {
                                    HStack {
                                        Spacer()
                                        Text("この日の睡眠記録を削除")
                                        Spacer()
                                    }
                                }
                            }
                        }
                        .navigationTitle("睡眠データの追加")
                        .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("保存") {
                            viewModel.addSleep(start: sleepStart, end: sleepEnd)
                            showingSleepInput = false
                        }
                    }
                    ToolbarItem(placement: .cancellationAction) {
                        Button("閉じる") { showingSleepInput = false }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
    }
    
    // --- ヘルパーメソッド（変更なし） ---
    private func sectionHeader(_ title: String) -> some View {
        Text(title).font(.subheadline).foregroundColor(.primary.opacity(0.8)).bold().padding(.leading, 8)
    }
    
    @ViewBuilder
    private func energyRow(icon: String, title: String, value: String, color: Color, isLarge: Bool = false) -> some View {
        HStack {
            Image(systemName: icon).font(isLarge ? .largeTitle : .title).frame(width: 44, alignment: .center)
            Text(title).font(isLarge ? .title2 : .title3).bold()
            Spacer()
            Text(value).font(isLarge ? .largeTitle : .title).bold()
        }
        .foregroundColor(color).padding(panelPadding)
    }
    
    @ViewBuilder
    private func healthRow(icon: String, title: String, value: String, color: Color, isMulticolor: Bool = false) -> some View {
        HStack {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.largeTitle).symbolRenderingMode(isMulticolor ? .multicolor : .monochrome).frame(width: 44, alignment: .center)
                Text(title).font(.title2).bold()
            }
            .foregroundColor(color).frame(width: 140, alignment: .leading)
            Spacer()
            Text(value).font(.largeTitle).foregroundColor(color).bold()
        }
        .padding(panelPadding)
    }
}

// --- Preview ---
#Preview {
    let sample = DailyMetrics(
        date: Date(), activeCalories: 600, restingCalories: 1500, dietaryCalories: 1800, steps: 10240, sleepSeconds: 27000, weight: 50.5
    )
    return NavigationStack {
        DayDetailView(viewModel: CalorieBalanceViewModel(previewData: [sample]), metrics: sample)
    }
}
