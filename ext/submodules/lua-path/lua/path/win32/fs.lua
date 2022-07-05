------------------------------------------------------------------
--
--  Author: Alexey Melnichuk <alexeymelnichuck@gmail.com>
--
--  Copyright (C) 2013-2016 Alexey Melnichuk <alexeymelnichuck@gmail.com>
--
--  Licensed according to the included 'LICENCE' document
--
--  This file is part of lua-path library.
--
------------------------------------------------------------------

--[[ note GetTempPath
GetTempPath() might ignore the environment variables it's supposed to use (TEMP, TMP, ...) if they are more than 130 characters or so.
http://blogs.msdn.com/b/larryosterman/archive/2010/10/19/because-if-you-do_2c00_-stuff-doesn_2700_t-work-the-way-you-intended_2e00_.aspx

---------------
 Limit of Buffer Size for GetTempPath
[Note - this behavior does not occur with the latest versions of the OS as of Vista SP1/Windows Server 2008. If anyone has more information about when this condition occurs, please update this content.]

[Note - this post has been edited based on, and extended by, information in the following post]

Apparently due to the method used by GetTempPathA to translate ANSI strings to UNICODE, this function itself cannot be told that the buffer is greater than 32766 in narrow convention. Attempting to pass a larger value in nBufferLength will result in a failed RtlHeapFree call in ntdll.dll and subsequently cause your application to call DbgBreakPoint in debug compiles and simple close without warning in release compiles.

Example:

// Allocate a 32Ki character buffer, enough to hold even native NT paths.
LPTSTR tempPath = new TCHAR[32767];
::GetTempPath(32767, tempPath);    // Will crash in RtlHeapFree
----------------
--]]

local function prequire(...)
  local ok, mod = pcall(require, ...)
  if not ok then return nil, mod end
  return mod
end

local lua_version do

local lua_version_t
lua_version = function()
  if not lua_version_t then 
    local version = assert(_VERSION)
    local maj, min = version:match("^Lua (%d+)%.(%d+)$")
    if maj then                         lua_version_t = {tonumber(maj),tonumber(min)}
    elseif math.type    then            lua_version_t = {5,3}
    elseif not math.mod then            lua_version_t = {5,2}
    elseif table.pack and not pack then lua_version_t = {5,2}
    else                                lua_version_t = {5,2} end
  end
  return lua_version_t[1], lua_version_t[2]
end

end

local LUA_MAJOR, LUA_MINOR = lua_version()

local LUA_VER_NUM = LUA_MAJOR * 100 + LUA_MINOR

local load_bit if LUA_VER_NUM < 503 then
  load_bit = function()
    return assert(prequire("bit32") or prequire("bit"))
  end
else
  load_bit = function ()
    local bit_loader = assert(load[[
      return {
        band = function(a, b) return a & b end;
      }
    ]])
    return assert(bit_loader())
  end
end

local bit = load_bit()

