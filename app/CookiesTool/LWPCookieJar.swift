import Foundation

public enum LWPCookieJarError: Error {
    case lineShouldSkip
    case lineSkipped
    case lineNotSupported
    case lineMalformed
}

public protocol LWPCookieJarConvertible {
    init(from cookieJar: LWPCookieJar)
}

public class LWPCookieJar: Codable, BinaryCodable, CookieJarConvertible, HTTPCookieJarExportable, EditThisCookieExportable, MiddleCookieJarExportable {
    
    public var cookies: [LWPCookie]
    
    enum CodingKeys: String, CodingKey {
        case cookies
    }
    
    public required init(from cookieJar: LWPCookieJar) {
        self.cookies = cookieJar.cookies.map({ LWPCookie(from: $0) })
    }
    
    public required init(from cookieJar: EditThisCookie) {
        self.cookies = cookieJar.map({ LWPCookie(from: $0) })
    }
    
    public required init(from cookieJar: NetscapeCookieJar) {
        self.cookies = cookieJar.cookies.map({ LWPCookie(from: $0) })
    }
    
    public required init(from cookieJar: BinaryCookieJar) {
        self.cookies = cookieJar.pages.flatMap({ $0.cookies }).map({ LWPCookie(from: $0) })
    }
    
    public required init(from cookieJar: HTTPCookieJar) {
        self.cookies = cookieJar.map({ LWPCookie(from: $0) })
    }
    
    public required init(from cookieJar: MiddleCookieJar) {
        self.cookies = cookieJar.map({ LWPCookie(from: $0) })
    }
    
    public func toEditThisCookie() -> EditThisCookie {
        return cookies.map({ EditThisCookieItem(from: $0) })
    }
    
    public func toHTTPCookieJar() -> HTTPCookieJar {
        return cookies.compactMap({ $0.toHTTPCookie() })
    }
    
    public func toMiddleCookieJar() -> MiddleCookieJar {
        return cookies.compactMap({ $0.toMiddleCookie() })
    }
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.cookies = try container.decode([LWPCookie].self, forKey: .cookies)
    }
    
    public required init(from decoder: BinaryDecoder) throws {
        var container = decoder.container(maxLength: nil)
        
        var cookies: [LWPCookie] = []
        while !container.isAtEnd {
            do {
                if LWPCookieJar.skippedPrefixes.contains(Unicode.Scalar(try container.peek(length: 1).first!)) {
                    throw LWPCookieJarError.lineShouldSkip
                }
                var cookieContainer = container.nestedContainer(maxLength: nil)
                let cookie = try cookieContainer.decode(LWPCookie.self)
                cookies.append(cookie)
            } catch LWPCookieJarError.lineShouldSkip {
                _ = try? container.decodeString(encoding: .utf8, terminator: LWPCookieJar.newlineCharacter)
                continue
            } catch LWPCookieJarError.lineSkipped {
                continue
            }
        }
        
        if cookies.count == 0 {
            throw BinaryDecodingError.dataCorrupted(.init(debugDescription: "cookie not found"))
        }
        
        self.cookies = cookies
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(cookies, forKey: .cookies)
    }
    
    public func encode(to encoder: BinaryEncoder) throws {
        var container = encoder.container()
        
        try container.encode(sequence: LWPCookieJar.optionalHeader)
        try container.encode(cookies)
    }
    
    private static let optionalHeader = Data("""
#LWP-Cookies-2.0

""".utf8)
    private static let skippedPrefixes = CharacterSet.whitespacesAndNewlines
    private static let newlineCharacter = "\n".utf8.first!
    
}

public protocol LWPCookieConvertible {
    init(from cookie: LWPCookie)
}

public class LWPCookie: Codable, BinaryCodable, CookieConvertible, HTTPCookieExportable, MiddleCookieExportable {
    
    public var key: String!
    public var val: String!
    public var path: String!
    public var domain: String!
    public var port: Int16?
    public var pathSpec: Bool = false
    public var portSpec: Bool = false
    public var domainDot: Bool = false
    public var secure: Bool = false
    public var httpOnly: Bool = false
    public var expires: Date
    public var comment: String?
    public var commentURL: String?
    public var discard: Bool = false
    public var hash: String?
    public var version: Int32
    
