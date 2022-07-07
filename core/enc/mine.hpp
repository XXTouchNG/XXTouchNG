//
//  Bismillah ar-Rahmaan ar-Raheem
//
//  Mine (1.1.4)
//  Single header minimal cryptography library
//
//  Copyright (c) 2017-present Zuhd Web Services
//  Copyright (c) 2017-present @abumusamq
//
//  This library is released under the Apache 2.0 license
//  https://github.com/muflihun/zuhd-org/blob/master/LICENSE
//
//  https://github.com/zuhd-org/mine
//  https://zuhd.org
//  https://muflihun.com
//

#ifndef MINE_CRYPTO_H
#define MINE_CRYPTO_H

#include <vector>
#include <string>
#include <cstdlib>
#include <algorithm>
#include <sstream>
#include <unordered_map>
#include <iostream>
#include <array>
#include <map>
#include <cmath>
#include <stdexcept>

namespace mine {

using byte = unsigned char;

///
/// \brief Handy safe byte array
///
using ByteArray = std::vector<byte>;

///
/// \brief Contains common functions used across the lib
///
class MineCommon {
public:

    ///
    /// \brief Convert mode for various functions
    ///
    enum class Encoding {
        Raw,
        Base16,
        Base64
    };

    ///
    /// \brief Total items in random bytes list
    ///
    static const int kRandomBytesCount = 256;

    ///
    /// \brief List to choose random byte from
    ///
    static const byte kRandomBytesList[];

#ifdef MINE_WSTRING_CONVERSION
    ///
    /// \brief Converts it to std::string and calls countChars on it
    ///
    /// \note You need to include <locale> and <codecvt> headers before mine.h
    ///
    static std::size_t countChars(const std::wstring& raw) noexcept
    {
        std::string converted = std::wstring_convert
                <std::codecvt_utf8<wchar_t>, wchar_t>{}.to_bytes(raw);
        return countChars(converted);
    }
#endif

    ///
    /// \brief Replacement for better d.size() that consider unicode bytes too
    /// \see https://en.wikipedia.org/wiki/UTF-8#Description
    ///
    static std::size_t countChars(const std::string& d) noexcept;

    ///
    /// \brief Generates random bytes of length
    ///
    static ByteArray generateRandomBytes(const std::size_t len) noexcept;

    ///
    /// \brief Converts byte array to linear string
    ///
    static std::string byteArrayToRawString(const ByteArray& input) noexcept;

    ///
    /// \brief Converts string to byte array
    ///
    static ByteArray rawStringToByteArray(const std::string& str) noexcept;

    ///
    /// \brief Version of mine
    ///
    static std::string version() noexcept;
private:
    MineCommon() = delete;
    MineCommon(const MineCommon&) = delete;
    MineCommon& operator=(const MineCommon&) = delete;
};

///
/// \brief Provides base16 encoding / decoding
///
/// This class also contains some helpers to convert various input types
/// to byte array and also provides public interface to encode
/// the iterators for other containers like vector etc.
///
class Base16 {
public:

    ///
    /// \brief List of valid hex encoding characters
    ///
    static const std::string kValidChars;

    ///
    /// \brief Map for fast lookup corresponding character
    /// \see Base64::kDecodeMap
    ///
    static const std::unordered_map<byte, byte> kDecodeMap;

    ///
    /// \brief Encodes input to hex encoding
    ///
    static inline std::string encode(const std::string& raw) noexcept
    {
        return encode(raw.begin(), raw.end());
    }

    ///
    /// \brief Wrapper function to encode single hex char to corresponding byte
    ///
    static byte encode(const char* e)
    {
        return static_cast<byte>(strtol(e, nullptr, 16));
    }

    ///
    /// \brief Encodes input iterator to hex encoding
    ///
    template <class Iter>
    static std::string encode(const Iter& begin, const Iter& end) noexcept
    {
        std::ostringstream ss;
        for (auto it = begin; it < end; ++it) {
            encode(*it, ss);
        }
        return ss.str();
    }

    ///
    /// \brief Converts hex stream (e.g, 48656C6C6F) to byte array
    /// \param hex String stream e.g, 48656C6C6F (Hello)
    /// \return Byte array (mine::ByteArray) containing bytes e.g, 0x48, 0x65, 0x6C, 0x6C, 0x6F
    /// \throws invalid_argument if hex is not valid
    ///
    static ByteArray fromString(const std::string& hex);

    ///
    /// \brief Encodes integer to hex
    ///
    template <typename T>
    static std::string encode(T n) noexcept
    {
        std::stringstream ss;
        const int t16(16);
        int remainder;
        while (n != 0) {
            remainder = static_cast<int>(n % t16);
            n /= t16;
            ss << kValidChars[remainder];
        }
        std::string res(ss.str());
        std::reverse(res.begin(), res.end());
        return res;
    }

    ///
    /// \brief Decodes encoded hex
    /// \throws std::invalid_argument if invalid encoding.
    /// std::invalid_argument::what() is set accordingly
    ///
    static std::string decode(const std::string& enc)
    {
        if (enc.size() % 2 != 0) {
            throw std::invalid_argument("Invalid base-16 encoding");
        }
        return decode(enc.begin(), enc.end());
    }

    ///
    /// \brief Decodes encoding to single integer of type T
    ///
    template <typename T>
    static T decodeInt(const std::string& e)
    {
        T result = 0;
        for (auto it = e.begin(); it != e.end() && result >= 0; ++it) {
            try {
                result = ((result << 4) | kDecodeMap.at(*it & 0xff));
            } catch (const std::exception&) {
                throw std::runtime_error("Invalid base-16 encoding");
            }
        }
        return result;
    }

    ///
    /// \brief Encodes single byte
    ///
    static inline void encode(char b, std::ostringstream& ss) noexcept
    {
        int h = (b & 0xff);
        ss << kValidChars[(h >> 4) & 0xf] << kValidChars[(h & 0xf)];
    }

private:
    Base16() = delete;
    Base16(const Base16&) = delete;
    Base16& operator=(const Base16&) = delete;

    ///
    /// \brief Decodes input iterator to hex encoding
    /// \note User should check for the valid size or use decode(std::string)
    /// \throws runtime_error if invalid base16-encoding
    ///
    template <class Iter>
    static std::string decode(const Iter& begin, const Iter& end)
    {
        std::ostringstream ss;
        for (auto it = begin; it != end; it += 2) {
            decode(*it, *(it + 1), ss);
        }
        return ss.str();
    }

    ///
    /// \brief Decodes single byte pair
    ///
    static void decode(char a, char b, std::ostringstream& ss);
};

///
/// \brief Provides base64 encoding / decoding implementation
///
/// This class also provides public interface to encode
/// the iterators for other containers like vector etc.
///
/// This also handles 16-bit, 24-bit and 32-bit characters
///
///
///
class Base64 {
public:

    ///
    /// \brief List of valid base64 encoding characters
    ///
    static const char kValidChars[];

    static const std::unordered_map<byte, byte> kDecodeMap;

