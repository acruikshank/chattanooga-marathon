var server = require('http').createServer();
var express = require('express');
var fs = require('fs');
var concat = require('concat-stream');
var WebSocketServer = require('ws').Server;
var wss = new WebSocketServer({ server: server });

var SAMPLE_SIZE = 26;

var app = express();

var connections = [];

app.use(function(req, res, next){
  req.pipe(concat(function(data){
    req.body = data;
    next();
  }));
});
app.use(express.static('public'));

app.get('/recorded', function(req, res) {
  var path = './public/recordings/';
  fs.readdir(path, function (err, files) {
    if(err) throw err;
    res.send('<html><head><title>recordings</title><link rel="stylesheet" type="text/css" href="/css/recordings.css"></head>'
      +'<body><h1>Recordings</h1><ul><li>'
      + files.filter(function(f){return f.match(/\.csv$/)})
             .map(function(file) { return '<a href="'+file+'">'+file+'</a>'; }).join('</li><li>')
      + '</li></ul></body></html>');
  });
})

app.post('/api/1.0/samples/:device/:session', function(req, res) {
  var body = req.body.toString('binary');

  var buf = new ArrayBuffer(body.length);
  var byteView = new Int8Array(buf);
  for (var i=0; i<body.length; i++)
    byteView[i] = body.charCodeAt(i);

  var samples = new Float64Array(buf);
  var start = new Date(1000*samples[0]);
  console.log('time:',start, 'user:',req.params.device, 'session:', req.params.session, 'length:',body.length / 8);
  recordDeviceData(req.params.device, req.params.session, samples);

  var times = [];
  for (var i=0; i<samples.length; i+=26) times.push( new Date(1000*samples[i]).getTime() - start.getTime());
  var valuesOnly = new Float32Array(Array.prototype.slice.call(samples,1));
  connections.forEach(function(connection) {
    connection.send(valuesOnly, {binary:true});
  })

  res.sendStatus(200);
})

function recordDeviceData(device, session, data) {
  var path = 'public/recordings/'+device.replace(/[^\w-]/g,'')+'-'+session.replace(/[^\w-]/g,'')+'.csv';
  fs.stat(path, fileExists);

  function fileExists(err, stat) { stat ? appendData() : createFile(); }

  function createFile() {
    var writer = fs.createWriteStream(path, {flags:'w'})
    writer.write('Time, Theta AF3,Alpha AF3,Low beta AF3,High beta AF3, Gamma AF3, Theta AF4,Alpha AF4,Low beta AF4,High beta AF4, Gamma AF4, Theta T7,Alpha T7,Low beta T7,High beta T7, Gamma T7, Theta T8,Alpha T8,Low beta T8,High beta T8, Gamma T8, Theta Pz,Alpha Pz,Low beta Pz,High beta Pz, Gamma Pz')
    writer.end('\n')
    writer.on('finish', appendData)
  }

  function appendData() {
    var writer = fs.createWriteStream(path, {flags:'a'})
    for (var i=0; i<data.length; i++) {
      writer.write(String(data[i]));
      writer.write( (i+1)%SAMPLE_SIZE ? ',' : '\n');
    }
    writer.end();
  }
}

/* Write data
  stat file recordings/{deviceID}-{sessionID}.csv
  if (! exists) write header to file
  append data
*/

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
