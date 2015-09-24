//
//  TGCameraViewController.m
//  TGCameraViewController
//
//  Created by Bruno Tortato Furtado on 13/09/14.
//  Copyright (c) 2014 Tudo Gostoso Internet. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

#import "TGCameraViewController.h"
#import "TGPhotoViewController.h"
#import "TGCameraSlideView.h"
#import "TGTintedButton.h"
#import <CoreLocation/CoreLocation.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import <ImageIO/ImageIO.h>
#import "TGCameraColor.h"

@interface TGCameraViewController () <UIImagePickerControllerDelegate, UINavigationControllerDelegate>

@property (strong, nonatomic) IBOutlet UIView *captureView;
@property (strong, nonatomic) IBOutlet UIImageView *topLeftView;
@property (strong, nonatomic) IBOutlet UIImageView *topRightView;
@property (strong, nonatomic) IBOutlet UIImageView *bottomLeftView;
@property (strong, nonatomic) IBOutlet UIImageView *bottomRightView;
@property (strong, nonatomic) IBOutlet UIView *separatorView;
@property (strong, nonatomic) IBOutlet UIView *actionsView;
@property (strong, nonatomic) IBOutlet UIButton *gridButton;
@property (strong, nonatomic) IBOutlet UIButton *toggleButton;
@property (strong, nonatomic) IBOutlet UIButton *shotButton;
@property (strong, nonatomic) IBOutlet TGTintedButton *albumButton;
@property (strong, nonatomic) IBOutlet UIButton *flashButton;
@property (strong, nonatomic) IBOutlet TGCameraSlideView *slideUpView;
@property (strong, nonatomic) IBOutlet TGCameraSlideView *slideDownView;
@property (strong, nonatomic) IBOutlet UIImageView *shotOutline;
@property (weak, nonatomic) IBOutlet UIView *squareCaptureView;
@property (weak, nonatomic) IBOutlet UIView *topView;

@property (weak, nonatomic) IBOutlet NSLayoutConstraint *topViewHeight;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *toggleButtonWidth;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *topLeftViewTopConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *topRightViewTopConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *bottomRightBottomConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *bottomLeftBottomConstraint;

@property (strong, nonatomic) TGCamera *camera;
@property (nonatomic) BOOL wasLoaded;
@property (nonatomic) UIDeviceOrientation deviceOrientation;
@property (nonatomic) BOOL landscapeViewMode;

- (IBAction)closeTapped;
- (IBAction)gridTapped;
- (IBAction)flashTapped;
- (IBAction)shotTapped;
- (IBAction)albumTapped;
- (IBAction)toggleTapped;

- (IBAction)handleTapGesture:(UITapGestureRecognizer *)recognizer;

- (void)deviceOrientationDidChangeNotification;
- (void)latestPhoto;
- (AVCaptureVideoOrientation)videoOrientationForDeviceOrientation:(UIDeviceOrientation)deviceOrientation;
- (void)viewWillDisappearWithCompletion:(void (^)(void))completion;

@end

@implementation TGCameraViewController

- (void)viewDidLoad {
    NSLog(@"%s",__FUNCTION__);
    
    [super viewDidLoad];
    
    if (CGRectGetHeight([[UIScreen mainScreen] bounds]) <= 480) {
        _topViewHeight.constant = 0;
    }
    
    if ([[TGCamera getOption:kTGCameraOptionHiddenToggleButton] boolValue] == YES) {
        _toggleButton.hidden = YES;
        _toggleButtonWidth.constant = 0;
    }
    
    [self setupAlbumButton];
    
    _camera = [TGCamera cameraWithFlashButton:_flashButton];
    
    _captureView.backgroundColor = [UIColor clearColor];
    
    _topLeftView.transform = CGAffineTransformMakeRotation(0);
    _topRightView.transform = CGAffineTransformMakeRotation(M_PI_2);
    _bottomLeftView.transform = CGAffineTransformMakeRotation(-M_PI_2);
    _bottomRightView.transform = CGAffineTransformMakeRotation(M_PI_2*2);
    
    // get the latest image from the album
    [self latestPhoto];
}

- (void)viewWillAppear:(BOOL)animated {
    NSLog(@"%s",__FUNCTION__);
    
    [super viewWillAppear:animated];
    
    dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
        [_camera startRunning];
        
        dispatch_async(dispatch_get_main_queue(), ^(void){
            _separatorView.hidden = YES;
            
            if (_wasLoaded == NO) {
                _wasLoaded = YES;
                [_camera insertSublayerWithCaptureView:_captureView atRootView:self.view];
            }
        });
    });
    
    _shotButton.enabled = true;
    _shotOutline.hidden = false;
}

