//
//  SettingsViewController.h
//  Go Map!!
//
//  Created by Bryce Cogswell on 12/6/12.
//  Copyright (c) 2012 Bryce Cogswell. All rights reserved.
//

#import <UIKit/UIKit.h>


@interface SettingsViewController : UITableViewController <UITableViewDataSource, MFMailComposeViewControllerDelegate>
{
    IBOutlet UILabel            *    _username;
    IBOutlet UILabel            *    _kaartUsername;
    IBOutlet UILabel            *    _language;
}
@end