    ///
    /// \brief Padding is must in mine implementation of base64
    ///
    static const int kPadding = 64;

    ///
    /// \brief Encodes input of length to base64 encoding
    ///
    static std::string encode(const std::string& raw) noexcept
    {
        return encode(raw.begin(), raw.end());
    }

    ///
    /// \brief Encodes iterators
    ///
    template <class Iter>
    static std::string encode(const Iter& begin, const Iter& end) noexcept
    {
        std::string padding;
        std::stringstream ss;
        for (auto it = begin; it < end; it += 3) {

            //
            // we use example following example for implementation basis
            // Bits              01100001   01100010  01100011
            // 24-bit stream:    011000   010110   001001   100011
            // result indices     24        22       9        35
            //

            int c = static_cast<int>(*it & 0xff);
            ss << static_cast<char>(static_cast<char>(kValidChars[(c >> 2) & 0x3f])); // first 6 bits from first bitset
            if (it + 1 < end) {
                int c2 = static_cast<int>(*(it + 1) & 0xff);
                ss << static_cast<char>(kValidChars[((c << 4) | // remaining 2 bits from first bitset - shift them left to get 4-bit spaces 010000
                                                     (c2 >> 4) // first 4 bits of second bitset - shift them right to get 2 spaces and bitwise
                                                                      // to add them 000110
                                                     ) & 0x3f]);      // must be within 63 --
                                                                      // 010000
                                                                      // 000110
                                                                      // --|---
                                                                      // 010110
                                                                      // 111111
                                                                      // ---&--
                                                                      // 010110 ==> 22
                if (it + 2 < end) {
                    int c3 = static_cast<int>(*(it + 2) & 0xff);
                    ss << static_cast<char>(kValidChars[((c2 << 2) | // remaining 4 bits from second bitset - shift them to get 011000
                                                         (c3 >> 6)   // the first 2 bits from third bitset - shift them right to get 000001
                                                         ) & 0x3f]);
                                                                             // the rest of the explanation is same as above
                    ss << static_cast<char>(kValidChars[c3 & 0x3f]); // all the remaing bits
                } else {
                    ss << static_cast<char>(kValidChars[(c2 << 2) & 0x3f]); // we have 4 bits left from last byte need space for two 0-bits
                    ss << "=";
                }
            } else {
                ss << static_cast<char>(kValidChars[(c << 4) & 0x3f]); // remaining 2 bits from single byte
                ss << "==";
            }
        }
        return ss.str() + padding;
    }

    ///
    /// \brief Decodes encoded base64
    /// \see decode(const Iter&, const Iter&)
    ///
    static std::string decode(const std::string& e)
    {
        // don't check for e's length to be multiple of 4
        // because of 76 character line-break format (MIME)
        // https://tools.ietf.org/html/rfc4648#section-3.1
        return decode(e.begin(), e.end());
    }

    ///
    /// \brief Decodes base64 iterator from begin to end
    /// \throws std::invalid_argument if invalid encoding. Another time it is thrown
    /// is if no padding is found
    /// std::invalid_argument::what() is set according to the error
    ///
    template <class Iter>
    static std::string decode(const Iter& begin, const Iter& end)
    {
        //
        // we use example following example for implementation basis
        // Bits              01100001   01100010  01100011
        // 24-bit stream:    011000   010110   001001   100011
        // result indices     24        22       9        35
        //

        auto findPosOf = [](char c) -> int {
            try {
                return kDecodeMap.at(static_cast<int>(c & 0xff));
            } catch (const std::exception& e) {
                throw e;
            }
        };

        std::stringstream ss;
        for (auto it = begin; it < end; it += 4) {
            try {
                while (iswspace(*it)) {
                    ++it;

                    if (it >= end) {
                        goto result;
                    }
                }
                int b0 = findPosOf(*it);
                if (b0 == kPadding) {
                    throw std::invalid_argument("No data available");
                }
                if (b0 == -1) {
                    throw std::invalid_argument("Invalid base64 encoding");
                }

                while (iswspace(*(it + 1))) {
                    ++it;

                    if (it >= end) {
                        goto result;
                    }
                }
                int b1 = findPosOf(*(it + 1));
                if (b1 == -1) {
                    throw std::invalid_argument("Invalid base64 encoding");
                }

                while (iswspace(*(it + 2))) {
                    ++it;

                    if (it >= end) {
                        goto result;
                    }
                }
                int b2 = findPosOf(*(it + 2));
                if (b2 == -1) {
                    throw std::invalid_argument("Invalid base64 encoding");
                }

                while (iswspace(*(it + 3))) {
                    ++it;

                    if (it >= end) {
                        goto result;
                    }
                }
                int b3 = findPosOf(*(it + 3));
                if (b3 == -1) {
                    throw std::invalid_argument("Invalid base64 encoding");
                }

                ss << static_cast<byte>(b0 << 2 |     // 011000 << 2 ==> 01100000
                                        b1 >> 4); // 000001 >> 4 ==> 01100001 ==> 11000001 = 97

                if (b1 != kPadding) {
                    if (b2 == kPadding) {
                        // second bitset is only 4 bits
                    } else {
                        ss << static_cast<byte>((b1 & ~(1 << 5) & ~(1 << 4)) << 4 |     // 010110 ==> 000110 << 4 ==> 1100000
                                                                                        // first we clear the bits at pos 4 and 5
                                                                                        // then we concat with next bit
                                                 b2 >> 2); // 001001 >> 2 ==> 00000010 ==> 01100010 = 98
                        if (b3 == kPadding) {
                            // third bitset is only 4 bits
                        } else {
                            ss << static_cast<byte>((b2 & ~(1 << 5) & ~(1 << 4) & ~(1 << 3) & ~(1 << 2)) << 6 |     // 001001 ==> 000001 << 6 ==> 01000000
                                                    // first we clear first 4 bits
                                                    // then concat with last byte as is
                                                     b3); // as is
                        }
                    }
                }
            } catch (const std::exception& e) {
                throw std::invalid_argument(std::string("Invalid base64 encoding: " + std::string(e.what())));
            }
        }
result:
        return ss.str();
    }


#ifdef MINE_WSTRING_CONVERSION
    ///
    /// \brief Converts wstring to corresponding string and returns
    /// encoding
    /// \see encode(const std::string&)
    ///
    /// \note You need to include <locale> and <codecvt> headers before mine.h
    ///
    static std::string encode(const std::wstring& raw) noexcept
    {
        std::string converted = std::wstring_convert
                <std::codecvt_utf8<wchar_t>, wchar_t>{}.to_bytes(raw);
        return encode(converted);
    }

    ///
    /// \brief Helper method to decode base64 encoding as wstring (basic_string<wchar_t>)
    /// \see decode(const std::string&)
    /// \note We do not recommend using it, instead have your own conversion function from
    /// std::string to wstring as it can give you invalid results with characters that are
    /// 5+ bytes long e.g, \x1F680. If you don't use such characters then it should be safe
    /// to use this
    ///
    /// \note You need to include <locale> and <codecvt> headers before mine.h
    ///
    static std::wstring decodeAsWString(const std::string& e)
    {
        std::string result = decode(e);
        std::wstring converted = std::wstring_convert
                <std::codecvt_utf8_utf16<wchar_t>>{}.from_bytes(result);
        return converted;
    }
#endif

