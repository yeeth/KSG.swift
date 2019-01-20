import Foundation

let g = EthereumResearchGhost()

let startTime = CFAbsoluteTimeGetCurrent()
for i in stride(from: 0, to: 131072, by: 1024) {
    let head = g.head()
    var phead: Data = Data(capacity: 32)
    for _ in stride(from: i, to: i + 1024, by: 1) {
        let phead = g.getPerturbedHead(h: head)
        g.addAttestations(block: phead, v: i % g.NODE_COUNT)
    }

    let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
    print(
        NSString(
            format: "Adding new block on top of block %d, Time: %.5f",
            (g.blocks[phead]?.0 ?? 0),
            timeElapsed
        )
    )

    g.addBlock(parent: phead)
}
