#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <AVFoundation/AVFoundation.h>
#import <dlfcn.h>

// ========== НАСТРОЙКИ ==========
static BOOL freeLookEnabled = NO;
static BOOL showHatESP = NO;
static BOOL hitColorEnabled = NO;
static float playerAlpha = 1.0;
static float handX = 0.0, handY = 0.0, handZ = 0.0, handScale = 1.0;
static int skyboxType = 0;
static int hitSoundType = 0;
static BOOL menuVisible = NO;
static UIButton *floatingButton = nil;
static AVAudioPlayer *hitSoundPlayer = nil;
static UILabel *fpsLabel = nil;
static BOOL hooksFound = NO;

// ========== FPS ==========
static CADisplayLink *displayLink = nil;
static NSTimeInterval lastTime = 0;
static int frameCount = 0;
static float currentFPS = 60.0;

// ========== ЦВЕТА ==========
#define NEON_GREEN [UIColor colorWithRed:0.22 green:1.0 blue:0.08 alpha:1.0]
#define BLACK_BG [UIColor colorWithRed:0.04 green:0.04 blue:0.04 alpha:0.96]

// ========== FPS ХЭЛПЕР ==========
@interface FPSHelper : NSObject
- (void)updateFPS;
@end
@implementation FPSHelper
- (void)updateFPS {
    if (!lastTime) { lastTime = CACurrentMediaTime(); return; }
    frameCount++;
    NSTimeInterval now = CACurrentMediaTime();
    NSTimeInterval delta = now - lastTime;
    if (delta >= 0.5) {
        currentFPS = frameCount / delta;
        frameCount = 0; lastTime = now;
        if (fpsLabel) dispatch_async(dispatch_get_main_queue(), ^{
            fpsLabel.text = [NSString stringWithFormat:@"⚡%.0f", currentFPS];
        });
    }
}
@end

// ========== ФУНКЦИИ ==========
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

static void AddGlow(UIView *v, UIColor *c, float r) {
    v.layer.shadowColor = c.CGColor;
    v.layer.shadowOffset = CGSizeZero;
    v.layer.shadowRadius = r;
    v.layer.shadowOpacity = 1.0;
    v.layer.masksToBounds = NO;
}

static void PlayHitSound(int type) {
    NSString *s = nil;
    switch (type) { case 1: s = @"bell"; break; case 2: s = @"pop"; break; case 3: s = @"coin"; break; default: return; }
    NSString *p = [NSString stringWithFormat:@"/System/Library/Audio/UISounds/%@.caf", s];
    NSURL *u = [NSURL fileURLWithPath:p];
    if (u) { hitSoundPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:u error:nil]; [hitSoundPlayer play]; }
}

static void SearchCppSymbols(void) {
    NSLog(@"[CREEPER] Searching C++ symbols...");
    void *handle = dlopen(NULL, RTLD_NOW);
    if (!handle) return;
    
    void *ptr = dlsym(handle, "_ZN5Actor7getAABBEv");
    if (!ptr) ptr = dlsym(handle, "getAABB");
    if (ptr) { NSLog(@"[CREEPER] ✅ getAABB found"); hooksFound = YES; }
    
    ptr = dlsym(handle, "_ZN19LevelRendererCamera19queueRenderEntitiesE");
    if (!ptr) ptr = dlsym(handle, "queueRenderEntities");
    if (ptr) { NSLog(@"[CREEPER] ✅ render found"); hooksFound = YES; }
    
    if (!hooksFound) NSLog(@"[CREEPER] ❌ No symbols found");
}

// ========== МЕНЮ ==========
@interface CreeperMenuVC : UIViewController
@property (nonatomic, strong) UIScrollView *sv;
@property (nonatomic, strong) UILabel *fpsLbl;
@end

@implementation CreeperMenuVC

