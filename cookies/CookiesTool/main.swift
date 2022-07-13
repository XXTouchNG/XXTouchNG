import Foundation


func usage() {
    print("""
Usage: CookiesTool [OPTIONS]... [FILE]...
Convert between Apple BinaryCookies, EditThisCookie (JSON), Perl::LWP and Netscape HTTP Cookie File.

Command options are (-l is the default):
  -h | --help               show this message and exit
  -l | --lint               check the cookies file for syntax errors
  -c | --convert FORMAT     rewrite cookies file in format
  -o | --output PATH        specify file path name for result;
                            the -o option is used with -c, and is only useful
                            with one file argument;
  -r | --readable           if writing JSON, output in human-readable form

FORMAT is one of: \(Format.allCases.map({ $0.rawValue }).joined(separator: " "))
""")
}


enum CustomError: LocalizedError {
    case invalidOption
    case invalidArgumentFormat
    case missingArgumentFile
    case missingOptionOutput
    case missingArgumentConvert
    case missingArgumentOutput
    case invalidFileFormat
    
    var errorDescription: String? {
        switch self {
        case .invalidOption:
            return "invalid option"
        case .invalidArgumentFormat:
            return "invalid argument: FORMAT"
        case .missingArgumentFile:
            return "missing argument: FILE"
        case .missingOptionOutput:
            return "missing required option: --output"
        case .missingArgumentConvert:
            return "missing argument for: --convert"
        case .missingArgumentOutput:
            return "missing argument for: --output"
        case .invalidFileFormat:
            return "invalid file format"
        }
    }
}


enum Mode {
    case help
    case lint
    case convert
}


enum Format: String, CaseIterable {
    case binary         = "binarycookies"
    case editThisCookie = "edit-this-cookie"
    case netscape       = "netscape"
    case PerlLWP        = "perl-lwp"
    case invalid        = ""
}


struct Options: OptionSet {
    let rawValue: Int
    static let jsonReadable = Options(rawValue: 1 << 0)
}


do {
    
    var mode = Mode.lint
    var inFormat = Format.invalid
    var outFormat = Format.binary
    var options: Options = []
    var outputPath: String? = nil
    var inputPaths: [String] = []
    
    
    // MARK: - Parse Arguments
    let args = CommandLine.arguments
    var i = 1
    while i < args.count {
        if args[i] == "-h" || args[i] == "--help" {
            mode = .help
            break
        }
        else if args[i] == "-l" || args[i] == "--lint" {
            mode = .lint
            break
        }
        else if args[i] == "-c" || args[i] == "--convert" {
            mode = .convert
            guard let argi = args[safe: i + 1] else {
                throw CustomError.missingArgumentConvert
            }
            guard let argiFormat = Format(rawValue: argi) else {
                throw CustomError.invalidArgumentFormat
            }
            outFormat = argiFormat
            i = i + 1
        }
        else if args[i] == "-r" || args[i] == "--readable" {
            options.insert(.jsonReadable)
        }
        else if args[i] == "-o" || args[i] == "--output" {
            mode = .convert
            guard let argiPath = args[safe: i + 1] else {
                throw CustomError.missingArgumentOutput
            }
            outputPath = argiPath
            i = i + 1
        }
        else {
            inputPaths.append(args[i])
        }
        
        i = i + 1
    }
    
    
    // MARK: - Help
    guard mode != .help else {
        usage()
        exit(EXIT_SUCCESS)
    }
    
    
    // MARK: - Lint (Read)
    guard let path = inputPaths.first else {
        throw CustomError.missingArgumentFile
    }
    let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath, relativeTo: nil).standardizedFileURL
    let data = try Data(contentsOf: url)
    var rawCookies: Any?
    var middleCookieJar: MiddleCookieJar
    if let tryCookieJar = try? BinaryDataDecoder().decode(BinaryCookieJar.self, from: data) {
        inFormat = .binary
        guard mode != .lint else {
            dump(tryCookieJar)
            exit(EXIT_SUCCESS)
        }
        middleCookieJar = tryCookieJar.toMiddleCookieJar()
    }
    else if let tryCookieJar = try? JSONDecoder().decode(EditThisCookie.self, from: data) {
        inFormat = .editThisCookie
        guard mode != .lint else {
            dump(tryCookieJar)
            exit(EXIT_SUCCESS)
        }
        if outFormat == inFormat { rawCookies = tryCookieJar }
        middleCookieJar = tryCookieJar.toMiddleCookieJar()
    }
    else if let tryCookieJar = try? BinaryDataDecoder().decode(NetscapeCookieJar.self, from: data) {
        inFormat = .netscape
        guard mode != .lint else {
            dump(tryCookieJar)
            exit(EXIT_SUCCESS)
        }
        if outFormat == inFormat { rawCookies = tryCookieJar }
        middleCookieJar = tryCookieJar.toMiddleCookieJar()
    }
    else if let tryCookieJar = try? BinaryDataDecoder().decode(LWPCookieJar.self.self, from: data) {
        inFormat = .PerlLWP
        guard mode != .lint else {
            dump(tryCookieJar)
            exit(EXIT_SUCCESS)
        }
        if outFormat == inFormat { rawCookies = tryCookieJar }
        middleCookieJar = tryCookieJar.toMiddleCookieJar()
    }
    else {
        throw CustomError.invalidFileFormat
    }
    
    
    // MARK: - Convert
    guard let toPath = outputPath else {
        throw CustomError.missingOptionOutput
    }
    let toURL = URL(fileURLWithPath: (toPath as NSString).expandingTildeInPath, relativeTo: nil).standardizedFileURL
    var outputData: Data
    switch outFormat {
    case .binary:
        outputData = try BinaryDataEncoder().encode(BinaryCookieJar(from: middleCookieJar))
    case .editThisCookie:
        let encoder = JSONEncoder()
        encoder.outputFormatting = options.contains(.jsonReadable) ? [.prettyPrinted, .sortedKeys] : []
        if let rawCookies = rawCookies as? EditThisCookie {
            outputData = try encoder.encode(rawCookies)
        } else {
            outputData = try encoder.encode(middleCookieJar.toEditThisCookie())
        }
    case .netscape:
        if let rawCookies = rawCookies as? NetscapeCookieJar {
            outputData = try BinaryDataEncoder().encode(rawCookies)
        } else {
            outputData = try BinaryDataEncoder().encode(NetscapeCookieJar(from: middleCookieJar))
        }
    case .PerlLWP:
        if let rawCookies = rawCookies as? LWPCookieJar {
            outputData = try BinaryDataEncoder().encode(rawCookies)
        } else {
            outputData = try BinaryDataEncoder().encode(LWPCookieJar(from: middleCookieJar))
        }
    case .invalid:
        outputData = Data()
    }
    
    
    // MARK: - Convert (Write)
    try outputData.write(to: toURL)
    
}
catch let error {
    print(error.localizedDescription)
    exit(EXIT_FAILURE)
}
