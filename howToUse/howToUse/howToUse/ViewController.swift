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
        // Do any additional setup after loading the view.

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
}
