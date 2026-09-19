import Foundation

/// ─────────────────────────────────────────────
///  Auth0 Configuration
///  1. Create a free tenant at https://auth0.com
///  2. Create a "Native" application
///  3. Enable "Google" social connection
///  4. Add callback URL:  com.kisnner.uamschedule://AUTH0_DOMAIN/ios/com.kisnner.uamschedule/callback
///  5. Fill in the values below
/// ─────────────────────────────────────────────
enum Auth0Config {
    static let domain   = "YOUR_TENANT.us.auth0.com"   // your Auth0 tenant domain
    static let clientId = "YOUR_AUTH0_CLIENT_ID"   // Auth0 dashboard → Application Settings

    /// Universal Login URL for Google
    static func authorizeURL(state: String) -> URL? {
        var comps = URLComponents()
        comps.scheme   = "https"
        comps.host     = domain
        comps.path     = "/authorize"
        comps.queryItems = [
            .init(name: "response_type", value: "token id_token"),
            .init(name: "client_id",     value: clientId),
            .init(name: "redirect_uri",  value: callbackURL),
            .init(name: "scope",         value: "openid profile email https://www.googleapis.com/auth/calendar.readonly"),
            .init(name: "connection",    value: "google-oauth2"),
            .init(name: "nonce",         value: state),
            .init(name: "state",         value: state),
        ]
        return comps.url
    }

    static let callbackURL = "com.kisnner.uamschedule://\(domain)/ios/com.kisnner.uamschedule/callback"
}
