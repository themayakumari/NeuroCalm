//
//  LoginView.swift
//  NeuroCalm
//
//  The first screen for signed-out users. Sign in with Apple is live;
//  Google and school-code sign-in are placeholders for the next steps.
//

import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @EnvironmentObject private var auth: AuthService
    @State private var pulse = false
    @State private var showSchoolSheet = false

    var body: some View {
        ZStack {
            AppTheme.primaryGradient.ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                ZStack {
                    Circle()
                        .stroke(AppTheme.sage.opacity(0.3), lineWidth: 2)
                        .frame(width: 180, height: 180)
                        .scaleEffect(pulse ? 1.1 : 0.95)
                        .opacity(pulse ? 0.4 : 0.8)
                    Image(systemName: "brain.head.profile")
                        .resizable().scaledToFit()
                        .frame(width: 64, height: 64)
                        .foregroundStyle(AppTheme.sage)
                }
                .animation(.easeInOut(duration: 3).repeatForever(autoreverses: true), value: pulse)
                .onAppear { pulse = true }

                VStack(spacing: 10) {
                    Text("NeuroCalm")
                        .font(AppTheme.display(40))
                        .foregroundStyle(AppTheme.cream)
                    Text("Sign in to save your progress and\nsync across your devices.")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(AppTheme.mist)
                }

                Spacer()

                VStack(spacing: 12) {
                    SignInWithAppleButton(.signIn) { request in
                        auth.prepareAppleRequest(request)
                    } onCompletion: { result in
                        auth.handleAppleCompletion(result)
                    }
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.buttonRadius))

                    authButton(icon: "g.circle.fill", text: "Continue with Google") {
                        auth.signInWithGoogle()
                    }
                    authButton(icon: "graduationcap.fill", text: "Join with a school code") {
                        auth.errorMessage = nil
                        showSchoolSheet = true
                    }
                }
                // The Apple button caps at 375pt wide; keep the whole stack
                // under that so it never fights Auto Layout on wide screens.
                .frame(maxWidth: 360)

                if let error = auth.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(AppTheme.ember)
                        .multilineTextAlignment(.center)
                }

                Text("By continuing you agree to keep it calm. 🌿")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.mist.opacity(0.7))
                    .padding(.top, 4)

                Spacer().frame(height: 12)
            }
            .padding(.horizontal, 32)
            .adaptiveContentWidth(440)
        }
        .sheet(isPresented: $showSchoolSheet) {
            SchoolCodeSheet()
                .presentationDetents([.medium])
        }
    }

    private func authButton(icon: String, text: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                Text(text).fontWeight(.medium)
            }
            .font(.subheadline)
            .foregroundStyle(AppTheme.cream)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(AppTheme.twilight2)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.buttonRadius))
        }
    }
}

/// Sheet to enter a school code and join anonymously.
struct SchoolCodeSheet: View {
    @EnvironmentObject private var auth: AuthService
    @Environment(\.dismiss) private var dismiss
    @State private var code = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Text("Enter the code your school gave you.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)

                TextField("SCHOOL CODE", text: $code)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .multilineTextAlignment(.center)
                    .font(AppTheme.mono(20, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .padding()
                    .background(AppTheme.twilight2)
                    .cornerRadius(AppTheme.buttonRadius)

                if let error = auth.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(AppTheme.ember)
                        .multilineTextAlignment(.center)
                }

                Button {
                    auth.joinWithSchoolCode(code)
                } label: {
                    Group {
                        if auth.isJoining {
                            ProgressView().tint(AppTheme.ink)
                        } else {
                            Text("Join").fontWeight(.semibold)
                        }
                    }
                    .foregroundStyle(AppTheme.ink)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(AppTheme.sage)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.buttonRadius))
                }
                .disabled(code.isEmpty || auth.isJoining)

                Spacer()
            }
            .padding()
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Join with school")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onChange(of: auth.isSignedIn) { _, signedIn in
                if signedIn { dismiss() }
            }
        }
    }
}

#Preview {
    LoginView().environmentObject(AuthService())
}
