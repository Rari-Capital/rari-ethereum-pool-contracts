const ganache = require("ganache-core");
require('dotenv').config();
const server = ganache.server({ fork: process.env.DEVELOPMENT_WEB3_PROVIDER_URL_TO_BE_FORKED });

const fs = require('fs');

server.listen(8546, function(err, blockchain) {
    if (err) return console.log(err);

    let keyVars = 'DEVELOPMENT_ADDRESS=\"' + Object.keys(blockchain['unlocked_accounts'])[0] + "\"\n";
    keyVars += 'DEVELOPMENT_ADDRESS_SECONDARY=\"' + Object.keys(blockchain['unlocked_accounts'])[1] + "\"\n";

    fs.writeFile('.env', keyVars, function(err) {
    	if(err) console.log(err);
    	console.log('wrote keys to .env with no errors');
    });
});