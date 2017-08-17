//
//  ToolBoxVC.m
//  视频采集
//
//  Created by  luzhaoyang on 17/8/11.
//  Copyright © 2017年 Kingstong. All rights reserved.
//

#import "ToolBoxVC.h"
#import <VideoToolbox/VideoToolbox.h>

const char pStarCode[] = "\x00\x00\x00\x01";

@interface ToolBoxVC ()
{
    long inputMaxSize; // 一次读多少
    long inputSize; // 实际读取了多少
    uint8_t *inputBuffer; // 保存数据的内存
    
    long packetSize; // 解析的数据的大小
    uint8_t *packetBuffer; // 解析好的数据存放的地方
    
    long spsSize; 
    uint8_t *pSPS;
    
    long ppsSize;
    uint8_t *pPPS;
}

@property (nonatomic, weak) CADisplayLink *displayLink;
@property (nonatomic, strong) NSInputStream *inputStream;
@property (nonatomic, strong) dispatch_queue_t queue;
@property (nonatomic, assign) VTDecompressionSessionRef decompressionSession;
@property (nonatomic, assign) CMVideoFormatDescriptionRef formatDescription;

@end

@implementation ToolBoxVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    
    // 1.创建CADisplayLink
    CADisplayLink *displaylink = [CADisplayLink displayLinkWithTarget:self selector:@selector(updataSream)];
    self.displayLink = displaylink;
    self.displayLink.frameInterval = 2; // 两秒钟更新一次
    [displaylink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    [self.displayLink setPaused:YES];
    
    // 2.创建NSInputStream
    NSString *filePath = [[NSBundle mainBundle] pathForResource:@"123.h264" ofType:nil];
    self.inputStream = [NSInputStream inputStreamWithFileAtPath:filePath];
    
    // 3.创建对列
    self.queue = dispatch_get_global_queue(0, 0);
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event{
    [self play];
}


- (void)play {
    
    // 0.初始化一次读取多少数据, 以及数据的长度, 数据储存放在那里
    inputMaxSize = 1280 * 720; // 至少读出一帧
    inputSize = 0;
    inputBuffer = malloc(inputMaxSize);
    
    // 1. 打开流
    [self.inputStream open];
    
    // 2.开示读取数据
    [self.displayLink setPaused: NO];
}

# pragma mark - 开始读取数据
- (void)updataSream
{
    dispatch_sync(_queue, ^{
        
        // 1.读取数据
        [self readPacket];
        
        // 2.判断数据的类型
        if (packetSize == 0 && packetBuffer == NULL) {
            [self.displayLink setPaused:YES];
            NSLog(@"数据读取完成");
            return;
        }
        
        // 3.解码 H264的打端数据 数据是在内存中:系统端的数据
        uint32_t nalSize = (uint32_t)(packetSize - 4);
        uint32_t *pNAL = (uint32_t *)packetBuffer;
        *pNAL = CFSwapInt32HostToBig(nalSize);
        
        // 4.获取类型 sps: 0x27 pps: 0x28 IDR: 0x25
        // 前五位: 0x07 sps 0x08 pps 0x05 : i
        int nalType = packetBuffer[4] & 0x1F;
        switch (nalType) {
            case 0x07:
                spsSize = packetSize - 4;
                pSPS = malloc(spsSize);
                memcpy(pSPS, packetBuffer + 4, spsSize);
                
                break;
            case 0x08:
                
                ppsSize = packetSize - 4;
                pPPS = malloc(ppsSize);
                memcpy(pPPS, packetBuffer + 4, ppsSize);
                
                break;
            case 0x05:
                
                // 1. 创建VTDecompressionSessionRef
                [self initDecompressionSession];
                
                // 2. 解码I帧
                [self decodeFrame];
                NSLog(@"开示解码");
                
                break;
            default:
                [self decodeFrame];
                NSLog(@"开示解码");
                break;
        }
    });
}


#pragma mark - 从文件中读取一个NALU的数据
// AVFrame(编码前的帧数据)/AVPacket(编码后的帧数据)
- (void)readPacket {
    
    // 0. 第二次读取的时候必须保证 第一次的数据被清除掉了
    if (packetSize || packetBuffer) {
        packetSize = 0;
        free(packetBuffer);
        packetBuffer = nil;
    }
    
    // 2. 读取数据
    if (inputSize < inputMaxSize && _inputStream.hasBytesAvailable) {
        inputSize += [self.inputStream read: inputBuffer + inputSize maxLength: inputMaxSize - inputSize];
    }
    
    // 这个方法之后 inputSize == inputMaxSize
    // 3.获取解码想要的数据 可以解码的数据坑定是以 00 00 00 01 开头
    
    // - 1: 非正常 0: 正常
    if (memcmp(inputBuffer, pStarCode, 4) == 0) {
        
        uint8_t *pStar = inputBuffer + 4;
        uint8_t *pEnd = inputBuffer + inputSize;
        while (pStar != pEnd) {
            
            if (memcmp(pStar - 3, pStarCode, 4) == 0) {
                
                // 获取到下一个 0x 00 00 00 01
                packetSize = pStar - 3 - inputBuffer;
                packetBuffer = malloc(packetSize);
                
                // 从inputBuffer中,拷贝导数据,packetbuffer
                memcpy(packetBuffer, inputBuffer, packetSize);
                
                // 将数据移动到最前方
                memmove(inputBuffer, inputBuffer + packetSize, inputSize - packetSize);
                
                // 改变inputSize的大小
                inputSize -= packetSize;
                
                break;
                
            } else {
                pStar++;
            }
        }
    }
}


#pragma mark - 初始化VTDecompressionSession
- (void)initDecompressionSession {
    
    // 1.创建一个CMVideoFormatDescriptonRef
    // 参数1. 模式
    // 参数2. 参数集 两个 sps pps
    // 参数3. 参数的的指针
    // 参数4. 数组的大小
    
    const uint8_t *pParamSet[2] = {pSPS, pPPS};
    const size_t pParamSizes[2] = {spsSize, ppsSize};
    
    CMVideoFormatDescriptionCreateFromH264ParameterSets(NULL, 2, pParamSet, pParamSizes, 4, &_formatDescription);
    
    NSDictionary *attrs = @{(__bridge NSString *)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)};
    VTDecompressionOutputCallbackRecord callbackRecord;
    callbackRecord.decompressionOutputCallback = decodeCallback;
    
    // 2.创建VTDecompressionSessionRef YUV(颜色储存格式)/RGB()
    VTDecompressionSessionCreate(NULL, self.formatDescription, NULL, (__bridge CFDictionaryRef)attrs, &callbackRecord, &_decompressionSession);
}

