import SwiftUI
import UniformTypeIdentifiers

// MARK: - Backup View

struct ScheduleBackupView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: ScheduleStore
    @State private var appeared = false
    @State private var showExporter = false
    @State private var showImporter = false
    @State private var exportDoc: ScheduleDocument? = nil
    @State private var showImportSuccess = false
    @State private var importedCount = 0
    @State private var showImportError = false
    @State private var showClearConfirm = false
    @State private var shareText: ShareTextWrapper? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {

                        // Header
                        VStack(alignment: .leading, spacing: 2) {
                            Text("DATOS").font(DS.Font.body(9, weight: .semibold))
                                .foregroundStyle(DS.Color.wine).tracking(3)
                            Text("Exportar & Importar")
                                .font(DS.Font.display(28, weight: .semibold)).foregroundStyle(Color.appInk)
                            WineAccentLine(height: 1.5, width: 36).padding(.top, 3)
                            Text("\(store.courses.count) materias guardadas")
                                .font(DS.Font.body(12)).foregroundStyle(Color.appInkTertiary).padding(.top, 3)
                        }
                        .padding(.horizontal, DS.Space.lg)
                        .padding(.top, 20).padding(.bottom, DS.Space.xl)
                        .opacity(appeared ? 1 : 0).animation(DS.Anim.easeSlow, value: appeared)

                        // Export section
                        VStack(alignment: .leading, spacing: DS.Space.sm) {
                            SectionLabel2("EXPORTAR")

                            VStack(spacing: 8) {
                                // Export as JSON file
                                BackupActionRow(
                                    icon: "square.and.arrow.up",
                                    title: "Exportar horario",
                                    subtitle: "Guarda todas tus materias en un archivo .uamschedule",
                                    color: DS.Color.wine
                                ) {
                                    // Use ScheduleBackupManager so the format matches the importer
                                    if let data = ScheduleBackupManager.export(store: store),
                                       let json = String(data: data, encoding: .utf8) {
                                        exportDoc = ScheduleDocument(json: json)
                                        showExporter = true
                                    }
                                }

                                // Share as text summary
                                BackupActionRow(
                                    icon: "text.bubble",
                                    title: "Compartir resumen",
                                    subtitle: "Comparte tu horario como texto legible",
                                    color: DS.Color.wine
                                ) {
                                    shareText = ShareTextWrapper(text: buildShareText())
                                }
                            }
                        }
                        .padding(.horizontal, DS.Space.md)
                        .padding(.bottom, DS.Space.xl)
                        .opacity(appeared ? 1 : 0).animation(DS.Anim.spring.delay(0.08), value: appeared)

                        // Import section
                        VStack(alignment: .leading, spacing: DS.Space.sm) {
                            SectionLabel2("IMPORTAR")

                            VStack(spacing: 8) {
                                BackupActionRow(
                                    icon: "square.and.arrow.down",
                                    title: "Importar horario",
                                    subtitle: "Carga un archivo .uamschedule exportado anteriormente",
                                    color: DS.Color.wine
                                ) {
                                    showImporter = true
                                }
                            }
                        }
                        .padding(.horizontal, DS.Space.md)
                        .padding(.bottom, DS.Space.xl)
                        .opacity(appeared ? 1 : 0).animation(DS.Anim.spring.delay(0.12), value: appeared)

                        // Danger zone
                        VStack(alignment: .leading, spacing: DS.Space.sm) {
                            SectionLabel2("ZONA DE PELIGRO")

                            BackupActionRow(
                                icon: "trash.fill",
                                title: "Borrar todo el horario",
                                subtitle: "Elimina todas las materias permanentemente",
                                color: Color(hex: "#CC1A1A")
                            ) {
                                showClearConfirm = true
                            }
                        }
                        .padding(.horizontal, DS.Space.md)
                        .padding(.bottom, 40)
                        .opacity(appeared ? 1 : 0).animation(DS.Anim.spring.delay(0.16), value: appeared)

                        // Info
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle").font(.system(size: 13)).foregroundStyle(Color.appInkTertiary)
                            Text("El archivo .uamschedule contiene todas tus materias, horarios, recordatorios, notas y calificaciones.")
                                .font(DS.Font.body(11)).foregroundStyle(Color.appInkTertiary).lineSpacing(2)
                        }
                        .padding(.horizontal, DS.Space.lg)
                        .padding(.bottom, 40)
                        .opacity(appeared ? 1 : 0).animation(DS.Anim.spring.delay(0.18), value: appeared)
                    }
                }
            }
            .navigationTitle("").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }.foregroundStyle(Color.appInkTertiary)
                }
            }
            // Export file
            .fileExporter(
                isPresented: $showExporter,
                document: exportDoc,
                contentType: .uamBackup,   // matches Info.plist UTExportedTypeDeclarations
                defaultFilename: "uamschedule_\(formattedDate())"
            ) { result in
                if case .failure(let err) = result { print("Export error: \(err)") }
            }
            // Import file
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [.uamBackup, .json],   // same type as what we export
                allowsMultipleSelection: false
            ) { result in
                handleImport(result)
            }
            // Share sheet
            .sheet(item: $shareText) { wrapper in
                ShareSheetView(text: wrapper.text)
            }
            // Alerts
            .alert("Importación exitosa", isPresented: $showImportSuccess) {
                Button("OK") {}
            } message: {
                Text("Se importaron \(importedCount) materia\(importedCount == 1 ? "" : "s") correctamente.")
            }
            .alert("Error al importar", isPresented: $showImportError) {
                Button("OK") {}
            } message: {
                Text("El archivo no es válido o está corrupto.")
            }
            .confirmationDialog("¿Borrar todo el horario?", isPresented: $showClearConfirm, titleVisibility: .visible) {
                Button("Borrar todo", role: .destructive) {
                    withAnimation(DS.Anim.spring) {
                        store.courses.forEach { CoursePhotoStore.delete(for: $0.id) }
                        store.courses = []
                        store.save()
                    }
                }
                Button("Cancelar", role: .cancel) {}
            } message: {
                Text("Esta acción no se puede deshacer.")
            }
        }
        .onAppear { appeared = true }
    }

    // MARK: - Helpers

    func handleImport(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let url = urls.first else { return }
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }

        do {
            let data = try Data(contentsOf: url)
            // Delegate to ScheduleBackupManager which understands the UAMBackup envelope
            // (version, exportedAt, courses, moodEntries) written by the exporter.
            try ScheduleBackupManager.import(data: data, into: store)
            importedCount = store.courses.count
            showImportSuccess = true
        } catch {
            showImportError = true
        }
    }

    func buildShareText() -> String {
        guard !store.courses.isEmpty else { return "No tienes materias registradas aún." }
        let dayNames = ["","Dom","Lun","Mar","Mié","Jue","Vie","Sáb"]
        var lines: [String] = ["📅 Mi Horario UAM — \(semesterLabel())", ""]
        for c in store.courses {
            var line = "• \(c.name)"
            if !c.code.isEmpty { line += " (\(c.code))" }
            lines.append(line)
            for s in c.sessions {
                let day = dayNames[s.weekday]
                let time = "\(s.startTimeString) – \(s.endTimeString)"
                let room = c.room.isEmpty ? "" : " · \(c.room)"
                lines.append("  \(day) \(time)\(room)")
            }
            if c.grades.total > 0 {
                lines.append("  Notas: \(Int(c.grades.corte1))/\(Int(c.grades.corte2))/\(Int(c.grades.corte3)) = \(Int(c.grades.total))/300")
            }
        }
        lines.append("")
        lines.append("📊 \(store.courses.count) materias · \(store.courses.reduce(0){$0+$1.credits}) créditos")
        return lines.joined(separator: "\n")
    }

    func semesterLabel() -> String {
        let f = DateFormatter(); f.dateFormat = "MMMM yyyy"; f.locale = Locale(identifier: "es")
        return f.string(from: Date()).capitalized
    }

    func formattedDate() -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: Date())
    }
}

