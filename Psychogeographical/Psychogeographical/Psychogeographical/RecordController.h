//
//  RecordController.h
//  Psychogeographical
//
//  Created by Alex Cruikshank on 11/5/16.
//  Copyright © 2016 Alex Cruikshank. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>
#import <MicrosoftBandKit_iOS/MicrosoftBandKit_iOS.h>

@interface RecordController : UIViewController <CLLocationManagerDelegate, MSBClientManagerDelegate> {
  NSArray        *name_channel;
  NSString       *documentDirectory;
}

@property (weak) IBOutlet UILabel *time;
@property (weak) IBOutlet UILabel *status;
@property (weak) IBOutlet UILabel *bandStatus;
@property (weak) IBOutlet UILabel *destination;
@property (weak) IBOutlet UIButton *recordButton;

-(IBAction)toggleRecord:(id)sender;
-(void)locationUpdate:(CLLocationCoordinate2D)location;

@end

