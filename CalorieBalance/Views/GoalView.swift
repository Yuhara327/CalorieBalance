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
                            // --- 1段目：日次目標収支 ---
                            VStack(alignment: .leading, spacing: 12) {
                                Text("今日の目標")
                                    .font(.caption).bold()
                                    .foregroundColor(.secondary)
                                
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("目標収支")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
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
                            .glassEffect(in: .rect(cornerRadius: 30.0))
                            
                            // --- 2段目：トータル進捗（グラフセクション） ---
                            VStack(alignment: .leading, spacing: 12) {
                                Text("全体進捗")
                                    .font(.caption).bold()
                                    .foregroundColor(.secondary)
                                
                                VStack(spacing: 20) {
                                    ZStack {
                                        Circle()
                                            .stroke(Color.white.opacity(0.2), lineWidth: 15)
                                        Circle()
                                            .trim(from: 0, to: viewModel.achievementRate)
                                            .stroke(
                                                LinearGradient(colors: [.teal, .cyan], startPoint: .top, endPoint: .bottom),
                                                style: StrokeStyle(lineWidth: 15, lineCap: .round)
                                            )
                                            .rotationEffect(.degrees(-90))
                                            .animation(.spring(), value: viewModel.achievementRate)
                                        
                                        VStack {
                                            Text("\(Int(viewModel.achievementRate * 100))%")
                                                .font(.system(size: 44, weight: .bold, design: .rounded))
                                            Text("達成")
                                                .font(.caption).foregroundColor(.secondary)
                                        }
                                    }
                                    .frame(width: 180, height: 180)
                                    .padding(.vertical, 10)
                                    
                                    let diff = abs(viewModel.targetWeight - viewModel.effectiveCurrentWeight)
                                    Text(String(format: "目標まであと %.1f kg", diff))
                                        .font(.subheadline).bold()
                                        .padding(.horizontal, 16).padding(.vertical, 8)
                                        .background(Capsule().fill(Color.teal.opacity(0.1)))
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .padding()
                            .glassEffect(in: .rect(cornerRadius: 30.0)) // グラフ背景にもエフェクトを適用
                            
                            // --- 3段目：目標管理 ---
                            VStack(alignment: .leading, spacing: 16) {
                                Text("目標管理")
                                    .font(.caption).bold()
                                    .foregroundColor(.secondary)
                                
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text(viewModel.goalMode.rawValue).bold()
                                            Text("\(viewModel.targetWeight, format: .number) kg まで")
                                        }
                                        Text("達成期限: \(viewModel.targetDate, style: .date)")
                                            .font(.caption).foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    
                                    // 編集ボタン（必要に応じて）
                                    Button {
                                        isShowingSetup = true
                                    } label: {
                                        Image(systemName: "pencil.circle.fill")
                                            .font(.title2)
                                            .symbolRenderingMode(.hierarchical)
                                            .foregroundStyle(.teal)
                                    }
                                }
                                
                                Divider()
                                
                                Button(role: .destructive) {
                                    viewModel.isGoalSet = false
                                    viewModel.startingWeight = 0
                                } label: {
                                    Text("目標を削除")
                                        .frame(maxWidth: .infinity)
                                        .bold()
                                }
                                .buttonStyle(.bordered)
                            }
                            .padding()
                            .glassEffect(in: .rect(cornerRadius: 30.0))
                            
                        } else {
                            // --- 目標未設定時 ---
                            Spacer()
                            VStack(spacing: 24) {
                                Image(systemName: "target")
                                    .font(.system(size: 60))
                                    .foregroundColor(.teal)
                                    .padding(.top)
                                
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
                    .padding()
                }
            }
            .navigationTitle("Goal")
            .sheet(isPresented: $isShowingSetup) {
                GoalSetupView(viewModel: viewModel)
                    // 画面の約半分(.medium)か、最大でも8割程度(.fraction(0.8))に制限
                    .presentationDetents([.fraction(0.8)])
                    // 引き出しのインジケータ（棒）を表示して直感的に
                    .presentationDragIndicator(.visible)
            }
        }
    }
}

#Preview {
    GoalView(viewModel: CalorieBalanceViewModel(previewData: DailyMetrics.mockData))
}
