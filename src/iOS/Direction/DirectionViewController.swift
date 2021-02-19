//
//  DirectionViewController.swift
//  Go Map!!
//
//  Created by Wolfgang Timme on 4/2/19.
//  Copyright © 2019 Bryce. All rights reserved.
//

import UIKit

@objc class DirectionViewController: UIViewController {
    
    // MARK: Private properties
    
    @IBOutlet weak var cancelButton: UIButton!
    
    // MARK: Initializer
    
    @objc init() {
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
