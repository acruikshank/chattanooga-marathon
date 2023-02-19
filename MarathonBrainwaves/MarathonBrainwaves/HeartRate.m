//
//  HeartRate.m
//  MarathonBrainwaves
//
//  Created by Lance Brackett on 2/18/23.
//  Copyright © 2023 Alex Cruikshank. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "HeartRate.h"
#import "RRValues.h"

#define TIMER_SCAN_INTERVAL    2.0
#define DEVICE_NAME   @"Polar H10 BD487724"
#define DEVICE_IDENTIFIER @"C337ED9F-B1E6-CB9B-36B3-6BDDF7ADAC0E"
#define HR_SERVICE @"180D"
#define HR_CHARACTERISTIC @"2A37"

@implementation HeartRate

- (instancetype)initWithName:(NSString *)name {
    self = [super init];
    if (self) {
      self.centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil options:nil];
      self.rrValues = [[RRValues alloc]initWithSize:200];
      self.deviceName = name;
      self.connected = false;
    }
    return self;
}

- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    if (central.state == CBManagerStatePoweredOn) {
        [central scanForPeripheralsWithServices:@[[CBUUID UUIDWithString:@"180D"]] options:nil];
    }
}

// Looking for: Polar H10 BD487724 connectable: true address: A02701D8-DA45-6916-2EEE-815F3FB31530

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI {
  if ([peripheral.name hasSuffix:self.deviceName]){
    NSLog(@"CONNECTING TO DEVICE...%@", peripheral.name);
    [central stopScan];
    self.peripheral = peripheral;
    self.peripheral.delegate = self;
    [self.centralManager connectPeripheral:self.peripheral options:nil];
      
  } else {
    NSLog(@"IGNORING DEVICE: %@", peripheral.name);
  }
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    NSLog(@"**** SUCCESSFULLY CONNECTED TO POLAR DEVICE");
    [peripheral discoverServices:nil];
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    NSLog(@"**** CONNECTION FAILED");
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
  if ([peripheral.name hasSuffix:self.deviceName]) {
    self.connected = false;
  }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    for (CBService *service in peripheral.services) {
        NSLog(@"Discovered service: %@", service);
        NSString *uuidString = [service.UUID UUIDString];
        NSLog(@"UUID STRING: %@", uuidString);
        if ([service.UUID isEqual:[CBUUID UUIDWithString:@"180D"]]) {
            [peripheral discoverCharacteristics:nil forService:service];
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
  for (CBCharacteristic *characteristic in service.characteristics) {
    uint8_t enableValue = 1;
    NSData *enableBytes = [NSData dataWithBytes:&enableValue length:sizeof(uint8_t)];
    NSLog(@"CHARACTERISTIC: %@", characteristic);

    if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:HR_CHARACTERISTIC]]) {
      _notifyCharacteristic = characteristic;
      self.connected = true;
      [self.peripheral setNotifyValue:YES forCharacteristic:characteristic];
    }
  }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    if (error) {
        NSLog(@"Error changing notification state: %@", [error localizedDescription]);
    } else {
      if (characteristic == _notifyCharacteristic){
        UInt16 value = 0;
        UInt8 heartRate = 0;
        [characteristic.value getBytes:&heartRate range:NSMakeRange(1, 1)];
        for (NSUInteger i = 2; i < characteristic.value.length; i += 2) {
          [characteristic.value getBytes:&value range:NSMakeRange(i, 2)];
          NSLog(@"RRVALUE: %d", value);
          
          [self.rrValues appendValue:[NSNumber numberWithInt:value]];
        }
        self.heartRate = heartRate;
        self.hsv = [self.rrValues standardDeviation] / 1024.0;
        NSLog(@"HR: %d   HRV: %f", heartRate, self.hsv);
      };
    }
}
@end
