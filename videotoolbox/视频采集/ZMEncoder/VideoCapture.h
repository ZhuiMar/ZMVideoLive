//
//  VideoCapture.h
//  视频采集
//
//  Created by  luzhaoyang on 17/7/25.
//  Copyright © 2017年 Kingstong. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface VideoCapture : NSObject
 
- (void)starCapturing:(UIView *)preView;
- (void)stopCapturing;

@end
