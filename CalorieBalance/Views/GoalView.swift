//
//  GoalView.swift
//  CalorieBalance
//
//  Created by Soichiro Yuhara on 2026/03/22.
//

import SwiftUI

struct GoalView: View {
    @ObservedObject var viewModel: CalorieBalanceViewModel
    // 追加：課金状態の監視
    @StateObject private var subManager = SubscriptionManager.shared
    
    @State private var isShowingSetup = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                AdvancedBackgroundView()
                    .ignoresSafeArea()
                
                // --- メインコンテンツ（未課金時はぼかして触れなくする） ---
                ScrollView {
                    VStack(spacing: 24) {
                        if viewModel.isGoalSet {
                            statusHeaderSection
                            managementSection
                        } else {
                            unsetPlaceholderView
                        }
                    }
                    .padding()
                }
                .blur(radius: subManager.isPremium ? 0 : 8)
                .disabled(!subManager.isPremium)
                
                // --- 課金誘導オーバーレイ ---
                if !subManager.isPremium {
                    ProFeatureOverlay(
                        title: String(localized: "目標管理の解放"),
                        message: String(localized: "あなた専用の目標を設定し、進捗リングで\n成果を可視化しましょう。\n目標を持つことがダイエット成功への最短ルートです。")
                    )
                }
            }
            .navigationTitle(String(localized: "Goal"))
            .toolbarTitleDisplayMode(.inlineLarge)
            .sheet(isPresented: $isShowingSetup) {
                GoalSetupView(viewModel: viewModel)
                    .presentationDetents([.fraction(0.8)])
                    .presentationDragIndicator(.visible)
            }
        }
    }
    
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
                Text(String(localized: "次の目標を設定する"))
                    .bold()
                    .padding(.horizontal, 24)
            }
            .buttonStyle(.borderedProminent)
            .tint(.teal)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .glassEffect(in: .rect(cornerRadius: 30.0))
    }
    
    private var expiredStatusView: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text(String(localized: "期限が終了しました"))
                .font(.headline)
            
            Text(viewModel.goalStatusMessage)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button(String(localized: "目標を再設定")) {
                viewModel.prepareForReselectingGoal()
                isShowingSetup = true
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .glassEffect(in: .rect(cornerRadius: 30.0))
    }
    
    private var inProgressStatusView: some View {
        VStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 12) {
                Text(String(localized: "今日の目標"))
                    .font(.caption).bold()
                    .foregroundColor(.secondary)
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(localized: "目標収支")).font(.caption).foregroundColor(.secondary)
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
            
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 15)
                    
                    // MARK: - デバッグ時はスクショ映えする固定の進捗率を注入
                    #if DEBUG
                    let progress = 0.72 // 72%（お好みの数字に変更してください）
                    #else
                    let progress = (viewModel.goalMode == .maintain) ? viewModel.maintenanceProgress : viewModel.achievementRate
                    #endif
                    
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            LinearGradient(colors: [.teal, .cyan], startPoint: .top, endPoint: .bottom),
                            style: StrokeStyle(lineWidth: 15, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                    
                    if viewModel.goalMode == .maintain {
                        VStack(spacing: -4) {
                            Text(viewModel.remainingDays, format: .number)
                                .font(.system(size: 54, weight: .bold, design: .rounded))
                            Text(String(localized: "残り日数"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        VStack {
                            #if DEBUG
                            Text(progress, format: .percent.precision(.fractionLength(0)))
                                .font(.system(size: 40, weight: .bold, design: .rounded))
                            #else
                            Text(viewModel.achievementRate, format: .percent.precision(.fractionLength(0)))
                                .font(.system(size: 40, weight: .bold, design: .rounded))
                            #endif
                            
                            Text(String(localized: "達成状況")).font(.caption).foregroundColor(.secondary)
                        }
                    }
                }
                .frame(width: 160, height: 160)
                
                Text(viewModel.goalStatusMessage)
                    .font(.subheadline).bold()
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(Capsule().fill(Color.teal.opacity(0.1)))
            }
        }
        .padding()
        .glassEffect(in: .rect(cornerRadius: 30.0))
    }

    private var managementSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(String(localized: "目標管理"))
                .font(.caption).bold()
                .foregroundColor(.secondary)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(viewModel.goalMode.localizedName).bold()
                        let targetMass = Measurement(value: viewModel.targetWeight, unit: UnitMass.kilograms)
                        Text("目標: \(targetMass.formatted(.measurement(width: .abbreviated, usage: .personWeight)))")
                    }
                    Text("達成期限: \(viewModel.targetDate.formatted(date: .numeric, time: .omitted))")
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
                Text(String(localized: "目標を削除"))
                    .frame(maxWidth: .infinity)
                    .bold()
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .glassEffect(in: .rect(cornerRadius: 30.0))
    }
    
    private var unsetPlaceholderView: some View {
        VStack(spacing: 24) {
            Image(systemName: "target")
                .font(.system(size: 60))
                .foregroundColor(.teal)
            
            VStack(spacing: 8) {
                Text(String(localized: "目標が設定されていません"))
                    .font(.headline)
                Text(String(localized: "体重の目標を設定して、理想の体に近づきましょう。"))
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }
            
            Button {
                isShowingSetup = true
                viewModel.prepareForReselectingGoal()
            } label: {
                Text(String(localized: "目標を設定する"))
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

// プレビュー群
#Preview("目標未設定") {
    let viewModel = CalorieBalanceViewModel()
    viewModel.isGoalSet = false
    
    return GoalView(viewModel: viewModel)
}

#Preview("目標進行中 (減量)") {
    let viewModel = CalorieBalanceViewModel()
    viewModel.isGoalSet = true
    viewModel.goalMode = .lose
    viewModel.startingWeight = 75.0
    viewModel.targetWeight = 70.0
    viewModel.targetDate = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
    
    return GoalView(viewModel: viewModel)
}

#Preview("維持モード") {
    let viewModel = CalorieBalanceViewModel()
    viewModel.isGoalSet = true
    viewModel.goalMode = .maintain
    viewModel.startingWeight = 70.0
    viewModel.targetWeight = 70.0
    viewModel.dietStartDate = Calendar.current.date(byAdding: .day, value: -15, to: Date()) ?? Date()
    viewModel.targetDate = Calendar.current.date(byAdding: .day, value: 15, to: Date()) ?? Date()
    
    return GoalView(viewModel: viewModel)
}

#Preview("目標達成！") {
    let viewModel = CalorieBalanceViewModel()
    viewModel.isGoalSet = true
    viewModel.targetWeight = 70.0
    
    return GoalView(viewModel: viewModel)
}
