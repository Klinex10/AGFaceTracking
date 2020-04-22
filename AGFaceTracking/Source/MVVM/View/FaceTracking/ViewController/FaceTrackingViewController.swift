//
//  FaceTrackingViewController.swift
//  FaceTrackingTest
//
//  Created by Alexey Gross on 2020-04-18.
//  Copyright © 2020 Alexey Gross. All rights reserved.
//

import UIKit
import ARKit
import Combine

/// Enables to show the front camera live video to user with face tracking features
class FaceTrackingViewController: UIViewController {
    
    private var faceTrackingView: FaceTrackingView!
    private var viewModel: FaceTrackingViewModel
    private var faceNode: SCNNode?
    
    required init(viewModel: ViewModelProtocol) {
        
        guard let viewModel = viewModel as? FaceTrackingViewModel else {
            fatalError()
        }
        
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        faceTrackingView = FaceTrackingView(frame: UIScreen.main.bounds)
        view = faceTrackingView
    }
}

// MARK: - Life cycle
extension FaceTrackingViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        configureUI()
        bind(viewModel: viewModel)
        viewModel.fetchData()
        configureARSession()
    }
}

// MARK: - View protocol
extension FaceTrackingViewController: FaceTrackingViewProtocol {
    
    func bind(viewModel: ViewModelProtocol) {
        
        guard let viewModel = viewModel as? FaceTrackingViewModel else {
            fatalError()
        }
        
        viewModel.$modes.sink { newValue in
            self.faceTrackingView.modesView.collectionView.reloadData()
        }.cancel()
    }
}

// MARK: - Private methods
extension FaceTrackingViewController {
    
    private func configureUI() {
        
        DispatchQueue.main.async {
            self.navigationController?.setNavigationBarHidden(true, animated: true)
            
            self.faceTrackingView.modesView.collectionView.delegate = self
            self.faceTrackingView.modesView.collectionView.dataSource = self
            self.faceTrackingView.modesView.collectionView.register(FaceTrackingModeCell.self, forCellWithReuseIdentifier: "\(FaceTrackingModeCell.self)")
            
            self.faceTrackingView.sceneView.delegate = self
        }
    }
    
    private func configureARSession() {
        
        DispatchQueue.main.async {
            self.faceNode = nil
            self.viewModel.configureSession?.apply(to: self.faceTrackingView.sceneView)
                .sink(receiveCompletion: { completion in
                
                    switch completion {
                    case .failure(let error):
                        AlertHelper().showAlert(error: error, showIn: self)
                    case .finished:
                        break
                    }
                
                }, receiveValue: { _ in
                    print("AR session is configured")
                }).cancel()
        }
    }
}

// MARK: - UICollectionViewDataSource
extension FaceTrackingViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return viewModel.modes?.count ?? 0
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "\(FaceTrackingModeCell.self)", for: indexPath) as? FaceTrackingModeCell else {
            return FaceTrackingModeCell()
        }
        
        DispatchQueue.main.async {
            cell.update(with: self.viewModel.viewModelForCell(at: indexPath.row))
        }
        return cell
    }
}

// MARK: - UICollectionViewDelegate
extension FaceTrackingViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        guard let row = viewModel.currentFaceTrackingMode()?.index,
            let lastCell = collectionView.cellForItem(at: IndexPath(row: row, section: 0)) as? FaceTrackingModeCell,
            let newCell = collectionView.cellForItem(at: indexPath) as? FaceTrackingModeCell else { return }
            
        DispatchQueue.main.async {
            lastCell.update(with: self.viewModel.viewModelForCell(at: row).unselected())
            newCell.update(with: self.viewModel.viewModelForCell(at: indexPath.row).selected())
                
            if lastCell != newCell { self.configureARSession() }
        }
    }
}

// MARK: - SceneKit renderer
extension FaceTrackingViewController: ARSCNViewDelegate {
    
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        
        // TODO: to improve SceneKit renderer logic - watch the thread for nodes
        viewModel.processScene?.sceneKitNode(for: renderer, anchor: anchor, mode: viewModel.currentFaceTrackingMode())
            .sink(receiveCompletion: { completion in

                switch completion {
                case .failure(let error):
                    AlertHelper().showAlert(error: error, showIn: self)
                case .finished:
                    return
                }

            }, receiveValue: { node in
                self.faceNode = node
            }).cancel()
        
        return self.faceNode
    }
}
