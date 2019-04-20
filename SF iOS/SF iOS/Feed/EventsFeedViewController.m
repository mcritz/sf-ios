//
//  EventsFeedViewController.m
//  SF iOS
//
//  Created by Amit Jain on 7/31/17.
//  Copyright © 2017 Amit Jain. All rights reserved.
//

#import "EventsFeedViewController.h"
#import "EventDetailsViewController.h"
#import "FeedItemCell.h"
#import "FeedItem.h"
#import "UserLocation.h"
#import "UIViewController+StatusBarBackground.h"
#import "UIImage+URL.h"
#import "ImageStore.h"

NS_ASSUME_NONNULL_BEGIN
@interface EventsFeedViewController () <EventDataSourceDelegate, UITableViewDataSource, UITableViewDelegate, UIViewControllerPreviewingDelegate, UISearchBarDelegate>

@property (nonatomic) EventDataSource *dataSource;
@property (nonatomic) UITableView *tableView;
@property (nonatomic, assign) BOOL firstLoad;
@property (nonatomic) ImageStore *imageStore;
@property (nonatomic) NSOperationQueue *imageFetchQueue;
@property (nullable, nonatomic) UserLocation *userLocationService;
@property (nonatomic) UISearchBar *searchBar;
@property (nonatomic) UIView *noResultsView;
@end
NS_ASSUME_NONNULL_END

@implementation EventsFeedViewController

#define kSEARCHBARHEIGHT 32
#define kTABLEHEADERHEIGHT (2 * kSEARCHBARHEIGHT)

- (instancetype)initWithDataSource:(EventDataSource *)dataSource {
    if (self = [super initWithNibName:nil bundle:nil]) {
        self.dataSource = dataSource;
        dataSource.delegate = self;
        self.userLocationService = [UserLocation new];
        self.imageFetchQueue = [[NSOperationQueue alloc] init];
        self.imageFetchQueue.name = @"Image Fetch Queue";
        self.imageStore = [[ImageStore alloc] init];
        self.firstLoad = self.dataSource.numberOfEvents == 0;
    }
    
    return self;
}

