//
//  FirstViewController.h
//  Go Map!!
//
//  Created by Bryce Cogswell on 12/6/12.
//  Copyright (c) 2012 Bryce Cogswell. All rights reserved.
//

#import <CoreLocation/CoreLocation.h>
#import <UIKit/UIKit.h>
#import "MapView.h"

typedef enum {
    BUTTON_LAYOUT_ADD_ON_LEFT,
    BUTTON_LAYOUT_ADD_ON_RIGHT,
} BUTTON_LAYOUT;


@class MapView;

@interface MainViewController : UIViewController <UIActionSheetDelegate,UIGestureRecognizerDelegate,UIContextMenuInteractionDelegate,UINavigationControllerDelegate,UIImagePickerControllerDelegate, CLLocationManagerDelegate>
{
    IBOutlet UIButton        *    _uploadButton;
    IBOutlet UIButton        *    _undoButton;
    IBOutlet UIButton        *    _redoButton;
    IBOutlet UIView            *    _undoRedoView;
    IBOutlet UIButton        *    _searchButton;
}

@property (assign,nonatomic) IBOutlet MapView    *    _Nonnull mapView;
@property (assign,nonatomic) IBOutlet UIButton     *     _Nonnull locationButton;
@property (assign,nonatomic) IBOutlet UIButton      *       _Nonnull cameraButton;
@property (assign,nonatomic) IBOutlet UIButton      *       _Nonnull galleryButton;
@property (assign,nonatomic) BUTTON_LAYOUT    buttonLayout;

@property (nonatomic, strong) CLLocationManager * _Nonnull locationManager;
@property (nonatomic, strong) CLLocation * _Nonnull currentLocation;
@property (nonatomic, strong) CLLocationManager * _Nonnull headingManager;
@property (nonatomic) CLLocationDirection currentHeading;
@property (nonatomic) BOOL headingCaptured;

-(IBAction)toggleLocation:(_Nullable id)sender;
- (IBAction)takePhoto:(UIButton *_Nullable)sender;
- (IBAction)selectPhoto:(UIButton *_Nullable)sender;

- (void)uploadPhotoToDigitalOcean:(UIImage * _Nonnull)photo;
- (void)transferPhotoToViewer:(NSDictionary * _Nonnull)dataDict;

-(void)setGpsState:(GPS_STATE)state;

- (void)updateUndoRedoButtonState;

@end
