//
//  MuleCameraViewController.m
//  Mule
//
//  Created by Vince Allen on 2/7/14.
//  Copyright (c) 2014 Vince Allen. All rights reserved.
//

#import "MuleCameraViewController.h"
#include <mach/mach_time.h>
#import <AssetsLibrary/AssetsLibrary.h>

@interface MuleCameraViewController ()

@end

static float kFrameInterval = 1.0;
UInt8 bufOn[1] = {'A'};
UInt8 bufOff[1] = {'B'};

@implementation MuleCameraViewController

@synthesize previewView, startFinishButton, totalFrames, ble;

- (BOOL)setupAVCapture
{
	NSError *error = nil;
    // 30 fps - taking 30 pictures will equal 1 second of video
	frameDuration = CMTimeMakeWithSeconds(1./30., 90000);
	
	AVCaptureSession *session = [AVCaptureSession new];
	[session setSessionPreset:AVCaptureSessionPresetHigh];
	
	// Select a video device, make an input
	AVCaptureDevice *backCamera = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
	AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:backCamera error:&error];
	if (error)
		return NO;
	if ([session canAddInput:input])
		[session addInput:input];
	
	// Make a still image output
	stillImageOutput = [AVCaptureStillImageOutput new];
	if ([session canAddOutput:stillImageOutput])
		[session addOutput:stillImageOutput];
	
	// Make a preview layer so we can see the visual output of an AVCaptureSession
	AVCaptureVideoPreviewLayer *previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:session];
	[previewLayer setVideoGravity:AVLayerVideoGravityResizeAspect];
	[previewLayer setFrame:[previewView bounds]];
	
    // add the preview layer to the hierarchy
    CALayer *rootLayer = [previewView layer];
	[rootLayer setBackgroundColor:[[UIColor blackColor] CGColor]];
	[rootLayer addSublayer:previewLayer];
	
    // start the capture session running, note this is an async operation
    // status is provided via notifications such as AVCaptureSessionDidStartRunningNotification/AVCaptureSessionDidStopRunningNotification
    [session startRunning];
	
	return YES;
}

static CGFloat DegreesToRadians(CGFloat degrees) {return degrees * M_PI / 180;};

