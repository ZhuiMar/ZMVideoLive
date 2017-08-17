//
//  H264Encoder.h
//  视频采集
//
//  Created by  luzhaoyang on 17/8/6.
//  Copyright © 2017年 Kingstong. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@interface H264Encoder : NSObject

- (void)prepareEncodeWithWidth:(int)width height: (int)height;
- (void)encodeFrame: (CMSampleBufferRef)CMSampleBuffer;

@end