local CONST = {
  GENERIC_READ                     = 0x80000000;
  GENERIC_WRITE                    = 0x40000000;
  GENERIC_EXECUTE                  = 0x20000000;
  GENERIC_ALL                      = 0x10000000;

  FILE_FLAG_WRITE_THROUGH          = 0x80000000;
  FILE_FLAG_NO_BUFFERING           = 0x20000000;
  FILE_FLAG_RANDOM_ACCESS          = 0x10000000;
  FILE_FLAG_SEQUENTIAL_SCAN        = 0x08000000;
  FILE_FLAG_DELETE_ON_CLOSE        = 0x04000000;
  FILE_FLAG_OVERLAPPED             = 0x40000000;

  FILE_ATTRIBUTE_ARCHIVE             = 0x00000020; -- A file or directory that is an archive file or directory. Applications typically use this attribute to mark files for backup or removal . 
  FILE_ATTRIBUTE_COMPRESSED          = 0x00000800; -- A file or directory that is compressed. For a file, all of the data in the file is compressed. For a directory, compression is the default for newly created files and subdirectories.
  FILE_ATTRIBUTE_DEVICE              = 0x00000040; -- This value is reserved for system use.
  FILE_ATTRIBUTE_DIRECTORY           = 0x00000010; -- The handle that identifies a directory.
  FILE_ATTRIBUTE_ENCRYPTED           = 0x00004000; -- A file or directory that is encrypted. For a file, all data streams in the file are encrypted. For a directory, encryption is the default for newly created files and subdirectories.
  FILE_ATTRIBUTE_HIDDEN              = 0x00000002; -- The file or directory is hidden. It is not included in an ordinary directory listing.
  FILE_ATTRIBUTE_INTEGRITY_STREAM    = 0x00008000; -- The directory or user data stream is configured with integrity (only supported on ReFS volumes). It is not included in an ordinary directory listing. The integrity setting persists with the file if it's renamed. If a file is copied the destination file will have integrity set if either the source file or destination directory have integrity set. (This flag is not supported until Windows Server 2012.)
  FILE_ATTRIBUTE_NORMAL              = 0x00000080; -- A file that does not have other attributes set. This attribute is valid only when used alone.
  FILE_ATTRIBUTE_NOT_CONTENT_INDEXED = 0x00002000; -- The file or directory is not to be indexed by the content indexing service.
  FILE_ATTRIBUTE_NO_SCRUB_DATA       = 0x00020000; -- The user data stream not to be read by the background data integrity scanner (AKA scrubber). When set on a directory it only provides inheritance. This flag is only supported on Storage Spaces and ReFS volumes. It is not included in an ordinary directory listing. This flag is not supported until Windows 8 and Windows Server 2012.
  FILE_ATTRIBUTE_OFFLINE             = 0x00001000; -- The data of a file is not available immediately. This attribute indicates that the file data is physically moved to offline storage. This attribute is used by Remote Storage, which is the hierarchical storage management software. Applications should not arbitrarily change this attribute.
  FILE_ATTRIBUTE_READONLY            = 0x00000001; -- A file that is read-only. Applications can read the file, but cannot write to it or delete it. This attribute is not honored on directories. For more information, see You cannot view or change the Read-only or the System attributes of folders in Windows Server 2003, in Windows XP, in Windows Vista or in Windows 7.
  FILE_ATTRIBUTE_REPARSE_POINT       = 0x00000400; -- A file or directory that has an associated reparse point, or a file that is a symbolic link.
  FILE_ATTRIBUTE_SPARSE_FILE         = 0x00000200; -- A file that is a sparse file.
  FILE_ATTRIBUTE_SYSTEM              = 0x00000004; -- A file or directory that the operating system uses a part of, or uses exclusively.
  FILE_ATTRIBUTE_TEMPORARY           = 0x00000100; -- A file that is being used for temporary storage. File systems avoid writing data back to mass storage if sufficient cache memory is available, because typically, an application deletes a temporary file after the handle is closed. In that scenario, the system can entirely avoid writing the data. Otherwise, the data is written after the handle is closed.
  FILE_ATTRIBUTE_VIRTUAL             = 0x00010000; --

  FILE_READ_DATA                     = 0x00000001; -- file & pipe
  FILE_LIST_DIRECTORY                = 0x00000001; -- directory
  FILE_WRITE_DATA                    = 0x00000002; -- file & pipe
  FILE_ADD_FILE                      = 0x00000002; -- directory
  FILE_APPEND_DATA                   = 0x00000004; -- file
  FILE_ADD_SUBDIRECTORY              = 0x00000004; -- directory
  FILE_CREATE_PIPE_INSTANCE          = 0x00000004; -- named pipe
  FILE_READ_EA                       = 0x00000008; -- file & directory
  FILE_WRITE_EA                      = 0x00000010; -- file & directory
  FILE_EXECUTE                       = 0x00000020; -- file
  FILE_TRAVERSE                      = 0x00000020; -- directory
  FILE_DELETE_CHILD                  = 0x00000040; -- directory
  FILE_READ_ATTRIBUTES               = 0x00000080; -- all
  FILE_WRITE_ATTRIBUTES              = 0x00000100; -- all

  FILE_SHARE_READ                  = 0x00000001;
  FILE_SHARE_WRITE                 = 0x00000002;
  FILE_SHARE_DELETE                = 0x00000004;

  CREATE_NEW                       = 1;
  CREATE_ALWAYS                    = 2;
  OPEN_EXISTING                    = 3;
  OPEN_ALWAYS                      = 4;
  TRUNCATE_EXISTING                = 5;

  FILE_DEVICE_8042_PORT            = 0x00000027;
  FILE_DEVICE_ACPI                 = 0x00000032;
  FILE_DEVICE_BATTERY              = 0x00000029;
  FILE_DEVICE_BEEP                 = 0x00000001;
  FILE_DEVICE_BUS_EXTENDER         = 0x0000002a;
  FILE_DEVICE_CD_ROM               = 0x00000002;
  FILE_DEVICE_CD_ROM_FILE_SYSTEM   = 0x00000003;
  FILE_DEVICE_CHANGER              = 0x00000030;
  FILE_DEVICE_CONTROLLER           = 0x00000004;
  FILE_DEVICE_DATALINK             = 0x00000005;
  FILE_DEVICE_DFS                  = 0x00000006;
  FILE_DEVICE_DFS_FILE_SYSTEM      = 0x00000035;
  FILE_DEVICE_DFS_VOLUME           = 0x00000036;
  FILE_DEVICE_DISK                 = 0x00000007;
  FILE_DEVICE_DISK_FILE_SYSTEM     = 0x00000008;
  FILE_DEVICE_DVD                  = 0x00000033;
  FILE_DEVICE_FILE_SYSTEM          = 0x00000009;
  FILE_DEVICE_FIPS                 = 0x0000003a;
  FILE_DEVICE_FULLSCREEN_VIDEO     = 0x00000034;
  FILE_DEVICE_INPORT_PORT          = 0x0000000a;
  FILE_DEVICE_KEYBOARD             = 0x0000000b;
  FILE_DEVICE_KS                   = 0x0000002f;
  FILE_DEVICE_KSEC                 = 0x00000039;
  FILE_DEVICE_MAILSLOT             = 0x0000000c;
  FILE_DEVICE_MASS_STORAGE         = 0x0000002d;
  FILE_DEVICE_MIDI_IN              = 0x0000000d;
  FILE_DEVICE_MIDI_OUT             = 0x0000000e;
  FILE_DEVICE_MODEM                = 0x0000002b;
  FILE_DEVICE_MOUSE                = 0x0000000f;
  FILE_DEVICE_MULTI_UNC_PROVIDER   = 0x00000010;
  FILE_DEVICE_NAMED_PIPE           = 0x00000011;
  FILE_DEVICE_NETWORK              = 0x00000012;
  FILE_DEVICE_NETWORK_BROWSER      = 0x00000013;
  FILE_DEVICE_NETWORK_FILE_SYSTEM  = 0x00000014;
  FILE_DEVICE_NETWORK_REDIRECTOR   = 0x00000028;
  FILE_DEVICE_NULL                 = 0x00000015;
  FILE_DEVICE_PARALLEL_PORT        = 0x00000016;
  FILE_DEVICE_PHYSICAL_NETCARD     = 0x00000017;
  FILE_DEVICE_PRINTER              = 0x00000018;
  FILE_DEVICE_SCANNER              = 0x00000019;
  FILE_DEVICE_SCREEN               = 0x0000001c;
  FILE_DEVICE_SERENUM              = 0x00000037;
  FILE_DEVICE_SERIAL_MOUSE_PORT    = 0x0000001a;
  FILE_DEVICE_SERIAL_PORT          = 0x0000001b;
  FILE_DEVICE_SMARTCARD            = 0x00000031;
  FILE_DEVICE_SMB                  = 0x0000002e;
  FILE_DEVICE_SOUND                = 0x0000001d;
  FILE_DEVICE_STREAMS              = 0x0000001e;
  FILE_DEVICE_TAPE                 = 0x0000001f;
  FILE_DEVICE_TAPE_FILE_SYSTEM     = 0x00000020;
  FILE_DEVICE_TERMSRV              = 0x00000038;
  FILE_DEVICE_TRANSPORT            = 0x00000021;
  FILE_DEVICE_UNKNOWN              = 0x00000022;
  FILE_DEVICE_VDM                  = 0x0000002c;
  FILE_DEVICE_VIDEO                = 0x00000023;
  FILE_DEVICE_VIRTUAL_DISK         = 0x00000024;
  FILE_DEVICE_WAVE_IN              = 0x00000025;
  FILE_DEVICE_WAVE_OUT             = 0x00000026;

  -- If the file is to be moved to a different volume, the function simulates the move by using the CopyFile and DeleteFile functions.
  -- If the file is successfully copied to a different volume and the original file is unable to be deleted, the function succeeds leaving the source file intact.
  -- This value cannot be used with MOVEFILE_DELAY_UNTIL_REBOOT.
  MOVEFILE_COPY_ALLOWED           = 0x00000002;

  -- Reserved for future use.
  MOVEFILE_CREATE_HARDLINK        = 0x00000010;

  -- The system does not move the file until the operating system is restarted. The system moves the file immediately after AUTOCHK is executed, but before creating any paging files. Consequently, this parameter enables the function to delete paging files from previous startups.
  -- This value can be used only if the process is in the context of a user who belongs to the administrators group or the LocalSystem account.
  -- This value cannot be used with MOVEFILE_COPY_ALLOWED.
  -- Windows Server 2003 and Windows XP:  For information about special situations where this functionality can fail, and a suggested workaround solution, see Files are not exchanged when Windows Server 2003 restarts if you use the MoveFileEx function to schedule a replacement for some files in the Help and Support Knowledge Base.
  MOVEFILE_DELAY_UNTIL_REBOOT     = 0x00000004;


  -- The function fails if the source file is a link source, but the file cannot be tracked after the move. This situation can occur if the destination is a volume formatted with the FAT file system.
  MOVEFILE_FAIL_IF_NOT_TRACKABLE  = 0x00000020;


  -- If a file named lpNewFileName exists, the function replaces its contents with the contents of the lpExistingFileName file, provided that security requirements regarding access control lists (ACLs) are met. For more information, see the Remarks section of this topic.
  -- This value cannot be used if lpNewFileName or lpExistingFileName names a directory.
  MOVEFILE_REPLACE_EXISTING       = 0x00000001;


  -- The function does not return until the file is actually moved on the disk.
  -- Setting this value guarantees that a move performed as a copy and delete operation is flushed to disk before the function returns. The flush occurs at the end of the copy operation.
  -- This value has no effect if MOVEFILE_DELAY_UNTIL_REBOOT is set.
  MOVEFILE_WRITE_THROUGH          = 0x00000008;

  LANG_NEUTRAL                     = 0x00;
  LANG_AFRIKAANS                   = 0x36;
  LANG_ALBANIAN                    = 0x1c;
  LANG_ARABIC                      = 0x01;
  LANG_BASQUE                      = 0x2d;
  LANG_BELARUSIAN                  = 0x23;
  LANG_BULGARIAN                   = 0x02;
  LANG_CATALAN                     = 0x03;
  LANG_CHINESE                     = 0x04;
  LANG_CROATIAN                    = 0x1a;
  LANG_CZECH                       = 0x05;
  LANG_DANISH                      = 0x06;
  LANG_DUTCH                       = 0x13;
  LANG_ENGLISH                     = 0x09;
  LANG_ESTONIAN                    = 0x25;
  LANG_FAEROESE                    = 0x38;
  LANG_FARSI                       = 0x29;
  LANG_FINNISH                     = 0x0b;
  LANG_FRENCH                      = 0x0c;
  LANG_GERMAN                      = 0x07;
  LANG_GREEK                       = 0x08;
  LANG_HEBREW                      = 0x0d;
  LANG_HINDI                       = 0x39;
  LANG_HUNGARIAN                   = 0x0e;
  LANG_ICELANDIC                   = 0x0f;
  LANG_INDONESIAN                  = 0x21;
  LANG_ITALIAN                     = 0x10;
  LANG_JAPANESE                    = 0x11;
  LANG_KOREAN                      = 0x12;
  LANG_LATVIAN                     = 0x26;
  LANG_LITHUANIAN                  = 0x27;
  LANG_MACEDONIAN                  = 0x2f;
  LANG_MALAY                       = 0x3e;
  LANG_NORWEGIAN                   = 0x14;
  LANG_POLISH                      = 0x15;
  LANG_PORTUGUESE                  = 0x16;
  LANG_ROMANIAN                    = 0x18;
  LANG_RUSSIAN                     = 0x19;
  LANG_SERBIAN                     = 0x1a;
  LANG_SLOVAK                      = 0x1b;
  LANG_SLOVENIAN                   = 0x24;
  LANG_SPANISH                     = 0x0a;
  LANG_SWAHILI                     = 0x41;
  LANG_SWEDISH                     = 0x1d;
  LANG_THAI                        = 0x1e;
  LANG_TURKISH                     = 0x1f;
  LANG_UKRAINIAN                   = 0x22;
  LANG_VIETNAMESE                  = 0x2a;

  SUBLANG_NEUTRAL                  = 0x00;    -- language neutral 
  SUBLANG_DEFAULT                  = 0x01;    -- user default 
  SUBLANG_SYS_DEFAULT              = 0x02;    -- system default 

  SUBLANG_ARABIC_SAUDI_ARABIA      = 0x01;    -- Arabic (Saudi Arabia) 
  SUBLANG_ARABIC_IRAQ              = 0x02;    -- Arabic (Iraq) 
  SUBLANG_ARABIC_EGYPT             = 0x03;    -- Arabic (Egypt) 
  SUBLANG_ARABIC_LIBYA             = 0x04;    -- Arabic (Libya) 
  SUBLANG_ARABIC_ALGERIA           = 0x05;    -- Arabic (Algeria) 
  SUBLANG_ARABIC_MOROCCO           = 0x06;    -- Arabic (Morocco) 
  SUBLANG_ARABIC_TUNISIA           = 0x07;    -- Arabic (Tunisia) 
  SUBLANG_ARABIC_OMAN              = 0x08;    -- Arabic (Oman) 
  SUBLANG_ARABIC_YEMEN             = 0x09;    -- Arabic (Yemen) 
  SUBLANG_ARABIC_SYRIA             = 0x0a;    -- Arabic (Syria) 
  SUBLANG_ARABIC_JORDAN            = 0x0b;    -- Arabic (Jordan) 
  SUBLANG_ARABIC_LEBANON           = 0x0c;    -- Arabic (Lebanon) 
  SUBLANG_ARABIC_KUWAIT            = 0x0d;    -- Arabic (Kuwait) 
  SUBLANG_ARABIC_UAE               = 0x0e;    -- Arabic (U.A.E) 
  SUBLANG_ARABIC_BAHRAIN           = 0x0f;    -- Arabic (Bahrain) 
  SUBLANG_ARABIC_QATAR             = 0x10;    -- Arabic (Qatar) 
  SUBLANG_CHINESE_TRADITIONAL      = 0x01;    -- Chinese (Taiwan Region) 
  SUBLANG_CHINESE_SIMPLIFIED       = 0x02;    -- Chinese (PR China) 
  SUBLANG_CHINESE_HONGKONG         = 0x03;    -- Chinese (Hong Kong) 
  SUBLANG_CHINESE_SINGAPORE        = 0x04;    -- Chinese (Singapore) 
  SUBLANG_CHINESE_MACAU            = 0x05;    -- Chinese (Macau) 
  SUBLANG_DUTCH                    = 0x01;    -- Dutch 
  SUBLANG_DUTCH_BELGIAN            = 0x02;    -- Dutch (Belgian) 
  SUBLANG_ENGLISH_US               = 0x01;    -- English (USA) 
  SUBLANG_ENGLISH_UK               = 0x02;    -- English (UK) 
  SUBLANG_ENGLISH_AUS              = 0x03;    -- English (Australian) 
  SUBLANG_ENGLISH_CAN              = 0x04;    -- English (Canadian) 
  SUBLANG_ENGLISH_NZ               = 0x05;    -- English (New Zealand) 
  SUBLANG_ENGLISH_EIRE             = 0x06;    -- English (Irish) 
  SUBLANG_ENGLISH_SOUTH_AFRICA     = 0x07;    -- English (South Africa) 
  SUBLANG_ENGLISH_JAMAICA          = 0x08;    -- English (Jamaica) 
  SUBLANG_ENGLISH_CARIBBEAN        = 0x09;    -- English (Caribbean) 
  SUBLANG_ENGLISH_BELIZE           = 0x0a;    -- English (Belize) 
  SUBLANG_ENGLISH_TRINIDAD         = 0x0b;    -- English (Trinidad) 
  SUBLANG_ENGLISH_ZIMBABWE         = 0x0c;    -- English (Zimbabwe) 
  SUBLANG_ENGLISH_PHILIPPINES      = 0x0d;    -- English (Philippines) 
  SUBLANG_FRENCH                   = 0x01;    -- French 
  SUBLANG_FRENCH_BELGIAN           = 0x02;    -- French (Belgian) 
  SUBLANG_FRENCH_CANADIAN          = 0x03;    -- French (Canadian) 
  SUBLANG_FRENCH_SWISS             = 0x04;    -- French (Swiss) 
  SUBLANG_FRENCH_LUXEMBOURG        = 0x05;    -- French (Luxembourg) 
  SUBLANG_FRENCH_MONACO            = 0x06;    -- French (Monaco) 
  SUBLANG_GERMAN                   = 0x01;    -- German 
  SUBLANG_GERMAN_SWISS             = 0x02;    -- German (Swiss) 
  SUBLANG_GERMAN_AUSTRIAN          = 0x03;    -- German (Austrian) 
  SUBLANG_GERMAN_LUXEMBOURG        = 0x04;    -- German (Luxembourg) 
  SUBLANG_GERMAN_LIECHTENSTEIN     = 0x05;    -- German (Liechtenstein) 
  SUBLANG_ITALIAN                  = 0x01;    -- Italian 
  SUBLANG_ITALIAN_SWISS            = 0x02;    -- Italian (Swiss) 
  SUBLANG_KOREAN                   = 0x01;    -- Korean (Extended Wansung) 
  SUBLANG_KOREAN_JOHAB             = 0x02;    -- Korean (Johab) 
  SUBLANG_LITHUANIAN               = 0x01;    -- Lithuanian 
  SUBLANG_LITHUANIAN_CLASSIC       = 0x02;    -- Lithuanian (Classic) 
  SUBLANG_MALAY_MALAYSIA           = 0x01;    -- Malay (Malaysia) 
  SUBLANG_MALAY_BRUNEI_DARUSSALAM  = 0x02;    -- Malay (Brunei Darussalam) 
  SUBLANG_NORWEGIAN_BOKMAL         = 0x01;    -- Norwegian (Bokmal) 
  SUBLANG_NORWEGIAN_NYNORSK        = 0x02;    -- Norwegian (Nynorsk) 
  SUBLANG_PORTUGUESE               = 0x02;    -- Portuguese 
  SUBLANG_PORTUGUESE_BRAZILIAN     = 0x01;    -- Portuguese (Brazilian) 
  SUBLANG_SERBIAN_LATIN            = 0x02;    -- Serbian (Latin) 
  SUBLANG_SERBIAN_CYRILLIC         = 0x03;    -- Serbian (Cyrillic) 
  SUBLANG_SPANISH                  = 0x01;    -- Spanish (Castilian) 
  SUBLANG_SPANISH_MEXICAN          = 0x02;    -- Spanish (Mexican) 
  SUBLANG_SPANISH_MODERN           = 0x03;    -- Spanish (Modern) 
  SUBLANG_SPANISH_GUATEMALA        = 0x04;    -- Spanish (Guatemala) 
  SUBLANG_SPANISH_COSTA_RICA       = 0x05;    -- Spanish (Costa Rica) 
  SUBLANG_SPANISH_PANAMA           = 0x06;    -- Spanish (Panama) 
  SUBLANG_SPANISH_DOMINICAN_REPUBLIC = 0x07;  -- Spanish (Dominican Republic) 
  SUBLANG_SPANISH_VENEZUELA        = 0x08;    -- Spanish (Venezuela) 
  SUBLANG_SPANISH_COLOMBIA         = 0x09;    -- Spanish (Colombia) 
  SUBLANG_SPANISH_PERU             = 0x0a;    -- Spanish (Peru) 
  SUBLANG_SPANISH_ARGENTINA        = 0x0b;    -- Spanish (Argentina) 
  SUBLANG_SPANISH_ECUADOR          = 0x0c;    -- Spanish (Ecuador) 
  SUBLANG_SPANISH_CHILE            = 0x0d;    -- Spanish (Chile) 
  SUBLANG_SPANISH_URUGUAY          = 0x0e;    -- Spanish (Uruguay) 
  SUBLANG_SPANISH_PARAGUAY         = 0x0f;    -- Spanish (Paraguay) 
  SUBLANG_SPANISH_BOLIVIA          = 0x10;    -- Spanish (Bolivia) 
  SUBLANG_SPANISH_EL_SALVADOR      = 0x11;    -- Spanish (El Salvador) 
  SUBLANG_SPANISH_HONDURAS         = 0x12;    -- Spanish (Honduras) 
  SUBLANG_SPANISH_NICARAGUA        = 0x13;    -- Spanish (Nicaragua) 
  SUBLANG_SPANISH_PUERTO_RICO      = 0x14;    -- Spanish (Puerto Rico) 
  SUBLANG_SWEDISH                  = 0x01;    -- Swedish 
  SUBLANG_SWEDISH_FINLAND          = 0x02;    -- Swedish (Finland) 


  -- The system cannot find the file specified.
  ERROR_FILE_NOT_FOUND                     =     2; -- 0x00000002
  -- The system cannot find the path specified.
  ERROR_PATH_NOT_FOUND                     =     3; -- 0x00000003
  -- Cannot create a file when that file already exists.
  ERROR_ALREADY_EXISTS                     =   183; -- 0x000000B7
}

