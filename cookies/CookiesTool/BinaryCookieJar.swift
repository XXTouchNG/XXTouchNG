import Foundation

extension UnsafeRawBufferPointer {
    func loadUnaligned<T>(fromByteOffset offset: Int, as: T.Type) -> T {
        // Allocate correctly aligned memory and copy bytes there
        let alignedPointer = UnsafeMutableRawPointer.allocate(byteCount: MemoryLayout<T>.stride, alignment: MemoryLayout<T>.alignment)
        defer {
            alignedPointer.deallocate()
        }
        alignedPointer.copyMemory(from: baseAddress!.advanced(by: offset), byteCount: MemoryLayout<T>.size)
        return alignedPointer.load(as: T.self)
    }
}

public protocol BinaryCookieJarConvertible {
    init(from cookieJar: BinaryCookieJar)
}

public class BinaryCookieJar: Codable, BinaryCodable, CookieJarConvertible, HTTPCookieJarExportable, EditThisCookieExportable, MiddleCookieJarExportable {
    public var pages: [BinaryPage]
    public var metadata: Any
    
    enum CodingKeys: String, CodingKey {
        case pages, metadata
    }
    
    public required init(from cookieJar: BinaryCookieJar) {
        self.pages = cookieJar.pages.map({ BinaryPage(with: $0) })
        metadata = Data()
    }
    
    public required init(from cookieJar: NetscapeCookieJar) {
        var pages: [BinaryPage] = []
        Dictionary(grouping: cookieJar.cookies, by: { $0.domain })
            .forEach({ pages.append(BinaryPage(with: $0.value.map({ BinaryCookie(from: $0) }))) })
        self.pages = pages
        metadata = Data()
    }
    
    public required init(from cookieJar: EditThisCookie) {
        var pages: [BinaryPage] = []
        Dictionary(grouping: cookieJar, by: { $0.domain })
            .forEach({ pages.append(BinaryPage(with: $0.value.map({ BinaryCookie(from: $0) }))) })
        self.pages = pages
        metadata = Data()
    }
    
    public required init(from cookieJar: HTTPCookieJar) {
        var pages: [BinaryPage] = []
        Dictionary(grouping: cookieJar, by: { $0.domain })
            .forEach({ pages.append(BinaryPage(with: $0.value.map({ BinaryCookie(from: $0) }))) })
        self.pages = pages
        metadata = Data()
    }
    
    public required init(from cookieJar: LWPCookieJar) {
        var pages: [BinaryPage] = []
        Dictionary(grouping: cookieJar.cookies, by: { $0.domain })
            .forEach({ pages.append(BinaryPage(with: $0.value.map({ BinaryCookie(from: $0) }))) })
        self.pages = pages
        metadata = Data()
    }
    
    public required init(from cookieJar: MiddleCookieJar) {
        var pages: [BinaryPage] = []
        Dictionary(grouping: cookieJar, by: { $0[.domain] as! String })
            .forEach({ pages.append(BinaryPage(with: $0.value.map({ BinaryCookie(from: $0) }))) })
        self.pages = pages
        metadata = Data()
    }
    
    public func toHTTPCookieJar() -> HTTPCookieJar {
        return pages.flatMap({ $0.cookies }).compactMap({ $0.toHTTPCookie() })
    }
    
    public func toEditThisCookie() -> EditThisCookie {
        return pages.flatMap({ $0.cookies }).map({ EditThisCookieItem(from: $0) })
    }
    
    public func toMiddleCookieJar() -> MiddleCookieJar {
        return pages.flatMap({ $0.cookies }).compactMap({ $0.toMiddleCookie() })
    }
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        pages = try container.decode([BinaryPage].self, forKey: .pages)
        
