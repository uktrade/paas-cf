var express = require('express');
var router = express.Router();
var OAuth = require('oauth');

/* GET home page. */
router.get('/', function(req, res, next) {
  res.render('index', { title: 'Express' });
})

 router.post('/login', function(req, res, next){
   var OAuth2 = OAuth.OAuth2
   var clientId = process.env.CLIENT_ID
   var clientSecret = process.env.CLIENT_SECRET
   var baseSite = ''
   var authorizePath = process.env.AUTHORIZE_PATH
   var accessTokenPath = process.env.ACCESS_TOKEN_PATH
   var customHeaders = ''
   var oauth2 = new OAuth2(clientId,
     clientSecret,
     baseSite,
     authorizePath,
     accessTokenPath,
     customHeaders,
   );

});

module.exports = router;
