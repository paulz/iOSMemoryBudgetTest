//
//  ViewController.m
//  MemoryTest
//
//  Created by Jan Ilavsky on 11/5/12.
//  Copyright (c) 2012 Jan Ilavsky. All rights reserved.
//

#import <sys/types.h>
#import <sys/sysctl.h>
#import <malloc/malloc.h>

#define CRASH_MEMORY_FILE_NAME @"CrashMemory.dat"
#define MEMORY_WARNINGS_FILE_NAME @"MemoryWarnings.dat"

@import UIKit;
@interface ViewController : UIViewController
@end

@interface ViewController () {
    
    NSTimer *timer;

    int allocatedMB;
    Byte *p[10000];
    uint64_t physicalMemorySize;
    uint64_t userMemorySize;
    
    NSMutableArray *infoLabels;
    NSMutableArray *memoryWarnings;
    
    BOOL initialLayoutFinished;
    BOOL firstMemoryWarningReceived;
}

@property (weak, nonatomic) IBOutlet UIView *progressBarBG;
@property (weak, nonatomic) IBOutlet UIView *alocatedMemoryBar;
@property (weak, nonatomic) IBOutlet UIView *kernelMemoryBar;
@property (weak, nonatomic) IBOutlet UILabel *userMemoryLabel;
@property (weak, nonatomic) IBOutlet UILabel *totalMemoryLabel;
@property (weak, nonatomic) IBOutlet UIButton *startButton;

@property (strong, nonatomic) NSString *crashFilePath;

@end

@implementation ViewController

#pragma mark - Helpers

static unsigned long long oneMB = 1048576;

- (void)refreshUI {
    
    unsigned long long physicalMemorySizeMB = physicalMemorySize / oneMB;
    unsigned long long userMemorySizeMB = userMemorySize / oneMB;
    
    self.userMemoryLabel.text = [NSString stringWithFormat:@"%llu MB -", userMemorySizeMB];
    self.totalMemoryLabel.text = [NSString stringWithFormat:@"%llu MB -", physicalMemorySizeMB];
    
    CGRect rect;
    
    CGFloat userMemoryProgressLength = self.progressBarBG.bounds.size.height *  (userMemorySizeMB / (float)physicalMemorySizeMB);
    
    rect = self.userMemoryLabel.frame;
    rect.origin.y = roundf((self.progressBarBG.bounds.size.height - userMemoryProgressLength) - self.userMemoryLabel.bounds.size.height * 0.5f + self.progressBarBG.frame.origin.y - 3);
    self.userMemoryLabel.frame = rect;
    
    rect = self.kernelMemoryBar.frame;
    rect.size.height = roundf(self.progressBarBG.bounds.size.height - userMemoryProgressLength);
    self.kernelMemoryBar.frame = rect;
    
    rect = self.alocatedMemoryBar.frame;
    rect.size.height = roundf(self.progressBarBG.bounds.size.height * (allocatedMB / (float)physicalMemorySizeMB));
    rect.origin.y = self.progressBarBG.bounds.size.height - rect.size.height;
    self.alocatedMemoryBar.frame = rect;
}

- (void)refreshMemoryInfo {
    [self get:HW_MEMSIZE info:&physicalMemorySize];
    [self get:HW_USERMEM info:&userMemorySize];
}

-(void)get:(int)hardwareInfoType info:(uint64_t *)value {
    int hardwareId[] = {CTL_HW, hardwareInfoType};
    size_t length = sizeof(*value);
    sysctl(hardwareId, sizeof(hardwareId)/sizeof(*hardwareId),
           value, &length,
           NULL, 0);
}

- (void)refreshAppMemory {
    struct mstats stats = mstats();
    physicalMemorySize = stats.bytes_total;
    userMemorySize = stats.bytes_used;
    NSLog(@"free:%zu, total: %zu", stats.bytes_free, stats.bytes_total);
    malloc_printf("free:%y, used:%y, total: %y\n", stats.bytes_free, stats.bytes_used, stats.bytes_total);
}

