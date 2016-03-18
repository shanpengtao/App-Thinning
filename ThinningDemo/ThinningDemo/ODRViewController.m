//
//  ODRViewController.m
//  ThinningDemo
//
//  Created by shanpengtao on 16/1/13.
//  Copyright © 2016年 shanpengtao. All rights reserved.
//
/*
 ** 启用或关闭按需加载资源 **
 *
 * 在project navigator中选择工程文件。
 * 在project editor中选择对应的target。
 * 选择Build Settings选项卡。
 * 展开Assets分类。
 * 提示：可以在Build Settings选项卡右上角的搜索框中输入“Assets”，来快速定位到Assets分类。
 * 设置Enable On-Demand Resources的值。
 * Yes为这个target开启按需加载资源。
 * No为这个target关闭按需加载资源。
 *
 **/

/*
 ** 创建和编辑tag **
 *
 * 在project navigator中选择工程文件。
 * 在project editor中选择对应的target。
 * 选择Resource Tags选项卡。
 * 点击选项卡左上角的添加按钮（+）进行创建
 * ==================================
 * 搜索框：用来查找指定的tag或资源。
 * tag编辑器：用来更改tag的名称，删除tag，增删tag下的资源。tag下全部资源所占的存储大小会显示在tag名称右边的圆括号中。大小是依据最后一次构建所选择的运行设备来计算的。
 * tag视图选择器：用来在查看全部tag和查看预获取分类tag之间切换。tag可以在app安装时下载，在安装之后预获取，或者在app运行时按需加载。
 * 预取优先级编辑器也会显示每个分类中资源所占的存储大小。大小是依据最后一次构建所选择的运行设备来计算的。
 *
 **/

/*
 ** 在Asset Catalog中添加tag **
 *
 * 选择Asset Catalog。
 * 在job_manager_normal中选择要加tag的。
 * 为选择的项目打开Attributes inspector。
 * 在按需加载资源tag框，输入tag的名称。Xcode会根据输入的字符进行自动补全提示。
 * 按下Return键来确认输入的tag名称。
 *
 **/

/**
 *
 *  tag在列表的位置会决定下载的顺序。列表最上面的tag会最先下载。
 *
 *  初始安装tag（Initial install tags）。只有在初始安装tag下载到设备后，app才能启动。这些资源会在下载app时一起下载。这部分资源的大小会包括在App Store中app的安装包大小。如果这些资源从来没有被NSBundleResourceRequest对象获取过，就有可能被清理掉。
 *  按顺序预获取tag（Prefetch tag order）。在app安装后会开始下载tag。tag会按照此处指定的顺序来下载。
 *  按需下载（Dowloaded only on demand）。当app请求一个tag，且tag没有缓存时，才会下载该tag。
 *
 */


#import "ODRViewController.h"

@interface ODRViewController ()

@property (nonatomic, strong) NSBundleResourceRequest *lowPriorityRequest;

@property (nonatomic, strong) NSBundleResourceRequest *resourceRequest;

@property (nonatomic, strong) NSMutableArray *lowPriorityRequests;

@property (nonatomic, strong) UIImageView *imageView;

@end

@implementation ODRViewController

#pragma mark - ViewLife

- (void)dealloc
{
    [_resourceRequest.progress removeObserver:self forKeyPath:@"resourceRequestProgress"];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        /**
         *  低存储空间警告时的通知
         */
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(lowDiskSpace:) name:NSBundleResourceRequestLowDiskSpaceNotification object:nil];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    [self initView];
    
    [self initLowPriorityRequests];

    [self initResoutceRequest];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)initView
{
    self.view.backgroundColor = [UIColor whiteColor];
    
    _imageView = [[UIImageView alloc] init];
    _imageView.center = self.view.center;
    _imageView.userInteractionEnabled = YES;
    _imageView.backgroundColor = [UIColor redColor];
    [self.view addSubview:_imageView];

    UITapGestureRecognizer *singleFingerOne = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(releaseResource)];
    [_imageView addGestureRecognizer:singleFingerOne];
}

#pragma mark - initData
/**
 *  初始化低优先级的资源
 */
- (void)initLowPriorityRequests
{
    NSSet *tags = [NSSet setWithArray: @[@"tab"]];
    _lowPriorityRequest = [[NSBundleResourceRequest alloc] initWithTags:tags];
    _lowPriorityRequest.loadingPriority = 0.1;
    
    [_lowPriorityRequests addObject:_lowPriorityRequest];
}

/**
 *  加载高优先级的资源
 */
