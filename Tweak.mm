#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <AVFoundation/AVFoundation.h>

// ========== НАСТРОЙКИ ==========
static BOOL freeLookEnabled = NO;
static BOOL showHatESP = NO;
static BOOL hitColorEnabled = NO;
static float hitColorR = 1.0, hitColorG = 0.0, hitColorB = 0.0;
static float playerAlpha = 1.0;
static float handX = 0.0, handY = 0.0, handZ = 0.0, handScale = 1.0;
static int skyboxType = 0;
static int hitSoundType = 0; // 0-обычный, 1-звон, 2-хлопок, 3-монета
static BOOL menuVisible = NO;
static UIButton *floatingButton = nil;
static AVAudioPlayer *hitSoundPlayer = nil;

// ========== НЕОНОВЫЕ ЦВЕТА ==========
#define NEON_GREEN [UIColor colorWithRed:0.22 green:1.0 blue:0.08 alpha:1.0]
#define DARK_BG [UIColor colorWithRed:0.05 green:0.08 blue:0.05 alpha:0.95]

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

static void AddGlow(UIView *view, UIColor *color, float radius) {
    view.layer.shadowColor = color.CGColor;
    view.layer.shadowOffset = CGSizeZero;
    view.layer.shadowRadius = radius;
    view.layer.shadowOpacity = 1.0;
    view.layer.masksToBounds = NO;
}

// Воспроизвести звук удара
static void PlayHitSound(int type) {
    NSString *soundName = nil;
    switch (type) {
        case 1: soundName = @"bell"; break;      // Звон
        case 2: soundName = @"pop"; break;        // Хлопок
        case 3: soundName = @"coin"; break;       // Монета
        default: return;                          // Обычный (не меняем)
    }
    
    NSString *path = [NSString stringWithFormat:@"/System/Library/Audio/UISounds/%@.caf", soundName];
    NSURL *url = [NSURL fileURLWithPath:path];
    if (url) {
        hitSoundPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:nil];
        [hitSoundPlayer play];
    }
}

// ========== МЕНЮ ==========
@interface CreeperMenuVC : UIViewController
@end

@implementation CreeperMenuVC

