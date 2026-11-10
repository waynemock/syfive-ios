import Testing
@testable import SyFive

// PlayersView is main-actor isolated under the app target's default isolation, so the suite is
// too. 34 §2.1, D-194.
@MainActor
struct ArchivedDeleteOthersTests {

    @Test("The archived-delete alert names up to three others, then \"and 1 other\" or \"and k others\"")
    func othersListNamesThreeThenCounts() {
        #expect(PlayersView.list([]) == "")
        #expect(PlayersView.list(["Ada"]) == "Ada")
        #expect(PlayersView.list(["Ada", "Bo"]) == "Ada and Bo")
        #expect(PlayersView.list(["Ada", "Bo", "Cy"]) == "Ada, Bo and Cy")
        #expect(PlayersView.list(["Ada", "Bo", "Cy", "Di"]) == "Ada, Bo, Cy and 1 other")
        #expect(PlayersView.list(["Ada", "Bo", "Cy", "Di", "Ed"]) == "Ada, Bo, Cy and 2 others")
    }
}