- (void)initResoutceRequest
{
    /*
     *  初始化NSBundleResourceRequest
     *
     *  如果资源都在app的main bundle中，使用 initWithTags:
     *  如果资源都在同一个自定义bundle中，使用 initWithTags:bundle:
     */
    NSSet *tags = [NSSet setWithArray: @[@"batch", @"company", @"other"]];
    _resourceRequest = [[NSBundleResourceRequest alloc] initWithTags:tags];
    
    /**
     *  检查保存优先级 默认为0 范围：0-1
     */
    double currentPriority = [[NSBundle mainBundle] preservationPriorityForTag:@"other"];
    NSLog(@"currentPriority:%f",currentPriority);
    /**
     *  设置保存优先级
     */
    NSSet *tags2 = [NSSet setWithArray:@[@"other"]];
    [[NSBundle mainBundle] setPreservationPriority:1.0 forTags:tags2];
    
    /**
     *  设置下载优先级，可根基实际情况去设置 0.0 》loadingPriority 》 1.0
     * NSBundleResourceRequestLoadingPriorityUrgent 。这会告诉操作系统尽可能多地分配资源来处理下载。
     */
    _resourceRequest.loadingPriority = NSBundleResourceRequestLoadingPriorityUrgent;

    // 开始下载
    [self startRequestData];
    
    /**
     *  监测下载资源进度变化
     */
    [_resourceRequest.progress addObserver:self forKeyPath:@"resourceRequestProgress" options:NSKeyValueObservingOptionNew context:NULL];
    
    /**
     *  暂停当前下载
     */
    //    [_resourceRequest.progress pause];
    //
    //    /**
    //     *  恢复当前下载
    //     */
    //    [_resourceRequest.progress resume];
    //
    //    /**
    //     *  取消当前下载
    //     */
    //    [_resourceRequest.progress cancel];
}

#pragma mark - Custom Method
- (void)startRequestData
{
    /**
     *  1.注意：在允许访问之后，不要使用同一个NSBundleResourceRequest实例再次请求访问。
     *
     *  2.注意：如果 conditionallyBeginAccessingResourcesWithCompletionHandler 返回YES
     *  就不要调用 beginAccessingResourcesWithCompletionHandler 了
     *
     *  3.每个NSBundleResourceRequest对象都只能用于一个请求访问/结束访问循环。
     */

    [_resourceRequest conditionallyBeginAccessingResourcesWithCompletionHandler:^(BOOL resourcesAvailable) {
         if (resourcesAvailable) {
             NSLog(@"本地已存在高质量资源");

             [self loadImage];
         }
         else {
             // 可使用低质量的资源 也可以去下载高质量的资源
             BOOL needHightResource = YES;
             if (needHightResource) {
                 [_resourceRequest beginAccessingResourcesWithCompletionHandler:^(NSError *__nullable error) {
                     if (error) {
                         NSLog(@"下载失败");
                         return;
                     }
                     NSLog(@"下载成功");
                    
                     [self loadImage];
                 }];
             }
             else {
                 NSLog(@"加载低质量资源");
                 [self loadLowQualityImage];
             }
        }
    }];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ((object == _resourceRequest.progress) && ([keyPath isEqualToString:@"resourceRequestProgress"])) {
        double progressSoFar = _resourceRequest.progress.fractionCompleted;
        NSLog(@"progress:%f", progressSoFar);
    }
}

-(void)lowDiskSpace:(NSNotification*)theNotification
{
    /**
     *  可以删除一些低保存优先级的资源
     */
    for (NSBundleResourceRequest *aRequest in self.lowPriorityRequests) {
        [aRequest endAccessingResources];
    }
    
    [self.lowPriorityRequests removeAllObjects];
}

- (void)loadImage
{
    __weak typeof(self) weakSelf = self;

    dispatch_async(dispatch_get_main_queue(), ^{

        __strong typeof(weakSelf) strongSelf = weakSelf;

        UIImage *image = [UIImage imageNamed:@"ODR"];
        strongSelf.imageView.image = image;
        strongSelf.imageView.bounds = CGRectMake(0, 0, image.size.width, image.size.height);

    });
}

- (void)loadLowQualityImage
{
    __weak typeof(self) weakSelf = self;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        __strong typeof(weakSelf) strongSelf = weakSelf;
        UIImage *image = [UIImage imageNamed:@"ODR_low"];
        
        strongSelf.imageView.image = image;
        strongSelf.imageView.bounds = CGRectMake(0, 0, image.size.width, image.size.height);
        
    });
}

- (void)releaseResource
{
    /**
     *  结束当前tag的访问
     *  在endAccessingResources（异步）调用之后，这个请求就不能再用于请求访问了。如果app还需要访问同一个tag，需要再重新创建一个NSBundleResourceRequest实例。
     */
    [_resourceRequest endAccessingResources];
    _resourceRequest = nil;
    
    double delayInSeconds = 1.0;

    __weak typeof(self) weakSelf = self;

    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){

        __strong typeof(weakSelf) strongSelf = weakSelf;
        
        UIImage *image = [UIImage imageNamed:@"ODR"];
        
        strongSelf.imageView.image = image;
        strongSelf.imageView.bounds = CGRectMake(0, 0, image.size.width, image.size.height);
    });
    
    // 测试一下NSBundleResourceRequest被释放掉后再次请求使用
//    [self startRequestData];
}

@end
