               var exec = require('cordova/exec');
               
               exports.setDevice = function (success, error, model, deviceId, command, url) {
               exec(success, error, 'WristbandsPlugin', 'setDevice', [model, deviceId, command, url]); }

