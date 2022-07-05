$(document).ready(function() {
    $("#main-drawer a[href='./upgrade.html']").addClass("mdui-list-item-active");
    $.post("/deviceinfo", "", function(data) {
        if (data.code == 0) {
            $("#zeversion").html(data.data.zeversion)
        } else {
            mdui.snackbar({
                message: data.message
            })
        }
    }, "json").error(function() {
        mdui.snackbar({
            message: "与设备通讯无法达成"
        })
    });
    $("#choose_file_upgrade").click(function() {
        var fileinput = $('<input type="file" style="display:none" name="upload"/>');
        fileinput.change(function(e) {
            up_file(e.target.files)
        });
        fileinput.click()
    });
    var dropbox = document.getElementById("dropbox");
    document.addEventListener("dragenter", function(e) {
        dropbox.style.borderColor = "gray"
    }, false);
    document.addEventListener("dragleave", function(e) {
        dropbox.style.borderColor = "silver"
    }, false);
    dropbox.addEventListener("dragenter", function(e) {
        dropbox.style.borderColor = "gray";
        dropbox.style.backgroundColor = "white"
    }, false);
    dropbox.addEventListener("dragleave", function(e) {
        dropbox.style.backgroundColor = "transparent"
    }, false);
    dropbox.addEventListener("dragenter", function(e) {
        e.stopPropagation();
        e.preventDefault()
    }, false);
    dropbox.addEventListener("dragover", function(e) {
        e.stopPropagation();
        e.preventDefault()
    }, false);
    dropbox.addEventListener("drop", function(e) {
        e.stopPropagation();
        e.preventDefault();
        handleFiles(e.dataTransfer.files)
    }, false);

    function arrayBufferToBase64(buffer) {
        var binary = "";
        var bytes = new Uint8Array(buffer);
        var len = bytes.byteLength;
        for (var i = 0; i < len; i++) {
            binary += String.fromCharCode(bytes[i])
        }
        return window.btoa(binary)
    }

    function base64ToArrayBuffer(base64) {
        var binary_string = window.atob(base64);
        var len = binary_string.length;
        var bytes = new Uint8Array(len);
        for (var i = 0; i < len; i++) {
            bytes[i] = binary_string.charCodeAt(i)
        }
        return bytes.buffer
    }

    function timeoutrun() {
        $.post("/deviceinfo", "", function(data) {
            if (data.code == 0) {
                $("#zeversion").html(data.data.zeversion)
            } else {
                mdui.snackbar({
                    message: data.message
                })
            }
            $("#bform").show();
            $("#display-message").hide()
        }, "json").error(function() {
            setTimeout(timeoutrun, 3000)
        })
    }

    function up_file(files) {
        var _file = files[0];
        $("#display-message").hide();
        $("#bform").hide();
        $("#display-uploaded").show();
        var filesize = _file.size;
        var fileloaded = 0;
        var reader = new FileReader();
        reader.readAsBinaryString(_file);
        reader.onload = function() {
            if (!XMLHttpRequest.prototype.sendAsBinary) {
                XMLHttpRequest.prototype.sendAsBinary = function(datastr) {
                    function byteValue(x) {
                        return x.charCodeAt(0) & 255
                    }
                    var ords = Array.prototype.map.call(datastr, byteValue);
                    var ui8a = new Uint8Array(ords);
                    this.send(ui8a.buffer)
                }
            }
            var xhr = new XMLHttpRequest();
            xhr.open("POST", "install_deb");
            xhr.overrideMimeType("application/octet-stream");
            xhr.sendAsBinary(this.result);
            xhr.onreadystatechange = function() {
                if (xhr.readyState == 4) {
                    if (xhr.status == 200) {
                        var obj = JSON.parse(xhr.responseText);
                        if (obj.code == 0) {
                            $("#bform").hide();
                            $("#display-uploaded").hide();
                            $("#display-message").show();
                            setTimeout(timeoutrun, 10000)
                        } else {
                            $("#display-uploaded").hide();
                            $("#bform").show();
                            mdui.snackbar({
                                message: obj.message
                            })
                        }
                    } else {
                        $("#display-uploaded").hide();
                        $("#bform").show();
                        mdui.snackbar({
                            message: "出现一个错误"
                        })
                    }
                }
            }
        }
    }
    handleFiles = function(files) {
        up_file(files)
    }
});