- (instancetype)initWithStyle:(UITableViewStyle)style {
    NSAssert(false, @"Use -initWithDataSource");
    self = [self initWithDataSource:[EventDataSource new]];
    return self;
}

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    NSAssert(false, @"Use -initWithDataSource");
    self = [self initWithDataSource:[EventDataSource new]];
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    NSAssert(false, @"Use -initWithDataSource");
    self = [self initWithDataSource:[EventDataSource new]];
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    [self.tableView registerClass:self.feedItemCellClass forCellReuseIdentifier:NSStringFromClass(self.feedItemCellClass)];
    self.tableView.rowHeight = self.cellHeight;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.tableHeaderView.backgroundColor = UIColor.clearColor;
    
    UIEdgeInsets safeInsets = self.view.safeAreaInsets;
    self.tableView.contentInset = UIEdgeInsetsMake(safeInsets.top + kSEARCHBARHEIGHT,
                                                   safeInsets.right,
                                                   safeInsets.bottom,
                                                   safeInsets.right);
    self.tableView.translatesAutoresizingMaskIntoConstraints = false;
    self.tableView.delaysContentTouches = NO;
    [self.view addSubview:self.tableView];

    [self.tableView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor].active = true;
    [self.tableView.leftAnchor constraintEqualToAnchor:self.view.leftAnchor].active = true;
    [self.tableView.rightAnchor constraintEqualToAnchor:self.view.rightAnchor].active = true;
    [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor].active = true;
    [self.tableView.widthAnchor constraintEqualToAnchor:self.view.widthAnchor].active = true;
    
    self.tableView.refreshControl = [[UIRefreshControl alloc] init];
    [self.tableView.refreshControl addTarget:self action:@selector(handleRefresh) forControlEvents:UIControlEventValueChanged];
    
    if (self.traitCollection.forceTouchCapability == UIForceTouchCapabilityAvailable) {
        [self registerForPreviewingWithDelegate:self sourceView:self.tableView];
    }
    
    CGRect searchBarRect = CGRectMake(0, 0, self.view.frame.size.width, kSEARCHBARHEIGHT);
    self.searchBar = [[UISearchBar alloc] initWithFrame:searchBarRect];
    self.searchBar.searchBarStyle = UISearchBarStyleMinimal;
    self.searchBar.placeholder = NSLocalizedString(@"Filter", @"Prompt to search for event names. Here, `Filter` is a joke in English because people filter coffee and this list can be filtered by a term.");
    self.searchBar.showsCancelButton = true;
    self.searchBar.delegate = self;
    
    // TODO: There’s probably a better way of doing this that doesn’t require a new view
    // https://github.com/ThumbWorks/sf-ios/issues/37
    CGRect tableSearchViewRect = CGRectMake(0, 0, self.searchBar.frame.size.width, kTABLEHEADERHEIGHT);
    UIView *tableSearchView = [[UIView alloc] initWithFrame:tableSearchViewRect];
    tableSearchView.backgroundColor = UIColor.whiteColor;
    [tableSearchView addSubview:self.searchBar];
    self.tableView.tableHeaderView = tableSearchView;
    
    self.tableView.tableHeaderView.backgroundColor = UIColor.whiteColor;
    CGPoint contentOffest = self.tableView.contentOffset;
    contentOffest.y += kSEARCHBARHEIGHT;
    self.tableView.contentOffset = contentOffest;
    
    // TODO: Add an invisible, dismissng button below the search UI
    
    self.noResultsView = [[UIView alloc] init];
    self.noResultsView.frame = CGRectMake(0, (1.5 * kTABLEHEADERHEIGHT), self.tableView.frame.size.width, (self.view.bounds.size.height - (4 * kTABLEHEADERHEIGHT)));
    [self.noResultsView setHidden:true];
    [self.view addSubview:self.noResultsView];
    CGRect labelFrame = CGRectMake(0, 0, self.view.frame.size.width, 100);
    UILabel *noResultsLabel = [[UILabel alloc] initWithFrame:labelFrame];
    noResultsLabel.text = NSLocalizedString(@"No events", @"Displayed when no Event names match the given search term");
    noResultsLabel.textAlignment = NSTextAlignmentCenter;
    noResultsLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleTitle2];
    [self.noResultsView addSubview:noResultsLabel];
    
    [noResultsLabel.topAnchor constraintEqualToAnchor:self.noResultsView.topAnchor].active = true;
    [noResultsLabel.leftAnchor constraintEqualToAnchor:self.noResultsView.leftAnchor].active = true;
    [noResultsLabel.rightAnchor constraintEqualToAnchor:self.noResultsView.rightAnchor].active = true;
    [noResultsLabel.bottomAnchor constraintEqualToAnchor:self.noResultsView.bottomAnchor].active = true;
    [noResultsLabel.widthAnchor constraintEqualToAnchor:self.noResultsView.widthAnchor].active = true;

    [self.noResultsView.topAnchor constraintEqualToAnchor:self.searchBar.bottomAnchor].active = true;
    [self.noResultsView.leftAnchor constraintEqualToAnchor:self.tableView.leftAnchor].active = true;
    [self.noResultsView.rightAnchor constraintEqualToAnchor:self.tableView.rightAnchor].active = true;
    [self.noResultsView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor].active = true;
    [self.noResultsView.widthAnchor constraintEqualToAnchor:self.tableView.widthAnchor].active = true;
    
    [self addStatusBarBlurBackground];

    [self.dataSource refresh];
}

- (void)viewDidDisappear:(BOOL)animated {
    [self.tableView.refreshControl endRefreshing];
    [self.imageFetchQueue cancelAllOperations];
    
    [super viewDidDisappear:animated];
}