- (void)viewDidLoad {
    [super viewDidLoad];
    
    float menuW = 290;
    float menuH = 420;
    float x = (self.view.frame.size.width - menuW) / 2;
    float y = (self.view.frame.size.height - menuH) / 2;
    
    // Фон с неоновым свечением
    UIView *bg = [[UIView alloc] initWithFrame:CGRectMake(x, y, menuW, menuH)];
    bg.backgroundColor = DARK_BG;
    bg.layer.cornerRadius = 18;
    bg.layer.borderWidth = 2;
    bg.layer.borderColor = NEON_GREEN.CGColor;
    AddGlow(bg, NEON_GREEN, 15);
    [self.view addSubview:bg];
    
    float w = menuW - 30;
    float cy = 15;
    
    // ===== HEADER =====
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(15, cy, w, 50)];
    header.backgroundColor = [NEON_GREEN colorWithAlphaComponent:0.15];
    header.layer.cornerRadius = 12;
    AddGlow(header, NEON_GREEN, 5);
    [bg addSubview:header];
    
    UILabel *icon = [[UILabel alloc] initWithFrame:CGRectMake(10, 8, 34, 34)];
    icon.text = @"☠️";
    icon.font = [UIFont systemFontOfSize:26];
    [header addSubview:icon];
    
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(48, 5, w - 100, 22)];
    title.text = @"CREEPER VISUAL";
    title.textColor = NEON_GREEN;
    title.font = [UIFont boldSystemFontOfSize:17];
    AddGlow(title, NEON_GREEN, 3);
    [header addSubview:title];
    
    UILabel *ver = [[UILabel alloc] initWithFrame:CGRectMake(48, 27, 80, 16)];
    ver.text = @"v1.0 BETA";
    ver.textColor = [NEON_GREEN colorWithAlphaComponent:0.7];
    ver.font = [UIFont systemFontOfSize:10];
    [header addSubview:ver];
    
    UILabel *fps = [[UILabel alloc] initWithFrame:CGRectMake(w - 75, 12, 65, 26)];
    fps.text = @"⚡60 FPS";
    fps.textColor = NEON_GREEN;
    fps.font = [UIFont boldSystemFontOfSize:13];
    fps.textAlignment = NSTextAlignmentRight;
    AddGlow(fps, NEON_GREEN, 2);
    [header addSubview:fps];
    
    cy += 60;
    
    // ===== VISUALS =====
    cy = [self addSectionTitle:@"🎨 VISUALS" y:cy w:w bg:bg];
    cy = [self addSwitch:@"Free Look (360°)" y:cy w:w bg:bg tag:1];
    cy = [self addSwitch:@"Hat ESP" y:cy w:w bg:bg tag:2];
    cy = [self addSwitch:@"Hit Color" y:cy w:w bg:bg tag:3];
    
    // ===== SKYBOX =====
    cy = [self addSectionTitle:@"🌅 SKYBOX" y:cy w:w bg:bg];
    cy = [self addSegment:@[@"Day", @"Sunset", @"Night", @"Custom"] y:cy w:w bg:bg tag:10];
    
    // ===== HIT SOUND =====
    cy = [self addSectionTitle:@"🔊 HIT SOUND" y:cy w:w bg:bg];
    cy = [self addSegment:@[@"Default", @"Bell", @"Pop", @"Coin"] y:cy w:w bg:bg tag:20];
    
    // ===== HAND =====
    cy = [self addSectionTitle:@"✋ HAND POSITION" y:cy w:w bg:bg];
    cy = [self addSlider:@"X" y:cy w:w bg:bg tag:100 value:0 min:-2 max:2];
    cy = [self addSlider:@"Y" y:cy w:w bg:bg tag:101 value:0 min:-2 max:2];
    cy = [self addSlider:@"Z" y:cy w:w bg:bg tag:102 value:0 min:-2 max:2];
    cy = [self addSlider:@"Scale" y:cy w:w bg:bg tag:103 value:1 min:0.5 max:3];
    
    // ===== PLAYER =====
    cy = [self addSectionTitle:@"👤 PLAYER" y:cy w:w bg:bg];
    cy = [self addSlider:@"Alpha" y:cy w:w bg:bg tag:200 value:1 min:0 max:1];
    
    // ===== CLOSE =====
    UIButton *close = [UIButton buttonWithType:UIButtonTypeCustom];
    close.frame = CGRectMake(15, cy + 10, w, 38);
    close.backgroundColor = NEON_GREEN;
    [close setTitle:@"✕ CLOSE" forState:UIControlStateNormal];
    [close setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    close.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    close.layer.cornerRadius = 10;
    AddGlow(close, NEON_GREEN, 10);
    [close addTarget:self action:@selector(closeMenu) forControlEvents:UIControlEventTouchUpInside];
    [bg addSubview:close];
}

- (float)addSectionTitle:(NSString *)title y:(float)y w:(float)w bg:(UIView *)bg {
    UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(18, y, w, 22)];
    lbl.text = title;
    lbl.textColor = NEON_GREEN;
    lbl.font = [UIFont boldSystemFontOfSize:13];
    AddGlow(lbl, NEON_GREEN, 2);
    [bg addSubview:lbl];
    return y + 26;
}

- (float)addSwitch:(NSString *)name y:(float)y w:(float)w bg:(UIView *)bg tag:(int)tag {
    UIView *row = [[UIView alloc] initWithFrame:CGRectMake(15, y, w, 32)];
    row.backgroundColor = [NEON_GREEN colorWithAlphaComponent:0.05];
    row.layer.cornerRadius = 8;
    [bg addSubview:row];
    
    UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(10, 6, 180, 20)];
    lbl.text = name;
    lbl.textColor = [UIColor whiteColor];
    lbl.font = [UIFont systemFontOfSize:13];
    [row addSubview:lbl];
    
    UISwitch *sw = [[UISwitch alloc] initWithFrame:CGRectMake(w - 55, 1, 45, 30)];
    sw.onTintColor = NEON_GREEN;
    sw.tag = tag;
    [sw addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
    [row addSubview:sw];
    
    return y + 36;
}

