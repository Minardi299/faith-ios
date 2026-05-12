import Testing
@testable import faith_ios

@Suite("CrisisClassifier")
struct CrisisClassifierTests {

    @Test("Detects 'I want to die'")
    func positiveCase1() {
        #expect(CrisisClassifier.detects(in: "I want to die"))
    }

    @Test("Detects 'I'm thinking about suicide'")
    func positiveCase2() {
        #expect(CrisisClassifier.detects(in: "I'm thinking about suicide"))
    }

    @Test("Detects capitalized variants")
    func positiveCaseCaps() {
        #expect(CrisisClassifier.detects(in: "I CAN'T GO ON"))
    }

    @Test("Does not fire on 'I'm grieving my dog'")
    func negativeCase1() {
        #expect(!CrisisClassifier.detects(in: "I'm grieving my dog"))
    }

    @Test("Does not fire on 'how do I sit with anger'")
    func negativeCase2() {
        #expect(!CrisisClassifier.detects(in: "how do I sit with anger"))
    }

    @Test("Does not fire on empty input")
    func negativeEmpty() {
        #expect(!CrisisClassifier.detects(in: ""))
    }

    @Test("Detects smart apostrophe variants")
    func smartApostropheCantGoOn() {
        #expect(CrisisClassifier.detects(in: "I CAN\u{2019}T GO ON"))
        #expect(CrisisClassifier.detects(in: "i can\u{2018}t go on"))
    }

    @Test("Detects Unicode hyphen variants in 'self-harm'")
    func unicodeHyphenSelfHarm() {
        #expect(CrisisClassifier.detects(in: "self\u{2010}harm"))   // hyphen
        #expect(CrisisClassifier.detects(in: "self\u{2011}harm"))   // non-breaking hyphen
        #expect(CrisisClassifier.detects(in: "self\u{2013}harm"))   // en dash
        #expect(CrisisClassifier.detects(in: "self\u{2014}harm"))   // em dash
    }

    @Test("Detects diacritic-folded variants")
    func diacriticFolded() {
        // "süicid" with an umlaut should still match "suicid"
        #expect(CrisisClassifier.detects(in: "I'm thinking about süicide"))
    }
}
