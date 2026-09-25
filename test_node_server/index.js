// Example of the server https is taken from here: https://engineering.circle.com/https-authorized-certs-with-node-js-315e548354a2
// Renew certificates:
// - openssl x509 -req -extfile server.cnf -days 9999 -passin "pass:password" -in server-csr.pem -CA ca-crt.pem -CAkey ca-key.pem -CAcreateserial -out server-crt.pem
// - openssl x509 -req -extfile client1.cnf -days 9999 -passin "pass:password" -in client1-csr.pem -CA ca-crt.pem -CAkey ca-key.pem -CAcreateserial -out client1-crt.pem
// - openssl x509 -req -extfile client2.cnf -days 9999 -passin "pass:password" -in client2-csr.pem -CA ca-crt.pem -CAkey ca-key.pem -CAcreateserial -out client2-crt.pem
// Verify certificates:
// - openssl verify -CAfile ca-crt.pem server-crt.pem
// - openssl verify -CAfile ca-crt.pem client1-crt.pem
// - openssl verify -CAfile ca-crt.pem client2-crt.pem
// Conversion of client1-crt.pem to certificate.pfx: https://stackoverflow.com/a/38408666/4637638
// - openssl pkcs12 -export -out certificate.pfx -inkey client1-key.pem -in client1-crt.pem -certfile ca-crt.pem
// - Overwrite certificate.pfx to example/test_assets/certificate.pfx
const express = require('express');
const http = require('http');
const net = require('net');
const dgram = require('dgram');
const https = require('https');
const cors = require('cors');
const auth = require('basic-auth');
const app = express();
const appHttps = express();
const appAuthBasic = express();
const fs = require('fs')
const path = require('path')
const bodyParser = require('body-parser');
const multiparty = require('multiparty');

var options = {
  key: fs.readFileSync('server-key.pem'),
  cert: fs.readFileSync('server-crt.pem'),
  ca: fs.readFileSync('ca-crt.pem'),
  requestCert: true,
  rejectUnauthorized: false,
  ciphers: "DEFAULT:@SECLEVEL=0"
};

appHttps.get('/', (req, res) => {
  console.log(JSON.stringify(req.headers))
	const cert = req.connection.getPeerCertificate()

  // The `req.client.authorized` flag will be true if the certificate is valid and was issued by a CA we white-listed
  // earlier in `opts.ca`. We display the name of our user (CN = Common Name) and the name of the issuer, which is
  // `localhost`.

	if (req.client.authorized) {
		res.send(`
      <html>
        <head>
        </head>
        <body>
          <h1>Authorized</h1>
        </body>
      </html>
    `);
  // They can still provide a certificate which is not accepted by us. Unfortunately, the `cert` object will be an empty
  // object instead of `null` if there is no certificate at all, so we have to check for a known field rather than
  // truthiness.

	} else if (cert.subject) {
    console.log(`Sorry ${cert.subject.CN}, certificates from ${cert.issuer.CN} are not welcome here.`);
		res.status(403).send(`
      <html>
        <head>
        </head>
        <body>
          <h1>Forbidden</h1>
        </body>
      </html>
    `);
  // And last, they can come to us with no certificate at all:
	} else {
	  console.log(`Sorry, but you need to provide a client certificate to continue.`)
		res.status(401).send(`
      <html>
        <head>
        </head>
        <body>
          <h1>Unauthorized</h1>
        </body>
      </html>
    `);
	}
	res.end()
})

// Let's create our HTTPS server and we're ready to go.
https.createServer(options, appHttps).listen(4433)



// Ensure this is before any other middleware or routes
appAuthBasic.use((req, res, next) => {
  let user = auth(req)

  if (user === undefined || user['name'] !== 'USERNAME' || user['pass'] !== 'PASSWORD') {
    res.statusCode = 401
    res.setHeader('WWW-Authenticate', 'Basic realm="Node"')
    res.send(`
        <html>
          <head>
          </head>
          <body>
            <h1>Unauthorized</h1>
          </body>
        </html>
      `);
    res.end()
  } else {
    next()
  }
});

