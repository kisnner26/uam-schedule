import SwiftUI
import MapKit
import CoreLocation

// MARK: - Models

struct CampusRoutePoint: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    let latitude: Double; let longitude: Double; let timestamp: Date
    init(_ coord: CLLocationCoordinate2D) { latitude = coord.latitude; longitude = coord.longitude; timestamp = Date() }
    var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }
}

struct CampusRoute: Codable, Identifiable {
    var id: UUID = UUID()
    var name: String; var originLabel: String; var destLabel: String
    var points: [CampusRoutePoint]; var colorHex: String; var createdAt: Date = Date()
    var coordinates: [CLLocationCoordinate2D] { points.map(\.coordinate) }
    var distanceMeters: Double {
        guard points.count > 1 else { return 0 }
        return zip(points, points.dropFirst()).reduce(0.0) { acc, pair in
            CLLocation(latitude: pair.0.latitude, longitude: pair.0.longitude)
                .distance(from: CLLocation(latitude: pair.1.latitude, longitude: pair.1.longitude)) + acc
        }
    }
    var distanceString: String {
        distanceMeters >= 1000 ? String(format: "%.1f km", distanceMeters/1000) : String(format: "%.0f m", distanceMeters)
    }
    var durationString: String {
        guard let f = points.first, let l = points.last else { return "—" }
        let s = Int(l.timestamp.timeIntervalSince(f.timestamp))
        return s < 60 ? "\(s)s" : "\(s/60)m \(s%60)s"
    }
}

// MARK: - Store

@MainActor final class CampusRouteStore: ObservableObject {
    static let shared = CampusRouteStore()
    private let key = "uam_campus_routes_v2"
    @Published var routes: [CampusRoute] = []
    private init() { load() }
    func save(_ r: CampusRoute) { routes.append(r); persist() }
    func delete(at i: IndexSet) { routes.remove(atOffsets: i); persist() }
    func delete(_ r: CampusRoute) { routes.removeAll { $0.id == r.id }; persist() }
    private func persist() { if let d = try? JSONEncoder().encode(routes) { UserDefaults.standard.set(d, forKey: key) } }
    private func load() { guard let d = UserDefaults.standard.data(forKey: key), let r = try? JSONDecoder().decode([CampusRoute].self, from: d) else { return }; routes = r }
}

// MARK: - Location Manager

final class CampusLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let mgr = CLLocationManager()
    @Published var location: CLLocation?
    @Published var authStatus: CLAuthorizationStatus = .notDetermined
    @Published var isTracking = false
    @Published var livePoints: [CampusRoutePoint] = []
    override init() { super.init(); mgr.delegate = self; mgr.desiredAccuracy = kCLLocationAccuracyBest; mgr.distanceFilter = 2; authStatus = mgr.authorizationStatus }
    func requestAuth() { mgr.requestWhenInUseAuthorization() }
    func startTracking() { livePoints = []; isTracking = true; mgr.startUpdatingLocation() }
    func stopTracking() -> [CampusRoutePoint] { isTracking = false; mgr.stopUpdatingLocation(); return livePoints }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locs: [CLLocation]) {
        guard let l = locs.last else { return }; location = l
        if isTracking { livePoints.append(CampusRoutePoint(l.coordinate)) }
    }
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authStatus = manager.authorizationStatus
        if authStatus == .authorizedWhenInUse || authStatus == .authorizedAlways { mgr.startUpdatingLocation() }
    }
}

// MARK: - Main View

