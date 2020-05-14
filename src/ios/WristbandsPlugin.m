//
//  WristbandsPlugin.m
//
//  Created by Andre Grillo on 02/05/2020.
//  Copyright © 2020 Andre Grillo. All rights reserved.
//

#import <Cordova/CDV.h>
#import "MinewBeaconManager.h"
#import "MinewBeacon.h"
#import "MinewBeaconManager.h"
#import <CoreBluetooth/CoreBluetooth.h>
#import <UserNotifications/UserNotifications.h>

#define defaultUUID @"FDA50693-A4E2-4FB1-AFCF-C6EB07647825"

@interface WristbandsPlugin : CDVPlugin <MinewBeaconManagerDelegate, CBCentralManagerDelegate, UNUserNotificationCenterDelegate> {
}
@property (nonatomic, strong) CDVInvokedUrlCommand* commandHelper;
@property (nonatomic, strong) CDVPluginResult* pluginResult;
@property (nonatomic, strong) CDVInvokedUrlCommand* pluginCommand;
- (void)setDevice:(CDVInvokedUrlCommand*)command;
@end

@implementation WristbandsPlugin {
    NSTimer *timerDelay;
    BOOL pluginInitialized;
    int timer;
    NSString *postURL;
    NSMutableDictionary *returnJSONParameters;
    NSArray * scannedDevices;
    MinewBeaconManager *beaconManager;
    CBCentralManager *centralManager;
    //Plugin Inputs
    NSString *wristbandModel;
    NSString *trackedBeacon;
    NSString *wristbandCommand;
//    BOOL backgroudTracking;
    BOOL bluetoothON;
    BOOL beaconInRange;
    float distance;
}

- (void)setDevice:(CDVInvokedUrlCommand*)command
{
    pluginInitialized = NO;
    self.pluginResult = nil;
    [self.pluginResult setKeepCallbackAsBool:YES];

    self.commandHelper = command;
    //Plugin Inputs
    
    //Checking if parameters are valid
    wristbandModel = [command.arguments objectAtIndex:0];
    if (wristbandModel == nil || [wristbandModel length] == 0) {
        self.pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"wristBandModel input parameter cannot be empty"];
        [self.commandDelegate sendPluginResult:self.pluginResult callbackId:self.commandHelper.callbackId];
    } else {
        NSLog(@"> WristbandModel: %@", wristbandModel);
    }
    
    trackedBeacon = [command.arguments objectAtIndex:1];
    if (trackedBeacon == nil || [trackedBeacon length] == 0) {
        self.pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"trackedBeacon input parameter cannot be empty"];
        [self.commandDelegate sendPluginResult:self.pluginResult callbackId:self.commandHelper.callbackId];
    } else {
        NSLog(@"> TrackedBeacon: %@", trackedBeacon);
    }
    
    wristbandCommand = [command.arguments objectAtIndex:2];
    if (wristbandCommand == nil || [wristbandCommand length] == 0) {
        self.pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"command input parameter cannot be empty"];
        [self.commandDelegate sendPluginResult:self.pluginResult callbackId:self.commandHelper.callbackId];
    } else {
        NSLog(@"> Command: %@", wristbandCommand);
    }
    
    postURL = [command.arguments objectAtIndex:3];
    if (postURL == nil || [postURL length] == 0) {
        self.pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"URL input parameter cannot be empty"];
        [self.commandDelegate sendPluginResult:self.pluginResult callbackId:self.commandHelper.callbackId];
    } else {
        NSLog(@"> PostURL: %@", postURL);
    }
    
    NSString *timerString = [command.arguments objectAtIndex:4];
    if (timerString == nil || [timerString length] == 0) {
        self.pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Timer input parameter cannot be empty"];
        [self.commandDelegate sendPluginResult:self.pluginResult callbackId:self.commandHelper.callbackId];
    } else {
            timer = [timerString intValue];
            NSLog(@"> Timer: %i", timer);
    }
    
    //Let's make it run...
    if ([wristbandCommand isEqualToString:@"init"]) {
        [self initialize];
    }
    else if ([wristbandCommand isEqualToString:@"start"]) {
        [self startScan];
    }
    else if ([wristbandCommand isEqualToString:@"stop"]) {
        [self stopScan];
    }
    else if ([wristbandCommand isEqualToString:@"setDelegate"]) {
        [self setDelegate];
    }
    else {
        //No valid command parameter
        self.pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Invalid command input value"];
        [self.commandDelegate sendPluginResult:self.pluginResult callbackId:self.commandHelper.callbackId];
        [self.pluginResult setKeepCallbackAsBool:YES];
    }
}

