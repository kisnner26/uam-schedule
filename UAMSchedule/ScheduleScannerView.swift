import SwiftUI
import Vision
import VisionKit

// ─────────────────────────────────────────────────
// MARK: - Text Observation (text + position)
// ─────────────────────────────────────────────────

struct TextObservation {
    let text: String
    let box: CGRect // VN normalized: (0,0) = bottom-left, (1,1) = top-right
}

// ─────────────────────────────────────────────────
// MARK: - Scanner View
// ─────────────────────────────────────────────────

struct ScheduleScannerView: View {
    @EnvironmentObject var store: ScheduleStore
    @Environment(\.dismiss) private var dismiss
    @State private var showScanner = false
    @State private var parsedCourses: [Course] = []
    @State private var step: ScanStep = .intro
    @State private var selected: Set<UUID> = []
    @State private var appeared = false
    @State private var rawText = ""

    enum ScanStep { case intro, analyzing, reviewing, done }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                switch step {
                case .intro:     IntroStep(onScan: { showScanner = true })
                case .analyzing: AnalyzingStep()
                case .reviewing: ReviewStep(courses: parsedCourses, rawText: rawText, selected: $selected, onImport: importSelected)
                case .done:      DoneStep(count: selected.count, onDismiss: { dismiss() })
                }
            }
            .navigationTitle("Escanear Horario")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }.foregroundStyle(Color.appInkTertiary)
                }
                if step == .reviewing {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Volver a escanear") {
                            withAnimation(DS.Anim.springFast) { step = .intro }
                        }.foregroundStyle(DS.Color.wine)
                    }
                }
            }
            .sheet(isPresented: $showScanner) {
                DocumentScannerRepresentable { images in
                    showScanner = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        step = .analyzing
                        recognizeText(from: images)
                    }
                }
            }
        }
        .onAppear { appeared = true }
    }

    func importSelected() {
        parsedCourses.filter { selected.contains($0.id) }.forEach { store.addCourse($0) }
        step = .done
    }

    // MARK: - OCR + Table Detection

    func recognizeText(from images: [UIImage]) {
        var allObservations: [TextObservation] = []
        var allLines: [String] = []
        let group = DispatchGroup()

        for image in images {
            guard let cg = image.cgImage else { continue }
            group.enter()
            let req = VNRecognizeTextRequest { r, _ in
                let obs = r.results as? [VNRecognizedTextObservation] ?? []
                // Sort top-to-bottom (Y=1 is top in VN), then left-to-right
                let sorted = obs.sorted {
                    let diff = $1.boundingBox.midY - $0.boundingBox.midY
                    return abs(diff) > 0.01 ? diff > 0 : $0.boundingBox.midX < $1.boundingBox.midX
                }
                for o in sorted {
                    if let text = o.topCandidates(1).first?.string {
                        allObservations.append(TextObservation(text: text, box: o.boundingBox))
                        allLines.append(text)
                    }
                }
                group.leave()
            }
            req.recognitionLevel = .accurate
            req.recognitionLanguages = ["es-419", "es", "en-US"]
            req.usesLanguageCorrection = false
            try? VNImageRequestHandler(cgImage: cg, options: [:]).perform([req])
        }

        group.notify(queue: .main) {
            rawText = allLines.joined(separator: "\n")
            // Try table parser first (Hora | Lunes | Martes… format)
            var courses = TableScheduleParser.parse(observations: allObservations)
            // Fallback: line-based parser (course-code format)
            if courses.isEmpty {
                courses = SmartScheduleParser.parse(lines: allLines)
            }
            parsedCourses = courses
            selected = Set(parsedCourses.map { $0.id })
            step = .reviewing
        }
    }
}

// ─────────────────────────────────────────────────
// MARK: - Table Schedule Parser
// Handles grid-format schedules:
//   Hora        | Lunes          | Martes | …
//   7:00-8:30   | Programación I | Mat.D  | …
// Uses bounding-box X/Y positions to reconstruct rows and columns.
// ─────────────────────────────────────────────────