struct UAMRouteView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: ScheduleStore
    @StateObject private var routeStore = CampusRouteStore.shared
    @StateObject private var loc = CampusLocationManager()

    @State private var camera = MapCameraPosition.region(
        MKCoordinateRegion(center: UAMCampus.center, latitudinalMeters: 500, longitudinalMeters: 500)
    )
    @State private var isTracing = false
    @State private var traceColor = "#6B1A2A"
    @State private var showSave = false
    @State private var showList = false
    @State private var showBldg = false
    @State private var selectedRoute: CampusRoute? = nil
    @State private var selectedBldg: UAMBuilding? = nil
    @State private var catFilter: UAMBuilding.Category? = nil
    @State private var satellite = false
    @State private var appeared = false
    // Save form
    @State private var originLabel = ""
    @State private var destLabel = ""
    @State private var routeName = ""
    @State private var saveColor = "#6B1A2A"

    private let palette = ["#6B1A2A","#1A3A6B","#1A5C3A","#6B4A1A","#3A1A6B","#1A5A6B"]

    var filtered: [UAMBuilding] {
        guard let c = catFilter else { return UAMCampus.buildings }
        return UAMCampus.buildings.filter { $0.category == c }
    }

    var body: some View {
        ZStack(alignment: .bottom) {

            // MAP
            Map(position: $camera) {
                UserAnnotation()
                ForEach(filtered) { b in
                    Annotation("", coordinate: b.coord) {
                        CampusPin(building: b, isSelected: selectedBldg?.id == b.id)
                            .onTapGesture { withAnimation(DS.Anim.spring) {
                                selectedBldg = selectedBldg?.id == b.id ? nil : b
                            }}
                    }
                }
                ForEach(routeStore.routes) { r in
                    if r.coordinates.count > 1 {
                        let sel = selectedRoute?.id == r.id
                        MapPolyline(coordinates: r.coordinates)
                            .stroke(Color(hex: r.colorHex).opacity(sel ? 1 : 0.45),
                                    style: StrokeStyle(lineWidth: sel ? 5 : 3, lineCap: .round, lineJoin: .round))
                    }
                }
                if loc.livePoints.count > 1 {
                    MapPolyline(coordinates: loc.livePoints.map(\.coordinate))
                        .stroke(Color(hex: traceColor), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round, dash: [8,5]))
                }
            }
            .mapStyle(satellite ? .imagery(elevation: .realistic) : .standard(elevation: .realistic, pointsOfInterest: .excludingAll))
            .ignoresSafeArea()

            // OVERLAY CONTROLS
            overlayControls
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.top, 56)
                .zIndex(30)

            // TRACING BANNER
            if isTracing {
                tracingBanner
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.top, 120)
                    .zIndex(20)
                    .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity),
                                            removal: .move(edge: .top).combined(with: .opacity)))
            }

            // BUILDING CALLOUT
            if let b = selectedBldg, !isTracing {
                CampusCallout(building: b) { selectedBldg = nil }
                    .padding(.horizontal, DS.Space.md)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 230)
                    .zIndex(25)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // BOTTOM SHEET
            bottomSheet
                .zIndex(10)
        }
        .ignoresSafeArea(edges: .bottom)
        .onAppear { loc.requestAuth(); appeared = true }
        .sheet(isPresented: $showSave) { saveSheet }
        .sheet(isPresented: $showList) { listSheet }
        .sheet(isPresented: $showBldg) { buildingSheet }
        .animation(DS.Anim.spring, value: isTracing)
        .animation(DS.Anim.spring, value: selectedBldg?.id)
    }

    // MARK: Overlay controls

    var overlayControls: some View {
        HStack(alignment: .top, spacing: 8) {
            // Back
            Button { dismiss() } label: {
                Label("Volver", systemImage: "chevron.left")
                    .font(DS.Font.body(13, weight: .semibold))
                    .foregroundStyle(Color.appInk)
                    .padding(.horizontal, 14).padding(.vertical, 9)
                    .background(.ultraThinMaterial, in: Capsule())
                    .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
            }.buttonStyle(.plain)

            Spacer()

            VStack(alignment: .trailing, spacing: 8) {
                // Map style
                Button {
                    withAnimation(DS.Anim.springFast) { satellite.toggle() }
                } label: {
                    Image(systemName: satellite ? "map" : "globe")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.appInk)
                        .frame(width: 38, height: 38)
                        .background(.ultraThinMaterial, in: Circle())
                        .shadow(color: .black.opacity(0.1), radius: 6, y: 2)
                }.buttonStyle(.plain)

                // Re-center
                Button {
                    withAnimation(DS.Anim.spring) {
                        camera = .region(MKCoordinateRegion(center: UAMCampus.center, latitudinalMeters: 500, longitudinalMeters: 500))
                    }
                } label: {
                    Image(systemName: "location.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DS.Color.wine)
                        .frame(width: 38, height: 38)
                        .background(.ultraThinMaterial, in: Circle())
                        .shadow(color: .black.opacity(0.1), radius: 6, y: 2)
                }.buttonStyle(.plain)
            }
        }
        .padding(.horizontal, DS.Space.md)
    }

    // MARK: Tracing banner

    var tracingBanner: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(.red.opacity(0.15)).frame(width: 34, height: 34)
                Circle().fill(.red).frame(width: 10, height: 10)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("GRABANDO RUTA").font(DS.Font.body(10, weight: .black)).foregroundStyle(.red).tracking(1.5)
                Text("\(loc.livePoints.count) puntos — muevete hacia tu destino")
                    .font(DS.Font.body(11)).foregroundStyle(Color.appInkSecondary)
            }
            Spacer()
            if loc.livePoints.count > 1 {
                let dist = CampusRoute(name:"",originLabel:"",destLabel:"",points:loc.livePoints,colorHex:traceColor).distanceString
                Text(dist).font(DS.Font.mono(14, weight: .bold)).foregroundStyle(.red)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 11)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.red.opacity(0.2), lineWidth: 1))
        .shadow(color: .black.opacity(0.1), radius: 10, y: 3)
        .padding(.horizontal, DS.Space.md)
    }

    // MARK: Bottom sheet

    var bottomSheet: some View {
        VStack(spacing: 0) {
            // Drag handle
            Capsule().fill(Color.appInkTertiary.opacity(0.25)).frame(width: 36, height: 4)
                .padding(.top, 10).padding(.bottom, 14)

            // Category filter scroll
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    CampusChip(label: "Todo", icon: "map.fill", active: catFilter == nil) {
                        withAnimation(DS.Anim.springFast) { catFilter = nil }
                    }
                    ForEach(UAMBuilding.Category.orderedCases, id: \.self) { cat in
                        CampusChip(label: cat.rawValue, icon: cat.icon, active: catFilter == cat) {
                            withAnimation(DS.Anim.springFast) { catFilter = catFilter == cat ? nil : cat }
                        }
                    }
                }
                .padding(.horizontal, DS.Space.md)
            }
            .padding(.bottom, 14)

            // Saved routes horizontal scroll
            if !routeStore.routes.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(routeStore.routes) { r in
                            let sel = selectedRoute?.id == r.id
                            Button {
                                withAnimation(DS.Anim.spring) {
                                    selectedRoute = sel ? nil : r
                                    if !sel, r.coordinates.count > 1 {
                                        camera = .region(MKCoordinateRegion(
                                            center: r.coordinates[r.coordinates.count/2],
                                            latitudinalMeters: 350, longitudinalMeters: 350))
                                    }
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Circle().fill(Color(hex: r.colorHex)).frame(width: 7, height: 7)
                                    Text(r.name.isEmpty ? "\(r.originLabel) → \(r.destLabel)" : r.name)
                                        .font(DS.Font.body(11, weight: .semibold)).foregroundStyle(Color.appInk).lineLimit(1)
                                    Text("·").foregroundStyle(Color.appInkTertiary)
                                    Text(r.distanceString).font(DS.Font.mono(10)).foregroundStyle(Color.appInkTertiary)
                                }
                                .padding(.horizontal, 12).padding(.vertical, 7)
                                .background(sel ? Color(hex: r.colorHex).opacity(0.12) : Color.appBackgroundSecondary)
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(sel ? Color(hex: r.colorHex).opacity(0.4) : Color.appCardBorder, lineWidth: 1))
                            }.buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, DS.Space.md)
                }
                .padding(.bottom, 12)
            }

            // Color row when tracing
            if isTracing {
                HStack(spacing: 10) {
                    Text("Color:").font(DS.Font.body(11, weight: .medium)).foregroundStyle(Color.appInkTertiary)
                    ForEach(palette, id: \.self) { hex in
                        Button { withAnimation(DS.Anim.springFast) { traceColor = hex } } label: {
                            Circle().fill(Color(hex: hex)).frame(width: 26, height: 26)
                                .overlay(Circle().stroke(.white, lineWidth: traceColor == hex ? 2.5 : 0).padding(2))
                                .shadow(color: Color(hex: hex).opacity(0.4), radius: traceColor == hex ? 4 : 0)
                        }.buttonStyle(.plain)
                    }
                    Spacer()
                }
                .padding(.horizontal, DS.Space.md).padding(.bottom, 10)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Action buttons
            HStack(spacing: 10) {
                if !isTracing {
                    // Primary: trace
                    Button {
                        Soft.haptic(.medium)
                        withAnimation(DS.Anim.spring) { isTracing = true }
                        loc.startTracking()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "point.3.connected.trianglepath.dotted").font(.system(size: 16, weight: .semibold))
                            Text("Trazar ruta").font(DS.Font.body(15, weight: .semibold))
                        }
                        .foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(
                            LinearGradient(colors: [DS.Color.wine, DS.Color.wineLight], startPoint: .leading, endPoint: .trailing)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: DS.Color.wine.opacity(0.4), radius: 12, y: 4)
                    }.buttonStyle(.plain)

                    // Secondary: buildings
                    Button { withAnimation { showBldg = true } } label: {
                        Image(systemName: "building.columns.fill")
                            .font(.system(size: 17, weight: .semibold)).foregroundStyle(DS.Color.wine)
                            .frame(width: 50, height: 50)
                            .background(DS.Color.wineMuted)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(DS.Color.wine.opacity(0.2), lineWidth: 1))
                    }.buttonStyle(.plain)

                    // Routes list
                    Button { withAnimation { showList = true } } label: {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "list.bullet.below.rectangle")
                                .font(.system(size: 17, weight: .semibold)).foregroundStyle(Color.appInkTertiary)
                                .frame(width: 50, height: 50)
                                .background(Color.appBackgroundSecondary)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.appCardBorder, lineWidth: 1))
                            if !routeStore.routes.isEmpty {
                                Text("\(routeStore.routes.count)")
                                    .font(DS.Font.mono(9, weight: .bold)).foregroundStyle(.white)
                                    .frame(width: 16, height: 16)
                                    .background(DS.Color.wine).clipShape(Circle())
                                    .offset(x: 4, y: -4)
                            }
                        }
                    }.buttonStyle(.plain)

                } else {
                    // Save
                    Button {
                        Soft.haptic(.success)
                        let pts = loc.stopTracking()
                        withAnimation(DS.Anim.spring) { isTracing = false }
                        if pts.count > 1 { showSave = true }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill").font(.system(size: 16, weight: .semibold))
                            Text("Guardar ruta").font(DS.Font.body(15, weight: .semibold))
                        }
                        .foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(LinearGradient(colors: [Color(hex:"#1A5C3A"), Color(hex:"#2A7C4A")], startPoint: .leading, endPoint: .trailing))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: Color(hex:"#1A5C3A").opacity(0.4), radius: 12, y: 4)
                    }.buttonStyle(.plain)

                    // Cancel
                    Button {
                        Soft.haptic(.light); _ = loc.stopTracking()
                        withAnimation(DS.Anim.spring) { isTracing = false }
                    } label: {
                        Image(systemName: "xmark").font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.red)
                            .frame(width: 50, height: 50)
                            .background(Color.red.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }.buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DS.Space.md)
            .padding(.bottom, 36)
        }
        .background(Color.appBackground
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: 22, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 22)))
        .shadow(color: .black.opacity(0.1), radius: 20, y: -4)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 60)
        .animation(DS.Anim.spring.delay(0.08), value: appeared)
    }

    // MARK: Save sheet

    var saveSheet: some View {
        NavigationStack {
            ZStack { Color.appBackground.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        // Summary card
                        ZStack(alignment: .bottomLeading) {
                            RoundedRectangle(cornerRadius: 16).fill(Color(hex: saveColor).opacity(0.12)).frame(height: 100)
                            HStack(spacing: 12) {
                                Capsule().fill(Color(hex: saveColor)).frame(width: 4, height: 60)
                                VStack(alignment: .leading, spacing: 3) {
                                    let r = CampusRoute(name:"",originLabel:"",destLabel:"",points:loc.livePoints,colorHex:saveColor)
                                    Text(r.distanceString).font(DS.Font.display(24, weight: .bold)).foregroundStyle(Color.appInk)
                                    Text("\(loc.livePoints.count) puntos · \(r.durationString)").font(DS.Font.body(12)).foregroundStyle(Color.appInkTertiary)
                                }
                                Spacer()
                                Image(systemName: "point.3.connected.trianglepath.dotted").font(.system(size: 32)).foregroundStyle(Color(hex:saveColor).opacity(0.25))
                            }.padding(DS.Space.md)
                        }

                        // Fields
                        VStack(spacing: 10) {
                            SaveFieldRow(icon: "arrow.up.right.circle.fill", label: "Origen", placeholder: "Ej: Entrada principal", text: $originLabel)
                            SaveFieldRow(icon: "mappin.circle.fill", label: "Destino", placeholder: "Ej: Edificio C-211", text: $destLabel)
                            SaveFieldRow(icon: "tag.fill", label: "Nombre (opcional)", placeholder: "Ej: Mi ruta habitual", text: $routeName)
                        }

                        // Color
                        VStack(alignment: .leading, spacing: 10) {
                            Text("COLOR").font(DS.Font.body(9, weight: .semibold)).foregroundStyle(Color.appInkTertiary).tracking(2)
                            HStack(spacing: 12) {
                                ForEach(palette, id: \.self) { hex in
                                    Button { withAnimation(DS.Anim.springFast) { saveColor = hex } } label: {
                                        Circle().fill(Color(hex: hex)).frame(width: 40, height: 40)
                                            .overlay(Circle().stroke(.white, lineWidth: saveColor == hex ? 2.5 : 0).padding(3))
                                            .overlay(Image(systemName:"checkmark").font(.system(size:13,weight:.bold)).foregroundStyle(.white).opacity(saveColor==hex ? 1:0))
                                            .scaleEffect(saveColor == hex ? 1.1 : 1)
                                            .animation(DS.Anim.springFast, value: saveColor)
                                    }.buttonStyle(.plain)
                                }
                                Spacer()
                            }
                        }
                        .padding(DS.Space.md).background(Color.appBackgroundSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                        .overlay(RoundedRectangle(cornerRadius: DS.Radius.sm).stroke(Color.appCardBorder, lineWidth: 1))

                        // Save button
                        let canSave = !originLabel.trimmingCharacters(in:.whitespaces).isEmpty && !destLabel.trimmingCharacters(in:.whitespaces).isEmpty
                        Button {
                            let name = routeName.isEmpty ? "\(originLabel) → \(destLabel)" : routeName
                            routeStore.save(CampusRoute(name:name, originLabel:originLabel, destLabel:destLabel, points:loc.livePoints, colorHex:saveColor))
                            originLabel=""; destLabel=""; routeName=""; saveColor="#6B1A2A"
                            showSave = false; Soft.haptic(.success)
                        } label: {
                            Text("Guardar ruta").font(DS.Font.body(15, weight: .semibold)).foregroundStyle(.white)
                                .frame(maxWidth: .infinity).padding(.vertical, 14)
                                .background(canSave ? DS.Color.wine : Color.appInkTertiary)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }.buttonStyle(.plain).disabled(!canSave).padding(.top, 4)
                    }
                    .padding(DS.Space.md)
                }
            }
            .navigationTitle("Guardar ruta").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { showSave=false }.foregroundStyle(Color.appInkTertiary) } }
        }
    }

    // MARK: List sheet

    var listSheet: some View {
        NavigationStack {
            ZStack { Color.appBackground.ignoresSafeArea()
                if routeStore.routes.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName:"point.3.connected.trianglepath.dotted").font(.system(size:40,weight:.light)).foregroundStyle(Color.appInkTertiary.opacity(0.3))
                        Text("Sin rutas guardadas").font(DS.Font.body(16)).foregroundStyle(Color.appInkTertiary.opacity(0.5))
                    }
                } else {
                    List {
                        ForEach(routeStore.routes) { r in
                            Button {
                                withAnimation(DS.Anim.spring) { selectedRoute = r; showList = false
                                    if r.coordinates.count > 1 {
                                        camera = .region(MKCoordinateRegion(center: r.coordinates[r.coordinates.count/2], latitudinalMeters:350, longitudinalMeters:350))
                                    }
                                }
                            } label: {
                                HStack(spacing: DS.Space.md) {
                                    Capsule().fill(Color(hex:r.colorHex)).frame(width:4, height:44)
                                    VStack(alignment:.leading, spacing:3) {
                                        Text(r.name.isEmpty ? "\(r.originLabel) → \(r.destLabel)" : r.name)
                                            .font(DS.Font.body(13, weight:.semibold)).foregroundStyle(Color.appInk).lineLimit(1)
                                        HStack(spacing:8) {
                                            Label(r.distanceString, systemImage:"arrow.left.and.right").font(DS.Font.body(11)).foregroundStyle(Color.appInkTertiary)
                                            Label("\(r.points.count) pts", systemImage:"mappin").font(DS.Font.body(11)).foregroundStyle(Color.appInkTertiary)
                                        }
                                    }
                                    Spacer()
                                }
                            }
                            .listRowBackground(Color.appBackgroundSecondary)
                        }
                        .onDelete { routeStore.delete(at: $0) }
                    }
                    .listStyle(.insetGrouped).scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Rutas guardadas").navigationBarTitleDisplayMode(.large)
            .toolbar { ToolbarItem(placement:.confirmationAction) { Button("Listo") { showList=false }.foregroundStyle(DS.Color.wine).fontWeight(.semibold) } }
        }
    }

    // MARK: Building sheet

    var buildingSheet: some View {
        NavigationStack {
            ZStack { Color.appBackground.ignoresSafeArea()
                List {
                    ForEach(UAMBuilding.Category.orderedCases, id:\.self) { cat in
                        let buildings = UAMCampus.buildings.filter { $0.category == cat }
                        if !buildings.isEmpty {
                            Section {
                                ForEach(buildings) { b in
                                    Button {
                                        withAnimation(DS.Anim.spring) {
                                            selectedBldg = b
                                            camera = .region(MKCoordinateRegion(center:b.coord, latitudinalMeters:200, longitudinalMeters:200))
                                            showBldg = false
                                        }
                                    } label: {
                                        HStack(spacing:12) {
                                            Image(systemName:b.category.icon).font(.system(size:14,weight:.semibold))
                                                .foregroundStyle(DS.Color.wine).frame(width:32,height:32)
                                                .background(DS.Color.wineMuted).clipShape(RoundedRectangle(cornerRadius:8))
                                            VStack(alignment:.leading, spacing:2) {
                                                Text(b.code).font(DS.Font.body(13,weight:.semibold)).foregroundStyle(Color.appInk)
                                                Text(b.name).font(DS.Font.body(11)).foregroundStyle(Color.appInkTertiary).lineLimit(1)
                                            }
                                            Spacer()
                                        }
                                    }
                                    .listRowBackground(Color.appBackgroundSecondary)
                                }
                            } header: {
                                Text(cat.rawValue.uppercased()).font(DS.Font.body(9,weight:.semibold)).foregroundStyle(Color.appInkTertiary).tracking(1.5)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped).scrollContentBackground(.hidden)
            }
            .navigationTitle("Edificios UAM").navigationBarTitleDisplayMode(.large)
            .toolbar { ToolbarItem(placement:.confirmationAction) { Button("Listo") { showBldg=false }.foregroundStyle(DS.Color.wine).fontWeight(.semibold) } }
        }
    }
}

// MARK: - Campus Pin

struct CampusPin: View {
    let building: UAMBuilding; let isSelected: Bool
    var color: Color {
        switch building.category {
        case .academic: return DS.Color.wine
        case .service:  return Color(hex:"#1A3A6B")
        case .sports:   return Color(hex:"#1A5C3A")
        case .parking:  return Color(hex:"#6B4A1A")
        case .entrance: return Color(hex:"#3A1A6B")
        @unknown default: return DS.Color.wine
        }
    }
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                if isSelected {
                    Circle().fill(color.opacity(0.2)).frame(width:54,height:54)
                        .transition(.scale.combined(with: .opacity))
                }
                Circle().fill(color).frame(width: isSelected ? 40 : 32, height: isSelected ? 40 : 32)
                    .shadow(color:color.opacity(0.45), radius: isSelected ? 10 : 4, y:2)
                Image(systemName: building.category.icon)
                    .font(.system(size: isSelected ? 17 : 13, weight:.semibold))
                    .foregroundStyle(.white)
            }
            .scaleEffect(isSelected ? 1.1 : 1)
            .animation(DS.Anim.spring, value: isSelected)

            if isSelected {
                Text(building.code).font(DS.Font.body(9,weight:.black)).foregroundStyle(color).tracking(0.5)
                    .padding(.horizontal,7).padding(.vertical,3)
                    .background(.ultraThinMaterial, in:Capsule())
                    .transition(.scale.combined(with:.opacity))
                    .padding(.top,3)
            }
        }
    }
}

