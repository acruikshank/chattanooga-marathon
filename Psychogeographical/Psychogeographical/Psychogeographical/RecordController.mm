//
//  RecordController.m
//  Psychogeographical
//
//  Created by Alex Cruikshank on 11/5/16.
//  Copyright © 2016 Alex Cruikshank. All rights reserved.
//

#import "RecordController.h"
#import <edk_ios/Iedk.h>
#import <CoreLocation/CoreLocation.h>
#import "STHTTPRequest.h"
#import <MobileCoreServices/MobileCoreServices.h>

typedef struct SensorReading
{
  NSTimeInterval lastReading;
  double value;
  
} SensorReading;

BOOL isConnected = NO;


IEE_DataChannel_t ChannelList[] = {
  IED_AF3, IED_AF4, IED_T7, IED_T8, IED_Pz
};

const char header[] = "Time, Theta AF3,Alpha AF3,Low beta AF3,High beta AF3, Gamma AF3, Theta AF4,Alpha AF4,Low beta AF4,High beta AF4, Gamma AF4, Theta T7,Alpha T7,Low beta T7,High beta T7, Gamma T7, Theta T8,Alpha T8,Low beta T8,High beta T8, Gamma T8, Theta Pz,Alpha Pz,Low beta Pz,High beta Pz, Gamma Pz,Lat,Lon, Altitude,Climb Rate,GSR,Skin Temp,Heart Rate,RR Interval";

const char *newLine = "\n";
const char *comma = ",";
const int SAMPLE_SIZE = 26;
const int BUFFER_SIZE = 1200;

@interface RecordController ()

@property (nonatomic, retain) NSString *deviceName;
@property (nonatomic, retain) NSString *session;
@property (nonatomic, retain) CLLocationManager *locationManager;
@property (nonatomic, retain) NSFileHandle *file;
@property (nonatomic, retain) MSBClient *bandClient;
@property (nonatomic, retain) NSDateFormatter *clockFormat;

@end

@implementation RecordController
EmoEngineEventHandle eEvent;
EmoStateHandle eState;

unsigned int userID	= 0;
float secs = 1;
bool readytocollect = false;
bool recording = false;
int state = 0;
int currentPointer = 0;

SensorReading altimeterChange;
SensorReading altimeterRate;
SensorReading gsrResistance;
SensorReading skinTemperature;
SensorReading heartRate;
SensorReading rrInterval;

CLLocationCoordinate2D currentLocation;
Float64 buffer[SAMPLE_SIZE*BUFFER_SIZE];
Float64 scratchBuffer[SAMPLE_SIZE*BUFFER_SIZE];

NSMutableData *data;

- (void)viewDidLoad {
  [super viewDidLoad];
  eEvent	= IEE_EmoEngineEventCreate();
  eState	= IEE_EmoStateCreate();
  
  IEE_EmoInitDevice();
  NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
                                                       NSUserDomainMask,
                                                       YES);
  documentDirectory = [paths lastObject];
  
  name_channel = [[NSArray alloc]initWithObjects:@"AF3",@"AF4",@"T7",@"T8",@"Pz", nil];
  IEE_EmoInitDevice();
  if( IEE_EngineConnect("Emotiv Systems-5") != EDK_OK ) {
    self.status.text = @"Can't connect engine";
  }
  
  //IEE_MotionDataSetBufferSizeInSec(secs);
  self.recordButton.alpha = 0.0;
  
  [[MSBClientManager sharedManager] setDelegate:self];
  NSArray *attachedClients = [[MSBClientManager sharedManager]
                              attachedClients];
  MSBClient *client = [attachedClients firstObject];
  if (client) {
    [[MSBClientManager sharedManager] connectClient:client];
  }
  
  [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(getNextEvent) userInfo:nil repeats:YES];
  
  
  self.clockFormat = [[NSDateFormatter alloc] init];
  self.clockFormat.dateStyle = NSDateFormatterNoStyle;
  self.clockFormat.timeStyle = NSDateFormatterMediumStyle;
  [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(updateClock) userInfo:nil repeats:YES];
  
  [self startLocationUpdates];
}

