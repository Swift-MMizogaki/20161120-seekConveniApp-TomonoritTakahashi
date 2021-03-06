import UIKit
import MapKit
import CoreLocation

extension MKPlacemark {
    var address: String {
        let components = [self.administrativeArea, self.locality, self.thoroughfare, self.subThoroughfare]
        return components.flatMap { $0 }.joined(separator: "")
    }
}


// CLLocationManagerDelegateを継承しなければならない
class ViewController: UIViewController, UISearchBarDelegate,CLLocationManagerDelegate,MKMapViewDelegate {
    
    @IBOutlet weak var conveniMapView: MKMapView! = MKMapView() //マップ生成
    @IBOutlet weak var destSearchBar: UISearchBar! //検索バー
    
    @IBOutlet weak var trackingButton: UIBarButtonItem! // トラッキングのボタン
    
    @IBOutlet weak var userLocation: UITextField!
    
    
    // 現在地の位置情報の取得にはCLLocationManagerを使用
    var lm: CLLocationManager!
    
    // 取得した現在地の緯度を保持するインスタンス
    var userLatitude: CLLocationDegrees!
    // 取得した現在地の経度を保持するインスタンス
    var userLongitude: CLLocationDegrees!
    
    //任意のピンを刺した位置の緯度経度を保持するインスタンス
    var pinLatitude: CLLocationDegrees!
    var pinLongitude: CLLocationDegrees!

    //立てるピンのインスタンス
    
    //長押しで立てるピン
    var myPin: MKPointAnnotation!
    
    
    //ユーザーの現在地に立てるピン
    var userPin: MKPointAnnotation!

    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // フィールドの初期化
        lm = CLLocationManager()
        userLatitude = CLLocationDegrees()
        userLongitude = CLLocationDegrees()
        
        //立てたピンの緯度経度の初期化
        pinLatitude = CLLocationDegrees()
        pinLongitude = CLLocationDegrees()

        
        
        conveniMapView.frame = self.view.frame
        
        
        //デリゲート先に自分を設定する。
        conveniMapView.delegate = self
        
        // CLLocationManagerをDelegateに指定
        lm.delegate = self
        
        //サーチバーのデリゲートを自分に設定
        destSearchBar.delegate = self
        
        // 位置情報取得の許可を求めるメッセージの表示．必須．
        lm.requestWhenInUseAuthorization()
        // 位置情報の精度を指定．任意，
        lm.desiredAccuracy = kCLLocationAccuracyKilometer
        // 位置情報取得間隔を指定．指定した値（メートル）移動したら位置情報を更新する．任意．
        lm.distanceFilter = 1000.0
        
        
        // GPSの使用を開始する
        lm.startUpdatingLocation()
    
        //スケールを表示する
        conveniMapView.showsScale = true
        
        // 長押しのUIGestureRecognizerを生成.
        let myLongPress: UILongPressGestureRecognizer = UILongPressGestureRecognizer()
        myLongPress.addTarget(self, action: #selector(ViewController.recognizeLongPress(sender:)))
        
        // MapViewにUIGestureRecognizerを追加.
        conveniMapView.addGestureRecognizer(myLongPress)
        
    }
    
    
    
    /*
     長押しを感知した際に呼ばれるメソッド.
     */
    func recognizeLongPress(sender: UILongPressGestureRecognizer) {
        
        // 長押しの最中に何度もピンを生成しないようにする.
        if sender.state != UIGestureRecognizerState.began {
            return
        }
        
        // 長押しした地点の座標を取得.
        let location = sender.location(in: conveniMapView)
        
        // locationをCLLocationCoordinate2Dに変換.
        let myCoordinate: CLLocationCoordinate2D = conveniMapView.convert(location, toCoordinateFrom: conveniMapView)
        
        //長押しした地点＝ピンを刺す地点の緯度経度を変数に格納
        pinLatitude = myCoordinate.latitude
        pinLongitude = myCoordinate.longitude
        
        // ピンを生成.（長押し時のもの）
        myPin = MKPointAnnotation()
        
        // 座標を設定.
        myPin.coordinate = myCoordinate
        
        // タイトルを設定.
        myPin.title = "国名"
        
        // サブタイトルを設定.（緯度経度を表示）
        myPin.subtitle = "latitude: \(pinLatitude!) , longitude: \(pinLongitude!)"
        
         //MapViewにピンを追加.
        conveniMapView.addAnnotation(myPin)
        
        //ピンの情報を取得
        self.reverseGeocord(latitude: pinLatitude, longitude: pinLongitude, myPin: myPin)
    }
    
    /*
     addAnnotationした際に呼ばれるデリゲートメソッド.
     */
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        
        let myPinIdentifier = "PinAnnotationIdentifier"
        