    enum CodingKeys: String, CodingKey, CaseIterable {
        case key, val, path, pathSpec, domain, domainDot, port, portSpec, secure, httpOnly, expires, discard, comment, commentURL, hash, version
    }
    
    public required init(from cookie: LWPCookie) {
        version = cookie.version
        key = cookie.key
        val = cookie.val
        path = cookie.path
        domain = cookie.domain
        port = cookie.port
        pathSpec = cookie.pathSpec
        portSpec = cookie.portSpec
        domainDot = cookie.domainDot
        secure = cookie.secure
        httpOnly = cookie.httpOnly
        expires = cookie.expires
        comment = cookie.comment
        commentURL = cookie.commentURL
        discard = cookie.discard
        hash = cookie.hash
    }
    
    public required init(from cookie: NetscapeCookie) {
        version = 0
        key = cookie.name
        val = cookie.value
        path = cookie.path
        domain = cookie.domain
        // port
        pathSpec = !cookie.path.isEmpty
        // portSpec
        domainDot = cookie.domain.hasPrefix(".")
        secure = cookie.isSecure
        httpOnly = cookie.isHTTPOnly
        expires = cookie.expiration
        // comment
        // commentURL
        // discard
        // hash
    }
    
    public required init(from cookie: EditThisCookieItem) {
        version = 0
        key = cookie.name
        val = cookie.value
        path = cookie.path
        domain = cookie.domain
        // port
        pathSpec = !cookie.path.isEmpty
        // portSpec
        domainDot = cookie.domain.hasPrefix(".")
        secure = cookie.secure
        httpOnly = cookie.httpOnly
        expires = cookie.expirationDate ?? Date.distantFuture
        // comment
        // commentURL
        // discard
        // hash
    }
    
    public required init(from cookie: BinaryCookie) {
        version = cookie.version
        key = cookie.name
        val = cookie.value
        path = cookie.path
        domain = cookie.url
        port = cookie.port
        pathSpec = !cookie.path.isEmpty
        portSpec = cookie.port != nil
        domainDot = cookie.url.hasPrefix(".")
        secure = cookie.flags.contains(.isSecure)
        httpOnly = cookie.flags.contains(.isHTTPOnly)
        expires = cookie.expiration
        comment = cookie.comment
        commentURL = cookie.commentURL
        // discard
        // hash
    }
    
    public required init(from cookie: HTTPCookie) {
        version = Int32(cookie.version)
        key = cookie.name
        val = cookie.value
        path = cookie.path
        domain = cookie.domain
        port = cookie.portList?.first?.int16Value
        pathSpec = !cookie.path.isEmpty
        portSpec = (cookie.portList?.first?.int16Value != nil)
        domainDot = cookie.domain.hasPrefix(".")
        secure = cookie.isSecure
        httpOnly = cookie.isHTTPOnly
        expires = cookie.expiresDate ?? Date.distantFuture
        comment = cookie.comment
        commentURL = cookie.commentURL?.absoluteString
        // discard
        // hash
    }
    
