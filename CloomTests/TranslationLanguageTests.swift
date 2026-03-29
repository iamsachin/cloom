import Testing
@testable import Cloom

struct TranslationLanguageTests {

    @Test func allCasesContainsOriginal() {
        #expect(TranslationLanguage.allCases.contains(.original))
    }

    @Test func allCasesCount() {
        // 1 original + 14 languages
        #expect(TranslationLanguage.allCases.count == 15)
    }

    @Test func rawValueRoundTrip() {
        for lang in TranslationLanguage.allCases {
            let roundTripped = TranslationLanguage(rawValue: lang.rawValue)
            #expect(roundTripped == lang)
        }
    }

    @Test func identifiableId() {
        for lang in TranslationLanguage.allCases {
            #expect(lang.id == lang.rawValue)
        }
    }

    @Test func originalRawValue() {
        #expect(TranslationLanguage.original.rawValue == "Original")
    }

    @Test func specificLanguageRawValues() {
        #expect(TranslationLanguage.spanish.rawValue == "Spanish")
        #expect(TranslationLanguage.japanese.rawValue == "Japanese")
        #expect(TranslationLanguage.arabic.rawValue == "Arabic")
        #expect(TranslationLanguage.turkish.rawValue == "Turkish")
    }
}
