//
//  MeasureDirectionViewModelTestCase.swift
//  GoMapTests
//
//  Created by Wolfgang Timme on 4/2/19.
//  Copyright © 2019 Bryce. All rights reserved.
//

import XCTest

@testable import Go_Map__
import CoreLocation

class MeasureDirectionViewModelTestCase: XCTestCase {
    
    private var viewModel: MeasureDirectionViewModel!
    private var headingProviderMock: HeadingProviderMock!
    private var delegateMock: MeasureDirectionViewModelDelegateMock!

    override func setUp() {
        super.setUp()
        
        headingProviderMock = HeadingProviderMock()
        viewModel = MeasureDirectionViewModel(headingProvider: headingProviderMock)
        
        delegateMock = MeasureDirectionViewModelDelegateMock()
        viewModel.delegate = delegateMock
    }

    override func tearDown() {
        viewModel = nil
        headingProviderMock = nil
        delegateMock = nil
        
        super.tearDown()
    }
    
    // MARK: Heading is not available
    
    func testValueLabelTextShouldIndicateThatHeadingIsNotAvailableWhenHeadingIsNotAvailable() {
        headingProviderMock.isHeadingAvailable = false
        
        // Re-create the view model, since it only asks for the `headingAvailble` during initialization.
        viewModel = MeasureDirectionViewModel(headingProvider: headingProviderMock)
        
        XCTAssertEqual(viewModel.valueLabelText.value, "🤷‍♂️")
    }
    
    func testOldValueLabelTextShouldIndicateThatHeadingIsNotAvailableWhenHeadingIsNotAvailable() {
        headingProviderMock.isHeadingAvailable = false
        
        // Re-create the view model, since it only asks for the `headingAvailble` during initialization.
        viewModel = MeasureDirectionViewModel(headingProvider: headingProviderMock)
        
        XCTAssertEqual(viewModel.oldValueLabelText.value,
                       "This device is not able to provide heading data.")
    }
    
    func testIsPrimaryActionButtonHiddenShouldBeTrueWhenHeadingIsNotAvailable() {
        headingProviderMock.isHeadingAvailable = false
        
        // Re-create the view model, since it only asks for the `headingAvailble` during initialization.
        viewModel = MeasureDirectionViewModel(headingProvider: headingProviderMock)
        
        XCTAssertTrue(viewModel.isPrimaryActionButtonHidden.value)
    }
    
    func testDismissButtonTitleShouldBeBackWhenHeadingIsNotAvailable() {
        headingProviderMock.isHeadingAvailable = false
        
        // Re-create the view model, since it only asks for the `headingAvailble` during initialization.
        viewModel = MeasureDirectionViewModel(headingProvider: headingProviderMock)
        
        XCTAssertEqual(viewModel.dismissButtonTitle.value, "Back")
    }
    
    // MARK: Heading is available
    
    func testValueLabelTextShouldInitiallyBeThreeDotsWhenHeadingIsAvailable() {
        headingProviderMock.isHeadingAvailable = true
        
        // Re-create the view model, since it only asks for the `headingAvailble` during initialization.
        viewModel = MeasureDirectionViewModel(headingProvider: headingProviderMock)
        
        XCTAssertEqual(viewModel.valueLabelText.value, "...")
    }
    
    func testPrimaryActionButtonShouldBeVisibleWhenHeadingIsAvailable() {
        headingProviderMock.isHeadingAvailable = true
        
        // Re-create the view model, since it only asks for the `headingAvailble` during initialization.
        viewModel = MeasureDirectionViewModel(headingProvider: headingProviderMock)
        
        XCTAssertFalse(viewModel.isPrimaryActionButtonHidden.value)
    }
    
    func testOldValueLabelTextShouldContainTheOldValueWhenItWasProvidedDuringInitialization() {
        let oldValue = "Lorem Ipsum"
        
        // Re-create the view model and pass the mocked old value.
        viewModel = MeasureDirectionViewModel(headingProvider: headingProviderMock, oldValue: oldValue)
        
        XCTAssertEqual(viewModel.oldValueLabelText.value, "Old value: \(oldValue)")
    }
    
    // MARK: Receiving heading updates
    
    func testValueLabelTextShouldBeTrueHeadingWhenHeadingProviderDidUpdateHeading() {
        let trueHeading: CLLocationDirection = 123.456789
        
        let heading = CLHeadingMock(trueHeading: trueHeading)
        headingProviderMock.delegate?.headingProviderDidUpdateHeading(heading)
        
        XCTAssertEqual(viewModel.valueLabelText.value, "123")
    }
    
    // MARK: viewDidAppear
    
    func testViewDidAppearShouldAskHeadingProviderToStartUpdatingHeading() {
        viewModel.viewDidAppear()
        
        XCTAssertTrue(headingProviderMock.startUpdatingHeadingCalled)
    }
    
    // MARK: viewDidDisappear
    
    func testViewDidDisappearShouldAskHeadingProviderToStartUpdatingHeading() {
        viewModel.viewDidDisappear()
        
        XCTAssertTrue(headingProviderMock.stopUpdatingHeadingCalled)
    }
    
    // MARK: didTapPrimaryActionButton
    
    func testDidTapPrimaryActionButtonShouldAskDelegateToDismiss() {
        viewModel.didTapPrimaryActionButton()
        
        XCTAssertTrue(delegateMock.dismissCalled)
    }
    
    func testDidTapPrimaryActionButtonShouldAskDelegateToDismissWithDirectionNilWhenNoHeadingUpdateWasReceivedYet() {
        viewModel.didTapPrimaryActionButton()
        
        XCTAssertNil(delegateMock.dismissDirection)
    }
    
    func testDidTapPrimaryActionButtonShouldAskDelegateToDismissWithDirectionWithoutDecimalsOfTheLastHeadingUpdate() {
        let firstHeading = CLHeadingMock(trueHeading: 123.456)
        headingProviderMock.delegate?.headingProviderDidUpdateHeading(firstHeading)
        
        let secondHeading = CLHeadingMock(trueHeading: 987.654)
        headingProviderMock.delegate?.headingProviderDidUpdateHeading(secondHeading)
        
        viewModel.didTapPrimaryActionButton()
        
        XCTAssertEqual(delegateMock.dismissDirection, "987")
    }

}