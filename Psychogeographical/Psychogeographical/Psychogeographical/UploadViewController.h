//
//  UploadViewController.h
//  Psychogeographical
//
//  Created by Alex Cruikshank on 11/5/16.
//  Copyright © 2016 Alex Cruikshank. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Google/SignIn.h>

#import "GTMOAuth2ViewControllerTouch.h"
#import "GTLDrive.h"

@interface UploadViewController : UIViewController <GIDSignInDelegate, GIDSignInUIDelegate,
                                                    UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) GTLServiceDrive *service;
@property (nonatomic, strong) UITableView *tableView;
@property (weak, nonatomic) IBOutlet GIDSignInButton *signInButton;
@property (nonatomic, strong) NSArray *files;


@end