        let plistData =  try container.decode(Data.self, forKey: .metadata)
        metadata = try PropertyListSerialization.propertyList(from: plistData, options: [], format: nil)
    }
    
    public required init(from decoder: BinaryDecoder) throws {
        var container = decoder.container(maxLength: nil)
        
        let magic = try container.decode(length: 4)
        guard magic == BinaryCookieJar.magic else { throw BinaryDecodingError.dataCorrupted(.init(debugDescription: "missing magic value")) }
        
        let pageCount = try container.decode(Int32.self).bigEndian
        var pageSizes: [Int32] = []
        for _ in 0..<pageCount {
            pageSizes.append(try container.decode(Int32.self).bigEndian)
        }
        
        var pages: [BinaryPage] = []
        for pageSize in pageSizes {
            var pageContainer = container.nestedContainer(maxLength: Int(pageSize))
            let page = try pageContainer.decode(BinaryPage.self)
            pages.append(page)
        }
        self.pages = pages
        
        // Checksum
        let _ = try container.decode(length: 4)
        
        let footer = try container.decode(Int64.self).bigEndian
        guard footer == BinaryCookieJar.footer else { throw BinaryDecodingError.dataCorrupted(.init(debugDescription: "invalid cookies footer")) }
        
        let plistData = try container.decodeRemainder()
        metadata = try PropertyListSerialization.propertyList(from: plistData, options: [], format: nil)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(pages, forKey: .pages)
        
        let plistData = try PropertyListSerialization.data(fromPropertyList: metadata, format: .binary, options: 0)
        try container.encode(plistData, forKey: .metadata)
    }
    
    public func encode(to encoder: BinaryEncoder) throws {
        var container = encoder.container()
        
        try container.encode(sequence: BinaryCookieJar.magic)
        try container.encode(Int32(pages.count).bigEndian)
        for page in pages {
            try container.encode(Int32(page.totalByteCount).bigEndian)
        }
        
        try container.encode(pages)
        
        let checksum: Int32 = try pages.reduce(0) { try $0 + $1.checksum() }
        try container.encode(checksum.bigEndian)
        
        try container.encode(BinaryCookieJar.footer.bigEndian)
        
        let plistData = try PropertyListSerialization.data(fromPropertyList: metadata, format: .binary, options: 0)
        try container.encode(sequence: plistData)
    }
    
    private static let magic = Data("cook".utf8)
    private static let footer: Int64 = 0x071720050000004b
}

public class BinaryPage: BinaryCodable, Codable {
    public var cookies: [BinaryCookie]
    
    enum CodingKeys: String, CodingKey {
        case cookies
    }
    
    init(with page: BinaryPage) {
        self.cookies = page.cookies.map({ BinaryCookie(from: $0) })
    }
    
    init(with cookies: [BinaryCookie]) {
        self.cookies = cookies
    }
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        cookies = try container.decode([BinaryCookie].self, forKey: .cookies)
    }
    
    public required init(from decoder: BinaryDecoder) throws {
        var container = decoder.container(maxLength: nil)
        
        let header = try container.decode(Int32.self).bigEndian
        guard header == BinaryPage.header else { throw BinaryDecodingError.dataCorrupted(.init(debugDescription: "invalid page header")) }
        
        let cookieCount = try container.decode(Int32.self)
        // BinaryCodable's container can't seek to an offset, so instead of 
        // using these offsets we trust that the cookies aren't padded and 
        // decode them one after another.
        var cookieOffsets: [Int32] = []
        for _ in 0..<cookieCount {
            cookieOffsets.append(try container.decode(Int32.self))
        }
        
        let footer = try container.decode(Int32.self)
        guard footer == BinaryPage.footer else { throw BinaryDecodingError.dataCorrupted(.init(debugDescription: "invalid page footer")) }
        
        var cookies: [BinaryCookie] = []
        for _ in 0..<cookieCount {
            let cookieSize = try container.peek(length: 4).withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 0, as: Int32.self) }
            var cookieContainer = container.nestedContainer(maxLength: Int(cookieSize))
            let cookie = try cookieContainer.decode(BinaryCookie.self)
            cookies.append(cookie)
        }
        self.cookies = cookies
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(cookies, forKey: .cookies)
    }
    
    public func encode(to encoder: BinaryEncoder) throws {
        var container = encoder.container()
        
        try container.encode(BinaryPage.header.bigEndian)
        try container.encode(Int32(cookies.count))
        
        for index in 0..<cookies.count {
            let offset = cookiesByteOffset + cookies[0..<index].reduce(0) { $0 + $1.totalByteCount }
            try container.encode(offset)
        }
        
        try container.encode(BinaryPage.footer)
        try container.encode(cookies)
    }
    
    private var cookiesByteOffset: Int32 {
        return Int32(12 + 4 * cookies.count)
    }
    
    var totalByteCount: Int32 {
        return cookiesByteOffset + cookies.reduce(0) { $0 + $1.totalByteCount }
    }
    
    func checksum() throws -> Int32 {
        let data = try BinaryDataEncoder().encode(self)
        var checksum: Int32 = 0
        for index in stride(from: 0, to: data.count, by: 4) {
            checksum += Int32(data[index])
        }
        return checksum
    }
    
    private static let header: Int32 = 0x00000100
    private static let footer: Int32 = 0x00000000
}

