import Foundation

@Observable
final class AuthStore {
    var isAuthenticated = false
    var serverURL: String = "" {
        didSet { UserDefaults.standard.set(serverURL, forKey: "serverURL") }
    }
    var isLoading = false
    var error: String?

    init() {
        serverURL = UserDefaults.standard.string(forKey: "serverURL") ?? ""
        isAuthenticated = KeychainService.load(forKey: "authToken") != nil
    }

    var apiClient: APIClient? {
        guard let url = URL(string: serverURL), !serverURL.isEmpty else { return nil }
        return APIClient(baseURL: url)
    }

    func login(password: String) async {
        guard let client = apiClient else {
            error = "URL do servidor inválida"
            return
        }

        isLoading = true
        error = nil

        do {
            let response = try await client.login(password: password)
            KeychainService.save(token: response.token, forKey: "authToken")
            isAuthenticated = true
        } catch let apiError as APIError {
            switch apiError {
            case .unauthorized:
                error = "Senha incorreta"
            default:
                error = apiError.localizedDescription
            }
        } catch _ {
            self.error = "Erro ao conectar ao servidor"
        }

        isLoading = false
    }

    func logout() {
        KeychainService.delete(forKey: "authToken")
        isAuthenticated = false
    }
}
