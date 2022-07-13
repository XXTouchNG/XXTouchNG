import Foundation

public protocol MiddleCookieJarConvertible {
    init(from cookieJar: MiddleCookieJar)
}

public protocol MiddleCookieJarExportable {
    func toMiddleCookieJar() -> MiddleCookieJar
}

public protocol MiddleCookieConvertible {
    init(from cookie: MiddleCookie)
}

public protocol MiddleCookieExportable {
    func toMiddleCookie() -> MiddleCookie?
}

public typealias MiddleCookieJar = [[HTTPCookiePropertyKey: Any]]
public typealias MiddleCookie = [HTTPCookiePropertyKey: Any]

extension MiddleCookieJar: EditThisCookieExportable {
    
    public func toEditThisCookie() -> EditThisCookie {
        map({ EditThisCookieItem(from: $0) })
    }
    
}

extension HTTPCookiePropertyKey {
    static let httpOnly = HTTPCookiePropertyKey(rawValue: "httpOnly")
    static let sessionOnly = HTTPCookiePropertyKey(rawValue: "sessionOnly")
}