local function lshift(v, n)
  return math.floor(v * (2 ^ n))
end

local function rshift(v, n)
  return math.floor(v / (2 ^ n))
end

local function FileTimeToTimeT(low, high)
  return math.floor(low / 10000000 + high * (2^32 / 10000000)) - 11644473600;
end

local function TimeTToFileTime(v)
  v = 10000000 * (v + 11644473600)
  local high = rshift(v,32)
  local low  = v - lshift(high, 32)
  return low, high
end

local function LargeToNumber(low, high)
  return low + high * 2^32
end

local function TestBit(flags, flag)
  return (0 ~= bit.band(flags, flag))
end

local function AttributesToStat(fd)
  local flags = fd.dwFileAttributes;
  local ctime = FileTimeToTimeT(fd.ftCreationTime.dwLowDateTime,   fd.ftCreationTime.dwHighDateTime);
  local atime = FileTimeToTimeT(fd.ftLastAccessTime.dwLowDateTime, fd.ftLastAccessTime.dwHighDateTime);
  local mtime = FileTimeToTimeT(fd.ftLastWriteTime.dwLowDateTime,  fd.ftLastWriteTime.dwHighDateTime);
  local size  = LargeToNumber  (fd.nFileSizeLow,                   fd.nFileSizeHigh);

  local mode
  if TestBit(flags, CONST.FILE_ATTRIBUTE_REPARSE_POINT) then mode = "link"
  elseif TestBit(flags, CONST.FILE_ATTRIBUTE_DIRECTORY) then mode = "directory"
  else mode = "file" end

  return{
    mode         = mode;
    nlink        = 1; -- number of hard links to the file
    uid          = 0; -- user-id of owner (Unix only, always 0 on Windows)
    gid          = 0; -- group-id of owner (Unix only, always 0 on Windows)
    ino          = 0;
    access       = atime;
    modification = mtime;
    change       = ctime;
    size         = size;
  }
