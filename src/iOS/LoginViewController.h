//
//  LoginViewController.h
//  Go Map!!
//
//  Created by Bryce Cogswell on 12/19/12.
//  Copyright (c) 2012 Bryce Cogswell. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface LoginViewController : UITableViewController
{
    IBOutlet UIBarButtonItem            *    _saveButton;
    IBOutlet UITextField                *    _username;
    IBOutlet UITextField                *    _password;
    IBOutlet UIActivityIndicatorView    *    _activityIndicator;
}

- (IBAction)textFieldReturn:(id)sender;
- (IBAction)textFieldDidChange:(id)sender;

- (IBAction)registerAccount:(id)sender;
- (IBAction)verifyAccount:(id)sender;
- (IBAction)logout:(id)sender;

@end

@interface KaartLoginViewController : UITableViewController
{
    IBOutlet UIBarButtonItem            *    _saveButton;
    IBOutlet UITextField                *    _kaartUsername;
    IBOutlet UITextField                *    _kaartPassword;
    IBOutlet UIActivityIndicatorView    *    _activityIndicator;
}

- (IBAction)kaartTextFieldReturn:(id)sender;
- (IBAction)kaartTextFieldDidChange:(id)sender;

- (IBAction)kaartRegisterAccount:(id)sender;
- (IBAction)kaartVerifyAccount:(id)sender;
- (IBAction)kaartLogout:(id)sender;

@end