- (void)viewDidLoad {
    [super viewDidLoad];
    
    float mw = 310, mh = 280;
    self.view.frame = CGRectMake(([UIScreen mainScreen].bounds.size.width-mw)/2, ([UIScreen mainScreen].bounds.size.height-mh)/2, mw, mh);
    
    UIView *bg = [[UIView alloc] initWithFrame:CGRectMake(0,0,mw,mh)];
    bg.backgroundColor = BLACK_BG; bg.layer.cornerRadius = 16;
    bg.layer.borderWidth = 2; bg.layer.borderColor = NEON_GREEN.CGColor;
    AddGlow(bg, NEON_GREEN, 20); [self.view addSubview:bg];
    
    float w = mw - 24;
    
    UIView *hdr = [[UIView alloc] initWithFrame:CGRectMake(12,10,w,44)];
    hdr.backgroundColor = [NEON_GREEN colorWithAlphaComponent:0.12]; hdr.layer.cornerRadius = 10;
    AddGlow(hdr, NEON_GREEN, 4); [bg addSubview:hdr];
    
    UILabel *ico = [[UILabel alloc] initWithFrame:CGRectMake(8,7,30,30)];
    ico.text = @"☠️"; ico.font = [UIFont systemFontOfSize:22]; [hdr addSubview:ico];
    
    UILabel *ttl = [[UILabel alloc] initWithFrame:CGRectMake(40,4,w-110,20)];
    ttl.text = @"CREEPER VISUAL"; ttl.textColor = NEON_GREEN;
    ttl.font = [UIFont boldSystemFontOfSize:15]; AddGlow(ttl, NEON_GREEN, 2); [hdr addSubview:ttl];
    
    self.fpsLbl = [[UILabel alloc] initWithFrame:CGRectMake(w-70,8,60,24)];
    self.fpsLbl.text = @"⚡60"; self.fpsLbl.textColor = NEON_GREEN;
    self.fpsLbl.font = [UIFont boldSystemFontOfSize:13]; self.fpsLbl.textAlignment = NSTextAlignmentRight;
    AddGlow(self.fpsLbl, NEON_GREEN, 2); [hdr addSubview:self.fpsLbl];
    fpsLabel = self.fpsLbl;
    
    self.sv = [[UIScrollView alloc] initWithFrame:CGRectMake(0,60,mw,mh-60)]; [bg addSubview:self.sv];
    
    float cy = 4;
    cy = [self sec:@"🎨 VISUALS" y:cy w:w];
    cy = [self sw:@"Free Look (360°)" y:cy w:w tag:1];
    cy = [self sw:@"Hat ESP" y:cy w:w tag:2];
    cy = [self sw:@"Hit Color" y:cy w:w tag:3];
    cy = [self sec:@"🌅 SKYBOX" y:cy w:w];
    cy = [self seg:@[@"Day",@"Sunset",@"Night",@"Custom"] y:cy w:w tag:10 sel:skyboxType];
    cy = [self sec:@"🔊 HIT SOUND" y:cy w:w];
    cy = [self seg:@[@"Default",@"Bell",@"Pop",@"Coin"] y:cy w:w tag:20 sel:hitSoundType];
    cy = [self sec:@"✋ HAND" y:cy w:w];
    cy = [self sl:@"X" y:cy w:w tag:100 val:handX min:-2 max:2];
    cy = [self sl:@"Y" y:cy w:w tag:101 val:handY min:-2 max:2];
    cy = [self sl:@"Z" y:cy w:w tag:102 val:handZ min:-2 max:2];
    cy = [self sl:@"Scl" y:cy w:w tag:103 val:handScale min:0.5 max:3];
    cy = [self sec:@"👤 PLAYER" y:cy w:w];
    cy = [self sl:@"Alpha" y:cy w:w tag:200 val:playerAlpha min:0 max:1];
    
    UIButton *cls = [UIButton buttonWithType:UIButtonTypeCustom];
    cls.frame = CGRectMake(8,cy+6,w-16,34); cls.backgroundColor = NEON_GREEN;
    [cls setTitle:hooksFound ? @"✕ CLOSE (✓)" : @"✕ CLOSE" forState:UIControlStateNormal];
    [cls setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    cls.titleLabel.font = [UIFont boldSystemFontOfSize:13]; cls.layer.cornerRadius = 8;
    AddGlow(cls, NEON_GREEN, 8);
    [cls addTarget:self action:@selector(closeMenu) forControlEvents:UIControlEventTouchUpInside];
    [self.sv addSubview:cls];
    self.sv.contentSize = CGSizeMake(w, cy+50);
}

- (float)sec:(NSString *)t y:(float)y w:(float)w { UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(4,y,w,20)]; l.text = t; l.textColor = NEON_GREEN; l.font = [UIFont boldSystemFontOfSize:12]; AddGlow(l, NEON_GREEN, 2); [self.sv addSubview:l]; return y+22; }
- (float)sw:(NSString *)n y:(float)y w:(float)w tag:(int)tag { UIView *r = [[UIView alloc] initWithFrame:CGRectMake(4,y,w,28)]; r.backgroundColor = [NEON_GREEN colorWithAlphaComponent:0.04]; r.layer.cornerRadius = 6; [self.sv addSubview:r]; UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(8,4,180,20)]; l.text = n; l.textColor = [UIColor whiteColor]; l.font = [UIFont systemFontOfSize:12]; [r addSubview:l]; UISwitch *sw = [[UISwitch alloc] initWithFrame:CGRectMake(w-50,0,42,28)]; sw.onTintColor = NEON_GREEN; sw.tag = tag; [sw addTarget:self action:@selector(swCh:) forControlEvents:UIControlEventValueChanged]; [r addSubview:sw]; return y+32; }
- (float)sl:(NSString *)n y:(float)y w:(float)w tag:(int)tag val:(float)v min:(float)mn max:(float)mx { UIView *r = [[UIView alloc] initWithFrame:CGRectMake(4,y,w,30)]; r.backgroundColor = [NEON_GREEN colorWithAlphaComponent:0.04]; r.layer.cornerRadius = 6; [self.sv addSubview:r]; UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(8,6,30,18)]; l.text = n; l.textColor = NEON_GREEN; l.font = [UIFont boldSystemFontOfSize:10]; [r addSubview:l]; UISlider *sl = [[UISlider alloc] initWithFrame:CGRectMake(40,4,w-52,22)]; sl.minimumValue = mn; sl.maximumValue = mx; sl.value = v; sl.minimumTrackTintColor = NEON_GREEN; sl.thumbTintColor = NEON_GREEN; sl.tag = tag; [sl addTarget:self action:@selector(slCh:) forControlEvents:UIControlEventValueChanged]; [r addSubview:sl]; return y+34; }
- (float)seg:(NSArray *)it y:(float)y w:(float)w tag:(int)tag sel:(int)sel { UISegmentedControl *sg = [[UISegmentedControl alloc] initWithItems:it]; sg.frame = CGRectMake(4,y,w,28); sg.selectedSegmentIndex = sel; sg.tag = tag; [sg addTarget:self action:@selector(sgCh:) forControlEvents:UIControlEventValueChanged]; if (@available(iOS 13.0, *)) sg.selectedSegmentTintColor = NEON_GREEN; [self.sv addSubview:sg]; return y+32; }
- (void)swCh:(UISwitch *)s { if (s.tag==1) freeLookEnabled=s.isOn; else if (s.tag==2) showHatESP=s.isOn; else if (s.tag==3) hitColorEnabled=s.isOn; }
- (void)slCh:(UISlider *)s { if (s.tag==100) handX=s.value; else if (s.tag==101) handY=s.value; else if (s.tag==102) handZ=s.value; else if (s.tag==103) handScale=s.value; else if (s.tag==200) playerAlpha=s.value; }
- (void)sgCh:(UISegmentedControl *)s { if (s.tag==10) skyboxType=(int)s.selectedSegmentIndex; else if (s.tag==20) { hitSoundType=(int)s.selectedSegmentIndex; PlayHitSound(hitSoundType); } }
- (void)closeMenu { menuVisible = NO; [UIView animateWithDuration:0.15 animations:^{ self.view.alpha = 0; } completion:^(BOOL f) { [self.view removeFromSuperview]; }]; }
@end

