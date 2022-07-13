import Foundation

public enum ChromeCookiesSameSitePolicy: String {
    case unspecified
    case no_restriction
    case lax
    case strict
}

public enum EditThisCookieError: Error {
    case inconsistentStateOfHostOnly
    case inconsistentStateOfSession
    case inconsistentStateOfSize
    case invalidValueOfSameSite
}

public protocol EditThisCookieConvertible {
    init(from cookieJar: EditThisCookie)
}

public protocol EditThisCookieExportable {
    func toEditThisCookie() -> EditThisCookie
}

public typealias EditThisCookie = [EditThisCookieItem]

extension EditThisCookie: MiddleCookieJarExportable {
    
    public func toMiddleCookieJar() -> MiddleCookieJar {
        return compactMap({ $0.toMiddleCookie() })
    }
    
}

public protocol EditThisCookieItemConvertible {
    init(from cookie: EditThisCookieItem)
}

public class EditThisCookieItem: Codable, CookieConvertible, HTTPCookieExportable, MiddleCookieExportable {
    
    public var domain: String
    public var sourcePort: Int16?     // 443
    public var sourceScheme: String?  // Secure
    public var expirationDate: Date?
    public var expires: Date? {      // alias for expirationDate
        return expirationDate
    }
    public var hostOnly: Bool {
        return !domain.hasPrefix(".")
    }
    public var httpOnly: Bool = false
    public var name: String
    public var path: String
    public var priority: String?      // Medium
    public var sameSite: ChromeCookiesSameSitePolicy = .unspecified
    public var sameParty: Bool = false
    public var secure: Bool = false
    public var session: Bool = false
    public var storeId: String
    public var value: String
    public var size: Int {
        return name.count + value.count
    }
    public var id: Int
    public static var autoIncrement: Int = 1
    
    enum CodingKeys: String, CodingKey {
        case domain, sourcePort, sourceScheme, expirationDate, expires, hostOnly, httpOnly, name, path, priority, sameSite, sameParty, secure, session, storeId, value, size, id
    }
    
    public required init(from cookie: EditThisCookieItem) {
        domain = cookie.domain
        sourcePort = cookie.sourcePort
        sourceScheme = cookie.sourceScheme
        expirationDate = cookie.expirationDate
        httpOnly = cookie.httpOnly
        name = cookie.name
        path = cookie.path
        priority = cookie.priority
        sameSite = cookie.sameSite
        sameParty = cookie.sameParty
        secure = cookie.secure
        session = cookie.session
        storeId = cookie.storeId
        value = cookie.value
        id = cookie.id
    }
    
    public required init(from cookie: BinaryCookie) {
        domain = cookie.url
        sourcePort = cookie.port
        sourceScheme = cookie.flags.contains(.isSecure) ? "Secure" : nil
        expirationDate = cookie.expiration
        httpOnly = cookie.flags.contains(.isHTTPOnly)
        name = cookie.name
        path = cookie.path
        priority = "Medium"
        sameSite = .unspecified
        sameParty = false
        secure = cookie.flags.contains(.isSecure)
        session = false
        storeId = "0"
        value = cookie.value
        id = EditThisCookieItem.autoIncrement
        EditThisCookieItem.autoIncrement += 1
    }
    
    public required init(from cookie: NetscapeCookie) {
        domain = cookie.domain
        // sourcePort
        sourceScheme = cookie.isSecure ? "Secure" : nil
        expirationDate = cookie.expiration
        httpOnly = cookie.isHTTPOnly
        name = cookie.name
        path = cookie.path
        priority = "Medium"
        sameSite = .unspecified
        sameParty = false
        secure = cookie.isSecure
        session = false
        storeId = "0"
        value = cookie.value
        id = EditThisCookieItem.autoIncrement
        EditThisCookieItem.autoIncrement += 1
    }
    
