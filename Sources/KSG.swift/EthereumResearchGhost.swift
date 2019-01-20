import Foundation

class EthereumResearchGhost: Ghost {

    let NODE_COUNT = 131072
    let LATENCY_FACTOR = 0.5
    let balances = Array(repeating: 1.0, count: 131072)
    var latestMessage = Array(repeating: Data(repeating: 0, count: 32), count: 131072)
    var maxKnownHeight = [0]
    var children = [Data: [Data]]()

    var blocks = [Int: (Int, Data)]()

    var logz = [0, 0]

    var cache = [Data: Data]()
    var heightToBytes = [Data]()
    var ancestors = [[Int: Data]]()

    init() {

        blocks[(Data(capacity: 32)).hashValue] = (0, Data(capacity: 0))

        for _ in 0..<16 {
            ancestors.append([Data(capacity: 32).hashValue: Data(capacity: 32)])
        }

        for i in 0..<10000 {
            var num = i
            heightToBytes.append(Data(bytes: &num, count: MemoryLayout<Int>.size))
        }

        for i in 2..<10000 {
            logz.append(logz[i / 2] + 1)
        }
    }

    func head() -> Data {

        var latestVotes = [Data: Double]()

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

            var step = Int(floor(Double(powerOfTwo(below: maxKnownHeight[0] - height)) / 2.0))
            while step > 0 {
                if let possibleClearWinner = clearWinner(
                    latestVotes: latestVotes,
                    height: height - Int(fmod(Double(height), Double(step))) + step
                ) {
                    head = possibleClearWinner
                    break
                }

                let d = Double(step) / 2.0
                step = Int(floor(d))
            }

            if step > 0 {
                continue
            } else if c.count == 1 {
                head = c[0]
            } else {
                var childVotes = [Data: Double]()
                for x in c {
                    childVotes[x] = 0.01
                }

                for (k, v) in latestVotes {
                    if let child = ancestor(block: k, height: height + 1) {
                        childVotes[child] = (childVotes[child] ?? 0) + v
                    }
                }

                head = bestChild(votes: childVotes)!
            }

            height = self.height(head)
            let votes = latestVotes
            for (k, _) in votes {
                if ancestor(block: k, height: height) != head {
                    latestVotes.removeValue(forKey: k)
                }
            }
        }
    }

    private func powerOfTwo(below: Int) -> Int {
        return 2^logz[below]
    }

    private func height(_ block: Data) -> Int {
        if let b = blocks[block.hashValue] {
            return b.0
        }

        return 0
    }

    private func addAttestation(block: Data, validatorIndex: Int) {
        latestMessage[validatorIndex] = block
    }

    private func clearWinner(latestVotes: [Data: Double], height: Int) -> Data? {
        var atHeight = [Data: Double]()
        var totalVoteCount = 0.0

        for (k, v) in latestVotes {
            if let ancestor = self.ancestor(block: k, height: height) {
                atHeight[ancestor] = (atHeight[ancestor] ?? 0.0) + v
                totalVoteCount += v
            }

        }

        for (k, v) in atHeight {
            if totalVoteCount == 0.0 {
                return k
            }

            if v >= floor(totalVoteCount / 2.0) {
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
        if let h = blocks[block.hashValue]?.0 {
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

            let o = ancestor(block: ancestors[logz[h - height - 1]][block.hashValue]!, height: height)
            cache[cachekey] = o
            return o
        }

        return nil
    }

    func getPerturbedHead(h: Data) -> Data {
        var head = h
        var upcount = 0

        while height(head) > 0 && Double.random(in: 0.0...1.0) < LATENCY_FACTOR {
            head = blocks[head.hashValue]!.1
            upcount += 1
        }

        for _ in 0..<Int.random(in: 0..<(upcount + 1)) {
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
        var bytes = [UInt8](repeating: 0, count: 32)
        SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) // @todo check status

        let newHash = Data(bytes: bytes, count: bytes.count)

        let h = height(parent)

        blocks[newHash.hashValue] = (h+1, parent)
        if let _ = children[parent] {} else {
            children[parent] = [Data]()
        }

        children[parent]?.append(newHash)

        for i in 0..<16 {
            if fmod(Double(h), Double(2^i)) == 0 {
                ancestors.insert([newHash.hashValue: parent], at: i)
            } else {
                if let _ = ancestors[i][parent.hashValue] {
                } else {
                    ancestors[i][parent.hashValue] = Data(count: 32)
                }
                ancestors.insert([newHash.hashValue: ancestors[i][parent.hashValue]!], at: i)
            }
        }

        maxKnownHeight[0] = max(maxKnownHeight[0], h+1)
    }
}
