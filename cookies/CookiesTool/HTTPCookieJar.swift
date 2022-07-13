import Foundation

public protocol HTTPCookieJarConvertible {
    init(from cookieJar: HTTPCookieJar)
}

public protocol HTTPCookieJarExportable {
    func toHTTPCookieJar() -> HTTPCookieJar
}

public typealias HTTPCookieJar = [HTTPCookie]

public protocol HTTPCookieConvertible {
    init(from cookie: HTTPCookie)
}

public protocol HTTPCookieExportable {
    func toHTTPCookie() -> HTTPCookie?
}
