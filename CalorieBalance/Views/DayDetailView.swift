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
                            energyRow(
                                icon: "flame.fill",
                                title: String(localized: "消費"),
                                value: currentData.totalBurnedCalories.map { Text("\(Int($0)) kcal") } ?? Text("-- kcal"),
                                color: .green
                            )
                            
                            Divider().padding(.horizontal)
                            
                            Button(action: { showingEnergyInput = true }) {
                                energyRow(
                                    icon: "fork.knife",
                                    title: String(localized: "摂取"),
                                    value: currentData.dietaryCalories.map { Text("\(Int($0)) kcal") } ?? Text(String(localized: "入力する")),
                                    color: .red
                                )
                            }
                            
                            Divider().padding(.horizontal)
                            
                            energyRow(
                                icon: "equal.circle",
                                title: String(localized: "収支"),
                                value: currentData.netCalories.map { Text("\(Int($0)) kcal") } ?? Text("-- kcal"),
                                color: currentData.netColor,
                                isLarge: true
                            )
                        }
                        .glassEffect(in: .rect(cornerRadius: glassCornerRadius))
                    }
                    
                    VStack(spacing: 12) {
                        sectionHeader(String(localized: "ヘルスケア"))
                        
                        VStack(spacing: 0) {
                            healthRow(
                                icon: "figure.walk",
                                title: String(localized: "歩数"),
                                value: currentData.steps.map { Text("\($0) 歩") } ?? Text("--"),
                                color: .orange
                            )
                            
                            Divider().padding(.horizontal)
                            
                            let weightValue: Text = {
                                if let w = currentData.weight {
                                    // 修正：内部のkgをユーザー設定の単位（kg/lb/st）に変換して表示
                                    let m = Measurement(value: w, unit: UnitMass.kilograms)
                                    return Text(m.formatted(.measurement(width: .abbreviated, usage: .personWeight)))
                                } else {
                                    return Text(String(localized: "入力する"))
                                }
                            }()
                            
                            Button(action: {
                                // アラートを開く前に、現在の体重をユーザーの単位に変換してセット
                                if let w = currentData.weight {
                                    let converted = viewModel.convertToUserUnitValue(w)
                                    weightInput = String(format: "%.1f", converted)
                                }
                                showingWeightInput = true
                            }) {
                                healthRow(icon: "scalemass.fill", title: String(localized: "体重"), value: weightValue, color: .teal)
                            }
                            
                            Divider().padding(.horizontal)
                            
                            let sleepValue: Text = {
                                if let s = currentData.sleepSeconds {
                                    let hours = Int(s) / 3600
                                    let minutes = (Int(s) % 3600) / 60
                                    return Text("\(hours) 時間 \(minutes) 分")
                                } else {
                                    return Text(String(localized: "入力する"))
                                }
                            }()
                            
                            Button(action: { showingSleepInput = true }) {
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
        .alert(String(localized: "食事カロリーを入力"), isPresented: $showingEnergyInput) {
            TextField(String(localized: "カロリー (kcal)"), text: $energyInput)
                .keyboardType(.numberPad)
            Button(String(localized: "キャンセル"), role: .cancel) { energyInput = "" }
            Button(String(localized: "保存")) {
                if let amount = Double(energyInput) {
                    viewModel.addDietaryCalories(amount, for: currentData.date)
                }
                energyInput = ""
            }
        }
        .alert(String(localized: "体重を入力"), isPresented: $showingWeightInput) {
            // 修正：現在の地域設定に合わせた単位記号を表示
            TextField(viewModel.userWeightUnit.symbol, text: $weightInput)
                .keyboardType(.decimalPad)
            Button(String(localized: "キャンセル"), role: .cancel) { weightInput = "" }
            Button(String(localized: "保存")) {
                if let val = Double(weightInput) {
                    // 修正：ユーザーの単位として解釈し、内部でkg変換して保存
                    viewModel.saveWeightFromUserUnit(val, for: currentData.date)
                }
                weightInput = ""
            }
        }
        .sheet(isPresented: $showingSleepInput) {
            NavigationStack {
                Form {
                    DatePicker(String(localized: "就寝"), selection: $sleepStart, displayedComponents: .hourAndMinute)
                    DatePicker(String(localized: "起床"), selection: $sleepEnd, displayedComponents: .hourAndMinute)
                }
                .navigationTitle(String(localized: "睡眠時間を入力"))
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(String(localized: "キャンセル")) { showingSleepInput = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(String(localized: "保存")) {
                            viewModel.addSleep(start: sleepStart, end: sleepEnd)
                            showingSleepInput = false
                        }
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }
    
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.subheadline)
            .foregroundColor(.primary.opacity(0.8))
            .bold()
            .padding(.leading, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func energyRow(icon: String, title: String, value: Text, color: Color, isLarge: Bool = false) -> some View {
        HStack {
            Image(systemName: icon).font(isLarge ? .largeTitle : .title).frame(width: 44, alignment: .center)
            Text(title).font(isLarge ? .title2 : .title3).bold()
            Spacer()
            value.font(isLarge ? .largeTitle : .title).bold()
        }
        .foregroundColor(color).padding(panelPadding)
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
        .padding(panelPadding)
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