    ///
    /// \brief expectedBase64Length Returns expected base64 length
    /// \param n Length of input (plain data)
    ///
    inline static std::size_t expectedLength(std::size_t n) noexcept
    {
        return ((4 * n / 3) + 3) & ~0x03;
    }

    ///
    /// \brief Calculates the length of string
    /// \see countChars()
    ///
    template <typename T = std::string>
    inline static std::size_t expectedLength(const T& str) noexcept
    {
        return expectedLength(MineCommon::countChars(str));
    }

private:
    Base64() = delete;
    Base64(const Base64&) = delete;
    Base64& operator=(const Base64&) = delete;
};

///
/// \brief Provides AES crypto functionalities
///
/// This is validated against NIST test data and all
/// the corresponding tests under test/ directory
/// are from NIST themselves.
///
/// Please make sure to use public functions and do not
/// use private functions especially in production as
/// you may end up using them incorrectly. However
/// the source code for AES class is heavily commented for
/// verification on implementation.
///
class AES {
public:

    ///
    /// \brief A key is a byte array
    ///
    using Key = ByteArray;

    AES() = default;
    AES(const std::string& key);
    AES(const ByteArray& key);
    AES(const AES&);
    AES(const AES&&);
    AES& operator=(const AES&);
    virtual ~AES() = default;

    void setKey(const std::string& key);
    void setKey(const ByteArray& key);

    ///
    /// \brief Generates random key of valid length
    ///
    static std::string generateRandomKey(const std::size_t len);

    ///
    /// \brief Ciphers the input with specified hex key
    /// \param key Hex key
    /// \param inputEncoding the type of input. Defaults to Plain
    /// \param outputEncoding Type of encoding for cipher
    /// \param pkcs5Padding Defaults to true, if false non-standard zero-padding is used
    /// \return Base16 encoded cipher
    ///
    std::string encrypt(const std::string& input, const std::string& key, MineCommon::Encoding inputEncoding = MineCommon::Encoding::Raw, MineCommon::Encoding outputEncoding = MineCommon::Encoding::Base16, bool pkcs5Padding = true);

    ///
    /// \brief Ciphers the input with specified hex key using CBC mode
    /// \param key Hex key
    /// \param iv Initialization vector, passed by reference. If empty a random is generated and passed in
    /// \param inputEncoding the type of input. Defaults to Plain
    /// \param outputEncoding Type of encoding for cipher
    /// \param pkcs5Padding Defaults to true, if false non-standard zero-padding is used
    /// \return Base16 encoded cipher
    ///
    std::string encrypt(const std::string& input, const std::string& key, std::string& iv, MineCommon::Encoding inputEncoding = MineCommon::Encoding::Raw, MineCommon::Encoding outputEncoding = MineCommon::Encoding::Base16, bool pkcs5Padding = true);

    ///
    /// \brief Deciphers the input with specified hex key
    /// \param key Hex key
    /// \param inputEncoding the type of input. Defaults to base16
    /// \param outputEncoding Type of encoding for result
    /// \return Base16 encoded cipher
    ///
    std::string decrypt(const std::string& input, const std::string& key, MineCommon::Encoding inputEncoding = MineCommon::Encoding::Base16, MineCommon::Encoding outputEncoding = MineCommon::Encoding::Raw);

    ///
    /// \brief Deciphers the input with specified hex key using CBC mode
    /// \param key Hex key
    /// \param iv Initialization vector
    /// \param inputEncoding the type of input. Defaults to base16
    /// \param outputEncoding Type of encoding for result
    /// \return Base16 encoded cipher
    ///
    std::string decrypt(const std::string& input, const std::string& key, const std::string& iv, MineCommon::Encoding inputEncoding = MineCommon::Encoding::Base16, MineCommon::Encoding outputEncoding = MineCommon::Encoding::Raw);

    ///
    /// \brief Ciphers with ECB-Mode, the input can be as long as user wants
    /// \param input Plain input of any length
    /// \param key Pointer to a valid AES key
    /// \param pkcs5Padding Defaults to true, if false non-standard zero-padding is used
    /// \return Cipher text byte array
    ///
    ByteArray encrypt(const ByteArray& input, const Key* key, bool pkcs5Padding = true);

    ///
    /// \brief Deciphers with ECB-Mode, the input can be as long as user wants
    /// \param input Plain input of any length
    /// \param key Pointer to a valid AES key
    /// \return Cipher text byte array
    ///
    ByteArray decrypt(const ByteArray& input, const Key* key);

    ///
    /// \brief Ciphers with CBC-Mode, the input can be as long as user wants
    /// \param input Plain input of any length
    /// \param key Pointer to a valid AES key
    /// \param iv Initialization vector
    /// \param pkcs5Padding Defaults to true, if false non-standard zero-padding is used
    /// \return Cipher text byte array
    ///
    ByteArray encrypt(const ByteArray& input, const Key* key, ByteArray& iv, bool pkcs5Padding = true);

    ///
    /// \brief Deciphers with CBC-Mode, the input can be as long as user wants
    /// \param input Plain input of any length
    /// \param key Pointer to a valid AES key
    /// \param iv Initialization vector
    /// \return Cipher text byte array
    ///
    ByteArray decrypt(const ByteArray& input, const Key* key, ByteArray& iv);


    // cipher / decipher interface without keys

    std::string encr(const std::string& input, MineCommon::Encoding inputEncoding = MineCommon::Encoding::Raw, MineCommon::Encoding outputEncoding = MineCommon::Encoding::Base16, bool pkcs5Padding = true);

    std::string encr(const std::string& input, std::string& iv, MineCommon::Encoding inputEncoding = MineCommon::Encoding::Raw, MineCommon::Encoding outputEncoding = MineCommon::Encoding::Base16, bool pkcs5Padding = true);

    std::string decr(const std::string& input, MineCommon::Encoding inputEncoding = MineCommon::Encoding::Base16, MineCommon::Encoding outputEncoding = MineCommon::Encoding::Raw);

    std::string decr(const std::string& input, const std::string& iv, MineCommon::Encoding inputEncoding = MineCommon::Encoding::Base16, MineCommon::Encoding outputEncoding = MineCommon::Encoding::Raw);

    ByteArray encr(const ByteArray& input, bool pkcs5Padding = true);

    ByteArray decr(const ByteArray& input);

    ByteArray encr(const ByteArray& input, ByteArray& iv, bool pkcs5Padding = true);

    ByteArray decr(const ByteArray& input, ByteArray& iv);

private:

    ///
    /// \brief A word is array of 4 byte
    ///
    using Word = std::array<byte, 4>;

    ///
    /// \brief KeySchedule is linear array of 4-byte words
    /// \ref FIPS.197 Sec 5.2
    ///
    using KeySchedule = std::map<uint8_t, Word>;

