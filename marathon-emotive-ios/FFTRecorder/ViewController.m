//
//  ViewController.m
//  FFTRecorder
//
//  Created by Alex Cruikshank on 1/17/16.
//  Copyright © 2016 Alex Cruikshank. All rights reserved.
//

#import "ViewController.h"
#import <edk/Iedk.h>
#import "STHTTPRequest.h"

BOOL isConnected = NO;

IEE_DataChannel_t ChannelList[] = {
  IED_AF3, IED_AF4, IED_T7, IED_T8, IED_Pz
};

const char header[] = "Time, Theta AF3,Alpha AF3,Low beta AF3,High beta AF3, Gamma AF3, Theta AF4,Alpha AF4,Low beta AF4,High beta AF4, Gamma AF4, Theta T7,Alpha T7,Low beta T7,High beta T7, Gamma T7, Theta T8,Alpha T8,Low beta T8,High beta T8, Gamma T8, Theta Pz,Alpha Pz,Low beta Pz,High beta Pz, Gamma Pz";

const char *newLine = "\n";
const char *comma = ",";

@interface ViewController ()

@end

@implementation ViewController
EmoEngineEventHandle eEvent;
EmoStateHandle eState;

unsigned int userID					= 0;
float secs							= 1;
bool readytocollect					= false;
bool transmitting           = false;
int state                           = 0;


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
  
  NSString* fileName = [NSString stringWithFormat:@"%@/BandPowerValue.csv",documentDirectory];
  NSLog(@"Path: %@", fileName);
  NSString* createFile = @"";
  [createFile writeToFile:fileName atomically:YES encoding:NSUnicodeStringEncoding error:nil];
  
  file = [NSFileHandle fileHandleForUpdatingAtPath:fileName];
  [self saveStr:file data:data value:header];
  [self saveStr:file data:data value:newLine];
  
  //IEE_MotionDataSetBufferSizeInSec(secs);
  self.transmitButton.alpha = 0.0;
  
  [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(getNextEvent) userInfo:nil repeats:YES];
  
}

-(void) getNextEvent {
  int numberDevice = IEE_GetInsightDeviceCount();
  if(numberDevice > 0 && !isConnected) {
    IEE_ConnectInsightDevice(0);
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
      self.status.text = @"Connected";
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

-(IBAction)toggleTransmit:(id)sender {
  if (transmitting) {
    transmitting = false;
    [self.transmitButton setTitle:@"Transmit" forState:UIControlStateNormal];
  } else {
    transmitting = true;
    [self.transmitButton setTitle:@"Stop Transmitting" forState:UIControlStateNormal];
  }
}

-(void) sendValues:(double[26])values {
  Float64 converted[26];
  for (int i=0; i<26; i++) converted[i] = (Float64) values[i];
  STHTTPRequest *request = [STHTTPRequest requestWithURLString:@"https://chama-emote.herokuapp.com/api/1.0/samples"];
//  STHTTPRequest *request = [STHTTPRequest requestWithURLString:@"https://chattanooga-marathon-alex.ngrok.io/api/1.0/samples"];
  
  request.rawPOSTData = [NSData dataWithBytes:&converted length:208];
  
  request.completionBlock = ^(NSDictionary *headers, NSString *body) {
    NSLog(@"-- %@", body);
  };
  
  request.errorBlock = ^(NSError *error) {
    NSLog(@"-- error: %@", error);
  };
  
  [request startAsynchronous];
}

-(void) saveStr : (NSFileHandle * )file data : (NSMutableData *) data value : (const char*) str
{
  [file seekToEndOfFile];
  data = [NSMutableData dataWithBytes:str length:strlen(str)];
  [file writeData:data];
}

-(void) saveDoubleVal : (NSFileHandle * )file data : (NSMutableData *) data value : (const double) val
{
  NSString* str = [NSString stringWithFormat:@"%f",val];
  const char* myValStr = (const char*)[str UTF8String];
  [self saveStr:file data:data value:myValStr];
}

- (void)didReceiveMemoryWarning {
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
}

@end
