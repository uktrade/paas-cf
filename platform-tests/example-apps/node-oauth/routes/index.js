var express = require('express');
const app = express();
const simpleOauthModule = require('simple-oauth2')


  // Set the configuration settings
  const oauth2 = simpleOauthModule.create({
    client: {
      id: process.env.CLIENT_ID,
      secret: process.env.CLIENT_SECRET
    },
    auth: {
      tokenHost: process.env.ACCESS_TOKEN_HOST,
      tokenPath: process.env.ACCESS_TOKEN_PATH,
      authorizePath: process.env.AUTHORIZE_PATH
    },
    http: {
      rejectUnauthorized: false
    }
  });

  // Authorization uri definition
  const authorizationUri = oauth2.authorizationCode.authorizeURL({
    redirect_uri: 'http://localhost:3000/auth/cloudfoundry/callback',
    scope: 'cloud_controller.read,cloud_controller.admin_read_only,cloud_controller.global_auditor,openid,oauth.approvals',
    state: 'some-non-empty-value',
  });

  // Initial page redirecting to Github
  app.get('/auth', (req, res) => {
    console.log(authorizationUri);
    res.redirect(authorizationUri);
  });

  // Callback service parsing the authorization token and asking for the access token
  app.get('/auth/cloudfoundry/callback', (req, res) => {
    const code = req.query.code;
    const options = {
      code,
      'redirect_uri': 'http://localhost:3000/auth/cloudfoundry/callback',
    };

    oauth2.authorizationCode.getToken(options, (error, result) => {
      if (error) {
        console.error('Access Token Error', error.message);
        return res.json('Authentication failed');
      }

      console.log('The resulting token: ', result);
      const token = oauth2.accessToken.create(result);

      return res
        .status(200)
        .json(token);
    });
  });

module.exports = app;