    public required init(from cookie: MiddleCookie) {
        if let version = cookie[.version] as? String {
            self.version = Int32(version) ?? 0
        } else if let version = cookie[.version] as? Int32 {
            self.version = version
        } else {
            self.version = 0
        }
        self.key = (cookie[.name] as! String)
        self.val = (cookie[.value] as! String)
        self.path = (cookie[.path] as? String) ?? "/"
        self.domain = (cookie[.domain] as! String)
        self.domainDot = (cookie[.domain] as! String).hasPrefix(".")
        if let port = cookie[.port] as? String, let firstPort = port.split(separator: ",").first {
            self.port = Int16(String(firstPort))
            self.portSpec = true
        } else if let port = cookie[.port] as? Int16 {
            self.port = port
            self.portSpec = true
        } else {
            self.portSpec = false
        }
        self.pathSpec = !((cookie[.path] as? String) ?? "/").isEmpty
        if let secure = cookie[.secure] as? Bool {
            self.secure = secure
        } else if let secure = cookie[.secure] as? String {
            self.secure = Bool(secure) ?? false
        } else {
            self.secure = false
        }
        if let httpOnly = cookie[.httpOnly] as? Bool {
            self.httpOnly = httpOnly
        } else if let httpOnly = cookie[.httpOnly] as? String {
            self.httpOnly = Bool(httpOnly) ?? false
        } else {
            self.httpOnly = false
        }
        if let expirationDate = cookie[.expires] as? Date {
            self.expires = expirationDate
        } else if let expirationDate = cookie[.expires] as? String, let expInterval = TimeInterval(expirationDate) {
            self.expires = Date(timeIntervalSince1970: expInterval)
        } else {
            self.expires = Date.distantFuture
        }
        self.comment = cookie[.comment] as? String
        if let commentURL = cookie[.commentURL] as? String {
            self.commentURL = commentURL
        } else if let commentURL = cookie[.commentURL] as? URL {
            self.commentURL = commentURL.absoluteString
        }
        if let discard = cookie[.discard] as? Bool {
            self.discard = discard
        } else if let discard = cookie[.discard] as? String {
            self.discard = Bool(discard) ?? false
        } else {
            self.discard = false
        }
        // hash
    }
    
    public func toHTTPCookie() -> HTTPCookie? {
        return HTTPCookie(properties: toMiddleCookie()!)
    }
    