    ///
    /// \brief State as described in FIPS.197 Sec. 3.4
    ///
    using State = std::array<Word, 4>;

    ///
    /// \brief AES works on 16 bit block at a time
    ///
    static const uint8_t kBlockSize = 16;

    ///
    /// \brief Defines the key params to it's size
    ///
    static const std::unordered_map<uint8_t, std::vector<uint8_t>> kKeyParams;

    ///
    /// \brief As defined in FIPS. 197 Sec. 5.1.1
    ///
    static const byte kSBox[];

    ///
    /// \brief As defined in FIPS. 197 Sec. 5.3.2
    ///
    static const byte kSBoxInverse[];

    ///
    /// \brief Round constant is constant for each round
    /// it contains 10 values each defined in
    /// Appendix A of FIPS.197 in column Rcon[i/Nk] for
    /// each key size, we add all of them in one array for
    /// ease of access
    ///
    static const byte kRoundConstant[];

    ///
    /// \brief Nb
    /// \note we make it constant as FIPS.197 p.9 says
    /// "For this standard, Nb=4."
    ///
    static const uint8_t kNb = 4;


    /// rotateWord function is specified in FIPS.197 Sec. 5.2:
    ///      The function RotWord() takes a
    ///      word [a0,a1,a2,a3] as input, performs a cyclic permutation,
    ///      and returns the word [a1,a2,a3,a0]. The
    ///      round constant word array
    ///
    /// Our definition:
    ///      We swap the first byte
    ///      to last one causing it to shift to the left
    ///      i.e,
    ///           [a1]      [a2]
    ///           [a2]      [a3]
    ///           [a3]  =>  [a4]
    ///           [a4]      [a1]
    ///
    static void rotateWord(Word* w);

    /// this function is also specified in FIPS.197 Sec. 5.2:
    ///      SubWord() is a function that takes a four-byte
    ///      input word and applies the S-box
    ///      to each of the four bytes to produce an output word.
    ///
    /// Out definition:
    /// It's a simple substition with kSbox for corresponding byte
    /// index
    ///
    static void substituteWord(Word* w);

    ///
    /// \brief Key expansion function as described in FIPS.197
    ///
    static KeySchedule keyExpansion(const Key* key);

    ///
    /// \brief Adds round to the state using specified key schedule
    ///
    static void addRoundKey(State* state, KeySchedule* keySchedule, int round);

    ///
    /// \brief Substitution step for state
    /// \ref Sec. 5.1.1
    ///
    static void subBytes(State* state);

    ///
    /// \brief Shifting rows step for the state
    /// \ref Sec. 5.1.2
    ///
    static void shiftRows(State* state);

    ///
    /// \ref Sec. 4.2.1
    ///
    static byte xtime(byte x);

    ///
    /// \ref Sec. 4.2.1
    ///
    static byte multiply(byte x, byte y);

    ///
    /// \brief Mixing columns for the state
    /// \ref Sec. 5.1.3
    ///
    static void mixColumns(State* state);

    ///
    /// \brief Transformation in the Inverse Cipher
    /// that is the reverse of subBytes()
    /// \ref Sec. 5.3.2
    ///
    static void invSubBytes(State* state);

    ///
    /// \brief  Transformation in the Inverse Cipher that is
    /// the reverse of shiftRows()
    /// \ref Sec. 5.3.1
    ///
    static void invShiftRows(State* state);

    ///
    /// \brief Transformation in the Inverse Cipher
    /// that is the reverse of mixColumns()
    /// \ref Sec. 5.3.3
    ///
    static void invMixColumns(State* state);

    ///
    /// \brief Prints bytes in hex format in 4x4 matrix fashion
    ///
    static void printBytes(const ByteArray& b);

    ///
    /// \brief Prints state for debugging
    ///
    static void printState(const State*);

    ///
    /// \brief Initializes the state with input. This function
    /// also pads the input if needed (i.e, input is not block of 128-bit)
    ///
    static void initState(State* state, const ByteArray::const_iterator& begin);

    ///
    /// \brief Creates byte array from input based on input mode
    ///
    static ByteArray resolveInputMode(const std::string& input, MineCommon::Encoding inputMode);

    ///
    /// \brief Creates string from byte array based on convert mode
    ///
    static std::string resolveOutputMode(const ByteArray& input, MineCommon::Encoding outputMode);

    ///
    /// \brief Exclusive XOR with iter of range size as input
    ///
    static ByteArray* xorWithRange(ByteArray* input, const ByteArray::const_iterator& begin, const ByteArray::const_iterator& end);

    ///
    /// \brief Raw encryption function - not for public use
    /// \param input 128-bit plain input
    /// If array is bigger it's chopped and if it's smaller, it's padded
    /// please use alternative functions if your array is bigger. Those
    /// function will handle all the bytes correctly.
    /// \param key Pointer to a valid AES key
    /// \note This does not do any key or input validation
    /// \return 128-bit cipher text
    ///
    static ByteArray encryptSingleBlock(const ByteArray::const_iterator& range, const Key* key, KeySchedule* keySchedule);

    ///
    /// \brief Raw decryption function - not for public use
    /// \param input 128-bit cipher input
    /// If array is bigger it's chopped and if it's smaller, it's padded
    /// please use alternative functions if your array is bigger. Those
    /// function will handle all the bytes correctly.
    /// \param key Byte array of key
    /// \return 128-bit plain text
    ///
    static ByteArray decryptSingleBlock(const ByteArray::const_iterator& range, const Key* key, KeySchedule* keySchedule);

    ///
    /// \brief Converts 4x4 byte state matrix in to linear 128-bit byte array
    ///
    static ByteArray stateToByteArray(const State* state);

    ///
    /// \brief Get padding index for stripping the padding (unpadding)
    ///
    static std::size_t getPaddingIndex(const ByteArray& byteArr);

    Key m_key; // to keep track of key differences
    KeySchedule m_keySchedule;

    // for tests
    friend class AESTest_RawCipher_Test;
    friend class AESTest_RawCipherPlain_Test;
    friend class AESTest_RawCipherBase64_Test;
    friend class AESTest_RawSimpleCipher_Test;
    friend class AESTest_RawSimpleDecipher_Test;
    friend class AESTest_SubByte_Test;
    friend class AESTest_InvSubByte_Test;
    friend class AESTest_ShiftRows_Test;
    friend class AESTest_InvShiftRows_Test;
    friend class AESTest_MixColumns_Test;
    friend class AESTest_InvMixColumns_Test;
    friend class AESTest_KeyExpansion_Test;
    friend class AESTest_AddRoundKey_Test;
    friend class AESTest_CbcCipher_Test;
    friend class AESTest_Copy_Test;
};

/// Here onwards start implementation for RSA - this contains
/// generic classes (templates).
/// User will provide their own implementation of big integer
/// or use existing one.
///
/// Compliant with PKCS#1 (v2.1)
/// https://tools.ietf.org/html/rfc3447#section-7.2
///
/// Big integer must support have following functions implemented
///  -  operator-() [subtraction]
///  -  operator+() [addition]
///  -  operator+=() [short-hand addition]
///  -  operator*() [multiply]
///  -  operator/() [divide]
///  -  operator%() [mod]
///  -  operator>>() [right-shift]
///
/// Also you must provide proper implementation to Helper class
/// which will extend MathHelper and must implement
/// <code>MathHelper<BigIntegerT>::bigIntegerToByte</code>
/// function. The base function returns empty byte.
///


///
/// \brief Default exponent for RSA public key
///
static const unsigned int kDefaultPublicExponent = 65537;

///
/// \brief Simple raw string (a.k.a octet string)
///
using RawString = ByteArray;

///
/// \brief Contains helper functions for RSA throughout
///
template <class BigIntegerT>
class MathHelper {
public:

    static const BigIntegerT kBigIntegerT256;

    MathHelper() = default;
    virtual ~MathHelper() = default;

    ///
    /// \brief Implementation inverse mod
    ///
    virtual BigIntegerT modInverse(BigIntegerT a, BigIntegerT m) const
    {
        BigIntegerT x, y;
        BigIntegerT gcdResult = gcdExtended(a, m, &x, &y);
        if (gcdResult != 1) {
            throw std::invalid_argument("Inverse does not exist");
        }
        /*std::cout << x << std::endl;
        std::cout << (x % m) << std::endl;
        std::cout << (x % m) + m << std::endl;
        std::cout << ((x % m) + m) % m << std::endl;*/
        return ((x % m) + m) % m;
    }

    ///
    /// \brief Fast GCD
    ///
    virtual BigIntegerT gcd(BigIntegerT a, BigIntegerT b) const
    {
        BigIntegerT c;
        while (a != 0) {
            c = a;
            a = b % a;
            b = c;
        }
        return b;
    }

    ///
    /// \brief Extended GCD
    /// \see https://en.wikipedia.org/wiki/Euclidean_algorithm#Extended_Euclidean_algorithm
    ///
    virtual BigIntegerT gcdExtended(BigIntegerT a, BigIntegerT b, BigIntegerT* x, BigIntegerT* y) const
    {
        // Base case
        if (a == 0)
        {
            *x = 0, *y = 1;
            return b;
        }

        BigIntegerT x1, y1;
        BigIntegerT gcd = gcdExtended(b % a, a, &x1, &y1);

        /*std::cout << y1 << " - " << ((b / a) * x1) << " = " << (y1 - ((b / a) * x1)) << std::endl;
        std::cout << std::endl;*/
        *x = y1 - ((b / a) * x1);
        *y = x1;

        return gcd;
    }

    ///
    /// \brief Simple (b ^ e) mod m implementation
    /// \param b Base
    /// \param e Exponent
    /// \param m Mod
    ///
    virtual BigIntegerT powerMod(BigIntegerT b, BigIntegerT e, const BigIntegerT& m) const
    {
        BigIntegerT res = 1;
        while (e > 0) {
            if (e % 2 != 0) {
                res = (b * res) % m;
            }
            b = (b * b) % m;
            e /= 2;
        }
        return res;
    }

    ///
    /// \brief Power of numb i.e, b ^ e
    ///
    virtual BigIntegerT power(BigIntegerT b, BigIntegerT e) const
    {
        BigIntegerT result = 1;
        while (e > 0) {
            if (e % 2 == 1) {
                // we decrement exponent to make it even
                e = e - 1;
                // store this multiplication directly to the
                // result
                result *= b;
                // we modify this alg to ignore the next multiplication
                // if we have already reached 0 (for speed)
                // here are details and what we changed and how it all works
                //
                // Let's say we have case of 2 ^ 4 [expected answer = 16]
                // 2 ^ 4 -- b = 4, e = 2 [result = 1]
                // 2 ^ 2 -- b = 16, e = 1 [result = 1]
                // 2 ^ 1 -- e = 0 [result = 1 * 16]
                //
                // here is what we changed here
                // now we have result set and we have e set to zero
                // doing another b ^= b means b = 16 * 16 = 256 (in our case)
                // which is useless so we end here
                if (e == 0) {
                    break;
                }
            }
            e /= 2;
            b *= b;
        }
        return result;
    }

    ///
    /// \brief Counts number of bits in big integer
    ///
    virtual unsigned int countBits(const BigIntegerT& b) const
    {
        BigIntegerT bc(b);
        unsigned int bits = 0;
        while (bc > 0) {
            bits++;
            bc = bc >> 1;
        }
        return bits;
    }

    ///
    /// \brief Count number of bytes in big integer
    ///
    virtual inline unsigned int countBytes(const BigIntegerT& b) const
    {
        return countBits(b) * 8;
    }

    ///
    /// Raw-string to integer (a.k.a os2ip)
    ///
    BigIntegerT rawStringToInteger(const RawString& x) const
    {
        BigIntegerT result = 0;
        std::size_t len = x.size();
        for (std::size_t i = len; i > 0; --i) {
            result += BigIntegerT(x[i - 1]) * power(kBigIntegerT256, BigIntegerT(static_cast<unsigned long long>(len - i)));
        }
        return result;
    }

    ///
    /// \brief Convert integer to raw string
    /// (this func is also known as i2osp)
    ///
    RawString integerToRaw(BigIntegerT x, int xlen = -1) const
    {
        xlen = xlen == -1 ? countBytes(x) : xlen;

        RawString ba(xlen);
        BigIntegerT r;
        BigIntegerT q;

        int i = 1;

        for (; i <= xlen; ++i) {
            divideBigInteger(x, power(kBigIntegerT256, BigIntegerT(xlen - i)), &q, &r);
            ba[i - 1] = bigIntegerToByte(q);
            x = r;
        }
        return ba;
    }

    ///
    /// \brief Divides big number
    /// You may override this function and call custom divisor from big integer class
    /// you are using.
    /// Result should be stored in quotient and remainder
    ///
    virtual void divideBigInteger(const BigIntegerT& divisor, const BigIntegerT& divident,
                                        BigIntegerT* quotient, BigIntegerT* remainder) const
    {
        *quotient = divisor / divident;
        *remainder = divisor % divident;
    }

    ///
    /// \brief Absolutely must override this - conversion from x to single byte
    ///
    virtual inline byte bigIntegerToByte(const BigIntegerT&) const
    {
        return static_cast<byte>(0);
    }

    ///
    /// \brief Converts big integer to hex
    ///
    virtual std::string bigIntegerToHex(BigIntegerT n) const
    {
        return Base16::encode(n);
    }

    ///
    /// \brief Converts big integer to hex
    ///
    virtual std::string bigIntegerToString(const BigIntegerT& b) const
    {
        std::stringstream ss;
        ss << b;
        return ss.str();
    }