- (void)viewDidAppear:(BOOL)animated {
    NSLog(@"%s",__FUNCTION__);
    
    [super viewDidAppear:animated];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(deviceOrientationDidChangeNotification)
                                                 name:UIDeviceOrientationDidChangeNotification
                                               object:nil];
    
    [self deviceOrientationDidChangeNotification];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [_camera stopRunning];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}

- (void)dealloc {
    _captureView = nil;
    _topLeftView = nil;
    _topRightView = nil;
    _bottomLeftView = nil;
    _bottomRightView = nil;
    _separatorView = nil;
    _actionsView = nil;
    _gridButton = nil;
    _toggleButton = nil;
    _shotButton = nil;
    _albumButton = nil;
    _flashButton = nil;
    _slideUpView = nil;
    _slideDownView = nil;
    _camera = nil;
}

#pragma mark -
#pragma mark - UIImagePickerControllerDelegate

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    UIImage *photo = [TGAlbum imageWithMediaInfo:info];
    //NSMutableDictionary* exifDict;
    
    if ([[info allKeys] containsObject:UIImagePickerControllerReferenceURL]){
        
        NSURL *assetURL = [info objectForKey:UIImagePickerControllerReferenceURL];
        ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
        [library assetForURL:assetURL resultBlock:^(ALAsset *asset) {
            if (asset)
            {
                NSDictionary *metadata = asset.defaultRepresentation.metadata;
                NSMutableDictionary *exifDict = [[NSMutableDictionary alloc] initWithDictionary:metadata];
                
                //IOS8対応
                //ALAssetRepresentation *assetRepresentation = [asset defaultRepresentation];
                //UIImage *fullscreenImage = [UIImage imageWithCGImage:[assetRepresentation fullScreenImage]];
                //UIImage *photo = scaleAndRotateImage(fullscreenImage); //イメージをセット
                Byte *buffer = (Byte*)malloc(asset.defaultRepresentation.size);
                NSUInteger buffered = [asset.defaultRepresentation getBytes:buffer fromOffset:0.0 length:asset.defaultRepresentation.size error:nil];
                NSData *imageData = [NSData dataWithBytesNoCopy:buffer length:buffered freeWhenDone:YES];
                
                
                
                if ([_delegate respondsToSelector:@selector(cameraShouldShowPreviewScreenForGalleryPicker)]) {
                    if ([_delegate cameraShouldShowPreviewScreenForGalleryPicker]) {
                        TGPhotoViewController *viewController = [TGPhotoViewController newWithDelegate:_delegate photo:photo];
                        [viewController setAlbumPhoto:YES];
                        [self.navigationController pushViewController:viewController animated:NO];
                    }else{
                        [_delegate cameraDidSelectAlbumPhoto:photo exifDict:exifDict imageData:imageData withDisappearingTime:0];
                    }
                }else{
                    TGPhotoViewController *viewController = [TGPhotoViewController newWithDelegate:_delegate photo:photo];
                    [viewController setAlbumPhoto:YES];
                    [self.navigationController pushViewController:viewController animated:NO];
                }
                
                [self dismissViewControllerAnimated:YES completion:nil];
            }
            else
            {
                [library enumerateGroupsWithTypes:ALAssetsGroupPhotoStream usingBlock:^(ALAssetsGroup *group, BOOL *stop) {
                    [group enumerateAssetsWithOptions:NSEnumerationReverse usingBlock:^(ALAsset *asset, NSUInteger index, BOOL *stop) {
                        if ([asset.defaultRepresentation.url isEqual:assetURL]){
                            // フォトストリームのALAsset取得成功
                            *stop = YES;
                            NSDictionary *metadata = asset.defaultRepresentation.metadata;
                            NSMutableDictionary *exifDict = [[NSMutableDictionary alloc] initWithDictionary:metadata];
                            
                            //IOS8対応
                            //ALAssetRepresentation *assetRepresentation = [asset defaultRepresentation];
                            //UIImage *fullscreenImage = [UIImage imageWithCGImage:[assetRepresentation fullScreenImage]];
                            //UIImage *photo = scaleAndRotateImage(fullscreenImage); //イメージをセット
                            
                            Byte *buffer = (Byte*)malloc(asset.defaultRepresentation.size);
                            NSUInteger buffered = [asset.defaultRepresentation getBytes:buffer fromOffset:0.0 length:asset.defaultRepresentation.size error:nil];
                            NSData *imageData = UIImageJPEGRepresentation(photo, 1.0); //[NSData dataWithBytesNoCopy:buffer length:buffered freeWhenDone:YES];
                            
                            
                            if ([_delegate respondsToSelector:@selector(cameraShouldShowPreviewScreenForGalleryPicker)]) {
                                if ([_delegate cameraShouldShowPreviewScreenForGalleryPicker]) {
                                    TGPhotoViewController *viewController = [TGPhotoViewController newWithDelegate:_delegate photo:photo];
                                    [viewController setAlbumPhoto:YES];
                                    [self.navigationController pushViewController:viewController animated:NO];
                                }else{
                                    [_delegate cameraDidSelectAlbumPhoto:photo  exifDict:exifDict imageData:imageData withDisappearingTime:0];
                                }
                            }else{
                                TGPhotoViewController *viewController = [TGPhotoViewController newWithDelegate:_delegate photo:photo];
                                [viewController setAlbumPhoto:YES];
                                [self.navigationController pushViewController:viewController animated:NO];
                            }
                            
                            [self dismissViewControllerAnimated:YES completion:nil];
                            
                        }
                    }];
                } failureBlock:^(NSError *error) {
                    // フォトストリームのALAsset取得失敗
                }];
            }
        } failureBlock:^(NSError *error) {
            // フォトストリーム以外のALAsset取得失敗
        }];
        
    }
    
    
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)navigationController:(UINavigationController *)navigationController willShowViewController:(UIViewController *)viewController animated:(BOOL)animated
{
    [[UIApplication sharedApplication] setStatusBarHidden:YES];
    [viewController prefersStatusBarHidden];
    viewController.navigationController.navigationBar.barTintColor = [TGCameraColor barColor];
    viewController.navigationController.navigationBar.tintColor = [TGCameraColor barTintColor];
    viewController.navigationController.navigationBar.translucent = false;
}

