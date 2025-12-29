import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), arabic: "وَقَالَ رَبُّكُمُ ادْعُونِي أَسْتَجِبْ لَكُمْ", translation: "Berdoalah kepada-Ku, niscaya akan Kuperkenankan bagimu.", reference: "Ghafir (40:60)")
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), arabic: "وَقَالَ رَبُّكُمُ ادْعُونِي أَسْتَجِبْ لَكُمْ", translation: "Berdoalah kepada-Ku, niscaya akan Kuperkenankan bagimu.", reference: "Ghafir (40:60)")
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let userDefaults = UserDefaults(suiteName: "group.com.myqurani.hafidz")
        let arabic = userDefaults?.string(forKey: "ayah_arabic") ?? "وَقَالَ رَبُّكُمُ ادْعُونِي أَسْتَجِبْ لَكُمْ"
        let translation = userDefaults?.string(forKey: "ayah_translation") ?? "Berdoalah kepada-Ku, niscaya akan Kuperkenankan bagimu."
        let reference = userDefaults?.string(forKey: "ayah_reference") ?? "Ghafir (40:60)"
        
        let entry = SimpleEntry(date: Date(), arabic: arabic, translation: translation, reference: reference)
        let timeline = Timeline(entries: [entry], policy: .atEnd)
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let arabic: String
    let translation: String
    let reference: String
}

struct QuraniWidgetEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Ayat Hari Ini")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white.opacity(0.8))
            
            Spacer()
            
            Text(entry.arabic)
                .font(.custom("Amiri-Regular", size: 18))
                .foregroundColor(.yellow)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
            
            Text(entry.translation)
                .font(.system(size: 12))
                .foregroundColor(.white)
                .lineLimit(2)
            
            Text(entry.reference)
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.6))
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding()
        .background(Color(hex: "247C64"))
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}

@main
struct QuraniWidget: Widget {
    let kind: String = "QuraniWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            QuraniWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Qurani Daily Ayah")
        .description("Menampilkan ayat hari ini.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