-(void) getNextEvent {
  int numberDevice = IEE_GetInsightDeviceCount();
  if(numberDevice > 0 && !isConnected) {
    IEE_ConnectInsightDevice(0);
    NSString *name = [[NSString alloc] initWithCString:(const char *)IEE_GetInsightDeviceName(0) encoding:NSASCIIStringEncoding];
    self.deviceName = [self parseSerialFromName:name];
    NSLog(@"Connected %@", self.deviceName);
    isConnected = YES;
  }
  else isConnected = NO;
  int state = IEE_EngineGetNextEvent(eEvent);
  unsigned int userID = 0;
  
  if (state == EDK_OK)
  {
    
    IEE_Event_t eventType = IEE_EmoEngineEventGetType(eEvent);
    IEE_EmoEngineEventGetUserId(eEvent, &userID);
    
    // Log the EmoState if it has been updated
    if (eventType == IEE_UserAdded)
    {
      
      NSLog(@"User Added");
      IEE_FFTSetWindowingType(userID, IEE_HANN);
      self.status.text = [NSString stringWithFormat:@"Emotive Connected:\n %@", self.deviceName];
      readytocollect = TRUE;
      self.recordButton.alpha = 1.0;
    }
    else if (eventType == IEE_UserRemoved)
    {
      NSLog(@"User Removed");
      isConnected = NO;
      self.status.text = @"Emotive Disconnected";
      readytocollect = FALSE;
      self.recordButton.alpha = 0.0;
    }
    else if (eventType == IEE_EmoStateUpdated)
    {
      
    }
  }
  if (readytocollect)
  {
    double value[26];
    memset(value, 0, 26*sizeof(double));
    int overallResult = EDK_OK;
    
    value[0] = [[NSDate date] timeIntervalSince1970];
    for(int i=0 ; i< sizeof(ChannelList)/sizeof(IEE_DataChannel_t) ; ++i)
    {
      int result = IEE_GetAverageBandPowers(userID, ChannelList[i], &value[i*5+1], &value[i*5+2], &value[i*5+3], &value[i*5+4], &value[i*5+5]);
      overallResult = fmax(overallResult, result);
    }
    
    if(overallResult == EDK_OK && recording){
      for(int j =0; j < 26; j++){
        if (j > 0)
          [self saveStr:self.file data:data value:comma];
        [self saveDoubleVal:self.file data:data value:value[j]];
      }
      [self saveStr:self.file data:data value:comma];
      [self saveDoubleVal:self.file data:data value:currentLocation.latitude];
      [self saveStr:self.file data:data value:comma];
      [self saveDoubleVal:self.file data:data value:currentLocation.longitude];
      [self saveStr:self.file data:data value:comma];
      [self saveNSStr:self.file data:data value:[self sensorValue:altimeterChange]];
      [self saveStr:self.file data:data value:comma];
      [self saveNSStr:self.file data:data value:[self sensorValue:altimeterRate]];
      [self saveStr:self.file data:data value:comma];
      [self saveNSStr:self.file data:data value:[self sensorValue:gsrResistance]];
      [self saveStr:self.file data:data value:comma];
      [self saveNSStr:self.file data:data value:[self sensorValue:skinTemperature]];
      [self saveStr:self.file data:data value:comma];
      [self saveNSStr:self.file data:data value:[self sensorValue:heartRate]];
      [self saveStr:self.file data:data value:comma];
      [self saveNSStr:self.file data:data value:[self sensorValue:rrInterval]];
      [self saveStr:self.file data:data value:newLine];
    }
  }
}

-(void)updateClock {
  self.time.text = [self.clockFormat stringFromDate:[NSDate date]];
}

-(NSString *)sensorValue:(SensorReading) reading {
  return (reading.lastReading > [[NSDate date] timeIntervalSince1970] - 3.0)
    ? [NSString stringWithFormat:@"%f", reading.value]
    : @"";
}

-(void)locationUpdate:(CLLocationCoordinate2D)location {
  currentLocation = location;
  NSLog(@"current location: %f, %f", currentLocation.longitude, currentLocation.latitude);
}

-(IBAction)toggleRecord:(id)sender {
  if (recording) {
    [self.recordButton setTitle:@"Record" forState:UIControlStateNormal];
    [self stopRecording];
  } else {
    [self.recordButton setTitle:@"Stop Recording" forState:UIControlStateNormal];
    [self startRecording];
  }
}