//MARK: - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.dataSource.numberOfEvents;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    FeedItemCell *cell = [tableView dequeueReusableCellWithIdentifier:NSStringFromClass(self.feedItemCellClass) forIndexPath:indexPath];
    if (!cell) {
        NSAssert(false, @"cell couldn't be dequeued");
    }
    
    FeedItem *item = [[FeedItem alloc] initWithEvent:[self.dataSource eventAtIndex:indexPath.row]];
    [cell configureWithFeedItem:item];
    
    UIImage *image = [self.imageStore imageForKey:[item.coverImageFileURL absoluteString]];
    if (image) {
        [cell setCoverToImage:image];
    } else {
        __weak typeof(self) welf = self;
        [UIImage
         fetchImageFromURL:item.coverImageFileURL
         onQueue: self.imageFetchQueue
         withCompletionHandler:^(UIImage * _Nullable image, NSError * _Nullable error) {
             if (!image || error) {
                 NSLog(@"Error decoding image: %@", error);
                 return;
             }
             [welf.imageStore storeImage:image forKey:[item.coverImageFileURL absoluteString]];

             // Fetch the cell again, if it exists as the original instance of cell might have been
             // dequeued by now. If the cell does not exist, setting the image will silently fail.
             [(FeedItemCell *)[tableView cellForRowAtIndexPath:indexPath] setCoverToImage:image];
         }];
    }
    
    return cell;
}

- (Class)feedItemCellClass {
    return [FeedItemCell class];
}

//MARK: - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self.userLocationService requestLocationPermission];
    EventDetailsViewController *vc = [self eventDetailsViewControllerForEventAtIndexPath:indexPath];
    [self presentViewController:vc animated:true completion:nil];
}

- (void)handleRefresh {
    self.dataSource.searchQuery = @"";
    self.searchBar.text = @"";
    [self.tableView reloadData];
    [self handleFilterResults];
    [self.tableView.refreshControl endRefreshing];
}

//MARK: - 3D Touch Peek & Pop

- (UIViewController *)previewingContext:(id<UIViewControllerPreviewing>)previewingContext viewControllerForLocation:(CGPoint)location {
    NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:location];
    if (!indexPath) { return nil; }
    
    UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
    if (!cell || ![cell isKindOfClass:[self.feedItemCellClass class]]) {
        return nil;
    }
    
    previewingContext.sourceRect = [(FeedItemCell *)cell contentFrame];
    
    return [self eventDetailsViewControllerForEventAtIndexPath:indexPath];
}

- (void)previewingContext:(id<UIViewControllerPreviewing>)previewingContext commitViewController:(UIViewController *)viewControllerToCommit {
    [self presentViewController:viewControllerToCommit animated:true completion:nil];
}

//MARK: - UISearchBarDelegate
- (void)handleFilterResults {
    if (self.dataSource.numberOfEvents < 1) {
        [self.noResultsView setHidden:false];
        return;
    }
    [self.noResultsView setHidden:true];
    [self.tableView.refreshControl endRefreshing];
}

- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar {
    self.tableView.scrollEnabled = false;
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    self.dataSource.searchQuery = searchText;
    [self.tableView reloadData];
    [self handleFilterResults];
}

- (void)searchBarTextDidEndEditing:(UISearchBar *)searchBar {
    self.tableView.scrollEnabled = true;
    [searchBar resignFirstResponder];
    self.dataSource.searchQuery = searchBar.text;
    [self.tableView reloadData];
    [self handleFilterResults];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
    self.tableView.scrollEnabled = true;
    [searchBar resignFirstResponder];
    self.dataSource.searchQuery = @"";
    [self.tableView reloadData];
    [self handleFilterResults];
    searchBar.text = @"";
    [self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0] atScrollPosition:UITableViewScrollPositionTop animated:YES];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    self.tableView.scrollEnabled = true;
    [searchBar resignFirstResponder];
    self.dataSource.searchQuery = searchBar.text;
    [self.tableView reloadData];
    [self handleFilterResults];
}

