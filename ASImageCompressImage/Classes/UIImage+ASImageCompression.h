//
//  MTImageCompressTool.h
//  AS
//
//  Created by AS on 2019/6/21.
//  Copyright © 2019 AS. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

typedef void(^ImageBlock)(NSData *imageData);

@interface UIImage (ASImageCompression)

/**
 内存处理，循环压缩处理，图片处理过程中内存不会爆增
 
 @param fImageKBytes 限制最终的文件大小
 */
- (NSData *)as_compressImageToData:(CGFloat)fImageKBytes;

- (void)as_resizeImage:(CGFloat)fImageKBytes imageBlock:(ImageBlock)block;

- (UIImage *)as_resizeImageWithNewSize:(CGSize)newSize;

@end

@interface NSData (ASImageCompression)

/**
 内存处理，循环压缩处理，图片处理过程中内存不会爆增
 
 @param fImageKBytes 限制最终的文件大小
 */
- (NSData *)as_compressImageToData:(CGFloat)fImageKBytes;

- (NSString *)as_dataMD5String;

@end
