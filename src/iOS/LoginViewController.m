//
//  LoginViewController.m
//  Go Map!!
//
//  Created by Bryce Cogswell on 12/19/12.
//  Copyright (c) 2012 Bryce Cogswell. All rights reserved.
//

#import "AppDelegate.h"
#import "EditorMapLayer.h"
#import "KeyChain.h"
#import "LoginViewController.h"
#import "MapView.h"
#import "OsmMapData.h"

@implementation LoginViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
}

- (IBAction)textFieldReturn:(id)sender
{
    [sender resignFirstResponder];
}

- (IBAction)textFieldDidChange:(id)sender
{
    _saveButton.enabled = _username.text.length && _password.text.length;
}

- (IBAction)registerAccount:(id)sender
{
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString: @"https://www.openstreetmap.org/user/new"]
                                       options:@{}
                             completionHandler:nil];
}


- (IBAction)verifyAccount:(id)sender
{
    if ( _activityIndicator.isAnimating )
        return;
    
    NSString *username = [_username.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *password = [_password.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

    AppDelegate * appDelegate = (id)[[UIApplication sharedApplication] delegate];
    appDelegate.userName        = username;
    appDelegate.userPassword    = password;

    _activityIndicator.color = UIColor.darkGrayColor;
    [_activityIndicator startAnimating];

    [appDelegate.mapView.editorLayer.mapData verifyUserCredentialsWithCompletion:^(NSString * errorMessage){
        [_activityIndicator stopAnimating];
        if ( errorMessage ) {

            // warn that email addresses don't work
            if ( [appDelegate.userName containsString:@"@"] ) {
                errorMessage = NSLocalizedString(@"You must provide your OSM user name, not an email address.",nil);
            }
            UIAlertController * alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Bad login",nil) message:errorMessage preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK",nil) style:UIAlertActionStyleCancel handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
        } else {
            // verifying credentials may update the appDelegate values when we subsitute name for correct case:
            _username.text    = username;
            _password.text    = password;
            [_username resignFirstResponder];
            [_password resignFirstResponder];
            
            [self saveVerifiedCredentialsWithUsername:username password:password];

            UIAlertController * alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Login successful",nil) message:nil preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK",nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
                [self.navigationController popToRootViewControllerAnimated:YES];
            }]];
            [self presentViewController:alert animated:YES completion:nil];
        }
    }];
}

- (IBAction)logout:(id)sender {
    _username.text = @"";
    _password.text = @"";
    
    [KeyChain deleteStringForIdentifier:@"username"];
    [KeyChain deleteStringForIdentifier:@"password"];
    
    AppDelegate *appDelegate = (id)[[UIApplication sharedApplication] delegate];
    appDelegate.userName = @"";
    appDelegate.userPassword = @"";
    
    OsmMapData *mapData = [appDelegate.mapView editorLayer].mapData;
    mapData.credentialsUserName = @"";
    mapData.credentialsPassword = @"";
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    AppDelegate * appDelegate = (id)[[UIApplication sharedApplication] delegate];
    _username.text    = appDelegate.userName;
    _password.text    = appDelegate.userPassword;

    _saveButton.enabled = _username.text.length && _password.text.length;
}

#pragma mark - Table view delegate

@end


@implementation KaartLoginViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
}

- (IBAction)kaartTextFieldReturn:(id)sender {
    [sender resignFirstResponder];
}

- (IBAction)kaartTextFieldDidChange:(id)sender {
    _saveButton.enabled = _kaartUsername.text.length && _kaartPassword.text.length;
}

- (IBAction)kaartRegisterAccount:(id)sender {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://my.kaart.com/"]
                                       options:@{}
                             completionHandler:nil];
}

- (IBAction)kaartVerifyAccount:(id)sender {
    if (_activityIndicator.isAnimating)
        return;

    NSString *kaartUsername = [_kaartUsername.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *kaartPassword = [_kaartPassword.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];


    AppDelegate *appDelegate = (id)[[UIApplication sharedApplication] delegate];
    appDelegate.kaartUserName = kaartUsername;
    appDelegate.kaartPassword = kaartPassword;

    _activityIndicator.color = UIColor.darkGrayColor;
    [_activityIndicator startAnimating];

    [appDelegate.mapView.editorLayer.mapData verifyUserCredentialsWithCompletion:^(NSString *errorMessage) {
        [_activityIndicator stopAnimating];

        if (errorMessage) {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Login credentials not found", nil) message:errorMessage preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil) style:UIAlertActionStyleCancel handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
        } else {
            _kaartUsername.text = kaartUsername;
            _kaartPassword.text = kaartPassword;
            [_kaartUsername resignFirstResponder];
            [_kaartPassword resignFirstResponder];

            [self saveVerifiedCredentialsWithKaartUsername:kaartUsername kaartPassword:kaartPassword];

            UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Login successful", nil) message:nil preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
                [self.navigationController popToRootViewControllerAnimated:YES];
            }]];
            [self presentViewController:alert animated:YES completion:nil];
        }
    }];
}

- (IBAction)kaartLogout:(id)sender {
    _kaartUsername.text = @"";
    _kaartPassword.text = @"";
    
    [KeyChain deleteStringForIdentifier:@"kaartUsername"];
    [KeyChain deleteStringForIdentifier:@"kaartPassword"];
    
    AppDelegate *appDelegate = (id)[[UIApplication sharedApplication] delegate];
    appDelegate.kaartUserName = @"";
    appDelegate.kaartPassword = @"";
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    AppDelegate *appDelegate = (id)[[UIApplication sharedApplication] delegate];
    _kaartUsername.text = appDelegate.kaartUserName;
    _kaartPassword.text = appDelegate.kaartPassword;

    _saveButton.enabled = _kaartUsername.text.length && _kaartPassword.text.length;
}

- (void)saveVerifiedCredentialsWithKaartUsername:(NSString *)kaartUsername kaartPassword:(NSString *)kaartPassword {
    [KeyChain setString:kaartUsername forIdentifier:@"kaartUsername"];
    [KeyChain setString:kaartPassword forIdentifier:@"kaartPassword"];

    // Update the app delegate as well
    AppDelegate *appDelegate = (id)[[UIApplication sharedApplication] delegate];
    appDelegate.kaartUserName = kaartUsername;
    appDelegate.kaartPassword = kaartPassword;
}

@end
