import Foundation
import UserNotifications

// MARK: - Models

public struct MoodleMessage: Identifiable, Codable, Equatable {
    public var id: Int
    public var fromUserId: Int
    public var fromName: String
    public var subject: String
    public var text: String
    public var timeSent: Date
    public var isRead: Bool

    public var timeString: String {
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: "es_NI")
        f.unitsStyle = .short
        return f.localizedString(for: timeSent, relativeTo: Date())
    }

    public var previewText: String {
        String(text.prefix(120))
    }
}

public struct MoodleNotification: Identifiable, Codable, Equatable {
    public var id: Int
    public var subject: String
    public var text: String
    public var timeCreated: Date
    public var isRead: Bool
    public var component: String

    public var typeLabel: String {
        switch component {
        case "mod_assign":  return "Tarea"
        case "core_message": return "Mensaje"
        case "mod_forum":   return "Foro"
        default:            return "Aviso"
        }
    }

    public var sfIcon: String {
        switch component {
        case "mod_assign":   return "pencil.and.list.clipboard"
        case "core_message": return "message.fill"
        case "mod_forum":    return "bubble.left.and.bubble.right.fill"
        default:             return "bell.fill"
        }
    }

    public var timeString: String {
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: "es_NI")
        f.unitsStyle = .short
        return f.localizedString(for: timeCreated, relativeTo: Date())
    }

    public var previewText: String {
        String(text.prefix(120))
    }
}

// MARK: - Store

@MainActor
public class MoodleMessagingStore: ObservableObject {
    public static let shared = MoodleMessagingStore()

    @Published public var messages: [MoodleMessage] = []
    @Published public var notifications: [MoodleNotification] = []
    @Published public var isLoading: Bool = false
    @Published public var error: String? = nil

    private let seenMsgKey  = "moodle_seen_msgs"
    private let seenNotiKey = "moodle_seen_notis"

    private var seenMsgIds: Set<Int> {
        get { Set(UserDefaults.standard.array(forKey: seenMsgKey) as? [Int] ?? []) }
        set { UserDefaults.standard.set(Array(newValue), forKey: seenMsgKey) }
    }
    private var seenNotiIds: Set<Int> {
        get { Set(UserDefaults.standard.array(forKey: seenNotiKey) as? [Int] ?? []) }
        set { UserDefaults.standard.set(Array(newValue), forKey: seenNotiKey) }
    }

    public var unreadMessages: Int      { messages.filter { !$0.isRead }.count }
    public var unreadNotifications: Int { notifications.filter { !$0.isRead }.count }
    public var totalUnread: Int         { unreadMessages + unreadNotifications }

