import UIKit

/**
 API from https://dog.ceo/dog-api/documentation/
 在 Network struct 裡實作串接上述網站的提供的狗品種資訊:
  - getBreedList  => 獲得狗品種列表
  - getSubBreedList => 查詢輸入的品種是否有衍生品種
  - getImageUrl => 輸入品種與衍生品種(可選)名稱取得隨機圖片連結
 */
struct Network {
    
    static func getBreedList(completion: @escaping(([String]) -> Void)) {
        let dogListUrl = URL(string: "https://dog.ceo/api/breeds/list/all")!
        URLSession.shared.dataTask(with: URLRequest(url: dogListUrl)) { data, res, err in
            if let data, let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let breedDict = raw["message"] as? [String: [String]] {
                    completion(Array(breedDict.keys))
                }
                completion([])
            }
        }.resume()
    }
    
    static func getSubBreedList(_ breed: String, completion: @escaping(([String]) -> Void)) {
        let subBreedListUrl = URL(string: "https://dog.ceo/api/breed/\(breed)/list")!
        URLSession.shared.dataTask(with: URLRequest(url: subBreedListUrl)) { data, res, error in
            if let data, let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let subBreedList = raw["message"] as? [String] {
                    completion(subBreedList)
                }
                completion([])
            }
        }.resume()
    }
    
    static func getImageUrl(breed: String, subBreed: String? = nil, completion: @escaping((URL?) -> Void)) {
        var subBreedPath = ""
        if let subBreed {
            subBreedPath = "/\(subBreed)"
        }
        let randomImageUrl = URL(string:"https://dog.ceo/api/breed/\(breed)\(subBreedPath)/images/random")!
        URLSession.shared.dataTask(with: URLRequest(url: randomImageUrl)) { data, res, error in
            if let data, let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let image = raw["message"] as? String, let url = URL(string: image) {
                    completion(url)
                }
                completion(nil)
            }
        }.resume()
    }
}

/**
 需求 1:
 從狗品種名稱列表裡隨機得到一個品種名稱後取得:
 a. 該品種的隨機圖片
 b. 該品種的所有衍生品種與隨機圖片
 用此品種名稱獲得含所有的衍生品種的隨機圖片連結，
 預期可能結果: print(randomBreedImages()) => ["hound": https://images.dog.ceo/breeds/hound-ibizan/n02091244_596.jpg]
 
 發現目前開發中的 function randomBreedImages() -> [String : URL] 無法滿足需求，
 請以修正錯誤、可維護性、可讀性為目標，嘗試調整並改善 randomBreedImages 的實作。
 */

func randomBreedImages(completion: @escaping ([[String: URL]]) -> Void) {
    var breeds: [[String: URL]] = []
    //創建 DispatchGroup 同步多個非同步任務
    let dispatchGroup = DispatchGroup()
    //進入一個任務
    dispatchGroup.enter()
    dispatchGroup.enter()
    
    Network.getBreedList { breedList in
        if let breed = breedList.randomElement() {
            do {
                try Network.getImageUrl(breed: breed) { url in

                    if let url {
                        breeds.append([breed : url])
                        print("breeds1:\(breeds)")
                        //加入完畢就直接離開任務
                        dispatchGroup.leave()
                    }
                }
            } catch {
                print("Error fetching image for breed \(breed): \(error)")
                //如果網路請求失敗就進去 catch 一樣直接離開任務
                dispatchGroup.leave()
            }
            
            
            Network.getSubBreedList(breed) { subList in
                for subBreed in subList {
                    let combinedBreed = breed + " " + subBreed
                    //這邊只要重複就不在請求網路
                    if !breeds.contains { $0.keys.first == combinedBreed } {
                        //在 for 裡面創建多個任務進入點
                        dispatchGroup.enter()
                        do {
                            try Network.getImageUrl(breed: breed, subBreed: subBreed) { url in
                                if let url {
                                    breeds.append([breed + " " + subBreed : url ])
                                    print("breeds2:\(breeds)")
                                    //每請求完畢就離開任務
                                    dispatchGroup.leave()
                                }
                            }
                        } catch {
                            print("Error fetching image for breed \(breed) and subBreed \(subBreed): \(error)")
                            dispatchGroup.leave()
                        }
                    }
                }
            }
        }
    }
    dispatchGroup.leave()
    dispatchGroup.wait()
    //等待都請求完畢後在收集全部的任務後執行
    dispatchGroup.notify(queue: .main) {
        completion(breeds)
        print("main \(breeds.count)")
        
    }
}


