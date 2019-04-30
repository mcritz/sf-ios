//
//  EventDataSourceTests.m
//  SF iOSTests
//
//  Created by Amit Jain on 7/30/17.
//  Copyright © 2017 Amit Jain. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "EventDataSource.h"

@interface EventDataSourceTests : XCTestCase

@end

@implementation EventDataSourceTests

- (void)setUp {
    [super setUp];
}


- (void)testFilterEvents {
    EventDataSource *testEvtDataSource = [[EventDataSource alloc] initWithEventType:EventTypeSFCoffee];
    NSUInteger eventCount = [testEvtDataSource numberOfEvents];
    XCTAssertGreaterThan(eventCount, 0, @"There really should be events here. Are you connected to the internet? If not, it’s likely that production is unreachable and you have bigger problems.");
    Event *someEvent = [testEvtDataSource eventAtIndex:0];
    XCTAssertNotNil(someEvent);
    
    
    // I double dog dare you to make this a production event name
    NSString *completelyUnreasonableSearchTerm = @"Little Bobby Tables https://www.xkcd.com/327/";
    RLMResults *results = [testEvtDataSource filterEventsWithSearchTerm:completelyUnreasonableSearchTerm];
    XCTAssertEqual(results.count, 0);
}

/**
 This test will start failing as soon as more events are added. Figure out a better way to test CloudKit!
 The limitation is that w/o mocking the only way to test is with live records in the dev enviornment.
 */
//- (void)testFetchingCoffeeEvents {
//    XCTestExpectation *exp = [self expectationWithDescription:@"Wait for events"];
//    
//    EventDataSource *dataSource = [[EventDataSource alloc] initWithEventType:EventTypeSFCoffee database:self.database];
//    [dataSource fetchPreviousEventsWithCompletionHandler:^(BOOL didUpdate, NSError * _Nullable error) {
//        if (error) {
//            XCTAssertFalse(didUpdate);
//            XCTFail(@"Error fetching events: %@", error);
//        } else {
//            XCTAssertTrue(didUpdate);
//            XCTAssertEqual(dataSource.numberOfEvents, 2);
//        }
//        
//        [exp fulfill];
//    }];
//    
//    [self waitForExpectationsWithTimeout:2.0 handler:nil];
//}

@end
