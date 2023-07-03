//
//  SettingsViewController.m
//  Go Map!!
//
//  Created by Bryce Cogswell on 12/6/12.
//  Copyright (c) 2012 Bryce Cogswell. All rights reserved.
//

#import "AppDelegate.h"
#import "AerialList.h"
#import "AerialListViewController.h"
#import "EditorMapLayer.h"
#import "OsmMapData.h"
#import "MapView.h"
#import "MercatorTileLayer.h"
#import "SettingsViewController.h"


@interface OsmLoginCell : UITableViewCell
@end
@implementation OsmLoginCell
@end

@interface KaartLoginCell : UITableViewCell
@end
@implementation KaartLoginCell
@end

@implementation SettingsViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    
    [self.tableView registerClass:[OsmLoginCell class] forCellReuseIdentifier:@"OsmLoginCell"];
    [self.tableView registerClass:[KaartLoginCell class] forCellReuseIdentifier:@"KaartLoginCell"];


    self.tableView.estimatedRowHeight = 44.0;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    self.navigationController.navigationBarHidden = NO;

    PresetLanguages * presetLanguages = [PresetLanguages new];
    NSString * preferredLanguageCode = presetLanguages.preferredLanguageCode;
    NSString * preferredLanguage = [PresetLanguages localLanguageNameForCode:preferredLanguageCode];
    _language.text = preferredLanguage;

    // set username, but then validate it
    AppDelegate * appDelegate = AppDelegate.shared;

    _username.text = @"";
    //NSLog(@"%@", appDelegate.userName.length);
    if (appDelegate.userName != nil && appDelegate.userName.length > 0) {
        //NSLog(@"%@", appDelegate.userName);
        [appDelegate.mapView.editorLayer.mapData verifyUserCredentialsWithCompletion:^(NSString * errorMessage) {
            if ( errorMessage ) {
                _username.text = NSLocalizedString(@"<unknown>",@"unknown user name");
            } else {
                _username.text = appDelegate.userName;
            }
            
            [self.tableView reloadData];
        }];
    }
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
}

-(void)accessoryDidConnect:(id)sender
{
}

- (IBAction)onDone:(id)sender
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 2;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    //NSLog(@"IndexPath.row: %ld", (long)indexPath.row); // Log the indexPath.row
    if (indexPath.row == 0) {
        OsmLoginCell *cell = [tableView dequeueReusableCellWithIdentifier:@"OsmLoginCell" forIndexPath:indexPath];
        // Configure the cell properties
        return cell;
    } else if (indexPath.row == 1) {
        KaartLoginCell *cell = [tableView dequeueReusableCellWithIdentifier:@"KaartLoginCell" forIndexPath:indexPath];
        // Configure the new cell properties
        return cell;
    }
    return nil;
}

@end