/**
 需求 2.
 開發搜尋狗品種功能，邊打字會即時呈現出與輸入內容相似的狗品種(不含衍生品種的)名稱與圖片，
 在 UISearchBarDelegate delegate methof 實作上述搜尋功能，
 功能上線後發現容易因為觸發頻繁的 API request & update UI with response，
 在網路環境不佳的情形下容易導致 UI 列表顯示與資料格式不一致，
 容易發生 app crash 進而影響使用者題驗，
 請以提升使用者題驗為目標嘗試改善 func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String)  實作流程。
  
 */

class SearchViewController: UIViewController, UISearchBarDelegate {
    var collectionView: UICollectionView! // NOTE: 顯示搜尋結果的 collection view
    var breedContent: [[String : URL]] = [] // NOTE: 作為 collectionView 的 data source
   
    var content: [[String: URL]] = [] // 多利用一個變數去存取網路請求的值，之後拿來search 部分做優化
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        randomBreedImages { [weak self] result in
            self?.breedContent = result
            self?.content = result
            DispatchQueue.main.async {
                self?.collectionView.reloadData()
            }
        }

        
        let searchBar = UISearchBar()
        searchBar.delegate = self
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(searchBar)
        searchBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10).isActive = true
        searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        searchBar.heightAnchor.constraint(equalToConstant: 44).isActive = true
        
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: 124, height: 124)
        layout.minimumLineSpacing = 1
        layout.estimatedItemSize = .zero
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        view.addSubview(collectionView)
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.register(DogCollectionViewCell.self, forCellWithReuseIdentifier: "DogCollectionViewCell")
        collectionView.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: 10).isActive = true
        collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        collectionView.heightAnchor.constraint(equalToConstant: view.bounds.height - searchBar.bounds.height).isActive = true
        
 
        
    }
    
    var searchWorkItem: DispatchWorkItem?
    let dispatchQueue = DispatchQueue(label: "searchQueue", qos: .userInitiated)
    
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        var searchContent: [[String: URL]] = []
        
        searchWorkItem?.cancel()
        
        if searchText.isEmpty {
            //進入 seachBar 後 讓一起同步存取值的變數，賦予給主要的變數 breedContent
            DispatchQueue.main.async {
                self.breedContent = self.content
                self.collectionView.reloadData()
            }
        }else{
            searchWorkItem = DispatchWorkItem { [weak self] in
                Network.getBreedList { breedList in
                    //利用 searchText 來過濾 寵物的列表
                    let filtered = breedList.filter { $0.lowercased().contains(searchText.lowercased()) }
                    for breedName in filtered {
                        // 取得到過濾後的列表向網路請求圖片
                        Network.getImageUrl(breed: breedName) { url in
                            if let url {
                                // 利用一個專門存取 search 結果的變數
                                searchContent.append([breedName : url])
                                DispatchQueue.main.async {
                                    self?.breedContent = []
                                    self?.breedContent = searchContent
                                    self?.collectionView.reloadData()
                                }
                            }
                        }
                    }
                }
            }
        }
        dispatchQueue.asyncAfter(deadline: .now() + 0.5, execute: searchWorkItem!)
    }
}

extension SearchViewController: UICollectionViewDelegate,UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return breedContent.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "\(DogCollectionViewCell.self)", for: indexPath) as! DogCollectionViewCell
        cell.storePhoto.image = UIImage(systemName: "photo")
        for (i, urlDict) in breedContent.enumerated() {
            if let url = urlDict.first?.value {
                URLSession.shared.dataTask(with: url) { data, _, error in
                    if let data = data, let image = UIImage(data: data) {
                        DispatchQueue.main.async {
                            //獲取指定索引路徑位置的 Cell
                            if let cell = collectionView.cellForItem(at: IndexPath(row: i, section: 0)) as? DogCollectionViewCell {
                                cell.storePhoto.image = image
                            }
                        }
                    } else {
                        if let error = error {
                            print("Error loading image at index \(i): \(error)")
                        }
                    }
                }.resume()
            }
        }

        return cell
    }
    
    
}