    public func toMiddleCookie() -> MiddleCookie? {
        var props: [HTTPCookiePropertyKey: Any] = [
            .discard: String(describing: discard),
            .domain: domain!,
            .name: key!,
            .path: path!,
            .secure: String(describing: secure),
            .value: val!,
            .version: "0"  /* String(describing: version) */,
        ]
        if expires != Date.distantFuture {
            props[.expires] = String(describing: expires.timeIntervalSince1970)
            props[.maximumAge] = String(describing: Date().distance(to: expires))
        }
        if port != nil {
            props[.port] = String(describing: port!)
        }
        if comment != nil {
            props[.comment] = comment!
        }
        if commentURL != nil {
            props[.commentURL] = commentURL!
        }
        return props
    }
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        key = try container.decode(String.self, forKey: .key)
        val = try container.decode(String.self, forKey: .val)
        path = try container.decode(String.self, forKey: .path)
        domain = try container.decode(String.self, forKey: .domain)
        port = try container.decode(Int16.self, forKey: .port)
        pathSpec = try container.decode(Bool.self, forKey: .pathSpec)
        portSpec = try container.decode(Bool.self, forKey: .portSpec)
        domainDot = try container.decode(Bool.self, forKey: .domainDot)
        secure = try container.decode(Bool.self, forKey: .secure)
        httpOnly = try container.decode(Bool.self, forKey: .httpOnly)
        expires = try container.decode(Date.self, forKey: .expires)
        comment = try container.decode(String.self, forKey: .comment)
        commentURL = try container.decode(String.self, forKey: .commentURL)
        discard = try container.decode(Bool.self, forKey: .discard)
        hash = try container.decode(String.self, forKey: .hash)
        version = try container.decode(Int32.self, forKey: .version)
    }
    
    public required init(from decoder: BinaryDecoder) throws {
        var container = decoder.container(maxLength: nil)
        
        let prefixData = try container.peek(length: LWPCookie.httpHeaderPrefix.count)
        if prefixData == LWPCookie.httpHeaderPrefix {
            _ = try? container.decode(length: prefixData.count)
        }
        else if prefixData.prefix(2) == LWPCookie.skipPrefix {
            _ = try? container.decodeString(encoding: .utf8, terminator: LWPCookie.newlineCharacter)
            throw LWPCookieJarError.lineSkipped
        }
        else {
            throw LWPCookieJarError.lineSkipped
        }
        
        var _key: String?
        var _val: String?
        var _path: String?
        var _domain: String?
        var _port: Int16?
        var _pathSpec: Bool?
        var _portSpec: Bool?
        var _domainDot: Bool?
        var _secure: Bool?
        var _httpOnly: Bool?
        var _expires: Date?
        var _comment: String?
        var _commentURL: String?
        var _discard: Bool?
        var _hash: String?
        var _version: Int32?
        
        if let stringLeft = try? container.decodeString(encoding: .utf8, terminator: LWPCookie.newlineCharacter) {
            let cookieLines = stringLeft.split(separator: ";").map({ $0.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) })
            for cookieLine in cookieLines {
                if let firstEqualChar = cookieLine.firstIndex(of: "=") {
                    let cookieKey = String(cookieLine.prefix(upTo: firstEqualChar)).lowercased()
                    let cookieVal = String(cookieLine.suffix(from: cookieLine.index(firstEqualChar, offsetBy: 1))).trimmingCharacters(in: CharacterSet(charactersIn: "\"")).lowercased()
                    
                    if _key == nil && _val == nil {
                        _key = cookieKey
                        _val = cookieVal
                        continue
                    }
                    
                    switch cookieKey {
                        case "path":
                            _path = cookieVal
                        case "domain":
                            _domain = cookieVal
                        case "port":
                            _port = Int16(cookieVal)
                        case "expires":
                            if let cookieVal = TimeInterval(cookieVal) {
                                _expires = Date(timeIntervalSince1970: cookieVal)
                            } else if let cookieVal = ISO8601DateFormatter().date(from: cookieVal) {
                                _expires = cookieVal
                            }
                        case "comment":
                            _comment = cookieVal
                        case "commenturl":
                            _commentURL = cookieVal
                        case "hash":
                            _hash = cookieVal
                        case "version":
                            _version = Int32(cookieVal)
                        default:
                            break
                    }
                    
                } else {
                    if _val == nil {
                        _val = cookieLine
                        continue
                    }
                    
                    switch cookieLine {
                        case "path_spec":
                            _pathSpec = true
                        case "port_spec":
                            _portSpec = true
                        case "domain_dot":
                            _domainDot = true
                        case "secure":
                            _secure = true
                        case "httponly":
                            _httpOnly = true
                        case "discard":
                            _discard = true
                        default:
                            break
                    }
                }
            }
        } else {
            throw LWPCookieJarError.lineMalformed
        }
        
        guard _key != nil, _val != nil, _domain != nil else { throw LWPCookieJarError.lineMalformed }
        
        self.key = _key!
        self.val = _val!
        self.path = _path ?? "/"
        self.domain = _domain!
        self.port = _port
        self.pathSpec = _pathSpec ?? !(_path ?? "/").isEmpty
        self.portSpec = _portSpec ?? (_port != nil)
        self.domainDot = _domainDot ?? (_domain!.hasPrefix("."))
        self.secure = _secure ?? false
        self.httpOnly = _httpOnly ?? false
        self.expires = _expires ?? Date.distantFuture
        self.comment = _comment
        self.commentURL = _commentURL
        self.discard = _discard ?? false
        self.hash = _hash
        self.version = _version ?? 0
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(key, forKey: .key)
        try container.encode(val, forKey: .val)
        try container.encode(path, forKey: .path)
        try container.encode(domain, forKey: .domain)
        try container.encode(port, forKey: .port)
        try container.encode(pathSpec, forKey: .pathSpec)
        try container.encode(portSpec, forKey: .portSpec)
        try container.encode(domainDot, forKey: .domainDot)
        try container.encode(secure, forKey: .secure)
        try container.encode(httpOnly, forKey: .httpOnly)
        try container.encode(expires, forKey: .expires)
        try container.encode(comment, forKey: .comment)
        try container.encode(commentURL, forKey: .commentURL)
        try container.encode(discard, forKey: .discard)
        try container.encode(hash, forKey: .hash)
        try container.encode(version, forKey: .version)
    }
    
    public func encode(to encoder: BinaryEncoder) throws {
        var container = encoder.container()
        
        try container.encode(sequence: LWPCookie.httpHeaderPrefix)
        
        var hasKey: Bool = false
        for keyCase in CodingKeys.allCases {
            switch keyCase {
                case .key:
                    hasKey = !key.isEmpty
                case .val:
                    if hasKey {
                        try container.encode("\(key!)=", encoding: .utf8, terminator: nil)
                    }
                    try container.encode(val, encoding: .utf8, terminator: nil)
                case .path:
                    try container.encode("; ", encoding: .utf8, terminator: nil)
                    try container.encode("path=", encoding: .utf8, terminator: nil)
                    try container.encode("\"\(path!)\"", encoding: .utf8, terminator: nil)
                case .domain:
                    try container.encode("; ", encoding: .utf8, terminator: nil)
                    try container.encode("domain=", encoding: .utf8, terminator: nil)
                    try container.encode(domain, encoding: .utf8, terminator: nil)
                case .port:
                    if port != nil {
                        try container.encode("; ", encoding: .utf8, terminator: nil)
                        try container.encode("port=", encoding: .utf8, terminator: nil)
                        try container.encode(String(describing: port!), encoding: .utf8, terminator: nil)
                    }
                case .pathSpec:
                    if pathSpec {
                        try container.encode("; ", encoding: .utf8, terminator: nil)
                        try container.encode("path_spec", encoding: .utf8, terminator: nil)
                    }
                case .portSpec:
                    if portSpec {
                        try container.encode("; ", encoding: .utf8, terminator: nil)
                        try container.encode("port_spec", encoding: .utf8, terminator: nil)
                    }
                case .domainDot:
                    if domainDot {
                        try container.encode("; ", encoding: .utf8, terminator: nil)
                        try container.encode("domain_dot", encoding: .utf8, terminator: nil)
                    }
                case .secure:
                    if secure {
                        try container.encode("; ", encoding: .utf8, terminator: nil)
                        try container.encode("secure", encoding: .utf8, terminator: nil)
                    }
                case .httpOnly:
                    if httpOnly {
                        try container.encode("; ", encoding: .utf8, terminator: nil)
                        try container.encode("httponly", encoding: .utf8, terminator: nil)
                    }
                case .expires:
                    if expires != Date.distantFuture {
                        try container.encode("; ", encoding: .utf8, terminator: nil)
                        try container.encode("expires=", encoding: .utf8, terminator: nil)
                        try container.encode("\"\(ISO8601DateFormatter().string(from: expires))\"", encoding: .utf8, terminator: nil)
                    }
                case .comment:
                    if comment != nil {
                        try container.encode("; ", encoding: .utf8, terminator: nil)
                        try container.encode("comment=", encoding: .utf8, terminator: nil)
                        try container.encode(comment!, encoding: .utf8, terminator: nil)
                    }
                case .commentURL:
                    if commentURL != nil {
                        try container.encode("; ", encoding: .utf8, terminator: nil)
                        try container.encode("commenturl=", encoding: .utf8, terminator: nil)
                        try container.encode(commentURL!, encoding: .utf8, terminator: nil)
                    }
                case .discard:
                    if discard {
                        try container.encode("; ", encoding: .utf8, terminator: nil)
                        try container.encode("discard", encoding: .utf8, terminator: nil)
                    }
                case .version:
                    try container.encode("; ", encoding: .utf8, terminator: nil)
                    try container.encode("version=", encoding: .utf8, terminator: nil)
                    try container.encode(String(describing: version), encoding: .utf8, terminator: nil)
                case .hash:
                    if hash != nil {
                        try container.encode("; ", encoding: .utf8, terminator: nil)
                        try container.encode("hash=", encoding: .utf8, terminator: nil)
                        try container.encode(hash!, encoding: .utf8, terminator: nil)
                    }
            }
        }
        
        try container.encode("", encoding: .utf8, terminator: LWPCookie.newlineCharacter)
    }
    
    private static let headerName = "Set-Cookie3"
    private static let newlineCharacter = "\n".utf8.first!
    private static let skipPrefix = Data("//".utf8)
    private static let httpHeaderPrefix = Data("\(LWPCookie.headerName): ".utf8)
    
}