struct TableScheduleParser {

    // Weekday: 1=Sunday, 2=Monday … 7=Saturday (matches Calendar.weekday)
    private static let dayToWeekday: [String: Int] = [
        "lunes": 2, "martes": 3,
        "miercoles": 4, "miércoles": 4,
        "jueves": 5, "viernes": 6,
        "sabado": 7, "sábado": 7,
        "domingo": 1
    ]
    private static let skipKeywords = ["almuerzo", "comida", "descanso", "libre", "hora"]

    static func parse(observations: [TextObservation]) -> [Course] {
        guard observations.count >= 6 else { return [] }

        let norm: (String) -> String = {
            $0.lowercased()
              .trimmingCharacters(in: .whitespacesAndNewlines)
              .folding(options: .diacriticInsensitive, locale: .current)
        }

        // ── 1. Locate day-column headers by text ──────────────────────
        struct DayCol { let xMid: CGFloat; let weekday: Int }
        var dayCols: [DayCol] = []
        for obs in observations {
            if let wd = dayToWeekday[norm(obs.text)] {
                dayCols.append(DayCol(xMid: obs.box.midX, weekday: wd))
            }
        }
        guard dayCols.count >= 2 else { return [] }
        dayCols.sort { $0.xMid < $1.xMid }

        // Estimate column width from gaps between adjacent day headers
        let dayXs = dayCols.map { $0.xMid }
        var gaps: [CGFloat] = []
        for i in 1..<dayXs.count { gaps.append(dayXs[i] - dayXs[i-1]) }
        let colWidth  = gaps.isEmpty ? 0.18 : gaps.reduce(0,+) / CGFloat(gaps.count)
        let halfCol   = colWidth * 0.55
        let timColMax = dayCols.first!.xMid - halfCol * 0.4  // right edge of time column

        // ── 2. Extract time slots from first column ───────────────────
        let timeRx = try! NSRegularExpression(pattern: #"(\d{1,2})[:.](\d{2})"#)

        func timeTokens(_ s: String) -> [(Int, Int)] {
            let ns = s as NSString
            return timeRx.matches(in: s, range: NSRange(location:0,length:ns.length)).compactMap { m in
                guard m.numberOfRanges >= 3,
                      let h = Int(ns.substring(with: m.range(at:1))),
                      let mn = Int(ns.substring(with: m.range(at:2))) else { return nil }
                return (h, mn)
            }
        }

        // Cluster time-column observations by Y proximity
        let timeColObs = observations.filter { $0.box.midX < timColMax }
        let timeClusters = clusterByY(timeColObs, tol: 0.06)

        struct Slot { let yMid: CGFloat; let sh,sm,eh,em: Int }
        var slots: [Slot] = []

        for cluster in timeClusters {
            let combined = cluster.map { $0.text }.joined(separator: " ")
            let yMid = cluster.map { $0.box.midY }.reduce(0,+) / CGFloat(cluster.count)
            let toks = timeTokens(combined)
            guard toks.count >= 2 else { continue }
            let (sh, sm) = toks[0]
            var (eh, em) = toks[1]
            if eh < sh || (eh == sh && em <= sm) { eh += 12 }
            slots.append(Slot(yMid: yMid, sh: sh, sm: sm, eh: eh, em: em))
        }
        guard !slots.isEmpty else { return [] }
        slots.sort { $0.yMid > $1.yMid } // top-to-bottom

        // Tolerance for assigning content to nearest slot
        var slotGaps: [CGFloat] = []
        for i in 1..<slots.count { slotGaps.append(slots[i-1].yMid - slots[i].yMid) }
        let avgGap = slotGaps.isEmpty ? 0.14 : slotGaps.reduce(0,+)/CGFloat(slotGaps.count)
        let slotTol = avgGap * 0.62

        // ── 3. Assign content observations to (slot, day) cells ───────
        let contentObs = observations.filter { obs in
            guard obs.box.midX >= timColMax else { return false }
            let n = norm(obs.text)
            guard dayToWeekday[n] == nil else { return false }
            guard !skipKeywords.contains(where: { n.contains($0) }) else { return false }
            guard !n.isEmpty, obs.text.count > 1 else { return false }
            guard let closest = dayCols.min(by: { abs($0.xMid-obs.box.midX) < abs($1.xMid-obs.box.midX) }) else { return false }
            return abs(closest.xMid - obs.box.midX) < halfCol
        }

        struct CellKey: Hashable { let slotIdx: Int; let weekday: Int }
        var cellTexts: [CellKey: [String]] = [:]

        for obs in contentObs {
            guard let (sIdx, slot) = slots.enumerated()
                .min(by: { abs($0.element.yMid-obs.box.midY) < abs($1.element.yMid-obs.box.midY) }) else { continue }
            guard abs(slot.yMid - obs.box.midY) < slotTol else { continue }
            guard let day = dayCols.min(by: { abs($0.xMid-obs.box.midX) < abs($1.xMid-obs.box.midX) }) else { continue }

            let key = CellKey(slotIdx: sIdx, weekday: day.weekday)
            cellTexts[key, default: []].append(obs.text)
        }

        // ── 4. Build Course objects ────────────────────────────────────
        var courseMap: [String: Course] = [:]
        let colors = DS.Color.courseColors

        for (key, texts) in cellTexts {
            let name = texts.joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: .whitespaces).filter { !$0.isEmpty }.joined(separator: " ")
            guard !name.isEmpty, name.count > 2 else { continue }

            let slot = slots[key.slotIdx]
            let session = ClassSession(weekday: key.weekday,
                startHour: slot.sh, startMinute: slot.sm,
                endHour: slot.eh, endMinute: slot.em)

            if courseMap[name] != nil {
                let dup = courseMap[name]!.sessions.contains {
                    $0.weekday == session.weekday && $0.startHour == session.startHour
                }
                if !dup { courseMap[name]!.sessions.append(session) }
            } else {
                courseMap[name] = Course(name: name, room: "", credits: 3,
                    color: colors[abs(name.hashValue) % colors.count],
                    sessions: [session])
            }
        }

        return Array(courseMap.values).sorted { $0.name < $1.name }
    }

