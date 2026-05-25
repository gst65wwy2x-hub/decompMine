#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// ========== ПЕРЕМЕННЫЕ ==========
static UIButton *floatingButton = nil;
static BOOL menuVisible = NO;
static BOOL hitboxesEnabled = NO;
static BOOL playerESPEnabled = NO;
static BOOL blockESPEnabled = NO;
static float hitboxScale = 1.0;
static int chunkLoadRadius = 4;
static NSMutableArray *friendsList = nil;

// ========== ECS КОМПОНЕНТЫ (из strings.txt) ==========
// HitboxComponent — хранит размеры хитбокса
// AABBShapeComponent — форма AABB
// ActorOwnerComponent — владелец актора
// PlayerComponent — компонент игрока
// LocalPlayerComponent — локальный игрок
// StateVectorComponent — позиция

// ========== ХРАНЕНИЕ ОРИГИНАЛОВ ==========
static IMP orig_HitboxComponent_getHitbox = NULL;
static IMP orig_LevelRendererCamera_queueRenderEntities = NULL;

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

// ========== ХУК: HitboxComponent (хитбоксы) ==========
static void *hooked_HitboxComponent_getHitbox(id self, SEL _cmd) {
    typedef void *(*OrigFunc)(id, SEL);
    OrigFunc orig = (OrigFunc)orig_HitboxComponent_getHitbox;
    
    if (!hitboxesEnabled || !orig) {
        return orig ? orig(self, _cmd) : NULL;
    }
    
    // Получаем оригинальный хитбокс
    float *box = (float *)orig(self, _cmd);
    if (!box) return NULL;
    
    // Проверка на друга (если есть метод getName)
    if ([self respondsToSelector:NSSelectorFromString(@"getName")]) {
        NSString *name = [self performSelector:NSSelectorFromString(@"getName")];
        if (name && [friendsList containsObject:name]) return box;
    }
    
    // Увеличиваем хитбокс
    @try {
        float cx = (box[0] + box[3]) / 2.0f;
        float cy = (box[1] + box[4]) / 2.0f;
        float cz = (box[2] + box[5]) / 2.0f;
        float hx = (box[3] - box[0]) / 2.0f * hitboxScale;
        float hy = (box[4] - box[1]) / 2.0f * hitboxScale;
        float hz = (box[5] - box[2]) / 2.0f * hitboxScale;
        
        static float modifiedBox[6];
        modifiedBox[0] = cx - hx; modifiedBox[3] = cx + hx;
        modifiedBox[1] = cy - hy; modifiedBox[4] = cy + hy;
        modifiedBox[2] = cz - hz; modifiedBox[5] = cz + hz;
        
        return modifiedBox;
    } @catch (NSException *e) {
        return box;
    }
}

// ========== ХУК: LevelRendererCamera::queueRenderEntities (ESP) ==========
static void hooked_LevelRendererCamera_queueRenderEntities(id self, SEL _cmd, void *params) {
    typedef void (*OrigFunc)(id, SEL, void *);
    OrigFunc orig = (OrigFunc)orig_LevelRendererCamera_queueRenderEntities;
    
    // Вызываем оригинал
    if (orig) orig(self, _cmd, params);
    
    // ESP игроков
    if (playerESPEnabled) {
        dispatch_async(dispatch_get_main_queue(), ^{
            // Удаляем старые ESP боксы
            UIWindow *w = GetKeyWindow();
            if (!w) return;
            
            for (UIView *v in w.subviews) {
                if (v.tag == 7777) [v removeFromSuperview];
            }
            
            // Здесь должен быть WorldToScreen и отрисовка боксов
            // Пока рисуем тестовый квадрат
            UIView *esp = [[UIView alloc] initWithFrame:CGRectMake(150, 300, 50*hitboxScale, 50*hitboxScale)];
            esp.layer.borderColor = [UIColor redColor].CGColor;
            esp.layer.borderWidth = 2.0f;
            esp.backgroundColor = [[UIColor redColor] colorWithAlphaComponent:0.2f];
            esp.tag = 7777;
            [w addSubview:esp];
        });
    }
}