        // ピンを生成.
        let myPinView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: myPinIdentifier)
        
        // アニメーションをつける.
        myPinView.animatesDrop = true
        
        // コールアウトを表示する.
        myPinView.canShowCallout = true
        
        myPinView.pinTintColor = UIColor.magenta
        
        // annotationを設定.
        myPinView.annotation = annotation
        
        return myPinView
        
    }
    
    /*
     * トラッキングボタンが押されたときのメソッド（トラッキングモード切り替え）
     */
    @IBAction func tapTrackingButton(_ sender: UIBarButtonItem) {
        switch conveniMapView.userTrackingMode{
        case .none:
            //noneからfollowへ
            conveniMapView.setUserTrackingMode(.follow, animated: true)
            //トラッキングボタンの画像を変更する
            trackingButton.image = UIImage(named: "trackingFollow")
            
        case .follow:
            //followからfollowWithHeadingへ
            conveniMapView.setUserTrackingMode(.followWithHeading, animated: true)
            //トラッキングボタンの画像を変更する
            trackingButton.image = UIImage(named: "trackingHeading")
            
        case .followWithHeading:
            //followWithHeadingからnoneへ
            conveniMapView.setUserTrackingMode(.none, animated: true)
            //トラッキングボタンの画像を変更する
            trackingButton.image = UIImage(named: "trackingNone")
        }
    }
    
    /*
     * トラッキングが自動解除されたとき
     */
    @objc(mapView:didChangeUserTrackingMode:animated:) func mapView (_ mapView :MKMapView, didChange mode:MKUserTrackingMode, animated:Bool){
        trackingButton.image = UIImage(named: "trackingNone")
    }
    
    //位置情報利用許可のステータスが変わった
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status{
        //ロケーションの更新を開始する
        case .authorizedAlways, .authorizedWhenInUse:
            lm.startUpdatingLocation()
            
            //トラッキングボタンを有効にする
            trackingButton.isEnabled = true
            
        default:
            
            //ロケーションの更新を停止する
            lm.stopUpdatingLocation()
            
            //トラッキングモードをnoneにする
            conveniMapView.setUserTrackingMode(.none, animated: true)
            
            // トラッキングボタンを変更する
            trackingButton.image = UIImage(named: "trackingNone")
            
            //トラッキングボタンを無効にする
            trackingButton.isEnabled = false
        }
    }
    
    /* 現在の位置情報取得成功時に実行される関数 */
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let newLocation = locations.last
        // 取得した緯度がnewLocation.coordinate.longitudeに格納されている
        userLatitude = newLocation!.coordinate.latitude
        // 取得した経度がnewLocation.coordinate.longitudeに格納されている
        userLongitude = newLocation!.coordinate.longitude
        
        let userLocation:CLLocationCoordinate2D  = CLLocationCoordinate2DMake(userLatitude,userLongitude)
        userPin = MKPointAnnotation()
        userPin.coordinate = userLocation
        
        conveniMapView.addAnnotation(userPin)
    
        // 取得した緯度・経度をLogに表示
        NSLog("latitude: \(userLatitude) , longitude: \(userLongitude)")
        // GPSの使用を停止する．停止しない限りGPSは実行され，指定間隔で更新され続ける．
        // lm.stopUpdatingLocation()
    }
    
    /* 位置情報取得失敗時に実行される関数 */
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // この例ではLogにErrorと表示するだけ．
        NSLog("Error")
    }
    
    
    /*
     * 座標から情報を呼び出す関数
     */
    func reverseGeocord (latitude:CLLocationDegrees , longitude:CLLocationDegrees, myPin:MKPointAnnotation){
        
        // geocoderを作成.
        let myGeocorder = CLGeocoder()
        
        // locationを作成.
        let myLocation = CLLocation(latitude: latitude, longitude: longitude)
        
        
        //逆ジオコーディングで座標から国名、住所、名称、郵便番号等を取得。
        myGeocorder.reverseGeocodeLocation(myLocation, completionHandler: { (placemarks, error) -> Void in
            
            for placemark in placemarks! {
                
                print("Name: \(placemark.name)")
                print("Country: \(placemark.country)")
                print("ISOcountryCode: \(placemark.isoCountryCode)")
                print("administrativeArea: \(placemark.administrativeArea)")
                print("subAdministrativeArea: \(placemark.subAdministrativeArea)")
                print("Locality: \(placemark.locality)")
                print("PostalCode: \(placemark.postalCode)")
                print("areaOfInterest: \(placemark.areasOfInterest)")
                print("Ocean: \(placemark.ocean)")
                
                // pinのタイトルとサブタイトルを国名と土地名称に変更する.
                
                
                //「?」でnilを許容…oceanとかがnilになりやすいので。
                    self.myPin?.title = "\(placemark.country!)"
                    self.myPin?.subtitle = "\(placemark.name!)"
                
                self.userLocation.text = "\(placemark.country!),\(placemark.name!)"
            }
        })

    }
    
    
    /*
     * コールアウトにボタンを表示するメソッド
     */
    func mapView(_ mapView: MKMapView, didAdd views: [MKAnnotationView]) {
        for view in views {
            view.rightCalloutAccessoryView = UIButton(type: UIButtonType.detailDisclosure)
        }
    }
    
    
    /*
     * コールアウトのボタンが押されたときのメソッド
     */
    func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
        
        
        // UIAlertControllerを作成する.
        let myAlert: UIAlertController = UIAlertController(title: "ピンの削除", message: "Delete this pin?", preferredStyle: .alert)
        
        // OKが押されたらピンを削除するアクションを作成.
        let myOkAction = UIAlertAction(title: "OK", style: .default) { action in
            mapView.removeAnnotation(view.annotation!)
        }
        
        //ピンの削除をキャンセルするアクションを作成.
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)

        
        // OK,cancelのActionを追加する.
        myAlert.addAction(myOkAction)
        myAlert.addAction(cancelAction)
        
        // UIAlertを発動する.
        present(myAlert, animated: true, completion: nil)

    }
    
}