//MARK: - EventDataSourceDelegate

- (void)willUpdateDataSource:(EventDataSource *)datasource {
    [self.tableView.refreshControl beginRefreshing];
}

- (void)didChangeDataSourceWithInsertions:(nullable NSArray<NSIndexPath *> *)insertions updates:(nullable NSArray<NSIndexPath *> *)updates deletions:(nullable NSArray<NSIndexPath *> *)deletions {
    
    // Don’t crash the app by modifying the table while the user is searching
    if (self.dataSource.searchQuery.length > 0) { return; }
    
    // Otherwise update on changes
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.tableView beginUpdates];
        [self.tableView deleteRowsAtIndexPaths:deletions
                              withRowAnimation:UITableViewRowAnimationAutomatic];
        [self.tableView insertRowsAtIndexPaths:insertions
                              withRowAnimation:UITableViewRowAnimationTop];
        [self.tableView reloadRowsAtIndexPaths:updates
                              withRowAnimation:UITableViewRowAnimationNone];
        [self.tableView endUpdates];
        [self.tableView.refreshControl endRefreshing];
    });
}

- (void)didFailToUpdateWithError:(nonnull NSError *)error {
    [self handleError:error];
    [self.tableView.refreshControl endRefreshing];
}

//MARK: - Details View

- (EventDetailsViewController *)eventDetailsViewControllerForEventAtIndexPath:(NSIndexPath *)indexPath {
    Event *event = [self.dataSource eventAtIndex:indexPath.row];
    return [[EventDetailsViewController alloc] initWithEvent:event userLocationService:self.userLocationService];
}

//MARK: - Cell Dimensions

static CGFloat const eventCellAspectRatio = 1.352;

- (CGFloat)cellHeight{
    return [UIScreen mainScreen].bounds.size.width * eventCellAspectRatio;
}

//MARK: - Error Handling

- (void)handleError:(NSError *)error {
    NSLog(@"Error fetching events: %@", error);
    NSString *errorTitle = NSLocalizedString(@"Error Fetching Events",
                                              @"Title label for when a fetch from the network failed");
    NSString *errorMessage = NSLocalizedString(@"There was an error fetching events. Please try again",
                                               @"Title message body for when a fetch from the network failed");
    UIAlertController *alert = [UIAlertController
                                alertControllerWithTitle:errorTitle
                                message:errorMessage
                                preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [alert dismissViewControllerAnimated:true completion:nil];
    }];
    [alert addAction:okAction];
    
    [self presentViewController:alert animated:true completion:nil];
}

//MARK: - First Load

- (void)refresh {
    if (!self.firstLoad) {
        [self.tableView reloadData];
        return;
    }
    
    [self animateFirstLoad];
    self.firstLoad = false;
}

- (void)animateFirstLoad {
    [self.tableView reloadData];
    
    if (self.dataSource.indexOfCurrentEvent != NSNotFound) {
        NSIndexPath *nextEventIndexPath = [NSIndexPath indexPathForRow:self.dataSource.indexOfCurrentEvent inSection:0];
        [self.tableView scrollToRowAtIndexPath:nextEventIndexPath atScrollPosition:UITableViewScrollPositionMiddle animated:false];
    }
    
    NSTimeInterval stagger = 0.2;
    [self.tableView.visibleCells enumerateObjectsUsingBlock:^(__kindof UITableViewCell * _Nonnull cell, NSUInteger idx, BOOL * _Nonnull stop) {
        cell.transform = CGAffineTransformTranslate(CGAffineTransformIdentity, 0, [UIScreen mainScreen].bounds.size.height);
        cell.alpha = 0;
        
        [UIView
         animateWithDuration:0.8
         delay:stagger * (idx + 1)
         usingSpringWithDamping:0.8
         initialSpringVelocity:0
         options:0
         animations:^{
             cell.alpha = 1;
             cell.transform = CGAffineTransformIdentity;
         }
         completion:nil];
    }];
}

@end
