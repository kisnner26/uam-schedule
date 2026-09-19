import SwiftUI
import UniformTypeIdentifiers
import QuickLook

// ═══════════════════════════════════════════════════════
// MARK: - Submission Sheet
// ═══════════════════════════════════════════════════════

struct MoodleSubmissionView: View {
    let assignment: MoodleAssignment
    @StateObject private var ext = MoodleExtendedStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var appeared = false

    // ── File picker state ─────────────────────────
    @State private var showFilePicker    = false
    @State private var showDocPicker     = false
    @State private var selectedFileURL: URL? = nil
    @State private var selectedFileName  = ""
    @State private var selectedFileMime  = ""
    @State private var selectedFileSize  = 0

    // ── Preview ───────────────────────────────────
    @State private var quickLookURL: URL? = nil

    // ── Confirm ───────────────────────────────────
    @State private var showConfirm = false

    private var subStatus: MoodleSubmissionStatus? {
        ext.submissionStatusCache[assignment.id]
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: DS.Space.lg) {

                        // ── Assignment info ───────────────────
                        AssignmentHeaderCard(assignment: assignment)
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 8)
                            .animation(DS.Anim.easeSlow.delay(0.08), value: appeared)

                        // ── Current submission status ─────────
                        if let sub = subStatus {
                            SubmissionStatusCard(status: sub)
                                .opacity(appeared ? 1 : 0)
                                .animation(DS.Anim.easeSlow.delay(0.12), value: appeared)
                        } else if ext.loadingSubmissions.contains(assignment.id) {
                            HStack(spacing: DS.Space.sm) {
                                ProgressView().scaleEffect(0.75)
                                Text("Verificando entrega anterior...")
                                    .font(DS.Font.body(12))
                                    .foregroundStyle(Color.appInkTertiary)
                            }
                        }

                        // ── Upload section ────────────────────
                        if !assignment.noSubmissions {
                            UploadSection(
                                selectedFileURL: $selectedFileURL,
                                selectedFileName: $selectedFileName,
                                selectedFileMime: $selectedFileMime,
                                selectedFileSize: $selectedFileSize,
                                showFilePicker: $showFilePicker,
                                showDocPicker: $showDocPicker,
                                quickLookURL: $quickLookURL,
                                showConfirm: $showConfirm,
                                isUploading: ext.isUploading,
                                uploadProgress: ext.uploadProgress,
                                uploadSuccess: ext.uploadSuccess,
                                uploadError: ext.uploadError
                            )
                            .opacity(appeared ? 1 : 0)
                            .animation(DS.Anim.easeSlow.delay(0.16), value: appeared)
                        }

                        Spacer().frame(height: 60)
                    }
                    .padding(.horizontal, DS.Space.md)
                    .padding(.top, DS.Space.md)
                }
            }
            .navigationTitle("Entrega")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                        .foregroundStyle(Color.appInkTertiary)
                }
            }
        }

        // ── File pickers ──────────────────────────────
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.pdf, .data],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result: result)
        }
        .fileImporter(
            isPresented: $showDocPicker,
            allowedContentTypes: [
                UTType("com.microsoft.word.doc") ?? .data,
                UTType("org.openxmlformats.wordprocessingml.document") ?? .data,
                .pdf
            ],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result: result)
        }

        // ── QuickLook preview ─────────────────────────
        .quickLookPreview($quickLookURL)

        // ── Submit confirmation ───────────────────────
        .alert("Confirmar entrega", isPresented: $showConfirm) {
            Button("Cancelar", role: .cancel) {}
            Button("Entregar") {
                guard let url = selectedFileURL else { return }
                Task {
                    await ext.submitFile(
                        assignmentId: assignment.id,
                        fileURL: url,
                        filename: selectedFileName,
                        mimeType: selectedFileMime
                    )
                }
            }
        } message: {
            Text("Se enviara \"\(selectedFileName)\" como tu entrega para \"\(assignment.name)\". Esta accion no se puede deshacer facilmente.")
        }

        .onAppear {
            appeared = true
            Task { await ext.loadSubmissionStatus(assignmentId: assignment.id) }
        }
        // Reset upload state on dismiss
        .onDisappear {
            ext.uploadSuccess = false
            ext.uploadError = nil
            ext.uploadProgress = 0
        }
    }

    private func handleFileImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            // Access security-scoped resource
            guard url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }

            // Copy to temp directory to preserve access
            let tempDir = FileManager.default.temporaryDirectory
            let tempURL = tempDir.appendingPathComponent(url.lastPathComponent)
            try? FileManager.default.removeItem(at: tempURL)
            do {
                try FileManager.default.copyItem(at: url, to: tempURL)
                selectedFileURL  = tempURL
                selectedFileName = url.lastPathComponent
                selectedFileMime = mimeType(for: url)
                selectedFileSize = (try? FileManager.default.attributesOfItem(atPath: tempURL.path)[.size] as? Int) ?? 0
            } catch {
                print("File copy error: \(error)")
            }
        case .failure(let error):
            print("File import error: \(error)")
        }
    }

    private func mimeType(for url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "pdf":  return "application/pdf"
        case "doc":  return "application/msword"
        case "docx": return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        case "ppt":  return "application/vnd.ms-powerpoint"
        case "pptx": return "application/vnd.openxmlformats-officedocument.presentationml.presentation"
        case "xls":  return "application/vnd.ms-excel"
        case "xlsx": return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        case "jpg", "jpeg": return "image/jpeg"
        case "png":  return "image/png"
        default:     return "application/octet-stream"
        }
    }
}

