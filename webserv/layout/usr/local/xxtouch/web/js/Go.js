/** 
 * Created by Administrator on 2015/6/15. 
 */  
(function($) {  
    $(document).ready(function() {  
        var url = decodeURI(window.location.href);  
        var index = url.indexOf('?');  
        if (index < 0) {  
            return;  
        }  
        var parameters = {};  
        var entrys = url.substring(++index, url.length).split('&');  
        for (var i = 0, len = entrys.length; i < len; i++) {  
            var entry = entrys[i].split('=');  
            parameters[entry[0]] = entry[1];  
        }  
        $.data(document, 'parameters', parameters);  
    });  
    $.jump = function(url, params) {  
        var entrys = [];  
        for(var i in params) {  
            entrys.push(i + '=' + params[i]);  
        }  
        if (!entrys.length) {  
            window.location.href = encodeURI(url);  
            return;  
        }  
        window.location.href = encodeURI(url + '?' + entrys.join('&'));  
        //window.open(encodeURI(url + '?' + entrys.join('&')));
    }  
    $.req = function(key) {  
        var parameters = $.data(document, 'parameters');  
        return parameters === undefined ? undefined : parameters[key];  
    }  
})(jQuery);  