#!/bin/bash


# colors
RED="$(tput setaf 196)$(tput bold)"
GREEN="$(tput setaf 71)$(tput bold)"
YELLOW="$(tput setaf 214)$(tput bold)"
RESET="$(tput init)"


# retrieve the server's certificate if you don't already have it
#
# be sure to examine the certificate to see if it is what you expected
#
# Windows-specific:
# - Use NUL instead of /dev/null.
# - OpenSSL may wait for input instead of disconnecting. Hit enter.
# - If you don't have sed, then just copy the certificate into a file:
#   Lines from -----BEGIN CERTIFICATE----- to -----END CERTIFICATE-----.
#


BUILD_ROOT=$(git rev-parse --show-toplevel)
function pause(){
   read -p "${YELLOW}$*${RESET}"
}


# fetch version
echo -e "${YELLOW}current version: ${XXT_VERSION}${RESET}"


# generate new certificate
read -sp 'Password: ' PASSWORD
echo ""
echo -e "${GREEN}generate new RSA...${RESET}"
openssl genrsa -des3 -passout "pass:${PASSWORD}" -out "${BUILD_ROOT}/certs/versions/private.pem" 2048

openssl rsa -in "${BUILD_ROOT}/certs/versions/private.pem" -out "${BUILD_ROOT}/certs/versions/private_unencrypted.pem" -outform PEM -passin "pass:${PASSWORD}"; cat "${BUILD_ROOT}/certs/versions/private_unencrypted.pem"
pause 'Press [Enter] key to copy private key...'
cat "${BUILD_ROOT}/certs/versions/private_unencrypted.pem" | pbcopy

openssl rsa -in "${BUILD_ROOT}/certs/versions/private.pem" -outform PEM -pubout -out "${BUILD_ROOT}/certs/versions/public.pem" -passin "pass:${PASSWORD}"; cat "${BUILD_ROOT}/certs/versions/public.pem"
pause 'Press [Enter] key to copy public key...'
cat "${BUILD_ROOT}/certs/versions/public.pem" | pbcopy

XXT_API_SALT=$(uuidgen)
echo "${XXT_API_SALT}"
pause 'Press [Enter] key to copy salt...'
echo "${XXT_API_SALT}" | pbcopy


# send request to license server
pause 'Press [Enter] key to continue...'
echo -e "${GREEN}generate SSL certificate hash...${RESET}"
DOMAIN="api.xxtou.ch"
openssl s_client -servername "${DOMAIN}" -connect "${DOMAIN}:443" < /dev/null | sed -n "/-----BEGIN/,/-----END/p" > "${BUILD_ROOT}/certs/${DOMAIN}.pem"
openssl x509 -in "${BUILD_ROOT}/certs/${DOMAIN}.pem" -pubkey -noout > "${BUILD_ROOT}/certs/${DOMAIN}.pubkey.pem"
openssl asn1parse -noout -inform pem -in "${BUILD_ROOT}/certs/${DOMAIN}.pubkey.pem" -out "${BUILD_ROOT}/certs/${DOMAIN}.pubkey.der"


# update license.h
echo -e "${GREEN}update license.h...${RESET}"
HASH=$(openssl dgst -sha256 -binary "${BUILD_ROOT}/certs/${DOMAIN}.pubkey.der" | openssl base64)

cat > "${BUILD_ROOT}/shared/include/license.h" << __EOF__
#ifndef license_h
#define license_h

#import <Foundation/Foundation.h>
#import "cacert.pem.h"
#define CACERT_PATH "/usr/local/xxtouch/lib/ssl/curl-ca-bundle.crt"


/* SECURE_SERVER_HASH//BEGIN */
static const char *XXT_API_SALT = "${XXT_API_SALT}";
#define XXT_SSL_HASH "sha256//${HASH}"
__EOF__

echo "#define XXT_RSA_PUBLIC_KEY \\" >> "${BUILD_ROOT}/shared/include/license.h"
while read -r line; do echo "\"$line\\n\" \\" >> "${BUILD_ROOT}/shared/include/license.h"; done < "${BUILD_ROOT}/certs/versions/public.pem"
echo "\"\"" >> "${BUILD_ROOT}/shared/include/license.h"

cat >> "${BUILD_ROOT}/shared/include/license.h" << __EOF__
/* SECURE_SERVER_HASH//END */

#endif /* license_h */

__EOF__

