#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static UIButton *floatingButton = nil;
static BOOL menuVisible = NO;
static BOOL hitboxesEnabled = NO;
static float hitboxScale = 1.0;
static NSMutableArray *friendsList = nil;
static IMP orig_getAABB = NULL;

static UIWindow *GetKeyWindow(void) {
    UIWindow *w = nil;
    if (@available(iOS 13.0, *)) {
        for (UIScene *s in [UIApplication sharedApplication].connectedScenes) {
            if ([s isKindOfClass:[UIWindowScene class]] && s.activationState == UISceneActivationStateForegroundActive) {
                for (UIWindow *ww in ((UIWindowScene *)s).windows) if (ww.isKeyWindow) { w = ww; break; }
            }
        }
    }
    if (!w) w = [UIApplication sharedApplication].keyWindow;
    return w;
}

static void *hooked_getAABB(id self, SEL _cmd) {
    typedef void *(*F)(id, SEL);
    F orig = (F)orig_getAABB;
    if (!hitboxesEnabled || !orig) return orig(self, _cmd);
    
    NSString *name = nil;
    if ([self respondsToSelector:NSSelectorFromString(@"getName")])
        name = [self performSelector:NSSelectorFromString(@"getName")];
    if (name && [friendsList containsObject:name]) return orig(self, _cmd);
    
    float *box = (float *)orig(self, _cmd);
    if (!box) return NULL;
    
    float cx = (box[0]+box[3])/2, cy = (box[1]+box[4])/2, cz = (box[2]+box[5])/2;
    float hx = (box[3]-box[0])/2*hitboxScale, hy = (box[4]-box[1])/2*hitboxScale, hz = (box[5]-box[2])/2*hitboxScale;
    box[0]=cx-hx; box[3]=cx+hx; box[1]=cy-hy; box[4]=cy+hy; box[2]=cz-hz; box[5]=cz+hz;
    return box;
}

static void InstallHooks(void) {
    NSArray *classes = @[@"Actor", @"Entity", @"Mob", @"Player", @"ServerPlayer", @"LocalPlayer"];
    NSArray *methods = @[@"getAABB", @"getBoundingBox", @"getHitbox", @"aabb", @"getCollisionBox"];
    
    for (NSString *c in classes) {
        for (NSString *m in methods) {
            Class cls = NSClassFromString(c);
            if (!cls) continue;
            SEL sel = NSSelectorFromString(m);
            Method meth = class_getInstanceMethod(cls, sel);
            if (!meth) meth = class_getClassMethod(cls, sel);
            if (!meth) continue;
            orig_getAABB = method_getImplementation(meth);
            method_setImplementation(meth, (IMP)hooked_getAABB);
            return;
        }
    }
}

@interface MenuVC : UIViewController <UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate>
@property (nonatomic, strong) UITableView *tv;
@property (nonatomic, strong) UITextField *tf;
@end

@implementation MenuVC

- (void)viewDidLoad {
    [super viewDidLoad];
    if (!friendsList) friendsList = [NSMutableArray array];
    
    self.view.backgroundColor = [UIColor colorWithRed:0.05 green:0.05 blue:0.05 alpha:0.92];
    self.view.layer.cornerRadius = 14;
    self.view.layer.borderWidth = 1.5;
    self.view.layer.borderColor = [UIColor greenColor].CGColor;
    self.view.clipsToBounds = YES;
    
    float w = self.view.frame.size.width - 24, y = 12;
    
    UILabel *t = [[UILabel alloc] initWithFrame:CGRectMake(12, y, w, 22)];
    t.text = @"MCPE Cheats"; t.textColor = [UIColor greenColor];
    t.font = [UIFont boldSystemFontOfSize:16]; t.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:t]; y += 30;
    
    UIButton *hb = [UIButton buttonWithType:UIButtonTypeCustom];
    hb.frame = CGRectMake(12, y, w, 32);
    hb.backgroundColor = hitboxesEnabled ? [UIColor greenColor] : [UIColor darkGrayColor];
    [hb setTitle:hitboxesEnabled ? @"Hitboxes: ON" : @"Hitboxes: OFF" forState:UIControlStateNormal];
    hb.titleLabel.font = [UIFont boldSystemFontOfSize:12]; hb.layer.cornerRadius = 5;
    [hb addTarget:self action:@selector(tgl) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:hb]; y += 36;
    
    UISlider *sl = [[UISlider alloc] initWithFrame:CGRectMake(12, y, w, 25)];
    sl.minimumValue = 0.5; sl.maximumValue = 5.0; sl.value = hitboxScale;
    sl.minimumTrackTintColor = [UIColor greenColor];
    [sl addTarget:self action:@selector(sc:) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:sl]; y += 30;
    
    self.tf = [[UITextField alloc] initWithFrame:CGRectMake(12, y, w-52, 28)];
    self.tf.placeholder = @"Ник друга"; self.tf.backgroundColor = [UIColor colorWithRed:0.15 green:0.15 blue:0.15 alpha:1];
    self.tf.textColor = [UIColor whiteColor]; self.tf.font = [UIFont systemFontOfSize:13];
    self.tf.layer.cornerRadius = 5; self.tf.delegate = self; self.tf.returnKeyType = UIReturnKeyDone;
    [self.view addSubview:self.tf];
    
    UIButton *add = [UIButton buttonWithType:UIButtonTypeCustom];
    add.frame = CGRectMake(w-36, y, 28, 28); add.backgroundColor = [UIColor greenColor];
    [add setTitle:@"+" forState:UIControlStateNormal]; add.titleLabel.font = [UIFont boldSystemFontOfSize:18];
    add.layer.cornerRadius = 5; [add addTarget:self action:@selector(addF) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:add]; y += 34;
    
    self.tv = [[UITableView alloc] initWithFrame:CGRectMake(12, y, w, 60) style:UITableViewStylePlain];
    self.tv.backgroundColor = [UIColor colorWithRed:0.08 green:0.08 blue:0.08 alpha:0.9];
    self.tv.delegate = self; self.tv.dataSource = self; self.tv.rowHeight = 24;
    [self.view addSubview:self.tv]; y += 64;
    
    UIButton *close = [UIButton buttonWithType:UIButtonTypeCustom];
    close.frame = CGRectMake(12, y, w, 30); close.backgroundColor = [UIColor redColor];
    [close setTitle:@"Закрыть" forState:UIControlStateNormal];
    close.titleLabel.font = [UIFont boldSystemFontOfSize:14]; close.layer.cornerRadius = 6;
    [close addTarget:self action:@selector(closeM) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:close];
}

