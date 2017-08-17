//
//  H264Encoder.m
//  视频采集
//
//  Created by  luzhaoyang on 17/8/6.
//  Copyright © 2017年 Kingstong. All rights reserved.
//

#import "H264Encoder.h"
#import <VideoToolbox/VideoToolbox.h>

@interface H264Encoder()

@property (nonatomic, assign) VTCompressionSessionRef compressionSession;
@property (nonatomic, assign) int frameIndex;
@property(nonatomic, strong) NSFileHandle *fileHandle;

@end

@implementation H264Encoder

- (void)prepareEncodeWithWidth:(int)width height: (int)height;
{
    NSString *filePath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject]stringByAppendingPathComponent: @"123.h264"];
    
    [[NSFileManager defaultManager] createFileAtPath: filePath contents: nil attributes: nil];
    
    self.fileHandle = [NSFileHandle fileHandleForWritingAtPath: filePath];
    self.frameIndex = 0;
    
    // VTCCompressionSessionRef
    // 参数1:CFAllocatorRef 用于 CoreFoundation分配模式 NULL表示默认的分配的方式
    // 参数2:编码出来的视屏的宽度 width
    // 参数3:编码出来的视屏的高度 height
    // 参数4:编码的标准: H.264/AVC
    // 参数5.6.7: NULL
    // 参数8:编码成功后的回调函数
    // 参数9:可以传递到回调函数中的参数, self:将当前对象传入
    
    VTCompressionSessionCreate(NULL, width, height, kCMVideoCodecType_H264, NULL, NULL, NULL, didCompressionCallback, (__bridge void *_Nullable)(self), &_compressionSession);
    
    // 设置属性
    
    // 1.设置实时输出
    VTSessionSetProperty(_compressionSession, kVTCompressionPropertyKey_RealTime, kCFBooleanTrue);
    
    // 2.设置帧率
    VTSessionSetProperty(_compressionSession, kVTCompressionPropertyKey_ExpectedFrameRate, (__bridge CFTypeRef _Nonnull)(@24));
    
    // 3.设置比特率
    VTSessionSetProperty(_compressionSession, kVTCompressionPropertyKey_AverageBitRate, (__bridge CFTypeRef _Nonnull)(@1500000)); // bit
    VTSessionSetProperty(_compressionSession, kVTCompressionPropertyKey_DataRateLimits, (__bridge CFTypeRef _Nonnull)(@[@(1500000/8), @1])); // 表示1秒钟1500000的比特率  除以8表示
    
    // 3.设置GOP的小
    VTSessionSetProperty(_compressionSession, kVTCompressionPropertyKey_MaxKeyFrameInterval, (__bridge CFTypeRef _Nonnull)(@20));
    
    // 4.准备编码
    VTCompressionSessionPrepareToEncodeFrames(_compressionSession);
}


-  (void)encodeFrame:(CMSampleBufferRef)sampleBuffer
{
    // 1.将CMSampleBufferRef转化成CVImageBufferRef
    CVImageBufferRef iamgeBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    
    // 2.真正的开示编码
    // 参数1: compressionSession
    // 参数2: 将CMSampleBufferRef转化成CVImageBufferRef
    // 参数3: PTS(presenttationTimeStamp)/DTS(DecodeTimeStamp)
    // 参数4: kCMTimeInvalid
    // 参数5: 实在回调函数中的第二个参数
    // 参数6: 实在回调函数中的第四个参数
    
    CMTime pts = CMTimeMake(self.frameIndex, 24);
    VTCompressionSessionEncodeFrame(self.compressionSession, iamgeBuffer, pts, kCMTimeInvalid, NULL, NULL, NULL);
    NSLog(@"开始编码第一帧数据");
}


#pragma mark - 获取编码后的数据
void didCompressionCallback(void * CM_NULLABLE outputCallbackRefCon,
                                    void * CM_NULLABLE sourceFrameRefCon,
                                    OSStatus status,
                                    VTEncodeInfoFlags infoFlags,
                                    CM_NULLABLE CMSampleBufferRef sampleBuffer ) {
    NSLog(@"编码出以贞的图像");
    
    // 0.获取当前的额对象
    H264Encoder *encoder = (__bridge H264Encoder *)(outputCallbackRefCon);
    
    // 1.判断该帧是否是关键帧
    CFArrayRef attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, true);
    CFDictionaryRef dict = CFArrayGetValueAtIndex(attachments, 0);
    BOOL iskeyFrame = !CFDictionaryContainsKey(dict, kCMSampleAttachmentKey_NotSync);
    
    // 2.如果是关键帧，获取SPS/PPS数据并写入文件
    if (iskeyFrame) {
        
        CMFormatDescriptionRef format = CMSampleBufferGetFormatDescription(sampleBuffer);
        
        // 获取SPS的信息
        const uint8_t *spsOut;
        size_t spsSize, spsCount;
        CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 0, &spsOut, &spsSize, &spsCount, NULL);
        
        // 获取PPS的信息
        const uint8_t *ppsOut;
        size_t ppsSize, ppsCount;
        CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 1, &ppsOut, &ppsSize, &ppsCount, NULL);
        
        // 将SPS/PPS转化成NSData, 幷写入问件
        NSData *spsData = [NSData dataWithBytes:spsOut length: spsSize];
        NSData *ppsData = [NSData dataWithBytes:ppsOut length: ppsSize];
        
        // 写入文件(NALU单元 0x00 00 00 01 的前四个字节一定是这四个字节)所以存储之前一定要拼接上这些东西
        [encoder wirteData: spsData];
        [encoder wirteData: ppsData];
    }
    
        // 1.获取编码之后的数据, 写入文件
        CMBlockBufferRef blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
        
        // 2.从blockBuffer内存地址中获取起始位置的内存地址
        size_t totalLength = 0;
        char *dataPointer;
        CMBlockBufferGetDataPointer(blockBuffer, 0, NULL, &totalLength, &dataPointer);
        
        // 3.一帧的图像可能需要写入多个NALU单元 --->Slice切片
        static const int H264HeaderLength = 4;
        size_t bufferOffset = 0;
        
        while (bufferOffset < totalLength - H264HeaderLength) {
            
            // 4.从其实位置拷贝H264HeaderLenght长度的地址，计算NALULenght
            int NALULenght = 0;
            memcpy(&NALULenght, dataPointer + bufferOffset, H264HeaderLength);
            
            // 5.大端模式/小端模式 --> 系统模式
            // H264编码的数据是大端模式(字节序)
            NALULenght = CFSwapInt32BigToHost(NALULenght);
            
            // 6.从dataPointer开示，根据长度创建NSdata
            NSData *data = [NSData dataWithBytes:dataPointer + H264HeaderLength + bufferOffset length: NALULenght];
            
            // 6.1写入文件
            [encoder wirteData: data];
            
            // 7.写入文件前先设置偏移
            bufferOffset += NALULenght + H264HeaderLength;
        }
}


- (void)wirteData: (NSData *)data
{
    NSLog(@"可以看到是否有写入");
    
    // 1.获取starCoder
    const char bytes[] = "\x00\x00\x00\x01";
    
    // 2.获取headerData
    NSData *headerData = [NSData dataWithBytes: bytes length: sizeof(bytes) - 1]; // 减1 每个字符串的后面都有\0
    
    // 3.写入文件
    [self.fileHandle writeData: headerData];
    [self.fileHandle writeData: data];
}


@end