appAuthBasic.use(express.static(__dirname + '/public'));

appAuthBasic.get("/", (req, res) => {
  console.log(JSON.stringify(req.headers))
  res.send(`
    <html>
      <head>
      </head>
      <body>
        <h1>Authorized</h1>
      </body>
    </html>
  `);
  res.end()
});

appAuthBasic.get('/test-index', (req, res) => {
    res.sendFile(__dirname + '/public/test-index.html');
});

appAuthBasic.listen(8081);


app.use(cors());

app.use(bodyParser.urlencoded({extended: false}));
// Parse JSON bodies (as sent by API clients)
app.use(bodyParser.json());

app.use(express.static(__dirname + '/public'));

app.get("/", (req, res) => {
  console.log(JSON.stringify(req.headers))
  res.send(`
    <html>
      <head>
      </head>
      <body>
        <p>HELLO</p>
      </body>
    </html>
  `);
  res.end()
})

app.get("/echo-headers", (req, res) => {
  res.send(`
    <html>
      <head>
      </head>
      <body>
        <pre style="word-wrap: break-word; white-space: pre-wrap;">${JSON.stringify(req.headers)}</pre>
      </body>
    </html>
  `);
  res.end()
})

app.get('/test-index', (req, res) => {
    res.sendFile(__dirname + '/public/test-index.html');
})

app.post("/test-post", (req, res) => {
  console.log(JSON.stringify(req.headers))
  console.log(JSON.stringify(req.body))
  res.send(`
    <html>
      <head>
      </head>
      <body>
        <p>HELLO ${req.body.name}!</p>
      </body>
    </html>
  `);
  res.end()
})

app.post("/test-ajax-post", (req, res) => {
  console.log(JSON.stringify(req.headers));
  if (req.headers["content-type"].indexOf("multipart/form-data;") === 0) {
    const form = new multiparty.Form();
    form.parse(req, function(err, fields, files) {
      console.log(fields);
      res.set("Content-Type", "application/json")
      res.send(JSON.stringify({
        "firstname": fields.firstname[0],
        "lastname": fields.lastname[0],
      }));
      res.end();
    });
  } else {
    console.log(req.body);
    res.set("Content-Type", "application/json")
    res.send(JSON.stringify({
      "firstname": req.body.firstname,
      "lastname": req.body.lastname,
    }));
    res.end();
  }
})

app.get("/test-download-file", (req, res) => {
  console.log(JSON.stringify(req.headers))
  const filePath = path.join(__dirname, 'assets', 'flutter_logo.png');
  const stat = fs.statSync(filePath);
  const file = fs.readFileSync(filePath, 'binary');
  res.setHeader('Content-Length', stat.size);
  res.setHeader('Content-Type', 'image/png');
  res.setHeader('Content-Disposition', 'attachment; filename=flutter_logo.png');
  res.write(file, 'binary');
  res.end();
})

// What WebRTC sent where, for the WebRTC tests: every STUN binding request
// the STUN server below received, and what the proxies were asked to carry.
// A STUN request that did not come through a SOCKS UDP relay went out
// directly, around whatever proxy the WebView had.
let webrtcLog = { stun: [], socks: [], http: [] };
const socksRelayPorts = new Set();
app.get('/webrtc-log', (req, res) => res.json(webrtcLog));
app.get('/webrtc-log/reset', (req, res) => {
  webrtcLog = { stun: [], socks: [], http: [] };
  res.json(webrtcLog);
});

app.listen(8082)

