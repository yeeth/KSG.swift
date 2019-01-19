//
//  File.swift
//  KSG.swift
//
//  Created by Dean Eigenmann on 19.01.19.
//

import Foundation

class EFG {

    let NODE_COUNT = 10
    let balances = Array(repeating: 1.0, count: 10)
    var latestMessage = Array(repeating: Data(repeating: 0, count: 32), count: 10)
    var maxKnownHeight = [0]
    var children = [Data:[Data]]()

    var blocks = [Data:(Int, Data)]()

    var logz = [0, 0]

    var cache = [Data:Data]()
    var heightToBytes = [Data]()
    var ancestors = [[Data:Data]]()

    init() {

        blocks[Data(capacity: 4)] = (0, Data(capacity: 0))

        for _ in 0...16 {
            ancestors.append([Data(capacity: 32):Data(capacity: 32)])

        }

        for i in 0...100 {
            var num = i
            heightToBytes.append(Data(bytes: &num, count: MemoryLayout<Int>.size))
        }

        for i in 2...1000 {
            logz.append(logz[i / 2] + 1)
        }
    }

    func head() -> Data {

        var latestVotes = [Data:Double]()

        for (i, balance) in balances.enumerated() {
            latestVotes[latestMessage[i]] = (latestVotes[latestMessage[i]] ?? 0.0) + balance
        }

        var head = Data(repeating: 0, count: 32)

        var height = 0

        while true {
            let c = (children[head] ?? [Data]())
            if c.count == 0 {
                return head
            }

            var step = powerOfTwo(below: maxKnownHeight[0] - height) / 2
            while step > 0 {
                if let possibleClearWinner = clearWinner(latestVotes: latestVotes, height: height - (height % step) + step) {
                    head = possibleClearWinner
                    break
                }

                step /= 2
            }

            if step > 0 {
                continue
            } else if c.count == 1 {
                head = c[0]
            } else {
                var childVotes = [Data:Double]()
                for x in c {
                    childVotes[x] = 0.1
                }

                for (k, v) in latestVotes {
                    if let child = ancestor(block: k, height: height + 1) {
                        childVotes[child] = (childVotes[child] ?? 0) + v
                    }

                    head = bestChild(votes: childVotes)!
                }
            }

            height = self.height(head)
            let votes = latestVotes
            for (k, _) in votes {
                if ancestor(block: k, height: height) != head {
                    latestVotes.removeValue(forKey: k)
                }
            }
        }

        return head
    }

    private func powerOfTwo(below: Int) -> Int {
        return 2^logz[below]
    }

    private func height(_ block: Data) -> Int {
        if let b = blocks[block] {
            return b.0
        }

        return 0
    }

    private func addAttestation(block: Data, validatorIndex: Int) {
        latestMessage[validatorIndex] = block
    }

    private func clearWinner(latestVotes: [Data:Double], height: Int) -> Data? {
        var atHeight = [Data:Double]()
        var totalVoteCount = 0.0

        for (k, v) in latestVotes {
            if let ancestor = self.ancestor(block: k, height: height) {
                atHeight[ancestor] = (atHeight[ancestor] ?? 0.0) + v
                totalVoteCount += v
            }
        }

        for (k, v) in atHeight {
            if v >= Double(totalVoteCount / 2) {
                return k
            }
        }

        return nil
    }

    private func bestChild(votes: [Data: Double]) -> Data? {
        var bitmask = 0
        var b = 0

        for bit in stride(from: 255, to: -1, by: -1) {
            b = bit
            var zeroVotes = 0.0
            var oneVotes = 0.0
            var singleCandidate: Data?

            for (candidate, votesForCandidate) in votes {
                let candidateAsInt = candidate.withUnsafeBytes { (ptr: UnsafePointer<Int>) -> Int in
                    return ptr.pointee
                }

                if candidateAsInt >> (bit+1) != bitmask {
                    continue
                }

                if (candidateAsInt >> bit) % 2 == 0 {
                    zeroVotes += votesForCandidate
                } else {
                    oneVotes += votesForCandidate
                }

                if singleCandidate == nil {
                    singleCandidate = candidate
                    break // @todo I think we can do this
                }
            }

            bitmask = (bitmask * 2) + (oneVotes > zeroVotes ? 1 : 0)
            if singleCandidate != nil {
                return singleCandidate
            }
        }

        assert(b >= 1)
        return nil
    }

    private func ancestor(block: Data, height: Int) -> Data? {
        if let h = blocks[block]?.0 {
            if (height >= h) {
                if (height > h) {
                    return nil
                }

                return block
            }

            let cachekey = block + heightToBytes[height]
            if let data = cache[cachekey] {
                return data
            }

            let o = ancestor(block: ancestors[logz[h - height - 1]][block]!, height: height)
            cache[cachekey] = o
            return o
        }

        return nil
    }

    func getPerturbedHead(h: Data) -> Data {
        var head = h
        var upcount = 0

        var foo = 0
        while height(head) > 0 && foo < 10 {
            head = blocks[head]!.1
            upcount += 1
            foo += 1

        }


        for _ in 0...Int.random(in: 0..<10) {
            if let c = children[head] {
                if let sh = c.randomElement() {
                    head = sh
                }
            }
        }

        return head
    }

    func addAttestations(block: Data, v: Int) {
        latestMessage.insert(block, at: v)
    }

    func addBlock(parent: Data) {

        var keyData = Data(count: 32)

        var result = keyData.withUnsafeMutableBytes {
            SecRandomCopyBytes(kSecRandomDefault, 32, $0)
        }

        let newHash = Data(bytes: &result, count: MemoryLayout<Int>.size)
        let h = height(parent)
        blocks[newHash] = (h+1, parent)
        if let _ = children[parent] {
        } else {
            children[parent] = [Data]()
        }

        children[parent]?.append(newHash)
        for i in 0...16 {
            if h % (2^i) == 0 {
                ancestors.insert([newHash:parent], at: i)
            } else {
                ancestors.insert([newHash:ancestors[i][parent]!], at: i)
            }
        }

        maxKnownHeight[0] = max(maxKnownHeight[0], h+1)

    }
}


let g = EFG()

let startTime = CFAbsoluteTimeGetCurrent()
for i in stride(from: 0, to: g.NODE_COUNT, by: 1024) {
    let head = g.head()
    for _ in i...(i + g.NODE_COUNT) {
        let phead = g.getPerturbedHead(h: head)
        g.addAttestations(block: phead, v: i % g.NODE_COUNT)
        g.addBlock(parent: phead)

    }
}