// ─────────────────────────────────────────────────
// MARK: - Assignment Header Card
// ─────────────────────────────────────────────────

private struct AssignmentHeaderCard: View {
    let assignment: MoodleAssignment

    var statusColor: Color {
        if assignment.isOverdue { return Color(hex: "#CC1A1A") }
        if assignment.isDueSoon { return Color(hex: "#8B5A1A") }
        return DS.Color.wine
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            HStack(spacing: DS.Space.xs) {
                Text("TAREA")
                    .font(DS.Font.body(8, weight: .bold))
                    .foregroundStyle(Color.appInkTertiary)
                    .tracking(2)
                Text("·")
                    .foregroundStyle(Color.appInkTertiary)
                Text(assignment.courseName)
                    .font(DS.Font.body(8, weight: .semibold))
                    .foregroundStyle(DS.Color.wine)
                    .tracking(0.5)
                    .lineLimit(1)
            }

            Text(assignment.name)
                .font(DS.Font.display(20, weight: .semibold))
                .foregroundStyle(Color.appInk)
                .lineSpacing(2)

            WineAccentLine(height: 1.5, width: 24).padding(.top, 1)

            if assignment.dueDate != nil && !assignment.noSubmissions {
                HStack(spacing: DS.Space.xs) {
                    Image(systemName: "calendar")
                        .font(.system(size: 11))
                        .foregroundStyle(statusColor)
                    Text("Fecha limite: \(assignment.dueDateString)")
                        .font(DS.Font.body(12))
                        .foregroundStyle(statusColor)
                }
                .padding(.top, 2)
            }

            if !assignment.intro.isEmpty {
                Text(assignment.intro)
                    .font(DS.Font.body(12))
                    .foregroundStyle(Color.appInkTertiary)
                    .lineSpacing(3)
                    .lineLimit(6)
                    .padding(.top, 2)
            }
        }
        .padding(DS.Space.md)
        .background(Color.appBackgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.appCardBorder, lineWidth: 1))
    }
}

// ─────────────────────────────────────────────────
// MARK: - Submission Status Card
// ─────────────────────────────────────────────────

