import SwiftUI

struct DayDetailView: View {
    @ObservedObject var viewModel: CalorieBalanceViewModel
    let metrics: DailyMetrics
    
    var currentData: DailyMetrics {
        if let updated = viewModel.allData.first(where: { Calendar.current.isDate($0.date, inSameDayAs: metrics.date) }) {
            return updated
        }
        return metrics
    }
    
    private let glassCornerRadius: CGFloat = 30.0
    private let panelPadding: CGFloat = 16.0
    
    @State private var showingEnergyInput = false
    @State private var energyInput = ""
    @State private var showingWeightInput = false
    @State private var weightInput = ""
    @State private var showingSleepInput = false
    @State private var sleepStart = Date()
    @State private var sleepEnd = Date()
    @State private var inputErrorMessage: String? = nil
    @State private var showInputError: Bool = false
    
    private var sleepEndRange: ClosedRange<Date> {
        let start = Calendar.current.startOfDay(for: currentData.date)
        let end = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: currentData.date) ?? currentData.date
        return start...end
    }
    
    var body: some View {
        ZStack {
            AdvancedBackgroundView()
            
            ScrollView {
                VStack(spacing: 28) {
                    if let net = currentData.netCalories {
                        HStack {
                            let fatGrams = Measurement(value: abs(currentData.fatEquivalentGram), unit: UnitMass.grams)
                            Text("脂肪換算で約 \(fatGrams.formatted(.measurement(width: .abbreviated))) \(net <= 0 ? Text("減少") : Text("増加"))")
                                .font(.headline)
                        }
                        .padding(.top, 8)
                    }
                    
                    VStack(spacing: 12) {
                        sectionHeader(String(localized: "エネルギー"))
                        
                        VStack(spacing: 0) {
                            energyRow(icon: "flame.fill", title: String(localized: "消費"), value: currentData.totalBurnedCalories.map { Text("\(Int($0)) kcal") } ?? Text("-- kcal"), color: .green)
                            
                            Divider().padding(.horizontal)
                            
                            Button(action: {
                                energyInput = currentData.dietaryCalories.map { String(Int($0)) } ?? ""
                                showingEnergyInput = true
                            }) {
                                energyRow(icon: "fork.knife", title: String(localized: "摂取"), value: currentData.dietaryCalories.map { Text("\(Int($0)) kcal") } ?? Text(String(localized: "入力する")), color: .red)
                            }
                            
                            Divider().padding(.horizontal)
                            
                            energyRow(icon: "equal.circle", title: String(localized: "収支"), value: currentData.netCalories.map { Text("\(Int($0)) kcal") } ?? Text("-- kcal"), color: currentData.netColor, isLarge: true)
                        }
                        .glassEffect(in: .rect(cornerRadius: glassCornerRadius))
                    }
                    
                    VStack(spacing: 12) {
                        sectionHeader(String(localized: "ヘルスケア"))
                        
                        VStack(spacing: 0) {
                            healthRow(icon: "figure.walk", title: String(localized: "歩数"), value: currentData.steps.map { Text("\($0) 歩") } ?? Text("--"), color: .orange)
                            
                            Divider().padding(.horizontal)
                            
                            Button(action: {
                                if let w = currentData.weight { weightInput = String(format: "%.1f", viewModel.convertToUserUnitValue(w)) }
                                showingWeightInput = true
                            }) {
                                let weightValue = currentData.weight.map { w in
                                    let m = Measurement(value: w, unit: UnitMass.kilograms)
                                    return Text(m.formatted(.measurement(width: .abbreviated, usage: .personWeight)))
                                } ?? Text(String(localized: "入力する"))
                                healthRow(icon: "scalemass.fill", title: String(localized: "体重"), value: weightValue, color: .teal)
                            }
                            
                            Divider().padding(.horizontal)
                            
                            Button(action: {
                                let baseDate = currentData.date
                                sleepEnd = Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: baseDate) ?? baseDate
                                sleepStart = Calendar.current.date(byAdding: .day, value: -1, to: baseDate).flatMap { Calendar.current.date(bySettingHour: 23, minute: 0, second: 0, of: $0) } ?? baseDate
                                showingSleepInput = true
                            }) {
                                let sleepValue = currentData.sleepSeconds.map { s in
                                    Text("\(Int(s) / 3600) 時間 \((Int(s) % 3600) / 60) 分")
                                } ?? Text(String(localized: "入力する"))
                                healthRow(icon: "bed.double.fill", title: String(localized: "睡眠"), value: sleepValue, color: .indigo, isMulticolor: true)
                            }
                        }
                        .glassEffect(in: .rect(cornerRadius: glassCornerRadius))
                    }
                }
                .padding()
            }
        }
        .navigationTitle(currentData.date.formatted(.dateTime.month().day().weekday()))
        .navigationBarTitleDisplayMode(.inline)
        
        // --- 摂取エネルギー Alert (バリデーション追加) ---
        .alert(String(localized: "食事カロリーを入力"), isPresented: $showingEnergyInput) {
            TextField(String(localized: "カロリー (kcal)"), text: $energyInput).keyboardType(.numberPad)
            
            Button(String(localized: "保存")) {
                if let amount = Double(energyInput) {
                    viewModel.addDietaryCalories(amount, for: currentData.date)
                    energyInput = ""
                } else {
                    inputErrorMessage = "有効な数値を入力してください。"
                    showInputError = true
                }
            }
            if currentData.dietaryCalories != nil {
                Button(role: .destructive) { viewModel.deleteDietaryCalories(for: currentData.date); energyInput = "" } label: { Text("このアプリから入力したデータを削除") }
            }
            Button(String(localized: "キャンセル"), role: .cancel) { energyInput = "" }
        }
        
        // --- 体重 Alert (バリデーション追加) ---
        .alert(String(localized: "体重を入力"), isPresented: $showingWeightInput) {
            TextField(viewModel.userWeightUnit.symbol, text: $weightInput).keyboardType(.decimalPad)
            
            Button(String(localized: "保存")) {
                if let val = Double(weightInput) {
                    viewModel.saveWeightFromUserUnit(val, for: currentData.date)
                    weightInput = ""
                } else {
                    inputErrorMessage = "有効な数値を入力してください。"
                    showInputError = true
                }
            }
            if currentData.weight != nil {
                Button(role: .destructive) { viewModel.deleteWeight(for: currentData.date); weightInput = "" } label: { Text("このアプリから入力したデータを削除") }
            }
            Button(String(localized: "キャンセル"), role: .cancel) { weightInput = "" }
        }
        
        .sheet(isPresented: $showingSleepInput) {
            NavigationStack {
                Form {
                    Section {
                        DatePicker(String(localized: "就寝"), selection: $sleepStart, displayedComponents: [.date, .hourAndMinute])
                        DatePicker(String(localized: "起床"), selection: $sleepEnd, in: sleepEndRange, displayedComponents: [.date, .hourAndMinute])
                    }
                    
                    if currentData.sleepSeconds != nil {
                        Section {
                            Button(role: .destructive) {
                                viewModel.deleteSleep(for: currentData.date)
                                showingSleepInput = false
                            } label: {
                                Text("このアプリから入力したデータを削除").frame(maxWidth: .infinity)
                            }
                        }
                    }
                }
                .navigationTitle(String(localized: "睡眠時間を入力"))
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button(String(localized: "キャンセル")) { showingSleepInput = false } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(String(localized: "保存")) {
                            let now = Date()
                            if sleepEnd > now { inputErrorMessage = "未来の睡眠時間は保存できません。"; showInputError = true }
                            else if !Calendar.current.isDate(sleepEnd, inSameDayAs: currentData.date) { inputErrorMessage = "起床時間は表示されている日付内で設定してください。"; showInputError = true }
                            else if sleepStart >= sleepEnd { inputErrorMessage = "就寝日時は起床日時より前に設定してください。"; showInputError = true }
                            else if sleepEnd.timeIntervalSince(sleepStart) > 86400 { inputErrorMessage = "睡眠時間が24時間を超えています。"; showInputError = true }
                            else { viewModel.addSleep(start: sleepStart, end: sleepEnd, targetDate: currentData.date); showingSleepInput = false }
                        }
                    }
                }
            }
            .presentationDetents([.medium])
        }
        // 共通のエラーアラート
        .alert(String(localized: "入力エラー"), isPresented: $showInputError) {
            Button("OK", role: .cancel) { }
        } message: {
            if let message = inputErrorMessage { Text(message) }
        }
    }
    
    private func sectionHeader(_ title: String) -> some View {
        Text(title).font(.subheadline).foregroundColor(.primary.opacity(0.8)).bold().padding(.leading, 8).frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func energyRow(icon: String, title: String, value: Text, color: Color, isLarge: Bool = false) -> some View {
        HStack {
            Image(systemName: icon).font(isLarge ? .largeTitle : .title).frame(width: 44, alignment: .center)
            Text(title).font(isLarge ? .title2 : .title3).bold()
            Spacer()
            value.font(isLarge ? .largeTitle : .title).bold()
        }
        .foregroundColor(color).padding(16)
    }
    
    @ViewBuilder
    private func healthRow(icon: String, title: String, value: Text, color: Color, isMulticolor: Bool = false) -> some View {
        HStack {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.largeTitle).symbolRenderingMode(isMulticolor ? .multicolor : .monochrome).frame(width: 44, alignment: .center)
                Text(title).font(.title2).bold()
            }
            .foregroundColor(color).frame(width: 140, alignment: .leading)
            Spacer()
            value.font(.largeTitle).foregroundColor(color).bold()
        }
        .padding(16)
    }
}
#Preview {
    let viewModel = CalorieBalanceViewModel()
    let dummyMetrics = DailyMetrics(
        date: Date(),
        activeCalories: 1800,
        restingCalories: 600,
        dietaryCalories: 1500,
        steps: 8500,
        sleepSeconds: 27000, // 7.5時間
        weight: 70.5        // 正しい位置に修正
    )
    
    NavigationStack {
        DayDetailView(viewModel: viewModel, metrics: dummyMetrics)
    }
}