end

local function FlagsToMode(flags)
  if TestBit(flags, CONST.FILE_ATTRIBUTE_REPARSE_POINT) then return "link" end
  if TestBit(flags, CONST.FILE_ATTRIBUTE_DIRECTORY) then return "directory" end
  return "file"
end

local function AttributesToStat2(fd)
  local flags = fd.dwFileAttributes;
  local ctime = FileTimeToTimeT( fd.ftCreationTime[1],   fd.ftCreationTime[2]   );
  local atime = FileTimeToTimeT( fd.ftLastAccessTime[1], fd.ftLastAccessTime[2] );
  local mtime = FileTimeToTimeT( fd.ftLastWriteTime[1],  fd.ftLastWriteTime[2]  );
  local size  = LargeToNumber  ( fd.nFileSize[1],        fd.nFileSize[2]        );

  local mode = FlagsToMode(flags)

  return{
    mode         = mode;
    nlink        = 1; -- number of hard links to the file
    uid          = 0; -- user-id of owner (Unix only, always 0 on Windows)
    gid          = 0; -- group-id of owner (Unix only, always 0 on Windows)
    ino          = 0;
    access       = atime;
    modification = mtime;
    change       = ctime;
    size         = size;
  }
end

local function clone(t, o)
  if not o then o = {} end
  for k, v in pairs(t) do o[k] = v end
  return o
