<p align="center">

<img width="128" alt="icon-256" src="https://user-images.githubusercontent.com/5410705/177363260-e44a5e57-19d9-4dea-bc3e-fa069c302717.png">

</p>

<h1 align="center">XXTouchNG</h1>

<p align="center">Next generation XXTouch for iOS 13 and 14. Rewritten in Objective-C.</p>


## What’s XXTouch/XXTouchNG?

XXTouch was a system wide touch event simulation and automation tool (jailbreak required).

我的英语荒废太久，如果让我以真心撰写一大段话颇耗精力，所以还是拿中文写吧。

XXTouch 曾是一款模拟截取屏幕和模拟点击事件来实现 iOS 自动化的应用软件（需要越狱）。但是由于其部分功能（如修改地理位置），对目标进程实施了注入，被中华人民共和国的司法鉴定机构认定为“外挂”一类性质的软件。2018 年中，我们团队经某地法院判决，没收了全部收入，并且分别获刑三年至六年不等的有期徒刑。我因为认罪态度良好，上缴全部收入并且缴纳了一笔不菲的罚金，所以得以缓期执行。

近年来，随着“净网行动”的开展，不少类似性质的软件都遭到了不同程度的打击，例如叉叉助手、大牛助手、NZT 等等。这些软件无一例外的，都含有“注入”这一技术实施细节。而这，也是一款软件被认定为“外挂”的重要标准之一。

首先，“注入”这一行为，违规访问并且修改了了目标应用的内存空间，侵犯了目标应用所有者的软件著作权。其次，这类自动化工具给黑色产业链提供了技术上的支撑，并且获得了非法收入。

然而，当初作为大学刚毕业的我，在参与到 XXTouch 开发的时候，只负责其 UI 部分的编写，并没有深刻认识到这一点。我当时坚持认为，*XXTouch 只是一款自动化工具，而非传统意义上的“外挂”，就算使用我们工具的人进行了违法犯罪，和我们应该也没有什么关系。* 现在看来，当初的想法确实有些天真。

因为这件事，我深刻地见证了中国互联网从野蛮生长，到逐渐有序的过程。

**技术是一把双刃剑，使用不当，可能将自己带入深渊。** 

我希望通过这次开源，能够促进公众，尤其是刚刚步入社会、步入程序员行业的年轻同行们，对于这一行业法律责任的认知。如果看到这个页面的在座各位，还有在编写非法爬虫、外挂，为违法犯罪提供有偿技术支撑的，请停下你们的键盘，想一想可能会付出的代价。快播如此，乌云如此，XXTouch 更是如此，**请君牢记**。

我大概花了 2 个多月的时间来重写 XXTouch，将其取名为 XXTouchNG，一是为了了解它的技术实现细节，二是为了借此机会了我自己一个心结。如果 XXTouch 不“注入”他人进程，或者不以侵害他人著作权来盈利，它仍旧是一款很有乐趣的软件。“快捷指令”的限制太多，对于很多喜欢折腾的朋友来说，越狱一下自己的 iPhone，编写一些小脚本来实现一些小任务，是很有成就感的。

_注意，本应用程序基于 AGPLv3 协议发布，仅用于学习和交流目的。本开源软件包含“注入”行为，如果因为安装、使用本软件及其衍生物所造成的一切后果，需要你自行承担。_

最后，致“南山必胜客”。你们作为中文互联网真正的顶流，希望能够以更高的水平，更公正的方式，让中国乃至世界的互联网发展得更加美好，而不是只会反复依靠国家机器，施加着不对等的制裁。窝里横很自豪吗？我言尽于此。


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
libsimulatetouch.h
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

- **IMPORTANT**: Remove `~/theos/vendor/include/openssl` because we shipped another version of OpenSSL in this repo
- **IMPORTANT**: Edit `~/theos/makefiles/common.mk`, then append line `export THEOS_OBJ_DIR` to a good place
- Edit your `~/.zshrc` and ensure `THEOS_DEVICE_IP` is set

```bash
$ env
THEOS=$HOME/theos
THEOS_DEVICE_IP=192.168.2.151
```


## Build

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

```bash
$ make package FINALPACKAGE=1
```


## Usage

#### User Manual (Chinese Only)

- [XXTouch iOS 使用入门](https://www.zybuluo.com/xxtouch/note/378784)
- [XXTouch 常见问题答疑](https://www.zybuluo.com/xxtouch/note/712055)


#### Documentation (Chinese Only)

- [Lua 5.3 Manual](https://cloudwu.github.io/lua53doc/manual.html)
- [XXTouch iOS 开发手册](https://www.zybuluo.com/xxtouch/note/370734)
- [XXTouchBook](https://github.com/XXTouchNG/XXTouchBook)


## Credits

XXTouchNG uses codes from many open-source projects. Part of them were listed in [submodules](https://github.com/XXTouchNG/XXTouchNG/tree/main/ext/submodules).


## License

See [LICENSE](https://github.com/XXTouchNG/XXTouchNG/blob/main/LICENSE).