- (void)allocateMemory {
    NSUInteger mbToAllocate = 3;
    unsigned long long chunk = mbToAllocate * oneMB;
    
    p[allocatedMB] = malloc(chunk);
    memset(p[allocatedMB], 0, chunk);
    allocatedMB += mbToAllocate;
    
    [self refreshMemoryInfo];
    [self refreshAppMemory];
    [self refreshUI];
    
    if (firstMemoryWarningReceived) {
        [NSKeyedArchiver archiveRootObject:@(allocatedMB) toFile:self.crashFilePath];
    }
}

- (void)clearAll {
    
    for (int i = 0; i < allocatedMB; i++) {
        free(p[i]);
    }
    
    allocatedMB = 0;
    
    [infoLabels makeObjectsPerformSelector:@selector(removeFromSuperview)];
    [infoLabels removeAllObjects];
    
    [memoryWarnings removeAllObjects];
}

- (void)addLabelAtMemoryProgress:(NSInteger)memory text:(NSString*)text color:(UIColor*)color {

    CGFloat length = self.progressBarBG.bounds.size.height * (1.0f - memory / (float)(physicalMemorySize / 1048576));
    
    CGRect rect;
    rect.origin.x = 20;
    rect.size.width = self.progressBarBG.frame.origin.x - rect.origin.x - 8;
    rect.size.height = 20;
    rect.origin.y = roundf(self.progressBarBG.frame.origin.y + length - rect.size.height * 0.5f);

    UILabel *label = [[UILabel alloc] initWithFrame:rect];
    label.textAlignment = NSTextAlignmentRight;
    label.text = [NSString stringWithFormat:@"%@ %ld MB -", text, (long)memory];
    label.font = self.totalMemoryLabel.font;
    label.textColor = color;
    
    [infoLabels addObject:label];
    [self.view addSubview:label];
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    infoLabels = [[NSMutableArray alloc] init];
    memoryWarnings = [[NSMutableArray alloc] init];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    self.crashFilePath = [basePath stringByAppendingPathComponent:CRASH_MEMORY_FILE_NAME];
}

- (void)viewDidLayoutSubviews {
    
    if (!initialLayoutFinished) {
    
        [self refreshMemoryInfo];
        [self refreshUI];
        
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
        NSInteger crashMemory = [[NSKeyedUnarchiver unarchiveObjectWithFile:[basePath stringByAppendingPathComponent:CRASH_MEMORY_FILE_NAME]] intValue];
        if (crashMemory > 0) {
            [self addLabelAtMemoryProgress:crashMemory text:@"Crash" color:[UIColor colorWithRed:0.8 green:0.0 blue:0.0 alpha:1.0]];
        }
        
        NSArray *lastMemoryWarnings = [NSKeyedUnarchiver unarchiveObjectWithFile:[basePath stringByAppendingPathComponent:MEMORY_WARNINGS_FILE_NAME]];
        if (lastMemoryWarnings) {
            
            for (NSNumber *number in lastMemoryWarnings) {
                
                [self addLabelAtMemoryProgress:[number intValue] text:@"Memory Warning" color:[UIColor colorWithWhite:0.6 alpha:1.0]];
            }
        }
        
        initialLayoutFinished = YES;
    }
}

- (void)dealloc {
    [timer invalidate];
    [self clearAll];    
    
    infoLabels = nil;
    memoryWarnings = nil;
    
    initialLayoutFinished = NO;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    
    firstMemoryWarningReceived = YES;
    
    [self addLabelAtMemoryProgress:allocatedMB text:@"Memory Warning" color:[UIColor colorWithWhite:0.6 alpha:1.0]];
    
    [memoryWarnings addObject:@(allocatedMB)];
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    [NSKeyedArchiver archiveRootObject:memoryWarnings toFile:[basePath stringByAppendingPathComponent:MEMORY_WARNINGS_FILE_NAME]];
}

#pragma mark - Actions

- (IBAction)startButtonPressed:(id)sender {
    
    [self clearAll];
    
    firstMemoryWarningReceived = NO;
    
    [timer invalidate];
    timer = [NSTimer scheduledTimerWithTimeInterval:0.02 target:self selector:@selector(allocateMemory) userInfo:nil repeats:YES];
}

@end