end

local _M = {}

function _M.currentdir(u)
  return u.GetCurrentDirectory()
end

function _M.attributes(u, P, a)
  --- @todo On Windows systems, represents the drive number of the disk containing the file
  local dev = 0
  --- @todo decode only one attribute if `a` provided
  local attr, err = u.GetFileAttributesEx(P)
  if not attr then return nil, err end
  local stat = AttributesToStat(attr)
  stat.dev, stat.rdev = dev, dev
  if a then return stat[a] end
  return stat
end

function _M.flags(u, P)
  local fd, err = u.GetFileAttributesEx(P)
  if not fd then return nil, err end
  return fd.dwFileAttributes
end

function _M.ctime(u, P)
  local fd, err = u.GetFileAttributesEx(P)
  if not fd then return nil, err end
  return FileTimeToTimeT(fd.ftCreationTime.dwLowDateTime,   fd.ftCreationTime.dwHighDateTime)
end

function _M.atime(u, P)
  local fd, err = u.GetFileAttributesEx(P)
  if not fd then return nil, err end
  return FileTimeToTimeT(fd.ftLastAccessTime.dwLowDateTime, fd.ftLastAccessTime.dwHighDateTime)
end

function _M.mtime(u, P)
  local fd, err = u.GetFileAttributesEx(P)
  if not fd then return nil, err end
  return FileTimeToTimeT(fd.ftLastWriteTime.dwLowDateTime,  fd.ftLastWriteTime.dwHighDateTime)