// MARK: - Campus Callout

struct CampusCallout: View {
    let building: UAMBuilding; let onClose: () -> Void
    var color: Color {
        switch building.category {
        case .academic: return DS.Color.wine
        case .service:  return Color(hex:"#1A3A6B")
        case .sports:   return Color(hex:"#1A5C3A")
        case .parking:  return Color(hex:"#6B4A1A")
        case .entrance: return Color(hex:"#3A1A6B")
        @unknown default: return DS.Color.wine
        }
    }
    var body: some View {
        HStack(spacing:14) {
            ZStack {
                RoundedRectangle(cornerRadius:12).fill(color.opacity(0.12)).frame(width:48,height:48)
                Image(systemName:building.category.icon).font(.system(size:20,weight:.semibold)).foregroundStyle(color)
            }
            VStack(alignment:.leading, spacing:3) {
                Text(building.code).font(DS.Font.body(15,weight:.bold)).foregroundStyle(Color.appInk)
                Text(building.name).font(DS.Font.body(12)).foregroundStyle(Color.appInkTertiary).lineLimit(1)
                Text(building.category.rawValue).font(DS.Font.body(9,weight:.semibold)).foregroundStyle(color).tracking(0.5)
            }
            Spacer()
            Button(action:onClose) {
                Image(systemName:"xmark.circle.fill").font(.system(size:22)).foregroundStyle(Color.appInkTertiary.opacity(0.4))
            }.buttonStyle(.plain)
        }
        .padding(DS.Space.md)
        .background(.regularMaterial, in:RoundedRectangle(cornerRadius:18))
        .overlay(RoundedRectangle(cornerRadius:18).stroke(color.opacity(0.15),lineWidth:1))
        .shadow(color:.black.opacity(0.1),radius:14,y:4)
    }
}