// ========== УСТАНОВКА ХУКОВ ==========
static void InstallHooks(void) {
    NSLog(@"[MCPE] Installing hooks for ECS system...");
    
    // 1. HitboxComponent
    NSArray *hitboxClasses = @[@"HitboxComponent", @"AABBShapeComponent", 
                                @"ActorHitboxComponent", @"EntityHitboxComponent"];
    NSArray *hitboxMethods = @[@"getHitbox", @"getAABB", @"getBox", @"getBoundingBox",
                                @"hitbox", @"aabb", @"box"];
    
    for (NSString *clsName in hitboxClasses) {
        Class cls = NSClassFromString(clsName);
        if (!cls) continue;
        
        for (NSString *mtdName in hitboxMethods) {
            SEL sel = NSSelectorFromString(mtdName);
            Method method = class_getInstanceMethod(cls, sel);
            if (!method) method = class_getClassMethod(cls, sel);
            if (!method) continue;
            
            orig_HitboxComponent_getHitbox = method_getImplementation(method);
            method_setImplementation(method, (IMP)hooked_HitboxComponent_getHitbox);
            NSLog(@"[MCPE] ✅ Hitbox hook: %@::%@", clsName, mtdName);
            goto hook2;
        }
    }
    NSLog(@"[MCPE] ❌ Hitbox component not found");
    
hook2:
    // 2. LevelRendererCamera::queueRenderEntities
    NSArray *renderClasses = @[@"LevelRendererCamera", @"LevelRenderer", 
                                @"LevelRendererPlayer", @"MinecraftRenderer"];
    NSArray *renderMethods = @[@"queueRenderEntities:", @"renderEntities:", 
                                @"renderPlayers:", @"render:"];
    
    for (NSString *clsName in renderClasses) {
        Class cls = NSClassFromString(clsName);
        if (!cls) continue;
        
        for (NSString *mtdName in renderMethods) {
            SEL sel = NSSelectorFromString(mtdName);
            Method method = class_getInstanceMethod(cls, sel);
            if (!method) continue;
            
            orig_LevelRendererCamera_queueRenderEntities = method_getImplementation(method);
            method_setImplementation(method, (IMP)hooked_LevelRendererCamera_queueRenderEntities);
            NSLog(@"[MCPE] ✅ Render hook: %@::%@", clsName, mtdName);
            return;
        }
    }
    NSLog(@"[MCPE] ❌ Renderer not found");
}

// ========== МЕНЮ ==========
@interface MenuVC : UIViewController <UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate>
@property (nonatomic, strong) UITableView *tv;
@property (nonatomic, strong) UITextField *tf;
@property (nonatomic, strong) UILabel *hitboxSizeLabel;
@property (nonatomic, strong) UILabel *chunkSizeLabel;
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
    t.text = @"MCPE Cheats ECS"; t.textColor = [UIColor greenColor];
    t.font = [UIFont boldSystemFontOfSize:16]; t.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:t]; y += 30;
    
    // Hitboxes
    UIButton *hb = [self btn:CGRectMake(12, y, w, 32) title:hitboxesEnabled ? @"✓ Hitboxes" : @"✗ Hitboxes" 
                       color:hitboxesEnabled ? [UIColor greenColor] : [UIColor darkGrayColor] action:@selector(tglHB:)];
    [self.view addSubview:hb]; y += 36;
    
    self.hitboxSizeLabel = [[UILabel alloc] initWithFrame:CGRectMake(12, y, w, 16)];
    self.hitboxSizeLabel.text = [NSString stringWithFormat:@"Размер: %.1fx", hitboxScale];
    self.hitboxSizeLabel.textColor = [UIColor whiteColor]; self.hitboxSizeLabel.font = [UIFont systemFontOfSize:11];
    [self.view addSubview:self.hitboxSizeLabel]; y += 16;
    
    UISlider *hs = [[UISlider alloc] initWithFrame:CGRectMake(12, y, w, 25)];
    hs.minimumValue = 0.5; hs.maximumValue = 5.0; hs.value = hitboxScale;
    hs.minimumTrackTintColor = [UIColor greenColor];
    [hs addTarget:self action:@selector(chgHS:) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:hs]; y += 30;
    
    // Player ESP
    UIButton *pe = [self btn:CGRectMake(12, y, w, 32) title:playerESPEnabled ? @"✓ Player ESP" : @"✗ Player ESP"
                       color:playerESPEnabled ? [UIColor cyanColor] : [UIColor darkGrayColor] action:@selector(tglPE:)];
    [self.view addSubview:pe]; y += 36;
    
    // Block ESP
    UIButton *be = [self btn:CGRectMake(12, y, w, 32) title:blockESPEnabled ? @"✓ Block ESP" : @"✗ Block ESP"
                       color:blockESPEnabled ? [UIColor orangeColor] : [UIColor darkGrayColor] action:@selector(tglBE:)];
    [self.view addSubview:be]; y += 36;
    
    // Chunks
    self.chunkSizeLabel = [[UILabel alloc] initWithFrame:CGRectMake(12, y, w, 16)];
    self.chunkSizeLabel.text = [NSString stringWithFormat:@"Чанки: %d", chunkLoadRadius];
    self.chunkSizeLabel.textColor = [UIColor whiteColor]; self.chunkSizeLabel.font = [UIFont systemFontOfSize:11];
    [self.view addSubview:self.chunkSizeLabel]; y += 16;
    
    UISlider *cs = [[UISlider alloc] initWithFrame:CGRectMake(12, y, w, 25)];
    cs.minimumValue = 2; cs.maximumValue = 16; cs.value = chunkLoadRadius;
    cs.minimumTrackTintColor = [UIColor purpleColor];
    [cs addTarget:self action:@selector(chgCL:) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:cs]; y += 30;
    
    // Friends
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
    
    self.tv = [[UITableView alloc] initWithFrame:CGRectMake(12, y, w, 50) style:UITableViewStylePlain];
    self.tv.backgroundColor = [UIColor colorWithRed:0.08 green:0.08 blue:0.08 alpha:0.9];
    self.tv.delegate = self; self.tv.dataSource = self; self.tv.rowHeight = 24;
    [self.view addSubview:self.tv]; y += 55;
    
    UIButton *close = [UIButton buttonWithType:UIButtonTypeCustom];
    close.frame = CGRectMake(12, y, w, 30); close.backgroundColor = [UIColor redColor];
    [close setTitle:@"Закрыть" forState:UIControlStateNormal]; close.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    close.layer.cornerRadius = 6; [close addTarget:self action:@selector(closeM) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:close];
}

