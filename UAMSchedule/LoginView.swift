import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @EnvironmentObject var profile: UserProfile
    @State private var isLoading = false
    @State private var errorMsg: String? = nil
    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Logo mark
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(DS.Color.wineMuted)
                        .frame(width: 80, height: 80)
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(DS.Color.wine)
                        .frame(width: 38, height: 38)
                }
                .scaleEffect(appeared ? 1 : 0.8)
                .opacity(appeared ? 1 : 0)
                .animation(DS.Anim.spring.delay(0.05), value: appeared)

                Spacer().frame(height: 32)

                VStack(spacing: 8) {
                    Text("UAMSchedule")
                        .font(DS.Font.display(30, weight: .semibold))
                        .foregroundStyle(Color.appInk)
                    WineAccentLine(height: 1.5, width: 32)
                    Text("Tu semestre, organizado.")
                        .font(DS.Font.body(14))
                        .foregroundStyle(Color.appInkTertiary)
                        .padding(.top, 2)
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)
                .animation(DS.Anim.easeSlow.delay(0.12), value: appeared)

                Spacer()

                VStack(spacing: 12) {
                    Button { signInWithGoogle() } label: {
                        HStack(spacing: 10) {
                            if isLoading {
                                ProgressView().progressViewStyle(.circular).tint(.white).scaleEffect(0.85)
                            } else {
                                Image(systemName: "globe").font(.system(size: 16, weight: .semibold))
                            }
                            Text(isLoading ? "Conectando..." : "Continuar con Google")
                                .font(DS.Font.body(15, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(DS.Color.wine)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
                        .shadow(color: DS.Color.wine.opacity(0.25), radius: 12, y: 4)
                    }
                    .buttonStyle(.plain)
                    .disabled(isLoading)

                    if let err = errorMsg {
                        Text(err)
                            .font(DS.Font.body(12))
                            .foregroundStyle(Color.red.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }

                    Text("Al continuar aceptas los terminos de uso.\nDatos protegidos con Auth0.")
                        .font(DS.Font.body(11))
                        .foregroundStyle(Color.appInkTertiary.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .padding(.top, 6)
                }
                .padding(.horizontal, DS.Space.xl)
                .padding(.bottom, 52)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 20)
                .animation(DS.Anim.easeSlow.delay(0.22), value: appeared)
            }
        }
        .onAppear { withAnimation { appeared = true } }
    }

    private func signInWithGoogle() {
        guard let url = Auth0Config.authorizeURL(state: UUID().uuidString) else {
            errorMsg = "Error al construir la URL."; return
        }
        isLoading = true; errorMsg = nil
        let session = ASWebAuthenticationSession(url: url, callbackURLScheme: "com.kisnner.uamschedule") { cb, error in
            DispatchQueue.main.async {
                isLoading = false
                if let error = error as? ASWebAuthenticationSessionError, error.code == .canceledLogin { return }
                guard let cb = cb else { errorMsg = error?.localizedDescription ?? "Error al iniciar sesion."; return }
                handleCallback(cb)
            }
        }
        session.prefersEphemeralWebBrowserSession = false
        session.presentationContextProvider = PresentationAnchor.shared
        session.start()
    }

    private func handleCallback(_ url: URL) {
        guard let fragment = url.fragment else { errorMsg = "Respuesta invalida."; return }
        var params: [String: String] = [:]
        for pair in fragment.split(separator: "&") {
            let kv = pair.split(separator: "=", maxSplits: 1)
            if kv.count == 2 { params[String(kv[0])] = String(kv[1]).removingPercentEncoding }
        }
        guard let idToken = params["id_token"] else { errorMsg = "Token no recibido."; return }
        let parts = idToken.split(separator: ".")
        if parts.count >= 2 {
            var b64 = String(parts[1]); let r = b64.count % 4; if r != 0 { b64 += String(repeating: "=", count: 4 - r) }
            if let data = Data(base64Encoded: b64), let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                profile.name = json["name"] as? String ?? ""
                profile.email = json["email"] as? String ?? ""
                profile.avatarURL = json["picture"] as? String ?? ""
            }
        }
        UserDefaults.standard.set(idToken, forKey: "auth_idToken")
        if let at = params["access_token"] { UserDefaults.standard.set(at, forKey: "auth_accessToken") }
        profile.isLoggedIn = true
    }
}

final class PresentationAnchor: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = PresentationAnchor()
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first?.windows.first ?? ASPresentationAnchor()
    }
}