    public func sync(token: String) async {
        guard !token.isEmpty else { return }
        isLoading = true
        error = nil
        do {
            let userId   = try await fetchUserId(token: token)
            let newMsgs  = try await fetchMessages(token: token, userId: userId)
            let newNotis = try await fetchNotifications(token: token, userId: userId)
            fireMessageNotifications(newMsgs)
            fireNotiAlerts(newNotis)
            messages      = newMsgs
            notifications = newNotis
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    private func fetchUserId(token: String) async throws -> Int {
        let data = try await callAPI(params: "wstoken=\(token)&wsfunction=core_webservice_get_site_info&moodlewsrestformat=json")
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let uid = json?["userid"] as? Int else { throw URLError(.badServerResponse) }
        return uid
    }

    private func fetchMessages(token: String, userId: Int) async throws -> [MoodleMessage] {
        // Usar core_message_get_conversations para obtener lista de conversaciones
        // exactamente igual que la app oficial de Moodle
        let params = "wstoken=\(token)&wsfunction=core_message_get_conversations&moodlewsrestformat=json&userid=\(userId)&type=1&limitnum=50&limitfrom=0"
        let data = try await callAPI(params: params)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let convs = json["conversations"] as? [[String: Any]] else {
            // Fallback al metodo antiguo si el servidor no soporta el nuevo endpoint
            return try await fetchMessagesFallback(token: token, userId: userId)
        }
        storedUserId = userId
        return convs.compactMap { conv -> MoodleMessage? in
            guard let id = conv["id"] as? Int else { return nil }
            let members  = conv["members"] as? [[String: Any]] ?? []
            // El otro participante (no yo)
            let other    = members.first { ($0["id"] as? Int ?? 0) != userId }
            let fromName = other?["fullname"] as? String ?? "Moodle"
            let fromId   = other?["id"] as? Int ?? 0
            let msgs     = conv["messages"] as? [[String: Any]] ?? []
            let lastMsg  = msgs.first
            let ts       = lastMsg?["timecreated"] as? Int ?? 0
            let text     = ((lastMsg?["text"] as? String) ?? "").strippingHTML()
            let isRead   = (conv["isread"] as? Bool) ?? true
            return MoodleMessage(
                id: id,
                fromUserId: fromId,
                fromName: fromName,
                subject: conv["name"] as? String ?? fromName,
                text: text,
                timeSent: Date(timeIntervalSince1970: TimeInterval(ts)),
                isRead: isRead
            )
        }
    }

    private var storedUserId: Int = 0

    private func fetchMessagesFallback(token: String, userId: Int) async throws -> [MoodleMessage] {
        let params = "wstoken=\(token)&wsfunction=core_message_get_messages&moodlewsrestformat=json&useridto=\(userId)&type=both&read=0&newestfirst=1&limitnum=50"
        let data = try await callAPI(params: params)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let msgs = json["messages"] as? [[String: Any]] else { return [] }
        return msgs.compactMap { m -> MoodleMessage? in
            guard let id = m["id"] as? Int,
                  (m["useridfrom"] as? Int ?? 0) != userId else { return nil } // solo recibidos
            let ts = m["timecreated"] as? Int ?? 0
            return MoodleMessage(
                id: id, fromUserId: m["useridfrom"] as? Int ?? 0,
                fromName: m["userfromfullname"] as? String ?? "Moodle",
                subject: m["subject"] as? String ?? "(sin asunto)",
                text: (m["text"] as? String ?? "").strippingHTML(),
                timeSent: Date(timeIntervalSince1970: TimeInterval(ts)),
                isRead: (m["read"] as? Int ?? 0) == 1
            )
        }
    }

    /// Enviar mensaje de respuesta a un usuario
    public func sendMessage(token: String, toUserId: Int, text: String) async throws {
        let escaped = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? text
        let params = "wstoken=\(token)&wsfunction=core_message_send_instant_messages&moodlewsrestformat=json&messages[0][touserid]=\(toUserId)&messages[0][text]=\(escaped)&messages[0][textformat]=0"
        _ = try await callAPI(params: params)
    }

    private func fetchNotifications(token: String, userId: Int) async throws -> [MoodleNotification] {
        let params = "wstoken=\(token)&wsfunction=message_popup_get_popup_notifications&moodlewsrestformat=json&useridto=\(userId)&newestfirst=1&limit=50"
        let data = try await callAPI(params: params)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let notis = json["notifications"] as? [[String: Any]] else { return [] }
        return notis.compactMap { n -> MoodleNotification? in
            guard let id = n["id"] as? Int else { return nil }
            let ts = n["timecreated"] as? Int ?? 0
            let text = (n["fullmessagehtml"] as? String
                        ?? n["fullmessage"] as? String
                        ?? n["smallmessage"] as? String ?? "").strippingHTML()
            return MoodleNotification(
                id: id, subject: n["subject"] as? String ?? "(aviso)",
                text: text, timeCreated: Date(timeIntervalSince1970: TimeInterval(ts)),
                isRead: (n["read"] as? Int ?? 0) == 1,
                component: n["component"] as? String ?? "core"
            )
        }
    }

    private func fireMessageNotifications(_ incoming: [MoodleMessage]) {
        var seen = seenMsgIds
        let center = UNUserNotificationCenter.current()
        for msg in incoming where !msg.isRead {
            guard !seen.contains(msg.id) else { continue }
            seen.insert(msg.id)
            let content = UNMutableNotificationContent()
            content.title = "Mensaje de \(msg.fromName)"
            content.body  = msg.previewText.isEmpty ? msg.subject : msg.previewText
            content.sound = .default
            content.interruptionLevel = .active
            content.categoryIdentifier = "UAM_MOODLE_MESSAGE"
            content.userInfo = ["moodleMsgId": msg.id]
            let req = UNNotificationRequest(
                identifier: "uam-moodle-msg-\(msg.id)",
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: 0.5, repeats: false)
            )
            center.add(req) { _ in }
        }
        seenMsgIds = seen
    }

    private func fireNotiAlerts(_ incoming: [MoodleNotification]) {
        var seen = seenNotiIds
        let center = UNUserNotificationCenter.current()
        for noti in incoming where !noti.isRead {
            guard !seen.contains(noti.id) else { continue }
            seen.insert(noti.id)
            let content = UNMutableNotificationContent()
            content.title    = noti.subject.isEmpty ? "Aviso de Moodle" : noti.subject
            content.body     = noti.previewText.isEmpty ? noti.typeLabel : noti.previewText
            content.subtitle = noti.typeLabel
            content.sound    = .default
            content.interruptionLevel = .active
            content.categoryIdentifier = "UAM_MOODLE_NOTIFICATION"
            content.userInfo = ["moodleNotiId": noti.id]
            let req = UNNotificationRequest(
                identifier: "uam-moodle-noti-\(noti.id)",
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1.0, repeats: false)
            )
            center.add(req) { _ in }
        }
        seenNotiIds = seen
    }

    public func markMessageRead(_ id: Int) {
        if let i = messages.firstIndex(where: { $0.id == id }) { messages[i].isRead = true }
    }
    public func markNotificationRead(_ id: Int) {
        if let i = notifications.firstIndex(where: { $0.id == id }) { notifications[i].isRead = true }
    }

    private func callAPI(params: String) async throws -> Data {
        guard let url = URL(string: "https://uamvirtual.uam.edu.ni/grado/webservice/rest/server.php") else {
            throw URLError(.badURL)
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = params.data(using: .utf8)
        req.timeoutInterval = 15
        let (data, _) = try await URLSession.shared.data(for: req)
        return data
    }
}
