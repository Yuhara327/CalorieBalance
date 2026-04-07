import SwiftUI

struct GoalSetupView: View {
    @ObservedObject var viewModel: CalorieBalanceViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isTextFieldFocused: Bool
    
    // 表示・入力用の状態（ユーザーの単位系に合わせた数値が入る）
    @State private var currentWeightInput: Double = 0
    @State private var targetWeightInput: Double = 0
    
    // バリデーションロジック（単位系が何であれ、数値の大小関係で判定可能）
    private var isInputValid: Bool {
        if viewModel.goalMode == .maintain { return currentWeightInput > 0 }
        guard targetWeightInput > 0 && currentWeightInput > 0 else { return false }
        switch viewModel.goalMode {
        case .lose: return targetWeightInput < currentWeightInput
        case .gain: return targetWeightInput > currentWeightInput
        default: return false
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Spacer(minLength: 20)
                    
                    // --- セクション1: ダイエットモード ---
                    VStack(alignment: .leading, spacing: 16) {
                        Text("ダイエットモード")
                            .font(.caption).bold()
                            .foregroundColor(.secondary)
                        
                        Picker(String(localized: "モード"), selection: $viewModel.goalMode) {
                            ForEach(DietGoalMode.allCases) { mode in
                                Text(mode.localizedName).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        
                        HStack {
                            Spacer()
                            Image(systemName: viewModel.goalMode.iconName)
                                .font(.title2)
                                .foregroundColor(.teal)
                            
                            Text(viewModel.goalMode.localizedName)
                                .font(.headline)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .padding(.top, 4)
                        .animation(.spring(response: 0.3), value: viewModel.goalMode)
                    }
                    .padding()
                    .background(
                        .regularMaterial,
                        in: RoundedRectangle(cornerRadius: 30)
                    )
                    
                    // --- セクション2: 数値設定 ---
                    VStack(spacing: 0) {
                        // 1. 現在の体重
                        HStack {
                            Label(String(localized: "現在の体重"), systemImage: "figure.walk")
                            Spacer()
                            HStack(spacing: 8) {
                                TextField("0.0", value: $currentWeightInput, format: .number.precision(.fractionLength(1)))
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .focused($isTextFieldFocused)
                                    .frame(minWidth: 60)
                                    .font(.system(.body, design: .rounded)).bold()
                                
                                if isTextFieldFocused && currentWeightInput != 0 {
                                    Button { currentWeightInput = 0 } label: {
                                        Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                                    }
                                }
                                // 動的な単位表示
                                Text(viewModel.userWeightUnit.symbol)
                            }
                        }
                        .padding()
                        .contentShape(Rectangle())
                        .onTapGesture { isTextFieldFocused = true }
                        
                        Divider().padding(.horizontal)
                        
                        // 2. 目標体重
                        if viewModel.goalMode != .maintain {
                            VStack(alignment: .trailing, spacing: 4) {
                                HStack {
                                    Label(String(localized: "目標体重"), systemImage: "target")
                                    Spacer()
                                    HStack(spacing: 8) {
                                        TextField("0.0", value: $targetWeightInput, format: .number.precision(.fractionLength(1)))
                                            .keyboardType(.decimalPad)
                                            .multilineTextAlignment(.trailing)
                                            .focused($isTextFieldFocused)
                                            .frame(minWidth: 60)
                                            .font(.system(.body, design: .rounded)).bold()
                                        
                                        if isTextFieldFocused && targetWeightInput != 0 {
                                            Button { targetWeightInput = 0 } label: {
                                                Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                                            }
                                        }
                                        // 動的な単位表示
                                        Text(viewModel.userWeightUnit.symbol)
                                    }
                                }
                                .contentShape(Rectangle())
                                .onTapGesture { isTextFieldFocused = true }
                                
                                if !isInputValid && (targetWeightInput > 0 || currentWeightInput > 0) {
                                    Text(viewModel.goalMode == .lose
                                         ? String(localized: "現在より低い値を入力してください")
                                         : String(localized: "現在より高い値を入力してください"))
                                        .font(.caption2)
                                        .foregroundColor(.red)
                                }
                            }
                            .padding()
                            
                            Divider().padding(.horizontal)
                        }
                        
                        // 3. 達成期限
                        DatePicker(
                            selection: $viewModel.targetDate,
                            in: Date()...,
                            displayedComponents: .date
                        ) {
                            Label(String(localized: "達成期限"), systemImage: "calendar")
                        }
                        .padding()
                    }
                    .background(
                        .regularMaterial,
                        in: RoundedRectangle(cornerRadius: 30)
                    )
                    
                    // --- セクション3: 開始ボタン ---
                    Button {
                        // 入力されたユーザー単位の値を内部用のkgに変換して保存
                        let unit = viewModel.userWeightUnit
                        
                        // 開始体重の変換保存
                        let startMg = Measurement(value: currentWeightInput, unit: unit)
                        viewModel.startingWeight = startMg.converted(to: .kilograms).value
                        
                        // 目標体重の変換保存
                        if viewModel.goalMode == .maintain {
                            viewModel.targetWeight = viewModel.startingWeight
                        } else {
                            let targetMg = Measurement(value: targetWeightInput, unit: unit)
                            viewModel.targetWeight = targetMg.converted(to: .kilograms).value
                        }
                        
                        viewModel.isGoalSet = true
                        viewModel.dietStartDate = Date()
                        dismiss()
                    } label: {
                        Text(isInputValid ? String(localized: "この目標で開始する") : String(localized: "入力を確認してください"))
                            .frame(maxWidth: .infinity)
                            .font(.headline)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.teal)
                    .disabled(!isInputValid)
                    .opacity(isInputValid ? 1.0 : 0.6)
                    .padding(.top, 10)
                }
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(String(localized: "目標の設定"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "キャンセル")) { dismiss() }
                }
                
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(String(localized: "完了")) { isTextFieldFocused = false }
                }
            }
        }
        .onAppear {
            // 初期表示時に内部のkgをユーザーの単位に変換してStateにセット
            currentWeightInput = viewModel.convertToUserUnitValue(viewModel.effectiveCurrentWeight)
            targetWeightInput = viewModel.convertToUserUnitValue(viewModel.targetWeight)
        }
    }
}
#Preview {
    GoalSetupView(viewModel: CalorieBalanceViewModel(previewData: DailyMetrics.mockData))
}
