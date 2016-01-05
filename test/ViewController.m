//
//  ViewController.m
//  test
//
//  Created by Brian Olencki on 10/16/15.
//  Copyright © 2015 bolencki13. All rights reserved.
//

#import "ViewController.h"

#define SCREEN ([UIScreen mainScreen].bounds)
#define CENTER (CGPointMake(SCREEN.size.width/2,SCREEN.size.height/2))

#import <objc/runtime.h>
#import <dlfcn.h>
@interface ViewController()

@end

Class getClassFromPrivateFramework(NSString *class) {
    Class outClass = NSClassFromString(class);
    
    void *handle = dlopen("/System/Library/PrivateFrameworks/Preferences.framework/Preferences", RTLD_NOW);
    if (handle) {
        outClass = NSClassFromString(class);
        assert(outClass != Nil);
        if (0 != dlclose(handle)) {
            printf("dlclose failed! %s\n", dlerror());
        }
    } else {
        printf("dlopen failed! %s\n", dlerror());
    }
    
    return outClass;
}
Class subClass(Class superClass) {
    Class subClass = objc_allocateClassPair(superClass, [[NSString stringWithFormat:@"my_%@",superClass] UTF8String], 0);
    objc_registerClassPair(subClass);
    
    return objc_getClass([[NSString stringWithFormat:@"my_%@",superClass] UTF8String]);
}
Method getCorrectMethod() {
    unsigned int methodCount = 0;
    Method *methods = class_copyMethodList(NSClassFromString(@"PSSpecifier"), &methodCount);
    
    for (unsigned int i = 0; i < methodCount; i++) {
        Method method = methods[i];
        
        if (strcmp(sel_getName(method_getName(method)), "setButtonAction:")) {
            free(methods);
            return method;
        }
    }
    
    free(methods);
    return nil;
}