- (void)setDelegate {
    pluginInitialized = NO;
    centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
    beaconManager = [MinewBeaconManager sharedInstance];
    beaconManager.delegate = self;
    NSLog(@"Set Beacon SDK Delegate OK");
    
    //Sending a local notification if in background (just for testing). Should be removed from the final plugin.
    UNUserNotificationCenter* center = [UNUserNotificationCenter currentNotificationCenter];
    [center requestAuthorizationWithOptions:(UNAuthorizationOptionAlert + UNAuthorizationOptionSound)
                          completionHandler:^(BOOL granted, NSError * _Nullable error) {
                              // Enable or disable features based on authorization.

                                if (!error) {
                                    NSLog(@"Notification Authorization OK");
                                }
                          }];
    [[UIApplication sharedApplication] registerForRemoteNotifications]; // you can also set here for local notification.


    UNMutableNotificationContent* content = [[UNMutableNotificationContent alloc] init];
    content.title = [NSString localizedUserNotificationStringForKey:@"WOHOOO! 😎" arguments:nil];
    content.body = [NSString localizedUserNotificationStringForKey:@"The set delegate Method got fired!"
                arguments:nil];
    content.sound = [UNNotificationSound defaultSound];

    // Deliver the notification
    UNTimeIntervalNotificationTrigger* trigger = [UNTimeIntervalNotificationTrigger
                triggerWithTimeInterval:1 repeats:NO];
    UNNotificationRequest* request = [UNNotificationRequest requestWithIdentifier:@"setDelegateAlert"
                content:content trigger:trigger];

    // Schedule the notification.
    UNUserNotificationCenter* notificationCenter = [UNUserNotificationCenter currentNotificationCenter];
    [notificationCenter addNotificationRequest:request withCompletionHandler:nil];
    
    self.pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"iOS SDK Delegate initialized"];
    [self.pluginResult setKeepCallbackAsBool:YES];
    [self.commandDelegate sendPluginResult:self.pluginResult callbackId:self.commandHelper.callbackId];
}

- (void)initialize {
    NSLog(@">>> Plugin initialization");
    beaconInRange = NO;
    distance = 0;
    returnJSONParameters = [[NSMutableDictionary alloc] initWithCapacity:8 ];
//    trackedBeacon = @"ac233f61e8c0";
    
    //Starting the SDK
//    centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
//    beaconManager = [MinewBeaconManager sharedInstance];
//    beaconManager.delegate = self;
    [self setDelegate];
    pluginInitialized = YES;
    NSLog(@">>> Wristband Plugin Initialized");
    self.pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"Plugin initialized"];
    [self.pluginResult setKeepCallbackAsBool:YES];
    [self.commandDelegate sendPluginResult:self.pluginResult callbackId:self.commandHelper.callbackId];
}

- (void)startScan {
    NSLog(@">>> Start Scan");
    beaconManager.delegate = self;
    
    //Checks initial bluetooth status and then starts scanning
    bluetoothON = [centralManager state] == CBManagerStatePoweredOn;
    if (bluetoothON) {
        [beaconManager startScan:@[defaultUUID] backgroundSupport:YES];
        NSLog(@">>> Wristband Plugin: Started Scanning");
        timerDelay = [NSTimer scheduledTimerWithTimeInterval:timer target:self selector:@selector(sendJson2REST) userInfo:nil repeats:YES];
        self.pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"Started Scanning"];
        [self.pluginResult setKeepCallbackAsBool:YES];
        [self.commandDelegate sendPluginResult:self.pluginResult callbackId:self.commandHelper.callbackId];
    } else {
        NSLog(@">>> Cannot start Scanning. Bluetooth is OFF.");
        self.pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Cannot start Scanning. Bluetooth is OFF."];
        [self.pluginResult setKeepCallbackAsBool:YES];
        [self.commandDelegate sendPluginResult:self.pluginResult callbackId:self.commandHelper.callbackId];
    }
}

