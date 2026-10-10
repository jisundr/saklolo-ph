import XCTest
@testable import Saklolo

final class ContactEntryTests: XCTestCase {
    // MARK: Name

    func testThePickedNameIsGivenThenFamily() {
        XCTAssertEqual(ContactEntry.name(given: "Ben", family: "Santos"), "Ben Santos")
    }

    func testStraySpacesAroundNamePartsAreDropped() {
        XCTAssertEqual(ContactEntry.name(given: "  Ben ", family: " Santos\n"), "Ben Santos")
    }

    func testAMissingNamePartLeavesNoGap() {
        XCTAssertEqual(ContactEntry.name(given: "Kuya Ben", family: ""), "Kuya Ben")
        XCTAssertEqual(ContactEntry.name(given: "", family: "Santos"), "Santos")
    }

    func testACardWithOnlyAnOrganisationUsesIt() {
        XCTAssertEqual(ContactEntry.name(given: "", family: " ", organization: "Barangay Hall"), "Barangay Hall")
    }

    func testAPersonalNameWinsOverTheOrganisation() {
        XCTAssertEqual(ContactEntry.name(given: "Ben", family: "", organization: "Barangay Hall"), "Ben")
    }

    // MARK: Number

    func testTheTappedNumberIsUsedEvenWhenOthersComeFirst() {
        let phone = ContactEntry.phone(chosen: "0918 765 4321", from: ["0917 123 4567", "0918 765 4321"])
        XCTAssertEqual(phone, "0918 765 4321")
    }

    func testTheTappedNumberLosesSurroundingWhitespaceLikeATypedOne() {
        XCTAssertEqual(ContactEntry.phone(chosen: " +63 917 123 4567 ", from: []), "+63 917 123 4567")
    }

    func testWithNoTapTheFirstSavableNumberIsUsed() {
        XCTAssertEqual(ContactEntry.phone(chosen: nil, from: ["117", "0917 123 4567"]), "0917 123 4567")
    }

    func testWithNoSavableNumberTheFirstIsStillShownToFix() {
        XCTAssertEqual(ContactEntry.phone(chosen: nil, from: ["117", "911"]), "117")
    }

    func testACardWithNoNumbersGivesNoNumber() {
        XCTAssertNil(ContactEntry.phone(chosen: nil, from: []))
        XCTAssertNil(ContactEntry.phone(chosen: "  ", from: [" "]))
    }

    // MARK: Draft

    func testAPickFillsNameAndNumber() {
        let draft = ContactEntry.draft(given: "Ben", family: "Santos", numbers: ["0917 123 4567"], chosen: nil)
        XCTAssertEqual(draft, ContactEntry.Draft(name: "Ben Santos", phone: "0917 123 4567"))
    }

    func testAnEmptyCardFillsNothing() {
        XCTAssertNil(ContactEntry.draft(given: " ", family: "", numbers: [], chosen: nil))
    }

    // MARK: Saving

    func testSevenDigitsAndANameCanBeSaved() {
        XCTAssertTrue(ContactEntry.canSave(name: "Ben", phone: "123-4567"))
    }

    func testSixDigitsCannotBeSaved() {
        XCTAssertFalse(ContactEntry.canSave(name: "Ben", phone: "12 34 56"))
    }

    func testABlankNameCannotBeSaved() {
        XCTAssertFalse(ContactEntry.canSave(name: "   ", phone: "0917 123 4567"))
    }

    func testAPickedNumberThatIsTooShortCannotBeSaved() {
        let draft = ContactEntry.draft(given: "Hotline", family: "", numbers: ["911"], chosen: nil)
        XCTAssertEqual(draft?.phone, "911")
        XCTAssertFalse(ContactEntry.canSave(name: draft?.name ?? "", phone: draft?.phone ?? ""))
    }
}
