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

#define defaultUUID @"FDA50693-A4E2-4FB1-AFCF-C6EB07647825"

@interface WristbandsPlugin : CDVPlugin <MinewBeaconManagerDelegate, CBCentralManagerDelegate> {
}
//@property (nonatomic, strong) NSString *callbackId;
@property (nonatomic, strong) CDVInvokedUrlCommand* commandHelper;
@property (nonatomic, strong) CDVPluginResult* pluginResult;
@property (nonatomic, strong) CDVInvokedUrlCommand* pluginCommand;
- (void)setDevice:(CDVInvokedUrlCommand*)command;
@end

@implementation WristbandsPlugin {
    NSMutableDictionary *returnJSONParameters;
    NSArray * scannedDevices;
    MinewBeaconManager *beaconManager;
    CBCentralManager *centralManager;
    //Plugin Inputs
    NSString *wristbandModel;
    NSString *trackedBeacon;
    NSString *wristbandCommand;
    BOOL backgroudTracking;
    BOOL bluetoothON;
    BOOL beaconInRange;
    float distance;
}

- (void)setDevice:(CDVInvokedUrlCommand*)command
{
    self.pluginResult = nil;
    [self.pluginResult setKeepCallback:[NSNumber numberWithBool:YES]];
//    self.callbackId = command.callbackId;
    self.commandHelper = command;
    //Plugin Inputs
    
    //Checking if parameters are valid
    wristbandModel = [command.arguments objectAtIndex:0];
    if (wristbandModel == nil || [wristbandModel length] == 0) {
        self.pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"wristBandModel parameter cannot be empty"];
        [self.commandDelegate sendPluginResult:self.pluginResult callbackId:self.commandHelper.callbackId];
    }
    
    trackedBeacon = [command.arguments objectAtIndex:1];
    if (trackedBeacon == nil || [trackedBeacon length] == 0) {
        self.pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"trackedBeacon parameter cannot be empty"];
        [self.commandDelegate sendPluginResult:self.pluginResult callbackId:self.commandHelper.callbackId];
    }
    
    wristbandCommand = [command.arguments objectAtIndex:2];
    if (wristbandCommand == nil || [wristbandCommand length] == 0) {
        self.pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"command parameter cannot be empty"];
        [self.commandDelegate sendPluginResult:self.pluginResult callbackId:self.commandHelper.callbackId];
    }
    
    if ([[command.arguments objectAtIndex:3] isEqualToString:@"yes"]) {
        backgroudTracking = YES;
    } else if ([[command.arguments objectAtIndex:3] isEqualToString:@"no"]) {
        backgroudTracking = NO;
    } else {
        self.pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Invalid backgroundTracking input value"];
        [self.commandDelegate sendPluginResult:self.pluginResult callbackId:self.commandHelper.callbackId];
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
    else {
        //No valid command parameter
        self.pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Invalid command input value"];
        [self.commandDelegate sendPluginResult:self.pluginResult callbackId:self.commandHelper.callbackId];
    }

}

- (void)initialize {
    NSLog(@">>> Plugin initialization");
    beaconInRange = NO;
    distance = 0;
    returnJSONParameters = [[NSMutableDictionary alloc] initWithCapacity:8 ];
//    trackedBeacon = @"ac233f61e8c0";
    
    //Starting the SDK
    centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
    beaconManager = [MinewBeaconManager sharedInstance];
    beaconManager.delegate = self;
    
    NSLog(@">>> Wristband Plugin Initialized");
    self.pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"Plugin initialized"];
    [self.commandDelegate sendPluginResult:self.pluginResult callbackId:self.commandHelper.callbackId];
//    [self.pluginResult setKeepCallback:[NSNumber numberWithBool:YES]];
}

- (void)startScan {
    NSLog(@">>> Start Scan");
    beaconManager.delegate = self;
    
    //Checks initial bluetooth status and then starts scanning
    bluetoothON = [centralManager state] == CBManagerStatePoweredOn;
    if (bluetoothON) {
//        [self startScan];
        
        [beaconManager startScan:@[defaultUUID] backgroundSupport:backgroudTracking];
        NSLog(@">>> Wristband Plugin: Started Scanning");
        self.pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"Started Scanning"];
        [self.commandDelegate sendPluginResult:self.pluginResult callbackId:self.commandHelper.callbackId];
    }
}

- (void)stopScan {
    NSLog(@">>> Stop Scan");
    [[MinewBeaconManager sharedInstance] stopScan];
    scannedDevices = nil;
    
    if (!bluetoothON) {
        NSLog(@">>> Wristband Plugin: Stopped Scanning. Bluetooth OFF");
        self.pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Stopped Scanning because Bluetooth is OFF"];
        [self.commandDelegate sendPluginResult:self.pluginResult callbackId:self.commandHelper.callbackId];
    } else {
        NSLog(@">>> Wristband Plugin: Stopped Scanning.");
        self.pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"Stopped Scanning"];
        [self.commandDelegate sendPluginResult:self.pluginResult callbackId:self.commandHelper.callbackId];
    }
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
                    //Verifica se o beacon monitorado (uuid) está próximo
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
                        
                        NSLog(@"%@",returnJSONParameters);
                        
                        // Returns the JSON
                        NSError * error;
                        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:returnJSONParameters options:0 error:&error];
                        NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
                        
                        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:jsonString];
                        [self.commandDelegate sendPluginResult:pluginResult callbackId:self.commandHelper.callbackId];
                    }
                }
            }
    } else {
    	//Bluetooth is OFF
        beaconInRange = NO;
        self.pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Bluetooth is OFF"];
        [self.commandDelegate sendPluginResult:self.pluginResult callbackId:self.commandHelper.callbackId];
    }
    
}

- (void)minewBeaconManager:(MinewBeaconManager *)manager appearBeacons:(NSArray<MinewBeacon *> *)beacons
{
    for (int i = 0; i < beacons.count; i++) {
        //Verifica se é o beacon monitorado (uuid)
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
        //Verifica se é o beacon monitorado (uuid)
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
       
       self.pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Bluetooth is OFF"];
       [self.commandDelegate sendPluginResult:self.pluginResult callbackId:self.commandHelper.callbackId];
       
   }
   else if ([central state] == CBManagerStatePoweredOn) {
       NSLog(@">>> Bluetooth is ON");
       bluetoothON = YES;
       //TRATAR ISSO!!!! Crash no inicio da app
       [self startScan];
   }
}

@end
