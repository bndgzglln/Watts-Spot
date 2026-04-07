//
//  AppIntent.swift
//  widget
//
//  Created by Bendegúz Gellén on 06.04.26.
//

import SwiftUI
import WidgetKit

@main
struct PriceWidgetBundle: WidgetBundle {
    var body: some Widget {
        CurrentPriceWidget()
    }
}
