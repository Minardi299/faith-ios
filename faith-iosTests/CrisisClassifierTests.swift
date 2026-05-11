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
}
