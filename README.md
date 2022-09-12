<p align="center">

<img width="128" alt="icon-256" src="https://user-images.githubusercontent.com/5410705/177363260-e44a5e57-19d9-4dea-bc3e-fa069c302717.png">

</p>

<h1 align="center">XXTouchNG</h1>

<p align="center">Next generation XXTouch for iOS 13 and 14. Rewritten in Objective-C.</p>


## What’s XXTouch/XXTouchNG?

XXTouch was a system wide touch event simulation and automation tool (jailbreak required).


## Features

#### Lua Core

- [x] extension of os, print
- [x] sys.log, nLog
- [x] screen, image
- [x] touch, key, accelerometer
- [x] sys, device
- [x] pasteboard, proc
- [x] app
- [x] thread
- [x] extension of table, string
- [x] http, ftp
- [x] json, plist, file
- [x] utils
- [x] other extensions
- [ ] dialog, webview
- [ ] clear
- [ ] xpp, xui


#### Lua Modules

- [x] `alert`, Automation module for `UIAlertViewController`.
- [x] `appstore`, Automation module for `AuthKit`.
- [x] `monkey`, Automation module for `WKWebView`.
- [x] `cookies`
- [x] `samba`


#### App Features

- [x] **Full Featured Recording**
- [x] [Full Featured App](https://github.com/XXTouchNG/XXTExplorer)
- [x] [OpenAPI](https://www.zybuluo.com/xxtouch/note/386268)
- [x] Startup Script
- [x] Daemon Mode
- [x] OCR Support (Provided by Apple’s `Vision.framework`)
- [x] Template Matching (Provided by `OpenCV`)
- [x] Activator Support


#### XPC Services

```bash
$ ls /usr/local/include/lib*
libdeviceconfigurator.h  libsupervisor.h
libprocqueue.h           libtfcontainermanager.h
libscreencapture.h       libtfcookiesmanager.h
libsimulatetouch.h       libauthpolicy.h
```


#### OpenAPI Protocols

- [x] Legacy XXTouch
- [x] TouchSprite (触动精灵协议)
- [x] TouchElf & Cloud API (触摸精灵及其云控协议)


#### Debugger Support

- [x] VSCode
- [x] [LuaPanda](https://github.com/Tencent/LuaPanda)
- [x] [XXTouch-VSCode-Debugger](https://github.com/XXTouchNG/XXTouch-VSCode-Debugger)


#### IDE Support

- [x] VSCode
- [x] [XXTouch-VSCode-Plugin](https://github.com/XXTouchNG/XXTouch-VSCode-Plugin)


## Prepare Your Device

- iOS 13 or 14
- Jailbreak it with [unc0ver](https://unc0ver.dev/) or [checkra1n](https://checkra.in/)
- Install [dependencies](https://github.com/XXTouchNG/XXTouchNG/blob/main/dependencies/dependencies.txt) with your favorite package manager
- `ssh-copy-id`


## Prepare Your Mac

- Xcode 12 (required)
- VSCode (recommended)

```bash
$ xcode-select -p
/Applications/Xcode-12.5.1.app/Contents/Developer
```

- Install [theos](https://github.com/theos/theos) with its submodules

```bash
$ ls ~/theos
CODE_OF_CONDUCT.md bin                makefiles          templates
LICENSE.md         extras             mod                toolchain
Prefix.pch         include            package.json       vendor
README.md          lib                sdks
```

- [theos/sdks](https://github.com/theos/sdks)
- [theos/headers](https://github.com/theos/headers)

```bash
$ ls ~/theos/sdks | wc -l
      16
$ ls ~/theos/vendor/include | wc -l
     110
```

- **IMPORTANT**: Remove `~/theos/vendor/include/openssl` because we shipped another version of OpenSSL with this repo
- **IMPORTANT**: Edit `~/theos/makefiles/common.mk`, then **append a new line** `export THEOS_OBJ_DIR` here:

```makefile
ifeq ($(THEOS_CURRENT_ARCH),)
THEOS_OBJ_DIR = $(_THEOS_LOCAL_DATA_DIR)/$(THEOS_OBJ_DIR_NAME)
else
THEOS_OBJ_DIR = $(_THEOS_LOCAL_DATA_DIR)/$(THEOS_OBJ_DIR_NAME)/$(THEOS_CURRENT_ARCH)
endif
export THEOS_OBJ_DIR  # <- append this line
```

- Edit your `~/.zshrc` and ensure `THEOS_DEVICE_IP` is set

```bash
$ env
THEOS=$HOME/theos
THEOS_DEVICE_IP=192.168.2.151
```


## Build

#### Clone Repo

You need to `git clone` this repo instead of download a zipped archive of it!

```bash
$ git lfs install  # if you do not have Git LFS yet
$ git clone --recursive git@github.com:XXTouchNG/XXTouchNG.git
```


#### Build Only

```bash
$ make
```

#### Build Package

```bash
$ make package
```

#### Install Package

```bash
$ make install
```

#### Build & Install

```bash
$ make do
```

#### Build Release

To build a final release, you need to:

- Clone and configure [XXTExplorer](https://github.com/XXTouchNG/XXTExplorer) in Xcode
- Prepare a valid `Apple Development` or `Developer ID` certificate
- Edit `Makefile` and set `TARGET_CODESIGN_CERT` to your certificate
- Run following commands:

```bash
$ make explorer FINALPACKAGE=1
$ make package FINALPACKAGE=1
```


## Usage

#### User Manual & Documentation (Chinese Only)

- [Lua 5.3 Manual](https://cloudwu.github.io/lua53doc/manual.html)
- [XXTouchBook](https://xxtouchng.github.io/)


## Credits

XXTouchNG uses codes from many open-source projects. Part of them were listed in [submodules](https://github.com/XXTouchNG/XXTouchNG/tree/main/ext/submodules).


## License

See [LICENSE](https://github.com/XXTouchNG/XXTouchNG/blob/main/LICENSE).