@interface Handler : NSObject @end
@implementation Handler
- (void)drag:(UIPanGestureRecognizer *)g { UIView *v=g.view; CGPoint t=[g translationInView:v.superview]; if (g.state==UIGestureRecognizerStateChanged) { CGPoint c=CGPointMake(v.center.x+t.x, v.center.y+t.y); CGRect b=[UIScreen mainScreen].bounds; c.x=MAX(30,MIN(b.size.width-30,c.x)); c.y=MAX(50,MIN(b.size.height-50,c.y)); v.center=c; [g setTranslation:CGPointZero inView:v.superview]; } }
- (void)tap { if (menuVisible) { for (UIView *v in GetKeyWindow().subviews) if ([v.nextResponder isKindOfClass:[CreeperMenuVC class]]) [(CreeperMenuVC *)v.nextResponder closeMenu]; return; } menuVisible=YES; CreeperMenuVC *m=[[CreeperMenuVC alloc] init]; m.view.alpha=0; UIWindow *w=GetKeyWindow(); if (w) { [w addSubview:m.view]; [UIView animateWithDuration:0.2 animations:^{ m.view.alpha=1; }]; } }
@end

static Handler *h = nil;
static FPSHelper *fpsHelper = nil;
__attribute__((constructor)) static void init(void) {
    h = [[Handler alloc] init];
    fpsHelper = [[FPSHelper alloc] init];
    dispatch_async(dispatch_get_main_queue(), ^{
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 5*NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            SearchCppSymbols();
        });
        
        displayLink = [CADisplayLink displayLinkWithTarget:fpsHelper selector:@selector(updateFPS)];
        [displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
        
        floatingButton = [UIButton buttonWithType:UIButtonTypeCustom];
        floatingButton.frame = CGRectMake(50,200,46,46); floatingButton.layer.cornerRadius=23;
        floatingButton.backgroundColor = [UIColor colorWithRed:0.04 green:0.04 blue:0.04 alpha:0.9];
        floatingButton.layer.borderColor = NEON_GREEN.CGColor; floatingButton.layer.borderWidth=2;
        AddGlow(floatingButton, NEON_GREEN, 15);
        [floatingButton setTitle:@"MC" forState:UIControlStateNormal];
        [floatingButton setTitleColor:NEON_GREEN forState:UIControlStateNormal];
        floatingButton.titleLabel.font = [UIFont boldSystemFontOfSize:11];
        [floatingButton addTarget:h action:@selector(tap) forControlEvents:UIControlEventTouchUpInside];
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:h action:@selector(drag:)];
        [floatingButton addGestureRecognizer:pan];
        UIWindow *w = GetKeyWindow(); if (w) [w addSubview:floatingButton];
    });
}