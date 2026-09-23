// Waits for test_node_server to answer on 8082, and prints its log if it
// never does. Node rather than a shell loop so every runner shell can use it.
const fs = require('fs');
const http = require('http');
const path = require('path');

let tries = 0;
(function probe() {
  http
    .get('http://127.0.0.1:8082', (res) => {
      res.resume();
      console.log('fixture server is up');
      process.exit(0);
    })
    .on('error', () => {
      if (++tries < 30) {
        setTimeout(probe, 1000);
        return;
      }
      console.log('fixture server did not come up');
      for (const name of ['node_server.log', 'node_server.err.log']) {
        const file = path.join(process.env.RUNNER_TEMP || '.', name);
        if (fs.existsSync(file)) process.stdout.write(fs.readFileSync(file));
      }
      process.exit(1);
    });
})();
