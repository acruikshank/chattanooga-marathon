//
//  ViewController.m
//  FFTRecorder
//
//  Created by Alex Cruikshank on 1/17/16.
//  Copyright © 2016 Alex Cruikshank. All rights reserved.
//

#import "ViewController.h"
#import <edk_ios/Iedk.h>
#import <CoreLocation/CoreLocation.h>
#import "STHTTPRequest.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import "HeartRate.h"

BOOL isConnected = NO;

IEE_DataChannel_t ChannelList[] = {
  IED_AF3, IED_AF4, IED_T7, IED_T8, IED_Pz
};

const char header[] = "Time,Theta AF3,Alpha AF3,Low beta AF3,High beta AF3,Gamma AF3,Theta AF4,Alpha AF4,Low beta AF4,High beta AF4,Gamma AF4,Theta T7,Alpha T7,Low beta T7,High beta T7,Gamma T7,Theta T8,Alpha T8,Low beta T8,High beta T8,Gamma T8,Theta Pz,Alpha Pz,Low beta Pz,High beta Pz,Gamma Pz,Heart Rate,HRV,RR0,RR1,RR2,RR3,Lattitude,Longitude";

const char *newLine = "\n";
const char *comma = ",";
const int MAX_RR_PER_SAMPLE = 4;

const int SAMPLE_SIZE = 28 + MAX_RR_PER_SAMPLE;
const int BUFFER_SIZE = SAMPLE_SIZE * 4 * 25;

@interface ViewController ()

@property (nonatomic, retain) NSString *session;
@property (nonatomic, retain) CLLocationManager *locationManager;
@property (nonatomic, retain) NSString *expectedDeviceName;
@property (nonatomic, retain) NSString *deviceName;
@property (nonatomic, retain) NSString *expectedHRDeviceName;
@property (nonatomic, retain) NSString *hrDeviceName;
@property (nonatomic, strong) HeartRate *heartRate;

@end

@implementation ViewController
EmoEngineEventHandle eEvent;
EmoStateHandle eState;

unsigned int userID	= 0;
float secs = 1;
bool readytocollect = false;
bool transmitting = false;
bool sending = false;
int state = 0;
int currentPointer = 0;
int lastTransmitted = 0;
int lastAttempted = 0;
CLLocationCoordinate2D currentLocation;
Float64 buffer[SAMPLE_SIZE*BUFFER_SIZE];
Float64 scratchBuffer[SAMPLE_SIZE*BUFFER_SIZE];

NSFileHandle *file;
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
  
  NSString* fileName = [NSString stringWithFormat:@"%@/datalog-%f.csv",documentDirectory,CFAbsoluteTimeGetCurrent()];
  NSLog(@"Path: %@", fileName);
  NSString* createFile = @"";
  [createFile writeToFile:fileName atomically:YES encoding:NSUnicodeStringEncoding error:nil];
  
  file = [NSFileHandle fileHandleForUpdatingAtPath:fileName];
  [self saveStr:file data:data value:header];
  [self saveStr:file data:data value:newLine];
  
  //IEE_MotionDataSetBufferSizeInSec(secs);
  self.transmitButton.alpha = 0.0;
  
  [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(getNextEvent) userInfo:nil repeats:YES];
  [NSTimer scheduledTimerWithTimeInterval:3.0 target:self selector:@selector(transmit) userInfo:nil repeats:YES];

  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  self.destination.text = [defaults stringForKey:@"host_preference"];
  
  self.expectedDeviceName = [defaults stringForKey:@"device"];
  if (!self.expectedDeviceName || [self.expectedDeviceName length] == 0)
    self.expectedDeviceName = @"";
    
  self.expectedHRDeviceName = [defaults stringForKey:@"heart"];
  if (self.expectedHRDeviceName && [self.expectedHRDeviceName length] != 0)
    self.heartRate = [[HeartRate alloc] initWithName:self.expectedHRDeviceName];
}

// Polar H10 BD487724
// 596849CA, 5A68593D

