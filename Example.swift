//
//  BonjourServiceBrowser.swift
//  Remote Bridge
//
//  Created by Jerry Seigle on 6/27/23.
//

import Foundation
import Network

class Zeroconf: NSObject, NetServiceBrowserDelegate, NetServiceDelegate {
    
    // MARK: - Properties
    
    var browser: NetServiceBrowser!
    var resolvingServices: [String: NetService] = [:]
    var publishedServices: [String: NetService] = [:]
    
    // MARK: - Initialization
    
    override init() {
        resolvingServices = [:]
        publishedServices = [:]
        browser = NetServiceBrowser()
        super.init()
        browser.delegate = self
    }
    
    // MARK: - Public Methods
    
    func scan(_ type: String, domain: String) {
        print("Starting scan")
        stop()
        browser.searchForServices(ofType: "\(type)", inDomain: domain)
    }
    
    func stop() {
        browser.stop()
        resolvingServices.removeAll()
    }
    
    func registerService(type: String, domain: String, name: String, port: Int32, txt: [String : Data]) {
        let svc = NetService(domain: domain as String, type: type, name: name as String, port: port)
        svc.delegate = self
        svc.schedule(in: RunLoop.current, forMode: .default)
        
        // Todo: Add txt data
        
        svc.publish()
        self.publishedServices[svc.name] = svc
        NSLog("Zeroconf: Publish called")
    }
    
    func unregisterService(_ serviceName: String) {
        if let svc = publishedServices[serviceName] {
            svc.stop()
        }
    }
    
    // MARK: - NetServiceBrowserDelegate
    
    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        print("Zeroconf: Found some services - \(service)")
        
        let serviceInfo = serializeService(toDictionary: service, resolved: false)
        // Handle the data. This is where the host name, port, etc. are located.
        // You can set a variable, return the data, or run your task that requires the network service IP and port number.
        print("Zeroconf: Found some services - \(service)")
        resolvingServices[service.name] = service
        service.delegate = self
        service.resolve(withTimeout: 5.0)
    }
    
    func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        let serviceInfo = serializeService(toDictionary: service, resolved: false)
        // Handle whatever you need when a service is removed from the network.
    }
    
    func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String : NSNumber]) {
        reportError(errorDict)
    }
    
    func netServiceBrowserDidStopSearch(_ browser: NetServiceBrowser) {
        // Handle when a service search is stopped.
    }
    
    func netServiceBrowserWillSearch(_ browser: NetServiceBrowser) {
        // Handle when we will search. This is not the same thing as searching, but it's like preparing to search.
    }
    
    // MARK: - NetServiceDelegate
    
    func netServiceDidResolveAddress(_ sender: NetService) {
        let serviceInfo = serializeService(toDictionary: sender, resolved: true)
        // Handle resolved. If you are not sure what this does, just print the variable.
        
        sender.delegate = nil
        resolvingServices.removeValue(forKey: sender.name)
    }
    
    func netService(_ sender: NetService, didNotResolve errorDict: [String : NSNumber]) {
        reportError(errorDict)
        
        sender.delegate = nil
        resolvingServices.removeValue(forKey: sender.name)
    }
    
    func netServiceWillPublish(_ sender: NetService) {
        NSLog("Zeroconf: netServiceWillPublish")
    }
    
    func netServiceDidPublish(_ sender: NetService) {
        NSLog("Zeroconf: netServiceDidPublish")
        let serviceInfo = serializeService(toDictionary: sender, resolved: true)
        
        publishedServices[sender.name] = sender
    }
    
    func netService(_ sender: NetService, didNotPublish errorDict: [String : NSNumber]) {
        NSLog("Zeroconf: netServiceDidNotPublish")
        reportError(errorDict)
        sender.delegate = nil
        publishedServices.removeValue(forKey: sender.name)
    }
    
    func netServiceDidStop(_ sender: NetService) {
        sender.delegate = nil
        publishedServices.removeValue(forKey: sender.name)
        
        let serviceInfo = serializeService(toDictionary: sender, resolved: true)
    }
    
    // MARK: - Private Methods
    
    private func serializeService(toDictionary service: NetService, resolved: Bool) -> [String: Any] {
        var serviceInfo: [String: Any] = [:]
        serviceInfo["name"] = service.name
        serviceInfo["host"] = service.hostName
        serviceInfo["port"] = service.port
        serviceInfo["addresses"] = addressesFromService(service)
        return serviceInfo
    }
    
    func addressesFromService(_ service: NetService) -> [String] {
        var addresses = [String]()
        
        // Source: http://stackoverflow.com/a/4976808/2715
        var addressBuffer = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
        
        for data in service.addresses ?? [] {
            memset(&addressBuffer, 0, Int(INET6_ADDRSTRLEN))
            
            typealias IPSocketAddress = (
                sa: sockaddr,
                ipv4: sockaddr_in,
                ipv6: sockaddr_in6
            )
            
            var socketAddress = data.withUnsafeBytes { (pointer: UnsafePointer<IPSocketAddress>) -> IPSocketAddress in
                return pointer.pointee
            }
            
            if socketAddress.sa.sa_family == sa_family_t(AF_INET) || socketAddress.sa.sa_family == sa_family_t(AF_INET6) {
                let addressStr = socketAddress.sa.sa_family == sa_family_t(AF_INET)
                    ? inet_ntop(AF_INET, &(socketAddress.ipv4.sin_addr), &addressBuffer, socklen_t(INET6_ADDRSTRLEN))
                    : inet_ntop(AF_INET6, &(socketAddress.ipv6.sin6_addr), &addressBuffer, socklen_t(INET6_ADDRSTRLEN))
                
                if let addressStr = addressStr, let address = String(utf8String: addressStr) {
                    addresses.append(address)
                }
            }
        }
        
        return addresses
    }
    
    func reportError(_ errorDict: [AnyHashable: Any]) {
        // Handle errors here.
        NSLog("\(errorDict)")
    }
}
