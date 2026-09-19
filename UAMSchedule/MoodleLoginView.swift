import SwiftUI

struct MoodleLoginView: View {
    @EnvironmentObject var store: ScheduleStore
    @StateObject private var moodle = MoodleStore.shared
    @Environment(\.dismiss) private var dismiss

    @State private var cif = ""
    @State private var pin = ""
    @State private var isLoading = false
    @State private var errorMsg: String? = nil
    @State private var showSuccess = false
    @State private var appeared = false
    @State private var showImportConfirm = false
    @State private var importResult: MoodleImportResult? = nil

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {

                    // Header
                    VStack(spacing: DS.Space.sm) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(DS.Color.wineMuted)
                                .frame(width: 80, height: 80)
                            Image(systemName: "graduationcap.fill")
                                .font(.system(size: 34, weight: .light))
                                .foregroundStyle(DS.Color.wine)
                        }
                        .scaleEffect(appeared ? 1 : 0.8)
                        .animation(DS.Anim.spring.delay(0.1), value: appeared)

                        VStack(spacing: 6) {
                            Text("Campus Virtual UAM")
                                .font(DS.Font.display(24, weight: .semibold))
                                .foregroundStyle(Color.appInk)
                            Text("Usa tus credenciales del campus virtual para importar tareas y calificaciones automáticamente.")
                                .font(DS.Font.body(13))
                                .foregroundStyle(Color.appInkTertiary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, DS.Space.lg)
                        }
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 6)
                        .animation(DS.Anim.easeSlow.delay(0.15), value: appeared)
                    }
                    .padding(.top, 40)
                    .padding(.bottom, DS.Space.xl)

                    // Fields
                    VStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("CIF / Usuario").font(DS.Font.body(11, weight: .semibold))
                                .foregroundStyle(Color.appInkTertiary).tracking(0.5)
                            TextField("tu_cif", text: $cif)
                                .font(DS.Font.body(15))
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .padding(14)
                                .background(Color.appBackgroundSecondary)
                                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                                .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).stroke(Color.appCardBorder, lineWidth: 1))
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Contraseña").font(DS.Font.body(11, weight: .semibold))
                                .foregroundStyle(Color.appInkTertiary).tracking(0.5)
                            SecureField("••••••••", text: $pin)
                                .font(DS.Font.body(15))
                                .padding(14)
                                .background(Color.appBackgroundSecondary)
                                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                                .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).stroke(Color.appCardBorder, lineWidth: 1))
                        }

                        if let err = errorMsg {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundStyle(Color(hex: "#CC1A1A"))
                                Text(err).font(DS.Font.body(12)).foregroundStyle(Color(hex: "#CC1A1A"))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .background(Color(hex: "#CC1A1A").opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    .padding(.horizontal, DS.Space.md)
                    .opacity(appeared ? 1 : 0)
                    .animation(DS.Anim.easeSlow.delay(0.2), value: appeared)

                    // Connect button
                    Button {
                        Task { await connect() }
                    } label: {
                        HStack(spacing: 8) {
                            if isLoading { ProgressView().progressViewStyle(.circular).tint(.white) }
                            Text(isLoading ? "Conectando..." : "Conectar")
                                .font(DS.Font.body(16, weight: .bold)).foregroundStyle(.white)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 15)
                        .background(cif.isEmpty || pin.isEmpty ? DS.Color.wine.opacity(0.4) : DS.Color.wine)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
                        .shadow(color: DS.Color.wine.opacity(0.3), radius: 10, y: 4)
                    }
                    .buttonStyle(.plain)
                    .disabled(cif.isEmpty || pin.isEmpty || isLoading)
                    .padding(.horizontal, DS.Space.md)
                    .padding(.top, DS.Space.xl)
                    .padding(.bottom, 48)
                    .opacity(appeared ? 1 : 0)
                    .animation(DS.Anim.spring.delay(0.25), value: appeared)
                }
            }

            // Success overlay
            if showSuccess {
                ZStack {
                    Color.appBackground.ignoresSafeArea()
                    VStack(spacing: DS.Space.lg) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(Color(hex: "#1A5C3A"))
                            .scaleEffect(showSuccess ? 1 : 0.3)
                            .animation(.spring(response: 0.5, dampingFraction: 0.6), value: showSuccess)

                        VStack(spacing: 8) {
                            Text("¡Moodle conectado!")
                                .font(DS.Font.display(26, weight: .semibold))
                                .foregroundStyle(Color.appInk)
                            Text("Sincronizando tareas y materias...")
                                .font(DS.Font.body(14))
                                .foregroundStyle(Color.appInkTertiary)
                        }
                        .opacity(showSuccess ? 1 : 0)
                        .animation(.easeIn(duration: 0.25), value: showSuccess)
                    }
                }
                .transition(.opacity)
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancelar") { dismiss() }
                    .foregroundStyle(Color.appInkTertiary)
                    .opacity(showSuccess ? 0 : 1)
            }
        }
        // Import confirmation dialog — shown after login when store has existing courses
        .confirmationDialog(
            "Importar materias de Moodle",
            isPresented: $showImportConfirm,
            titleVisibility: .visible
        ) {
            Button("Importar y mantener las mías") {
                moodle.confirmImport(overwrite: false)
                dismiss()
            }
            Button("Importar y reemplazar las mías", role: .destructive) {
                moodle.confirmImport(overwrite: true)
                dismiss()
            }
            Button("No importar ahora", role: .cancel) {
                moodle.declineImport()
                dismiss()
            }
        } message: {
            Text("Se encontraron \(moodle.moodleCourses.count) materias en tu cuenta Moodle. ¿Quieres importarlas a UAMSchedule?")
        }
        .onAppear { appeared = true }
        .onReceive(moodle.$pendingImportConfirmation) { pending in
            if pending { showImportConfirm = true }
        }
    }

    // MARK: - Connect

    private func connect() async {
        isLoading = true
        errorMsg = nil
        if moodle.scheduleStore == nil { moodle.scheduleStore = store }
        do {
            try await moodle.login(cif: cif.trimmingCharacters(in: .whitespaces), pin: pin)
            withAnimation(DS.Anim.spring) { showSuccess = true }
            // If no pending confirmation (empty store), just dismiss after delay
            if !moodle.pendingImportConfirmation {
                try? await Task.sleep(nanoseconds: 1_400_000_000)
                dismiss()
            }
        } catch {
            errorMsg = error.localizedDescription
        }
        isLoading = false
    }
}
