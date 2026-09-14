import Foundation
import Security

struct SupabaseConfiguration {
    let projectURL: URL
    let anonKey: String
    let functionName: String

    static let moonPlace = SupabaseConfiguration(
        projectURL: URL(string: "https://YOUR_PROJECT_REF.supabase.co")!,
        anonKey: "YOUR_SUPABASE_ANON_KEY",
        functionName: "moon-auth"
    )
}

protocol MoonPlaceAuthenticationClient {
    func login(username: String, password: String, key: String) async throws -> MoonPlaceAuthenticationResult
    func register(username: String, password: String, key: String, phone: String) async throws -> MoonPlaceAuthenticationResult
}

struct MoonPlaceAuthenticationResult {
    let username: String
    let phone: String
    let expiresAt: Date?
}

enum SupabaseAuthenticationError: LocalizedError {
    case endpointNotConfigured
    case invalidResponse
    case server(String)

    var errorDescription: String? {
        switch self {
        case .endpointNotConfigured:
            return "Supabase project URL or anon key is not configured."
        case .invalidResponse:
            return "Supabase returned an invalid response."
        case .server(let message):
            return message
        }
    }
}

final class SupabaseAuthenticationClient: MoonPlaceAuthenticationClient {
    private let configuration: SupabaseConfiguration

    init(configuration: SupabaseConfiguration = .moonPlace) {
        self.configuration = configuration
    }

    func login(username: String, password: String, key: String) async throws -> MoonPlaceAuthenticationResult {
        try await request(action: "login", username: username, password: password, key: key, phone: "")
    }

    func register(username: String, password: String, key: String, phone: String) async throws -> MoonPlaceAuthenticationResult {
        try await request(action: "register", username: username, password: password, key: key, phone: phone)
    }

    private func request(
        action: String,
        username: String,
        password: String,
        key: String,
        phone: String
    ) async throws -> MoonPlaceAuthenticationResult {
        guard !configuration.projectURL.absoluteString.contains("YOUR_PROJECT_REF"),
              !configuration.anonKey.contains("YOUR_SUPABASE_ANON_KEY") else {
            throw SupabaseAuthenticationError.endpointNotConfigured
        }
        let endpoint = configuration.projectURL
            .appendingPathComponent("functions")
            .appendingPathComponent("v1")
            .appendingPathComponent(configuration.functionName)
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue(configuration.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(configuration.anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "action": action,
            "username": username,
            "password": password,
            "key": key,
            "phone": phone
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseAuthenticationError.invalidResponse
        }
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw SupabaseAuthenticationError.server(object?["message"] as? String ?? "Authentication failed.")
        }
        guard let object,
              let returnedUsername = object["username"] as? String,
              let returnedPhone = object["phone"] as? String,
              let expiresText = object["expires_at"] as? String,
              let expiresAt = ISO8601DateFormatter().date(from: expiresText) else {
            throw SupabaseAuthenticationError.invalidResponse
        }
        if let accessToken = object["access_token"] as? String {
            KeychainTokenStore.save(accessToken, account: returnedUsername)
        }
        return MoonPlaceAuthenticationResult(
            username: returnedUsername,
            phone: returnedPhone,
            expiresAt: expiresAt
        )
    }
}

private enum KeychainTokenStore {
    static func save(_ token: String, account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecValueData as String: Data(token.utf8)
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
}
