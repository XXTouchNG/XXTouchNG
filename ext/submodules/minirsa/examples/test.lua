-- 跨平台编译指令 (脚本作者无需关心)
-- gcc -arch i386 -arch x86_64 -O3 -std=c99 -Iinclude -c -o minirsa64.o minirsa.c && gcc -arch i386 -arch x86_64 -LmacOS -lcrypto -O3 -Wl,-segalign,4000 -framework Foundation -bundle -undefined dynamic_lookup -o minirsa.so minirsa64.o && mv minirsa.so macOS && rm -rf *.o
-- xcrun -sdk iphoneos gcc -arch armv7 -miphoneos-version-min=7.0 -O3 -std=c99 -Iinclude -c -o minirsa.o minirsa.c && xcrun -sdk iphoneos gcc -arch armv7 -LiOS -lcrypto -miphoneos-version-min=7.0 -O3 -Wl,-segalign,4000 -framework Foundation -framework UIKit -bundle -undefined dynamic_lookup -o minirsa.so minirsa.o && mv minirsa.so iOS && rm -rf *.o && ldid -S iOS/minirsa.so

-- 生成 RSA 私钥
-- openssl genrsa -out rsa_private_key.pem 1024
-- 生成 RSA 公钥
-- openssl rsa -in rsa_private_key.pem -pubout -out rsa_public_key.pem

local rsa = require "minirsa"
local RSA_PUBLIC_FILE = io.open("rsa_public_key.pem", "r")
local RSA_PUBLIC_KEY = RSA_PUBLIC_FILE:read("*a")
RSA_PUBLIC_FILE:close()
local RSA_PRIV_FILE = io.open("rsa_private_key.pem", "r")
local RSA_PRIV_KEY = RSA_PRIV_FILE:read("*a")
RSA_PRIV_FILE:close()

alert = print
if dialog then
	alert = dialog
end
if sys and sys.alert then
	alert = sys.alert
end

alert('-----公钥加密私钥解密 start------')
local str = '12345611'
local encryptPubStr = rsa.public_encrypt(str, RSA_PUBLIC_KEY)
if not encryptPubStr then
	print('pub encrypt failed')
end
local decryptPriStr = rsa.private_decrypt(encryptPubStr, RSA_PRIV_KEY)
if not decryptPriStr then
	print('pri decrypt failed')
end
alert('公钥加密私钥解密成功\n'..decryptPriStr)
alert('-----公钥加密私钥解密 end------')

alert('================================')

alert('-----私钥加密公钥解密 start------')
local str='12345611'
local encryptPriStr = rsa.private_encrypt(str, RSA_PRIV_KEY)
if not encryptPriStr then
	alert('pri encrypt failed')
end
local decryptPubStr = rsa.public_decrypt(encryptPriStr, RSA_PUBLIC_KEY)
if not decryptPubStr then
	alert('pub decrypt failed')
end
alert('私钥加密公钥解密成功\n'..decryptPubStr)
alert('-----私钥加密公钥解密 end------')