Class my_PSListController;
id instanceMethod;
@implementation ViewController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor lightGrayColor];
    
    Class PSListController = getClassFromPrivateFramework(@"PSListController");
    my_PSListController = subClass(PSListController);

    SEL origSel = @selector(specifiers);
    SEL mySel = @selector(my_specifiers);
    class_addMethod(my_PSListController,origSel,[self methodForSelector:mySel],[[NSString stringWithFormat:@"mySpecifiers"] UTF8String]);
    
    SEL orig_tableSelect = @selector(tableView:didSelectRowAtIndexPath:);
    SEL my_tableSelect = @selector(my_tableView:didSelectRowAtIndexPath:);
    class_addMethod(my_PSListController,orig_tableSelect,[self methodForSelector:my_tableSelect],[[NSString stringWithFormat:@"myTableSelect"] UTF8String]);
}
- (void)viewDidAppear:(BOOL)animated {
    instanceMethod = [my_PSListController new];
    [self.navigationController pushViewController:instanceMethod animated:YES];
}
- (id)my_specifiers {
    NSMutableArray *_specifiers;
    if (_specifiers == nil) {
        _specifiers = [NSMutableArray new];
#if TARGET_IPHONE_SIMULATOR
        id target = instanceMethod;
        SEL selector = @selector(loadSpecifiersFromPlistName:target:);

        typedef NSArray* (*MethodType)(id, SEL, NSString*, id);
        MethodType methodToCall = (MethodType)[target methodForSelector:selector];
        _specifiers = [methodToCall(target, selector, @"pasSettings", target) mutableCopy];
#else
        Class PSSpecifier = getClassFromPrivateFramework(@"PSSpecifier");
        NSArray *subpaths = [[NSFileManager defaultManager] subpathsOfDirectoryAtPath:@"/Library/PreferenceLoader/Preferences" error:NULL];
        for(NSString *item in subpaths) {
            if(![[item pathExtension] isEqualToString:@"plist"]) continue;
            NSString *fullPath = [NSString stringWithFormat:@"/Library/PreferenceLoader/Preferences/%@", item];
            NSDictionary *plPlist = [NSDictionary dictionaryWithContentsOfFile:fullPath];
            NSDictionary *entry = [plPlist objectForKey:@"entry"];
            NSDictionary *specifierPlist = [NSDictionary dictionaryWithObjectsAndKeys:[NSArray arrayWithObjects:entry, nil], @"items", nil];
            
            BOOL isBundle = [entry objectForKey:@"bundle"] != nil;
            BOOL isLocalizedBundle = ![[fullPath lastPathComponent] isEqualToString:@"Preferences"];
            
            NSBundle *prefBundle;
            NSString *bundleName = [entry objectForKey:@"bundle"];
            NSString *bundlePath = [entry objectForKey:@"bundlePath"];
            
            if ([entry objectForKey:@"detail"] == nil) continue;
            
            if(isBundle) {
                // Second Try (bundlePath key failed)
                if(![[NSFileManager defaultManager] fileExistsAtPath:bundlePath])
                    bundlePath = [NSString stringWithFormat:@"/Library/PreferenceBundles/%@.bundle", bundleName];
                
                // Third Try (/Library failed)
                if(![[NSFileManager defaultManager] fileExistsAtPath:bundlePath])
                    bundlePath = [NSString stringWithFormat:@"/System/Library/PreferenceBundles/%@.bundle", bundleName];
                
                // Really? (/System/Library failed...)
                if(![[NSFileManager defaultManager] fileExistsAtPath:bundlePath]) {
                    return nil;
                }
                dlopen([[NSString stringWithFormat:@"%@/%@",bundlePath,bundleName] UTF8String], RTLD_NOW);
                prefBundle = [NSBundle bundleWithPath:bundlePath];
                [prefBundle load];
            } else {
                dlopen([[NSString stringWithFormat:@"%@",fullPath] UTF8String], RTLD_NOW);
                prefBundle = [NSBundle bundleWithPath:fullPath];
                [prefBundle load];
            }
            
            Ivar ivar = class_getInstanceVariable([my_PSListController class], "_bundleControllers");
            NSMutableArray *ary_bundleControllers = (NSMutableArray*)object_getIvar(instanceMethod, ivar);
            
            NSString *cell = [entry objectForKey:@"cell"];
            const int offset = 0;
            int cellType = offset;// PSGroupCell
            if ([cell isEqualToString:@"PSLinkCell"]) {
                cellType = offset+1;// PSLinkCell
            } else if ([cell isEqualToString:@"PSLinkListCell"]) {
                cellType = offset+2;// PSLinkListCell
            } else if ([cell isEqualToString:@"PSListItemCell"]) {
                cellType = offset+3;// PSListItemCell
            } else if ([cell isEqualToString:@"PSTitleValueCell"]) {
                cellType = offset+4;// PSTitleValueCell
            } else if ([cell isEqualToString:@"PSSliderCell"]) {
                cellType = offset+5;// PSSliderCell
            } else if ([cell isEqualToString:@"PSSwitchCell"]) {
                cellType = offset+6;// PSSwitchCell
            } else if ([cell isEqualToString:@"PSStaticTextCell"]) {
                cellType = offset+7;// PSStaticTextCell
            } else if ([cell isEqualToString:@"PSEditTextCell"]) {
                cellType = offset+8;// PSEditTextCell
            } else if ([cell isEqualToString:@"PSSegmentCell"]) {
                cellType = offset+9;// PSSegmentCell
            } else if ([cell isEqualToString:@"PSGiantIconCell"]) {
                cellType = offset+10;// PSGiantIconCell
            } else if ([cell isEqualToString:@"PSGiantCell"]) {
                cellType = offset+11;// PSGiantCell
            } else if ([cell isEqualToString:@"PSSecureEditTextCell"]) {
                cellType = offset+12;// PSSecureEditTextCell
            } else if ([cell isEqualToString:@"PSButtonCell"]) {
                cellType = offset+13;// PSButtonCell
            } else if ([cell isEqualToString:@"PSEditTextViewCell"]) {
                cellType = offset+14;// PSEditTextViewCell
            }

            if (cellType != offset+1) continue;// go to next item if it is not a PSLinkCell

            id class = [PSSpecifier class];
            SEL mainSelector = @selector(preferenceSpecifierNamed:target:set:get:detail:cell:edit:);
            typedef id (*MainSetUp)(id, SEL, id, id, SEL, SEL, Class, int, Class);
            MainSetUp cell_setUpCell = (MainSetUp)[class methodForSelector:mainSelector];
            id spec_Instance = cell_setUpCell(class, mainSelector,[entry objectForKey:@"label"], instanceMethod, nil, nil, NSClassFromString([entry objectForKey:@"detail"]), cellType, nil);
            
            [spec_Instance setProperty:bundlePath forKey:@"lazy-bundle"];
            [spec_Instance setProperty:prefBundle forKey:@"pl_bundle"];
            
            SEL loadBundle = method_getName(getCorrectMethod());
            typedef void* (*BundleSetUp)(id, SEL, SEL);
            BundleSetUp cell_Bundle = (BundleSetUp)[spec_Instance methodForSelector:loadBundle];
            cell_Bundle(spec_Instance, loadBundle, @selector(lazyLoadBundle:));
            
            Class detailControllerClass = [PSSpecifier class];// isLocalizedBundle ? [PSSpecifier class] : [PLCustomListController class]
            Ivar ivar_detail = class_getInstanceVariable([my_PSListController class], "detailControllerClass");
            ((void (*)(id, Ivar, Class))object_setIvar)(self, ivar_detail, detailControllerClass);
            
            [_specifiers addObject:spec_Instance];
        }
#endif
        
        Ivar ivar = class_getInstanceVariable([my_PSListController class], "_specifiers");
        ((void (*)(id, Ivar, NSArray*))object_setIvar)(self, ivar, _specifiers);
    }
    return _specifiers;
}
- (void)my_tableView:(id)arg1 didSelectRowAtIndexPath:(id)arg2 {
    [arg1 deselectRowAtIndexPath:arg2 animated:YES];
    UITableViewCell *cell = [arg1 cellForRowAtIndexPath:arg2];

    Class PSSpecifier = getClassFromPrivateFramework(@"PSSpecifier");
    Ivar ivar = class_getInstanceVariable([my_PSListController class], "_specifiers");
    NSMutableArray *_specifiers = (NSMutableArray*)object_getIvar(instanceMethod, ivar);
    
    for (id specifier in _specifiers) {
        Ivar ivar = class_getInstanceVariable([PSSpecifier class], "_name");
        NSString *name = (NSString*)object_getIvar(specifier, ivar);
        if ([name isEqualToString:cell.textLabel.text]) {
            Ivar ivar = class_getInstanceVariable([PSSpecifier class], "detailControllerClass");
            Class detailControllerClass = (Class)object_getIvar(specifier, ivar);
            if ([[detailControllerClass class] isSubclassOfClass:[UIViewController class]]) {
                id class = self;
                SEL mainSelector = @selector(pushController:animate:);
                typedef void* (*MainSetUp)(id, SEL, id, BOOL);
                MainSetUp cell_setUpCell = (MainSetUp)[class methodForSelector:mainSelector];
                cell_setUpCell(class, mainSelector, [detailControllerClass new], YES);
            }
        }
    }
}
@end