//
//  GoalView.swift
//  CalorieBalance
//
//  Created by Soichiro Yuhara on 2026/03/22.
//

import SwiftUI

struct GoalView: View {
    @ObservedObject var viewModel: CalorieBalanceViewModel
    @State private var isShowingSetup = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                AdvancedBackgroundView()
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        if viewModel.isGoalSet {
                            // 状態（達成・期限切れ・進行中）に応じたトップセクション
                            statusHeaderSection
                            
                            // 共通：目標管理セクション
                            managementSection
                        } else {
                            // 目標未設定時の表示
                            unsetPlaceholderView
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Goal")
            .toolbarTitleDisplayMode(.inlineLarge)
            .sheet(isPresented: $isShowingSetup) {
                GoalSetupView(viewModel: viewModel)
                    .presentationDetents([.fraction(0.8)])
                    .presentationDragIndicator(.visible)
            }
        }
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private var statusHeaderSection: some View {
        switch viewModel.currentGoalStatus {
        case .achieved:
            achievedStatusView
        case .expired:
            expiredStatusView
        case .inProgress:
            inProgressStatusView
        }
    }
    
    // 1. 達成時のView
    private var achievedStatusView: some View {
        VStack(spacing: 20) {
            Image(systemName: "flag.pattern.checkered.2.crossed")
                .font(.system(size: 60))
                .foregroundStyle(LinearGradient(colors: [.yellow, .orange], startPoint: .top, endPoint: .bottom))
                .shadow(color: .orange.opacity(0.3), radius: 10)
            
            VStack(spacing: 8) {
                Text("Congratulations!")
                    .font(.system(.title2, design: .rounded)).bold()
                Text(viewModel.goalStatusMessage)
                    .font(.headline)
                    .multilineTextAlignment(.center)
            }
            
            Button {
                viewModel.prepareForReselectingGoal()
                isShowingSetup = true
            } label: {
                Text("次の目標を設定する")
                    .bold()
                    .padding(.horizontal, 24)
            }
            .buttonStyle(.borderedProminent)
            .tint(.teal)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .glassEffect(in: .rect(cornerRadius: 30.0))
        .transition(.scale.combined(with: .opacity))
    }
    
    // 2. 期限切れのView
    private var expiredStatusView: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text("期限が終了しました")
                .font(.headline)
            
            Text(viewModel.goalStatusMessage)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("目標を再設定") {
                viewModel.prepareForReselectingGoal()
                isShowingSetup = true
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .glassEffect(in: .rect(cornerRadius: 30.0))
    }
    
    // 3. 進行中のView
    private var inProgressStatusView: some View {
        VStack(spacing: 24) {
            // 今日の目標収支
            VStack(alignment: .leading, spacing: 12) {
                Text("今日の目標")
                    .font(.caption).bold()
                    .foregroundColor(.secondary)
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("目標収支").font(.caption).foregroundColor(.secondary)
                        Text("\(Int(viewModel.dailyTargetCalories)) kcal")
                            .font(.title2).bold()
                    }
                    Spacer()
                    Image(systemName: viewModel.isDailyGoalAcheived ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 30))
                        .foregroundColor(viewModel.isDailyGoalAcheived ? .green : .secondary.opacity(0.3))
                }
            }
            .padding()
            .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 20))
            
            // 全体進捗グラフ / 残り日数
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 15)
                    
                    // --- 共通：青い進捗リングを描画 ---
                    // 分岐によって trim の 'to' に渡す値を切り替える
                    let progress = (viewModel.goalMode == .maintain) ? viewModel.maintenanceProgress : viewModel.achievementRate
                    
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            LinearGradient(colors: [.teal, .cyan], startPoint: .top, endPoint: .bottom),
                            style: StrokeStyle(lineWidth: 15, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                    // アニメーションは全モードで適用
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
                    
                    // --- 中央のテキスト表示はモードで出し分け ---
                    if viewModel.goalMode == .maintain {
                        VStack(spacing: -4) {
                            Text("\(viewModel.remainingDays)")
                                .font(.system(size: 54, weight: .bold, design: .rounded))
                            Text("あと何日")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        // 減量・増量：達成率(%)を表示
                        VStack {
                            Text("\(Int(viewModel.achievementRate * 100))%")
                                .font(.system(size: 40, weight: .bold, design: .rounded))
                            Text("達成").font(.caption).foregroundColor(.secondary)
                        }
                    }
                }
                .frame(width: 160, height: 160)
                
                // 下部のステータスメッセージ（既存のままでOK）
                Text(viewModel.goalStatusMessage)
                    .font(.subheadline).bold()
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(Capsule().fill(Color.teal.opacity(0.1)))
            }
        }
        .padding()
        .glassEffect(in: .rect(cornerRadius: 30.0))
    }
    // 4. 管理セクション（共通）
    private var managementSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("目標管理")
                .font(.caption).bold()
                .foregroundColor(.secondary)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(viewModel.goalMode.localizedName).bold()
                        Text("\(viewModel.targetWeight, format: .number) kg まで")
                    }
                    Text("達成期限: \(viewModel.targetDate, style: .date)")
                        .font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                Button { isShowingSetup = true } label: {
                    Image(systemName: "pencil.circle.fill")
                        .font(.title2)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.teal)
                }
            }
            
            Divider()
            
            Button(role: .destructive) {
                withAnimation {
                    viewModel.isGoalSet = false
                    viewModel.startingWeight = 0
                }
            } label: {
                Text("目標を削除")
                    .frame(maxWidth: .infinity)
                    .bold()
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .glassEffect(in: .rect(cornerRadius: 30.0))
    }
    
    // 5. 目標未設定時
    private var unsetPlaceholderView: some View {
        VStack(spacing: 24) {
            Image(systemName: "target")
                .font(.system(size: 60))
                .foregroundColor(.teal)
            
            VStack(spacing: 8) {
                Text("目標が設定されていません")
                    .font(.headline)
                Text("体重の目標を設定して、理想の体に近づきましょう。")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }
            
            Button {
                isShowingSetup = true
                viewModel.prepareForReselectingGoal()
            } label: {
                Text("目標を設定する")
                    .bold()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(.teal)
        }
        .padding(32)
        .glassEffect(in: .rect(cornerRadius: 30.0))
        .padding(.top, 40)
    }
}

