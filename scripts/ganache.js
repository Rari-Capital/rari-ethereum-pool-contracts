const ganache = require("ganache-core");
var dotenv = require('dotenv').config().parsed;
const server = ganache.server({ fork: process.env.DEVELOPMENT_WEB3_PROVIDER_URL_TO_BE_FORKED, unlocked_accounts: ["0x10dB6Bce3F2AE1589ec91A872213DAE59697967a"] });

const fs = require('fs');

server.listen(8546, function(err, blockchain) {
  if (err) return console.log(err);

  if (dotenv === undefined) dotenv = {};
  dotenv.DEVELOPMENT_ADDRESS = Object.keys(blockchain['unlocked_accounts'])[1];
  dotenv.DEVELOPMENT_ADDRESS_SECONDARY = Object.keys(blockchain['unlocked_accounts'])[2];
  dotenv.DEVELOPMENT_PRIVATE_KEY = blockchain['unlocked_accounts'][Object.keys(blockchain['unlocked_accounts'])[1]]['secretKey'].toString('hex');
  dotenv.DEVELOPMENT_PRIVATE_KEY_SECONDARY = blockchain['unlocked_accounts'][Object.keys(blockchain['unlocked_accounts'])[2]]['secretKey'].toString('hex');
  let keyVars = '';
  for (const key of Object.keys(dotenv)) keyVars += key + "=\"" + dotenv[key] + "\"\n";

  fs.writeFile('.env', keyVars, function(err) {
    if (err) console.log(err);
  });
});
