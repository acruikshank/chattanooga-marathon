//
//  HeartRate.h
//  MarathonBrainwaves
//
//  Created by Lance Brackett on 2/18/23.
//  Copyright © 2023 Alex Cruikshank. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import "RRValues.h"

@interface HeartRate: NSObject

@property (nonatomic, strong) CBCentralManager *centralManager;
@property (nonatomic, strong) CBPeripheral *peripheral;
@property (nonatomic) CBCharacteristicProperties *characteristicProperties;
@property (nonatomic, strong) NSMutableArray<CBPeripheral *> *discoveredPeripherals;
@property (nonatomic, strong) CBCharacteristic *notifyCharacteristic;
@property (nonatomic, strong) RRValues *rrValues;
@property (nonatomic, strong) NSString *deviceName;


@property (nonatomic, assign) BOOL keepScanning;

- (instancetype)initWithName: (NSString *)name;

@end