    ///
    /// \brief Converts hex to big integer
    /// \param hex Hexadecimal without '0x' prefix
    ///
    virtual BigIntegerT hexToBigInteger(const std::string& hex) const
    {
        std::string readableMsg = "0x" + hex;
        return BigIntegerT(readableMsg.c_str());
    }
private:
    MathHelper(const MathHelper&) = delete;
    MathHelper& operator=(const MathHelper&) = delete;
};

///
/// \brief Big Integer = 256 (static declaration)
///
template <typename BigIntegerT>
const BigIntegerT MathHelper<BigIntegerT>::kBigIntegerT256 = 256;

template <class BigIntegerT, class Helper = MathHelper<BigIntegerT>>
class GenericBaseKey {
public:
    GenericBaseKey() = default;
    virtual ~GenericBaseKey() = default;

    inline std::size_t emBits() const { return (m_helper.countBits(m_n) + 7) >> 3; }
    inline std::size_t modBits() const { return 8 * m_k; }

    inline BigIntegerT n() const { return m_n; }
    inline unsigned int k() const { return m_k; }
    inline virtual bool empty() const = 0;

    void init(const BigIntegerT& n)
    {
        m_n = n;
        m_k = m_helper.countBytes(m_n);
        if (m_k < 11) {
            throw std::invalid_argument("Invalid prime. Length error.");
        }
    }

protected:
    BigIntegerT m_n;
    unsigned int m_k;
    Helper m_helper;
};

///
/// \brief Public key object with generic big integer
///
template <class BigIntegerT, class Helper = MathHelper<BigIntegerT>>
class GenericPublicKey : public GenericBaseKey<BigIntegerT, Helper> {
    using BaseKey = GenericBaseKey<BigIntegerT, Helper>;
public:

    GenericPublicKey() = default;

    GenericPublicKey(const GenericPublicKey& other)
    {
        this->m_n = other.m_n;
        this->m_e = other.m_e;
        this->m_k = other.m_k;
    }

    GenericPublicKey& operator=(const GenericPublicKey& other)
    {
        if (this != &other) {
            this->m_n = other.m_n;
            this->m_e = other.m_e;
            this->m_k = other.m_k;
        }
        return *this;
    }

    GenericPublicKey(BigIntegerT n, int e)
    {
        init(n, e);
    }

    void init(const BigIntegerT& n, int e = kDefaultPublicExponent)
    {
        BaseKey::init(n);
        m_e = e;
    }

    virtual ~GenericPublicKey() = default;

    inline int e() const { return m_e; }
    inline virtual bool empty() const { return m_e == 0 || BaseKey::m_n == 0; }

protected:
    int m_e;
};

///
/// \brief Private key object with generic big integer
///
template <class BigIntegerT, class Helper = MathHelper<BigIntegerT>>
class GenericPrivateKey : public GenericBaseKey<BigIntegerT, Helper> {
    using BaseKey = GenericBaseKey<BigIntegerT, Helper>;
public:

    GenericPrivateKey() = default;

    GenericPrivateKey(const GenericPrivateKey& other)
    {
        this->m_p = other.m_p;
        this->m_q = other.m_q;
        this->m_e = other.m_e;
        this->m_n = other.m_n;
        this->m_d = other.m_d;
        this->m_coeff = other.m_coeff;
        this->m_dp = other.m_dp;
        this->m_dq = other.m_dq;
        this->m_k = other.m_k;
    }

    GenericPrivateKey& operator=(const GenericPrivateKey& other)
    {
        if (this != &other) {
            this->m_p = other.m_p;
            this->m_q = other.m_q;
            this->m_e = other.m_e;
            this->m_n = other.m_n;
            this->m_d = other.m_d;
            this->m_coeff = other.m_coeff;
            this->m_dp = other.m_dp;
            this->m_dq = other.m_dq;
            this->m_k = other.m_k;
        }
        return *this;
    }

    GenericPrivateKey(const BigIntegerT& p, const BigIntegerT& q, int e = kDefaultPublicExponent)
    {
        init(p, q, e);
    }

    void init(const BigIntegerT& p, const BigIntegerT& q, int e = kDefaultPublicExponent)
    {
        if (p == q || p == 0 || q == 0) {
            throw std::invalid_argument("p and q must be prime numbers unique to each other");
        }
        m_p = p;
        m_q = q;
        m_e = e;

        const BigIntegerT pMinus1 = m_p - 1;
        const BigIntegerT qMinus1 = m_q - 1;
        const BigIntegerT phi = pMinus1 * qMinus1;

        if (BaseKey::m_helper.gcd(m_e, phi) != 1) {
            throw std::invalid_argument("Invalid exponent, it must not share factor with phi");
        }
        BaseKey::m_n = m_p * m_q;
        m_k = BaseKey::m_helper.countBytes(BaseKey::m_n);
        if (m_k < 11) {
            throw std::invalid_argument("Invalid prime. Length error.");
        }
        m_coeff = BaseKey::m_helper.modInverse(m_q, m_p);

        m_d = BaseKey::m_helper.modInverse(m_e, phi);

        // note:
        // https://tools.ietf.org/html/rfc3447#section-2 says to use m_e
        // openssl says to use m_d - which one?!
        //
        m_dp = BigIntegerT(m_d) % pMinus1;
        m_dq = BigIntegerT(m_d) % qMinus1;
    }

    virtual ~GenericPrivateKey() = default;

    inline BigIntegerT p() const { return m_p; }
    inline BigIntegerT q() const { return m_q; }
    inline BigIntegerT coeff() const { return m_coeff; }
    inline int e() const { return m_e; }
    inline BigIntegerT d() const { return m_d; }
    inline BigIntegerT dp() const { return m_dq; }
    inline BigIntegerT dq() const { return m_dp; }
    inline virtual bool empty() const { return m_p == 0 || m_q == 0; }

    friend std::ostream& operator<<(std::ostream& ss, const GenericPrivateKey<BigIntegerT, Helper>& k)
    {
        ss << "modulus: " << k.m_n << "\npublicExponent: " << k.m_e << "\nprivateExponent: " << k.m_d
           << "\nprime1: " << k.m_p << "\nprime2: " << k.m_q << "\nexponent1: " << k.m_dp << "\nexponent2: "
           << k.m_dq << "\ncoefficient: " << k.m_coeff;
        return ss;
    }

    ///
    /// \brief You can use this to export the key via
    /// openssl-cli using
    ///     openssl asn1parse -genconf exported.asn -out imp.der
    ///     openssl rsa -in imp.der -inform der -text -check
    ///   save the private key as pri.pem
    ///   export public key from it using
    ///     openssl rsa -in pri.pem -pubout > pub.pub
    ///
    virtual std::string exportASNSequence() const
    {
        std::stringstream ss;
        ss << "asn1=SEQUENCE:rsa_key\n\n";
        ss << "[rsa_key]\n";
        ss << "version=INTEGER:0\n";
        ss << "modulus=INTEGER:" << BaseKey::m_helper.bigIntegerToString(BaseKey::m_n) << "\n";
        ss << "pubExp=INTEGER:" << m_e << "\n";
        ss << "privExp=INTEGER:" << BaseKey::m_helper.bigIntegerToString(m_d) << "\n";
        ss << "p=INTEGER:" << BaseKey::m_helper.bigIntegerToString(m_p) << "\n";
        ss << "q=INTEGER:" << BaseKey::m_helper.bigIntegerToString(m_q) << "\n";
        ss << "e1=INTEGER:" << BaseKey::m_helper.bigIntegerToString(m_dp) << "\n";
        ss << "e2=INTEGER:" << BaseKey::m_helper.bigIntegerToString(m_dq) << "\n";
        ss << "coeff=INTEGER:" << BaseKey::m_helper.bigIntegerToString(m_coeff);
        return ss.str();
    }
protected:
    BigIntegerT m_p;
    BigIntegerT m_q;
    int m_e;
    BigIntegerT m_coeff;
    BigIntegerT m_d;
    BigIntegerT m_dp;
    BigIntegerT m_dq;
    unsigned int m_k;
};

///
/// \brief Key pair (containing public and private key objects) with generic big integer
///
template <class BigIntegerT, class Helper = MathHelper<BigIntegerT>>
class GenericKeyPair {
public:
    GenericKeyPair() = default;

