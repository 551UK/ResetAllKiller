#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// Minimal runtime declarations: no private framework link is necessary.
@interface PSSpecifier : NSObject
@property (nonatomic, retain) NSString *name;
@property (nonatomic, retain) NSString *identifier;
- (id)propertyForKey:(NSString *)key;
- (void)setProperty:(id)value forKey:(NSString *)key;
@end

@interface PSListController : UIViewController
- (NSArray *)specifiers;
- (PSSpecifier *)specifierAtIndexPath:(NSIndexPath *)indexPath;
- (BOOL)performActionForSpecifier:(PSSpecifier *)specifier;
- (BOOL)performButtonActionForSpecifier:(PSSpecifier *)specifier;
- (BOOL)performLoadActionForSpecifier:(PSSpecifier *)specifier;
- (void)showConfirmationViewForSpecifier:(PSSpecifier *)specifier;
@end

static NSString *RAKClean(NSString *value) {
    if (![value isKindOfClass:[NSString class]]) return @"";
    return [[value stringByTrimmingCharactersInSet:
             [NSCharacterSet whitespaceAndNewlineCharacterSet]] lowercaseString];
}

static BOOL RAKProtectedIdentifier(NSString *identifier) {
    NSString *name = RAKClean(identifier);
    if (name.length == 0) return NO;
    static NSSet<NSString *> *identifiers;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        identifiers = [NSSet setWithArray:@[
            @"settingserase", @"fullerase", @"cellularerase",
            @"reset_network_label", @"reset_keyboard_dictionary_label",
            @"reset_icons_label", @"reset_location_privacy_label",
            @"reset_location_and_privacy_label", @"reset_all_settings_label",
            @"reset_all_settings", @"reset", @"erase_all_content_and_settings"
        ]];
    });
    return [identifiers containsObject:name];
}

static BOOL RAKProtectedTitle(NSString *title) {
    NSString *name = RAKClean(title);
    if (name.length == 0) return NO;
    static NSSet<NSString *> *titles;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        titles = [NSSet setWithArray:@[
            @"reset", @"reset all settings", @"reset network settings",
            @"reset keyboard dictionary", @"reset home screen layout",
            @"reset location & privacy", @"reset location and privacy",
            @"reset subscriber services", @"remove all cellular data plans",
            @"erase all content and settings", @"erase all content & settings"
        ]];
    });
    return [titles containsObject:name];
}

static NSString *RAKSpecifierID(PSSpecifier *specifier) {
    if (![specifier respondsToSelector:@selector(identifier)]) return nil;
    NSString *identifier = specifier.identifier;
    if (![identifier isKindOfClass:[NSString class]] || identifier.length == 0) {
        id value = [specifier propertyForKey:@"id"];
        identifier = [value isKindOfClass:[NSString class]] ? value : nil;
    }
    return identifier;
}

static NSString *RAKSpecifierName(PSSpecifier *specifier) {
    if (![specifier respondsToSelector:@selector(name)]) return nil;
    return specifier.name;
}

static BOOL RAKResetPageTitle(NSString *title) {
    NSString *clean = RAKClean(title);
    return [clean isEqualToString:@"reset"] ||
           [clean hasPrefix:@"transfer or reset"] ||
           [clean hasPrefix:@"transfer or restore"];
}

// Limit all specifier changes to Apple's reset UI, not unrelated Settings panes.
static BOOL RAKResetContext(PSListController *controller, NSArray *specifiers) {
    if (RAKResetPageTitle(controller.title)) return YES;

    NSString *cls = RAKClean(NSStringFromClass([controller class]));
    if ([cls containsString:@"transferorreset"] ||
        [cls containsString:@"resetsettingscontroller"] ||
        [cls containsString:@"resetcontroller"]) return YES;

    for (id object in specifiers) {
        if (![object isKindOfClass:%c(PSSpecifier)]) continue;
        NSString *identifier = RAKClean(RAKSpecifierID(object));
        if ([identifier isEqualToString:@"fullerase"] ||
            [identifier isEqualToString:@"settingserase"]) return YES;
    }

    BOOL foundReset = NO;
    BOOL foundErase = NO;
    for (id object in specifiers) {
        if (![object isKindOfClass:%c(PSSpecifier)]) continue;
        NSString *name = RAKClean(RAKSpecifierName(object));
        if ([name isEqualToString:@"reset"] ||
            [name isEqualToString:@"reset all settings"]) foundReset = YES;
        if ([name isEqualToString:@"erase all content and settings"]) foundErase = YES;
    }
    return foundReset && foundErase;
}