#pragma mark -
#pragma mark - Actions

- (IBAction)closeTapped {
    if ([_delegate respondsToSelector:@selector(cameraDidCancel)]) {
        [_delegate cameraDidCancel];
    }
}

- (IBAction)gridTapped {
    [_camera disPlayGridView];
}

- (IBAction)flashTapped {
    [_camera changeFlashModeWithButton:_flashButton];
}

- (IBAction)shotTapped {
    _shotButton.enabled =
    _albumButton.enabled = NO;
    
    UIDeviceOrientation deviceOrientation;
    if (self.deviceOrientation) {
        deviceOrientation = self.deviceOrientation;
    }else{
        deviceOrientation = [[UIDevice currentDevice] orientation];
    }
    AVCaptureVideoOrientation videoOrientation = [self videoOrientationForDeviceOrientation:deviceOrientation];
    
    [self viewWillDisappearWithCompletion:^{
        [_camera takePhotoWithCaptureView:_captureView videoOrientation:videoOrientation cropSize:_captureView.frame.size
                               completion:^(UIImage *photo,NSDictionary *meta) {
                                   if ([_delegate respondsToSelector:@selector(cameraShouldShowPreviewScreen)]) {
                                       if ([_delegate cameraShouldShowPreviewScreen]) {
                                           [self navigateToPhotoViewController:photo];
                                       } else {
                                           [_delegate cameraDidTakePhoto:photo exifDict:[meta mutableCopy] withDisappearingTime:0];
                                       }
                                   } else {
                                       [self navigateToPhotoViewController:photo];
                                   }
                               }];
    }];
}

- (void)navigateToPhotoViewController:(UIImage *)photo {
    TGPhotoViewController *viewController = [TGPhotoViewController newWithDelegate:_delegate photo:photo];
    [self.navigationController pushViewController:viewController animated:YES];
}

- (IBAction)albumTapped {
    _shotButton.enabled = false;
    _shotOutline.hidden = true;
    _albumButton.enabled = NO;
    
    [self viewWillDisappearWithCompletion:^{
        UIImagePickerController *pickerController = [TGAlbum imagePickerControllerWithDelegate:self];
        [self presentViewController:pickerController animated:YES completion:nil];
    }];
    
}

- (IBAction)toggleTapped {
    [_camera toogleWithFlashButton:_flashButton];
}

- (IBAction)handleTapGesture:(UITapGestureRecognizer *)recognizer {
    CGPoint touchPoint = [recognizer locationInView:_captureView];
    [_camera focusView:_captureView inTouchPoint:touchPoint];
}

#pragma mark -
#pragma mark - Private methods