void decodeCallback(void * CM_NULLABLE decompressionOutputRefCon,
                    void * CM_NULLABLE sourceFrameRefCon,
                    OSStatus status,
                    VTDecodeInfoFlags infoFlags,
                    CM_NULLABLE CVImageBufferRef imageBuffer,
                    CMTime presentationTimeStamp,
                    CMTime presentationDuration ) {
    
    NSLog(@"解码出一帧的数据");
}

#pragma mark - 真正的解码数据
- (void)decodeFrame {
    
    // 1. 通过将数据创建一个CMblockBuffer
    CMBlockBufferRef blockBuffer;
    CMBlockBufferCreateWithMemoryBlock(NULL, (void *)packetBuffer, packetSize, kCFAllocatorNull, NULL, 0, packetSize, 0, &blockBuffer);
    
    // 2. 准备CMSampleBuffer;
    size_t sizeArray[] = {packetSize};
    CMSampleBufferRef sampleBuffer;
    CMSampleBufferCreateReady(NULL, blockBuffer, self.formatDescription, 0, 0, NULL, 0, sizeArray, &sampleBuffer);
    
    // 3. 开始我们的解码操作
    OSStatus status = VTDecompressionSessionDecodeFrame(self.decompressionSession, sampleBuffer, 0, (__bridge void * _Nullable)(self), NULL);
    
    if (status == noErr) {
    }
}


@end