    // Groups observations with similar Y midpoints (Y=1 top in VN coords)
    private static func clusterByY(_ obs: [TextObservation], tol: CGFloat) -> [[TextObservation]] {
        var clusters: [[TextObservation]] = []
        for o in obs.sorted(by: { $0.box.midY > $1.box.midY }) {
            if let i = clusters.indices.first(where: {
                let mean = clusters[$0].map { $0.box.midY }.reduce(0,+) / CGFloat(clusters[$0].count)
                return abs(mean - o.box.midY) < tol
            }) {
                clusters[i].append(o)
            } else {
                clusters.append([o])
            }
        }
        return clusters
    }
}

// ─────────────────────────────────────────────────
// MARK: - Smart Parser (line-based, code-style schedules)
// ─────────────────────────────────────────────────

struct SmartScheduleParser {
    static func parse(lines: [String]) -> [Course] {
        var courses: [Course] = []

        let codeRx   = try! NSRegularExpression(pattern: #"[A-Z]{2,4}\d{3,5}"#)
        let timeRx   = try! NSRegularExpression(pattern: #"\d{1,2}[:\.]\d{2}\s*(?:AM|PM|am|pm)?"#)
        let roomRx   = try! NSRegularExpression(pattern: #"[A-Z]-?\d{2,4}"#)
        let dayRx    = try! NSRegularExpression(pattern: #"(?i)(lun|mar|mi[eé]|jue|vie|sáb|sab|dom|lunes|martes|mi[eé]rcoles|jueves|viernes|s[aá]bado|domingo)"#)
        let creditRx = try! NSRegularExpression(pattern: #"(\d)\s*cr"#, options: .caseInsensitive)

        let dayMap: [String: Int] = [
            "lun":2,"lunes":2,"mar":3,"martes":3,"mié":4,"mie":4,"miércoles":4,"miercoles":4,
            "jue":5,"jueves":5,"vie":6,"viernes":6,"sáb":7,"sab":7,"sábado":7,"sabado":7,
            "dom":1,"domingo":1
        ]

        var i = 0
        while i < lines.count {
            let line = lines[i]
            guard let code = firstMatch(codeRx, in: line) else { i += 1; continue }
            guard !courses.contains(where: { $0.code == code }) else { i += 1; continue }

            var name = ""
            let afterCode = line.replacingOccurrences(of: code, with: "").trimmingCharacters(in: .whitespaces)
            if afterCode.count > 5 && !looksLikeMetadata(afterCode) {
                name = afterCode
            } else {
                for di in 1...min(3, lines.count-i-1) {
                    let c = lines[i+di]
                    if !looksLikeMetadata(c) && c.count > 4 && firstMatch(codeRx, in: c) == nil { name = c; break }
                }
            }
            if name.isEmpty { name = code }
            name = cleanName(name)

            var room = ""
            let window = max(0,i-2)...min(lines.count-1,i+5)
            for j in window {
                if let r = firstMatch(roomRx, in: lines[j]), r.count >= 3 && r.count <= 6 { room = r; break }
            }

            var credits = 3
            for j in window {
                if let cm = firstMatch(creditRx, in: lines[j]), let n = Int(cm.filter { $0.isNumber }) { credits = n; break }
            }

            var allTimes: [String] = []
            for j in window { allTimes += allMatches(timeRx, in: lines[j]) }

            var weekdays: [Int] = []
            for j in window {
                let lower = lines[j].lowercased()
                for dm in allMatches(dayRx, in: lower) {
                    let key = dm.lowercased().folding(options: .diacriticInsensitive, locale: .current)
                    if let wd = dayMap[key] ?? dayMap[String(key.prefix(3))], !weekdays.contains(wd) { weekdays.append(wd) }
                }
            }
            if weekdays.isEmpty { weekdays = [2] }

            var sessions: [ClassSession] = []
            let startT = allTimes.first.map { parseTime($0) } ?? (8, 0)
            let endT   = allTimes.count >= 2 ? parseTime(allTimes[1]) : (startT.0+2, startT.1)
            for wd in weekdays.sorted() {
                sessions.append(ClassSession(weekday: wd,
                    startHour: startT.0, startMinute: startT.1, endHour: endT.0, endMinute: endT.1))
            }

            let colors = DS.Color.courseColors
            courses.append(Course(code: code, name: name, room: room, credits: credits,
                color: colors[abs(code.hashValue) % colors.count], sessions: sessions))
            i += 1
        }

        if courses.isEmpty {
            courses = parseByTimePattern(lines: lines, timeRx: timeRx, roomRx: roomRx)
        }
        return courses
    }

    static func parseByTimePattern(lines: [String], timeRx: NSRegularExpression, roomRx: NSRegularExpression) -> [Course] {
        var courses: [Course] = []
        let colors = DS.Color.courseColors
        for (i, line) in lines.enumerated() {
            let times = allMatches(timeRx, in: line)
            guard times.count >= 2 else { continue }
            var name = ""
            if i > 0 && lines[i-1].count > 4 && !looksLikeMetadata(lines[i-1]) {
                name = cleanName(lines[i-1])
            } else {
                var stripped = line
                for t in times { stripped = stripped.replacingOccurrences(of: t, with: "") }
                stripped = stripped.trimmingCharacters(in: .whitespaces)
                if stripped.count > 4 { name = cleanName(stripped) }
            }
            guard !name.isEmpty, !courses.contains(where: { $0.name == name }) else { continue }
            let room = firstMatch(roomRx, in: line) ?? ""
            let s = parseTime(times[0]); let e = parseTime(times[1])
            courses.append(Course(name: name, room: room, credits: 3,
                color: colors[abs(name.hashValue) % colors.count],
                sessions: [ClassSession(weekday: 2, startHour: s.0, startMinute: s.1, endHour: e.0, endMinute: e.1)]))
        }
        return courses
    }

    static func firstMatch(_ rx: NSRegularExpression, in str: String) -> String? {
        let ns = str as NSString
        guard let m = rx.firstMatch(in: str, range: NSRange(location:0,length:ns.length)) else { return nil }
        return ns.substring(with: m.range)
    }
    static func allMatches(_ rx: NSRegularExpression, in str: String) -> [String] {
        let ns = str as NSString
        return rx.matches(in: str, range: NSRange(location:0,length:ns.length)).map { ns.substring(with: $0.range) }
    }
    static func looksLikeMetadata(_ s: String) -> Bool {
        let lower = s.lowercased()
        let meta = ["crédito","credito","grupo","sección","seccion","semestre","horario",
                    "lunes","martes","miércoles","miercoles","jueves","viernes","sábado",
                    "am","pm","total","sede","campus","carrera","aula","salón","salon"]
        return s.filter { $0.isLetter }.isEmpty || meta.contains(where: { lower.contains($0) }) || s.count < 3
    }
    static func cleanName(_ s: String) -> String {
        var r = s
        if let rx = try? NSRegularExpression(pattern: #"^[A-Z]{2,4}\d{3,5}\s*"#) {
            let ns = r as NSString
            if let m = rx.firstMatch(in: r, range: NSRange(location:0,length:ns.length)) {
                r = ns.substring(from: m.range.location + m.range.length)
            }
        }
        r = r.replacingOccurrences(of: #"\d+\s*cr\.?"#, with: "", options: .regularExpression)
        r = r.replacingOccurrences(of: #"G\d+"#, with: "", options: .regularExpression)
        return r.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespaces).filter { !$0.isEmpty }.joined(separator: " ")
    }
    static func parseTime(_ s: String) -> (Int, Int) {
        let up = s.uppercased().trimmingCharacters(in: .whitespaces)
        let isPM = up.contains("PM"); let isAM = up.contains("AM")
        let clean = up.replacingOccurrences(of: "AM", with: "").replacingOccurrences(of: "PM", with: "")
                      .replacingOccurrences(of: ".", with: ":")
                      .trimmingCharacters(in: .whitespaces)
        let parts = clean.split(separator: ":")
        guard parts.count == 2, var h = Int(parts[0]), let m = Int(parts[1]) else { return (8,0) }
        if isPM && h < 12 { h += 12 }
        if isAM && h == 12 { h = 0 }
        if !isPM && !isAM && h > 0 && h < 7 { h += 12 }
        return (h, m)
    }
}

// ─────────────────────────────────────────────────
// MARK: - Step Views
// ─────────────────────────────────────────────────

struct IntroStep: View {
    let onScan: () -> Void
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: DS.Space.lg) {
                ZStack {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(DS.Color.wineMuted).frame(width: 96, height: 96)
                    Image(systemName: "doc.text.viewfinder")
                        .font(.system(size: 42, weight: .light)).foregroundStyle(DS.Color.wine)
                }
                .scaleEffect(appeared ? 1 : 0.85)
                .animation(DS.Anim.spring.delay(0.1), value: appeared)

                VStack(spacing: 8) {
                    Text("Escanear Horario")
                        .font(DS.Font.display(24, weight: .semibold)).foregroundStyle(Color.appInk)
                    Text("Toma una foto de tu horario en tabla o en lista. La app detecta materias, horarios y aulas automáticamente.")
                        .font(DS.Font.body(14)).foregroundStyle(Color.appInkTertiary)
                        .multilineTextAlignment(.center).lineSpacing(3)
                        .padding(.horizontal, DS.Space.xl)
                }
                .opacity(appeared ? 1 : 0).offset(y: appeared ? 0 : 8)
                .animation(DS.Anim.easeSlow.delay(0.15), value: appeared)

                VStack(spacing: 8) {
                    TipRow(icon: "tablecells",                  text: "Detecta horarios en tabla (Hora | Lunes | Martes…)")
                    TipRow(icon: "sun.max",                     text: "Buena iluminación mejora el resultado")
                    TipRow(icon: "doc.text",                    text: "También detecta códigos tipo SIS0401")
                    TipRow(icon: "arrow.triangle.2.circlepath", text: "Puedes corregir los datos después de importar")
                }
                .opacity(appeared ? 1 : 0)
                .animation(DS.Anim.easeSlow.delay(0.2), value: appeared)
            }
            Spacer()

            VStack(spacing: 10) {
                if VNDocumentCameraViewController.isSupported {
                    Button(action: onScan) {
                        Label("Abrir cámara", systemImage: "camera.fill")
                            .font(DS.Font.body(16, weight: .bold)).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 15)
                            .background(DS.Color.wine)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
                            .shadow(color: DS.Color.wine.opacity(0.3), radius: 10, y: 4)
                    }.buttonStyle(.plain)
                } else {
                    Text("VisionKit no disponible en este dispositivo.")
                        .font(DS.Font.body(13)).foregroundStyle(Color.appInkTertiary).multilineTextAlignment(.center)
                }
                Text("Toca la cámara, escanea 1 o varias páginas, luego toca \"Guardar\".")
                    .font(DS.Font.body(11)).foregroundStyle(Color.appInkTertiary).multilineTextAlignment(.center)
            }
            .padding(.horizontal, DS.Space.md).padding(.bottom, 48)
            .opacity(appeared ? 1 : 0).animation(DS.Anim.spring.delay(0.25), value: appeared)
        }
        .onAppear { appeared = true }
    }
}

struct TipRow: View {
    let icon: String; let text: String
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 13, weight: .medium))
                .foregroundStyle(DS.Color.wine.opacity(0.6)).frame(width: 20)
            Text(text).font(DS.Font.body(13)).foregroundStyle(Color.appInkSecondary)
            Spacer()
        }.padding(.horizontal, DS.Space.lg)
    }
}