end

function _M.size(u, P)
  local fd, err = u.GetFileAttributesEx(P)
  if not fd then return nil, err end
  return LargeToNumber  (fd.nFileSizeLow,                   fd.nFileSizeHigh);
end

local function file_not_found(err)
  return (err == CONST.ERROR_FILE_NOT_FOUND) or (err == CONST.ERROR_PATH_NOT_FOUND)
end

function _M.exists(u, P)
  local fd, err = u.GetFileAttributesEx(P)
  if not fd then 
    if file_not_found(err) then return false end
    return nil, err
  end
  return P
end

function _M.isdir(u, P)
  local fd, err = u.GetFileAttributesEx(P)
  if not fd then 
    if file_not_found(err) then return false end
    return nil, err
  end
  if TestBit(fd.dwFileAttributes, CONST.FILE_ATTRIBUTE_REPARSE_POINT) then return false end
  return TestBit(fd.dwFileAttributes, CONST.FILE_ATTRIBUTE_DIRECTORY) and P
end

function _M.isfile(u, P)
  local fd, err = u.GetFileAttributesEx(P)
  if not fd then 
    if file_not_found(err) then return false end
    return nil, err
  end
  if TestBit(fd.dwFileAttributes, CONST.FILE_ATTRIBUTE_REPARSE_POINT) then return false end
  return (not TestBit(fd.dwFileAttributes, CONST.FILE_ATTRIBUTE_DIRECTORY)) and P