// Proxy servers
// Two identical HTTP tunnelling proxies on different ports. Each answers every
// request with its own marker page rather than forwarding, so a test can tell
// *which* proxy served a load -- that is what makes per-WebView proxy binding
// observable: two WebViews pinned to different proxies must report different
// ids, and a WebView whose proxy was ignored reports neither.
function startProxy(port, id) {
  const proxy = http.createServer((req, res) => {
    console.log(`proxy ${id} response`, req.url);
    res.writeHead(200, { 'Content-Type': 'text/html' });
    res.end(`
    <html>
      <head>
      </head>
      <body>
        <h1>Proxy Works</h1>
        <p id="proxy">${id}</p>
        <p id="url">${req.url}</p>
        <p id="method">${req.method}</p>
        <p id="headers">${JSON.stringify(req.headers)}</p>
      </body>
    </html>
  `);
  });
  proxy.on('connect', (req, clientSocket, head) => {
    console.log(`proxy ${id} connect request`, req.url);
    webrtcLog.http.push({ proxy: id, connect: req.url });
    // Terminate the tunnel at this same proxy so CONNECT loads also get the
    // marker page identifying which proxy handled them.
    const { port: originPort, hostname } = new URL(`http://127.0.0.1:${port}`);
    const serverSocket = net.connect(originPort || 80, hostname, () => {
      clientSocket.write('HTTP/1.1 200 Connection Established\r\n' +
                      'Proxy-agent: Node.js-Proxy\r\n' +
                      '\r\n');
      serverSocket.write(head);
      serverSocket.pipe(clientSocket);
      clientSocket.pipe(serverSocket);
    });
  });
  proxy.listen(port, null, () => {
    console.log(`proxy server ${id} listening on port ${port}`);
  });
  return proxy;
}

// 8083 keeps the port the existing ProxyController test already uses.
const proxy = startProxy(8083, 'A');
const proxyB = startProxy(8084, 'B');

// SOCKS5 proxies with the same marker page. The tunnel ends here: after the
// SOCKS handshake the socket goes to an HTTP server that answers as proxy
// `id`, so a SOCKS load is as identifiable as an HTTP-proxy one and needs no
// outside network. Keep-alive works as on any HTTP server, so a client can
// pool the tunnel.
function startSocksProxy(port, id) {
  const pages = http.createServer((req, res) => {
    console.log(`socks ${id} response`, req.url);
    res.writeHead(200, { 'Content-Type': 'text/html' });
    res.end(`
    <html>
      <head>
      </head>
      <body>
        <h1>Proxy Works</h1>
        <p id="proxy">${id}</p>
        <p id="url">${req.url}</p>
        <p id="method">${req.method}</p>
        <p id="headers">${JSON.stringify(req.headers)}</p>
      </body>
    </html>
  `);
  });
  const socks = net.createServer((socket) => {
    socket.on('error', () => {});
    // Greeting: VER, NMETHODS, METHODS. Accept "no authentication".
    socket.once('data', () => {
      socket.write(Buffer.from([0x05, 0x00]));
      // Request: VER, CMD, RSV, ATYP, DST.ADDR, DST.PORT.
      socket.once('data', (request) => {
        const target = socksAddress(request, 3);
        if (request[1] === 0x03) {
          console.log(`socks ${id} udp associate request`, target && target.text);
          webrtcLog.socks.push({ proxy: id, udpAssociate: target && target.text });
          socksUdpRelay(socket, id);
          return;
        }
        // CONNECT: the destination is not dialled; the tunnel ends at this
        // proxy.
        console.log(`socks ${id} connect request`, target && target.text);
        webrtcLog.socks.push({ proxy: id, connect: target && target.text });
        socket.write(Buffer.from([0x05, 0x00, 0x00, 0x01, 0, 0, 0, 0, 0, 0]));
        pages.emit('connection', socket);
      });
    });
  });
  socks.listen(port, null, () => {
    console.log(`socks proxy ${id} listening on port ${port}`);
  });
  return socks;
}

