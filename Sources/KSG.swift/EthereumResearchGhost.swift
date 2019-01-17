import Foundation

class EthereumResearchGhost: Ghost {

    let NODE_COUNT = 131072
    let balances = Array(repeating: 1, count: 131072)
    var latestMessage = Array(repeating: Data(repeating: 0, count: 32), count: 131072)
    let maxKnownHeight = [0]
    var children = [Data:[Data]]()

    var blocks = [Data:(Int, Data)]()

    var logz = [Int]()

    init() {
        for i in 2...1000 {
            logz[i] = logz[i / 2] + 1
        }
    }

    func head() -> Data {
        var latestVotes = [Data:Int]()
        for (i, balance) in balances.enumerated() {
            latestVotes[latestMessage[i]] = (latestVotes[latestMessage[i]] ?? 0) + balance
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
                if step > 0 {
                    continue
                } else if c.count == 1 {
                    head = c[0]
                } else {
                    // @todo
                }
            }
        }

        return head
    }

    private func powerOfTwo(below: Int) -> Int {
        return 2^logz[below]
    }

    private func height(_ block: Data) -> Int {
        return (blocks[block]?.0)!
    }

    private func addAttestation(block: Data, validatorIndex: Int) {
        latestMessage[validatorIndex] = block
    }

    private func ancestor(block: Data, height: Int) -> Data {
        // @todo
    }

    private func clearWinner(latestVotes: [Data:Int], height: Int) -> Data? {
        var atHeight = [Data:Int]()
        let totalVoteCount = 0

        for (k, v) in latestVotes {
            let ancestor = self.ancestor(block: k, height: height)
            atHeight[ancestor] = (atHeight[ancestor] ?? 0) + v
            // @todo figure out next part
        }

        for (k, v) in atHeight {
            if v >= totalVoteCount / 2 {
                return k
            }
        }

        return nil
    }
}
