//
//  ViewController.m
//  FFTRecorder
//
//  Created by Alex Cruikshank on 1/17/16.
//  Copyright © 2016 Alex Cruikshank. All rights reserved.
//

#import "ViewController.h"
#import <edk/Iedk.h>
#import <CoreLocation/CoreLocation.h>
#import "STHTTPRequest.h"
#import <MobileCoreServices/MobileCoreServices.h>

BOOL isConnected = NO;

IEE_DataChannel_t ChannelList[] = {
  IED_AF3, IED_AF4, IED_T7, IED_T8, IED_Pz
};

const char header[] = "Time, Theta AF3,Alpha AF3,Low beta AF3,High beta AF3, Gamma AF3, Theta AF4,Alpha AF4,Low beta AF4,High beta AF4, Gamma AF4, Theta T7,Alpha T7,Low beta T7,High beta T7, Gamma T7, Theta T8,Alpha T8,Low beta T8,High beta T8, Gamma T8, Theta Pz,Alpha Pz,Low beta Pz,High beta Pz, Gamma Pz";

const char *newLine = "\n";
const char *comma = ",";
const int SAMPLE_SIZE = 26;
const int BUFFER_SIZE = 1200;

@interface ViewController ()

@property (nonatomic, retain) NSString *deviceName;
@property (nonatomic, retain) NSString *session;
@property (nonatomic, retain) CLLocationManager *locationManager;

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

    if(overallResult == EDK_OK){
      for(int j =0; j < 26; j++){
        if (j > 0)
          [self saveStr:file data:data value:comma];
        [self saveDoubleVal:file data:data value:value[j]];
      }
      [self saveStr:file data:data value:newLine];
      if (transmitting) {
        [self sendValues:value];
      }
    }
    
  }
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

-(void) sendValues:(double[26])values {
  for (int i=0; i<26; i++) buffer[i + SAMPLE_SIZE*currentPointer] = (Float64) values[i];
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

  NSString *url = [NSString stringWithFormat:@"http://%@/api/1.0/samples/%@/%@", host, self.deviceName, self.session];
  STHTTPRequest *request = [STHTTPRequest requestWithURLString:url];
  
  NSString *location = [NSString stringWithFormat:@"%f;%f", currentLocation.latitude, currentLocation.longitude];
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
