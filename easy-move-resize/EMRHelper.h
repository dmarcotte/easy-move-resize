//
//  EMRHelper.h
//  easy-move-resize
//
//  Created by Sven A. Schmidt on 10/06/2018.
//  Copyright © 2018 Daniel Marcotte. All rights reserved.
//

#ifndef EMRHelper_h
#define EMRHelper_h

#import <Foundation/Foundation.h>


typedef enum : NSUInteger {
    equal,
    wider,
    smaller,
    disjoint
} MaskComparison;


MaskComparison compareMasks(int mask1, int mask2);


#endif /* EMRHelper_h */