private struct SubmissionStatusCard: View {
    let status: MoodleSubmissionStatus

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {

            // Status row
            HStack(spacing: DS.Space.sm) {
                Image(systemName: status.statusIcon)
                    .font(.system(size: 18))
                    .foregroundStyle(status.statusColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(status.statusLabel)
                        .font(DS.Font.body(15, weight: .bold))
                        .foregroundStyle(status.statusColor)
                    if let mod = status.lastModified {
                        Text("Ultima modificacion: \(mod, style: .relative)")
                            .font(DS.Font.body(11))
                            .foregroundStyle(Color.appInkTertiary)
                    }
                }
                Spacer()
                if let gStatus = status.gradingStatus {
                    Text(gStatus == "graded" ? "Calificada" : "Sin calificar")
                        .font(DS.Font.body(10, weight: .semibold))
                        .foregroundStyle(gStatus == "graded" ? DS.Color.wine : Color.appInkTertiary)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background((gStatus == "graded" ? DS.Color.wine : Color.appInkTertiary).opacity(0.10))
                        .clipShape(Capsule())
                }
            }

            // Submitted files
            if !status.submittedFiles.isEmpty {
                Divider().background(Color.appSeparator)
                VStack(alignment: .leading, spacing: DS.Space.xs) {
                    Text("ARCHIVOS ENVIADOS")
                        .font(DS.Font.body(8, weight: .bold))
                        .foregroundStyle(Color.appInkTertiary)
                        .tracking(2)
                    ForEach(status.submittedFiles) { file in
                        HStack(spacing: DS.Space.sm) {
                            Image(systemName: "doc.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(status.statusColor)
                            Text(file.filename)
                                .font(DS.Font.body(12))
                                .foregroundStyle(Color.appInk)
                                .lineLimit(1)
                            Spacer()
                            let kb = Double(file.filesize) / 1024
                            Text(kb < 1024 ? String(format: "%.0f KB", kb) : String(format: "%.1f MB", kb/1024))
                                .font(DS.Font.mono(10))
                                .foregroundStyle(Color.appInkTertiary)
                        }
                    }
                }
            }

            // Online text submission
            if let text = status.onlineText, !text.isEmpty {
                Divider().background(Color.appSeparator)
                Text(text)
                    .font(DS.Font.body(12))
                    .foregroundStyle(Color.appInkTertiary)
                    .lineLimit(4)
            }

            // Feedback / grade
            if let fb = status.feedback {
                Divider().background(Color.appSeparator)
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("CALIFICACION")
                            .font(DS.Font.body(8, weight: .bold))
                            .foregroundStyle(Color.appInkTertiary)
                            .tracking(2)
                        Text(fb.gradeString)
                            .font(DS.Font.mono(18, weight: .bold))
                            .foregroundStyle(DS.Color.wine)
                    }
                    Spacer()
                    if let gradedDate = fb.gradedDate {
                        Text(gradedDate, style: .date)
                            .font(DS.Font.body(11))
                            .foregroundStyle(Color.appInkTertiary)
                    }
                }
                if let fbText = fb.feedbacktext, !fbText.isEmpty {
                    Text(fbText)
                        .font(DS.Font.body(12))
                        .foregroundStyle(Color.appInkTertiary)
                        .lineSpacing(2)
                }
            }
        }
        .padding(DS.Space.md)
        .background(status.statusColor.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(status.statusColor.opacity(0.15), lineWidth: 1))
    }
}

// ─────────────────────────────────────────────────
// MARK: - Upload Section
// ─────────────────────────────────────────────────

private struct UploadSection: View {
    @Binding var selectedFileURL: URL?
    @Binding var selectedFileName: String
    @Binding var selectedFileMime: String
    @Binding var selectedFileSize: Int
    @Binding var showFilePicker: Bool
    @Binding var showDocPicker: Bool
    @Binding var quickLookURL: URL?
    @Binding var showConfirm: Bool

    let isUploading: Bool
    let uploadProgress: Double
    let uploadSuccess: Bool
    let uploadError: String?