- (void)stopScan {
    NSLog(@">>> Stop Scan");
    [timerDelay invalidate];
    timerDelay = nil;
    [[MinewBeaconManager sharedInstance] stopScan];
    scannedDevices = nil;
    
    if (!bluetoothON) {
        NSLog(@">>> Wristband Plugin: Stopped Scanning. Bluetooth OFF");
        self.pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Stopped Scanning because Bluetooth is OFF"];
        [self.pluginResult setKeepCallbackAsBool:YES];
        [self.commandDelegate sendPluginResult:self.pluginResult callbackId:self.commandHelper.callbackId];
    } else {
        NSLog(@">>> Wristband Plugin: Stopped Scanning.");
        self.pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"Stopped Scanning"];
        [self.pluginResult setKeepCallbackAsBool:YES];
        [self.commandDelegate sendPluginResult:self.pluginResult callbackId:self.commandHelper.callbackId];

    }
}


- (void)sendJson2REST {
    
    // Preparing the JSON
    NSError *error;
    if (returnJSONParameters.count == 0) {
        //time stamp
        NSDate *now = [NSDate date];
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateFormat:@"dd-MM-yyyy HH:mm:ss"];
        [returnJSONParameters setObject:[NSString stringWithFormat:@"%@", [dateFormatter stringFromDate:now]] forKey:@"timeStamp"];
        [returnJSONParameters setObject:trackedBeacon forKey:@"mac"];
        [returnJSONParameters setObject:[NSNumber numberWithBool:NO] forKey:@"range"];
        
    }
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:returnJSONParameters options:NSJSONWritingPrettyPrinted error:&error];
    if (!jsonData && error) {
        NSLog(@"Error serializing JSON Object: %@", [error localizedDescription]);
    }
    NSString *postString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    NSLog(@">>> PostString: %@",postString);
    
    // Posting it to the REST URL
//    postURL = @"https://atc-dev.outsystemsenterprise.com/HomeQuarantine_Care_API/rest/Wristband/ReceiveWristbandInfo";
    
//    NSLog(@">>> URL: %@", postURL);
    
    NSURL *url=[NSURL URLWithString:postURL];
    NSMutableURLRequest *request=[[NSMutableURLRequest alloc]initWithURL:url];
    [request setHTTPMethod:@"POST"];
    [request addValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setHTTPBody:jsonData];
    
    NSURLSessionConfiguration *defaultConfigObject = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration: defaultConfigObject delegate: nil delegateQueue: [NSOperationQueue mainQueue]];
    
    NSURLSessionTask *task=[session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error)
                            {
        if (error==nil) {
            NSDictionary *dicData=[NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];\
            NSLog(@">>> Response Data: %@",dicData);
        }
        else{
            NSLog(@">>> Error posting jsonData: %@", error.localizedDescription);
        }
    }];
    [task resume];
}