- (void)tgl { hitboxesEnabled = !hitboxesEnabled; [self dismissViewControllerAnimated:NO completion:nil]; menuVisible = NO; }
- (void)sc:(UISlider *)s { hitboxScale = s.value; }
- (void)addF { NSString *n = [self.tf.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]; if (n.length && ![friendsList containsObject:n]) { [friendsList addObject:n]; [self.tv reloadData]; self.tf.text = @""; [self.tf resignFirstResponder]; } }
- (void)closeM { menuVisible = NO; [self dismissViewControllerAnimated:YES completion:nil]; }
- (BOOL)textFieldShouldReturn:(UITextField *)tf { [self addF]; return YES; }
- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s { return friendsList.count; }
- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *c = [tv dequeueReusableCellWithIdentifier:@"c"];
    if (!c) { c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"c"]; c.backgroundColor = [UIColor clearColor]; c.textLabel.textColor = [UIColor cyanColor]; c.textLabel.font = [UIFont systemFontOfSize:12]; }
    if (ip.row < friendsList.count) { id o = friendsList[ip.row]; c.textLabel.text = [o isKindOfClass:[NSString class]] ? o : [NSString stringWithFormat:@"%@", o]; }
    return c;
}
- (void)tableView:(UITableView *)tv commitEditingStyle:(UITableViewCellEditingStyle)es forRowAtIndexPath:(NSIndexPath *)ip {
    if (es == UITableViewCellEditingStyleDelete && ip.row < friendsList.count) { [friendsList removeObjectAtIndex:ip.row]; [tv deleteRowsAtIndexPaths:@[ip] withRowAnimation:UITableViewRowAnimationFade]; }
}
@end

@interface Handler : NSObject @end
@implementation Handler
- (void)drag:(UIPanGestureRecognizer *)g {
    UIView *v = g.view; CGPoint t = [g translationInView:v.superview];
    if (g.state == UIGestureRecognizerStateChanged) {
        CGPoint c = CGPointMake(v.center.x+t.x, v.center.y+t.y);
        CGRect b = [UIScreen mainScreen].bounds;
        c.x = MAX(30, MIN(b.size.width-30, c.x)); c.y = MAX(50, MIN(b.size.height-50, c.y));
        v.center = c; [g setTranslation:CGPointZero inView:v.superview];
    }
}
- (void)tap {
    if (menuVisible) return; menuVisible = YES;
    MenuVC *m = [[MenuVC alloc] init]; m.view.frame = CGRectMake(0, 0, 260, 300);
    m.modalPresentationStyle = UIModalPresentationFormSheet;
    UIWindow *w = GetKeyWindow(); if (w && w.rootViewController) [w.rootViewController presentViewController:m animated:YES completion:nil];
}
@end

static Handler *h = nil;
__attribute__((constructor)) static void init(void) {
    h = [[Handler alloc] init];
    dispatch_async(dispatch_get_main_queue(), ^{
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3*NSEC_PER_SEC), dispatch_get_main_queue(), ^{ InstallHooks(); });
        floatingButton = [UIButton buttonWithType:UIButtonTypeCustom];
        floatingButton.frame = CGRectMake(50, 200, 50, 50); floatingButton.layer.cornerRadius = 25;
        floatingButton.clipsToBounds = YES;
        floatingButton.backgroundColor = [UIColor colorWithRed:0.1 green:0.1 blue:0.1 alpha:0.85];
        floatingButton.layer.borderColor = [UIColor greenColor].CGColor; floatingButton.layer.borderWidth = 2;
        [floatingButton setTitle:@"MC" forState:UIControlStateNormal];
        [floatingButton setTitleColor:[UIColor greenColor] forState:UIControlStateNormal];
        floatingButton.titleLabel.font = [UIFont boldSystemFontOfSize:11];
        [floatingButton addTarget:h action:@selector(tap) forControlEvents:UIControlEventTouchUpInside];
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:h action:@selector(drag:)];
        [floatingButton addGestureRecognizer:pan];
        UIWindow *w = GetKeyWindow(); if (w) [w addSubview:floatingButton];
    });
}