struct AnalyzingStep: View {
    @State private var pulse = false
    var body: some View {
        VStack(spacing: DS.Space.lg) {
            Spacer()
            ZStack {
                Circle().stroke(DS.Color.wineMuted, lineWidth: 2).frame(width: 80, height: 80)
                    .scaleEffect(pulse ? 1.3 : 1.0).opacity(pulse ? 0 : 0.5)
                    .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: false), value: pulse)
                Image(systemName: "tablecells")
                    .font(.system(size: 32, weight: .light)).foregroundStyle(DS.Color.wine)
            }
            VStack(spacing: 6) {
                Text("Analizando tabla…").font(DS.Font.display(20, weight: .semibold)).foregroundStyle(Color.appInk)
                Text("Detectando columnas, horarios y materias")
                    .font(DS.Font.body(13)).foregroundStyle(Color.appInkTertiary)
            }
            Spacer()
        }
        .onAppear { pulse = true }
    }
}

struct ReviewStep: View {
    let courses: [Course]
    let rawText: String
    @Binding var selected: Set<UUID>
    let onImport: () -> Void
    @State private var showRaw = false

    var body: some View {
        VStack(spacing: 0) {
            if courses.isEmpty {
                VStack(spacing: 14) {
                    Spacer()
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 32)).foregroundStyle(Color.appInkTertiary.opacity(0.3))
                    Text("No se detectaron materias")
                        .font(DS.Font.body(15, weight: .semibold)).foregroundStyle(Color.appInkTertiary.opacity(0.6))
                    Text("Asegúrate de que el encabezado de días (Lunes, Martes…) sea visible y usa buena iluminación.")
                        .font(DS.Font.body(12)).foregroundStyle(Color.appInkTertiary.opacity(0.4))
                        .multilineTextAlignment(.center).padding(.horizontal, DS.Space.xl)

                    if !rawText.isEmpty {
                        Button { showRaw.toggle() } label: {
                            Text(showRaw ? "Ocultar texto detectado" : "Ver texto detectado")
                                .font(DS.Font.body(12, weight: .semibold)).foregroundStyle(DS.Color.wine)
                        }.buttonStyle(.plain)
                        if showRaw {
                            ScrollView {
                                Text(rawText)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(Color.appInkSecondary)
                                    .frame(maxWidth: .infinity, alignment: .leading).padding(12)
                            }
                            .frame(maxHeight: 200)
                            .background(Color.appBackgroundSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
                            .padding(.horizontal, DS.Space.md)
                        }
                    }
                    Spacer()
                }
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: DS.Space.md) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(courses.count) materias detectadas")
                                    .font(DS.Font.body(14, weight: .semibold)).foregroundStyle(Color.appInk)
                                Text("Verifica y edita después de importar")
                                    .font(DS.Font.body(11)).foregroundStyle(Color.appInkTertiary)
                            }
                            Spacer()
                            Button("Todo") {
                                withAnimation(DS.Anim.springFast) { selected = Set(courses.map { $0.id }) }
                            }
                            .font(DS.Font.body(12, weight: .semibold)).foregroundStyle(DS.Color.wine)
                        }
                        ForEach(courses) { course in
                            let isSel = selected.contains(course.id)
                            ScannedCourseRow(course: course, isSelected: isSel) {
                                withAnimation(DS.Anim.springFast) {
                                    if isSel { selected.remove(course.id) } else { selected.insert(course.id) }
                                }
                            }
                        }
                        if !rawText.isEmpty {
                            Button { showRaw.toggle() } label: {
                                Label(showRaw ? "Ocultar texto OCR" : "Ver texto OCR detectado",
                                      systemImage: showRaw ? "eye.slash" : "eye")
                                    .font(DS.Font.body(12)).foregroundStyle(Color.appInkTertiary)
                            }.buttonStyle(.plain)
                            if showRaw {
                                ScrollView {
                                    Text(rawText)
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundStyle(Color.appInkSecondary)
                                        .frame(maxWidth: .infinity, alignment: .leading).padding(12)
                                }
                                .frame(maxHeight: 200)
                                .background(Color.appBackgroundSecondary)
                                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
                            }
                        }
                    }
                    .padding(DS.Space.md).padding(.bottom, 120)
                }
                if !selected.isEmpty {
                    VStack {
                        Spacer()
                        Button(action: onImport) {
                            Text("Importar \(selected.count) materia\(selected.count > 1 ? "s" : "")")
                                .font(DS.Font.body(15, weight: .bold)).foregroundStyle(.white)
                                .frame(maxWidth: .infinity).padding(.vertical, 15)
                                .background(DS.Color.wine)
                                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
                                .shadow(color: DS.Color.wine.opacity(0.3), radius: 8, y: 4)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, DS.Space.md).padding(.bottom, 32)
                    }
                    .ignoresSafeArea(edges: .bottom)
                }
            }
        }
    }
}

