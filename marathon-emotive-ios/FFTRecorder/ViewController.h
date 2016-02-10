//
//  ViewController.h
//  FFTRecorder
//
//  Created by Alex Cruikshank on 1/17/16.
//  Copyright © 2016 Alex Cruikshank. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ViewController : UIViewController {
  NSArray        *name_channel;
  NSString       *documentDirectory;  
}

@property (weak) IBOutlet UILabel *status;
@property (weak) IBOutlet UIButton *transmitButton;

-(IBAction)toggleTransmit:(id)sender;

@end
