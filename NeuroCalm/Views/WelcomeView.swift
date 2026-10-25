//
//  WelcomeView.swift
//  NeuroCalm
//
//  The very first screen new users see.
//

import SwiftUI

struct WelcomeView: View {
    @State private var showOnboarding = false

    // Animation state: makes the breathing circle pulse gently.
    @State private var pulse = false

    var body: some View {
        ZStack {
            AppTheme.primaryGradient
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Logo: a brain icon inside a pulsing circle.
                ZStack {
                    Circle()
                        .stroke(AppTheme.sage.opacity(0.3), lineWidth: 2)
                        .frame(width: 200, height: 200)
                        .scaleEffect(pulse ? 1.1 : 0.95)
                        .opacity(pulse ? 0.4 : 0.8)

                    Circle()
                        .fill(AppTheme.sage.opacity(0.15))
                        .frame(width: 140, height: 140)

                    Image(systemName: "brain.head.profile")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 70, height: 70)
                        .foregroundStyle(AppTheme.sage)
                }
                .animation(.easeInOut(duration: 3).repeatForever(autoreverses: true), value: pulse)
                .onAppear { pulse = true }

                VStack(spacing: 12) {
                    Text("NeuroCalm")
                        .font(AppTheme.display(44))
                        .foregroundStyle(AppTheme.cream)

                    Text("Student Stress &\nFocus Companion")
                        .font(.title3)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(AppTheme.cream.opacity(0.9))

                    Text("Calm your mind. Focus your future.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.mist)
                        .padding(.top, 8)
                }

                Spacer()

                Button {
                    showOnboarding = true
                } label: {
                    Text("Get Started")
                        .font(.headline)
                        .foregroundStyle(AppTheme.ink)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppTheme.sage)
                        .cornerRadius(AppTheme.buttonRadius)
                }
                .padding(.horizontal, 32)
                .adaptiveContentWidth(420)
                .padding(.bottom, 40)
            }
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView()
        }
    }
}

#Preview {
    WelcomeView()
}