extension String {
    public var byteCount: Int {
        return self.utf8.count + 1
    }
}

public protocol BinaryCookieConvertible {
    init(from cookie: BinaryCookie)
}

public class BinaryCookie: Codable, BinaryCodable, CookieConvertible, HTTPCookieExportable, MiddleCookieExportable {
    
    public var version: Int32
    public var url: String!
    public var port: Int16?
    public var name: String!
    public var path: String!
    public var value: String!
    public var comment: String?
    public var commentURL: String?
    public let flags: Flags
    public let creation: Date
    public let expiration: Date
    
    enum CodingKeys: String, CodingKey {
        case version, url, port, name, path, value, comment, commentURL, flags, creation, expiration
    }
    
    public struct Flags: OptionSet, BinaryCodable, Codable {
        public let rawValue: Int32
        
        public init(rawValue: Int32) {
            self.rawValue = rawValue
        }
        
        static let isSecure   = Flags(rawValue: 1)
        static let isHTTPOnly = Flags(rawValue: 1 << 2)
        static let unknown1   = Flags(rawValue: 1 << 3)
        static let unknown2   = Flags(rawValue: 1 << 4)
    }
    
    public required init(from cookie: BinaryCookie) {
        version = cookie.version
        url = cookie.url
        port = cookie.port
        name = cookie.name
        path = cookie.path
        value = cookie.value
        comment = cookie.comment
        commentURL = cookie.commentURL
        flags = cookie.flags
        creation = cookie.creation
        expiration = cookie.expiration
    }
    
    public required init(from cookie: NetscapeCookie) {
        version = 0
        url = cookie.domain
        // port
        name = cookie.name
        path = cookie.path
        value = cookie.value
        // comment
        // commentURL
        var flags: Flags = []
        if cookie.isHTTPOnly {
            flags.insert(.isHTTPOnly)
        }
        if cookie.isSecure {
            flags.insert(.isSecure)
        }
        self.flags = flags
        creation = Date()
        expiration = cookie.expiration
    }
    
    public required init(from cookie: EditThisCookieItem) {
        version = 0
        url = cookie.domain
        // port
        name = cookie.name
        path = cookie.path
        value = cookie.value
        // comment
        // commentURL
        var flags: Flags = []
        if cookie.httpOnly {
            flags.insert(.isHTTPOnly)
        }
        if cookie.secure {
            flags.insert(.isSecure)
        }
        self.flags = flags
        creation = Date()
        expiration = cookie.expirationDate ?? Date.distantFuture
    }
    
    public required init(from cookie: LWPCookie) {
        version = cookie.version
        url = cookie.domain
        port = cookie.port
        name = cookie.key
        path = cookie.path
        value = cookie.val
        // comment
        // commentURL
        var flags: Flags = []
        if cookie.secure {
            flags.insert(.isSecure)
        }
        self.flags = flags
        creation = Date()
        expiration = cookie.expires
    }
    
    public required init(from cookie: HTTPCookie) {
        version = Int32(cookie.version)
        url = cookie.domain
        port = cookie.portList?.first?.int16Value
        name = cookie.name
        path = cookie.path
        value = cookie.value
        comment = cookie.comment
        commentURL = cookie.commentURL?.absoluteString
        var flags: Flags = []
        if cookie.isSecure {
            flags.insert(.isSecure)
        }
        if cookie.isHTTPOnly {
            flags.insert(.isHTTPOnly)
        }
        self.flags = flags
        creation = Date()
        expiration = cookie.expiresDate ?? Date.distantFuture
    }
    
