LiveData = (function() {
  var sample;
  var ws = new WebSocket("ws://"+location.host);
  ws.binaryType = 'arraybuffer';
  ws.addEventListener('message',  handleSamples);

  function handleSamples(msg) {
    sample = new Float32Array(msg.data)
  }

  function getSample() {
    return sample || new Float32Array(25);
  }

  return {getSample: getSample};
})()
