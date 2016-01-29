PositionData = function(file, cb) {
  var out = {};

  var xhr = new XMLHttpRequest();
  xhr.open('GET', file, true);
  xhr.responseType = 'document';
  xhr.overrideMimeType('text/xml');

  var data = [];
  xhr.onload = function () {
    if (xhr.readyState === xhr.DONE && xhr.status === 200) {

      var gpx = xhr.responseXML;
      var points = gpx.querySelectorAll('trkpt');
      for (var i=0, point; point = points[i]; i++) {
        var lat = Number(point.getAttribute('lat'));
        var lon = Number(point.getAttribute('lon'));
        var time = new Date(point.querySelector('time').innerHTML);

        if (!out.minLat || out.minLat > lat) out.minLat = lat;
        if (!out.maxLat || out.maxLat < lat) out.maxLat = lat;
        if (!out.minLon || out.minLon > lon) out.minLon = lon;
        if (!out.maxLon || out.maxLon < lon) out.maxLon = lon;
        if (!out.minDate || out.minDate > time) out.minDate = time;
        if (!out.maxDate || out.maxDate < time) out.maxDate = time;

        data.push( {
          lat: lat, lon: lon, time: time,
          elevation: Number(point.querySelector('ele').innerHTML),
          heart: Number(point.querySelector('hr').innerHTML),
        })
      }
      cb(out, data);
    }
  };

  xhr.send(null);

  out.sampleAt = function sampleAt(time) {
    if (data.length < 1) return;

    return sampleIn(time, 0, data.length);
  }

  function sampleIn(time, start, end) {
    if (end - start < 2) return data[start];
    var midpoint = start + Math.floor((end-start)/2);
    return time < data[midpoint].time
      ? sampleIn(time, start, midpoint)
      : sampleIn(time, midpoint, end)
  }

  return out;
}
