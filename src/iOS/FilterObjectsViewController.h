//
//  FilterObjectsViewController.h
//  Go Map!!
//
//  Created by Bryce Cogswell on 5/20/18.
//  Copyright © 2018 Bryce. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface FilterObjectsViewController : UITableViewController <UITextFieldDelegate>

@property (weak)    IBOutlet UITextField    *    levelsText;
@property (weak)    IBOutlet UISwitch        *    switchLevel;
@property (weak)    IBOutlet UISwitch        *    switchPoints;
@property (weak)    IBOutlet UISwitch        *    switchBarriers;
@property (weak)    IBOutlet UISwitch        *    switchTrafficRoads;
@property (weak)    IBOutlet UISwitch        *    switchServiceRoads;
@property (weak)    IBOutlet UISwitch        *    switchPedestrian;
@property (weak)    IBOutlet UISwitch        *    switchConstructionRoads;
@property (weak)    IBOutlet UISwitch        *    switchBuildings;
@property (weak)    IBOutlet UISwitch        *    switchLanduse;
@property (weak)    IBOutlet UISwitch        *    switchBoundaries;
@property (weak)    IBOutlet UISwitch        *    switchWater;
@property (weak)    IBOutlet UISwitch        *    switchRail;
@property (weak)    IBOutlet UISwitch        *    switchPower;
@property (weak)    IBOutlet UISwitch        *    switchPastFuture;
@property (weak)    IBOutlet UISwitch        *    switchOthers;

+(NSArray *)levelsForString:(NSString *)text;

@end