- (BOOL)setupAssetWriterForURL:(NSURL *)fileURL formatDescription:(CMFormatDescriptionRef)formatDescription
{
    // allocate the writer object with our output file URL
	NSError *error = nil;
	assetWriter = [[AVAssetWriter alloc] initWithURL:fileURL fileType:AVFileTypeQuickTimeMovie error:&error];
	if (error)
		return NO;
	
    // initialized a new input for video to receive sample buffers for writing
    // passing nil for outputSettings instructs the input to pass through appended samples, doing no processing before they are written
	assetWriterInput = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeVideo outputSettings:nil];
	[assetWriterInput setExpectsMediaDataInRealTime:YES];
	if ([assetWriter canAddInput:assetWriterInput])
		[assetWriter addInput:assetWriterInput];
	
    // specify the prefered transform for the output file
	CGFloat rotationDegrees;
	switch ([[UIDevice currentDevice] orientation]) {
		case UIDeviceOrientationPortraitUpsideDown:
			rotationDegrees = -90.;
			break;
		case UIDeviceOrientationLandscapeLeft: // no rotation
			rotationDegrees = 0.;
			break;
		case UIDeviceOrientationLandscapeRight:
			rotationDegrees = 180.;
			break;
		case UIDeviceOrientationPortrait:
		case UIDeviceOrientationUnknown:
		case UIDeviceOrientationFaceUp:
		case UIDeviceOrientationFaceDown:
		default:
			rotationDegrees = 90.;
			break;
	}
	CGFloat rotationRadians = DegreesToRadians(rotationDegrees);
	[assetWriterInput setTransform:CGAffineTransformMakeRotation(rotationRadians)];
	
    // initiates a sample-writing at time 0
	nextPTS = kCMTimeZero;
	[assetWriter startWriting];
	[assetWriter startSessionAtSourceTime:nextPTS];
	
    return YES;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    [self setupAVCapture];
    frameCount = 0;
    [totalFrames setText:[NSString stringWithFormat:@"frames: %d",frameCount]];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)captureFrame
{
 
    NSData *data = [[NSData alloc] initWithBytes:bufOn length:1];
    [ble write:data];
    
    // initiate a still image capture, return immediately
    // the completionHandler is called when a sample buffer has been captured
	AVCaptureConnection *stillImageConnection = [stillImageOutput connectionWithMediaType:AVMediaTypeVideo];
	[stillImageOutput captureStillImageAsynchronouslyFromConnection:stillImageConnection
      completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *__strong error) {
          
          // set up the AVAssetWriter using the format description from the first sample buffer captured
          if ( !assetWriter ) {
              outputURL = [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@/%llu.mov", NSTemporaryDirectory(), mach_absolute_time()]];
              //NSLog(@"Writing movie to \"%@\"", outputURL);
              CMFormatDescriptionRef formatDescription = CMSampleBufferGetFormatDescription(imageDataSampleBuffer);
              if ( NO == [self setupAssetWriterForURL:outputURL formatDescription:formatDescription] )
                  return;
          }
          
          // re-time the sample buffer - in this sample frameDuration is set to 5 fps
          CMSampleTimingInfo timingInfo = kCMTimingInfoInvalid;
          timingInfo.duration = frameDuration;
          timingInfo.presentationTimeStamp = nextPTS;
          CMSampleBufferRef sbufWithNewTiming = NULL;
          OSStatus err = CMSampleBufferCreateCopyWithNewTiming(kCFAllocatorDefault,
                                                               imageDataSampleBuffer,
                                                               1, // numSampleTimingEntries
                                                               &timingInfo,
                                                               &sbufWithNewTiming);
          if (err)
              return;
          
          // append the sample buffer if we can and increment presnetation time
          if ( [assetWriterInput isReadyForMoreMediaData] ) {
              if ([assetWriterInput appendSampleBuffer:sbufWithNewTiming]) {
                  nextPTS = CMTimeAdd(frameDuration, nextPTS);
              }
              else {
                  NSError *error = [assetWriter error];
                  NSLog(@"failed to append sbuf: %@", error);
              }
          }
          
          // release the copy of the sample buffer we made
          CFRelease(sbufWithNewTiming);
      }];
    
    
    if (started) {
        NSData *data = [[NSData alloc] initWithBytes:bufOff length:1];
        [ble write:data];
        frameCount++;
        [totalFrames setText:[NSString stringWithFormat:@"frames: %d",frameCount]];
        [self performSelector:@selector(captureFrame) withObject:nil afterDelay:kFrameInterval];
    }
}

- (void)saveMovieToCameraRoll
{
    // save the movie to the camera roll
	ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
	//NSLog(@"writing \"%@\" to photos album", outputURL);
	[library writeVideoAtPathToSavedPhotosAlbum:outputURL
        completionBlock:^(NSURL *assetURL, NSError *error) {
            if (error) {
                NSLog(@"assets library failed (%@)", error);
            }
            else {
                [[NSFileManager defaultManager] removeItemAtURL:outputURL error:&error];
                if (error)
                    NSLog(@"Couldn't remove temporary movie file \"%@\"", outputURL);
            }
            outputURL = nil;
        }];
}

- (IBAction)startStop:(id)sender
{
	if (started) {
        NSData *data = [[NSData alloc] initWithBytes:bufOff length:1];
        [ble write:data];
		if (assetWriter) {
			[assetWriterInput markAsFinished];
            [assetWriter finishWritingWithCompletionHandler:^(){
                NSLog (@"finished writing");
            }];
			assetWriterInput = nil;
			assetWriter = nil;
			[self saveMovieToCameraRoll];
		}
		[sender setTitle:@"Start"];
	}
	else {
		[sender setTitle:@"Finish"];
        [self performSelector:@selector(captureFrame) withObject:nil afterDelay:kFrameInterval];
	}
	started = !started;
}


@end