#Preview("進行中") {
    let viewModel = CalorieBalanceViewModel(previewData: DailyMetrics.mockData)
    // 直接値を設定（UserDefaultsに書き込まれるがプレビュー内なので安全）
    viewModel.isGoalSet = true
    viewModel.goalMode = .lose
    viewModel.targetWeight = 60.0
    viewModel.startingWeight = 75.0
    // 期限を未来に設定
    viewModel.targetDate = Calendar.current.date(byAdding: .day, value: 30, to: Date())!
    
    return GoalView(viewModel: viewModel)
}

#Preview("達成済み") {
    let viewModel = CalorieBalanceViewModel(previewData: DailyMetrics.mockData)
    viewModel.isGoalSet = true
    viewModel.goalMode = .lose
    // 現在の体重(mockは約65kg)より高い数値を目標にすれば達成判定になる
    viewModel.targetWeight = 70.0
    return GoalView(viewModel: viewModel)
}

#Preview("期限切れ") {
    let viewModel = CalorieBalanceViewModel(previewData: DailyMetrics.mockData)
    viewModel.isGoalSet = true
    viewModel.goalMode = .lose
    viewModel.targetWeight = 50.0 // 未達
    // 期限を昨日に設定
    viewModel.targetDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
    return GoalView(viewModel: viewModel)
}

#Preview {
    let viewmodel = CalorieBalanceViewModel(previewData: DailyMetrics.mockData)
    return GoalView(viewModel: viewmodel)
}
