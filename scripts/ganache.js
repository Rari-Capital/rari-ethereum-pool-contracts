const ganache = require("ganache-core");
require('dotenv').config();
const server = ganache.server({ fork: process.env.DEVELOPMENT_WEB3_PROVIDER_URL_TO_BE_FORKED, unlocked_accounts: ["0x10dB6Bce3F2AE1589ec91A872213DAE59697967a"] });

const fs = require('fs');

server.listen(8546, function(err, blockchain) {
    if (err) return console.log(err);
    let keyVars = 'DEVELOPMENT_ADDRESS=\"' + Object.keys(blockchain['unlocked_accounts'])[1] + "\"\n";
    keyVars += 'DEVELOPMENT_ADDRESS_SECONDARY=\"' + Object.keys(blockchain['unlocked_accounts'])[2] + "\"\n";
    keyVars += 'DEVELOPMENT_PRIVATE_KEY=\"' + blockchain['unlocked_accounts'][Object.keys(blockchain['unlocked_accounts'])[1]]['secretKey'].toString('hex') + '\"\n';
    keyVars += 'DEVELOPMENT_PRIVATE_KEY_SECONDARY=\"' + blockchain['unlocked_accounts'][Object.keys(blockchain['unlocked_accounts'])[2]]['secretKey'].toString('hex') + '\"\n';
    keyVars += "DEVELOPMENT_WEB3_PROVIDER_URL_TO_BE_FORKED=\"" + process.env.DEVELOPMENT_WEB3_PROVIDER_URL_TO_BE_FORKED + "\"\n";
    console.log(keyVars);

    fs.writeFile('.env', keyVars, function(err) {
    	if (err) console.log(err);
    	console.log('wrote keys to .env with no errors');
    });
});