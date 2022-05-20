require('dotenv').config();
const express = require('express');
const app = express();
const rp = require('request-promise');


var timeout = parseInt(process.env.TIMEOUT);
var port = process.env.PORT || 8080;
var targetURL = process.env.TARGETURL
var instanceName = process.env.INSTANCENAME;

app.get('/', function (req, res) {
  var o = {
    headers: {      
    },
    timeout: timeout,
    resolveWithFullResponse: true
  }

  console.log("Requesting data from "+ targetURL);
  rp.get(targetURL, o)
    .then(function (data) {
      console.log("Data received from ... " + targetURL);
      console.log("Response status code: " + data.statusCode);     

      res.write("Answer from " + instanceName + " calling: " +targetURL );
      res.write(data.body)
      console.log("Answer from " + instanceName + " calling: " +targetURL );
      console.log(data.body);
      console.log("")
      res.send();

    },
      function (err) {
        // if backend request fails
        console.log("Answer from " + instanceName + " calling: " +targetURL );
        console.log("something bad happenend downstream, sending 500")
        console.log("")
        res.statusCode = 500;
        res.send(err);
      });
});

app.listen(port);
console.log("generichttpendpoint running & listening on " + port + ".\nChange the port by adding an environment variable PORT.")
console.log ("")







