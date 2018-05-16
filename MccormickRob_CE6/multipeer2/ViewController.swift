//  ViewController.swift
//  multipeer2
//  Created by Robert  McCormick on 20/01/2018.
//  Copyright © 2018 Robert  McCormick. All rights reserved.

import UIKit
import MultipeerConnectivity

class ViewController: UIViewController, MCBrowserViewControllerDelegate, MCSessionDelegate, UITextFieldDelegate {
    
    @IBOutlet weak var chatView: UITextView!
    @IBOutlet weak var inputField: UITextField!
    @IBOutlet weak var navItem: UINavigationItem!
    
    @IBOutlet weak var opponentNameLabel: UILabel!
    @IBOutlet weak var winLabel: UILabel!
    @IBOutlet weak var loseLabel: UILabel!
    @IBOutlet weak var tiesAgainstLabel: UILabel!
    @IBOutlet weak var timerLabel: UILabel!
    @IBOutlet weak var scissorsButton: UIButton!
    @IBOutlet weak var rockButton: UIButton!
    @IBOutlet weak var paperButton: UIButton!
    @IBOutlet weak var overlayView: UIView!
    
    var winCount = 0
    var loseCount = 0
    var tiesAgainstCount = 0
    var timer : Timer?
    var timerCount = 3
    //Some flags
    let beginFlag = "beginFlag"
    let scissorsFlag = "scissorsFlag"
    let rockFlag = "rockFlag"
    let paperFlag = "paperFlag"
    var currentChoice : String = ""
    var opponentChoice : String = ""
    var opponentName : String = ""
    
    
    
    var peerID:MCPeerID!   //our devices id or name as viewed by other browsing devices
    var browser:MCBrowserViewController!
    var advertiser:MCAdvertiserAssistant!
    var session:MCSession!
    
