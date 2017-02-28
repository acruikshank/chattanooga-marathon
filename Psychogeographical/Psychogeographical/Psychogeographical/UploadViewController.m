//
//  UploadViewController.m
//  Psychogeographical
//
//  Created by Alex Cruikshank on 11/5/16.
//  Copyright © 2016 Alex Cruikshank. All rights reserved.
//

#import "UploadViewController.h"

static NSString *const kKeychainItemName = @"Drive API";
static NSString *const kClientID = @"728468507317-lbqo2blvv375o21fh1bbmmur8c55a8q0.apps.googleusercontent.com";

@implementation UploadViewController

- (void)viewDidLoad {
  [super viewDidLoad];

  [GIDSignIn sharedInstance].uiDelegate = self;
  [GIDSignIn sharedInstance].delegate = self;

  GIDSignIn.sharedInstance.scopes = [NSArray arrayWithObjects:kGTLAuthScopeDrive, nil];


  [self updateFiles];

  // Initialize the Drive API service & load existing credentials from the keychain if available.
  self.service = [[GTLServiceDrive alloc] init];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
  return [self.files count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
  static NSString *tableIdentifier = @"FileTableCell";

  UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:tableIdentifier];

  if (cell == nil) {
    cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:tableIdentifier];
    UIButton *uploadButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    [uploadButton setTitle:@"upload" forState:UIControlStateNormal];
    [uploadButton setFrame:CGRectMake(0, 0, 100, 35)];
    [uploadButton addTarget: self action: @selector(accessoryButtonTapped:withEvent:) forControlEvents: UIControlEventTouchUpInside];
    cell.accessoryView = uploadButton;
  }

  cell.textLabel.text = [self.files objectAtIndex:indexPath.row];
  return cell;
}

- (void)signIn:(GIDSignIn *)signIn didSignInForUser:(GIDGoogleUser *)user withError:(NSError *)error {

  if (error == nil) {
    [self setAuthorizerForSignIn:signIn user:user];
  }
}

- (void)setAuthorizerForSignIn:(GIDSignIn *)signIn user:(GIDGoogleUser *)user {
  GTMOAuth2Authentication *auth = [[GTMOAuth2Authentication alloc] init];

  [auth setClientID:signIn.clientID];
  [auth setClientSecret:[[NSBundle mainBundle] objectForInfoDictionaryKey:@"GoogleClientSecret"]];
  [auth setUserEmail:user.profile.email];
  [auth setUserID:user.userID];
  [auth setAccessToken:user.authentication.accessToken];
  [auth setRefreshToken:user.authentication.refreshToken];
  [auth setExpirationDate: user.authentication.accessTokenExpirationDate];
  self.service.authorizer = auth;

  self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds];
  self.tableView.contentInset = UIEdgeInsetsMake(20.0, 0.0, 20.0, 0.0);
  self.tableView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
  [self.view addSubview:self.tableView];
  self.tableView.delegate = self;
  self.tableView.dataSource = self;
  self.tableView.allowsMultipleSelectionDuringEditing = NO;
}

- (void) accessoryButtonTapped: (UIControl *) button withEvent: (UIEvent *) event {
  NSIndexPath * indexPath = [self.tableView indexPathForRowAtPoint: [[[event touchesForView: button] anyObject] locationInView: self.tableView]];
  if ( indexPath == nil )
    return;
  
  [self.tableView.delegate tableView: self.tableView accessoryButtonTappedForRowWithIndexPath: indexPath];
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath {
  NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
  NSString __block *file = [self.files objectAtIndex:indexPath.row];
  NSString __block *filePath = [[paths objectAtIndex:0] stringByAppendingPathComponent:file];
  [self findOrCreateDriveFolder:@"Psychogeographic Files" completionHandler:^(GTLDriveFile *folder) {
    GTLDriveFile *metadata = [GTLDriveFile object];
    metadata.name = file;
    metadata.parents = @[folder.identifier];
    
    NSData *data = [[NSFileManager defaultManager] contentsAtPath:filePath];
    GTLUploadParameters *uploadParameters = [GTLUploadParameters uploadParametersWithData:data MIMEType:@"text/csv"];
    GTLQueryDrive *query = [GTLQueryDrive queryForFilesCreateWithObject:metadata
                                                       uploadParameters:uploadParameters];
    [self.service executeQuery:query completionHandler:^(GTLServiceTicket *ticket,
                                                         GTLDriveFile *updatedFile,
                                                         NSError *error) {
      if (error == nil) {
        NSLog(@"File %@", updatedFile);
        [self deleteFile:filePath];
      } else {
        NSLog(@"An error occurred: %@", error);
      }
    }];
  }];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
  // Return YES if you want the specified item to be editable.
  return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
  if (editingStyle == UITableViewCellEditingStyleDelete) {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *file = [self.files objectAtIndex:indexPath.row];
    NSString *filePath = [[paths objectAtIndex:0] stringByAppendingPathComponent:file];
    [self deleteFile:filePath];
  }
}

- (void)deleteFile:(NSString *)filePath {
  [[NSFileManager defaultManager] removeItemAtPath:filePath error:NULL];
  [self updateFiles];
}

- (void)updateFiles {
  NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
  self.files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[paths objectAtIndex:0] error:NULL];
  if (self.tableView) {
    [self.tableView reloadData];
  }
}

- (void)findOrCreateDriveFolder:(NSString *)folderName completionHandler:(void (^)(GTLDriveFile *))completionHandler {
  GTLQueryDrive *query = [GTLQueryDrive queryForFilesList];
  query.q = [[@"name='" stringByAppendingString:folderName]
             stringByAppendingString:@"' and mimeType='application/vnd.google-apps.folder'"];
  [self.service executeQuery:query completionHandler:^(GTLServiceTicket *ticket,
                                                       GTLDriveFileList *fileList,
                                                       NSError *error) {
    if (error == nil) {
      if (fileList.files.count > 0)
        return completionHandler(fileList.files[0]);
      
      GTLDriveFile *folder = [GTLDriveFile object];
      folder.name = folderName;
      folder.mimeType = @"application/vnd.google-apps.folder";
      
      GTLQueryDrive *query = [GTLQueryDrive queryForFilesCreateWithObject:folder uploadParameters:nil];
      [self.service executeQuery:query completionHandler:^(GTLServiceTicket *ticket,
                                                           GTLDriveFile *updatedFile,
                                                           NSError *error) {
        if (error == nil)
          return completionHandler(folder);
        
        NSLog(@"An error occurred: %@", error);
      }];
    } else {
      NSLog(@"An error occurred: %@", error);
    }
  }];
}

// Helper for showing an alert
- (void)showAlert:(NSString *)title message:(NSString *)message {
  UIAlertController *alert =
  [UIAlertController alertControllerWithTitle:title
                                      message:message
                               preferredStyle:UIAlertControllerStyleAlert];
  UIAlertAction *ok =
  [UIAlertAction actionWithTitle:@"OK"
                           style:UIAlertActionStyleDefault
                         handler:^(UIAlertAction * action)
   {
     [alert dismissViewControllerAnimated:YES completion:nil];
   }];
  [alert addAction:ok];
  [self presentViewController:alert animated:YES completion:nil];

}

@end