-(void) startRecording {
  NSString* fileName = [NSString stringWithFormat:@"%@/data-%@.csv",documentDirectory,[self timestamp]];
  NSString* createFile = @"";
  [createFile writeToFile:fileName atomically:YES encoding:NSUnicodeStringEncoding error:nil];
  
  self.file = [NSFileHandle fileHandleForUpdatingAtPath:fileName];
  [self saveStr:self.file data:data value:header];
  [self saveStr:self.file data:data value:newLine];
  
  currentPointer = 0;
  [self updateSession];
  recording = true;
//  [self startLocationUpdates];
}

-(void)stopRecording {
  recording = false;
  if (self.locationManager != nil) {
    [self.locationManager stopUpdatingLocation];
  }
}

-(void) updateSession {
  NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
  [dateFormatter setDateFormat:@"yyyyMMdd'-'HHmmss"];
  NSDate *date = [NSDate date];
  self.session = [dateFormatter stringFromDate:date];
}

- (void)startLocationUpdates {
  // Create the location manager if this object does not
  // already have one.
//  if (nil == self.locationManager)
//    self.locationManager = [[CLLocationManager alloc] init];
//
//  [self.locationManager requestAlwaysAuthorization];
//  self.locationManager.pausesLocationUpdatesAutomatically = false;
//
//  self.locationManager.delegate = self;
//  self.locationManager.desiredAccuracy = kCLLocationAccuracyBest;


  // Set a movement threshold for new events.
//  self.locationManager.distanceFilter = 1; // meters
//
//  currentLocation = [self.locationManager location].coordinate;
//  [self.locationManager startUpdatingLocation];
}

-(NSString *)timestamp {
  NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
  dateFormatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
  dateFormatter.dateFormat = @"yyyyMMdd'-'HHmm";
  dateFormatter.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
  return [dateFormatter stringFromDate:[NSDate date]];
}

-(void) saveStr: (NSFileHandle * )file data: (NSMutableData *)data value: (const char*)str {
  [file seekToEndOfFile];
  data = [NSMutableData dataWithBytes:str length:strlen(str)];
  [file writeData:data];
}

-(void) saveNSStr: (NSFileHandle * )file data: (NSMutableData *)data value: (NSString *)str {
  [self saveStr:file data:data value:[str cStringUsingEncoding:NSASCIIStringEncoding]];
}

-(void) saveDoubleVal : (NSFileHandle * )file data : (NSMutableData *) data value : (const double) val {
  NSString* str = [NSString stringWithFormat:@"%f",val];
  const char* myValStr = (const char*)[str UTF8String];
  [self saveStr:file data:data value:myValStr];
}

-(NSString *)parseSerialFromName: (NSString *)name {
  NSError *error = NULL;
  NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"\\(.*?\\)"
                                                                         options:NSRegularExpressionCaseInsensitive
                                                                           error:&error];
  NSRange match = [regex rangeOfFirstMatchInString:name options:0 range:NSMakeRange(0, [name length])];
  if (!NSEqualRanges(match, NSMakeRange(NSNotFound, 0))) {
    NSRange insideParens = NSMakeRange(match.location+1, match.length - 2);
    return [name substringWithRange:insideParens];
  }
  return @"unknown";
}

