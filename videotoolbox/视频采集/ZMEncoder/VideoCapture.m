//
//  VideoCapture.m
//  视频采集
//
//  Created by  luzhaoyang on 17/7/25.
//  Copyright © 2017年 Kingstong. All rights reserved.
//

#import "VideoCapture.h"
#import <AVFoundation/AVFoundation.h>
#import "H264Encoder.h"


@interface VideoCapture()<AVCaptureVideoDataOutputSampleBufferDelegate>

@property (nonatomic, weak) AVCaptureSession *session;
@property (nonatomic, weak) AVCaptureVideoPreviewLayer *previewLayer;
@property(nonatomic, strong) H264Encoder *encoder;


@end

@implementation VideoCapture


- (void)starCapturing:(UIView *)preView
{
    self.encoder = [[H264Encoder alloc]init];
    [self.encoder prepareEncodeWithWidth:720 height:1280];
    
    // 1.创建session
    AVCaptureSession *session = [[AVCaptureSession alloc]init];
    session.sessionPreset = AVCaptureSessionPreset1280x720;
    self.session = session;
    
    // 2.设置视频的输入
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType: AVMediaTypeVideo]; // 默认是前置还是后后置
    NSError *error;
    
    AVCaptureDeviceInput *input = [[AVCaptureDeviceInput alloc]initWithDevice:device error:&error];
    [session addInput:input];
    
    // 3.设置视屏的输出
    AVCaptureVideoDataOutput *output = [[AVCaptureVideoDataOutput alloc]init];
    dispatch_queue_t queue = dispatch_get_global_queue(0, 0); // 在队列中输出
    [output setSampleBufferDelegate:self queue:queue];
    [output setAlwaysDiscardsLateVideoFrames:YES]; // 如果有贞如果来不及处理的话就直接丢弃掉
    [session addOutput: output];
   

    // 视屏输出的方向
    // 设置方向必须是要把outPut放到session之后
    AVCaptureConnection *connection = [output connectionWithMediaType: AVMediaTypeVideo];
    

    if (connection.isVideoMirroringSupported) {
        connection.videoOrientation = AVCaptureVideoOrientationPortrait;
    } else {
        NSLog(@"不支持设置方向");
    }
    
    // 4.添加预览图层
    AVCaptureVideoPreviewLayer *layer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:session];
    layer.frame = preView.bounds;
    [preView.layer insertSublayer:layer atIndex:0];
    self.previewLayer = layer;
    
    [session startRunning];
    
}


- (void)stopCapturing
{
    [self.previewLayer removeFromSuperlayer];
    [self.session stopRunning];
}


// 如果出现丢帧
- (void)captureOutput:(AVCaptureOutput *)captureOutput didDropSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection{}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    NSLog(@"采集到视屏的画面"); // 拿到的画面的帧数都在这里面
    [self.encoder encodeFrame:sampleBuffer];
}








@end
