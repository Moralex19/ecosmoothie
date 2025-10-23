//
//  AuthView.swift
//  ecosmoothie
//
//  Created by Freddy Morales on 21/10/25.
//
// AuthView.swift
// AuthView.swift
import SwiftUI

struct AuthView: View {
    @EnvironmentObject var session: SessionManager

    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isLoading = false
    @State private var showPassword = false
    @State private var selectedRole: AppRole = .client

    @State private var showAlert = false
    @State private var alertMessage = ""

    @FocusState private var focused: Field?
    enum Field { case email, password }

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(spacing: 20) {
                    header
                    form
                    rolePicker
                    actions
                    footer
                }
                .padding(.horizontal, idealPadding(for: geo.size))
                .padding(.top, 32)
                .frame(maxWidth: 700)
                .frame(maxWidth: .infinity)
                .frame(minHeight: geo.size.height, alignment: .top)
            }
            .background(Color(.systemBackground))
        }
        .navigationBarHidden(true)
        .disabled(isLoading) // ← bloquea interacción durante el login
        .overlay(alignment: .top) {
            // ← Barra de carga lineal, visible solo mientras isLoading == true
            if isLoading {
                ProgressView()
                    .progressViewStyle(.linear)
                    .tint(.matcha)
                    .frame(height: 2)
                    .padding(.top, 0)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .alert("Inicio de sesión", isPresented: $showAlert, actions: {
            Button("OK", role: .cancel) {}
        }, message: {
            Text(alertMessage)
        })
    }

    // MARK: - Subviews

    private var header: some View {
        VStack(spacing: 8) {
            Image("profile2")
                .resizable()
                .scaledToFit()
                .frame(width: 96, height: 96)
                .shadow(radius: 3, y: 2)
            Text("Inicia sesión")
                .font(.largeTitle.bold())
            Text("Usa tu correo y contraseña. Luego elige el modo de uso.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var form: some View {
        VStack(spacing: 14) {
            TextField("Correo electrónico", text: $email)
                .keyboardType(.emailAddress)
                .textContentType(.username)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focused, equals: .email)
                .submitLabel(.next)
                .onSubmit { focused = .password }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))

            HStack {
                Group {
                    if showPassword {
                        TextField("Contraseña", text: $password)
                            .textContentType(.password)
                    } else {
                        SecureField("Contraseña", text: $password)
                            .textContentType(.password)
                    }
                }
                Button(action: { showPassword.toggle() }) {
                    Image(systemName: showPassword ? "eye.slash" : "eye")
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
        }
    }

    private var rolePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Elegir modo de uso")
                .font(.headline)
            Picker("Rol", selection: $selectedRole) {
                ForEach(AppRole.allCases, id: \.self) { role in
                    Text(role.rawValue).tag(role)
                }
            }
            .pickerStyle(.segmented)
            Text("Puedes cambiarlo luego si tu cuenta permite ambos.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
    }

    private var actions: some View {
        VStack(spacing: 12) {
            Button {
                Task { await login() }
            } label: {
                HStack {
                    if isLoading { ProgressView().tint(.white) }
                    Text(isLoading ? "Entrando..." : "Entrar")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isLoading || email.isEmpty || password.isEmpty)

            Button("¿Olvidaste tu contraseña?") {
                alertMessage = "Flujo de recuperación pendiente de implementar."
                showAlert = true
            }
            .font(.footnote)
            .disabled(isLoading)
        }
    }

    private var footer: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Text("¿No tienes cuenta?")
                Button("Crear cuenta") {
                    alertMessage = "Registro pendiente de implementar."
                    showAlert = true
                }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
    }

    // MARK: - Actions

    private func login() async {
        guard !email.isEmpty, !password.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            try await session.login(email: email, password: password, role: selectedRole)
            // RootView reaccionará y te llevará a Client/Server según el rol.
        } catch {
            alertMessage = error.localizedDescription
            showAlert = true
        }
    }

    // MARK: - Layout helper

    private func idealPadding(for size: CGSize) -> CGFloat {
        let base: CGFloat = 20
        let extra = max(0, (size.width - 430) * 0.15)
        return base + extra
    }
}

#Preview {
    NavigationStack { AuthView().environmentObject(SessionManager()) }
        .previewLayout(.fixed(width: 430, height: 932))
}