// Note: The delegate methods of MSBClientManagerDelegate protocol are called in the main thread.
-(void)clientManager:(MSBClientManager *)cm
    clientDidConnect:(MSBClient *)client
{
  self.bandClient = client;
  
  self.bandStatus.text = [NSString stringWithFormat:@"Band Connected:\n %@", client.name];

  [self requestBandConsent:[self.bandClient.sensorManager heartRateUserConsent] handler:^(BOOL userConsent, NSError *error) {
    if (userConsent)
      [self startHeartRateUpdates];
  }];
  
  NSError *subscriptionError;
  [self.bandClient.sensorManager startAltimeterUpdatesToQueue:nil errorRef:&subscriptionError
                                                  withHandler:^(MSBSensorAltimeterData *altimeterData, NSError *error) {
    if (!error) {
      altimeterChange.lastReading = [[NSDate date] timeIntervalSince1970];
      altimeterChange.value = (double) altimeterData.totalGain - (double) altimeterData.totalLoss;
      altimeterRate.lastReading = [[NSDate date] timeIntervalSince1970];
      altimeterRate.value = (double) altimeterData.rate;
//      NSLog(@"Got altimeter gain: %lu, loss: %lu, diff: %ld, rate: %f",
//            (unsigned long) altimeterData.totalGain,
//            (unsigned long) altimeterData.totalLoss,
//            ((long) altimeterData.totalGain) - ((long) altimeterData.totalLoss),
//            altimeterData.rate);
    }
  }];
  if (subscriptionError){
    NSLog(@"Failed to subscribe to altimeter");
  }
  
  subscriptionError = nil;
  [self.bandClient.sensorManager startGSRUpdatesToQueue:nil errorRef:&subscriptionError
                                                  withHandler:^(MSBSensorGSRData *gsrData, NSError *error) {
    if (!error) {
      gsrResistance.lastReading = [[NSDate date] timeIntervalSince1970];
      gsrResistance.value = (double) gsrData.resistance;

//      NSLog(@"Got gsr resistence: %lu", (unsigned long) gsrData.resistance);
    }
  }];
  if (subscriptionError){
    NSLog(@"Failed to subscribe to GSR");
  }
  
  subscriptionError = nil;
  [self.bandClient.sensorManager startSkinTempUpdatesToQueue:nil errorRef:&subscriptionError
                                            withHandler:^(MSBSensorSkinTemperatureData *skinTempData, NSError *error) {
    if (!error) {
      skinTemperature.lastReading = [[NSDate date] timeIntervalSince1970];
      skinTemperature.value = (double) skinTempData.temperature;
//      NSLog(@"Got skin temperature: %f", (double) skinTempData.temperature);
    }
  }];
  if (subscriptionError){
    NSLog(@"Failed to subscribe to skin temperature");
  }
}

- (void)startHeartRateUpdates {
  if (!self.bandClient) return;
  
  // if Queue is nil, it uses default mainQueue
  NSError *subscriptionError;
  [self.bandClient.sensorManager startHeartRateUpdatesToQueue:nil errorRef:&subscriptionError
                                                  withHandler:^(MSBSensorHeartRateData *heartRateData, NSError *error) {
    if (!error) {
      heartRate.lastReading = [[NSDate date] timeIntervalSince1970];
      heartRate.value = (double) heartRateData.heartRate;
//      NSLog(@"Got heart rate %lu", (unsigned long) heartRateData.heartRate);
    }
  }];
  if (subscriptionError){
    NSLog(@"Failed to subscribe to heartrate");
  }
  
  subscriptionError = nil;
  [self.bandClient.sensorManager startRRIntervalUpdatesToQueue:nil errorRef:&subscriptionError
                                                  withHandler:^(MSBSensorRRIntervalData *rrIntervalData, NSError *error) {
    if (!error) {
      rrInterval.lastReading = [[NSDate date] timeIntervalSince1970];
      rrInterval.value = (double) rrIntervalData.interval;
//      NSLog(@"Got interval rate data %f", (double) rrIntervalData.interval);
    }
                                                  }];
  if (subscriptionError){
    NSLog(@"Failed to subscribe to rr interval");
  }
}

-(void) requestBandConsent:(MSBUserConsent) consent handler:(void (^)(BOOL userConsent, NSError *error)) handler {
  switch (consent)
  {
    case MSBUserConsentGranted:
      // user has granted access
      handler(true, nil);
      break;
    case MSBUserConsentDeclined:
      break;
    default:
      break;
    case MSBUserConsentNotSpecified:
      // request user consent
      [self.bandClient.sensorManager requestHRUserConsentWithCompletion:handler];
      break;
  }
}

-(void)clientManager:(MSBClientManager *)cm clientDidDisconnect:(MSBClient *)client
{
  self.bandStatus.text = @"Band Disconnected";
  if (self.bandClient) {
    NSError *subscriptionError;
    [self.bandClient.sensorManager stopHeartRateUpdatesErrorRef:&subscriptionError];
    [self.bandClient.sensorManager stopRRIntervalUpdatesErrorRef:&subscriptionError];
    [self.bandClient.sensorManager stopGSRUpdatesErrorRef:&subscriptionError];
    [self.bandClient.sensorManager stopSkinTempUpdatesErrorRef:&subscriptionError];
    [self.bandClient.sensorManager stopAltimeterUpdatesErrorRef:&subscriptionError];
  }
  self.bandClient = nil;
}

-(void)clientManager:(MSBClientManager *)cm client:(MSBClient *)client didFailToConnectWithError:(NSError *)error
{
  NSLog(@"Band failed to connect");
}

@end
