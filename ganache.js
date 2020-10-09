const ganache = require("ganache-core");
const server = ganache.server({ fork: "https://mainnet.infura.io/v3/834349d34934494f80797f2f551cb12e" });
const fs = require('fs');

server.listen(8546, function(err, blockchain) {
    if (err) return console.log(err);
    // console.log(blockchain);
    let keyVars = 'DEVELOPMENT_ADDRRESS=\"' + Object.keys(blockchain['unlocked_accounts'])[0] + "\"\n";
    keyVars += 'DEVELOPMENT_PRIVATE_KEY=\"' + blockchain['unlocked_accounts'][Object.keys(blockchain['unlocked_accounts'])[0]]['secretKey'].toString('hex') + '\"\n';
    keyVars += 'DEVELOPMENT_PRIVATE_KEY_SECONDARY=\"' + blockchain['unlocked_accounts'][Object.keys(blockchain['unlocked_accounts'])[1]]['secretKey'].toString('hex') + '\"\n';

    fs.writeFile('.env', keyVars, function(err) {
    	if(err)
    		console.log(err);
    	console.log('wrote keys to .env with no errors');
    });

});