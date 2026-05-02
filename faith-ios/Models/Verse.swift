import Foundation

struct Verse: Codable, Identifiable, Hashable {
    let number: Int
    let chapter: Int
    let chapterPali: String
    let chapterTitle: String
    let storyTitle: String
    let storyPaliName: String
    let story: String
    let text: String

    var id: Int { number }
}
