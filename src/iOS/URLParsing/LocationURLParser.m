//
//  GeoURLParser.m
//  Go Map!!
//
//  Created by Wolfgang Timme on 2/2/20.
//  Copyright © 2020 Bryce. All rights reserved.
//

#import "LocationURLParser.h"
#import "MapView.h"


@implementation LocationURLParser

- (MapLocation *)parseURL:(NSURL *)url
{
    if ( [url.absoluteString hasPrefix:@"geo:"] ) {
        // geo:47.75538,-122.15979?z=18
        double lat = 0, lon = 0, zoom = 0;
        NSScanner * scanner = [NSScanner scannerWithString:url.absoluteString];
        [scanner scanString:@"geo:" intoString:NULL];
        if (![scanner scanDouble:&lat]) {
            /// Invalid latitude
            return nil;
        }
        [scanner scanString:@"," intoString:NULL];
        if (![scanner scanDouble:&lon]) {
            /// Invalid longitude
            return nil;
        }
        while ( [scanner scanString:@";" intoString:NULL] ) {
            NSMutableCharacterSet * nonSemicolon = [[NSCharacterSet characterSetWithCharactersInString:@";"] mutableCopy];
            [nonSemicolon invert];
            [scanner scanCharactersFromSet:nonSemicolon intoString:NULL];
        }
        if ( [scanner scanString:@"?" intoString:NULL] && [scanner scanString:@"z=" intoString:NULL] ) {
            [scanner scanDouble:&zoom];
        }
        
        MapLocation * parserResult = [MapLocation new];
        parserResult.longitude = lon;
        parserResult.latitude  = lat;
        parserResult.zoom      = zoom;
        parserResult.viewState = MAPVIEW_NONE;
        return parserResult;
    }

    NSURLComponents * urlComponents = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];

    // https://gomaposm.com/edit?center=47.679056,-122.212559&zoom=21&view=aerial%2Beditor
    if ( [url.absoluteString hasPrefix:@"gomaposm://?"] || [urlComponents.host isEqualToString:@"gomaposm.com"] ) {
        BOOL hasCenter = NO, hasZoom = NO;
        double lat = 0, lon = 0, zoom = 0;
        MapViewState view = MAPVIEW_NONE;

        for ( NSURLQueryItem * queryItem in urlComponents.queryItems ) {

            if ( [queryItem.name isEqualToString:@"center"] ) {
                // scan center
                NSScanner * scanner = [NSScanner scannerWithString:queryItem.value];
                hasCenter = [scanner scanDouble:&lat] &&
                            [scanner scanString:@"," intoString:NULL] &&
                            [scanner scanDouble:&lon] &&
                            scanner.isAtEnd;
            } else if ( [queryItem.name isEqualToString:@"zoom"] ) {
                // scan zoom
                NSScanner * scanner = [NSScanner scannerWithString:queryItem.value];
                hasZoom = [scanner scanDouble:&zoom] &&
                            scanner.isAtEnd;
            } else if ( [queryItem.name isEqualToString:@"view"] ) {
                // scan view
                if ( [queryItem.value isEqualToString:@"aerial+editor"] ) {
                    view = MAPVIEW_EDITORAERIAL;
                } else if ( [queryItem.value isEqualToString:@"aerial"] ) {
                    view = MAPVIEW_AERIAL;
                } else if ( [queryItem.value isEqualToString:@"mapnik"] ) {
                    view = MAPVIEW_MAPNIK;
                } else if ( [queryItem.value isEqualToString:@"editor"] ) {
                    view = MAPVIEW_EDITOR;
                } else if ( [queryItem.value isEqualToString:@"aerial+mapnik"]) {
                    view = MAPVIEW_AERIAL_MAPNIK;
                }
            } else {
                // unrecognized parameter
            }
        }
        if ( hasCenter ) {
            MapLocation * parserResult = [MapLocation new];
            parserResult.longitude = lon;
            parserResult.latitude  = lat;
            parserResult.zoom      = hasZoom ? zoom : 0.0;
            parserResult.viewState = view;
            return parserResult;
        }
    }
    return nil;
}

@end


