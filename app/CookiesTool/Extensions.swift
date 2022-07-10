import Foundation

typealias CookieConvertible = MiddleCookieConvertible & EditThisCookieItemConvertible & NetscapeCookieConvertible & BinaryCookieConvertible & LWPCookieConvertible & HTTPCookieConvertible
typealias CookieJarConvertible = MiddleCookieJarConvertible & EditThisCookieConvertible & NetscapeCookieJarConvertible & BinaryCookieJarConvertible & LWPCookieJarConvertible & HTTPCookieJarConvertible

public extension Collection {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
