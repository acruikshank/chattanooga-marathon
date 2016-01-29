LiveData = function() {
  var sample;
  var ws = new WebSocket("ws://"+location.host);
  ws.binaryType = 'arraybuffer';
  ws.addEventListener('message',  handleSamples);

  function handleSamples(msg) {
    var array = new Float32Array(msg.data)
    if (array.length > 24)
      sample = array;
  }

  function getSample() {
    return sample || new Float32Array(25);
  }

  return {getSample: getSample};
}