    public required init(from cookie: LWPCookie) {
        domain = cookie.domain
        sourcePort = cookie.port
        sourceScheme = cookie.secure ? "Secure" : nil
        expirationDate = cookie.expires
        httpOnly = false
        name = cookie.key
        path = cookie.path ?? "/"
        priority = "Medium"
        sameSite = .unspecified
        sameParty = false
        secure = cookie.secure
        session = false
        storeId = "0"
        value = cookie.val
        id = EditThisCookieItem.autoIncrement
        EditThisCookieItem.autoIncrement += 1
    }
    
    public required init(from cookie: HTTPCookie) {
        domain = cookie.domain
        sourcePort = cookie.portList?.first?.int16Value
        sourceScheme = cookie.isSecure ? "Secure" : nil
        expirationDate = cookie.expiresDate
        httpOnly = cookie.isHTTPOnly
        name = cookie.name
        path = cookie.path
        priority = "Medium"
        if #available(macOS 10.15, *) {
            switch cookie.sameSitePolicy {
                case HTTPCookieStringPolicy.sameSiteLax:
                    sameSite = .lax
                case HTTPCookieStringPolicy.sameSiteStrict:
                    sameSite = .strict
                default:
                    sameSite = .unspecified
            }
        } else {
            // Fallback on earlier versions
            sameSite = .unspecified
        }
        sameParty = false
        secure = cookie.isSecure
        session = cookie.isSessionOnly
        storeId = "0"
        value = cookie.value
        id = EditThisCookieItem.autoIncrement
        EditThisCookieItem.autoIncrement += 1
    }
    
    public required init(from cookie: MiddleCookie) {
        self.domain = cookie[.domain] as! String
        if let port = cookie[.port] as? String, let firstPort = port.split(separator: ",").first {
            self.sourcePort = Int16(String(firstPort))
        } else if let port = cookie[.port] as? Int16 {
            self.sourcePort = port
        }
        if let expirationDate = cookie[.expires] as? Date {
            self.expirationDate = expirationDate
        } else if let expirationDate = cookie[.expires] as? String, let expInterval = TimeInterval(expirationDate) {
            self.expirationDate = Date(timeIntervalSince1970: expInterval)
        } else {
            self.expirationDate = Date.distantFuture
        }
        if let httpOnly = cookie[.httpOnly] as? Bool {
            self.httpOnly = httpOnly
        } else if let httpOnly = cookie[.httpOnly] as? String {
            self.httpOnly = Bool(httpOnly) ?? false
        } else {
            self.httpOnly = false
        }
        self.name = cookie[.name] as! String
        self.path = (cookie[.path] as? String) ?? "/"
        self.priority = "Medium"
        if let sameSite = cookie[.sameSitePolicy] as? HTTPCookieStringPolicy {
            switch sameSite {
                case HTTPCookieStringPolicy.sameSiteLax:
                    self.sameSite = .lax
                case HTTPCookieStringPolicy.sameSiteStrict:
                    self.sameSite = .strict
                default:
                    self.sameSite = .unspecified
            }
        } else {
            self.sameSite = .unspecified
        }
        self.sameParty = false
        if let secure = cookie[.secure] as? Bool {
            self.secure = secure
            self.sourceScheme = secure ? "Secure" : nil
        } else if let secure = cookie[.secure] as? String {
            self.secure = Bool(secure) ?? false
            self.sourceScheme = (Bool(secure) ?? false) ? "Secure" : nil
        } else {
            self.secure = false
            self.sourceScheme = nil
        }
        if let session = cookie[.sessionOnly] as? Bool {
            self.session = session
        } else if let session = cookie[.sessionOnly] as? String {
            self.session = Bool(session) ?? false
        } else {
            self.session = false
        }
        storeId = "0"
        value = cookie[.value] as! String
        id = EditThisCookieItem.autoIncrement
        EditThisCookieItem.autoIncrement += 1
    }
    
    public func toHTTPCookie() -> HTTPCookie? {
        return HTTPCookie(properties: toMiddleCookie()!)
    }
    
    public func toMiddleCookie() -> MiddleCookie? {
        var props: [HTTPCookiePropertyKey: Any] = [
            .domain: domain,
            .name: name,
            .path: path,
            .secure: String(describing: secure),
            .value: value,
            .version: "0",
            .sessionOnly: String(describing: session),
        ]
        if sourcePort != nil {
            props[.port] = String(describing: sourcePort!)
        }
        if expirationDate != nil {
            props[.expires] = expirationDate!
        }
        switch sameSite {
            case .lax:
                props[.sameSitePolicy] = HTTPCookieStringPolicy.sameSiteLax.rawValue
            case .strict:
                props[.sameSitePolicy] = HTTPCookieStringPolicy.sameSiteStrict.rawValue
            default:
                break
        }
        return props
    }
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let domain = try container.decode(String.self, forKey: .domain)
        var expirationDate: Date?
        if let expiration = try container.decodeIfPresent(TimeInterval.self, forKey: .expirationDate) {
            expirationDate = Date(timeIntervalSince1970: expiration)
        }
        if let hostOnly = try container.decodeIfPresent(Bool.self, forKey: .hostOnly) {
            guard hostOnly || domain.hasPrefix(".") else {
                throw EditThisCookieError.inconsistentStateOfHostOnly
            }
        }
        self.domain = domain
        self.sourcePort = try container.decodeIfPresent(Int16.self, forKey: .sourcePort)
        self.sourceScheme = try container.decodeIfPresent(String.self, forKey: .sourceScheme)
        self.httpOnly = try container.decode(Bool.self, forKey: .httpOnly)
        let name = try container.decode(String.self, forKey: .name)
        self.name = name
        self.path = try container.decode(String.self, forKey: .path)
        self.priority = try container.decodeIfPresent(String.self, forKey: .priority)
        if let sameSite = try container.decodeIfPresent(String.self, forKey: .sameSite)?.lowercased() {
            if sameSite == "none" {
                self.sameSite = .no_restriction
            } else {
                guard let sameSitePolicy = ChromeCookiesSameSitePolicy(rawValue: sameSite) else {
                    throw EditThisCookieError.invalidValueOfSameSite
                }
                self.sameSite = sameSitePolicy
            }
        } else {
            self.sameSite = .unspecified
        }
        self.sameParty = try container.decodeIfPresent(Bool.self, forKey: .sameParty) ?? false
        self.secure = try container.decode(Bool.self, forKey: .secure)
        if let session = try container.decodeIfPresent(Bool.self, forKey: .session) {
            guard session || expirationDate != nil else {
                throw EditThisCookieError.inconsistentStateOfSession
            }
            self.session = session
        } else {
            self.session = false
        }
        self.expirationDate = expirationDate
        self.storeId = try container.decodeIfPresent(String.self, forKey: .storeId) ?? "0"
        let value = try container.decode(String.self, forKey: .value)
        if let size = try container.decodeIfPresent(Int.self, forKey: .size) {
            guard size == name.count + value.count else {
                throw EditThisCookieError.inconsistentStateOfSize
            }
        }
        self.value = value
        self.id = try container.decodeIfPresent(Int.self, forKey: .id) ?? EditThisCookieItem.autoIncrement
        EditThisCookieItem.autoIncrement += 1
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(domain, forKey: .domain)
        try container.encode(sourcePort, forKey: .sourcePort)
        try container.encode(sourceScheme, forKey: .sourceScheme)
        if let expirationDate = expirationDate {
            try container.encode(expirationDate.timeIntervalSince1970, forKey: .expirationDate)
        }
        try container.encode(hostOnly, forKey: .hostOnly)
        try container.encode(httpOnly, forKey: .httpOnly)
        try container.encode(name, forKey: .name)
        try container.encode(path, forKey: .path)
        try container.encode(priority, forKey: .priority)
        try container.encode(sameSite.rawValue, forKey: .sameSite)
        try container.encode(sameParty, forKey: .sameParty)
        try container.encode(secure, forKey: .secure)
        try container.encode(session, forKey: .session)
        try container.encode(storeId, forKey: .storeId)
        try container.encode(value, forKey: .value)
        try container.encode(size, forKey: .size)
        try container.encode(id, forKey: .id)
    }
}