-(void) getNextEvent {
  int deviceIndex = [self getDeviceUser];
  if (deviceIndex >= 0 && !isConnected) {
    IEE_ConnectInsightDevice(deviceIndex);
    self.deviceName = [self getDeviceName:deviceIndex];
    NSLog(@"Line: %d: Connected %@", __LINE__, self.deviceName);
    isConnected = YES;
  } else {
    isConnected = NO;
  }
  
  if (_heartRate) {
    self.heartStatus.text = _heartRate.connected ? @"Heart Monitor Connected" : @"heart monitor disconnected";
  }
  
  int state = IEE_EngineGetNextEvent(eEvent);
  unsigned int userID = 0;

  
  if (state == EDK_OK)
  {
    IEE_Event_t eventType = IEE_EmoEngineEventGetType(eEvent);
    IEE_EmoEngineEventGetUserId(eEvent, &userID);
    
    if (eventType == IEE_UserAdded)
    {
      
      NSLog(@"User Added %d", userID);
      IEE_FFTSetWindowingType(userID, IEE_HANN);
      self.status.text = [NSString stringWithFormat:@"Connected: %@", self.deviceName];
      readytocollect = TRUE;
      self.transmitButton.alpha = 1.0;
    }
    else if (eventType == IEE_UserRemoved)
    {
      NSLog(@"User Removed");
      isConnected = NO;
      self.status.text = @"Disconnected";
      readytocollect = FALSE;
      self.transmitButton.alpha = 0.0;
    }
  }
  
  if (readytocollect)
  {
    double value[SAMPLE_SIZE];
    memset(value, 0, SAMPLE_SIZE*sizeof(double));
    int overallResult = EDK_OK;
    
    for(int i=0 ; i< sizeof(ChannelList)/sizeof(IEE_DataChannel_t) ; ++i)
    {
      int result = IEE_GetAverageBandPowers(userID, ChannelList[i], &value[i*5+1], &value[i*5+2], &value[i*5+3], &value[i*5+4], &value[i*5+5]);
      overallResult = fmax(overallResult, result);
    }
    
    if(overallResult == EDK_OK){
      
      
      value[0] = [[NSDate date] timeIntervalSince1970];
      if (_heartRate) {
        value[SAMPLE_SIZE - MAX_RR_PER_SAMPLE - 2] = _heartRate.heartRate;
        value[SAMPLE_SIZE - MAX_RR_PER_SAMPLE - 1] = _heartRate.hsv;
        
        NSArray *rrValues = [_heartRate lastRRvalues: MAX_RR_PER_SAMPLE];
        for (int i=0; i<MAX_RR_PER_SAMPLE; i++) {
          value[SAMPLE_SIZE - MAX_RR_PER_SAMPLE + i] = rrValues.count > i ? [[rrValues objectAtIndex:i] floatValue] : 0;
        }
      } else {
        for (int i=0; i<2+MAX_RR_PER_SAMPLE; i++) {
          value[SAMPLE_SIZE - i - 1] = 0;
        }
      }

      for(int j=0; j < SAMPLE_SIZE; j++){
        if (j > 0)
          [self saveStr:file data:data value:comma];
        [self saveDoubleVal:file data:data value:value[j]];
      }
      
      // save location to backup (transmitted values send location via headers).
      [self saveStr:file data:data value:comma];
      [self saveDoubleVal:file data:data value:currentLocation.latitude];
      [self saveStr:file data:data value:comma];
      [self saveDoubleVal:file data:data value:currentLocation.longitude];

      [self saveStr:file data:data value:newLine];
      if (transmitting) {
        [self sendValues:value];
      }
    }
  }
}

-(int)getDeviceUser {
  int numberDevice = IEE_GetInsightDeviceCount();
  if (numberDevice < 1) return -1;
  if (self.expectedDeviceName.length == 0) return 0;
  
  for (int i=0; i<numberDevice; i++) {
    
    if ([self.expectedDeviceName isEqualToString:[self getDeviceName:i]])
      return i;
  }
  return -1;
}

-(NSString *)getDeviceName:(int) userNumber {
  const char *cname = IEE_GetInsightDeviceName(userNumber);
  if (cname == nil)
    cname = "unknown";
  return [self parseSerialFromName:[[NSString alloc] initWithCString:cname encoding:NSASCIIStringEncoding]];
}

-(void)locationUpdate:(CLLocationCoordinate2D)location {
  currentLocation = location;
}