end

function _M.islink(u, P)
  local fd, err = u.GetFileAttributesEx(P)
  if not fd then 
    if file_not_found(err) then return false end
    return nil, err
  end
  return TestBit(fd.dwFileAttributes, CONST.FILE_ATTRIBUTE_REPARSE_POINT)
end

function _M.mkdir(u, P)
  local ok, err = u.CreateDirectory(P)
  if not ok then
    -- if err == CONST.ERROR_ALREADY_EXISTS then return false end
    return ok, err
  end
  return ok
end

function _M.rmdir(u, P)
  return u.RemoveDirectory(P)
end

function _M.chdir(u, P)
  return u.SetCurrentDirectory(P)
end

function _M.copy(u, src, dst, force)
  return u.CopyFile(src, dst, not force)
end

function _M.move(u, src, dst, flags)
  if flags == nil then flags = CONST.MOVEFILE_COPY_ALLOWED
  elseif flags == true then flags = CONST.MOVEFILE_COPY_ALLOWED + CONST.MOVEFILE_REPLACE_EXISTING end
  return u.MoveFileEx(src, dst, flags)
end

function _M.remove(u, P)
  return u.DeleteFile(P)
end

function _M.tmpdir(u)
  return u.GetTempPath()
end

function _M.link()
  return nil, "make_link is not supported on Windows";
end

function _M.setmode()
  return nil, "setmode is not supported by this implementation";
end

function _M.dir(u, P)
  local h, fd = u.FindFirstFile(P .. u.DIR_SEP .. u.ANY_MASK)
  if not h then
    local closed = false

    local function close()
      if not closed then
        closed = true
        return
      end
      error("calling 'next' on bad self (closed directory)", 2)
    end
    local next
    if (fd == CONST.ERROR_FILE_NOT_FOUND) or (fd == CONST.ERROR_PATH_NOT_FOUND) then
      next = function()
        if closed then
          error("calling 'next' on bad self (closed directory)", 2)
        end
        close()
      end
    else
      next = function()
        if closed then
          error("calling 'next' on bad self (closed directory)", 2)
        end
        close()
        return nil, fd
      end
    end

    local obj = { close = close; next = next}

    return obj.next, obj
  end

  local closed = false
  local obj = {
    close = function(self)
      if not h then return end
      u.FindClose(h)
      h, closed = nil, true
    end;
    next  = function(self)
      if not h then
        if not closed then
          closed = true
          return
        end
        error("calling 'next' on bad self (closed directory)", 2)
      end
      local fname = u.WIN32_FIND_DATA2TABLE(fd).cFileName
      local ret, err = u.FindNextFile(h, fd)
      if ret == 0 then self:close() closed = false end
      return fname
    end
  }
  return obj.next, obj
end

function _M.touch(u, P, at, mt)
  if not at then at = os.time() end
  if not mt then mt = at end
  local atime = {TimeTToFileTime(at)}
  local mtime = {TimeTToFileTime(mt)}
  local h, err = u.CreateFile(P, 
    CONST.GENERIC_READ + CONST.FILE_WRITE_ATTRIBUTES,
    CONST.FILE_SHARE_READ + CONST.FILE_SHARE_WRITE, nil,
    CONST.OPEN_EXISTING, CONST.FILE_ATTRIBUTE_NORMAL, nil
  )
  if not h then return nil, err end

  local ok, err = u.SetFileTime(h, nil, atime, mtime)
  u.CloseHandle(h)
  if not ok then return nil, err end
  return ok
end

local function findfile(u, P, cb)
  local h, fd = u.FindFirstFile(P)
  if not h then
    if (fd == CONST.ERROR_FILE_NOT_FOUND) or (fd == CONST.ERROR_PATH_NOT_FOUND) then
      -- this is not error but just empty result
      return
    end
    return nil, fd
  end
  repeat
    local ret = cb(fd)
    if ret then
      u.FindClose(h)
      return ret
    end
    ret = u.FindNextFile(h, fd)
  until ret == 0;
  u.FindClose(h)
end

local function isdots(P)
  return P == '.' or P == '..'
    or P == '.\0' or P == '.\0.\0'
end

local function find_last(str, sub)
  local pos = nil
  while true do
    local next_pos = string.find(str, sub, pos, true)
    if not next_pos then return pos end
    pos = next_pos + #sub
  end
end