    public required init(from cookie: MiddleCookie) {
        if let version = cookie[.version] as? String {
            self.version = Int32(version) ?? 0
        } else if let version = cookie[.version] as? Int32 {
            self.version = version
        } else {
            self.version = 0
        }
        self.url = (cookie[.domain] as! String)
        if let port = cookie[.port] as? String, let firstPort = port.split(separator: ",").first {
            self.port = Int16(String(firstPort))
        } else if let port = cookie[.port] as? Int16 {
            self.port = port
        }
        self.name = (cookie[.name] as! String)
        self.path = (cookie[.path] as? String) ?? "/"
        self.value = (cookie[.value] as! String)
        self.comment = cookie[.comment] as? String
        if let commentURL = cookie[.commentURL] as? String {
            self.commentURL = commentURL
        } else if let commentURL = cookie[.commentURL] as? URL {
            self.commentURL = commentURL.absoluteString
        }
        var flags: Flags = []
        var isSecure: Bool
        if let secure = cookie[.secure] as? Bool {
            isSecure = secure
        } else if let secure = cookie[.secure] as? String {
            isSecure = Bool(secure) ?? false
        } else {
            isSecure = false
        }
        if isSecure {
            flags.insert(.isSecure)
        }
        var isHTTPOnly: Bool
        if let httpOnly = cookie[.httpOnly] as? Bool {
            isHTTPOnly = httpOnly
        } else if let httpOnly = cookie[.httpOnly] as? String {
            isHTTPOnly = Bool(httpOnly) ?? false
        } else {
            isHTTPOnly = false
        }
        if isHTTPOnly {
            flags.insert(.isHTTPOnly)
        }
        self.flags = flags
        self.creation = Date()
        if let expirationDate = cookie[.expires] as? Date {
            self.expiration = expirationDate
        } else if let expirationDate = cookie[.expires] as? String, let expInterval = TimeInterval(expirationDate) {
            self.expiration = Date(timeIntervalSince1970: expInterval)
        } else {
            self.expiration = Date.distantFuture
        }
    }
    
    public func toHTTPCookie() -> HTTPCookie? {
        return HTTPCookie(properties: toMiddleCookie()!)
    }
    
