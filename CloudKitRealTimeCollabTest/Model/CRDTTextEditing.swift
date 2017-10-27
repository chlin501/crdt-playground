//
//  CRDTTextEditing.swift
//  CloudKitRealTimeCollabTest
//
//  Created by Alexei Baboulevitch on 2017-10-27.
//  Copyright © 2017 Alexei Baboulevitch. All rights reserved.
//

import Foundation

final class CRDTTextEditing: CvRDT, ApproxSizeable, NSCopying
{
    private var ct: CausalTreeString
    private var cursorMap: CRDTMap<CausalTreeString.SiteUUIDT, AtomId, CausalTreeString.SiteUUIDT>

    // starting from scratch
    public init(site: CausalTreeString.SiteUUIDT)
    {
        self.ct = CausalTreeString(site: site, clock: 0)
        self.cursorMap = CRDTMap(withOwner: site)
    }
    
    public func copy(with zone: NSZone? = nil) -> Any
    {
        let returnCopy = CRDTTextEditing(site: self.ct.ownerUUID())
        
        returnCopy.ct = ct.copy() as! CausalTreeString
        returnCopy.cursorMap = cursorMap.copy() as! CRDTMap
        
        return returnCopy
    }
    
    public func updateCursor(to atomId: AtomId)
    {
        cursorMap.setValue(atomId)
    }
    
    public func transferToNewOwner(withUUID uuid: CausalTreeString.SiteUUIDT) -> ([SiteId:SiteId])
    {
        let remap = ct.transferToNewOwner(withUUID: uuid)

        for pair in cursorMap.map
        {
            if let newSite = remap[pair.value.value.site]
            {
                cursorMap.setValue(AtomId(site: newSite, index: pair.value.value.index), forKey: pair.key, updatingId: false)
            }
        }

        return remap
    }
    
    // WARNING: the inout CRDT will be mutated, so make absolutely sure it's a copy you're willing to waste!
    public func integrate(_ v: inout CRDTTextEditing)
    {
        let remaps = ct.integrateReturningSiteIdRemaps(&v.ct)
        
        for pair in cursorMap.map
        {
            if let newSite = remaps.localRemap[pair.value.value.site]
            {
                cursorMap.setValue(AtomId(site: newSite, index: pair.value.value.index), forKey: pair.key, updatingId: false)
            }
        }
        
        for pair in v.cursorMap.map
        {
            if let newSite = remaps.remoteRemap[pair.value.value.site]
            {
                v.cursorMap.setValue(AtomId(site: newSite, index: pair.value.value.index), forKey: pair.key, updatingId: false)
            }
        }
        
        cursorMap.integrate(&v.cursorMap)
    }
    
    public func superset(_ v: inout CRDTTextEditing) -> Bool
    {
        return ct.superset(&v.ct) && cursorMap.superset(&v.cursorMap)
    }
    
    public func validate() throws -> Bool
    {
        return try ct.validate() && cursorMap.validate()
    }
    
    public func sizeInBytes() -> Int
    {
        return ct.sizeInBytes() + cursorMap.sizeInBytes()
    }
    
    public static func ==(lhs: CRDTTextEditing, rhs: CRDTTextEditing) -> Bool
    {
        return lhs.ct == rhs.ct && lhs.cursorMap == rhs.cursorMap
    }

    public var hashValue: Int
    {
        return ct.hashValue ^ cursorMap.hashValue
    }
}