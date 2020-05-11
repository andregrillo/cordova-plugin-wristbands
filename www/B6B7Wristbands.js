               var exec = require('cordova/exec');
               
               exports.setDevice = function (success, error, model, deviceId, command, backgroundTracking) {
               exec(success, error, 'WristbandsPlugin', 'setDevice', [model, deviceId, command, backgroundTracking]); }