- (void)setupAlbumButton {
    if ([_delegate respondsToSelector:@selector(cameraShouldShowGalleryPicker)]) {
        _albumButton.hidden = ![_delegate cameraShouldShowGalleryPicker];
    }
    
    [_albumButton.layer setCornerRadius:10.f];
    [_albumButton.layer setMasksToBounds:YES];
}

- (void)deviceOrientationDidChangeNotification {
    [self orientationDevice:[UIDevice.currentDevice orientation]];
}

-(void)deviceOrientationChange:(UIDeviceOrientation)orientation{
    self.deviceOrientation = orientation;
    [self orientationDevice:orientation];
}

-(void)orientationDevice:(UIDeviceOrientation)orientation{
    NSInteger degress;
    
    switch (orientation) {
        case UIDeviceOrientationFaceUp:
        case UIDeviceOrientationPortrait:
        case UIDeviceOrientationUnknown:
            degress = 0;
            [self portraitView];
            break;
            
        case UIDeviceOrientationLandscapeLeft:
            degress = 90;
            [self landscapeView];
            break;
            
        case UIDeviceOrientationFaceDown:
        case UIDeviceOrientationPortraitUpsideDown:
            degress = 180;
            [self portraitView];
            break;
            
        case UIDeviceOrientationLandscapeRight:
            degress = 270;
            [self landscapeView];
            break;
    }
    
    CGFloat radians = degress * M_PI / 180;
    CGAffineTransform transform = CGAffineTransformMakeRotation(radians);
    
    [UIView animateWithDuration:.5f animations:^{
        //_gridButton.transform =
        //_toggleButton.transform =
        _albumButton.transform = transform;
        //_flashButton.transform = transform;
    }];
}


-(void)landscapeView
{
    if (!_landscapeViewMode) {
        _landscapeViewMode = YES;
        
        [UIView animateWithDuration:0.3 animations:^{
            _actionsView.alpha = 0;
            _topView.alpha = 0;
            
        } completion: ^(BOOL finished) {
            _actionsView.hidden = finished - 0.2;
            _topView.hidden = finished - 0.2;
            
            _topLeftViewTopConstraint.constant = 0;
            _topRightViewTopConstraint.constant = 0;
            _bottomRightBottomConstraint.constant = 0;
            _bottomLeftBottomConstraint.constant = 0;
            
        }];
    }
}

-(void)portraitView
{
    if (_landscapeViewMode) {
        _landscapeViewMode = NO;
        
        _actionsView.alpha = 0;
        _actionsView.hidden = NO;
        
        _topView.alpha = 0;
        _topView.hidden = NO;
        
        [UIView animateWithDuration:0.3 animations:^{
            _actionsView.alpha = 0.8;
            _topView.alpha = 0.8;
            
            _topLeftViewTopConstraint.constant = 50;
            _topRightViewTopConstraint.constant = 50;
            _bottomRightBottomConstraint.constant = 60;
            _bottomLeftBottomConstraint.constant = 60;
        }];
    }
}

-(void)latestPhoto
{
    dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
        
        // get the latest image from the album
        ALAuthorizationStatus status = [ALAssetsLibrary authorizationStatus];
        if (status != ALAuthorizationStatusDenied) {
            TGAssetsLibrary *library = [TGAssetsLibrary defaultAssetsLibrary];
            
            __weak __typeof(self)wSelf = self;
            [library latestPhotoWithCompletion:^(UIImage *photo) {
                dispatch_async(dispatch_get_main_queue(), ^(void){
                    
                    wSelf.albumButton.disableTint = YES;
                    [[wSelf.albumButton imageView] setContentMode: UIViewContentModeScaleAspectFill];
                    [wSelf.albumButton setImage:photo forState:UIControlStateNormal];
                    
                });
            }];
        }
    });
}

- (AVCaptureVideoOrientation)videoOrientationForDeviceOrientation:(UIDeviceOrientation)deviceOrientation {
    AVCaptureVideoOrientation result = (AVCaptureVideoOrientation) deviceOrientation;
    
    switch (deviceOrientation) {
        case UIDeviceOrientationLandscapeLeft:
            result = AVCaptureVideoOrientationLandscapeRight;
            break;
            
        case UIDeviceOrientationLandscapeRight:
            result = AVCaptureVideoOrientationLandscapeLeft;
            break;
            
        default:
            break;
    }
    
    return result;
}

- (void)viewWillDisappearWithCompletion:(void (^)(void))completion {
    _actionsView.hidden = YES;
    
    [TGCameraSlideView showSlideUpView:_slideUpView slideDownView:_slideDownView atView:_captureView completion:^{
        completion();
    }];
}


@end
