//
//  AppDelegate.h
//  视频采集
//
//  Created by  luzhaoyang on 17/7/25.
//  Copyright © 2017年 Kingstong. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

@property (readonly, strong) NSPersistentContainer *persistentContainer;

- (void)saveContext;


@end