    GenericKeyPair(const GenericKeyPair& other)
    {
        this->m_privateKey = other.m_privateKey;
        this->m_publicKey = other.m_publicKey;
    }

    GenericKeyPair& operator=(const GenericKeyPair& other)
    {
        if (this != &other) {
            this->m_privateKey = other.m_privateKey;
            this->m_publicKey = other.m_publicKey;
        }
        return *this;
    }

    GenericKeyPair(const BigIntegerT& p, const BigIntegerT& q, unsigned int exp = kDefaultPublicExponent)
    {
        init(p, q, exp);
    }

    void init(const BigIntegerT& p, const BigIntegerT& q, unsigned int exp = kDefaultPublicExponent)
    {
        m_publicKey = GenericPublicKey<BigIntegerT, Helper>(p * q, exp);
        m_privateKey = GenericPrivateKey<BigIntegerT, Helper>(p, q, exp);
    }

    virtual ~GenericKeyPair() = default;

    inline const GenericPublicKey<BigIntegerT, Helper>* publicKey() const { return &m_publicKey; }
    inline const GenericPrivateKey<BigIntegerT, Helper>* privateKey() const { return &m_privateKey; }

protected:
    GenericPublicKey<BigIntegerT, Helper> m_publicKey;
    GenericPrivateKey<BigIntegerT, Helper> m_privateKey;
};

///
/// \brief Provides RSA crypto functionalities
///
template <class BigIntegerT, class Helper = MathHelper<BigIntegerT>>
class GenericRSA {
public:

    using PublicKey = GenericPublicKey<BigIntegerT, Helper>;
    using PrivateKey = GenericPrivateKey<BigIntegerT, Helper>;

    GenericRSA() = default;
    GenericRSA(const GenericRSA&) = delete;
    GenericRSA& operator=(const GenericRSA&) = delete;

    ///
    /// \brief Helper method to encrypt wide-string messages using public key.
    /// \see encrypt<T>(const GenericPublicKey<BigIntegerT>* publicKey, const T& m)
    ///
    inline std::string encrypt(const PublicKey* publicKey,
                               const std::wstring& message)
    {
        return encrypt<decltype(message)>(publicKey, message);
    }

    ///
    /// \brief Helper method to encrypt std::string messages using public key.
    /// \see encrypt<T>(const GenericPublicKey<BigIntegerT>* publicKey, const T& m)
    ///
    inline std::string encrypt(const PublicKey* publicKey,
                               const std::string& message)
    {
        return encrypt<decltype(message)>(publicKey, message);
    }

    ///
    /// \brief Encrypts plain bytes using RSA public key
    /// \param publicKey RSA Public key for encryption
    /// \param m The message. This can be raw bytes or plain text
    /// T can of std::string or std::wstring or custom string type that has
    /// basic_stringstream implementation alongside it
    /// \note Mine uses pkcs#1 padding scheme
    /// \return hex of cipher
    ///
    template <class T>
    std::string encrypt(const PublicKey* publicKey, const T& m)
    {
        BigIntegerT paddedMsg = addPadding<T>(m, publicKey->emBits());
        BigIntegerT cipher = m_helper.powerMod(paddedMsg, publicKey->e(), publicKey->n());
        return m_helper.bigIntegerToHex(cipher);
    }

    ///
    /// \brief Decrypts RSA hex message using RSA private key
    /// \param privateKey RSA private key
    /// \param c Cipher in hex format (should not start with 0x)
    /// \return Plain result of TResult type
    ///
    template <class TResult = std::wstring>
    TResult decrypt(const PrivateKey* privateKey, const std::string& c)
    {
        BigIntegerT msg = m_helper.hexToBigInteger(c);
        int xlen = privateKey->emBits();
        if (msg >= m_helper.power(MathHelper<BigIntegerT>::kBigIntegerT256, BigIntegerT(xlen))) {
            throw std::runtime_error("Integer too large");
        }
        BigIntegerT decr = m_helper.powerMod(msg, privateKey->d(), privateKey->n());
        RawString rawStr = m_helper.integerToRaw(decr, xlen);
        return removePadding<TResult>(rawStr);
    }

    ///
    /// \brief Verifies signature for text using RSA public key
    /// \param message Base16 msg
    /// \param signature Base16 signature
    /// \see https://tools.ietf.org/html/rfc3447#section-8.1.2
    ///
    bool verify(const PublicKey* publicKey, const std::string& msg, const std::string& sign)
    {
        if (sign.size() != publicKey->k()) {
            //return false;
        }
        BigIntegerT signature = m_helper.rawStringToInteger(MineCommon::rawStringToByteArray(sign));
        try {
            BigIntegerT verifyPrimitive = createVerificationPrimitive(publicKey, signature);
            RawString em = m_helper.integerToRaw(verifyPrimitive, publicKey->emBits());
            return emsaPssVerify(msg, em, publicKey->modBits() - 1);
        } catch (const std::exception&) {
            return false;
        }
    }

    ///
    /// \brief Signs the message with private key
    /// \return Signature (base16)
    /// \see https://tools.ietf.org/html/rfc3447#section-8.1.1
    ///
    template <typename T>
    std::string sign(const PrivateKey* privateKey, const T& msg)
    {
        RawString encoded = emsaPssEncode(msg, privateKey->modBits() - 1);

        BigIntegerT m = m_helper.rawStringToInteger(encoded);

        BigIntegerT signPrimitive = createSignaturePrimitive(privateKey, m);
        return m_helper.integerToRaw(signPrimitive, privateKey->k());
    }

    ///
    /// \brief Maximum size of RSA block with specified key size
    /// \param keySize 2048, 1024, ...
    ///
    inline static unsigned int maxRSABlockSize(std::size_t keySize)
    {
        return (keySize / 8) - 11;
    }

    ///
    /// \brief Minimum size of RSA key to encrypt data of dataSize size
    ///
    inline static unsigned int minRSAKeySize(std::size_t dataSize)
    {
        return (dataSize + 11) * 8;
    }

private:
    Helper m_helper;

