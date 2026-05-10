import Foundation

/// A pre-recorded chant playable from the Meditate tab. Audio files live in
/// `faith-ios/Resources/chants/` and are baked offline by
/// `tools/build_chants.py` (ElevenLabs).
struct Chant: Identifiable, Hashable {
    let id: String
    let title: String
    let romanised: String?     // optional traditional name in original script
    let language: String       // English / Pali / Sanskrit / Vietnamese / Tibetan
    let filename: String       // extension is .m4a in the bundle
    let estimatedSeconds: Int
    let traditions: Set<Tradition>

    static let all: [Chant] = [
        // MARK: - English

        Chant(
            id: "three-refuges-en", title: "Three Refuges",
            romanised: "Tisaraṇa", language: "English",
            filename: "three-refuges", estimatedSeconds: 90,
            traditions: [.theravada, .mahayana, .vajrayana, .zen]
        ),
        Chant(
            id: "five-precepts-en", title: "Five Precepts",
            romanised: "Pañcasīla", language: "English",
            filename: "five-precepts", estimatedSeconds: 70,
            traditions: [.theravada, .secular]
        ),
        Chant(
            id: "heart-sutra-en", title: "Heart Sūtra",
            romanised: "Prajñāpāramitā Hṛdaya", language: "English",
            filename: "heart-sutra", estimatedSeconds: 240,
            traditions: [.mahayana, .zen]
        ),
        Chant(
            id: "metta-sutta-en", title: "Mettā Sutta",
            romanised: "Karaṇīya Mettā", language: "English",
            filename: "metta-sutta", estimatedSeconds: 180,
            traditions: [.theravada, .secular]
        ),
        Chant(
            id: "three-jewels-en", title: "Three Jewels",
            romanised: "Triratna", language: "English",
            filename: "three-jewels", estimatedSeconds: 60,
            traditions: [.theravada, .mahayana, .vajrayana, .zen]
        ),

        // MARK: - Pali (Theravāda)

        Chant(
            id: "tisarana-pali", title: "Tisaraṇa",
            romanised: "Three Refuges", language: "Pali",
            filename: "tisarana-pali", estimatedSeconds: 90,
            traditions: [.theravada, .mahayana, .vajrayana, .zen]
        ),
        Chant(
            id: "pancasila-pali", title: "Pañcasīla",
            romanised: "Five Precepts", language: "Pali",
            filename: "pancasila-pali", estimatedSeconds: 80,
            traditions: [.theravada, .secular]
        ),
        Chant(
            id: "metta-pali", title: "Karaṇīya Mettā Sutta",
            romanised: "Mettā in Pali", language: "Pali",
            filename: "metta-pali", estimatedSeconds: 120,
            traditions: [.theravada, .secular]
        ),

        // MARK: - Sanskrit (Mahāyāna)

        Chant(
            id: "heart-sutra-sanskrit", title: "Prajñāpāramitā Hṛdaya",
            romanised: "Heart Sūtra in Sanskrit", language: "Sanskrit",
            filename: "heart-sutra-sanskrit", estimatedSeconds: 150,
            traditions: [.mahayana, .zen]
        ),

        // MARK: - Vietnamese (Pure Land)

        Chant(
            id: "nam-mo-a-di-da-phat", title: "Nam Mô A Di Đà Phật",
            romanised: "Amitābha recitation", language: "Vietnamese",
            filename: "nam-mo-a-di-da-phat", estimatedSeconds: 60,
            traditions: [.mahayana]
        ),
        Chant(
            id: "nam-mo-quan-the-am", title: "Nam Mô Quán Thế Âm Bồ Tát",
            romanised: "Avalokiteśvara recitation", language: "Vietnamese",
            filename: "nam-mo-quan-the-am", estimatedSeconds: 70,
            traditions: [.mahayana, .zen]
        ),
        Chant(
            id: "bat-nha-tam-kinh", title: "Bát Nhã Tâm Kinh",
            romanised: "Heart Sūtra in Vietnamese", language: "Vietnamese",
            filename: "bat-nha-tam-kinh", estimatedSeconds: 130,
            traditions: [.mahayana, .zen]
        ),
        Chant(
            id: "quy-y-tam-bao", title: "Quy Y Tam Bảo",
            romanised: "Three Refuges in Vietnamese", language: "Vietnamese",
            filename: "quy-y-tam-bao", estimatedSeconds: 60,
            traditions: [.theravada, .mahayana, .vajrayana, .zen]
        ),

        // MARK: - Tibetan / Sanskrit mantra

        Chant(
            id: "om-mani-padme-hum", title: "Oṃ Maṇi Padme Hūṃ",
            romanised: "Mantra of Avalokiteśvara", language: "Tibetan",
            filename: "om-mani-padme-hum", estimatedSeconds: 90,
            traditions: [.vajrayana]
        ),

        // MARK: - Chinese (Pure Land / Chan)

        Chant(
            id: "xin-jing", title: "心經",
            romanised: "Heart Sūtra in Chinese", language: "Chinese",
            filename: "xin-jing", estimatedSeconds: 130,
            traditions: [.mahayana, .zen]
        ),
        Chant(
            id: "a-mi-tuo-fo", title: "南無阿彌陀佛",
            romanised: "Amitabha recitation", language: "Chinese",
            filename: "a-mi-tuo-fo", estimatedSeconds: 60,
            traditions: [.mahayana]
        ),
        Chant(
            id: "guan-shi-yin", title: "南無觀世音菩薩",
            romanised: "Avalokiteśvara recitation", language: "Chinese",
            filename: "guan-shi-yin", estimatedSeconds: 60,
            traditions: [.mahayana, .zen]
        ),

        // MARK: - Japanese (Zen / Nichiren)

        Chant(
            id: "hannya-shingyo", title: "般若心経",
            romanised: "Heart Sūtra in Japanese", language: "Japanese",
            filename: "hannya-shingyo", estimatedSeconds: 130,
            traditions: [.mahayana, .zen]
        ),
        Chant(
            id: "namu-myoho-renge-kyo", title: "南無妙法蓮華經",
            romanised: "Lotus Sūtra mantra", language: "Japanese",
            filename: "namu-myoho-renge-kyo", estimatedSeconds: 60,
            traditions: [.mahayana]
        ),
    ]
}