-(IBAction)toggleTransmit:(id)sender {
  if (transmitting) {
    [self.transmitButton setTitle:@"Transmit" forState:UIControlStateNormal];
    [self stopTransmitting];
  } else {
    [self.transmitButton setTitle:@"Stop Transmitting" forState:UIControlStateNormal];
    [self startTransmitting];
  }
}

-(void) startTransmitting {
  currentPointer = 0;
  lastTransmitted = 0;
  lastAttempted = 0;
  [self updateSession];
  transmitting = true;
  [self startLocationUpdates];
}

-(void)stopTransmitting {
  transmitting = false;
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

-(void) sendValues:(double[SAMPLE_SIZE])values {
  for (int i=0; i<SAMPLE_SIZE; i++) buffer[i + SAMPLE_SIZE*currentPointer] = (Float64) values[i];
  currentPointer = (currentPointer+1) % BUFFER_SIZE;
  if (lastTransmitted == currentPointer)
    lastTransmitted = (lastTransmitted+1) % BUFFER_SIZE;
}

-(BOOL) transmit {
  if (!transmitting || sending || lastTransmitted == currentPointer) return false;
  
  int sampleBytes = SAMPLE_SIZE*sizeof(Float64);
  int transmissionSize = 0;
  int attemptedTransmission = currentPointer;
  if (currentPointer > lastTransmitted) {
    memcpy(scratchBuffer, &buffer[lastTransmitted*SAMPLE_SIZE], (currentPointer-lastTransmitted)*sampleBytes);
    transmissionSize = sampleBytes * (currentPointer - lastTransmitted);
  } else {
    memcpy(scratchBuffer, &buffer[lastTransmitted*SAMPLE_SIZE], (BUFFER_SIZE-lastTransmitted)*sampleBytes);
    memcpy(&scratchBuffer[(BUFFER_SIZE-lastTransmitted)*SAMPLE_SIZE], &buffer, currentPointer*sampleBytes);
    transmissionSize = sampleBytes * (BUFFER_SIZE - lastTransmitted + currentPointer);
  }
  
  // Get host from defaults
  //  NSString *host = @"chama-emote.herokuapp.com";
  //  NSString *host = @"chattanooga-marathon-alex.ngrok.io";
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSString *host = [defaults stringForKey:@"host_preference"];
  if (!host || [host length] == 0) {
    host = @"chattanooga-marathon-alex.ngrok.io";
  }

  NSString *url = [NSString stringWithFormat:@"https://%@/api/1.0/samples/%@/%@", host, self.deviceName, self.session];
  NSLog(@"Sending samples to %@", url);
  STHTTPRequest *request = [STHTTPRequest requestWithURLString:url];
  
  NSString *location = [NSString stringWithFormat:@"%f;%f", currentLocation.latitude, currentLocation.longitude];
  NSLog(@"Current Position: %f, %f", currentLocation.longitude, currentLocation.latitude);
  [request setHeaderWithName:@"Geo-Position" value:location];
  
  request.rawPOSTData = [NSData dataWithBytes:scratchBuffer length:transmissionSize];
  
  request.completionBlock = ^(NSDictionary *headers, NSString *body) {
    lastTransmitted = attemptedTransmission;
    sending = false;
    NSLog(@"sent %dbytes", transmissionSize);
  };
  
  request.errorBlock = ^(NSError *error) {
    sending = false;
    NSLog(@"-- error: %@", error);
  };
  
  sending = true;
  [request startAsynchronous];
  return true;
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
//  
//  
//  // Set a movement threshold for new events.
//  self.locationManager.distanceFilter = 1; // meters
  
//  [self.locationManager startUpdatingLocation];
}

-(void) saveStr : (NSFileHandle * )file data : (NSMutableData *) data value : (const char*) str {
  [file seekToEndOfFile];
  data = [NSMutableData dataWithBytes:str length:strlen(str)];
  [file writeData:data];
}

-(void) saveDoubleVal : (NSFileHandle * )file data : (NSMutableData *) data value : (const double) val {
  NSString* str = [NSString stringWithFormat:@"%f",val];
  const char* myValStr = (const char*)[str UTF8String];
  [self saveStr:file data:data value:myValStr];
}

- (void)didReceiveMemoryWarning {
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
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

@end
