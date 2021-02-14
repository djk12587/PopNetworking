//
//  ViewController.swift
//  howToUse
//
//  Created by Dan Koza on 2/14/21.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        addInstructionLabel()

        API.Jokes.Routes.GetJoke().request { result in
            switch result {
                case .success(let joke):
                    print(joke)
                case .failure(let error):
                    print(error)
            }
        }

        API.Jokes.Routes.GetTenJokes().request { result in
            switch result {
                case .success(let jokes):
                    print(jokes)
                case .failure(let error):
                    print(error)
            }
        }

        API.PetFinder.Routes.GetAnimals(animalType: .bird).request { result in
            switch result {
                case .success(let birds):
                    print(birds)
                case .failure(let error):
                    print(error)
            }
        }

        API.PetFinder.Routes.GetAnimal(animalId: 50548438).request { result in
            switch result {
                case .success(let animal):
                    print(animal)
                case .failure(let error):
                    print(error)
            }
        }
    }

    private func addInstructionLabel() {
        view.backgroundColor = .white

        let label = UILabel()
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.text = "Nothing to see here. Look at your debug console for request responses!"
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
        ])
    }
}