// ATYP, ADDR, PORT at `offset`, as in a SOCKS5 request or UDP header.
function socksAddress(buffer, offset) {
  let host;
  let end;
  if (buffer[offset] === 0x01) {
    host = [...buffer.subarray(offset + 1, offset + 5)].join('.');
    end = offset + 5;
  } else if (buffer[offset] === 0x03) {
    const length = buffer[offset + 1];
    host = buffer.subarray(offset + 2, offset + 2 + length).toString();
    end = offset + 2 + length;
  } else if (buffer[offset] === 0x04) {
    host = buffer.subarray(offset + 1, offset + 17).toString('hex');
    end = offset + 17;
  } else {
    return null;
  }
  if (buffer.length < end + 2) return null;
  const port = buffer.readUInt16BE(end);
  return { host, port, end: end + 2, text: `${host}:${port}` };
}

// UDP ASSOCIATE: relays the client's datagrams to where their SOCKS header
// says, and the replies back, for as long as the control connection lives.
function socksUdpRelay(socket, id) {
  const relay = dgram.createSocket('udp4');
  let client = null;
  relay.on('error', () => {});
  relay.on('message', (message, from) => {
    if (client === null
        || (from.address === client.address && from.port === client.port)) {
      // From the client: RSV(2), FRAG, ATYP, DST.ADDR, DST.PORT, DATA.
      if (message.length < 10 || message[2] !== 0) return;
      const target = socksAddress(message, 3);
      if (!target) return;
      client = { address: from.address, port: from.port };
      console.log(`socks ${id} udp relay to`, target.text);
      webrtcLog.socks.push({ proxy: id, udpTo: target.text });
      relay.send(message.subarray(target.end), target.port, target.host);
      return;
    }
    const header = Buffer.alloc(10);
    header[3] = 0x01;
    from.address.split('.').forEach((b, i) => { header[4 + i] = Number(b); });
    header.writeUInt16BE(from.port, 8);
    relay.send(Buffer.concat([header, message]), client.port, client.address);
  });
  relay.bind(0, () => {
    const port = relay.address().port;
    socksRelayPorts.add(port);
    // BND.ADDR is the address the client reached this proxy on.
    const reply = Buffer.from([0x05, 0x00, 0x00, 0x01, 0, 0, 0, 0, 0, 0]);
    socket.localAddress.replace('::ffff:', '').split('.')
      .forEach((b, i) => { reply[4 + i] = Number(b); });
    reply.writeUInt16BE(port, 8);
    socket.write(reply);
  });
  socket.on('close', () => relay.close());
}

const socksA = startSocksProxy(8085, 'A');
const socksB = startSocksProxy(8086, 'B');

// STUN server (RFC 5389 Binding only) for the WebRTC tests. Answers with the
// address it saw, and logs whether the request came through a SOCKS relay.
function startStunServer(port) {
  const server = dgram.createSocket('udp4');
  server.on('error', (err) => console.error('stun', err));
  server.on('message', (message, from) => {
    if (message.length < 20 || message.readUInt16BE(0) !== 0x0001
        || message.readUInt32BE(4) !== 0x2112A442) {
      return;
    }
    const viaSocks = socksRelayPorts.has(from.port);
    console.log(`stun binding request from ${from.address}:${from.port}`,
        viaSocks ? '(socks relay)' : '(direct)');
    webrtcLog.stun.push({ from: `${from.address}:${from.port}`, viaSocks });
    // Binding success response with XOR-MAPPED-ADDRESS.
    const attribute = Buffer.alloc(12);
    attribute.writeUInt16BE(0x0020, 0);
    attribute.writeUInt16BE(8, 2);
    attribute[5] = 0x01;
    attribute.writeUInt16BE(from.port ^ 0x2112, 6);
    const cookie = [0x21, 0x12, 0xA4, 0x42];
    from.address.split('.').forEach((b, i) => { attribute[8 + i] = Number(b) ^ cookie[i]; });
    const header = Buffer.alloc(20);
    header.writeUInt16BE(0x0101, 0);
    header.writeUInt16BE(attribute.length, 2);
    message.copy(header, 4, 4, 20);
    server.send(Buffer.concat([header, attribute]), from.port, from.address);
  });
  server.bind(port, () => console.log(`stun server listening on udp port ${port}`));
  return server;
}

const stun = startStunServer(3478);

process.on('uncaughtException', function (err) {
  console.error(err);
});