//-(BOOL)application:(UIApplication *)application openURL:(NSURL *)url options:(nonnull NSDictionary<NSString *,id> *)options
//{
//    if ( [url.absoluteString hasPrefix:@"geo:"] ) {
//        // geo:47.75538,-122.15979?z=18
//        double lat = 0, lon = 0, zoom = 0;
//        NSScanner * scanner = [NSScanner scannerWithString:url.absoluteString];
//        [scanner scanString:@"geo:" intoString:NULL];
//        [scanner scanDouble:&lat];
//        [scanner scanString:@"," intoString:NULL];
//        [scanner scanDouble:&lon];
//        while ( [scanner scanString:@";" intoString:NULL] ) {
//            NSMutableCharacterSet * nonSemicolon = [[NSCharacterSet characterSetWithCharactersInString:@";"] mutableCopy];
//            [nonSemicolon invert];
//            [scanner scanCharactersFromSet:nonSemicolon intoString:NULL];
//        }
//        if ( [scanner scanString:@"?" intoString:NULL] && [scanner scanString:@"z=" intoString:NULL] ) {
//            [scanner scanDouble:&zoom];
//        }
//        [self setMapLatitude:lat longitude:lon zoom:zoom view:MAPVIEW_NONE];
//    }
//
//    // open to longitude/latitude
//    if ( [url.absoluteString hasPrefix:@"gomaposm://?"] ) {
//
//        NSArray * params = [url.query componentsSeparatedByString:@"&"];
//        BOOL hasCenter = NO, hasZoom = NO;
//        double lat = 0, lon = 0, zoom = 0;
//        MapViewState view = MAPVIEW_NONE;
//
//        for ( NSString * param in params ) {
//            NSScanner * scanner = [NSScanner scannerWithString:param];
//
//            if ( [scanner scanString:@"center=" intoString:NULL] ) {
//
//                // scan center
//                BOOL ok = YES;
//                if ( ![scanner scanDouble:&lat] )
//                    ok = NO;
//                if ( ![scanner scanString:@"," intoString:NULL] )
//                    ok = NO;
//                if ( ![scanner scanDouble:&lon] )
//                    ok = NO;
//                hasCenter = ok;
//
//            } else if ( [scanner scanString:@"zoom=" intoString:NULL] ) {
//
//                // scan zoom
//                BOOL ok = YES;
//                if ( ![scanner scanDouble:&zoom] )
//                    ok = NO;
//                hasZoom = ok;
//
//            } else if ( [scanner scanString:@"view=" intoString:NULL] ) {
//
//                // scan view
//                if ( [scanner scanString:@"aerial+editor" intoString:NULL] ) {
//                    view = MAPVIEW_EDITORAERIAL;
//                } else if ( [scanner scanString:@"aerial" intoString:NULL] ) {
//                    view = MAPVIEW_AERIAL;
//                } else if ( [scanner scanString:@"mapnik" intoString:NULL] ) {
//                    view = MAPVIEW_MAPNIK;
//                } else if ( [scanner scanString:@"editor" intoString:NULL] ) {
//                    view = MAPVIEW_EDITOR;
//                }
//
//            } else {
//                // unrecognized parameter
//            }
//        }
//        if ( hasCenter ) {
//            [self setMapLatitude:lat longitude:lon zoom:(hasZoom?zoom:0) view:view];
//        } else {
//            UIAlertController * alertView = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Invalid URL",nil) message:url.absoluteString preferredStyle:UIAlertControllerStyleAlert];
//            [alertView addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK",nil) style:UIAlertActionStyleCancel handler:nil]];
//            [self.mapView.viewController presentViewController:alertView animated:YES completion:nil];
//        }
//    }
//
//    // GPX support
//    if ( url.isFileURL && [url.pathExtension isEqualToString:@"gpx"] ) {
//
//        // Process the URL
//
//        double delayInSeconds = 1.0;
//        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
//        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
//            NSData * data = [NSData dataWithContentsOfURL:url];
//            BOOL ok = [self.mapView.gpxLayer loadGPXData:data center:YES];
//            if ( !ok ) {
//                UIAlertController * alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Open URL",nil)
//                                                                                message:NSLocalizedString(@"Sorry, an error occurred while loading the GPX file",nil)
//                                                                         preferredStyle:UIAlertControllerStyleAlert];
//                [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK",nil) style:UIAlertActionStyleCancel handler:nil]];
//                [self.mapView.viewController presentViewController:alert animated:YES completion:nil];
//            }
//        });
//
//        // Indicate that we have successfully opened the URL
//        return YES;
//    }
//    return NO;
//}
