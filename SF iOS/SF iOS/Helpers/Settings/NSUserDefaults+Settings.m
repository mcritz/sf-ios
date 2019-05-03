//
//  NSUserDefaults+Settings.m
//  SF iOS
//
//  Created by Zachary Drayer on 4/8/19.
//

#import "NSUserDefaults+Settings.h"
#import "Group.h"

@implementation NSUserDefaults (Settings)

- (NSString *)SFIOS_directionsProviderKey {
    return NSStringFromSelector(@selector(directionsProvider));
}

- (NSString *)SFIOS_notifiationsDictionaryKey {
    return NSStringFromSelector(@selector(notificationSettingForGroup:));
}

- (SettingsDirectionProvider)directionsProvider {
    return [self integerForKey:self.SFIOS_directionsProviderKey];
}

- (void)setDirectionsProvider:(SettingsDirectionProvider)directionsProvider {
    [self setInteger:directionsProvider forKey:self.SFIOS_directionsProviderKey];
}

- (void)setNotificationSetting:(BOOL)isOn forGroup:(nonnull Group *)group {
    NSNumber *newValue = [NSNumber numberWithBool:isOn];
    NSString *key = self.SFIOS_notifiationsDictionaryKey;
    // TODO until group interactions are merged in this is always sf-ios-coffee
    NSString *groupID = @"28ef50f9-b909-4f03-9a69-a8218a8cbd99";// group.groupID;
    NSMutableDictionary<NSString *, NSNumber *> *settingsDictionary = [[self dictionaryForKey:key] mutableCopy];
    if (settingsDictionary == nil) {
        settingsDictionary = [[NSMutableDictionary<NSString *, NSNumber *> alloc] initWithObjectsAndKeys:newValue,
                              groupID,
                              nil];
    } else {
        [settingsDictionary setObject:newValue forKey:groupID];
    }
    [self setObject:settingsDictionary forKey:key];
}


- (BOOL)notificationSettingForGroup:(nonnull Group *)group {
    // TODO until group interactions are merged in this is always sf-ios-coffee
    NSString *groupID = @"28ef50f9-b909-4f03-9a69-a8218a8cbd99";// group.groupID;
    NSDictionary *settingsDictionary = [self dictionaryForKey:self.SFIOS_notifiationsDictionaryKey];
    return [[settingsDictionary valueForKey:groupID] boolValue];
}

@end
