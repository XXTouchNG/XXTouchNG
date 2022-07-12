var className = "AAUISignInController";
var funcName = "- setServiceType:";
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
        var serviceType = ObjC.Object(args[2]);
 
        console.log("className: " + className.toString());
        console.log("methodName: " + methodName.readUtf8String());
        console.log("serviceType: " + serviceType.toString());  // com.apple.AppleID.Service.Store
        console.log("-----------------------------------------");

        console.log('called from:\n' +
        Thread.backtrace(this.context, Backtracer.ACCURATE).map(DebugSymbol.fromAddress).join('\n') + '\n');
        console.log("-----------------------------------------");
    }
});

var rootCtrl = ObjC.classes.UIApplication.sharedApplication().keyWindow().rootViewController();

var navCtrl = ObjC.classes.AAUISignInController.new();
navCtrl.setUsername_('i.82@outlook.com');
navCtrl.setCanEditUsername_(false);
navCtrl.setServiceType_('com.apple.AppleID.Service.Store');

var signCtrl = navCtrl['- _signInViewController']();
var nextItem = signCtrl['- _nextBarButtonItem']();

ObjC.schedule(ObjC.mainQueue, function () {
    rootCtrl.presentViewController_animated_completion_(navCtrl, true, ptr(0x0));
});