    public func toMiddleCookie() -> MiddleCookie? {
        var props: [HTTPCookiePropertyKey: Any] = [
            .domain: url!,
            .expires: expiration,
            .name: name!,
            .path: path!,
            .secure: String(describing: flags.contains(.isSecure)),
            .value: value!,
            .version: "0" /* String(describing: version) */,
        ]
        if comment != nil {
            props[.comment] = comment!
        }
        if commentURL != nil {
            props[.commentURL] = commentURL!
        }
        if port != nil {
            props[.port] = String(describing: port)
        }
        return props
    }
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        version = try container.decode(Int32.self, forKey: .version)
        flags = try container.decode(Flags.self, forKey: .flags)
        expiration = Date(timeIntervalSinceReferenceDate: try container.decode(TimeInterval.self, forKey: .expiration))
        creation = Date(timeIntervalSinceReferenceDate: try container.decode(TimeInterval.self, forKey: .creation))
        port = try container.decodeIfPresent(Int16.self, forKey: .port)
        url = try container.decode(String.self, forKey: .url)
        name = try container.decode(String.self, forKey: .name)
        path = try container.decode(String.self, forKey: .path)
        value = try container.decode(String.self, forKey: .value)
        comment = try container.decodeIfPresent(String.self, forKey: .comment)
        commentURL = try container.decodeIfPresent(String.self, forKey: .commentURL)
    }
    
    public required init(from decoder: BinaryDecoder) throws {
        var container = decoder.container(maxLength: nil)
        
        let size = try container.decode(Int32.self)
        version = try container.decode(Int32.self)
        flags = try container.decode(Flags.self)
        let hasPort = try container.decode(Int32.self)
        
        let urlOffset = try container.decode(Int32.self)
        let nameOffset = try container.decode(Int32.self)
        let pathOffset = try container.decode(Int32.self)
        let valueOffset = try container.decode(Int32.self)
        let commentOffset = try container.decode(Int32.self)
        let commentURLOffset = try container.decode(Int32.self)
        
        let expiration = try container.decode(TimeInterval.self)
        self.expiration = Date(timeIntervalSinceReferenceDate: expiration)
        let creation = try container.decode(TimeInterval.self)
        self.creation = Date(timeIntervalSinceReferenceDate: creation)
        
        if hasPort > 0 {
            port = try container.decode(Int16.self)
        }
        
        // url, name, path, and value aren't in a known order, and because
        // BinaryCodable can't seek to an offset, do a little math to figure out
        // the order and trust that they aren't padded.
        let offsets: [Int32] = [urlOffset, nameOffset, pathOffset, valueOffset, commentOffset, commentURLOffset].sorted()
        for (offset, next) in zip(offsets, offsets.dropFirst() + [size]) {
            let length = Int(next - offset)
            var stringContainer = container.nestedContainer(maxLength: length)
            
            if offset == urlOffset {
                url = try stringContainer.decodeString(encoding: .utf8, terminator: 0)
            }
            else if offset == nameOffset {
                name = try stringContainer.decodeString(encoding: .utf8, terminator: 0)
            }
            else if offset == pathOffset {
                path = try stringContainer.decodeString(encoding: .utf8, terminator: 0)
            }
            else if offset == valueOffset {
                value = try stringContainer.decodeString(encoding: .utf8, terminator: 0)
            }
            else if offset == commentOffset, offset > 0 {
                comment = try stringContainer.decodeString(encoding: .utf8, terminator: 0)
            }
            else if offset == commentURLOffset, offset > 0 {
                commentURL = try stringContainer.decodeString(encoding: .utf8, terminator: 0)
            }
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(version, forKey: .version)
        try container.encode(flags, forKey: .flags)
        try container.encode(expiration.timeIntervalSinceReferenceDate, forKey: .expiration)
        try container.encode(creation.timeIntervalSinceReferenceDate, forKey: .creation)
        
        if let port = port {
            try container.encode(port, forKey: .port)
        } else {
            try container.encodeNil(forKey: .port)
        }
        if let comment = comment {
            try container.encode(comment, forKey: .comment)
        } else {
            try container.encodeNil(forKey: .comment)
        }
        if let commentURL = commentURL {
            try container.encode(commentURL, forKey: .commentURL)
        } else {
            try container.encodeNil(forKey: .commentURL)
        }
        
        try container.encode(url, forKey: .url)
        try container.encode(name, forKey: .name)
        try container.encode(path, forKey: .path)
        try container.encode(value, forKey: .value)
    }
    
    public func encode(to encoder: BinaryEncoder) throws {
        var container = encoder.container()
        
        try container.encode(totalByteCount)
        try container.encode(version)
        try container.encode(flags)
        if port != nil {
            try container.encode(Int32(1))
        }
        else {
            try container.encode(Int32(0))
        }
        
        let commentOffset = fixedByteSize + (port != nil ? 2 : 0)
        let commentURLOffset = commentOffset + Int32(comment?.byteCount ?? 0)
        let urlOffset = commentURLOffset + Int32(commentURL?.byteCount ?? 0)
        try container.encode(urlOffset)
        let nameOffset = urlOffset + Int32(url.byteCount)
        try container.encode(nameOffset)
        let pathOffset = nameOffset + Int32(name.byteCount)
        try container.encode(pathOffset)
        let valueOffset = pathOffset + Int32(path.byteCount)
        try container.encode(valueOffset)
        if comment != nil {
            try container.encode(commentOffset)
        }
        else {
            try container.encode(Int32(0))
        }
        if commentURL != nil {
            try container.encode(commentURLOffset)
        }
        else {
            try container.encode(Int32(0))
        }
        
        try container.encode(expiration.timeIntervalSinceReferenceDate)
        try container.encode(creation.timeIntervalSinceReferenceDate)
        
        if let port = port {
            try container.encode(port)
        }
        if let comment = comment {
            try container.encode(comment, encoding: .utf8, terminator: 0)
        }
        if let commentURL = commentURL {
            try container.encode(commentURL, encoding: .utf8, terminator: 0)
        }
        try container.encode(url, encoding: .utf8, terminator: 0)
        try container.encode(name, encoding: .utf8, terminator: 0)
        try container.encode(path, encoding: .utf8, terminator: 0)
        try container.encode(value, encoding: .utf8, terminator: 0)
    }
    
    private let fixedByteSize: Int32 = 56
    
    var totalByteCount: Int32 {
        return fixedByteSize + 
            (port != nil ? 2 : 0) +
            Int32(comment?.byteCount ?? 0) +
            Int32(commentURL?.byteCount ?? 0) +
            Int32(url.byteCount) +
            Int32(name.byteCount) +
            Int32(path.byteCount) +
            Int32(value.byteCount)
    }
}
