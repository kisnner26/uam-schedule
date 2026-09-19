import Foundation
import CoreLocation

// MARK: - UAM Campus
// Catalogo de edificios y puntos de interes del campus UAM Managua.
// Coordenadas basadas en el mapa oficial del campus UAM (mapa fisico interno).
// Centroide del campus: aprox. 12.1085, -86.2572
// Orientacion del mapa: Norte arriba, entrada principal al sur.
//
// Edificios academicos: A, B, C, G, F, H, K (pabellones centrales)
// Edificio Copernico (P) — norte del campus
// Clinica Dental (J/D area) — zona central-norte
// Comedor / Lunch Area — zona central
// Rancho / Ranch — zona central
// Kioscos — zona central
// Plaza Central Ruben Dario — sur del campus
// Jaguar Center — sureste
// Cancha de futbol — este
// Estacion Meteorologica — noroeste
// Banpro / Bank — suroeste
// Acopio / Gathering — noroeste
// Parqueos multiples distribuidos
// RRPP / Relaciones Publicas — sur
// Rotulo UAM / UAM Sign Wall — sur
// Area de Contenedores — sureste
// Senderos / Paths — este

public struct UAMBuilding: Identifiable, Hashable, Sendable {
    public let id: String
    public let code: String
    public let name: String
    public let latitude: Double
    public let longitude: Double
    public let category: Category

    public var coord: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    public enum Category: String, Hashable, CaseIterable, Sendable {
        case academic   = "Academico"
        case service    = "Servicios"
        case sports     = "Deportes"
        case parking    = "Parqueo"
        case entrance   = "Entrada"
        case food       = "Alimentacion"
        case bank       = "Banco"
        case health     = "Salud"
        case recreation = "Recreacion"

        public var icon: String {
            switch self {
            case .academic:   return "building.columns"
            case .service:    return "person.2.badge.gearshape"
            case .sports:     return "sportscourt"
            case .parking:    return "car.fill"
            case .entrance:   return "arrow.right.to.line"
            case .food:       return "fork.knife"
            case .bank:       return "banknote"
            case .health:     return "cross.fill"
            case .recreation: return "figure.walk"
            }
        }

        public static var orderedCases: [Category] {
            [.entrance, .academic, .health, .food, .service, .bank, .sports, .recreation, .parking]
        }
    }

    public init(id: String, code: String, name: String, lat: Double, lon: Double, category: Category) {
        self.id = id; self.code = code; self.name = name
        self.latitude = lat; self.longitude = lon; self.category = category
    }

    public static func == (lhs: UAMBuilding, rhs: UAMBuilding) -> Bool { lhs.id == rhs.id }
    public func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

public enum UAMCampus {

    public static let centerLatitude: Double  = 12.108511
    public static let centerLongitude: Double = -86.25712