- (UIButton *)btn:(CGRect)f title:(NSString *)t color:(UIColor *)c action:(SEL)a {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
    b.frame = f; b.backgroundColor = c; [b setTitle:t forState:UIControlStateNormal];
    [b setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    b.titleLabel.font = [UIFont boldSystemFontOfSize:12]; b.layer.cornerRadius = 5;
    [b addTarget:self action:a forControlEvents:UIControlEventTouchUpInside];
    return b;
}

- (void)tglHB:(UIButton *)s { hitboxesEnabled = !hitboxesEnabled; [self reload]; }
- (void)chgHS:(UISlider *)s { hitboxScale = s.value; self.hitboxSizeLabel.text = [NSString stringWithFormat:@"Размер: %.1fx", hitboxScale]; }
- (void)tglPE:(UIButton *)s { playerESPEnabled = !playerESPEnabled; [self reload]; }
- (void)tglBE:(UIButton *)s { blockESPEnabled = !blockESPEnabled; [self reload]; }
- (void)chgCL:(UISlider *)s { chunkLoadRadius = (int)s.value; self.chunkSizeLabel.text = [NSString stringWithFormat:@"Чанки: %d", chunkLoadRadius]; }
- (void)addF { NSString *n = [self.tf.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]; if (n.length && ![friendsList containsObject:n]) { [friendsList addObject:n]; [self.tv reloadData]; self.tf.text = @""; [self.tf resignFirstResponder]; } }
- (void)reload { [self dismissViewControllerAnimated:NO completion:nil]; menuVisible = NO; }
- (void)closeM { menuVisible = NO; [self dismissViewControllerAnimated:YES completion:nil]; }
- (BOOL)textFieldShouldReturn:(UITextField *)tf { [self addF]; return YES; }
- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s { return friendsList.count; }
- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *c = [tv dequeueReusableCellWithIdentifier:@"c"];
    if (!c) { c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"c"]; c.backgroundColor = [UIColor clearColor]; c.textLabel.textColor = [UIColor cyanColor]; c.textLabel.font = [UIFont systemFontOfSize:12]; }
    if (ip.row < friendsList.count) c.textLabel.text = friendsList[ip.row];
    return c;
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
    if (menuVisible) return; menuVisible = YES;
    MenuVC *m = [[MenuVC alloc] init]; m.view.frame = CGRectMake(0, 0, 280, 350);
    m.modalPresentationStyle = UIModalPresentationFormSheet;
    UIWindow *w = GetKeyWindow(); if (w && w.rootViewController) [w.rootViewController presentViewController:m animated:YES completion:nil];
}
@end

static Handler *h = nil;
__attribute__((constructor)) static void init(void) {
    h = [[Handler alloc] init];
    dispatch_async(dispatch_get_main_queue(), ^{
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3*NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            InstallHooks();
        });
        
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