    private var fileSizeString: String {
        let kb = Double(selectedFileSize) / 1024
        if kb < 1 { return "<1 KB" }
        if kb < 1024 { return String(format: "%.0f KB", kb) }
        return String(format: "%.1f MB", kb / 1024)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.md) {

            // Section header
            VStack(alignment: .leading, spacing: 2) {
                Text("NUEVA ENTREGA")
                    .font(DS.Font.body(9, weight: .bold))
                    .foregroundStyle(Color.appInkTertiary)
                    .tracking(2)
                Text("Selecciona el archivo a entregar")
                    .font(DS.Font.body(13))
                    .foregroundStyle(Color.appInkSecondary)
            }

            // ── Success state ─────────────────────────
            if uploadSuccess {
                HStack(spacing: DS.Space.md) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(Color(hex: "#1A5C3A"))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Entrega enviada")
                            .font(DS.Font.body(15, weight: .bold))
                            .foregroundStyle(Color(hex: "#1A5C3A"))
                        Text("Tu archivo fue recibido por Moodle correctamente.")
                            .font(DS.Font.body(12))
                            .foregroundStyle(Color.appInkTertiary)
                    }
                }
                .padding(DS.Space.md)
                .background(Color(hex: "#1A5C3A").opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color(hex: "#1A5C3A").opacity(0.20), lineWidth: 1))
            } else if isUploading {
                // ── Upload progress ───────────────────────
                VStack(spacing: DS.Space.sm) {
                    HStack {
                        Text("Subiendo archivo...")
                            .font(DS.Font.body(13))
                            .foregroundStyle(Color.appInk)
                        Spacer()
                        Text("\(Int(uploadProgress * 100))%")
                            .font(DS.Font.mono(13, weight: .bold))
                            .foregroundStyle(DS.Color.wine)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.appBackgroundTertiary).frame(height: 6)
                            Capsule()
                                .fill(LinearGradient(colors: [DS.Color.wine, DS.Color.wineLight], startPoint: .leading, endPoint: .trailing))
                                .frame(width: geo.size.width * uploadProgress, height: 6)
                                .animation(DS.Anim.easeSlow, value: uploadProgress)
                        }
                    }
                    .frame(height: 6)
                }
                .padding(DS.Space.md)
                .background(Color.appBackgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(DS.Color.wine.opacity(0.20), lineWidth: 1))
            } else {
                // ── Rest of content ───────────────────────────
                if let err = uploadError {
                    HStack(spacing: DS.Space.sm) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(Color(hex: "#CC1A1A"))
                        Text(err)
                            .font(DS.Font.body(12))
                            .foregroundStyle(Color(hex: "#CC1A1A"))
                        Spacer()
                    }
                    .padding(DS.Space.sm)
                    .background(Color(hex: "#CC1A1A").opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                // ── File source buttons ───────────────────
                HStack(spacing: DS.Space.sm) {
                    PickerButton(icon: "doc.richtext.fill", label: "PDF / Word", color: DS.Color.wine) {
                        showDocPicker = true
                    }
                    PickerButton(icon: "folder.fill", label: "Archivos", color: Color(hex: "#1A3A6B")) {
                        showFilePicker = true
                    }
                }

                // ── Selected file preview ─────────────────
                if let url = selectedFileURL {
                    VStack(alignment: .leading, spacing: DS.Space.sm) {
                        HStack(spacing: DS.Space.sm) {
                            Image(systemName: fileIcon(for: selectedFileMime))
                                .font(.system(size: 20))
                                .foregroundStyle(DS.Color.wine)
                                .frame(width: 32)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(selectedFileName)
                                    .font(DS.Font.body(13, weight: .semibold))
                                    .foregroundStyle(Color.appInk)
                                    .lineLimit(2)
                                Text(fileSizeString)
                                    .font(DS.Font.mono(11))
                                    .foregroundStyle(Color.appInkTertiary)
                            }

                            Spacer()

                            // Preview button
                            Button {
                                quickLookURL = url
                            } label: {
                                Image(systemName: "eye.circle")
                                    .font(.system(size: 20))
                                    .foregroundStyle(DS.Color.wine.opacity(0.7))
                            }
                            .buttonStyle(.plain)

                            // Remove
                            Button {
                                selectedFileURL = nil
                                selectedFileName = ""
                                selectedFileMime = ""
                                selectedFileSize = 0
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundStyle(Color.appInkTertiary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(DS.Space.md)
                        .background(DS.Color.wineMuted)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(DS.Color.wine.opacity(0.20), lineWidth: 1))

                        // Submit button
                        Button {
                            showConfirm = true
                        } label: {
                            HStack(spacing: DS.Space.sm) {
                                Image(systemName: "paperplane.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Enviar entrega")
                                    .font(DS.Font.body(15, weight: .bold))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(DS.Color.wine)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .shadow(color: DS.Color.wine.opacity(0.30), radius: 10, y: 4)
                        }
                        .buttonStyle(.plain)
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                // ── Warning ───────────────────────────────
                HStack(spacing: DS.Space.xs) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.appInkTertiary)
                    Text("Verifica con tu docente si acepta entregas fuera de tiempo. Las entregas son definitivas.")
                        .font(DS.Font.body(11))
                        .foregroundStyle(Color.appInkTertiary)
                        .lineSpacing(2)
                }
            }
        }
        .padding(DS.Space.md)
        .background(Color.appBackgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.appCardBorder, lineWidth: 1))
        .animation(DS.Anim.spring, value: selectedFileURL != nil)
        .animation(DS.Anim.spring, value: uploadSuccess)
    }

    func fileIcon(for mime: String) -> String {
        if mime.contains("pdf") { return "doc.richtext.fill" }
        if mime.contains("word") || mime.contains("document") { return "doc.text.fill" }
        if mime.contains("image") { return "photo.fill" }
        return "doc.fill"
    }
}

struct PickerButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Space.xs) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(color)
                Text(label)
                    .font(DS.Font.body(12, weight: .semibold))
                    .foregroundStyle(color)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(color.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(color.opacity(0.20), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
