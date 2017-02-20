//
//  PlaylistViewCell.swift
//  PlaylistAll
//
//  Created by Terrence Park on 1/14/17.
//  Copyright © 2017 Terrence Park. All rights reserved.
//

import UIKit

class PlaylistViewCell: UITableViewCell {
    
    @IBOutlet weak var playlistArtImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
