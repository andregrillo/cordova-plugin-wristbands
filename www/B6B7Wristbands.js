               var exec = require('cordova/exec');
               
               exports.setDevice = function (success, error, model, deviceId, command, url, timer) {
               exec(success, error, 'WristbandsPlugin', 'setDevice', [model, deviceId, command, url, timer]); }

