//
//  TOCropWidgetSizeHelper.h
//  ScriptWidget
//
//  Created by everettjf on 2020/11/9.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN


@interface TOCropWidgetSize : NSObject

@property (nonatomic, assign) CGSize small;
@property (nonatomic, assign) CGSize medium;
@property (nonatomic, assign) CGSize large;

@end

@interface TOCropWidgetSizeHelper : NSObject

@property (nonatomic, strong) TOCropWidgetSize *prop;

+ (instancetype)shared;

@end

@interface WidgetSizeHelper : NSObject

+ (CGSize)small;
+ (CGSize)medium;
+ (CGSize)large;

+ (CGSize)size:(int)type;

@end

NS_ASSUME_NONNULL_END
