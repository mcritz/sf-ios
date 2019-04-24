//
//  FeedItem.m
//  SF iOS
//
//  Created by Amit Jain on 7/31/17.
//  Copyright © 2017 Amit Jain. All rights reserved.
//

#import "FeedItem.h"
#import "NSDate+Utilities.h"
#import "NSAttributedString+EventDetails.h"
#import "Venue.h"

@interface FeedItem ()

@property (readwrite, assign, nonatomic) BOOL isActive;

@end

@implementation FeedItem

- (instancetype)initWithEvent:(Event *)event {
    self = [super init];
    if (!self) {
        return nil;
    }
    self.dateString = [event.date dateString];
    self.title = event.name;
    self.isActive = event.isActive;
    if (![event.imageFileURLString isEqual:[NSNull null]]) {
        self.coverImageFileURL = event.imageFileURL;
    }
    self.annotationGlyph = event.annotationGlyph;
    
    NSString *time;
    
    if ([[NSDate new] isBetweenEarlierDate:event.date laterDate:event.endDate]) {
        time = @"Now";
    } else {
        time = [NSDate timeslotStringFromStartDate:event.date duration:event.duration];
    }
    
    self.subtitle = [NSAttributedString attributedDetailsStringFromEvent:event];

    return self;
}

- (BOOL)directionsAreRelevantForEventWithDate:(NSDate *)date {
    if (date.isToday || date.isInFuture) {
        return true;
    }
    return false;
}

@end
