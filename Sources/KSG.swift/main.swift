import Foundation

let g = EthereumResearchGhost()

let startTime = CFAbsoluteTimeGetCurrent()
var phead: Data = Data(capacity: 32)
for i in stride(from: 0, to: 131072, by: 1024) {
    let head = g.head()
    for _ in stride(from: i, to: i + g.NODE_COUNT, by: 1) {
        phead = g.getPerturbedHead(h: head)
        g.addAttestations(block: phead, v: Int(fmod(Double(i), Double(g.NODE_COUNT))))
    }

    let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
    print(
        NSString(
            format: "Adding new block on top of block %d, Time: %.5f",
            (g.blocks[phead.hashValue]?.0 ?? 0),
            timeElapsed
        )
    )

    g.addBlock(parent: phead)
}
