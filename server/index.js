var server = require('http').createServer();
var express = require('express');
var concat = require('concat-stream');
var WebSocketServer = require('ws').Server;
var wss = new WebSocketServer({ server: server });

var app = express();

var connections = [];

app.use(function(req, res, next){
  req.pipe(concat(function(data){
    req.body = data;
    next();
  }));
});
app.use(express.static('public'));

app.post('/api/samples', function(req, res) {
  var body = req.body.toString('binary');

  var buf = new ArrayBuffer(body.length);
  var byteView = new Int8Array(buf);
  for (var i=0; i<body.length; i++)
    byteView[i] = body.charCodeAt(i);

  var samples = new Float32Array(buf);
  connections.forEach(function(connection) {
    connection.send(samples, {binary:true});
  })

  res.sendStatus(200);
})

wss.on('connection', function connection(ws) {

  connections.push(ws);

  ws.on('message', function incoming(message) {
    console.log('received: %s', message);
  });

  ws.on('close', function() {
    var index = connections.indexOf(ws);
    console.log('Close index', index, !~index)
    if (~index) connections.splice(index,1);
  })

  ws.send(new Float32Array([200]), {binary:true});
});

server.on('request', app);
server.listen(8000, function () { console.log('Listening on ' + server.address().port) });
