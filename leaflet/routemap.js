var fusionTableID = "1qA15yQEnAQ7CJNnCCrKSh1-zhI5d-xGV1B6c8wHr";
var polyline;

function getBusRoutes()
{
  var query = "SELECT 'route' FROM " + fusionTableID + " GROUP BY 'route'";
  var url = "https://www.googleapis.com/fusiontables/v1/query?sql=" + encodeURIComponent(query) + "&key=AIzaSyDAIH2tiaKi8IkKbakTlozr7Bh8dClbjSw&callback=routesCallback";
  requestServerCall(url);
}

function routesCallback(data)
{
  for (var i in data["rows"]) {
    var route = data["rows"][i];
    var option = $("<option>" + route + "</option>");
    option.appendTo("select#route");
  }
}

function getBusStopData(route)
{
  console.log("route = " + route);
  var query = "SELECT 'latitude', 'longitude' FROM " + fusionTableID + " WHERE 'route' = '" + route + "'";
  var url = "https://www.googleapis.com/fusiontables/v1/query?sql=" + encodeURIComponent(query) + "&key=AIzaSyDAIH2tiaKi8IkKbakTlozr7Bh8dClbjSw&callback=busStopCallback";
  requestServerCall(url);
}

// Used by all JSONP calls -- constructs the script tag at Runtime
function requestServerCall(url) {
  console.log(url);
  var head = document.head;
  var script = document.createElement("script");
  script.setAttribute("src", url);
  head.appendChild(script);
  head.removeChild(script);
}

function busStopCallback(data) {
  polyline = L.polyline(data["rows"], {color: 'red'}).addTo(map);
  map.fitBounds(polyline.getBounds());
}

// create a map in the "map" div, set the view to a given place and zoom
var map = L.map('map').setView([53.8, -1.549], 12);

// add an OpenStreetMap tile layer
L.tileLayer('http://{s}.tile.osm.org/{z}/{x}/{y}.png', {
    attribution: '&copy; <a href="http://osm.org/copyright">OpenStreetMap</a> contributors'
}).addTo(map);

getBusRoutes();

$("#route").change(function() {
  if (polyline != null) {
    window.map.removeLayer(polyline);
  }
  var route = $("#route").val();
  getBusStopData(route);
});
