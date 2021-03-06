//
//  MTImageCompressTool.m
//  AS
//
//  Created by AS on 2019/6/21.
//  Copyright © 2019 AS. All rights reserved.
//

#import "UIImage+ASImageCompression.h"
#import <CommonCrypto/CommonCrypto.h>

@implementation UIImage (ASImageCompression)

- (NSData *)as_compressImageToData:(CGFloat)fImageKBytes{
    NSData *imageData = UIImageJPEGRepresentation(self, 1.0);
    if (imageData == nil) {
        imageData = UIImagePNGRepresentation(self);
    }
    //二分法压缩图片
    CGFloat compression = 1;
    
    NSUInteger fImageBytes = fImageKBytes * 1000;//需要压缩的字节Byte，iOS系统内部的进制1000
    if (imageData.length <= fImageBytes){
        return imageData;
    }
    CGFloat max = 1;
    CGFloat min = 0;
    //指数二分处理，s首先计算最小值
    compression = pow(2, -6);

    imageData = UIImageJPEGRepresentation(self, compression);
    if (imageData.length < fImageBytes) {
        //二分最大10次，区间范围精度最大可达0.00097657；最大6次，精度可达0.015625
        for (int i = 0; i < 6; ++i) {
            @autoreleasepool {
                compression = (max + min) / 2;
                imageData = UIImageJPEGRepresentation(self, compression);
                //容错区间范围0.9～1.0
                if (imageData.length < fImageBytes * 0.9) {
                    min = compression;
                } else if (imageData.length > fImageBytes) {
                    max = compression;
                } else {
                    break;
                }
            }
        }
        return imageData;
    }
    
    // 对于图片太大上面的压缩比即使很小压缩出来的图片也是很大，不满足使用。
    //然后再一步绘制压缩处理
    UIImage *resultImage = [UIImage imageWithData:imageData];
    while (imageData.length > fImageBytes) {
        @autoreleasepool {
            CGFloat ratio = (CGFloat)fImageBytes / imageData.length;
            //使用NSUInteger不然由于精度问题，某些图片会有白边
            CGSize size = CGSizeMake((NSUInteger)(resultImage.size.width * sqrtf(ratio)),
                                     (NSUInteger)(resultImage.size.height * sqrtf(ratio)));
            resultImage = [self as_createImageForData:imageData maxPixelSize:MAX(size.width, size.height)];
            imageData = UIImageJPEGRepresentation(resultImage, compression);
        }
    }
    
    //   整理后的图片尽量不要用UIImageJPEGRepresentation方法转换，后面参数1.0并不表示的是原质量转换。
    return imageData;
}

- (void)as_resizeImage:(CGFloat)fImageKBytes imageBlock:(ImageBlock)block {
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        //二分法压缩图片
        CGFloat compression = 1;
        __block NSData *imageData = UIImageJPEGRepresentation(self, compression);
        NSUInteger fImageBytes = fImageKBytes*1000;
        if (imageData.length <= fImageBytes){
            block(imageData);
            return;
        }
        //获取原图片宽高比
        CGFloat sourceImageAspectRatio = self.size.width/self.size.height;
        //先调整分辨率
        CGSize defaultSize = CGSizeMake(1024, 1024/sourceImageAspectRatio);
        UIImage *newImage = [self as_createImageForData:imageData maxPixelSize:MAX((NSUInteger)defaultSize.width, (NSUInteger)defaultSize.height)];
        [UIImage as_halfFuntionImage:newImage maxSizeByte:fImageBytes back:^(NSData *halfImageData, CGFloat compress) {
            //再一步绘制压缩处理
            UIImage *resultImage = [UIImage imageWithData:halfImageData];
            imageData = halfImageData;
            while (imageData.length > fImageBytes) {
                CGFloat ratio = (CGFloat)fImageBytes / imageData.length;
                //使用NSUInteger不然由于精度问题，某些图片会有白边
                CGSize size = CGSizeMake((NSUInteger)(resultImage.size.width * sqrtf(ratio)),
                                         (NSUInteger)(resultImage.size.height * sqrtf(ratio)));
                resultImage = [self as_createImageForData:imageData maxPixelSize:MAX(size.width, size.height)];
                imageData = UIImageJPEGRepresentation(resultImage, compress);
            }
            //   整理后的图片尽量不要用UIImageJPEGRepresentation方法转换，后面参数1.0并不表示的是原质量转换。
            block(imageData);
        }];
    });
}


#pragma mark --------------二分法
+ (void)as_halfFuntionImage:(UIImage *)image maxSizeByte:(NSInteger)maxSizeByte back:(void(^)(NSData *halfImageData, CGFloat compress))block {
    //二分法压缩图片
    CGFloat compression = 1;
    NSData *imageData = UIImageJPEGRepresentation(image, compression);
    CGFloat max = 1;
    CGFloat min = 0;
    //指数二分处理，s首先计算最小值
    compression = pow(2, -6);
    imageData = UIImageJPEGRepresentation(image, compression);
    if (imageData.length < maxSizeByte) {
        //二分最大10次，区间范围精度最大可达0.00097657；最大6次，精度可达0.015625
        for (int i = 0; i < 6; i++) {
            compression = (max + min) / 2;
            imageData = UIImageJPEGRepresentation(image, compression);
            //容错区间范围0.9～1.0
            if (imageData.length < maxSizeByte * 0.9) {
                min = compression;
            } else if (imageData.length > maxSizeByte) {
                max = compression;
            } else {
                break;
            }
        }
    }
    if (block) {
        block(imageData, compression);
    }
}

- (UIImage *)as_createImageForData:(NSData *)data maxPixelSize:(NSUInteger)size {
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
    CGImageSourceRef source = CGImageSourceCreateWithDataProvider(provider, NULL);
    CGImageRef imageRef = CGImageSourceCreateThumbnailAtIndex(source, 0, (__bridge CFDictionaryRef) @{
                                                                                                      (NSString *)kCGImageSourceCreateThumbnailFromImageAlways : @YES,
                                                                                                      (NSString *)kCGImageSourceThumbnailMaxPixelSize : @(size),
                                                                                                      (NSString *)kCGImageSourceCreateThumbnailWithTransform : @YES,
                                                                                                      });
    CFRelease(source);
    CFRelease(provider);
    if (!imageRef) {
        return nil;
    }
    UIImage *toReturn = [UIImage imageWithCGImage:imageRef];
    CFRelease(imageRef);
    return toReturn;
}

- (UIImage *)as_resizeImageWithNewSize:(CGSize)newSize {
    UIImage *newImage;
    UIGraphicsBeginImageContext(newSize);
    [self drawInRect:CGRectMake(0, 0, newSize.width, newSize.height)];
    newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;
}

@end

@implementation NSData (ASImageCompression)

- (NSData *)as_compressImageToData:(CGFloat)fImageKBytes {
    return [[UIImage imageWithData:self] as_compressImageToData:fImageKBytes];
}

- (NSString *)as_dataMD5String {
    CC_MD5_CTX md5;
    CC_MD5_Init(&md5);
    CC_MD5_Update(&md5, self.bytes, (CC_LONG)self.length);
    unsigned char result[CC_MD5_DIGEST_LENGTH];
    CC_MD5_Final(result, &md5);
    NSMutableString *resultString = [NSMutableString string];
    for (int i = 0; i < CC_MD5_DIGEST_LENGTH; i++) {
        [resultString appendFormat:@"%02X", result[i]];
    }
    
    if (resultString.length == 32) {
        NSString *ret = [resultString substringWithRange:NSMakeRange(8, 16)];
        return ret;
    }
    
    return resultString;
}

@end

