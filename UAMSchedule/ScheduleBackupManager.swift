import SwiftUI
import UniformTypeIdentifiers

// ─────────────────────────────────────────────────
// MARK: - Backup Model
// ─────────────────────────────────────────────────

private struct UAMBackup: Codable {
    let version: Int
    let exportedAt: Date
    let courses: [Course]
    let moodEntries: [MoodEntry]
}

// ─────────────────────────────────────────────────
// MARK: - File Type
// ─────────────────────────────────────────────────

extension UTType {
    static let uamBackup = UTType(exportedAs: "com.kisnner.uamschedule.backup")
}

// ─────────────────────────────────────────────────
// MARK: - Document wrapper (for ShareSheet / FileImporter)
// ─────────────────────────────────────────────────

struct UAMBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.uamBackup, .json] }
    var data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        guard let d = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        data = d
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

// ─────────────────────────────────────────────────
// MARK: - Manager
// ─────────────────────────────────────────────────

enum ScheduleBackupManager {

    static func export(store: ScheduleStore) -> Data? {
        let backup = UAMBackup(
            version: 1,
            exportedAt: Date(),
            courses: store.courses,
            moodEntries: store.moodEntries
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(backup)
    }

    @MainActor
    static func `import`(data: Data, into store: ScheduleStore) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(UAMBackup.self, from: data)
        store.courses = backup.courses
        store.save()
        // Merge mood entries (avoid duplicates by id)
        let existingIds = Set(store.moodEntries.map { $0.id })
        let newMoods = backup.moodEntries.filter { !existingIds.contains($0.id) }
        store.moodEntries.append(contentsOf: newMoods)
        store.saveMood()
    }
}

// ─────────────────────────────────────────────────
// MARK: - Backup & Restore View
// ─────────────────────────────────────────────────

struct BackupRestoreView: View {
    @EnvironmentObject var store: ScheduleStore
    @Environment(\.dismiss) private var dismiss

    @State private var exportURL: URL? = nil
    @State private var showShareSheet = false
    @State private var showImporter = false
    @State private var showImportConfirm = false
    @State private var pendingImportData: Data? = nil
    @State private var appeared = false
    @State private var toast: String? = nil
    @State private var toastSuccess = true

