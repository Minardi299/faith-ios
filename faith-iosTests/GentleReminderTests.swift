import Testing
@testable import faith_ios

@Suite("GentleReminder")
struct GentleReminderTests {

    @Test("Fires on 'I want to die'")
    func positiveCase1() {
        #expect(GentleReminder.shouldFire(on: "I want to die"))
    }

    @Test("Fires on 'I'm thinking about suicide'")
    func positiveCase2() {
        #expect(GentleReminder.shouldFire(on: "I'm thinking about suicide"))
    }

    @Test("Fires on capitalized variants")
    func positiveCaseCaps() {
        #expect(GentleReminder.shouldFire(on: "I CAN'T GO ON"))
    }

    @Test("Does not fire on 'I'm grieving my dog'")
    func negativeCase1() {
        #expect(!GentleReminder.shouldFire(on: "I'm grieving my dog"))
    }

    @Test("Does not fire on 'how do I sit with anger'")
    func negativeCase2() {
        #expect(!GentleReminder.shouldFire(on: "how do I sit with anger"))
    }

    @Test("Does not fire on empty input")
    func negativeEmpty() {
        #expect(!GentleReminder.shouldFire(on: ""))
    }
}
