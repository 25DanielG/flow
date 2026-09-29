import AppKit

// prints get lost on pkill without this
setvbuf(stdout, nil, _IOLBF, 0)

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
