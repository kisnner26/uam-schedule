import SwiftUI
import Foundation

class UserProfile: ObservableObject {
    @AppStorage("profile_name")        var name: String = ""
    @AppStorage("profile_university")  var university: String = ""
    @AppStorage("profile_career")      var career: String = ""
    @AppStorage("profile_semester")    var semester: String = ""
    @AppStorage("profile_accentColor") var accentColorHex: String = "#6B1A2A"
    @AppStorage("profile_showGreeting")    var showGreeting: Bool = true
    @AppStorage("profile_compactMode")     var compactMode: Bool = false
    @AppStorage("profile_showProgressBar") var showProgressBar: Bool = true
    @AppStorage("profile_hasPhoto")        var hasPhoto: Bool = false

    // Auth
    @AppStorage("auth_isLoggedIn")   var isLoggedIn: Bool = false
    @AppStorage("auth_email")        var email: String = ""
    @AppStorage("auth_avatarURL")    var avatarURL: String = ""

    var accentColor: Color { Color(hex: accentColorHex) }

    var profileImageData: Data? {
        get { UserDefaults.standard.data(forKey: "profile_photo") }
        set { UserDefaults.standard.set(newValue, forKey: "profile_photo") }
    }

    var profileImage: UIImage? {
        guard let data = profileImageData else { return nil }
        return UIImage(data: data)
    }

    func logOut() {
        isLoggedIn = false
        email = ""
        avatarURL = ""
        name = ""
        university = ""
        career = ""
        semester = ""
        hasPhoto = false
        profileImageData = nil
        UserDefaults.standard.removeObject(forKey: "onboardingDone")
        UserDefaults.standard.removeObject(forKey: "auth_idToken")
    }
}

// MARK: - Preview Helper
// Bug fix: .preview static property was missing, causing MoodleTodaySection
// preview to fail to compile.

extension UserProfile {
    static var preview: UserProfile {
        let p = UserProfile()
        p.name = "Estudiante UAM"
        p.university = "Universidad Americana"
        p.career = "Ingeniería en Sistemas"
        p.semester = "5to Semestre"
        return p
    }
}