struct ScannedCourseRow: View {
    let course: Course; let isSelected: Bool; let onToggle: () -> Void
    let dayShort = ["","Dom","Lun","Mar","Mié","Jue","Vie","Sáb"]

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 22))
                .foregroundStyle(isSelected ? DS.Color.wine : Color.appInkTertiary.opacity(0.3))
                .animation(DS.Anim.springFast, value: isSelected)
            Rectangle().fill(Color(hex: course.color)).frame(width: 3, height: 52).clipShape(Capsule())
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if !course.code.isEmpty {
                        Text(course.code).font(DS.Font.body(9, weight: .bold))
                            .foregroundStyle(Color(hex: course.color).opacity(0.7)).tracking(1)
                    }
                    Text(course.name).font(DS.Font.body(13, weight: .semibold))
                        .foregroundStyle(Color.appInk).lineLimit(1)
                }
                HStack(spacing: 10) {
                    if !course.room.isEmpty {
                        Label(course.room, systemImage: "mappin").font(DS.Font.body(10))
                            .foregroundStyle(Color.appInkTertiary).tint(DS.Color.wine.opacity(0.4))
                    }
                    if let s = course.sessions.first {
                        let days = course.sessions.compactMap { sess -> String? in
                            guard sess.weekday < dayShort.count else { return nil }
                            return dayShort[sess.weekday]
                        }.joined(separator: "/")
                        Text("\(days) \(s.startTimeString)–\(s.endTimeString)")
                            .font(DS.Font.mono(10)).foregroundStyle(Color.appInkTertiary)
                    }
                    Text("\(course.credits) cr.").font(DS.Font.mono(10)).foregroundStyle(Color.appInkTertiary)
                }
            }
            Spacer()
        }
        .padding(12)
        .background(isSelected ? DS.Color.wine.opacity(0.03) : Color.appBackgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.md)
            .stroke(isSelected ? DS.Color.wine.opacity(0.2) : Color.appCardBorder, lineWidth: isSelected ? 1.5 : 1))
        .onTapGesture { onToggle() }
    }
}

