cordova.define("cordova-plugin-wristbands.B6B7Wristbands", function(require, exports, module) {
               var exec = require('cordova/exec');
               
               exports.setDevice = function (success, error, model, deviceId, command, backgroundTracking) {
               exec(success, error, 'WristbandsPlugin', 'setDevice', [model, deviceId, command, backgroundTracking]); }
               });

