import SwiftUI

struct MoodTrackerView: View {
    @EnvironmentObject var store: ScheduleStore
    @State private var selectedMood: MoodLevel? = nil
    @State private var note = ""
    @State private var appeared = false
    @Environment(\.dismiss) private var dismiss

    var todayMood: MoodEntry? { store.todayMood() }

    var last7Days: [MoodEntry] {
        let cal = Calendar.current
        let weekAgo = cal.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return store.moodEntries.filter { $0.date >= weekAgo }.sorted { $0.date < $1.date }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: DS.Space.xl) {

                    if let today = todayMood {
                        // Already logged
                        VStack(spacing: 12) {
                            Text(today.mood.emoji).font(.system(size: 56))
                            Text("Hoy te sientes \(today.mood.label.lowercased())")
                                .font(DS.Font.display(18, weight: .semibold)).foregroundStyle(Color.appInk)
                            if !today.note.isEmpty {
                                Text(today.note).font(DS.Font.body(13)).foregroundStyle(Color.appInkTertiary).multilineTextAlignment(.center)
                            }
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, DS.Space.xl)
                    } else {
                        // Log mood
                        VStack(spacing: DS.Space.lg) {
                            Text("Cómo te sientes hoy?")
                                .font(DS.Font.display(20, weight: .semibold)).foregroundStyle(Color.appInk)

                            HStack(spacing: DS.Space.md) {
                                ForEach(MoodLevel.allCases, id: \.self) { mood in
                                    Button {
                                        withAnimation(DS.Anim.springFast) { selectedMood = mood }
                                    } label: {
                                        VStack(spacing: 6) {
                                            Text(mood.emoji).font(.system(size: 32))
                                                .scaleEffect(selectedMood == mood ? 1.3 : 1.0)
                                                .animation(DS.Anim.springFast, value: selectedMood)
                                            Text(mood.label)
                                                .font(DS.Font.body(9, weight: selectedMood == mood ? .bold : .regular))
                                                .foregroundStyle(selectedMood == mood ? Color(hex: mood.color) : Color.appInkTertiary)
                                        }
                                        .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }

                            if selectedMood != nil {
                                VStack(spacing: 10) {
                                    TextField("Alguna nota? (opcional)", text: $note, axis: .vertical)
                                        .font(DS.Font.body(13)).lineLimit(3).padding(10)
                                        .background(Color.appBackgroundTertiary)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))

                                    Button {
                                        guard let mood = selectedMood else { return }
                                        withAnimation(DS.Anim.spring) {
                                            store.addMood(MoodEntry(mood: mood, note: note))
                                        }
                                    } label: {
                                        Text("Registrar").font(DS.Font.body(14, weight: .bold)).foregroundStyle(.white)
                                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                                            .background(DS.Color.wine).clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
                                    }
                                    .buttonStyle(.plain)
                                }
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                            }
                        }
                        .cardStyle()
                    }

                    // History
                    if !last7Days.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("ÚLTIMOS 7 DÍAS")
                                .font(DS.Font.body(9, weight: .bold)).foregroundStyle(Color.appInkTertiary).tracking(2)

                            HStack(alignment: .bottom, spacing: 6) {
                                ForEach(last7Days) { entry in
                                    VStack(spacing: 6) {
                                        Text(entry.mood.emoji).font(.system(size: 20))

                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Color(hex: entry.mood.color).opacity(0.6))
                                            .frame(height: CGFloat(entry.mood.rawValue) * 12)

                                        Text(dayShort(entry.date))
                                            .font(DS.Font.mono(9)).foregroundStyle(Color.appInkTertiary)
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                            }
                        }
                        .cardStyle()
                    }

                    // Average mood
                    if !store.moodEntries.isEmpty {
                        let avg = Double(store.moodEntries.reduce(0) { $0 + $1.mood.rawValue }) / Double(store.moodEntries.count)
                        VStack(spacing: 6) {
                            Text("PROMEDIO DEL SEMESTRE").font(DS.Font.body(9, weight: .bold)).foregroundStyle(Color.appInkTertiary).tracking(2)
                            Text(String(format: "%.1f", avg)).font(DS.Font.display(28, weight: .bold)).foregroundStyle(DS.Color.wine)
                            Text("de 5.0").font(DS.Font.mono(11)).foregroundStyle(Color.appInkTertiary)
                            Text("\(store.moodEntries.count) registros").font(DS.Font.body(11)).foregroundStyle(Color.appInkTertiary)
                        }
                        .frame(maxWidth: .infinity).cardStyle()
                    }
                }
                .padding(.horizontal, DS.Space.md)
                .padding(.bottom, 40)
            }
            .background(Color.appBackground)
            .navigationTitle("Estado de ánimo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }.foregroundStyle(Color.appInkTertiary)
                }
            }
        }
    }

    func dayShort(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "EEE"; f.locale = Locale(identifier: "es")
        return f.string(from: date).prefix(3).capitalized
    }
}