#pragma mark ********************************** Device Manager Delegate Methods
- (void)minewBeaconManager:(MinewBeaconManager *)manager didRangeBeacons:(NSArray<MinewBeacon *> *)beacons
{
    [returnJSONParameters removeAllObjects];
    
    if (bluetoothON){
//        beaconInRange = YES;
        
        @synchronized (self)
            {
                scannedDevices = [beacons copy];

                for (int i = 0; i < beacons.count; i++) {
                    MinewBeacon *beacon = beacons[i];
                    NSString *mac = [beacon getBeaconValue:BeaconValueIndex_Mac].stringValue;
                    //Checks if it's the monitored beacon
                    if ([trackedBeacon isEqualToString:mac]){
                        
                        //RSSI
                        int rssi = (int)[beacon getBeaconValue:BeaconValueIndex_RSSI].intValue;
                        [returnJSONParameters setObject:[NSNumber numberWithInt:rssi] forKey:@"rssi"];
                        
                        // Distance
                        float powered = (-59.0f-(float)rssi)/20.0;
                        distance = powf(10, powered);
                        [returnJSONParameters setObject:[NSNumber numberWithFloat:distance] forKey:@"distance"];
                        
                        // UUID address
                        NSString *uuid = [beacon getBeaconValue:BeaconValueIndex_UUID].stringValue;
                        [returnJSONParameters setObject:[NSString stringWithFormat:@"%@",uuid] forKey:@"uuid"];
                        
                        // In Range
//                        NSInteger inRangeInt = (long)[beacon getBeaconValue:BeaconValueIndex_InRage].boolValue;
//                        NSString* inRange;
//                        if (inRangeInt == 1) {
//                            inRange = @"YES";
//                        } else {
//                            inRange =@"NO";
//                        }
                        //[returnJSONParameters setObject:[NSString stringWithFormat:@"%@",inRange] forKey:@"inRange"];
                        
                        if (beaconInRange) {
                            [returnJSONParameters setObject:[NSNumber numberWithBool:beaconInRange] forKey:@"range"];
                        } else {
                            [returnJSONParameters setObject:[NSNumber numberWithBool:beaconInRange] forKey:@"range"];
                        }
                        
                        // mac
                        NSString *mac = [beacon getBeaconValue:BeaconValueIndex_Mac].stringValue;
                        [returnJSONParameters setObject:[NSString stringWithFormat:@"%@",mac] forKey:@"mac"];
                        
                        // major
                        int major = (int)[beacon getBeaconValue:BeaconValueIndex_Major].intValue;
                        [returnJSONParameters setObject:[NSNumber numberWithInt:major] forKey:@"major"];
                        
                        // minor
                        int minor = (int)[beacon getBeaconValue:BeaconValueIndex_Minor].intValue;
                        [returnJSONParameters setObject:[NSNumber numberWithInt:minor] forKey:@"minor"];
                        
                        // battery
                        int battery = (int)[beacon getBeaconValue:BeaconValueIndex_BatteryLevel].intValue;
                        [returnJSONParameters setObject:[NSNumber numberWithInt:battery] forKey:@"battery"];
                        
                        //time stamp
                        NSDate *now = [NSDate date];
                        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
                        [dateFormatter setDateFormat:@"dd-MM-yyyy HH:mm:ss"];
                        [returnJSONParameters setObject:[NSString stringWithFormat:@"%@", [dateFormatter stringFromDate:now]] forKey:@"timeStamp"];
                        
//                        NSLog(@"%@",returnJSONParameters);
                        
                        // Returns the JSON to Cordova
                        NSError * error;
                        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:returnJSONParameters options:NSJSONWritingPrettyPrinted error:&error];
                        if (!jsonData && error) {
                            NSLog(@"Error serializing JSON Object: %@", [error localizedDescription]);
                        }
                        NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
//                        NSLog(@"%@",jsonString);
                        
                        self.pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:jsonString];
                        [self.pluginResult setKeepCallbackAsBool:YES];
                        [self.commandDelegate sendPluginResult:self.pluginResult callbackId:self.commandHelper.callbackId];
                    }
                }
            }
    } else {
        //Bluetooth is OFF
        beaconInRange = NO;
        self.pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Bluetooth is OFF"];
        [self.pluginResult setKeepCallbackAsBool:YES];
        [self.commandDelegate sendPluginResult:self.pluginResult callbackId:self.commandHelper.callbackId];
    }
}

- (void)minewBeaconManager:(MinewBeaconManager *)manager appearBeacons:(NSArray<MinewBeacon *> *)beacons
{
    for (int i = 0; i < beacons.count; i++) {
        //Checks if it's the monitored beacon
        MinewBeacon *beacon = beacons[i];
        NSString *mac = [beacon getBeaconValue:BeaconValueIndex_Mac].stringValue;
        if ([trackedBeacon isEqualToString:mac]){
            beaconInRange = YES;
        }
        NSLog(@">>> Appeared beacons:%@", beacons);
    }
}

- (void)minewBeaconManager:(MinewBeaconManager *)manager disappearBeacons:(NSArray<MinewBeacon *> *)beacons
{
    for (int i = 0; i < beacons.count; i++) {
        //Checks if it's the monitored beacon
        MinewBeacon *beacon = beacons[i];
        NSString *mac = [beacon getBeaconValue:BeaconValueIndex_Mac].stringValue;
        if ([trackedBeacon isEqualToString:mac]){
            beaconInRange = NO;
        }
    }
    NSLog(@">>> Disappeared beacons: %@", beacons);
}


#pragma mark ********************************** CBCentralManagerDelegate Methods (Bluetooth)

- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
   if ([central state] == CBManagerStatePoweredOff) {
       NSLog(@">>> Bluetooth is OFF");
       bluetoothON = NO;
       beaconInRange = NO;
       [self stopScan];
       self.pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Bluetooth OFF"];
       [self.pluginResult setKeepCallbackAsBool:YES];
       [self.commandDelegate sendPluginResult:self.pluginResult callbackId:self.commandHelper.callbackId];
       
   }
   else if ([central state] == CBManagerStatePoweredOn) {
       NSLog(@">>> Bluetooth is ON");
       bluetoothON = YES;
       if (pluginInitialized) {
        [self startScan];
       }
       self.pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"Bluetooth ON"];
       [self.pluginResult setKeepCallbackAsBool:YES];
       [self.commandDelegate sendPluginResult:self.pluginResult callbackId:self.commandHelper.callbackId];
   }
}

@end
