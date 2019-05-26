//
//  Group.m
//  Coffup
//
//  Created by Roderic Campbell on 4/17/19.
//

#import "Group.h"

@implementation Group
- (instancetype)initWithDictionary:(NSDictionary *)record {
    if (self = [super init]) {
        self.groupID = record[@"id"];
        self.imageURLString = record[@"image_url"];
        self.name = record[@"name"];
    }
    return self;
}

+ (NSString *)primaryKey {
    return @"groupID";
}

+ (NSArray *)ignoredProperties {
    return @[@"displayPriority"];
}

- (NSInteger)displayPriority {
    return [[NSUserDefaults standardUserDefaults] integerForKey:@"display_priority"];
}

- (void)setDisplayPriority: (NSInteger) newDisplayPriority {
    [[NSUserDefaults standardUserDefaults] setInteger:newDisplayPriority
                                               forKey:@"display_priority"];
}

@end
