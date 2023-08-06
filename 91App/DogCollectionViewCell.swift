//
//  DogCollectionViewCell.swift
//  91App
//
//  Created by 林祔利 on 2023/7/31.
//

import UIKit

class DogCollectionViewCell: UICollectionViewCell {
    
    let storePhoto = UIImageView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        // 將 storePhoto 添加到 Cell 上
        contentView.addSubview(storePhoto)
        storePhoto.translatesAutoresizingMaskIntoConstraints = false
        
        // 設置 Auto Layout 約束
        NSLayoutConstraint.activate([
            storePhoto.topAnchor.constraint(equalTo: contentView.topAnchor),
            storePhoto.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            storePhoto.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            storePhoto.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
