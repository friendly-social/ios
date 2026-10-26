import CustomDump
import Foundation
import Testing

struct ActivityTimeTests {
  @Test(arguments: ["ru", "en"])
  func namedTimeDistinguishesNowTodayYesterdayAndTwoDaysAgo(language: String) {
    let offsets: [TimeInterval] = [0, -3 * 60 * 60, -24 * 60 * 60, -48 * 60 * 60]
    let expected = language == "ru"
      ? ["сейчас", "3 часа назад", "вчера", "позавчера"]
      : ["now", "3 hours ago", "yesterday", "2 days ago"]
    let style = Date.RelativeFormatStyle(presentation: .named).locale(Locale(identifier: language))
    for (offset, label) in zip(offsets, expected) {
      expectNoDifference(style.format(Date().addingTimeInterval(offset)), label)
    }
  }
}
