import Foundation

class EthereumResearchGhost: Ghost {

    let NODE_COUNT = 131072
    let balances = Array(repeating: 1, count: 131072)
    let latestMessage = Array(repeating: Data(repeating: 0, count: 32), count: 131072)
    let maxKnownHeight = [0]
    var children = [Data:[Data]]()

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

            let step = powerOfTwo(below: maxKnownHeight[0] - height) / 2
            while step > 0 {

            }
        }

        return head
    }

    func powerOfTwo(below: Int) -> Int {
        return 2^logz[below]
    }
}