// MARK: - Campus Chip

struct CampusChip: View {
    let label: String; let icon: String; let active: Bool; let action: () -> Void
    var body: some View {
        Button(action:action) {
            HStack(spacing:4) {
                Image(systemName:icon).font(.system(size:10,weight:.semibold))
                Text(label).font(DS.Font.body(11,weight: active ? .semibold : .regular))
            }
            .foregroundStyle(active ? .white : Color.appInk)
            .padding(.horizontal,11).padding(.vertical,7)
            .background(active ? DS.Color.wine : Color.appBackgroundSecondary, in:Capsule())
            .overlay(Capsule().stroke(active ? Color.clear : Color.appCardBorder, lineWidth:1))
        }.buttonStyle(.plain)
        .shadow(color:active ? DS.Color.wine.opacity(0.3) : .clear, radius:6, y:2)
    }
}

// MARK: - Save Field Row

struct SaveFieldRow: View {
    let icon: String; let label: String; let placeholder: String
    @Binding var text: String
    var body: some View {
        HStack(spacing:10) {
            Image(systemName:icon).font(.system(size:15,weight:.semibold)).foregroundStyle(DS.Color.wine).frame(width:28)
            VStack(alignment:.leading, spacing:3) {
                Text(label.uppercased()).font(DS.Font.body(8,weight:.semibold)).foregroundStyle(Color.appInkTertiary).tracking(0.8)
                TextField(placeholder, text:$text).font(DS.Font.body(14)).foregroundStyle(Color.appInk)
            }
        }
        .padding(DS.Space.md).background(Color.appBackgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius:DS.Radius.sm))
        .overlay(RoundedRectangle(cornerRadius:DS.Radius.sm).stroke(Color.appCardBorder,lineWidth:1))
    }
}

// Compatibility aliases
typealias UAMBuildingPin = CampusPin
