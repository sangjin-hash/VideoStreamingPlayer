//
//  GestureType.swift
//  ToyVideoStreamingPlayer
//
//  Created by 이상진 on 12/5/25.
//

import Foundation
import CoreGraphics

enum GestureType {
    case horizontalSwipe(direction: SwipeDirection, distance: CGFloat)
    case verticalSwipe(side: ScreenSide, distance: CGFloat)
    case doubleTap(side: ScreenSide)
    case singleTap
}

enum SwipeDirection {
    case left   // 뒤로 (rewind)
    case right  // 앞으로 (forward)
}

enum ScreenSide {
    case left   // 왼쪽 (밝기)
    case right  // 오른쪽 (볼륨)
}
