//
//  ViewController.h
//  FFTRecorder
//
//  Created by Alex Cruikshank on 1/17/16.
//  Copyright © 2016 Alex Cruikshank. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>

@interface ViewController : UIViewController <CLLocationManagerDelegate> {
  NSArray        *name_channel;
  NSString       *documentDirectory;  
}

@property (weak) IBOutlet UILabel *status;
@property (weak) IBOutlet UILabel *destination;
@property (weak) IBOutlet UIButton *recordButton;
@property (weak) IBOutlet UIButton *transmitButton;

-(IBAction)toggleTransmit:(id)sender;
-(IBAction)toggleRecord:(id)sender;
-(BOOL)transmit;
-(void)locationUpdate:(CLLocationCoordinate2D)location;

@end