// MARK: - Document Type
// NOTE: UTType.uamBackup is declared in ScheduleBackupManager.swift and
// registered in Info.plist as com.kisnner.uamschedule.backup.
// ScheduleDocument wraps that same type so fileExporter uses the registered UTI.

struct ScheduleDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.uamBackup, .json] }
    var json: String

    init(json: String) { self.json = json }
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let str = String(data: data, encoding: .utf8) else { throw CocoaError(.fileReadCorruptFile) }
        json = str
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(json.utf8))
    }
}

// MARK: - Share Sheet

struct ShareTextWrapper: Identifiable { let id = UUID(); let text: String }

struct ShareSheetView: View {
    let text: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                VStack(spacing: DS.Space.lg) {
                    ScrollView(showsIndicators: false) {
                        Text(text)
                            .font(DS.Font.body(13))
                            .foregroundStyle(Color.appInk)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(DS.Space.md)
                            .background(Color.appBackgroundSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                            .padding(.horizontal, DS.Space.md)
                            .padding(.top, DS.Space.lg)
                    }

                    HStack(spacing: 12) {
                        ShareLink(item: text) {
                            Label("Compartir", systemImage: "square.and.arrow.up")
                                .font(DS.Font.body(15, weight: .bold)).foregroundStyle(.white)
                                .frame(maxWidth: .infinity).padding(.vertical, 14)
                                .background(DS.Color.wine)
                                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                        }
                        .buttonStyle(.plain)

                        Button {
                            UIPasteboard.general.string = text
                            dismiss()
                        } label: {
                            Label("Copiar", systemImage: "doc.on.doc")
                                .font(DS.Font.body(15, weight: .semibold))
                                .foregroundStyle(DS.Color.wine)
                                .frame(maxWidth: .infinity).padding(.vertical, 14)
                                .background(DS.Color.wineMuted)
                                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, DS.Space.md)
                    .padding(.bottom, DS.Space.lg)
                }
            }
            .navigationTitle("Compartir horario").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }.foregroundStyle(Color.appInkTertiary)
                }
            }
        }
    }
}

// MARK: - Helper Components

struct SectionLabel2: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text).font(DS.Font.body(9, weight: .semibold))
            .foregroundStyle(Color.appInkTertiary).tracking(2).padding(.horizontal, 4)
    }
}

struct BackupActionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                        .fill(color.opacity(0.1)).frame(width: 40, height: 40)
                    Image(systemName: icon).font(.system(size: 16, weight: .medium)).foregroundStyle(color)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(DS.Font.body(14, weight: .semibold)).foregroundStyle(Color.appInk)
                    Text(subtitle).font(DS.Font.body(11)).foregroundStyle(Color.appInkTertiary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.appInkTertiary.opacity(0.4))
            }
            .padding(14)
            .background(Color.appBackgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).stroke(Color.appCardBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
