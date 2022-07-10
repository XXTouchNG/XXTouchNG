import Foundation

@objc
public class CookiesToolObjectiveCBridge: NSObject
{
    @objc
    public static func readBinaryCookies(atURL url: URL) throws -> MiddleCookieJar
    {
        return try BinaryDataDecoder().decode(BinaryCookieJar.self, from: try Data(contentsOf: url)).toMiddleCookieJar()
    }
    
    @objc
    public static func writeBinaryCookies(_ cookies: MiddleCookieJar, toURL url: URL) throws
    {
        try BinaryDataEncoder().encode(BinaryCookieJar(from: cookies)).write(to: url, options: .atomic)
    }
}
