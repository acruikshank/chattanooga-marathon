RecordedData = function(file, playbackRate, cb) {
  playbackRate = playbackRate || 1.0;
  var times, data;
  var currentTime;
  var lastRender;
  var index = 0;
  var out = {};

  function fetchData() {
    var request = new XMLHttpRequest();
    request.open("GET", file, true);

    request.onreadystatechange = function() {
      if (request.readyState > 3) {
        if (request.status != 200)
          displayError(request.responseText);
        else
          uploadComplete(request.response);
      }
    }
    request.send();
  }

  function uploadComplete(csv) {
    var values = [];
    for (var i=0; i<26; i++) values.push([]);
    for (var re = /(.*)\n/gm, m, i=0; m = re.exec(csv); i++)
      if (i>0)
        m[1].split(',').forEach(function(v,j) { values[j].push(v) })
    times = new Float64Array(values[0]);
    data = values.slice(1).map(function(v) { return new Float64Array(v) });

    out.startTime = times[0];
    out.endTime = times[times.length-1];
    out.timeRange = out.endTime - out.startTime;
    currentTime = out.startTime;
    lastRender = new Date().getTime();

    if (cb) cb();
  }

  out.getSample = function getSample() {
    if (! times) return new Float32Array(25);

    var now = new Date().getTime();
    currentTime += (now - lastRender) / 1000 * playbackRate;
    lastRender = now;
    while (index < times.length-1 && times[index] < currentTime) index++;
    out.currentTime = currentTime;

    var sample = new Float32Array(data.length);
    for (var i=0; i<data.length; i++) sample[i] = data[i][index];
    return sample;
  }

  out.sampleAt = function sampleAt(time, start, end) {
    start = start || 0;
    end = (end == null ? times.length : end);
    if (end - start < 2) {
      var sample = new Float32Array(data.length);
      for (var i=0; i<data.length; i++) sample[i] = data[i][start];
      return sample;
    }
    var midpoint = start + Math.floor((end-start)/2);
    return time < times[midpoint]
      ? sampleAt(time, start, midpoint)
      : sampleAt(time, midpoint, end)
  }


  fetchData();

  return out;
}
