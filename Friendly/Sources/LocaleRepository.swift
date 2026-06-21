import Foundation

struct LocaleRepository {
    func obtain() -> LocaleCode {
        let identifier =
            Bundle.main.preferredLocalizations.first ?? Locale.current.identifier
        let languageCode =
            Locale(identifier: identifier).language.languageCode?.identifier
            ?? LocaleCode.en.rawValue
        return LocaleCode(rawValue: languageCode) ?? .en
    }
}

enum LocaleCode: String {
    case en
    case ru
}
