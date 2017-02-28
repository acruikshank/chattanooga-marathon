//
//  AppDelegate.h
//  FFTRecorder
//
//  Created by Alex Cruikshank on 1/17/16.
//  Copyright © 2016 Alex Cruikshank. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ViewController.h"
#import "LocationTracker.h"

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;
@property LocationTracker * locationTracker;
@property (nonatomic) NSTimer* locationUpdateTimer;

@end