static BOOL RAKBlockedSpecifier(PSListController *controller, PSSpecifier *specifier) {
    if (!specifier || ![specifier isKindOfClass:%c(PSSpecifier)]) return NO;
    if (!RAKResetContext(controller, [controller specifiers])) return NO;
    return RAKProtectedIdentifier(RAKSpecifierID(specifier)) ||
           RAKProtectedTitle(RAKSpecifierName(specifier));
}

static void RAKDisableCell(UITableViewCell *cell) {
    cell.userInteractionEnabled = NO;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.textLabel.enabled = NO;
    cell.detailTextLabel.enabled = NO;
    if (@available(iOS 13.0, *)) {
        cell.textLabel.textColor = [UIColor tertiaryLabelColor];
        cell.detailTextLabel.textColor = [UIColor tertiaryLabelColor];
    }
}

// iOS 16 may render the footer buttons using UIKit rather than PSSpecifier.
static BOOL RAKHasProtectedLabel(UIView *view) {
    if ([view isKindOfClass:[UILabel class]]) {
        return RAKProtectedTitle(((UILabel *)view).text);
    }
    for (UIView *subview in view.subviews) {
        if (RAKHasProtectedLabel(subview)) return YES;
    }
    return NO;
}

static void RAKGuardViewTree(UIView *root) {
    if (!root) return;
    if ([root isKindOfClass:[UITableViewCell class]]) {
        UITableViewCell *cell = (UITableViewCell *)root;
        if (RAKProtectedTitle(cell.textLabel.text) ||
            RAKProtectedTitle(cell.accessibilityLabel) ||
            RAKHasProtectedLabel(cell.contentView)) {
            RAKDisableCell(cell);
        }
    }
    if ([root isKindOfClass:[UIControl class]] &&
        ![root isKindOfClass:[UITableViewCell class]]) {
        UIControl *control = (UIControl *)root;
        NSString *title = nil;
        if ([control isKindOfClass:[UIButton class]]) {
            title = [(UIButton *)control currentTitle];
        }
        if (RAKProtectedTitle(title) ||
            RAKProtectedTitle(control.accessibilityLabel)) {
            control.enabled = NO;
            control.userInteractionEnabled = NO;
            control.alpha = MIN(control.alpha, 0.45);
        }
    }
    for (UIView *subview in root.subviews) RAKGuardViewTree(subview);
}

%hook PSListController

- (NSArray *)specifiers {
    NSArray *result = %orig;
    if (![result isKindOfClass:[NSArray class]] ||
        !RAKResetContext(self, result)) return result;

    for (id object in result) {
        if (![object isKindOfClass:%c(PSSpecifier)]) continue;
        PSSpecifier *specifier = (PSSpecifier *)object;
        if (RAKProtectedIdentifier(RAKSpecifierID(specifier)) ||
            RAKProtectedTitle(RAKSpecifierName(specifier))) {
            [specifier setProperty:@NO forKey:@"enabled"];
        }
    }
    return result;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = %orig;
    PSSpecifier *specifier = [self specifierAtIndexPath:indexPath];
    if (RAKBlockedSpecifier(self, specifier)) RAKDisableCell(cell);
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView
    shouldHighlightRowAtIndexPath:(NSIndexPath *)indexPath {
    if (RAKBlockedSpecifier(self, [self specifierAtIndexPath:indexPath])) return NO;
    return %orig;
}

- (void)tableView:(UITableView *)tableView
    didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (RAKBlockedSpecifier(self, [self specifierAtIndexPath:indexPath])) {
        [tableView deselectRowAtIndexPath:indexPath animated:NO];
        return;
    }
    %orig;
}

- (BOOL)performActionForSpecifier:(PSSpecifier *)specifier {
    if (RAKBlockedSpecifier(self, specifier)) return NO;
    return %orig;
}

- (BOOL)performButtonActionForSpecifier:(PSSpecifier *)specifier {
    if (RAKBlockedSpecifier(self, specifier)) return NO;
    return %orig;
}

- (BOOL)performLoadActionForSpecifier:(PSSpecifier *)specifier {
    if (RAKBlockedSpecifier(self, specifier)) return NO;
    return %orig;
}

- (void)showConfirmationViewForSpecifier:(PSSpecifier *)specifier {
    if (RAKBlockedSpecifier(self, specifier)) return;
    %orig;
}

%end

%hook UIViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    // This is intentionally limited to Settings and the named reset pages.
    if (RAKResetPageTitle(self.title)) RAKGuardViewTree(self.view);
}

- (void)viewDidLayoutSubviews {
    %orig;
    if (RAKResetPageTitle(self.title)) RAKGuardViewTree(self.view);
}

%end