    let serviceID = "mdf2-game"
    var myConcurrentQueue : DispatchQueue!
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        peerID = MCPeerID(displayName: UIDevice.current.name)      
        session = MCSession(peer: peerID)
        session.delegate = self
        advertiser = MCAdvertiserAssistant(serviceType: serviceID, discoveryInfo: nil, session: session)
        advertiser.start()
        myConcurrentQueue = DispatchQueue(label: "myQueue", attributes: DispatchQueue.Attributes.concurrent)
    }
    
    
    
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    @IBAction func connectTap(_ sender: Any) {
        browser = MCBrowserViewController(serviceType: serviceID, session: session)
        browser.delegate = self
        
        self.present(browser, animated: true, completion:nil)
        
        //  browser.pressesCancelled(serviceID, with: session)
    }
    
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool{
        textField.resignFirstResponder()
        return true
    }
    
    func browserViewControllerDidFinish(_ browserViewController: MCBrowserViewController){
        browserViewController.dismiss(animated: true, completion: nil)
    }
    
    func browserViewControllerWasCancelled(_ browserViewController: MCBrowserViewController){
        browserViewController.dismiss(animated: true, completion: nil)
        // browserViewController.viewWillDisappear(animated)
        browserViewController.viewWillDisappear(true)
    }
    
    
    
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState){
        /*The whole callback happens in a background thread*/
        myConcurrentQueue.async {
            DispatchQueue.main.async {
                self.overlayView.isHidden = false
                
                if state == MCSessionState.connected{
                    if session.connectedPeers.count > 1 {
                        self.navItem.title = "Status: Connected to \(session.connectedPeers.count) peers"
                    }
                    else {
                        self.opponentName = peerID.displayName
                        self.navItem.title = "Status connected to: " + self.opponentName
                        self.resetControls()
                        self.overlayView.isHidden = true
                    }
                }
                else if state == MCSessionState.connecting{
                    self.navItem.title = "Status Connecting... "
                }
                else if state == MCSessionState.notConnected{
                    self.navItem.title = "Status Not Connected... "
                }
            }
        }
    }
    
    // Received data from remote peer.
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID){
        
        if let messageText:String = String(data: data, encoding: String.Encoding.utf8){
            DispatchQueue.main.async {
                if messageText == self.beginFlag {
                    self.startTimer()
                }else{
                    //Compare result
                    self.opponentChoice = messageText
                    if self.currentChoice != "" {
                        self.compareYourChoice()
                    }
                }
            }
        }
    }
    
    // Received a byte stream from remote peer.
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID){}
    // Start receiving a resource from remote peer.
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress){}
    // Finished receiving a resource from remote peer and saved the content
    // in a temporary location - the app is responsible for moving the file
    // to a permanent location within its sandbox.
    @available(iOS 7.0, *)
    public func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?){}
    
    //MARK: Game
    //Update game timer
    @objc func updateGameTimer(){
        timerCount -= 1
        timerLabel.text = "\(timerCount)"
        if timerCount == 0 {
            if let uTimer = timer {
                uTimer.invalidate()
                self.timer = nil
            }
            timerCount = 3
            
            //Compare
            compareYourChoice()
        }
    }
    func startTimer(){
        //Reset choice
        currentChoice = ""
        opponentChoice = ""
        resetButtons()
        
        timerCount = 3
        if (timer == nil) {
            timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(self.updateGameTimer), userInfo: nil, repeats: true)
        }else{
            timer?.fire()
        }
    }
    //Begin game with timer
    @IBAction func beginAction(_ sender: Any) {
        startTimer()
        
        self.sendDataWithFlag(flag: beginFlag)
    }
    
    func resetControls(){
        winCount = 0
        loseCount = 0
        tiesAgainstCount = 0
        
        opponentNameLabel.text = "You vs \(opponentName)"
        timerLabel.text = "3"
        
        updateLabels()
        
        resetButtons()
    }
    func resetButtons(){
        scissorsButton.layer.borderWidth = 1.0
        scissorsButton.layer.borderColor = UIColor.lightGray.cgColor
        rockButton.layer.borderWidth = 1.0
        rockButton.layer.borderColor = UIColor.lightGray.cgColor
        paperButton.layer.borderWidth = 1.0
        paperButton.layer.borderColor = UIColor.lightGray.cgColor
    }
    func updateLabels(){
        winLabel.text = "Win: \(winCount)"
        loseLabel.text = "Lose: \(loseCount)"
        tiesAgainstLabel.text = "Ties against: \(tiesAgainstCount)"
    }
    
    //Compare result
    func showAlert(title:String) {
        var yourChoiceValue = ""
        var opponentChoiceValue = ""
        switch currentChoice {
        case paperFlag:
            yourChoiceValue = "Paper"
        case rockFlag:
            yourChoiceValue = "Rock"
        case scissorsFlag:
            yourChoiceValue = "Scissors"
        default:
            opponentChoiceValue = ""
        }
        switch opponentChoice {
        case paperFlag:
            opponentChoiceValue = "Paper"
        case rockFlag:
            opponentChoiceValue = "Rock"
        case scissorsFlag:
            opponentChoiceValue = "Scissors"
        default:
            opponentChoiceValue = ""
        }
        let message = "You chose \(yourChoiceValue) and Your opponent choose \(opponentChoiceValue)"
        
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
        alert.addAction(okAction)
        
        present(alert, animated: true, completion: nil)
    }
    func winNotification(){
        winCount += 1
        
        updateLabels()
        
        self.showAlert(title: "You win!")
    }
    func loseNotification(){
        loseCount += 1
        
        updateLabels()
        
        self.showAlert(title: "You lose!")
    }
    func tiesAgainstNotification(){
        tiesAgainstCount += 1
        
        updateLabels()
        
        self.showAlert(title: "Please play again!")
    }
    
    func compareYourChoice(){
        if let uTimer = timer {
            uTimer.invalidate()
            self.timer = nil
        }
        
        if(currentChoice==opponentChoice) {
            //Ties against
            tiesAgainstNotification()
        }else{
            let temp : (String,String) = (currentChoice,opponentChoice)
            switch(temp) {
            case (scissorsFlag,rockFlag):
                //lose
                loseNotification()
                break
            case (scissorsFlag,paperFlag):
                //win
                winNotification()
                break
            case (rockFlag,scissorsFlag):
                //win
                winNotification()
                break
            case (rockFlag,paperFlag):
                //lose
                loseNotification()
                break
            case (paperFlag,scissorsFlag):
                //lose
                loseNotification()
                break
            case (paperFlag,rockFlag):
                //win
                winNotification()
                break
            case ("",_):
                //win
                loseNotification()
                break
            case (_,""):
                //win
                winNotification()
            default:
                break
            }
        }
    }
    
    @IBAction func rockAction(_ sender: Any) {
        if currentChoice == "" {
            resetButtons()
            rockButton.layer.borderColor = UIColor.orange.cgColor
            
            currentChoice = rockFlag
            sendDataWithFlag(flag: currentChoice)
            
            if opponentChoice != "" {
                compareYourChoice()
            }
        }
    }
    @IBAction func paperAction(_ sender: Any) {
        if currentChoice == "" {
            resetButtons()
            paperButton.layer.borderColor = UIColor.orange.cgColor
            
            currentChoice = paperFlag
            sendDataWithFlag(flag: currentChoice)
            
            if opponentChoice != ""
            {
                compareYourChoice()
            }
        }
    }
    @IBAction func scissoersAction(_ sender: Any) {
        if currentChoice == "" {
            resetButtons()
            scissorsButton.layer.borderColor = UIColor.orange.cgColor
            
            currentChoice = scissorsFlag
            sendDataWithFlag(flag: currentChoice)
            
            if opponentChoice != ""
            {
                compareYourChoice()
            }
        }
    }
    
    //Send data with flag: paper, rock...
    func sendDataWithFlag(flag:String) {
        if let encodedString = flag.data(using: String.Encoding.utf8) {
            do {
                try session.send(encodedString, toPeers: session.connectedPeers, with: MCSessionSendDataMode.reliable)
            }
            catch {
                print (" error: Send Data Failed")
            }
            
            print ("Sending Message \(flag) to \(session.connectedPeers.description)")
        }
    }
}

