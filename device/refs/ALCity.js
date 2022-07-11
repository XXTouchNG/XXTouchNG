var className = "PSGDateTimeController";
var funcName = "- setTimeZoneValue:specifier:";
var hook = eval('ObjC.classes.' + className + '["' + funcName + '"]');
Interceptor.attach(hook.implementation, {
    onLeave: function(/* retval */) {
        console.log("[*] Class Name: " + className);
        console.log("[*] Method Name: " + funcName);
        // console.log("\t[-] Type of return value: " + typeof retval);
        // console.log("\t[-] Original Return Value: " + retval);
    },
    onEnter: function(args) {
        var className = ObjC.Object(args[0]);
        var methodName = args[1];
        var timeZoneValue = ObjC.Object(args[2]);
        var specifier = ObjC.Object(args[3]);
 
        console.log("className: " + className.toString());
        console.log("methodName: " + methodName.readUtf8String());
        console.log("timeZoneValue: " + timeZoneValue.toString());
        console.log("specifier: " + specifier.toString());
        console.log("-----------------------------------------");

        console.log('called from:\n' +
        Thread.backtrace(this.context, Backtracer.ACCURATE).map(DebugSymbol.fromAddress).join('\n') + '\n');
        console.log("-----------------------------------------");
    }
});

var hookCity = Module.findExportByName(null, "PSCityForTimeZone")
Interceptor.attach(hookCity, {
    onEnter: function(args) {
        console.log("timezone: " + ObjC.Object(args[0]).toString());
    },
    onLeave: function(retval) {
        console.log("_PSCityForTimeZone: " + ObjC.Object(retval).toString());
    },
});