    private var formattedNow: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd_HH-mm"
        return "uamschedule_backup_\(f.string(from: Date())).uambackup"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {

                        // Header
                        VStack(alignment: .leading, spacing: 2) {
                            Text("DATA").font(DS.Font.body(9, weight: .semibold))
                                .foregroundStyle(DS.Color.wine).tracking(3)
                            Text("Backup & Restore")
                                .font(DS.Font.display(28, weight: .semibold))
                                .foregroundStyle(Color.appInk)
                            WineAccentLine(height: 1.5, width: 36).padding(.top, 3)
                        }
                        .padding(.horizontal, DS.Space.lg)
                        .padding(.top, 20).padding(.bottom, DS.Space.xl)
                        .opacity(appeared ? 1 : 0)
                        .animation(DS.Anim.easeSlow, value: appeared)

                        // Info card
                        HStack(spacing: 12) {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 20)).foregroundStyle(DS.Color.wine)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Tu horario, materias, notas y calificaciones se guardan en un archivo .uambackup que puedes compartir o guardar en iCloud.")
                                    .font(DS.Font.body(12))
                                    .foregroundStyle(Color.appInkSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .cardStyle()
                        .padding(.horizontal, DS.Space.md)
                        .padding(.bottom, DS.Space.lg)
                        .opacity(appeared ? 1 : 0)
                        .animation(DS.Anim.spring.delay(0.06), value: appeared)

                        // Stats
                        HStack(spacing: 0) {
                            statPill(value: "\(store.courses.count)", label: "Materias")
                            Divider().frame(height: 30).opacity(0.15)
                            statPill(value: "\(store.courses.flatMap { $0.sessions }.count)", label: "Sesiones")
                            Divider().frame(height: 30).opacity(0.15)
                            statPill(value: "\(store.moodEntries.count)", label: "Moods")
                        }
                        .cardStyle()
                        .padding(.horizontal, DS.Space.md)
                        .padding(.bottom, DS.Space.lg)
                        .opacity(appeared ? 1 : 0)
                        .animation(DS.Anim.spring.delay(0.1), value: appeared)

                        // Export
                        BackupToolRow(icon: "square.and.arrow.up.fill",
                                title: "Exportar horario",
                                subtitle: "Guarda un archivo con todo tu semestre",
                                tint: DS.Color.wine) {
                            if let data = ScheduleBackupManager.export(store: store) {
                                let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd_HH-mm"
                                let name = "uamschedule_\(f.string(from: Date())).uamschedule"
                                let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(name)
                                try? data.write(to: tmp)
                                exportURL = tmp
                                showShareSheet = true
                            }
                        }
                        .opacity(appeared ? 1 : 0).offset(y: appeared ? 0 : 8)
                        .animation(DS.Anim.spring.delay(0.14), value: appeared)

                        BackupToolRow(icon: "square.and.arrow.down.fill",
                                title: "Importar horario",
                                subtitle: "Restaura desde un archivo .uamschedule o .json",
                                tint: Color(hex: "#1A4A8A")) {
                            showImporter = true
                        }
                        .opacity(appeared ? 1 : 0).offset(y: appeared ? 0 : 8)
                        .animation(DS.Anim.spring.delay(0.18), value: appeared)

                        Spacer().frame(height: 60)
                    }
                }

                // Toast
                if let msg = toast {
                    VStack {
                        Spacer()
                        HStack(spacing: 10) {
                            Image(systemName: toastSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(toastSuccess ? Color(hex: "#1A5C3A") : .red)
                            Text(msg).font(DS.Font.body(13, weight: .semibold))
                                .foregroundStyle(Color.appInk)
                        }
                        .padding(.horizontal, 20).padding(.vertical, 14)
                        .background(Color.appBackgroundSecondary)
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
                        .padding(.bottom, 40)
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .zIndex(10)
                }
            }
            .navigationTitle("").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }.foregroundStyle(Color.appInkTertiary)
                }
            }
            // Share sheet for export
            .sheet(isPresented: $showShareSheet) {
                if let url = exportURL {
                    ActivityView(activityItems: [url])
                }
            }
            // Import picker
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [.uamBackup, .json],
                allowsMultipleSelection: false
            ) { result in
                guard case .success(let urls) = result,
                      let url = urls.first else { return }
                let ok = url.startAccessingSecurityScopedResource()
                defer { if ok { url.stopAccessingSecurityScopedResource() } }
                if let data = try? Data(contentsOf: url) {
                    pendingImportData = data
                    showImportConfirm = true
                } else {
                    showToast("No se pudo leer el archivo", success: false)
                }
            }
            // Confirm overwrite
            .alert("¿Restaurar horario?", isPresented: $showImportConfirm) {
                Button("Cancelar", role: .cancel) { pendingImportData = nil }
                Button("Restaurar", role: .destructive) {
                    if let data = pendingImportData {
                        do {
                            try ScheduleBackupManager.import(data: data, into: store)
                            showToast("Horario restaurado ✓", success: true)
                        } catch {
                            showToast("Archivo inválido", success: false)
                        }
                    }
                    pendingImportData = nil
                }
            } message: {
                Text("Esto reemplazará tus materias actuales con las del archivo. Los moods se combinarán.")
            }
        }
        .onAppear { appeared = true }
    }

    // ── Helpers ──────────────────────────────────

    @ViewBuilder
    private func statPill(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value).font(DS.Font.display(22, weight: .semibold)).foregroundStyle(DS.Color.wine)
            Text(label).font(DS.Font.body(10)).foregroundStyle(Color.appInkTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }

    private func showToast(_ msg: String, success: Bool) {
        withAnimation(DS.Anim.spring) { toast = msg; toastSuccess = success }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation { toast = nil }
        }
    }
}

// ─────────────────────────────────────────────────
// MARK: - UIActivityViewController wrapper
// ─────────────────────────────────────────────────
import UIKit

struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ uvc: UIActivityViewController, context: Context) {}
}

// ─────────────────────────────────────────────────
// MARK: - ToolRow for Backup UI
// ─────────────────────────────────────────────────
private struct BackupToolRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(tint.opacity(0.1)).frame(width: 46, height: 46)
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .medium)).foregroundStyle(tint)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(DS.Font.body(15, weight: .semibold)).foregroundStyle(Color.appInk)
                    Text(subtitle).font(DS.Font.body(11)).foregroundStyle(Color.appInkTertiary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.appInkTertiary.opacity(0.4))
            }
            .cardStyle()
            .padding(.horizontal, DS.Space.md)
            .padding(.bottom, DS.Space.sm)
        }
        .buttonStyle(.plain)
    }
}