local function splitpath(P, sep)
  local pos = find_last(P, sep)
  if not pos then return "", P end
  return string.sub(P, 1, pos - #sep - 1), string.sub(P, pos)
end

local foreach_impl
local function do_foreach_recurse(u, base, mask, callback, option)
  return findfile(u, base .. u.DIR_SEP .. u.ANY_MASK, function(fd)
    if not TestBit(fd.dwFileAttributes, CONST.FILE_ATTRIBUTE_DIRECTORY) then return end
    if option.skiplinks and TestBit(fd.dwFileAttributes, CONST.FILE_ATTRIBUTE_REPARSE_POINT) then return end
    fd = u.WIN32_FIND_DATA2TABLE(fd)
    if isdots(fd.cFileName) then return end
    return foreach_impl(u, base .. u.DIR_SEP .. fd.cFileName, mask, callback, option)
  end)
end

foreach_impl = function (u, base, mask, callback, option)
  local path = base .. u.DIR_SEP
  if option.recurse and option.reverse then
    local res, err = do_foreach_recurse(u, base, mask, callback, option)
    if res or err then return res, err end
  end

  local tmp, origin_cb
  if option.delay then
    tmp, origin_cb, callback = {}, callback, function(base,name,fd) 
      table.insert(tmp, {base,name,fd})
    end;
  end

  local ok, err = findfile(u, path .. mask, function(fd)
    local isdir = TestBit(fd.dwFileAttributes, CONST.FILE_ATTRIBUTE_DIRECTORY)
    if isdir then if option.skipdirs then return end
    else if option.skipfiles then return end end

    fd = u.WIN32_FIND_DATA2TABLE(fd)
    if isdir and option.skipdots ~= false and isdots(fd.cFileName) then
      return
    end

    return callback(base, fd.cFileName, fd)
  end)

  if ok or err then return ok, err end

  if option.delay then
    for _, t in pairs(tmp) do
      local ok, err = origin_cb(t[1], t[2], t[3])
      if ok or err then return ok, err end
    end
  end

  if option.recurse and not option.reverse then
    local res, err = do_foreach_recurse(u, base, mask, origin_cb or callback, option)
    if res or err then return res, err end
  end

end

function _M.foreach(u, base, callback, option)
  local base, mask = splitpath(base, u.DIR_SEP)
  if mask == '' then mask = u.ANY_MASK end
  return foreach_impl(u, base, mask, function(base, name, fd)
    return callback(base .. u.DIR_SEP .. name, AttributesToStat2(fd))
  end, option or {})
end

local attribs = {
  f = function(u, base, name, fd) return base..u.DIR_SEP..name                  end;
  p = function(u, base, name, fd) return base                                   end;
  n = function(u, base, name, fd) return name                                   end;
  m = function(u, base, name, fd) return FlagsToMode(fd.dwFileAttributes)       end;
  a = function(u, base, name, fd) return AttributesToStat2(fd)                  end;
  z = function(u, base, name, fd) return LargeToNumber  ( fd.nFileSize[1],        fd.nFileSize[2]        ) end;
  t = function(u, base, name, fd) return FileTimeToTimeT( fd.ftLastWriteTime[1],  fd.ftLastWriteTime[2]  ) end;
  c = function(u, base, name, fd) return FileTimeToTimeT( fd.ftCreationTime[1],   fd.ftCreationTime[2]   ) end;
  l = function(u, base, name, fd) return FileTimeToTimeT( fd.ftLastAccessTime[1], fd.ftLastAccessTime[2] ) end;
}

local function make_attrib(str)
  local t = {}
  for i = 1, #str do 
    local ch = str:sub(i,i)
    local fn = attribs[ ch ]
    if not fn then return nil, 'unknown file attribute: ' .. ch end
    table.insert(t, fn)
  end

  return function(...)
    local res = {n = #t}
    for i, f in ipairs(t) do
      local ok, err = f(...)
      if ok == nil then return nil, err end
      table.insert(res, ok)
    end
    return res
  end
end

function _M.each_impl(u, option)
  if not option.file then return nil, 'no file mask present' end
  local base, mask = splitpath( option.file, u.DIR_SEP )
  if mask == '' then mask = u.ANY_MASK end

  local get_params, err = make_attrib(option.param or 'f')
  if not get_params then return nil, err end
  local unpack = unpack or table.unpack

  local filter = option.filter

  if option.callback then
    local callback = option.callback 

    local function cb(base, name, path, fd)
      local params = assert(get_params(u, base, name, path, fd))
      if filter and (not filter(unpack(params, 1, params.n))) then return end
      return callback(unpack(params, 1, params.n))
    end

    return foreach_impl(u, base, mask, cb, option)
  else
    local function cb(base, name, path, fd)
      local params = assert(get_params(u, base, name, path, fd))
      if filter and (not filter(unpack(params, 1, params.n))) then return end
      coroutine.yield(params)
    end
    local co = coroutine.create(function()
      foreach_impl(u, base, mask, cb, option)
    end)
    return function()
      local status, params = coroutine.resume(co)
      if status then if params then return unpack(params, 1, params.n) end
      else error(params, 2) end
    end
  end
end

local create_each = require "path.findfile".load

local LOADED = {}
local function load(ltype, sub)
  local M = LOADED[ltype .. "/" .. sub]
  if M then return M end
  local IMPL  = require("path.win32." .. ltype ..".fs")[sub]
  M = {
    CONST = CONST;
    DIR_SEP = IMPL.DIR_SEP;
  }
  for k, v in pairs(_M) do
    if type(v) ~= "function" then M[k] = v 
    else M[k] = function(...) return v(IMPL, ...) end end
  end
  local each_impl = _M.each_impl
  M.each = create_each(function(...) return each_impl(IMPL, ...) end)

  LOADED[ltype .. "/" .. sub] = M
  return M
end

return {
  load = load
}