    ///
    /// \brief PKCS #1 padding
    /// \see https://tools.ietf.org/html/rfc3447#page-23
    /// \return corresponding nonnegative integer
    ///
    template <class T = std::wstring>
    BigIntegerT addPadding(const T& s, std::size_t n) {
        if (n < s.size() + 11) {
            throw std::runtime_error("Message too long");
        }
        RawString byteArray(n);
        long long i = s.size() - 1;
        while(i >= 0 && n > 0) {
            int c = static_cast<int>(s.at(i--));
            if (c <= 0x7f) {
                // utf
                byteArray[--n] = c;
            } else if (c <= 0x7ff) {
                byteArray[--n] = (c & 0x3f) | 128;
                byteArray[--n] = (c >> 6) | 192;
            } else if (c <= 0xffff) {
                // utf-16
                byteArray[--n] = (c & 0x3f) | 128;
                byteArray[--n] = ((c >> 6) & 63) | 128;
                byteArray[--n] = (c >> 12) | 224;
            } else {
                // utf-32
                byteArray[--n] = (c & 0x3f) | 128;
                byteArray[--n] = ((c >> 6) & 0x3f) | 128;
                byteArray[--n] = ((c >> 12) & 0x3f) | 128;
                byteArray[--n] = (c >> 18) | 240;
            }
        }

        // now padding i.e, 0x00 || 0x02 || PS || 0x00
        // see point #2 on https://tools.ietf.org/html/rfc3447#section-7.2.1 => EME-PKCS1-v1_5 encoding

        const int kLengthOfRandom = 127;

        byteArray[--n] = 0;

        srand(time(nullptr));
        int r = rand() % kLengthOfRandom + 1;
        while (n > 2) {
            r = 0;
            while (r == 0) {
                r = rand() % kLengthOfRandom + 1;
            }
            byteArray[--n] = r;
        }
        // first two bytes of padding are 0x2 (second) and 0x0 (first)
        byteArray[--n] = 2;
        byteArray[--n] = 0;
        return m_helper.rawStringToInteger(byteArray);
    }

    ///
    /// \brief PKCS #1 unpadding
    /// \see https://tools.ietf.org/html/rfc3447#section-4.1
    /// \return corresponding octet string of length n
    ///
    template <class T = std::wstring>
    T removePadding(const RawString& ba)
    {
        std::size_t baLen = ba.size();
        if (baLen <= 2 || ba[0] != 0 || ba[1] != 2) {
            throw std::runtime_error("Incorrect padding PKCS#1");
        }
        std::size_t i = 2; // passed first two characters (0x0 and 0x2) test
        // lets check for the <PS>

        // if we hit end while still we're still with non-zeros, it's a padding error
        // 0x0 (done) | 0x2 (done) | <PS> | 0x0
        while (ba[i] != 0) {
            if (++i >= baLen) { // already ended!
                throw std::runtime_error("Incorrect padding PKCS#1");
            }
        }
        // last zero
        ++i;

        // now we should be at the first non-zero byte
        // which is our first item, concat them as char | wchar_t

        using CharacterType = typename T::value_type;
        std::basic_stringstream<CharacterType> ss;

        for (; i < baLen; ++i) {
            // reference: http://en.cppreference.com/w/cpp/language/types -> range of values
            int c = ba[i] & 0xff;
            if (c <= 0x7f) {
                ss << static_cast<CharacterType>(c);
            } else if (c > 0xbf && c < 0xe0) {
                ss << static_cast<CharacterType>(
                          ((c & 0x1f) << 6) |
                          (ba[i+1] & 0x3f)
                      );
                ++i;
            } else if ((c < 0xbf) || (c >= 0xe0 && c < 0xf0)) { // utf-16 char
                ss << static_cast<CharacterType>(
                          ((c & 0xf) << 12) |
                          ((ba[i+1] & 0x3f) << 6) |
                          (ba[i+2] & 0x3f)
                        );
                i += 2;
            } else { // utf-32 char
                ss << static_cast<CharacterType>(
                          ((c & 0x7) << 18) |
                          ((ba[i+1] & 0x3f) << 12) |
                          ((ba[i+2] & 0x3f) << 6) |
                          (ba[i+3] & 0x3f)
                        );
                i += 3;
            }
        }
        return ss.str();
    }

    ///
    /// \brief Creates RSA VP for verification (aka rsavp1)
    /// \param signature signature representative, an integer between 0 and n - 1
    /// \return message representative, an integer between 0 and n - 1
    /// \see https://tools.ietf.org/html/rfc3447#section-5.2.2
    ///
    BigIntegerT createVerificationPrimitive(const PublicKey* publicKey, const BigIntegerT& signature)
    {
        if (signature < 0 || signature > publicKey->n() - 1) {
            throw std::runtime_error("signature representative out of range");
        }
        return m_helper.powerMod(signature, publicKey->e(), publicKey->n());
    }

    ///
    /// \brief Creates RSA SP for signing (aka rsasp1)
    /// \param signature signature representative, an integer between 0 and n - 1
    /// \return message representative, an integer between 0 and n - 1
    /// \see https://tools.ietf.org/html/rfc3447#section-5.2.2
    ///
    BigIntegerT createSignaturePrimitive(const PrivateKey* privateKey, const BigIntegerT& msg)
    {
        if (msg < 0 || msg > privateKey->n() - 1) {
            throw std::runtime_error("message representative out of range");
        }
        return m_helper.powerMod(msg, privateKey->e(), privateKey->n());
    }

    ///
    /// \see https://tools.ietf.org/html/rfc3447#section-9.1.1
    ///
    template <typename T>
    RawString emsaPssEncode(const T&, std::size_t)
    {
        return RawString();
    }

    ///
    /// \see http://tools.ietf.org/html/rfc3447#section-9.1.2
    ///
    bool emsaPssVerify(const std::string&, const RawString&, std::size_t)
    {

        return true;
    }

    // for tests
    friend class RSATest_Signature_Test;
    friend class RSATest_Decryption_Test;
    friend class RSATest_KeyAndEncryptionDecryption_Test;
    friend class RSATest_PowerMod_Test;
};


///
/// \brief Provides Zlib functionality for inflate and deflate
///
class ZLib {
public:

    ///
    /// \brief Size of buffer algorithm should operate under
    ///
    static const int kBufferSize = 32768;

    ///
    /// \brief Compress input file (path) and create new file
    /// \param gzFilename Output file path
    /// \param inputFile Input file path
    /// \return True if successful, otherwise false
    ///
    static bool compressFile(const std::string& gzFilename, const std::string& inputFile);

    ///
    /// @brief Compresses string using zlib (inflate)
    /// @param str Input plain text
    /// @return Raw output (binary)
    ///
    static std::string compressString(const std::string& str);

    ///
    /// @brief Decompresses string using zlib (deflate)
    /// @param str Raw input
    /// @return Plain output
    ///
    static std::string decompressString(const std::string& str);
private:
    ZLib() = delete;
    ZLib(const ZLib&) = delete;
    ZLib& operator=(const ZLib&) = delete;
};

} // namespace mine
#endif // MINE_CRYPTO_H
