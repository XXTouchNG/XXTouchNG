-- 简介: samba 是一个基于 KxSMBClient 的 SMB 客户端 Lua 扩展, 由于精力有限, 尚未编写协程支持.


-- 创建一个新的 SMB 客户端.
smbclient = samba.client {
    workgroup = "WORKGROUP",
    username = 'guest',
    password = 'mypassword123'
}


-- 列出指定目录内容
tab, err = smbclient:list('smb://WORKGROUP/Documents/JSTColorPicker')

-- 示例返回
tab, err = {  -- table: 0x105f56e50
     [1] = {  -- table: 0x105f56f30
          modification = 1654506149.0,  -- 最后修改时间戳
          name = "TagList.sqlite-wal",  -- 文件名
          path = "smb://WORKGROUP/Documents/JSTColorPicker/TagList.sqlite-wal",  -- 文件完整路径
          size = 74192,  -- 文件尺寸
          type = "file",  -- 类型
          access = 1654533327.0,  -- 最后访问时间戳
          mode = 33252,
          creation = 1654506149.0,  -- 创建时间戳
     },
     [2] = {  -- table: 0x105f56fd0
          modification = 1656912977.0,
          name = "TagList.sqlite-shm",
          path = "smb://WORKGROUP/Documents/JSTColorPicker/TagList.sqlite-shm",
          size = 32768,
          type = "file",
          access = 1656912977.0,
          mode = 33252,
          creation = 1656913376.0,
     },
     [3] = {  -- table: 0x105f57030
          modification = 1648479813.0,
          name = "TagList-Passport.plist",
          path = "smb://WORKGROUP/Documents/JSTColorPicker/TagList-Passport.plist",
          size = 24365,
          type = "file",
          access = 1657128964.0,
          mode = 33252,
          creation = 1650208834.0,
     },
     [4] = {  -- table: 0x105f57280
          modification = 1647704196.0,
          name = "TagList-UI.plist",
          path = "smb://WORKGROUP/Documents/JSTColorPicker/TagList-UI.plist",
          size = 2514,
          type = "file",
          access = 1657128964.0,
          mode = 33252,
          creation = 1649782735.0,
     },
     [5] = {  -- table: 0x105934000
          modification = 1654505287.0,
          name = "TagList.sqlite",
          path = "smb://WORKGROUP/Documents/JSTColorPicker/TagList.sqlite",
          size = 45056,
          type = "file",
          access = 1654505287.0,
          mode = 33252,
          creation = 1654505287.0,
     },
}, nil


-- 创建指定目录
tab, err = smbclient:mkdir('smb://WORKGROUP/Documents/JSTColorPicker/test_dir')

-- 示例返回
tab, err = {  -- table: 0x1059a7d30
     modification = 1657130592.0,
     name = "test_dir",
     path = "smb://WORKGROUP/Documents/JSTColorPicker/test_dir",
     size = 0,
     type = "dir",
     access = 1657130592.0,
     mode = 16877,
     creation = 1657130592.0,
}, nil


-- 创建空白文件
succeed, err = smbclient:touch('smb://WORKGROUP/Documents/JSTColorPicker/test_dir/aaa')

-- 示例返回
succeed, err = true, nil


-- 删除指定文件或目录 (不支持非空目录)
succeed, err = smbclient:remove('smb://WORKGROUP/Documents/JSTColorPicker/test_dir')

-- 示例返回 (非空目录)
succeed, err = false, "SMB Directory not empty"


-- 删除指定目录 (支持递归删除非空目录)
succeed, err = smbclient:rmdir('smb://WORKGROUP/Documents/JSTColorPicker/test_dir')

-- 示例返回
succeed, err = true, nil


-- 重命名指定文件或目录
succeed, err = smbclient:rename('smb://WORKGROUP/Documents/JSTColorPicker/.DS_Store', 'smb://WORKGROUP/Documents/JSTColorPicker/DS_Store')

-- 示例返回
succeed, err = true, nil


-- 下载指定文件或目录 (支持递归下载整个目录)
smbclient:download('smb://WORKGROUP/Documents/JSTColorPicker', 'JSTColorPicker')  -- 本地路径支持相对路径和绝对路径


-- 上传指定文件或目录 (支持递归上传整个目录)
smbclient:upload('plugins', 'smb://WORKGROUP/Documents/plugins')