- (float)addSlider:(NSString *)name y:(float)y w:(float)w bg:(UIView *)bg tag:(int)tag value:(float)val min:(float)min max:(float)max {
    UIView *row = [[UIView alloc] initWithFrame:CGRectMake(15, y, w, 36)];
    row.backgroundColor = [NEON_GREEN colorWithAlphaComponent:0.05];
    row.layer.cornerRadius = 8;
    [bg addSubview:row];
    
    UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(10, 8, 40, 20)];
    lbl.text = name;
    lbl.textColor = NEON_GREEN;
    lbl.font = [UIFont boldSystemFontOfSize:11];
    [row addSubview:lbl];
    
    UISlider *sl = [[UISlider alloc] initWithFrame:CGRectMake(50, 6, w - 65, 24)];
    sl.minimumValue = min;
    sl.maximumValue = max;
    sl.value = val;
    sl.minimumTrackTintColor = NEON_GREEN;
    sl.thumbTintColor = NEON_GREEN;
    sl.tag = tag;
    [sl addTarget:self action:@selector(sliderChanged:) forControlEvents:UIControlEventValueChanged];
    AddGlow(sl, NEON_GREEN, 3);
    [row addSubview:sl];
    
    return y + 40;
}

- (float)addSegment:(NSArray *)items y:(float)y w:(float)w bg:(UIView *)bg tag:(int)tag {
    UISegmentedControl *seg = [[UISegmentedControl alloc] initWithItems:items];
    seg.frame = CGRectMake(15, y, w, 32);
    seg.selectedSegmentIndex = 0;
    seg.tag = tag;
    [seg addTarget:self action:@selector(segmentChanged:) forControlEvents:UIControlEventValueChanged];
    if (@available(iOS 13.0, *)) {
        seg.selectedSegmentTintColor = NEON_GREEN;
    }
    [bg addSubview:seg];
    return y + 38;
}

- (void)switchChanged:(UISwitch *)sw {
    switch (sw.tag) {
        case 1: freeLookEnabled = sw.isOn; break;
        case 2: showHatESP = sw.isOn; break;
        case 3: hitColorEnabled = sw.isOn; break;
    }
}

- (void)sliderChanged:(UISlider *)sl {
    switch (sl.tag) {
        case 100: handX = sl.value; break;
        case 101: handY = sl.value; break;
        case 102: handZ = sl.value; break;
        case 103: handScale = sl.value; break;
        case 200: playerAlpha = sl.value; break;
    }
}

- (void)segmentChanged:(UISegmentedControl *)seg {
    if (seg.tag == 10) skyboxType = (int)seg.selectedSegmentIndex;
    else if (seg.tag == 20) {
        hitSoundType = (int)seg.selectedSegmentIndex;
        PlayHitSound(hitSoundType); // Демонстрация звука при выборе
    }
}

- (void)closeMenu {
    menuVisible = NO;
    [UIView animateWithDuration:0.2 animations:^{
        self.view.alpha = 0;
    } completion:^(BOOL f) {
        [self.view removeFromSuperview];
    }];
}

@end

// ========== КНОПКА ==========
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
    if (menuVisible) return;
    menuVisible = YES;
    CreeperMenuVC *m = [[CreeperMenuVC alloc] init];
    m.view.frame = [UIScreen mainScreen].bounds;
    m.view.backgroundColor = [UIColor clearColor];
    UIWindow *w = GetKeyWindow();
    if (w) {
        m.view.alpha = 0;
        [w addSubview:m.view];
        [UIView animateWithDuration:0.25 animations:^{ m.view.alpha = 1; }];
    }
}
@end

static Handler *h = nil;
__attribute__((constructor)) static void init(void) {
    h = [[Handler alloc] init];
    dispatch_async(dispatch_get_main_queue(), ^{
        floatingButton = [UIButton buttonWithType:UIButtonTypeCustom];
        floatingButton.frame = CGRectMake(50, 200, 48, 48);
        floatingButton.layer.cornerRadius = 24;
        floatingButton.backgroundColor = [UIColor colorWithRed:0.05 green:0.08 blue:0.05 alpha:0.9];
        floatingButton.layer.borderColor = NEON_GREEN.CGColor;
        floatingButton.layer.borderWidth = 2;
        AddGlow(floatingButton, NEON_GREEN, 12);
        [floatingButton setTitle:@"MC" forState:UIControlStateNormal];
        [floatingButton setTitleColor:NEON_GREEN forState:UIControlStateNormal];
        floatingButton.titleLabel.font = [UIFont boldSystemFontOfSize:12];
        [floatingButton addTarget:h action:@selector(tap) forControlEvents:UIControlEventTouchUpInside];
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:h action:@selector(drag:)];
        [floatingButton addGestureRecognizer:pan];
        UIWindow *w = GetKeyWindow(); if (w) [w addSubview:floatingButton];
    });
}