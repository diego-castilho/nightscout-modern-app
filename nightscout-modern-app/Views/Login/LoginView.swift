import SwiftUI

struct LoginView: View {
    @Environment(AuthStore.self) private var authStore

    @State private var serverURL = ""
    @State private var password = ""

    var body: some View {
        @Bindable var auth = authStore

        VStack(spacing: 32) {
            Spacer()

            // Logo
            VStack(spacing: 12) {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 48))
                    .foregroundStyle(GlucoseColors.inRange)

                Text("Nightscout Modern")
                    .font(.title.bold())

                Text("Monitoramento contínuo de glicose")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Form
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("URL do Servidor")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    TextField("https://seu-servidor.com/api", text: $serverURL)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.URL)
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        #endif
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Senha (API_SECRET)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    SecureField("Senha", text: $password)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.password)
                }

                if let error = authStore.error {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button {
                    authStore.serverURL = serverURL
                    Task {
                        await authStore.login(password: password)
                    }
                } label: {
                    if authStore.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Entrar")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(serverURL.isEmpty || password.isEmpty || authStore.isLoading)
            }
            .padding(.horizontal, 4)

            Spacer()
            Spacer()
        }
        .padding(32)
        .frame(maxWidth: 400)
        .frame(maxWidth: .infinity)
        .onAppear {
            serverURL = authStore.serverURL
        }
    }
}