struct DoneStep: View {
    let count: Int; let onDismiss: () -> Void
    @State private var appeared = false
    var body: some View {
        VStack(spacing: DS.Space.lg) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64)).foregroundStyle(Color(hex: "1A5C3A"))
                .scaleEffect(appeared ? 1 : 0.5).animation(DS.Anim.spring.delay(0.1), value: appeared)
            VStack(spacing: 6) {
                Text("¡Importado!").font(DS.Font.display(26, weight: .semibold)).foregroundStyle(Color.appInk)
                Text("\(count) materia\(count != 1 ? "s" : "") agregada\(count != 1 ? "s" : "").")
                    .font(DS.Font.body(14)).foregroundStyle(Color.appInkTertiary)
                Text("Puedes editar los detalles desde la tab Materias.")
                    .font(DS.Font.body(12)).foregroundStyle(Color.appInkTertiary)
            }
            .opacity(appeared ? 1 : 0).animation(DS.Anim.easeSlow.delay(0.2), value: appeared)
            Spacer()
            Button(action: onDismiss) {
                Text("Listo").font(DS.Font.body(16, weight: .bold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 15)
                    .background(DS.Color.wine).clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, DS.Space.md).padding(.bottom, 48)
            .opacity(appeared ? 1 : 0).animation(DS.Anim.spring.delay(0.3), value: appeared)
        }
        .onAppear { appeared = true }
    }
}

// ─────────────────────────────────────────────────
// MARK: - VisionKit Wrapper
// ─────────────────────────────────────────────────

struct DocumentScannerRepresentable: UIViewControllerRepresentable {
    let onScan: ([UIImage]) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(onScan: onScan) }
    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let vc = VNDocumentCameraViewController(); vc.delegate = context.coordinator; return vc
    }
    func updateUIViewController(_ vc: VNDocumentCameraViewController, context: Context) {}

    @MainActor
    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onScan: ([UIImage]) -> Void
        init(onScan: @escaping ([UIImage]) -> Void) { self.onScan = onScan }

        nonisolated func documentCameraViewController(_ c: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            let images = (0..<scan.pageCount).map { scan.imageOfPage(at: $0) }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                c.dismiss(animated: true) { self.onScan(images) }
            }
        }
        nonisolated func documentCameraViewControllerDidCancel(_ c: VNDocumentCameraViewController) {
            DispatchQueue.main.async { c.dismiss(animated: true) }
        }
        nonisolated func documentCameraViewController(_ c: VNDocumentCameraViewController, didFailWithError e: Error) {
            DispatchQueue.main.async { c.dismiss(animated: true) }
        }
    }
}
