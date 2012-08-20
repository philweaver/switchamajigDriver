//
//  SwitchamajigDriver.m
//  SwitchamajigDriver
//
//  Created by Phil Weaver on 5/27/12.
//  Copyright (c) 2012 PAW Solutions. All rights reserved.
//

#import "SwitchamajigDriver.h"
const NSString *SwitchamajigDriverErrorDomain = @"com.switchamjig.switchamajigDriver";
@implementation SwitchamajigDriver
@synthesize delegate;
- (id) initWithHostname:(NSString *)hostName {
    return nil;
}

- (void) issueCommandFromXMLNode:(DDXMLNode*) xmlCommandNode error:(NSError **)error{
    
}
@end


@implementation SwitchamajigListener
@synthesize delegate;
- (id) initWithDelegate:(id)delegate_init {
    return nil;
}

@end