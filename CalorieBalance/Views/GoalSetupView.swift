//
//  GoalSetupView.swift
//  CalorieBalance
//
//  Created by Soichiro Yuhara on 2026/03/22.
//

import SwiftUI

struct GoalSetupView: View {
    @ObservedObject var viewModel: CalorieBalanceViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isTextFieldFocused: Bool
    @State private var currentWeightInput: Double = 0
    
    // バリデーションロジック（手入力値 currentWeightInput を反映）
    private var isInputValid: Bool {
        let current = currentWeightInput
        let target = viewModel.targetWeight
        if viewModel.goalMode == .maintain { return true }
        guard target > 0 && current > 0 else { return false }
        switch viewModel.goalMode {
        case .lose: return target < current
        case .gain: return target > current
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
                        
                        // 1. ピッカーはテキストのみにする（OSの制約を回避）
                        Picker("モード", selection: $viewModel.goalMode) {
                            ForEach(DietGoalMode.allCases) { mode in
                                Text(mode.localizedName).tag(mode) // rawValueをlocalizedNameに変更
                            }
                        }
                        .pickerStyle(.segmented)
                        // 2. ピッカーの下にアイコンと現在のモード名を表示
                        HStack {
                            Spacer()
                            Image(systemName: viewModel.goalMode.iconName)
                                .font(.title2)
                                .foregroundColor(.teal) // 全てtealで統一
                            
                            Text(viewModel.goalMode.localizedName)
                                .font(.headline)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .padding(.top, 4)
                        // 選択が変わった時にふわっと動くようにする
                        .animation(.spring(response: 0.3), value: viewModel.goalMode)
                    }
                    .padding()
                    .background(
                        .regularMaterial,
                        in: RoundedRectangle(cornerRadius: 30)
                    )
                    
                    // --- セクション2: 数値設定 ---
                    VStack(spacing: 0) {
                        // 1. 現在の体重（当たり判定拡大・クリアボタン付）
                        HStack {
                            Label("現在の体重", systemImage: "figure.walk")
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
                                Text("kg")
                            }
                        }
                        .padding()
                        .contentShape(Rectangle()) // 行全体のタップ判定を有効化
                        .onTapGesture { isTextFieldFocused = true }
                        
                        Divider().padding(.horizontal)
                        
                        // 2. 目標体重
                        if viewModel.goalMode != .maintain {
                            VStack(alignment: .trailing, spacing: 4) {
                                HStack {
                                    Label("目標体重", systemImage: "target")
                                    Spacer()
                                    HStack(spacing: 8) {
                                        TextField("0.0", value: $viewModel.targetWeight, format: .number)
                                            .keyboardType(.decimalPad)
                                            .multilineTextAlignment(.trailing)
                                            .focused($isTextFieldFocused)
                                            .frame(minWidth: 60)
                                            .font(.system(.body, design: .rounded)).bold()
                                        
                                        if isTextFieldFocused && viewModel.targetWeight != 0 {
                                            Button { viewModel.targetWeight = 0 } label: {
                                                Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                                            }
                                        }
                                        Text("kg")
                                    }
                                }
                                .contentShape(Rectangle())
                                .onTapGesture { isTextFieldFocused = true }
                                
                                if !isInputValid && (viewModel.targetWeight > 0 || currentWeightInput > 0) {
                                    Text(viewModel.goalMode == .lose
                                         ? "現在より低い値を入力してください"
                                         : "現在より高い値を入力してください")
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
                            Label("達成期限", systemImage: "calendar")
                        }
                        .padding()
                    }
                    .background(
                        .regularMaterial,
                        in: RoundedRectangle(cornerRadius: 30)
                    )
                    
                    // --- セクション3: 開始ボタン ---
                    Button {
                        if viewModel.goalMode == .maintain {
                            viewModel.targetWeight = currentWeightInput
                        }
                        viewModel.startingWeight = currentWeightInput
                        viewModel.isGoalSet = true
                        viewModel.dietStartDate = Date()
                        dismiss()
                    } label: {
                        Text(isInputValid ? "この目標で開始する" : "入力を確認してください")
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
            .navigationTitle("目標の設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完了") { isTextFieldFocused = false }
                }
            }
        }
        .onAppear {
            currentWeightInput = (viewModel.effectiveCurrentWeight * 10).rounded() / 10
        }
    }
}

#Preview {
    GoalSetupView(viewModel: CalorieBalanceViewModel(previewData: DailyMetrics.mockData))
}
