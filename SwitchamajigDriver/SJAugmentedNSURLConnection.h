//
//  SJAugmentedNSURLConnection.h
//  SwitchamajigDriver
//
//  Created by Phil Weaver on 8/13/13.
//  Copyright (c) 2013 PAW Solutions. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SJAugmentedNSURLConnection : NSURLConnection {
    
}
@property NSString *SJHostName;
@property NSMutableData *SJData;
@property NSDate *connectionStartTime;
@end