    public static var center: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: centerLatitude, longitude: centerLongitude)
    }

    public static let defaultRadiusMeters: Double = 300

    // MARK: - Catalogo oficial de edificios y POIs
    // Posiciones relativas tomadas del mapa fisico oficial UAM.
    // El campus se distribuye de norte a sur:
    //   Norte:  Edificio Copernico (P), Estacion Meteorologica, Parqueos norte
    //   Centro: Clinica Dental (J/D), Kioscos, Comedor, Rancho, Edificios A-K, Cancha
    //   Sur:    Plaza Central, Jaguar Center, Banpro, Rotulo UAM, RRPP

    public static let buildings: [UAMBuilding] = [

        // ── Entradas ──────────────────────────────────────────────────────────
        UAMBuilding(id: "ENTRADA_PRINCIPAL", code: "Entrada Principal",
            name: "Acceso principal — Rotulo UAM / UAM Sign Wall",
            lat: 12.107200, lon: -86.257120, category: .entrance),

        UAMBuilding(id: "ENTRADA_NORTE", code: "Entrada Norte",
            name: "Acceso norte — Edificio Copernico / Parqueo norte",
            lat: 12.109300, lon: -86.257000, category: .entrance),

        // ── Edificios Academicos Centrales ────────────────────────────────────
        // Pabellones A-C al centro-norte, K al centro, G-H al centro-este, F al sur-centro
        UAMBuilding(id: "A", code: "Edificio A",
            name: "Pabellon A — Aulas teoricas",
            lat: 12.108500, lon: -86.257550, category: .academic),

        UAMBuilding(id: "B", code: "Edificio B",
            name: "Pabellon B — Aulas teoricas",
            lat: 12.108460, lon: -86.257380, category: .academic),

        UAMBuilding(id: "C", code: "Edificio C",
            name: "Pabellon C — Aulas teoricas",
            lat: 12.108560, lon: -86.257250, category: .academic),

        UAMBuilding(id: "G", code: "Edificio G",
            name: "Pabellon G — Aulas y laboratorios",
            lat: 12.108350, lon: -86.257050, category: .academic),

        UAMBuilding(id: "H", code: "Edificio H",
            name: "Pabellon H — Aulas y cubiculos docentes",
            lat: 12.108650, lon: -86.257100, category: .academic),

        UAMBuilding(id: "K", code: "Edificio K",
            name: "Pabellon K — Aulas teoricas",
            lat: 12.108280, lon: -86.257400, category: .academic),

        UAMBuilding(id: "F", code: "Edificio F",
            name: "Pabellon F — Aulas y laboratorios",
            lat: 12.108100, lon: -86.257050, category: .academic),

        UAMBuilding(id: "M", code: "Edificio M",
            name: "Pabellon M — Aulas este",
            lat: 12.108500, lon: -86.256900, category: .academic),

        UAMBuilding(id: "L", code: "Edificio L",
            name: "Pabellon L — Jaguar Center area",
            lat: 12.107900, lon: -86.256750, category: .academic),

        UAMBuilding(id: "I", code: "Edificio I",
            name: "Pabellon I — Aulas sur-este",
            lat: 12.107850, lon: -86.257000, category: .academic),

        UAMBuilding(id: "N", code: "Edificio N / Clinica",
            name: "Edificio N — Zona Clinica Dental",
            lat: 12.108800, lon: -86.257200, category: .academic),

        // ── Edificio Copernico ────────────────────────────────────────────────
        UAMBuilding(id: "P", code: "Ed. Copernico",
            name: "Edificio Copernico / Copernicus Building — norte del campus",
            lat: 12.109100, lon: -86.257050, category: .academic),

        // ── Servicios de Salud ─────────────────────────────────────────────────
        UAMBuilding(id: "CLINICA", code: "Clinica Dental",
            name: "Clinica Odontologica UAM / Dental Clinic — zona J/D",
            lat: 12.108820, lon: -86.257300, category: .health),

        // ── Alimentacion ───────────────────────────────────────────────────────
        UAMBuilding(id: "COMEDOR", code: "Comedor",
            name: "Comedor / Lunch Area — zona central",
            lat: 12.108600, lon: -86.256980, category: .food),

        UAMBuilding(id: "RANCHO", code: "Rancho",
            name: "Rancho / Ranch — area de descanso y alimentacion",
            lat: 12.108700, lon: -86.256850, category: .food),

        UAMBuilding(id: "KIOSCOS", code: "Kioscos",
            name: "Kioscos / Kiosk — zona central junto a Clinica",
            lat: 12.108750, lon: -86.257450, category: .food),

        // ── Servicios Generales ────────────────────────────────────────────────
        UAMBuilding(id: "JAGUAR_CENTER", code: "Jaguar Center",
            name: "Jaguar Center — zona sureste del campus",
            lat: 12.107700, lon: -86.256800, category: .service),

        UAMBuilding(id: "RRPP", code: "RRPP",
            name: "Relaciones Publicas / Public Relations — zona sur",
            lat: 12.107350, lon: -86.257000, category: .service),

        UAMBuilding(id: "ESTACION_MET", code: "Estacion Met.",
            name: "Estacion Meteorologica / Weather Station — noroeste",
            lat: 12.109050, lon: -86.257600, category: .service),

        UAMBuilding(id: "FONDO_COUNT", code: "Fondo / Count.",
            name: "Fondo / Contaduria — zona central junto a Plaza",
            lat: 12.108200, lon: -86.257500, category: .service),

        UAMBuilding(id: "COMPLEJO_DEPORTIVO", code: "Complejo Dep.",
            name: "Complejo Deportivo Jaguar — sureste",
            lat: 12.107600, lon: -86.256600, category: .service),

        // ── Banco ──────────────────────────────────────────────────────────────
        UAMBuilding(id: "BANPRO", code: "Banpro",
            name: "Banpro / Bank — suroeste del campus",
            lat: 12.107900, lon: -86.257800, category: .bank),

        // ── Deportes ───────────────────────────────────────────────────────────
        UAMBuilding(id: "CANCHA_FUTBOL", code: "Cancha Futbol",
            name: "Cancha de Futbol / Soccer Field — este del campus",
            lat: 12.108550, lon: -86.256650, category: .sports),

        UAMBuilding(id: "CANCHA_DEPORTIVA", code: "Canchas Dep.",
            name: "Canchas Deportivas Jaguar — sureste",
            lat: 12.107500, lon: -86.256700, category: .sports),

        // ── Recreacion / Plazas ────────────────────────────────────────────────
        UAMBuilding(id: "PLAZA_CENTRAL", code: "Plaza Central",
            name: "Plaza Central Ruben Dario / Central Square — sur del campus",
            lat: 12.107950, lon: -86.257300, category: .recreation),

        UAMBuilding(id: "SENDEROS", code: "Senderos",
            name: "Senderos / Paths — zona este del campus",
            lat: 12.108800, lon: -86.256500, category: .recreation),

        UAMBuilding(id: "ACOPIO", code: "Acopio",
            name: "Acopio / Gathering Area — noroeste",
            lat: 12.108900, lon: -86.257900, category: .recreation),

        // ── Parqueos ───────────────────────────────────────────────────────────
        UAMBuilding(id: "PARQUEO_NORTE_1", code: "Parqueo Norte",
            name: "Parqueo Norte — junto a Edificio Copernico",
            lat: 12.109250, lon: -86.257200, category: .parking),

        UAMBuilding(id: "PARQUEO_NORTE_2", code: "Parqueo N-2",
            name: "Parqueo Norte 2 — acceso por entrada norte",
            lat: 12.109200, lon: -86.256900, category: .parking),

        UAMBuilding(id: "PARQUEO_CENTRAL", code: "Parqueo Central",
            name: "Parqueo Central — zona pabellones A-C-K",
            lat: 12.108700, lon: -86.257700, category: .parking),

        UAMBuilding(id: "PARQUEO_ACOPIO", code: "Parqueo Acopio",
            name: "Parqueo Acopio / Gathering Lot — noroeste",
            lat: 12.108950, lon: -86.258100, category: .parking),

        UAMBuilding(id: "PARQUEO_SUR", code: "Parqueo Sur",
            name: "Parqueo Sur — zona Plaza Central / Jaguar",
            lat: 12.107600, lon: -86.257200, category: .parking),

        UAMBuilding(id: "PARQUEO_JAGUAR", code: "Parqueo Jaguar",
            name: "Parqueo Jaguar Center — sureste",
            lat: 12.107400, lon: -86.256800, category: .parking),

        UAMBuilding(id: "PANELES_SOLARES", code: "Paneles Solares",
            name: "Paneles Solares / Solar Panels — oeste del campus",
            lat: 12.108300, lon: -86.258000, category: .service),

        UAMBuilding(id: "AREA_CONTENEDORES", code: "Contenedores",
            name: "Area de Contenedores / Container Area — sureste extremo",
            lat: 12.107300, lon: -86.256500, category: .service),
    ]

    // MARK: - Helpers

    public static func building(id: String) -> UAMBuilding? {
        buildings.first { $0.id == id }
    }

    // MARK: - Room inference
    // Convencion UAM: aulas se nombran "<letra>-<numero>" (ej. C-102, A-201, H-302, K-105).
    // Esta funcion infiere el edificio desde el codigo de aula.
    // Edificios validos del mapa oficial: A, B, C, F, G, H, I, K, L, M, N, P

    public static func inferBuilding(fromRoom room: String) -> UAMBuilding? {
        let trimmed = room.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard let first = trimmed.first else { return nil }

        let validBuildings: Set<String> = ["A","B","C","F","G","H","I","K","L","M","N","P"]
        let candidate = String(first)

        if validBuildings.contains(candidate) {
            return building(id: candidate)
        }

        // Fallback: extraer letra tras "EDIFICIO" o "EDIF" o "PABELLON"
        for prefix in ["EDIFICIO ", "EDIF ", "PABELLON ", "PAB "] {
            if let range = trimmed.range(of: prefix), range.upperBound < trimmed.endIndex {
                let after = String(trimmed[range.upperBound...])
                if let letter = after.first.map(String.init), validBuildings.contains(letter) {
                    return building(id: letter)
                }
            }
        }

        // Keyword matches for named facilities
        let lower = trimmed.lowercased()
        if lower.contains("clinica") || lower.contains("dental") { return building(id: "CLINICA") }
        if lower.contains("comedor") || lower.contains("lunch")  { return building(id: "COMEDOR") }
        if lower.contains("rancho") || lower.contains("ranch")   { return building(id: "RANCHO") }
        if lower.contains("kiosko") || lower.contains("kiosk")   { return building(id: "KIOSCOS") }
        if lower.contains("copernico") || lower.contains("copernicus") { return building(id: "P") }
        if lower.contains("jaguar")                              { return building(id: "JAGUAR_CENTER") }
        if lower.contains("plaza") || lower.contains("ruben")    { return building(id: "PLAZA_CENTRAL") }
        if lower.contains("banpro") || lower.contains("banco")   { return building(id: "BANPRO") }
        if lower.contains("cancha") || lower.contains("futbol")  { return building(id: "CANCHA_FUTBOL") }
        if lower.contains("estacion") || lower.contains("weather") { return building(id: "ESTACION_MET") }

        return nil
    }

    public static func inferBuilding(for course: Course, session: ClassSession? = nil) -> UAMBuilding? {
        if let s = session {
            let r = s.room.trimmingCharacters(in: .whitespaces)
            if !r.isEmpty, let b = inferBuilding(fromRoom: r) { return b }
        }
        return inferBuilding(fromRoom: course.room)
    }
}
